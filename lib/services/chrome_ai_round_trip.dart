import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Chrome AI（Google検索 AIモード）への往復で使う共通処理。
/// プロンプトをクリップボードへコピーして外部ブラウザを開き、
/// 復帰後に回答テキストを読み取る、というレイヤーⅤ／ダッシュボード共通の
/// 手順を1箇所に集約する。
abstract final class ChromeAiRoundTrip {
  /// [url]を外部アプリで開く。起動に成功したら true。
  ///
  /// [copyPromptToClipboard]が true のときだけ[prompt]をクリップボードへ置く
  /// （長い依頼文を Chrome 側で貼り付ける経路）。false のときは依頼文を
  /// **置かず空にする**。短い依頼は URL の `q` に載るためクリップボードへ
  /// 残す必要がなく、残すと「AI 回答のコピーに失敗した／遅延した」ときに
  /// 依頼文のままを読み取って未変化扱いになりやすい（レイヤーⅡ解答例など）。
  static Future<bool> copyPromptAndLaunch({
    required String prompt,
    required Uri url,
    bool copyPromptToClipboard = true,
  }) async {
    if (copyPromptToClipboard) {
      await Clipboard.setData(ClipboardData(text: prompt));
    } else {
      await Clipboard.setData(const ClipboardData(text: ''));
    }
    try {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// クリップボードのプレーンテキストを trim して返す。空なら null。
  static Future<String?> readClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  /// Chrome へ送る直前にコピーした [sentPrompt] が、まだクリップボードに
  /// 残っているかどうか。AI 回答をコピーせずに戻ったときの誤保存を防ぐ。
  static bool isUnchangedSentPrompt(String? clipboard, String sentPrompt) {
    if (clipboard == null) return false;
    return clipboard.trim() == sentPrompt.trim();
  }
}
