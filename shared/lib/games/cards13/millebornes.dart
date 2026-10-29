import '../../src/engine.dart';

const String milleBornesRules = '''
# 千里之行 Mille Bornes 规则说明

## 基本配置
- **人数**：2～4 人。
- **目标里程（`target`）**：可选 **1000 km 标准** 或 **700 km 快速**。
- **牌堆（共 106 张）**：
  - **里程牌（Distance，46 张）**：`D25`（25km×10）、`D50`（50km×10）、`D75`（75km×10）、`D100`（100km×12）、`D200`（200km×4）。
  - **故障牌（Hazards，18 张）**：`H_STOP`（红灯×5）、`H_LIMIT`（限速50×4）、`H_GAS`（没油×3）、`H_TIRE`（爆胎×3）、`H_ACC`（车祸×3）。
  - **排除牌（Remedies，38 张）**：`R_ROLL`（绿灯×14）、`R_LIMIT`（解除限速×6）、`R_GAS`（加油×6）、`R_TIRE`（备胎×6）、`R_ACC`（修理×6）。
  - **王牌安全卡（Safeties，4 张）**：`S_ROW`（优先通行权）、`S_GAS`（副油箱）、`S_TIRE`（防爆胎）、`S_ACC`（王牌车手）。

## 对局流程与出牌规则
- 开局每人 6 张手牌；轮到自己回合时自动摸 1 张牌（手牌变为 7 张），随后必须 **打出 1 张牌（`'play'`）** 或 **弃掉 1 张牌（`'discard'`）**（手牌恢复 6 张）。
1. **里程牌（`D25..D200`）**：
   - 必须处于 **行驶状态（`rolling == true`）**（或已打出 `S_ROW` 优先通行权）且无未解除的故障牌。
   - 累计里程 **不能超过目标里程 `target`**（必须刚好抵达 `target`）。
   - 每位玩家整局最多只能打出 **2 张 `D200`**。
   - 若处于 **限速状态（`speedLimit == true`）**，只能打出 `D25` 或 `D50`！
2. **故障牌（`H_*`，对一名对手 `targetSeat` 使用）**：
   - `H_STOP`（红灯）、`H_GAS`（没油）、`H_TIRE`（爆胎）、`H_ACC`（车祸）会使目标对手停止行驶（`rolling = false`）并挂上对应故障；`H_LIMIT` 会给对手挂上限速（`speedLimit = true`）。
   - 若对手已拥有对应的 **王牌安全卡**，则免疫该类故障！
3. **排除牌（`R_*`，对自己使用）**：
   - `R_GAS`、`R_TIRE`、`R_ACC` 可解除对应的没油、爆胎、车祸故障（解除后仍需打出 `R_ROLL` 绿灯才能恢复行驶，除非拥有 `S_ROW`）。
   - `R_ROLL`（绿灯）可在无故障时启动或解除红灯恢复行驶（`rolling = true`）。
   - `R_LIMIT`（解除限速）可移除 `H_LIMIT`（`speedLimit = false`）。
4. **王牌安全卡（`S_*`）与反击（Coup-Fourré）**：
   - 打出王牌后永久免疫对应故障（`S_ROW` 同时免疫红灯与限速，并永久保持绿灯行驶状态），立即清除已有的对应故障，获得 **+100 分奖励**，并 **立即获得一个额外回合**！
   - **绝妙反击（Coup-Fourré）**：当对手刚对你打出故障牌时，若你手中持有对应的王牌并立即打出反击，不仅清除故障并恢复行驶，还将获得 **+300 分反击奖励** 并获得额外回合！
''';

const Map<String, int> kMilleDistanceValues = {
  'D25': 25,
  'D50': 50,
  'D75': 75,
  'D100': 100,
  'D200': 200,
};

const Set<String> kMilleHazards = {
  'H_STOP',
  'H_LIMIT',
  'H_GAS',
  'H_TIRE',
  'H_ACC',
};

const Set<String> kMilleRemedies = {
  'R_ROLL',
  'R_LIMIT',
  'R_GAS',
  'R_TIRE',
  'R_ACC',
};

const Set<String> kMilleSafeties = {
  'S_ROW',
  'S_GAS',
  'S_TIRE',
  'S_ACC',
};

/// Builds the 106-card Mille Bornes deck.
List<String> buildMilleBornesDeck() {
  final deck = <String>[];
  void addCopies(String code, int count) {
    for (var i = 0; i < count; i++) {
      deck.add(code);
    }
  }

  // Distance cards (46)
  addCopies('D25', 10);
  addCopies('D50', 10);
  addCopies('D75', 10);
  addCopies('D100', 12);
  addCopies('D200', 4);

  // Hazard cards (18)
  addCopies('H_STOP', 5);
  addCopies('H_LIMIT', 4);
  addCopies('H_GAS', 3);
  addCopies('H_TIRE', 3);
  addCopies('H_ACC', 3);

  // Remedy cards (38)
  addCopies('R_ROLL', 14);
  addCopies('R_LIMIT', 6);
  addCopies('R_GAS', 6);
  addCopies('R_TIRE', 6);
  addCopies('R_ACC', 6);

  // Safety cards (4)
  addCopies('S_ROW', 1);
  addCopies('S_GAS', 1);
  addCopies('S_TIRE', 1);
  addCopies('S_ACC', 1);

  return deck;
}

/// Returns the Safety card code that counters [hazard], or null.
String? matchingSafetyForHazard(String hazard) {
  switch (hazard) {
    case 'H_STOP':
    case 'H_LIMIT':
      return 'S_ROW';
    case 'H_GAS':
      return 'S_GAS';
    case 'H_TIRE':
      return 'S_TIRE';
    case 'H_ACC':
      return 'S_ACC';
    default:
      return null;
  }
}

/// Returns the Hazard card code cured by [remedy], or null.
String? hazardClearedByRemedy(String remedy) {
  switch (remedy) {
    case 'R_ROLL':
      return 'H_STOP';
    case 'R_LIMIT':
      return 'H_LIMIT';
    case 'R_GAS':
      return 'H_GAS';
    case 'R_TIRE':
      return 'H_TIRE';
    case 'R_ACC':
      return 'H_ACC';
    default:
      return null;
  }
}

class MilleBornesGame extends GameEngine {
  MilleBornesGame(super.setup);

  late int target;
  int turn = 0;
  String phase = 'play';

  List<String> deck = [];
  List<String> discardPile = [];
  late List<List<String>> hands;
  late List<int> distance;
  late List<int> d200Count;
  late List<bool> rolling;
  late List<bool> speedLimit;
  late List<String?> battleHazard;
  late List<List<String>> safeties;
  late List<List<String>> coupFourres;
  late List<int> bonusPoints;
  late List<int> scores;

  int? lastHazardTarget;
  String? lastHazardCard;
  Map<String, dynamic>? lastMove;
  bool _over = false;

  @override
  void start() {
    target = setup.opt<int>('target', 1000);
    deck = shuffled(buildMilleBornesDeck(), rng);
    discardPile = [];
    hands = List.generate(players, (_) => <String>[]);
    distance = List.filled(players, 0);
    d200Count = List.filled(players, 0);
    rolling = List.filled(players, false);
    speedLimit = List.filled(players, false);
    battleHazard = List.filled(players, null);
    safeties = List.generate(players, (_) => <String>[]);
    coupFourres = List.generate(players, (_) => <String>[]);
    bonusPoints = List.filled(players, 0);
    scores = List.filled(players, 0);

    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(0, 6);
      deck.removeRange(0, 6);
    }
    turn = 0;
    _drawForTurn(turn);
    host.log('千里之行开始！目标里程：$target km');
  }

  void _drawForTurn(int seat) {
    if (deck.isNotEmpty && hands[seat].length < 7) {
      hands[seat].add(deck.removeAt(0));
    }
  }

  void _recalcScores() {
    for (var s = 0; s < players; s++) {
      scores[s] = distance[s] + bonusPoints[s];
    }
  }

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings {
    if (!_over) return null;
    // Any player who reached exact target ranks ahead of those who didn't, breaking ties by total score.
    final effective = [
      for (var s = 0; s < players; s++)
        scores[s] + (distance[s] >= target ? 100000 : 0),
    ];
    return rankByScore(effective);
  }

  bool canPlayCard(int seat, String card, {int? targetSeat}) {
    if (kMilleDistanceValues.containsKey(card)) {
      final km = kMilleDistanceValues[card]!;
      final hasRow = safeties[seat].contains('S_ROW');
      if (battleHazard[seat] != null) return false;
      if (!rolling[seat] && !hasRow) return false;
      if (speedLimit[seat] && !hasRow && km > 50) return false;
      if (card == 'D200' && d200Count[seat] >= 2) return false;
      if (distance[seat] + km > target) return false;
      return true;
    }
    if (kMilleHazards.contains(card)) {
      if (targetSeat == null ||
          targetSeat < 0 ||
          targetSeat >= players ||
          targetSeat == seat) {
        return false;
      }
      final safety = matchingSafetyForHazard(card);
      if (safety != null && safeties[targetSeat].contains(safety)) {
        return false;
      }
      if (card == 'H_LIMIT') {
        return !speedLimit[targetSeat];
      }
      // Battle hazard: target cannot already have an active battle hazard
      return battleHazard[targetSeat] == null;
    }
    if (kMilleRemedies.contains(card)) {
      switch (card) {
        case 'R_ROLL':
          if (safeties[seat].contains('S_ROW') && rolling[seat] && battleHazard[seat] == null) {
            return false;
          }
          return !rolling[seat] &&
              (battleHazard[seat] == null || battleHazard[seat] == 'H_STOP');
        case 'R_LIMIT':
          return speedLimit[seat];
        case 'R_GAS':
          return battleHazard[seat] == 'H_GAS';
        case 'R_TIRE':
          return battleHazard[seat] == 'H_TIRE';
        case 'R_ACC':
          return battleHazard[seat] == 'H_ACC';
      }
    }
    if (kMilleSafeties.contains(card)) {
      return !safeties[seat].contains(card);
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');

    final type = asStr(action['type']);
    final card = asStr(action['card']);

    // Allow out-of-turn Coup-Fourré if seat was just hit by a hazard and holds matching safety
    final isImmediateCoupFourre = kMilleSafeties.contains(card) &&
        lastHazardTarget == seat &&
        lastHazardCard != null &&
        matchingSafetyForHazard(lastHazardCard!) == card &&
        hands[seat].contains(card);

    if (seat != turn && !isImmediateCoupFourre) {
      throw GameError('还没轮到你操作');
    }
    if (!hands[seat].contains(card)) {
      throw GameError('你手中没有这张牌：$card');
    }

    if (type == 'discard') {
      hands[seat].remove(card);
      discardPile.add(card);
      lastHazardTarget = null;
      lastHazardCard = null;
      lastMove = {'seat': seat, 'type': 'discard', 'card': card};
      host.log('${name(seat)} 弃置了 $card');
      _advanceTurnAfterNormalMove(seat);
      return;
    }

    if (type != 'play' && type != 'coup_fourre') {
      throw GameError('未知的操作类型：$type');
    }

    // 1. Distance Card
    if (kMilleDistanceValues.containsKey(card)) {
      final km = kMilleDistanceValues[card]!;
      final hasRow = safeties[seat].contains('S_ROW');
      if (battleHazard[seat] != null) {
        throw GameError('当前存在未解除的故障（${battleHazard[seat]}），无法前进');
      }
      if (!rolling[seat] && !hasRow) {
        throw GameError('尚未打出绿灯（R_ROLL）或优先通行权（S_ROW），无法前进');
      }
      if (speedLimit[seat] && !hasRow && km > 50) {
        throw GameError('当前处于限速 50 km/h 状态，只能打出 D25 或 D50');
      }
      if (card == 'D200' && d200Count[seat] >= 2) {
        throw GameError('每位玩家整局最多只能打出 2 张 200 km 里程牌');
      }
      if (distance[seat] + km > target) {
        throw GameError('打出 $card 后将超过目标里程 $target km');
      }

      hands[seat].remove(card);
      distance[seat] += km;
      if (card == 'D200') d200Count[seat]++;
      if (hasRow) rolling[seat] = true;
      lastHazardTarget = null;
      lastHazardCard = null;
      _recalcScores();
      lastMove = {'seat': seat, 'type': 'distance', 'card': card, 'km': km};
      host.log('${name(seat)} 前进 $km km（当前 ${distance[seat]}/$target km）');

      if (distance[seat] == target) {
        _over = true;
        host.log('${name(seat)} 率先抵达终点 $target km，赢得胜利！');
        return;
      }
      _advanceTurnAfterNormalMove(seat);
      return;
    }

    // 2. Hazard Card
    if (kMilleHazards.contains(card)) {
      var targetSeat = asInt(action['targetSeat'], asInt(action['target'], -1));
      if (targetSeat < 0 && players == 2) {
        targetSeat = 1 - seat;
      }
      if (targetSeat < 0 || targetSeat >= players || targetSeat == seat) {
        throw GameError('必须指定一名有效的对手座位作为故障目标');
      }
      final safety = matchingSafetyForHazard(card);
      if (safety != null && safeties[targetSeat].contains(safety)) {
        throw GameError('目标已拥有王牌 $safety，免疫 $card');
      }
      if (card == 'H_LIMIT') {
        if (speedLimit[targetSeat]) {
          throw GameError('目标已处于限速状态');
        }
        hands[seat].remove(card);
        speedLimit[targetSeat] = true;
      } else {
        if (battleHazard[targetSeat] != null) {
          throw GameError('目标已有未解除的故障（${battleHazard[targetSeat]}）');
        }
        hands[seat].remove(card);
        battleHazard[targetSeat] = card;
        rolling[targetSeat] = false;
      }

      lastHazardTarget = targetSeat;
      lastHazardCard = card;
      lastMove = {
        'seat': seat,
        'type': 'hazard',
        'card': card,
        'targetSeat': targetSeat,
      };
      host.log('${name(seat)} 对 ${name(targetSeat)} 打出故障牌 $card！');
      _advanceTurnAfterNormalMove(seat);
      return;
    }

    // 3. Remedy Card
    if (kMilleRemedies.contains(card)) {
      if (!canPlayCard(seat, card)) {
        throw GameError('当前状态不需要或无法打出排除牌 $card');
      }
      hands[seat].remove(card);
      switch (card) {
        case 'R_ROLL':
          if (battleHazard[seat] == 'H_STOP') {
            battleHazard[seat] = null;
          }
          rolling[seat] = true;
          break;
        case 'R_LIMIT':
          speedLimit[seat] = false;
          break;
        case 'R_GAS':
        case 'R_TIRE':
        case 'R_ACC':
          battleHazard[seat] = null;
          if (safeties[seat].contains('S_ROW')) {
            rolling[seat] = true;
          }
          break;
      }
      lastHazardTarget = null;
      lastHazardCard = null;
      lastMove = {'seat': seat, 'type': 'remedy', 'card': card};
      host.log('${name(seat)} 打出排除牌 $card');
      _advanceTurnAfterNormalMove(seat);
      return;
    }

    // 4. Safety Card
    if (kMilleSafeties.contains(card)) {
      if (safeties[seat].contains(card)) {
        throw GameError('已打出过该王牌');
      }
      hands[seat].remove(card);
      safeties[seat].add(card);

      // Determine whether this is a Coup-Fourré (+300) or normal Safety (+100)
      final isCoupFourre = type == 'coup_fourre' ||
          (lastHazardTarget == seat &&
              lastHazardCard != null &&
              matchingSafetyForHazard(lastHazardCard!) == card) ||
          (card == 'S_GAS' && battleHazard[seat] == 'H_GAS') ||
          (card == 'S_TIRE' && battleHazard[seat] == 'H_TIRE') ||
          (card == 'S_ACC' && battleHazard[seat] == 'H_ACC') ||
          (card == 'S_ROW' &&
              (battleHazard[seat] == 'H_STOP' || speedLimit[seat]) &&
              lastHazardTarget == seat);

      // Cure matching active hazards
      if (card == 'S_ROW') {
        speedLimit[seat] = false;
        if (battleHazard[seat] == 'H_STOP') {
          battleHazard[seat] = null;
        }
        if (battleHazard[seat] == null) {
          rolling[seat] = true;
        }
      } else if (card == 'S_GAS') {
        if (battleHazard[seat] == 'H_GAS') battleHazard[seat] = null;
      } else if (card == 'S_TIRE') {
        if (battleHazard[seat] == 'H_TIRE') battleHazard[seat] = null;
      } else if (card == 'S_ACC') {
        if (battleHazard[seat] == 'H_ACC') battleHazard[seat] = null;
      }

      if (isCoupFourre) {
        coupFourres[seat].add(card);
        bonusPoints[seat] += 300;
        if (battleHazard[seat] == null) {
          rolling[seat] = true;
        }
        host.log('${name(seat)} 发动【Coup-Fourré 绝妙反击】打出 $card（+300分，额外回合）！');
      } else {
        bonusPoints[seat] += 100;
        if (safeties[seat].contains('S_ROW') && battleHazard[seat] == null) {
          rolling[seat] = true;
        }
        host.log('${name(seat)} 打出王牌 $card（+100分，额外回合）！');
      }

      lastHazardTarget = null;
      lastHazardCard = null;
      _recalcScores();
      lastMove = {
        'seat': seat,
        'type': 'safety',
        'card': card,
        'coupFourre': isCoupFourre,
      };

      // Grant extra turn to seat and draw replacement card
      turn = seat;
      _drawForTurn(seat);
      _checkDeckExhausted();
      return;
    }

    throw GameError('无效的卡牌：$card');
  }

  void _advanceTurnAfterNormalMove(int currentSeat) {
    if (_checkDeckExhausted()) return;
    for (var step = 1; step <= players; step++) {
      final next = (currentSeat + step) % players;
      _drawForTurn(next);
      if (hands[next].isNotEmpty) {
        turn = next;
        return;
      }
    }
    _checkDeckExhausted();
  }

  bool _checkDeckExhausted() {
    if (deck.isEmpty && hands.every((h) => h.isEmpty)) {
      _recalcScores();
      _over = true;
      host.log('牌库与所有玩家手牌已耗尽，对局结束！');
      return true;
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn || hands[seat].isEmpty) return null;

    // 1. If holding a Safety that cures an active hazard (Coup-Fourré!), play it immediately
    for (final c in hands[seat]) {
      if (kMilleSafeties.contains(c)) {
        if ((c == 'S_ROW' && (battleHazard[seat] == 'H_STOP' || speedLimit[seat] || !rolling[seat])) ||
            (c == 'S_GAS' && battleHazard[seat] == 'H_GAS') ||
            (c == 'S_TIRE' && battleHazard[seat] == 'H_TIRE') ||
            (c == 'S_ACC' && battleHazard[seat] == 'H_ACC')) {
          return {'type': 'play', 'card': c};
        }
      }
    }

    // 2. If holding a Remedy that cures an active hazard or starts rolling, play it
    for (final c in hands[seat]) {
      if (kMilleRemedies.contains(c) && canPlayCard(seat, c)) {
        return {'type': 'play', 'card': c};
      }
    }

    // 3. Play highest valid Distance card
    final validDistances = hands[seat]
        .where((c) => kMilleDistanceValues.containsKey(c) && canPlayCard(seat, c))
        .toList();
    if (validDistances.isNotEmpty) {
      validDistances.sort(
        (a, b) => kMilleDistanceValues[b]!.compareTo(kMilleDistanceValues[a]!),
      );
      return {'type': 'play', 'card': validDistances.first};
    }

    // 4. Play a Hazard on a leading/rolling opponent
    final opponents = [
      for (var s = 0; s < players; s++)
        if (s != seat) s,
    ]..sort((a, b) => distance[b].compareTo(distance[a]));

    for (final c in hands[seat]) {
      if (kMilleHazards.contains(c)) {
        for (final opp in opponents) {
          if (c == 'H_STOP' && !rolling[opp]) continue;
          if (canPlayCard(seat, c, targetSeat: opp)) {
            return {'type': 'play', 'card': c, 'targetSeat': opp};
          }
        }
      }
    }

    // 5. Play any remaining Safety card for +100 bonus & extra turn
    for (final c in hands[seat]) {
      if (kMilleSafeties.contains(c) && canPlayCard(seat, c)) {
        return {'type': 'play', 'card': c};
      }
    }

    // 6. Discard least useful card
    final discardCandidates = List<String>.of(hands[seat])
      ..sort((a, b) => _discardPriority(seat, a).compareTo(_discardPriority(seat, b)));
    return {'type': 'discard', 'card': discardCandidates.first};
  }

  int _discardPriority(int seat, String card) {
    if (kMilleSafeties.contains(card)) return 100;
    if (card == 'R_ROLL' && !rolling[seat]) return 90;
    if (kMilleDistanceValues.containsKey(card)) {
      final km = kMilleDistanceValues[card]!;
      if (distance[seat] + km > target) return 0; // Unplayable excess distance
      if (card == 'D200' && d200Count[seat] >= 2) return 1;
      return 30 + (km ~/ 25);
    }
    if (kMilleRemedies.contains(card)) {
      final haz = hazardClearedByRemedy(card);
      if (haz != null) {
        final saf = matchingSafetyForHazard(haz);
        if (saf != null && safeties[seat].contains(saf)) {
          return 2; // Redundant remedy since we have the safety
        }
      }
      return 25;
    }
    return 15;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? List<String>.of(hands[seat])
        : <String>[];
    return {
      'phase': phase,
      'target': target,
      'turn': turn,
      'deckCount': deck.length,
      'discardCount': discardPile.length,
      'topDiscard': discardPile.isNotEmpty ? discardPile.last : null,
      'hand': myHand,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'distance': List<int>.of(distance),
      'd200Count': List<int>.of(d200Count),
      'rolling': List<bool>.of(rolling),
      'speedLimit': List<bool>.of(speedLimit),
      'battleHazard': List<String?>.of(battleHazard),
      'safeties': [for (var s = 0; s < players; s++) List<String>.of(safeties[s])],
      'coupFourres': [
        for (var s = 0; s < players; s++) List<String>.of(coupFourres[s]),
      ],
      'bonusPoints': List<int>.of(bonusPoints),
      'scores': List<int>.of(scores),
      'lastMove': lastMove,
      'over': _over,
    };
  }
}
