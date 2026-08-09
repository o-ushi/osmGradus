import 'package:flutter_test/flutter_test.dart';

import 'package:osm_gradus/models/vocab_test_session.dart';
import 'package:osm_gradus/models/vocabulary_entry.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';

VocabularyEntry _entry(String id) {
  return VocabularyEntry(
    id: id,
    word: '単語$id',
    translation: 'word$id',
    level: VocabularyLevel.n2,
    createdAt: DateTime(2026),
  );
}

VocabTestSession _session(int count) {
  return VocabTestSession(
    questions: [
      for (var i = 0; i < count; i++) VocabTestQuestion(entry: _entry('$i')),
    ],
  );
}

void main() {
  group('VocabTestSession 基本操作', () {
    test('questionCountは問題数を返す', () {
      expect(_session(10).questionCount, 10);
      expect(_session(3).questionCount, 3);
    });

    test('currentIndexは0から始まる', () {
      expect(_session(10).currentIndex, 0);
    });

    test('currentは現在位置の問題を返す', () {
      final session = _session(3);
      expect(session.current.entry.id, '0');
    });

    test('hasNextは最後の問題でfalseになる', () {
      final session = _session(2);
      expect(session.hasNext, isTrue);
      session.next();
      expect(session.hasNext, isFalse);
    });

    test('next()はcurrentIndexを進める', () {
      final session = _session(3);
      session.next();
      expect(session.currentIndex, 1);
      expect(session.current.entry.id, '1');
    });

    test('next()は最後の問題では何もしない', () {
      final session = _session(2);
      session.next();
      session.next();
      session.next();
      expect(session.currentIndex, 1);
    });

    test('previous()はcurrentIndexを戻す', () {
      final session = _session(3);
      session.next();
      session.next();
      session.previous();
      expect(session.currentIndex, 1);
      expect(session.current.entry.id, '1');
    });

    test('previous()は先頭の問題では何もしない', () {
      final session = _session(2);
      session.previous();
      expect(session.currentIndex, 0);
    });

    test('reopenCurrentForEditingはcompletedをwaitingに戻しsttResultは残す', () {
      final session = _session(1);
      session.completeWithResult('答え');
      session.reopenCurrentForEditing();
      expect(session.current.status, VocabTestQuestionStatus.waiting);
      expect(session.current.sttResult, '答え');
    });
  });

  group('VocabTestSession.allAnswered', () {
    test('waitingの問題が残っている間はfalse', () {
      final session = _session(2);
      expect(session.allAnswered, isFalse);
      session.completeWithResult('answer');
      expect(session.allAnswered, isFalse);
    });

    test('全問がcompletedまたはfailedになるとtrue', () {
      final session = _session(2);
      session.completeWithResult('answer0');
      session.next();
      session.markFailed();
      expect(session.allAnswered, isTrue);
    });
  });

  group('VocabTestSession 状態遷移', () {
    test('setStatusはcurrentの状態を変更する', () {
      final session = _session(1);
      session.setStatus(VocabTestQuestionStatus.recording);
      expect(session.current.status, VocabTestQuestionStatus.recording);
    });

    test('completeWithResultはsttResultを記録しcompletedにする', () {
      final session = _session(1);
      session.completeWithResult('答え');
      expect(session.current.sttResult, '答え');
      expect(session.current.status, VocabTestQuestionStatus.completed);
    });

    test('markFailedはfailedにしsttResultは変更しない', () {
      final session = _session(1);
      session.markFailed();
      expect(session.current.status, VocabTestQuestionStatus.failed);
      expect(session.current.sttResult, isNull);
    });
  });
}
