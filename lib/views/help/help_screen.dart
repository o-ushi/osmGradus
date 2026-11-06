import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../localization/app_strings.dart';
import '../../main.dart';
import '../../theme/app_colors.dart';
import '../../widgets/gradus_expand_card.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../settings/privacy_data_screen.dart';

/// ヘルプ。上から 練習 → 閲覧 → 困った時 → その他 の順。
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

  /// 開いている節。
  final Set<String> _openSections = {};

  /// 色はまとまりごとに揃える。
  List<_HelpSection> get _sections => [
    const _HelpSection('g_l1', Icons.style_rounded, Colors.orange, 3),
    const _HelpSection(
      'g_l2',
      Icons.lightbulb_outline_rounded,
      Colors.orange,
      3,
    ),
    const _HelpSection('g_l3', Icons.account_tree_outlined, Colors.orange, 3),
    const _HelpSection('g_l4', Icons.mic_none_rounded, Colors.orange, 3),
    const _HelpSection(
      'g_l5',
      Icons.record_voice_over_outlined,
      Colors.orange,
      3,
    ),
    const _HelpSection('g_vocab', Icons.menu_book_rounded, Colors.blue, 3),
    const _HelpSection('g_prompts', Icons.list_alt_rounded, Colors.blue, 3),
    const _HelpSection(
      'g_dashboard',
      Icons.space_dashboard_outlined,
      Colors.blue,
      3,
    ),
    const _HelpSection(
      'g_certificate',
      Icons.workspace_premium_outlined,
      Colors.blue,
      1,
    ),
    const _HelpSection('g_copy', Icons.copy_rounded, Colors.purple, 2),
    const _HelpSection('g_hint', Icons.touch_app_outlined, Colors.purple, 1),
    const _HelpSection('g_close', Icons.swipe_rounded, Colors.purple, 1),
    const _HelpSection('g_export', Icons.upload_outlined, Colors.purple, 2),
    const _HelpSection('g_import', Icons.download_outlined, Colors.purple, 2),
    // iCloud同期はiPhoneだけの機能（Androidでは設定にも出さない）。
    if (!Platform.isAndroid)
      const _HelpSection('g_icloud', Icons.cloud_sync_outlined, Colors.teal, 1),
  ];

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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _HelpHero(
            title: 'help.gradus.title'.tr(lang),
            subtitle: 'help.gradus.subtitle'.tr(lang),
            versionLabel: _versionLabel,
          ),
          const SizedBox(height: 20),
          for (final section in _sections)
            Padding(
              key: ValueKey('help-section-${section.id}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: GradusExpandCard(
                title: 'help.${section.id}.title'.tr(lang),
                icon: section.icon,
                accent: section.accent,
                open: _openSections.contains(section.id),
                onToggle: () => setState(() {
                  if (!_openSections.remove(section.id)) {
                    _openSections.add(section.id);
                  }
                }),
                child: GradusStepList(
                  color: section.accent,
                  steps: [
                    for (var i = 1; i <= section.stepCount; i++)
                      'help.${section.id}.$i'.tr(lang),
                  ],
                ),
              ),
            ),
          Material(
            color: palette.cardFill,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: palette.cardBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              key: const ValueKey('help-privacy'),
              leading: const Icon(
                Icons.privacy_tip_outlined,
                color: Colors.teal,
              ),
              title: Text(
                'プライバシーとデータ'.tr(lang),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: palette.textOnCardSecondary,
              ),
              onTap: () => PrivacyDataScreen.push(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// ヘルプの 1 節。文言は `help.<id>.title` と `help.<id>.1`〜。
class _HelpSection {
  const _HelpSection(this.id, this.icon, this.accent, this.stepCount);

  final String id;
  final IconData icon;
  final Color accent;
  final int stepCount;
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
