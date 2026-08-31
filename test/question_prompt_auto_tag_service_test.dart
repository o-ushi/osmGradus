import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/services/question_prompt_auto_tag_service.dart';

void main() {
  group('QuestionPromptAutoTagService', () {
    final service = QuestionPromptAutoTagService();

    test('趣味キーワードを含む本文は趣味タグを返す', () {
      expect(
        service.suggestTags('あなたの趣味について、その魅力を説明してください。'),
        contains('趣味'),
      );
    });

    test('複数タブのキーワードを含む本文は両方のタグを返す（例：リモートワーク→会社＋環境）', () {
      final tags = service.suggestTags('在宅勤務（リモートワーク）は環境にも良い影響がありますか。上司はどう考えていますか。');
      expect(tags, containsAll(['会社', '環境']));
    });

    test('健康キーワードを含む本文は健康タグを返す', () {
      expect(service.suggestTags('健康のために毎日運動しています。'), contains('健康'));
    });

    test('マッチするキーワードが無ければ趣味へフォールバックする（空タブ禁止）', () {
      final tags = service.suggestTags('xyzだけの本文');
      expect(tags, ['趣味']);
      expect(tags, isNotEmpty);
    });
  });
}
