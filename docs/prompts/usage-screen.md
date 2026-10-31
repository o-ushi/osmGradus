# 使い方画面（Chrome AI のコピーボタン案内）

このファイルは Claude Code 向けの実装指示書です。

## Claude への指示テンプレ

まとめて進めるとき:

```
docs/prompts/usage-screen.md の各 Step を順番に実行して
```

1 Step ずつ進めるとき:

```
docs/prompts/usage-screen.md の Step N をやって
```

「各 Step を順番に実行して」と指示された場合は、Step 1 から最後まで順に実施する。  
各 Step の受け入れを満たし、`flutter analyze`（と当該テスト）が通ってから次へ進む。  
途中で赤ならそこで止めて直す。大きな設計変更は提案のみ。

1 Step = 1 セッションでも、1 セッションで全 Step でもよい。粒度は「受け入れを飛ばさない」こと。

---

## 機能概要（ユーザーの狙い）

Chrome AI モードにジャンプして戻ってきてもペーストできない、という問い合わせが来た。  
原因は、画面下の**コピーボタン（重なった2つの四角）**をタップしていなかったこと。  
最初にきちんと教えないと、同じトラブルが続出する。

```
スタートアップ（ブランド案内）
  →「はじめる」
  → 使い方画面（コピーボタン＋操作の基本）
  →「ホーム画面へ」
  → ホーム（レイヤー一覧）
```

- スタートアップから「各画面の＋ボタン長押しで…」（`起動_操作ヒント`）を**削除**する  
  （ホーム画面下部の同じ文言は残す）
- 使い方画面に、スタートアップと同型の「次回から表示しない」と「ホーム画面へ」を置く
- 設定画面で、スタートアップと同様に使い方画面の表示／非表示を切り替えられる

---

## 動線（これが仕様の正本。推測で変えない）

用語:

| 画面上のチェック | 内部フラグ | 意味 |
|------------------|------------|------|
| 「次回から表示しない」OFF | `showXxxScreen == true` | まだ出す |
| 「次回から表示しない」ON（確定後） | `showXxxScreen == false` | 出さない |

チェックはボタンを押したときに初めて保存する（スタートアップと同じ）。  
チェックした瞬間にフラグを書き換えない。

### A. コールドスタート（アプリ起動）

| `showStartupScreen` | 表示 |
|---------------------|------|
| true（既定） | スタートアップ。使い方はまだ出さない |
| false | **ホームのみ**。使い方フラグが true でも出さない |

### B. スタートアップで「はじめる」

今この場でスタートアップのチェックを ON にしても、**このタップの行き先は使い方フラグだけを見る**。

| `showUsageScreen` | 「はじめる」の着地 |
|-------------------|-------------------|
| true（既定） | 使い方画面 |
| false | ホーム |

スタートアップのチェック ON で「はじめる」→ 今セッションは使い方（usage が true なら）を出す。  
**次回**コールドスタートは A によりホーム直通（スタートアップも使い方も出さない）。

### C. 使い方で「ホーム画面へ」

チェック ON なら `showUsageScreen = false` を保存してからホームへ。  
OFF ならフラグは true のままホームへ。

### D. ホームで左端からの右スワイプ

| `showStartupScreen` | `showUsageScreen` | 着地 |
|---------------------|-------------------|------|
| false | （不問） | **動かない** |
| true | true | **使い方画面**（スタートアップではない） |
| true | false | **スタートアップ画面** |

既存どおり、設定のスタートアップが OFF なら `LaunchScreen` はスワイプラッパー自体を付けない。

### 使い方画面からの戻り

- 出口は「ホーム画面へ」ボタンのみ
- 使い方 → スタートアップへ戻るスワイプ／戻るボタンは**作らない**（指定なし。読み終わる前に消えないようにする）

### 設定トグル

- スタートアップと同じく、ON にしても**今のコールドスタート重ね表示は出し直さない**
- スワイプ可否・スワイプ先は `appSettings` の**現在値**を見る（設定を切れば即座に効く。既存スタートアップと同じ）

---

## 共通ルール（全 Step 共通・必ず守る）

1. **Navigator で使い方を push しない** — `StartupScreen` と同じく `AppRootShell` の兄弟切替。`MainShell` の `maintainState` を壊さない。
2. **既存のスタートアップ設定・セッション変数の意味を変えない** — `showStartupScreen` の既定 true、チェック時だけ false、同プロセスでは初期重ねを出し直さない、は維持。
3. **l10n** — ユーザー向け文言は `gradus_l10n.dart`。ja / en / vi を揃える。キーだけ書いて訳を空にしない。
4. **スコープ外を触らない** — その Step の受け入れ以外のリファクタ・ドキュメント追加はしない（最終 Step のレビュー修正は除く）。Google スライド操作マニュアルは対象外。
5. **ホームの `起動_操作ヒント` は残す** — 消すのはスタートアップ画面の表示だけ。l10n キー自体はホームが使うので削除しない。
6. **完了報告** — 変更ファイル一覧・手動確認手順・次 Step への前提を短く報告する。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| ルート切替 | `lib/views/app_root_shell.dart` |
| スタートアップ | `lib/views/startup_screen.dart` |
| ホーム（レイヤー一覧） | `lib/views/launch_screen.dart` |
| 設定 | `lib/views/settings/tts_settings_screen.dart` |
| 設定永続化 | `lib/services/app_preferences.dart` |
| 設定通知 | `lib/notifiers/app_settings.dart` |
| l10n | `lib/localization/gradus_l10n.dart` |
| ヘルプ | `lib/views/help/help_screen.dart` / `lib/data/layer_help_tips.dart` |
| スタートアップテスト | `test/startup_screen_test.dart` |
| 設定テスト | `test/tts_settings_screen_test.dart` |
| 案内画像（配置済） | `assets/images/chrome_ai_copy_button.png` |
| pubspec 資産 | `pubspec.yaml` の `flutter.assets` |

案内画像はリポジトリに配置済み。**Chrome AI の操作バー（コピー・共有・評価・メニュー）に、左端のコピーへ赤い矢印と TAP! を付けた図**（約 657×479）。  
全画面スクショや手描き赤丸、2アイコンだけの切り抜きは使わない。無い場合だけ会話添付の同図を同じパスへコピーする。新規撮影しない。

---

## UX 仕様（全 Step で固定）

### スタートアップから消すもの

`StartupScreen` の `'起動_操作ヒント'.tr(lang)` とその `SizedBox`。  
説明文 `'スタートアップ_説明'`・チェック・「はじめる」・国旗はそのまま。

### 使い方画面の中身（上から）

スタートアップと同じ `palette.scene`、`SafeArea`、横パディング、右上 `LanguageFlagButton`、縦スクロール。  
アプリアイコンと「osmGradus」タイトルは**出さない**（ブランド画面と役割を分ける）。

1. 見出し「使い方」
2. 案内画像 `assets/images/chrome_ai_copy_button.png`（操作バー＋赤い矢印＋ TAP!。横幅はパディング内いっぱいでよい、`BoxFit.contain`、白地＋角丸）。`semanticLabel` を付ける
3. コピー手順（素人向け・優しく。**赤い矢印と TAP! が指す、左端の重なった2つの四角**と本文で言う。手描き赤丸には触れない）
4. ＋長押しの説明
5. ダブルタップの説明
6. 「次回から表示しない」チェック（見た目はスタートアップ踏襲。2画面だけなので共通ウィジェット化は必須ではない）
7. 「ホーム画面へ」ボタン（スタートアップの「はじめる」と同型 `FilledButton`）

### 推奨 l10n（キー名は既存スタイルに合わせて可。意味は変えない）

**ja**

| キー | 文言 |
|------|------|
| `使い方_タイトル` | `使い方` |
| `使い方_コピー本文` | `ChromeのAIモードで答えが出たら、画面の下のほうにあるコピーボタンをタップしてください。下の画像の赤い矢印と TAP! が指している、左端の重なった2つの四角です。\n\nこのボタンを押さずにアプリへ戻ると、貼り付けできません。コピーできたら、osmGradusに戻ってください。` |
| `使い方_プラス長押し` | `各画面の＋ボタンを長押しすると、その画面の操作方法が表示されます。` |
| `使い方_ダブルタップ` | `ボタンをダブルタップすると、タップしたときと長押ししたときの動作がポップアップで表示されます。` |
| `使い方_コピー画像_説明` | `Chrome AIモードのコピーボタン（赤い矢印と TAP!）` |
| `ホーム画面へ` | `ホーム画面へ` |
| `使い方画面` | `使い方画面` |
| `使い方画面_説明` | `Chrome AIのコピー方法や、＋の長押し・ダブルタップなどの基本操作を表示します` |

**en**

| キー | 文言 |
|------|------|
| `使い方_タイトル` | `How to use` |
| `使い方_コピー本文` | `When Chrome’s AI Mode shows an answer, tap the Copy button near the bottom of the screen — the leftmost icon of two overlapping squares, marked TAP! with a red arrow.\n\nIf you skip this and return to the app, you won’t be able to paste. After copying, come back to osmGradus.` |
| `使い方_プラス長押し` | `Long-press the + button on each screen to see how to use it.` |
| `使い方_ダブルタップ` | `Double-tap a button to see what tap and long-press do.` |
| `使い方_コピー画像_説明` | `Copy button in Chrome AI Mode (red arrow and TAP!)` |
| `ホーム画面へ` | `Go to Home` |
| `使い方画面` | `How-to screen` |
| `使い方画面_説明` | `Show how to copy from Chrome AI, long-press +, and double-tap for button hints` |

**vi**

| キー | 文言 |
|------|------|
| `使い方_タイトル` | `Cách dùng` |
| `使い方_コピー本文` | `Khi AI Mode của Chrome hiện câu trả lời, hãy chạm nút Sao chép ở phía dưới màn hình — biểu tượng ngoài cùng bên trái gồm hai hình vuông chồng lên nhau, có mũi tên đỏ và chữ TAP!.\n\nNếu quay lại ứng dụng mà chưa chạm nút này, bạn sẽ không dán được. Sau khi sao chép, hãy quay lại osmGradus.` |
| `使い方_プラス長押し` | `Nhấn giữ nút + trên mỗi màn hình để xem cách sử dụng.` |
| `使い方_ダブルタップ` | `Nhấn đúp một nút để xem thao tác khi chạm và khi nhấn giữ.` |
| `使い方_コピー画像_説明` | `Nút sao chép trong Chrome AI Mode (mũi tên đỏ và TAP!)` |
| `ホーム画面へ` | `Về màn hình chính` |
| `使い方画面` | `Màn hình hướng dẫn` |
| `使い方画面_説明` | `Hiện cách sao chép từ Chrome AI, nhấn giữ +, và nhấn đúp để xem gợi ý nút` |

「次回から表示しない」は既存キーを再利用する。

設定のセクション見出しは、2スイッチを並べるなら `案内` / `Onboarding` / `Màn hình giới thiệu` へのリネームを推奨。  
見出しを「スタートアップ画面」のまま残すなら、2行目が使い方でも矛盾しない範囲でよい。

---

## Step 1 — 永続化フラグ ＋ 設定スイッチ

### 目的

使い方画面の表示／非表示を、スタートアップと同じ仕組みで保存・設定できるようにする。画面本体はまだ作らない。

### 指示

1. `AppPreferences`
   - キー例: `osmGradus.showUsageScreen`
   - getter 既定 **true**（未設定＝初回は出す）
   - setter は `showStartupScreen` と同型
2. `AppSettings`
   - `showUsageScreen` の get/set。値が変わったときだけ `notifyListeners`
3. `TtsSettingsScreen`
   - スタートアップのカードに `SettingsItemDivider` ＋ `SettingsSwitchRow`（使い方画面）を追加
   - ON/OFF は即 `appSettings.showUsageScreen` に保存（スタートアップスイッチと同じ）
4. 初期化（`AppReset.resetToFactoryDefaults` の `prefs.clear()`）で未設定に戻れば既定 true になる。個別処理は不要
5. テスト
   - 既定 true
   - setter で false になり再読込でも false
   - 設定画面にスイッチが出て、トグルで値が変わる  
     （`test/tts_settings_screen_test.dart` に足すか、設定／prefs の既存テストに足す）

### 受け入れ

- [ ] `showUsageScreen` 未設定時 true
- [ ] 設定画面で切り替えられる
- [ ] スタートアップのフラグ・UI を壊していない
- [ ] `flutter analyze` 当該テストが通る

---

## Step 2 — 使い方画面 UI ＋ スタートアップから操作ヒント削除 ＋ 画像資産

### 目的

教えたい内容を、スタートアップと同じトーンの画面として描く。動線配線は次 Step。

### 指示

1. **新規** `lib/views/usage_screen.dart`（名前は既存スタイルに合わせて可）
   - API は `StartupScreen` に合わせる: `onContinue: ValueChanged<bool>`（`dontShowAgain`）
   - UX 仕様どおりの中身。国旗で言語が切り替わること（`appSettings` を listen）
2. `StartupScreen` から `'起動_操作ヒント'` の Text を削除
3. `pubspec.yaml` の `flutter.assets` に `assets/images/chrome_ai_copy_button.png` を追加
4. `gradus_l10n.dart` に上記キーを ja/en/vi で追加
5. 画面単体テスト（`test/usage_screen_test.dart`）
   - タイトル、コピー本文、＋長押し、ダブルタップ、チェック、「ホーム画面へ」、画像（`Image` / asset パス）がある
   - スタートアップ単体（または `OsmGradusApp` 初回）に `起動_操作ヒント` が**出ない**
   - チェックして「ホーム画面へ」で `onContinue(true)`、未チェックで `onContinue(false)`
   - この Step では `AppRootShell` 全体の着地までは必須にしない（Step 3）

`test/startup_screen_test.dart` の「初回起動では…`起動_操作ヒント`」アサーションは、この Step でスタートアップ側から外す（ヒント削除と同時にテストが赤くなるため）。

### 受け入れ

- [ ] 使い方画面が仕様の説明をすべて表示する
- [ ] スタートアップに `起動_操作ヒント` が無い
- [ ] ホーム（`LaunchScreen`）には `起動_操作ヒント` が残っている
- [ ] 画像がアセットとして載る
- [ ] ja/en/vi が揃っている
- [ ] `flutter analyze` 当該テストが通る

---

## Step 3 — `AppRootShell` / `LaunchScreen` の動線配線

### 目的

仕様の A〜D どおりに画面が切り替わる。

### 指示

1. `AppRootShell`
   - `_showingUsage` を追加。初期値は **false**（起動直後はスタートアップまたはホームだけ）
   - 表示条件:
     - `_showingStartup` → `StartupScreen`
     - else `_showingUsage` → `UsageScreen`
     - else `!_showingMainShell` → `LaunchScreen`
     - `MainShell` の `Visibility(maintainState: true)` は現状維持
   - `_finishStartup(dontShowAgain)`:
     - 既存どおり必要なら `showStartupScreen = false`
     - `_showingStartup = false`
     - **`showUsageScreen` が true なら `_showingUsage = true`、false ならホーム**
   - `_finishUsage(dontShowAgain)`:
     - 必要なら `showUsageScreen = false`
     - `_showingUsage = false`（ホームへ）
   - ホームからのスワイプ:
     - `showStartupScreen == false` なら何もしない（LaunchScreen 側でもガード）
     - `showUsageScreen == true` なら `_showingUsage = true`
     - それ以外（startup ON かつ usage OFF）なら既存どおり `_showingStartup = true`
2. `LaunchScreen`
   - スワイプ有効条件は **`showStartupScreen` のみ**（usage だけではラッパーを付けない＝仕様 D）
   - コールバック名が「必ずスタートアップを出す」という意味なら、`onSwipeFromHome` 等へリネームしてコメントを直す。挙動の分岐は Root 側
3. 既存テストが「はじめる → すぐホーム」を前提にしている箇所を直す
   - 特に `test/startup_screen_test.dart`
   - 既定では「はじめる」の次は使い方。「ホーム画面へ」を押してからホームを assert する
   - 右スワイプで「はじめる」が出るテストは、usage が true のままだと**使い方**が正しい着地。スタートアップに戻すケースは usage を false にして別テストにする
4. `flutter analyze`

この Step で動線の回帰が赤のまま次へ行かない。足りないケースは Step 4 で厚くてよいが、既存の赤はここで消す。

### 受け入れ

- [ ] 仕様 A〜D がコード上の分岐と一致する
- [ ] 既存の「スタートアップ OFF なら起動でホーム」「MainShell 状態保持」が残る
- [ ] スタートアップ関連の既存テストが新しい着地に更新され、通る
- [ ] `flutter analyze` が通る

---

## Step 4 — 動線のウィジェットテストを厚くする

### 目的

トラブル再発防止のため、表の組み合わせをテストで固定する。

### 指示

`test/startup_screen_test.dart` を拡張するか、`test/usage_screen_test.dart` にルート結合テストを追加する。  
スワイプは既存スタートアップテストと同じ左端ジェスチャでよい。

必須ケース:

1. 初回（両方 true）: 起動 → スタートアップ → はじめる → 使い方 → ホーム画面へ → ホーム
2. スタートアップでチェック ON → はじめる → **このセッションは使い方**（usage true）→ ホーム画面へ → 再マウント → **ホーム直通**（スタートアップも使い方も出ない）
3. スタートアップはチェックしない、使い方でチェック ON → ホーム → 再マウント → スタートアップは再表示、はじめる → **ホーム**（使い方スキップ）
4. 両方チェックしない → 再マウント → またスタートアップ
5. ホーム右スワイプ（startup true, usage true）→ **使い方**（スタートアップの「はじめる」は出ない）
6. ホーム右スワイプ（startup true, usage false）→ **スタートアップ**
7. ホーム右スワイプ（startup false, usage は true でも）→ **動かない**
8. 設定でスタートアップ OFF（既存）に加え、使い方スイッチの OFF がスワイプ先に効くこと
9. 言語国旗で使い方の本文が切り替わる（スタートアップの国旗テストに準拠）

テスト言語は既存どおり `vi` 既定＋必要なら ja/en でよい。

### 受け入れ

- [ ] 上記 1〜9 がテストになっている
- [ ] `flutter test test/startup_screen_test.dart test/usage_screen_test.dart test/tts_settings_screen_test.dart` が通る

---

## Step 5 — ヘルプ・設定文言の整合

### 目的

ヘルプが「使い方画面が無い世界」のまま残らないようにする。長くしない。

### 指示

1. `help.gradus.overview` か `help.gradus.gesture` に、Chrome AI では下のコピーボタン（重なった四角）を押してから戻る、を **1 tip** 足す（ja/en/vi）
2. `help.gradus.settings` に、設定でスタートアップと使い方の表示を切り替えられる旨を短く足すか、既存 tip を更新する
3. ＋長押し／ダブルタップは `help.gradus.gesture.tip3` と使い方本文で矛盾しないこと（片方だけ古い説明にしない）
4. 必要なら `test/help_screen_test.dart` に新セクション／新キーが見えることの最小テスト

操作マニュアル（Google スライド）は触らない。

### 受け入れ

- [ ] ヘルプにコピーボタンの案内がある
- [ ] 設定ヘルプが新しいスイッチと矛盾しない
- [ ] ja/en/vi
- [ ] `flutter analyze` 当該テストが通る

---

## Step 6 — レビュー（重複・ゾンビ・冗長）

### 目的

実装後のコードを、ユーザー指定の観点で点検し、安全な修正は同セッションで入れる。

### 観点（必須）

① **重複** — 同じ説明・同じフラグ判定・同じチェック UI が二系統になって食い違っていないか。  
　意図的な残置（ホーム下部の一行ヒントと使い方本文、など）は理由を書く。

② **ゾンビ** — 使われない l10n、リネーム漏れの `onShowStartup`、スタートアップに残った操作ヒント、古いテスト名（スワイプでスタートアップに戻ると書いてあるのに使い方に着地する）など。

③ **冗長な動線** — 使い方のあとに同じ内容のダイアログが重なる、スワイプとボタンで矛盾する着地、startup OFF なのに usage だけコールドスタートで出る、など仕様逸脱。

加えて既存レビューと同じく見てよいもの:

④ ヘルプ／設定ラベルと実装の不一致  
⑤ ＋長押し・ダブルタップの案内が、使い方・ホーム一行・ヘルプで食い違う

### 指示

1. Step 1〜5 後のコードを上記で点検する
2. 明らかで安全な修正は同セッションで直す。大きな設計変更は提案のみ
3. 結果を `docs/prompts/usage-screen-review.md` に短くまとめる（各項目は **修正済 / 意図的残置 / 確認 / 提案のみ**）
4. `flutter analyze` と関連テストを通す

### 受け入れ

- [ ] レビュー文書がある
- [ ] 致命的な重複・ゾンビ・冗長動線・文言不整合が残っていない（残すなら意図的残置理由あり）

---

## Step 依存関係

```
Step 1 フラグ＋設定
  → Step 2 使い方 UI＋スタートアップからヒント削除
    → Step 3 Root / Launch 動線
      → Step 4 結合テスト
        → Step 5 ヘルプ
          → Step 6 レビュー
```

Step 2 と Step 3 は密接なため、1 セッションで続けてよい。その場合も受け入れは両方満たすこと。

---

## 使い方（ユーザー → Claude Code）

```
docs/prompts/usage-screen.md の各 Step を順番に実行して
```

または:

```
docs/prompts/usage-screen.md の Step 1 をやって
```

完了報告を確認してから Step 2 へ。レビューは必ず **Step 6** で実施する。

レビュー結果の確認だけしたいとき:

```
docs/prompts/usage-screen.md の Step 6 をやって
```

（Step 1〜5 未完了なら、先に不足 Step を実施してから Step 6）

---

## 設計メモ（現状との差分）

| 現状 | 本改修 |
|------|--------|
| 起動: スタートアップ → はじめる → ホーム | 起動: スタートアップ → はじめる → 使い方 → ホーム |
| ホーム右スワイプ: スタートアップ（設定 ON 時） | usage ON なら使い方、OFF ならスタートアップ。startup OFF なら動かない |
| スタートアップに＋長押しの一行 | スタートアップから削除。使い方本文へ移す。ホーム下部の一行は残す |
| 設定はスタートアップスイッチのみ | 使い方スイッチを追加（既定 ON） |
| Chrome コピー操作は各機能画面のその場案内のみ | 初回（およびスワイプ）で共通の使い方画面でも教える |

### 意図的に残すもの（レビューで「重複」扱いしない）

- **ホーム下部の `起動_操作ヒント`:** 使い方をスキップした人・日常のリマインド用。スタートアップからは消す
- **各画面の＋長押しシート／ダブルタップヒント:** 使い方画面は「そういう操作がある」と教えるだけ。各画面の詳細シートは残す
- **Chrome 往復中の既存コピー案内**（貼り付け待ちアイコン、`SampleAnswerPasteSheet` 等）: 失敗した人のその場フォールバック。使い方画面の代替ではない
- **旧インストールで `showUsageScreen` 未設定:** 既定 true。既存ユーザーにも一度は使い方を出す（コピー事故防止が目的）。出したくない人はチェックまたは設定で OFF
- **startup OFF なら usage もコールドスタートに出さない:** ユーザー指定。usage だけを起動時に出す経路は作らない
- **使い方からスタートアップへ戻るジェスチャなし:** 指定なし。出口は「ホーム画面へ」のみ
