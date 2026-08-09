import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../controllers/prep_stage_controller.dart';
import '../theme/app_colors.dart';

/// 「結論」「理由」「例示」（PREP法）の実ボタン版。
/// 現在アクティブな段階だけが[AppPalette.cardAccent]（橙）で優しく点滅し、
/// タップすると次の段階へ進む。他の段階は白のまま反応しない。
class PrepStageRow extends StatefulWidget {
  const PrepStageRow({
    super.key,
    required this.controller,
    this.visible = true,
  });

  final PrepStageController controller;

  /// falseのとき、他のゴーストピル群と同じく背景色に同化させて
  /// 実質非表示・タップ無効にする（レイヤーⅣではPREPガイドを使わないため）。
  final bool visible;

  @override
  State<PrepStageRow> createState() => _PrepStageRowState();
}

class _PrepStageRowState extends State<PrepStageRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final stage = widget.controller.stage;
        return Row(
          children: [
            _pill(
              label: '結論'.tr(lang),
              stageValue: PrepStage.conclusion,
              currentStage: stage,
            ),
            const SizedBox(width: 8),
            _pill(
              label: '理由'.tr(lang),
              stageValue: PrepStage.reason,
              currentStage: stage,
            ),
            const SizedBox(width: 8),
            _pill(
              label: '例示'.tr(lang),
              stageValue: PrepStage.example,
              currentStage: stage,
            ),
          ],
        );
      },
    );
  }

  Widget _pill({
    required String label,
    required PrepStage stageValue,
    required PrepStage currentStage,
  }) {
    final active = stageValue == currentStage;
    return Expanded(
      child: AnimatedBuilder(
        animation: _blinkController,
        builder: (context, _) {
          return _PrepPill(
            label: label,
            active: active,
            visible: widget.visible,
            blinkOpacity: active ? _blinkController.value : 1.0,
            onTap: (active && widget.visible)
                ? widget.controller.advance
                : null,
          );
        },
      ),
    );
  }
}

class _PrepPill extends StatelessWidget {
  const _PrepPill({
    required this.label,
    required this.active,
    required this.visible,
    required this.blinkOpacity,
    required this.onTap,
  });

  final String label;
  final bool active;
  final bool visible;
  final double blinkOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.current;
    // 0.55〜1.0の範囲で優しく点滅させる（blinkOpacityは0.0〜1.0）。
    final opacity = active && visible ? 0.55 + blinkOpacity * 0.45 : 1.0;
    final sceneOutline = palette.textOnScenePrimary;
    final activeFill = palette.cardAccent;
    final fill = !visible
        ? palette.scene
        : (active ? activeFill : palette.scene);
    final border = !visible
        ? palette.scene
        : (active ? activeFill : sceneOutline);
    final foreground = !visible
        ? palette.scene
        : (active ? palette.onFill(activeFill) : sceneOutline);
    final content = Opacity(
      opacity: opacity,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: border, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
    return IgnorePointer(
      ignoring: !visible,
      child: ExcludeSemantics(
        excluding: !visible,
        child: GestureDetector(onTap: onTap, child: content),
      ),
    );
  }
}
