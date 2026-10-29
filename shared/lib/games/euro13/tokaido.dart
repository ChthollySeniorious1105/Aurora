import 'dart:math';

import '../../src/engine.dart';

const List<String> tokaidoStopNames = [
  '村落',
  '稻田画景',
  '山景画',
  '海景画',
  '温泉',
  '神社',
  '邂逅',
  '农田',
  '旅店',
];

const List<String> tokaidoStopEmojis = [
  '🏘️',
  '🌾',
  '⛰️',
  '🌊',
  '♨️',
  '⛩️',
  '🤝',
  '🪙',
  '🍜',
];

const List<String> tokaidoSouvenirNames = [
  '折扇',
  '和服',
  '人形',
  '茶具',
];

const List<String> tokaidoSouvenirEmojis = [
  '🪭',
  '👘',
  '🎎',
  '🍵',
];

class TokaidoGame extends GameEngine {
  late final int roadLength;
  late List<int> road; // stop types 0..8
  late List<int> innIndices;
  int currentInnStage = 1; // index in innIndices (1..innIndices.length-1)

  late List<int> pos;
  late List<int> arrivalTick;
  int _tickCounter = 0;

  late List<int> coins;
  late List<List<int>> souvenirs; // souvenirs[seat][0..3]
  late List<int> paddy; // 0..3
  late List<int> mountain; // 0..4
  late List<int> sea; // 0..5
  late List<int> hotSpringVp;
  late List<int> templeDonated;
  late List<int> meals;
  late List<int> encounterVp;
  late List<int> achievementVp;
  late List<int> score;

  bool paddyClaimed = false;
  bool mountainClaimed = false;
  bool seaClaimed = false;

  int turn = 0;
  bool over = false;
  String lastAction = '京都启程！踏上江户东海道之旅';

  TokaidoGame(super.setup) : roadLength = setup.opt<int>('roadLength', 27);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  int get currentInnPos => innIndices[currentInnStage];

  int get stopCapacity => players >= 4 ? 2 : 1;

  List<int> _buildRoad(int len) {
    if (len == 20) {
      // 20 stops: Kyoto(0), Inns at 5, 10, 15, Edo(19) -> 3 Intermediate Inns + Final Inn!
      return const [
        8, // 0: Kyoto Start
        7, 0, 1, 4,
        8, // 5: Inn 1
        5, 2, 6, 0,
        8, // 10: Inn 2
        7, 3, 4, 5,
        8, // 15: Inn 3
        1, 2, 3,
        8, // 19: Edo Final Inn
      ];
    }
    // 27 stops: Kyoto(0), Inns at 5, 11, 16, 21, Edo(26) -> 4 Intermediate Inns + Final Inn!
    return const [
      8, // 0: Kyoto Start
      7, 0, 1, 4,
      8, // 5: Inn 1
      5, 2, 6, 0, 3,
      8, // 11: Inn 2
      7, 4, 5, 1,
      8, // 16: Inn 3
      0, 2, 6, 3,
      8, // 21: Inn 4
      7, 5, 4, 3,
      8, // 26: Edo Final Inn
    ];
  }

  @override
  void start() {
    road = _buildRoad(roadLength);
    innIndices = [
      for (var i = 0; i < road.length; i++)
        if (road[i] == 8) i,
    ];
    currentInnStage = 1;

    pos = List.filled(players, 0);
    // Reverse initial arrivalTick so seat 0 is on top of the stack and moves first
    arrivalTick = [for (var s = 0; s < players; s++) players - s];
    _tickCounter = players + 1;

    coins = List.filled(players, 7);
    souvenirs = List.generate(players, (_) => List.filled(4, 0));
    paddy = List.filled(players, 0);
    mountain = List.filled(players, 0);
    sea = List.filled(players, 0);
    hotSpringVp = List.filled(players, 0);
    templeDonated = List.filled(players, 0);
    meals = List.filled(players, 0);
    encounterVp = List.filled(players, 0);
    achievementVp = List.filled(players, 0);
    score = List.filled(players, 0);

    paddyClaimed = false;
    mountainClaimed = false;
    seaClaimed = false;

    turn = computeNextTurn();
  }

  List<int> travelersAtStop(int stopIdx) {
    final list = [
      for (var s = 0; s < players; s++)
        if (pos[s] == stopIdx) s,
    ];
    list.sort((a, b) => arrivalTick[a].compareTo(arrivalTick[b]));
    return list;
  }

  List<int> availableStops(int seat) {
    final cur = pos[seat];
    final limit = currentInnPos;
    if (cur >= limit) return const [];
    final out = <int>[];
    for (var idx = cur + 1; idx <= limit; idx++) {
      if (road[idx] == 8) {
        out.add(idx);
      } else if (travelersAtStop(idx).length < stopCapacity) {
        out.add(idx);
      }
    }
    return out;
  }

  /// Rear-Most Traveler Rule: Whoever is furthest behind (smallest pos) moves next!
  /// If tied at the same stop, the most recently arrived traveler (largest arrivalTick) moves first.
  int computeNextTurn() {
    var bestSeat = -1;
    var bestPos = 999999;
    var bestTick = -1;
    for (var s = 0; s < players; s++) {
      if (pos[s] >= currentInnPos) continue;
      if (pos[s] < bestPos ||
          (pos[s] == bestPos && arrivalTick[s] > bestTick)) {
        bestSeat = s;
        bestPos = pos[s];
        bestTick = arrivalTick[s];
      }
    }
    return bestSeat;
  }

  /// Sets of 1 / 2 / 3 / 4 distinct souvenir types score 1 / 4 / 9 / 16 VP!
  int calcSouvenirScore(int seat) {
    final counts = List<int>.of(souvenirs[seat]);
    var total = 0;
    while (true) {
      var distinct = 0;
      for (var i = 0; i < 4; i++) {
        if (counts[i] > 0) {
          distinct++;
          counts[i]--;
        }
      }
      if (distinct == 0) break;
      total += distinct * distinct; // 1->1, 2->4, 3->9, 4->16
    }
    return total;
  }

  static int _triSum(int n) => (n * (n + 1)) ~/ 2;

  int calcPanoramaScore(int seat) =>
      _triSum(paddy[seat]) + _triSum(mountain[seat]) + _triSum(sea[seat]);

  /// Endgame Temple Majority VP: +10 / +7 / +4 / +2 for 1st / 2nd / 3rd / 4th+ among donors
  int calcTempleMajorityBonus(int seat) {
    final donated = templeDonated[seat];
    if (donated <= 0) return 0;
    const rewards = [10, 7, 4, 2, 2];
    var higherCount = 0;
    for (var s = 0; s < players; s++) {
      if (templeDonated[s] > donated) higherCount++;
    }
    return rewards[min(higherCount, rewards.length - 1)];
  }

  int recalcScore(int seat, {bool includeEndgame = false}) {
    var total = calcSouvenirScore(seat) +
        calcPanoramaScore(seat) +
        hotSpringVp[seat] +
        templeDonated[seat] +
        meals[seat] * 6 +
        encounterVp[seat] +
        achievementVp[seat];
    if (includeEndgame) {
      total += calcTempleMajorityBonus(seat);
    }
    score[seat] = total;
    return total;
  }

  void _gainBestSouvenir(int seat) {
    // Prefer a souvenir type the player has the fewest of, to complete a 4-type set (16 VP)!
    var bestType = 0;
    var minCount = 999;
    for (var t = 0; t < 4; t++) {
      if (souvenirs[seat][t] < minCount) {
        minCount = souvenirs[seat][t];
        bestType = t;
      }
    }
    souvenirs[seat][bestType]++;
  }

  void _advancePanorama(int seat, int stopType) {
    if (stopType == 1) {
      if (paddy[seat] < 3) {
        paddy[seat]++;
        if (paddy[seat] == 3 && !paddyClaimed) {
          paddyClaimed = true;
          achievementVp[seat] += 3;
        }
      } else {
        encounterVp[seat] += 2;
      }
    } else if (stopType == 2) {
      if (mountain[seat] < 4) {
        mountain[seat]++;
        if (mountain[seat] == 4 && !mountainClaimed) {
          mountainClaimed = true;
          achievementVp[seat] += 3;
        }
      } else {
        encounterVp[seat] += 2;
      }
    } else if (stopType == 3) {
      if (sea[seat] < 5) {
        sea[seat]++;
        if (sea[seat] == 5 && !seaClaimed) {
          seaClaimed = true;
          achievementVp[seat] += 3;
        }
      } else {
        encounterVp[seat] += 2;
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('旅途已结束');
    if (seat != turn) throw GameError('按照最落后旅人行动规则，尚未轮到你移动');

    final type = asStr(action['type']);
    if (type != 'move') throw GameError('未知操作: $type');

    final target = asInt(action['stop'], -1);
    final avail = availableStops(seat);
    if (!avail.contains(target)) {
      throw GameError('不可前往该站点（必须向前且不可越过前方必停旅店）');
    }

    pos[seat] = target;
    arrivalTick[seat] = _tickCounter++;

    final stopType = road[target];
    var detail = '';

    switch (stopType) {
      case 0: // 🏘️ 村落 Village: buy 1..3 Souvenirs
        final want = asInt(action['souvenirs'], min(3, max(1, coins[seat]))).clamp(1, 3);
        final canBuy = min(want, coins[seat]);
        if (canBuy > 0) {
          coins[seat] -= canBuy;
          for (var i = 0; i < canBuy; i++) {
            _gainBestSouvenir(seat);
          }
          detail = '在村落购入 $canBuy 件纪念品 (-$canBuy🪙)';
        } else {
          _gainBestSouvenir(seat);
          detail = '在村落获赠 1 件乡土纪念品';
        }
        break;

      case 1: // 🌾 稻田画景 (1..3 VP)
        _advancePanorama(seat, 1);
        detail = '描绘稻田画景 (${paddy[seat]}/3)';
        break;

      case 2: // ⛰️ 山景画 (1..4 VP)
        _advancePanorama(seat, 2);
        detail = '描绘富岳山景 (${mountain[seat]}/4)';
        break;

      case 3: // 🌊 海景画 (1..5 VP)
        _advancePanorama(seat, 3);
        detail = '描绘沧海画景 (${sea[seat]}/5)';
        break;

      case 4: // ♨️ 温泉 Hot Spring (+2..3 VP)
        final vp = 2 + (rng.nextInt(2)); // 2 or 3 VP
        hotSpringVp[seat] += vp;
        detail = '沐浴名汤温泉 (+$vp 分)';
        break;

      case 5: // ⛩️ 神社 Temple (donate 1..3 Coins for +1 VP each + Endgame Majority)
        final reqDonate = asInt(action['donate'], min(2, max(1, coins[seat]))).clamp(1, 3);
        final donate = min(reqDonate, coins[seat]);
        if (donate > 0) {
          coins[seat] -= donate;
          templeDonated[seat] += donate;
          detail = '参拜神社供奉 $donate 枚金币 (+$donate 分)';
        } else {
          templeDonated[seat] += 1;
          detail = '虔诚参拜神社祈福 (+1 供奉)';
        }
        break;

      case 6: // 🤝 邂逅 Encounter (+3 VP / +3 Coins / +1 Panorama / +1 Shrine Coin)
        final roll = (target + seat + _tickCounter) % 4;
        if (roll == 0) {
          encounterVp[seat] += 3;
          detail = '邂逅公家贵人 (+3 分)';
        } else if (roll == 1) {
          coins[seat] += 3;
          detail = '邂逅豪商大名 (+3🪙)';
        } else if (roll == 2) {
          // Advance the panorama closest to completion
          if (sea[seat] < 5) {
            _advancePanorama(seat, 3);
            detail = '邂逅浮世绘师 (获赠海景画卷)';
          } else if (mountain[seat] < 4) {
            _advancePanorama(seat, 2);
            detail = '邂逅浮世绘师 (获赠山景画卷)';
          } else {
            _advancePanorama(seat, 1);
            detail = '邂逅浮世绘师 (获赠稻田画卷)';
          }
        } else {
          templeDonated[seat] += 1;
          encounterVp[seat] += 1;
          detail = '邂逅神社巫女 (+1 神社供奉 +1 分)';
        }
        break;

      case 7: // 🪙 农田 Farm (+3 Gold Coins)
        coins[seat] += 3;
        detail = '农田劳作 (+3🪙)';
        break;

      case 8: // 🍜 旅店 Inn (mandatory stop: buy Meal Card 6 VP for 1..3 Coins)
        final buyMeal = action['buyMeal'] != false;
        final mealCost = asInt(action['mealCost'], min(2, max(1, coins[seat]))).clamp(1, 3);
        if (buyMeal && coins[seat] >= 1) {
          final actualCost = min(mealCost, coins[seat]);
          coins[seat] -= actualCost;
          meals[seat]++;
          detail = '抵达旅店宿场，品尝乡土料理 (+6 分, -$actualCost🪙)';
        } else {
          detail = '抵达旅店宿场歇息';
        }
        break;
    }

    recalcScore(seat, includeEndgame: false);
    lastAction = '${name(seat)} 前进至第 $target 站【${tokaidoStopNames[stopType]}】：$detail';
    host.log(lastAction);

    _advanceTurnOrInn();
  }

  void _advanceTurnOrInn() {
    var next = computeNextTurn();
    while (next == -1) {
      // Everyone has reached currentInnPos!
      if (currentInnStage >= innIndices.length - 1) {
        over = true;
        _finalizeEndgameScoring();
        return;
      }
      currentInnStage++;
      next = computeNextTurn();
    }
    turn = next;
  }

  void _finalizeEndgameScoring() {
    // Award Gourmet, Bathhouse, Chatterbox, Collector achievements (+3 VP each)
    _awardMaxAchievement(meals);
    _awardMaxAchievement(hotSpringVp);
    _awardMaxAchievement(encounterVp);
    final souvCounts = [
      for (var s = 0; s < players; s++)
        souvenirs[s].fold<int>(0, (a, b) => a + b),
    ];
    _awardMaxAchievement(souvCounts);

    for (var s = 0; s < players; s++) {
      recalcScore(s, includeEndgame: true);
    }
    lastAction = '全员抵达江户终点！结算神社供奉排行与旅途成就';
    host.log(lastAction);
  }

  void _awardMaxAchievement(List<int> metric) {
    final maxVal = metric.fold<int>(0, max);
    if (maxVal <= 0) return;
    for (var s = 0; s < players; s++) {
      if (metric[s] == maxVal) {
        achievementVp[s] += 3;
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final avail = availableStops(seat);
    if (avail.isEmpty) return null;

    if (botLevel == 0) {
      return {'type': 'move', 'stop': avail.first};
    }

    // Prefer stepping only 1..2 stops ahead to maximize total stops visited along the road!
    var bestStop = avail.first;
    var bestScore = -9999;
    for (final stopIdx in avail) {
      final dist = stopIdx - pos[seat];
      final st = road[stopIdx];
      var val = -dist * 3; // Taking smaller steps gives more turns!
      switch (st) {
        case 0: // Village
          val += coins[seat] >= 2 ? 12 : 4;
          break;
        case 1:
          val += paddy[seat] < 3 ? (paddy[seat] + 1) * 4 : 3;
          break;
        case 2:
          val += mountain[seat] < 4 ? (mountain[seat] + 1) * 4 : 3;
          break;
        case 3:
          val += sea[seat] < 5 ? (sea[seat] + 1) * 4 : 3;
          break;
        case 4: // Hot Spring
          val += 9;
          break;
        case 5: // Temple
          val += coins[seat] >= 2 ? 11 : 5;
          break;
        case 6: // Encounter
          val += 10;
          break;
        case 7: // Farm
          val += coins[seat] <= 2 ? 13 : 6;
          break;
        case 8: // Inn
          val -= 6; // Only go to Inn when closer stops are full or worth less
          break;
      }
      if (val > bestScore) {
        bestScore = val;
        bestStop = stopIdx;
      }
    }

    return {
      'type': 'move',
      'stop': bestStop,
      'donate': min(2, max(1, coins[seat])),
      'souvenirs': min(2, max(1, coins[seat])),
      'buyMeal': true,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final avail = (!over && seat >= 0 && seat < players && seat == turn)
        ? availableStops(seat)
        : const <int>[];
    return {
      'roadLength': road.length,
      'road': List<int>.of(road),
      'innIndices': List<int>.of(innIndices),
      'currentInnPos': currentInnPos,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'availableStops': avail,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'pos': pos[s],
            'arrivalTick': arrivalTick[s],
            'coins': coins[s],
            'souvenirs': List<int>.of(souvenirs[s]),
            'souvenirVp': calcSouvenirScore(s),
            'paddy': paddy[s],
            'mountain': mountain[s],
            'sea': sea[s],
            'hotSpringVp': hotSpringVp[s],
            'templeDonated': templeDonated[s],
            'templeBonus': calcTempleMajorityBonus(s),
            'meals': meals[s],
            'achievementVp': achievementVp[s],
            'score': score[s],
          },
      ],
    };
  }
}
