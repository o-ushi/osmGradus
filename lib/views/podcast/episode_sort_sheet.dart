import 'package:flutter/material.dart';

import '../../localization/app_strings.dart';
import '../../main.dart' show appSettings;
import '../../services/podcast_library_service.dart';
import '../../theme/app_colors.dart';

/// osmPodの `LibrarySortToolbarMenu`（並べ替えパネル）に相当。
/// 「日付」「名前」の基準選択（チェックマーク）＋昇順トグルという、
/// osmPod本体と同じ2軸構成をそのまま移植する。
class EpisodeSortSheet extends StatefulWidget {
  const EpisodeSortSheet({
    super.key,
    required this.criterion,
    required this.ascending,
    required this.onChanged,
  });

  final EpisodeSortCriterion criterion;
  final bool ascending;
  final void Function(EpisodeSortCriterion criterion, bool ascending) onChanged;

  static Future<void> show(
    BuildContext context, {
    required EpisodeSortCriterion criterion,
    required bool ascending,
    required void Function(EpisodeSortCriterion criterion, bool ascending)
    onChanged,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet(
      context: context,
      backgroundColor: palette.cardFill,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EpisodeSortSheet(
        criterion: criterion,
        ascending: ascending,
        onChanged: onChanged,
      ),
    );
  }

  @override
  State<EpisodeSortSheet> createState() => _EpisodeSortSheetState();
}

class _EpisodeSortSheetState extends State<EpisodeSortSheet> {
  late EpisodeSortCriterion _criterion = widget.criterion;
  late bool _ascending = widget.ascending;

  void _selectCriterion(EpisodeSortCriterion criterion) {
    setState(() => _criterion = criterion);
    widget.onChanged(_criterion, _ascending);
  }

  void _setAscending(bool value) {
    setState(() => _ascending = value);
    widget.onChanged(_criterion, _ascending);
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '並べ替え'.tr(lang),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: palette.textOnCardPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'エピソード'.tr(lang),
              style: TextStyle(
                fontSize: 13,
                color: palette.textOnCardSecondary,
              ),
            ),
            const SizedBox(height: 8),
            _CriterionRow(
              label: '日付'.tr(lang),
              selected: _criterion == EpisodeSortCriterion.date,
              onTap: () => _selectCriterion(EpisodeSortCriterion.date),
            ),
            _CriterionRow(
              label: '名前'.tr(lang),
              selected: _criterion == EpisodeSortCriterion.name,
              onTap: () => _selectCriterion(EpisodeSortCriterion.name),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '昇順'.tr(lang),
                style: TextStyle(color: palette.textOnCardPrimary),
              ),
              value: _ascending,
              activeThumbColor: palette.accentColor,
              onChanged: _setAscending,
            ),
          ],
        ),
      ),
    );
  }
}

class _CriterionRow extends StatelessWidget {
  const _CriterionRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  color: palette.textOnCardPrimary,
                ),
              ),
            ),
            if (selected) Icon(Icons.check, color: palette.accentColor),
          ],
        ),
      ),
    );
  }
}
