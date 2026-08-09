import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../services/speech_recognition_debug_log_store.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// 永続化された音声認識ログ。フリーズ後にアプリを再起動して確認する。
/// osmWashabeの`SpeechRecognitionDebugLogView`の移植。
class SpeechRecognitionDebugLogView extends StatefulWidget {
  const SpeechRecognitionDebugLogView({super.key});

  static Future<void> push(BuildContext context) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpeechRecognitionDebugLogView()),
    );
  }

  @override
  State<SpeechRecognitionDebugLogView> createState() =>
      _SpeechRecognitionDebugLogViewState();
}

class _SpeechRecognitionDebugLogViewState
    extends State<SpeechRecognitionDebugLogView> {
  late Future<List<String>> _future = SpeechRecognitionDebugLogStore.instance
      .load();

  Future<void> _reload() async {
    setState(() {
      _future = SpeechRecognitionDebugLogStore.instance.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return OsmSubpageScaffold(
      title: Text('音声認識ログ'.tr(lang)),
      body: FutureBuilder<List<String>>(
        future: _future,
        builder: (context, snapshot) {
          final lines = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              Text(
                '音声認識ログ_説明'.tr(lang),
                style: TextStyle(color: palette.textOnSubpageSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  TextButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: Text('再読み込み'.tr(lang)),
                  ),
                  TextButton.icon(
                    onPressed: lines.isEmpty
                        ? null
                        : () async {
                            await Clipboard.setData(
                              ClipboardData(text: lines.join('\n')),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('コピーしました'.tr(lang))),
                            );
                          },
                    icon: const Icon(Icons.copy, size: 18),
                    label: Text('コピー'.tr(lang)),
                  ),
                  TextButton.icon(
                    onPressed: lines.isEmpty
                        ? null
                        : () async {
                            await SpeechRecognitionDebugLogStore.instance
                                .clear();
                            await _reload();
                          },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: Text('クリア'.tr(lang)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Center(child: CircularProgressIndicator())
              else if (lines.isEmpty)
                Text(
                  '(ログなし)'.tr(lang),
                  style: TextStyle(color: palette.textOnSubpageSecondary),
                )
              else
                SelectableText(
                  lines.join('\n'),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    height: 1.45,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
