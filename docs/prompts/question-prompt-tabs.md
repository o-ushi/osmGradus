# 問題文タブ分類 — Claude Code 用ステップ別プロンプト

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/question-prompt-tabs.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze` と、その Step で追加・更新したテストが通ることを確認してから次へ進んでください。

| 渡す言葉 | 中身 |
|---------|------|
| Step 1 | データモデル・タブレジストリ・マイグレーション（UI は最小限） |
| Step 2 | 組み込み問題文へのタブ付与 |
| Step 3 | 一覧・フィルタ・抽選 UI をタブ対応に更新 |
| Step 4 | 新規追加時の自動タブ設定（手入力・AI取込・インポート） |
| Step 5 | 長押し編集画面（問題文＋タブ） |
| Step 6 | 全体レビュー（バックアップ・ヘルプ・25マスとの共存） |

`docs/prompts/category-and-matrix-v2.md` は **25マス＋旧カテゴリ名称の履歴**なので書き換えない。このファイルがタブ分類改修の正本。

---

## 0. プロダクト仕様（この改修で確定すること）

### A. 分類の2段構え

| 第1段階 | 内容 |
|--------|------|
| **シチュエーション** | 現状どおり。`body`＝状況、`situationCondition`＝条件。タブは持たない。 |
| **シチュエーション以外** | 旧「日常」「ビジネス」の区別をやめる。代わりに**タブ**（複数可）で分類する。 |

- ユーザー向けの第1段階ラベル: **シチュエーション** / **その他**（en: Situations / General、vi: Tình huống / Chung — Step 1 で l10n 確定）。
- データ上は `TopicCategory.situational` と **`TopicCategory.general`（新規）** の2種。`random` は抽選専用のまま（問題文エンティティの `category` には付けない）。

### B. タブ（第2段階・シチュエーション以外のみ）

**初期組み込みタブ**（ユーザーが削除できない。表示順はこの並び）:

| storageKey（= l10n 日本語ソース） | 用途の目安 |
|----------------------------------|-----------|
| `趣味` | 趣味・余暇・娯楽 |
| `健康` | 健康・運動・生活習慣 |
| `旅行` | 旅行・場所・観光 |
| `家族` | 家族・人間関係（私的） |
| `環境` | 環境・自然・季節・社会課題 |
| `会社` | 職場・ビジネス・仕事 |

- **1問に複数タブ**を付けられる（例: リモートワーク → `会社`＋`環境`）。
- **ユーザー独自タブ**を追加できる（SharedPreferences に保存。組み込みタブと同じ UI で選択可能）。
- タブ名は **storageKey = 表示の日本語ソース**（`gradus_l10n` で en/vi 翻訳。ユーザーが作った独自タブは翻訳せず保存文字列のまま表示）。
- シチュエーション問題の `tags` は **常に空配列**。読み込み時に値があっても捨てる。

### C. 旧カテゴリからの移行

| 旧 `TopicCategory` | 新 `category` | `tags` |
|--------------------|---------------|--------|
| `daily` | `general` | Step 2 のマッピング表どおり |
| `business` | `general` | Step 2 のマッピング表どおり |
| `situational` | `situational` | `[]` |
| `random` | （問題文には付けない） | — |

- JSON の旧 `"category": "日常"` / `"ビジネス"` は読み込み時に `general` へ。`tags` が無ければ Step 2 相当の推定ロジック or 空（Step 1 では空でも可、Step 2 で組み込みを埋める）。
- **書き込み**は `"category": "一般"`（`general` の storageKey）と `"tags": ["趣味", ...]` のみ。`日常` / `ビジネス` は書かない。
- prefs `topics.imported.日常` 等の旧取り込みキーは、Step 1 で `topics.imported.一般` へ移行する（本文リストはそのまま。取り込み時に `general`＋自動タブ付与は Step 4）。

### D. 25マス（ThinkingMatrix）との関係

- **25マスのプリセットカテゴリ（日常／ビジネス／シチュエーション）は Step 1〜5 では触らない。** `TopicCategory.daily` / `business` は **25マス専用のレガシー値として enum に残す**（storageKey は現状の `日常` / `ビジネス` のまま）。
- 問題文は `general` / `situational` のみ使う。`daily` / `business` を問題文に新規書き込みしない。
- Step 6 で「問題文と25マスで日常／ビジネスという言葉が別意味になっていないか」をレビューする。

### E. やらないこと（全 Step 共通）

- 発音5カテゴリ（`PronunciationCategory`）の変更
- 長文読解・ダッシュボードの大規模リデザイン（タブ対応に必要な最小限の集計修正のみ Step 6）
- このプロンプトファイル自身の書き換え（誤字修正以外）
- Hive / SQLite の新規導入

---

## 共通ルール（全 Step 共通・必ず守る）

1. **既存の予約席レイアウトを動かさない** — レイヤー詳細の `DiceActionRow` / `PrepLabelRow` 等の枠位置は維持。
2. **l10n** — ユーザー向け文言は `gradus_l10n.dart`（キーは日本語ソース）経由。ja / en / vi を揃える。
3. **永続化** — SharedPreferences + 既存 `JsonListStore`。`fromJson` で欠落・旧形式を許容するマイグレーション必須。
4. **スコープ外を触らない** — その Step の受け入れ条件以外のリファクタ・ドキュメント追加はしない。
5. **完了報告** — Step 終了時に「変更ファイル一覧」「手動確認手順」「次 Step への前提」を短く報告する。
6. **テスト** — `flutter analyze` と関連テストを通す。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| 問題文モデル | `lib/models/question_prompt.dart` |
| カテゴリ enum | `lib/models/topic_category.dart` |
| 組み込みバンク | `lib/data/topic_bank.dart` |
| 問題文サービス | `lib/services/question_prompt_service.dart` |
| 一覧・フィルタ | `lib/views/topics/question_prompt_list_screen.dart` / `question_prompt_filter_sheet.dart` |
| 手動追加 | `lib/views/topics/topic_manual_add_screen.dart` |
| AI取込 | `lib/views/topics/topic_import_screen.dart` / `lib/data/ai_prompt_template.dart` |
| 一覧行 | `lib/widgets/question_prompt_list_row.dart` |
| カテゴリ選択 UI | `lib/views/topics/category_select_sheet.dart` / `category_select_field.dart` |
| レイヤーⅡランダム | `lib/views/layers/layer2_random_screen.dart` |
| 練習共通 | `lib/views/layers/practice_layer_screen.dart` |
| バックアップ | `lib/services/gradus_backup.dart` / `question_prompt_json_transfer.dart` |
| l10n | `lib/localization/gradus_l10n.dart` / `app_strings.dart` |
| テスト | `test/question_prompt_*_test.dart` / `test/question_prompt_service_test.dart` |

---

## Step 1 — データモデル・タブレジストリ・マイグレーション

### 目的
タブ分類の土台を作る。`QuestionPrompt` に `tags` を足し、`TopicCategory.general` を追加する。組み込みタブとユーザー独自タブのレジストリを用意する。**画面の大きな変更はまだしない。**

### 指示

1. **`TopicCategory` に `general` を追加**
   - `storageKey` = `'一般'`（表示も「その他」にするなら l10n キー `'その他'` を別途足し、`labelKey()` は状況に応じて使い分けてよい。storageKey は `'一般'` で固定）。
   - `fromStorageKey` は `'一般'` に加え、旧 `'日常'` / `'ビジネス'` / `daily` / `business` を **`general` にマップ**（situational へ誤マップしない）。
   - `daily` / `business` は **削除しない**（25マス用に残す）。

2. **`QuestionPrompt` に `tags` を追加**
   - `final List<String> tags`（既定 `const []`）。
   - `category == situational` のとき assert または factory で `tags` を空に強制。
   - `copyWith` に `tags` と `List<String>? tags` を足す。
   - `toJson`: situational 以外で tags が非空なら `"tags": [...]`。general で空ならキー省略可。
   - `fromJson`: `tags` 欠落は `[]`。situational なら読んだ tags を捨てる。
   - 旧 `category` が `日常`/`ビジネス`/`daily`/`business` なら `general` に正規化。

3. **`QuestionPromptTabRegistry`（新規サービス or モデル）**
   - ファイル例: `lib/services/question_prompt_tab_registry.dart`
   - `static const builtInTabKeys = ['趣味', '健康', '旅行', '家族', '環境', '会社'];`
   - `Future<List<String>> allTabKeys()` → 組み込み + prefs の独自タブ（重複除去、組み込みが先）。
   - `Future<void> addCustomTab(String name)` — 前後空白トリム、空・組み込みと同名は拒否。
   - prefs キー例: `questionPromptTabs.custom`
   - タブ名の最大長（例: 20文字）を設けてよい。

4. **`QuestionPromptService`**
   - `_builtInPrompts()` は Step 2 まで tags 空でも可。ただし `category` は `general` / `situational` を使う（`daily`/`business` を新規生成に使わない）。
   - `filter` に `String? tag` 引数を追加（指定時: `prompt.tags.contains(tag)`。situational は tag フィルタで除外）。
   - `update` のコメントを「body/category/tags も更新可」に広げる準備（実装は Step 5 でも可。Step 1 では copyWith が足りていればよい）。
   - `loadImportedTopicsPref` の移行: `topics.imported.日常` / `topics.imported.ビジネス` を読んだら `topics.imported.一般` にマージして旧キー削除。

5. **l10n（最小）**
   - `'一般'` / `'その他'`（画面によって使い分け）、組み込み6タブの en/vi。
   - Step 3 以前は画面に出さなくても、キーだけ足しておく。

6. **テスト** `test/question_prompt_service_test.dart` 他
   - 旧 JSON `"category": "日常"` → `general`、`tags` 欠落 → `[]`
   - situational + tags あり JSON → tags が捨てられる
   - `QuestionPromptTabRegistry` の組み込み一覧・独自タブ追加
   - `filter(tag: '趣味')` が general のみヒット

### 受け入れ
- `flutter analyze` と関連テストが通る。
- 既存インストールの `questionPrompts.entries` が読み込める（category が general に正規化される）。
- **UI はまだ旧表示（日常／ビジネス）のままでよい** — コンパイルが通れば最小修正のみ。

### 手動確認
- 必須なし（データ層のみ）。

---

## Step 2 — 組み込み問題文へのタブ付与

### 目的
`TopicBank` 由来の組み込み問題文すべてに、内容に即したタブを付ける。

### 指示

1. **マッピングファイルを新規作成**  
   `lib/data/question_prompt_builtin_tags.dart`（名前は明確なら変更可）

   - キー: 組み込み ID（`builtin_daily_0` 形式）または本文完全一致。
   - 値: `List<String>`（組み込みタブの storageKey のみ。独自タブは使わない）。

2. **以下のマッピングを正とする**（調整が必要なら理由をコメントに残す）:

   **旧 daily（`TopicBank.dailyTopics`）**

   | # | 本文（先頭のみ） | tags |
   |---|-----------------|------|
   | 0 | あなたの趣味について | `趣味` |
   | 1 | 最近読んだ本や見た映画 | `趣味` |
   | 2 | 子供の頃の一番楽しかった思い出 | `家族` |
   | 3 | あなたの好きな食べ物 | `趣味` |
   | 4 | 休日はどのように過ごしていますか | `趣味` |
   | 5 | あなたの故郷、または今住んでいる場所 | `旅行` |
   | 6 | 健康のために普段からしていること | `健康` |
   | 7 | 最近始めたこと、または始めてみたいこと | `趣味` |
   | 8 | あなたにとって大切な人について | `家族` |
   | 9 | あなたの一年で一番好きな季節 | `環境` |

   **旧 business（`TopicBank.businessTopics`）** — すべて `会社` を基本とし、下記のみ追加タブ:

   | # | 追加タブ（`会社` に加える） |
   |---|---------------------------|
   | 4 | `家族`（チーム＝職場チームだが、人間関係の話題でもあるため任意。付けない判断も可） |
   | 全10問 | 最低 `会社` は必須 |

   **シチュエーション（`TopicBank.situationPrompts`）** — tags なし（`[]`）。

   **`TopicBank.supplementTopics`**（ランダム専用だった10問）— 今回 **general 化はしない**。従来どおり `QuestionPrompt` 化せず `TopicService.drawRandom` 専用のまま（Step 1 のコメント方針を維持）。

3. **`QuestionPromptService._builtInPrompts()`**  
   上記マッピングで `category: TopicCategory.general` / `situational` と `tags` を設定。

4. **既存ストアの組み込みエントリ**  
   `loadAll` 時、組み込み ID が一致する既存行の `category`/`tags` が古ければ **バンク側の正しい値で上書き**（ユーザーの学習進捗フィールドは保持。`copyWith` で category/tags だけ更新）。  
   本文だけ一致する旧 `builtin_daily_*` 行もマイグレーションできるとよい。

5. **テスト**
   - 組み込み10+10+10件それぞれ期待 tags
   - `builtin_daily_0` の tags が `['趣味']`
   - situational の tags が常に空

### 受け入れ
- `loadAll()` 後、組み込み general 問題がすべて非空 tags を持つ（意図的に空のものが無い）。
- シチュエーション組み込みは tags 空。
- テスト・analyze 通過。

### 手動確認
1. デバッグ用に一時ログ or 既存テストで、組み込み件数と tags を確認。

---

## Step 3 — 一覧・フィルタ・抽選 UI のタブ対応

### 目的
ユーザーが「シチュエーション vs その他」とタブで問題を探せるようにする。日常／ビジネスの3分類 UI を廃止する。

### 指示

1. **フィルタ（`QuestionPromptFilter` / `QuestionPromptFilterSheet`）**
   - `category` 軸を **`situational` / `general` / 全て** に変更（`daily` / `business` チップを削除）。
   - 新軸 **`tag`（単一選択、nullable）** を追加。`general` 選択時のみ有効（シチュエーション選択中は tag チップ非表示 or 無効）。
   - tag チップ一覧は `QuestionPromptTabRegistry.allTabKeys()` から動的取得。
   - `matches` / `QuestionPromptService.filter` を tag 対応。

2. **一覧行（`QuestionPromptListRow`）**
   - 本文の下 or 右に、小さな **タブチップ**（最大2つ表示＋「+N」可）を situational 以外で表示。
   - シチュエーションは従来どおり本文1行のみでよい。

3. **カテゴリ選択（問題文用）**
   - `CategorySelectSheet` を問題文向けに分岐するか、`QuestionPromptCategorySelectSheet` を新設。
   - 選択肢: **その他（一般）** / **シチュエーション** / **ランダム**（抽選画面のみ）。
   - 25マス作成で使う従来の4択（日常／ビジネス／シチュエーション／オリジナル）は **別メソッドのまま維持**（`ThinkingMatrixScreen` 用）。

4. **レイヤーⅡランダム（`Layer2RandomScreen`）** — レイヤーⅣと同じ
   [QuestionPromptDrawSelectField]（シチュエーションは常に選択可）。

4b. **レイヤーⅢ・Ⅳランダム（`PracticeLayerScreen` 系）**

   ```
   趣味
   健康
   旅行
   家族
   環境
   会社
   ランダム          ← general 全件から抽選（タブで絞らない）
   ───────────────  （15+60秒モードのみ）
   シチュエーション
   ```

   - 45秒・60秒モード: 上7行のみ（シチュエーション行と区切り線は非表示）。
   - 15+60秒モード: 区切り線の下にシチュエーションを追加。
   - **手動追加・編集・一覧フィルタ**も同じ選択肢（編集は「ランダム」行なし、フィルタは「すべて」チップあり）。
   - 各タブ行を選ぶと、そのタブを持つ general 問題だけからサイコロ抽選。
   - 実装: `QuestionPromptDrawSelection` / `QuestionPromptDrawSelectField`。
   - レイヤーⅢは従来どおり `CategorySelectField`（その他／シチュエーション）のまま可。

5. **練習レイヤー（`PracticeLayerScreen`）**
   - 分野セレクトをその他／シチュエーションに。general 時は一覧を tag で絞れるようにするか、Step 3 では「すべての general」を出す簡易版でも可（tag 絞り込みはランダム画面とフィルタで先行実装）。

6. **l10n**
   - フィルタ見出し「カテゴリ」は維持。tag 軸見出し `'タブ'`（en: Tags、vi: Thẻ）。
   - 旧「日常」「ビジネス」が問題文 UI に出ないこと。

7. **テスト**
   - フィルタで tag=趣味 → 趣味タグ付き general のみ
   - ランダム画面でタブ選択後に抽選プールが変わる
   - `test/question_prompt_layer1_test.dart` 等の daily/business assert を更新

### 受け入れ
- 問題文一覧フィルタに日常／ビジネスが無い。その他／シチュエーション＋タブで絞れる。
- 一覧にタブチップが見える（general のみ）。
- 25マス作成のカテゴリ4択は従来どおり動く。
- analyze・関連テスト通過。

### 手動確認
1. 問題文一覧 → フィルタ → タブ「健康」で絞り込み。
2. レイヤーⅡランダム → その他 → タブ「会社」→ サイコロで会社系が出やすい。
3. 25マス新規 → 日常プリセットがまだ選べる。

---

## Step 4 — 新規追加時の自動タブ設定

### 目的
手入力・AI一括・JSON 取込で追加した general 問題に、問題文からタブを自動付与する。

### 指示

1. **`QuestionPromptAutoTagService`（新規）**  
   ファイル例: `lib/services/question_prompt_auto_tag_service.dart`

   - `List<String> suggestTags(String body)` を実装。
   - **第1段: キーワード辞書**（高速・オフライン）。例:
     - 趣味: 趣味、映画、本、休日、ゲーム…
     - 健康: 健康、運動、体調…
     - 旅行: 旅行、観光、故郷、海外…
     - 家族: 家族、子供、友人、大切な人…
     - 環境: 環境、自然、季節、リサイクル、地球…
     - 会社: 仕事、職場、上司、会議、取引、顧客、ビジネス、納期…
   - マッチしたタブをすべて返す（0件なら `['趣味']` をフォールバック — 空タブ禁止）。
   - **第2段（任意）**: Chrome AI 連携は **この Step では必須にしない**。辞書で足りなければ Step 6 で拡張。

2. **手動追加（`TopicManualAddScreen`）**
   - カテゴリ UI をその他／シチュエーションに変更。
   - 保存時: general なら `QuestionPrompt.create(category: general, tags: suggestTags(body))` を経由。シチュエーションは従来どおり（状況／条件の入力 UI があれば維持）。
   - `TopicService.importTopics` の category 引数を `general` に寄せる（旧 daily/business 引数は general にマップ）。

3. **AI 一括（`AIPromptTemplate` / `TopicImportParser` / `topic_import_screen.dart`）**
   - プロンプト出力形式を更新:
     ```
     【その他】（45秒スピーチ・10問）
     【シチュエーション】（15秒準備＋60秒発話・10問）
     ```
   - 旧見出し `【日常】` `【ビジネス】` は **読み込み時のみ** general にマップ（互換1リリース分）。新プロンプトは出さない。
   - パース後 general 問題に `suggestTags` を適用。

4. **JSON 取込（`QuestionPromptJsonTransfer`）**
   - エクスポートに `tags` を含める。
   - インポートで `tags` 欠落の general は `suggestTags(body)`。

5. **`showTopicAddChoiceFlow` / 一覧の「＋」**
   - 追加後のデフォルトカテゴリを `general` に。

6. **テスト**
   - `suggestTags('あなたの趣味について…')` → 含む `趣味`
   - 手動追加のモックで tags が付く
   - 旧 AI 形式 `【日常】` パース → general + 自動 tags

### 受け入れ
- 手入力1件追加 → 一覧にタブ付きで出る。
- AI 新形式取込 → general / situational に分かれ tags 付き。
- analyze・テスト通過。

### 手動確認
1. 手動追加「週末はキャンプに行きます」→ 旅行 or 趣味タグが付く。
2. AI 取込（新プロンプト）が通る。

---

## Step 5 — 長押し編集（問題文＋タブ）

### 目的
問題文一覧で**本文を長押し**すると編集画面が開き、**問題文テキストとタブ**を変更できる。

### 指示

1. **`QuestionPromptEditScreen`（新規）**  
   ファイル例: `lib/views/topics/question_prompt_edit_screen.dart`

   - 入力: `QuestionPrompt prompt`（読み取り専用: id, source, 各レイヤー進捗）。
   - **本文** `TextField`（複数行）。シチュエーションは `body`＋`situationCondition` の2欄。
   - **タブ**（general のみ）:
     - `QuestionPromptTabRegistry.allTabKeys()` をチップで **複数選択**。
     - 「＋新しいタブ」で独自タブ追加 → レジストリに登録 → 即選択状態に。
     - 1つも選択されていない保存は禁止（SnackBar）。
   - カテゴリ切替（その他 ↔ シチュエーション）:
     - general→situational: tags クリア、条件欄を表示。
     - situational→general: 条件欄を隠し、`suggestTags(body)` を初期値にしてよい。
   - 保存 → `QuestionPromptService` の新メソッド `updateContent`（id 固定で body / situationCondition / category / tags を更新。他フィールドは保持）。
   - **組み込み（builtIn）** も編集可とする（本文・タブの変更はストアに上書き。次回 `loadAll` でバンク値に戻されないよう、組み込み ID 行はユーザー編集を優先するロジックを `loadAll` に追加）。

2. **一覧（`QuestionPromptListScreen` / `QuestionPromptListRow`）**
   - 本文 `Text` に `onLongPress` を付与（`onTap` は従来どおり詳細へ）。
   - 長押し → `QuestionPromptEditScreen` → 戻ったら `reload()`。
   - ヘルプ（「＋」長押し）に1行追加: 「問題文を長押しで編集」。

3. **取り込み分の prefs 同期**
   - `source == imported` 等で `topics.imported.*` に本文がある場合、body 変更時は prefs 側の文字列も更新（旧本文を新本文に置換）。`delete` と同様の整合性。

4. **l10n**
   - 画面タイトル `'問題文を編集'`、保存／キャンセル、タブ見出し、新規タブダイアログ。

5. **テスト** `test/question_prompt_edit_screen_test.dart`（新規）
   - general 問題: タブ変更が保存される
   - 長押しでシート／画面が開く（`question_prompt_layer1_test` に1本足しても可）
   - builtIn 編集後 reload で tags が保持される

### 受け入れ
- 一覧で本文長押し → 編集 → タブ・本文が反映。
- シチュエーション問題は条件文も編集可。
- 組み込み問題も編集でき、再起動後も維持。
- analyze・テスト通過。

### 手動確認
1. 組み込み「趣味」問題に「会社」タブを足して保存 → 一覧に両方表示。
2. シチュエーション問題を長押し → 状況・条件を編集。
3. 独自タブ「スポーツ」作成 → 他の問題にも選べる。

---

## Step 6 — 全体レビューと周辺整合

### 目的
バックアップ・ダッシュボード・ヘルプ・表記揺れを潰す。25マスとの共存を確認する。

### 視点（この順で見て、問題があれば直す）

1. **バックアップ / JSON** — `tags` と `category: 一般` がエクスポート・復元される。旧バックアップ（日常／ビジネス）も読める。
2. **ダッシュボード** — カテゴリ別集計が daily/business 前提なら general/tags または「その他」に更新。
3. **ヘルプ・使い方** — 「日常／ビジネス」が問題文の説明に残っていない。タブ・長押し編集の説明を追加。
4. **表記揺れ** — 「その他」「一般」「シチュエーション以外」が画面間で矛盾していないか統一。
5. **25マス** — 日常／ビジネスプリセットが問題文のタブと混同されない（UI ラベルで区別できる）。
6. **ゾンビ** — `TopicCategory.daily`/`business` を問題文に新規書き込みしている箇所、死んだ l10n、未使用のフィルタコード。

### 指示
- 先に調査結果を短く分類してから直す。
- 修正は最小。`flutter test` 全体を可能なら実行。

### 受け入れ
- 上記6視点の所見と実施内容が完了報告にある。
- 問題文 UI に「日常」「ビジネス」が出ない（25マス作成画面を除く）。
- analyze・主要テスト通過。

### 手動確認
1. バックアップ書き出し → 削除 → 復元で tags 維持。
2. ヘルプ ja/en/vi。
3. 問題文一覧 → フィルタ → 長押し編集 → 手動追加 → AI 取込の一連動線。

---

## 実装時の判断に迷ったら

- **問題文の第1分類は `general` / `situational` のみ。** `daily`/`business` は25マスレガシー。
- **タブは general 専用。** 複数可。storageKey は日本語。l10n で en/vi。
- **組み込みタブ6つは削除不可。** 独自タブはユーザー追加のみ。
- **自動タグは辞書ベースを正とする。** AI は後から足せる。
- **表示「その他」、永続化 `一般` でよい**（`TopicCategory.general` の storageKey）。
- **長押しは本文のみ。** 行全体タップは従来どおり詳細画面へ。
- **`supplementTopics` は今回 QuestionPrompt 化しない**（ランダム専用のまま）。

---

## クイックリファレンス（ユーザー向けコピペ用）

```
docs/prompts/question-prompt-tabs.md の Step 1 をやって
docs/prompts/question-prompt-tabs.md の Step 2 をやって
docs/prompts/question-prompt-tabs.md の Step 3 をやって
docs/prompts/question-prompt-tabs.md の Step 4 をやって
docs/prompts/question-prompt-tabs.md の Step 5 をやって
docs/prompts/question-prompt-tabs.md の Step 6 をやって
```
