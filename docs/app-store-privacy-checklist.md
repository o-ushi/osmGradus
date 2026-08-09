# App Store Connect 更新チェックリスト

## 提出前に必須

- Googleドキュメントの本文を `docs/privacy-policy-ja.md` で全面的に差し替える
- App Store ConnectのPrivacy Policy URLに公開URLを設定する
- App Review Informationへ `docs/app-review-response-privacy-ja.md` の確認手順を記載する
- 審査メッセージへ同文案を返信する
- Build 5をアップロードし、Build 4ではなくBuild 5を審査対象に選択する

## App Privacy回答の再確認

Appleの質問文と第三者サービスの最新条件を確認し、少なくとも以下を申告対象として精査する。

- User Content > Audio Data
  - 音声認識のためAppleまたは端末の音声認識事業者が処理する可能性
- User Content > Other User Content
  - 発話文字起こし、Google AIへ送る発音チェックデータ
- Search History
  - Google AI検索クエリ、Podcast検索語
- Diagnostics
  - 診断ログは原則ローカルのみ。ユーザーが共有した場合だけ端末外へ出る
- Tracking
  - 広告・クロスアプリ追跡なし

用途は実態に応じて「App Functionality」を選択する。開発者または第三者がデータをユーザー／端末へリンクする可能性については、Googleログイン状態およびOS音声認識事業者の取扱いを考慮して回答する。「収集なし」と一括回答しない。

## 実機確認

- iPad Air 11-inch相当の縦向き・横向きで同意文を最後まで読める
- 同意しない場合に録音・外部送信が始まらない
- Google送信をキャンセルした場合にChromeが開かない
- 設定からプライバシーポリシーを開ける
- 音声認識同意を撤回後、次回利用時に再確認される
- 全データ初期化後、履歴・設定・録音ファイルが残らない
