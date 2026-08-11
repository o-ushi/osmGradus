# osmGradus

日本語学習アプリ（Flutter）。5つの練習レイヤー、単語帳、ポッドキャスト、ダッシュボードで構成される。

## 主な機能

- **レイヤーⅠ** — 語彙テスト / ポッドキャスト（耳慣れ）
- **レイヤーⅡ〜Ⅳ** — 会話問題文の練習（タイマー・TTS・採点）
- **レイヤーⅤ** — 発音チェック（5カテゴリ × 10問）
- **単語帳** — フラッシュカード形式の復習
- **ダッシュボード** — 直近の結果サマリーと Chrome AI アドバイス

## 技術スタック

- Flutter / Dart SDK ^3.12
- 状態管理: `ChangeNotifier`（`AppSettings`）
- 永続化: `shared_preferences`、JSON バックアップ
- 音声: `just_audio`、`audio_service`、プラットフォーム STT/TTS
- AI: Chrome / Google AI への手動往復（`ChromeAiRoundTrip`）

## 開発

```bash
flutter pub get
flutter test
flutter run
```

## ディレクトリ構成（抜粋）

| パス | 内容 |
|------|------|
| `lib/views/` | 画面・ナビゲーション |
| `lib/widgets/` | 共通 UI コンポーネント |
| `lib/services/` | STT、採点、ストレージ、AI |
| `lib/navigation/app_routes.dart` | 画面遷移の共通エントリ |
| `lib/services/app_services.dart` | グローバルサービス登録先 |
| `test/` | ユニット・ウィジェットテスト |

## プラットフォーム

iOS（iPhone 縦画面）を主ターゲット。Android もサポート。
