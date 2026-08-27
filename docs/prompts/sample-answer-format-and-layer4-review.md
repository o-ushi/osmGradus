# レビュー結果：模範解答フォーマット（質問／日本語／Romaji）＋レイヤーⅣ閲覧

`docs/prompts/sample-answer-format-and-layer4.md` Step 1〜5 実装後のコードを、
Step 6 の4観点で点検した結果。

対象範囲：Step 1〜5で変更した以下のファイル。

- `lib/data/layer2_sample_answer_ai_prompt_template.dart`
- `lib/services/layer2_sample_answer_chrome_ai.dart`
- `lib/views/layers/layer4_screen.dart`
- `lib/data/layer_help_tips.dart`
- `lib/localization/gradus_l10n.dart`
- `test/layer2_sample_answer_ai_prompt_template_test.dart`
- `test/chrome_ai_round_trip_test.dart`
- `test/question_prompt_layer4_test.dart`

---

## 1️⃣ 作成者の意図に反して重複している機能

### 修正済み：解答例の読み取り専用シート表示が Ⅱ・Ⅳ で二重実装されていた

Step 3 で `Layer4ScreenState._showSampleAnswer` を追加した際、
`Layer2SampleAnswerMixin.showSampleAnswerViewSheet` とほぼ同一の
`TextViewSheet.show(context, title: '解答例'.tr(lang), text: ...)` 呼び出しを
そのまま複製していた。

共通ルール2「Ⅳは閲覧のみ・表示ヘルパーの共有は可」に従い、
`lib/services/layer2_sample_answer_chrome_ai.dart` にトップレベル関数
`showSampleAnswerReadOnlySheet(BuildContext, String)` を切り出し、
`Layer2SampleAnswerMixin.showSampleAnswerViewSheet`・
`Layer4ScreenState._showSampleAnswer` の両方から呼ぶように統一した
（`Layer4Screen`は`Layer2SampleAnswerMixin`自体には乗らず、この表示関数だけを
import している。送信・貼り付け・長押し再取得の実装は引き続きⅡのみ）。

### 問題なし

- Ⅳの「理由」枠タップは表示シートを開くだけで、送信・貼り付け・保存先の
  二重実装はない（`onReasonTap: hasSampleAnswer ? _showSampleAnswer : null`）。
- `sampleAnswer`の保存先は`QuestionPromptService`一本のまま。Ⅱ・Ⅳで別ストアに
  分岐していない。

---

## 2️⃣ ゾンビ化している機能

### 問題なし

- 新規追加した l10n キー（`help.gradus.layer4.tip4`、
  `レイヤーⅣ_問題文_使い方_解答例`）はいずれも
  `LayerHelpTips.layers`／`Layer4ScreenState._showUsageHelp`から参照されており、
  未使用キーは無い（`help_l10n_test.dart`の機械チェックでも確認済み）。
- 「日本語本文のみ」を前提にした古いコメント・処理は検索した限り残っていない
  （`Layer2SampleAnswerAiPromptTemplate`のクラス doc コメントは Step 1 で
  3ブロック構成に更新済み）。
- Ⅳの解答例アイコンは`hasSampleAnswer`が false のとき`reasonIcon`自体を
  渡さない実装（レイヤーⅡランダムと同じ方式）のため、「押しても何も起きない
  ゴーストアイコン」は存在しない。

---

## 3️⃣ 作成者の意図に反して動線が冗長的な機能

### 問題なし

- Ⅳの解答例タップ→表示は単発（確認ダイアログや中間画面を挟まない）。
- 「ランダム」（`fixedPrompt == null`）では解答例アイコン自体が出ない
  （`hasSampleAnswer`が常にfalse）。無意味な導線・空押しは発生しない。
- ▲▼移動時に画面スタックが増えることはなく、同一`Layer4Screen`インスタンスへ
  `fixedPrompt`を差し替えるだけの既存方式のまま。

---

## 4️⃣ その他

### 修正済み：Ⅳの「＋」長押し使い方シートに解答例閲覧の案内が欠けていた

Help画面（`help.gradus.layer4.tip4`）には Step 4 で解答例閲覧の案内を
追加したが、レイヤーⅣ「問題文一覧から選ぶ」画面自体の「＋」長押し
使い方シート（`レイヤーⅣ_問題文_使い方_*`）には対応する案内が無く、
Ⅱの同種シート（`レイヤーⅡ_問題文_使い方_解答例`）と比べて非対称だった。

`レイヤーⅣ_問題文_使い方_解答例`（ja/en/vi）を追加し、「日本語で回答」の次
・「PREP評価・的中度」の前に挿入。後続の3ステップ（PREP的中度→5️⃣、
採点結果→6️⃣、V→7️⃣）の番号を繰り下げた。ウィジェットテストで新しい案内行が
表示されることを確認済み。

### 確認済み（問題なし）

- 旧`sampleAnswer`（見出しなしのプレーン日本語）は、Ⅱ・Ⅳどちらの表示シートも
  パース処理を一切持たないため、そのまま表示される（後方互換は自動的に成立）。
- ▲▼で問題文を切り替えたとき、解答例アイコンの表示は常に新しい
  `fixedPrompt.sampleAnswer`に追従する（別問題の解答例が残ったり、
  一度消えたまま戻らなかったりしない）。ウィジェットテストで固定済み。
- レイヤーⅣの例示枠（採点結果一覧）は本改修の影響を受けていない
  （既存テストが全て緑）。
- ja/en/vi は各Stepで常に3言語同時に更新しており、言語間の文言欠落は無い
  （`help_l10n_test.dart`が機械的に検査）。

### 提案のみ（大きな変更ではないため今回は見送り）

- なし。

---

## 確認結果

- `flutter analyze`：プロジェクト全体で問題なし。
- `flutter test`：831件（本レビューでの追加1件含む）すべて green。
