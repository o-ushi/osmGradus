import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../services/alarm_sound_service.dart';
import '../../services/tts_settings_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/osm_subpage_scaffold.dart';

/// タイマー完了時に鳴らすアラーム音の選択画面。
/// osmWashabeのタイマー音ピッカー（`TimerSoundPickerView`）の移植。
/// Android: 通知音一覧。iOS: カタログ音（Appleのシステムサウンド18種）＋
/// 着信音ファイル一覧。各行の再生ボタンでプレビューでき、選択中の音には
/// チェックが付く。
class AlarmSoundPickerScreen extends StatefulWidget {
  const AlarmSoundPickerScreen({super.key, required this.settings});

  final TtsSettingsService settings;

  static Future<void> push(
    BuildContext context, {
    required TtsSettingsService settings,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlarmSoundPickerScreen(settings: settings),
      ),
    );
  }

  @override
  State<AlarmSoundPickerScreen> createState() => _AlarmSoundPickerScreenState();
}

class _AlarmSoundPickerScreenState extends State<AlarmSoundPickerScreen> {
  List<AlarmSoundOption> _options = [];
  bool _loading = true;
  String? _previewing;

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    AlarmSoundService.stop();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final options = await AlarmSoundService.getSounds();
    if (!mounted) return;
    setState(() {
      _options = options;
      _loading = false;
    });
  }

  Future<void> _preview(AlarmSoundOption option) async {
    setState(() => _previewing = option.storedValue);
    await AlarmSoundService.play(option.storedValue);
    if (!mounted) return;
    if (_previewing == option.storedValue) {
      setState(() => _previewing = null);
    }
  }

  Future<void> _select(String storedValue, String title) async {
    await AlarmSoundService.stop();
    await widget.settings.setAlarmSound(storedValue, title);
    if (!mounted) return;
    setState(() => _previewing = null);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return OsmSubpageScaffold(
      title: Text('タイマー音'.tr(lang)),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) {
          if (_loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_options.isEmpty) {
            return Center(child: Text('利用できる音がありません'.tr(lang)));
          }
          return ListView(
            children: [
              _SoundTile(
                title: '既定の通知音'.tr(lang),
                selected: widget.settings.alarmSound.isEmpty,
                playing: false,
                onTap: () => _select('', '既定の通知音'.tr(lang)),
                onPlay: null,
              ),
              const Divider(height: 1),
              for (final option in _options)
                _SoundTile(
                  title: option.title,
                  selected: widget.settings.alarmSound == option.storedValue,
                  playing: _previewing == option.storedValue,
                  onTap: () => _select(option.storedValue, option.title),
                  onPlay: () => _preview(option),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.title,
    required this.selected,
    required this.playing,
    required this.onTap,
    required this.onPlay,
  });

  final String title;
  final bool selected;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return ListTile(
      title: Text(title),
      onTap: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onPlay != null)
            IconButton(
              onPressed: onPlay,
              icon: Icon(
                playing ? Icons.stop_circle : Icons.play_circle_outline,
                color: palette.accentColor,
              ),
            ),
          if (selected) Icon(Icons.check, color: palette.accentColor),
        ],
      ),
    );
  }
}
