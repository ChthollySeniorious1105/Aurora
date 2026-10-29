import '../../src/engine.dart';

class BombBustersGame extends GameEngine {
  BombBustersGame(super.setup);

  static const int yellowWire = 99;
  static const int redWire = 100;

  int maxWireNum = 8;
  int detonator = 4;
  int maxDetonator = 4;
  int turn = 0;
  String phase = 'play'; // 'play' | 'over'
  bool defused = false;
  bool exploded = false;

  /// Each seat's sorted wire rack: list of `{'value': int, 'cut': bool, 'token': int?}`.
  late List<List<Map<String, dynamic>>> wires;

  /// Individual accuracy scores & team score.
  late List<int> scores;
  int teamScore = 0;

  String lastEvent = '拆弹专家就位！各排雷员导线架已按从小到大升序排列，请协同剪除所有数字线与黄线，切勿触碰红线！';

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
    return [turn];
  }

  static String wireLabel(int v) {
    if (v == redWire) return '🔴红线(炸弹)';
    if (v == yellowWire) return '🟡黄线';
    if (v <= 0) return '❓未知导线';
    return '🔵$v号线';
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    maxWireNum = mode == 'fast' ? 6 : 8;
    maxDetonator = players + 2;
    detonator = maxDetonator;
    turn = 0;
    phase = 'play';
    defused = false;
    exploded = false;
    scores = List<int>.filled(players, 0);
    teamScore = 0;

    // Build wire deck: (1..maxWireNum) x 2 + 2 Yellow Wires (99) + 1 Red Bomb Wire (100)
    final deck = <int>[
      for (var n = 1; n <= maxWireNum; n++) ...[n, n],
      yellowWire,
      yellowWire,
      redWire,
    ]..shuffle(rng);

    wires = [for (var s = 0; s < players; s++) <Map<String, dynamic>>[]];
    for (var i = 0; i < deck.length; i++) {
      wires[i % players].add({
        'value': deck[i],
        'cut': false,
        'token': null,
      });
    }

    // Sort each player's wire rack in ascending order (1..8 -> 99 -> 100)
    for (var s = 0; s < players; s++) {
      wires[s].sort((a, b) => (a['value'] as int).compareTo(b['value'] as int));
      // Automatically place 1 initial public Info Token on one uncut number wire
      final numIndices = <int>[
        for (var i = 0; i < wires[s].length; i++)
          if ((wires[s][i]['value'] as int) <= maxWireNum) i,
      ];
      if (numIndices.isNotEmpty) {
        final pickIdx = numIndices[rng.nextInt(numIndices.length)];
        wires[s][pickIdx]['token'] = wires[s][pickIdx]['value'];
      }
    }

    _ensureTurnHasAction();
    lastEvent =
        '💣 拆弹任务启动！共 ${deck.length} 根导线（含 2 根🟡黄线与 1 根🔴高危红线），引信剩余 $detonator/$maxDetonator 格，请 ${name(turn)} 行动！';
    host.log(lastEvent);
  }

  /// Checks whether [seat] holds all remaining uncut copies of wire value [v] (and [v] != redWire).
  bool canSoloCutValue(int seat, int v) {
    if (seat < 0 || seat >= players || v == redWire || v <= 0) return false;
    final myUncut = wires[seat].where((w) => w['cut'] != true && w['value'] == v).length;
    if (myUncut == 0) return false;
    for (var s = 0; s < players; s++) {
      if (s == seat) continue;
      if (wires[s].any((w) => w['cut'] != true && w['value'] == v)) {
        return false;
      }
    }
    return true;
  }

  /// All values `v` that [seat] can currently solo cut.
  List<int> soloCuttableValues(int seat) {
    if (seat < 0 || seat >= players) return const [];
    final seen = <int>{};
    final out = <int>[];
    for (final w in wires[seat]) {
      final v = w['value'] as int;
      if (w['cut'] != true && v != redWire && seen.add(v)) {
        if (canSoloCutValue(seat, v)) {
          out.add(v);
        }
      }
    }
    return out;
  }

  bool seatHasUncutNonRed(int seat) =>
      wires[seat].any((w) => w['cut'] != true && (w['value'] as int) != redWire);

  bool allNonRedWiresCut() {
    for (var s = 0; s < players; s++) {
      for (final w in wires[s]) {
        if ((w['value'] as int) != redWire && w['cut'] != true) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你拆弹');

    final type = asStr(action['type']);
    switch (type) {
      case 'dual_cut':
        _handleDualCut(seat, action);
        break;
      case 'solo_cut':
        _handleSoloCut(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleDualCut(int seat, Map<String, dynamic> action) {
    final myIdx = asInt(action['myIdx'], -1);
    final targetSeat = asInt(action['targetSeat'], -1);
    final targetIdx = asInt(action['targetIdx'], -1);

    if (myIdx < 0 || myIdx >= wires[seat].length) {
      throw GameError('请选择你自己导线架上的有效导线位置');
    }
    final myWire = wires[seat][myIdx];
    if (myWire['cut'] == true) {
      throw GameError('你选择的这根导线已经被剪断了');
    }
    final v = myWire['value'] as int;
    if (v == redWire) {
      throw GameError('不能主动用自己的🔴红线发起双人剪线！');
    }

    if (targetSeat < 0 || targetSeat >= players || targetSeat == seat) {
      throw GameError('请选择一名队友的导线架');
    }
    if (targetIdx < 0 || targetIdx >= wires[targetSeat].length) {
      throw GameError('目标队友的导线槽位无效');
    }
    final targetWire = wires[targetSeat][targetIdx];
    if (targetWire['cut'] == true) {
      throw GameError('队友该位置的导线已经被剪断了');
    }

    final targetVal = targetWire['value'] as int;

    if (targetVal == v) {
      // Success! Both wires are safely cut!
      myWire['cut'] = true;
      targetWire['cut'] = true;
      scores[seat] += 3;
      scores[targetSeat] += 1;
      teamScore += 3;
      lastEvent =
          '✂️ 精准双剪！${name(seat)} 用自己的第 ${myIdx + 1} 根导线与 ${name(targetSeat)} 的第 ${targetIdx + 1} 根导线配对成功，同时剪除两根【${wireLabel(v)}】（+3 分）！';
      host.log(lastEvent);
      _checkVictoryOrAdvance();
      return;
    }

    if (targetVal == redWire) {
      // Hit Red Bomb Wire -> BOOM! Immediate explosion!
      targetWire['cut'] = true;
      targetWire['token'] = redWire;
      detonator = 0;
      exploded = true;
      defused = false;
      phase = 'over';
      scores[seat] -= 3;
      lastEvent =
          '💥 轰隆！！${name(seat)} 试图将 ${name(targetSeat)} 的第 ${targetIdx + 1} 根导线当作【${wireLabel(v)}】剪除，却误剪了【🔴红线(炸弹)】！炸弹当场引爆！';
      host.log(lastEvent);
      return;
    }

    // Mismatch on non-Red wire: Detonator advances and Info Token is placed on targetWire!
    detonator--;
    targetWire['token'] = targetVal;
    if (detonator <= 0) {
      exploded = true;
      defused = false;
      phase = 'over';
      lastEvent =
          '💥 剪线失误！${name(seat)} 猜测 ${name(targetSeat)} 的第 ${targetIdx + 1} 根是【${wireLabel(v)}】，实际为【${wireLabel(targetVal)}】！引信归零，炸弹爆炸！';
      host.log(lastEvent);
      return;
    }

    lastEvent =
        '⚠️ 配对偏差！${name(seat)} 猜测 ${name(targetSeat)} 的第 ${targetIdx + 1} 根为【${wireLabel(v)}】，实为【${wireLabel(targetVal)}】（已放置公开情报标记，引信剩余 $detonator/$maxDetonator）！';
    host.log(lastEvent);
    _checkVictoryOrAdvance();
  }

  void _handleSoloCut(int seat, Map<String, dynamic> action) {
    var v = asInt(action['value'], -1);
    final myIdx = asInt(action['myIdx'], -1);
    if (v <= 0 && myIdx >= 0 && myIdx < wires[seat].length) {
      v = wires[seat][myIdx]['value'] as int;
    }
    if (!canSoloCutValue(seat, v)) {
      throw GameError('你尚未集齐场上所有剩余未剪的【${wireLabel(v)}】，无法执行单人独剪！');
    }

    var cutCount = 0;
    for (final w in wires[seat]) {
      if (w['cut'] != true && w['value'] == v) {
        w['cut'] = true;
        cutCount++;
      }
    }
    scores[seat] += 2;
    teamScore += 2;
    lastEvent = '✂️ 单人独剪！${name(seat)} 确认自己手握场上剩余全部 $cutCount 根【${wireLabel(v)}】，干净利落一举剪除（+2 分）！';
    host.log(lastEvent);
    _checkVictoryOrAdvance();
  }

  void _checkVictoryOrAdvance() {
    if (allNonRedWiresCut()) {
      defused = true;
      exploded = false;
      phase = 'over';
      for (var s = 0; s < players; s++) {
        scores[s] += 5;
      }
      teamScore += 10;
      lastEvent = '🏆 拆弹大成功！所有数字导线与黄线均被安全剪除，仅留🔴红线未动，拆弹专家团队完美凯旋！';
      host.log(lastEvent);
      return;
    }
    _advanceTurn();
  }

  void _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final next = (turn + step) % players;
      if (seatHasUncutNonRed(next)) {
        turn = next;
        return;
      }
    }
    // If no player has any uncut non-Red wires left, bomb is defused!
    if (allNonRedWiresCut()) {
      defused = true;
      exploded = false;
      phase = 'over';
    }
  }

  void _ensureTurnHasAction() {
    if (!seatHasUncutNonRed(turn)) {
      _advanceTurn();
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final revealAll = isOver;

    final maskedWires = <List<Map<String, dynamic>>>[
      for (var s = 0; s < players; s++)
        [
          for (var i = 0; i < wires[s].length; i++)
            BuilderHelper.maskWire(
              wire: wires[s][i],
              idx: i,
              showSecret: revealAll || s == seat,
            ),
        ],
    ];

    return {
      'maxWireNum': maxWireNum,
      'detonator': detonator,
      'maxDetonator': maxDetonator,
      'turn': turn,
      'phase': phase,
      'defused': defused,
      'exploded': exploded,
      'wires': maskedWires,
      'soloCuttable': (!isOver && seat == turn) ? soloCuttableValues(seat) : const <int>[],
      'scores': List<int>.of(scores),
      'teamScore': teamScore,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    // 1. Check if any value in `seat`'s rack can be Solo Cut (100% deducible from own rack + public cuts)
    final solos = soloCuttableValues(seat);
    if (solos.isNotEmpty) {
      return {'type': 'solo_cut', 'value': solos.first};
    }

    // 2. Check if any teammate has a public Info Token matching one of `seat`'s uncut non-Red wires
    final myUncutIndices = <int>[
      for (var i = 0; i < wires[seat].length; i++)
        if (wires[seat][i]['cut'] != true && (wires[seat][i]['value'] as int) != redWire) i,
    ];
    if (myUncutIndices.isEmpty) return null;

    for (final mIdx in myUncutIndices) {
      final v = wires[seat][mIdx]['value'] as int;
      for (var tSeat = 0; tSeat < players; tSeat++) {
        if (tSeat == seat) continue;
        for (var tIdx = 0; tIdx < wires[tSeat].length; tIdx++) {
          final tw = wires[tSeat][tIdx];
          if (tw['cut'] != true && tw['token'] == v) {
            return {
              'type': 'dual_cut',
              'myIdx': mIdx,
              'targetSeat': tSeat,
              'targetIdx': tIdx,
            };
          }
        }
      }
    }

    // 3. Otherwise, use public sorted rack bounds to pick the most promising uncut slot on a teammate's rack
    var bestMyIdx = myUncutIndices.first;
    var bestTargetSeat = -1;
    var bestTargetIdx = -1;
    var bestScore = -9999;

    for (final mIdx in myUncutIndices) {
      final v = wires[seat][mIdx]['value'] as int;
      for (var tSeat = 0; tSeat < players; tSeat++) {
        if (tSeat == seat) continue;
        final rack = wires[tSeat];
        for (var tIdx = 0; tIdx < rack.length; tIdx++) {
          final tw = rack[tIdx];
          if (tw['cut'] == true) continue;
          // If it has a public token that is != v, skip it!
          if (tw['token'] != null && tw['token'] != v) continue;

          // Determine public lower and upper bounds on rack[tIdx] from revealed/tokenized neighbors
          var lo = 1;
          for (var k = tIdx - 1; k >= 0; k--) {
            final kw = rack[k];
            final knownVal = kw['cut'] == true ? (kw['value'] as int) : (kw['token'] as int?);
            if (knownVal != null) {
              lo = knownVal;
              break;
            }
          }
          var hi = redWire;
          for (var k = tIdx + 1; k < rack.length; k++) {
            final kw = rack[k];
            final knownVal = kw['cut'] == true ? (kw['value'] as int) : (kw['token'] as int?);
            if (knownVal != null) {
              hi = knownVal;
              break;
            }
          }

          if (v < lo || v > hi) continue; // Impossible by ascending sort order!

          // Estimate expected value at tIdx by linear interpolation across the rack
          final expected = 1 + ((maxWireNum + 1) * tIdx / (rack.length <= 1 ? 1 : rack.length - 1)).round();
          final compareVal = v == yellowWire ? maxWireNum + 1 : v;
          var score = 100 - (expected - compareVal).abs() * 10 - (hi - lo);
          // Avoid the rightmost uncut wire of a rack when guessing high numbers as it might be the Red Wire (100)!
          if (tIdx == rack.length - 1 && hi == redWire) {
            score -= 40;
          }
          if (score > bestScore) {
            bestScore = score;
            bestMyIdx = mIdx;
            bestTargetSeat = tSeat;
            bestTargetIdx = tIdx;
          }
        }
      }
    }

    if (bestTargetSeat >= 0 && bestTargetIdx >= 0) {
      return {
        'type': 'dual_cut',
        'myIdx': bestMyIdx,
        'targetSeat': bestTargetSeat,
        'targetIdx': bestTargetIdx,
      };
    }

    // Fallback: pick any teammate with an uncut wire (preferring leftmost slot to avoid Red wire at the right end)
    for (var tSeat = 0; tSeat < players; tSeat++) {
      if (tSeat == seat) continue;
      for (var tIdx = 0; tIdx < wires[tSeat].length; tIdx++) {
        if (wires[tSeat][tIdx]['cut'] != true) {
          return {
            'type': 'dual_cut',
            'myIdx': bestMyIdx,
            'targetSeat': tSeat,
            'targetIdx': tIdx,
          };
        }
      }
    }

    return null;
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] -= 50;
    exploded = true;
    defused = false;
    phase = 'over';
    lastEvent = '${name(seat)} 放弃拆弹任务，游戏结束！';
    host.log(lastEvent);
  }
}

class BuilderHelper {
  static Map<String, dynamic> maskWire({
    required Map<String, dynamic> wire,
    required int idx,
    required bool showSecret,
  }) {
    final cut = wire['cut'] == true;
    final token = wire['token'] as int?;
    final visible = showSecret || cut || token != null;
    return {
      'idx': idx,
      'cut': cut,
      'token': token,
      'value': visible ? (wire['value'] as int) : -1,
    };
  }
}
