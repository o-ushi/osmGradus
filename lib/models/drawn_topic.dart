import 'topic_category.dart';

/// サイコロで引いた1件のお題。シチュエーションのみ状況(text)と条件(subtext)の
/// 2段構成になる。
class DrawnTopic {
  const DrawnTopic({required this.category, required this.text, this.subtext});

  final TopicCategory category;
  final String text;
  final String? subtext;
}
