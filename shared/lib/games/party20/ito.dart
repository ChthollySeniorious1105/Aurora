import 'dart:math';

import '../../src/ai.dart';
import '../../src/engine.dart';

class ItoGame extends GameEngine {
  ItoGame(super.setup);

  /// Built-in bank of 22 fun themes, each with a title, lowLabel (1), highLabel (100),
  /// and a 10-tier scale (indices 0..9 for deciles 1..10 through 91..100) free of digits.
  static const List<Map<String, Object>> themeBank = [
    {
      'title': '最受欢迎的火锅食材',
      'lowLabel': '1=白开水锅底',
      'highLabel': '100=顶级肥牛虾滑',
      'scale': ['苦瓜片', '白萝卜块', '大白菜叶', '金针菇', '冻豆腐', '土豆宽粉', '脆毛肚', '手打牛肉丸', '精品肥牛卷', '黑虎虾滑皇'],
    },
    {
      'title': '破坏力最强的事物',
      'lowLabel': '1=蒲公英绒毛',
      'highLabel': '100=超新星爆发',
      'scale': ['蒲公英绒毛', '纸飞机', '玩具水枪', '冰雹雨', '推土机', '龙卷风', '海底地震', '火山喷发', '小行星撞击', '超新星爆发'],
    },
    {
      'title': '最令人期待的假期活动',
      'lowLabel': '1=在家大扫除',
      'highLabel': '100=环球豪华邮轮游',
      'scale': ['擦窗户拖地', '小区散步', '逛菜市场', '看午夜电影', '郊野露营烧烤', '游乐园过山车', '海岛浮潜冲浪', '极光雪屋之旅', '跨国美食巡礼', '环球豪华邮轮'],
    },
    {
      'title': '体型最庞大的生物或存在',
      'lowLabel': '1=草履虫',
      'highLabel': '100=蓝鲸与世界树',
      'scale': ['草履虫', '小蚂蚁', '麻雀', '橘猫', '金毛犬', '成年棕熊', '非洲草原象', '抹香鲸', '深海蓝鲸', '远古巨型泰坦'],
    },
    {
      'title': '最让人感到幸福的瞬间',
      'lowLabel': '1=捡到一分钱',
      'highLabel': '100=实现毕生梦想',
      'scale': ['微风拂面', '喝口冰汽水', '准时赶上公交', '吃到热腾腾夜宵', '收到意外礼物', '周末睡到自然醒', '与挚友重逢欢聚', '加薪升职表彰', '金榜题名时刻', '实现毕生梦想'],
    },
    {
      'title': '速度最快的事物',
      'lowLabel': '1=树懒散步',
      'highLabel': '100=宇宙光速脉冲',
      'scale': ['蜗牛爬行', '乌龟慢走', '婴儿学步', '自行车骑行', '猎豹冲刺', '复兴号高铁', '民航客机巡航', '超音速战斗机', '重返大气层火箭', '宇宙光速脉冲'],
    },
    {
      'title': '最让人抓狂的生活小事',
      'lowLabel': '1=鞋带松了',
      'highLabel': '100=未保存文档断电崩溃',
      'scale': ['鞋带松开', '衣服沾水滴', '耳机线打结', '墨水弄脏手指', '外卖漏送餐具', '洗澡突然停冷水', '出门忘带钥匙', '手机只剩微弱电量', '闹钟没响迟到', '文档未存断电'],
    },
    {
      'title': '最珍贵稀有的宝物',
      'lowLabel': '1=路边小石子',
      'highLabel': '100=传世国宝和氏璧',
      'scale': ['路边小石子', '玻璃弹珠', '贝壳书签', '铜制纪念币', '纯银怀表', '珍珠项链', '古董青花瓷', '天然红宝石冠', '深海夜明珠', '传世国宝玉玺'],
    },
    {
      'title': '最辣最刺激的食物体验',
      'lowLabel': '1=清甜黄瓜条',
      'highLabel': '100=地狱魔鬼辣椒王',
      'scale': ['冰镇黄瓜条', '清汤挂面', '青椒炒蛋', '蒜泥白肉', '微辣麻辣烫', '宫保鸡丁', '水煮肉片', '重庆九宫格老油', '变态辣火鸡面', '地狱魔鬼辣椒'],
    },
    {
      'title': '最恐怖惊悚的场景',
      'lowLabel': '1=阳光草坪野餐',
      'highLabel': '100=深渊古宅午夜怪声',
      'scale': ['暖阳草坪', '黄昏小巷', '空旷地下车库', '停电的电梯间', '迷雾森林深处', '荒废游乐园', '午夜旧医院走廊', '古墓幽暗密室', '幽灵船甲板', '深渊禁忌古宅'],
    },
    {
      'title': '最考验毅力的挑战',
      'lowLabel': '1=少喝一口奶茶',
      'highLabel': '100=徒步横穿撒哈拉沙漠',
      'scale': ['少放半勺糖', '早起十分钟', '爬几层楼梯', '戒掉夜宵一周', '每天晨跑打卡', '跑完半程马拉松', '冬泳横渡大江', '登顶珠穆朗玛峰', '单人帆船环球', '徒步横穿沙漠'],
    },
    {
      'title': '最可爱的萌物排行',
      'lowLabel': '1=干瘪木头桩',
      'highLabel': '100=打滚卖萌大熊猫幼崽',
      'scale': ['枯木桩', '小蜗牛', '金鱼吐泡', '小黄鸭幼崽', '垂耳小灰兔', '圆滚滚仓鼠', '歪头杀柯基犬', '奶声奶气小奶猫', '海獭手牵手睡觉', '大熊猫幼崽打滚'],
    },
    {
      'title': '最烧脑的高难度技能',
      'lowLabel': '1=学会石头剪刀布',
      'highLabel': '100=量子引力弦理论推导',
      'scale': ['石头剪刀布', '折纸飞机', '拼图入门', '三阶魔方还原', '盲棋对弈', '同声传译速记', '交响乐总谱指挥', '超算架构设计', '航天轨道微积分', '量子弦理论推导'],
    },
    {
      'title': '温度最高的事物',
      'lowLabel': '1=极地万年冰川',
      'highLabel': '100=恒星核心聚变烈焰',
      'scale': ['极地冰川', '冰镇柠檬水', '春日微风', '温热牛奶', '温泉池水', '沸腾开水壶', '炭火烧烤炉', '炼钢高炉铁水', '地心炽热岩浆', '恒星核心聚变'],
    },
    {
      'title': '声音最响亮的场景',
      'lowLabel': '1=雪花飘落无声',
      'highLabel': '100=火箭发射近距轰鸣',
      'scale': ['雪花飘落', '翻书轻响', '图书馆耳语', '咖啡馆交谈', '热闹菜市场', '交响乐团齐奏', '摇滚音乐节前排', '惊雷闪电炸响', '喷气机低空掠过', '火箭发射轰鸣'],
    },
    {
      'title': '最适合冬天的治愈事物',
      'lowLabel': '1=赤脚踩冰水',
      'highLabel': '100=壁炉旁裹毛毯喝热可可',
      'scale': ['冷风吹脸', '单薄外套', '温水洗手', '戴上绒线手套', '烤红薯香气', '糖炒栗子出锅', '暖气房钻进被窝', '热气腾腾羊肉汤', '雪景露天温泉', '壁炉旁喝热可可'],
    },
    {
      'title': '寿命最漫长的存在',
      'lowLabel': '1=朝生暮死蜉蝣',
      'highLabel': '100=百亿年恒星宇宙',
      'scale': ['夏夜蜉蝣', '蝴蝶飞舞', '田园小仓鼠', '家养猫咪', '野生亚洲象', '百岁加拉帕戈斯龟', '格陵兰长寿鲨', '千年银杏古树', '万里山脉岩层', '百亿年恒星宇宙'],
    },
    {
      'title': '最浪漫的心动瞬间',
      'lowLabel': '1=收到群发广告短信',
      'highLabel': '100=漫天流星雨下深情告白',
      'scale': ['路人点头之交', '借用一把雨伞', '顺路买杯热饮', '并肩看夕阳晚霞', '游乐园摩天轮顶', '雪夜共撑一把伞', '亲手准备惊喜晚餐', '海边烟花绽放夜', '极光下交换信物', '流星雨下深情告白'],
    },
    {
      'title': '最硬核的求生装备',
      'lowLabel': '1=一根塑料吸管',
      'highLabel': '100=全地形太阳能移动基地',
      'scale': ['塑料吸管', '纸巾一包', '普通打火机', '不锈钢水壶', '多功能瑞士军刀', '防风登山帐篷', '卫星求救通讯仪', '净水与急救箱套组', '重型防弹越野车', '太阳能移动基地'],
    },
    {
      'title': '最让人嘴馋的深夜美食',
      'lowLabel': '1=干咽白面馒头皮',
      'highLabel': '100=滋滋冒油炭烤羊肉串配冰饮',
      'scale': ['冷馒头片', '苏打饼干', '荷包蛋汤面', '煎饺配醋', '芝士焗红薯', '蒜香小龙虾', '脆皮炸鸡配可乐', '秘制卤味拼盘', '海鲜砂锅粥', '炭烤羊肉串配冰饮'],
    },
  ];

  int totalRounds = 3;
  int round = 1;
  int lives = 3;
  int maxLives = 3;
  String phase = 'clue'; // 'clue' | 'play' | 'over'
  bool teamWon = false;

  int themeIdx = 0;
  String theme = '';
  String lowLabel = '';
  String highLabel = '';
  List<String> currentScale = const [];

  /// Secret number 1..100 for each seat. Strictly hidden from other seats until played!
  late List<int> secretNumber;

  /// Whether each seat's secret number card has been played/revealed this round.
  late List<bool> cardPlayed;

  /// Submitted clues in the current round: seat -> clue text.
  final Map<int, String> clues = {};

  /// Cards revealed on the table in order: {'seat': int, 'value': int, 'status': 'perfect'|'early'|'skipped'}.
  final List<Map<String, dynamic>> playedCards = [];

  int lastPlayedValue = 0;
  int nominatedSeat = -1;

  /// Individual accuracy scores & team score.
  late List<int> scores;
  int teamScore = 0;

  final Set<int> _usedThemes = {};
  final AiSlot _ai = AiSlot();
  String lastEvent = '糸：数字共鸣开启！请根据本轮主题，用不带数字的比喻词描述你手中秘密数字的大小！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    return rankByScore(scores);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'clue') {
      return [
        for (var s = 0; s < players; s++)
          if (!clues.containsKey(s)) s,
      ];
    }
    if (phase == 'play') {
      return [
        for (var s = 0; s < players; s++)
          if (!cardPlayed[s]) s,
      ];
    }
    return const [];
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 3);
    round = 1;
    maxLives = players >= 4 ? 4 : 3;
    lives = maxLives;
    scores = List<int>.filled(players, 0);
    teamScore = 0;
    teamWon = false;
    _usedThemes.clear();
    _startRound();
    host.log('【糸：数字共鸣】合作派对游戏开始！共 $totalRounds 轮，团队初始拥有 $lives ❤️ 生命值！');
  }

  void _startRound() {
    _ai.clear();
    if (_usedThemes.length >= themeBank.length) _usedThemes.clear();
    int idx;
    do {
      idx = rng.nextInt(themeBank.length);
    } while (_usedThemes.contains(idx));
    _usedThemes.add(idx);
    themeIdx = idx;

    final t = themeBank[idx];
    theme = t['title'] as String;
    lowLabel = t['lowLabel'] as String;
    highLabel = t['highLabel'] as String;
    currentScale = List<String>.from(t['scale'] as List);

    // Deal unique secret numbers in 1..100
    final pool = [for (var i = 1; i <= 100; i++) i]..shuffle(rng);
    secretNumber = pool.sublist(0, players);
    cardPlayed = List<bool>.filled(players, false);
    clues.clear();
    playedCards.clear();
    lastPlayedValue = 0;
    nominatedSeat = -1;
    phase = 'clue';

    lastEvent = '第 $round/$totalRounds 轮主题【$theme】（$lowLabel ↔ $highLabel）：请描述你的秘密数字！';
  }

  /// Validates that [text] is non-empty and does not contain Arabic numerals 0-9 or the secret number.
  String? validateClue(int seat, String text) {
    final clean = text.trim();
    if (clean.isEmpty) {
      return '线索不能为空！';
    }
    if (clean.runes.length > 30) {
      return '线索不能超过 30 个字！';
    }
    final myNum = secretNumber[seat];
    if (clean.contains('$myNum') || RegExp(r'[0-9０-９]').hasMatch(clean)) {
      return '线索严禁包含阿拉伯数字（0-9）或直接透露秘密数字！';
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);
    switch (type) {
      case 'clue':
        _handleClue(seat, action);
        break;
      case 'play_card':
        _handlePlayCard(seat);
        break;
      case 'nominate':
        _handleNominate(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleClue(int seat, Map<String, dynamic> action) {
    if (phase != 'clue') throw GameError('当前不是线索描述阶段');
    if (clues.containsKey(seat)) throw GameError('你本轮已经提交过线索了');

    final text = asStr(action['text']).trim();
    final err = validateClue(seat, text);
    if (err != null) throw GameError(err);

    clues[seat] = text;
    host.log('💬 ${name(seat)} 给出了共鸣线索：「$text」');

    if (clues.length >= players) {
      phase = 'play';
      nominatedSeat = bestNextSeatFromPublicClues();
      lastEvent = '✨ 全员线索已公开！请按从小到大（1 → 100）的顺序亮出数字牌！';
      host.log(lastEvent);
    } else {
      lastEvent = '💬 ${name(seat)} 已给出线索：「$text」（已提交 ${clues.length}/$players 人）';
    }
  }

  void _handleNominate(int seat, Map<String, dynamic> action) {
    if (phase != 'play') throw GameError('当前不是升序亮牌阶段');
    final target = asInt(action['target'], -1);
    if (target < 0 || target >= players || cardPlayed[target]) {
      throw GameError('只能提名尚未亮牌的玩家');
    }
    nominatedSeat = target;
    lastEvent = '👉 ${name(seat)} 提议由 ${name(target)}（线索：「${clues[target] ?? ""}」）下一位亮牌！';
    host.log(lastEvent);
  }

  void _handlePlayCard(int seat) {
    if (phase != 'play') throw GameError('当前不是升序亮牌阶段');
    if (cardPlayed[seat]) throw GameError('你的数字牌已经亮过了');

    final v = secretNumber[seat];
    // Find any other unplayed seats holding a smaller secret number (< v)
    final skippedSeats = <int>[
      for (var s = 0; s < players; s++)
        if (s != seat && !cardPlayed[s] && secretNumber[s] < v) s,
    ]..sort((a, b) => secretNumber[a].compareTo(secretNumber[b]));

    if (skippedSeats.isEmpty) {
      // Perfect Play!
      cardPlayed[seat] = true;
      lastPlayedValue = v;
      playedCards.add({
        'seat': seat,
        'value': v,
        'clue': clues[seat] ?? '',
        'status': 'perfect',
      });
      scores[seat] += 10;
      teamScore += 10;
      lastEvent = '🎯 完美共鸣！${name(seat)} 亮出【$v】（「${clues[seat]}」），精准衔接升序序列（+10 分）！';
      host.log(lastEvent);
    } else {
      // Early play mistake: smaller unplayed cards are automatically discarded face-up & cost 1 life each!
      final skippedDesc = <String>[];
      for (final sk in skippedSeats) {
        cardPlayed[sk] = true;
        playedCards.add({
          'seat': sk,
          'value': secretNumber[sk],
          'clue': clues[sk] ?? '',
          'status': 'skipped',
        });
        // Players who held smaller cards and waited patiently get +3 accuracy consolation bonus
        scores[sk] += 3;
        skippedDesc.add('${name(sk)}【${secretNumber[sk]}】');
      }
      cardPlayed[seat] = true;
      lastPlayedValue = v;
      playedCards.add({
        'seat': seat,
        'value': v,
        'clue': clues[seat] ?? '',
        'status': 'early',
      });
      final lost = skippedSeats.length;
      lives = max(0, lives - lost);
      lastEvent =
          '💥 顺序错位！${name(seat)} 亮出【$v】，跳过了更小的 ${skippedDesc.join("、")}，团队扣除 -$lost ❤️（剩余 $lives ❤️）！';
      host.log(lastEvent);

      if (lives <= 0) {
        teamWon = false;
        phase = 'over';
        lastEvent = '$lastEvent · 💔 团队生命值归零，共鸣挑战遗憾失败！';
        host.log('💔 团队生命值耗尽，游戏结束！');
        return;
      }
    }

    // Check if all cards in this round have been revealed
    if (cardPlayed.every((c) => c)) {
      for (var s = 0; s < players; s++) {
        scores[s] += 5;
      }
      teamScore += 15;
      if (round < totalRounds) {
        final prevRound = round;
        round++;
        _startRound();
        lastEvent = '🎉 第 $prevRound 轮全员亮牌完成！进入第 $round/$totalRounds 轮【$theme】！';
        host.log(lastEvent);
      } else {
        teamWon = lives > 0;
        phase = 'over';
        lastEvent = '🏆 糸：数字共鸣 $totalRounds 轮完美通关！团队剩余 $lives ❤️，总共鸣分 $teamScore 分！';
        host.log(lastEvent);
      }
    } else {
      nominatedSeat = bestNextSeatFromPublicClues();
    }
  }

  /// Heuristic clue generator for bots (strictly digit-free).
  String heuristicClue(int seat) {
    final v = secretNumber[seat];
    final decile = ((v - 1) ~/ 10).clamp(0, currentScale.length - 1);
    final rem = (v - 1) % 10;
    final item = currentScale[decile];
    if (rem <= 2) return '偏弱的$item';
    if (rem <= 6) return '标准的$item';
    return '极强的$item';
  }

  /// Public clue estimator (uses ONLY public `clues[s]` and `currentScale`, never `secretNumber`!).
  int estimateFromClue(String clue) {
    for (var d = 0; d < currentScale.length; d++) {
      final item = currentScale[d];
      if (clue.contains(item)) {
        var offset = 5;
        if (clue.startsWith('偏弱的') || clue.contains('微') || clue.contains('稍')) {
          offset = 2;
        } else if (clue.startsWith('极强的') || clue.contains('超') || clue.contains('顶')) {
          offset = 9;
        }
        return d * 10 + offset;
      }
    }
    // Fallback lexical sentiment estimate for free-form human/AI clues
    if (RegExp(r'极小|微弱|最低|垫底|白开水|草履虫|蜗牛').hasMatch(clue)) return 8;
    if (RegExp(r'偏小|普通|一般|轻微|日常').hasMatch(clue)) return 30;
    if (RegExp(r'中等|还行|居中|适中').hasMatch(clue)) return 50;
    if (RegExp(r'很|非常|相当|高级|豪华').hasMatch(clue)) return 75;
    if (RegExp(r'极|最|宇宙|巅峰|顶级|无敌|超新星').hasMatch(clue)) return 92;
    return 50;
  }

  /// Deterministically picks the unplayed seat with the lowest estimated clue value.
  int bestNextSeatFromPublicClues() {
    var bestSeat = -1;
    var bestEst = 9999;
    for (var s = 0; s < players; s++) {
      if (cardPlayed[s]) continue;
      final est = estimateFromClue(clues[s] ?? '');
      if (est < bestEst) {
        bestEst = est;
        bestSeat = s;
      }
    }
    return bestSeat;
  }

  Map<String, dynamic>? _aiClue(int seat) {
    final myNum = secretNumber[seat];
    final r = _ai.poll(
      setup.ai!,
      'ito_clue:$round:$seat:$themeIdx',
      () => AiRequest(
        system: '你在玩合作派对桌游《糸 Ito：数字共鸣》。本轮有一个 1 到 100 的主题刻度。'
            '你需要根据你抽到的秘密数字（1~100），给出一个符合该主题的事物或短语作为比喻线索。'
            '严禁包含任何阿拉伯数字（0-9）或百分比！只输出线索词语本身（2~12个字）。',
        prompt: '本轮主题：$theme（$lowLabel ↔ $highLabel）\n你的秘密数字：$myNum（1~100）\n请给出不含数字的比喻线索：',
        maxTokens: 50,
      ),
    );
    if (r.pending) return const {'_pending': true};
    final t = r.text;
    if (t == null) return null;
    var candidate = AiText.firstLine(t, maxLen: 20);
    final j = AiText.json(t);
    if (j != null && j['clue'] is String) {
      candidate = (j['clue'] as String).trim();
    }
    if (candidate.length < 2 || candidate.length > 20 || candidate.startsWith('{')) {
      return null;
    }
    if (validateClue(seat, candidate) != null) {
      return null;
    }
    return {'type': 'clue', 'text': candidate};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    final revealAll = isOver;

    return {
      'round': round,
      'totalRounds': totalRounds,
      'lives': lives,
      'maxLives': maxLives,
      'phase': phase,
      'teamWon': teamWon,
      'theme': theme,
      'lowLabel': lowLabel,
      'highLabel': highLabel,
      'scale': currentScale,
      // Strictly hide other players' unplayed secret numbers!
      'mySecretNumber': validPlayer ? secretNumber[seat] : -1,
      'secretNumbers': [
        for (var s = 0; s < players; s++)
          (revealAll || cardPlayed[s] || s == seat) ? secretNumber[s] : -1,
      ],
      'cardPlayed': List<bool>.of(cardPlayed),
      'clues': {
        for (final e in clues.entries) '${e.key}': e.value,
      },
      'playedCards': playedCards,
      'lastPlayedValue': lastPlayedValue,
      'nominatedSeat': nominatedSeat,
      'scores': List<int>.of(scores),
      'teamScore': teamScore,
      'lastEvent': lastEvent,
      'canClue': !isOver && phase == 'clue' && validPlayer && !clues.containsKey(seat),
      'canPlay': !isOver && phase == 'play' && validPlayer && !cardPlayed[seat],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat < 0 || seat >= players) return null;

    if (phase == 'clue') {
      if (clues.containsKey(seat)) return null;
      if (aiOn) {
        final a = _aiClue(seat);
        if (a != null && a['_pending'] == true) return null;
        if (a != null) return a;
      }
      return {'type': 'clue', 'text': heuristicClue(seat)};
    }

    if (phase == 'play') {
      if (cardPlayed[seat]) return null;
      if (nominatedSeat == seat) {
        return {'type': 'play_card'};
      }
      final best = bestNextSeatFromPublicClues();
      if (seat == best) {
        return {'type': 'play_card'};
      }
      // If the nominated or best seat is a human player, wait for them;
      // if all remaining unplayed seats are bots and best is someone else, let `best` act.
      if (best >= 0 && !isBot(best) && nominatedSeat != best) {
        return {'type': 'nominate', 'target': best};
      }
      return null;
    }

    return null;
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] -= 50;
    teamWon = false;
    phase = 'over';
    lastEvent = '${name(seat)} 中途放弃共鸣挑战，本局结束！';
    host.log(lastEvent);
  }
}
