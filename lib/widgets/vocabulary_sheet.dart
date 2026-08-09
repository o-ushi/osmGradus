import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_strings.dart';
import '../main.dart' show appSettings, topicSpeechReader;
import '../models/vocabulary_entry.dart';
import '../models/vocabulary_level.dart';
import '../services/jlpt_vocab_bank_service.dart';
import '../services/vocabulary_service.dart';
import '../theme/app_colors.dart';
import 'level_checkbox_row.dart';

part 'vocabulary_sheet_deck.dart';
part 'vocabulary_sheet_manage.dart';
part 'vocabulary_sheet_form.dart';

/// 起動画面のアイコンから開く単語帳。めくれるフラッシュカードデッキで復習する。
class VocabularySheet extends StatefulWidget {
  const VocabularySheet({super.key, this.focusEntryId});

  /// 開いた直後に表示するエントリのID（例：レイヤーⅠの単語テストで
  /// 出題中の語）。nullまたは該当エントリが無ければ先頭から表示する。
  final String? focusEntryId;

  static bool _isShowing = false;

  static Future<void> show(BuildContext context, {String? focusEntryId}) async {
    if (_isShowing) return;
    _isShowing = true;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        barrierLabel: '単語帳',
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => VocabularySheet(focusEntryId: focusEntryId),
        transitionBuilder: (context, animation, _, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      );
    } finally {
      _isShowing = false;
    }
  }

  @override
  State<VocabularySheet> createState() => _VocabularySheetState();
}

class _VocabularySheetState extends State<VocabularySheet> {
  final _service = VocabularyService();
  final _pageController = PageController();
  final _wordController = TextEditingController();
  final _readingController = TextEditingController();
  final _exampleController = TextEditingController();
  final _translationController = TextEditingController();

  List<VocabularyEntry> _entries = [];
  List<int> _order = [];
  bool _loading = true;
  bool _showAddPanel = false;
  bool _showManage = false;
  String? _editingId;
  String _translationLang = 'vi';
  VocabularyLevel _level = VocabularyLevel.other;
  int _currentIndex = 0;

  /// レベルによる絞り込み。空＝絞り込みなし（全件表示）。
  Set<VocabularyLevel> _selectedLevels = {};

  /// [_selectedLevels]で絞り込んだ現在の表示対象（デッキ／一覧共通）。
  List<VocabularyEntry> get _visibleEntries => _selectedLevels.isEmpty
      ? _entries
      : _entries
            .where((entry) => _selectedLevels.contains(entry.level))
            .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userEntries = await _service.loadEntries();
    final hiddenBuiltinIds = await _service.loadHiddenBuiltinIds();
    if (!mounted) return;
    final entries = JlptVocabBankService.mergeWithDefaults(
      userEntries,
      includeDefaults: appSettings.includeDefaultVocabulary,
      hiddenBuiltinIds: hiddenBuiltinIds,
    );
    final visible = _selectedLevels.isEmpty
        ? entries
        : entries
              .where((entry) => _selectedLevels.contains(entry.level))
              .toList();
    final focusId = widget.focusEntryId;
    final focusIndex = focusId == null
        ? -1
        : visible.indexWhere((entry) => entry.id == focusId);
    setState(() {
      _entries = entries;
      _order = List<int>.generate(visible.length, (index) => index);
      _loading = false;
      if (focusIndex >= 0) _currentIndex = focusIndex;
    });
    // 読み込み直後、指定エントリ（[widget.focusEntryId]）のカードへ直接
    // 移動する（レイヤーⅠの単語テストで出題中の語を単語帳から開いた
    // ときに、その語をすぐ見返せるようにするため）。
    if (focusIndex > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(focusIndex);
      });
    }
  }

  void _resetPanelFields() {
    _wordController.clear();
    _readingController.clear();
    _exampleController.clear();
    _translationController.clear();
    _translationLang = 'vi';
    _level = VocabularyLevel.other;
  }

  Future<void> _submitPanel() async {
    final word = _wordController.text.trim();
    final translation = _translationController.text.trim();
    if (word.isEmpty || translation.isEmpty) return;
    final reading = _readingController.text.trim();
    final exampleSentence = _exampleController.text.trim();
    final editingId = _editingId;

    if (editingId != null) {
      if (JlptVocabBankService.isBuiltinId(editingId)) {
        await _service.replaceBuiltinEntry(
          editingId,
          word: word,
          reading: reading,
          exampleSentence: exampleSentence,
          translation: translation,
          translationLang: _translationLang,
          level: _level,
        );
      } else {
        await _service.updateEntry(
          editingId,
          word: word,
          reading: reading,
          exampleSentence: exampleSentence,
          translation: translation,
          translationLang: _translationLang,
          level: _level,
        );
      }
    } else {
      await _service.addEntry(
        word,
        translation,
        reading: reading,
        exampleSentence: exampleSentence,
        translationLang: _translationLang,
        level: _level,
      );
    }

    _resetPanelFields();
    if (!mounted) return;

    HapticFeedback.mediumImpact();
    final wasManaging = _showManage;
    setState(() {
      _showAddPanel = false;
      _editingId = null;
    });
    await _load();
    if (!mounted || editingId != null || wasManaging) return;
    final focusIndex = _entries.indexWhere((entry) => entry.word == word);
    if (focusIndex < 0) return;
    setState(() => _currentIndex = focusIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.animateToPage(
        focusIndex,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _toggleAddPanel() {
    if (_showAddPanel) {
      _resetPanelFields();
      setState(() {
        _showAddPanel = false;
        _editingId = null;
      });
    } else {
      setState(() => _showAddPanel = true);
    }
  }

  void _startEdit(VocabularyEntry entry) {
    _wordController.text = entry.word;
    _readingController.text = entry.reading;
    _exampleController.text = entry.exampleSentence;
    _translationController.text = entry.translation;
    setState(() {
      _editingId = entry.id;
      _translationLang = entry.translationLang;
      _level = entry.level;
      _showAddPanel = true;
    });
  }

  Future<void> _deleteEntry(String id) async {
    if (JlptVocabBankService.isBuiltinId(id)) {
      await _service.hideBuiltinEntry(id);
    } else {
      await _service.deleteEntry(id);
    }
    if (!mounted) return;

    final removedIndex = _visibleEntries.indexWhere((entry) => entry.id == id);
    final wasEditing = _editingId == id;
    if (wasEditing) {
      _editingId = null;
      _showAddPanel = false;
      _resetPanelFields();
    }
    await _load();
    if (!mounted) return;
    final visibleCount = _visibleEntries.length;
    if (_currentIndex >= visibleCount) {
      setState(() {
        _currentIndex = math.max(0, visibleCount - 1);
      });
    } else if (removedIndex != -1 && removedIndex <= _currentIndex) {
      setState(() {
        _currentIndex = math.max(0, _currentIndex - 1);
      });
    }

    if (_visibleEntries.isEmpty || _showManage) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(_currentIndex);
    });
  }

  /// フラッシュカードの長押しで編集パネルを開く。
  void _handleEditRequest(VocabularyEntry entry) => _startEdit(entry);

  Future<void> _handleDeleteRequest(String id) async {
    final lang = appSettings.language;
    final confirmed = await _confirmDelete(context, lang);
    if (confirmed) await _deleteEntry(id);
  }

  /// レベルで絞り込んで一覧を表示している間も、表示中の並びだけを
  /// 並び替えられるようにする。絞り込みで隠れている語は元の位置を保ったまま、
  /// 表示中の語だけを選ばれた新しい順序に差し替える。
  Future<void> _reorder(int oldIndex, int newIndex) async {
    final visible = _visibleEntries;
    final movedEntry = visible[oldIndex];
    if (JlptVocabBankService.isBuiltinId(movedEntry.id)) return;

    final reorderedVisible = List<VocabularyEntry>.from(visible)
      ..removeAt(oldIndex)
      ..insert(newIndex, movedEntry);
    final newVisibleIds = [for (final entry in reorderedVisible) entry.id];
    final visibleIds = {for (final entry in visible) entry.id};

    final fullList = List<VocabularyEntry>.from(_entries);
    var cursor = 0;
    for (var i = 0; i < fullList.length; i++) {
      if (!visibleIds.contains(fullList[i].id)) continue;
      final targetId = newVisibleIds[cursor++];
      fullList[i] = _entries.firstWhere((entry) => entry.id == targetId);
    }

    HapticFeedback.selectionClick();
    final userIds = [
      for (final entry in fullList)
        if (!JlptVocabBankService.isBuiltinId(entry.id)) entry.id,
    ];
    await _service.reorderEntries(userIds);
    await _load();
  }

  void _speakEntry(VocabularyEntry entry) {
    final text = entry.reading.isNotEmpty ? entry.reading : entry.word;
    if (text.trim().isEmpty) return;
    HapticFeedback.selectionClick();
    topicSpeechReader.speak(text: text);
  }

  void _shuffleDeck() {
    final visibleCount = _visibleEntries.length;
    if (visibleCount < 2) return;
    HapticFeedback.selectionClick();
    setState(() {
      _order = List<int>.generate(visibleCount, (index) => index)..shuffle();
      _currentIndex = 0;
    });
    _pageController.jumpToPage(0);
  }

  void _toggleManage() {
    setState(() {
      _showManage = !_showManage;
      _showAddPanel = false;
      _editingId = null;
    });
    _resetPanelFields();
  }

  void _onFilterChanged(Set<VocabularyLevel> levels) {
    setState(() {
      _selectedLevels = levels;
      _order = List<int>.generate(_visibleEntries.length, (index) => index);
      _currentIndex = 0;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _wordController.dispose();
    _readingController.dispose();
    _exampleController.dispose();
    _translationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = appSettings.language;
    final palette = AppColors.current;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final visibleEntries = _visibleEntries;
    final bottomBar = _DeckBottomBar(
      lang: lang,
      currentIndex: _currentIndex,
      total: visibleEntries.length,
      showProgress: !_showManage,
      showAddPanel: _showAddPanel,
      isEditing: _editingId != null,
      wordController: _wordController,
      readingController: _readingController,
      exampleController: _exampleController,
      translationController: _translationController,
      translationLang: _translationLang,
      onLangChange: (value) => setState(() => _translationLang = value),
      level: _level,
      onLevelChange: (value) => setState(() => _level = value),
      onToggleAddPanel: _toggleAddPanel,
      onSubmit: _submitPanel,
    );

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              palette.scene,
              Color.lerp(palette.scene, Colors.black, 0.28)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            const _DeckBackdrop(),
            SafeArea(
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Column(
                  children: [
                    _DeckTopBar(
                      lang: lang,
                      entryCount: visibleEntries.length,
                      canShuffle: visibleEntries.length > 1,
                      isManaging: _showManage,
                      selectedLevels: _selectedLevels,
                      onFilterChanged: _onFilterChanged,
                      onClose: () => Navigator.of(context).pop(),
                      onShuffle: _shuffleDeck,
                      onToggleManage: _toggleManage,
                    ),
                    if (_showAddPanel)
                      Expanded(child: SingleChildScrollView(child: bottomBar))
                    else ...[
                      Expanded(
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              )
                            : _entries.isEmpty
                            ? _EmptyDeck(
                                lang: lang,
                                onAddTap: () =>
                                    setState(() => _showAddPanel = true),
                              )
                            : visibleEntries.isEmpty
                            ? _NoFilterMatches(
                                lang: lang,
                                onClearFilter: () => _onFilterChanged({}),
                              )
                            : _showManage
                            ? _ManageList(
                                lang: lang,
                                entries: visibleEntries,
                                onReorder: _reorder,
                                onEdit: _startEdit,
                                onDelete: (entry) =>
                                    _handleDeleteRequest(entry.id),
                              )
                            : _DeckView(
                                lang: lang,
                                entries: visibleEntries,
                                order: _order,
                                pageController: _pageController,
                                currentIndex: _currentIndex,
                                onPageChanged: (index) =>
                                    setState(() => _currentIndex = index),
                                onDelete: _handleDeleteRequest,
                                onSpeak: _speakEntry,
                                onEdit: _handleEditRequest,
                              ),
                      ),
                      bottomBar,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context, String lang) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('削除しますか？'.tr(lang)),
      content: Text('一度削除すると元に戻せません。'.tr(lang)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('キャンセル'.tr(lang)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('削除'.tr(lang), style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}
