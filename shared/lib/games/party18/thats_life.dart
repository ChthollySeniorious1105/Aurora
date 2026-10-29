import '../../src/engine.dart';

class ThatsLifeGame extends GameEngine {
  ThatsLifeGame(super.setup);

  int round = 1;
  int turn = 0;
  int roll = 1;
  String phase = 'act'; // 'act' | 'over'

  /// Linear path of 20 tiles (0 = Start, 1..18 = Path Tiles, 19 = Finish).
  /// Values on 1..18: Negative Red (-1..-8), Positive Green (+1..+6), or 🍀 Guardian (99).
  late List<int> tiles;

  /// Whether tile index 0..19 is still present on the path (0 and 19 are always true).
  late List<bool> activeTiles;

  /// Each player has 3 Pawns: pawns[seat][0..2], starting at 0, finishing at 19.
  late List<List<int>> pawns;

  /// Neutral Guard Pawns starting on Guardian & Positive tiles (positions 1..19).
  late List<int> guards;

  /// Collected path tile values per player.
  late List<List<int>> collected;

  /// Current computed scores per player (with Guardian Reversal applied).
  late List<int> scores;

  String lastEvent = '百变人生启程！投掷骰子移动你的棋子或同格中立守卫，最后离开板块者将板块收入囊中！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    recalcScores();
    final adjusted = <num>[
      for (var s = 0; s < players; s++)
        scores[s] * 100 + collected[s].where((v) => v == 99).length * 5 + collected[s].length,
    ];
    return rankByScore(adjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (!_hasMovablePawn(turn)) return const [];
    return [turn];
  }

  bool _hasMovablePawn(int seat) =>
      seat >= 0 && seat < players && pawns[seat].any((p) => p < 19);

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    round = 1;
    turn = 0;
    phase = 'act';

    // Path of 20 tiles: 0 = Start, 1..18 = Path Tiles, 19 = Finish
    // Standard path layout mixing Red (-1..-8), Green (+1..+6), and 🍀 Guardian (99)
    final pathPool = <int>[
      -1,
      -2,
      1,
      -3,
      99,
      2,
      -4,
      3,
      -5,
      99,
      4,
      -6,
      5,
      -7,
      99,
      6,
      -8,
      mode == 'fast' ? 4 : -4,
    ];

    tiles = <int>[
      0, // 0: Start
      ...pathPool, // 1..18
      0, // 19: Finish
    ];
    activeTiles = List<bool>.filled(20, true);

    pawns = [
      for (var s = 0; s < players; s++) <int>[0, 0, 0],
    ];

    // Neutral Guard pawns start on the Guardian (99) and high Positive (+4..+6) tiles
    guards = <int>[];
    for (var pos = 1; pos <= 18; pos++) {
      if (tiles[pos] == 99 || tiles[pos] >= 4) {
        guards.add(pos);
      }
    }

    collected = [for (var s = 0; s < players; s++) <int>[]];
    scores = List<int>.filled(players, 0);
    roll = rng.nextInt(6) + 1;

    lastEvent = '百变人生开局！${name(turn)} 掷出 🎲$roll 点，可移动自己的棋子或与己方同格的中立守卫！';
    host.log('【百变人生】20 格人生旅途开启！收集 🍀幸运守护草 (99) 可将所有负分红砖反转为正分！');
  }

  /// Compute a player's score under the Endgame Guardian Reversal rule:
  /// If collected[seat] contains at least one 99 (🍀 Guardian Tile),
  /// ALL Negative Red Tiles (-1..-8) flip to POSITIVE (+1..+8)!
  int scoreOf(int seat) {
    final items = collected[seat];
    final hasGuardian = items.contains(99);
    var sum = 0;
    for (final v in items) {
      if (v == 99) continue;
      if (v < 0) {
        sum += hasGuardian ? -v : v;
      } else {
        sum += v;
      }
    }
    return sum;
  }

  void recalcScores() {
    for (var s = 0; s < players; s++) {
      scores[s] = scoreOf(s);
    }
  }

  /// Advance from [oldPos] forward by [steps] active tiles, clamping at Finish (19).
  int advanceAlongActivePath(int oldPos, int steps) {
    var cur = oldPos;
    var remaining = steps;
    while (remaining > 0 && cur < 19) {
      cur++;
      if (cur >= 19) {
        cur = 19;
        break;
      }
      if (activeTiles[cur]) {
        remaining--;
      }
    }
    return cur.clamp(0, 19);
  }

  /// Count total pieces (all players' pawns + neutral guards) currently standing on [pos].
  int piecesAt(int pos) {
    var count = 0;
    for (var s = 0; s < players; s++) {
      for (final p in pawns[s]) {
        if (p == pos) count++;
      }
    }
    for (final gPos in guards) {
      if (gPos == pos) count++;
    }
    return count;
  }

  /// Positions 1..18 where [seat] can legally move a Neutral Guard Pawn
  /// (must contain at least 1 neutral guard AND at least 1 of [seat]'s own pawns).
  List<int> movableGuardPositions(int seat) {
    if (seat < 0 || seat >= players) return const <int>[];
    final myPositions = pawns[seat].toSet();
    final out = <int>{};
    for (final gPos in guards) {
      if (gPos >= 1 && gPos <= 18 && myPositions.contains(gPos)) {
        out.add(gPos);
      }
    }
    final list = out.toList()..sort();
    return list;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'move_pawn':
        _handleMovePawn(seat, action);
        break;
      case 'move_guard':
        _handleMoveGuard(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleMovePawn(int seat, Map<String, dynamic> action) {
    final idx = asInt(action['idx'], -1);
    if (idx < 0 || idx >= 3) {
      throw GameError('棋子编号必须在 0~2 之间');
    }
    final oldPos = pawns[seat][idx];
    if (oldPos >= 19) {
      throw GameError('该棋子已经抵达终点');
    }

    final newPos = advanceAlongActivePath(oldPos, roll);
    pawns[seat][idx] = newPos;

    final tileMsg = _checkLeavingLastRule(seat, oldPos);
    recalcScores();

    lastEvent = '🏃 ${name(seat)} (🎲$roll) 将 ${idx + 1} 号棋子从第 $oldPos 格移至第 $newPos 格$tileMsg';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _handleMoveGuard(int seat, Map<String, dynamic> action) {
    var pos = asInt(action['pos'], -1);
    var gIdx = -1;
    if (pos >= 1 && pos <= 18) {
      gIdx = guards.indexOf(pos);
    } else if (action.containsKey('idx')) {
      final idx = asInt(action['idx'], -1);
      if (idx >= 0 && idx < guards.length) {
        gIdx = idx;
        pos = guards[idx];
      }
    }

    if (gIdx < 0 || pos < 1 || pos >= 19) {
      throw GameError('指定位置没有可移动的中立守卫');
    }
    if (!pawns[seat].contains(pos)) {
      throw GameError('只能移动与你自己棋子处于同一格的中立守卫');
    }

    final oldPos = pos;
    final newPos = advanceAlongActivePath(oldPos, roll);
    guards[gIdx] = newPos;

    final tileMsg = _checkLeavingLastRule(seat, oldPos);
    recalcScores();

    lastEvent = '🛡️ ${name(seat)} (🎲$roll) 调动第 $oldPos 格的中立守卫前进至第 $newPos 格$tileMsg';
    host.log(lastEvent);
    _advanceTurn();
  }

  String _checkLeavingLastRule(int seat, int oldPos) {
    if (oldPos < 1 || oldPos > 18 || !activeTiles[oldPos]) {
      return '';
    }
    if (piecesAt(oldPos) == 0) {
      activeTiles[oldPos] = false;
      final val = tiles[oldPos];
      collected[seat].add(val);
      final label = val == 99
          ? '🍀幸运守护草'
          : (val > 0 ? '+$val 绿砖' : '$val 红砖');
      return '，作为最后离开者收走第 $oldPos 格【$label】！';
    }
    return '';
  }

  void _advanceTurn() {
    recalcScores();

    // Check if all players' pawns have reached tile 19
    final allFinished = pawns.every((pList) => pList.every((p) => p >= 19));
    if (allFinished) {
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent = '🏆 全员抵达人生终点！${name(bestSeat)} 以 ${scores[bestSeat]} 分赢得百变人生冠军！';
      host.log(lastEvent);
      return;
    }

    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (next <= turn) {
        round++;
      }
      if (_hasMovablePawn(next)) {
        turn = next;
        break;
      }
    }

    roll = rng.nextInt(6) + 1;
  }

  @override
  Map<String, dynamic> view(int seat) {
    recalcScores();
    final validPlayer = seat >= 0 && seat < players;
    return {
      'round': round,
      'turn': turn,
      'roll': roll,
      'phase': phase,
      'tiles': List<int>.of(tiles),
      'activeTiles': List<bool>.of(activeTiles),
      'pawns': [
        for (final pList in pawns) List<int>.of(pList),
      ],
      'guards': List<int>.of(guards),
      'collected': [
        for (final cList in collected) List<int>.of(cList),
      ],
      'scores': List<int>.of(scores),
      'movableGuards': validPlayer ? movableGuardPositions(seat) : const <int>[],
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    final hasGuardian = collected[seat].contains(99);
    Map<String, dynamic>? bestAct;
    var bestScore = -999999;

    // Evaluate moving each of seat's own movable pawns (0..2)
    for (var i = 0; i < 3; i++) {
      final oldPos = pawns[seat][i];
      if (oldPos >= 19) continue;
      final newPos = advanceAlongActivePath(oldPos, roll);
      final val = _evaluateMove(seat, oldPos, newPos, hasGuardian, isGuard: false);
      if (val > bestScore) {
        bestScore = val;
        bestAct = {'type': 'move_pawn', 'idx': i};
      }
    }

    // Evaluate moving any shared Neutral Guard pawn
    for (final gPos in movableGuardPositions(seat)) {
      final newPos = advanceAlongActivePath(gPos, roll);
      final val = _evaluateMove(seat, gPos, newPos, hasGuardian, isGuard: true);
      if (val > bestScore) {
        bestScore = val;
        bestAct = {'type': 'move_guard', 'pos': gPos};
      }
    }

    return bestAct;
  }

  int _evaluateMove(int seat, int oldPos, int newPos, bool hasGuardian, {required bool isGuard}) {
    var score = 0;
    // Check if leaving oldPos triggers the Leaving-Last Rule
    if (oldPos >= 1 && oldPos <= 18 && activeTiles[oldPos] && piecesAt(oldPos) == 1) {
      final v = tiles[oldPos];
      if (v == 99) {
        score += 120; // Huge priority to claim a Guardian tile!
      } else if (v > 0) {
        score += v * 15;
      } else {
        // Negative tile: great if we already have a Guardian tile, bad otherwise!
        score += hasGuardian ? (-v) * 14 : v * 16;
      }
    }

    // Evaluate landing on newPos
    if (newPos >= 1 && newPos <= 18 && activeTiles[newPos]) {
      final destV = tiles[newPos];
      if (destV == 99) {
        score += 25;
      } else if (destV > 0) {
        score += destV * 3;
      } else if (!hasGuardian && piecesAt(newPos) == 0) {
        // Landing alone on a negative tile without a guardian is risky
        score += destV * 4;
      }
    }

    if (!isGuard) {
      score += 5; // Slight preference to advance own pawns so the game progresses smoothly
    }
    return score + rng.nextInt(3);
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    collected[seat] = <int>[-100];
    recalcScores();
    phase = 'over';
    lastEvent = '${name(seat)} 中途退出人生旅途，游戏结束！';
    host.log(lastEvent);
  }
}
