# カテゴリ名称＋25マス v2 — Claude Code 用ステップ別プロンプト

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/category-and-matrix-v2.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze` と、その Step で追加・更新したテストが通ることを確認してから次へ進んでください。

| 渡す言葉 | 中身 |
|---------|------|
| Step 1 | 問題文カテゴリの名称変更（日常／ビジネス、分野→カテゴリ） |
| Step 2 | 25マス テンプレート — データモデル・プリセット・単体テスト |
| Step 3 | 25マス テンプレート — 作成フロー UI（カテゴリ選択→盤面） |
| Step 4 | 25マスの見た目（テーマ表記・ゴールドは背景色のみ・トロフィー2つ） |
| Step 5 | 全体レビュー（重複・ゾンビ・冗長動線・表記揺れ・ヘルプ整合） |

`docs/prompts/layer2-thinking-matrix.md` は **初期実装の履歴**なので書き換えない。このファイルが v2 の正本。

---

## 0. プロダクト仕様（この改修で確定すること）

### A. 問題文カテゴリの表示名と永続化キー（リネームする）

表示だけ変えてキーを残さない。**storageKey・JSON キー・Dart プロパティも新名称に合わせ、旧値は読み込み時だけ変換する。**

| enum（Dart名は英語のまま） | 旧 storageKey | **新 storageKey** | 新表示 ja | en | vi |
|---------------------------|---------------|-------------------|-----------|----|----|
| `daily` | `daily` | `日常` | 日常 | Daily | Hàng ngày |
| `business` | `business` | `ビジネス` | ビジネス | Business | Công việc |
| `situational` | `situational` | `シチュエーション` | シチュエーション | Situations | Tình huống |
| `random` | `random` | `ランダム` | ランダム | Random | Ngẫu nhiên |

- `TopicCategoryLabel.labelKey()` と `storageKey` は **同じ日本語**（`日常` 等）でよい。
- `fromStorageKey` は新キーを正とし、旧英語キー（`daily` / `business` / `situational` / `random`）も読む。
- **`QuestionPrompt.field` → `category`。** JSON も `"field"` → `"category"`。旧 JSON の `field` は読む。書くときは `category` だけ。
- ユーザー向けの「問題文の分野」「分野」は **「問題文のカテゴリ」「カテゴリ」に統一**する。l10n のキー名も `'分野'` → `'カテゴリ'`、`'レイヤーⅡ_使い方_分野'` → `'レイヤーⅡ_使い方_カテゴリ'` のようにリネームする（値だけ変えて旧キーを残さない）。
- 発音の「5カテゴリ」（つ／ざ行／ラ行…）や待遇表現カテゴリは**別物**。触らない。`PronunciationCategory` の storageKey は変えない。

### B. カテゴリは問題文と同一（`TopicCategory` が単一ソース）

日常・ビジネス・シチュエーションは **問題文と同じ `TopicCategory`** を使う。表示名・l10n・storageKey を二重に持たない。`ThinkingMatrixCategory` のような別 enum は作らない。

| セットの category | 列（横軸＝視点） | 行（縦軸＝テーマ） | マス数 | 作成後 |
|-------------------|------------------|-------------------|--------|--------|
| `TopicCategory.daily` | 汎用5列 | 趣味・健康・買い物・旅行・季節 | 25 | すぐ盤面 |
| `TopicCategory.business` | 汎用5列 | 時間・チーム・成長・仕事・問題 | 25 | すぐ盤面 |
| `TopicCategory.situational` | 職場・学校・病院（3列） | 相談・依頼・断り・謝罪・提案 | **15** | すぐ盤面 |
| `null`（オリジナル） | 汎用5列 | ユーザーが自分で5つ入力 | 25 | 今の登録画面へ |

- 新規作成の選択肢は **日常 / ビジネス / シチュエーション / オリジナル**。先頭3つは問題文と全く同じラベル（`TopicCategoryLabel.labelKey()`）。
- **オリジナルは `TopicCategory` に足さない。** 問題文側に「オリジナル」が出ると困る。`random` と同じく「プリセットを持たない経路」で、enum の値にはしない。
- `ThinkingMatrixSet.category` の型は `TopicCategory?`。`daily` / `business` / `situational` のみ保存する。`random` は保存しない（JSON に来たらオリジナル扱い）。欠落・未知キーもオリジナル（`null`）。
- UI は問題文と同じ `CategorySelectSheet` の見た目を流用する（行コンポーネントを共有）。25マス用は `random` を出さず、4行目にオリジナルを足す。キャンセル（シートを閉じる）とオリジナル選択は区別する（キャンセルは `null` pop のまま、オリジナルは結果型で表す）。

汎用5列（日常・ビジネス・オリジナル＝`category == null` 共通）:

| id | ja | en | vi |
|----|----|----|-----|
| `time` | 時間 | Time | Thời gian |
| `view` | 視点 | View | Góc nhìn |
| `compare` | 比較 | Compare | So sánh |
| `scale` | 規模 | Scale | Quy mô |
| `reason` | 理由 | Reason | Lý do |

シチュエーション列:

| id | ja | en | vi |
|----|----|----|-----|
| `workplace` | 職場 | Work | Công ty |
| `school` | 学校 | School | Trường |
| `hospital` | 病院 | Hospital | Bệnh viện |

行（テーマ）の ja/en/vi は Gemini 案どおり（趣味/Hobby/Sở thích 等）。ビジネス行の「時間」が列の「時間」と同名なのは**仕様どおり。リネームしない**。

既存セット（JSON に category が無い）は **オリジナル** として読む。列は **新汎用5列へ載せ替える**（`stance`→`view`＝立場→視点、`change`→`reason`＝変化→理由。時間・比較・規模はそのまま）。セルのキーワードは columnId 変換後も残す。読み込み時に変換し、保存し直せば旧 id はディスクから消える。

### C. 見た目（Step 4）

- UI の「鉄板ネタ」→「テーマ」。横軸の総称は「視点」、縦軸の総称は「テーマ」。
- 「1分話した」ON のマスは **背景色（ゴールド）だけ**。チェックアイコンは出さない。
- 揃った行／列のトロフィー（`Icons.workspace_premium_rounded`）は、そのラインのマスが **すべて `spoken`** なら **2つ**、埋まっただけ（`filled` 混じり）なら **1つ**。

### やらないこと（全 Step 共通）

- 発音5カテゴリ（`PronunciationCategory`）の storageKey・ダッシュボード数値・新規パッケージ
- このプロンプトファイル自身の書き換え（誤字修正以外）
- `docs/prompts/layer2-thinking-matrix.md` の更新
- クラス名に `Topic` を新規追加しない（既存のお題と衝突する。`TopicCategory` は既存のまま使う）

---

## 共通ルール（全 Step 共通・必ず守る）

1. **既存モードを壊さない** — レイヤーⅡの他3モード、レイヤーⅢ〜Ⅴの予約席レイアウトは動かさない。
2. **l10n** — ユーザー向け文言は `gradus_l10n.dart`（キーは日本語ソース）経由。ja / en / vi を揃える。キー文字列を画面に出さない。
3. **永続化** — SharedPreferences。モデルにフィールドを足すときは `fromJson` で欠落を許容する（マイグレーション）。
4. **スコープ外を触らない** — その Step の受け入れ条件以外のリファクタ・ドキュメント追加はしない。
5. **完了報告** — Step 終了時に「変更ファイル一覧」「手動確認手順」「次 Step への前提」を短く報告する。
6. **テスト** — `flutter analyze` と関連テストを通す。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| 問題文カテゴリ enum | `lib/models/topic_category.dart` |
| カテゴリ選択 UI | `lib/widgets/category_select_field.dart` / `lib/views/topics/category_select_sheet.dart` |
| 一覧フィルタ | `lib/views/topics/question_prompt_filter_sheet.dart` |
| インポート見出し | `lib/services/topic_service.dart`（`TopicImportParser`） / `lib/views/topics/topic_import_screen.dart` |
| AI一括プロンプト | `lib/data/ai_prompt_template.dart` |
| l10n | `lib/localization/gradus_l10n.dart` / `app_strings.dart` |
| 25マス画面 | `lib/views/layers/layer2_thinking_matrix_screen.dart` |
| 25マスモデル | `lib/models/thinking_matrix_set.dart` 他 `thinking_*.dart` |
| 25マスサービス | `lib/services/thinking_matrix_service.dart` |
| セルシート | `lib/widgets/thinking_matrix_cell_sheet.dart` |
| 視点 enum（現行5列） | `lib/models/thinking_perspective.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart` / `gradus_l10n` の `help.gradus.layer2.*` |
| テスト | `test/layers_test.dart` / `test/question_prompt_layer*_test.dart` / `test/thinking_matrix_*.dart` |

---

## Step 1 — 問題文カテゴリの名称変更

### 目的
アプリ全体で、問題文のカテゴリ表示を「日常」「ビジネス」にし、「分野」ユーザー向け表記を「カテゴリ」に統一する。25マスの構造・見た目はまだ変えない。

### 指示

1. **表示名と storageKey**
   - `TopicCategoryLabel.labelKey()` と `storageKey` を `'日常'` / `'ビジネス'` / `'シチュエーション'` / `'ランダム'` にする（同じ文字列でよい）。
   - `fromStorageKey` は新キーに加え、旧 `daily` / `business` / `situational` / `random` を対応する enum へマップする。
   - prefs `topics.imported.daily` 等の旧キーを読んだら新キー（`topics.imported.日常`）へ移して旧キーを消す（`TopicService` / バックアップの明示キー列挙も追随）。
   - `gradus_l10n.dart` の ja/en/vi に新キーを足す。画面・インポート・AI プロンプトは新キーだけ。旧キー `'日常の身近な話題'` `'ビジネスシーン'` は参照ゼロなら削除。
   - en: Daily / Business。vi: Hàng ngày / Công việc。シチュエーション・ランダムの訳は既存を維持。

2. **「分野」→「カテゴリ」（ユーザー向けだけ）**
   - l10n キー `'分野'` を `'カテゴリ'` にリネーム（ja: カテゴリ、en: Category、vi: Danh mục）。呼び出しもすべて `'カテゴリ'.tr`。
   - 画面ラベル: `category_select_field.dart` / `question_prompt_filter_sheet.dart` など。
   - ヘルプ・使い方の **キー名も** リネームする:
     - `'レイヤーⅡ_使い方_分野'` → `'レイヤーⅡ_使い方_カテゴリ'`（Ⅲ・Ⅳ・ランダムも同様）
     - 値は「1️⃣ カテゴリを選択」（en/vi も Category / danh mục）
     - `'問題文一覧_使い方_フィルタ'` の本文「入手元・分野・実施状況」→「入手元・カテゴリ・実施状況」（3言語）
   - `CategorySelectSheet` 見出しキー `'お題のカテゴリ'` も `'問題文のカテゴリ'` に寄せてよい（値が既にそうならキーだけ合わせる）。
   - **`QuestionPrompt.field` → `category`**（プロパティ・コンストラクタ・copyWith・JSON・コメント・テスト）。`fromJson` は `category ?? field`。`toJson` は `category` のみ。assert 文面も「分野」→「カテゴリ」。
   - フィルタモデルやサービスで `field` と呼んでいる問題文カテゴリも `category` に揃える（発音カテゴリの `category` と衝突するファイルでは、問題文側を `promptCategory` にはせず、発音側の既存名を維持して問題文側を `category` にする。衝突したら局所的に接頭辞で区別し、コメントで理由を書く）。
   - **やらない**: 発音5カテゴリの storageKey。コメント内の「分野」は問題文カテゴリを指すなら「カテゴリ」に直す。

3. **インポート見出し**
   - `TopicImportParser` の正は新見出しだけ：`【日常】` `【ビジネス】` `【シチュエーション】`。
   - **旧見出し（`【日常の身近な話題】` `【ビジネスシーン】`）は受け付けない。** 互換分岐は書かない。
   - `topic_import_screen.dart` の `looksLikeAiImport`・エラーメッセージ・成功メッセージ・ヒントを新名称に更新。成功メッセージ例: `日常 %lld 件、ビジネス %lld 件、シチュエーション %lld 件を追加しました。`（`app_strings.dart` の `%1` 置換も追随）。
   - `AIPromptTemplate.batchPrompt` の見出しと説明文を新名称にする（「3分野」→「3カテゴリ」）。

4. **テスト**
   - `test/layers_test.dart` など `find.text(_t('日常の身近な話題'))` を `_t('日常')` に。ビジネスも同様。
   - フィルタシートの `'分野'` assert を `'カテゴリ'` に（`test/question_prompt_layer1_test.dart` 等）。
   - インポートテストの見出しを `【日常】` `【ビジネス】` に更新する。旧見出しの互換テストは書かない（既存があれば新見出しに直すか削除）。
   - 問題文 JSON: 旧 `"field": "daily"` が `category == TopicCategory.daily` で読める。新規 `toJson` は `"category": "日常"` で `"field"` を持たない。

### 受け入れ
- カテゴリ選択・フィルタ・手動追加・インポート画面の表示が「日常」「ビジネス」「カテゴリ」。
- 新しく保存した問題文 JSON のカテゴリキーは `"category": "日常"` のようになる。旧 `"field": "daily"` も読める。
- prefs の取り込みキーは `topics.imported.日常` 等。旧 `topics.imported.daily` は読み取り後に移行される。
- インポート・AI プロンプトの見出しは `【日常】` `【ビジネス】` `【シチュエーション】` のみ。
- `flutter analyze` と関連テストが通る。
- 25マス画面の「鉄板ネタ」や盤面ロジックは**まだ変えない**。

### 手動確認
1. レイヤーⅡランダムでカテゴリ行が「カテゴリ　日常」と出る。切り替えると「ビジネス」「シチュエーション」。
2. 問題文一覧のフィルタに「カテゴリ」と出る。
3. 言語を en/vi にしてキー生出しがない。
4. 話題を増やす → AI 取り込みの見出しが `【日常】` `【ビジネス】` `【シチュエーション】`。

---

## Step 2 — 25マス テンプレート（データ層）

### 目的
UI はまだ大きく変えず、カテゴリ別テンプレートと可変列数（5 or 3）をモデルとサービスに載せる。既存 JSON が読めること。

### 指示

1. **カテゴリは `TopicCategory` を使う。別 enum は作らない。**  
   - `ThinkingMatrixSet.category` は `TopicCategory?`（`null` = オリジナル）。
   - JSON の `category` は `TopicCategory.storageKey`（`日常` / `ビジネス` / `シチュエーション`）。欠落・`ランダム`・旧英語キー以外の未知・`"original"` はすべて `null`。旧英語キー `daily` 等は対応する enum へマップする。
   - オリジナル用 l10n キー `'オリジナル'` だけ新規（en: Original、vi: Nguyên bản）。日常・ビジネス・シチュエーションは Step 1 の `labelKey()` をそのまま使う。
   - `createFromPreset(TopicCategory category)` は `daily` / `business` / `situational` のみ。`random` は拒否。

2. **列のラベル**  
   新規・既存とも汎用5列は `generalColumns`（`time` / `view` / `compare` / `scale` / `reason`）。  
   現行 `ThinkingPerspective`（`stance` / `change` を含む）は **読み込み時の変換表にだけ使う**。新規ボードや描画は `set.columns` を回す。変換後に enum を描画で参照しない。

   新ファイル例:
   - `lib/models/thinking_matrix_column.dart` — `id` + `labelKey`（l10n の日本語ソース）
   - `lib/data/thinking_matrix_presets.dart` — Gemini 案を Dart にする

```dart
class ThinkingMatrixPresets {
  static const generalColumns = <ThinkingMatrixColumn>[ /* time, view, compare, scale, reason */ ];
  static const dailyThemes = <String>[ /* 趣味, 健康, 買い物, 旅行, 季節 */ ];
  static const businessThemes = <String>[ /* 時間, チーム, 成長, 仕事, 問題 */ ];
  static const situationColumns = <ThinkingMatrixColumn>[ /* workplace, school, hospital */ ];
  static const situationThemes = <String>[ /* 相談, 依頼, 断り, 謝罪, 提案 */ ];
}
```

   テーマ文字列は l10n キー（日本語）。en/vi を `gradus_l10n.dart` にこの Step で入れる。

3. **ThinkingMatrixSet**
   - `category`（`TopicCategory?`。fromJson 欠落時は `null`＝オリジナル）
   - `columns`（1セットが自分の列を持つ。5 or 3）
   - `totalCells` は **定数25をやめる**。`themes.length * columns.length`（通常 25 or 15）。
   - `create` は `category` と `columns` を受け取る。ファクトリを分ける:
     - `ThinkingMatrixSet.create({required title, TopicCategory? category, required themes, required columns})`
     - プリセット用はサービス側 `createFromPreset(TopicCategory category)` でテーマ名・列を埋める（`random` 不可）
   - `isColumnFilled` は `ThinkingPerspective` ではなく **columnId** で判定。
   - 行・列の「すべて spoken か」ヘルパを public に（Step 4 のトロフィー2つ用。この Step でテストまで書いておく）:
     - `bool isRowSpoken(int themeIndex)`
     - `bool isColumnSpoken(String columnId)`

4. **ThinkingMatrixCell**
   - `netaId` → `themeId`。JSON は `themeId` で書く。旧 `netaId` は読む。
   - JSON の列は `columnId`（String）を正とする。
   - 旧 JSON の `perspective` が来たら `columnId` にマップする:
     - `time` → `time`
     - `stance` → `view`
     - `compare` → `compare`
     - `scale` → `scale`
     - `change` → `reason`
   - すでに `view` / `reason` ならそのまま。未知 id のセルは落とす。
   - `ThinkingPerspective` 型のフィールドは段階的に外す。残すなら変換表だけ。

5. **fromJson マイグレーション**
   - `columns` 欠落、または旧5視点（`stance` / `change` を含む）→ **`generalColumns` に載せ替える**（立場・変化の見出しは出さない）。
   - セルの `perspective` / 旧 `columnId` は上表で `view` / `reason` に直し、キーワード・status は保持する。
   - `category` 欠落 → `null`（オリジナル）。
   - セル数が `themes × columns` 未満なら空セルで補う（現行どおり）。
   - シチュエーション用の3列は、もともと旧データに無いのでこの変換の対象外。

6. **ThinkingMatrixService**
   - **`ThinkingNeta` → `ThinkingTheme`。** ファイル `thinking_neta.dart` → `thinking_theme.dart`。プロパティ `netas` → `themes`、`netaId` → `themeId`、`updateNetaName` → `updateThemeName`、変数名 `neta` も `theme` に揃える。JSON は新キー `themes` / `themeId` で書く。旧 `netas` / `netaId` は読む。
   - `createSet` はオリジナル用（`category: null`、テーマ5つ必須、列は `generalColumns`）。引数名も `themeNames`。
   - `createFromPreset(TopicCategory category)`  
     - `daily` / `business` / `situational` のみ。`random` は拒否（呼び出し側が `createSet`）。
     - プリセットのテーマ名・列で create。タイトルは呼び出し側 or 「セットN」（UI は Step 3。ここでは title 必須でも、サービス内で日本語キー `セット1` 相当を入れてもよい。Step 3 で l10n するなら title を引数にする）。
   - `upsertCell` の perspective 引数を `columnId` に、netaId を `themeId` に変更。既存呼び出し（UI・テスト）をこの Step で直す。

7. **バックアップ**
   - `toJson` に `category` と `columns` が載ることを確認。`formatVersion` は上げなくてよい（欠落許容マイグレーションがあるため）。`test/gradus_backup_test.dart` が旧 shape の fixture を持っていたら、旧 JSON でも復元できることを維持する。

8. **テスト** `test/thinking_matrix_service_test.dart`（不足は追加）
   - 日常プリセット: 列5・行5・cell 25、テーマが趣味…季節
   - シチュエーション: 列3・cell 15
   - 旧 JSON（`netas` / `netaId` / `perspective: stance|change`、category なし）が `themes` + original + 新汎用5列で読める。スタンス列のキーワードが `view` 列に残る。変化列は `reason` 列に残る
   - `isRowSpoken` / `isColumnSpoken`
   - 既存の filled/spoken/completedAt テストが通る

### 受け入れ
- 既存の保存済み25マスセットがアプリ起動後も開ける。列見出しは時間・視点・比較・規模・理由。旧「立場」「変化」マスのキーワードはそれぞれ視点・理由に載っている。
- UI の作成フローはまだ「鉄板ネタ5つ入力」のままでよい（`createSet` が generalColumns を使うよう直す）。盤面が `set.columns` を回すよう、**描画がコンパイルできる最小限の画面修正はしてよい**（3列テンプレ UI は Step 3）。
- `flutter analyze` と `flutter test test/thinking_matrix_service_test.dart test/thinking_matrix_layer2_test.dart test/gradus_backup_test.dart` が通る。

### 手動確認
なし必須。既存セットが残っている端末なら、アプリを起動してボードが開けることだけ見るとよい。

---

## Step 3 — 25マス テンプレート（作成フロー UI）

### 目的
新規作成でカテゴリを選び、プリセットならすぐ盤面、オリジナルなら今のテーマ入力画面へ進む。シチュエーションは 3×5。

### 指示

1. **作成の動線**

```
セット0件で入場、または一覧の＋
 └─ カテゴリ選択（日常 / ビジネス / シチュエーション / オリジナル）
      ├─ オリジナル → 既存の5欄入力画面（ラベルは「テーマ」。Step 4 で徹底するが、この画面はここで「テーマ」にする）
      └─ それ以外 → createFromPreset → 盤面
```

- フェーズを `pickCategory | edit | list | board` にするか、カテゴリ選択をボトムシートにするかは既存トーンに合わせる（MainShell ヘッダーの内側、`AppHeader` を積まない）。
- **カテゴリ選択 UI は問題文と同一ソース。** `CategorySelectSheet` の行見た目を共有し、ラベルは `TopicCategoryLabel`。`random` は出さない。4行目だけ `'オリジナル'.tr`。問題文用の `show()` の戻り値（キャンセル＝null）を壊さないこと。
- キャンセルは4択へ出さず、一覧（空なら空状態）へ。
- セット0件入場時も、いきなり5欄ではなく **先にカテゴリ選択**。

2. **盤面**
   - 列は `ThinkingPerspective.values` ではなく `set.columns`。
   - 行は `set.themes`（5）。
   - シチュエーションは3列でも横スクロール必須にしない（列が広いだけでよい）。
   - 達成率の分母は `set.totalCells`（15 のとき 15）。文言キー `25マス_達成率` は既に `%2/%3` なので流用。
   - コンプリートダイアログ: 15マスでも出せる。本文が「25マスすべて」固定なら、マス数を置換するキーに変える（例: `%1マスすべて埋まりました`）。タイトル「25マスコンプリート」は製品名として残してよい。
   - 左上〜軸: 縦軸側に「テーマ」、横軸側に「視点」がユーザーに分かること（小さくてよい。列の個別見出しはテンプレ短名のまま）。
   - プリセットのテーマ名も、既存の編集シートで改名できる（セルは `themeId` 参照のまま）。

3. **一覧**
   - 行にカテゴリ名を出してもよい（任意。出すなら小さいラベル）。達成率は分母がセットごとに違うので現行の % 表示を流用。

4. **セルシート**
   - 見出しは `テーマ名 × 列のフル名`。列にフル名が無いなら `labelKey` でよい。
   - `upsertCell` は `columnId`。

5. **l10n**
   - `オリジナル`、カテゴリ選択の案内、軸ラベル `テーマ` / `視点`（`視点` は既にキーがある。値の用途が増えるだけなら流用可）。
   - 空一覧文面の「鉄板ネタ5つ」を「テーマ」寄りに直す（完全な「鉄板ネタ」撲滅は Step 4 でも可。この Step で触った画面は「テーマ」にする）。

6. **テスト** `test/thinking_matrix_layer2_test.dart`
   - 入場 → カテゴリ選択が見える
   - オリジナル → 5欄。4つでは作成できない。5つで25マス盤面
   - 日常を選ぶとテーマ入力をスキップし、行に「趣味」等が見える
   - シチュエーションを選ぶと列が3つ（職場・学校・病院）、セルが15
   - 既存の「5欄から作成」テストは、オリジナル経由に更新

### 受け入れ
- 4カテゴリとも作成でき、再起動後も列・行が残る。
- 旧セット（オリジナル扱い）が新汎用5列で開ける。キーワードは stance→view、change→reason で残る。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. 新規「日常」→ すぐ25マス。縦が趣味…季節、横が時間・視点・比較・規模・理由。
2. 新規「シチュエーション」→ 3×5。相談×職場のセルが開く。
3. 新規「オリジナル」→ テーマ5つ入力 → 汎用5列の盤面。
4. ヘッダー「Ⅱ」再タップで4択に戻れる。
5. Step 1 以前に作ったセットがあれば、列が「視点」「理由」に置き換わり、中身のキーワードが残っている。

---

## Step 4 — 25マスの見た目

### 目的
「テーマ／視点」の言い方を徹底し、ゴールドマスのチェックをやめ、spoken ビンゴはトロフィー2つにする。

### 指示

1. **「鉄板ネタ」→「テーマ」**
   - ユーザー向けのすべての「鉄板ネタ」（l10n 値・画面・ツールチップ・ヘルプ tip6・コンプリート本文・空状態）。
   - キー名 `'鉄板ネタ'` は参照が残るなら、値だけ `'テーマ'` にするか、キーを `'テーマ'` に寄せて呼び出しを置換する（キー `'テーマ'` は Step 3 で追加済みのはず）。
   - コード識別子は Step 2 で `ThinkingTheme` / `themeId` にリネーム済み。この Step で `neta` が残っていたら消す。
   - `help.gradus.layer2.tip6` を「テーマ×視点」に更新（3言語）。

2. **spoken マスの見た目**
   - `_ThinkingMatrixCellView`: `spoken` はゴールド背景＋キーワードのみ。`Icons.check_circle_rounded` を出さない。
   - filled と同じテキストスタイルでよい（背景色だけ違う）。
   - テスト `「1分話した」ONで保存するとチェック＋ゴールド` を、チェック無し・ゴールド背景（または `spokenCount == 1` ＋キーワード表示）に直す。

3. **トロフィー2つ**
   - 行が `isRowFilled` かつ `isRowSpoken` → アイコン2つ。filled のみ → 1つ。
   - 列も同様（`isColumnFilled` / `isColumnSpoken`）。
   - 2つは横並び。既存の `_masterIconSize`（12）を流用。行ラベル幅 60px に収める。列は `Expanded` 内で中央寄せ。
   - 揃っていないラインは 0。アイコン増減で盤面がジャンプしないよう、アイコン行の高さは現行どおり確保する。
   - テスト: 1行を全部 spoken にするとトロフィーが2つ（`find.byIcon(Icons.workspace_premium_rounded)` の個数で assert してよい。他列が空ならその行の2つだけ）。

4. **軸ラベル**
   - Step 3 で入れていなければ、ボード上で横＝視点・縦＝テーマが分かるラベルを足す。

### 受け入れ
- 画面に「鉄板ネタ」が出ない（開発者コメントは可）。
- spoken マスにチェックが無い。
- spoken で揃えた行／列はトロフィー2つ、filled だけなら1つ。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. 1マスを「1分話した」ON → ゴールドのみ。チェック無し。
2. 1行5マスをキーワードだけで埋める → トロフィー1。
3. 同じ行をすべて「1分話した」ON → トロフィー2。
4. シチュエーション（3マスで行ビンゴ）でも同様。

---

## Step 5 — 全体レビューと修正

### 目的
エキスパートとして、この改修と既存機能の隙間を潰す。新機能を足さない。直すのはユーザー意図に反するものだけ。

### 視点（この順で見て、問題があれば直す）

1. **ユーザー意図に反する重複機能**  
   例: カテゴリ名の二重管理（`ThinkingMatrixCategory` が残っている、日常／ビジネスの l10n が2系統）、オリジナル作成とテーマ編集が同じことを2画面で強制する、問題文の Picker にオリジナルや random が25マス用として漏れる、など。
2. **ゾンビ機能**  
   使われない l10n キー（`'分野'` や旧 `'日常の身近な話題'` が画面から消えたまま残っている等）、旧インポート見出しの死に分岐、`ThinkingPerspective` を新規ボードがまだ参照している、チェックアイコン用の死にコード、コメントの「3択」「鉄板ネタ5つ×視点5つ＝25マス」固定、テスト名と実装の不一致。
3. **動線が冗長**  
   プリセットなのにテーマ入力を踏まされる、カテゴリ選択のキャンセルが4択まで飛ばされる、シチュエーションなのに5列前提の UI が空列を出す、など。
4. **表記揺れ**  
   「分野／カテゴリ」「鉄板ネタ／テーマ／ネタ」「問題文の分野／お題のカテゴリ」「25マス／15マス」のユーザー向け文言。en/vi の抜け。
5. **最新機能とヘルプの整合**  
   `LayerHelpTips` の layer2 tip1〜tip6、各レイヤー「＋」長押しの「カテゴリを選択」、インポート画面の説明、README に古いカテゴリ名が残っていたら一言直す（長文を足さない）。
6. **その他**  
   旧バックアップ、15マスのコンプリート、ビンゴ演出が3列でも落ちない、言語切替でプリセット名が訳される（ユーザー改名済みテーマは訳さない＝`theme.name` は保存文字列のまま）。`ThinkingNeta` / `netaId` / `"field"` / 旧 `daily` storageKey の残存。

### 指示
- 先に調査結果を短く分類してから直す（直さない判断も「問題なし」と書く）。
- 修正は最小。リネームのための巨大リファクタはしない。
- 直した項目ごとにテストを1本足すか、既存テストを更新する。
- `flutter analyze` と、layer2 / thinking_matrix / layers / help / backup / question_prompt 系テストを通す。可能なら `flutter test` 全体。

### 受け入れ
- 上記6視点の所見と、実施した修正（または修正しなかった理由）が完了報告にある。
- ユーザー向けに「分野」「鉄板ネタ」「日常の身近な話題」「ビジネスシーン」が**画面にもインポート見出しにも出ない**。
- ヘルプのレイヤーⅡが4択＋テーマ×視点＋ゴールド自己申告と一致する。

### 手動確認
1. レイヤーⅡを4択から一通り（一覧・ランダム・25マス各カテゴリ・話題を増やす）。
2. ヘルプ画面を ja/en/vi。
3. 問題文フィルタの「カテゴリ」。
4. 25マス: 日常テンプレ作成、オリジナル作成、spoken ビンゴでトロフィー2つ。

---

## 実装時の判断に迷ったら

- **表示とキーを揃えてリネームする。** storageKey は日本語の新名称。`ThinkingNeta`→`ThinkingTheme`、`netaId`→`themeId`、`QuestionPrompt.field`→`category`。旧 JSON / 旧 prefs は読む。
- **シチュエーションは 3×5=15** が正しい。無理に空列を足して25にしない。
- **旧ボードも新汎用5列へ載せ替える。** `stance`→`view`（立場→視点）、`change`→`reason`（変化→理由）。キーワードは消さない。
- **問題文と25マスのカテゴリは `TopicCategory` で同一。** 別 enum を作らない。オリジナルは `category == null` で、`TopicCategory` には足さない。
- **オリジナルだけがテーマ手入力。** 日常・ビジネス・シチュエーションはテンプレで盤面へ。
- **`random` は25マスに出さない。** 問題文の抽選専用のまま。
- ビジネス行の「時間」と列の「時間」の重複は仕様。
- Swift の `MatrixLabel` は参考。実装は Dart + `gradus_l10n`。
