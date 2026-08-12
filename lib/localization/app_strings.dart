/// iOS `AppLocaleString` 相当（キーは日本語文字列）
library;

import 'package:flutter/foundation.dart';

import 'gradus_l10n.dart';

abstract final class AppStrings {
  static String text(String key, String languageCode) {
    final lang = switch (languageCode) {
      'en' => 'en',
      'ja' => 'ja',
      _ => 'vi',
    };
    return GradusL10n.data[lang]?[key] ??
        _data[lang]?[key] ??
        _data['ja']?[key] ??
        key;
  }

  /// テスト用：AppStrings 側（osmWashabe由来）に定義されているキー。
  @visibleForTesting
  static Set<String> debugBaseKeysFor(String languageCode) {
    final lang = switch (languageCode) {
      'en' => 'en',
      'ja' => 'ja',
      _ => 'vi',
    };
    return _data[lang]?.keys.toSet() ?? {};
  }

  static const _data = <String, Map<String, String>>{
    'ja': _ja,
    'en': _en,
    'vi': _vi,
  };

  static const _ja = <String, String>{
    '設定': '設定',
    '完了': '完了',
    '言語': '言語',
    'アプリの表示言語を変更できます。': 'アプリの表示言語を変更できます。',
    '読み上げ': '読み上げ',
    '読み上げ_音声なし': '音声なし（設定＞テキスト読み上げ＞日本語を追加）',
    '読み上げ_音声なし_iOS': '日本語音声なし（設定＞アクセシビリティ＞読み上げコンテンツ＞声＞日本語を追加）',
    '声質': '声質',
    '男性の声': '男性の声',
    '女性の声': '女性の声',
    '読み上げ速度': '読み上げ速度',
    'ゆっくり': 'ゆっくり',
    'はやい': 'はやい',
    '使用中の声': '使用中の声',
    '使用中の声_高品質': '現在 %@ を使用中です。',
    '声_高品質': '高品質',
    '声_プレミアム': 'プレミアム',
    '声_標準': '標準',
    'より自然な声: iPhone の設定 → アクセシビリティ → リーダーと読み上げ → 声 → 日本語 → Kyoko または Otoya の高品質版をダウンロード（iOS によっては「読み上げコンテンツ」と表示）':
        '【高品質ボイスの入れ方】\n1. iPhoneの「設定」を開く\n2. 上の検索欄で「声」と入力（見つからなければ「読み上げ」）\n3. 「声」→「日本語」→ Kyoko または Otoya\n4. ↓ から「高品質」をダウンロード\n\n※ メニュー名は iOS のバージョンで異なります。\n・iOS 26 以降: アクセシビリティ → リーダーと読み上げ\n・それ以前: アクセシビリティ → 読み上げコンテンツ',
    'Chrome AI で開く': 'Chrome AI で開く',
    'Chrome AI を開きました': 'Chrome AI を開きました',
    'クリップボードから読み込む': 'クリップボードから読み込む',
    '取り込み済みのお題': '取り込み済みの問題文',
    '取り込み済みお題をすべて削除': '取り込み済み問題文をすべて削除',
    '取り込み済みのお題をすべて削除しました。': '取り込み済みの問題文をすべて削除しました。',
    'Chrome AI 用プロンプト': 'Chrome AI 用プロンプト',
    'AI の出力（確認・編集）': 'AI の出力（確認・編集）',
    '秒': '秒',
    'ヘルプ': 'ヘルプ',
    'English': 'English',
    '日本語': '日本語',
    'Tiếng Việt': 'Tiếng Việt',
    'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。':
        'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。',
    'クリップボードから読み込みました。内容を確認して「お題を取り込む」を押してください。':
        'クリップボードから読み込みました。内容を確認して「問題文を取り込む」を押してください。',
    'お題を読み取れませんでした。【日常】【ビジネス】【シチュエーション】の見出し付きで貼り付けてください。':
        '問題文を読み取れませんでした。【日常】【ビジネス】【シチュエーション】の見出し付きで貼り付けてください。',
    '新しいお題はありませんでした（すべて重複しています）。': '新しい問題文はありませんでした（すべて重複しています）。',
    '日常 %lld 件、ビジネス %lld 件、シチュエーション %lld 件を追加しました。':
        '日常 %1件、ビジネス %2件、シチュエーション %3件を追加しました。',
    'Chrome AI で開く → 回答をコピー → 自動読み込み → 取り込む':
        'Chrome AI で開く → 回答をコピー → 自動読み込み → 取り込む',
    '操作方法': '操作方法',
    '読み上げ一時停止': '読み上げ一時停止',
    'タイマー': 'タイマー',
    r'%lld 件': r'%1$lld 件',
    '採点結果がありません': '採点結果がありません',
    '開発者モードを有効にしました': '開発者モードを有効にしました',
    '開発者モードを無効にしました': '開発者モードを無効にしました',
    '開発者向け': '開発者向け',
    '採点結果_試験版': '（試験版）',
    'JSSTの「待遇表現」「テキストタイプ」「時間の使い方（流暢さ）」の3軸を近似したものです。公式の採点とは異なります。':
        'JSSTの「待遇表現」「テキストタイプ」「時間の使い方（流暢さ）」の3軸を近似したものです。公式の採点とは異なります。',
    '発話内容': '発話内容',
    '発話を認識できませんでした': '発話を認識できませんでした',
    'モデルDL_エラー': '音声認識モデルの準備に失敗しました',
    'マイク権限なし': 'マイクの使用を許可してください（設定 → アプリ → 権限）',
    '待遇表現': '待遇表現',
    '尊敬語': '尊敬語',
    '謙譲語': '謙譲語',
    '丁寧語': '丁寧語',
    '検出された表現はありません': '検出された表現はありません',
    'テキストタイプ': 'テキストタイプ',
    '発話単位数': '発話単位数',
    '複文・重文の数': '複文・重文の数',
    '複雑度': '複雑度',
    '判定まとめ': '判定まとめ',
    '待遇表現の幅': '待遇表現の幅',
    'テキストの複雑さ': 'テキストの複雑さ',
    '参考レベル感': '参考レベル感',
    '敬語の使用は検出されませんでした': '敬語の使用は検出されませんでした',
    '丁寧語のみ': '丁寧語のみ',
    '丁寧語＋尊敬語': '丁寧語＋尊敬語',
    '丁寧語＋謙譲語': '丁寧語＋謙譲語',
    '尊敬語・謙譲語・丁寧語のすべてを使用': '尊敬語・謙譲語・丁寧語のすべてを使用',
    '単文のみ': '単文のみ',
    '単文が中心': '単文が中心',
    '複文・重文を使用': '複文・重文を使用',
    '複文・重文が中心': '複文・重文が中心',
    '3軸の参考値。公式採点とは大きく異なる場合があります。': '3軸の参考値。公式採点とは大きく異なる場合があります。',
    '時間の使い方': '時間の使い方',
    '発話枠': '発話枠',
    '発話文字数': '発話文字数',
    '枠あたりの発話量': '枠あたりの発話量',
    '字/分': '字/分',
    '推定発話時間': '推定発話時間',
    '時間の利用率': '時間の利用率',
    '推定沈黙の割合': '推定沈黙の割合',
    '長い沈黙（4秒以上）': '長い沈黙（4秒以上）',
    '回': '回',
    '最初の発話まで': '最初の発話まで',
    '発話が検出されませんでした': '発話が検出されませんでした',
    '枠をよく使って話している': '枠をよく使って話している',
    'ある程度まとめて話している': 'ある程度まとめて話している',
    '沈黙が多く、発話量が少ない': '沈黙が多く、発話量が少ない',
    '(ログなし)': '(ログなし)',
    '音声認識ログ': '音声認識ログ',
    '音声認識ログ_説明':
        '直近の音声認識の動きを端末に保存しています。フリーズした場合はアプリを再起動し、設定 → 音声認識ログ を開いてください。',
    '音声認識ログ_設定説明': 'フリーズ・クラッシュ後もここからログを確認できます。',
    '表示': '表示',
    '再読み込み': '再読み込み',
    'コピー': 'コピー',
    'コピーしました': 'コピーしました',
    'クリア': 'クリア',
    '丁寧語は検出されず（STTがです/ますを落とした可能性）': '丁寧語は検出されず（STTがです/ますを落とした可能性）',
    '参考サンプルとの比較': '参考サンプルとの比較',
    '参考サンプル_説明': '%1秒枠の参考値と比較しています（15+60秒モードは発話60秒）。流暢さは想定タイミングでシミュレーションしています。',
    'あなた': 'あなた',
    'レベル4参考': 'Lv.4',
    'レベル9参考': 'Lv.9',
    '丁寧語検出数': '丁寧語検出数',
    '参考抜粋を見る': '参考抜粋を見る',
    'JSST 1〜2': 'JSST 1〜2',
    'JSST 3〜4': 'JSST 3〜4',
    'JSST 5〜6': 'JSST 5〜6',
    'JSST 7〜': 'JSST 7〜',
    '参考サンプル_Level4': 'レベル4',
    '参考サンプル_Level9': 'レベル9',
    'キャリブレーション（開発者）': 'キャリブレーション（開発者）',
    '参考レベルが算出できませんでした。キャリブレーションは利用できません。':
        '参考レベルが算出できませんでした。キャリブレーションは利用できません。',
    '参考レベル_日本語として不十分': '日本語として十分に認識できなかったため、参考レベルは算出しません。',
    '参考レベル_発話が短すぎます': '発話が短すぎるため、参考レベルは算出しません。',
    '補正係数': '補正係数',
    '評価傾向': '評価傾向',
    '学習回数': '学習回数',
    '補正後レベル': '補正後レベル',
    '自己評価を入力 (JSST 1–10)': '自己評価を入力 (JSST 1–10)',
    '適用': '適用',
    '甘め': '甘め',
    '辛め': '辛め',
    '各指標の定義': '各指標の定義',
    '各指標の定義_注記': 'この閾値はアプリ独自の近似値です。公式のJSST採点基準とは異なります。',
    '各指標の定義_閾値': '閾値',
    '各指標の定義_参考のみ': '参考のみ（レベル判定には直接使わない）',
    '指標定義_枠あたりの発話量':
        '発話枠（45秒・60秒）あたりの発話量を1分換算した値。STTが認識した文字数 ÷ 発話枠（秒） × 60 で算出します。',
    '指標定義_時間の利用率':
        '発話枠のうち実際に話していたと推定される時間の割合。推定発話時間 ÷ 発話枠で算出（1文字あたり約0.18秒で換算）。値が大きいほど途切れずに話せています。',
    '指標定義_推定沈黙の割合':
        '発話枠のうち沈黙と推定される時間の割合。最初の発話までの時間とチャンク間のギャップから算出。値が小さいほどテンポよく話せています。',
    '指標定義_複雑度':
        '発話を句点（。！？）で区切った単位のうち、従属接続表現（ので・から・けど・ながら等）や並列表現（たり・ですが等）を含む単位の割合。高いほど複文・重文を多用しています。',
    '指標定義_丁寧語の検出数':
        'です/ます体として検出されたユニークな表現の種類数。STTがです/ますを省略することがあるため、口語的代替表現も補完的に集計。レベル判定には直接使わず参考値として表示。',
  };

  static const _en = <String, String>{
    '設定': 'Settings',
    '完了': 'Done',
    '言語': 'Language',
    'アプリの表示言語を変更できます。': 'You can change the app display language.',
    '読み上げ': 'Read Aloud',
    '読み上げ_音声なし': 'No TTS (Settings > Text-to-speech > Add Japanese)',
    '読み上げ_音声なし_iOS':
        'No Japanese voice (Settings > Accessibility > Spoken Content > Voices > Add Japanese)',
    '声質': 'Voice',
    '男性の声': 'Male voice',
    '女性の声': 'Female voice',
    '読み上げ速度': 'Speech rate',
    'ゆっくり': 'Slow',
    'はやい': 'Fast',
    '使用中の声': 'Voice in use',
    '使用中の声_高品質': 'Currently using %@.',
    '声_高品質': 'Enhanced',
    '声_プレミアム': 'Premium',
    '声_標準': 'Standard',
    'より自然な声: iPhone の設定 → アクセシビリティ → リーダーと読み上げ → 声 → 日本語 → Kyoko または Otoya の高品質版をダウンロード（iOS によっては「読み上げコンテンツ」と表示）':
        '【Enhanced voice setup】\n1. Open iPhone Settings\n2. Search for "Voices" (or "Spoken Content" / "Reader")\n3. Tap Voices → Japanese → Kyoko or Otoya\n4. Tap ↓ and download Enhanced\n\nMenu names vary by iOS version:\n• iOS 26+: Accessibility → Reader & Spoken Content\n• Earlier: Accessibility → Spoken Content',
    'Chrome AI で開く': 'Open Chrome AI',
    'Chrome AI を開きました': 'Chrome AI opened',
    'クリップボードから読み込む': 'Load from Clipboard',
    '取り込み済みのお題': 'Imported Prompts',
    '取り込み済みお題をすべて削除': 'Delete All Imported Prompts',
    '取り込み済みのお題をすべて削除しました。': 'All imported prompts have been deleted.',
    'Chrome AI 用プロンプト': 'Chrome AI Prompt',
    'AI の出力（確認・編集）': 'AI Output (Review & Edit)',
    '秒': 'sec',
    'ヘルプ': 'Help',
    'English': 'English',
    '日本語': '日本語',
    'Tiếng Việt': 'Tiếng Việt',
    'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。':
        'No AI answer on clipboard. Long-press in Chrome → Select All → Copy.',
    'クリップボードから読み込みました。内容を確認して「お題を取り込む」を押してください。':
        'Loaded from clipboard. Review then tap Import Prompts.',
    'お題を読み取れませんでした。【日常】【ビジネス】【シチュエーション】の見出し付きで貼り付けてください。':
        'Could not read prompts. Paste with section headers.',
    '新しいお題はありませんでした（すべて重複しています）。': 'No new prompts (all duplicates).',
    '日常 %lld 件、ビジネス %lld 件、シチュエーション %lld 件を追加しました。':
        'Added %1 Daily, %2 Business, %3 Situation prompts.',
    'Chrome AI で開く → 回答をコピー → 自動読み込み → 取り込む':
        'Open Chrome AI → copy → auto-load → import',
    '操作方法': 'How to use',
    '読み上げ一時停止': 'Pause reading',
    'タイマー': 'Timer',
    r'%lld 件': r'%1$lld',
    '採点結果がありません': 'No scoring result yet',
    '開発者モードを有効にしました': 'Developer mode enabled',
    '開発者モードを無効にしました': 'Developer mode disabled',
    '開発者向け': 'Developer',
    '採点結果_試験版': '(Experimental)',
    'JSSTの「待遇表現」「テキストタイプ」「時間の使い方（流暢さ）」の3軸を近似したものです。公式の採点とは異なります。':
        'This approximates the "honorific usage", "sentence complexity", and "time usage (fluency)" axes of the JSST rubric. It is not the official score.',
    '発話内容': 'Transcript',
    '発話を認識できませんでした': 'Could not recognize any speech',
    'モデルDL_エラー': 'Failed to prepare the speech recognition model',
    'マイク権限なし': 'Please allow microphone access (Settings → Apps → Permissions)',
    '待遇表現': 'Honorific Usage',
    '尊敬語': 'Respectful (Sonkeigo)',
    '謙譲語': 'Humble (Kenjougo)',
    '丁寧語': 'Polite (Teineigo)',
    '検出された表現はありません': 'No expressions detected',
    'テキストタイプ': 'Sentence Complexity',
    '発話単位数': 'Utterance units',
    '複文・重文の数': 'Compound/complex units',
    '複雑度': 'Complexity ratio',
    '判定まとめ': 'Summary',
    '待遇表現の幅': 'Honorific breadth',
    'テキストの複雑さ': 'Sentence complexity',
    '参考レベル感': 'Approx. JSST level',
    '敬語の使用は検出されませんでした': 'No honorifics detected',
    '丁寧語のみ': 'Polite form only',
    '丁寧語＋尊敬語': 'Polite + respectful forms',
    '丁寧語＋謙譲語': 'Polite + humble forms',
    '尊敬語・謙譲語・丁寧語のすべてを使用': 'All three honorific types used',
    '単文のみ': 'Simple sentences only',
    '単文が中心': 'Mostly simple sentences',
    '複文・重文を使用': 'Some complex sentences',
    '複文・重文が中心': 'Mostly complex sentences',
    '3軸の参考値。公式採点とは大きく異なる場合があります。':
        'Reference only (3 axes). May differ significantly from official scoring.',
    '時間の使い方': 'Time usage',
    '発話枠': 'Speaking window',
    '発話文字数': 'Characters spoken',
    '枠あたりの発話量': 'Output per window',
    '字/分': ' chars/min',
    '推定発話時間': 'Est. speaking time',
    '時間の利用率': 'Time utilization',
    '推定沈黙の割合': 'Est. silence ratio',
    '長い沈黙（4秒以上）': 'Long pauses (≥4s)',
    '回': '',
    '最初の発話まで': 'Time to first speech',
    '発話が検出されませんでした': 'No speech detected',
    '枠をよく使って話している': 'Good use of the speaking window',
    'ある程度まとめて話している': 'Moderate sustained speech',
    '沈黙が多く、発話量が少ない': 'Many pauses, low output',
    '(ログなし)': '(no log)',
    '音声認識ログ': 'Speech recognition log',
    '音声認識ログ_説明':
        'Recent speech recognition activity is saved on this device. After a freeze, restart the app and open Settings → Speech recognition log.',
    '音声認識ログ_設定説明': 'You can review logs here even after a freeze or crash.',
    '表示': 'View',
    '再読み込み': 'Reload',
    'コピー': 'Copy',
    'コピーしました': 'Copied',
    'クリア': 'Clear',
    '丁寧語は検出されず（STTがです/ますを落とした可能性）':
        'No polite forms detected (STT may have dropped desu/masu endings)',
    '参考サンプルとの比較': 'Compare with reference samples',
    '参考サンプル_説明':
        'Compared using a %1-second speaking window (15+60 mode uses the 60s speaking phase). Fluency uses simulated timing.',
    'あなた': 'You',
    'レベル4参考': 'Lv.4',
    'レベル9参考': 'Lv.9',
    '丁寧語検出数': 'Polite-form hits',
    '参考抜粋を見る': 'View excerpt',
    'JSST 1〜2': 'JSST 1–2',
    'JSST 3〜4': 'JSST 3–4',
    'JSST 5〜6': 'JSST 5–6',
    'JSST 7〜': 'JSST 7+',
    '参考サンプル_Level4': 'Level 4',
    '参考サンプル_Level9': 'Level 9',
    'キャリブレーション（開発者）': 'Calibration (Developer)',
    '参考レベルが算出できませんでした。キャリブレーションは利用できません。':
        'Reference level could not be calculated. Calibration is unavailable.',
    '参考レベル_日本語として不十分':
        'Reference level was not calculated because the speech was not recognized as sufficient Japanese.',
    '参考レベル_発話が短すぎます':
        'Reference level was not calculated because the utterance was too short.',
    '補正係数': 'Correction factor',
    '評価傾向': 'Evaluation tendency',
    '学習回数': 'Learning count',
    '補正後レベル': 'Adjusted level',
    '自己評価を入力 (JSST 1–10)': 'Enter self-assessment (JSST 1–10)',
    '適用': 'Apply',
    '甘め': 'Lenient',
    '辛め': 'Strict',
    '各指標の定義': 'Indicator Definitions',
    '各指標の定義_注記':
        'These thresholds are app-specific approximations, not official JSST criteria.',
    '各指標の定義_閾値': 'Thresholds',
    '各指標の定義_参考のみ': 'Reference only (not used directly in scoring)',
    '指標定義_枠あたりの発話量':
        'Speaking output within the allotted window, normalized to a per-minute rate. Calculated as: character count ÷ allotted seconds × 60.',
    '指標定義_時間の利用率':
        'Estimated proportion of the allotted window actually spent speaking. Calculated as: estimated speaking time ÷ allotted seconds (approx. 5.5 chars/sec). Higher values indicate more sustained speech.',
    '指標定義_推定沈黙の割合':
        'Estimated proportion of the allotted window spent in silence. Derived from time-to-first-speech and inter-chunk gaps. Lower values indicate a better speaking tempo.',
    '指標定義_複雑度':
        'Proportion of utterance units (delimited by sentence-ending punctuation) that contain subordinate connectors (ので, から, けど, ながら, etc.) or coordinating expressions (たり, ですが, etc.). Higher values indicate more complex sentence structures.',
    '指標定義_丁寧語の検出数':
        'Number of unique polite-form patterns (desu/masu endings) detected. Since STT sometimes drops desu/masu, colloquial alternatives are also counted. Shown for reference only; not applied directly to level scoring.',
  };

  static const _vi = <String, String>{
    '設定': 'Cài đặt',
    '完了': 'Xong',
    '言語': 'Ngôn ngữ',
    'アプリの表示言語を変更できます。': 'Bạn có thể đổi ngôn ngữ hiển thị.',
    '読み上げ': 'Đọc to',
    '読み上げ_音声なし': 'Không có TTS (Cài đặt > TTS > Thêm tiếng Nhật)',
    '読み上げ_音声なし_iOS':
        'Không có giọng tiếng Nhật (Cài đặt > Trợ năng > Nội dung đọc > Giọng > Thêm tiếng Nhật)',
    '声質': 'Giọng nói',
    '男性の声': 'Giọng nam',
    '女性の声': 'Giọng nữ',
    '読み上げ速度': 'Tốc độ đọc',
    'ゆっくり': 'Chậm',
    'はやい': 'Nhanh',
    '使用中の声': 'Giọng đang dùng',
    '使用中の声_高品質': 'Đang dùng %@.',
    '声_高品質': 'Nâng cao',
    '声_プレミアム': 'Cao cấp',
    '声_標準': 'Tiêu chuẩn',
    'より自然な声: iPhone の設定 → アクセシビリティ → リーダーと読み上げ → 声 → 日本語 → Kyoko または Otoya の高品質版をダウンロード（iOS によっては「読み上げコンテンツ」と表示）':
        '【Cài giọng Nâng cao】\n1. Mở Cài đặt iPhone\n2. Tìm "Giọng" (hoặc "Nội dung đọc")\n3. Giọng → Tiếng Nhật → Kyoko hoặc Otoya\n4. Nhấn ↓ để tải bản Nâng cao\n\nTên menu khác nhau theo iOS:\n• iOS 26+: Trợ năng → Trình đọc & Nội dung đọc\n• Trước đó: Trợ năng → Nội dung đọc',
    'Chrome AI で開く': 'Mở Chrome AI',
    'Chrome AI を開きました': 'Đã mở Chrome AI',
    'クリップボードから読み込む': 'Tải từ bộ nhớ tạm',
    '取り込み済みのお題': 'Đề bài đã nhập',
    '取り込み済みお題をすべて削除': 'Xóa tất cả đề bài đã nhập',
    '取り込み済みのお題をすべて削除しました。': 'Đã xóa tất cả đề bài đã nhập.',
    'Chrome AI 用プロンプト': 'Prompt cho Chrome AI',
    'AI の出力（確認・編集）': 'Kết quả AI (xem & chỉnh sửa)',
    '秒': 'giây',
    'ヘルプ': 'Trợ giúp',
    'English': 'English',
    '日本語': '日本語',
    'Tiếng Việt': 'Tiếng Việt',
    'クリップボードに AI の回答が見つかりませんでした。Chrome で回答を長押し→すべて選択→コピー してから再度お試しください。':
        'Không tìm thấy câu trả lời AI. Nhấn giữ trong Chrome → Chọn tất cả → Sao chép.',
    'クリップボードから読み込みました。内容を確認して「お題を取り込む」を押してください。':
        'Đã tải từ bộ nhớ tạm. Kiểm tra rồi nhấn Nhập đề bài.',
    'お題を読み取れませんでした。【日常】【ビジネス】【シチュエーション】の見出し付きで貼り付けてください。':
        'Không đọc được đề bài. Dán văn bản có tiêu đề phần.',
    '新しいお題はありませんでした（すべて重複しています）。': 'Không có đề bài mới (trùng hết).',
    '日常 %lld 件、ビジネス %lld 件、シチュエーション %lld 件を追加しました。':
        'Đã thêm %1 Hàng ngày, %2 Công việc, %3 Tình huống.',
    'Chrome AI で開く → 回答をコピー → 自動読み込み → 取り込む':
        'Mở Chrome AI → sao chép → tự tải → nhập',
    '操作方法': 'Cách dùng',
    '読み上げ一時停止': 'Tạm dừng đọc',
    'タイマー': 'Hẹn giờ',
    r'%lld 件': r'%1$lld',
    '採点結果がありません': 'Chưa có kết quả chấm điểm',
    '開発者モードを有効にしました': 'Đã bật chế độ nhà phát triển',
    '開発者モードを無効にしました': 'Đã tắt chế độ nhà phát triển',
    '開発者向け': 'Dành cho nhà phát triển',
    '採点結果_試験版': '(Thử nghiệm)',
    'JSSTの「待遇表現」「テキストタイプ」「時間の使い方（流暢さ）」の3軸を近似したものです。公式の採点とは異なります。':
        'Đây là ước tính cho 3 tiêu chí "kính ngữ", "độ phức tạp câu" và "cách dùng thời gian (độ trôi chảy)" của JSST, không phải điểm chính thức.',
    '発話内容': 'Nội dung đã nói',
    '発話を認識できませんでした': 'Không nhận dạng được giọng nói',
    'モデルDL_エラー': 'Chuẩn bị mô hình nhận dạng giọng nói thất bại',
    'マイク権限なし': 'Vui lòng cho phép sử dụng micrô (Cài đặt → Ứng dụng → Quyền)',
    '待遇表現': 'Cách dùng kính ngữ',
    '尊敬語': 'Kính ngữ (Sonkeigo)',
    '謙譲語': 'Khiêm nhường ngữ (Kenjougo)',
    '丁寧語': 'Lịch sự ngữ (Teineigo)',
    '検出された表現はありません': 'Không phát hiện cách dùng nào',
    'テキストタイプ': 'Độ phức tạp câu',
    '発話単位数': 'Số đơn vị phát ngôn',
    '複文・重文の数': 'Số câu ghép/phức',
    '複雑度': 'Tỷ lệ phức tạp',
    '判定まとめ': 'Tóm tắt',
    '待遇表現の幅': 'Phạm vi kính ngữ',
    'テキストの複雑さ': 'Độ phức tạp văn bản',
    '参考レベル感': 'Mức độ tham khảo',
    '敬語の使用は検出されませんでした': 'Không phát hiện kính ngữ',
    '丁寧語のみ': 'Chỉ thể lịch sự',
    '丁寧語＋尊敬語': 'Thể lịch sự + tôn kính ngữ',
    '丁寧語＋謙譲語': 'Thể lịch sự + khiêm nhường ngữ',
    '尊敬語・謙譲語・丁寧語のすべてを使用': 'Sử dụng cả 3 loại kính ngữ',
    '単文のみ': 'Chỉ câu đơn',
    '単文が中心': 'Chủ yếu câu đơn',
    '複文・重文を使用': 'Có câu phức hợp',
    '複文・重文が中心': 'Chủ yếu câu phức hợp',
    '3軸の参考値。公式採点とは大きく異なる場合があります。':
        'Chỉ mang tính tham khảo (3 trục). Có thể khác đáng kể so với điểm chính thức.',
    '時間の使い方': 'Cách dùng thời gian',
    '発話枠': 'Khung thời gian nói',
    '発話文字数': 'Số ký tự đã nói',
    '枠あたりの発話量': 'Lượng nói / khung',
    '字/分': ' ký tự/phút',
    '推定発話時間': 'Thời gian nói ước tính',
    '時間の利用率': 'Tỷ lệ sử dụng thời gian',
    '推定沈黙の割合': 'Tỷ lệ im lặng ước tính',
    '長い沈黙（4秒以上）': 'Khoảng im lặng dài (≥4s)',
    '回': ' lần',
    '最初の発話まで': 'Đến lần nói đầu',
    '発話が検出されませんでした': 'Không phát hiện lời nói',
    '枠をよく使って話している': 'Sử dụng tốt khung thời gian',
    'ある程度まとめて話している': 'Nói liên tục ở mức vừa phải',
    '沈黙が多く、発話量が少ない': 'Nhiều im lặng, ít nội dung',
    '(ログなし)': '(không có nhật ký)',
    '音声認識ログ': 'Nhật ký nhận dạng giọng nói',
    '音声認識ログ_説明':
        'Hoạt động nhận dạng giọng nói gần đây được lưu trên thiết bị. Sau khi bị đơ, hãy khởi động lại ứng dụng và mở Cài đặt → Nhật ký nhận dạng giọng nói.',
    '音声認識ログ_設定説明': 'Có thể xem nhật ký ở đây ngay cả sau khi bị đơ hoặc crash.',
    '表示': 'Xem',
    '再読み込み': 'Tải lại',
    'コピー': 'Sao chép',
    'コピーしました': 'Đã sao chép',
    'クリア': 'Xóa',
    '丁寧語は検出されず（STTがです/ますを落とした可能性）':
        'Không phát hiện thể lịch sự (STT có thể đã bỏ đuôi desu/masu)',
    '参考サンプルとの比較': 'So sánh với mẫu tham khảo',
    '参考サンプル_説明':
        'So sánh theo khung nói %1 giây (chế độ 15+60 dùng giai đoạn nói 60 giây). Độ trôi chảy được mô phỏng theo thời gian giả định.',
    'あなた': 'Bạn',
    'レベル4参考': 'Lv.4',
    'レベル9参考': 'Lv.9',
    '丁寧語検出数': 'Số lần phát hiện thể lịch sự',
    '参考抜粋を見る': 'Xem đoạn trích',
    'JSST 1〜2': 'JSST 1–2',
    'JSST 3〜4': 'JSST 3–4',
    'JSST 5〜6': 'JSST 5–6',
    'JSST 7〜': 'JSST 7+',
    '参考サンプル_Level4': 'Cấp 4',
    '参考サンプル_Level9': 'Cấp 9',
    'キャリブレーション（開発者）': 'Hiệu chỉnh (Nhà phát triển)',
    '参考レベルが算出できませんでした。キャリブレーションは利用できません。':
        'Không thể tính cấp độ tham chiếu. Không thể sử dụng hiệu chỉnh.',
    '参考レベル_日本語として不十分':
        'Không tính cấp độ tham chiếu vì không nhận dạng đủ tiếng Nhật.',
    '参考レベル_発話が短すぎます': 'Không tính cấp độ tham chiếu vì phát ngôn quá ngắn.',
    '補正係数': 'Hệ số hiệu chỉnh',
    '評価傾向': 'Xu hướng đánh giá',
    '学習回数': 'Số lần học',
    '補正後レベル': 'Cấp độ sau hiệu chỉnh',
    '自己評価を入力 (JSST 1–10)': 'Nhập tự đánh giá (JSST 1–10)',
    '適用': 'Áp dụng',
    '甘め': 'Dễ dãi',
    '辛め': 'Nghiêm khắc',
    '各指標の定義': 'Định nghĩa chỉ số',
    '各指標の定義_注記':
        'Các ngưỡng này là ước tính riêng của ứng dụng, không phải tiêu chí JSST chính thức.',
    '各指標の定義_閾値': 'Ngưỡng',
    '各指標の定義_参考のみ': 'Chỉ tham khảo (không dùng trực tiếp để chấm điểm)',
    '指標定義_枠あたりの発話量':
        'Lượng nói trong khung thời gian quy đổi theo phút. Tính bằng: số ký tự ÷ giây khung × 60.',
    '指標定義_時間の利用率':
        'Tỷ lệ ước tính thực sự nói trong khung. Tính bằng: thời gian nói ÷ khung (khoảng 5,5 ký tự/giây). Giá trị cao hơn cho thấy ít im lặng và nói liên tục hơn.',
    '指標定義_推定沈黙の割合':
        'Tỷ lệ ước tính im lặng trong khung. Bắt nguồn từ thời gian đến lần nói đầu và khoảng cách giữa các đoạn. Giá trị thấp hơn cho thấy nhịp nói tốt hơn.',
    '指標定義_複雑度':
        'Tỷ lệ đơn vị phát ngôn (phân cách bởi dấu câu) chứa liên từ phụ thuộc (ので, から, けど, ながら v.v.) hoặc biểu thức song song (たり, ですが v.v.). Giá trị cao hơn cho thấy câu phức tạp hơn.',
    '指標定義_丁寧語の検出数':
        'Số mẫu thể lịch sự (đuôi desu/masu) được phát hiện. Do STT đôi khi bỏ đuôi desu/masu, các biểu thức thay thế cũng được đếm. Chỉ tham khảo, không dùng trực tiếp để chấm điểm.',
  };
}

extension AppStringsContext on String {
  String tr(String languageCode) => AppStrings.text(this, languageCode);

  String trFmt(String languageCode, List<String> args) {
    var result = tr(languageCode);
    for (var i = 0; i < args.length; i++) {
      final oneBasedAt = '%${i + 1}\$@';
      final oneBasedLld = '%${i + 1}\$lld';
      final oneBasedSimple = '%${i + 1}';
      if (result.contains(oneBasedLld)) {
        result = result.replaceFirst(oneBasedLld, args[i]);
      } else if (result.contains(oneBasedAt)) {
        result = result.replaceFirst(oneBasedAt, args[i]);
      } else if (result.contains(oneBasedSimple)) {
        result = result.replaceFirst(oneBasedSimple, args[i]);
      } else {
        result = result.replaceFirst('%@', args[i]);
        result = result.replaceFirst('%lld', args[i]);
      }
    }
    return result;
  }
}
