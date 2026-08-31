import 'dart:math';

import 'pronunciation_exercise.dart'
    show PronunciationCategory, PronunciationCategoryLabel;
import 'question_prompt_pronunciation_sentence.dart';
import 'question_prompt_source.dart';
import 'question_prompt_vocab_word.dart';
import 'topic_category.dart';

final _idRandom = Random();

/// 「お題」を発展させた、レイヤーⅠ〜Ⅴを横断する問題文1件。
///
/// [category]は[TopicCategory.random]以外を取る（[TopicCategory.random]は問題文
/// 自体のカテゴリにはならない抽選専用カテゴリのため）。[TopicCategory.daily]/
/// [TopicCategory.business]は25マス専用のレガシー値で、問題文の新規生成では
/// 使わない方針（`docs/prompts/question-prompt-tabs.md`）だが、Step 1時点では
/// 既存の[QuestionPromptService]・[TopicService]がまだこの2値を使い続けるため、
/// データ型としては引き続き受け付ける。[TopicCategory.general]（同ドキュメント
/// Step 1で追加）が「シチュエーション以外」の新しい正式カテゴリで、[tags]と
/// 組み合わせて使う。
///
/// レイヤーⅣ・Ⅴの採点結果（[jsstScore]・[hitScore]・[prepScore]・
/// [pronunciationScores]）は、Step 1時点では[ScoringResultStorage]・
/// [PronunciationCheckStorage]と統合せず、この問題文エンティティ側に直接
/// 保持する簡易フィールドとして持つ。将来的にそれぞれの保存結果へ
/// `questionPromptId`のような参照を持たせて突合する場合に備え、[id]は
/// 生成時点で確定し、以後変わらない安定値として扱う（[SavedPronunciationCheck]の
/// `longArticleId`と同じ「参照先が消えてもIDは残す」方針を踏襲する想定）。
class QuestionPrompt {
  QuestionPrompt({
    required this.id,
    required this.source,
    required this.category,
    required this.body,
    this.situationCondition,
    this.tags = const [],
    this.contentEdited = false,
    this.understood = false,
    this.vocabTestWords = const [],
    this.vocabTestCorrectCount,
    this.vocabTestQuestionCount,
    this.pronunciationSentences = const [],
    this.registeredWordIds = const [],
    this.summary = '',
    this.sampleAnswer = '',
    this.conclusion = '',
    this.reason = '',
    this.example = '',
    this.jsstScore,
    this.hitScore,
    this.prepScore,
    this.pronunciationScores = const {},
    this.advice = '',
    required this.createdAt,
  }) : assert(
         category != TopicCategory.random,
         'QuestionPrompt.category はrandomを取らない（問題文自体のカテゴリにはならない抽選専用カテゴリのため）',
       ),
       assert(
         category != TopicCategory.situational || tags.isEmpty,
         'QuestionPrompt.tags はsituationalのとき常に空（タブ分類は[TopicCategory.general]専用）',
       );

  final String id;
  final QuestionPromptSource source;
  final TopicCategory category;

  /// 問題文本文。[category]が[TopicCategory.situational]の場合は状況説明。
  final String body;

  /// [category]が[TopicCategory.situational]のときのみ使う条件文。
  /// それ以外のカテゴリ、または条件を持たない旧データではnull。
  final String? situationCondition;

  /// 問題文タブ分類（`question-prompt-tabs.md`）。[TopicCategory.general]の
  /// 問題文にのみ複数付けられる（[QuestionPromptTabRegistry]の組み込み6タブ＋
  /// ユーザー独自タブ）。[category]が[TopicCategory.situational]のときは
  /// 常に空（コンストラクタのassertで強制、[fromJson]でも捨てる）。
  final List<String> tags;

  /// 長押し編集画面（`question-prompt-tabs.md` Step 5）でbody/situationCondition/
  /// category/tagsのいずれかをユーザーが変更済みか。[source]が
  /// [QuestionPromptSource.builtIn]の行で、[QuestionPromptService.loadAll]が
  /// バンク側の値へ上書きし直さないようにするためのフラグ（Step 2で追加した
  /// 組み込み行のcategory/tags追随ロジックが、ユーザー編集を巻き戻さないよう
  /// ガードする）。組み込み以外の行では意味を持たないが、区別せず立てる。
  final bool contentEdited;

  /// レイヤーⅠ旧「理解した」トグルの値。Step 1時点で[isLayer1Done]の判定からは
  /// 外れており、新規UIからは書かない（Step 2でボタン自体を廃止）。JSONの
  /// 読み書きは後方互換のため当面残す。
  final bool understood;

  /// レイヤーⅠ「問題作成」（Step 2）でChrome AIが抽出した単語のスナップショット。
  /// Step 3の語彙テスト出題・不正解時の単語帳登録・総評での再表示に、追加の
  /// AI往復なしで使い回す。未抽出は空配列。
  final List<QuestionPromptVocabWord> vocabTestWords;

  /// レイヤーⅠ語彙テストの正解数。未実施はnull。
  final int? vocabTestCorrectCount;

  /// レイヤーⅠ語彙テストの出題数（[vocabTestWords.length]と対応する想定だが、
  /// 実施後に[vocabTestWords]の内容が変わっても正解率の分母を保つため独立して持つ）。
  /// 未実施はnull。
  final int? vocabTestQuestionCount;

  /// レイヤーⅤ「問題作成」（Step 6）でChrome AIが問題文に関連して作成した
  /// 発音練習用の短文のスナップショット（最大10件、5カテゴリをおおむね
  /// 均等に含む）。「ランダム」（[Layer5Screen]）と同型のセッションUIへ、
  /// 既存プールの代わりにこの問題文専用の出題プールとして渡す。未生成は空配列。
  final List<QuestionPromptPronunciationSentence> pronunciationSentences;

  /// この問題文から登録した単語帳エントリのID（[VocabularyEntry.id]）一覧。
  /// 単語の本体・訳語は[VocabularyService]側の唯一のストアが持ち、ここでは
  /// 「どの単語をこの問題文から登録したか」の参照のみを持つ
  /// （長文読解側の`VocabularyService`と重複実装しないため）。
  final List<String> registeredWordIds;

  final String summary;

  /// レイヤーⅡ「解答例」（Chrome AIが作成した45秒模範解答）のスナップショット。
  /// [summary]（学習者自身の答えのメモ）とは役割が異なり、進捗判定
  /// （[isLayer2Done]）には含めない。未取得は空文字。
  final String sampleAnswer;

  final String conclusion;
  final String reason;
  final String example;

  /// JSST参考レベル。未実施はnull。
  final int? jsstScore;

  /// 的中度（1〜5）。未実施はnull。
  final int? hitScore;

  /// PREP評価（1〜5）。未実施はnull。
  final int? prepScore;

  /// 「つ」「ざ・ず・ぞ」「ラ行」「長音」「促音」の発音評点（1〜5）。
  /// 未実施のカテゴリはキー自体を持たない（＝null相当）。
  final Map<PronunciationCategory, int> pronunciationScores;

  /// Chrome AIからのアドバイス（総評画面用、Step 7）。
  final String advice;

  final DateTime createdAt;

  /// 新規問題文用のID・作成日時を割り当てて生成する
  /// （[QuestionPromptService]の取り込み・組み込みバンク以外の追加で使う）。
  factory QuestionPrompt.create({
    required TopicCategory category,
    required String body,
    required QuestionPromptSource source,
    String? situationCondition,
    List<String> tags = const [],
  }) => QuestionPrompt(
    id: 'qp_${DateTime.now().microsecondsSinceEpoch}_${_idRandom.nextInt(1 << 32)}',
    source: source,
    category: category,
    body: body,
    situationCondition: situationCondition,
    tags: tags,
    createdAt: DateTime.now(),
  );

  QuestionPrompt copyWith({
    TopicCategory? category,
    String? body,
    String? situationCondition,
    bool clearSituationCondition = false,
    List<String>? tags,
    bool? contentEdited,
    bool? understood,
    List<QuestionPromptVocabWord>? vocabTestWords,
    int? vocabTestCorrectCount,
    bool clearVocabTestCorrectCount = false,
    int? vocabTestQuestionCount,
    bool clearVocabTestQuestionCount = false,
    List<QuestionPromptPronunciationSentence>? pronunciationSentences,
    List<String>? registeredWordIds,
    String? summary,
    String? sampleAnswer,
    String? conclusion,
    String? reason,
    String? example,
    int? jsstScore,
    bool clearJsstScore = false,
    int? hitScore,
    bool clearHitScore = false,
    int? prepScore,
    bool clearPrepScore = false,
    Map<PronunciationCategory, int>? pronunciationScores,
    String? advice,
  }) => QuestionPrompt(
    id: id,
    source: source,
    category: category ?? this.category,
    body: body ?? this.body,
    situationCondition: clearSituationCondition
        ? null
        : (situationCondition ?? this.situationCondition),
    tags: tags ?? this.tags,
    contentEdited: contentEdited ?? this.contentEdited,
    understood: understood ?? this.understood,
    vocabTestWords: vocabTestWords ?? this.vocabTestWords,
    vocabTestCorrectCount: clearVocabTestCorrectCount
        ? null
        : (vocabTestCorrectCount ?? this.vocabTestCorrectCount),
    vocabTestQuestionCount: clearVocabTestQuestionCount
        ? null
        : (vocabTestQuestionCount ?? this.vocabTestQuestionCount),
    pronunciationSentences:
        pronunciationSentences ?? this.pronunciationSentences,
    registeredWordIds: registeredWordIds ?? this.registeredWordIds,
    summary: summary ?? this.summary,
    sampleAnswer: sampleAnswer ?? this.sampleAnswer,
    conclusion: conclusion ?? this.conclusion,
    reason: reason ?? this.reason,
    example: example ?? this.example,
    jsstScore: clearJsstScore ? null : (jsstScore ?? this.jsstScore),
    hitScore: clearHitScore ? null : (hitScore ?? this.hitScore),
    prepScore: clearPrepScore ? null : (prepScore ?? this.prepScore),
    pronunciationScores: pronunciationScores ?? this.pronunciationScores,
    advice: advice ?? this.advice,
    createdAt: createdAt,
  );

  /// レイヤーⅢ「PREP」（結論・理由・具体例）がすべて記入済みか。
  bool get isPrepFilled =>
      conclusion.isNotEmpty && reason.isNotEmpty && example.isNotEmpty;

  /// レイヤーⅤの発音評点をいずれか1つでも記録済みか。
  bool get hasPronunciationScore => pronunciationScores.isNotEmpty;

  /// レイヤーⅠ語彙テストの正解率（0.0〜1.0）。未実施はnull。
  double? get vocabTestAccuracy {
    final total = vocabTestQuestionCount;
    final correct = vocabTestCorrectCount;
    if (total == null || correct == null || total == 0) return null;
    return correct / total;
  }

  /// レイヤーⅠ「語彙テスト」実施済みか（起動画面の横断一覧用）。
  /// 出題数・正解数の両方が記録済みで、出題数が1件以上のとき実施済みとする。
  /// 旧データで[understood]がtrueでも、語彙テストを実施していなければ
  /// 実施済み扱いにしない（語彙テスト実績が無い＝未実施という方針）。
  bool get isLayer1Done =>
      vocabTestQuestionCount != null &&
      vocabTestCorrectCount != null &&
      vocabTestQuestionCount! > 0;

  /// レイヤーⅡ「要約」記入済みか。
  bool get isLayer2Done => summary.isNotEmpty;

  /// レイヤーⅢ「PREP」記入済みか（[isPrepFilled]と同じ）。
  bool get isLayer3Done => isPrepFilled;

  /// レイヤーⅣ「JSST」評点あり。
  bool get isLayer4Done => jsstScore != null;

  /// レイヤーⅤ「発音」評点あり。
  bool get isLayer5Done => hasPronunciationScore;

  /// Ⅰ〜Ⅴのマイルストーンがすべて埋まっているか。
  bool get isAllLayersDone =>
      isLayer1Done &&
      isLayer2Done &&
      isLayer3Done &&
      isLayer4Done &&
      isLayer5Done;

  /// Ⅰ〜Ⅴのいずれかが実施済みか。
  bool get hasAnyLayerDone =>
      isLayer1Done ||
      isLayer2Done ||
      isLayer3Done ||
      isLayer4Done ||
      isLayer5Done;

  /// 起動画面の横断一覧で「総評」列に ⭕️ を出すか。
  /// アドバイス取得済み、またはⅠ〜Ⅴのいずれか実施済みのとき true。
  /// 未実施は「ー」。⭕️ タップで総評画面へ進む。
  bool get showsOverviewSummaryMarker => advice.isNotEmpty || hasAnyLayerDone;

  /// バックアップ対象にすべき利用者データを持つか。[source]が組み込み
  /// ([QuestionPromptSource.builtin])で、かつ理解・要約・PREP・スコア・
  /// 単語登録参照のいずれも記録されていない未使用の問題文は、
  /// [TopicBank]が既にアプリ側に静的に持つ内容と重複するため対象外とする
  /// （[TopicJsonTransfer]が組み込みのお題バンクをバックアップ対象から
  /// 除外しているのと同じ考え方）。
  bool get hasUserData =>
      source != QuestionPromptSource.builtIn ||
      understood ||
      vocabTestWords.isNotEmpty ||
      vocabTestCorrectCount != null ||
      pronunciationSentences.isNotEmpty ||
      summary.isNotEmpty ||
      sampleAnswer.isNotEmpty ||
      conclusion.isNotEmpty ||
      reason.isNotEmpty ||
      example.isNotEmpty ||
      registeredWordIds.isNotEmpty ||
      jsstScore != null ||
      hitScore != null ||
      prepScore != null ||
      hasPronunciationScore ||
      advice.isNotEmpty;

  factory QuestionPrompt.fromJson(Map<String, dynamic> json) {
    final category = _categoryFromJson(json['category'] ?? json['field']);
    return QuestionPrompt(
      id: json['id'] as String,
      source: QuestionPromptSourceLabel.fromStorageKey(
        json['source'] as String?,
      ),
      category: category,
      body: json['body'] as String? ?? '',
      situationCondition: json['situationCondition'] as String?,
      tags: _tagsFromJson(json['tags'], category),
      contentEdited: json['contentEdited'] as bool? ?? false,
      understood: json['understood'] as bool? ?? false,
      vocabTestWords: _vocabTestWordsFromJson(json['vocabTestWords']),
      vocabTestCorrectCount: (json['vocabTestCorrectCount'] as num?)?.toInt(),
      vocabTestQuestionCount: (json['vocabTestQuestionCount'] as num?)?.toInt(),
      pronunciationSentences: _pronunciationSentencesFromJson(
        json['pronunciationSentences'],
      ),
      registeredWordIds:
          (json['registeredWordIds'] as List<dynamic>?)?.cast<String>() ??
          const [],
      summary: json['summary'] as String? ?? '',
      sampleAnswer: json['sampleAnswer'] as String? ?? '',
      conclusion: json['conclusion'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      example: json['example'] as String? ?? '',
      jsstScore: (json['jsstScore'] as num?)?.toInt(),
      hitScore: (json['hitScore'] as num?)?.toInt(),
      prepScore: (json['prepScore'] as num?)?.toInt(),
      pronunciationScores: _pronunciationScoresFromJson(
        json['pronunciationScores'],
      ),
      advice: json['advice'] as String? ?? '',
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.parse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.storageKey,
    'category': category.storageKey,
    'body': body,
    if (situationCondition != null) 'situationCondition': situationCondition,
    if (category != TopicCategory.situational && tags.isNotEmpty) 'tags': tags,
    if (contentEdited) 'contentEdited': contentEdited,
    'understood': understood,
    if (vocabTestWords.isNotEmpty)
      'vocabTestWords': vocabTestWords.map((w) => w.toJson()).toList(),
    if (vocabTestCorrectCount != null)
      'vocabTestCorrectCount': vocabTestCorrectCount,
    if (vocabTestQuestionCount != null)
      'vocabTestQuestionCount': vocabTestQuestionCount,
    if (pronunciationSentences.isNotEmpty)
      'pronunciationSentences': pronunciationSentences
          .map((s) => s.toJson())
          .toList(),
    if (registeredWordIds.isNotEmpty) 'registeredWordIds': registeredWordIds,
    if (summary.isNotEmpty) 'summary': summary,
    if (sampleAnswer.isNotEmpty) 'sampleAnswer': sampleAnswer,
    if (conclusion.isNotEmpty) 'conclusion': conclusion,
    if (reason.isNotEmpty) 'reason': reason,
    if (example.isNotEmpty) 'example': example,
    if (jsstScore != null) 'jsstScore': jsstScore,
    if (hitScore != null) 'hitScore': hitScore,
    if (prepScore != null) 'prepScore': prepScore,
    if (pronunciationScores.isNotEmpty)
      'pronunciationScores': {
        for (final entry in pronunciationScores.entries)
          entry.key.storageKey: entry.value,
      },
    if (advice.isNotEmpty) 'advice': advice,
    'createdAt': createdAt.toIso8601String(),
  };

  /// 旧`"category": "日常"`/`"ビジネス"`（新旧storageKeyどちらも）は
  /// [normalizeToGeneral]で`general`に正規化する（Step 6）。この正規化は
  /// Step 1〜5の間は[QuestionPromptService]側の書き込み経路（組み込み・
  /// recordImport・移行スキャン）がすべて`general`だけを書くよう揃うまで
  /// 保留していた（ここだけ先に正規化すると、揃う前は読み直すたびに
  /// category が daily/business↔general でフラつき、`topics.imported.*`の
  /// 重複除外判定が壊れて再取り込みが起きていた）。今はどの書き込み経路も
  /// generalのみを書くため、読み込み側のこの正規化と矛盾しない。
  static TopicCategory _categoryFromJson(Object? raw) {
    if (raw is! String) return TopicCategory.general;
    try {
      final category = normalizeToGeneral(
        TopicCategoryLabel.fromStorageKey(raw),
      );
      return category == TopicCategory.random
          ? TopicCategory.general
          : category;
    } on ArgumentError {
      return TopicCategory.general;
    }
  }

  /// situationalは常に空（不正データ・旧仕様データ問わず読んだtagsを捨てる）。
  /// それ以外は文字列のリストとして読み、欠落・不正な形は空配列。
  static List<String> _tagsFromJson(Object? raw, TopicCategory category) {
    if (category == TopicCategory.situational) return const [];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  static List<QuestionPromptVocabWord> _vocabTestWordsFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <QuestionPromptVocabWord>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          QuestionPromptVocabWord.fromJson(Map<String, dynamic>.from(item)),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  static List<QuestionPromptPronunciationSentence>
  _pronunciationSentencesFromJson(Object? raw) {
    if (raw is! List) return const [];
    final result = <QuestionPromptPronunciationSentence>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          QuestionPromptPronunciationSentence.fromJson(
            Map<String, dynamic>.from(item),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  static Map<PronunciationCategory, int> _pronunciationScoresFromJson(
    Object? raw,
  ) {
    if (raw is! Map) return const {};
    final result = <PronunciationCategory, int>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! num) continue;
      try {
        result[PronunciationCategoryLabel.fromStorageKey(key)] = value.toInt();
      } catch (_) {
        continue;
      }
    }
    return result;
  }
}
