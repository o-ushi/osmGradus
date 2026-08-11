import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:osm_gradus/audio/podcast_audio_handler.dart';
import 'package:osm_gradus/main.dart';
import 'package:osm_gradus/models/recording_mode.dart';
import 'package:osm_gradus/models/podcast_episode.dart';
import 'package:osm_gradus/models/podcast_show.dart';
import 'package:osm_gradus/localization/app_strings.dart';
import 'package:osm_gradus/models/pronunciation_exercise.dart';
import 'package:osm_gradus/models/pronunciation_practice_session.dart';
import 'package:osm_gradus/models/vocab_answer_mode.dart';
import 'package:osm_gradus/models/vocabulary_level.dart';
import 'package:osm_gradus/notifiers/app_settings.dart';
import 'package:osm_gradus/services/app_preferences.dart';
import 'package:osm_gradus/data/long_article_omakase_topics.dart';
import 'package:osm_gradus/services/jsst_calibration_preferences.dart';
import 'package:osm_gradus/services/long_article_service.dart';
import 'package:osm_gradus/services/podcast_library_service.dart';
import 'package:osm_gradus/services/privacy_consent_service.dart';
import 'package:osm_gradus/services/pronunciation_check_storage.dart';
import 'package:osm_gradus/services/topic_speech_reader.dart';
import 'package:osm_gradus/services/tts_settings_service.dart';
import 'package:osm_gradus/services/vocabulary_check_storage.dart';
import 'package:osm_gradus/services/vocabulary_service.dart';
import 'package:osm_gradus/views/layers/layer1_vocab_screen.dart';
import 'package:osm_gradus/views/layers/layer5_screen.dart';
import 'package:osm_gradus/views/layers/long_article_list_screen.dart';
import 'package:osm_gradus/views/launch_screen.dart';
import 'package:osm_gradus/widgets/app_header.dart';
import 'package:osm_gradus/widgets/category_select_field.dart';
import 'package:osm_gradus/widgets/curated_show_card.dart';
import 'package:osm_gradus/widgets/dice_action_row.dart';
import 'package:osm_gradus/widgets/genki_transport_row.dart';
import 'package:osm_gradus/widgets/ghost_pill.dart';
import 'package:osm_gradus/widgets/layer_help_sheet.dart';
import 'package:osm_gradus/widgets/prep_label_row.dart';
import 'package:osm_gradus/widgets/pronunciation_exercise_card.dart';
import 'package:osm_gradus/widgets/tappable_japanese_text.dart';
import 'package:osm_gradus/widgets/transport_icon_button.dart';
import 'package:osm_gradus/widgets/vocab_countdown_button.dart';
import 'package:osm_gradus/widgets/vocabulary_sheet.dart';
import 'package:osm_gradus/views/podcast/mini_player_bar.dart';

const _lang = 'vi';
String _t(String key) => key.tr(_lang);

/// 「送信」「リセット」「貼り付け」「総評」等、ダブルタップの機能ヒントが
/// 付いたボタン（Step 7）はGestureDetector.onDoubleTapで単タップ判定を
/// 約300ms（kDoubleTapTimeout）保留するため、単タップとして確定させるには
/// この分だけ余分にpumpする。
const _tapConfirmWait = Duration(milliseconds: 350);

/// 使い方シートの1行で`{{icon}}`より後ろの断片（[LayerHelpLine]のアイコン付き行は
/// アイコンの前後でTextウィジェットが分かれるため、後半だけで照合する）。
String _afterIcon(String key) => _t(key).split('{{icon}}').last;

/// 使い方シートの1行の先頭連番バッジ（1️⃣など）を取り除いた断片
/// （[_HelpLineView]が描画時にバッジを別ウィジェットへ分離するため）。
String _withoutBadge(String key) =>
    _t(key).replaceFirst(RegExp('^[0-9]️⃣[ 　]*'), '');

/// 空状態案内の先頭文（`{{dice}}`より前）。RichText化後も[find.textContaining]で拾える。
String get _layer1EmptyLead => _t('レイヤーⅠ_語彙_空状態').split('{{dice}}').first;

/// 中央のサイコロボタン（空状態案内の小さい`{{dice}}`アイコンと区別する）。
Finder get _vocabDiceButton => find.byWidgetPredicate(
  (widget) =>
      widget is Icon && widget.icon == Icons.casino && (widget.size ?? 0) >= 40,
);

const _curatedL10nKeys = [
  'おすすめ_セクション説明',
  'おすすめ_グループ_初心者',
  'おすすめ_グループ_リスニング',
  'おすすめ_NHK_タイトル',
  'おすすめ_NHK_説明',
  'おすすめ_ゆっくり_タイトル',
  'おすすめ_ゆっくり_説明',
  'おすすめ_教室_タイトル',
  'おすすめ_教室_説明',
  'おすすめ_Noriko_タイトル',
  'おすすめ_Noriko_説明',
  'おすすめ_Yuyu_タイトル',
  'おすすめ_Yuyu_説明',
  'おすすめ_会話_タイトル',
  'おすすめ_会話_説明',
  'おすすめに該当する番組が見つかりませんでした',
  'おすすめ_登録確認',
  '登録する',
];

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences = await AppPreferences.load();
    appSettings = AppSettings(appPreferences);
    audioHandler = PodcastAudioHandler(PodcastLibraryService());
    // レイヤーⅢ/トップ画面が参照するグローバルなTTS設定・読み上げサービス。
    // load()はSharedPreferencesのモック未設定時に呼ぶと不安定なため、
    // ここでは構築のみ行う（テストでは既定値のままで問題ない）。
    ttsSettings = TtsSettingsService();
    topicSpeechReader = TopicSpeechReader(ttsSettings);
    // 採点結果画面（開発者モード時のキャリブレーションカード）が参照する。
    jsstCalibrationPreferences = JsstCalibrationPreferences();
  });

  setUp(() async {
    // SharedPreferencesはプラットフォームチャンネルを使うため、テストでは
    // インメモリのモック値を明示的に設定しておく必要がある。
    // スタートアップ案内は既定ONのため、既存の起動画面テストではオフにする。
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
    });
    appPreferences.showStartupScreen = false;
    // テスト間で標準語彙フラグが漏れないよう既定（ON）に戻す。
    // 決定論的な抽選が必要なテストは個別にOFFにする。
    appSettings.includeDefaultVocabulary = true;
    await PrivacyConsentService.grantSpeechProcessingConsent();
  });

  test('おすすめ関連の文言が日本語・英語・ベトナム語で解決できる', () {
    for (final lang in ['ja', 'en', 'vi']) {
      for (final key in _curatedL10nKeys) {
        final text = key.tr(lang);
        expect(text.trim(), isNotEmpty, reason: '$key is empty for $lang');
        if (lang != 'ja') {
          expect(text, isNot(equals(key)), reason: '$key is missing for $lang');
        }
      }
    }
  });

  testWidgets('レイヤーⅠ画面が例外なく描画され、Podcast登録導線が表示される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();

    expect(find.text(_t('番組を登録してください')), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsWidgets);
  });

  testWidgets('レイヤーⅠ画面の「＋」を長押しすると使い方シートが開く', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_afterIcon('レイヤーⅠ_ポッドキャスト_使い方_番組追加'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅠ_ポッドキャスト_使い方_エピソード選択'), findRichText: true),
      findsOneWidget,
    );
    // 「＋」の長押しはタップと違って番組追加画面を開かない。
    expect(find.text(_t('番組を追加')), findsNothing);
  });

  testWidgets('番組追加画面が開き、URL追加/検索/おすすめの3セクションが表示され、おすすめカードが表示される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();

    // 空状態でも常に表示される上段右の「＋」から追加画面を開く。
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('番組を追加')), findsOneWidget);
    expect(find.text(_t('URLで追加')), findsOneWidget);
    expect(find.text(_t('番組を検索')), findsOneWidget);
    expect(find.text(_t('おすすめ')), findsOneWidget);
    expect(find.text(_t('おすすめ_セクション説明')), findsOneWidget);
    expect(find.text(_t('おすすめ_グループ_初心者')), findsOneWidget);
    expect(find.text(_t('おすすめ_グループ_リスニング')), findsOneWidget);
    expect(find.text(_t('おすすめ_NHK_タイトル')), findsOneWidget);
    expect(find.text(_t('おすすめ_Noriko_タイトル')), findsOneWidget);
    expect(find.text(_t('おすすめ_Yuyu_タイトル')), findsOneWidget);
    expect(find.text(_t('おすすめ_会話_タイトル')), findsOneWidget);
    expect(find.text('Nihongo con Teppei for Beginners'), findsNothing);
  });

  testWidgets('番組追加画面は左端からの右スワイプで閉じる（PageRouteBuilderの実プッシュ経由）', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(_t('番組を追加')), findsOneWidget);

    final gesture = await tester.startGesture(const Offset(16, 100));
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveBy(
      const Offset(80, 0),
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 40),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('番組を追加')), findsNothing);
  });

  testWidgets('番組追加画面：検索欄にフォーカスした状態でも左端からの右スワイプで閉じる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(_t('番組を追加')), findsOneWidget);

    // 検索欄をタップしてフォーカス・キーボード表示状態にしてから入力する。
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'テスト検索語');
    await tester.pump();

    final gesture = await tester.startGesture(const Offset(16, 100));
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveBy(
      const Offset(80, 0),
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 40),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('番組を追加')), findsNothing);
  });

  testWidgets('番組追加画面：おすすめカードの上から右スワイプを始めても、カードのタップ扱いに'
      'ならず画面が閉じる（左端ゾーンとカードの当たり判定が重なる領域の回帰テスト）', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(_t('番組を追加')), findsOneWidget);

    // 最初のおすすめカードの左端（＝スワイプ受付ゾーンと重なる領域）から始める。
    final cardTopLeft = tester.getTopLeft(find.byType(CuratedShowCard).first);
    final gesture = await tester.startGesture(
      cardTopLeft + const Offset(2, 10),
    );
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveBy(
      const Offset(80, 0),
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 40),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // カードのonTapが誤って発火していれば「登録確認」ダイアログが残り、
    // 画面は閉じないはず。
    expect(find.text(_t('番組を追加')), findsNothing);
  });

  testWidgets('登録済み番組を展開すると、エピソード一覧が例外なく描画される（折りたたみカードの回帰テスト）', (
    WidgetTester tester,
  ) async {
    final show = const PodcastShow(
      id: 'show1',
      title: 'テスト番組',
      feedUrl: 'https://example.com/feed',
    );
    final episode = PodcastEpisode(
      showId: 'show1',
      showTitle: 'テスト番組',
      audioUrl: 'https://example.com/ep1.mp3',
      title: '第1回　テストエピソード',
      publishedAt: DateTime(2026, 1, 1),
      totalDuration: const Duration(minutes: 30),
    );
    SharedPreferences.setMockInitialValues({
      'podcast.registeredShows': [jsonEncode(show.toJson())],
      'podcast.episodes.show1': [jsonEncode(episode.toJson())],
      'podcast.expandedShowIds': ['show1'],
    });

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    // ネットワーク取得は失敗する（テスト環境ではHTTPが常に400になる）ため、
    // pumpAndSettleではなく明示的なpumpでキャッシュ済みデータの描画を待つ。
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(tester.takeException(), isNull);
    expect(find.text('テスト番組'), findsOneWidget);
    expect(find.text('第1回　テストエピソード'), findsOneWidget);
  });

  testWidgets('並べ替えシートを開いて基準を変更すると、エピソードの並び順が変わる', (WidgetTester tester) async {
    final show = const PodcastShow(
      id: 'show1',
      title: 'テスト番組',
      feedUrl: 'https://example.com/feed',
    );
    final episodeA = PodcastEpisode(
      showId: 'show1',
      showTitle: 'テスト番組',
      audioUrl: 'https://example.com/a.mp3',
      title: 'Aエピソード',
      publishedAt: DateTime(2026, 1, 1),
    );
    final episodeZ = PodcastEpisode(
      showId: 'show1',
      showTitle: 'テスト番組',
      audioUrl: 'https://example.com/z.mp3',
      title: 'Zエピソード',
      publishedAt: DateTime(2026, 2, 1),
    );
    SharedPreferences.setMockInitialValues({
      'podcast.registeredShows': [jsonEncode(show.toJson())],
      'podcast.episodes.show1': [
        jsonEncode(episodeA.toJson()),
        jsonEncode(episodeZ.toJson()),
      ],
      'podcast.expandedShowIds': ['show1'],
    });

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // 既定（日付・降順）では新しいZエピソードが先に来る。
    var titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t == 'Aエピソード' || t == 'Zエピソード')
        .toList();
    expect(titles, ['Zエピソード', 'Aエピソード']);

    // 並べ替えアイコンをタップしてシートを開き、「名前」＋「昇順」に変更する。
    await tester.tap(find.byIcon(Icons.swap_vert));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.text(_t('並べ替え')), findsOneWidget);

    await tester.tap(find.text(_t('名前')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('昇順')));
    await tester.pumpAndSettle();

    // シートの背後にあるエピソード一覧は、setStateの反映後は
    // ウィジェットツリー上に既に新しい並び順で存在している。
    titles = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .where((t) => t == 'Aエピソード' || t == 'Zエピソード')
        .toList();
    expect(titles, ['Aエピソード', 'Zエピソード']);
  });

  testWidgets('ジャンプバーは画面に固定され、直近で展開した番組だけを対象に動く', (WidgetTester tester) async {
    // 番組2つ分のカード（各12エピソード）が同時にビルドされるよう、
    // ListView.builderの遅延ビルドに引っかからない縦長のビューポートにする。
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 番組ごとにジャンプバーの表示閾値(10件)以上のエピソードを用意する。
    List<String> episodesJsonFor(String showId) => List.generate(12, (i) {
      final episode = PodcastEpisode(
        showId: showId,
        showTitle: showId,
        audioUrl: 'https://example.com/$showId/ep$i.mp3',
        title: '$showId-エピソード$i',
        publishedAt: DateTime(2026, 1, i + 1),
      );
      return jsonEncode(episode.toJson());
    });

    final showA = const PodcastShow(
      id: 'showA',
      title: '番組A',
      feedUrl: 'https://example.com/a/feed',
    );
    final showB = const PodcastShow(
      id: 'showB',
      title: '番組B',
      feedUrl: 'https://example.com/b/feed',
    );
    SharedPreferences.setMockInitialValues({
      'podcast.registeredShows': [
        jsonEncode(showA.toJson()),
        jsonEncode(showB.toJson()),
      ],
      'podcast.episodes.showA': episodesJsonFor('showA'),
      'podcast.episodes.showB': episodesJsonFor('showB'),
      'podcast.expandedShowIds': ['showA', 'showB'],
    });

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    // 番組カードの中ではなく、画面に固定されたジャンプバーが1つだけ存在する
    // （番組ごとに個別のバーは持たない）。
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);

    // 両方の番組が復元された展開状態の場合、先に展開された番組（showA）が
    // 初期フォーカスになる。ジャンプボタンをタップしても番組Bには影響しない。
    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('番組B'), findsOneWidget);
    expect(find.text('showB-エピソード11'), findsOneWidget);
  });

  testWidgets('下端にジャンプしてから上端に戻ると、番組名（ヘッダー）が画面内に見える', (
    WidgetTester tester,
  ) async {
    // 実機に近い縦長の狭いビューポートにする（広すぎると全件が最初から
    // 画面内に収まってしまい、スクロールが発生する不具合を再現できない）。
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final show = const PodcastShow(
      id: 'show1',
      title: 'テスト番組',
      feedUrl: 'https://example.com/feed',
    );
    final episodesJson = List.generate(15, (i) {
      final episode = PodcastEpisode(
        showId: 'show1',
        showTitle: 'テスト番組',
        audioUrl: 'https://example.com/ep$i.mp3',
        title: 'エピソード$i',
        publishedAt: DateTime(2026, 1, i + 1),
      );
      return jsonEncode(episode.toJson());
    });
    SharedPreferences.setMockInitialValues({
      'podcast.registeredShows': [jsonEncode(show.toJson())],
      'podcast.episodes.show1': episodesJson,
      'podcast.expandedShowIds': ['show1'],
    });

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_downward));
    await tester.pump();
    // 下端へ移動した直後は番組名が画面外（上）にスクロールされている。
    expect(tester.getTopLeft(find.text('テスト番組')).dy, lessThan(0));

    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pump();
    // 上端へ戻ると、番組名は画面内（上端付近）に見えていなければならない。
    final headerTop = tester.getTopLeft(find.text('テスト番組')).dy;
    expect(headerTop, greaterThanOrEqualTo(0));
    // セーフエリア+ツールバー分のオフセットを考慮した余裕を持たせる
    // （画面外に隠れていないことが確認できれば十分）。
    expect(headerTop, lessThan(300));
  });

  testWidgets('レイヤーⅡ画面が例外なく描画され、カテゴリ選択とサイコロボタンが表示される', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();

    // ヘッダーの「Ⅱ」をタップしてレイヤーⅡへ即時切り替え。
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    // Ⅱ画面では「45」「60」「15+60」は枠自体は残るが背景色に同化して実質非表示になり、
    // タップにも反応しない（IgnorePointerでignoring: true）。
    for (final label in ['45', '60', '15+60']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }
    // 「＋」をお題の取り込み導線として使う。
    final addIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(addIgnorePointer.ignoring, isFalse);

    // 「結論」「例示」「再生」「リセット」「診断」はⅡ画面では未使用のため、
    // 枠は残るがすべて非表示（タップ無効）状態。「理由」枠だけ🌐として表示する。
    for (final label in ['結論', '例示']) {
      final finder = find.text(_t(label));
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }
    final globeIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(of: find.text('🌐'), matching: find.byType(IgnorePointer))
          .first,
    );
    expect(globeIgnorePointer.ignoring, isFalse);
    for (final icon in [
      Icons.play_arrow_rounded,
      Icons.refresh_rounded,
      Icons.send_rounded,
    ]) {
      final finder = find.byIcon(icon);
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }

    // カテゴリ選択トリガーには選択中カテゴリ（初期値）が表示される。
    expect(find.text(_t('日常の身近な話題')), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsOneWidget);

    // トリガーをタップするとosmWashabeと同じ一覧シートが開き、他のカテゴリを選べる。
    await tester.tap(find.text(_t('日常の身近な話題')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ビジネスシーン')), findsOneWidget);
    expect(find.text(_t('シチュエーション')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
    await tester.tap(find.text(_t('ビジネスシーン')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ビジネスシーン')), findsOneWidget);

    // ダイスタップ中は不確定なCircularProgressIndicatorが一瞬表示されるため、
    // pumpAndSettleではなく明示的なpumpで非同期処理の完了を待つ。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);
  });

  testWidgets('シチュエーションのお題で文章が長くなっても、サイコロボタンの位置は動かない', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    // お題を引く前のサイコロボタンのY座標を記録する。
    final initialY = tester.getTopLeft(find.byIcon(Icons.casino)).dy;

    // シチュエーションカテゴリ（本文＋条件文の2行構成で文章が長くなりやすい）に切り替える。
    await tester.tap(find.text(_t('日常の身近な話題')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('シチュエーション')));
    await tester.pumpAndSettle();

    // 複数回引いて、長めの本文＋条件文が表示された状態でも位置がずれないことを確認する。
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final drawnY = tester.getTopLeft(find.byIcon(Icons.casino)).dy;
      expect(drawnY, initialY);
    }
  });

  testWidgets('🌐ボタンをタップすると、選択中カテゴリの検索語で外部ブラウザが開く', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('🌐'));
    await tester.pumpAndSettle();

    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    final launched = Uri.parse(fakeUrlLauncher.launchedUrls.single);
    expect(launched.host, 'www.google.com');
    expect(launched.queryParameters['q'], '日本語 日常会話 お題 一覧');
  });

  testWidgets('レイヤーⅡ画面の「＋」を長押しすると使い方シートが開く', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // タイトルはそのまま見つかる。本文は独自のカスタム行に置き換わっている。
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅡ_使い方_分野'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅡ_使い方_サイコロ'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅡ_使い方_イメージ'), findRichText: true),
      findsOneWidget,
    );
    // 「＋」の長押しはタップと違って取り込み画面を開かない。
    expect(find.text(_t('お題の取り込み')), findsNothing);
  });

  testWidgets('レイヤーⅡ表示中に言語設定を変更すると、MainShellに再訪しなくても即座に翻訳が切り替わる'
      '（IndexedStackがレイヤー画面を破棄せず保持するため、appSettingsを直接購読していないと'
      '古い言語のまま表示され続ける回帰テスト）', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    expect(find.text(_t('なんて回答するかイメージして')), findsOneWidget);

    // 設定画面を経由せず、appSettingsの変更だけを直接発火させる
    // （MainShell・Layer2Screenは破棄されず保持され続けるため、実機で
    // 設定→言語変更→戻る、を行った状態と同じ状況を再現できる）。
    appSettings.language = 'en';
    await tester.pump();

    expect(find.text('Imagine how you would answer'.tr('en')), findsOneWidget);
    expect(find.text(_t('なんて回答するかイメージして')), findsNothing);

    appSettings.language = 'vi';
    await tester.pump();
  });

  testWidgets('レイヤーⅡ「ランダム」画面はサイコロで問題文をランダムに引ける。'
      '45/60/15+60は隠れたまま、カテゴリに「ランダム」は選べない', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3拡張: レイヤーⅡ入口の3択から「ランダム」を選ぶと、
    // [Layer2RandomScreen]（QuestionPromptServiceから1件引く）が開く。
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();

    // 45/60/15+60は枠自体は残るが背景色に同化して実質非表示になり、
    // タップにも反応しない（[Layer2Screen]の「話題を増やす」と同じ扱い）。
    for (final label in ['45', '60', '15+60']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }

    expect(find.text(_t('日常の身近な話題')), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsOneWidget);
    expect(find.text(_t('どんな回答をするか想像して')), findsOneWidget);

    // QuestionPrompt.fieldはrandomを取らないため、この画面のカテゴリ一覧には
    // 「ランダム」が出ない（「話題を増やす」のTopicCategoryとは異なるプールを
    // 使う回帰確認）。
    await tester.tap(find.text(_t('日常の身近な話題')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ビジネスシーン')), findsOneWidget);
    expect(find.text(_t('シチュエーション')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsNothing);
    await tester.tap(find.text(_t('ビジネスシーン')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ビジネスシーン')), findsOneWidget);

    // ダイスタップ中は不確定なCircularProgressIndicatorが一瞬表示されるため、
    // pumpAndSettleではなく明示的なpumpで非同期処理の完了を待つ。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);
  });

  testWidgets('レイヤーⅡ「ランダム」画面：リセットで問題文をプレースホルダーに戻せる', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    // 「リセット」にはダブルタップの機能ヒント（Step 7）が付いており、単タップ
    // 判定を約300ms（kDoubleTapTimeout）保留するため、確定するまで余分にpumpする。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsOneWidget);
  });

  testWidgets('レイヤーⅡ「ランダム」画面：＋長押しで実際の挙動に合った使い方シートが開き、'
      'リセットのダブルタップは機能ヒントを出すだけで単タップの動作は実行されない。'
      'サイコロはヒント対象外（連打できる）', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅡ_ランダム_使い方_分野'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅡ_ランダム_使い方_サイコロ'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅡ_ランダム_使い方_イメージ'), findRichText: true),
      findsOneWidget,
    );
    // ＋の長押しはタップと違って取り込み画面を開かない。
    expect(find.text(_t('お題の取り込み')), findsNothing);

    // シートを閉じる。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // 引いておく（リセットの単タップ効果と区別するため）。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    Future<void> doubleTap(Finder finder) async {
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(finder);
      await tester.pump(const Duration(milliseconds: 100));
    }

    await doubleTap(find.byIcon(Icons.refresh_rounded));
    expect(find.textContaining(_t('リセット')), findsWidgets);
    // ダブルタップはヒントを出すだけで、単タップの「リセット」は実行されない
    // （引いた問題文がまだ表示されたまま）。
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    // サイコロはダブルタップの対象外（連打する操作系ボタンのため、
    // [PronunciationMicButton]・他レイヤーのサイコロと同じくヒント無し）。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('レイヤーⅤ画面の「＋」を長押しすると使い方シートが開く', (WidgetTester tester) async {
    await _pumpLayer5Standalone(tester);

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_afterIcon('レイヤーⅤ_使い方_サイコロ'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅤ_使い方_マイク'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅤ_使い方_10問'), findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('お題の取り込み画面がosmWashabeと同じ動線（Chrome AI/貼り付け/取り込み/全削除）で開く', (
    WidgetTester tester,
  ) async {
    // 画面全体（3カード分）が一度にビルドされるよう縦長のビューポートにする。
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();

    // 「＋」にはダブルタップの機能ヒント（Step 7）が付いており、単タップ判定を
    // 約300ms（kDoubleTapTimeout）保留するため、確定するまで余分にpumpする。
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // 「＋」はまず「AIで追加」「自分で追加」の選択シートを開く。
    expect(find.text(_t('AIで追加')), findsOneWidget);
    expect(find.text(_t('自分で追加')), findsOneWidget);
    await tester.tap(find.text(_t('AIで追加')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // osmWashabeの実画面と同じ構成要素が揃っていること。
    expect(find.text(_t('お題の取り込み')), findsWidgets);
    expect(find.text(_t('Chrome AI で開く')), findsOneWidget);
    expect(find.text(_t('クリップボードから読み込む')), findsOneWidget);
    expect(find.text(_t('取り込む')), findsOneWidget);
    expect(find.text(_t('Chrome AI 用プロンプト')), findsOneWidget);
    expect(
      find.textContaining('あなたは日本語スピーチ練習用のお題を作成するアシスタントです'),
      findsOneWidget,
    );
    expect(find.text(_t('取り込み済みのお題')), findsOneWidget);
    expect(find.text(_t('全てクリア')), findsOneWidget);

    // 貼り付け欄に見出し付きテキストを入力して取り込む。
    await tester.enterText(
      find.byType(TextField),
      '【日常の身近な話題】\n1. 趣味について話してください。\n2. 休日の過ごし方を教えてください。',
    );
    await tester.pump();
    await tester.tap(find.text(_t('取り込む')));
    await tester.pump();

    expect(tester.takeException(), isNull);
    // osmWashabeと同じ書式の結果メッセージが表示される。
    expect(
      find.text(
        '日常の身近な話題 %lld 件、ビジネスシーン %lld 件、シチュエーション %lld 件を追加しました。'.trFmt(_lang, [
          '2',
          '0',
          '0',
        ]),
      ),
      findsOneWidget,
    );

    // 全てクリアで確認ダイアログが出て、削除するとメッセージが更新される。
    await tester.tap(find.text(_t('全てクリア')));
    await tester.pumpAndSettle();
    expect(find.text(_t('取り込み済みお題をすべて削除')), findsOneWidget);
    await tester.tap(find.text(_t('削除')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('取り込み済みのお題をすべて削除しました。')), findsOneWidget);
  });

  testWidgets('レイヤーⅢ画面はレイヤーⅡと同じ構成をベースに、対象ボタンだけが可視化されている', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅲ'));
    await tester.pumpAndSettle();
    // Step 4: レイヤーⅢ入口の2択から「ランダム」を選ぶと、既存の
    // サイコロ画面（Layer3Screen）が開く。
    await tester.tap(find.text(_t('ランダム')));
    // レイヤーⅢのPREPガイドは常時点滅する（無限に繰り返す）AnimationControllerを
    // 持つため、pumpAndSettle()は永久に終わらない。以降は明示的なpump()を使う。
    await tester.pump();

    // 分野リストとお題カードはレイヤーⅡと同じく表示される。
    expect(find.text(_t('日常の身近な話題')), findsOneWidget);
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsOneWidget);

    // 45/60/15+60はレイヤーⅡと違い実際に選択できる（IgnorePointerでignoring: false）。
    for (final label in ['45', '60', '15+60']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isFalse);
    }
    // 「＋」は操作方法シートの導線として実際に使える（お題取り込みはⅡ側）。
    final addIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(addIgnorePointer.ignoring, isFalse);

    // 結論/理由/例示はレイヤーⅡと違い実際に見える（PrepStageRowは常にignoring: false）。
    for (final label in ['結論', '理由', '例示']) {
      expect(find.text(_t(label)), findsOneWidget);
    }

    // 「再生」「診断」はまだ表示しない
    // （ロジックは実装済みだがUIには出さない、という今回の要件通り）。
    for (final icon in [Icons.play_arrow_rounded, Icons.send_rounded]) {
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byIcon(icon),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }
    // 「リセット」は読み上げ・カウントダウンの中止用に実際に表示・操作できる。
    final resetIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.refresh_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(resetIgnorePointer.ignoring, isFalse);

    // 読み上げ設定へのエントリーポイントはトップ画面（右下）にあるため、
    // レイヤーⅢ画面自体には歯車アイコンを置かない。
    expect(find.byIcon(Icons.settings), findsNothing);

    // 60秒プリセットをタップしても例外なく切り替わる。
    await tester.tap(find.text('60'));
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 60秒（45/60秒モード）では、分野の一覧にシチュエーションが出ない
    // （osmWashabeと同じく「15+60秒」モード専用のため）。PREPガイドが常時
    // 点滅しているため、ここでもpumpAndSettle()ではなく明示的なpump()を使う。
    await tester.tap(find.text(_t('日常の身近な話題')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_t('シチュエーション')), findsNothing);
    await tester.tap(find.text(_t('ビジネスシーン')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 「15+60」に切り替えると、分野の一覧にシチュエーションが出るようになる。
    await tester.tap(find.text('15+60'));
    await tester.pump();
    await tester.tap(find.text(_t('ビジネスシーン')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(_t('シチュエーション')), findsOneWidget);
    await tester.tap(find.text(_t('シチュエーション')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 45/60秒モードへ戻すと、シチュエーション選択中だった分野が
    // 日常の身近な話題にリセットされる（osmWashabeと同じ挙動）。
    await tester.tap(find.text('45'));
    await tester.pump();
    expect(find.text(_t('日常の身近な話題')), findsOneWidget);
    expect(find.text(_t('シチュエーション')), findsNothing);

    // サイコロボタンをタップするとお題が引かれ、スピーカーアイコンに変わる
    // （実機のネイティブTTSチャンネルがないウィジェットテスト環境では、
    // 読み上げ自体は即座に失敗して停止するが、状態遷移とお題描画は検証できる）。
    expect(find.byIcon(Icons.casino), findsOneWidget);
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    // リセットをタップすると例外なく初期状態（サイコロアイコン）に戻る。
    // _resetAttempt()内で呼ぶRecordingSttService.cancel()は、未登録の
    // プラットフォームチャンネルからの応答がない場合に備えて3秒のタイムアウトを
    // 持つ。pumpAndSettle()はPREPガイドの無限アニメーションで使えないため、
    // フェイククロックをタイムアウト分だけ一度に進めて解決させる。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.casino), findsOneWidget);
  });

  testWidgets('レイヤーⅢ画面の「＋」をタップ／長押しすると使い方シートが開く', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅲ'));
    await tester.pumpAndSettle();
    // Step 4: レイヤーⅢ入口の2択から「ランダム」を選ぶと、既存の
    // サイコロ画面（Layer3Screen）が開く。
    await tester.tap(find.text(_t('ランダム')));
    // レイヤーⅢのPREPガイドは常時点滅する（無限に繰り返す）AnimationControllerを
    // 持つため、pumpAndSettle()は使わない。
    await tester.pump();

    // タップは「AIで追加」「自分で追加」の選択シートを開く（お題の取り込み導線）。
    // 「＋」にはダブルタップの機能ヒント（Step 7）が付いており、単タップ判定を
    // 約300ms（kDoubleTapTimeout）保留するため、確定するまで余分にpumpする。
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('AIで追加')), findsOneWidget);
    expect(find.text(_t('自分で追加')), findsOneWidget);
    expect(find.text(_t('操作方法')), findsNothing);

    // シートを閉じて長押しでは使い方シートが開く。
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅢ_使い方_タイマー'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅢ_使い方_サイコロ'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅢ_使い方_ノート'), findRichText: true),
      findsOneWidget,
    );
    expect(find.text(_t('お題の取り込み')), findsNothing);
  });

  testWidgets('レイヤーⅣ画面はレイヤーⅢと同じ構成をベースに、評価系ボタンが可視化されている', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    // レイヤーⅢと同じく（PrepStageRowの点滅アニメーション自体は常駐するため）
    // pumpAndSettle()は使わない。
    await tester.pump();

    // 45/60/15+60はレイヤーⅢと同じく実際に選択できる。
    for (final label in ['45', '60', '15+60']) {
      final finder = find.text(label);
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isFalse);
    }

    // 「＋」は操作方法シートの導線として実際に使える（お題取り込みはⅡ側）。
    final addIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(addIgnorePointer.ignoring, isFalse);

    // 結論/理由はレイヤーⅢと違い非表示（IgnorePointerでゴースト化）のまま、
    // 例示の枠は保存済み採点結果があるときだけ一覧導線として表示する。
    // 0件のうちは背景色に同化して非表示。
    for (final label in ['結論', '理由']) {
      final finder = find.text(_t(label));
      expect(finder, findsOneWidget);
      final ignorePointer = tester.widget<IgnorePointer>(
        find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }
    final historyIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.list_alt_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(historyIgnorePointer.ignoring, isTrue);

    // 「リセット」は実際に表示・操作できる。「診断」は非表示のまま。
    final resetIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.refresh_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(resetIgnorePointer.ignoring, isFalse);
    // 「再生」は表示はされているが、録音がまだ無いためグレーアウトして
    // 操作できない。
    final playIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.play_arrow_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(playIgnorePointer.ignoring, isTrue);
    final diagnoseIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(diagnoseIgnorePointer.ignoring, isTrue);

    // お題欄の直下の注記はレイヤーⅢと異なる文言。
    expect(find.text(_t('日本語で回答しよう')), findsOneWidget);
    expect(find.text(_t('母語で回答してOK')), findsNothing);

    // リセットボタンをタップしても例外なく完了する
    // （プラットフォームチャンネル未実装のウィジェットテスト環境でも安全に失敗する）。
    // RecordingSttService.cancel()の3秒タイムアウトを、フェイククロックで
    // 一度に進めて解決させる（残存タイマーがあると後続テストの
    // 「pending timer」検証に失敗するため）。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('レイヤーⅣ画面の「＋」を長押しすると使い方シートが開く', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pump();

    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('操作方法')), findsOneWidget);
    expect(
      find.text(_withoutBadge('レイヤーⅣ_使い方_タイマー'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_afterIcon('レイヤーⅣ_使い方_サイコロ'), findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text(_withoutBadge('レイヤーⅣ_使い方_採点結果'), findRichText: true),
      findsOneWidget,
    );
    // 「＋」の長押しは取り込み画面を開かない。
    expect(find.text(_t('お題の取り込み')), findsNothing);
  });

  testWidgets('レイヤーⅤ画面はレイヤーⅡ〜Ⅳと同じ部品で構成される。初期状態はサイコロ表示で'
      '問題文なし、タップすると問題が表示されてマイクに変わる。未回答のうちは送信ボタンが非表示', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer5Standalone(tester);

    // 初期状態：サイコロのみ表示、問題文はまだ表示されない
    // （レイヤーⅡ〜Ⅳのサイコロ→スピーカーと同じ2アイコン制）。
    expect(find.byIcon(Icons.casino), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.text('1 / 10'), findsNothing);
    expect(find.text(_t('サイコロをタップして問題を表示')), findsOneWidget);
    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    expect(state.debugArmed, isFalse);

    // サイコロをタップすると、問題が表示されてマイクのアイコンに変わる。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();

    expect(state.debugArmed, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsNothing);
    expect(find.text('1 / 10'), findsOneWidget);

    final card = tester.widget<PronunciationExerciseCard>(
      find.byType(PronunciationExerciseCard),
    );
    expect(card.questionNumber, 1);
    expect(card.totalQuestions, 10);
    // 課題によっては短文とかな読みが同じ表記になる（例: 「おじいさん」に漢字表記が
    // ないなど）ため、重複表示があっても許容できるfindsAtLeastNWidgetsで検証する。
    expect(find.text(card.exercise.category.label), findsAtLeastNWidgets(1));
    expect(find.text(card.exercise.sentence), findsAtLeastNWidgets(1));
    expect(find.text(card.exercise.reading), findsAtLeastNWidgets(1));
    expect(find.text(card.exercise.vietnameseHint), findsAtLeastNWidgets(1));

    // 60・15+60はレイヤーⅤでは使わないため非表示（枠だけ確保）。
    for (final label in ['60', '15+60']) {
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text(label),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue, reason: '$labelは非表示のはず');
    }
    // 「45」の位置は断続/連続モードの切り替えボタンとして実際に表示・操作できる
    // （既定は断続モードなので、断続を示すアイコンで表示される）。
    final modeToggleIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.more_horiz_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(modeToggleIgnorePointer.ignoring, isFalse);
    // 「＋」の位置は発音課題の取り込み導線として実際に表示・操作できる。
    final importIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.add_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(importIgnorePointer.ignoring, isFalse);

    // 分野セレクタはレイヤーⅤでは使わないため、レイアウトの高さだけ
    // 他レイヤーと揃えつつVisibility(visible: false, maintainState: true)で
    // 非表示にしている（内部的にIgnorePointerでヒットテストを除外する）。
    final categoryIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byType(CategorySelectField),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(categoryIgnorePointer.ignoring, isTrue);

    // 結論/理由（PREPガイド）は非表示のまま、例示の枠は保存済み結果がある
    // ときだけ発音チェック結果一覧への導線として表示する。
    for (final label in ['結論', '理由']) {
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text(_t(label)),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);
    }
    final historyIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.list_alt_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(historyIgnorePointer.ignoring, isTrue);

    // リセットは常に表示・操作できる。送信は全問回答するまで非表示。
    final resetIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.refresh_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(resetIgnorePointer.ignoring, isFalse);
    // ▶︎（再生）は表示されているが、録音がまだ無いためグレーアウトして
    // 操作できない。
    final playIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.play_arrow_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(playIgnorePointer.ignoring, isTrue);
    final sendIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(sendIgnorePointer.ignoring, isTrue);
  });

  testWidgets(
    'サイコロをタップしてマイクに変えてからタップしても、権限取得・開始に失敗する環境では例外を出さず録音状態には進まない（安全な失敗処理）',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      await PrivacyConsentService.grantSpeechProcessingConsent();
      await _pumpLayer5Standalone(tester);

      // サイコロをタップして問題を表示し、マイクに切り替える。
      await tester.tap(find.byIcon(Icons.casino));
      await tester.pump();
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

      // プラットフォームチャンネル未実装のウィジェットテスト環境では、
      // 録音開始（マイク権限確認を含む）は必ず失敗する。それでも例外を出さず、
      // 「マイク権限なし」の案内を出したうえで待機状態のままであること。
      // startRecording()はpath_provider経由の実プラットフォームチャンネル呼び出しを
      // 含むため、FakeAsyncのpump()だけでは解決しない。runAsync()で実イベント
      // ループ上で完了させる。
      await tester.runAsync(() async {
        await tester.tap(find.byIcon(Icons.mic_rounded));
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(_t('マイク権限なし')), findsOneWidget);
      // 開始に失敗しても、もう一度タップし直せるようマイク表示のままになる
      // （サイコロには戻らない）。
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
      expect(
        state.debugSession.current.status,
        PronunciationQuestionStatus.waiting,
      );
    },
  );

  testWidgets('マイクボタンを連続でタップしても二重処理にならず例外も出ない', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PrivacyConsentService.grantSpeechProcessingConsent();
    await _pumpLayer5Standalone(tester);

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('現在の問題に回答すると、サイコロをタップして次の問題（進捗2/10）に進める', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    expect(state.debugSession.currentIndex, 0);

    // サイコロをタップすると問題が表示されてマイクに変わるが、まだ回答して
    // いないので次の問題には進まない。
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    expect(state.debugSession.currentIndex, 0);
    expect(state.debugArmed, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // 実機のネイティブ録音・STTはウィジェットテストで再現できないため、
    // セッション進行を検証するテスト専用フック（[Layer5ScreenState.debugCompleteCurrentQuestion]）
    // で「録音→STT完了」の結果だけを模擬する（このフックは実際の録音停止と
    // 同じく、armedをfalseに戻す＝サイコロ表示に戻す）。
    state.debugCompleteCurrentQuestion('テスト認識結果');
    await tester.pump();

    expect(find.text('テスト認識結果'), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();

    expect(state.debugSession.currentIndex, 1);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('マイクをタップして録音を終了すると、サイコロを経由せず自動的に次の問題へ進み、'
      'マイクは背景透明のまま次の録音に備える（連続モード）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // この自動進行は連続モードのときだけの挙動（既定の断続モードでは
    // マイク停止後にサイコロへ戻る）。連続モードは次の問題の録音も自動で
    // 始めるため、同意ダイアログが割り込んでタップを奪わないよう、
    // あらかじめ同意済みにしておく。
    appSettings.layer5RecordingMode = RecordingMode.continuous;
    addTearDown(
      () => appSettings.layer5RecordingMode = RecordingMode.intermittent,
    );
    await PrivacyConsentService.grantSpeechProcessingConsent();
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    expect(state.debugSession.currentIndex, 0);

    // ネイティブ録音を経由せず「録音中」を模擬したうえで、実際にマイク
    // アイコンをタップして止める（[Layer5ScreenState._onMicTapToStop]の
    // 本物の遷移ロジックを検証する）。stopAndTranscribe()自体は
    // （実際には録音していないため）プラットフォームチャンネルを呼ばず
    // 即座に空リストを返すが、_onMicTapToStop内のjust_audio（再生停止）
    // 呼び出しは、ネイティブ実装の存在しないウィジェットテスト環境では
    // 1回のrunAsync()内で解決しないことがある（1回のrunAsync()の終了
    // 自体が保留中のプラットフォームチャンネル呼び出しを解決させる一因に
    // なるため）。そのため、短いrunAsync()呼び出しを繰り返して完了を待つ。
    state.debugForceRecordingStatus();
    await tester.pump();
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.mic_rounded));
    });
    for (var i = 0; i < 40 && state.debugSession.currentIndex == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
    // プラットフォームチャンネル未実装のため空のSTT結果＝失敗扱いになるが、
    // それでもサイコロには戻らず、自動的に次の問題（進捗2/10）へ進み、
    // マイクの構えのまま（背景透明）になっていること。
    expect(
      state.debugSession.questions[0].status,
      PronunciationQuestionStatus.failed,
    );
    expect(state.debugSession.currentIndex, 1);
    expect(state.debugArmed, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsNothing);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('STT結果が空（失敗）でも安全に扱われ、サイコロのタップで次へ進むことができる', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    state.debugMarkCurrentFailed();
    await tester.pump();

    expect(find.text(_t('うまく聞き取れませんでした。もう一度録音してみましょう。')), findsOneWidget);
    expect(find.byIcon(Icons.casino), findsOneWidget);

    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();

    expect(state.debugSession.currentIndex, 1);
    expect(find.text('2 / 10'), findsOneWidget);
  });

  testWidgets('全10問に回答すると送信ボタンが表示される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await _completeAllQuestions(tester, state);

    expect(state.debugSession.currentIndex, 9);
    final sendIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(sendIgnorePointer.ignoring, isFalse);
  });

  testWidgets('Chrome AIの起動に失敗しても例外を出さず、貼り付け待ちにはならない', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform(succeeds: false);
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await _completeAllQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    expect(find.text(_t('Chrome AIを開けませんでした')), findsOneWidget);
    // 起動に失敗しているので、貼り付け待ち（貼り付けアイコン）にはならず
    // 送信アイコンのままである。
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
  });

  testWidgets('貼り付けボタンを連続でタップしても保存は1件だけになる（二重保存防止）', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await _pumpLayer5Standalone(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    await _completeAllQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(const ClipboardData(text: _validAiEvaluationJson));

    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

    // 「貼り付け」の連続タップ二重保存防止（Step 7以前）：素早い連続タップは
    // 今はダブルタップの機能ヒント（Step 7）として扱われ、本来の貼り付け動作は
    // 一度も呼ばれない（GhostPill等と同じ、ダブルタップ確定では単タップの
    // 動作を実行しない方式）。そのため二重保存はUIタップ経由では構造的に
    // 起こり得ず、単タップ（確定待ち後）で1件だけ保存されることを確認する。
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // 貼り付けで即保存され、結果概要ダイアログが表示される。
    expect(find.text(_t('評価結果プレビュー')), findsOneWidget);
    final saved = await PronunciationCheckStorage().loadAll();
    expect(saved, hasLength(1));
  });

  testWidgets('保存前の「発音チェック結果」アイコンは非表示', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer5Standalone(tester);

    final historyIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.list_alt_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(historyIgnorePointer.ignoring, isTrue);
  });

  testWidgets('レイヤーⅤから他のレイヤーへ切り替えるとresetAttemptが例外なく実行され、戻ると新しいセッションになっている', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _openLayer5(tester);

    final state = tester.state<Layer5ScreenState>(find.byType(Layer5Screen));
    state.debugCompleteCurrentQuestion('回答');
    await tester.pump();
    expect(
      state.debugSession.current.status,
      PronunciationQuestionStatus.completed,
    );

    // レイヤーⅢ・Ⅳと同じく、離れる瞬間に「リセット」相当の処理が安全に走ることを確認する
    // （RecordingSttService.cancel()の3秒タイムアウトをフェイククロックで進めて解決させる）。
    await tester.tap(find.text('Ⅰ'));
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Ⅴ'));
    await tester.pump();

    expect(state.debugSession.currentIndex, 0);
    expect(
      state.debugSession.questions.every(
        (q) => q.status == PronunciationQuestionStatus.waiting,
      ),
      isTrue,
    );
  });

  testWidgets('スタート画面へ戻ってから同じレイヤーに戻ると、MainShellが再生成されず'
      '進行中の状態が保持される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _openLayer5(tester);

    final layer5State = tester.state<Layer5ScreenState>(
      find.byType(Layer5Screen),
    );
    layer5State.debugCompleteCurrentQuestion('回答');
    await tester.pump();
    expect(
      layer5State.debugSession.current.status,
      PronunciationQuestionStatus.completed,
    );

    // 下スワイプでスタート画面へ戻る（SwipeToCloseWrapper→MainShell.onClose）。
    // MainShellの中心（既定のfling開始位置）は本文のSingleChildScrollView上に
    // 乗ってしまい、スクロール操作と誤認識されて閉じないことがあるため、
    // Layer5Screen自身の上端付近（DiceActionRow行、スクロール領域の外）から
    // 始める。
    final layer5TopLeft = tester.getTopLeft(find.byType(Layer5Screen));
    await tester.flingFrom(
      layer5TopLeft + const Offset(50, 20),
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // スタート画面（LaunchScreen）に戻っていること。MainShell自体は
    // 破棄されず裏で保持されているだけなので、AppHeaderの同名タブ文言
    // （例: 「Ⅴ」）と衝突しないよう、LaunchScreenの子孫に絞って探す。
    expect(find.byType(LaunchScreen), findsOneWidget);
    final launchTileFinder = find.descendant(
      of: find.byType(LaunchScreen),
      matching: find.text('Ⅴ'),
    );
    expect(launchTileFinder, findsOneWidget);

    // 同じレイヤーⅤを再度開く。
    await tester.tap(launchTileFinder);
    await tester.pump();

    // MainShellのインスタンスが再生成されていない
    // （＝Layer5ScreenStateも同一インスタンスのまま）ため、直前の回答が
    // そのまま残っていること。
    final layer5StateAfter = tester.state<Layer5ScreenState>(
      find.byType(Layer5Screen),
    );
    expect(identical(layer5StateAfter, layer5State), isTrue);
    expect(
      layer5StateAfter.debugSession.current.status,
      PronunciationQuestionStatus.completed,
    );
    expect(find.text('回答'), findsOneWidget);
  });

  testWidgets('AppHeaderのⅠ〜Ⅴタブ帯から右スワイプしても、bodyからと同じくスタート画面へ戻る'
      '（ヘッダーだけSwipeToCloseWrapperの対象外になっていた回帰テスト）', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _openLayer5(tester);

    // AppHeader（「Ⅰ」〜「Ⅴ」タブ帯）の内側、左端から右スワイプする。
    final headerTopLeft = tester.getTopLeft(find.byType(AppHeader));
    final gesture = await tester.startGesture(
      headerTopLeft + const Offset(4, 20),
    );
    await gesture.moveBy(
      const Offset(40, 0),
      timeStamp: const Duration(milliseconds: 10),
    );
    await gesture.moveBy(
      const Offset(80, 0),
      timeStamp: const Duration(milliseconds: 20),
    );
    await gesture.moveBy(
      const Offset(120, 0),
      timeStamp: const Duration(milliseconds: 30),
    );
    await gesture.moveBy(
      const Offset(60, 0),
      timeStamp: const Duration(milliseconds: 40),
    );
    await gesture.up(timeStamp: const Duration(milliseconds: 40));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(LaunchScreen), findsOneWidget);
  });

  testWidgets('AppHeaderのⅠ〜Ⅴいずれかのボタンを長押しすると、スタート画面へジャンプする', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _openLayer5(tester);

    // 現在Ⅴを表示中でも、長押しはどのボタンでも同じくスタート画面へ戻る
    // ことを確認するため、あえて別のⅢを長押しする。
    final longPressTarget = find.descendant(
      of: find.byType(AppHeader),
      matching: find.text('Ⅲ'),
    );
    await tester.longPress(longPressTarget);
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    expect(find.byType(LaunchScreen), findsOneWidget);
  });

  testWidgets('レイヤーⅠでモードを選んだあとに右スワイプすると、3択画面を経由せず'
      '直接スタート画面へ戻り、タイルのタップで選んでいたモードに再開する', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();

    // ポッドキャスト画面（Layer1Screen）が開いていること。
    expect(find.text(_t('番組を登録してください')), findsOneWidget);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));

    // 3択画面を経由せず、1回のスワイプでスタート画面へ戻る。
    expect(find.byType(LaunchScreen), findsOneWidget);

    // レイヤーⅠへ再訪すると、選んでいたポッドキャストモードのまま続きから
    // 再開する（3択画面には戻らない。長押しした場合のみ最初からになる）。
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    expect(find.text(_t('番組を登録してください')), findsOneWidget);
    expect(find.text('Làm quen với tiếng Nhật'), findsNothing);
  });

  testWidgets('レイヤーⅠでヘッダーⅠ再タップで3択に戻る', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    expect(find.byType(DiceActionRow), findsOneWidget);

    // ヘッダー「Ⅰ」タップで3択へ。
    await tester.tap(find.text('Ⅰ'));
    await tester.pumpAndSettle();
    expect(find.text('Làm quen với tiếng Nhật'), findsOneWidget);
    expect(find.text(_t('語彙を増やす')), findsOneWidget);

    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    expect(find.text(_t('番組を登録してください')), findsOneWidget);

    // ヘッダー「Ⅰ」再タップで3択へ。
    await tester.tap(find.text('Ⅰ'));
    await tester.pumpAndSettle();
    expect(find.text('Làm quen với tiếng Nhật'), findsOneWidget);
    expect(find.text(_t('語彙を増やす')), findsOneWidget);
  });

  testWidgets('レイヤーⅠで語彙テストを選んだあとにスタート画面へ戻っても、'
      'タイルのタップで3択を経由せず語彙テストへ再開する', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();
    expect(find.byType(DiceActionRow), findsOneWidget);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // タイルのタップは3択を経由せず、選んでいた語彙テストへ直接戻る。
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    expect(find.byType(DiceActionRow), findsOneWidget);
    expect(find.text('Làm quen với tiếng Nhật'), findsNothing);
  });

  testWidgets('MiniPlayerは耳慣れモードのときだけ表示される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();

    // 3択画面では MiniPlayer なし。
    expect(find.byType(MiniPlayerBar), findsNothing);

    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayerBar), findsNothing);

    await tester.tap(find.text('Ⅰ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Podcast'));
    await tester.pumpAndSettle();
    expect(find.byType(MiniPlayerBar), findsOneWidget);
  });

  testWidgets('レイヤーⅠで「長文読解」を選ぶとキーワード画面が開く', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();

    // 3択画面：見出し「語彙を増やす」の下に「長文読解」「語彙テスト」の
    // 子が並び、下段に従来どおり「日本語に耳を慣らす」がある。
    expect(find.text(_t('語彙を増やす')), findsOneWidget);
    expect(find.text(_t('長文読解')), findsOneWidget);
    expect(find.text(_t('語彙テスト')), findsOneWidget);
    expect(find.text('Làm quen với tiếng Nhật'), findsOneWidget);

    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();

    // キーワード画面（生成条件の設定）が開く。語彙テスト・Podcastの
    // シェルには遷移していない。
    expect(find.text(_t('キーワード')), findsOneWidget);
    expect(find.text(_t('おまかせ')), findsOneWidget);
    expect(find.text(_t('長文読解_JLPTレベル')), findsOneWidget);
    expect(find.byType(DiceActionRow), findsNothing);
    expect(find.text(_t('番組を登録してください')), findsNothing);

    // キーワード未入力では「開始する」を押せない。
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _t('開始する')),
    );
    expect(startButton.onPressed, isNull);

    await tester.tap(find.text('Ⅰ'));
    await tester.pumpAndSettle();
    expect(find.text(_t('長文読解')), findsOneWidget);
  });

  testWidgets('レイヤーⅠ長文読解：保存済みの長文があるときは選択シートが出て、'
      '「一覧から選ぶ」で一覧画面を開ける', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();

    // キーワード画面へ直行せず、まず選択シートが出る。
    expect(find.text(_t('長文読解_開始選択_タイトル')), findsOneWidget);
    expect(find.text(_t('長文読解_JLPTレベル')), findsNothing);

    await tester.tap(find.text(_t('長文読解_開始選択_一覧から選ぶ')));
    await tester.pumpAndSettle();

    expect(find.byType(LongArticleListScreen), findsOneWidget);
    expect(find.text('旅行'), findsOneWidget);
  });

  testWidgets('レイヤーⅠ長文読解：一覧から選ぶと、その長文でいきなり読解画面が開き、'
      '「次へ」で複製せず3択へ戻る', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解_開始選択_一覧から選ぶ')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('旅行'));
    await tester.pumpAndSettle();

    // キーワード・生成画面を経由せず、いきなり読解画面が開く。
    expect(find.byType(TappableJapaneseText), findsOneWidget);
    expect(find.textContaining('友達と公園へ行きました'), findsWidgets);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 3択画面へ戻り、長文は複製されず1件のまま。
    expect(find.text(_t('語彙を増やす')), findsOneWidget);
    expect(await LongArticleService().loadArticles(), hasLength(1));
  });

  testWidgets('レイヤーⅠ長文読解：保存済みの長文があっても「新規作成」を選べば'
      'キーワード画面から始まる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await LongArticleService().addArticle(body: '友達と公園へ行きました。', title: '旅行');

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解_開始選択_新規作成')));
    await tester.pumpAndSettle();

    expect(find.text(_t('キーワード')), findsOneWidget);
    expect(find.text(_t('長文読解_JLPTレベル')), findsOneWidget);
  });

  testWidgets('レイヤーⅠ長文読解：おまかせで候補が入力され、'
      '入力欄は編集不可になる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();

    var textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(textField.enabled, isTrue);

    await tester.tap(find.text(_t('おまかせ')));
    await tester.pump();

    textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isNotEmpty);
    expect(longArticleOmakaseTopics, contains(textField.controller!.text));
    expect(textField.enabled, isFalse);

    // おまかせ中も「開始する」は押せる。
    final startButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, _t('開始する')),
    );
    expect(startButton.onPressed, isNotNull);

    // チェックを外すと入力欄が再び編集できる（空に戻る）。
    await tester.tap(find.text(_t('おまかせ')));
    await tester.pump();
    textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.controller!.text, isEmpty);
    expect(textField.enabled, isTrue);
  });

  testWidgets('レイヤーⅠ長文読解：キーワード→同意→Chrome起動→貼付で自動的に読解画面へ進み、'
      'タップで単語登録→保存まで完走する', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, _t('開始する')));
    await tester.pumpAndSettle();

    // 生成画面表示と同時に同意ダイアログが自動で出る（手動タップ不要）。
    expect(
      find.widgetWithText(TextButton, _t('同意してGoogleへ送信')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Chromeが起動し（プロンプトにキーワードを含む）、貼り付け待ちになる。
    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    expect(
      find.widgetWithText(FilledButton, _t('長文読解_文章生成ボタン_貼付')),
      findsOneWidget,
    );

    await Clipboard.setData(
      const ClipboardData(text: '{"body": "友達と一緒に旅行に行きました。とても楽しかったです。"}'),
    );
    await tester.tap(find.widgetWithText(FilledButton, _t('長文読解_文章生成ボタン_貼付')));
    await tester.pumpAndSettle();

    // 手動の「使う」確認は無く、パース成功でそのまま読解画面へ進む。
    // 操作バーはGenkiTransportRowと同じ枠（アイコンのみ・余白ゼロ）。
    // 登録単語が無い間は「訳を付ける」は非表示（枠だけ確保）。
    expect(find.byType(TappableJapaneseText), findsOneWidget);
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
    expect(_enrichButton(tester).visible, isFalse);
    expect(_vocabularyButton(tester).visible, isTrue);
    expect(_nextButton(tester).visible, isTrue);

    // 本文の先頭付近（「友達」を含むチャンク）をタップして単語帳登録する。
    final textTopLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    final firstWordOffset = textTopLeft + const Offset(6, 10);
    await tester.tapAt(firstWordOffset);
    await tester.pump();

    final vocab = await VocabularyService().loadEntries();
    expect(vocab, isNotEmpty);
    expect(vocab.single.word, isNotEmpty);
    // タップ登録後は「訳を付ける」がタップできるようになる。
    expect(find.byIcon(Icons.translate_rounded), findsOneWidget);
    expect(_enrichButton(tester).visible, isTrue);

    // 登録した語を同じ位置で長押しすると、登録を取り消せる。
    await tester.longPressAt(firstWordOffset);
    await tester.pump();
    expect(await VocabularyService().loadEntries(), isEmpty);
    expect(_enrichButton(tester).visible, isFalse);

    // もう一度タップして登録し直す。
    await tester.tapAt(firstWordOffset);
    await tester.pump();
    expect(await VocabularyService().loadEntries(), hasLength(1));
    expect(_enrichButton(tester).visible, isTrue);

    // 直前の登録操作で連続表示されたSnackBar（登録→取消→再登録）が
    // キューに残ったまま操作バーに重なるとタップが通らないため、
    // まとめて消す。
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // 「訳を付ける」を長押しすると、選び直し画面を経由せず直接Chrome AIの
    // 同意ダイアログまで進む（近道）。
    final launchedUrlsBeforeLongPress = fakeUrlLauncher.launchedUrls.length;
    await tester.longPress(find.byIcon(Icons.translate_rounded));
    await tester.pump();
    expect(
      find.widgetWithText(TextButton, _t('同意してGoogleへ送信')),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(TextButton, _t('キャンセル')));
    await tester.pumpAndSettle();
    // 同意しなければChromeは起動しない。訳付け画面自体は開いたままなので、
    // 「戻る」で読解画面に戻る。
    expect(
      fakeUrlLauncher.launchedUrls,
      hasLength(launchedUrlsBeforeLongPress),
    );
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(TappableJapaneseText), findsOneWidget);

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pumpAndSettle();

    // 「単語帳」ボタンでVocabularySheetが開く（既存の単語帳導線）。
    // Tooltipのレイアウトサロゲート越しだと座標がずれるため、アイコン自体を
    // タップする。
    await tester.tap(find.byIcon(Icons.style_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();
    expect(find.byType(VocabularySheet), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pumpAndSettle();

    // 長文が永続化され、3択画面へ戻る。
    final articles = await LongArticleService().loadArticles();
    expect(articles, hasLength(1));
    expect(articles.single.title, '旅行');
    expect(articles.single.body, '友達と一緒に旅行に行きました。とても楽しかったです。');
    expect(articles.single.generationKeyword, '旅行');
    expect(find.text(_t('語彙を増やす')), findsOneWidget);
  });

  testWidgets('レイヤーⅠ長文読解：誤ってスワイプでスタート画面に戻っても、'
      '起動画面の「戻る」で読解中の長文に戻れる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await tester.pumpWidget(const OsmGradusApp());

    // 起動直後は、戻り先が無いので「戻る」ボタンは出ない。
    expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);

    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, _t('開始する')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await Clipboard.setData(
      const ClipboardData(text: '{"body": "友達と一緒に旅行に行きました。"}'),
    );
    await tester.tap(find.widgetWithText(FilledButton, _t('長文読解_文章生成ボタン_貼付')));
    await tester.pumpAndSettle();

    // 読解画面で単語を登録しておく（キーワード入力からは復元できない、
    // やり直しのきかない進行状況）。
    expect(find.byType(TappableJapaneseText), findsOneWidget);
    final textTopLeft = tester.getTopLeft(find.byType(TappableJapaneseText));
    await tester.tapAt(textTopLeft + const Offset(6, 10));
    await tester.pump();
    expect(await VocabularyService().loadEntries(), hasLength(1));

    // 単語登録のSnackBarが残ったまま（MainShellはVisibilityで裏に
    // 残り続ける）だと後続のタップを妨げるため消しておく。
    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .clearSnackBars();
    await tester.pump();

    // 誤って右スワイプしてスタート画面に戻ってしまう。
    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // レイヤーⅠのタイルを踏むと3択に戻ってしまうが、
    // 起動画面下部の「戻る」（単語帳の左）なら読解中の長文に戻れる。
    final backButton = find.byIcon(Icons.arrow_back_rounded);
    expect(backButton, findsOneWidget);
    // MainShellはVisibility(maintainState:true)で裏に残っているため、
    // 単語帳アイコンはそちら側にも存在する。起動画面のものだけに絞る。
    final vocabIcon = find.descendant(
      of: find.byType(LaunchScreen),
      matching: find.byIcon(Icons.style_rounded),
    );
    expect(
      tester.getCenter(backButton).dx < tester.getCenter(vocabIcon).dx,
      isTrue,
    );

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // 3択にもキーワード画面にも戻らず、読んでいた長文の続きに戻る。
    expect(find.byType(TappableJapaneseText), findsOneWidget);
    expect(find.textContaining('友達と一緒に旅行'), findsWidgets);
    expect(await VocabularyService().loadEntries(), hasLength(1));
  });

  testWidgets('レイヤーⅠ長文読解：スワイプでスタート画面に戻ってから同じレイヤータイルを'
      '踏んでも、読解中の長文に戻れる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, _t('開始する')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await Clipboard.setData(
      const ClipboardData(text: '{"body": "友達と一緒に旅行に行きました。"}'),
    );
    await tester.tap(find.widgetWithText(FilledButton, _t('長文読解_文章生成ボタン_貼付')));
    await tester.pumpAndSettle();
    expect(find.byType(TappableJapaneseText), findsOneWidget);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // 専用の「戻る」ボタンではなく、レイヤーⅠのタイル自体を踏んでも
    // 3択へリセットされず、読解中の長文へ戻れる。
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();

    expect(find.byType(TappableJapaneseText), findsOneWidget);
    expect(find.textContaining('友達と一緒に旅行'), findsWidgets);
  });

  testWidgets('レイヤーⅠ長文読解：スタート画面のタイルはタップで続きから再開し、'
      '長押しすると読解中でも3択の最初からになる', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('長文読解')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '旅行');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, _t('開始する')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await Clipboard.setData(
      const ClipboardData(text: '{"body": "友達と一緒に旅行に行きました。"}'),
    );
    await tester.tap(find.widgetWithText(FilledButton, _t('長文読解_文章生成ボタン_貼付')));
    await tester.pumpAndSettle();
    expect(find.byType(TappableJapaneseText), findsOneWidget);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // タップ（既存の挙動）は続きから再開する。
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    expect(find.byType(TappableJapaneseText), findsOneWidget);

    // 読解中のまま再度スタート画面へ戻り、今度は長押しする。
    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    await tester.longPress(find.text('Tầng I'));
    await tester.pumpAndSettle();

    // 読解中でも問答無用でリセットされ、3択の選択画面から始まる
    // （読み込み中だった長文は復元されない）。
    expect(find.byType(TappableJapaneseText), findsNothing);
    expect(find.text(_t('長文読解')), findsOneWidget);
  });

  testWidgets('レイヤーⅡ：スタート画面のタイルはタップで「話題を増やす」の状態を保持し、長押しすると3択に戻る', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng II'));
    await tester.pumpAndSettle();

    // Step 3: レイヤーⅡ入口の3択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.casino));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // タップは「話題を増やす」・引いたお題を保持したまま再開する。
    await tester.tap(find.text('Tầng II'));
    await tester.pumpAndSettle();
    expect(find.text(_t('ボタンを押してお題を引いてください')), findsNothing);

    await _rightSwipeFrom(tester, const Offset(4, 300));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(LaunchScreen), findsOneWidget);

    // 長押しは選択済みモード・引いたお題をクリアし、3択画面に戻す。
    await tester.longPress(find.text('Tầng II'));
    await tester.pumpAndSettle();
    expect(find.text(_t('話題を増やす')), findsOneWidget);
    expect(find.text(_t('問題文一覧から選ぶ')), findsOneWidget);
    expect(find.text(_t('ランダム')), findsOneWidget);
  });

  testWidgets('レイヤーⅠで「語彙テスト」を選ぶと、II〜Vと同型の単語テスト画面シェルが開く', (
    WidgetTester tester,
  ) async {
    // レベル選択シートのチェックボックス全件（N1/N2/N3/その他+ランダム）が
    // 一度にヒットテストできるよう、縦長のビューポートにする。
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    // II〜Vと同じ部品（トップ行・PREP転用行・下段トランスポート行）が
    // すべて揃っている。
    expect(find.byType(DiceActionRow), findsOneWidget);
    expect(find.byType(PrepLabelRow), findsOneWidget);
    expect(find.byType(GenkiTransportRow), findsOneWidget);
    expect(_vocabDiceButton, findsOneWidget);
    expect(find.text(_t('レベル')), findsOneWidget);
    expect(find.text(_t('N1レベル')), findsOneWidget);
    expect(
      find.textContaining(_layer1EmptyLead, findRichText: true),
      findsOneWidget,
    );
    // 単語帳（3択画面と同じ単語カードアイコン）。
    expect(
      find.descendant(
        of: find.byType(PrepLabelRow),
        matching: find.byIcon(Icons.style_rounded),
      ),
      findsOneWidget,
    );

    // 単語表示on/offトグル：既定はon（目のアイコン）で、タップで切り替わる。
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_off_rounded), findsOneWidget);

    // 標準語彙がON（既定）なので、単語帳が空でもサイコロでN1語が出る。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text(_t('レイヤーⅠ_語彙_プール空')), findsNothing);
    expect(
      find.textContaining(_layer1EmptyLead, findRichText: true),
      findsNothing,
    );

    // マイク状態に切り替わったあと、表示を戻してから単語帳を開く。
    await tester.tap(find.byIcon(Icons.visibility_off_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.byIcon(Icons.visibility_rounded), findsOneWidget);

    // 単語帳は既存のVocabularySheetを開く（標準語彙も含む）。
    await tester.tap(
      find.descendant(
        of: find.byType(PrepLabelRow),
        matching: find.byIcon(Icons.style_rounded),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(VocabularySheet), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    // レベル選択シートを開いて、チェックボックスで複数選択できる
    // （開いたまま続けて選べる）。シートの出現アニメーションを完了させて
    // から中の要素をタップしないと、途中の座標でヒットテストに失敗する
    // ため、開いた直後は必ずpumpAndSettle()を挟む。
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('N2レベル')));
    await tester.pump();
    // シートを閉じて、フィールドが複数レベルの組み合わせ表示になることを確認。
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text('${_t('N1レベル')}・${_t('N2レベル')}'), findsOneWidget);

    // 再度開いてN1を外すと、N2だけになる（最後の1つは解除できない）。
    await tester.tap(find.text('${_t('N1レベル')}・${_t('N2レベル')}'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(_t('N2レベル')), findsOneWidget);

    // ランダムを選ぶと即座に閉じ、全レベル対象になる。
    await tester.tap(find.text(_t('N2レベル')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();
    expect(find.text(_t('ランダム')), findsOneWidget);

    // 「＋」長押しで使い方シートが開き、各ボタンの説明が実際のアプリの
    // アイコンとともに並んでいる（🇻🇳はボタン自体が絵文字ラベルのため
    // テキストのまま）。表示言語（vi）に依存せず検証できるよう、
    // `{{icon}}`より後ろの断片を翻訳文字列から動的に取り出して照合する。
    await tester.longPress(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();
    final sheet = find.byType(LayerHelpSheet);
    expect(sheet, findsOneWidget);
    expect(find.text(_t('操作方法')), findsOneWidget);

    Finder inSheet(Finder matching) =>
        find.descendant(of: sheet, matching: matching);

    expect(inSheet(find.byIcon(Icons.visibility_rounded)), findsOneWidget);
    expect(inSheet(find.text(_afterIcon('レイヤーⅠ_語彙_使い方_表示切替'))), findsOneWidget);
    expect(
      inSheet(find.text(_withoutBadge('レイヤーⅠ_語彙_使い方_回答言語'))),
      findsOneWidget,
    );
    expect(inSheet(find.byIcon(Icons.keyboard_arrow_down)), findsNothing);
    expect(
      inSheet(find.text(_withoutBadge('レイヤーⅠ_語彙_使い方_レベル'))),
      findsOneWidget,
    );
    expect(inSheet(find.byIcon(Icons.casino)), findsOneWidget);
    expect(inSheet(find.text(_afterIcon('レイヤーⅠ_語彙_使い方_サイコロ'))), findsOneWidget);
    expect(inSheet(find.byIcon(Icons.mic_rounded)), findsOneWidget);
    expect(inSheet(find.text(_afterIcon('レイヤーⅠ_語彙_使い方_マイク'))), findsOneWidget);
    expect(inSheet(find.byIcon(Icons.send_rounded)), findsOneWidget);
    expect(inSheet(find.text(_afterIcon('レイヤーⅠ_語彙_使い方_評価'))), findsOneWidget);
    expect(inSheet(find.byIcon(Icons.content_paste_go_rounded)), findsNothing);
    expect(
      inSheet(find.text(_withoutBadge('レイヤーⅠ_語彙_使い方_保存'))),
      findsOneWidget,
    );
  });

  testWidgets('単語テスト画面の「＋」をタップすると語彙の取り込み画面が開く', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    // 「＋」にはダブルタップの機能ヒント（Step 7）が付いており、単タップ判定を
    // 約300ms（kDoubleTapTimeout）保留するため、確定するまで余分にpumpする。
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text(_t('語彙の取り込み')), findsWidgets);
    expect(find.text(_t('Chrome AI で開く')), findsOneWidget);
  });

  testWidgets('サイコロをタップすると選択レベルの単語帳から1語抽選して表示し、'
      '表示offにすると文字は隠れる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
      AppPreferences.includeDefaultVocabularyKey: false,
    });
    appSettings.includeDefaultVocabulary = false;
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      reading: 'たんご',
      level: VocabularyLevel.n1,
    );

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    // 既定はN1レベル。単語帳のN1語が抽選されてカードに表示される。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text('単語'), findsOneWidget);
    expect(find.text('たんご'), findsOneWidget);
    expect(
      find.textContaining(_layer1EmptyLead, findRichText: true),
      findsNothing,
    );
    // 抽選直後はボタンがマイク（録音待機）に変わる。
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(_vocabDiceButton, findsNothing);

    // 単語表示offにすると、文字は消えて非表示プレースホルダになる
    // （カード枠自体は残る＝ヒアリングのみのモード）。
    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.text('単語'), findsNothing);
    expect(find.text('たんご'), findsNothing);
    expect(find.text(_t('レイヤーⅠ_語彙_非表示中')), findsOneWidget);
  });

  testWidgets('回答言語ボタンは既定で🇻🇳を表示し、タップするたびに🇻🇳→🇺🇸→🇯🇵→🇻🇳と巡回する', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer1VocabStandalone(tester);

    expect(find.text('🇻🇳'), findsOneWidget);
    expect(find.text('🇺🇸'), findsNothing);
    expect(find.text('🇯🇵'), findsNothing);

    await tester.tap(find.text('🇻🇳'));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.text('🇺🇸'), findsOneWidget);

    await tester.tap(find.text('🇺🇸'));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.text('🇯🇵'), findsOneWidget);

    await tester.tap(find.text('🇯🇵'));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.text('🇻🇳'), findsOneWidget);
  });

  testWidgets('レベルを切り替えると、表示中の単語がクリアされ抽選範囲も変わる', (WidgetTester tester) async {
    // レベル選択シートのチェックボックス全件が一度にヒットテストできるよう、
    // 縦長のビューポートにする。
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    // 標準語彙（各レベル20語）が混ざると抽選結果が決定論的でなくなるため、
    // このテストではオフにする。
    appSettings.includeDefaultVocabulary = false;
    await VocabularyService().addEntry(
      '単語N1',
      'n1 word',
      level: VocabularyLevel.n1,
    );
    await VocabularyService().addEntry(
      '単語N2',
      'n2 word',
      level: VocabularyLevel.n2,
    );

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text('単語N1'), findsOneWidget);

    // N2をチェックしてからN1を外し、N2だけの選択に切り替える
    // （チェックボックスは追加式のため、単純な選び直しには両方の操作が要る）。
    // シートの出現アニメーションを完了させてから中の要素をタップする。
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('N2レベル')));
    await tester.pump();
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    // レベル変更直後は表示中の単語がクリアされ、空状態に戻る。
    expect(find.text('単語N1'), findsNothing);
    expect(
      find.textContaining(_layer1EmptyLead, findRichText: true),
      findsOneWidget,
    );

    // N2だけを選んでいるので、N2の語だけが抽選される。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text('単語N2'), findsOneWidget);
  });

  testWidgets('「その他」はチェックボックスで明示的に選ばない限り出題対象にならない', (
    WidgetTester tester,
  ) async {
    // レベル選択シートのチェックボックス全件が一度にヒットテストできるよう、
    // 縦長のビューポートにする。
    tester.view.physicalSize = const Size(390, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    // 標準語彙（各レベル20語）が混ざると抽選結果が決定論的でなくなるため、
    // このテストではオフにする。
    appSettings.includeDefaultVocabulary = false;
    await VocabularyService().addEntry(
      '単語N2',
      'n2 word',
      level: VocabularyLevel.n2,
    );
    await VocabularyService().addEntry('単語その他', 'other word');

    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();

    // 既定はN1のみ選択。「その他」を明示的に選んでいないため、
    // 該当する語が無くプールが空になる。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text(_t('レイヤーⅠ_語彙_プール空')), findsOneWidget);

    // レベル選択シートでN1を外し、「その他」をチェックすると出題対象になる。
    // シートの出現アニメーションを完了させてから中の要素をタップする。
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_t('単語帳_レベルその他')));
    await tester.pump();
    await tester.tap(find.text(_t('N1レベル')));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.text('単語その他'), findsOneWidget);
    expect(find.text('単語N2'), findsNothing);
  });

  testWidgets('単語テストの青マイクをタップしても、権限取得・開始に失敗する環境では'
      '例外を出さず録音状態には進まない（安全な失敗処理）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await PrivacyConsentService.grantSpeechProcessingConsent();
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    // サイコロをタップして単語を抽選し、マイクに切り替える。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // プラットフォームチャンネル未実装のウィジェットテスト環境では、
    // 録音開始（マイク権限確認を含む）は必ず失敗する。それでも例外を出さず、
    // 「マイク権限なし」の案内を出したうえで待機状態のままであること
    // （レイヤーⅤの同種テストと同じくrunAsync()で実イベントループ上に
    // 処理を逃がす必要がある）。
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('マイク権限なし')), findsOneWidget);
    // 開始に失敗しても、もう一度タップし直せるようマイク表示のままになる
    // （サイコロには戻らない）。
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(state.debugArmed, isTrue);
    expect(state.debugRecording, isFalse);
  });

  testWidgets('赤マイク（録音中）をタップすると録音が終了しサイコロに戻る'
      '（casino→青mic→赤mic→casinoの状態遷移が安定動作する）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(state.debugArmed, isTrue);

    // ネイティブ録音を経由せず、録音中状態を再現する
    // （レイヤーⅤの[Layer5ScreenState.debugForceRecordingStatus]と同じ
    // 理由：[RecordingSttService.stopAndTranscribe]は実際に録音を
    // 開始していなければプラットフォームチャンネルを呼ばず空リストを
    // 返すため、このフックのあとに実際にタップして止めても
    // 安全に完了する）。録音中は赤マイクの代わりに10秒カウントダウン
    // （[VocabCountdownButton]）を表示する。
    state.debugForceRecording();
    await tester.pump();
    expect(state.debugRecording, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.byType(VocabCountdownButton), findsOneWidget);

    await tester.tap(find.byType(VocabCountdownButton));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(state.debugArmed, isFalse);
    expect(state.debugRecording, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
    // 実際には録音していないためSTT結果は空になり、案内が出る。
    expect(find.text(_t('うまく聞き取れませんでした。もう一度録音してみましょう。')), findsOneWidget);
  });

  testWidgets('半連続モードでは、サイコロをタップすると手動でマイクを押さなくても'
      '録音開始を試みる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // setMockInitialValuesは内部のモックストアをリセットするため、setUp()で
    // 済ませた同意も失われる。録音開始（同意ダイアログ経由）を試みさせる
    // ため、ここで改めて同意済みにしておく（他のマイク系テストと同じ理由）。
    await PrivacyConsentService.grantSpeechProcessingConsent();
    appSettings.vocabRecordingMode = RecordingMode.semiContinuous;
    addTearDown(
      () => appSettings.vocabRecordingMode = RecordingMode.intermittent,
    );
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );

    // プラットフォームチャンネル未実装の環境では録音開始は必ず失敗するが、
    // 断続モードと違いマイクを手動でタップしなくても、サイコロタップ
    // だけで自動的に開始が試みられ「マイク権限なし」の案内が出る
    // （セッション組み立て・TTS読み上げ・録音開始と非同期処理が連続する
    // ため、レイヤーⅤの連続モード回帰テストと同じくrunAsync()を
    // 繰り返して完了を待つ）。
    await tester.runAsync(() async {
      await tester.tap(_vocabDiceButton);
    });
    for (
      var i = 0;
      i < 40 && find.text(_t('マイク権限なし')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_t('マイク権限なし')), findsOneWidget);
    expect(state.debugArmed, isTrue);
    expect(state.debugRecording, isFalse);
  });

  testWidgets('連続モードでは、マイクをタップして録音を終了するとサイコロを経由せず'
      '自動的に次の問題へ進む', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // setMockInitialValuesは内部のモックストアをリセットするため、setUp()で
    // 済ませた同意も失われる。連続モードはサイコロタップ時にも自動的に
    // 録音開始（同意ダイアログ経由）を試みるため、ここで改めて同意済みに
    // しておく（他のマイク系テストと同じ理由）。
    await PrivacyConsentService.grantSpeechProcessingConsent();
    appSettings.vocabRecordingMode = RecordingMode.continuous;
    addTearDown(
      () => appSettings.vocabRecordingMode = RecordingMode.intermittent,
    );
    // 標準語彙が混ざると2問だけのセッションにならないため、このテストでは
    // オフにする（[VocabTestSession]は最大10問だが、プールが2語しかなければ
    // 2問のセッションになる＝1問目で次へ進めることを確認しやすい）。
    appSettings.includeDefaultVocabulary = false;
    await VocabularyService().addEntry(
      '単語1',
      'từ 1',
      level: VocabularyLevel.n1,
    );
    await VocabularyService().addEntry(
      '単語2',
      'từ 2',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );

    // 連続モードはサイコロタップ時にも自動的に録音開始を試みる。
    // プラットフォームチャンネル未実装のため必ず失敗するが、その解決を
    // 待たずに次へ進むと_actionInFlightが立ったままになり、後続のマイク
    // タップが無視されてしまう。「マイク権限なし」の案内が出るまでを
    // もって自動開始の試行が解決したとみなし、runAsync()を繰り返して待つ
    // （レイヤーⅤの同種テストと同じ理由）。
    await tester.runAsync(() async {
      await tester.tap(_vocabDiceButton);
    });
    for (
      var i = 0;
      i < 40 && find.text(_t('マイク権限なし')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump();
    expect(state.debugSession?.currentIndex, 0);
    expect(find.text(_t('マイク権限なし')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    // ネイティブ録音を経由せず「録音中」を模擬したうえで、赤マイクの
    // 代わりに表示される[VocabCountdownButton]をタップして止める。
    state.debugForceRecording();
    await tester.pump();
    expect(find.byIcon(Icons.mic_rounded), findsNothing);
    expect(find.byType(VocabCountdownButton), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byType(VocabCountdownButton));
    });
    for (var i = 0; i < 40 && state.debugSession?.currentIndex == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pump();

    expect(tester.takeException(), isNull);
    // プラットフォームチャンネル未実装のため空のSTT結果＝失敗扱いになるが、
    // それでもサイコロには戻らず、自動的に次の問題（2問目）へ進み、
    // マイクの構えのまま（背景透明）になっていること。
    expect(state.debugSession?.currentIndex, 1);
    expect(state.debugArmed, isTrue);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(_vocabDiceButton, findsNothing);
  });

  testWidgets('この問の期待単語とSTT回答をセッションに保存できる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    // 標準語彙（各レベル20語）が混ざると抽選結果が決定論的でなくなるため、
    // このテストではオフにする。
    appSettings.includeDefaultVocabulary = false;
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    final expectedWord = state.debugDrawnWord;
    expect(expectedWord?.word, '単語');

    // ネイティブ録音・STTを経由せず、この問を回答済みにする。
    state.debugCompleteWithSttAnswer('từ vựng');
    await tester.pump();

    expect(state.debugArmed, isFalse);
    expect(state.debugRecording, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
    // 「期待単語」と「STT回答」の両方が1問分残っている。
    expect(state.debugDrawnWord?.word, '単語');
    expect(state.debugLastSttAnswer, 'từ vựng');
  });

  testWidgets('紙飛行機（送信）は試験開始前（未回答）はゴースト表示', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer1VocabStandalone(tester);

    final finder = find.byIcon(Icons.send_rounded);
    expect(finder, findsOneWidget);
    final ignorePointer = tester.widget<IgnorePointer>(
      find.ancestor(of: finder, matching: find.byType(IgnorePointer)).first,
    );
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('リセットタップで単語テストの状態が初期化される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await VocabularyService().addEntry(
      '単語',
      'từ vựng',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(state.debugArmed, isTrue);
    expect(state.debugDrawnWord, isNotNull);

    // RecordingSttService.cancel()の3秒タイムアウトをフェイククロックで
    // 進めて解決させる（レイヤーⅤのresetAttempt回帰テストと同じ理由）。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    expect(state.debugArmed, isFalse);
    expect(state.debugRecording, isFalse);
    expect(state.debugDrawnWord, isNull);
    expect(state.debugLastSttAnswer, isNull);
    // サイコロに戻り、問題カードも空状態に戻る（試験を最初からやり直せる）。
    expect(_vocabDiceButton, findsOneWidget);
    expect(
      find.textContaining(_layer1EmptyLead, findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('キーボード入力モードの初期画面はサイコロとレベル選択が見え、'
      'サイコロタップ後に回答欄が出て、ソフトキーボードの inset があるときだけ'
      'コンパクト表示に切り替わる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    // 初期はサイコロ。回答欄はまだ出ない。
    expect(state.debugAnswerFieldFocused, isFalse);
    expect(state.debugCompactKeyboardLayout, isFalse);
    expect(state.debugSession, isNull);
    expect(_vocabDiceButton, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(_t('レベル')), findsOneWidget);
    expect(
      find.textContaining(
        _t('レイヤーⅠ_語彙_サイコロで開始').split('{{dice}}').last.trim(),
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(state.debugSession, isNotNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(_vocabDiceButton, findsNothing);

    // inset 無しではコンパクトにしない。
    expect(state.debugCompactKeyboardLayout, isFalse);
    expect(find.text(_t('レベル')), findsOneWidget);

    state.debugSetKeyboardInsetVisible(true);
    await tester.pump();
    expect(state.debugCompactKeyboardLayout, isTrue);
    expect(find.text(_t('レベル')), findsNothing);
  });

  testWidgets('キーボード入力モードでリセットすると、サイコロ付きの初期画面に戻る', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(state.debugSession, isNotNull);
    state.debugSetKeyboardInsetVisible(true);
    await tester.pump();
    expect(state.debugCompactKeyboardLayout, isTrue);

    FocusManager.instance.primaryFocus?.unfocus();
    state.debugSetKeyboardInsetVisible(false);
    await tester.pump();
    expect(state.debugCompactKeyboardLayout, isFalse);
    expect(find.text(_t('レベル')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    expect(state.debugSession, isNull);
    expect(state.debugAnswerFieldFocused, isFalse);
    expect(state.debugCompactKeyboardLayout, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text(_t('レベル')), findsOneWidget);
  });

  testWidgets('キーボード入力でも回答言語はテキスト自動判定ではなく、'
      '回答言語ボタン（🇻🇳/🇺🇸/🇯🇵）の選択を記録する', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await tester.tap(find.text('🇻🇳'));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    expect(find.text('🇺🇸'), findsOneWidget);
    expect(state.debugAnswerLanguageCode, 'en');

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(state.debugSession, isNotNull);

    await state.debugSubmitKeyboardAnswer('物事を進めること');
    await tester.pump();

    expect(state.debugLastAnswerLanguageCode, 'en');
    expect(state.debugSession!.questions.first.answerLanguageCode, 'en');
  });

  testWidgets('キーボード入力でサイコロをタップすると1問目が表示され、'
      '回答欄に切り替わる', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(
      find.textContaining(
        _t('レイヤーⅠ_語彙_サイコロで開始').split('{{dice}}').last.trim(),
        findRichText: true,
      ),
      findsOneWidget,
    );

    await tester.tap(_vocabDiceButton);
    await tester.pump();
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    expect(state.debugSession, isNotNull);
    expect(state.debugDrawnWord?.word, '促進');
    expect(find.byType(TextField), findsOneWidget);
    expect(_vocabDiceButton, findsNothing);
    expect(
      find.textContaining(
        _t('レイヤーⅠ_語彙_サイコロで開始').split('{{dice}}').last.trim(),
        findRichText: true,
      ),
      findsNothing,
    );
  });

  testWidgets('キーボード入力で空ENTER中断するとサイコロに戻り、'
      '再タップで同じ問題の回答欄に戻る', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(state.debugSession, isNotNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('促進'), findsOneWidget);

    // 空ENTERで中断 → サイコロに戻る（問題はそのまま）。
    await state.debugSubmitKeyboardAnswer('');
    await tester.pump();
    expect(_vocabDiceButton, findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('促進'), findsOneWidget);

    // サイコロ再タップで回答欄へ再開。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);
    expect(_vocabDiceButton, findsNothing);
    expect(state.debugDrawnWord?.word, '促進');
  });

  testWidgets('回答一覧から任意の過去問を修正しても、その後の回答と現在問の下書きが残る', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    appSettings.vocabAnswerMode = VocabAnswerMode.keyboard;
    appSettings.includeDefaultVocabulary = false;
    addTearDown(() {
      appSettings.vocabAnswerMode = VocabAnswerMode.voice;
      appSettings.includeDefaultVocabulary = true;
    });
    for (var i = 1; i <= 5; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'answer $i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    for (var i = 0; i < 40 && state.debugSession == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }

    for (var i = 1; i <= 4; i++) {
      await state.debugSubmitKeyboardAnswer('回答$i');
      await tester.pump();
    }
    expect(state.debugSession!.currentIndex, 4);
    state.debugSetKeyboardInsetVisible(true);
    await tester.pump();
    await tester.enterText(find.byType(TextField), '5問目の下書き');

    await tester.tap(
      find.byKey(const ValueKey('review_keyboard_answers_button')),
    );
    await tester.pumpAndSettle();

    expect(find.text(_t('レイヤーⅠ_語彙_回答を修正')), findsOneWidget);
    for (var i = 1; i <= 4; i++) {
      expect(find.text('回答$i'), findsOneWidget);
    }

    await tester.tap(find.byKey(const ValueKey('edit_answer_2')));
    await tester.pumpAndSettle();
    expect(state.debugSession!.currentIndex, 2);
    expect(find.text('回答3'), findsOneWidget);

    await state.debugSubmitKeyboardAnswer('回答3修正');
    await tester.pump();

    expect(state.debugSession!.currentIndex, 4);
    expect(state.debugSession!.questions[2].sttResult, '回答3修正');
    expect(state.debugSession!.questions[3].sttResult, '回答4');
    expect(find.text('5問目の下書き'), findsOneWidget);
  });

  testWidgets('再生タップは、録音が無ければ何もしない', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer1VocabStandalone(tester);

    // 録音が無い間はグレーアウトしてタップ自体を無視するため、意図的に
    // ヒットテスト警告を黙らせる。
    await tester.tap(
      find.byIcon(Icons.play_arrow_rounded),
      warnIfMissed: false,
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(state.debugArmed, isFalse);
    expect(_vocabDiceButton, findsOneWidget);
  });

  testWidgets('単語帳を開くと、出題中の単語のカードが表示される（例：「促進」を出題中に'
      '単語帳を開いたら「促進」が見える）', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      AppPreferences.showStartupScreenKey: false,
      AppPreferences.includeDefaultVocabularyKey: false,
    });
    appSettings.includeDefaultVocabulary = false;
    // N1レベルの語は「促進」だけにして抽選を決定論的にしつつ、単語帳の
    // 既定の先頭（最後に登録した語）が「促進」にならないよう、N1以外の
    // 語を前後に挟んでおく。
    await VocabularyService().addEntry('単語A', 'a', level: VocabularyLevel.n2);
    await VocabularyService().addEntry(
      '促進',
      'thúc đẩy',
      level: VocabularyLevel.n1,
    );
    await VocabularyService().addEntry('単語B', 'b', level: VocabularyLevel.n2);
    await _pumpLayer1VocabStandalone(tester);

    // 既定のN1レベルでは「促進」しか引けないため決定論的。
    await tester.tap(_vocabDiceButton);
    await tester.pump();
    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    expect(state.debugDrawnWord?.word, '促進');

    await tester.tap(
      find.descendant(
        of: find.byType(PrepLabelRow),
        matching: find.byIcon(Icons.style_rounded),
      ),
    );
    await tester.pumpAndSettle();

    // 単語帳（ダイアログ）側のカードに絞って確認する（背後の単語テスト
    // 画面自体も「促進」を表示しているため、無条件のfind.textでは2件
    // ヒットしてしまう）。
    expect(
      find.descendant(
        of: find.byType(VocabularySheet),
        matching: find.text('促進'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('保存前の「語彙力評価結果」アイコンは非表示', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await _pumpLayer1VocabStandalone(tester);

    final ghostPill = tester.widget<GhostPill>(
      find.ancestor(
        of: find.byIcon(Icons.list_alt_rounded),
        matching: find.byType(GhostPill),
      ),
    );
    expect(ghostPill.visible, isFalse);
    expect(ghostPill.active, isFalse);
  });

  testWidgets('単語テスト結果を保存すると「語彙力評価結果」アイコンが青地になり、'
      '履歴一覧・詳細画面で確認できる', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(
      const ClipboardData(text: _validVocabAiEvaluationJson),
    );
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 保存直後に表示される結果ダイアログを閉じる。
    await tester.tap(find.widgetWithText(TextButton, _t('完了')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final ghostPill = tester.widget<GhostPill>(
      find.ancestor(
        of: find.byIcon(Icons.list_alt_rounded),
        matching: find.byType(GhostPill),
      ),
    );
    expect(ghostPill.visible, isTrue);
    expect(ghostPill.active, isTrue);

    await tester.tap(find.byIcon(Icons.list_alt_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(_t('語彙力評価結果')), findsOneWidget);
    expect(find.text('★★★★☆'), findsOneWidget);

    await tester.tap(find.text('★★★★☆'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 詳細画面：出題した単語一覧と、1問目のSTT結果が表示されている。
    expect(find.text(_t('出題した単語')), findsOneWidget);
    expect(find.text('回答0'), findsOneWidget);
  });

  testWidgets('単語テストで全10問に回答すると送信ボタンが表示される', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    expect(state.debugSession!.allAnswered, isTrue);
    final sendIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(sendIgnorePointer.ignoring, isFalse);
  });

  testWidgets('単語表示offのまま10問完走できる（ヒアリングのみのモードでも試験は成立する）', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    await tester.tap(find.byIcon(Icons.visibility_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    expect(tester.takeException(), isNull);
    expect(state.debugSession!.allAnswered, isTrue);
    final sendIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(sendIgnorePointer.ignoring, isFalse);
  });

  testWidgets('単語テストのChrome AI起動に失敗しても例外を出さず、貼り付け待ちにはならない', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform(succeeds: false);
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(fakeUrlLauncher.launchedUrls, hasLength(1));
    expect(find.text(_t('Chrome AIを開けませんでした')), findsOneWidget);
    // 起動に失敗しているので、貼り付け待ち（貼り付けアイコン）にはならず
    // 送信アイコンのままである。
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
  });

  testWidgets('単語テストはChromeから戻ったときに自動取り込みされ、緑ボタンなしでも保存される', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(
      const ClipboardData(text: _validVocabAiEvaluationJson),
    );

    final binding = tester.binding;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    final saved = await VocabularyCheckStorage().loadAll();
    expect(saved, hasLength(1));
    expect(saved.first.evaluation?.overallScore, 4);
    expect(find.text(_t('語彙力評価結果')), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
  });

  testWidgets('単語テストの貼り付けボタンを連続でタップしても保存は1件だけになり（二重保存防止）、'
      '★評価の結果ダイアログが表示される', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await Clipboard.setData(
      const ClipboardData(text: _validVocabAiEvaluationJson),
    );

    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

    // レイヤーⅤの同種テストと同じ理由（ダブルタップは今、機能ヒントに
    // 使われるため連続タップでの二重保存はUIタップ経由では起こり得ない）。
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    final saved = await VocabularyCheckStorage().loadAll();
    expect(saved, hasLength(1));
    expect(saved.first.evaluation?.overallScore, 4);
    // 貼り付け成功後は結果ダイアログがその場で表示される
    // （履歴一覧画面はStep7では作らない最小実装）。
    expect(find.text(_t('語彙力評価結果')), findsOneWidget);
    expect(find.text('★★★★☆'), findsOneWidget);
  });

  testWidgets('単語テストの回答をAIが解析できない形式で返しても、原文つきで保存され'
      '（結果ダイアログは出さない）貼り付け待ちは解除される', (WidgetTester tester) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    const garbledText = 'JSONではない、ただの説明文だけの回答です。';
    await Clipboard.setData(const ClipboardData(text: garbledText));
    await tester.tap(find.byIcon(Icons.content_paste_go_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    // 解析失敗時は結果ダイアログを出さず、メッセージだけ表示する。
    expect(find.text(_t('語彙力評価結果')), findsNothing);
    expect(find.text(_t('Chrome AIの回答を解析できませんでした')), findsOneWidget);
    // 保存済み扱いになり、貼り付け待ちは解除される（緑ボタンは消える）。
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);

    final saved = await VocabularyCheckStorage().loadAll();
    expect(saved, hasLength(1));
    expect(saved.single.evaluation, isNull);
    expect(saved.single.unparsedResponse, garbledText);
  });

  testWidgets('紙飛行機の貼り付け待ち中にリセットすると、貼り付け待ち状態も解除される', (
    WidgetTester tester,
  ) async {
    final originalUrlLauncher = UrlLauncherPlatform.instance;
    final fakeUrlLauncher = _FakeUrlLauncherPlatform();
    UrlLauncherPlatform.instance = fakeUrlLauncher;
    addTearDown(() => UrlLauncherPlatform.instance = originalUrlLauncher);

    SharedPreferences.setMockInitialValues({});
    _mockClipboard(tester);
    for (var i = 0; i < 10; i++) {
      await VocabularyService().addEntry(
        '単語$i',
        'word$i',
        level: VocabularyLevel.n1,
      );
    }
    await _pumpLayer1VocabStandalone(tester);

    final state = tester.state<Layer1VocabScreenState>(
      find.byType(Layer1VocabScreen),
    );
    await _completeAllVocabQuestions(tester, state);

    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, _t('同意してGoogleへ送信')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byIcon(Icons.content_paste_go_rounded), findsOneWidget);

    // RecordingSttService.cancel()の3秒タイムアウトをフェイククロックで
    // 進めて解決させる（他のリセット回帰テストと同じ理由）。
    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pump(_tapConfirmWait);
    await tester.pump(const Duration(seconds: 4));

    expect(tester.takeException(), isNull);
    expect(state.debugSession, isNull);
    // 貼り付け待ちが解除され、送信アイコン（送信前の見た目）に戻る。
    expect(find.byIcon(Icons.content_paste_go_rounded), findsNothing);
    final sendIgnorePointer = tester.widget<IgnorePointer>(
      find
          .ancestor(
            of: find.byIcon(Icons.send_rounded),
            matching: find.byType(IgnorePointer),
          )
          .first,
    );
    expect(sendIgnorePointer.ignoring, isTrue);
  });

  testWidgets('ホームインジケータ分の下端余白がある端末でも、レイヤーⅠのサイコロ等の'
      '縦位置がレイヤーⅡ・Ⅳと揃う（MainShellがレイヤーⅠ滞在中だけ'
      'bottomNavigationBarを渡すためScaffoldがbodyの下端安全域を0にする、'
      'その補正が効いているかの回帰テスト）', (WidgetTester tester) async {
    // ホームインジケータのある実機を模して、下端に安全域を持たせる。
    tester.view.physicalSize = const Size(900, 1900);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(bottom: 34);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiểm tra từ vựng'));
    await tester.pumpAndSettle();
    final layer1DiceY = tester.getTopLeft(_vocabDiceButton).dy;

    await tester.tap(find.text('Ⅱ'));
    await tester.pumpAndSettle();
    // Step 3: レイヤーⅡ入口の2択から「話題を増やす」を選ぶと、既存の
    // サイコロ画面（Layer2Screen）が開く。
    await tester.tap(find.text(_t('話題を増やす')));
    await tester.pumpAndSettle();
    final layer2DiceY = tester.getTopLeft(_vocabDiceButton).dy;

    await tester.tap(find.text('Ⅳ'));
    await tester.pumpAndSettle();
    // Step 5: レイヤーⅣ入口の2択から「ランダム」を選ぶと、既存の
    // サイコロ画面（Layer4Screen）が開く。
    await tester.tap(find.text(_t('ランダム')));
    await tester.pumpAndSettle();
    final layer4DiceY = tester.getTopLeft(_vocabDiceButton).dy;

    expect(layer1DiceY, closeTo(layer2DiceY, 0.5));
    expect(layer1DiceY, closeTo(layer4DiceY, 0.5));
  });

  testWidgets('レイヤーⅠの3択画面表示中に言語設定を変更すると、MainShellに再訪しなくても'
      '即座に翻訳が切り替わる（appSettingsを直接購読していないと、一度モードを'
      '選んでから3択画面へ戻るまで古い言語のまま表示され続ける回帰テスト）', (WidgetTester tester) async {
    await tester.pumpWidget(const OsmGradusApp());
    await tester.tap(find.text('Tầng I'));
    await tester.pumpAndSettle();

    expect(find.text('Mở rộng vốn từ'), findsOneWidget);

    // 設定画面を経由せず、appSettingsの変更だけを直接発火させる
    // （MainShell・Layer1EntryScreenは破棄されず保持され続けるため、実機で
    // 設定→言語変更→戻る、を行った状態と同じ状況を再現できる）。
    appSettings.language = 'en';
    await tester.pump();

    expect(find.text('Build vocabulary'.tr('en')), findsOneWidget);
    expect(find.text('Mở rộng vốn từ'), findsNothing);

    appSettings.language = 'vi';
    await tester.pump();
  });
}

/// 画面左端付近の[start]から右方向へフリックする
/// （[SwipeToCloseWrapper]の右スワイプ判定に必要な速度・距離を満たす）。
Future<void> _rightSwipeFrom(WidgetTester tester, Offset start) async {
  final gesture = await tester.startGesture(start);
  await gesture.moveBy(
    const Offset(40, 0),
    timeStamp: const Duration(milliseconds: 10),
  );
  await gesture.moveBy(
    const Offset(80, 0),
    timeStamp: const Duration(milliseconds: 20),
  );
  await gesture.moveBy(
    const Offset(120, 0),
    timeStamp: const Duration(milliseconds: 30),
  );
  await gesture.moveBy(
    const Offset(60, 0),
    timeStamp: const Duration(milliseconds: 40),
  );
  await gesture.up(timeStamp: const Duration(milliseconds: 40));
}

/// [Layer5Screen]単体を最小限のMaterialApp（SnackBar表示用にScaffold付き）で描画する。
///
/// レイヤーⅤの録音ボタンの検証は（path_provider経由のプラットフォーム
/// チャンネル呼び出しを含むため）[WidgetTester.runAsync]で実イベントループ上に
/// 処理を逃がす必要があるが、フルアプリ（[OsmGradusApp]）経由だとレイヤーⅠの
/// シェイク検出（sensors_plusの加速度センサー監視）がバックグラウンドで動いており、
/// runAsync()実行中にそちらの未実装プラットフォームチャンネル例外が無関係に
/// 飛んできてテストを汚染する。そのため、MainShellでのレイヤー切り替え自体を
/// 検証するテスト以外はこの単体描画を使う。
Future<void> _pumpLayer5Standalone(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer5Screen())),
  );
  await tester.pump();
}

/// [Layer1VocabScreen]単体を最小限のMaterialApp（SnackBar表示用にScaffold付き）
/// で描画する。理由は[_pumpLayer5Standalone]と同じ
/// （録音開始がpath_provider経由の実プラットフォームチャンネルを含むため
/// [WidgetTester.runAsync]が必要だが、フルアプリ経由だとレイヤーⅠの
/// シェイク検出がそこへ無関係な例外を投げ込みテストを汚染する）。
Future<void> _pumpLayer1VocabStandalone(WidgetTester tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: Scaffold(body: Layer1VocabScreen())),
  );
  await tester.pump();
}

/// 長文読解の操作バー（[LongArticleActionRow]）の各ボタンは
/// [TransportIconButton]として表示される。「訳を付ける」は登録単語があるとき
/// だけ visible になり、無いときは枠だけ残して非表示になる。
TransportIconButton _transportButtonWithTooltip(
  WidgetTester tester,
  String tooltip,
) => tester.widget<TransportIconButton>(
  find.byWidgetPredicate(
    (w) => w is TransportIconButton && w.tooltip == tooltip,
  ),
);

TransportIconButton _enrichButton(WidgetTester tester) =>
    _transportButtonWithTooltip(tester, _t('訳を付ける'));

TransportIconButton _vocabularyButton(WidgetTester tester) =>
    _transportButtonWithTooltip(tester, _t('単語帳'));

TransportIconButton _nextButton(WidgetTester tester) =>
    _transportButtonWithTooltip(tester, _t('次へ'));

/// クリップボードをテスト内で完結するインメモリの偽実装に差し替える。
///
/// `flutter_test`既定のクリップボード処理は`testWidgets`のFakeAsyncゾーン上では
/// setData/getDataが正しく往復しない（getDataが常にnullを返す）ため、
/// 貼り付けフローを検証するテストではこのモックを使う。
void _mockClipboard(WidgetTester tester) {
  var clipboardText = '';
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      switch (call.method) {
        case 'Clipboard.getData':
          return {'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String? ?? '';
          return null;
        default:
          return null;
      }
    },
  );
}

/// デバッグフックで10問すべてを「回答済み」にし、送信ボタンを表示させる
/// （実機のネイティブ録音・STTは介さない）。[Layer5ScreenState.debugCompleteCurrentQuestion]は
/// 実際の録音停止と同じくarmedをfalseに戻す（サイコロ表示）ため、
/// サイコロの軽いタップが「次の問題へ」の代わりになる。
Future<void> _completeAllQuestions(
  WidgetTester tester,
  Layer5ScreenState state,
) async {
  for (var i = 0; i < 10; i++) {
    state.debugCompleteCurrentQuestion('回答$i');
    await tester.pump();
    if (i < 9) {
      await tester.tap(_vocabDiceButton);
      await tester.pump();
    }
  }
}

/// デバッグフックで単語テストの全問を「回答済み」にし、送信ボタンを
/// 表示させる（実機のネイティブ録音・STTは介さない）。最初のサイコロ
/// タップでセッションを遅延生成してから、[Layer1VocabScreenState.debugCompleteWithSttAnswer]
/// で1問ずつ回答し、次の問題へはサイコロタップで進める
/// （[_completeAllQuestions]と同じ考え方）。
Future<void> _completeAllVocabQuestions(
  WidgetTester tester,
  Layer1VocabScreenState state,
) async {
  await tester.tap(_vocabDiceButton);
  await tester.pump();
  final total = state.debugSession!.questionCount;
  for (var i = 0; i < total; i++) {
    state.debugCompleteWithSttAnswer('回答$i');
    await tester.pump();
    if (i < total - 1) {
      await tester.tap(_vocabDiceButton);
      await tester.pump();
    }
  }
}

/// Chrome AIが返す5カテゴリ評価の正常なJSON回答例（貼り付けテスト用）。
const _validAiEvaluationJson = '''
{
  "categoryEvaluations": {
    "tsu": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "zRow": {"score": 4, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "rRow": {"score": 2, "confidence": "low", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "longVowel": {"score": 5, "confidence": "high", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"},
    "sokuon": {"score": 3, "confidence": "medium", "feedbackJa": "a", "feedbackVi": "b", "evidence": "c"}
  },
  "summaryJa": "全体的に良く練習できています。",
  "summaryVi": "Nhìn chung ban đã luyện tập tốt."
}''';

/// Chrome AIが返す単語テスト評価の正常なJSON回答例（貼り付けテスト用）。
/// 10問すべてに対応する`questionEvaluations`を用意する。
const _validVocabAiEvaluationJson = '''
{
  "questionEvaluations": [
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"},
    {"correct": true, "feedback": "a"}
  ],
  "overallScore": 4,
  "summary": "全体的に良く理解できています。"
}''';

/// アプリを起動し、起動画面→レイヤーⅤ→「短文」（既存のLayer5Screen）まで
/// 遷移する（Step 7でレイヤーⅤの入口が短文/長文の2択になったため、
/// 「短文」を選ぶ一手間が増えた）。
Future<void> _openLayer5(WidgetTester tester) async {
  await tester.pumpWidget(const OsmGradusApp());
  await tester.tap(find.text('Tầng I'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ⅴ'));
  await tester.pump();
  await tester.tap(find.text(_t('レイヤーⅤ_短文')));
  await tester.pump();
}

/// 🌐ボタン・レイヤーⅤの「評価を送信」での外部ブラウザ起動を、
/// 実プラットフォームチャンネルなしで検証するためのフェイク実装。
/// [succeeds]をfalseにすると、Chrome起動失敗（ブラウザが無い等）を模擬できる。
class _FakeUrlLauncherPlatform extends UrlLauncherPlatform {
  _FakeUrlLauncherPlatform({this.succeeds = true});

  final bool succeeds;
  final List<String> launchedUrls = [];

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchedUrls.add(url);
    return succeeds;
  }
}
