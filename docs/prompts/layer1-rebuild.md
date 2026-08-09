# レイヤーI再構築 — 実装済みサマリ

旧ステップ別プロンプト集は実装完了につき、このファイルを**現状仕様の要約**に置き換えた。

---

## 入口

レイヤーⅠを選ぶとまず2択:

1. **語彙を増やす** → `Layer1VocabScreen`（単語テスト）
2. **日本語に耳を慣らす** → `Layer1Screen`（Podcast）

実装: `lib/views/layers/layer1_entry_screen.dart`

### モード切替（スタート退出なし）

- 各モード画面の「モード選択に戻る」→ `resetMode()`
- ヘッダー「Ⅰ」再タップ → 同じく2択へ
- 右スワイプでスタートへ閉じるときもモード選択を解除

---

## 語彙テスト

| UI | 挙動 |
|---|---|
| 単語表示 on/off | on=問題欄表示 / off=ヒアリングのみ |
| ＋ | Chrome AI 語彙取り込み画面（`VocabularyImportScreen`） |
| レベル | N1 / N2 / N3 / ランダム |
| サイコ | プールから抽選 → TTS → 青マイク |
| マイク | 録音 → STT → 次問（10問） |
| 単語帳 | `VocabularySheet`（標準語は削除不可） |
| 紙飛行機 | Chrome AI ★ 評価（レイヤーV同型） |

### 標準 JLPT 語彙

- N1/N2/N3 各20語を **仮想マージ**（prefs に書かない）
- 設定「標準のJLPT語彙を含める」（既定 ON）
- ID は `builtin:` 接頭辞。取り込み画面のレベル削除は**ユーザー追加分のみ**

関連: `jlpt_vocabulary_bank.dart` / `JlptVocabBankService` / `AppSettings.includeDefaultVocabulary`

---

## Podcast / MiniPlayer

- 耳慣れモードのみ `MiniPlayerBar` を表示（語彙・2択では非表示）
- `MainShell` が `Layer1EntryScreen.mode` を購読

---

## Help / 起動説明

- 起動サブタイトル: 語彙／耳慣れの両方を示す
- `help.gradus.layer1.tip1`〜`tip4`: 2択・語彙・耳慣れ・モード切替

---

## 主要ファイル

| 領域 | パス |
|------|------|
| 入口 | `lib/views/layers/layer1_entry_screen.dart` |
| Podcast | `lib/views/layers/layer1_screen.dart` |
| 語彙 | `lib/views/layers/layer1_vocab_screen.dart` |
| 取り込み | `lib/views/layers/vocabulary_import_screen.dart` |
| Shell | `lib/views/main_shell.dart` |
| 戻るボタン | `lib/widgets/layer1_back_to_mode_button.dart` |
| 実機確認 | `docs/manual-testing-layer1-vocab.md` |
