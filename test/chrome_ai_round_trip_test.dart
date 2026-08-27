import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/data/layer2_sample_answer_ai_prompt_template.dart';
import 'package:osm_gradus/models/question_prompt.dart';
import 'package:osm_gradus/models/question_prompt_source.dart';
import 'package:osm_gradus/models/topic_category.dart';
import 'package:osm_gradus/services/chrome_ai_round_trip.dart';
import 'package:osm_gradus/services/layer2_sample_answer_chrome_ai.dart';

class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  String? lastUrl;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastUrl = url;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChromeAiRoundTrip.copyPromptAndLaunch', () {
    late _FakeUrlLauncherPlatform launcher;
    late UrlLauncherPlatform originalLauncher;
    var clipboardText = 'stale';

    setUp(() {
      originalLauncher = UrlLauncherPlatform.instance;
      launcher = _FakeUrlLauncherPlatform();
      UrlLauncherPlatform.instance = launcher;
      clipboardText = 'stale';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.getData') {
              return {'text': clipboardText};
            }
            if (call.method == 'Clipboard.setData') {
              clipboardText =
                  (call.arguments as Map)['text'] as String? ?? '';
              return null;
            }
            return null;
          });
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalLauncher;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    test('copyPromptToClipboard=true なら依頼文をクリップボードへ置く', () async {
      final ok = await ChromeAiRoundTrip.copyPromptAndLaunch(
        prompt: '依頼文です',
        url: Uri.parse('https://www.google.co.jp/search?q=test&udm=50'),
        copyPromptToClipboard: true,
      );
      expect(ok, isTrue);
      expect(clipboardText, '依頼文です');
      expect(launcher.lastUrl, contains('google.co.jp'));
    });

    test('copyPromptToClipboard=false なら依頼文を残さず空にする', () async {
      clipboardText = '古い依頼文';
      final ok = await ChromeAiRoundTrip.copyPromptAndLaunch(
        prompt: '短い依頼文',
        url: Uri.parse('https://www.google.co.jp/search?q=short&udm=50'),
        copyPromptToClipboard: false,
      );
      expect(ok, isTrue);
      expect(clipboardText, isEmpty);
    });
  });

  group('Layer2SampleAnswerMixin.isPlausibleSampleAnswer', () {
    test('十分な長さの口語テキストは通す', () {
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(
          '電話ではまず結論から簡潔に話すことが大切です。相手の時間を奪わないよう、'
          '用件を短くまとめて伝えましょう。',
        ),
        isTrue,
      );
    });

    test('依頼文そのものは弾く', () {
      const sent =
          'あなたは日本語スピーキング指導の専門家です。以下の問題文について、'
          '学習者が話す練習に使える「約45秒で話せる模範解答」を1つ作成して'
          'ください。\n\n問題文: テスト\n\nプレーンテキストのみで回答し';
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(
          sent,
          sentPrompt: sent,
        ),
        isFalse,
      );
    });

    test('共有URLだけは弾く', () {
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(
          'https://share.google/abcdefg0123456789',
        ),
        isFalse,
      );
    });

    test('極端に短い文字列は弾く', () {
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer('短い'),
        isFalse,
      );
    });

    test('新フォーマット（[質問]/[日本語]/[Romaji]の3ブロック）は通す', () {
      const answer =
          '[質問]\n'
          '週末はどう過ごしましたか？\n'
          '[日本語]\n'
          '週末は友達と近くの公園に行って、久しぶりにゆっくり話しながら'
          '散歩しました。天気もよかったので気分転換になりました。\n'
          '[Romaji]\n'
          'Shuumatsu wa tomodachi to chikaku no kouen ni itte, hisashiburi '
          'ni yukkuri hanashinagara sanpo shimashita.';
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(answer),
        isTrue,
      );
    });

    test('実際の新依頼文を送ったあと、依頼文そのものの再送は弾き、3ブロック回答は通す', () {
      final prompt = QuestionPrompt.create(
        category: TopicCategory.daily,
        body: '週末はどう過ごしましたか？',
        source: QuestionPromptSource.manual,
      );
      final sent = Layer2SampleAnswerAiPromptTemplate.prompt(
        prompt: prompt,
        lang: 'ja',
      );
      const answer =
          '[質問]\n'
          '週末はどう過ごしましたか？\n'
          '[日本語]\n'
          '週末は友達と近くの公園に行って散歩しました。天気もよく、'
          'ゆっくり話せてよい気分転換になりました。\n'
          '[Romaji]\n'
          'Shuumatsu wa tomodachi to chikaku no kouen ni itte sanpo '
          'shimashita.';

      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(
          sent,
          sentPrompt: sent,
        ),
        isFalse,
      );
      expect(
        Layer2SampleAnswerMixin.isPlausibleSampleAnswer(
          answer,
          sentPrompt: sent,
        ),
        isTrue,
      );
    });
  });

  group('Layer2SampleAnswerMixin.isAcceptableManualPaste', () {
    test('短い本文でも手動貼り付けなら通す', () {
      expect(
        Layer2SampleAnswerMixin.isAcceptableManualPaste('結論から先に伝えます。'),
        isTrue,
      );
    });

    test('依頼文やURLは手動でも弾く', () {
      expect(
        Layer2SampleAnswerMixin.isAcceptableManualPaste(
          '約45秒で話せる模範解答を作成してください',
        ),
        isFalse,
      );
      expect(
        Layer2SampleAnswerMixin.isAcceptableManualPaste('https://example.com/a'),
        isFalse,
      );
    });

    test('新フォーマット（3ブロック）も手動貼り付けで通す', () {
      const answer =
          '[質問]\n'
          '週末はどう過ごしましたか？\n'
          '[日本語]\n'
          '週末は友達と近くの公園に行きました。\n'
          '[Romaji]\n'
          'Shuumatsu wa tomodachi to chikaku no kouen ni ikimashita.';
      expect(
        Layer2SampleAnswerMixin.isAcceptableManualPaste(answer),
        isTrue,
      );
    });
  });
}
