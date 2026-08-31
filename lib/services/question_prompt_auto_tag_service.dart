/// 問題文の本文からタブを自動提案する（Step 4、`question-prompt-tabs.md`）。
///
/// 第1段はキーワード辞書によるオフライン判定のみ（Chrome AI連携は
/// このStepでは対象外、必要になればStep 6以降で拡張する）。マッチした
/// タブをすべて返し、1つもマッチしなければ`['趣味']`へフォールバックする
/// （空タブを禁止するため）。
class QuestionPromptAutoTagService {
  /// タブ別キーワード辞書（[QuestionPromptTabRegistry.builtInTabKeys]と
  /// 同じ並び）。1語でも本文に含まれていればそのタブがマッチする。
  static const Map<String, List<String>> _keywordsByTag = {
    '趣味': ['趣味', '映画', '本', '休日', 'ゲーム', '音楽', '読書'],
    '健康': ['健康', '運動', '体調', '睡眠', '食事'],
    '旅行': ['旅行', '観光', '故郷', '海外', '旅先'],
    '家族': ['家族', '子供', '子ども', '友人', '大切な人', '両親'],
    '環境': ['環境', '自然', '季節', 'リサイクル', '地球'],
    '会社': ['仕事', '職場', '上司', '会議', '取引', '顧客', 'ビジネス', '納期'],
  };

  /// [body]にマッチしたタブをすべて返す。マッチが0件なら`['趣味']`。
  List<String> suggestTags(String body) {
    final matched = [
      for (final entry in _keywordsByTag.entries)
        if (entry.value.any(body.contains)) entry.key,
    ];
    return matched.isEmpty ? const ['趣味'] : matched;
  }
}
