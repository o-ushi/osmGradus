# レビュー結果：模範解答フォーマット（質問／日本語／Romaji）＋レイヤーⅣ作成・閲覧

`docs/prompts/sample-answer-format-and-layer4.md` Step 1〜6 実装後のコードを、
Step 7 の4観点で点検した結果。

**注記:** 本ドキュメントの旧版は、途中で仕様が拡張される前（レイヤーⅣは
一覧のみ・閲覧専用という旧スコープ）のレビューだった。現在の実装は
Step 3・4 で一覧・ランダム双方に`Layer2SampleAnswerMixin`のフル機能
（作成・貼り付け・閲覧・長押し再取得）を持たせる形に置き換わっており、
本版はその最終形に対するレビューとして全面的に書き直した。

対象範囲：`lib/views/layers/layer4_screen.dart` を中心に、Step 1〜6 で
変更した以下のファイル一式（`lib/data/layer2_sample_answer_ai_prompt_template.dart`、
`lib/services/layer2_sample_answer_chrome_ai.dart`、
`lib/views/layers/layer2_question_prompt_detail_screen.dart`、
`lib/views/layers/layer2_random_screen.dart`、`lib/widgets/prep_label_row.dart`、
`lib/localization/gradus_l10n.dart`、`test/*.dart` 各種）。

---

## 1️⃣ 作成者の意図に反して重複している機能

### 問題なし（意図的な共有と確認）

- **`Layer2SampleAnswerMixin`をⅡ・Ⅳで共有:** `Layer4ScreenState`は
  `Layer2SampleAnswerMixin`を`with`し、`sampleAnswerPrompt`/`saveSampleAnswer`
  だけを実装して送信・貼り付け・閲覧・長押し再取得のロジック本体は一切
  複製していない。ドキュメントが明示的に「重複扱いしない」としている
  共有そのもの。
- **保存先の一本化:** `saveSampleAnswer`は一覧（`fixedPrompt`）・ランダム
  （`_drawnPrompt`）のどちらでも`_activePrompt`経由で同じ
  `QuestionPromptService.update`を呼ぶ。別の保存先を持たない。
- **紙飛行機（PREP・的中度）と解答例:** 同じ`ChromeAiSubmitMixin`の
  `chromeAiAwaitingPaste`を共有するが、`_ChromeAiPendingKind`
  （`sampleAnswer`/`prepHit`）で用途を分岐しており、役割が混線しない
  ことを双方向のテストで確認済み（後述）。

---

## 2️⃣ ゾンビ化している機能

### 修正済み：古いコメントが実体と食い違っていた

- `lib/services/layer2_sample_answer_chrome_ai.dart`の
  `showSampleAnswerReadOnlySheet`の doc コメントが「レイヤーⅣ（閲覧専用、
  送受信は持たない）」という、Step 3 以前の旧スコープの記述のまま残って
  いた。Ⅳは Step 3 でこの mixin をフル機能で使うようになったため、
  実体（Ⅱ・Ⅳ共通の表示ヘルパーであり、送受信の可否はこの関数と無関係）
  に合わせて書き直した。
- `lib/widgets/prep_label_row.dart`のクラス doc コメントが`reasonIcon`の
  利用例を「レイヤーⅠの単語帳導線、レイヤーⅡの解答例、レイヤーⅢのPREP
  「理由」欄」とだけ列挙し、レイヤーⅣ（Step 3・4 で追加）が抜けていた。
  追記した。
- `test/question_prompt_layer4_test.dart`の1テスト名が「Ⅱで取得済みの
  解答例をⅣでも読める旨の案内がある（Step 6レビュー）」という、旧
  ドキュメント番号かつ「読める（閲覧専用）」を前提にした死んだ名称の
  ままだった。「解答例の作成・閲覧の案内がある」に改めた（テスト内容
  自体は元から具体的な文言を固定していないため変更不要）。
- `Layer4ScreenState.pickTopic`の`super.pickTopic()`（`TopicService`題材
  バンク抽選）へのフォールバック分岐は、`drawAndSpeak`が必ず先に
  `_drawnPrompt`を確定させるため実運用では通らない。削除まではせず
  （呼び出し順が将来崩れた場合の防御的フォールバックとして有用）、
  その旨をコメントで明示した。

### 確認済み（問題なし）

- 新規追加した l10n キー（`レイヤーⅣ_使い方_解答例`、
  `レイヤーⅣ_問題文_使い方_解答例`の更新後の文言、`help.gradus.layer4.tip4`）
  はいずれも参照元があり、ja/en/vi すべてに存在する（`grep`で3言語分の
  存在を確認済み。前者2つは`help.gradus.*`名前空間外のため
  `help_l10n_test.dart`の自動チェック対象外だが、手動確認済み）。
- Ⅳの解答例アイコンは、対象問題文が無いとき（ランダム未抽選）は
  `reasonIcon`自体を渡さない実装のため、「押しても何も起きないボタン」
  は存在しない。

---

## 3️⃣ 作成者の意図に反して動線が冗長的な機能

### 問題なし

- Ⅳの解答例タップ→送信／貼り付け／閲覧は、Ⅱとまったく同じ
  mixin 経路をそのまま通るだけで、Ⅳ独自の追加確認ダイアログや余分な
  画面遷移はない。
- 用途分岐（`_ChromeAiPendingKind`）による競合ガードは、該当しない側の
  タップを黙って無視するだけで、余分な確認や警告ダイアログを挟まない
  （静かな安全側フォールバック。ユーザー操作から見れば通常のUXと差が
  出ない）。

---

## 4️⃣ その他

### 確認済み（問題なし）

- **ヘルプとUIの一致:** Ⅳの「＋」長押しシート（一覧・ランダム両方）と
  Help画面の`help.gradus.layer4.tip4`を、実装（一覧は常時、ランダムは
  抽選後に解答例ボタンが出る／両方フル機能）に合わせて Step 5 で更新済み。
  「題材バンクからランダム」のような矛盾する旧表現は元々存在しなかった
  （grep で確認）。
- **3言語同時更新:** Step 1〜6 で追加・変更した l10n キーはすべて
  ja/en/vi を同時に編集しており、`help.gradus.*`名前空間は
  `help_l10n_test.dart`が機械的に欠落を検出する。
- **旧`sampleAnswer`（見出しなし）:** `TextViewSheet`はパース処理を持たず
  受け取った文字列をそのまま表示するため、新旧フォーマットどちらでも
  表示できる（後方互換は自動的に成立）。
- **▲▼／再抽選後の待ち残り:** 一覧の▲▼、ランダムの再抽選・カテゴリ変更・
  タイマープリセット変更（シチュエーション除外の分岐）のいずれでも
  `_drawnPrompt`／`_sampleAnswer`／`chromeAiAwaitingPaste`／
  `_chromeAiPendingKind`を一緒に解除しており、専用テストで確認済み。
- **例示枠（採点結果一覧）:** 本改修は`_savedResults`／`exampleIcon`まわりに
  触れておらず、既存テスト（`layer4_prep_hit_flow_test.dart`ほか）が
  そのまま緑。
- **解答例とPREPの誤保存:** `_ChromeAiPendingKind`による分岐を、
  「PREP待ち中に解答例タップ」「解答例待ち中にPREPタップ」の両方向で
  ウィジェットテスト化し、クリップボードが誤った保存先に書き込まれない
  ことを確認済み。
- **ランダム採点の問題文ID紐づけ:** `_persistScoreToPrompt`・
  `SavedScoringResult`ともに`_activePrompt`（一覧は`fixedPrompt`、
  ランダムは`_drawnPrompt`）を参照するよう Step 4 で統一済み。専用テストで
  `QuestionPromptService`上の同じ id に反映されることを確認済み。

### 提案のみ（今回は見送り）

- なし。

---

## 確認結果

- `flutter analyze`：プロジェクト全体で問題なし。
- `flutter test`：839件すべて green（本レビューでの3件の安全な修正
  ―コメント2箇所・テスト名1箇所―を含む。ロジック変更は無し）。
