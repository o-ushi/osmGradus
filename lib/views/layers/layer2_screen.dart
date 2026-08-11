import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../models/drawn_topic.dart';
import '../../models/topic_category.dart';
import '../../services/topic_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/category_select_field.dart';
import '../../widgets/dice_action_row.dart';
import '../../widgets/dice_topic_card.dart';
import '../../widgets/genki_transport_row.dart';
import '../../widgets/layer_help_sheet.dart';
import '../../widgets/prep_label_row.dart';
import '../topics/topic_add_flow.dart';

/// レイヤーⅡ：なんて答えたら良いか分からず頭が真っ白。
/// osmWashabeのサイコロ機能・お題取り込み機能を移植する。
class Layer2Screen extends StatefulWidget {
  const Layer2Screen({super.key});

  @override
  State<Layer2Screen> createState() => Layer2ScreenState();
}

class Layer2ScreenState extends State<Layer2Screen> {
  final _topicService = TopicService();

  TopicCategory _selectedCategory = TopicCategory.daily;
  DrawnTopic? _drawnTopic;
  bool _drawing = false;

  @override
  void initState() {
    super.initState();
    // [MainShell]に一度生成されたら破棄されずキャッシュされ続けるため、
    // 設定画面で言語を変えて戻ってきただけでは再構築されず表示が古い言語の
    // ままになる。appSettingsの変更を直接購読し、その場で再描画する。
    appSettings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _drawTopic() async {
    setState(() => _drawing = true);
    final topic = await _topicService.drawRandom(_selectedCategory);
    if (!mounted) return;
    setState(() {
      _drawnTopic = topic;
      _drawing = false;
    });
  }

  Future<void> _showAddChoice() =>
      showTopicAddChoiceFlow(context, initialCategory: _selectedCategory);

  /// 「理由」枠を転用した🌐ボタンから、カテゴリに応じた検索語で
  /// 外部ブラウザを開く（以前はサイコロボタンの長押しだった機能）。
  Future<void> _browseInChrome() async {
    final query = switch (_selectedCategory) {
      TopicCategory.daily => '日本語 日常会話 お題 一覧',
      TopicCategory.business => '日本語 ビジネス会話 お題 一覧',
      TopicCategory.situational => '日本語 会話 シチュエーション 練習 一覧',
      TopicCategory.random => '日本語 スピーキング お題 一覧',
    };
    final url = Uri.https('www.google.com', '/search', {'q': query});
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// 「＋」長押し：分野選択・サイコロ・イメージの3ステップを表示する。
  void _showUsageHelp() {
    final lang = appSettings.language;
    LayerHelpSheet.show(
      context,
      title: '操作方法'.tr(lang),
      lines: [
        LayerHelpLine(text: 'レイヤーⅡ_使い方_分野'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_使い方_サイコロ'.tr(lang), icon: Icons.casino),
        LayerHelpLine(text: 'レイヤーⅡ_使い方_イメージ'.tr(lang)),
        LayerHelpLine(text: 'レイヤーⅡ_使い方_ノート1'.tr(lang), indent: true),
        LayerHelpLine(text: 'レイヤーⅡ_使い方_ノート2'.tr(lang), indent: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Container(
      color: palette.scene,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DiceActionRow(
                showAdd: true,
                addIcon: Icons.add_rounded,
                addTooltip: 'お題の取り込み',
                onAddTap: _showAddChoice,
                onAddLongPress: _showUsageHelp,
                addHintTapText: 'お題の取り込み',
                addHintLongPressText: '操作方法',
              ),
              const SizedBox(height: 4),
              CategorySelectField(
                selected: _selectedCategory,
                onChanged: (category) {
                  setState(() {
                    _selectedCategory = category;
                    _drawnTopic = null;
                  });
                },
              ),
              const SizedBox(height: 4),
              // シチュエーションのお題は文章が長くなることがあるため、お題エリアは
              // スクロール可能な領域に閉じ込める。ボタン列は下に固定サイズで
              // 積み上げ、余った縦幅は全てお題エリアに渡す
              // （問題表示欄の下が見切れないようにするため）。
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DiceTopicCard(topic: _drawnTopic),
                      const SizedBox(height: 8),
                      Text(
                        'なんて回答するかイメージして'.tr(lang),
                        style: TextStyle(
                          fontSize: 13,
                          color: palette.textOnSceneSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _drawing ? null : _drawTopic,
                  child: Container(
                    // 横長の長方形にする：高さはそのまま、幅だけ2倍にする。
                    width: 196,
                    height: 98,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(16)),
                    ),
                    child: _drawing
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: palette.onAccent,
                            ),
                          )
                        : Icon(
                            Icons.casino,
                            // 余白ゼロ：アイコンをボタンの高さいっぱいまで大きくする。
                            size: 98,
                            color: palette.onAccent,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 「理由」枠だけ🌐として表示し、タップでGoogle検索を開く。
              // 「結論」「例示」と下段の再生/リセット/診断は枠だけ確保した
              // 非表示（背景色化・タップ無効）状態で置いておく。
              PrepLabelRow(
                showReason: true,
                reasonLabel: '🌐',
                reasonTooltip: 'Google検索',
                reasonShowBorder: false,
                reasonHorizontalPadding: 0,
                reasonLabelFontSize: 56,
                onReasonTap: _browseInChrome,
              ),
              const SizedBox(height: 8),
              const GenkiTransportRow(),
            ],
          ),
        ),
      ),
    );
  }
}
