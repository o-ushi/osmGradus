# 使い方画面 — スワイプ＋設定連動 レビュー（Step 4）

`docs/prompts/usage-screen-swipe-and-settings.md` Step 1〜3 実施後のコードを、①同じ判定がsetterとUIで食い違う ②古いコメント・テスト名 ③スワイプと「ホーム画面へ」の着地矛盾 ④赤丸付き全画面スクショや「赤丸」l10nの残骸、の観点で点検した結果。

## ① setterとUIの判定不一致

- 不変条件（`showUsageScreen == true` は `showStartupScreen == true` のときだけ）は `AppSettings.showStartupScreen` のsetter1箇所にのみ実装。設定UI・`AppRootShell._finishStartup`はいずれもこのsetter経由でしか書き込まないため、判定が2箇所に分散していない。→ **確認**
- `TtsSettingsScreen`の使い方スイッチは`enabled: appSettings.showStartupScreen`でUI側もsetterと同じ条件を見ている。→ **確認**

## ② 古いコメント・テスト名

- `UsageScreen`のクラスdocを「ボタンでの確定に加え、左端からの右スワイプでも（チェックを保存せず）スタートアップへ戻れる」に更新済み。「出口はボタンのみ」といった記述は元々コード内コメントには無く（`usage-screen.md`という指示書側にのみあった記述）、コードの陳腐化は無かった。→ **確認**
- `test/startup_screen_test.dart`のテスト名は仕様どおりの着地（使い方／スタートアップ）を反映済み（前回レビュー時に修正済み）。今回の変更で新たに矛盾する名前は生じていない。→ **確認**

## ③ スワイプと「ホーム画面へ」の着地矛盾

- 使い方画面からの離脱は2経路:
  - 「ホーム画面へ」ボタン→`_finishUsage`→チェックONならフラグ保存の上でホームへ
  - 左端右スワイプ→`_swipeUsageToStartup`→フラグ保存せずスタートアップへ
  両者は着地も副作用も意図的に異なり、矛盾ではなく仕様どおりの分岐。→ **確認**
- スタートアップへスワイプで戻った後に再度「はじめる」を押すと、usageがONならまた使い方へ戻る往復動線を許容（指示書どおり）。→ **確認**（テストで担保）

## ④ 赤丸付き全画面スクショ・「赤丸」l10n残骸

- `assets/images/chrome_ai_copy_button.png`は657×479のTAP!図に差し替え済み。旧・全画面スクショや2アイコン切り抜きは資産に残っていない。→ **確認**
- `使い方_コピー本文`・`使い方_コピー画像_説明`（ja/en/vi）はいずれも「赤丸」「red circle」「khoanh đỏ」を含まず、「TAP!」に言及している（`test/usage_screen_test.dart`に回帰テストを追加）。→ **修正済み（テスト追加により固定）**
- `help.gradus.gesture.tip4`はもともと「赤丸」に言及していなかったため、指示書どおり未変更。→ **確認（意図的に触らず）**

## 追加で直したもの

- `help.gradus.settings.tip2`（ja/en/vi）に「スタートアップをOFFにすると使い方も自動でOFFになる」旨を1文追記し、連動を知らずに「独立に切れる」と誤読される余地を減らした。→ **修正済み**

## テスト・解析

- `flutter analyze`：本タスクで変更したファイル群はクリーン。プロジェクト全体では、本タスクと無関係な既存の未コミット作業（question-prompt-tabs関連ファイル）に起因する既存のエラー・警告が3件残っているが、スコープ外のため未修正。
- `flutter test test/startup_screen_test.dart test/usage_screen_test.dart test/tts_settings_screen_test.dart test/help_screen_test.dart` は全てパス（33件）。
