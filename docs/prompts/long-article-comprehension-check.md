# レイヤーⅠ 長文読解 — 1秒チェック（2択クイズ）追加

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/long-article-comprehension-check.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

---

## 機能概要

**現状:** 長文読解画面で「→」を押すと、保存（新規時）→ レイヤーⅠ 3択画面へ戻る。

**改修後:**

```
キーワード → AI生成 → 読解 → 1秒チェック（2択） → 正解/解説表示 → 3択へ戻る
```

- クイズは**文脈・ロジック理解**のみ（発話・発音は触らない）
- 問題・選択肢・正解・解説は**長文生成 AI レスポンスに同梱**（Chrome AI への往復は1回のまま）
- 保存済み長文（旧データ）にクイズが無い場合は**クイズをスキップ**して従来どおり終了

---

## 共通ルール（全 Step 共通・必ず守る）

1. **フェーズマシン設計を維持** — `Layer1LongReadingScreen` が `keyword | generate | reading` を切り替える既存パターンに `comprehensionCheck` を追加する。Navigator で別画面を積まない。
2. **レイヤーⅠの範囲に閉じる** — テキスト選択式 2 択のみ。音声入力・自由記述・発音評価は入れない。
3. **l10n** — ユーザー向け文言は `gradus_l10n.dart` / `app_strings.dart` 経由。ja / en / vi を揃える。
4. **後方互換** — 旧 `{"body": "..."}` 形式の AI レスポンス・クイズ未保存の `LongArticle` は落とさない。
5. **スコープ外を触らない** — その Step の受け入れ条件以外のリファクタ・ドキュメント追加はしない。
6. **完了報告** — Step 終了時に「変更ファイル一覧」「手動確認手順」「次 Step への前提」を短く報告する。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| フロー本体 | `lib/views/layers/long_article_flow_screen.dart` |
| 読解画面 | `lib/views/layers/long_article_reader_screen.dart` |
| 操作バー（→） | `lib/widgets/long_article_action_row.dart` |
| AI プロンプト | `lib/data/long_article_ai_prompt.dart` |
| レスポンス解析 | `lib/services/long_article_response_parser.dart` |
| 生成画面 | `lib/views/layers/long_article_generate_screen.dart` |
| 長文モデル | `lib/models/long_article.dart` |
| 長文サービス | `lib/services/long_article_service.dart` |
| 入口 | `lib/views/layers/layer1_entry_screen.dart` |
| 統合テスト | `test/layers_test.dart` |
| パーサーテスト | `test/long_article_response_parser_test.dart` |

---

## Step 1 — データモデル + AI プロンプト + パーサー

### 目的
長文生成 AI レスポンスに「1秒チェック」用クイズを同梱し、パースできる基盤を作る。

### 指示

1. **新規モデル** `lib/models/long_article_comprehension_check.dart` を追加:

```dart
class LongArticleComprehensionCheck {
  final String question;      // 問題文（日本語）
  final String optionA;       // 選択肢A
  final String optionB;       // 選択肢B
  final String correctOption; // "A" または "B"
  final String explanation;   // 1行解説
}
```

- `fromJson` / `toJson` / `copyWith` を既存モデル（`LongArticle` 等）と同型で実装
- `correctOption` は `"A"` / `"B"` のみ許可（バリデーション）

2. **生成結果ラッパー** `lib/models/long_article_generation_result.dart`（または同等）を追加:

```dart
class LongArticleGenerationResult {
  final String body;
  final LongArticleComprehensionCheck? comprehensionCheck;
}
```

3. **`lib/data/long_article_ai_prompt.dart`** の `buildPrompt` を拡張。出力 JSON を次の形に変更:

```json
{
  "body": "（生成した文章本文）",
  "comprehensionCheck": {
    "question": "この文章から読み取れる内容として正しいのはどちらですか？",
    "optionA": "（選択肢A）",
    "optionB": "（選択肢B）",
    "correctOption": "A",
    "explanation": "（1行解説）"
  }
}
```

**プロンプトに追加する制約（日本語で AI に指示）:**

- 問題は**文脈・因果・主張の理解**を問う（語彙暗記・発音・言い換えは不可）
- 選択肢は**短い日本語テキスト**（1〜2文以内）
- 正解は `"A"` または `"B"` のみ
- `explanation` は**1行**（なぜ正解か／なぜもう一方が違うか）
- レイヤーⅠ（インプット確認）の範囲に閉じる

4. **`lib/services/long_article_response_parser.dart`** を拡張:

- 既存 `parse(String)` は**後方互換のため残す**（`body` のみ返す）
- 新規 `parseResult(String)` → `LongArticleGenerationResult?` を追加
- `body` が無い／空 → `null`
- `comprehensionCheck` が無い／不完全 → `body` は返すが `comprehensionCheck: null`

5. **テスト** `test/long_article_response_parser_test.dart` を拡張:
   - 新 JSON 形式（body + comprehensionCheck）の正常系
   - 旧 `{"body": "..."}` のみでも動く後方互換
   - `correctOption` が `"C"` 等の異常値 → comprehensionCheck は null
   - comprehensionCheck の必須キー欠落 → comprehensionCheck は null、body は返る

### 受け入れ
- 新 JSON をパースして `LongArticleGenerationResult` が得られる
- 旧形式でも `body` だけは従来どおり取り出せる
- `flutter analyze` が通る
- パーサーテストが通る

---

## Step 2 — 生成画面の配線変更

### 目的
Chrome AI 貼付後、本文だけでなくクイズデータもフロー本体へ渡す。

### 前提
Step 1 完了（`LongArticleGenerationResult` / `parseResult` 存在）

### 指示

1. **`lib/views/layers/long_article_generate_screen.dart`**
   - `onGenerated` の型を `ValueChanged<String>` → `ValueChanged<LongArticleGenerationResult>` に変更
   - `_pasteAndApply` で `LongArticleResponseParser.parseResult(text)` を使う
   - `body == null` なら従来どおり `'長文読解_解析できません'` を表示
   - 成功時は `widget.onGenerated(result)` を呼ぶ

2. **`lib/views/layers/long_article_flow_screen.dart`**（この Step では最小限）
   - `_onArticleGenerated` の引数を `LongArticleGenerationResult` に変更
   - 状態 `_articleBody` に加え `_comprehensionCheck`（`LongArticleComprehensionCheck?`）を保持
   - **まだ UI / フェーズ追加はしない**（Step 3 で行う）

3. コンパイルが通るよう、呼び出し元の型エラーをすべて解消する。

### 受け入れ
- 生成成功後、フロー本体が `body` と `comprehensionCheck` を保持できる
- 旧形式 AI レスポンス（body のみ）でも生成フローは完走する（comprehensionCheck は null）
- `flutter analyze` が通る

---

## Step 3 — フロー遷移：読解 → 1秒チェック → 終了

### 目的
「→」ボタンで直接 3 択に戻らず、クイズフェーズを挟む。

### 前提
Step 2 完了

### 指示

1. **`long_article_flow_screen.dart`** の `_LongReadingPhase` に `comprehensionCheck` を追加:

```dart
enum _LongReadingPhase { keyword, generate, reading, comprehensionCheck }
```

2. **遷移ロジック:**

| 状況 | 「→」押下後 |
|------|------------|
| 新規生成フローで `comprehensionCheck != null` | `comprehensionCheck` フェーズへ |
| 保存済み `initialArticle` でクイズあり | 同上 |
| クイズが null（旧 AI レスポンス / 旧 LongArticle） | 従来の `_finish()` へ直行 |

3. **`LongArticleReaderScreen` の `onFinish`** は「読解完了」コールバックとして残し、呼び出し元（フロー本体）で上記分岐を行う。

4. **`_finish()` のタイミング変更:**
   - 保存（新規時）と 3 択への復帰は、**クイズ完了後**に行う
   - 保存済み `initialArticle` は従来どおり再保存せず、クイズ後に `onBackToModeSelect` のみ

5. **`comprehensionCheck` フェーズ用のプレースホルダー Widget** を仮置きしてよい（Step 4 で本実装）:

```dart
_LongReadingPhase.comprehensionCheck => LongArticleComprehensionCheckScreen(
  check: _comprehensionCheck!,
  onComplete: _finish,
),
```

   Step 3 時点で Screen ファイルが無ければ、最小限のスタブ（「TODO」+ `onComplete` ボタン）を作ってコンパイルを通す。

6. **`initialArticle` から読解開始した場合:**
   - `widget.initialArticle?.comprehensionCheck` を `_comprehensionCheck` にセット（Step 5 で LongArticle にフィールド追加。Step 3 時点では optional チェーンで null 許容）

### 受け入れ
- クイズあり → 読解後に comprehensionCheck フェーズへ進む（スタブでも可）
- クイズなし → 従来どおり即 `_finish()`
- `flutter analyze` が通る

---

## Step 4 — 1秒チェック画面 UI

### 目的
2 択クイズ UI と、回答後の正解/解説表示を実装する。

### 前提
Step 3 完了（フローに `comprehensionCheck` フェーズが存在）

### 指示

1. **新規** `lib/views/layers/long_article_comprehension_check_screen.dart`

**レイアウト（既存トーンに合わせる — `AppColors.current` / `SafeArea` / `Material(color: palette.scene)`）:**

```
┌─────────────────────────┐
│  1秒チェック（見出し）    │
│                         │
│  {question}             │
│                         │
│  ┌─────────────────┐    │
│  │  A. {optionA}   │    │  ← タップ可能
│  └─────────────────┘    │
│  ┌─────────────────┐    │
│  │  B. {optionB}   │    │
│  └─────────────────┘    │
└─────────────────────────┘
```

2. **回答フロー:**
   - A/B タップ → 正解/不正解を判定
   - 同画面内で結果を表示（モーダル or インライン展開、どちらでも可）
     - 正解: 緑系 / ✓ アイコン
     - 不正解: 赤系 / ✗ アイコン + 正解は `"A"` / `"B"` を明示
     - `explanation` を 1 行表示
   - 「トップへ戻る」ボタン → `onComplete()` を呼ぶ
   - **任意:** 2 秒後自動で `onComplete()`（ボタンと併存可）

3. **UX 制約:**
   - 回答前は A/B のみ操作可能（他ボタン不要）
   - 回答後は A/B を非活性化
   - 発音ボタン・マイク・TTS は置かない

4. **参考にする既存 UI:**
   - 選択肢ピル: `long_article_keyword_screen.dart` の `_SegmentedPillRow`
   - モード選択タイル: `lib/widgets/mode_list_tile.dart`

5. Step 3 のスタブを本実装に差し替える。

### 受け入れ
- クイズ表示 → タップ → 正解/解説 → 完了で `_finish()` が呼ばれ 3 択へ戻る
- 不正解時も解説が表示される
- `flutter analyze` が通る

---

## Step 5 — 永続化（LongArticle + Service + Backup）

### 目的
新規保存時にクイズも一緒に永続化し、一覧から再読時にもクイズを使えるようにする。

### 前提
Step 1〜4 完了

### 指示

1. **`lib/models/long_article.dart`** に追加:

```dart
final LongArticleComprehensionCheck? comprehensionCheck;
```

- `fromJson` / `toJson` / `copyWith` を更新
- JSON キー: `comprehensionCheck`（オブジェクト or 省略可）

2. **`lib/services/long_article_service.dart`** の `addArticle` に `LongArticleComprehensionCheck? comprehensionCheck` 引数を追加

3. **`long_article_flow_screen.dart` の `_finish()`** で保存時に `_comprehensionCheck` も渡す

4. **`initialArticle` 開始時** に `widget.initialArticle!.comprehensionCheck` を `_comprehensionCheck` へセット（Step 3 で未配線ならここで完了）

5. **`lib/services/gradus_backup.dart`** — `LongArticle.toJson()` 経由で自動的に含まれることを確認。専用変更が要れば最小限追加

6. **マイグレーション不要** — 旧データは `comprehensionCheck: null` として読み、クイズフェーズをスキップ

### 受け入れ
- 新規長文保存後、再読するとクイズフェーズが出る
- 旧 LongArticle（クイズ無し）は従来どおりスキップ
- バックアップ import/export でクイズが保持される
- `flutter analyze` / `test/gradus_backup_test.dart` が通る

---

## Step 6 — ローカライゼーション

### 目的
ハードコード文字列を排除し、ja / en / vi を揃える。

### 前提
Step 4 完了（UI に必要なキーが確定）

### 指示

1. **`lib/localization/gradus_l10n.dart`** に追加（ja / en / vi）:

| キー（例） | 用途 |
|-----------|------|
| `長文読解_1秒チェック_見出し` | 画面タイトル |
| `長文読解_1秒チェック_問題ラベル` | 「この文章について」等（任意） |
| `長文読解_1秒チェック_正解` | 正解フィードバック |
| `長文読解_1秒チェック_不正解` | 不正解フィードバック |
| `長文読解_1秒チェック_正解表示` | 「正解: A」等（`{0}` プレースホルダ） |
| `長文読解_1秒チェック_解説` | 解説ラベル（任意） |
| `長文読解_1秒チェック_トップへ戻る` | 完了ボタン |

2. **`lib/data/layer_help_tips.dart`** — 長文読解の tip に 1 秒チェックの説明を 1 行追加（既存 tip3 付近が自然）

3. UI 内の日本語直書きをすべて `.tr(lang)` / `.trFmt(lang, [...])` に置換

### 受け入れ
- 言語切替でクイズ画面の固定文言が変わる
- `flutter analyze` が通る

---

## Step 7 — テスト更新

### 目的
E2E と単体テストで新フローを担保する。

### 前提
Step 1〜6 完了

### 指示

1. **`test/layers_test.dart`** — 既存テスト  
   `'レイヤーⅠ長文読解：キーワード→同意→Chrome起動→貼付で自動的に読解画面へ進み...'` を更新:
   - モック AI レスポンスに `comprehensionCheck` を含める
   - 「→」タップ後、**クイズ画面が出る**ことを確認
   - 選択肢タップ → 解説表示 → 完了 → 3 択へ戻る
   - 保存された `LongArticle` に `comprehensionCheck` が含まれる

2. **新規** `test/long_article_comprehension_check_screen_test.dart`:
   - 正解タップ → 正解表示
   - 不正解タップ → 不正解 + 解説
   - 完了ボタンで `onComplete` が呼ばれる

3. **`test/long_article_service_test.dart`** — `addArticle` に comprehensionCheck を渡すケース

4. 後方互換テスト — body のみ JSON でフロー完走（クイズスキップ）

### 受け入れ
- `flutter test test/long_article_response_parser_test.dart test/layers_test.dart`（他追加テスト含む）が通る
- `flutter analyze` が通る

---

## スコープ外（今回やらない）

| 項目 | 理由 |
|------|------|
| `LongArticleListScreen` 単体ブラウズの → ボタン | 別 Navigator スタック。必要なら Step 8 として別 PR |
| クイズ無し旧長文への AI 再生成 | オフライン追加生成は別機能 |
| クイズ結果の履歴・正答率保存 | v1 は確認のみ |
| 複数問クイズ | 1秒チェック = 1 問固定 |

---

## Step 依存関係

```
Step 1（モデル+AI+パーサー）
  → Step 2（生成画面配線）
    → Step 3（フロー遷移）
      → Step 4（クイズUI）
        → Step 6（l10n）
      → Step 5（永続化）
  Step 5 + Step 6 → Step 7（テスト）
```

---

## 設計メモ（Gemini 案との差分）

| Gemini 案 | 本プロジェクトの実態 |
|-----------|---------------------|
| Swift/SwiftUI | **Flutter/Dart** |
| トップ画面に戻る | レイヤーⅠ **3 択モード選択**（`Layer1EntryScreen`）へ戻る |
| 新規 View | `Layer1LongReadingScreen` の**フェーズ追加**（Navigator 不使用） |
| AI 追加生成 | 長文生成プロンプトに**同梱**（Chrome AI 1 回で完結） |
