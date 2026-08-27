# 模範解答フォーマット（質問／日本語／Romaji）＋レイヤーⅣ作成・閲覧

このファイルは Claude Code 向けの実装指示書です。  
ユーザーは次のように指示します。

> `docs/prompts/sample-answer-format-and-layer4.md` の Step N をやって

各 Step は**独立して実行できる粒度**に分けています。前 Step が完了している前提で書いてあります。  
1 Step = 1 セッション推奨。終わったら `flutter analyze`（または該当テスト）で破綻がないことを確認してから次へ進んでください。

**前提（実装済み）:** `docs/prompts/layer2-sample-answer.md` のレイヤーⅡ「解答例」（Chrome AI 往復・`QuestionPrompt.sampleAnswer`・`Layer2SampleAnswerMixin`）は実装済み。本ドキュメントはその上に、(1) 模範解答の保存／表示フォーマット変更、(2) レイヤーⅣでもⅡと同じく作成・閲覧、を載せる。

---

## 機能概要（ユーザーの狙い）

```
【フォーマット】
これまで: 日本語の模範解答本文だけのプレーンテキスト
これから: 次の3ブロック構成（プレーンテキスト・見出しは半角ブラケット）

[質問]
質問本文
[日本語]
日本語の模範回答
[Romaji]
ローマ字での模範回答

【取得・閲覧】
レイヤーⅡ（一覧詳細／ランダム）
  — 既存どおり Chrome AI 往復で取得・保存・閲覧
  — 依頼文を上記フォーマットで返すよう更新

レイヤーⅣ（問題文一覧から選ぶ＝fixedPrompt）
  — Ⅱと同じ「解答例」ボタン挙動で作成・貼り付け・閲覧・長押し再取得
  — 保存先は同じ QuestionPrompt.sampleAnswer（Ⅱで取ったものもⅣで読める／逆も可）
```

**対象外（触らない）:**

| 項目 | 理由 |
|------|------|
| レイヤーⅢの結論・理由・例示 | PREP 記入。解答例で置き換えない |
| レイヤーⅣのタイマー／録音／JSST／PREP・的中度の採点ロジック本体 | 発話・採点フローは変えない。AI往復の**待ち状態の衝突回避**だけは Step 3 で扱う |
| レイヤーⅣ「ランダム」（サイコロお題） | お題バンク由来で `QuestionPrompt.sampleAnswer` を持たない。解答例は「問題文一覧から選ぶ」＝`fixedPrompt` のみ |
| 「話題を増やす」「25マス」 | 無関係 |
| `sampleAnswer` フィールドの分割（JSON化） | 既存の1文字列のまま。見出し付きプレーンテキストで十分 |

---

## UX 仕様（全 Step で固定）

### 保存フォーマット（`QuestionPrompt.sampleAnswer`）

必ず次の順・見出しで揃える（見出し行は半角 `[...]`、本文は直後の行から）:

```
[質問]
{問題文本文。状況条件がある場合は問題文の直後に続けてよい}
[日本語]
{口語・自然な話し言葉の模範解答（約45秒分）}
[Romaji]
{上記日本語のローマ字書き起こし（ヘボン式寄り・読みやすさ優先。長音は一般的な表記で可）}
```

- JSON / markdown 見出し（`#`）は使わない
- 空行はブロック間に1行あってもよい（パーサ／表示は寛容でよい）
- **後方互換:** 旧データ（見出しなしの日本語本文だけ）はそのまま表示してよい。再取得すると新フォーマットになる

### レイヤーⅡ（変更点のみ）

- 取得・貼り付け・長押し再取得の動線は現状維持
- AI 依頼文だけ新フォーマットを要求するよう更新
- 貼り付け妥当性チェック（`isPlausibleSampleAnswer`）は新フォーマットも旧プレーンも通す
- 表示は引き続き `TextViewSheet`（構造化テキストをそのまま見せる）

### レイヤーⅣ（Ⅱと同じ作成・閲覧）

- **対象画面:** `Layer4Screen` の `fixedPrompt != null`（＝「問題文一覧から選ぶ」詳細）
- **ボタン位置:** `PrepLabelRow` の **理由枠**（Ⅱと同じ予約席）
  - アイコン: `Icons.menu_book_rounded`（貼り付け待ち中はⅡと同じく `Icons.content_paste_go_rounded`＋緑）
  - tooltip / ヒント: 「解答例」（待ち中は「貼り付け」）
  - `reasonShowBorder: false`、`reasonHorizontalPadding: 0`
  - `reasonActive:` 取得済み（橙）／貼り付け待ち（緑）はⅡと同型
- **表示条件:** `fixedPrompt != null` のあいだは **常に** `showReason: true`（空でも作成できる。Ⅱ一覧詳細と同じ）
- **タップ挙動（Ⅱと同一）:**

  | 状態 | タップ |
  |------|--------|
  | 解答例が空 かつ 解答例の貼り付け待ちでない | 同意 → Chrome AI 送信 |
  | 解答例の貼り付け待ち | クリップボード貼り付け保存 |
  | 解答例が非空 かつ 待ちでない | `TextViewSheet` で読み取り専用表示 |

- **長押し（取得済み時）:** 再取得（Chrome AI へ再送信）。未取得時の長押しは何もしないでよい
- **例示枠:** 現状どおり採点結果一覧（`list_alt`）。理由枠と衝突させない
- **紙飛行機（PREP・的中度）:** 役割は現状維持。解答例ボタンと**待ち状態を混線させない**（下記「AI往復の衝突」）
- **ランダム（Ⅳ）:** 変更なし（解答例ボタンを出さない）

### AI往復の衝突（Ⅳのみ・必須）

`Layer4Screen` は既に `ChromeAiSubmitMixin` で PREP・的中度の紙飛行機往復を持つ。  
`chromeAiAwaitingPaste` を解答例と共有すると、次が壊れる:

- 紙飛行機待ち中に解答例タップ → 誤って模範解答として保存しようとする
- 解答例待ち中にアプリ復帰 → PREP用 `_pasteAndSaveResult` が誤作動する
- 待ちアイコンが紙飛行機と理由枠の両方／片方に誤表示される

**方針（実装してよい最小案）:**

1. 保留中の用途を区別する（例: `enum` / `String? chromeAiPendingKind` で `sampleAnswer` と `prepHit`）
2. 解答例の送信・貼り付け・アイコン緑／復帰時ペーストは **kind == sampleAnswer** のときだけ動く
3. 紙飛行機の送信・貼り付け・復帰時ペーストは **kind == prepHit**（または従来どおり解答例以外）のときだけ動く
4. 一方を開始するとき、他方の待ちが残っていたらクリアする（同時待ちは禁止）
5. `Layer2SampleAnswerMixin` をⅣに載せる場合は、mixin 側の `onResumedFromExternalApp` と `Layer4Screen` 側の override が食い違わないよう、用途分岐を1箇所に集約する

Ⅱ側の挙動は変えない（Ⅱに紙飛行機往復は無い）。

### AI 依頼内容（Ⅱのテンプレ更新・Ⅳも同じテンプレを使う）

- 渡すもの: 現状どおり `body` ＋（あれば）`situationCondition`
- 返させるもの: 上記3ブロック構成のプレーンテキストのみ
- `[質問]` には渡した問題文（状況があればそれも）をそのまま反映させる
- `[日本語]` は約45秒・口語。PREP の流れは推奨するが「結論：」等のラベルは付けない
- `[Romaji]` は日本語ブロックのローマ字。学習者が音読・発音のイメージに使えること
- 依頼文の言語は ja/en/vi で切り替えるが、`[日本語]`／`[Romaji]` の中身ルールは言語によらず固定

---

## 共通ルール（全 Step 共通・必ず守る）

1. **既存のⅡ往復を壊さない** — 送信／貼り付け待ちアイコン切替／長押し再取得／同意ダイアログは維持。
2. **Ⅳの解答例はⅡと同じ能力** — 作成・貼り付け・閲覧・長押し再取得。可能なら `Layer2SampleAnswerMixin` を再利用し、ロジックを二重実装しない。
3. **Ⅳの PREP・的中度往復を壊さない** — 待ち状態の用途分岐は必須（上記「AI往復の衝突」）。
4. **l10n** — 新規ユーザー向け文言は `gradus_l10n.dart`（ja / en / vi）。既存キーを流用できるなら流用。
5. **後方互換** — 旧 `sampleAnswer`（見出しなし）を落とさない・表示できる。
6. **スコープ外を触らない** — その Step の受け入れ以外のリファクタ・ドキュメント追加はしない（最終 Step のレビュー修正は除く）。
7. **完了報告** — 変更ファイル一覧・手動確認手順・次 Step への前提を短く報告する。

### 現状の主要ファイル（地図）

| 領域 | パス |
|------|------|
| AI 依頼テンプレ | `lib/data/layer2_sample_answer_ai_prompt_template.dart` |
| Ⅱ共通ロジック | `lib/services/layer2_sample_answer_chrome_ai.dart` |
| Chrome AI 送信基盤 | `lib/services/chrome_ai_submit_mixin.dart` |
| Ⅱ一覧詳細 | `lib/views/layers/layer2_question_prompt_detail_screen.dart` |
| Ⅱランダム | `lib/views/layers/layer2_random_screen.dart` |
| 問題文モデル | `lib/models/question_prompt.dart` |
| Ⅳ本体 | `lib/views/layers/layer4_screen.dart` |
| Ⅳ一覧詳細ラッパ | `lib/views/layers/layer4_question_prompt_detail_screen.dart` |
| 閲覧シート | `lib/widgets/text_view_sheet.dart` |
| Prep 予約席 | `lib/widgets/prep_label_row.dart` |
| l10n | `lib/localization/gradus_l10n.dart` |
| ヘルプ | `lib/data/layer_help_tips.dart`（実体は l10n の `help.gradus.layer*`） |
| 既存テンプレテスト | `test/layer2_sample_answer_ai_prompt_template_test.dart` |

---

## Step 1 — AI テンプレ：3ブロック構成を要求する

### 目的
Chrome AI への依頼文を更新し、返ってくる模範解答が `[質問]` / `[日本語]` / `[Romaji]` になるようにする。

### 指示

1. `lib/data/layer2_sample_answer_ai_prompt_template.dart` を更新:
   - ja / en / vi すべての `_copy` で、**返答形式**を明示する
   - 必須: 次の見出しをこの順で使うこと。JSON・markdown 見出し禁止。本文だけ（依頼文のエコーや前置き禁止）
   - `[質問]` = 渡した問題文（状況条件があれば含める）
   - `[日本語]` = 約45秒の口語模範解答
   - `[Romaji]` = そのローマ字
   - 既存の「日本語で書く」「PREPラベル付けない」方針は維持
2. クラス／ファイル先頭コメントを新フォーマットに合わせて更新
3. `test/layer2_sample_answer_ai_prompt_template_test.dart` を更新・追加:
   - 生成プロンプトに `[質問]` / `[日本語]` / `[Romaji]`（または同等の明示指示）が含まれる
   - ja / en / vi でフォーマット指示が欠けない
   - 既存の「短い依頼は URL に載せる」系テストは壊さない（期待文字列が変わるなら合わせて更新）

### 受け入れ

- [ ] AI テンプレが3ブロック返答を明示している（3言語）
- [ ] 関連ユニットテスト緑
- [ ] `flutter analyze` 緑（変更ファイル範囲）

### 手動確認

- （任意）実機でⅡの解答例を再取得し、貼り付け結果に3見出しが含まれること（本 Step ではコード＋テストまでで可。実機は Step 5 以降でもよい）

---

## Step 2 — 貼り付け妥当性：新フォーマットを通す

### 目的
新フォーマットの解答例が「解答例っぽくない」と弾かれないようにする。旧プレーンテキストも通す。

### 指示

1. `lib/services/layer2_sample_answer_chrome_ai.dart` の `isPlausibleSampleAnswer`（および関連メッセージ）を見直し:
   - **通す:** `[日本語]` または `[Romaji]` を含むテキスト／従来どおりの日本語本文っぽいテキスト
   - **弾く:** 明らかに依頼文そのもの・Google の UI 文言だけ・極端に短いゴミ、など既存意図は維持
   - 送った依頼文との同一視で弾くロジックがある場合、新依頼文でも誤爆しないこと
   - Step 1 で依頼文マーカー文言が変わったら、`promptMarkers` も追従する
2. 必要なら小さな純関数に切り出してテストしやすくする（ファイル分割は最小限）
3. ユニットテストを追加（既存の chrome AI / sample answer 系テストファイルへ、または新規 `test/...`）:
   - 3ブロック全文 → plausible
   - 旧プレーン日本語 → plausible
   - 明らかな非解答 → not plausible

### 受け入れ

- [ ] 新フォーマット・旧フォーマットの両方が plausible
- [ ] 関連テスト緑
- [ ] Ⅱの送信／貼り付け動線のコンパイル・解析が通る

### 手動確認

- なし（ロジック＋テストで可）

---

## Step 3 — レイヤーⅣ：解答例の作成・閲覧（Ⅱと同型）

### 目的
「問題文一覧から選ぶ」経路のレイヤーⅣで、Ⅱと同じく模範解答を作成・貼り付け・閲覧・再取得できるようにする。

### 指示

1. **AI往復の用途分岐**（上記「AI往復の衝突」）を先に入れる:
   - `ChromeAiSubmitMixin` または `Layer4Screen`＋`Layer2SampleAnswerMixin` 側で pending kind を持つ
   - PREP・的中度の送信開始時は kind = prepHit、解答例送信開始時は kind = sampleAnswer
   - `onResumedFromExternalApp` は kind に応じて `_pasteAndSaveResult` か解答例ペーストかを呼ぶ
   - 紙飛行機の緑／貼り付け待ち表示は prepHit 待ちのときだけ
   - 理由枠の緑／貼り付けアイコンは sampleAnswer 待ちのときだけ
2. `Layer4Screen`（`fixedPrompt != null`）に解答例 UI を載せる:
   - 可能なら `Layer2SampleAnswerMixin` を `on` に追加し、`sampleAnswerPrompt` / `saveSampleAnswer` を実装
   - `saveSampleAnswer` は `QuestionPromptService.update` で `sampleAnswer` を保存し、画面上の `fixedPrompt` 相当の状態も更新（▲▼で見ている問題文と一致させる。親の `Layer4QuestionPromptDetailScreen` が持っている `_prompt` との同期が必要なら最小限で橋渡し）
   - `PrepLabelRow` の理由枠は UX 仕様どおり（常時表示・タップ／長押しは mixin の `onSampleAnswerTap` / `onSampleAnswerLongPress`）
   - 例示枠（採点結果一覧）の既存条件はそのまま
3. ▲▼で `fixedPrompt` が差し替わったら:
   - 表示中の解答例ボタン状態（active／文言）が新しい問題文に追従
   - 解答例の貼り付け待ち中に問題文を動かさない／動かすなら待ちをクリア（録音中移動拒否に合わせ、busy なら移動拒否でも可。少なくとも**別問題の待ちが残らない**こと）
4. Ⅳランダム（`fixedPrompt == null`）では理由枠を出さない
5. 古いコメント（「Ⅳは閲覧専用」など）があれば実体に合わせて直す（`showSampleAnswerReadOnlySheet` のコメント含む）

### 受け入れ

- [ ] Ⅳ（一覧から選ぶ）で未取得の問題文から解答例を新規作成できる
- [ ] 取得済みはタップで閲覧、長押しで再取得できる
- [ ] 貼り付け待ち中は理由枠が緑の貼り付けアイコンになる（紙飛行機と混線しない）
- [ ] PREP・的中度の紙飛行機往復が従来どおり動く
- [ ] 解答例待ちと PREP 待ちが同時に成立しない／誤保存しない
- [ ] `flutter analyze` 緑

### 手動確認

1. Ⅳ → 問題文一覧から選ぶ → 解答例なしの問題文を開く
2. 解答例アイコン → 同意 → Chrome → 3ブロック回答をコピー → 戻って貼り付け → 保存・表示
3. 再タップで閲覧、長押しで再取得できる
4. 別操作: 発話→採点→紙飛行機の PREP・的中度往復が壊れていない
5. 解答例待ち中に紙飛行機が「貼り付け待ち」見た目にならないこと（および逆）
6. 採点結果がある場合、例示枠の一覧導線が従来どおり動く

---

## Step 4 — ヘルプ／l10n

### 目的
レイヤーⅣのヘルプと、必要ならヒント文言を新仕様に合わせる。

### 指示

1. `lib/localization/gradus_l10n.dart`:
   - `help.gradus.layer4.tip*` に、Ⅳでも「解答例」で Chrome AI に模範解答を作成・閲覧できる旨を短く追記（tip を増やしすぎない。既存 tip2/tip3 付近へ1文足すか、必要なら tip を1つ追加）
   - ja / en / vi を揃える
   - Ⅱの tip で「日本語だけ」と読める表現があれば、質問／日本語／ローマ字構成に合わせて軽く更新（大げさな書き換えはしない）
2. Ⅳの `reasonHintTapText` / 長押しヒントはⅡに合わせて既存キー（`レイヤーⅡ_解答例_取得` 等）を流用してよい。Ⅳ専用キーが必要なら最小限追加
3. `test/help_l10n_test.dart` / `test/help_screen_test.dart` などがある場合は期待値を追従

### 受け入れ

- [ ] Ⅳヘルプに解答例の作成・閲覧の言及がある（3言語）
- [ ] ヘルプ系テスト緑（ある場合）
- [ ] 未使用の新規 l10n キーを増やしすぎない

### 手動確認

- ヘルプ画面でレイヤーⅣの説明に解答例作成が含まれる

---

## Step 5 — テスト固め

### 目的
フォーマット変更とⅣの作成・閲覧の回帰をテストで固定する。

### 指示

1. Step 1〜2 のテンプレ／plausible テストが緑であることを再確認
2. Ⅳ向けのウィジェット／ユニットテストを追加（既存の `test/layer4_*.dart` や screen テストの流儀に合わせる）:
   - `fixedPrompt` あり → 理由枠（解答例）が出る
   - `sampleAnswer` 空／非空で active 見た目やヒントが切り替わる範囲で検証できること
   - pending kind の分岐（解答例待ち vs PREP待ち）を純関数／小さなヘルパーに切り出しているならユニットテストで固定
   - 無理に golden やフル実機フローまで書かない。既存プロジェクトの粒度に合わせる
3. 関連する既存テスト（question_prompt / layer2 / layer4）が赤なら本改修に合わせて直す
4. `flutter test`（関連ファイル）と `flutter analyze`

### 受け入れ

- [ ] 追加・更新テストが緑
- [ ] 本機能に関係する既存テストが緑
- [ ] analyze 緑

### 手動確認

- Step 3 の手動確認を一通り再実施

---

## Step 6 — レビュー（重複・ゾンビ・冗長・その他）

### 目的
実装後のコードを、次の4観点だけで点検し、明らかな問題を直す。

### 観点

1️⃣ **作成者の意図に反して重複している機能**  
   Ⅳで解答例の送受信を mixin と別経路で二重実装、Ⅱと別の保存先、紙飛行機と解答例の役割混線、など。  
   ※ⅡとⅣで同じ mixin を共有するのは意図どおり（重複扱いしない）。

2️⃣ **ゾンビ化している機能**  
   使われない l10n、「Ⅳは閲覧専用」の古いコメント、死んだテスト名、押しても何も起きないボタン。

3️⃣ **作成者の意図に反して動線が冗長的な機能**  
   Ⅳ作成のために余分な画面スタック、不要な確認ダイアログ、ランダムⅣへの無意味な導線、など。

4️⃣ **その他**  
   ヘルプと UI の不一致、ja のみ更新、旧 `sampleAnswer` が読めない、▲▼移動後に別問題の解答例待ちが残る、例示枠（採点一覧）の破壊、解答例と PREP の誤保存。

### 指示

1. Step 1〜5 後のコードを上記①〜④で点検する
2. 明らかで安全な修正は同セッションで直す。大きな設計変更は提案のみ
3. 結果を `docs/prompts/sample-answer-format-and-layer4-review.md` に短くまとめる（各項目は **修正済 / 意図的残置 / 提案のみ**）
4. `flutter analyze` と関連テストを通す

### 受け入れ

- [ ] レビュー文書がある
- [ ] 致命的な重複・ゾンビ・冗長動線・文言不整合が残っていない（残すなら意図的残置理由あり）

---

## Step 依存関係

```
Step 1 AIテンプレ（3ブロック）
  → Step 2 貼り付け妥当性
    → Step 3 レイヤーⅣ作成・閲覧 UI（＋AI待ち用途分岐）
      → Step 4 ヘルプ / l10n
        → Step 5 テスト
          → Step 6 レビュー
```

---

## 使い方（ユーザー → Claude Code）

```
docs/prompts/sample-answer-format-and-layer4.md の Step 1 をやって
```

続けて:

```
docs/prompts/sample-answer-format-and-layer4.md の Step 2 をやって
```

…と同様に Step 6 まで。

レビュー結果の確認だけしたいとき:

```
docs/prompts/sample-answer-format-and-layer4.md の Step 6 をやって
```

（Step 1〜5 未完了なら、先に不足 Step を実施してから Step 6）

---

## 設計メモ（現状との差分）

| 現状 | 本改修 |
|------|--------|
| 模範解答は日本語本文のみ | `[質問]` / `[日本語]` / `[Romaji]` の3ブロック |
| 解答例の作成・閲覧はレイヤーⅡのみ | ⅡとⅣ（一覧から選ぶ）の両方で作成・閲覧。保存先は共通 |
| Ⅳの理由枠は未使用 | 理由枠＝解答例（Ⅱと同型の Chrome AI 往復） |
| Ⅳの `chromeAiAwaitingPaste` は PREP・的中度専用 | 用途分岐で解答例と共存 |
| Ⅳランダム | 変更なし（解答例なし） |

### 意図的に残すもの（レビューで「重複」扱いしない）

- **ⅡとⅣで同じ `Layer2SampleAnswerMixin`／同じ `sampleAnswer` フィールド:** 意図的な共有
- **Ⅳの例示枠＝採点結果一覧:** 解答例とは別
- **Ⅳの紙飛行機＝PREP・的中度:** 解答例とは別（待ち状態だけ衝突回避）
- **旧 sampleAnswer（見出しなし）:** 再取得まで残る。表示は可能
- **`sampleAnswer` の単一 String:** JSON 分割しない
