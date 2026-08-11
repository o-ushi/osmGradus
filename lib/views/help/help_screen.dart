import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../data/layer_help_tips.dart';
import '../../localization/app_strings.dart';
import '../../main.dart';
import '../../theme/app_colors.dart';
import '../../theme/surface_theme.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// osmGradus ヘルプ。最新機能をレイヤー色付きカードと箇条書きで整理する。
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HelpScreen()));
  }

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String? _versionLabel;

  static const _extraSections = [
    _HelpSectionSpec(
      icon: Icons.space_dashboard_outlined,
      titleKey: 'help.gradus.dashboard.title',
      summaryKey: 'help.gradus.dashboard.summary',
      tipKeys: [
        'help.gradus.dashboard.tip1',
        'help.gradus.dashboard.tip2',
        'help.gradus.dashboard.tip3',
        'help.gradus.dashboard.tip4',
      ],
    ),
    _HelpSectionSpec(
      icon: Icons.style_rounded,
      titleKey: 'help.gradus.vocabulary.title',
      summaryKey: 'help.gradus.vocabulary.summary',
      tipKeys: [
        'help.gradus.vocabulary.tip1',
        'help.gradus.vocabulary.tip2',
        'help.gradus.vocabulary.tip3',
        'help.gradus.vocabulary.tip4',
      ],
    ),
    _HelpSectionSpec(
      icon: Icons.workspace_premium_outlined,
      titleKey: 'help.gradus.transcript.title',
      summaryKey: 'help.gradus.transcript.summary',
      tipKeys: [
        'help.gradus.transcript.tip1',
        'help.gradus.transcript.tip2',
        'help.gradus.transcript.tip3',
      ],
    ),
    _HelpSectionSpec(
      icon: Icons.upload_outlined,
      titleKey: 'help.gradus.backup.title',
      summaryKey: 'help.gradus.backup.summary',
      tipKeys: [
        'help.gradus.backup.tip1',
        'help.gradus.backup.tip2',
        'help.gradus.backup.tip3',
        'help.gradus.backup.tip4',
      ],
    ),
    _HelpSectionSpec(
      icon: Icons.settings_outlined,
      titleKey: 'help.gradus.settings.title',
      summaryKey: 'help.gradus.settings.summary',
      tipKeys: [
        'help.gradus.settings.tip1',
        'help.gradus.settings.tip2',
        'help.gradus.settings.tip3',
        'help.gradus.settings.tip4',
      ],
    ),
    _HelpSectionSpec(
      icon: Icons.swipe_rounded,
      titleKey: 'help.gradus.gesture.title',
      summaryKey: 'help.gradus.gesture.summary',
      tipKeys: [
        'help.gradus.gesture.tip1',
        'help.gradus.gesture.tip2',
        'help.gradus.gesture.tip3',
      ],
    ),
  ];

  static const _numerals = ['Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ'];

  @override
  void initState() {
    super.initState();
    appSettings.addListener(_onSettingsChanged);
    _loadVersion();
  }

  @override
  void dispose() {
    appSettings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _versionLabel = 'バージョン %@ (%@)'.trFmt(appSettings.language, [
        info.version,
        info.buildNumber,
      ]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('ヘルプ'.tr(lang)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _HelpHero(
            title: 'help.gradus.title'.tr(lang),
            subtitle: 'help.gradus.subtitle'.tr(lang),
            versionLabel: _versionLabel,
          ),
          const SizedBox(height: 20),
          _HelpLeadCard(
            title: 'help.gradus.overview.title'.tr(lang),
            summary: 'help.gradus.overview.summary'.tr(lang),
            tips: [
              'help.gradus.overview.tip1'.tr(lang),
              'help.gradus.overview.tip2'.tr(lang),
              'help.gradus.overview.tip3'.tr(lang),
              'help.gradus.overview.tip4'.tr(lang),
            ],
            accentColor: palette.scene,
          ),
          const SizedBox(height: 20),
          Text(
            'help.gradus.sections.layers'.tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: palette.textOnSubpageSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < LayerHelpTips.layers.length; i++)
            _HelpSectionCard(
              lang: lang,
              spec: _HelpSectionSpec(
                layerIndex: i,
                titleKey: LayerHelpTips.layers[i].titleKey,
                summaryKey: LayerHelpTips.layers[i].summaryKey,
                tipKeys: LayerHelpTips.layers[i].tipKeys,
              ),
              accentColor: kLayerColors[i],
              badgeLabel: _numerals[i],
            ),
          const SizedBox(height: 12),
          Text(
            'help.gradus.sections.more'.tr(lang),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: palette.textOnSubpageSecondary,
            ),
          ),
          const SizedBox(height: 10),
          for (final section in _extraSections)
            _HelpSectionCard(
              lang: lang,
              spec: section,
              accentColor: palette.cardAccent,
              icon: section.icon,
            ),
        ],
      ),
    );
  }
}

class _HelpSectionSpec {
  const _HelpSectionSpec({
    this.layerIndex,
    this.icon,
    required this.titleKey,
    required this.summaryKey,
    required this.tipKeys,
  });

  final int? layerIndex;
  final IconData? icon;
  final String titleKey;
  final String summaryKey;
  final List<String> tipKeys;
}

class _HelpHero extends StatelessWidget {
  const _HelpHero({
    required this.title,
    required this.subtitle,
    required this.versionLabel,
  });

  final String title;
  final String subtitle;
  final String? versionLabel;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: palette.textOnSubpagePrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: palette.textOnSubpageSecondary,
          ),
        ),
        if (versionLabel != null) ...[
          const SizedBox(height: 4),
          Text(
            versionLabel!,
            style: TextStyle(
              fontSize: 12,
              color: palette.textOnSubpageSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class _HelpLeadCard extends StatelessWidget {
  const _HelpLeadCard({
    required this.title,
    required this.summary,
    required this.tips,
    required this.accentColor,
  });

  final String title;
  final String summary;
  final List<String> tips;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return _HelpSectionCardShell(
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.current.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            summary,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: AppColors.current.textOnCardPrimary,
            ),
          ),
          const SizedBox(height: 10),
          _HelpBulletList(tips: tips, bulletColor: accentColor),
        ],
      ),
    );
  }
}

class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard({
    required this.lang,
    required this.spec,
    required this.accentColor,
    this.badgeLabel,
    this.icon,
  });

  final String lang;
  final _HelpSectionSpec spec;
  final Color accentColor;
  final String? badgeLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final onAccent = palette.onFill(accentColor);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _HelpSectionCardShell(
        accentColor: accentColor,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: badgeLabel != null
                      ? Text(
                          badgeLabel!,
                          style: TextStyle(
                            color: onAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        )
                      : Icon(icon, color: onAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spec.titleKey.tr(lang),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: palette.textOnCardPrimary,
                        ),
                      ),
                      Text(
                        spec.summaryKey.tr(lang),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _HelpBulletList(tips: spec.tipKeys.map((k) => k.tr(lang)).toList()),
          ],
        ),
      ),
    );
  }
}

class _HelpSectionCardShell extends StatelessWidget {
  const _HelpSectionCardShell({required this.accentColor, required this.child});

  final Color accentColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Container(
      decoration: BoxDecoration(
        color: palette.cardFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: accentColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Theme(data: SurfaceTheme.card(context), child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpBulletList extends StatelessWidget {
  const _HelpBulletList({required this.tips, this.bulletColor});

  final List<String> tips;
  final Color? bulletColor;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    final dotColor = bulletColor ?? palette.cardAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final tip in tips) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tip,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: palette.textOnCardSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (tip != tips.last) const SizedBox(height: 6),
        ],
      ],
    );
  }
}
