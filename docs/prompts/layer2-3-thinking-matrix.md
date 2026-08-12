# レイヤーⅡ／Ⅲ「25マス」段階化 — Claude Code 用ステップ別プロンプト

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/layer2-3-thinking-matrix.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze` と、その Step で追加・更新したテストが通ることを確認してから次へ進んでください。

| 渡す言葉 | 中身 |
|---------|------|
| Step 1 | レイヤーⅡ：キーワード入力のみ（1分間スピーチ UI を隠す） |
| Step 2 | データモデル：PREP 3項目 + 60秒チャレンジ（Ⅲ用） |
| Step 3 | レイヤーⅢ：入口に25マス追加 + PREP 入力 + トロフィー2つ |
| Step 4 | レイヤーⅢ：60秒スピーチ + トロフィー3つ + ヘルプ・テスト |

前提: `docs/prompts/category-and-matrix-v2.md`（カテゴリ名称・テンプレ・テーマ表記）は実装済み。  
`docs/prompts/layer2-thinking-matrix.md` は初期実装の履歴なので書き換えない。

---

## 0. プロダクト仕様（この改修で確定すること）

### レイヤー間の役割分担

| レイヤー | 25マスでやること | トロフィー（行／列が揃ったとき） |
|----------|------------------|--------------------------------|
| **Ⅱ** | **キーワードだけ**入力。声・タイマー・自己申告は出さない | **1つ**（キーワードが全マス埋まり） |
| **Ⅲ** | キーワードに加え **結論・理由・例示**（PREP）を記入。さらに **60秒スピーチ**にチャレンジ | **2つ**（PREP まで全マス完了）／**3つ**（60秒チャレンジまで全マス完了） |

- **同じセットデータ**を共有する（`ThinkingMatrixService` / `thinkingMatrix.sets`）。Ⅱで入れたキーワードはⅢでも見える。Ⅲで入れた PREP も保存され、Ⅱに戻っても消えない。
- セットの**新規作成**（カテゴリ選択・テンプレ・オリジナル）は**レイヤーⅡの入口のみ**でよい。Ⅲは既存セットを開いて深掘りする（一覧が空ならⅡと同様に作成導線を出してもよいが、カテゴリ選択 UI の二重実装はしない。空なら「Ⅱで作成」案内でも可）。
- 問題文（`QuestionPrompt`）とは**紐付けない**（従来どおり）。

### レイヤーⅡで隠すもの

セル入力シート・盤面から、次を**出さない／使わない**。

- 60秒タイマー（開始／リセット行）
- 「1分話した」トグル
- `spoken` ステータスによるゴールド背景（Ⅱの盤面では `filled` と同じ見た目でよい）
- トロフィー2つ表示（Ⅱでは最大 **1つ**）

### レイヤーⅢで足すもの

1. トップ画面を **2択 → 3択**（既存2つ + **「25マスで考える」**）。アイコンはⅡと同じ `Icons.grid_view_rounded` でよい。
2. セルシートに **結論・理由・例示** の入力（既存 l10n キー `'結論'` `'理由'` `'例示'` を使う。ヘルプ文の「具体例」は `'例示'` と同義）。
3. 行／列の全マスで **キーワード + 結論 + 理由 + 例示** がすべて非空 → トロフィー **2つ**。
4. **「60秒スピーチ」**ボタン → タップ直後に **母語で話してOK** のアラート → 閉じたら **60秒カウントダウン**開始 → 終了（またはユーザーが完了操作）でそのマスに `speech60Done = true` → 行／列の全マスが `speech60Done` → トロフィー **3つ**。
5. Ⅲの盤面トロフィーは **1 / 2 / 3** の段階表示（下記「トロフィー段階」参照）。

### トロフィー段階（Ⅲの盤面）

行または列について:

| 段階 | 条件 | 表示 |
|------|------|------|
| 0 | キーワードが1つでも空 | なし |
| 1 | 全マスにキーワードあり | 🏆×1 |
| 2 | 全マスにキーワード + 結論 + 理由 + 例示 | 🏆×2 |
| 3 | 上記 + 全マス `speech60Done` | 🏆×3 |

Ⅱの盤面は段階 0〜1 のみ（`_ThinkingMatrixMasterBadges` の `spoken` 分岐をⅢ専用に分離する）。

### 60秒スピーチの UX

- ボタンラベル: `'60秒スピーチ'`（新規 l10n、ja/en/vi）。
- **最初のタップ**でアラート（既存 `'母語で回答してOK'` を本文に使う。タイトルは `'60秒スピーチ'` または `'25マス_60秒スピーチ_確認'` など新規キーでよい）。
- アラートの OK で **60秒カウントダウン**を開始（シート内 `Timer.periodic` で足りる。録音・マイク・`PracticeTimerController` は使わない）。
- カウント中は残り秒数を表示。0秒で自動的に `speech60Done = true` として保存してよい。任意で「完了」ボタンを足してもよい（早く終えた人向け）。
- 時間切れ前にシートを閉じたら、**保存していなければ** `speech60Done` は変えない（キーワード・PREP の未保存と同じ）。

### データ（マス1つ）

`ThinkingMatrixCell` に足すフィールド（Step 2）:

| フィールド | 型 | 意味 |
|-----------|-----|------|
| `conclusion` | String | 結論（空可） |
| `reason` | String | 理由（空可） |
| `example` | String | 例示（空可） |
| `speech60Done` | bool | 60秒スピーチを完了した |

`keyword` は従来どおり。`status` は **`empty` / `filled` のみ**をⅡ・Ⅲの正とする。旧 `spoken` は読み込み時に `filled` へ落とし、新規保存では `spoken` を書かない（ゴールドはⅢでも使わない）。

**PREP 完了判定（1マス）**: `keyword`・`conclusion`・`reason`・`example` がすべて trim 後非空。

### やらないこと（全 Step 共通）

- 外部 AI API、音声認識、録音、TTS（60秒はカウントのみ）
- 新規パッケージ追加
- `QuestionPrompt` との紐付け
- このプロンプトファイル自身の書き換え（誤字修正以外）
- レイヤーⅡの他3モード・レイヤーⅢの他2モードの予約席レイアウト変更

---

## 共通ルール（全 Step 共通・必ず守る）

1. **ⅡとⅢでデータは1つ** — 別 prefs キーを増やさない。
2. **l10n** — `gradus_l10n.dart`（キーは日本語ソース）経由。ja / en / vi。
3. **永続化** — `fromJson` で欠落を許容。旧 `spoken` → `filled`。
4. **スコープ外を触らない** — その Step の受け入れ条件以外は直さない。
5. **完了報告** — 変更ファイル一覧・手動確認・次 Step の前提を短く書く。
6. **テスト** — `flutter analyze` と関連テストを通す。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| レイヤーⅡ入口 | `lib/views/layers/layer2_entry_screen.dart` |
| レイヤーⅢ入口 | `lib/views/layers/layer3_entry_screen.dart` |
| 25マス画面（Ⅱ） | `lib/views/layers/layer2_thinking_matrix_screen.dart` |
| セルシート | `lib/widgets/thinking_matrix_cell_sheet.dart` |
| マスモデル | `lib/models/thinking_matrix_cell.dart` |
| ステータス | `lib/models/thinking_matrix_cell_status.dart` |
| セットモデル | `lib/models/thinking_matrix_set.dart` |
| サービス | `lib/services/thinking_matrix_service.dart` |
| バックアップ | `lib/services/gradus_backup.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart` |
| Ⅱ入口テスト | `test/thinking_matrix_layer2_test.dart` |
| Ⅱ4択テスト | `test/question_prompt_layer2_test.dart` |
| レイヤー結合 | `test/layers_test.dart` |
| サービス単体 | `test/thinking_matrix_service_test.dart` |

---

## Step 1 — レイヤーⅡ：キーワードのみ

### 目的
レイヤーⅡの25マスは「キーワードを入れる」までに絞り、1分間スピーチ関連 UI を隠す。トロフィーは1つまで。

### 指示

1. **`ThinkingMatrixCellSheet` にモードを渡す**
   - 例: `enum ThinkingMatrixCellSheetMode { layer2, layer3 }` または `bool showSpeechFeatures`。
   - レイヤーⅡから開くときは `layer2`。
   - `layer2` のとき **非表示**: タイマー行（`Icons.timer_outlined`〜リセット）、`SwitchListTile`（「1分話した」）。
   - 保存時 `spoken: false` 固定（`upsertCell` の `spoken` 引数は常に false）。

2. **レイヤーⅡ盤面の見た目**
   - `_ThinkingMatrixCellView` にモードまたは `treatSpokenAsFilled` を渡す。
   - `layer2` では `ThinkingMatrixCellStatus.spoken` も **filled と同じ**背景・表示（ゴールドにしない）。
   - `_ThinkingMatrixMasterBadges`: レイヤーⅡでは `filled` かつ **not spoken 分岐** → 常に **1つ**（`isRowFilled` / `isColumnFilled` のみ。`isRowSpoken` は使わない）。

3. **既存データ**
   - 盤面上は `spoken` マスも filled 表示でよい（データは Step 2 で整理。ここでは見た目だけ）。

4. **ヘルプ**
   - `help.gradus.layer2.tip6` から「ゴールド」「1分話した」の記述を削除し、「キーワードで埋める」に更新（3言語）。

5. **テスト** `test/thinking_matrix_layer2_test.dart`
   - 「1分話した」ON のテストは **削除または layer3 用に移動予定**として、Ⅱではトグルが見えないことを assert。
   - キーワード保存・トロフィー1つのテストは維持・更新。
   - `spoken` 固定で保存されること（service 経由で status が `filled`）。

### 受け入れ
- Ⅱのセルシートにタイマー・「1分話した」が無い。
- Ⅱの盤面にゴールドマス・トロフィー2つが無い（キーワード揃いで🏆×1）。
- Ⅱの他モード・Ⅲの既存2モードは壊れない。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. レイヤーⅡ → 25マス → マスをタップ → キーワード欄と「マスを埋める」だけ。
2. 1行埋めてトロフィーが1つ。
3. ヘルプのレイヤーⅡ tip6 に1分話しの記述がない。

---

## Step 2 — データモデル（PREP + 60秒）

### 目的
UI をまだ大きく変えず、Ⅲ用の PREP 3項目と `speech60Done` を永続化できるようにする。

### 指示

1. **`ThinkingMatrixCell`**
   - `conclusion` / `reason` / `example`（String、既定 `''`）
   - `speech60Done`（bool、既定 `false`）
   - `toJson` / `fromJson` に追加。欠落は空／false。
   - `copyWith` を更新。

2. **`ThinkingMatrixSet` ヘルパ**
   - `bool isCellPrepComplete(ThinkingMatrixCell c)` — 4フィールドすべて非空。
   - `bool isRowPrepComplete(int themeIndex)` / `bool isColumnPrepComplete(String columnId)`
   - `bool isCellSpeech60Done` は `c.speech60Done`（キーワード空なら false 扱いでもよい）
   - `bool isRowSpeech60Complete(int themeIndex)` / `bool isColumnSpeech60Complete(String columnId)` — 行／列の全マスでキーワードありかつ `speech60Done`
   - `int trophyTierForRow(int themeIndex)` / `trophyTierForColumn(String columnId)` → 0〜3（上表）
   - 旧 `isRowSpoken` / `isColumnSpoken` は **削除するか** `@Deprecated` のうえⅢの `trophyTier` に置き換え（参照を Step 3〜4 で直す）。

3. **`ThinkingMatrixService`**
   - `upsertCell` を拡張するか `upsertCellLayer2` / `upsertCellLayer3` に分ける。
   - **Layer2 用**: `keyword` のみ更新。`spoken` 引数は廃止または無視。status は `empty`/`filled` のみ。
   - **Layer3 用**: `keyword` + `conclusion` + `reason` + `example` + `speech60Done` を更新。キーワード空なら `empty` に戻し、PREP・speech60 もクリア。
   - `markSpeech60Done(setId, themeId, columnId)` または upsert の一部でよい。

4. **ステータス**
   - `ThinkingMatrixCellStatus.spoken` は enum に残してもよいが、**新規書き込みでは使わない**。`fromJson` で `spoken` → `filled` に正規化。

5. **バックアップ**
   - 新フィールドが `toJson` に載ること。旧バックアップ（フィールド無し）が読めること。`formatVersion` は必要なら上げる（テストで往復）。

6. **テスト** `test/thinking_matrix_service_test.dart`
   - PREP 4項目の往復
   - `trophyTierForRow`: キーワードのみ→1、PREP まで→2、speech60 まで→3
   - 旧 `status: spoken` の JSON が `filled` で読める
   - `speech60Done` の保存・再読込

### 受け入れ
- Step 1 のⅡ UI はそのまま動く（新フィールドは空でよい）。
- サービス・モデル・バックアップテストが通る。
- `flutter analyze` が通る。

### 手動確認
なし必須（データ層のみ）。

---

## Step 3 — レイヤーⅢ：入口 + PREP 入力 + トロフィー2つ

### 目的
レイヤーⅢトップに「25マスで考える」を足し、同じセットを開いて PREP まで記入できる。トロフィーは最大2つまで表示。

### 指示

1. **`Layer3EntryScreen` を3択に**
   - `enum Layer3Mode { selectFromList, random, thinkingMatrix }`
   - 並び: 問題文一覧から選ぶ / ランダム / **25マスで考える**（Ⅱと同ラベル・同アイコン）。
   - `switch` に `Layer3ThinkingMatrixScreen`（新規）または共有画面を追加。
   - `resetMode()` / ヘッダー「Ⅲ」再タップは従来どおり3択へ。
   - コメントの「2択」を「3択」に。

2. **25マス画面（Ⅲ）**
   - **推奨**: `lib/views/layers/layer3_thinking_matrix_screen.dart` を新設し、一覧・盤面のロジックは `layer2_thinking_matrix_screen.dart` から **共通化**（`thinking_matrix_board.dart` 等に `_ThinkingMatrixGrid`・`_ThinkingMatrixMasterBadges` を抽出）。
   - 共通化が大きすぎる場合は、Ⅲ用画面を薄いラッパーにして `Layer2ThinkingMatrixScreen` に `ThinkingMatrixLayer layer` 引数を渡してもよい（ただしファイル名 `layer2_` のままⅢから呼ぶのは避け、共有ウィジェットへ寄せる）。
   - セット一覧・盤面は **同じ `ThinkingMatrixService`**。新規作成はⅡと同じフローを再利用（`Layer2ThinkingMatrixScreen` の作成フェーズを共有関数化してもよい）。
   - 盤面の `_ThinkingMatrixMasterBadges` は **`trophyTierForRow/Column`** を使い、0→非表示、1→🏆×1、2→🏆×2（**3は Step 4**）。

3. **`ThinkingMatrixCellSheet` モード `layer3`**
   - キーワード欄（既存）
   - その下に **結論・理由・例示**（各 `TextField` または行タップで `TextEditSheet` — Ⅲ問題文詳細と同型でよい）
   - ラベルは `'結論'.tr` `'理由'.tr` `'例示'.tr`
   - 「60秒スピーチ」ボタンは **Step 4 で実装**。この Step では非表示または disabled でよい。
   - 保存で `upsertCellLayer3`（名称は実装任せ）を呼ぶ。

4. **盤面のマス表示（Ⅲ）**
   - `empty` / `filled` はⅡ同様。PREP が一部入っているマスは、キーワードの下に小さく「結」「理」「例」のどれか入っている印でもよい（任意。最低限キーワード表示で可）。
   - `speech60Done` の見た目は Step 4。

5. **テスト**
   - 新規 `test/thinking_matrix_layer3_test.dart`（または `thinking_matrix_layer3_entry_test.dart`）:
     - Ⅲ入口に「25マスで考える」
     - タップでセット一覧または盤面（Ⅱで作ったセットが見える）
     - セルで PREP 保存 → サービスに `conclusion` 等が残る
     - 1行 PREP 完了でトロフィー2つ（`find.byIcon(Icons.workspace_premium_rounded)` が2）
   - `test/layers_test.dart` 等の「Ⅲは2択」があれば3択に更新。

6. **ヘルプ（最低限）**
   - `help.gradus.layer3.tip1` を3択に更新。
   - `help.gradus.layer3.tip5` を新設（25マス: キーワードに PREP を足す。Ⅱで埋めたマスを深掘り）— `LayerHelpTips` の layer3 `tipKeys` に追加。3言語。

### 受け入れ
- Ⅲトップが3択。25マスに入れる。
- Ⅱで入れたキーワードがⅢでも見える。Ⅲで PREP を入れると保存される。
- PREP が行／列で揃うと🏆×2。60秒前は🏆×3にならない。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. Ⅱでキーワードだけ埋める → Ⅲで同じセットを開きキーワードが見える。
2. Ⅲで結論・理由・例示を入れて保存。
3. 1行5マス PREP 完了でトロフィー2つ。

---

## Step 4 — レイヤーⅢ：60秒スピーチ + トロフィー3つ + 仕上げ

### 目的
60秒スピーチのカウントダウンと母語 OK アラートを実装し、トロフィー3段階を完成させる。

### 指示

1. **「60秒スピーチ」ボタン**（`ThinkingMatrixCellSheet` の `layer3` のみ）
   - キーワードが空のときは disabled（PREP 未入力でもボタンは出してよいが、キーワード無しでは開始不可）。
   - タップ → **アラート**（本文 `'母語で回答してOK'.tr`、OK で閉じる）。
   - 閉じたら **60秒カウントダウン** UI を表示（シート内。Step 1 以前の1分タイマー UI を流用してもよいが、ラベルは「60秒スピーチ」系に）。
   - 0秒到達（または「完了」ボタン）で `speech60Done: true` を保存してシートを閉じるか、シート内でトグル表示を更新。
   - カウント中にキャンセルしたら `speech60Done` は変えない。

2. **盤面トロフィー**
   - `trophyTierForRow/Column` が 3 のとき 🏆×3。
   - 段階は排他的（3のときは2や1を重ねて表示しない。常に tier 個だけ表示）。

3. **マス見た目（任意だが推奨）**
   - `speech60Done` のマスに薄いアクセント（枠線や小さなマーク）。ゴールド全面は使わない（Ⅱ方針と整合）。

4. **ヘルプ・文言**
   - `help.gradus.layer3.tip5` に60秒スピーチ・母語 OK を追記。
   - 新規 l10n: `'60秒スピーチ'`、`'25マス_60秒スピーチ_確認'`（アラートタイトル）等。ja/en/vi。

5. **テスト**
   - 60秒ボタン → アラートに母語文言 →（テストではタイマーを pump で進め）→ `speech60Done` 保存。
   - 1行すべて `speech60Done` でトロフィー3つ。
   - Ⅱのテストが壊れていないこと。
   - `test/gradus_backup_test.dart` で新フィールド往復。
   - 可能なら `test/help_l10n_test.dart` 通過。

6. **仕上げ**
   - 死にコード（Ⅱ専用 `spoken` トグル、`isRowSpoken` の未使用参照）を掃除。
   - README は触らなくてよい。

### 受け入れ
- 60秒スピーチ前に母語 OK アラートが出る。
- カウントダウン後に `speech60Done` が残る。
- 行／列で🏆×1／×2／×3が仕様どおり。
- `flutter analyze` と thinking_matrix / layer3 / backup / help 関連テストが通る。

### 手動確認
1. Ⅲでキーワード+PREP を入れたマスで「60秒スピーチ」→ アラート → カウントダウン → 保存。
2. 同じ行を5マスすべて60秒完了 → 🏆×3。
3. Ⅱに戻るとキーワードのみのシンプル UI のまま。
4. 言語 en/vi でキー生出しなし。

---

## 実装時の判断に迷ったら

- **Ⅱはキーワードだけ。声・タイマー・自己申告はⅢへ。**
- **同じセット・同じサービス。** prefs を分けない。
- **例示 = 具体例。** UI ラベルは既存 `'例示'` キーを使う。
- **トロフィーは段階的（1→2→3）。** 2と3を同時に並べない。
- **60秒は録音しない。** カウントと自己申告フラグだけ。
- **セット作成はⅡ入口が正。** Ⅲで二重にカテゴリ Picker を作らない。
