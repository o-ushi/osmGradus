import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../services/privacy_consent_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';
import '../../widgets/settings_section.dart';

class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key});

  static const privacyPolicyUrl =
      'https://docs.google.com/document/d/'
      '1ZFKiECg12-2mOJNLXP26TvfVtcnA_AfvbQJxT3knybo/edit?usp=sharing';
  static const googlePrivacyUrl = 'https://policies.google.com/privacy';
  static const applePrivacyUrl = 'https://www.apple.com/legal/privacy/';

  static Future<void> push(BuildContext context) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const PrivacyDataScreen()));

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool? _speechConsent;

  String get _lang => appSettings.language;

  /// iOS/Androidで実装が異なる（iOSはApple Speech Recognitionのみ、
  /// AndroidはOSの音声認識→失敗時Voskフォールバック）ため、文言も
  /// プラットフォームごとに分ける。それ以外（未対応OS等）は既存の汎用文言。
  String get _speechRecognitionExplanationKey {
    if (Platform.isIOS) return 'プライバシー_音声認識説明_iOS';
    if (Platform.isAndroid) return 'プライバシー_音声認識説明_Android';
    return 'プライバシー_音声認識説明';
  }

  @override
  void initState() {
    super.initState();
    _refreshConsent();
  }

  Future<void> _refreshConsent() async {
    final consent = await PrivacyConsentService.hasSpeechProcessingConsent();
    if (mounted) setState(() => _speechConsent = consent);
  }

  Future<void> _open(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _revoke() async {
    await PrivacyConsentService.revokeSpeechProcessingConsent();
    await _refreshConsent();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('音声認識の同意を撤回しました'.tr(_lang))));
  }

  Future<void> _grant() async {
    await PrivacyConsentService.grantSpeechProcessingConsent();
    await _refreshConsent();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('音声認識に同意しました'.tr(_lang))));
  }

  @override
  Widget build(BuildContext context) {
    final lang = _lang;
    return OsmSubpageScaffold(
      title: Text('プライバシーとデータ'.tr(lang)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              SettingsSectionHeader('プライバシー_外部送信'.tr(lang)),
              _InfoCard(
                title: '音声認識'.tr(lang),
                body: _speechRecognitionExplanationKey.tr(lang),
              ),
              _InfoCard(
                title: 'Google AIによる発音評価'.tr(lang),
                body: 'プライバシー_Google説明'.tr(lang),
              ),
              _InfoCard(
                title: 'お題・練習課題の生成'.tr(lang),
                body: 'プライバシー_お題生成説明'.tr(lang),
              ),
              _InfoCard(
                title: 'Podcast検索・再生'.tr(lang),
                body: 'プライバシー_Podcast説明'.tr(lang),
              ),

              const SizedBox(height: 8),
              _LinkTile(
                label: 'プライバシーポリシー'.tr(lang),
                onTap: () => _open(PrivacyDataScreen.privacyPolicyUrl),
              ),
              SettingsNoteText('プライバシー_ポリシー本文_詳細'.tr(lang)),

              SettingsSectionHeader('関連ポリシー'.tr(lang)),
              _LinkTile(
                label: 'Google プライバシーポリシー'.tr(lang),
                onTap: () => _open(PrivacyDataScreen.googlePrivacyUrl),
              ),
              _LinkTile(
                label: 'Apple プライバシーポリシー'.tr(lang),
                onTap: () => _open(PrivacyDataScreen.applePrivacyUrl),
              ),
              SettingsNoteText('プライバシー_関連ポリシー_詳細'.tr(lang)),

              SettingsSectionHeader('プライバシー_端末保存'.tr(lang)),
              _InfoCard(body: 'プライバシー_保存詳細'.tr(lang)),
              _InfoCard(body: 'プライバシー_保持削除詳細'.tr(lang)),

              SettingsSectionHeader('同意管理'.tr(lang)),
              _ConsentStatusCard(
                granted: _speechConsent,
                lang: lang,
                onGrant: _grant,
                onRevoke: _revoke,
              ),
              SettingsNoteText('プライバシー_撤回注記'.tr(lang)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentStatusCard extends StatelessWidget {
  const _ConsentStatusCard({
    required this.granted,
    required this.lang,
    required this.onGrant,
    required this.onRevoke,
  });

  final bool? granted;
  final String lang;
  final VoidCallback onGrant;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    if (granted == null) return const SizedBox.shrink();
    final palette = AppColors.current;
    final isGranted = granted == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isGranted ? Icons.check_circle : Icons.pan_tool_alt_outlined,
                  color: isGranted ? Colors.green : Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (isGranted ? 'プライバシー_同意済み' : 'プライバシー_未同意').tr(lang),
                    style: TextStyle(
                      fontSize: 15,
                      color: palette.textOnCardPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isGranted)
              OutlinedButton(
                onPressed: onRevoke,
                child: Text('音声認識への同意を撤回'.tr(lang)),
              )
            else
              FilledButton(
                onPressed: onGrant,
                child: Text('音声認識に同意する'.tr(lang)),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({this.title, required this.body});

  final String? title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: palette.textOnCardSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: const Icon(Icons.open_in_new_rounded),
    title: Text(label),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
