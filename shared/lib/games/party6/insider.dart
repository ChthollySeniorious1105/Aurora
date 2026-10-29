import '../../src/ai.dart';
import '../../src/engine.dart';

/// Built-in word entry for Insider (局内人), with structured attributes for Q&A deduction.
class InsiderWord {
  final String word;
  final String category;
  final Set<String> tags;
  final List<String> hints;
  const InsiderWord(this.word, this.category, this.tags, this.hints);
}

/// Standard attribute questions that players/bots can ask in Phase 1 (`'qa'`).
class InsiderQuestion {
  final String id;
  final String text;
  final String tag;
  const InsiderQuestion(this.id, this.text, this.tag);
}

const List<InsiderQuestion> kInsiderQuestionBank = [
  InsiderQuestion('living', '它是生物（动物、植物或人）吗？', 'living'),
  InsiderQuestion('animal', '它属于动物吗？', 'animal'),
  InsiderQuestion('food', '它是可以吃的食物或饮品吗？', 'food'),
  InsiderQuestion('manmade', '它是人造的物品或建筑吗？', 'manmade'),
  InsiderQuestion('nature', '它是自然界天然存在的现象或事物吗？', 'nature'),
  InsiderQuestion('daily', '在日常生活中经常能见到它吗？', 'daily'),
  InsiderQuestion('electric', '它需要用电或电池才能工作吗？', 'electric'),
  InsiderQuestion('big', '它的体积通常比一个书包更大吗？', 'big'),
  InsiderQuestion('small', '它可以轻松握在单手手心里吗？', 'small'),
  InsiderQuestion('indoor', '它通常出现在室内（家里或办公楼）吗？', 'indoor'),
  InsiderQuestion('outdoor', '它通常出现在户外、天空或野外吗？', 'outdoor'),
  InsiderQuestion('water', '它与水、海洋或液体密切相关吗？', 'water'),
  InsiderQuestion('move', '它自己会移动或是一种交通工具吗？', 'move'),
  InsiderQuestion('culture', '它与文化、娱乐、音乐或艺术有关吗？', 'culture'),
  InsiderQuestion('metal', '它主要是由金属材质制成的吗？', 'metal'),
  InsiderQuestion('ancient', '它在几百年前的古代就已经存在了吗？', 'ancient'),
];

const List<InsiderWord> kInsiderWordBank = [
  // 动物
  InsiderWord('大熊猫', '动物', {'living', 'animal', 'big', 'outdoor', 'ancient'}, ['它是中国的国宝动物吗？', '它喜欢吃竹子而且是黑白色的吗？']),
  InsiderWord('海豚', '动物', {'living', 'animal', 'big', 'outdoor', 'water', 'move', 'ancient'}, ['它生活在海洋里且非常聪明吗？', '它会跃出水面表演吗？']),
  InsiderWord('企鹅', '动物', {'living', 'animal', 'outdoor', 'water', 'move', 'ancient'}, ['它生活在冰天雪地的南极且不会飞吗？', '它走路摇摇摆摆像穿燕尾服吗？']),
  InsiderWord('萤火虫', '动物', {'living', 'animal', 'small', 'outdoor', 'nature', 'ancient'}, ['它在夏夜里尾部会一闪一闪发光吗？', '它是一种会飞的小昆虫吗？']),
  InsiderWord('变色龙', '动物', {'living', 'animal', 'small', 'outdoor', 'ancient'}, ['它能根据周围环境改变身体颜色吗？', '它的舌头很长可以捕食昆虫吗？']),
  InsiderWord('长颈鹿', '动物', {'living', 'animal', 'big', 'outdoor', 'move', 'ancient'}, ['它的脖子是陆地动物里最长的吗？', '它生活在非洲草原吃高处树叶吗？']),
  InsiderWord('猫咪', '动物', {'living', 'animal', 'daily', 'indoor', 'move', 'ancient'}, ['它是很多人家里养的毛茸茸宠物吗？', '它喜欢抓老鼠和晒太阳吗？']),
  InsiderWord('蜜蜂', '动物', {'living', 'animal', 'small', 'outdoor', 'move', 'ancient'}, ['它会在花丛中采蜜并酿造蜂蜜吗？', '它有翅膀而且尾端有蛰针吗？']),
  // 食物
  InsiderWord('火锅', '食物', {'food', 'manmade', 'daily', 'indoor'}, ['它是大家围坐在一起边煮边吃的美食吗？', '它有麻辣红汤或清汤锅底吗？']),
  InsiderWord('冰淇淋', '食物', {'food', 'manmade', 'daily', 'small'}, ['它是冰凉香甜、夏天最受欢迎的甜品吗？', '它不快点吃就会融化吗？']),
  InsiderWord('寿司', '食物', {'food', 'manmade', 'daily', 'small', 'water'}, ['它是用醋饭搭配鱼生或海苔捏成的料理吗？', '它常蘸酱油和芥末一起吃吗？']),
  InsiderWord('糖葫芦', '食物', {'food', 'manmade', 'small', 'outdoor', 'ancient'}, ['它是用竹签串起山楂并裹上硬糖壳的小吃吗？', '它红彤彤、酸甜可口吗？']),
  InsiderWord('小笼包', '食物', {'food', 'manmade', 'daily', 'small', 'indoor', 'ancient'}, ['它是放在蒸笼里蒸熟、里面有鲜美汤汁的面食吗？', '吃它的时候要先咬开小口喝汤吗？']),
  InsiderWord('西瓜', '食物', {'living', 'food', 'nature', 'daily', 'big', 'water', 'ancient'}, ['它是绿皮红瓤、水分充足的夏季水果吗？', '它形状圆圆的里面有黑色瓜子吗？']),
  InsiderWord('珍珠奶茶', '食物', {'food', 'manmade', 'daily', 'small', 'water'}, ['它是用吸管喝、底部有Q弹黑珍珠的饮品吗？', '它是年轻人在街边饮品店最爱点的饮料吗？']),
  InsiderWord('巧克力', '食物', {'food', 'manmade', 'daily', 'small'}, ['它是用可可豆制成、丝滑浓郁的棕色甜食吗？', '它在情人节常被装在礼盒里送人吗？']),
  // 日常与科技物品
  InsiderWord('智能手机', '物品', {'manmade', 'daily', 'electric', 'small', 'indoor', 'outdoor', 'culture'}, ['它是现代人每天随身携带、有触摸屏的电子设备吗？', '它可以打电话、拍照和上网聊天吗？']),
  InsiderWord('降落伞', '物品', {'manmade', 'big', 'outdoor', 'move'}, ['它是从高空跳下时打开用来安全减速的装备吗？', '它展开后像一朵巨大的蘑菇伞吗？']),
  InsiderWord('指南针', '物品', {'manmade', 'small', 'outdoor', 'metal', 'ancient'}, ['它是中国古代四大发明之一、用来辨别方向的仪器吗？', '它的指针总是固定指向南方或北方吗？']),
  InsiderWord('沙漏', '物品', {'manmade', 'small', 'indoor', 'ancient'}, ['它是两头大中间细、靠流沙来计时的玻璃器皿吗？', '把它倒过来就能重新开始计时吗？']),
  InsiderWord('望远镜', '物品', {'manmade', 'small', 'outdoor'}, ['它是通过镜片把远处的景物或星空放大来看的工具吗？', '观星或航海时常常用到它吗？']),
  InsiderWord('雨伞', '物品', {'manmade', 'daily', 'small', 'outdoor', 'water', 'ancient'}, ['它是下雨天撑开在头顶遮雨的日常用品吗？', '它可以折叠收拢起来随身携带吗？']),
  InsiderWord('电冰箱', '物品', {'manmade', 'daily', 'electric', 'big', 'indoor', 'metal'}, ['它是厨房里全天通电、用来冷藏和冷冻食物的家电吗？', '打开它的门会感到阵阵冷气吗？']),
  InsiderWord('钢琴', '物品', {'manmade', 'big', 'indoor', 'culture'}, ['它是有88个黑白琴键的西洋乐器之王吗？', '演奏时需要双手在琴键上弹奏吗？']),
  // 自然与建筑交通
  InsiderWord('彩虹', '自然', {'nature', 'big', 'outdoor', 'water', 'ancient'}, ['它是雨后天晴时挂在天空中的七彩拱桥吗？', '它是由阳光折射小水滴形成的光学现象吗？']),
  InsiderWord('火山', '自然', {'nature', 'big', 'outdoor', 'ancient'}, ['它是喷发时会涌出炽热岩浆和火山灰的山脉吗？', '它的顶部通常有一个火山口吗？']),
  InsiderWord('流星雨', '自然', {'nature', 'big', 'outdoor', 'ancient'}, ['它是夜空中许多星体划过天际并发光的壮丽天文现象吗？', '人们看到它时常常闭眼许愿吗？']),
  InsiderWord('灯塔', '建筑', {'manmade', 'big', 'outdoor', 'water', 'ancient'}, ['它是矗立在海边或孤岛上、夜晚发光为船只引航的高塔吗？', '它的顶端有旋转的强光探照灯吗？']),
  InsiderWord('摩天轮', '建筑', {'manmade', 'electric', 'big', 'outdoor', 'move', 'culture'}, ['它是游乐园里巨大的圆形转盘、人们坐在座舱里缓缓升空看风景吗？', '升到最高点时可以俯瞰整座城市吗？']),
  InsiderWord('热气球', '交通', {'manmade', 'big', 'outdoor', 'move'}, ['它是靠加热空气产生浮力、吊着藤篮在空中飘行的飞行器吗？', '它的球体通常色彩斑斓非常浪漫吗？']),
  InsiderWord('潜水艇', '交通', {'manmade', 'electric', 'big', 'outdoor', 'water', 'move', 'metal'}, ['它是能够潜入深海海底航行的钢铁船只吗？', '它配备有潜望镜和声呐系统吗？']),
  InsiderWord('长城', '建筑', {'manmade', 'big', 'outdoor', 'culture', 'ancient'}, ['它是盘旋在崇山峻岭之上的中国古代伟大军事防御工程吗？', '它有烽火台且绵延上万里吗？']),
];

List<InsiderWord> parseCustomInsiderWords(List<String> lines) {
  final out = <InsiderWord>[];
  final seen = <String>{};
  for (final raw in lines) {
    final s = raw.trim();
    if (s.isEmpty || s.startsWith('#')) continue;
    final parts = s.split(RegExp(r'[|｜]'));
    final w = parts[0].trim();
    if (w.isEmpty || w.length > 10 || !seen.add(w)) continue;
    final cat = parts.length > 1 && parts[1].trim().isNotEmpty ? parts[1].trim() : '自定义';
    out.add(InsiderWord(w, cat, const {'daily'}, ['它与「$cat」类别密切相关吗？']));
  }
  return out;
}

class InsiderGame extends GameEngine {
  final _ai = AiSlot();

  /// Seat of the Master (主持人, public).
  late int masterSeat;

  /// Seat of the Insider (局内人, secret until game over).
  late int insiderSeat;

  /// The secret word entry for this game.
  late InsiderWord secretEntry;
  String get secretWord => secretEntry.word;

  /// Candidate words for this match (always includes [secretWord] + distractors, shuffled).
  late List<String> candidateWords;

  /// Maximum allowed questions/attempts before time runs out.
  late int maxQuestions;
  int questionsUsed = 0;

  /// Current phase: 'qa' (Phase 1), 'accuse' (Phase 2), 'end' (Game Over).
  String phase = 'qa';

  /// Sub-step in Phase 2 ('accuse'):
  /// 1 = everyone votes Yes/No on whether [guesser] is the Insider.
  /// 2 = everyone votes among remaining suspects (excluding [masterSeat] and [guesser]).
  int accuseStep = 1;

  /// Whose turn to ask next in Phase 1 (rotates among non-Master seats).
  int currentAsker = 0;

  /// Pending question waiting for Master's answer ('yes' / 'no' / 'idk').
  int pendingAsker = -1;
  String? pendingQuestion;

  /// Seat of the player who guessed the secret word in Phase 1.
  int guesser = -1;

  /// History of Q&A items: `{'id': int, 'asker': int, 'text': String, 'answer': 'yes'|'no'|'idk'|'correct', 'isGuess': bool}`.
  final List<Map<String, dynamic>> qaHistory = [];

  /// Votes in Phase 2 Step 1 (whether `guesser` is the Insider).
  final Map<int, bool> guesserVotes = {};

  /// Votes in Phase 2 Step 2 (which remaining suspect is the Insider).
  final Map<int, int> suspectVotes = {};

  /// Seat accused at the end of Phase 2, or -1.
  int accusedSeat = -1;

  /// Outcome: 'commons' (Commons & Master win), 'insider' (Insider wins), or 'none' (Everyone loses).
  String? winner;
  String resultText = '';
  bool _over = false;

  InsiderGame(super.setup);

  @override
  bool get isOver => _over;

  String roleOf(int seat) {
    if (seat == masterSeat) return 'master';
    if (seat == insiderSeat) return 'insider';
    return 'common';
  }

  @override
  List<int>? get placings {
    if (!_over || winner == null) return null;
    if (winner == 'commons') {
      return rankWinners(players, [for (var s = 0; s < players; s++) if (s != insiderSeat) s]);
    }
    if (winner == 'insider') {
      return rankWinners(players, [insiderSeat]);
    }
    // Everyone loses -> all tied
    return rankWinners(players, const <int>[]);
  }

  @override
  void start() {
    maxQuestions = setup.opt<int>('maxQuestions', 20);
    final wordMode = setup.opt<String>('words', 'both');
    final custom = parseCustomInsiderWords(setup.resourceLines('insider.words'));
    final pool = <InsiderWord>[
      if (wordMode != 'custom' || custom.isEmpty) ...kInsiderWordBank,
      if (wordMode != 'builtin') ...custom,
    ];

    final seats = shuffled([for (var s = 0; s < players; s++) s], rng);
    masterSeat = seats[0];
    insiderSeat = seats[1];

    secretEntry = pool[rng.nextInt(pool.length)];

    // Build candidate words (12 words including secretWord)
    final others = shuffled([for (final w in pool) if (w.word != secretWord) w.word], rng);
    candidateWords = shuffled([secretWord, ...others.take(11)], rng);

    currentAsker = _nextNonMaster(masterSeat);
    phase = 'qa';
    accuseStep = 1;
    questionsUsed = 0;
    pendingAsker = -1;
    pendingQuestion = null;
    guesser = -1;
    qaHistory.clear();
    guesserVotes.clear();
    suspectVotes.clear();
    accusedSeat = -1;
    winner = null;
    resultText = '';
    _over = false;

    host.log('【局内人】开局！主持人是 ${name(masterSeat)}（词语类别：${secretEntry.category}，限 $maxQuestions 问）。');
  }

  int _nextNonMaster(int from) {
    for (var i = 1; i <= players; i++) {
      final cand = (from + i) % players;
      if (cand != masterSeat) return cand;
    }
    return 0;
  }

  /// Eligible suspect seats in Phase 2 Step 2 (all seats except Master and Guesser).
  List<int> get suspectSeats => [
        for (var s = 0; s < players; s++)
          if (s != masterSeat && s != guesser) s,
      ];

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'qa') {
      if (pendingQuestion != null) return [masterSeat];
      return [currentAsker];
    }
    if (phase == 'accuse') {
      if (accuseStep == 1) {
        return [
          for (var s = 0; s < players; s++)
            if (!guesserVotes.containsKey(s)) s,
        ];
      }
      return [
        for (var s = 0; s < players; s++)
          if (!suspectVotes.containsKey(s)) s,
      ];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);

    if (phase == 'qa') {
      if (pendingQuestion != null) {
        if (seat != masterSeat) throw GameError('请等待主持人回答当前问题');
        final rawAns = asStr(action['answer'], asStr(action['value'], type));
        final ans = switch (rawAns) {
          'yes' || '是' || 'true' => 'yes',
          'no' || '否' || 'false' => 'no',
          'idk' || '不知道' || 'unknown' => 'idk',
          _ => '',
        };
        if (ans.isEmpty) throw GameError('主持人请选择「是」、「否」或「不知道」');

        final qText = pendingQuestion!;
        final asker = pendingAsker;
        pendingQuestion = null;
        pendingAsker = -1;
        questionsUsed++;

        qaHistory.add({
          'id': qaHistory.length + 1,
          'asker': asker,
          'text': qText,
          'answer': ans,
          'isGuess': false,
        });

        final ansLabel = ans == 'yes' ? '是' : (ans == 'no' ? '否' : '不知道');
        host.log('${name(masterSeat)} 回答 ${name(asker)}：「$ansLabel」');

        if (questionsUsed >= maxQuestions) {
          _endAllLose();
          return;
        }
        currentAsker = _nextNonMaster(asker);
        return;
      }

      // Asking a question or guessing the word
      if (seat == masterSeat) throw GameError('主持人不能提问或猜词');
      final text = AiText.firstLine(asStr(action['text'], asStr(action['word'])), maxLen: 45);
      if (text.isEmpty) throw GameError('请输入提问或猜词内容');

      if (type == 'guess_word' || type == 'guess' || text == secretWord) {
        final cleanGuess = text.replaceAll(RegExp(r'^猜词[:：]?\s*'), '').trim();
        questionsUsed++;
        if (cleanGuess == secretWord || text.contains(secretWord)) {
          guesser = seat;
          qaHistory.add({
            'id': qaHistory.length + 1,
            'asker': seat,
            'text': '猜词：$secretWord',
            'answer': 'correct',
            'isGuess': true,
          });
          phase = 'accuse';
          accuseStep = 1;
          guesserVotes.clear();
          suspectVotes.clear();
          host.log('🎉 ${name(seat)} 猜中了神秘词「$secretWord」！进入指认局内人阶段。');
          return;
        } else {
          qaHistory.add({
            'id': qaHistory.length + 1,
            'asker': seat,
            'text': '猜词：$cleanGuess',
            'answer': 'no',
            'isGuess': true,
          });
          host.log('${name(seat)} 尝试猜词「$cleanGuess」—— 猜错了（否）！');
          if (questionsUsed >= maxQuestions) {
            _endAllLose();
            return;
          }
          currentAsker = _nextNonMaster(seat);
          return;
        }
      }

      if (type == 'ask') {
        pendingAsker = seat;
        pendingQuestion = text;
        host.log('${name(seat)} 提问：「$text」');
        return;
      }

      throw GameError('未知问答阶段操作：$type');
    }

    if (phase == 'accuse') {
      if (accuseStep == 1) {
        if (type != 'vote' && type != 'vote_guesser' && type != 'accuse') {
          throw GameError('请对猜中者是否为局内人进行表决');
        }
        if (guesserVotes.containsKey(seat)) throw GameError('你已经投过票了');
        final raw = action['yes'] ?? action['isInsider'] ?? action['vote'];
        final yes = raw == true || raw == 'yes' || raw == '是';
        guesserVotes[seat] = yes;
        if (waitingFor.isEmpty) {
          _resolveGuesserTrial();
        }
        return;
      }

      if (accuseStep == 2) {
        if (type != 'vote' && type != 'vote_suspect' && type != 'accuse') {
          throw GameError('请投票指认一名嫌疑人');
        }
        if (suspectVotes.containsKey(seat)) throw GameError('你已经投过票了');
        final target = asInt(action['target'], asInt(action['seat']));
        if (!suspectSeats.contains(target)) {
          throw GameError('只能投票给除主持人和猜中者以外的嫌疑人');
        }
        suspectVotes[seat] = target;
        if (waitingFor.isEmpty) {
          _resolveSuspectVote();
        }
        return;
      }
    }
  }

  void _endAllLose() {
    winner = 'none';
    resultText = '提问耗尽仍未猜出神秘词「$secretWord」（局内人是 ${name(insiderSeat)}），全员失败！';
    _over = true;
    phase = 'end';
    host.log('【全员失败】$resultText');
  }

  void _resolveGuesserTrial() {
    var yesCount = 0;
    var noCount = 0;
    for (final v in guesserVotes.values) {
      if (v) {
        yesCount++;
      } else {
        noCount++;
      }
    }

    if (yesCount > noCount) {
      // Majority says Guesser IS the Insider!
      accusedSeat = guesser;
      if (guesser == insiderSeat) {
        winner = 'commons';
        resultText = '多数票（$yesCount:$noCount）认定猜中者 ${name(guesser)} 是局内人——抓捕成功！平民与主持人获胜！';
      } else {
        winner = 'insider';
        resultText = '多数票（$yesCount:$noCount）冤枉了平民 ${name(guesser)}！真正的局内人 ${name(insiderSeat)} 潜伏成功获胜！';
      }
      _over = true;
      phase = 'end';
      host.log('【审判结果】$resultText');
    } else {
      // Majority says No -> proceed to general vote among remaining suspects!
      accuseStep = 2;
      host.log('【审判结果】多数票（赞成 $yesCount : 反对 $noCount）认为猜中者 ${name(guesser)} 不是局内人，进入全员指认投票！');
    }
  }

  void _resolveSuspectVote() {
    final counts = <int, int>{for (final s in suspectSeats) s: 0};
    for (final t in suspectVotes.values) {
      counts[t] = (counts[t] ?? 0) + 1;
    }

    var maxVotes = -1;
    for (final c in counts.values) {
      if (c > maxVotes) maxVotes = c;
    }
    final tied = [for (final e in counts.entries) if (e.value == maxVotes) e.key];

    // Official rule: Guesser's vote breaks ties!
    final gVote = suspectVotes[guesser];
    if (tied.length > 1 && gVote != null && tied.contains(gVote)) {
      accusedSeat = gVote;
    } else {
      accusedSeat = tied.first;
    }

    if (accusedSeat == insiderSeat) {
      winner = 'commons';
      resultText = '全员投票指认 ${name(accusedSeat)}（${counts[accusedSeat]} 票）——成功抓获局内人！平民与主持人获胜！';
    } else {
      winner = 'insider';
      resultText = '全员投票指认了平民 ${name(accusedSeat)}，真正的局内人 ${name(insiderSeat)} 完美伪装获胜！';
    }
    _over = true;
    phase = 'end';
    host.log('【最终判决】$resultText');
  }

  /// Evaluates a question against the secret word for Master bot / hints.
  String evaluateQuestion(String questionText) {
    for (final q in kInsiderQuestionBank) {
      if (questionText == q.text || questionText.contains(q.text.substring(0, 4))) {
        return secretEntry.tags.contains(q.tag) ? 'yes' : 'no';
      }
    }
    for (final h in secretEntry.hints) {
      if (questionText == h) return 'yes';
    }
    for (final w in kInsiderWordBank) {
      if (w.word != secretWord && w.hints.contains(questionText)) return 'no';
    }
    if (questionText.contains(secretEntry.category)) return 'yes';
    return 'idk';
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myRole = (seat >= 0 && seat < players) ? roleOf(seat) : 'spectator';
    final knowsWord = _over || phase != 'qa' || myRole == 'master' || myRole == 'insider';

    return {
      'phase': phase,
      'accuseStep': accuseStep,
      'masterSeat': masterSeat,
      'insiderSeat': _over ? insiderSeat : null,
      'myRole': myRole,
      'category': secretEntry.category,
      'secretWord': knowsWord ? secretWord : null,
      'candidateWords': candidateWords,
      'candidateQuestions': [
        for (final q in kInsiderQuestionBank) {'id': q.id, 'text': q.text},
        for (final h in secretEntry.hints) {'id': 'hint', 'text': h},
      ],
      'questionsUsed': questionsUsed,
      'maxQuestions': maxQuestions,
      'currentAsker': currentAsker,
      'pendingAsker': pendingAsker,
      'pendingQuestion': pendingQuestion,
      'guesser': guesser,
      'suspectSeats': suspectSeats,
      'qaHistory': List.of(qaHistory),
      'guesserVotes': {for (final e in guesserVotes.entries) '${e.key}': e.value},
      'suspectVotes': {for (final e in suspectVotes.entries) '${e.key}': e.value},
      'accusedSeat': accusedSeat,
      'winner': winner,
      'result': _over ? resultText : null,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'qa') {
      // 1. Master answering pendingQuestion
      if (pendingQuestion != null && seat == masterSeat) {
        final q = pendingQuestion!;
        if (aiOn) {
          final r = _ai.poll(
            setup.ai!,
            'insider_ans:${qaHistory.length}:$seat',
            () => AiRequest(
              system: '你是《局内人》游戏的主持人。请根据神秘词只回答“是”、“否”或“不知道”三个词之一。',
              prompt: '神秘词是「$secretWord」（类别：${secretEntry.category}）。玩家提问：「$q」。',
            ),
          );
          if (r.pending) return null;
          if (r.text != null) {
            final t = r.text!.trim();
            if (t.startsWith('是')) return {'type': 'answer', 'answer': 'yes'};
            if (t.startsWith('否') || t.startsWith('不')) {
              return {'type': 'answer', 'answer': t.contains('不知道') ? 'idk' : 'no'};
            }
          }
        }
        return {'type': 'answer', 'answer': evaluateQuestion(q)};
      }

      // 2. Insider or Common asking/guessing
      final askedTexts = {for (final item in qaHistory) asStr(item['text'])};
      final guessedWords = {
        for (final item in qaHistory)
          if (item['isGuess'] == true) asStr(item['text']).replaceAll('猜词：', '').trim(),
      };

      if (seat == insiderSeat) {
        // Insider knows secretWord!
        // If few questions left or enough questions asked, Insider either asks a revealing hint or guesses the word so time doesn't run out.
        if (questionsUsed >= maxQuestions - 3 || (questionsUsed >= 4 && rng.nextDouble() < 0.45)) {
          return {'type': 'guess_word', 'text': secretWord};
        }
        // Ask a specific hint for secretEntry if not yet asked
        for (final h in secretEntry.hints) {
          if (!askedTexts.contains(h)) {
            return {'type': 'ask', 'text': h};
          }
        }
        // Ask a tag question whose answer is 'yes' for secretEntry
        for (final q in kInsiderQuestionBank) {
          if (secretEntry.tags.contains(q.tag) && !askedTexts.contains(q.text)) {
            return {'type': 'ask', 'text': q.text};
          }
        }
        return {'type': 'guess_word', 'text': secretWord};
      }

      // Common player (does NOT know secretWord! Filters candidateWords using public qaHistory)
      final matchingWords = _filterCandidatesFromHistory(guessedWords);
      if (matchingWords.length == 1 || (questionsUsed >= 4 && matchingWords.length <= 2) || questionsUsed >= maxQuestions - 2) {
        final pick = matchingWords.isNotEmpty
            ? matchingWords[rng.nextInt(matchingWords.length)]
            : candidateWords.firstWhere((w) => !guessedWords.contains(w), orElse: () => candidateWords.first);
        return {'type': 'guess_word', 'text': pick};
      }

      if (aiOn) {
        final histStr = qaHistory
            .map((e) => '${e['text']} -> ${e['answer'] == 'yes' ? '是' : (e['answer'] == 'no' ? '否' : '不知道')}')
            .join('；');
        final r = _ai.poll(
          setup.ai!,
          'insider_ask:${qaHistory.length}:$seat',
          () => AiRequest(
            system: '你在玩《局内人》猜词游戏（平民身份）。请输出一个简短的是非问句（以“吗？”结尾，不超过20字），不要输出其他解释。',
            prompt: '词语类别：${secretEntry.category}。已有问答记录：${histStr.isEmpty ? "无" : histStr}。',
          ),
        );
        if (r.pending) return null;
        if (r.text != null) {
          final line = AiText.firstLine(r.text!, maxLen: 25);
          if (line.length >= 3 && !askedTexts.contains(line) && !line.contains(secretWord)) {
            return {'type': 'ask', 'text': line};
          }
        }
      }

      // Pick an unasked question from kInsiderQuestionBank
      final unasked = [for (final q in kInsiderQuestionBank) if (!askedTexts.contains(q.text)) q.text];
      if (unasked.isNotEmpty) {
        return {'type': 'ask', 'text': unasked[rng.nextInt(unasked.length)]};
      }
      final fallbackWord = matchingWords.isNotEmpty ? matchingWords.first : candidateWords.first;
      return {'type': 'guess_word', 'text': fallbackWord};
    }

    if (phase == 'accuse') {
      if (accuseStep == 1) {
        if (seat == insiderSeat) {
          // Insider wants Commons to be wrong: if Insider is guesser, vote No; if a Common is guesser, vote Yes!
          return {'type': 'vote', 'yes': guesser != insiderSeat};
        }
        if (seat == guesser) {
          return {'type': 'vote', 'yes': false};
        }
        // Heuristic: check if guesser asked specific hints or guessed very early
        final suspicious = qaHistory.where((e) => e['asker'] == guesser && e['answer'] == 'yes').length >= 2;
        return {'type': 'vote', 'yes': suspicious ? rng.nextDouble() < 0.7 : rng.nextDouble() < 0.35};
      }

      if (accuseStep == 2) {
        final cands = suspectSeats;
        if (seat == insiderSeat) {
          final others = [for (final s in cands) if (s != insiderSeat) s];
          final pick = others.isNotEmpty ? others[rng.nextInt(others.length)] : cands.first;
          return {'type': 'vote', 'target': pick};
        }
        // Commons/Master vote for the suspect who asked the most 'yes' questions
        var best = cands.first;
        var bestScore = -1;
        for (final s in cands) {
          final yesAsked = qaHistory.where((e) => e['asker'] == s && e['answer'] == 'yes').length;
          if (yesAsked > bestScore) {
            bestScore = yesAsked;
            best = s;
          }
        }
        if (botLevel == 0 && cands.length > 1) {
          return {'type': 'vote', 'target': cands[rng.nextInt(cands.length)]};
        }
        return {'type': 'vote', 'target': best};
      }
    }

    return null;
  }

  List<String> _filterCandidatesFromHistory(Set<String> excludeGuessed) {
    final mapByWord = {for (final w in kInsiderWordBank) w.word: w};
    final out = <String>[];
    for (final wStr in candidateWords) {
      if (excludeGuessed.contains(wStr)) continue;
      final entry = mapByWord[wStr];
      if (entry == null) {
        out.add(wStr);
        continue;
      }
      var ok = true;
      for (final item in qaHistory) {
        if (item['isGuess'] == true) continue;
        final qText = asStr(item['text']);
        final ans = asStr(item['answer']);
        if (ans != 'yes' && ans != 'no') continue;
        // Check against standard questions
        for (final q in kInsiderQuestionBank) {
          if (qText == q.text) {
            final hasTag = entry.tags.contains(q.tag);
            if ((ans == 'yes') != hasTag) ok = false;
          }
        }
        // Check against entry-specific hints
        if (entry.hints.contains(qText) && ans == 'no') ok = false;
      }
      if (ok) out.add(wStr);
    }
    return out;
  }
}
