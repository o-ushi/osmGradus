# レイヤーⅡ「25マス思考」— Claude Code 用ステップ別プロンプト

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/layer2-thinking-matrix.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze` と、その Step で追加・更新したテストで破綻がないことを確認してから次へ進んでください。

| 渡す言葉 | 中身 |
|---------|------|
| Step 1 | データモデル・サービス・単体テスト（UIなし） |
| Step 2 | レイヤーⅡを4択にし、ネタ登録＋セット一覧＋空の盤面まで |
| Step 3 | セルタップでキーワード入力・保存・マスの見た目（未入力／入力済／ゴールド） |
| Step 4 | 達成率・ビンゴ演出・列バッジ・25マスコンプリート |
| Step 5 | ヘルプ・バックアップ／初期化・残テスト・文言の仕上げ |

---

## 0. プロダクト仕様（Gemini案を osmGradus 向けに確定）

即興スピーキング（JSST 等）の対策として、ユーザーの**鉄板ネタ 5つ**と、アプリ固定の**思考の視点 5つ**を掛け合わせた 5×5（25マス）を作り、キーワードを埋めていく**コレクション／コンプリート**の思考筋トレ。

- **置く場所**: レイヤーⅡの**新しい第4モード**。既存の「問題文一覧から選ぶ」「ランダム」「話題を増やす」は残す（置き換えない）。
- **APIなし**: 音声認識・AI採点・TTS・録音は使わない。タイマーはローカルのカウントダウンのみ。
- **永続化**: SharedPreferences + 既存の `JsonListStore`。Hive / SQLite / SwiftData は導入しない。
- **ゲーム性**: 達成率 %、縦横が揃ったときのビンゴ、25マス埋まったときのコンプリート。録音の有無は問わない（「1分話した」は自己申告トグル）。

レイヤーⅡの既存コンセプト（「なんて答えたら良いか分からず頭が真っ白」→ 回答をイメージする）を、**自分のネタを多角的にすぐ出せる**方向へ補強する機能。問題文（`QuestionPrompt`）とは**別物**で、紐付けない。

### 画面の呼び方（ユーザー向け確定文言）

| 役割 | ja | en | vi |
|------|----|----|----|
| 4択の行 | 25マスで考える | Think in 25 cells | Suy nghĩ 25 ô |
| 一覧タイトル | 25マス思考 | 25-cell thinking | Tư duy 25 ô |
| 作成ボタン | 25マスボードを作成 | Create 25-cell board | Tạo bảng 25 ô |
| 保存 | マスを埋める | Fill the cell | Điền ô |
| ゴールド化トグル | 1分話した | I spoke for 1 min | Đã nói 1 phút |
| 進捗 | 達成率 40% (10/25) | 40% complete (10/25) | Hoàn thành 40% (10/25) |
| コンプリート | 25マスコンプリート | 25 cells complete | Hoàn thành 25 ô |

視点の列バッジ（揃ったとき）:

| id | 列の短い見出し | バッジ |
|----|----------------|--------|
| `time` | 時間 | 時間軸マスター / Time master / Bậc thầy thời gian |
| `stance` | 立場 | 立場マスター / Stance master / Bậc thầy góc nhìn |
| `compare` | 比較 | 比較マスター / Compare master / Bậc thầy so sánh |
| `scale` | 規模 | 規模マスター / Scale master / Bậc thầy quy mô |
| `change` | 変化 | 変化マスター / Change master / Bậc thầy thay đổi |

### 画面構成

```
レイヤーⅡ 4択
 └─ 「25マスで考える」
      ├─ セットが0件 → ネタ5つ登録画面（画面A）
      ├─ セットが1件以上 → セット一覧（進捗%つき）
      │     ├─ 行タップ → 5×5 ボード（画面B）
      │     └─ ＋ → 新規セットの登録画面
      └─ ボードのマスをタップ → キーワード入力シート（画面C）
```

- ボードは **MainShell のヘッダー（Ⅰ〜Ⅴ）の内側**で出す。`AppHeader` を二重に置かない（5×5 の縦幅を確保するため）。`Navigator.push` で詳細を積むなら、問題文詳細のような常設 `AppHeader` は付けず、MainShell 配下の内部状態切替を優先する。
- 画面Cは `TextEditSheet` と同型の **モーダルボトムシート**（フルスクリーンにしない）。
- ヘッダー「Ⅱ」の再タップで4択に戻る既存の `resetMode()` を壊さない。
- ヘッダー「Ⅱ」を問題文詳細から叩いたときの `selectListMode()`（問題文一覧へ）も**変えない**。25マス思考は4択から入る独立モード。

### 視点（アプリ固定・5つ。ユーザーは増減できない）

1. **時間軸**（過去・現在・未来）— id `time`
2. **立場・視点**（自分・他者・社会）— id `stance`
3. **比較・対立**（メリット・デメリット / 賛成・反対）— id `compare`
4. **規模・範囲**（ミクロ・マクロ / 身近な例・全体）— id `scale`
5. **変化・原因**（きっかけ・結果・課題）— id `change`

セル入力シートでは、ネタ名 × 視点名を強調し、視点の補足（上の括弧内）を小さく出す。

### マスの状態

| status | 見た目 | 意味 |
|--------|--------|------|
| `empty` | グレー寄り・「＋」 | 未入力 |
| `filled` | 明るい背景（`cardFill`）・キーワードを小さく | キーワードあり |
| `spoken` | ゴールド背景・チェック＋キーワード | キーワードあり、かつ「1分話した」 |

`spoken` は `filled` の上位。キーワード無しでゴールドにはできない。キーワードを空にして保存したら `empty` に戻し、ゴールドも解除する。

進捗の分母は常に 25。分子は `filled` + `spoken`（どちらも「埋まった」）。

### やらないこと（全 Step 共通）

- 外部 AI API、音声認識、録音、TTS
- 新規パッケージ追加（Lottie 等も不可。演出は Flutter 標準アニメーション + `HapticFeedback`）
- `QuestionPrompt` / `TopicService` / 既存3モードの予約席レイアウト変更
- ダッシュボードへの数値連携（将来用。この改修では触らない）
- クラス名・ファイル名に `Topic` を使わない（既存のお題／問題文と衝突する）

---

## 共通ルール（全 Step 共通・必ず守る）

1. **既存モードを壊さない** — `Layer2Screen` / `Layer2RandomScreen` / `Layer2QuestionPromptScreen` のボタン枠・予約席は動かさない。
2. **アイコン優先** — 新規の操作ボタンは極力アイコンのみ（ツールチップ／ダブルタップヒントは既存の `ButtonActionHint` に合わせてもよい）。
3. **l10n** — ユーザー向け文言は `gradus_l10n.dart`（キーは日本語ソース）経由。ja / en / vi を揃える。キー文字列を画面に出さない。
4. **永続化** — SharedPreferences。モデルにフィールドを足すときは `fromJson` で欠落を許容する（マイグレーション）。
5. **命名** — コードは `ThinkingMatrix*` / `ThinkingNeta` / `ThinkingPerspective`。UI は「鉄板ネタ」「25マス」。Gemini 原稿の `Topic` / `TopicSet` / SwiftData は使わない。
6. **スコープ外を触らない** — その Step の受け入れ条件以外のリファクタ・ドキュメント追加はしない（このプロンプトファイル自身も書き換えない）。
7. **完了報告** — Step 終了時に「変更ファイル一覧」「手動確認手順」「次 Step への前提」を短く報告する。
8. **テスト** — 既存の「レイヤーⅡは3択」断言は Step 2 で4択に直す。`flutter analyze` と関連テストを通す。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| レイヤーⅡ入口（3択） | `lib/views/layers/layer2_entry_screen.dart` |
| 問題文一覧モード | `layer2_question_prompt_screen.dart` |
| ランダム | `layer2_random_screen.dart` |
| 話題を増やす | `layer2_screen.dart` |
| 入口タイル | `lib/widgets/mode_list_tile.dart` |
| JSON配列ストア | `lib/services/json_list_store.dart` |
| バックアップ | `lib/services/gradus_backup.dart`（`formatVersion` は現在 5） |
| 初期化 | `lib/services/app_reset.dart`（`prefs.clear()` なのでキー追加だけで消える） |
| l10n | `lib/localization/gradus_l10n.dart` / `app_strings.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart` / `lib/views/help/help_screen.dart` |
| 色 | `lib/theme/app_colors.dart`（シーン青 `#3D5993`、カード `#FFFAF2`） |
| 入力シート参考 | `lib/widgets/text_edit_sheet.dart` |
| 削除確認参考 | `lib/widgets/confirm_history_delete_dialog.dart` |
| 入口テスト | `test/question_prompt_layer2_test.dart` |
| レイヤー結合テスト | `test/layers_test.dart`（「話題を増やす」をタップする既存ケースは残る） |
| ヘルプ3言語 | `test/help_l10n_test.dart` |
| バックアップ | `test/gradus_backup_test.dart` |

ID の付け方は `QuestionPrompt.create` に合わせる（例: `tm_${microseconds}_${random}`）。

---

## Step 1 — データモデルとサービス

### 目的
UI をまだ出さず、25マス思考の永続データと集計ロジックを固める。

### 指示

1. 視点をアプリ固定の enum にする。

```dart
enum ThinkingPerspective { time, stance, compare, scale, change }
```

- `storageKey` は上表の id（`time` 等）。未知キーは読み込み時に落とす／デフォルトしない。
- 列の短い見出し・フル名（「時間軸」等）・補足（「過去・現在・未来」等）は l10n キーを返すメソッドか、`ThinkingPerspective` 側の key 定数にする。
- `values` の順番 = ボード左から右の列順。この順番を変えない。

2. モデル（ファイルは `lib/models/` 配下。1ファイル1型で既存に合わせる）。

**ThinkingNeta**（鉄板ネタ1つ。Gemini の `Topic` 相当）
- `id`: String
- `name`: String

**ThinkingMatrixCellStatus**
- `empty` / `filled` / `spoken`

**ThinkingMatrixCell**
- `netaId`: String
- `perspective`: ThinkingPerspective
- `keyword`: String（未入力は空文字。null でもよいが JSON 往復を一貫させる）
- `status`: ThinkingMatrixCellStatus
- `updatedAt`: DateTime

**ThinkingMatrixSet**（Gemini の `TopicSet` 相当）
- `id`: String
- `title`: String（未入力時の作成は「セット1」相当をサービス側で採番）
- `netas`: List\<ThinkingNeta\> **ちょうど5つ**
- `cells`: List\<ThinkingMatrixCell\> **ちょうど25**（5ネタ × 5視点。欠けたら `empty` で補う）
- `createdAt` / `updatedAt`: DateTime
- `completedAt`: DateTime?（25マスが初めて埋まった瞬間。未コンプリートは null。Step 4 でダイアログ抑制に使うので Step 1 から持っておく）

ファクトリ `ThinkingMatrixSet.create({required String title, required List<ThinkingNeta> netas})` で 25 空セルを必ず生やす。`assert(netas.length == 5)`。

ヘルパ（モデルかサービスどちらでも可、テストしやすく public に）:
- `int get filledCount`（status != empty）
- `int get spokenCount`
- `double get completionRatio`（filledCount / 25）
- `bool isRowFilled(int netaIndex)`
- `bool isColumnFilled(ThinkingPerspective p)`
- `List<ThinkingPerspective> get completedPerspectives`
- `ThinkingMatrixCell cellFor(String netaId, ThinkingPerspective p)`

3. サービス `lib/services/thinking_matrix_service.dart`
- `JsonListStore<ThinkingMatrixSet>`、prefs キーは **`thinkingMatrix.sets`**
- `loadAll()` / `loadById(id)` / `save(set)` / `delete(id)` / `clearAll()`
- `createSet({String? title, required List<String> netaNames})`  
  - 名前は trim。空は拒否。ちょうど5つ。  
  - title が空なら既存セット数+1 で「セット1」「セット2」…（l10n は Step 2。ここでは日本語ソースキーを埋め込むか、title を必須にして呼び出し側に任せる。後者なら `createSet` は title 必須でよい）
- `renameSet` / `updateNetaName`（id は変えない。セルは netaId 参照のまま＝キーワードを消さない）
- `upsertCell({required setId, required netaId, required perspective, required keyword, required bool spoken})`  
  - keyword trim が空 → status `empty`、spoken は無視して false  
  - 空でない + spoken false → `filled`  
  - 空でない + spoken true → `spoken`  
  - 25 埋まったら `completedAt` が null のときだけ now を入れる（既に入っていれば上書きしない）
- 並びは新しい順（先頭が最新）で `JsonListStore.save` の既存方針に合わせる。更新時は updatedAt を更新し、一覧の先頭に持ってきてもよい（問題文と同じ「触ったものが上」ならその旨コメントする）。

4. JSON
- `toJson` / `fromJson` で全フィールド往復。
- 日付は ISO 8601（既存モデルに合わせる）。
- 旧データに `completedAt` が無くても読む。
- セルが 25 未満なら不足分を `empty` で補う（壊れたバックアップ耐性）。

5. テスト `test/thinking_matrix_service_test.dart`
最低限:
- create で neta 5・cell 25・全部 empty
- upsert で filled / spoken / 空に戻す
- 行・列の揃い判定（1行5マス、1列5マス）
- 25 埋めで `completedAt` が入る。1マス消して再保存しても `completedAt` は残る（初回コンプリート日時を消さない）
- `toJson` / `fromJson` 往復
- prefs に保存したものを新しい Service インスタンスで読める
- 6個目のネタで create すると assert または明示エラー

l10n の値は Step 2 以降で本入れしてよい。Step 1 では視点 enum の storageKey と、テストに必要な最小限だけでよい（画面に出すキーを Step 1 で全部埋めなくても可）。

### 受け入れ
- `flutter analyze` が通る。
- `flutter test test/thinking_matrix_service_test.dart` が通る。
- UI・入口・バックアップはまだ変えない。
- `Topic` という型名が新規に存在しない。

### 手動確認
なし（データ層のみ）。次 Step で入口から触る。

---

## Step 2 — 4択入口・ネタ登録・セット一覧・空のボード

### 目的
レイヤーⅡから「25マスで考える」に入れ、鉄板ネタ5つでセットを作り、空の5×5を画面に出す。セルタップでの保存は Step 3。

### 指示

1. **l10n（ja/en/vi）**  
   この Step で画面に出す文言を全部入れる。最低限:
   - `25マスで考える`
   - `25マス思考`
   - `25マスボードを作成`
   - `鉄板ネタ`
   - `セット1`（採番用。`セット%@` のように既存の `%@` 置換があればそれを使う）
   - 5つの視点フル名と短い見出し、補足
   - 一覧空状態、削除確認、ネタ5つのプレースホルダ（例: `メロンパン`、`カフェのバイト` はヒント例として1つでよい）
   - 未入力セル用は Step 3 でも可だが、ボードを出すなら「＋」はアイコンで足りる

2. **`Layer2Mode` に `thinkingMatrix` を追加**（`layer2_entry_screen.dart`）
   - 4択の並び（上から）:
     1. 問題文一覧から選ぶ（既存）
     2. ランダム（既存）
     3. **25マスで考える**（新規、`Icons.grid_view_rounded`）
     4. 話題を増やす（既存）
   - `switch (_mode)` に `Layer2ThinkingMatrixScreen` を足す。
   - コメントの「3択」を「4択」に直す（このファイルと、入口を説明するコメントだけ。無関係な「3択」には手を出さない）。
   - `resetMode` / `selectListMode` の意味は変えない。

3. **画面ファイル**（`lib/views/layers/`）
   - `layer2_thinking_matrix_screen.dart` — モードのルート。内部状態で `list | edit | board` を切り替える（MainShell のヘッダーを残す）。
   - セット0件でモードに入ったら **edit（登録）を直接出す**。キャンセル相当（中身が空のまま戻る）は4択へは出さず、一覧の空状態にしてよい。ヘッダー「Ⅱ」再タップで4択に戻れる。
   - 登録画面: タイトル1欄 + ネタ5欄。5つとも trim 後非空で「25マスボードを作成」を活性化。作成成功で board へ。
   - 一覧: タイトル、達成率（Step 1 の filledCount で 0% になる）、タップで board。＋で新規 edit。削除は既存の `confirmHistoryDelete` を使う。
   - ボード（この Step）:
     - 上: セットタイトル
     - 一覧へ戻るアイコン、ネタ編集アイコン
     - 横軸: 視点の短い見出し 5
     - 縦軸: ネタ名 5（ellipsis、最大2行）
     - 5×5: 全部 empty 見た目（グレー＋「＋」）。**タップはまだ無効か、無効と分かるようにする**（Step 3 で有効化）。誤って仮保存しない。
     - 5×5 が画面に収まること。はみ出しは `FittedBox` やフォント縮小で吸収。横スクロール必須にしない（スマホ縦向き1画面）。
   - `appSettings` を listen して言語変更で再描画（他レイヤー入口と同じ）。

4. **既存テストを赤くしない**
   - `test/question_prompt_layer2_test.dart` の「3択」テストを4択に更新し、新モードのラベルがあることを assert。
   - `test/layers_test.dart` で「話題を増やす」を選ぶケースは、4番目が増えてもラベルが残るので**原則そのまま**。3択限定の文言コメントがあれば4択に直す。
   - 新規 `test/question_prompt_layer2_thinking_matrix_test.dart`（または `test/thinking_matrix_layer2_test.dart`）:
     - 入口に「25マスで考える」がある
     - タップすると登録画面（5フィールド）が出る
     - 4つだけ入力では作成ボタンが押せない／押してもセットができない
     - 5つ入力して作成するとボード（ネタ名が見える、セルが25）に進む

5. 色は `AppColors.current`。empty セルはシーン上で「空」と分かる透明度の白/グレー。新規のゴールドは Step 3。

### 受け入れ
- 実機／エミュレータ相当の widget テストで 4択 → 登録 → ボードまで到達できる。
- 既存の問題文一覧・ランダム・話題を増やすが入口から開ける。
- `flutter analyze` と関連テストが通る。
- セルをタップしてもキーワードは保存されない（未実装で落ちない）。

### 手動確認
1. レイヤーⅡ → 「25マスで考える」→ ネタ5つ入れてボード作成。
2. ヘッダー「Ⅱ」再タップで4択に戻る。
3. もう一度入ると一覧にセットがあり、タップで空ボードが開く。
4. 「問題文一覧から選ぶ」が従来どおり動く。

---

## Step 3 — キーワード入力シートとマスの状態

### 目的
マスをタップしてキーワードを保存し、empty / filled / spoken の見た目を切り替える。ここがコア体験。

### 指示

1. **セルシート** `lib/widgets/thinking_matrix_cell_sheet.dart`  
   `TextEditSheet` を参考に `showModalBottomSheet`（`isScrollControlled: true`、キーボードで隠れない padding）。
   - 見出し: `ネタ名` × `視点フル名`（例: メロンパン × 時間軸）
   - 視点の補足を1行（例: 過去・現在・未来）
   - キーワード `TextField`（hint 例: 具体的な固有名詞や場面）
   - **1分タイマー（オプション）**: 60秒カウントダウン。開始／リセット。時間切れで自動ゴールドにしない。録音・マイク・`PracticeTimerController` は使わない。シート内の `Timer.periodic` で足りる。
   - トグル: 「1分話した」（ゴールド化）。キーワードが空のときはトグルしても保存時に spoken にしない（Step 1 の upsert 契約）。
   - 主ボタン: 「マスを埋める」→ upsert して pop。
   - 既存値の編集可。空保存で empty に戻す。

2. **ボードのセルをタップ可能に**
   - empty: グレー＋＋
   - filled: `cardFill`、keyword を小さく（maxLines 2、ellipsis、フォント 10〜12）
   - spoken: ゴールド系（シーン青の上で読めるアンバー／ゴールド。新規パレット定数をこのウィジェットか `app_colors.dart` に1つ足してよい）＋チェックアイコン＋keyword
   - 保存後、ボードと一覧の達成率が即反映されるよう set を再読込。

3. **レスポンシブ**
   - iPhone SE 幅でも列見出しが折り返さず読める（短い見出しを使う）。
   - ネタ名が長くても行高が崩壊しない。
   - キーワードがセルからはみ出して隣のマスに被らない。

4. **テスト**
   - ボードでセルをタップ → シート → キーワード保存 → そのマスに文字が出る
   - 再オープンで TextField に既存値が入る
   - トグル ON で保存するとチェック／ゴールド側の見た目（アイコンの有無で assert してよい）
   - 空保存で＋に戻る
   - Service を直接叩くケースは Step 1 にあるので、widget はハッピーパス中心でよい

### 受け入れ
- API / 録音 / TTS を呼ばない。
- キーワードとゴールドが再起動後も残る（SharedPreferences。widget テストなら同一 prefs で画面を開き直す）。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. 「メロンパン × 時間軸」に「海老名SAのメロンパン」を保存 → マスに表示。
2. 同じマスを「1分話した」ON で保存 → ゴールド＋チェック。
3. タイマーをスタートして数秒待ち、リセットできる。時間切れでも勝手にゴールドにならない。
4. キーワードを消して保存 → 空マスに戻る。

---

## Step 4 — 達成率・ビンゴ・バッジ・コンプリート

### 目的
埋めるほど気持ちいいフィードバックを足す。新規パッケージは使わない。

### 指示

1. **ボードヘッダーの進捗**
   - プログレスバー + `達成率 40% (10/25)` 形式（l10n、数字は置換）。
   - filled + spoken を分子にする。

2. **列バッジ**
   - その視点の5マスが全て埋まった列にバッジ（「時間軸マスター」等）。
   - 横1列（1ネタの5視点）が揃ったら、ネタ名を使った小さなチップでもよい（無くても可。列バッジは必須）。
   - バッジはヘッダー付近に Wrap で並べ、溢れは折り返す（横スクロール必須にしない）。

3. **ビンゴ演出**
   - 行または列が「今回の保存で初めて揃った」ときだけ。
   - `HapticFeedback.mediumImpact()` + 短い視覚（揃った5マスの枠が数回パルス、`AnimatedContainer` やハイライト。Lottie 禁止）。
   - 既に揃っているボードを開いただけでは出さない。
   - 一度に複数列が揃ったら1回にまとめてよい。

4. **25マスコンプリート**
   - `filledCount == 25` かつ、この操作で初めて 25 になったとき（`completedAt` が今回入った）だけダイアログ。
   - 既にコンプリート済みのセットを開いても出さない。
   - ダイアログは1ボタンで閉じる。誇張しすぎない（osmGradus の既存ダイアログトーン）。

5. **テスト**
   - 1列5マスを埋めるとバッジが出る
   - 25マス埋めるとダイアログが出る
   - 同じセットを再度開いてもダイアログは出ない
   - 1マス消して24/25になり、再コンプリートしたらダイアログは出ない（`completedAt` 維持の仕様。再祝いはしない）

再コンプリートで祝う必要はない（仕様を単純に保つ）。

### 受け入れ
- 進捗・バッジ・初回コンプリートダイアログが仕様どおり。
- 演出がテストをフレークさせない（時間に依存する待ちは `pump` / `pumpAndSettle` で閉じる。無限アニメーションは付けない）。
- `flutter analyze` と関連テストが通る。

### 手動確認
1. 1行（同じネタの5視点）を埋めてビンゴを見る。
2. 1列（同じ視点の5ネタ）を埋めてバッジを見る。
3. 25マス埋めてダイアログ。閉じてもう一度ボードを開いてダイアログが出ないこと。

---

## Step 5 — ヘルプ・バックアップ・仕上げ

### 目的
製品として困らない周辺をつなぎ、文言とテストの穴を塞ぐ。

### 指示

1. **ヘルプ**
   - `help.gradus.layer2.tip1` を4択に更新。
   - `help.gradus.layer2.tip6` を追加（25マス思考: 鉄板ネタ×視点、キーワードで埋める、声は出さなくてもよい、ゴールドは自己申告）。
   - `LayerHelpTips` の layer2 `tipKeys` に tip6 を足す。
   - `test/help_l10n_test.dart` は LayerHelpTips 経由で拾うので、3言語の値さえ入れれば足りる（`referenced` 固定リストはヘルプ画面の extra 用。tip 追加だけなら触らなくてよいことが多い。足りなければ足す）。
   - ボードの「＋」長押しや使い方アイコンで `LayerHelpSheet` を出してもよい（任意。出すなら ja/en/vi）。

2. **バックアップ**
   - `GradusBackup.formatVersion` を **6** にする。
   - 専用節 `thinkingMatrixSets`（セットの `toJson` 配列）。
   - `_explicitlyMergedPrefKeys` に `thinkingMatrix.sets` を入れる（preferences 生上書きでマージ結果を消さない）。
   - インポートは **id 単位マージ**（既存の questionPrompts と同じ思想。同じ id は取り込み側で上書き、無い id は追加）。
   - `itemCount` にセット数を含める。
   - 「問題のみ」スコープ（`BackupScope.questionPromptsOnly`）には**含めない**。「全て」に含める。
   - 旧 version 5 のバックアップを読んでも落ちない（節が無いだけ）。
   - `test/gradus_backup_test.dart` に往復テストを1本以上。

3. **初期化**
   - `AppReset` は `prefs.clear()` なので追加実装は不要。コメントを増やす必要もない。
   - 設定の初期化フローテストがキー列挙しているなら、必要なら追随（していなければ触らない）。

4. **仕上げ**
   - セットタイトルのインライン編集（ボード見出しタップ、または edit 画面）。
   - ネタ名変更後もセルのキーワードが残ること（手動確認＋できればテスト）。
   - README のレイヤーⅡが1行しか無いなら、無理に長文を足さない。触るなら「25マス思考」を括弧で一言足す程度。
   - 未翻訳キーが画面に生えていないこと（ja/en/vi）。

5. **テストの締め**
   - Step 2〜4 で弱かったケースを補う。
   - `flutter test` のうち、この機能と入口・backup・help・layer2 関連が通ること。可能なら `flutter test` 全体。

### 受け入れ
- ヘルプのレイヤーⅡに25マスの説明がある（3言語）。
- バックアップ「全て」でセットが戻り、「問題のみ」では戻らない。
- 初期化でセットが消える。
- `flutter analyze` が通る。

### 手動確認
1. ヘルプ画面でレイヤーⅡの tip に25マスが出る。言語を en/vi に切り替えてキー生出しがない。
2. セットを1つ埋めた状態で「全て」エクスポート → 初期化 → インポート → ボードのキーワードが戻る。
3. 「問題のみ」エクスポート／インポートでは25マスが消えない／上書きされない（既存データ保護）。

---

## 実装時の判断に迷ったら

- **問題文と混ぜない**。セルに問題文 ID を持たせない。
- **5×5 固定**。4ネタや6視点の拡張はしない。
- **ゴールドは自己申告**。タイマーは補助。強制しない。
- **祝うのは「初めて揃ったとき」だけ**。毎回うるさいのは失敗。
- **小さい画面で1画面に収める**方が、スクロール付きの巨大ボードより優先。
- Swift / UserDefaults / CoreData と書かれた外部メモは無視し、このファイルに従う。
