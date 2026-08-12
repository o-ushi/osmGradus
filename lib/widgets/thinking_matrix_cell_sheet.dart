import 'dart:async';

import 'package:flutter/material.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings;
import '../models/thinking_matrix_cell.dart';
import '../models/thinking_matrix_column.dart';
import '../models/thinking_matrix_layer.dart';
import '../models/thinking_matrix_set.dart';
import '../models/thinking_theme.dart';
import '../services/thinking_matrix_service.dart';
import '../theme/app_colors.dart';

/// 表示用のテーマ名。プリセット（[ThinkingMatrixSet.category]が非null）は
/// [ThinkingMatrixPresets]のテーマ名がそのままl10nキー（日本語ソース）のため
/// 翻訳する。オリジナル（`category`がnull）はユーザーの自由入力なので、
/// 偶然プリセットのテーマ名（「旅行」等）と一致していても翻訳しない。
String themeDisplayName(
  ThinkingMatrixSet set,
  ThinkingTheme theme,
  String lang,
) => set.category == null ? theme.name : theme.name.tr(lang);

/// [ThinkingMatrixCell]1マスのキーワード（・[layer]が[ThinkingMatrixLayer.layer3]
/// のときはPREP：結論・理由・例示、60秒スピーチ）入力を持つモーダルボトムシート
/// （[TextEditSheet]と同型）。60秒スピーチはタップ直後にシート内完結の
/// カウントダウンを始める（確認は挟まない。録音・マイク・
/// [PracticeTimerController]は使わない）。完了後のチェックマークは長押しで
/// 取り消せる（やり直し用）。
/// 「マスを埋める」で[ThinkingMatrixService.upsertCellLayer2]または
/// [ThinkingMatrixService.upsertCellLayer3]（[layer]による）を呼び、更新後の
/// [ThinkingMatrixSet]をpopする。キャンセル・スワイプで閉じた場合はnullを
/// popする（保存しない）。
class ThinkingMatrixCellSheet extends StatefulWidget {
  const ThinkingMatrixCellSheet({
    super.key,
    required this.service,
    required this.set,
    required this.theme,
    required this.column,
    required this.cell,
    required this.layer,
  });

  final ThinkingMatrixService service;
  final ThinkingMatrixSet set;
  final ThinkingTheme theme;
  final ThinkingMatrixColumn column;
  final ThinkingMatrixCell cell;
  final ThinkingMatrixLayer layer;

  static Future<ThinkingMatrixSet?> show(
    BuildContext context, {
    required ThinkingMatrixService service,
    required ThinkingMatrixSet set,
    required ThinkingTheme theme,
    required ThinkingMatrixColumn column,
    required ThinkingMatrixCell cell,
    required ThinkingMatrixLayer layer,
  }) {
    final palette = AppColors.current;
    return showModalBottomSheet<ThinkingMatrixSet>(
      context: context,
      backgroundColor: palette.cardFill,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ThinkingMatrixCellSheet(
        service: service,
        set: set,
        theme: theme,
        column: column,
        cell: cell,
        layer: layer,
      ),
    );
  }

  @override
  State<ThinkingMatrixCellSheet> createState() =>
      _ThinkingMatrixCellSheetState();
}

class _ThinkingMatrixCellSheetState extends State<ThinkingMatrixCellSheet> {
  static const _speechSeconds = 60;

  late final _controller = TextEditingController(text: widget.cell.keyword);
  late final _conclusionController = TextEditingController(
    text: widget.cell.conclusion,
  );
  late final _reasonController = TextEditingController(
    text: widget.cell.reason,
  );
  late final _exampleController = TextEditingController(
    text: widget.cell.example,
  );
  late var _speech60Done = widget.cell.speech60Done;
  bool _speechRunning = false;
  int _speechRemainingSeconds = _speechSeconds;
  Timer? _speechTimer;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // 60秒スピーチボタンはキーワードが空の間disabledにするため、入力の
    // たびに再評価できるよう購読する。
    _controller.addListener(_onKeywordChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onKeywordChanged);
    _controller.dispose();
    _conclusionController.dispose();
    _reasonController.dispose();
    _exampleController.dispose();
    _speechTimer?.cancel();
    super.dispose();
  }

  void _onKeywordChanged() => setState(() {});

  bool get _showPrepFields => widget.layer == ThinkingMatrixLayer.layer3;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final updated = switch (widget.layer) {
      ThinkingMatrixLayer.layer2 => await widget.service.upsertCellLayer2(
        setId: widget.set.id,
        themeId: widget.theme.id,
        columnId: widget.column.id,
        keyword: _controller.text,
      ),
      ThinkingMatrixLayer.layer3 => await widget.service.upsertCellLayer3(
        setId: widget.set.id,
        themeId: widget.theme.id,
        columnId: widget.column.id,
        keyword: _controller.text,
        conclusion: _conclusionController.text,
        reason: _reasonController.text,
        example: _exampleController.text,
        speech60Done: _speech60Done,
      ),
    };
    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  /// 「母語で60秒スピーチ」タップで即カウントダウン開始（確認は挟まない）。
  void _startSpeech60() {
    _speechTimer?.cancel();
    setState(() {
      _speechRunning = true;
      _speechRemainingSeconds = _speechSeconds;
    });
    _speechTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_speechRemainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _speechRemainingSeconds = 0;
          _speechRunning = false;
          _speech60Done = true;
        });
        return;
      }
      setState(() => _speechRemainingSeconds -= 1);
    });
  }

  /// カウント中に早めに終える「完了」ボタン用。
  void _completeSpeech60() {
    _speechTimer?.cancel();
    setState(() {
      _speechRunning = false;
      _speech60Done = true;
    });
  }

  /// チェックマークの長押しで「スピーチしていない」状態に戻す（やり直し用）。
  void _undoSpeech60() {
    setState(() => _speech60Done = false);
  }

  Widget _buildPrepField(String label, TextEditingController controller) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.tr(lang),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: palette.textOnCardSecondary,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          minLines: 1,
          maxLines: 3,
          style: TextStyle(color: palette.textOnCardPrimary, fontSize: 15),
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.subpageBackground,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpeech60Section() {
    final lang = appSettings.language;
    final palette = AppColors.current;
    if (_speechRunning) {
      return Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: palette.textOnCardSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            '$_speechRemainingSeconds${'秒'.tr(lang)}',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: palette.textOnCardPrimary,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: _completeSpeech60,
            child: Text('完了'.tr(lang)),
          ),
        ],
      );
    }
    final keywordEmpty = _controller.text.trim().isEmpty;
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: keywordEmpty ? null : _startSpeech60,
            icon: const Icon(Icons.mic_none_rounded, size: 18),
            label: Text('母語で60秒スピーチ'.tr(lang)),
          ),
        ),
        const SizedBox(width: 8),
        // チェックの有無でボタン幅が変わらないよう、無いときも同じ大きさの
        // 場所を確保しておく。チェックの長押しで「スピーチしていない」状態に
        // 戻せる（やり直し用）。
        SizedBox(
          width: 20,
          height: 20,
          child: _speech60Done
              ? GestureDetector(
                  onLongPress: _undoSpeech60,
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: kThinkingMatrixGoldColor,
                  ),
                )
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        // 見出し・キーワード欄・PREP欄・ボタンは、キーボード表示時に画面高を
        // 超えることがあるため、SingleChildScrollViewで包んでオーバーフロー
        // させず縦スクロールに逃がす。
        child: SingleChildScrollView(
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
                '${themeDisplayName(widget.set, widget.theme, lang)} × '
                '${widget.column.labelKey.tr(lang)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: palette.textOnCardPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 1,
                maxLines: 3,
                style: TextStyle(
                  color: palette.textOnCardPrimary,
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: '25マス_キーワード入力例'.tr(lang),
                  hintStyle: TextStyle(color: palette.textOnCardSecondary),
                  filled: true,
                  fillColor: palette.subpageBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              if (_showPrepFields) ...[
                const SizedBox(height: 16),
                _buildPrepField('結論', _conclusionController),
                const SizedBox(height: 10),
                _buildPrepField('理由', _reasonController),
                const SizedBox(height: 10),
                _buildPrepField('例示', _exampleController),
                const SizedBox(height: 16),
                _buildSpeech60Section(),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('キャンセル'.tr(lang)),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('マスを埋める'.tr(lang)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
