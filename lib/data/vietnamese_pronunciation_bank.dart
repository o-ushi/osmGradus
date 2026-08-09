import '../models/pronunciation_exercise.dart';

/// ベトナム語母語話者が苦手としやすい5カテゴリ（つ／ざ行／ラ行／長音／促音）に
/// 特化した組み込み発音課題（各5文、計25文）。
///
/// 各課題文は原則として1つの対象カテゴリの発音に焦点を絞る。[PronunciationExercise.targetExpressions]
/// は必ず[PronunciationExercise.reading]の部分文字列になっており、対象部分が
/// どこかを機械的にも特定できるようにしている。
abstract final class VietnamesePronunciationBank {
  static const List<PronunciationExercise> all = [
    ..._tsu,
    ..._zRow,
    ..._rRow,
    ..._longVowel,
    ..._sokuon,
  ];

  static List<PronunciationExercise> byCategory(
    PronunciationCategory category,
  ) => all.where((exercise) => exercise.category == category).toList();

  static const _tsu = [
    PronunciationExercise(
      id: 'pron_tsu_01',
      category: PronunciationCategory.tsu,
      sentence: '机の上にペンがあります。',
      reading: 'つくえのうえにぺんがあります。',
      targetExpressions: ['つくえ'],
      vietnameseHint:
          'Âm「つ」là âm tắc xát (đọc gần giống "t" nối liền với "s"), '
          'không phải "su" hay "chu" như người Việt hay đọc nhầm.',
      evaluationPoint: '「つ」を「す」や「ちゅ」にせず、破擦音として発音できているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_tsu_02',
      category: PronunciationCategory.tsu,
      sentence: '冷たい飲み物をください。',
      reading: 'つめたいのみものをください。',
      targetExpressions: ['つめたい'],
      vietnameseHint:
          'Âm「つ」ở đầu từ cần bật hơi rõ ràng, tránh đọc yếu đi thành "すめたい"。',
      evaluationPoint: '語頭の「つ」が弱くならず明確に発音できているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_tsu_03',
      category: PronunciationCategory.tsu,
      sentence: '次に会いましょう。',
      reading: 'つぎにあいましょう。',
      targetExpressions: ['つぎ'],
      vietnameseHint:
          '「つぎ」の「つ」は舌先を上の歯茎につけてから息を出す音。"すぎ"にならないように注意する。',
      evaluationPoint: '「つ」の子音部分がはっきり聞こえるか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_tsu_04',
      category: PronunciationCategory.tsu,
      sentence: '強い風が吹いています。',
      reading: 'つよいかぜがふいています。',
      targetExpressions: ['つよい'],
      vietnameseHint: '文頭の「つよい」で「つ」が"とよい"や"すよい"のように崩れていないか確認する。',
      evaluationPoint: '文頭の「つ」が別の音に置き換わっていないか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_tsu_05',
      category: PronunciationCategory.tsu,
      sentence: '彼はいつも元気です。',
      reading: 'かれはいつもげんきです。',
      targetExpressions: ['いつも'],
      vietnameseHint: '語中の「つ」も語頭と同じ強さで発音する。前後の母音に引っ張られて弱くならないようにする。',
      evaluationPoint: '語中の「つ」が前後の音に埋もれず発音できているか',
      source: PronunciationExerciseSource.builtIn,
    ),
  ];

  static const _zRow = [
    PronunciationExercise(
      id: 'pron_zRow_01',
      category: PronunciationCategory.zRow,
      sentence: '座布団に座ります。',
      reading: 'ざぶとんにすわります。',
      targetExpressions: ['ざぶとん'],
      vietnameseHint:
          '「ざ」は喉を震わせる有声音。無声音の「さ」にならないよう、のどの振動を意識する。',
      evaluationPoint: '「ざ」が有声音になっているか(「さ」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_zRow_02',
      category: PronunciationCategory.zRow,
      sentence: 'この水はきれいです。',
      reading: 'このみずはきれいです。',
      targetExpressions: ['みず'],
      vietnameseHint: '「ず」も有声音。「す」との違いはのどの震え。単語の意味が変わるので特に注意する。',
      evaluationPoint: '「ず」が有声音になっているか(「す」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_zRow_03',
      category: PronunciationCategory.zRow,
      sentence: '涼しい風が吹きます。',
      reading: 'すずしいかぜがふきます。',
      targetExpressions: ['すずしい'],
      vietnameseHint: '「すずしい」の中の「す」と「ず」の有声・無声の対比をはっきり出す。',
      evaluationPoint: '無声音「す」と有声音「ず」の対比が明確か',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_zRow_04',
      category: PronunciationCategory.zRow,
      sentence: '道に溝があります。',
      reading: 'みちにみぞがあります。',
      targetExpressions: ['みぞ'],
      vietnameseHint: '「ぞ」は「そ」の有声版。のどを震わせないと「みそ」(味噌)に聞こえてしまう。',
      evaluationPoint: '「ぞ」が有声音になっているか(「そ」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_zRow_05',
      category: PronunciationCategory.zRow,
      sentence: '税金を払います。',
      reading: 'ぜいきんをはらいます。',
      targetExpressions: ['ぜいきん'],
      vietnameseHint: '「ぜ」も有声音。文頭でのどの震えが弱くならないように意識する。',
      evaluationPoint: '文頭の「ぜ」が有声音として発音できているか',
      source: PronunciationExerciseSource.builtIn,
    ),
  ];

  static const _rRow = [
    PronunciationExercise(
      id: 'pron_rRow_01',
      category: PronunciationCategory.rRow,
      sentence: 'りんごを買いました。',
      reading: 'りんごをかいました。',
      targetExpressions: ['りんご'],
      vietnameseHint:
          '日本語のラ行は舌を巻く"r"でも英語の"l"でもなく、舌先で上あごを軽く一回はじく音。',
      evaluationPoint: '「り」が巻き舌の"r"や"l"になっていないか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_rRow_02',
      category: PronunciationCategory.rRow,
      sentence: '留守番をお願いします。',
      reading: 'るすばんをおねがいします。',
      targetExpressions: ['るすばん'],
      vietnameseHint: '「る」は舌先を一瞬だけ上あごにはじく軽い音。強く巻きすぎない。',
      evaluationPoint: '「る」が短くはじく音になっているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_rRow_03',
      category: PronunciationCategory.rRow,
      sentence: 'レモンを切ります。',
      reading: 'れもんをきります。',
      targetExpressions: ['れもん'],
      vietnameseHint: '「れ」も同じく軽くはじく音。ベトナム語の巻き舌のrと混同しないように。',
      evaluationPoint: '「れ」が軽くはじく音になっているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_rRow_04',
      category: PronunciationCategory.rRow,
      sentence: '6月に旅行します。',
      reading: 'ろくがつにりょこうします。',
      targetExpressions: ['ろくがつ'],
      vietnameseHint: '文中に「ろ」と「りょ」の2つのラ行音がある。どちらも同じ軽いはじき音で発音する。',
      evaluationPoint: '複数のラ行音が一貫して軽いはじき音になっているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_rRow_05',
      category: PronunciationCategory.rRow,
      sentence: '来年から働きます。',
      reading: 'らいねんからはたらきます。',
      targetExpressions: ['らいねん'],
      vietnameseHint: '文頭の「ら」を強く巻きすぎず、軽くはじく音で発音する。',
      evaluationPoint: '文頭の「ら」が軽くはじく音になっているか',
      source: PronunciationExerciseSource.builtIn,
    ),
  ];

  static const _longVowel = [
    PronunciationExercise(
      id: 'pron_longVowel_01',
      category: PronunciationCategory.longVowel,
      sentence: 'おばあさんは元気です。',
      reading: 'おばあさんはげんきです。',
      targetExpressions: ['おばあさん'],
      vietnameseHint:
          'ベトナム語には長母音の区別がないため、「あ」を伸ばさないと「おばさん」(cô/dì)と'
          '意味が変わってしまう。',
      evaluationPoint: '「あ」を十分な長さで伸ばせているか(「おばさん」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_longVowel_02',
      category: PronunciationCategory.longVowel,
      sentence: 'おじいさんはここにいます。',
      reading: 'おじいさんはここにいます。',
      targetExpressions: ['おじいさん'],
      vietnameseHint: '「い」を伸ばさないと「おじさん」(chú/bác)になり、意味が変わってしまう。',
      evaluationPoint: '「い」を十分な長さで伸ばせているか(「おじさん」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_longVowel_03',
      category: PronunciationCategory.longVowel,
      sentence: 'スーパーで買い物をします。',
      reading: 'すーぱーでかいものをします。',
      targetExpressions: ['すーぱー'],
      vietnameseHint: '長音記号「ー」は前の母音をもう1拍分伸ばす印。省略すると通じにくくなる。',
      evaluationPoint: '長音記号「ー」の部分を1拍分伸ばせているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_longVowel_04',
      category: PronunciationCategory.longVowel,
      sentence: '空気がきれいです。',
      reading: 'くうきがきれいです。',
      targetExpressions: ['くうき'],
      vietnameseHint: '「う」を伸ばさず短く「くき」と言ってしまうと別の単語に聞こえる。',
      evaluationPoint: '「う」を十分な長さで伸ばせているか(「くき」にならないか)',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_longVowel_05',
      category: PronunciationCategory.longVowel,
      sentence: '氷が溶けました。',
      reading: 'こおりがとけました。',
      targetExpressions: ['こおり'],
      vietnameseHint:
          '「お」を伸ばさないと短くなりすぎる。「こおり」(氷)は「お」を2拍分伸ばす代表的な単語。',
      evaluationPoint: '「お」を十分な長さで伸ばせているか',
      source: PronunciationExerciseSource.builtIn,
    ),
  ];

  static const _sokuon = [
    PronunciationExercise(
      id: 'pron_sokuon_01',
      category: PronunciationCategory.sokuon,
      sentence: '切手を買いました。',
      reading: 'きってをかいました。',
      targetExpressions: ['きって'],
      vietnameseHint:
          'ベトナム語には子音を止める促音「っ」がないため、省略しがち。「っ」の前で'
          '一瞬息を止めてから次の音を出す。',
      evaluationPoint: '「っ」の前で一拍分しっかり止めているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_sokuon_02',
      category: PronunciationCategory.sokuon,
      sentence: '結婚しました。',
      reading: 'けっこんしました。',
      targetExpressions: ['けっこん'],
      vietnameseHint: '「っ」を飛ばして「けこん」にならないよう、詰まる感覚を意識する。',
      evaluationPoint: '「っ」の分の長さ(1拍)が保たれているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_sokuon_03',
      category: PronunciationCategory.sokuon,
      sentence: '切符を見せてください。',
      reading: 'きっぷをみせてください。',
      targetExpressions: ['きっぷ'],
      vietnameseHint: '「っ」を省略すると「きぷ」のように聞こえ、意味が通じにくくなる。',
      evaluationPoint: '「っ」の前でしっかり間が取れているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_sokuon_04',
      category: PronunciationCategory.sokuon,
      sentence: '失敗しないでください。',
      reading: 'しっぱいしないでください。',
      targetExpressions: ['しっぱい'],
      vietnameseHint: '「しっぱい」の「っ」を飛ばすと「しはい」(支配)などの別の単語に近づいてしまう。',
      evaluationPoint: '「っ」の前で息を止める間が十分に取れているか',
      source: PronunciationExerciseSource.builtIn,
    ),
    PronunciationExercise(
      id: 'pron_sokuon_05',
      category: PronunciationCategory.sokuon,
      sentence: 'あさって友達と会います。',
      reading: 'あさってともだちとあいます。',
      targetExpressions: ['あさって'],
      vietnameseHint: '文頭の「あさって」の「っ」を省略すると「あさて」となり不自然に聞こえる。',
      evaluationPoint: '文頭付近の「っ」でも一拍分の間を保てているか',
      source: PronunciationExerciseSource.builtIn,
    ),
  ];
}
