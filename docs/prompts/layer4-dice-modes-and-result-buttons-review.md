# レビュー結果：レイヤーⅣサイコロモード ＋ 結果ボタン動線変更

**再レビュー日:** 2026-08-30（実装後コードベースを再点検）

対象: `docs/prompts/layer4-dice-modes-and-result-buttons.md` で計画した機能一式。  
Claude Code への指示例:

> `docs/prompts/layer4-dice-modes-and-result-buttons-review.md` の「残タスク」をやって

---

## 実装状況サマリー

| 機能 | 状態 | 主な根拠 |
|------|------|----------|
| ラピッド／タートル enum・永続化 | ✅ 完了 | `lib/models/layer4_prompt_reveal_mode.dart`, `AppPreferences` |
| サイコロ長押しでモード切替 | ✅ 完了 | `Layer4ScreenState._toggleRevealMode()` |
| タートル2タップ／ラピッド1タップ | ✅ 完了 | `_awaitingSpeakAfterPreview`, `onButtonTap` 分岐 |
| ラピッド時の橙サイコロ | ✅ 完了 | `_idleForegroundColor` → `palette.cardAccent` |
| 結果ボタン タップ＝最新詳細 | ✅ 完了 | `AppRoutes.openLatest*` + 各画面 `_openLatestResult` |
| 結果ボタン 長押し＝一覧 | ✅ 完了 | `PrepLabelRow.onExampleLongPress` + `_openHistory` |
| ダッシュボード行のタップ／長押し | ✅ 完了 | `dashboard_screen.dart` |
| ダブルタップヒント（結果ボタン） | ✅ 完了 | `exampleHintTapText` / `exampleHintLongPressText` |
| Ⅳの＋長押しシート・help.layer4 | ✅ ほぼ完了 | `_showUsageHelp`, `help.gradus.layer4.tip5–6` |
| ダッシュボード help.tip3 | ✅ 完了 | P0 で更新済み |
| Ⅰ・Ⅴ help の結果ボタン説明 | ❌ **未追加** | Ⅳ tip6 と対になる tip が無い |
| Ⅳ/V の結果ボタン widget test | ❌ **不足** | Ⅰのみ `layers_test.dart` で検証 |

**結論:** コア機能は実装済み。残りは**ヘルプ文言の陳腐化・コメント修正・テスト補強・小さなルート統一**が中心。

---

## 1️⃣ 作成者の意図に反して重複している機能

### 要対応（整理推奨）

| 重複 | 現状 | 推奨 |
|------|------|------|
| **保存直後プレビュー vs 詳細画面** | Ⅰ: `_VocabResultDialog`（`layer1_vocab_chrome_ai.dart`）。Ⅴ短・長文: 同一の `_showResultDialog` + `AlertDialog` が `layer5_screen.dart` と `layer5_long_reading_screen.dart` に**コピペ** | Ⅴは `showPronunciationResultPreviewDialog()` を1ファイルに抽出。Ⅰは「保存直後フィードバック」として残すなら、表示本体を `VocabularyCheckDetailScreen` と共有するか、ヘルプで「保存直後＝プレビュー／ボタン＝詳細」と役割を明示 |
| **`_openHistory` / `_openLatestResult` の6箇所パターン** | Ⅰ・Ⅳ・Ⅴ・Ⅴ長文・ダッシュボードで同型 | 一覧は `AppRoutes.open*History`、最新は `openLatest*` で既に共通化済み。**Ⅳだけ** `_openHistory` が `Navigator.push(ScoringHistoryScreen)` 直書き（他は `*.push` または `AppRoutes`）— `AppRoutes.openScoringHistory` に揃える |
| **ダッシュボード JSST／的中度／PREP 3行** | いずれも同じ `ScoringResultStorage` | **意図的重複**（指標別入口）。タップ／長押しの実装は正しい |

### 問題なし（意図的な共有）

| 項目 | 理由 |
|------|------|
| 3種の `*HistoryScreen` | `HistoryListScaffold` + `HistoryListCard` で一覧UIは共通化済み |
| `Layer2SampleAnswerMixin`（Ⅱ・Ⅳ） | 模範解答ロジックの二重実装なし |
| `ChromeAiSubmitMixin` + `_ChromeAiPendingKind` | 解答例と PREP・的中度の待ち状態分離済み |
| `PracticeLayerScreenState`（Ⅲ・Ⅳ） | タイマー・TTS・録音の共有は意図的。タートル分岐はⅣのみ |
| 問題文詳細画面×5 | レイヤーごとに PREP 枠の意味が異なる（Ⅲ「例示」＝PREP編集、Ⅳ「例示」＝採点結果） |
| `DashboardSummaryService`（ダッシュボード＋成績証明書） | 計算ロジック共有は意図的。UI目的は別 |

---

## 2️⃣ ゾンビ化している機能

### 要修正（文言・コメントの死骸）

| 項目 | 場所 | 内容 |
|------|------|------|
| **ダッシュボード help** | `gradus_l10n.dart` `help.gradus.dashboard.tip3`（ja/en/vi） | 「各行をタップすると**履歴**が開く」→ 実装は**タップ＝最新詳細・長押し＝一覧** |
| **採点後コメント** | `layer4_screen.dart` L465 `_evaluateNow` | 「詳細は『例示』枠の**一覧**から開く」→ タップ＝最新詳細に更新すべき |
| **語彙結果アイコンの doc** | `layer1_vocab_screen.dart` L1304–1305 | 「アイコンから**履歴**を開く（`_openHistory`）」→ タップ＝最新・長押し＝一覧に更新 |
| **テストコメント** | `layers_test.dart` L1031 | 「一覧導線」→「最新詳細／一覧（長押し）」に更新可 |

### 仕様と計画書の差異（作者確認）

| 項目 | 計画書 | 実装 | 判断 |
|------|--------|------|------|
| **既定モード** | プロンプト Step 1 は `rapid` 既定 | `AppPreferences` コメント「既定は**タートル**」、`orElse: () => turtle` | 実装意図は「初回ユーザーに問題文確認を促す」。ユーザー原文はラピッド＝「現在の動線」だが既定は明記なし。**作者がタートル既定を意図したなら OK**；ラピッド既定に戻すなら `orElse` と help を修正 |

### 残存するが防御的（削除不要）

| 項目 | 説明 |
|------|------|
| `Layer4ScreenState.pickTopic()` → `super.pickTopic()`（`TopicService`） | ランダムは先に `_drawnPrompt` を確定するため通常未到達。防御的フォールバック |
| `TopicService` 全体 | Ⅲランダム・取り込み・バックアップで依然使用。Ⅳからは外れている |
| `TopicCategory.random` | 取り込み専用。ゾンビではない |

---

## 3️⃣ 作成者の意図に反して動線が冗長的な機能

### 解消済み（今回の改修で改善）

| 以前 | 現在 |
|------|------|
| `list_alt` タップ＝常に一覧 | タップ＝最新詳細、長押し＝一覧 ✅ |
| サイコロ1タップのみ（模範解答を読む猶予なし） | タートルモードで2タップ ✅ |

### まだ残る冗長（許容 or 将来整理）

| 冗長 | 詳細 | 推奨 |
|------|------|------|
| **保存直後ダイアログ → 同じ結果をボタンから再閲覧** | Ⅰ・Ⅴで保存直後にダイアログ、続けて結果ボタンでも詳細へ行ける | UXとして「その場確認」は有用。詳細画面へ直行に統一するかは作者判断 |
| **Ⅳは保存直後ダイアログなし** | 採点後はボタンのみ | Ⅰ・Ⅴと非対称だが、Ⅳは「採点が主目的」なので意図的と解釈できる。help で明示するとよい |
| **ダッシュボード中・高・PREP 3タップ先が同一** | 同じ最新採点詳細 | 指標ラベルごとの入口として許容。help.tip3 だけ直せば十分 |

---

## 4️⃣ その他（アーキテクチャ・リスク・テスト）

### アーキテクチャ上の懸念

1. **Ⅲランダム vs Ⅳランダムの抽選元不一致**  
   - Ⅲ: `TopicService.drawRandom`（題材バンク）  
   - Ⅱ・Ⅳ・Ⅴ: `QuestionPromptService`（構造化問題文）  
   - 同カテゴリでも**別テキスト**が出る可能性あり。意図的移行途中なら help に書くか、Ⅲも `QuestionPromptService` へ寄せる（中〜大規模改修）。

2. **ⅤとⅣの「サイコロ→第2アイコン」**  
   - 見た目は似るが Ⅴは `PronunciationMicButton`、Ⅳタートルは `TopicSpeakerTimerButton` の idle 差し替え。**共通化しない**のが正しい（録音フローが別）。

3. **`openLatest*` の空リスト**  
   - 何もしない（サイレント）。ボタンは `showExample: false` で非表示の想定。ダッシュボード行はデータなしでも表示される → タップ時 SnackBar があると親切（未実装）。

### テストギャップ

| テスト | 状態 |
|--------|------|
| `test/layer4_prompt_reveal_mode_test.dart` | 永続化 ✅ |
| `test/question_prompt_layer4_test.dart` | モード切替・タートル2タップ ✅ |
| `test/app_routes_open_latest_test.dart` | 3種の openLatest ✅ |
| `test/prep_label_row_test.dart` | tap / longPress 独立 ✅ |
| `test/dashboard_screen_test.dart` | タップ詳細・長押し一覧 ✅ |
| `test/layers_test.dart` L3699+ | **Ⅰのみ** 結果ボタン統合テスト |
| Ⅳ `list_alt` タップ→`ScoringResultScreen` | **無し** |
| Ⅴ / Ⅴ長文 結果ボタン統合 | **無し**（表示テストのみ） |
| `help_l10n_test.dart` | キー存在は検証。**tip3 の文言内容は未検証**のため陳腐化に気づけない |

### l10n ギャップ

| キー | 状態 |
|------|------|
| `help.gradus.layer4.tip5–6` | ✅ モード切替・結果ボタン |
| `help.gradus.dashboard.tip3` | ❌ 古い |
| `help.gradus.layer1.tip4` | ❌ 語彙結果ボタンのタップ／長押しなし |
| `help.gradus.layer5.tip*` | ❌ 発音結果ボタンのタップ／長押しなし（tip6 追加 or tip3 拡張が自然） |
| `レイヤーⅣ_使い方_採点結果` 等の＋長押しシート用キー | ✅ 更新済み |

---

## 残タスク（優先度順）

### P0 — ユーザー向け文言（すぐ直すべき）

1. **`help.gradus.dashboard.tip3`**（ja/en/vi） — ✅ 2026-08-30 更新済み
2. **`help.gradus.layer1.tip4` に1行追加** — ✅ 2026-08-30 更新済み
3. **`help.gradus.layer5.tip6` 追加** — ✅ 2026-08-30 更新済み（`layer_help_tips.dart` も追従）

**既定モード:** タートル（`AppPreferences` の `orElse: turtle`）— 変更なし

### P1 — コードの一貫性（低リスク）

4. `Layer4ScreenState._openHistory()` → `AppRoutes.openScoringHistory(context)` — ✅ 2026-08-30
5. コメント修正（`layer4_screen.dart`, `layer1_vocab_screen.dart`, `scoring_result_screen.dart`, `layers_test.dart`）— ✅ 2026-08-30
6. `showPronunciationResultPreviewDialog`（`lib/widgets/pronunciation_result_preview_dialog.dart`）へ抽出 — ✅ 2026-08-30

### P2 — テスト

7. `layers_test.dart` にⅣ結果ボタン統合テスト — ✅ 2026-08-30
8. Ⅴ結果ボタン統合テスト — ✅ 2026-08-30
9. `help_l10n_test.dart` で `dashboard.tip3` の内容 assert — ✅ 2026-08-30

### P3 — 中長期（別プロンプト向け）

10. レイヤーⅢランダムを `QuestionPromptService` に統一
11. 保存直後ダイアログと詳細画面の表示統合（作者判断）
12. `openLatest*` 空時の SnackBar（ダッシュボード向け）

---

## 実装後チェックリスト

- [x] ラピッド／タートル永続化・長押し切替
- [x] タートル2タップ／ラピッド1タップ・橙サイコロ
- [x] Ⅰ/Ⅳ/Ⅴ/ダッシュボード 結果ボタン新動線
- [x] `PrepLabelRow.onExampleLongPress`
- [x] `AppRoutes.openLatest*`
- [x] `help.gradus.dashboard.tip3` 更新
- [x] `help.gradus.layer1` / `layer5` 結果ボタン説明
- [x] 陳腐化コメント修正（Ⅳ `_evaluateNow`、Ⅰ doc）
- [x] Ⅳ `_openHistory` → `AppRoutes`
- [x] Ⅳ/V結果ボタン widget test

### 実装後の追記

_2026-08-30: P0〜P2 完了。残りは P3（中長期）のみ。_
