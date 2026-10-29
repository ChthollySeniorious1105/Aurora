import 'dart:math';

import '../../src/engine.dart';

const List<String> trekkingTokenNames = [
  '人物',
  '事件',
  '发明',
  '文明',
  '百搭',
];

const List<String> trekkingTokenEmojis = [
  '👤',
  '📜',
  '🔬',
  '🏛️',
  '🌟',
];

class TrekkingEventCard {
  final int id;
  final int dayDeck; // 1, 2, or 3
  final String title;
  final String emoji;
  final int year; // -3000..2000
  final int hours; // 1..5
  final List<int> tokens; // indices in 0..4

  const TrekkingEventCard({
    required this.id,
    required this.dayDeck,
    required this.title,
    required this.emoji,
    required this.year,
    required this.hours,
    required this.tokens,
  });

  String get yearLabel => year < 0 ? '公元前 ${-year} 年' : '公元 $year 年';

  String get tokensLabel =>
      tokens.map((t) => trekkingTokenEmojis[t.clamp(0, 4)]).join('');

  Map<String, dynamic> toJson() => {
        'id': id,
        'dayDeck': dayDeck,
        'title': title,
        'emoji': emoji,
        'year': year,
        'yearLabel': yearLabel,
        'hours': hours,
        'tokens': tokens,
        'tokensLabel': tokensLabel,
      };
}

class TrekkingHistoryGame extends GameEngine {
  static const int maxHoursPerDay = 12;
  static const int riverSize = 6;
  static const List<int> trekScoreTable = [0, 0, 1, 3, 6, 10, 15, 21, 28];

  late final int maxDays;
  late List<TrekkingEventCard> deck;
  late List<TrekkingEventCard> market;
  late List<int> hourPos; // 0..12 on the Pocket-Watch track
  late List<int?> currentTrekLastYear;
  late List<int> trekLen;
  late List<int> completedTrekVp;
  late List<List<int>> completedTreks;
  late List<List<int>> itinerary; // counts of [人物, 事件, 发明, 文明, 百搭]
  late List<int> itineraryVp;
  late List<int> punctualityVp;
  late List<int> crystals; // 💎 Time Crystals
  late List<int> score;

  int day = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '穿越历史时空之旅开启';

  TrekkingHistoryGame(super.setup) : maxDays = setup.opt<int>('days', 3);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static int trekVpForLength(int len) {
    if (len <= 0) return 0;
    if (len < trekScoreTable.length) return trekScoreTable[len];
    return 28 + (len - 8) * 7;
  }

  List<TrekkingEventCard> _buildDeck() {
    const templates = [
      // Chronologically diverse historical landmarks from 3000 BCE to 2000 CE
      ('胡夫金字塔落成', '🔺', -2560, 2, [3, 2]),
      ('汉谟拉比法典颁布', '⚖️', -1750, 2, [1, 3]),
      ('商朝甲骨文记载', '🐢', -1200, 3, [2, 3]),
      ('荷马史诗传唱', '🏺', -750, 2, [0, 1]),
      ('孔子周游列国', '🎋', -497, 3, [0, 3]),
      ('雅典帕特农神庙', '🏛️', -432, 2, [3, 1]),
      ('亚历山大东征', '🐎', -334, 4, [0, 1, 3]),
      ('秦始皇统一六国', '👑', -221, 3, [0, 1]),
      ('阿基米德螺旋泵', '⚙️', -212, 2, [0, 2]),
      ('丝绸之路开辟', '🐪', -138, 3, [1, 3]),
      ('罗马斗兽场竣工', '🏟️', 80, 2, [3, 1]),
      ('蔡伦改进造纸术', '📜', 105, 3, [0, 2]),
      ('张衡发明地动仪', '🐉', 132, 2, [2, 4]),
      ('查士丁尼民法大全', '📖', 529, 2, [1, 3]),
      ('唐三藏西行取经', '🏮', 629, 3, [0, 1]),
      ('毕昇活字印刷术', '🔠', 1041, 3, [0, 2]),
      ('大宪章签署', '🪶', 1215, 2, [1, 3]),
      ('马可波罗抵达东方', '🧭', 1275, 3, [0, 1]),
      ('郑和七下西洋', '⛵', 1405, 4, [0, 1, 3]),
      ('古腾堡印刷机问世', '📚', 1440, 2, [2, 1]),
      ('达芬奇绘制蒙娜丽莎', '🎨', 1503, 3, [0, 4]),
      ('麦哲伦环球航行', '🌍', 1519, 4, [0, 1, 2]),
      ('伽利略天文望远镜', '🔭', 1609, 2, [0, 2]),
      ('牛顿发表自然哲学的数学原理', '🍎', 1687, 3, [0, 2]),
      ('瓦特改良蒸汽机', '🚂', 1776, 3, [2, 1]),
      ('居里夫人发现镭元素', '⚗️', 1898, 3, [0, 2]),
      ('莱特兄弟首次飞行', '✈️', 1903, 2, [2, 1]),
      ('阿波罗11号登月', '🚀', 1969, 4, [1, 2, 4]),
    ];
    final list = <TrekkingEventCard>[];
    var id = 1;
    for (final (title, em, yr, hrs, toks) in templates) {
      list.add(TrekkingEventCard(
        id: id++,
        dayDeck: 1,
        title: title,
        emoji: em,
        year: yr,
        hours: hrs,
        tokens: toks,
      ));
    }
    return shuffled(list, rng);
  }

  void _refillMarket() {
    while (market.length < riverSize && deck.isNotEmpty) {
      market.add(deck.removeLast());
    }
  }

  /// Rear-Most Time Traveler rule: player with minimum `hourPos[s] < 12` acts next.
  int computeRearMostSeat() {
    var bestSeat = -1;
    var minHour = 999;
    for (var s = 0; s < players; s++) {
      if (hourPos[s] < maxHoursPerDay && hourPos[s] < minHour) {
        minHour = hourPos[s];
        bestSeat = s;
      }
    }
    return bestSeat;
  }

  @override
  void start() {
    deck = _buildDeck();
    market = [];
    _refillMarket();

    hourPos = List.filled(players, 0);
    currentTrekLastYear = List.filled(players, null);
    trekLen = List.filled(players, 0);
    completedTrekVp = List.filled(players, 0);
    completedTreks = List.generate(players, (_) => <int>[]);
    itinerary = List.generate(players, (_) => List.filled(5, 0));
    itineraryVp = List.filled(players, 0);
    punctualityVp = List.filled(players, 0);
    crystals = List.filled(players, 1); // Each player starts with 1 💎 Time Crystal
    score = List.filled(players, 1);

    day = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 日开启，怀表指针位于 0 时，请探访历史事件';
  }

  int calcTotalScore(int seat) =>
      completedTrekVp[seat] +
      trekVpForLength(trekLen[seat]) +
      itineraryVp[seat] +
      punctualityVp[seat] +
      crystals[seat];

  void _applyItineraryTokens(int seat, List<int> tokens) {
    final prevTotal = itinerary[seat].fold<int>(0, (a, b) => a + b);
    for (final t in tokens) {
      final idx = t.clamp(0, 4);
      itinerary[seat][idx]++;
      itineraryVp[seat] += 1;
    }
    final newTotal = itinerary[seat].fold<int>(0, (a, b) => a + b);
    // Every 3 experience tokens collected on the Itinerary grants +1 💎 Time Crystal and +2 VP!
    final crossedMilestones = (newTotal ~/ 3) - (prevTotal ~/ 3);
    if (crossedMilestones > 0) {
      crystals[seat] += crossedMilestones;
      itineraryVp[seat] += crossedMilestones * 2;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    if (hourPos[seat] >= maxHoursPerDay) {
      throw GameError('你今日的 12 小时行程已满');
    }

    final type = asStr(action['type']);
    if (type != 'visit') {
      throw GameError('未知操作: $type');
    }

    final slot = asInt(action['slot'], -99);
    final useCrystals = asInt(action['useCrystals'], 0);
    if (useCrystals < 0 || useCrystals > crystals[seat]) {
      throw GameError('时间水晶 (💎) 数量无效或不足');
    }

    TrekkingEventCard card;
    var isAncestor = false;
    if (slot == -1) {
      // Ancestor Card: continues current Trek without breaking chronological order!
      isAncestor = true;
      card = TrekkingEventCard(
        id: 0,
        dayDeck: day,
        title: '远古先祖足迹',
        emoji: '🧭',
        year: currentTrekLastYear[seat] ?? -3000,
        hours: 3,
        tokens: const [4],
      );
    } else {
      if (slot < 0 || slot >= market.length) {
        throw GameError('无效的历史事件卡槽位');
      }
      card = market.removeAt(slot);
      _refillMarket();
    }

    final effectiveHours = max(1, card.hours - useCrystals);
    crystals[seat] -= useCrystals;

    final prevHour = hourPos[seat];
    final rawNewHour = prevHour + effectiveHours;
    var punctualBonus = false;
    if (rawNewHour == maxHoursPerDay) {
      punctualityVp[seat] += 3;
      punctualBonus = true;
    }
    hourPos[seat] = min(maxHoursPerDay, rawNewHour);

    // Chronological Trek Streak calculation
    final lastYr = currentTrekLastYear[seat];
    var startedNewTrek = false;
    var scoredOldTrekVp = 0;
    if (isAncestor || lastYr == null || card.year >= lastYr) {
      trekLen[seat] += 1;
      currentTrekLastYear[seat] = card.year;
    } else {
      scoredOldTrekVp = trekVpForLength(trekLen[seat]);
      completedTrekVp[seat] += scoredOldTrekVp;
      completedTreks[seat].add(trekLen[seat]);
      trekLen[seat] = 1;
      currentTrekLastYear[seat] = card.year;
      startedNewTrek = true;
    }

    _applyItineraryTokens(seat, card.tokens);
    score[seat] = calcTotalScore(seat);

    final crystalStr = useCrystals > 0 ? ' (消耗$useCrystals💎)' : '';
    final trekStr = startedNewTrek
        ? '，旧旅程结算+$scoredOldTrekVp分并开启新旅程'
        : '，连续旅程增至${trekLen[seat]}张';
    final puncStr = punctualBonus ? '，精准抵达12时+3分！' : '';
    lastAction =
        '${name(seat)} 探访「${card.emoji}${card.title} (${card.yearLabel})」耗时$effectiveHours小时$crystalStr$trekStr$puncStr';
    host.log(lastAction);

    _advanceTimeTrack();
  }

  void _advanceTimeTrack() {
    final nextSeat = computeRearMostSeat();
    if (nextSeat >= 0) {
      turn = nextSeat;
      return;
    }

    // All players have reached hour 12!
    if (day >= maxDays || market.isEmpty) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcTotalScore(s);
      }
      lastAction = '三日穿越之旅圆满结束！总分最高的时间旅行者获胜';
      host.log(lastAction);
      return;
    }

    day++;
    for (var s = 0; s < players; s++) {
      hourPos[s] = 0;
    }
    _refillMarket();
    turn = 0;
    lastAction = '进入第 $day 日，所有旅行者怀表归零 (0/12 时)';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    if (market.isEmpty) {
      return {'type': 'visit', 'slot': -1, 'useCrystals': 0};
    }

    final lastYr = currentTrekLastYear[seat];
    final curLen = trekLen[seat];
    final remHours = maxHoursPerDay - hourPos[seat];

    var bestSlot = 0;
    var bestCrystals = 0;
    var bestVal = -999999;

    for (var s = 0; s < market.length; s++) {
      final c = market[s];
      for (var k = 0; k <= min(crystals[seat], c.hours - 1); k++) {
        final effH = max(1, c.hours - k);
        var val = c.tokens.length * 4 - effH * 2 - k * 2;
        if (lastYr == null || c.year >= lastYr) {
          final nextDelta =
              trekVpForLength(curLen + 1) - trekVpForLength(curLen);
          val += 12 + nextDelta * 5;
          // Prefer smaller year jumps so future cards still fit chronologically
          if (lastYr != null) {
            val -= ((c.year - lastYr) ~/ 250);
          } else {
            val -= ((c.year + 3000) ~/ 300);
          }
        } else {
          // Breaking a long trek is fine, breaking a short trek is penalized
          if (curLen <= 2) val -= 10;
        }
        if (effH == remHours) {
          val += 10; // Punctuality +3 VP bonus!
        }
        if (val > bestVal) {
          bestVal = val;
          bestSlot = s;
          bestCrystals = k;
        }
      }
    }

    return {
      'type': 'visit',
      'slot': bestSlot,
      'useCrystals': bestCrystals,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'day': day,
      'maxDays': maxDays,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'market': [for (final c in market) c.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'hourPos': hourPos[s],
            'currentTrekLastYear': currentTrekLastYear[s],
            'trekLen': trekLen[s],
            'activeTrekVp': trekVpForLength(trekLen[s]),
            'completedTrekVp': completedTrekVp[s],
            'completedTreks': List<int>.of(completedTreks[s]),
            'itinerary': List<int>.of(itinerary[s]),
            'itineraryVp': itineraryVp[s],
            'punctualityVp': punctualityVp[s],
            'crystals': crystals[s],
          },
      ],
    };
  }
}
