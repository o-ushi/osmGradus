import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/widgets/question_prompt_list_row.dart';

/// [QuestionPromptListRow]はダブルタップヒントのため単タップ確定に待機が必要。
Future<void> tapQuestionPromptListRow(
  WidgetTester tester, {
  Finder? row,
}) async {
  await tester.tap(row ?? find.byType(QuestionPromptListRow).first);
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}
