# 25マス拡充度 ＋ ダッシュボード判定（テスト総合／拡充度総合／総合）

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/thinking-matrix-expansion-dashboard.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

**並行改修との関係:**

| ファイル | 内容 | ダッシュボードへの影響 |
|----------|------|------------------------|
| `docs/prompts/long-article-vocab-test.md` | 長文の語彙テスト → **テスト結果の「語彙」** | 5指標の語彙サンプルに混ざる |
| **本ファイル** | 25マス拡充度 ＋ **判定の3段構造** | 「総合／テスト総合／拡充度総合」と拡充％ブロック |

長文側 Step 7 は「語彙指標に含める」まで。**総合の計算式変更・UI の3段化は本ファイルが正本。**  
両方を進める場合は、本ファイルのダッシュボード Step を長文 Step 7 の**後**に実施すると衝突が少ない。

`docs/prompts/category-and-matrix-v2.md` / `layer2-3-thinking-matrix.md` は履歴。本ファイルが拡充度・ダッシュボード改修の正本。

---

## 機能概要（ユーザーの狙い）

### A. 最初から3枚のブランク回答シート

| カテゴリ | マス数 | テンプレート |
|----------|--------|--------------|
| 日常 | 25 | 既存 `ThinkingMatrixPresets`（5列×5テーマ） |
| ビジネス | 25 | 同上 |
| シチュエーション | 15 | 3列×5テーマ |
| **合計（母数）** | **65** | |

- アプリ初回（または25マス／ダッシュボード読込時）に、上記3セットが**無ければ自動作成**する
- 進捗・拡充度の母数は常にこの **65マス**（システム3セットのみ）
- 「オリジナル」やユーザーが追加で作った同カテゴリセットは**拡充度に含めない**（盤面練習用として残置）

### B. 1マスの進捗ウェイト

| 状態 | ウェイト |
|------|----------|
| 未入力 | `0` |
| キーワード入力済み | `1/3`（≈0.33） |
| 結論・理由・具体例（PREP）入力済み | `2/3`（≈0.67） |
| スピーチ実施済み | `1.0` |

- **段階の最大値**を取る（加算しない）
- 判定順: `speech60Done`（かつキーワード非空）→ `1.0`／否则 PREP完了 → `2/3`／否则 キーワード非空 → `1/3`／否则 `0`
- PREP完了の定義は既存 `ThinkingMatrixSet.isCellPrepComplete`（keyword + conclusion + reason + example）
- スピーチの定義は既存 `isCellSpeech60Done`（keyword 非空かつ `speech60Done`）
- **内部計算は `1/3`・`2/3`・`1.0`**（`0.33`/`0.67` の丸め誤差を避ける）。表示は小数第1位

### C. カテゴリ／トータル拡充度

```
日常%     = (日常25マスのウェイト合計) / 25 × 100
ビジネス% = (ビジネス25マスのウェイト合計) / 25 × 100
シチュ%   = (シチュ15マスのウェイト合計) / 15 × 100
トータル% = (全65マスのウェイト合計) / 65 × 100
```

表示は**小数第1位固定**（例: `82.5%` / `23.0%` / `15.2%` / `44.1%`）。

### D. 拡充度総合（A〜E）

| グレード | 条件（トータル%） |
|----------|-------------------|
| A | `>= 75` |
| B | `>= 50` |
| C | `>= 25` |
| D | `> 0` |
| E | `== 0` |

### E. テスト総合（A〜E）

- **現行**の5指標平均（JSST・的中度・PREP・語彙・発音）から出すグレードを **「テスト総合」** にリネーム
- 5指標が揃わないときは従来どおり **E**（データ不足）
- A〜D の閾値は現行 `gradeFromAverage` を維持（A≥4, B≥3, C≥2, else D）

### F. 総合（A〜E）＝テスト総合 × 拡充度総合

数値化: `A=4, B=3, C=2, D=1, E=0`

```
sum = points(テスト総合) + points(拡充度総合)   // 0〜8
```

| 総合 | sum |
|------|-----|
| A | 7〜8 |
| B | 5〜6 |
| C | 3〜4 |
| D | 1〜2 |
| E | 0 |

### G. ダッシュボード表示イメージ

```
判定
　総合　　　　　B
　テスト総合　　A
　拡充度総合　　C

テスト結果
　Ⅰ　語彙　　　…
　（的中度・PREP・JSST・発音 — 既存5指標。レイアウトは現行の層ラベルを踏襲）

25マス拡充度
　日常　　　　　　　82.5%
　ビジネス　　　　　23.0%
　シチュエーション　15.2%
　トータル　　　　　44.1%
```

※「テスト結果」の中身は既存5指標を維持。ユーザー文の `I 語彙 / II 的中度` はセクション例示であり、的中度をレイヤーⅡに付け替える意図ではない。

---

## 共通ルール（全 Step 共通・必ず守る）

1. **レイヤーⅡ／Ⅲの25マス盤面 UX を壊さない** — キーワード／PREP／60秒スピーチ／トロフィーの既存挙動は維持。拡充度は集計レイヤを足す。
2. **システム3セットのセル定義は既存プリセットを使う** — `ThinkingMatrixPresets` を再発明しない。
3. **l10n** — `gradus_l10n.dart` / `app_strings.dart`。ja / en / vi。
4. **後方互換** — 既存ユーザーセットは残す。システムIDの3枚を足す／補完するだけ。
5. **スコープ外を触らない** — その Step 以外のリファクタ・ドキュメント追加はしない（最終レビュー Step 除く）。
6. **完了報告** — 変更ファイル・手動確認・次 Step 前提を短く報告。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| プリセット | `lib/data/thinking_matrix_presets.dart` |
| セット／セル | `lib/models/thinking_matrix_set.dart`, `thinking_matrix_cell.dart` |
| サービス | `lib/services/thinking_matrix_service.dart` |
| UI | `lib/views/layers/thinking_matrix_screen.dart`, `lib/widgets/thinking_matrix_cell_sheet.dart` |
| ダッシュボードモデル | `lib/models/dashboard_summary.dart` |
| ダッシュボード集計 | `lib/services/dashboard_summary_service.dart` |
| ダッシュボード UI | `lib/views/dashboard/dashboard_screen.dart` |
| トランスクリプト | `lib/views/export/transcript_screen.dart` |
| アドバイス AI | `lib/data/dashboard_ai_prompt_template.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart`, `lib/localization/gradus_l10n.dart` |
| テスト | `test/thinking_matrix_*.dart`, `test/dashboard_*.dart` |

---

## Step 1 — システム3セットの自動シード

### 目的
日常／ビジネス／シチュエーションのブランク回答シートを最初から用意する。

### 指示

1. **安定 ID**（例）を決める:
   - `tm_system_daily`
   - `tm_system_business`
   - `tm_system_situational`
2. **`ThinkingMatrixService.ensureSystemPresets()`**（名称は既存スタイルに合わせて可）を追加:
   - `loadAll` して上記 ID が無ければ `createFromPreset` 相当で空セル付きセットを作成
   - タイトルは l10n しやすい固定（例: カテゴリ名そのもの／「日常（標準）」等）。既存の自動採番「セットN」と衝突しないこと
   - **既にある場合は中身を消さない**（ユーザーが進めた進捗を守る）
   - カテゴリ・列・テーマがプリセットと食い違っている破損データだけ、必要最小限で修復（迷ったら「IDが無ければ作る」だけに留め、修復はしない）
3. **呼び出しタイミング:**
   - `loadAll` の先頭、またはレイヤーⅡ／Ⅲの25マス画面 `initState`、およびダッシュボード読込前
   - 二重作成しないよう冪等にする
4. **削除ポリシー（どれか1つを実装しコメントで明記）:**
   - **推奨:** システムセットはスワイプ削除不可（または削除確認で「進捗の母数に使っています」と警告し、削除後は次回 `ensure` で空セットを再生成）
   - 再生成時は**空の新規**（削除前の進捗は戻さない）
5. 「オリジナル」や追加の日常セットは従来どおり作成可。拡充度計算（Step 2）ではシステムIDのみ使う。

### 受け入れ
- クリーンな prefs で25マスを開くと、日常・ビジネス・シチュエーションが最初から一覧にある（合計65マス分）
- 2回目の起動で増殖しない
- 既存のユーザー作成セットが消えない
- `flutter analyze` / サービステストが通る

---

## Step 2 — 拡充度の計算ロジック（単体）

### 目的
65マス母数の進捗％と拡充度総合を純関数で計算できるようにする。

### 前提
Step 1 のシステムIDが決まっていること

### 指示

1. **新規** `lib/services/thinking_matrix_expansion_service.dart`（または `lib/models/thinking_matrix_expansion.dart` + サービス）:

```dart
class ThinkingMatrixExpansionSummary {
  final double dailyPercent;        // 0–100
  final double businessPercent;
  final double situationalPercent;
  final double totalPercent;
  final DashboardOverallGrade expansionGrade; // 拡充度総合 A–E
  // 内訳デバッグ用に weightSum / cellCount を持っても可
}
```

2. **1マスのウェイト:**

```dart
static double cellWeight(ThinkingMatrixSet set, ThinkingMatrixCell cell) {
  if (set.isCellSpeech60Done(cell)) return 1.0;
  if (set.isCellPrepComplete(cell)) return 2 / 3;
  if (cell.keyword.trim().isNotEmpty) return 1 / 3;
  return 0.0;
}
```

3. **入力:** システム3セット（欠けているカテゴリは％=0、母数にはそのカテゴリの規定マス数を使う＝ensure 後なら常に揃う）
4. **拡充度総合:** Step 概要 D の閾値
5. **表示ヘルパー:** `toStringAsFixed(1) + '%'`（ロケールは既存アプリ方針に合わせる）
6. **単体テスト**（必須ケース）:
   - 全空 → 各0.0%、トータル0.0%、グレード E
   - 日常の1マスだけキーワード → 日常 = `(1/3)/25*100` ≈ `1.3%`、トータル = `(1/3)/65*100` ≈ `0.5%`、グレード D
   - 1マス PREP 完了 → ウェイト 2/3
   - 1マス speech 完了 → ウェイト 1.0
   - トータル 25% ちょうど → C、50% → B、75% → A
   - システム外セットを渡しても無視（または API がシステムだけ受け取る）

### 受け入れ
- 計算がテストで固定される
- UI はまだ変えなくてよい
- `flutter analyze` が通る

---

## Step 3 — ダッシュボードモデル：テスト総合／拡充度総合／総合

### 目的
`DashboardSummary` を3段判定に拡張する。

### 前提
Step 2 の `ThinkingMatrixExpansionSummary` があること

### 指示

1. **`DashboardSummary` を拡張:**

```dart
final DashboardOverallGrade overallGrade;       // 新・総合（テスト×拡充）
final DashboardOverallGrade testGrade;          // 旧 overall＝テスト総合
final DashboardOverallGrade expansionGrade;     // 拡充度総合
final double? testAveragePoints;                // 旧 averagePoints（5指標平均）
final ThinkingMatrixExpansionSummary? expansion; // ％内訳（ensure前は空でも可）
```

- 後方互換: 既存の `overallGrade` / `averagePoints` ゲッターをどう移行するか決めて**テストを全部直す**
  - **推奨:** `overallGrade` = 新・総合、`testGrade` = 旧ロジック、`averagePoints` はテスト平均のまま（または `testAveragePoints` にリネームし参照更新）

2. **`DashboardSummaryService.build`:**
   - 引数に `List<ThinkingMatrixSet> thinkingMatrixSets`（または既に ensure 済みの expansion summary）を追加
   - `testGrade` = 現行5指標ロジック
   - `expansionGrade` / ％ = Step 2
   - `overallGrade` = `points(test)+points(expansion)` の表（概要 F）
   - テスト総合が E（データ不足）でも、拡充が進めば総合は 0+拡充ポイントになり得る（例: テストE=0、拡充A=4 → sum=4 → 総合C）。**ユーザー定義どおり機械的に足す**

3. **表示:**
   - 総合／テスト総合／拡充度総合は基本 **文字のみ**（`B`）。テスト平均の `B（3.7）` 形式を残すなら「テスト総合」行だけに限定し、総合・拡充度総合は文字のみ（ユーザー例に合わせる）

4. 既存 `dashboard_summary_service_test.dart` を全面更新。

### 受け入れ
- 新総合の表がテストで正しい
- 旧「平均だけで総合」前提のテストが新仕様に更新されている
- `flutter analyze` が通る

---

## Step 4 — ダッシュボード UI ＋ トランスクリプト

### 目的
画面上の判定ブロックをユーザー指定レイアウトに合わせる。

### 前提
Step 3 完了

### 指示

1. **`dashboard_screen.dart`「判定」カード:**

```
総合
テスト総合
拡充度総合
────
（既存）語彙 / 的中度 / PREP / JSST / 発音
────
25マス拡充度
  日常　　　xx.x%
  ビジネス　xx.x%
  シチュエーション　xx.x%
  トータル　xx.x%
```

- セクション見出し用 l10n: `テスト結果`（既存指標のまとまり）、`25マス拡充度`、`テスト総合`、`拡充度総合`
- 「総合」キーは既存を流用し、意味が「新・総合」になることをヘルプで補足（Step 6）
- レイアウトは既存の判定行ウィジェットを再利用し、詰め込みすぎない

2. **読込時**に `ThinkingMatrixService.ensureSystemPresets()` → expansion を `build` に渡す

3. **`transcript_screen.dart`**
   - ヘッダーの総合を新・総合に合わせる
   - テスト総合・拡充度総合・25マス％を、紙面が破綻しない範囲で追記（最低: 総合＋テスト総合＋拡充度総合＋トータル％）

4. **`dashboard_ai_prompt_template.dart`**
   - アドバイス依頼に拡充度（カテゴリ％・拡充度総合・新総合）を短く含める
   - 長文化しすぎない

5. UI テスト更新（`dashboard_screen_test.dart` 等）

### 受け入れ
- 判定に3行（総合／テスト総合／拡充度総合）が見える
- 25マス％が小数第1位で見える
- 紙飛行機アドバイスに拡充情報が載る（プロンプト文字列のテストで確認可）
- `flutter analyze` が通る

---

## Step 5 — 25マス一覧での進捗表示整合（任意だが推奨）

### 目的
一覧の「達成率」がキーワード埋まり率だけのままだと、ダッシュボード拡充度と感覚がずれる。システムセットに限り表示を寄せる。

### 前提
Step 2 完了

### 指示

1. システム3セットの一覧タイル:
   - 表示を **拡充度％（小数第1位）** に変更する、または  
   - 併記: `キーワード達成率` と `拡充度` のどちらか一方に統一（ダッシュボードと同じ拡充度％を推奨）
2. オリジナル／追加セットは従来の `completionRatio`（キーワード）のままでよい
3. 盤面セルの色・トロフィー（cellStage 1–5）は**変更しない**（練習 UX）

### 受け入れ
- システムセットの一覧％がダッシュボードのカテゴリ％と一致する
- `flutter analyze` / 関連テストが通る

---

## Step 6 — l10n・ヘルプ

### 目的
判定の意味変更をヘルプ／使い方に反映する。

### 指示

1. **新キー（ja/en/vi）例:**
   - `テスト総合` / `拡充度総合` / `25マス拡充度` / `テスト結果`
   - `ダッシュボード_拡充度_日常` 等はカテゴリ既存キー流用可
   - `長文読解_*` は触らない

2. **`help.gradus.dashboard.tip*`** を更新:
   - 総合 = テスト総合＋拡充度総合
   - テスト総合 = 5指標（欠けるとE）
   - 拡充度総合 = 65マスのトータル％帯
   - 25マスは最初から3シートあること
   - 1マスの キーワード→PREP→スピーチ の進み方

3. **`help.gradus.layer2.tip6` / `layer3.tip5`**
   - 標準シートが最初からあること、ダッシュボード拡充度に反映されることを1行追加

4. **`help.gradus.transcript.tip*`** — 総合の定義変更を反映

5. `help_l10n_test` / `l10n_parity_test` を更新

### 受け入れ
- ヘルプが新判定と矛盾しない
- 3言語キー欠落なし

---

## Step 7 — テスト総仕上げ

### 指示

1. `thinking_matrix_service_test` — ensure の冪等・削除／再生成ポリシー
2. expansion 計算テスト（Step 2）のエッジケース追加
3. `dashboard_summary_service_test` — 総合表の全帯（0,1–2,3–4,5–6,7–8）
4. `dashboard_screen_test` — 3段判定＋％表示
5. レイヤーⅡ／Ⅲの25マス既存テストが緑のまま

### 受け入れ
- 関連 `flutter test` が通る
- `flutter analyze` が通る

---

## Step 8 — エキスパートレビューと修正（①〜⑤）

### 観点

#### ① 重複
- 一覧の達成率とダッシュボード拡充度が二重定義・食い違いしていないか
- 「総合」の旧意味（5指標平均）が画面・トランスクリプト・AIプロンプト・ヘルプのどこかに残っていないか
- ユーザー追加の同カテゴリセットが拡充度に誤混入していないか

#### ② ゾンビ
- 旧 `overallGradeDisplay`（`B（3.7）`）が「総合」行に残って意味不明になっていないか
- 使われない l10n・コメント・テスト名

#### ③ 冗長動線
- ensure の多重呼び出しで保存が暴れていないか
- システムセット作成のために余計な画面遷移を強いていないか（バックグラウンドで足りる）

#### ④ ヘルプ整合
- tip と実 UI の行ラベル一致
- 「E＝データ不足」がテスト総合だけの話だと分かるか

#### ⑤ ＋長押し／ダブルタップ
- 25マス一覧の＋（カテゴリ作成）使い方に「標準3シートは最初からある」と書く
- ダッシュボードに新規ボタンを足した場合はヒント漏れがないか（基本は表示のみなので不要なら「該当なし」とレビュー表に書く）

### 指示
1. `mondaibun-layer1-v-ux-review.md` 同型の表で判定を書く
2. 要修正だけ直す
3. 結果を `docs/prompts/thinking-matrix-expansion-dashboard-review.md` に残してよい

### 受け入れ
- 致命的な重複・ゾンビ・ヘルプ矛盾が無い
- テスト緑

---

## スコープ外（今回やらない）

| 項目 | 理由 |
|------|------|
| オリジナルセットを母数65に含める | ユーザー指定は 25+25+15 |
| スピーチをレイヤーⅣ録音に置き換え | 現行はⅢの60秒セルフタイマー。別改修 |
| セル段階の色／トロフィー仕様変更 | 拡充度は集計のみ |
| 長文語彙テスト本体 | `long-article-vocab-test.md` |
| 5指標の閾値変更 | テスト総合は現行維持 |

---

## Step 依存関係

```
Step 1 システム3セットシード
  → Step 2 拡充度計算
    → Step 3 DashboardSummary 3段化
      → Step 4 UI / トランスクリプト / AIプロンプト
      → Step 5 一覧％整合（推奨）
        → Step 6 l10n / ヘルプ
          → Step 7 テスト
            → Step 8 レビュー修正
```

---

## 使い方（ユーザー → Claude Code）

```
docs/prompts/thinking-matrix-expansion-dashboard.md の Step 1 をやって
```

長文語彙テストと並行する場合の推奨順:

1. `long-article-vocab-test.md` Step 1〜6（ダッシュボード以外）
2. 本ファイル Step 1〜4（判定の器を先に作る）
3. `long-article-vocab-test.md` Step 7（語彙をテスト結果へ）
4. 本ファイル Step 5〜8、および長文 Step 8〜10

---

## 設計メモ（現状との差分）

| 現状 | 本改修 |
|------|--------|
| 25マスはユーザーが＋で作成 | 日常/ビジネス/シチュを**自動シード** |
| 進捗はセット単位のキーワード％ | **65マス・3段階ウェイト**の拡充度 |
| ダッシュボード総合＝5指標平均のみ | **テスト総合**＋**拡充度総合**→**総合** |
| マトリクスはダッシュボード非関与 | 拡充度ブロックとして表示 |
| E＝5指標欠け | **テスト総合のE**は従来どおり。総合Eは sum=0 のみ |
