# 使い方画面 — 右スワイプでスタートアップへ ＋ 設定の連動

このファイルは Claude Code 向けの**差分**指示書です。  
`docs/prompts/usage-screen.md` は実装済み。本ファイルはその上に載せる。

## Claude への指示テンプレ

```
docs/prompts/usage-screen-swipe-and-settings.md の各 Step を順番に実行して
```

1 Step ずつ:

```
docs/prompts/usage-screen-swipe-and-settings.md の Step N をやって
```

各 Step の受け入れを満たし、`flutter analyze` と当該テストが通ってから次へ。  
スコープ外のリファクタ・ドキュメント追加はしない。l10n を足すなら ja/en/vi を揃える。

---

## 変更点（正本）

### 1. 使い方画面を右スワイプ → スタートアップ

案内のスタックは次のとおり（ホームが一番上）:

```
スタートアップ ← 使い方 ← ホーム
```

| 今いる画面 | 左端からの右スワイプ |
|------------|----------------------|
| ホーム | 既存どおり（startup OFF なら動かない。usage ON なら使い方、OFF ならスタートアップ） |
| **使い方** | **スタートアップ**（チェックは保存しない。「ホーム画面へ」を押していないので `dontShowAgain` は確定しない） |
| スタートアップ | 今までどおり、さらに戻る先はない |

- `SwipeToCloseWrapper` を `LaunchScreen` と同じく使い方に付ける（新規ジェスチャ実装はしない）
- Navigator で push しない。`AppRootShell` の `_showingUsage` / `_showingStartup` 切替のまま
- スワイプでスタートアップへ戻ったあと「はじめる」を押したら、usage が ON ならまた使い方へ（往復してよい。意図どおり）

### 2. 設定: スタートアップ OFF なら使い方も自動 OFF

**不変条件:** `showUsageScreen == true` は `showStartupScreen == true` のときだけ許す。  
「使い方だけ ON・スタートアップは OFF」は作らない。

| 操作 | 結果 |
|------|------|
| 設定でスタートアップを OFF | 使い方も **false に保存**。スイッチは OFF 表示 |
| 設定でスタートアップを ON に戻す | 使い方は **自動では戻さない**（OFF のまま。必要なら自分で ON） |
| 設定で使い方だけ OFF | スタートアップは ON のまま（既存どおり許可） |
| スタートアップが OFF のとき、使い方スイッチ | **操作不可**（`SettingsSwitchRow.enabled: false`）。ON にできない |
| スタートアップの「次回から表示しない」で `showStartupScreen = false` | 同じ不変条件を通すので、保存値の使い方も false になる |

**今セッションの「はじめる」:** チェック ON にする**前**の `showUsageScreen` を見て着地する（元仕様 B）。  
保存は不変条件どおり両方 false にしてよい。実装例:

```dart
final showUsageNow = appSettings.showUsageScreen;
if (dontShowAgain) {
  appSettings.showStartupScreen = false; // setter が usage も false にする
}
_showingStartup = false;
_showingUsage = showUsageNow;
```

連動は **`AppSettings.showStartupScreen` の setter** に置く（設定 UI だけだと、はじめるチェックや将来の呼び出しが不整合を残す）。  
`showStartupScreen = false` かつ usage が true なら usage も false にしてから `notifyListeners` は1回。

### 3. 案内画像を TAP! 図に差し替え

手描き赤丸付きの全画面スクショ、および2アイコンだけの切り抜きはやめる。  
`assets/images/chrome_ai_copy_button.png` は **操作バー（コピー・共有・評価・メニュー）に、左端のコピーへ赤い矢印と TAP! を付けた図**（配置済・約 657×479）。

- 横幅はパディング内いっぱいでよい。`BoxFit.contain`。白地＋角丸
- 本文・`semanticLabel` から「赤丸」を消し、**赤い矢印と TAP! が指す左端の重なった四角**と書く
- 推奨文言は `docs/prompts/usage-screen.md` の l10n 表（差し替え後）に合わせる

---

## 現状の地図

| 領域 | パス |
|------|------|
| ルート | `lib/views/app_root_shell.dart`（`_finishStartup` / `_finishUsage` / `_onSwipeFromHome`） |
| 使い方 | `lib/views/usage_screen.dart`（スワイプ未対応。画像は全画面スクショのまま） |
| 案内画像 | `assets/images/chrome_ai_copy_button.png`（TAP! 図・配置済。文言がまだ赤丸／2アイコン切り抜きのままなら直す） |
| ホームのスワイプ | `lib/views/launch_screen.dart` の `SwipeToCloseWrapper` |
| ラッパー | `lib/widgets/swipe_to_close_wrapper.dart` |
| 設定 | `lib/views/settings/tts_settings_screen.dart`（`SettingsSwitchRow` は既に `enabled` あり） |
| フラグ | `lib/notifiers/app_settings.dart` |
| テスト | `test/startup_screen_test.dart` / `test/usage_screen_test.dart` / `test/tts_settings_screen_test.dart` |
| スワイプの書き方 | `test/startup_screen_test.dart` の左端ジェスチャをコピー |

---

## Step 1 — 不変条件（setter ＋ 設定スイッチ）

### 目的

スタートアップを消したら、使い方だけ残る状態を保存できないようにする。

### 指示

1. `AppSettings.showStartupScreen` setter: `value == false` なら `showUsageScreen` も false（値が変わるときだけ書く）
2. 設定の使い方行: `enabled: appSettings.showStartupScreen`（OFF のときはグレーアウト、タップ無効）
3. テスト（`test/tts_settings_screen_test.dart` または prefs テスト）
   - 両方 true のときスタートアップを OFF → usage も false
   - スタートアップ OFF のとき使い方スイッチは `enabled: false` / タップしても usage は false のまま
   - スタートアップを再び ON → usage は false のまま（自動復帰しない）
   - スタートアップ ON のまま使い方だけ OFF → startup は true のまま
4. `_finishStartup` は上記「今セッションはチェック前の usage を見る」に直す（setter 連動で今セッションの使い方が消えないようにする）

### 受け入れ

- [ ] 保存値に「startup false かつ usage true」が残らない
- [ ] 設定 UI で使い方だけ ON にできない
- [ ] スタートアップ再 ON で使い方が勝手に ON に戻らない
- [ ] はじめる（チェック ON）でも、チェック前に usage が true なら今セッションは使い方に着地する
- [ ] `flutter analyze` 当該テストが通る

---

## Step 2 — 使い方画面の右スワイプ → スタートアップ

### 目的

使い方の左端右スワイプでスタートアップに戻る。

### 指示

1. `UsageScreen` に `VoidCallback? onSwipeToStartup`（名前は既存スタイルで可）を足す
2. 指定があるとき `SwipeToCloseWrapper(onClose: onSwipeToStartup, child: …)` で包む（`LaunchScreen` と同じ）
3. `AppRootShell`: コールバックで `_showingUsage = false; _showingStartup = true`。フラグは保存しない
4. 単体 `pumpUsage`（`MaterialApp(home: UsageScreen(…))`）はコールバック無しのままで壊さない
5. テスト（結合、`OsmGradusApp`）
   - はじめる → 使い方 → 左端右スワイプ → スタートアップ（「はじめる」が見える。「ホーム画面へ」は消える）
   - その状態で「はじめる」→ また使い方（usage ON のとき）
   - スワイプでは `showUsageScreen` / `showStartupScreen` が変わらない（チェック未確定）
   - 既存のホーム右スワイプ 3 ケース（usage ON → 使い方、usage OFF → スタートアップ、startup OFF → 動かない）は残す
6. `UsageScreen` / `AppRootShell` のコメントを「出口はボタンのみ」から直す

### 受け入れ

- [ ] 使い方の右スワイプでスタートアップに着地する
- [ ] スワイプは「次回から表示しない」を保存しない
- [ ] ホームのスワイプ仕様は壊していない
- [ ] `flutter analyze` 当該テストが通る

---

## Step 3 — 案内画像を TAP! 図に差し替え

### 目的

使い方画面の図を、赤い矢印と TAP! 付きの操作バーにし、赤丸／2アイコン切り抜き前提の文言を直す。

### 指示

1. `assets/images/chrome_ai_copy_button.png` は既に TAP! 図。パスは変えない。旧全画面や2アイコン切り抜きを復元しない
2. `UsageScreen` の画像: パディング内の横幅で `BoxFit.contain`。白地の角丸（`ColoredBox` + `ClipRRect`）で scene の上に載せる
3. `gradus_l10n.dart` の `使い方_コピー本文` / `使い方_コピー画像_説明`（ja/en/vi）を `usage-screen.md` の差し替え後の表に合わせる。「赤丸」「red circle」「khoanh đỏ」を残さない。TAP! と赤い矢印に言及する
4. ヘルプ `help.gradus.gesture.tip4` は赤丸無しのままでよければ触らない
5. テスト: 新しい本文が出ること。asset パスは従来どおりでよい

### 受け入れ

- [ ] 画面上は TAP! と赤い矢印付きの操作バー（2アイコン切り抜きや全画面スクショではない）
- [ ] ユーザー向け文言に赤丸が残っていない（ja/en/vi）
- [ ] 左端の重なった四角＝コピーだと本文から分かること
- [ ] `flutter analyze` 当該テストが通る

---

## Step 4 — ヘルプ一言 ＋ レビュー（重複・ゾンビ・冗長）

### 目的

文言と動線が新しいスタックと矛盾しないことを確認する。安全な修正だけ入れる。

### 指示

1. ヘルプのジェスチャ／はじめにが「右スワイプで前の画面」と書いてあるなら、使い方→スタートアップもそれに含まれるので、食い違う文だけ直す。新しい長文は足さない（足りなければ1文）
2. 設定ヘルプが「スタートアップと使い方を独立に切れる」と読めるなら、連動（スタートアップ OFF で使い方も OFF）に直す
3. 観点: ①同じ判定が setter と UI で食い違う ②古いコメント・テスト名（「使い方から戻れない」） ③スワイプと「ホーム画面へ」が同じ着地になっていないか ④赤丸付き全画面スクショや「赤丸」l10n の残骸
4. 短く `docs/prompts/usage-screen-swipe-and-settings-review.md` にまとめる（**修正済 / 意図的残置 / 確認**）
5. `flutter analyze` と  
   `flutter test test/startup_screen_test.dart test/usage_screen_test.dart test/tts_settings_screen_test.dart test/help_screen_test.dart`

### 受け入れ

- [ ] ヘルプ／コメントが新仕様と矛盾しない
- [ ] レビュー文書がある
- [ ] 当該テストが通る

---

## Step 依存関係

```
Step 1 設定連動
  → Step 2 使い方スワイプ
    → Step 3 案内画像（TAP!）差し替え
      → Step 4 ヘルプ＋レビュー
```

Step 1〜3 は 1 セッションで続けてよい。受け入れは満たしてから次へ。

---

## 触らないもの

- 「ホーム画面へ」ボタンとチェックの見た目（文言の赤丸削除は Step 3）
- ホーム下部の `起動_操作ヒント`
- Chrome 往復のその場コピー案内
- Google スライド操作マニュアル
- スタートアップ画面自体をスワイプで閉じる機能（今までどおり無し）
- 手描き赤丸付きの旧全画面スクショや、2アイコンだけの切り抜きを資産に戻すこと
