# レイヤーⅡ 解答例（45秒模範解答）— Chrome AI 往復

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/layer2-sample-answer.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

---

## 機能概要（ユーザーの狙い）

```
レイヤーⅡ
  ├─「問題文一覧から選ぶ」→ 詳細画面
  └─「ランダム」→ 問題文表示後

PrepLabelRow の「理由」枠（レイヤーⅢの理由ボタンと同じ位置）
  → アイコンボタン「解答例」

タップ（未取得）
  → 同意ダイアログ
  → 問題文（＋状況条件）を Google 検索 AIモードへ送信
  → 「45秒版の模範解答」を考えさせる

Chrome で回答をコピー → アプリに戻る → 同じボタン再タップ
  → クリップボードから取り込み
  → アプリ上に表示（保存）

再表示（取得済み）
  → 同じボタンで解答例を開く（閲覧専用。更新したい場合は長押しで再取得）
```

**対象外（触らない）:**

| 項目 | 理由 |
|------|------|
| 「25マスで考える」 | ユーザー指定は問題文一覧／ランダムのみ |
| 「話題を増やす」 | 入口の通常 Google 検索（お題探し）。AIモード解答例とは別役割 |
| レイヤーⅢの結論・理由・例示 | PREP 記入。解答例で置き換えない |
| レイヤーⅣの45秒タイマー／採点 | 発話練習。解答例は「読む／イメージする」用のテキスト |

---

## UX 仕様（全 Step で固定）

### ボタン位置・見た目

- `PrepLabelRow` の **理由枠**（`showReason: true` + `reasonIcon`）
- アイコン推奨: `Icons.menu_book_rounded`（Ⅲの `question_mark`／`lightbulb` と被らないこと）
- tooltip / ヒント: 「解答例」
- `reasonShowBorder: false`、`reasonHorizontalPadding: 0`（Ⅲの理由アイコンと同型）
- `reasonActive: sampleAnswer.isNotEmpty`（橙＝取得済み）

### タップ挙動（1ボタンで完結・紙飛行機は足さない）

| 状態 | タップ |
|------|--------|
| 解答例が空 かつ `chromeAiAwaitingPaste == false` | 同意 → Chrome AI 送信 |
| `chromeAiAwaitingPaste == true` | クリップボード貼り付け保存 |
| 解答例が非空 | `TextViewSheet` で読み取り専用表示（手編集不可。更新は長押しで再取得） |

- **貼り付け待ちの視覚フィードバック:** `chromeAiAwaitingPaste == true` の間は
  アイコンを `Icons.content_paste_go_rounded`・色を `kPasteReadyColor`（緑）に
  切り替える（`GenkiTransportRow` の送信⇄貼り付け切り替えと同じ見た目）。
  未取得時と同じ見た目のままだと、Chromeでまだコピーする前に早すぎるタップで
  貼り付け失敗（実質は「まだ準備できていない」だけ）を誘発しやすいため
  （実機報告で発覚・Step 7後の追加修正）。
- **長押し（取得済み時）:** 再取得（Chrome AI へ再送信）。未取得時の長押しはヒント／何もしないでよい。
- **ランダムで問題文未抽選:** 理由枠は出さない（現状どおり `PrepLabelRow()` の空席でも可）。抽選後だけ `showReason: true`。
- 一覧詳細は問題文が常にあるので、理由枠は常時表示。

### AI 依頼内容

- 渡すもの: `QuestionPrompt.body` ＋（あれば）`situationCondition`
- 依頼: **日本語で約45秒で話せる分量の模範解答**（口語・自然な話し言葉。PREP を強要しすぎないが、結論→理由→具体例の流れは推奨）
- レスポンス形式: **プレーンテキスト**（JSON 不要。ダッシュボード advice と同じ「そのまま保存」）
- URL: `GoogleAiSearch.buildLaunchPlan`（長文はクリップボード貼り付けフォールバック）

### 保存先

- `QuestionPrompt.sampleAnswer`（新規フィールド）
- 一覧詳細・ランダムとも同じ問題文 ID なら共有される
- 進捗判定（`summary.isNotEmpty`）には**含めない**（解答例だけでは「完了」にしない）

---

## 共通ルール（全 Step 共通・必ず守る）

1. **Chrome AI 往復は既存基盤を使う** — `ChromeAiSubmitMixin` / `AiImportKeepAliveMixin` / `GoogleAiSearch` / `GoogleAiSendConsentDialog`。新規の HTTP API や独自サーバは作らない。
2. **紙飛行機ボタンを新設しない** — 解答例アイコン自身が send／paste を切り替える（`chromeAiOnSubmitTap`）。`GenkiTransportRow` に diagnose を足して二重導線にしない。
3. **一覧詳細とランダムでロジックを二重実装しない** — 送信・貼り付け・保存・表示の共通処理を1か所に寄せる（Step 3）。
4. **l10n** — `gradus_l10n.dart` / `app_strings.dart`。ja / en / vi。
5. **後方互換** — 旧 `QuestionPrompt` JSON（`sampleAnswer` 無し）は空文字として読む。
6. **スコープ外を触らない** — その Step の受け入れ以外のリファクタ・ドキュメント追加はしない（最終レビュー Step 除く）。
7. **完了報告** — 変更ファイル一覧・手動確認手順・次 Step への前提を短く報告する。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| Ⅱ入口 | `lib/views/layers/layer2_entry_screen.dart` |
| 一覧詳細 | `lib/views/layers/layer2_question_prompt_detail_screen.dart` |
| ランダム | `lib/views/layers/layer2_random_screen.dart` |
| PREP 予約席 | `lib/widgets/prep_label_row.dart` |
| 問題文モデル | `lib/models/question_prompt.dart` |
| 問題文サービス | `lib/services/question_prompt_service.dart` |
| Chrome AI mixin | `lib/services/chrome_ai_submit_mixin.dart` |
| URL 組み立て | `lib/data/google_ai_search.dart` |
| 同意ダイアログ | `lib/widgets/google_ai_send_consent_dialog.dart` |
| テキスト表示／編集 | `lib/widgets/text_edit_sheet.dart` |
| ヘルプ tips | `lib/data/layer_help_tips.dart` |
| l10n | `lib/localization/gradus_l10n.dart` |
| 参考（advice 往復） | `lib/views/dashboard/dashboard_screen.dart` |
| 参考（プロンプト） | `lib/data/question_prompt_summary_ai_prompt_template.dart` |
| Ⅱテスト | `test/question_prompt_layer2_test.dart` ほか |

---

## Step 1 — データモデル：`sampleAnswer`

### 目的
問題文に「45秒模範解答」テキストを保存できるようにする。

### 指示

1. `lib/models/question_prompt.dart` に追加:

```dart
final String sampleAnswer; // 既定 ''
```

- コンストラクタ・`create`・`copyWith`・`fromJson`・`toJson` を既存フィールド（`summary` 等）と同型で更新
- JSON キー: `'sampleAnswer'`
- 欠落時は `''`（後方互換）
- 空のときは `toJson` に書かない／書いてもよい（既存 `summary` の方針に合わせる）

2. バックアップ／インポート経路が `QuestionPrompt.fromJson` 経由なら追加作業は不要。独自マップ組み立てがある場合のみ追従。

3. ユニットテスト（既存の `QuestionPrompt` round-trip テストがあれば拡張。無ければ最小の fromJson/toJson テストを追加）:
   - 旧 JSON（キー無し）→ `sampleAnswer == ''`
   - 保存→読込で文字列が残る

### 受け入れ

- `flutter analyze` 緑
- 旧データが落ちない
- `sampleAnswer` は進捗（一覧の完了マーク）に影響しない

### 手動確認

1. 既存問題文を開いてもクラッシュしない
2. （コード確認）`isDone: (prompt) => prompt.summary.isNotEmpty` のまま

---

## Step 2 — AI プロンプトテンプレート ＋ 同意／UI 用 l10n

### 目的
「問題文 → 45秒模範解答」依頼文と、ユーザー向け文言の土台を用意する。

### 指示

1. **新規** `lib/data/layer2_sample_answer_ai_prompt_template.dart`（名前は既存スタイルに合わせて可）:

```dart
abstract final class Layer2SampleAnswerAiPromptTemplate {
  static String prompt({required QuestionPrompt prompt, required String lang});
  static ChromeAiLaunchPlan buildLaunchPlan({
    required QuestionPrompt prompt,
    required String lang,
  });
}
```

- `prompt()` の要件（ja/en/vi で依頼文の言語を切替）:
  - ヘッダ: 日本語スピーキング練習用の**約45秒**で話せる模範解答を1つ作る
  - 問題文本文・（あれば）状況条件を明示
  - 口語・自然な話し言葉。読み上げやすい長さ（目安 150〜250 文字程度でよいが、厳密な文字数強制はしない）
  - PREP（結論→理由→具体例）の流れを推奨するが、見出しラベルを強制しない
  - **プレーンテキストのみ**返す（JSON・Markdown 見出し過多は避けるよう指示）
- `buildLaunchPlan` は `GoogleAiSearch.buildLaunchPlan` に委譲

2. l10n（ja/en/vi）を追加（キー名は既存に合わせて調整可）:

| キー用途 | 例 |
|----------|-----|
| ボタン名 | `解答例` |
| 同意タイトル／本文 | `Google送信確認_解答例_タイトル` / `_本文`（問題文を送り45秒模範解答を得る旨） |
| シートタイトル | `解答例`（`TextViewSheet`、読み取り専用） |
| シート閉じるボタン | `閉じる` |
| 使い方（一覧） | `レイヤーⅡ_問題文_使い方_解答例` |
| 使い方（ランダム） | `レイヤーⅡ_ランダム_使い方_解答例` |
| ダブルタップ hint | タップ＝解答例／取得、長押し＝再取得（取得済み時） |

3. プロンプト組み立てのユニットテスト（`test/layer2_sample_answer_ai_prompt_template_test.dart`）:
   - body / situationCondition がプロンプトに含まれる
   - `buildLaunchPlan` が非空の url・prompt を返す

### 受け入れ

- テンプレ単体で問題文が埋め込まれた依頼文になる
- l10n 3言語が揃う（この Step では UI 配線はまだでよい）

---

## Step 3 — 共通ロジック ＋ 一覧詳細画面への配線

### 目的
Chrome AI 送信→貼り付け→保存→表示を共通化し、**問題文一覧詳細**に解答例ボタンを出す。

### 指示

1. **共通化**（推奨形のいずれか）:
   - `lib/services/layer2_sample_answer_chrome_ai.dart` のようなヘルパー／mixin、または
   - 両画面から呼ぶ薄いコントローラ
   - 必須処理: send（同意キー差し替え可）／paste（`consumeChromeAiPasteText` または dashboard と同型）／`QuestionPromptService.update` で `sampleAnswer` 保存／表示用に `TextViewSheet.show`（読み取り専用。編集は提供せず、更新は長押し再取得で行う）
   - State が `ChromeAiSubmitMixin` + `AiImportKeepAliveMixin` + `WidgetsBindingObserver` を持てる形にする（既存 dashboard / long_article を踏襲）

2. `layer2_question_prompt_detail_screen.dart`:
   - `_Layer2PromptDetailBodyState` に mixin を載せる（または子ウィジェット化）
   - `PrepLabelRow` を次のように拡張（結論＝要約は維持）:

```dart
PrepLabelRow(
  showConclusion: true,
  // ...既存の要約設定...
  showReason: true,
  reasonIcon: Icons.menu_book_rounded,
  reasonTooltip: '解答例',
  reasonShowBorder: false,
  reasonHorizontalPadding: 0,
  reasonActive: prompt.sampleAnswer.isNotEmpty,
  onReasonTap: _onSampleAnswerTap,
  onReasonLongPress: /* 取得済みなら再送信。PrepLabelRowに長押しが無ければ GhostPill 側を確認して足す */,
  reasonHintTapText: '...',
  reasonHintLongPressText: '...', // 取得済み時のみでも可
);
```

   - `_onSampleAnswerTap`:
     - 非空 → `TextViewSheet` で読み取り専用表示（編集不可）
     - 空 or awaiting → `chromeAiOnSubmitTap(onSend:, onPaste:)`
   - アプリ復帰で自動 paste する既存パターン（dashboard の `didChangeAppLifecycleState`）があれば同様に載せる

3. `PrepLabelRow` / `GhostPill` に理由枠の長押しが無い場合のみ、最小限で `onReasonLongPress` を追加（結論・例示と同型）。不要なら「取得済み時はシート内に再取得導線」でも可だが、**＋長押しシートの説明と実操作を一致**させること。

4. 同意は `GoogleAiSendConsentDialog.confirm(..., bodyKey: 'Google送信確認_解答例_本文')` など Step 2 のキーを使う。

### 受け入れ

- 一覧 → 問題文詳細で「解答例」アイコンが見える（理由の位置）
- 未取得タップ → 同意 → Chrome（実機／シミュレータで URL 起動まで）
- 貼り付け後、アイコンが active（橙）になり、再タップで本文が見える
- 要約・Ⅲ遷移は壊れていない

### 手動確認

1. 要約入力 → 保存 → 解答例取得、の順でも逆順でも両方が残る
2. スワイプ閉じで詳細を抜けても、開き直すと解答例が残る

---

## Step 4 — ランダム画面への配線

### 目的
「ランダム」で問題文が表示されているときも、同じ解答例フローを使えるようにする。

### 指示

1. `layer2_random_screen.dart`:
   - Step 3 の共通ロジックを再利用（コピペ実装禁止）
   - `_drawnPrompt == null` のときは理由枠オフ
   - 抽選後:

```dart
PrepLabelRow(
  showReason: true,
  reasonIcon: Icons.menu_book_rounded,
  // ... Step 3 と同型 ...
  reasonActive: _drawnPrompt!.sampleAnswer.isNotEmpty,
  onReasonTap: ...,
);
```

   - 保存後は `_drawnPrompt` を更新済み `QuestionPrompt` に差し替え（一覧側とデータ共有）
   - リセット（`_resetPrompt`）で表示は消えてよいが、ストレージ上の `sampleAnswer` は消さない
   - カテゴリ変更で `_drawnPrompt = null` になる既存挙動は維持

2. `ChromeAiSubmitMixin` を載せるため `WidgetsBindingObserver` / keep-alive が必要なら追加。ランダム画面は `MainShell` に常駐キャッシュされる点に注意（`appSettings` 購読は既存）。

3. お題取り込み（＋タップ）・サイコロ・GenkiTransportRow のリセットは壊さない。**diagnose／紙飛行機は足さない。**

### 受け入れ

- サイコロ後に解答例アイコンが出る
- 取得→保存→別モードの一覧詳細で同じ問題を開くと解答例が見える（同一 ID）
- 未抽選時にアイコンが出ない／押せない

### 手動確認

1. ランダムで取得 → リセット → 同じ問題を再抽選（運任せ）または一覧から開いて残存確認
2. ＋長押しの既存3ステップが消えていない（解答例行の追加は Step 5）

---

## Step 5 — ヘルプ文 ＋「＋」長押し操作画面

### 目的
追加機能をヘルプと使い方シートに反映する。

### 指示

1. **ヘルプ**（`gradus_l10n.dart` の `help.gradus.layer2.*`、ja/en/vi）:
   - `tip2`: 要約に加え、解答例（Chrome AI）で45秒模範解答を得られる旨
   - `tip3`: ランダムでも解答例ボタンが使える旨
   - 必要なら短い tip を1行追加（tip 数を増やす場合は `layer_help_tips.dart` のキー配列も更新）
   - 「話題を増やす」（tip5）は**通常検索のまま**残し、解答例と混同しない文言にする

2. **一覧詳細の＋長押し**（`_showUsageHelp`）:
   - 既存: 要約 → III
   - 追加: 解答例のステップ（アイコン付き `LayerHelpLine` 推奨）
   - 順序例: ①要約 ②解答例 ③III

3. **ランダムの＋長押し**:
   - 既存カテゴリ／サイコロ／イメージのあとに解答例行を追加
   - 「問題文表示後に解答例アイコン → Chrome AI → コピーして再タップ」が分かること

4. ダブルタップヒント文言が実操作と一致していること（Step 3/4 で付けた hint）

5. `test/help_l10n_test.dart` / `test/help_screen_test.dart` があればキー追加に追従

### 受け入れ

- ヘルプ画面のレイヤーⅡに解答例の説明がある
- 両画面の＋長押しシートに解答例がある
- en/vi 欠落なし

---

## Step 6 — テスト

### 目的
回帰を自動テストで押さえる。

### 指示

1. モデル: Step 1 の round-trip（未実施ならここで）
2. プロンプト: Step 2 のテンプレテスト（未実施ならここで）
3. Widget（推奨）:
   - 一覧詳細: `PrepLabelRow`／解答例アイコンがいること、要約アイコンも残ること
   - ランダム: 抽選前は解答例なし、抽選後（サービスをモック／シード）に出ること
   - 可能なら `sampleAnswer` 非空で `reasonActive` 相当の見た目／タップでシート、まで
4. `url_launcher` モックは既存 layer テストのやり方を踏襲
5. `flutter test` の関連ファイル＋ `flutter analyze`

### 受け入れ

- 追加・更新したテストが緑
- Ⅱの既存テスト（4択入口・要約・25マス）が赤にならない

---

## Step 7 — エキスパートレビュー（①〜④）＋安全な修正

### 目的
実装後のコードベースをレビューし、致命的な重複・ゾンビ・冗長動線・その他を潰す。

### レビュー観点（この4つに限定）

1️⃣ **作成者の意図に反して重複している機能**  
   意図的併存は指摘しない（例: 「話題を増やす」＝お題探しの通常検索 ↔ 解答例＝AIモード45秒文。要約＝自分の答えのメモ ↔ 解答例＝AI模範）。  
   **狙いから外れた二系統**だけ挙げる（例: 紙飛行機と解答例ボタンの二重送信、一覧／ランダムでコピペ実装が残った、Ⅲの「理由」欄に書き込んでいる 等）。

2️⃣ **ゾンビ化している機能**  
   押しても何も起きないボタン、未使用 l10n、`PrepLabelRow` コメントの「レイヤーⅡの Google 検索導線」など実態と違うコメント、到達不能コード、死んだテスト名。

3️⃣ **作成者の意図に反して動線が冗長的な機能**  
   解答例のために余分な画面スタック、確認ダイアログの重複、AI 往復の二重化、ランダム→一覧を経由しないと保存できない、など。

4️⃣ **その他**  
   ヘルプ／＋長押し／ヒントと実 UI の不一致、ja のみ更新、同意文の目的が発音評価のまま、進捗％に解答例が誤混入、アクセシビリティの明らかな欠落。

### 指示

1. Step 1〜6 後のコードを上記①〜④で点検する
2. 明らかで安全な修正は同セッションで直す。大きな設計変更は提案のみ
3. 結果を `docs/prompts/layer2-sample-answer-review.md` に短くまとめる（各項目は **修正済 / 意図的残置 / 提案のみ**）
4. `flutter analyze` と関連テストを通す

### 受け入れ

- レビュー文書がある
- 致命的な重複・ゾンビ・冗長動線・文言不整合が残っていない（残すなら意図的残置理由あり）

---

## Step 依存関係

```
Step 1 モデル sampleAnswer
  → Step 2 AIテンプレ + l10n
    → Step 3 共通ロジック + 一覧詳細
      → Step 4 ランダム
        → Step 5 ヘルプ / ＋長押し
          → Step 6 テスト
            → Step 7 レビュー
```

---

## 使い方（ユーザー → Claude Code）

```
docs/prompts/layer2-sample-answer.md の Step 1 をやって
```

続けて:

```
docs/prompts/layer2-sample-answer.md の Step 2 をやって
```

…と同様に Step 7 まで。

レビュー結果の確認だけしたいとき:

```
docs/prompts/layer2-sample-answer.md の Step 7 をやって
```

（Step 1〜6 未完了なら、先に不足 Step を実施してから Step 7）

---

## 設計メモ（現状との差分）

| 現状 | 本改修 |
|------|--------|
| Ⅱ詳細の理由枠は未使用（要約のみ） | 理由枠＝解答例（Chrome AI） |
| Ⅱランダムの PrepLabelRow は全隠し | 抽選後のみ解答例アイコン |
| 模範解答機能なし | `sampleAnswer` を問題文に保存 |
| Ⅱの Chrome AI 往復なし | 既存 mixin で send／paste |
| ヘルプは要約・イメージ中心 | 解答例の手順を tip／＋長押しに追加 |

### 意図的に残すもの（レビューで「重複」扱いしない）

- **話題を増やす**: 外部の通常 Google 検索（お題インスピレーション）
- **要約**: 学習者自身の答えのメモ（AI 模範解答ではない）
- **Ⅲの理由**: PREP の「理由」記入欄（アイコン位置は同じ予約席だが役割が違う）
