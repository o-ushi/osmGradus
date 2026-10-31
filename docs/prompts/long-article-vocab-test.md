# レイヤーⅠ 長文読解 — 語彙力テスト（9語）＋一覧正解率＋ダッシュボード連携

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/long-article-vocab-test.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

**前提（実装済み）:** `docs/prompts/long-article-comprehension-check.md` の 1秒チェック（2択）は実装済み。本ドキュメントはその上に語彙力テストを載せる。

---

## 機能概要（ユーザーの狙い）

```
Chrome AI（1往復）
  → 長文 body
  → 1秒チェック（既存）
  → 語彙テスト用単語 9語（読み・英訳・越訳・例文・例文の英/越訳）

読解画面 →「→」
  → 1秒チェック（既存・無ければスキップ）
  → 語彙力テスト（9問）
  → 3択モード選択へ戻る

長文一覧の各行
  → 「正解率=90%」または「正解率=ー」
     **母数はクイズ1問＋単語テスト最大9問＝最大10問**
     （例: クイズ正解＋単語8/9 → 9/10 = 90%）
  → 正解率タップ → 語彙力評価結果（単語に加え **1秒チェックの結果も表示**）

ダッシュボードのレイヤーⅠ語彙判定に、この語彙テスト結果を含める
```

**問題文解析との差分（意図的）:**

| 項目 | 問題文解析 | 長文読解（本改修） |
|------|------------|-------------------|
| 単語数 | 最大5 | **9固定（取れなければ9未満可、0は避ける）** |
| 訳語 | アプリ言語に応じて en **または** vi の一方 | **en と vi を両方**常に持つ |
| 抽出タイミング | 詳細画面で別途「問題作成」 | **長文生成と同梱（追加 AI 往復なし）** |
| 動線 | 詳細 → 語彙テスト | 読解 → 1秒チェック → 語彙テスト |

---

## 共通ルール（全 Step 共通・必ず守る）

1. **フェーズマシン設計を維持** — `Layer1LongReadingScreen`（`long_article_flow_screen.dart`）にフェーズを追加する。Navigator で語彙テストを「別スタックの別世界」にしない（`Layer1VocabScreen.push` を使う場合は、完了後にフロー本体へ確実に戻ること）。
2. **既存の1秒チェックを壊さない** — `comprehensionCheck` フェーズは残す。語彙テストはその**後**。
3. **`Layer1VocabScreen` を再利用** — 語彙テスト UI・STT・Chrome AI 採点は新規実装しない。問題文解析の `gradedPrompt` 経路を長文向けに拡張する。
4. **l10n** — ユーザー向け文言は `gradus_l10n.dart` / `app_strings.dart`。ja / en / vi を揃える。
5. **後方互換** — 旧 `LongArticle`（`vocabTestWords` 無し）は語彙テストをスキップ。旧 AI JSON（body + comprehensionCheck のみ）も落とさない。
6. **スコープ外を触らない** — その Step の受け入れ以外のリファクタ・ドキュメント追加はしない（最終 Step のレビュー修正は除く）。
7. **完了報告** — 変更ファイル一覧・手動確認手順・次 Step への前提を短く報告する。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| フロー本体 | `lib/views/layers/long_article_flow_screen.dart` |
| AI プロンプト | `lib/data/long_article_ai_prompt.dart` |
| パーサー | `lib/services/long_article_response_parser.dart` |
| 生成結果 | `lib/models/long_article_generation_result.dart` |
| 長文モデル | `lib/models/long_article.dart` |
| 長文サービス | `lib/services/long_article_service.dart` |
| 一覧 | `lib/views/layers/long_article_list_screen.dart` |
| 1秒チェック | `lib/views/layers/long_article_comprehension_check_screen.dart` |
| 語彙テスト（再利用） | `lib/views/layers/layer1_vocab_screen.dart` |
| 問題文の抽出語モデル（参考） | `lib/models/question_prompt_vocab_word.dart` |
| 問題文抽出プロンプト（参考） | `lib/data/question_prompt_vocab_extraction_ai_prompt_template.dart` |
| 語彙結果詳細（再利用） | `lib/views/layers/vocabulary_check_detail_screen.dart` |
| 語彙結果保存 | `lib/models/saved_vocabulary_check.dart` / `lib/services/vocabulary_check_storage.dart` |
| ダッシュボード | `lib/services/dashboard_summary_service.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart` / `lib/localization/gradus_l10n.dart` |
| 読解操作バー | `lib/widgets/long_article_action_row.dart` |

---

## Step 1 — データモデル：9語スナップショット＋正解率フィールド

### 目的
長文に「語彙テスト用9語」と「実施後の正解率」を持てるようにする。

### 指示

1. **新規** `lib/models/long_article_vocab_word.dart`（名前は既存スタイルに合わせて可）:

```dart
class LongArticleVocabWord {
  final String word;
  final String reading;
  final String pos;       // 任意
  final String jlpt;      // 任意
  final String meaningEn;
  final String meaningVi;
  final String example;                 // 日本語例文
  final String exampleTranslationEn;    // 任意だが生成時は推奨
  final String exampleTranslationVi;    // 任意だが生成時は推奨
}
```

- `fromJson` / `toJson` を既存 `QuestionPromptVocabWord` と同型で実装
- **問題文側と違い、en/vi を両方持つ**（アプリ言語切替後も再生成不要）
- ヘルパー推奨: `String meaningFor(String appLanguage)` / `String exampleTranslationFor(String appLanguage)`  
  （`appLanguage == 'en'` → En、それ以外 → Vi。`LongArticleVocabTranslationPrompt.translationLangFor` と同じ判定）

2. **`lib/models/long_article.dart`** に追加:

```dart
final List<LongArticleVocabWord> vocabTestWords; // 既定 []
final int? vocabTestCorrectCount;               // 未実施 null
final int? vocabTestQuestionCount;              // 未実施 null
final String? lastVocabularyCheckId;            // 直近の SavedVocabularyCheck.id（詳細画面用）
```

- getter `double? get vocabTestAccuracy`（問題文の `QuestionPrompt.vocabTestAccuracy` と同型）
- getter `bool get hasVocabTestResult => vocabTestQuestionCount != null && vocabTestQuestionCount! > 0`
- **Step 11:** 一覧の正解率分母は「1秒チェック（あれば1）＋単語テスト出題数」。Step 1 時点ではフィールドだけ用意し、合成は Step 11 で行う
- `fromJson` / `toJson` / `copyWith`（clear フラグが必要なら問題文に倣う）を更新
- 旧 JSON にキーが無くても落ちない

3. **`lib/models/long_article_generation_result.dart`** に  
   `final List<LongArticleVocabWord> vocabTestWords`（既定空）を追加。

4. 単体テスト: `LongArticle.fromJson` の後方互換、`vocabTestAccuracy` の計算。

### 受け入れ
- 旧長文 JSON を読んでも落ちない（語彙フィールドは空/null）
- en/vi 両方を持つモデルがコンパイル・テストできる
- `flutter analyze` が通る

---

## Step 2 — AI プロンプト＋パーサー：生成時に9語を同梱

### 目的
Chrome AI の長文生成1往復で、本文・1秒チェック・語彙9語をまとめて取得する。

### 前提
Step 1 完了

### 指示

1. **`lib/data/long_article_ai_prompt.dart`** の `buildPrompt` を拡張。  
   既存の comprehensionCheck 指示は残し、語彙抽出を追加する。

**出力 JSON 形（目標）:**

```json
{
  "body": "（本文）",
  "comprehensionCheck": { "...既存と同じ..." },
  "vocabTestWords": [
    {
      "word": "表記",
      "reading": "かな",
      "pos": "品詞",
      "jlpt": "N2",
      "meaningEn": "English gloss",
      "meaningVi": "nghĩa tiếng Việt",
      "example": "日本語の例文",
      "exampleTranslationEn": "English example translation",
      "exampleTranslationVi": "Bản dịch ví dụ tiếng Việt"
    }
  ]
}
```

**プロンプト制約（問題文抽出テンプレートを参考に長文向けへ）:**

- 本文中の、学習者が文脈理解でつまずきやすい語を **最大9語**（`maxWords = 9`）
- 除外: 代名詞・助詞・初級基本語・オノマトペ等（問題文抽出と同じ精神）
- **必ず en と vi の両方**の短い訳と、可能なら例文訳も両方
- 語彙暗記クイズ用であり、1秒チェック（文脈2択）とは役割を分ける
- 9語取れない短文では未満可。0件は避ける

2. **`lib/services/long_article_response_parser.dart`**
   - `parseResult` が `vocabTestWords` を読む
   - 不正・欠落ワードはスキップ。配列が空／無しでも `body` は返す
   - `meaningEn`/`meaningVi` が両方空の語は採用しない
   - 上限9語で truncate

3. **テスト** `test/long_article_response_parser_test.dart` を拡張:
   - 新 JSON（body + check + 9語）正常系
   - 旧形式（body のみ / body+check のみ）後方互換
   - 壊れた語はスキップ、本文は残る
   - 10語来たら9語に切る

### 受け入れ
- 新 JSON から9語が取れる
- 旧 JSON でも生成フローが壊れない
- `flutter analyze` / パーサーテストが通る

---

## Step 3 — 生成画面・フロー配線（まだ語彙テスト UI は入れない）

### 目的
生成結果の9語をフロー状態と保存経路まで運ぶ。

### 前提
Step 2 完了

### 指示

1. **`long_article_generate_screen.dart`** — 既に `LongArticleGenerationResult` を渡しているなら、パーサーが埋めた `vocabTestWords` がそのまま流れることを確認。不足があれば修正。

2. **`long_article_flow_screen.dart`**
   - `_vocabTestWords`（`List<LongArticleVocabWord>`）を保持
   - `_onArticleGenerated` でセット
   - `initialArticle` 開始時は `widget.initialArticle!.vocabTestWords` をセット

3. **`LongArticleService.addArticle` / `updateArticle`（必要なら）**  
   - `vocabTestWords` を永続化できる引数を追加
   - `_finish()` で保存するときに渡す（この Step ではまだ語彙テスト未実施なので counts は null）

4. **バックアップ** — `toJson` 経由で含まれることを確認（専用変更は最小限）。

### 受け入れ
- 新規生成→保存した長文に `vocabTestWords` が入る（AIが返した場合）
- 旧長文は空配列のまま
- `flutter analyze` が通る

---

## Step 4 — 動線：1秒チェックの次に語彙力テスト（9問）

### 目的
ユーザー指定の動線を実装する。

```
読解 →（1秒チェック）→ 語彙力テスト → 終了（保存/3択復帰）
```

### 前提
Step 3 完了

### 指示

1. **フェーズ追加**（例）:

```dart
enum _LongReadingPhase {
  keyword, generate, reading, comprehensionCheck, vocabTest,
}
```

2. **遷移ルール:**

| 現在 | 次 |
|------|-----|
| reading で「→」、check あり | comprehensionCheck |
| reading で「→」、check なし、語彙あり | vocabTest |
| reading で「→」、どちらもなし | `_finish()` |
| comprehensionCheck 完了、語彙あり | vocabTest |
| comprehensionCheck 完了、語彙なし | `_finish()` |
| vocabTest 完了 | `_finish()` |

3. **語彙テストの起動** — `Layer1VocabScreen` を再利用:

- `fixedEntries`: `_vocabTestWords` から `VocabularyEntry` に変換（最大9）
  - `translation` = `meaningFor(appSettings.language)`
  - `exampleSentence` = `example`
  - `reading` = `reading`
- 既存の `gradedPrompt` に相当する **`gradedLongArticle`（または同等のコールバック／ID）** を追加し、採点後に:
  - `LongArticle.vocabTestCorrectCount` / `vocabTestQuestionCount` を更新
  - 不正解語を `VocabularyService` へ自動登録（問題文経路 `_gradeQuestionPrompt` と同型。訳はアプリ言語側を使う）
  - `SavedVocabularyCheck` を保存し、`lastVocabularyCheckId` を長文へ書く

4. **保存タイミング（重要）:**
   - **新規フロー:** 語彙テスト開始前までに `addArticle` して ID を確定させる（採点の書き戻し先が必要なため）。すでに `_finish` で保存しているなら、保存を「語彙テスト開始時」または「クイズ完了時」に前倒しし、終了時はスコア更新＋3択復帰だけにする。
   - **`initialArticle`:** 再保存せず、採点で `update` のみ。
   - 二重保存・二重 SnackBar「長文を保存しました」を出さないこと。

5. **語彙0件の旧データ**は語彙フェーズをスキップ（受け入れ済みの後方互換）。

### 受け入れ
- 新規生成（モックJSONに9語）: 読解→1秒チェック→9問語彙→3択
- 語彙なし旧データ: 読解→（チェック）→即終了
- 問題文解析の語彙テスト経路が壊れていない
- `flutter analyze` が通る

---

## Step 5 — `Layer1VocabScreen` / `SavedVocabularyCheck` の長文対応

### 目的
採点・履歴・ダッシュボード連携の基盤を問題文経路と対称にする。

### 前提
Step 4 の動線が動くこと（この Step で採点書き戻しを完成させてもよい。Step 4 と分割しづらい場合は Step 4 で骨組み、ここで完成）。

### 指示

1. **`SavedVocabularyCheck`** に追加:
   - `String? longArticleId`
   - `String? longArticleTitle`（または body 冒頭。詳細表示用のスナップショット）
   - `fromSession` / `fromJson` / `toJson` 更新
   - バッジ表示: 問題文と同様、長文由来なら識別ラベル（新 l10n キー）

2. **`VocabularyCheckDetailScreen`**
   - `longArticleId != null` のとき、問題文カード相当で長文タイトル／本文抜粋を表示
   - 既存の問題文表示を壊さない

3. **`Layer1VocabScreen`**
   - `gradedLongArticle`（`LongArticle?`）または `onLongArticleGraded` を追加
   - `_gradeQuestionPrompt` と並列の `_gradeLongArticle` を実装
   - `sourcePromptId` に相当する `longArticleId` を `SavedVocabularyCheck` へ渡す
   - `fixedEntries != null` のときは従来どおりプール抽選・レベルUIを出さない

4. **正解数の定義**は問題文経路と同じ（`VocabularyEvaluation` の各問正誤、または既存 `_gradeQuestionPrompt` が使っている基準をそのまま踏襲）。勝手に別基準を作らない。

### 受け入れ
- 長文語彙テスト完了後、`LongArticle` に counts が入る
- `SavedVocabularyCheck` に `longArticleId` が付き、履歴詳細で長文由来と分かる
- 通常の10問語彙テスト・問題文語彙テストが回帰しない
- `flutter analyze` が通る

---

## Step 6 — 長文一覧に正解率表示＋タップで結果詳細

### 目的
一覧の各項目に `正解率=90%` / `正解率=ー` を出し、タップで詳細へ。

### 前提
Step 5 完了（counts / lastVocabularyCheckId が入る）

### 指示

1. **`long_article_list_screen.dart` のリストタイル**を拡張:
   - タイトル／本文プレビューの近くに  
     `正解率={n}%` または `正解率=ー`  
     （l10n: 例 `長文読解_正解率` + `長文読解_正解率_なし`、または `trFmt`）
   - **正解率テキストだけ**がタップ可能（行全体の「開く」と競合しないこと）
     - selectionMode 中は正解率タップを無効 or 行選択を優先（既存 UX を壊さない）

2. **正解率タップ時:**
   - `lastVocabularyCheckId` があれば `VocabularyCheckStorage` 等からロードし `VocabularyCheckDetailScreen` を push
   - ID が欠落していても counts だけある場合は、最低限 counts＋`vocabTestWords` を見せる簡易詳細でも可（新規画面は最小限。可能なら既存詳細の再利用を優先）
   - 結果が無い（`ー`）ときはタップしても何もしない／SnackBar 程度

3. **一覧から長文を開く経路の修正（冗長・抜けの解消）:**
   - 現状: `_openArticle` が `LongArticleReaderScreen` だけを開き、1秒チェック／語彙テストを**スキップ**している（ゾンビ動線）
   - **修正:** 非 selectionMode の閲覧も、読解→チェック→語彙の一連に載せる  
     （`Layer1LongReadingScreen(initialArticle:)` を使うか、同等のフェーズ起動に統一）
   - selectionMode（「一覧から選ぶ」で返すだけ）は現状維持

### 受け入れ
- 未実施: `正解率=ー`
- 単語のみの暫定表示（Step 11 前）: 9問中8問正解など `正解率=89%`（問題文総評の％表示に合わせる）
- **Step 11 後:** クイズありなら母数は `1 + 単語出題数`（典型 10）。クイズ正解＋単語8/9 → `正解率=90%`
- 正解率タップで詳細が見える
- 一覧から開いてもクイズ→語彙が走る
- `flutter analyze` / 一覧テスト更新が通る

---

## Step 7 — ダッシュボード Layer I 判定への組み込み

### 目的
長文の語彙テスト結果を、ダッシュボードの語彙スコアに含める。

### 前提
Step 5 で `SavedVocabularyCheck` が長文経路でも保存されること

### 注意（25マス拡充度改修との境界）
ダッシュボードの「総合／テスト総合／拡充度総合」の3段化・25マス％表示は  
`docs/prompts/thinking-matrix-expansion-dashboard.md` が正本。  
**本 Step では語彙サンプルへの混入だけ行い、総合の計算式や判定カードの構造は変えない。**  
両方進める場合は、拡充度側のダッシュボード Step を本 Step の前後どちらにするか、拡充度ドキュメントの「並行改修」節に従う。

### 指示

1. **`DashboardSummaryService`**
   - 現状: 直近 ≤3 件の `SavedVocabularyCheck.evaluation.overallScore` を平均
   - 長文由来の `SavedVocabularyCheck` も**同じリストに既に入る**なら、追加フィルタは不要（保存されていれば自然に含まれる）
   - 「問題文だけ／プールだけ」に絞るコードが無いか確認。あれば長文も許可する

2. **ヘルプ文言** `help.gradus.dashboard.tip4`  
   現状: 「語彙の点数はレイヤーⅠの単語テスト結果のみ（長文で単語帳に登録した語は含まない）」  
   → **維持で正しい**（単語帳へのタップ登録は今も除外。語彙**テスト**結果は含む）。  
   必要なら「長文読解の語彙テスト結果も含む。読解中の単語帳登録だけでは点数に入らない」と明確化（ja/en/vi）。

3. ダッシュボード／AI プロンプト（`dashboard_ai_prompt_template.dart`）で長文由来チェックも要約に載ることを確認。バッジや見出しが問題文専用なら長文も識別。

### 受け入れ
- 長文語彙テストを実施すると、ダッシュボード語彙サンプルに入りうる
- 読解中のタップ登録だけでは点数に入らない（従来どおり）
- `flutter analyze` が通る

---

## Step 8 — l10n・ヘルプ・ダブルタップヒント・＋長押し使い方

### 目的
文言と操作説明を新動線に合わせる（レビュー観点④⑤の先回り）。

### 前提
Step 4〜6 で UI キーがほぼ確定

### 指示

1. **`gradus_l10n.dart`（ja/en/vi）** に不足キーを追加。例:
   - `長文読解_正解率` / `長文読解_正解率_なし`（`正解率={0}%` / `正解率=ー`）
   - `長文読解_語彙_履歴バッジ`（詳細画面用）
   - 語彙テスト開始前の案内が必要なら最小限

2. **`help.gradus.layer1.tip3`** を更新（3言語）:
   - 生成時に語彙9語＋1秒チェックが付く
   - 読解後: 1秒チェック → 語彙テスト（9問）
   - 一覧に正解率、タップで詳細
   - 「訳を付ける」は**追加で気になった語**用（9語テストの代替ではない）と分かるようにする

3. **`help.gradus.dashboard.tip4`** — Step 7 の方針で更新

4. **ダブルタップヒント**
   - `LongArticleActionRow` の「次へ」: ヒントが単に「次へ」だけなら、読解後にチェック／語彙が続くことが分かる短文に更新（既存 `ButtonActionHint` の長さ感を守る）
   - 1秒チェック画面・語彙テスト画面で未配線の主要ボタンがあれば `hintTapText` を足す

5. **＋長押しの使い方シート**
   - 長文読解フロー本体に「＋」が無い場合:
     - 無理に＋を新設しない
     - 代わりに、読解画面の「単語帳」長押し or 既存のヘルプ tip で足りるか確認
     - **抜けがあれば**: 読解の操作バーに使い方を出せる長押し（例: 単語帳長押しで `LayerHelpSheet`）を最小追加。内容は  
       ①次へ（チェック→語彙）②訳を付ける③単語帳 の順で、問題文詳細の使い方シートに倣う
   - 問題文解析・標準語彙・Podcast の既存＋長押しは壊さない

6. `help_l10n_test` / `l10n_parity_test` があればキーを足す

### 受け入れ
- tip3 / dashboard.tip4 が新仕様と矛盾しない
- ダブルタップで主要操作の説明が足りる
- `flutter analyze` / l10n 系テストが通る

---

## Step 9 — テスト更新（E2E / 単体）

### 目的
新動線を自動テストで固定する。

### 前提
Step 1〜8 完了

### 指示

1. **`test/layers_test.dart`** の長文読解完走テストを更新:
   - モック AI JSON に `vocabTestWords`（少数で可、例3語でもパーサー上限テストと分ける）を含める
   - 「→」→ 1秒チェック回答 → 語彙テスト画面出現までを検証  
     （Chrome AI 採点までフルに回すのが重い場合は、語彙画面到達＋`fixedEntries` 件数まででも可。採点書き戻しは単体でカバー）

2. **パーサー / LongArticle / Service** テストを拡充

3. **一覧テスト** `test/long_article_list_screen_test.dart`:
   - 正解率表示（ー / ％）
   - 正解率タップで詳細（モックデータ）

4. **`Layer1VocabScreen` 長文グレード**のウィジェット or 単体テスト（問題文 `_gradeQuestionPrompt` テストがあるなら同型）

5. 後方互換: body のみ JSON で従来完走（チェックスキップ・語彙スキップ）

### 受け入れ
- 関連 `flutter test` が通る
- `flutter analyze` が通る

---

## Step 10 — エキスパートレビューと修正（①〜⑤）

### 目的
実装後のコードを、ユーザー指定の5観点でレビューし、**この Step で修正まで行う**。

### 前提
Step 1〜9 完了

### 観点と想定チェックリスト（実装を見て判定し、表にまとめてから直す）

#### ① ユーザーの狙いに反して重複している機能
想定の確認ポイント:
- 「訳を付ける」（タップ登録語の後付け翻訳）と「生成時9語」は**役割が違う**なら意図的残置。9語の再翻訳を強いる UI は削除／案内しない
- 標準「語彙テスト」（10問プール）と長文9問は出題ソースが違う → 統合しない（問題文と同様の意図的残置）
- 1秒チェックと語彙テストの問題が同趣旨で重複していないか（プロンプト上の役割分担が守られているか）

#### ② ゾンビ機能
- 一覧の「読解のみ」経路が残っていないか（Step 6 で潰せているか再確認）
- 未使用 l10n・到達不能画面・コメント参照切れ
- `comprehensionCheck` 完了で即 `_finish` し語彙を飛ばす旧分岐の残留

#### ③ 動線が冗長
- AI 往復が増えていないか（生成1回・採点1回が上限）
- 保存 SnackBar の二重表示
- 語彙テスト後に不要な確認ダイアログが挟まっていないか
- 一覧 → 選択 → もう一度一覧、のような無駄な往復

#### ④ ヘルプ文の整合性
- `layer1.tip3` / `dashboard.tip4` / 起動サブタイトル（長文に言及があれば）
- 使い方シートと実際のボタン構成

#### ⑤ ＋長押し／ダブルタップの抜け漏れ
- 読解バー: 訳付け（タップ／長押し）・単語帳・次へ
- 1秒チェックの選択肢・戻る
- 語彙テスト画面（長文経路）の主要ボタン
- 問題文／標準語彙側の既存ヒントが巻き込まれて壊れていないか

### 指示
1. 上記①〜⑤について、`mondaibun-layer1-v-ux-review.md` と同型の表で「判定（修正済／意図的残置／確認）」を書く
2. **修正が必要なものだけ**コードを直す
3. レビュー結果を同ファイル末尾、または `docs/prompts/long-article-vocab-test-review.md` に追記してよい（ユーザーがレビュー成果を追えるようにする）

### 受け入れ
- 致命的な重複・ゾンビ・冗長動線が残っていない（意図的残置は表で明示）
- ヘルプとヒントが新動線と一致
- `flutter analyze` / 関連テストが通る

---

## Step 11 — 正解率を「クイズ1＋単語最大9＝最大10問」に合成し、語彙力評価結果にクイズを載せる

### 目的
一覧の正解率と語彙力評価結果を、長文読解セッション全体（1秒チェック＋単語テスト）で一貫させる。

**前提:** Step 1〜10 実装済み。現状は単語テストだけを `vocabTestCorrectCount` / `vocabTestQuestionCount` に書いており、1秒チェックの回答はフロー内の一時状態で捨てている。

### 仕様

| 項目 | ルール |
|------|--------|
| 母数 | `（1秒チェックを実施したなら 1） + 単語テスト出題数` |
| 典型 | クイズ1＋単語9 ＝ **10** |
| 分子 | クイズ正解なら +1、＋単語テストの正解数 |
| クイズ無し（旧データ／スキップ） | 単語テストのみ（従来どおり） |
| 単語が9未満 | `1 + 実際の出題数`（無理に10にしない） |
| 単語テスト未実施 | 一覧は `正解率=ー`（クイズだけ終わっても出さない） |
| ダッシュボードの ★（`evaluation.overallScore`） | **単語テストの Chrome AI 評価のまま**（クイズを星に混ぜない） |

表示例:

- クイズ正解、単語 8/9 → 一覧 `正解率=90%`（9/10）
- クイズ不正解、単語 9/9 → `正解率=90%`（9/10）
- クイズ無し、単語 8/9 → `正解率=89%`（8/9）

### 指示

1. **1秒チェックの回答をフローが受け取る**
   - `LongArticleComprehensionCheckScreen.onComplete` を、選択結果を渡せる形に変える（例: `void Function({required String selectedOption, required bool isCorrect})`、または小さな結果クラス）
   - `Layer1LongReadingScreen` が `_comprehensionSelectedOption` / `_comprehensionIsCorrect` を保持
   - クイズ無しで語彙へ進む経路では null のまま

2. **クイズ結果のスナップショットを `SavedVocabularyCheck` に保存**（新規クラス可）

```dart
class SavedComprehensionQuizResult {
  final String question;
  final String optionA;
  final String optionB;
  final String correctOption;   // "A" / "B"
  final String selectedOption;
  final bool isCorrect;
  // 解説は表示言語分だけでよい（ja/en/vi の該当1行、または既存 explanation オブジェクト）
}
```

- `SavedVocabularyCheck` に `SavedComprehensionQuizResult? comprehensionQuiz` を追加
- `fromSession` / `fromJson` / `toJson` を更新（欠落は null＝後方互換）
- `Layer1VocabScreen` にクイズ結果を渡す（`gradedLongArticle` と一緒に）。`_pasteAndSaveResult` で `SavedVocabularyCheck` に載せる
- 問題文経路・通常10問プールには **付けない**

3. **長文への正解数書き戻し（`_gradeLongArticle`）**

```
vocabCorrect = evaluation.correctCount
vocabTotal   = session.questions.length
quizTotal    = comprehensionQuiz != null ? 1 : 0
quizCorrect  = comprehensionQuiz?.isCorrect == true ? 1 : 0

correctCount  = vocabCorrect + quizCorrect
questionCount = vocabTotal + quizTotal
```

- `LongArticleService.recordVocabTestResult` にこの合成値を渡す
- 一覧の `正解率=` は既存 getter `vocabTestAccuracy` のままで、分母が最大10になる

4. **`VocabularyCheckDetailScreen`（語彙力評価結果）**
   - `check.comprehensionQuiz != null` のとき、長文タイトルカードの下・「出題した単語」の上にクイズ結果カードを出す:
     - 見出し（例: `長文読解_1秒チェック_見出し` 再利用）
     - 問題文
     - 選択肢 A/B（正解／選択が分かる）
     - 正解 or 不正解
     - 解説1行
   - 長文由来のとき、評価カードの「正解数」は **合成**（例: 9/10）。`evaluation.correctCount` / `questions.length`（単語だけ）を出さない
     - 内訳が分かるなら「単語 8/9 ＋ クイズ 1/1」を小さく併記してよい
   - 問題文経路・通常語彙テストの表示は変えない

5. **l10n** — 新規文言があれば ja/en/vi。既存の1秒チェック／正解率キーを優先再利用。`help.gradus.layer1.tip3` に「正解率はクイズ＋単語の最大10問」を1句足す。

6. **テスト**
   - 合成: クイズ正解＋単語8/9 → counts 9/10、accuracy 0.9
   - クイズ不正解＋単語9/9 → 9/10
   - クイズ無し → 単語のみ
   - `SavedVocabularyCheck` の JSON 後方互換（comprehensionQuiz 無し）
   - 詳細画面: クイズカードが出る／通常語彙テストには出ない
   - 一覧の `正解率=90%` が 9/10 で出る

### 受け入れ
- 典型フローで一覧が最大10問母数の％になる
- 語彙力評価結果に1秒チェックの問題・選択・正誤・解説がある
- ダッシュボードの語彙★は従来どおり単語テストの AI 評価
- 問題文解析・標準語彙テストが回帰しない
- `flutter analyze` / 関連テストが通る

---

## スコープ外（今回やらない）

| 項目 | 理由 |
|------|------|
| 1秒チェック単独の％を一覧に出す | 一覧は合成10問の1本。内訳は詳細画面 |
| クイズ結果をダッシュボードの ★ に混ぜる | ★は Chrome AI の単語評価。％だけ合成 |
| 問題文解析の抽出数を5→9に変更 | 長文だけの仕様 |
| 旧長文への語彙9語の後付け再生成 | 別機能（追加 AI 往復） |
| 語彙テストの問題数を設定可能にする | 9固定 |
| レイヤーⅤ音読フローの変更 | 本改修はレイヤーⅠ |

---

## Step 依存関係

```
Step 1 モデル
  → Step 2 AI+パーサー
    → Step 3 生成/フロー配線
      → Step 4 動線（チェック→語彙）
        → Step 5 VocabScreen/SavedCheck 長文対応
          → Step 6 一覧正解率+詳細+一覧経路修正
          → Step 7 ダッシュボード
            → Step 8 l10n/ヘルプ/ヒント
              → Step 9 テスト
                → Step 10 レビュー修正
                  → Step 11 クイズ＋単語の合成正解率／詳細画面
```

Step 4 と Step 5 は密接なため、1セッションで続けて実施してよい。その場合も受け入れは両方満たすこと。  
Step 11 は Step 10 完了後に単独で実施する（既存の単語9問採点を壊さず合成する）。

---

## 使い方（ユーザー → Claude Code）

```
docs/prompts/long-article-vocab-test.md の Step 1 をやって
```

完了報告を確認してから Step 2 へ。レビューは必ず **Step 10** で実施する。

Step 1〜10 済みなら:

```
docs/prompts/long-article-vocab-test.md の Step 11 をやって
```

---

## 設計メモ

| 決定 | 理由 |
|------|------|
| 訳は en+vi 両方保存 | ユーザー指定。アプリ言語切替後も再生成不要 |
| 9語 | ユーザー指定（問題文は5のまま） |
| `Layer1VocabScreen` 再利用 | 採点・STT・履歴 UI の二重実装を避ける |
| ダッシュボードは `SavedVocabularyCheck` 経由 | 既存の語彙スコア集計を壊さず長文結果を混ぜられる |
| 一覧の％はクイズ＋単語 | Step 11: 母数は最大10（1秒チェック1＋単語最大9）。クイズ無しは単語のみ |
| 語彙力評価結果にクイズ | `SavedVocabularyCheck.comprehensionQuiz`。単語カードの上に1秒チェック結果 |
| ダッシュボード★は単語AIのまま | 合成するのは一覧・詳細の正解率だけ |
| 「訳を付ける」は残す | 読解中の任意登録用。生成9語の代替ではない |
