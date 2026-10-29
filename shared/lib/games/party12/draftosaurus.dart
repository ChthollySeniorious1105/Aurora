import '../../src/engine.dart';

const List<String> kDinoNames = [
  '霸王龙',
  '三角龙',
  '剑龙',
  '腕龙',
  '棘龙',
  '副栉龙',
];

const List<String> kConstraintNames = [
  '森林区 (同类/三重/丛林王)',
  '平原区 (百兽/爱之原/孤岛)',
  '洗手间侧 (左半园: 同类/爱之原/三重)',
  '餐厅侧 (右半园: 百兽/丛林王/孤岛)',
  '空围栏 (当前无恐龙的围栏)',
  '无霸王龙围栏 (不含霸王龙的围栏)',
];

class PenDef {
  final int id;
  final String name;
  final String ruleText;
  final int zone; // 0 = 森林区, 1 = 平原区
  final int side; // 2 = 洗手间侧(左), 3 = 餐厅侧(右)
  final int maxCap;
  const PenDef({
    required this.id,
    required this.name,
    required this.ruleText,
    required this.zone,
    required this.side,
    required this.maxCap,
  });
}

const List<PenDef> kDraftosaurusPens = [
  PenDef(
    id: 0,
    name: '同类之森',
    ruleText: '只能放同一种恐龙 (2/4/8/12/18/24分)',
    zone: 0,
    side: 2,
    maxCap: 6,
  ),
  PenDef(
    id: 1,
    name: '百兽草甸',
    ruleText: '只能放不同种恐龙 (1/3/6/10/15/21分)',
    zone: 1,
    side: 3,
    maxCap: 6,
  ),
  PenDef(
    id: 2,
    name: '爱之草原',
    ruleText: '每对同种恐龙得 5 分',
    zone: 1,
    side: 2,
    maxCap: 6,
  ),
  PenDef(
    id: 3,
    name: '三重林',
    ruleText: '最多3只；恰好3只得 7 分',
    zone: 0,
    side: 2,
    maxCap: 3,
  ),
  PenDef(
    id: 4,
    name: '丛林之王',
    ruleText: '限1只；全园该种数量≥所有对手得 7 分',
    zone: 0,
    side: 3,
    maxCap: 1,
  ),
  PenDef(
    id: 5,
    name: '孤岛',
    ruleText: '限1只；全园唯一一只该种恐龙得 7 分',
    zone: 1,
    side: 3,
    maxCap: 1,
  ),
];

class DraftosaurusGame extends GameEngine {
  int round = 1; // 1..2
  int turn = 1; // 1..6 within each round
  int rollerSeat = 0;
  int constraint = 0; // 0..5

  final List<int> bag = [];
  late List<List<int>> hands;

  /// pens[seat][0..5] = list of dino species in each pen
  late List<List<List<int>>> pens;

  /// river[seat] = list of dino species in river (pen 6)
  late List<List<int>> river;

  /// Simultaneous draft selection for the current turn: {dino, pen}
  late List<Map<String, int>?> pendingPick;

  String phase = 'draft'; // 'draft' | 'end'

  DraftosaurusGame(super.setup);

  @override
  void start() {
    round = 1;
    turn = 1;
    rollerSeat = 0;
    phase = 'draft';

    // 60 dinosaurs in bag (10 of each of the 6 species)
    bag
      ..clear()
      ..addAll(shuffled([
        for (var d = 0; d < 6; d++)
          for (var i = 0; i < 10; i++) d
      ], rng));

    hands = List.generate(players, (_) => <int>[]);
    pens = List.generate(players, (_) => List.generate(6, (_) => <int>[]));
    river = List.generate(players, (_) => <int>[]);
    pendingPick = List.filled(players, null);

    _dealRoundHands();
    constraint = rng.nextInt(6);
    host.log('恐龙岛选秀开始！第 1 轮第 1 回合，${name(rollerSeat)} 投出放置骰：【${kConstraintNames[constraint]}】。');
  }

  void _dealRoundHands() {
    for (var s = 0; s < players; s++) {
      hands[s] = [
        for (var i = 0; i < 6 && bag.isNotEmpty; i++) bag.removeLast()
      ];
    }
  }

  @override
  bool get isOver => phase == 'end';

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [
      for (var s = 0; s < players; s++)
        if (pendingPick[s] == null) s
    ];
  }

  /// Checks whether pen `p` (0..5) can accept dinosaur `dino` by its own enclosure rule.
  static bool canPenAccept(List<int> currentPen, int p, int dino) {
    if (p < 0 || p >= 6) return false;
    final def = kDraftosaurusPens[p];
    if (currentPen.length >= def.maxCap) return false;
    if (p == 0 && currentPen.isNotEmpty && currentPen.first != dino) {
      return false; // 同类之森: must match existing species
    }
    if (p == 1 && currentPen.contains(dino)) {
      return false; // 百兽草甸: must be distinct species
    }
    return true;
  }

  /// Checks whether pen `p` (0..5) satisfies placement die `constraint` (0..5).
  static bool satisfiesConstraint(List<int> currentPen, int p, int constraint) {
    if (p < 0 || p >= 6) return false;
    final def = kDraftosaurusPens[p];
    switch (constraint) {
      case 0: // 森林区
        return def.zone == 0;
      case 1: // 平原区
        return def.zone == 1;
      case 2: // 洗手间侧 (左半园)
        return def.side == 2;
      case 3: // 餐厅侧 (右半园)
        return def.side == 3;
      case 4: // 空围栏
        return currentPen.isEmpty;
      case 5: // 无霸王龙围栏
        return !currentPen.contains(0);
      default:
        return true;
    }
  }

  /// Full legality check for `seat` placing `dino` into `pen` (0..5 or 6=River).
  bool canPlace(int seat, int dino, int pen) {
    if (dino < 0 || dino >= 6) return false;
    if (pen == 6) return true; // River is always allowed
    if (pen < 0 || pen > 5) return false;
    final currentPen = pens[seat][pen];
    if (!canPenAccept(currentPen, pen, dino)) return false;
    if (seat != rollerSeat && !satisfiesConstraint(currentPen, pen, constraint)) {
      return false;
    }
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('你本回合已经选定恐龙');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('请选择一只恐龙放入围栏或河流(place)');

    final dino = asInt(action['dino'], -1);
    final pen = asInt(action['pen'], -1);
    if (!hands[seat].contains(dino)) {
      throw GameError('你手中没有该种类的恐龙');
    }
    if (!canPlace(seat, dino, pen)) {
      if (pen >= 0 && pen <= 5 && seat != rollerSeat && !satisfiesConstraint(pens[seat][pen], pen, constraint)) {
        throw GameError('受放置骰【${kConstraintNames[constraint]}】限制，不能放入该围栏（可放入其他合规围栏或河流）');
      }
      throw GameError('该围栏不符合放置规则或已满');
    }

    pendingPick[seat] = {'dino': dino, 'pen': pen};

    if (pendingPick.every((p) => p != null)) {
      _resolveDraftTurn();
    }
  }

  void _resolveDraftTurn() {
    for (var s = 0; s < players; s++) {
      final pick = pendingPick[s]!;
      final dino = pick['dino']!;
      final pen = pick['pen']!;
      hands[s].remove(dino);
      if (pen == 6) {
        river[s].add(dino);
      } else {
        pens[s][pen].add(dino);
      }
      pendingPick[s] = null;
    }

    if (turn < 6) {
      // Pass remaining hands clockwise: seat s passes to (s + 1) % players
      final nextHands = List.generate(players, (_) => <int>[]);
      for (var s = 0; s < players; s++) {
        nextHands[(s + 1) % players] = hands[s];
      }
      hands = nextHands;
      turn++;
      rollerSeat = (rollerSeat + 1) % players;
      constraint = rng.nextInt(6);
      host.log('第 $round 轮第 $turn 回合：手牌顺时针传递，${name(rollerSeat)} 投出【${kConstraintNames[constraint]}】。');
      return;
    }

    if (round == 1) {
      round = 2;
      turn = 1;
      rollerSeat = (rollerSeat + 1) % players;
      _dealRoundHands();
      constraint = rng.nextInt(6);
      host.log('进入第 2 轮！重新抽取 6 只恐龙，${name(rollerSeat)} 投出【${kConstraintNames[constraint]}】。');
    } else {
      phase = 'end';
      final sc = scores;
      host.log('恐龙岛选秀结束！最终得分：${[for (var s = 0; s < players; s++) '${name(s)} ${sc[s]}分'].join('，')}。');
    }
  }

  int countSpeciesInPark(int seat, int species) {
    var count = 0;
    for (var p = 0; p < 6; p++) {
      for (final d in pens[seat][p]) {
        if (d == species) count++;
      }
    }
    return count;
  }

  Map<String, dynamic> scoreBreakdown(int seat) {
    const sameTable = [0, 2, 4, 8, 12, 18, 24];
    const diffTable = [0, 1, 3, 6, 10, 15, 21];

    final penScores = List.filled(6, 0);

    // Pen 0: 同类之森
    final len0 = pens[seat][0].length.clamp(0, 6);
    penScores[0] = sameTable[len0];

    // Pen 1: 百兽草甸
    final len1 = pens[seat][1].length.clamp(0, 6);
    penScores[1] = diffTable[len1];

    // Pen 2: 爱之草原 (5 VP per pair of same species)
    final counts2 = List.filled(6, 0);
    for (final d in pens[seat][2]) {
      counts2[d]++;
    }
    var pairs2 = 0;
    for (final c in counts2) {
      pairs2 += c ~/ 2;
    }
    penScores[2] = pairs2 * 5;

    // Pen 3: 三重林 (exactly 3 dinos = 7 VP)
    penScores[3] = pens[seat][3].length == 3 ? 7 : 0;

    // Pen 4: 丛林之王 (7 VP if you have >= as many of that species as every opponent)
    if (pens[seat][4].isNotEmpty) {
      final sp = pens[seat][4].first;
      final myTotal = countSpeciesInPark(seat, sp);
      var isKing = true;
      for (var other = 0; other < players; other++) {
        if (countSpeciesInPark(other, sp) > myTotal) {
          isKing = false;
          break;
        }
      }
      penScores[4] = isKing ? 7 : 0;
    }

    // Pen 5: 孤岛 (7 VP if it is the ONLY dino of that species in your entire park)
    if (pens[seat][5].isNotEmpty) {
      final sp = pens[seat][5].first;
      penScores[5] = countSpeciesInPark(seat, sp) == 1 ? 7 : 0;
    }

    // +1 VP per Pen (0..5) containing at least 1 T-Rex (species 0)
    var trexBonus = 0;
    for (var p = 0; p < 6; p++) {
      if (pens[seat][p].contains(0)) trexBonus++;
    }

    final riverScore = river[seat].length;
    final total = penScores.fold<int>(0, (a, b) => a + b) + trexBonus + riverScore;

    return {
      'penScores': penScores,
      'trexBonus': trexBonus,
      'riverScore': riverScore,
      'total': total,
    };
  }

  List<int> get scores => [
        for (var s = 0; s < players; s++) scoreBreakdown(s)['total'] as int
      ];

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;
    final h = hands[seat];
    if (h.isEmpty) return null;

    if (botLevel == 0) {
      final d = h[rng.nextInt(h.length)];
      final validPens = [
        for (var p = 0; p <= 6; p++)
          if (canPlace(seat, d, p)) p
      ];
      final p = validPens[rng.nextInt(validPens.length)];
      return {'type': 'place', 'dino': d, 'pen': p};
    }

    // Evaluate immediate score delta + heuristic value for every legal (dino, pen)
    final baseScore = scoreBreakdown(seat)['total'] as int;
    var bestDino = h.first;
    var bestPen = 6;
    var bestVal = -999;

    for (final d in h.toSet()) {
      for (var p = 0; p <= 6; p++) {
        if (!canPlace(seat, d, p)) continue;
        // Simulate placing d into p
        if (p == 6) {
          river[seat].add(d);
        } else {
          pens[seat][p].add(d);
        }
        final newScore = scoreBreakdown(seat)['total'] as int;
        if (p == 6) {
          river[seat].removeLast();
        } else {
          pens[seat][p].removeLast();
        }

        var val = (newScore - baseScore) * 10;
        if (p == 3 && pens[seat][3].length < 3) val += 25; // building towards 3-dino trio
        if (p == 2 && pens[seat][2].contains(d) && pens[seat][2].where((x) => x == d).length.isOdd) {
          val += 45; // completes a pair
        } else if (p == 2) {
          val += 15; // starts a pair
        }
        if (p < 6 && d == 0 && !pens[seat][p].contains(0)) val += 12; // T-Rex bonus

        if (val > bestVal) {
          bestVal = val;
          bestDino = d;
          bestPen = p;
        }
      }
    }

    return {'type': 'place', 'dino': bestDino, 'pen': bestPen};
  }

  @override
  List<int>? get placings => isOver ? rankByScore(scores) : null;

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? List.of(hands[seat]) : const <int>[];
    final myPick = (seat >= 0 && seat < players) ? pendingPick[seat] : null;

    return {
      'phase': phase,
      'round': round,
      'turn': turn,
      'rollerSeat': rollerSeat,
      'constraint': constraint,
      'constraintName': kConstraintNames[constraint],
      'hand': myHand,
      'handCounts': [for (final h in hands) h.length],
      'myPick': myPick,
      'picked': [for (final p in pendingPick) p != null],
      'pens': pens,
      'river': river,
      'scores': scores,
      'breakdowns': [for (var s = 0; s < players; s++) scoreBreakdown(s)],
      'waitingFor': waitingFor,
    };
  }
}
