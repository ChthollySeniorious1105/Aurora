import 'dart:math';

import '../../src/engine.dart';

class TacoCatGame extends GameEngine {
  TacoCatGame(super.setup);

  static const List<Map<String, Object>> cardDefs = [
    {'id': 0, 'name': '塔可 (Taco)', 'short': '塔可', 'emoji': '🌮', 'special': false},
    {'id': 1, 'name': '猫咪 (Cat)', 'short': '猫咪', 'emoji': '🐱', 'special': false},
    {'id': 2, 'name': '山羊 (Goat)', 'short': '山羊', 'emoji': '🐐', 'special': false},
    {'id': 3, 'name': '起司 (Cheese)', 'short': '起司', 'emoji': '🧀', 'special': false},
    {'id': 4, 'name': '披萨 (Pizza)', 'short': '披萨', 'emoji': '🍕', 'special': false},
    {'id': 5, 'name': '大猩猩 (Gorilla)', 'short': '大猩猩', 'emoji': '🦍', 'special': true, 'pose': 'pose_gorilla', 'poseLabel': '🦍捶胸拍桌'},
    {'id': 6, 'name': '土拨鼠 (Groundhog)', 'short': '土拨鼠', 'emoji': '🦫', 'special': true, 'pose': 'pose_groundhog', 'poseLabel': '🦫敲桌拍桌'},
    {'id': 7, 'name': '独角鲸 (Narwhal)', 'short': '独角鲸', 'emoji': '🐳', 'special': true, 'pose': 'pose_narwhal', 'poseLabel': '🐳头顶拍手'},
  ];

  static const List<Map<String, String>> actionDefs = [
    {'key': 'slap', 'label': '✋ 拍桌 (词牌一致!)', 'emoji': '✋'},
    {'key': 'hold', 'label': '🙅 忍住不拍 (词牌不符)', 'emoji': '🙅'},
    {'key': 'pose_gorilla', 'label': '🦍 捶胸拍桌 (大猩猩)', 'emoji': '🦍'},
    {'key': 'pose_groundhog', 'label': '🦫 敲桌拍桌 (土拨鼠)', 'emoji': '🦫'},
    {'key': 'pose_narwhal', 'label': '🐳 头顶拍手 (独角鲸)', 'emoji': '🐳'},
  ];

  static const Set<String> validActions = {
    'slap',
    'hold',
    'pose_gorilla',
    'pose_groundhog',
    'pose_narwhal',
  };

  int totalRounds = 12;
  int round = 1;
  int flipperSeat = 0;

  /// Current spoken mantra word index in `0..4` (0:🌮 -> 1:🐱 -> 2:🐐 -> 3:🧀 -> 4:🍕).
  int spokenWord = 0;

  /// Current flipped central card type in `0..7`.
  int cardType = 0;

  /// Number of cards accumulated in the central slap/penalty pile.
  int pileCount = 1;

  String phase = 'react'; // 'react' | 'over'

  /// Each seat's remaining personal deck count (lower is better!).
  late List<int> personalDeck;

  /// Each seat's score (higher is better; synchronized with personalDeck + accuracy).
  late List<int> scores;

  /// Current round's submitted reactions: `seat -> actionKey`.
  final Map<int, String> reactions = {};

  /// Order in which seats reacted in the current round.
  final List<int> reactionOrder = [];

  Map<String, dynamic>? lastRoundSummary;
  String lastEvent = '塔可猫羊起司披萨开启！念出咒语翻开卡牌，词牌一致立即拍桌，特殊动物做出招牌动作！';

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
    if (phase == 'react') {
      return [
        for (var s = 0; s < players; s++)
          if (!reactions.containsKey(s)) s,
      ];
    }
    return const [];
  }

  static String cardLabel(int c) {
    if (c < 0 || c >= cardDefs.length) return '❓未知卡';
    return '${cardDefs[c]['emoji']}${cardDefs[c]['short']}';
  }

  static String actionLabel(String key) {
    for (final a in actionDefs) {
      if (a['key'] == key) return a['label']!;
    }
    return key;
  }

  /// Expected correct reaction for the current (`spokenWord`, `cardType`) pair.
  static String expectedReactionFor(int spoken, int card) {
    if (card == 5) return 'pose_gorilla';
    if (card == 6) return 'pose_groundhog';
    if (card == 7) return 'pose_narwhal';
    if (card == spoken) return 'slap';
    return 'hold';
  }

  String get expectedReaction => expectedReactionFor(spokenWord, cardType);

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 12);
    round = 1;
    flipperSeat = 0;
    personalDeck = List<int>.filled(players, 10);
    scores = List<int>.filled(players, 30);
    pileCount = 0;
    lastRoundSummary = null;
    _flipNextCard(first: true);
    host.log('【塔可猫羊起司披萨】欢乐反应派对开始！共 $totalRounds 轮，每人初始 10 张个人牌库！');
  }

  void _flipNextCard({bool first = false}) {
    spokenWord = (round - 1) % 5;
    flipperSeat = (round - 1) % players;
    pileCount++;

    // Make matches and special cards happen frequently for exciting party gameplay!
    final roll = rng.nextInt(100);
    if (roll < 30) {
      cardType = spokenWord; // Exact Mantra Match!
    } else if (roll < 55) {
      cardType = 5 + rng.nextInt(3); // Special Animal (5:🦍, 6:🦫, 7:🐳)!
    } else {
      cardType = rng.nextInt(5); // Any Mantra card 0..4
    }

    reactions.clear();
    reactionOrder.clear();
    phase = 'react';

    lastEvent =
        '第 $round/$totalRounds 轮：🗣️ 咒语念出【${cardLabel(spokenWord)}】，翻开牌面【${cardLabel(cardType)}】（中央牌堆 $pileCount 张）——请全员立即反应！';
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (phase != 'react') throw GameError('当前不在反应阶段');
    if (reactions.containsKey(seat)) throw GameError('你本轮已经做出反应了');

    final rawType = asStr(action['type']);
    final actKey = rawType == 'react' ? asStr(action['action']) : rawType;
    if (!validActions.contains(actKey)) {
      throw GameError('未知反应动作：$actKey');
    }

    reactions[seat] = actKey;
    reactionOrder.add(seat);

    if (reactions.length >= players) {
      _resolveRound();
    } else {
      lastEvent =
          '⚡ ${name(seat)} 已做出反应（已完成 ${reactions.length}/$players 人）！';
    }
  }

  void _resolveRound() {
    final expected = expectedReaction;
    final correctSeats = <int>[
      for (final s in reactionOrder)
        if (reactions[s] == expected) s,
    ];
    final wrongSeats = <int>[
      for (final s in reactionOrder)
        if (reactions[s] != expected) s,
    ];

    final currentPile = pileCount;
    var summaryMsg = '';
    final penalizedSeats = <int>[];

    if (expected != 'hold') {
      // Active slap or special animal pose round!
      for (var i = 0; i < correctSeats.length; i++) {
        final s = correctSeats[i];
        final shed = i == 0 ? 2 : 1; // Fastest accurate player sheds 2 cards!
        personalDeck[s] = max(0, personalDeck[s] - shed);
        scores[s] += (i == 0 ? 5 : 2);
      }

      if (wrongSeats.isNotEmpty) {
        // Players who made the wrong reaction absorb the central penalty pile!
        for (final w in wrongSeats) {
          personalDeck[w] += currentPile;
          scores[w] -= currentPile * 2;
          penalizedSeats.add(w);
        }
        pileCount = 0;
        final fastInfo = correctSeats.isNotEmpty
            ? '${name(correctSeats.first)} 最快做出正确反应【${actionLabel(expected)}】甩掉 2 张牌；'
            : '';
        summaryMsg =
            '💥 咒语【${cardLabel(spokenWord)}】vs 牌面【${cardLabel(cardType)}】：$fastInfo${wrongSeats.map(name).join("、")} 反应失误，收下中央 $currentPile 张罚牌！';
      } else {
        // Everyone reacted accurately -> the SLOWEST player absorbs the central penalty pile!
        final slowest = reactionOrder.last;
        personalDeck[slowest] += currentPile;
        scores[slowest] -= currentPile;
        penalizedSeats.add(slowest);
        pileCount = 0;
        summaryMsg =
            '✋ 全员反应正确【${actionLabel(expected)}】！${name(reactionOrder.first)} 手速第一甩掉 2 张牌，手速最慢的 ${name(slowest)} 收下中央 $currentPile 张牌！';
      }
    } else {
      // Non-match normal card: players must HOLD ('hold') and NOT flinch!
      for (final s in correctSeats) {
        personalDeck[s] = max(0, personalDeck[s] - 1);
        scores[s] += 2;
      }

      if (wrongSeats.isNotEmpty) {
        // Anyone who flinched (slapped/posed on a non-match) absorbs the penalty pile!
        for (final w in wrongSeats) {
          personalDeck[w] += currentPile;
          scores[w] -= currentPile * 2;
          penalizedSeats.add(w);
        }
        pileCount = 0;
        summaryMsg =
            '🙅 虚晃一枪！咒语【${cardLabel(spokenWord)}】vs 牌面【${cardLabel(cardType)}】不匹配，${wrongSeats.map(name).join("、")} 假动作误拍，收下中央 $currentPile 张罚牌！';
      } else {
        // Everyone held back calmly -> pile stays in the center and accumulates!
        summaryMsg =
            '😌 全员稳如泰山忍住不拍！各自成功消耗 1 张手牌，中央牌堆累积至 $pileCount 张！';
      }
    }

    lastRoundSummary = {
      'round': round,
      'spokenWord': spokenWord,
      'cardType': cardType,
      'expected': expected,
      'correctSeats': correctSeats,
      'wrongSeats': wrongSeats,
      'penalizedSeats': penalizedSeats,
      'pileAbsorbed': currentPile,
    };

    host.log(summaryMsg);

    if (round < totalRounds) {
      round++;
      _flipNextCard();
      lastEvent = '$summaryMsg · 🔄 第 $round/$totalRounds 轮：🗣️【${cardLabel(spokenWord)}】vs 🃏【${cardLabel(cardType)}】！';
    } else {
      // Sync final scores so lowest personalDeck + accuracy bonus determines placings cleanly
      for (var s = 0; s < players; s++) {
        scores[s] += (20 - personalDeck[s]) * 3;
      }
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent =
          '$summaryMsg · 🏆 $totalRounds 轮闪电反应对决结束！${name(bestSeat)}（剩余 ${personalDeck[bestSeat]} 张牌 / ${scores[bestSeat]} 分）夺得派对反应王！';
      host.log(lastEvent);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;

    return {
      'round': round,
      'totalRounds': totalRounds,
      'flipperSeat': flipperSeat,
      'spokenWord': spokenWord,
      'cardType': cardType,
      'pileCount': pileCount,
      'phase': phase,
      'cardDefs': cardDefs,
      'actionDefs': actionDefs,
      'personalDeck': List<int>.of(personalDeck),
      'scores': List<int>.of(scores),
      'myReaction': validPlayer ? reactions[seat] : null,
      'reactedSeats': List<int>.of(reactionOrder),
      'lastRoundSummary': lastRoundSummary,
      'lastEvent': lastEvent,
      'canReact': !isOver && phase == 'react' && validPlayer && !reactions.containsKey(seat),
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || phase != 'react' || reactions.containsKey(seat)) return null;

    final expected = expectedReaction;
    // Easy bots occasionally flinch or pick the wrong pose; hard/normal bots are sharp
    final mistakeChance = switch (botLevel) {
      0 => 0.25,
      2 => 0.03,
      _ => 0.10,
    };
    if (rng.nextDouble() < mistakeChance) {
      final wrongOptions = validActions.where((a) => a != expected).toList();
      final pick = wrongOptions[rng.nextInt(wrongOptions.length)];
      return {'type': 'react', 'action': pick};
    }
    return {'type': 'react', 'action': expected};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    lastEvent = '${name(seat)} 放弃反应对决，游戏结束！';
    host.log(lastEvent);
  }
}
