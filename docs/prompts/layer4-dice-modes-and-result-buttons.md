# レイヤーⅣ：サイコロモード切替 ＋ 結果ボタン（タップ＝最新詳細／長押し＝一覧）

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/layer4-dice-modes-and-result-buttons.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

実装完了後のコードレビューは `docs/prompts/layer4-dice-modes-and-result-buttons-review.md` の Step 11 を参照。

---

## 機能概要（ユーザーの狙い）

### A. レイヤーⅣ — サイコロ長押しでモード切替

| モード | 動線 | サイコロの見た目 |
|--------|------|------------------|
| **ラピッド**（既定） | **現状どおり** — サイコロ1タップで問題文表示＋読み上げ開始→カウントダウン | **橙色**のアイコン |
| **タートル** | サイコロ1タップで**問題文だけ表示**→アイコンが**スピーカー**に変わる→スピーカータップで読み上げ開始→以降はラピッドと同じ | サイコロは通常色（白／onAccent） |

- **切替方法:** サイコロボタン（`TopicSpeakerTimerButton`、idle 状態）を**長押し**
- **対象:** レイヤーⅣのみ（ランダム／一覧から選ぶの**両方**）。レイヤーⅢは触らない
- **モードの記憶:** 端末内に永続化（`AppSettings` 等。言語設定と同じく再起動後も維持）
- **タートルの狙い:** 読み上げ前に問題文（および解答例ボタン）を確認したい人向け

### B. 結果表示ボタン — 全画面で統一

`PrepLabelRow` の「例示」枠（`list_alt` アイコン）およびダッシュボードのテスト結果行について:

| 操作 | 動作 |
|------|------|
| **タップ** | **最新1件**の結果**詳細画面**を開く |
| **長押し** | **結果一覧**を開く（現状のタップ動作） |

**対象画面（必須）:**

| 画面 | ストレージ | 詳細画面 | 一覧画面 |
|------|-----------|----------|----------|
| レイヤーⅠ 単語テスト | `VocabularyCheckStorage` | `VocabularyCheckDetailScreen` | `VocabularyCheckHistoryScreen` |
| レイヤーⅣ 採点 | `ScoringResultStorage` | `ScoringResultScreen` | `ScoringHistoryScreen` |
| レイヤーⅤ 発音 | `PronunciationCheckStorage` | `PronunciationCheckDetailScreen` | `PronunciationHistoryScreen` |
| レイヤーⅤ 長文音読 | 同上 | 同上 | 同上 |
| ダッシュボード「テスト結果」各行 | 同上（行ごと） | 同上 | 同上 |

- 保存済み結果が**0件**のとき: ボタンは従来どおり非表示（またはタップ／長押ししても何もしない — 現状の `showExample: false` を維持）
- 最新詳細を開いたあと一覧で削除して戻った場合: 呼び出し元が `_loadSavedResults` 等で再読込する（既存パターンを踏襲）

### C. 文言・ヘルプの更新

1. **ダブルタップのボタン操作説明** — 結果ボタン（`list_alt`）に `exampleHintTapText` / `exampleHintLongPressText` を付与（Step 7 の `ButtonActionHint` 基盤）
2. **＋ボタン長押しの操作手順** — レイヤーⅣの `_showUsageHelp` にモード切替・タートル手順を追記
3. **ヘルプ画面** — `lib/data/layer_help_tips.dart` / `gradus_l10n.dart` の `help.gradus.layer4.*` 等を更新

**対象外（触らない）:**

| 項目 | 理由 |
|------|------|
| レイヤーⅢのサイコロ動線 | ユーザー指定はⅣのみ |
| 採点・JSST・PREP・的中度・録音ロジック本体 | お題表示の入口だけ変える |
| 起動画面の `list_alt`（問題文一覧） | 結果ボタンではない |
| `TranscriptScreen`（成績証明書） | 別機能 |

---

## UX 仕様（全 Step で固定）

### ラピッド／タートル

```
【ラピッド】idle(🎲橙) ─tap─→ speaking ─→ counting ─→ idle
【タートル】idle(🎲) ─tap─→ idle(🔊, 問題文表示) ─tap─→ speaking ─→ counting ─→ idle
              └─ longPress ─→ モード切替（SnackBar または軽い確認で「ラピッド／タートル」表示）
```

- モード切替は **idle かつ 読み上げ・カウントダウン・採点中でない** ときだけ有効
- タートルで問題文表示済み（スピーカー待ち）の状態でモードをラピッドに切り替えた場合: **そのままスピーカータップで読み上げ**（表示済み問題文を捨てない）
- ラピッドに切り替えた直後の次回 idle からは橙サイコロ
- `fixedPrompt`（一覧から選ぶ）経路: idle アイコンは従来どおり `play_circle_fill`。**モード切替の長押しは play アイコンでも有効**（タートルなら play→スピーカー→読み上げ）
- リセット（`resetAttempt`）時: `drawnTopic` をクリアし idle に戻す（現状維持）

### 結果ボタン

- **タップ＝最新詳細** は `storage.loadAll()` の**先頭**（`JsonListStore` は新しい順）を使う
- **長押し＝一覧** は現行の `*_HistoryScreen.push` をそのまま使う
- ダッシュボード: `JSST` / `的中度` / `PREP` はいずれも**同じ** `ScoringResultStorage` — タップは同じ最新採点詳細、長押しは同じ採点一覧でよい
- `PrepLabelRow` に `onExampleLongPress` を追加し、`GhostPill.onLongPress` に接続（`reasonIcon` の長押しと同パターン）

### l10n キー（新規・更新の目安）

| キー（案） | 用途 |
|-----------|------|
| `レイヤーⅣ_モード_ラピッド` / `_タートル` | モード名・SnackBar |
| `レイヤーⅣ_モード_切替` | 長押しで切替した旨 |
| `レイヤーⅣ_使い方_モード切替` | ＋長押しシート・ヘルプ |
| `レイヤーⅣ_使い方_サイコロ_タートル` | タートル時の手順（ランダム用） |
| `レイヤーⅣ_問題文_使い方_開始_タートル` | タートル時（一覧用） |
| `採点結果_最新` / `採点結果_一覧` | ダブルタップヒント（Ⅳ） |
| `語彙力評価結果_最新` / `_一覧` | ダブルタップヒント（Ⅰ） |
| `発音チェック結果_最新` / `_一覧` | ダブルタップヒント（Ⅴ） |
| `help.gradus.layer4.tip*` | ヘルプカード更新 |

ja / en / vi すべてに追加・更新すること。

---

## 共通ルール（全 Step 共通・必ず守る）

1. **レイヤーⅢを壊さない** — `PracticeLayerScreenState` の変更は、デフォルトが現状挙動（ラピッド相当）になるようオプトインにする
2. **結果0件** — 詳細を開く導線は出さない（空リストで詳細画面に行かない）
3. **既存テスト** — `test/layers_test.dart` の結果アイコン・＋長押し・ダブルタップ系は期待値を更新する
4. **l10n** — `gradus_l10n.dart`（ja/en/vi）。`help_l10n_test.dart` がカバーする `help.gradus.*` は漏れなく
5. **スコープ** — その Step の受け入れ以外のリファクタはしない
6. **完了報告** — 変更ファイル一覧・手動確認手順・次 Step 前提を短く報告

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| Ⅳ本体 | `lib/views/layers/layer4_screen.dart` |
| 練習基底（抽選・TTS） | `lib/views/layers/practice_layer_screen.dart` |
| サイコロボタン | `lib/widgets/topic_speaker_timer_button.dart` |
| PREP 予約席 | `lib/widgets/prep_label_row.dart` |
| ルート集約 | `lib/navigation/app_routes.dart` |
| 設定 | `lib/main.dart`（`AppSettings`）等 |
| 採点詳細／一覧 | `scoring_result_screen.dart` / `scoring_history_screen.dart` |
| 語彙詳細／一覧 | `vocabulary_check_detail_screen.dart` / `vocabulary_check_history_screen.dart` |
| 発音詳細／一覧 | `pronunciation_check_detail_screen.dart` / `pronunciation_history_screen.dart` |
| ダッシュボード | `lib/views/dashboard/dashboard_screen.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart` / `lib/views/help/help_screen.dart` |
| l10n | `lib/localization/gradus_l10n.dart` |

---

## Step 1 — 設定：レイヤーⅣお題表示モードの永続化

### 目的
ラピッド／タートルを端末に保存し、読み書き API を用意する。

### 指示

1. `Layer4PromptRevealMode`（または同等名）enum を追加: `rapid`, `turtle`
2. `AppSettings`（または専用の小さな設定サービス）に getter/setter と SharedPreferences 永続化を追加。既定は **`rapid`**
3. 単体テスト: 既定値・保存・読み戻し

### 受け入れ

- [ ] enum と永続化 API がある
- [ ] 関連テスト緑
- [ ] `flutter analyze` 緑

---

## Step 2 — `TopicSpeakerTimerButton` 拡張

### 目的
長押し・idle 時の色・タートル用の「スピーカー待ち」表示を支える。

### 指示

1. `TopicSpeakerTimerButton` に追加:
   - `VoidCallback? onLongPress` — idle 時のみ有効（`GestureDetector.onLongPress`）
   - `Color? idleForegroundColor` — 非 null なら idle アイコン色（ラピッドの橙用）
   - `IconData? idleIconOverride` は既存 `idleIcon` で足りるなら不要
2. **タートル待ち:** `phase == idle` かつ `drawnTopic != null` かつ「読み上げ前」フラグが true のとき、表示アイコンを `Icons.volume_up` にする（呼び出し側が `idleIcon` を動的に渡す方式で可。ウィジェット内にビジネスロジックを入れない）
3. `test/` — 長押しコールバック・idle 色が反映される widget test

### 受け入れ

- [ ] レイヤーⅢの既存表示は変わらない（新パラメータはすべて optional）
- [ ] テスト緑

---

## Step 3 — `Layer4Screen`：タートル／ラピッドの抽選・読み上げ分岐

### 目的
タートル時は「表示」と「読み上げ」を2タップに分離。ラピッドは現状1タップ。

### 指示

1. `Layer4ScreenState` に状態を追加（例: `_awaitingSpeakAfterPreview`）
2. `onButtonTap` をオーバーライド（または `PracticeLayerScreenState` にフックを追加し、Ⅳだけ実装）:
   - **ラピッド:** 現行 `drawAndSpeak()` をそのまま
   - **タートル idle（未抽選）:** `pickTopic()` のみ → `drawnTopic` 設定 → `_awaitingSpeakAfterPreview = true` → **TTS は呼ばない**
   - **タートル idle（抽選済み・待ち）:** `drawAndSpeak` の TTS 以降と同じ処理を開始（`prepStage` はⅣでは無効のまま）
3. `resetAttempt` / カテゴリ変更 / タイマー変更時に `_awaitingSpeakAfterPreview` をクリア
4. `TopicSpeakerTimerButton` に渡す `idleIcon` / `idleForegroundColor`:
   - ラピッド idle: `Icons.casino`（または play）＋ **橙色**
   - タートル idle 未抽選: 通常色の casino / play
   - タートル idle 待ち: `Icons.volume_up`、通常色
5. `fixedPrompt` 経路も同じ分岐（play → タートルなら play → speaker → speak）

### 受け入れ

- [ ] ラピッドは現行と同じ1タップ動線
- [ ] タートルは2タップで読み上げ開始
- [ ] Ⅲの widget test / 手動でⅢが壊れていない

### 手動確認

- ランダム／一覧の両方でラピッド・タートルを切り替えて一連の採点まで到達できる

---

## Step 4 — サイコロ長押しでモード切替

### 目的
長押しでラピッド⇔タートルを切り替え、ユーザーにフィードバックする。

### 指示

1. `TopicSpeakerTimerButton.onLongPress` に、idle・非 busy 時のみ `_toggleRevealMode` を接続
2. 切替時: `AppSettings` に保存、`setState`、SnackBar 等でモード名表示（l10n）
3. 読み上げ中・カウントダウン中・採点中は長押し無効
4. widget test: 長押しで enum が切り替わる

### 受け入れ

- [ ] 長押しでモードが切り替わり永続化される
- [ ] ラピッド時サイコロが橙色

---

## Step 5 — `PrepLabelRow`：`onExampleLongPress`

### 目的
「例示」枠の結果ボタンに長押しを付けられるようにする。

### 指示

1. `PrepLabelRow` に `onExampleLongPress` / `exampleHintLongPressText` を追加（`reasonIcon` の長押しと同型）
2. `GhostPill` の `onLongPress` / `hintLongPressText` に接続
3. 既存画面の挙動は**未配線のまま変えない**（Step 7 で配線）

### 受け入れ

- [ ] API 追加のみで既存テストが緑

---

## Step 6 — `AppRoutes`：最新結果詳細を開くヘルパ

### 目的
各ストレージの先頭1件から詳細画面へ遷移する処理を1箇所に集約。

### 指示

1. `AppRoutes` に追加（名前は実装に合わせてよい）:
   - `openLatestScoringResult(BuildContext)` → 空なら return / SnackBar
   - `openLatestPronunciationCheck(BuildContext)`
   - `openLatestVocabularyCheck(BuildContext)`
2. 詳細画面への `MaterialPageRoute` は各 `*HistoryScreen` の `onItemTap` と**同じ**画面を開く
3. 単体テスト: ストレージに1件あるとき詳細 route が push される（モックまたは fake storage）

### 受け入れ

- [ ] 3種のヘルパがあり、空リストで落ちない

---

## Step 7 — レイヤー画面への結果ボタン配線

### 目的
Ⅰ・Ⅳ・Ⅴ・Ⅴ長文の `list_alt` をタップ＝最新詳細、長押し＝一覧にする。

### 指示

1. 各画面を更新:
   - `layer1_vocab_screen.dart`
   - `layer4_screen.dart`
   - `layer5_screen.dart`
   - `layer5_long_reading_screen.dart`
2. `onExampleTap` → `AppRoutes.openLatest*`（Step 6）
3. `onExampleLongPress` → 既存 `_openHistory`（一覧）
4. `exampleHintTapText` / `exampleHintLongPressText` を l10n キーで設定
5. 詳細から戻ったあと既存の `_loadSavedResults` / `_loadHasSavedChecks` を呼ぶ
6. `test/layers_test.dart` — 「タップで一覧」になっているテストを「タップで詳細」「長押しで一覧」に更新

### 受け入れ

- [ ] 4画面すべて新動線
- [ ] ダブルタップヒント文言が付いている
- [ ] 関連 widget test 緑

---

## Step 8 — ダッシュボードのテスト結果行

### 目的
ダッシュボードでもタップ＝最新詳細、長押し＝一覧。

### 指示

1. `_JudgmentRow`（または同等）に `onLongPress` を追加
2. 語彙／JSST／的中度／PREP／発音の各行に配線（採点系3行は同じストレージでよい）
3. `test/dashboard_screen_test.dart` を更新

### 受け入れ

- [ ] ダッシュボード5行（実質3ストレージ）が新動線

---

## Step 9 — ＋長押しシート・ヘルプ・l10n

### 目的
ユーザー向け説明文を実装に合わせて更新。

### 指示

1. `layer4_screen.dart` の `_showUsageHelp` にモード切替・タートル手順の `LayerHelpLine` を追加
2. `lib/data/layer_help_tips.dart` のレイヤーⅣセクションを更新
3. `gradus_l10n.dart` — 上記 UX 仕様のキーを ja/en/vi で追加・更新
4. `help.gradus.layer4.tip*` — サイコロモード・結果ボタンのタップ／長押しを反映
5. 必要なら `test/help_l10n_test.dart` / `test/help_screen_test.dart` 更新

### 受け入れ

- [ ] ＋長押しシート・ヘルプ画面に新機能が載っている
- [ ] 3言語ともキー欠けなし

---

## Step 10 — 総合テストと手動確認

### 指示

1. `flutter test` で変更範囲のテストを実行し、失敗があれば修正
2. `flutter analyze` 緑
3. 手動チェックリストを完了報告に含める:
   - [ ] Ⅳラピッド: 橙サイコロ・1タップで読み上げ
   - [ ] Ⅳタートル: 2タップ・解答例を読んでから読み上げ可能
   - [ ] Ⅳ長押しでモード切替・再起動後も維持
   - [ ] Ⅰ/Ⅳ/Ⅴ 結果ボタン タップ＝詳細、長押し＝一覧
   - [ ] ダッシュボード同様
   - [ ] 結果ボタンのダブルタップでヒント表示

---

## Step 11 — コードレビュー（別ファイル）

実装完了後、`docs/prompts/layer4-dice-modes-and-result-buttons-review.md` の観点で自己点検し、問題があれば修正する。  
レビュー結果を同ファイルに追記してよい。
