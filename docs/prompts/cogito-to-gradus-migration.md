# osmCogito → osmGradus 機能移行プロンプト集

App Store で osmCogito が osmGradus と類似でスパム却下されたため、**長文読解・単語登録・長文音読発音・的中度/PREP・ダッシュボード拡張**などを osmGradus に移し、osmCogito は別アプリとして残す。

このファイルは **Claude Code 向けのステップ実行仕様**。一度に全部やらず、指定ステップだけ実装する。

---

## Claude Code への指示文（コピペ用）

ワークスペースは `osmGradus ALL/osm_gradus`。参照元は隣の `osmCogito ALL/osm_cogito`。

```
docs/prompts/cogito-to-gradus-migration.md の Step 1 だけ実行して。
他の Step には手を出さないで。完了条件を満たしたら止めて、変更ファイル一覧と手動確認ポイントを短く報告して。
```

`Step 1` を必要な番号に差し替える（例: Step 3、Step 8）。

複数連続で頼むとき:

```
docs/prompts/cogito-to-gradus-migration.md の Step 2 と Step 3 だけ順に実行して。
各 Step の完了条件を満たしてから次へ。Step 4 以降には手を出さないで。
```

---

## 共通ルール（全 Step）

1. **移植元**: `/Users/osam/Developer/com.osamushikubo/osmCogito ALL/osm_cogito` の該当実装を読んでから、Gradus の既存パターンに合わせて移植する。コピペで `Cogito` プレフィックスを残さない。命名は `gradus` / 既存 Gradus 流儀に合わせる。
2. **触らない**: osmCogito アプリ本体のリポジトリは変更しない（参照のみ）。無関係なリファクタ・ドキュメント追加はしない。
3. **既存 UI 言語**: `PrepLabelRow` / `GenkiTransportRow` / `GhostPill` / `AppColors` / `gradus_l10n.dart`（ja/en/vi）を踏襲。
4. **テスト**: 変更領域に既存テストがあれば更新し、新規は最小限のユニット/ウィジェットテストを足す。
5. **完了報告**: 変更ファイル、受け入れ確認チェックリスト、次 Step への依存だけ報告。

### 参照パス早見

| 領域 | osmCogito | osmGradus |
|------|-----------|-----------|
| レイヤーI入口 | — | `lib/views/layers/layer1_entry_screen.dart` |
| キーワード〜文章生成 | `lib/views/cogito/cogito_setup_screen.dart`, `cogito_article_generate_screen.dart` | （新規） |
| 文章を読む | `lib/views/cogito/cogito_article_reader_screen.dart` | （新規） |
| 単語選択 | `lib/widgets/cogito_word_selectable_text.dart`, `lib/models/cogito_word_selection_mode.dart` | （新規） |
| 訳付け | `lib/views/cogito/cogito_vocab_enrich_screen.dart`, `cogito_related_question_screen.dart`（タップ/長押し） | （新規） |
| 長文音読 | `lib/views/cogito/cogito_long_reading_screen.dart` | （新規）+ Layer V |
| 的中度/PREP | `cogito_evaluation_*`, `cogito_scoring_service.dart` | Layer IV + dashboard |
| 語彙10秒 | `lib/widgets/cogito_vocab_countdown_button.dart` | `layer1_vocab_screen.dart` |
| 音声認識ヘルプ | `cogito_l10n` の `プライバシー_音声認識説明_iOS/Android` | `gradus_l10n.dart` + privacy UI |
| お題 | — | `topic_add_choice_sheet.dart`, `topic_service.dart` |

---

## 依存関係（実行順）

```
Step 1（長文モデル・永続化）
  ├─ Step 2（Layer I 入口 3択）
  ├─ Step 3（長文作成〜読解〜単語登録フロー）
  ├─ Step 4（長文一覧 UI）
  ├─ Step 5（文章を読むボタン配置・訳をつけるジェスチャ）
  ├─ Step 6（単語選択モード設定）
  └─ Step 7（Layer V 短文/長文 + 長文音読）
Step 8（Layer IV 的中度・PREP）  ← 長文と独立可。Step 1 不要
Step 9（ダッシュボード）          ← Step 8 必須。発音に長文結果を含めるなら Step 7 後が望ましい
Step 10（お題 import/export）     ← 独立
Step 11（語彙テスト 10秒タイマー） ← 独立
Step 12（ヘルプ iOS/Android）     ← 独立
Step 13（統合仕上げ・ゾンビ削除・レビュー対策） ← すべて後
```

推奨バッチ: `1→2→3→4→5→6→7` / 並行可: `8`, `10`, `11`, `12` / 最後: `9→13`

---

## Step 1 — 長文データモデルと永続化

### 目的
作成した長文を一覧保存できる基盤を作る（一覧・Layer V ランダム音読の前提）。

### 要件
- モデル例: `id`, `title`（キーワードや先頭抜粋）, `body`, `createdAt`, `updatedAt`, `isFavorite`, `sortOrder`, 生成メタ（keyword / JLPT / length 等、任意）
- `SharedPreferences` または既存の `JsonListStore` 系パターンで永続化
- CRUD: 追加・更新・削除・並び替え・お気に入りトグル
- バックアップ `gradus_backup.dart` に含める（バージョン上げて後方互換）

### 完了条件
- [ ] サービス単体で CRUD・並び替え・★ が動くテストがある
- [ ] UI はまだ最小（デバッグ用で十分）。本格 UI は Step 4
- [ ] 他 Step の画面は作らない

### 実装ヒント
osmCogito に長文一覧は無い。新規設計。語彙の `VocabularyService.reorderEntries` や結果履歴ストレージを参考にする。

---

## Step 2 — レイヤーIトップを3択にする

### 目的
`Layer1EntryScreen` の2択を、指定レイアウトの3系統にする。

### 要件（UI）
```
語彙を増やす
　　長文読解（←アイコン）
　　単語テスト（←アイコン）
日本語に耳を慣らす
　　ヘッドフォンアイコン
```
- 「語彙を増やす」はセクション見出し、「長文読解」「単語テスト」は選択可能な子
- 「日本語に耳を慣らす」は従来どおり Podcast（ヘッドフォン）
- モード enum を拡張（例: `longReading` / `vocab` / `podcast`）。既存のモード保持・Ⅰ再タップで戻る・スワイプでリセットは維持
- 長文読解タップ時は Step 3 の入口へ（Step 3 未実装ならプレースホルダ画面で可）
- 起動サブタイトル・Layer I ヘルプ文言を3択に合わせて更新

### 完了条件
- [ ] 3系統に遷移できる
- [ ] MiniPlayer は Podcast 時のみ表示（従来どおり）
- [ ] 長文フロー本体は Step 3 に任せる

---

## Step 3 — 長文読解フロー（キーワード→生成→読む→単語登録）

### 目的
osmCogito のキーワード画面〜長文作成・読み込み〜単語登録を Gradus Layer I「長文読解」に移植。

### 移植元
- `cogito_setup_screen.dart`（キーワード / おまかせ / JLPT / 緩さ / 長さ）
- `cogito_article_generate_screen.dart` + prompt/parser
- `cogito_article_reader_screen.dart` + `CogitoWordSelectableText`
- `cogito_vocab_enrich_screen.dart`（訳付け）

### 要件
- 動線: キーワード → Chrome AI 生成・貼付 → 文章を読む（タップで単語帳登録）→ 任意で訳付け → 完了時に **Step 1 の長文一覧へ保存**
- Gradus の `VocabularyService` に登録（既存単語帳と統合）
- **やらない（この Step）**: 関連質問・日本語回答・セッションラウンド・中断セッション（Cogito セッション全体は移植しない）
- 文章を読むのボタン最終レイアウトは Step 5。ここでは最低限「次へ」「訳を付ける」で可

### 完了条件
- [ ] Layer I「長文読解」から一連が完走し、長文が永続化される
- [ ] 登録単語が単語帳に出る
- [ ] Cogito セッションシェルは移植しない

---

## Step 4 — 長文一覧画面

### 目的
保存済み長文の一覧・詳細・削除・並び替え・お気に入り。

### 要件
- 一覧表示（★・タイトル/抜粋・日付など）
- タップ → 本文表示 + 単語登録可能な読解画面（Step 3 の reader を再利用）
- 削除（確認ダイアログ）
- 並び替え（ReorderableListView 等、語彙シートと同型で可）
- お気に入り ★ トグル
- 入口: Layer I「長文読解」内に「一覧」導線を置く（例: キーワード画面のツールバー、またはモード選択直後のサブ選択「新規作成 / 一覧」）。**一覧への導線が無い状態で終わらないこと**

### 完了条件
- [ ] 一覧から開いて単語登録できる
- [ ] 削除・並び替え・★ が永続化される
- [ ] Layer V（Step 7）が空判定に使える

---

## Step 5 — 「文章を読む」ボタン配置と「訳をつける」ジェスチャ

### 目的
読解画面の操作バーを仕様どおりにし、訳つけのタップ/長押しを移植。

### 要件 — ボタン
既存の隠れボタン枠（`PrepLabelRow` / `GenkiTransportRow` のスロット）を使い、**余白ゼロ・背景と枠線は透明・なるべく大きいアイコン**。

登録する単語が **無い** 場合:
- 「隠す」「単語帳」「次へ」

登録する単語が **ある** 場合:
- 「訳をつける」「単語帳」「次へ」

- 長文末尾（本文下）の「単語帳」テキストボタンは **削除**
- 「隠す」: 単語ハイライト/登録済み表示などの可視性トグル（実装は Gradus 読解に合わせて定義し、ヘルプに書く）
- 「再生」「リセット」「紙飛行機」スロットの見た目流儀を流用（機能は読解用にマップ）。無理に録音再生を載せず、3スロットを上記ラベル/アイコンに差し替える

### 要件 — 訳をつける
osmCogito `CogitoRelatedQuestionScreen` の実装を移植:
- **タップ** → 訳付け画面へ（自動送信あり = `autoSubmit: true` 相当）
- **長押し** → 訳付け画面へ（単語選び直し = `autoSubmit: false` 相当、画面をすっ飛ばして登録フローへ）

### 完了条件
- [ ] 単語あり/なしでボタンが切り替わる
- [ ] 本文下の単語帳ボタンが無い
- [ ] タップ/長押しの差が動く
- [ ] ja/en/vi 文言あり

---

## Step 6 — 長文の単語選択方式設定（S24 対策）

### 目的
osmCogito の「長押しで単語ごと選択」設定を Gradus に移植。

### 移植元
- `cogito_word_selection_mode.dart`（`character` 既定 / `chunk`）
- `cogito_word_selectable_text.dart`, `cogito_japanese_text_chunks.dart`
- `tts_settings_screen.dart` のスイッチ
- `app_preferences` / `AppSettings`

### 要件
- 設定画面にスイッチを追加（文言は Cogito の `Cogito_単語選択方式*` を Gradus 向けに）
- 読解画面の選択ウィジェットがモードを参照
- prefs キーは Gradus 用に新規（`osmCogito.*` を流用しない）

### 完了条件
- [x] 設定変更が即時または再入場で反映
- [x] character / chunk 両方で登録できる

---

## Step 7 — レイヤーV: 短文 / 長文 + 長文音読発音テスト

### 目的
Layer V トップを2択にし、長文は一覧からランダム音読→発音テスト。

### 要件 — トップ
```
短文（←アイコン）  → 既存 Layer5Screen（短文10問）
長文（←アイコン）  → 長文音読
```
- 長文一覧が空なら「長文」をグレーアウト・タップ不可、Layer I で長文作成するよう案内

### 要件 — 長文タップ時
- 一覧からランダムに1本選ぶ（★優先してもよいが、仕様明記して実装）
- osmCogito `CogitoLongReadingScreen` 相当: 全文表示・録音（赤15秒固定→橙で途中終了可）・STT・Chrome AI 発音評価
- 結果は既存の発音チェック履歴に保存するか、長文用履歴を分けてダッシュボード発音に含める（Step 9 と整合。分けるならモデルに `source: short|long` を付ける）

### 完了条件
- [x] 空一覧で長文不可 + 案内
- [x] あり時はランダム音読→評価まで完走
- [x] 短文フローが壊れていない

---

## Step 8 — レイヤーIV: 的中度と PREP 評点

### 目的
JSST に加え、osmCogito と同様に的中度・PREP を採点。

### 移植元
- `cogito_evaluation_prompt_builder.dart` / `cogito_evaluation_response_parser.dart`
- `cogito_japanese_answer_screen.dart` の AI 評価貼付フロー
- 結果カード・詳細

### 要件
- タイマー終了→JSST（既存）のあと、Chrome AI で `prepStars` / `hitStars`（と advice）を取得・保存
- `SavedScoringResult`（または拡張）に PREP・的中度を永続化
- 結果画面・履歴で JSST / 的中度 / PREP を表示
- Layer III の PREP **ガイド点灯**はそのまま（スコアではない）。混同しない文言に

### 完了条件
- [x] 1回の Layer IV 練習で JSST + 的中度 + PREP が残る
- [x] 旧データ（PREP/的中なし）は壊れず表示できる

---

## Step 9 — ダッシュボード評価の拡張

### 目的
表示と総合計算を仕様どおりに変更。

### 表示
```
総合 A (4.0)
JSST:  7~8   >
的中度: 4.2　>
PREP: 2.5　  >
語彙: 3.7　　>
発音: 5.0　　>
```
- `>` は既存 Gradus どおり行右端
- 各行タップで詳細/履歴（的中度・PREP は Layer IV 履歴の該当フィルタまたは詳細へ）

### 計算
- **JSST 数値化**（直近有効サンプルのレベル帯→点）:
  - 5.0 ← JSST 7~
  - 3.7 ← JSST 5~6
  - 2.3 ← JSST 3~4
  - 1.0 ← JSST 1~2
- 各指標は **過去3回の平均**、表示は **有効数字1桁（小数1桁）**（例: 3 → `3.0`）
- 総合 `ave` = JSST点・的中度・PREP・語彙・発音の平均
- 判定:
  - A: ave >= 4.0
  - B: ave >= 3.0
  - C: ave >= 2.0
  - D: ave >= 1.0
  - E: 上記5指標のうち **1つでも点数がない**（データ欠落）
- 旧ロジック（3指標・F 等）は置き換え。証明書・AIアドバイスプロンプトも新指標に追従

### 完了条件
- [x] UI が5行+総合
- [x] 計算ユニットテスト（境界・欠落→E・小数表示）
- [x] Step 8 の保存データを読む

---

## Step 10 — お題のインポート / エクスポート

### 目的
Layer II〜IV のお題追加シートに JSON の import/export を追加。

### 要件
- `TopicAddChoiceSheet` に「インポート」「エクスポート」を追加（既存「AIで追加」「自分で追加」は維持）
- **インポート**: お題のみの JSON をファイルピッカー等で読み込み、`TopicService` の imported にマージ（スキーマは明示。例: `{ "version": 1, "topics": [ { "category": "...", "text": "..." } ] }`）
- **エクスポート**: **デフォルト（ビルトイン）お題以外**のみを JSON ファイル共有/保存
- 既存の「AIで追加」（Chrome AI）と「JSONインポート」は名前・説明で混同しない
- フルバックアップの topics 節と矛盾しない（二重の真実にしない）

### 完了条件
- [x] 4択シートから import/export できる
- [x] ビルトインが export に混ざらない
- [x] 壊れた JSON はエラー表示で落ちない

---

## Step 11 — 語彙テスト 10秒タイマー

### 目的
osmCogito 同様、語彙テスト録音中に10秒カウントダウン。

### 移植元
- `cogito_vocab_countdown_button.dart`
- `layer1_vocab_screen.dart` の配線（Cogito 側）

### 要件
- Gradus `Layer1VocabScreen` で録音中、マイク位置に10秒タイマーボタン
- タップ早期終了 or 0秒 → 録音停止→STT（既存フローへ）
- キーボード回答モードではタイマー不要（音声モードのみ）

### 完了条件
- [x] 音声モードで10秒制限が効く
- [x] 既存の回答〜紙飛行機評価が壊れていない

---

## Step 12 — 音声認識ヘルプの iOS / Android 分岐

### 目的
iOS ヘルプに `vosk` / `Vosk` を出さない。

### 移植元
- Cogito `プライバシー_音声認識説明_iOS` / `_Android` / 切替（`privacy_data_screen.dart`）

### 要件
- `gradus_l10n.dart`（ja/en/vi）に iOS/Android 別キー
- 表示箇所（プライバシー画面・同意ダイアログ・ポリシー要約）をプラットフォームで切替
- iOS 文言に Vosk という単語を含めない
- Android は OS 認識または Vosk（端末内）を説明してよい
- `docs/privacy-policy-*.md` や審査用文面があれば整合（iOS 向けに Vosk を強調しない）

### 完了条件
- [x] iOS ビルド文字列に Vosk がヘルプ経路で出ないことを確認できる
- [x] Android は従来どおりフォールバック説明がある

---

## Step 13 — 統合仕上げ（重複・ゾンビ・冗長の掃除）

### 目的
本ファイル末尾「スーパーエキスパートレビュー」の **必須対策** を実装する。

### 必須でやること
1. 長文一覧への導線が Layer I から一発で分かることを確認・不足なら補完
2. Layer V 長文結果がダッシュボード「発音」に入ることを確認
3. お題「AIで追加」と「インポート」のラベル衝突を解消（説明文）
4. 使われなくなったプレースホルダ・デッドルート・重複「単語帳」ボタンを削除
5. Layer I/V ヘルプ・起動説明を最終文言に更新
6. 手動テスト観点を `docs/manual-testing-*.md` に短く追記（任意だが推奨）

### 完了条件
- [ ] 下のレビュー「必須対策」チェックがすべて埋まっている
- [ ] `flutter test` の関連失敗が無い

---

# スーパーエキスパートレビュー（対策込み）

調査時点の Gradus / Cogito 実装に基づく。Step 実装時にここを無視するとまたスパゲティになる。

## 1️⃣ 重複している機能

| 項目 | 問題 | 対策（Step） |
|------|------|--------------|
| 短文発音（V）と長文発音（V） | AI プロンプト/パーサが二系統になりやすい | 共通の発音評価パーサを共有し、プロンプトだけ short/long で分岐（Step 7） |
| 単語テスト（I）と長文中の単語登録 | どちらも `VocabularyService` に入るのは正しいが、ダッシュボード「語彙」は **テスト履歴のみ** | 長文登録は語彙点に入れない（現行どおり）。ヘルプで明記（Step 9/13） |
| お題「AIで追加」vs「インポート」 | どちらも「取り込む」印象 | ラベルを「AIで追加」「ファイルをインポート」等に分け、シートに一言説明（Step 10） |
| フルバックアップ vs お題エクスポート | topics が二重経路 | export は imported のみ・バックアップは全体、とコメントと UI で区別（Step 10） |
| Layer III PREP ガイド vs Layer IV PREP 点 | 同名で誤解 | III は「ガイド」、IV/ダッシュボードは「評点」とヘルプで分ける（Step 8/13） |

## 2️⃣ ゾンビ化している機能

| 項目 | 問題 | 対策 |
|------|------|------|
| Cogito セッション全体（関連質問・日本語回答・ラウンド） | Gradus に持ち込むと App Review 的にも「同じアプリ」感が強まる | **移植しない**（Step 3 で明示禁止） |
| 文章下の「単語帳」TextButton | Step 5 で廃止対象。残すと操作が二重 | Step 5 で削除、Step 13 で再grep |
| ダッシュボード旧総合（3指標・F） | 新式（5指標・欠落E）と共存するとバグ | Step 9 で完全置換。証明書も追従 |
| `pointsForJsst` の 0〜4 整数写像 | 新式は 5.0/3.7/2.3/1.0 | Step 9 で置換。旧テストを書き換え |
| 中断セッション（Cogito） | Gradus 長文は一覧保存で足りる | 中断セッションは移植しない |

## 3️⃣ 動線が冗長的になっている機能

| 項目 | 問題 | 対策 |
|------|------|------|
| 長文作成後 → 音読したい | I で作って V に行き直す必要あり | 仕様どおり層分離は維持。読解完了画面に「Layer V で音読できます」と短く案内（Step 3/13） |
| 長文一覧の入口不足 | 要件は一覧機能を求めるが入口が未指定だと死に機能 | Step 4 で「新規 / 一覧」サブ選択を必須化 |
| 訳つけ: 読解の「訳をつける」と enrich の往復 | ループ可能 | enrich 後は読解に戻す（Cogito 同様）。「次へ」で一覧に保存して終了を明確に（Step 3/5） |
| Layer V 長文が毎回ランダム | 練習したい長文を選べない | Step 7 はランダムでよい。不満なら Step 13 で「一覧から選んで音読」をオプション追加（必須ではない） |
| キーワード画面を毎回通す | 一覧から開く場合は不要 | 一覧タップは reader 直入。新規作成だけ setup（Step 3/4） |

## 4️⃣ その他気になること

| 項目 | リスク | 対策 |
|------|--------|------|
| App Store 再審査 | Gradus が Cogito クローンに見える / 逆に Cogito 残存との類似 | Gradus は Layer 体系・Podcast・短文Vを主軸に。Cogito 側は機能縮小して差別化（別リポ作業）。審査メモに「学習レイヤー統合」と書く材料を privacy/help で揃える |
| 総合 E の厳しさ | 5指標すべて埋まらないと E → 紙飛行機が出ない可能性 | 「記録が揃うまで E」とダッシュボードに一文。既存ユーザー向けに、的中度/PREP 追加後は Layer IV を1回やる案内（Step 9） |
| JSST 表示「7~8」と内部点 5.0 | 帯ラベルと平均点の混在 | 行の主表示は帯 or 平均レベル、総合用の写像点は内部計算と明記（Step 9） |
| 的中度/PREP のスケール | Cogito は ★1–5。ダッシュ例は 4.2 | ★平均を小数1桁で表示。総合 ave に同じ 1–5 スケールで入れるか、JSST 写像（最大5）と揃える。**統一スケール 1–5 を推奨**（Step 8/9） |
| 長文の Chrome AI 依存 | オフライン不可 | 既存 Gradus と同じ同意・keep-alive パターンを流用 |
| Android S24 選択 | 未設定だと誤登録 | Step 6 を Step 5 より前でも後でもよいが、読解リリース前に必須 |
| iOS ヘルプの Vosk | 審査・実機不一致の指摘要因 | Step 12 をリリース前必須 |
| バックアップ互換 | 長文・PREP フィールド追加で旧バックアップ壊れ | `gradus_backup` の version bump + 欠落キー許容（Step 1/8） |
| ローカライズ | 新画面が日本語のみになりがち | 各 Step で ja/en/vi を同時追加 |
| パフォーマンス | 長文多数×全文リスト | 一覧は抜粋表示、body は詳細時のみ（Step 4） |

### 必須対策チェックリスト（Step 13 で検証）

- [x] 長文「新規作成」と「一覧」の両方に Layer I から到達できる
- [x] 本文下の重複「単語帳」が無い
- [x] Layer V 長文空状態がグレーアウト＋案内
- [x] ダッシュボード5指標 + 欠落時 E
- [x] お題 AI追加 / ファイルインポートの表記が区別できる
- [x] iOS 音声認識ヘルプに Vosk が無い
- [x] Cogito フルセッション（関連質問〜会話ラウンド）が Gradus に混入していない
- [x] `flutter test` グリーン（関連）

---

## 実装進捗（人手で更新）

| Step | 状態 | 日付 | メモ |
|------|------|------|------|
| 1 | 完了 | 2026-08-07 | `LongArticle`モデル・`LongArticleService`・`gradus_backup`(v4)追加。UIなし（Step4で実装）|
| 2 | 完了 | 2026-08-07 | `Layer1Mode`に`longReading`追加、3択UI実装。長文読解はStep3待ちのプレースホルダ画面 |
| 3 | 完了 | 2026-08-07 | キーワード→Chrome AI生成貼付→タップ登録読解→任意訳付け→長文一覧保存の一連を実装。訳付け画面のウィジェットテストは未追加（パーサーのみユニットテスト） |
| 4 | 完了 | 2026-08-07 | `LongArticleListScreen`追加(一覧・タップ再開・削除確認・並び替え・★)。入口はキーワード画面右上の一覧アイコン。並び替えの実ドラッグ操作テストは未追加(サービス側は既存テストでカバー済み) |
| 5 | 完了 | 2026-08-07 | 本セッション内の別指示で先行実装済みだった内容を正式反映。仕様との差分2点あり: (1)単語なし時は「隠す」ボタンではなく訳付けスロットを単純非表示、(2)タップ/長押しの割当がドラフトと逆（タップ=選び直し、長押し=自動送信）。いずれもユーザーの明示指示による意図的な変更 |
| 6 | 完了 | 2026-08-07 | `LongArticleWordSelectionMode`(character既定/chunk)追加、`AppPreferences`/`AppSettings`に永続化、設定画面にスイッチ追加。`TappableJapaneseText`をヒット単位(`_hitUnits`)で切替可能にリファクタ（タップは常にチャンク単位で不変、長押し＋ドラッグのみモード依存）。デッドゾーン/縦ジッター許容をCogitoから移植 |
| 7 | 完了 | 2026-08-07 | `Layer5EntryScreen`追加（短文/長文2択、`Layer1EntryScreen`と同型）。長文は★優先ランダム抽選→`Layer5LongReadingScreen`で全文表示・録音（最短15秒ロック→オレンジで停止可→3分自動停止、osmCogito方式）・STT・Chrome AI評価（`LongReadingAiPromptTemplate`、本文中に実在するカテゴリのみ評価させる部分スキーマ）。結果は既存`SavedPronunciationCheck`/`PronunciationCheckStorage`を再利用し`source`(`short`/`long`)・`longArticleId`・`longArticleTitle`を追加（ダッシュボードは無改修で両対応、Step 9で要再整理の可能性）。一覧が空なら「長文」をグレーアウト+案内。ヘッダー「Ⅴ」再タップで2択に戻る挙動をLayer1に合わせて新規追加 |
| 8 | 完了 | 2026-08-07 | JSST（既存・ローカル解析）はそのまま、`PrepHitAiPromptTemplate`/`PrepHitAiResponseParser`（osmCogitoの`CogitoEvaluationPromptBuilder`/`CogitoEvaluationResponseParser`を移植、1ラウンド分だけ送るテキストの短いプロンプトでURL上限を回避）でPREP・的中度をChrome AIに追加依頼。`SavedScoringResult`に`prepStars`/`hitStars`/`prepAdvice`/`hitAdvice`/`aiEvaluationUnparsedResponse`を追加、`ScoringResultStorage.update()`で採点直後の同じレコードに後書き。レイヤーⅣのGenkiTransportRowに送信/貼り付けボタンを追加（JSST採点完了後のみ活性化）。結果一覧・詳細にPREP・的中度の★とアドバイスを表示、Layer IIIのPREPガイド（点滅のみ・非スコア）とは見出しに「評価」を付けて区別。旧データ（PREP/的中なし）は`hasAiEvaluation`がfalseになるだけで表示は壊れない |
| 9 | 完了 | 2026-08-07 | `DashboardSummary`/`DashboardSummaryService`をJSST・的中度・PREP・語彙・発音の5指標へ全面書き換え。JSSTは表示（バンドラベル）と総合計算用の点数（レベル1〜4→1.0/2.3/3.7/5.0）を分離、他4指標は1〜5の直近3件平均をそのまま小数1桁で表示。総合`ave`は5指標平均、5つ全て揃わなければ`DashboardOverallGrade.e`（旧F/E廃止・置換）。`DashboardScreen`を5行+総合に、的中度・PREP行はレイヤーⅣ履歴へ遷移。`TranscriptScreen`（証明書）も5区分に拡張。`DashboardAiPromptTemplate`にhitStars/prepStarsとプロンプト指示を追加。紙飛行機の表示条件は総合グレードでなく「素材が1件でもあるか」に変更（Eでも送信可能に） |
| 10 | 完了 | 2026-08-07 | `TopicAddChoiceSheet`を4択（AIで追加/自分で追加/インポート/エクスポート）に拡張。`TopicJsonTransfer`（新規）が`{version, topics:[{category,text}]}`形式でファイルI/O、`TopicService.importTopics`/`loadImported`をそのまま使うため`GradusBackup`のtopics節と同じデータソース（二重の真実にしない）。エクスポートはビルトインお題バンクを含めず取り込み済みのみ。壊れたJSON・不正要素は例外を`FormatException`に集約しエラーダイアログで案内、個々の不正要素（未知カテゴリ・空文字等）は読み飛ばして継続。既存の「AIで追加」（Chrome AI貼り付け）とはラベル・導線を分離して混同を防止 |
| 11 | 完了 | 2026-08-07 | osmCogitoの`CogitoVocabCountdownButton`を`VocabCountdownButton`として移植（`Cogito`プレフィックスは残さない）。見た目は既存の`TopicSpeakerTimerButton`の`counting`状態を流用しつつ、タイマー本体（開始・停止・0秒到達検知）は自前で持つ。`Layer1VocabScreen`の音声モード（`!_isKeyboardMode`）でのみ、録音中（`_recording`）は赤マイクの代わりにこのボタンを表示し、タップ早期終了・0秒到達のいずれも既存の`_stopRecordingAndTranscribe`（回答保存〜紙飛行機評価の既存フロー）へ合流させる新メソッド`_onVocabCountdownFinished`から呼ぶ。キーボード回答モードの分岐には手を入れていないためタイマーは出ない |
| 12 | 完了 | 2026-08-07 | `PrivacyDataScreen`に`Platform.isIOS`/`isAndroid`で切り替える`_speechRecognitionExplanationKey`を追加（`tts_settings_screen.dart`の既存パターンを踏襲）。`プライバシー_音声認識説明_iOS`（Voskに触れない）／`_Android`（Voskフォールバックに言及）をja/en/vi追加、既存の無印キーは非iOS/非Android向けフォールバックとして温存。あわせてダッシュボード・成績証明証のヘルプ文言（`help.gradus.dashboard.tip2`/`transcript.tip2`）がStep 9以前の3指標・A〜F表記のまま古くなっていたのを5指標・A〜D+Eの現行仕様に修正 |
| 13 | 完了 | 2026-08-07 | 仕上げ: 長文保存後にLayer V音読案内スナックバー、ダッシュボードE案内文、お題シートを「ファイルをインポート」+説明文でAI追加と区別、Layer I/III/IV/V/ダッシュボードヘルプを最終文言に更新（Ⅲ=ガイド/Ⅳ=評点、語彙点=テストのみ）、起動のレイヤーⅤ説明を短文/長文対応に更新。ゾンビ確認（本文下単語帳なし・Cogitoセッション未混入・プレースホルダなし）済み |
