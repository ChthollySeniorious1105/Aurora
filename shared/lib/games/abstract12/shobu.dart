import '../../src/engine.dart';

/// 8 compass directions (dr, dc) for SHŌBU:
/// 0: N (-1, 0), 1: NE (-1, 1), 2: E (0, 1), 3: SE (1, 1),
/// 4: S (1, 0),  5: SW (1, -1), 6: W (0, -1), 7: NW (-1, -1)
const List<(int, int)> kShobuDirs = [
  (-1, 0),
  (-1, 1),
  (0, 1),
  (1, 1),
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, -1),
];

const List<String> kShobuDirNames = ['北', '东北', '东', '东南', '南', '西南', '西', '西北'];

class ShobuMove {
  final int pBoard;
  final int pFrom;
  final int pTo;
  final int aBoard;
  final int aFrom;
  final int aTo;
  final int dir;
  final int steps;
  final bool pushed;
  final bool pushedOff;

  const ShobuMove({
    required this.pBoard,
    required this.pFrom,
    required this.pTo,
    required this.aBoard,
    required this.aFrom,
    required this.aTo,
    required this.dir,
    required this.steps,
    required this.pushed,
    required this.pushedOff,
  });

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'pBoard': pBoard,
        'pFrom': pFrom,
        'aBoard': aBoard,
        'aFrom': aFrom,
        'dir': dir,
        'steps': steps,
      };
}

class ShobuGame extends GameEngine {
  /// 4 boards of 16 cells (4x4): 0 = empty, 1 = Black (seat 0), 2 = White (seat 1).
  /// Board 0 (Dark) & Board 1 (Light) = Seat 0 (Black) Home Boards.
  /// Board 2 (Dark) & Board 3 (Light) = Seat 1 (White) Home Boards.
  late List<List<int>> boards;

  int turn = 0;
  int plyCount = 0;
  bool over = false;
  int? winner;
  List<int>? finalPlacings;
  String? resultText;
  Map<String, dynamic>? lastMove;

  ShobuGame(super.setup);

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => finalPlacings;

  @override
  void start() {
    boards = List.generate(4, (_) {
      final b = List.filled(16, 0);
      for (var c = 0; c < 4; c++) {
        b[0 * 4 + c] = 2; // Row 0: 4 White stones
        b[3 * 4 + c] = 1; // Row 3: 4 Black stones
      }
      return b;
    });
    turn = 0;
    plyCount = 0;
    over = false;
    winner = null;
    finalPlacings = null;
    resultText = null;
    lastMove = null;
  }

  /// Home boards for [seat]: [0, 1] for Black (seat 0), [2, 3] for White (seat 1).
  List<int> homeBoardsFor(int seat) => seat == 0 ? const [0, 1] : const [2, 3];

  /// Opposite-shade boards for a passive board [pBoard]:
  /// Dark (0, 2) -> Light [1, 3]; Light (1, 3) -> Dark [0, 2].
  List<int> aggressiveBoardsFor(int pBoard) =>
      (pBoard % 2 == 0) ? const [1, 3] : const [0, 2];

  static bool inBounds(int r, int c) => r >= 0 && r < 4 && c >= 0 && c < 4;

  /// Validate a passive move on [pBoard] from [pFrom] along [dir] for [steps] (1 or 2).
  /// Returns destination index (0..15) or -1 if invalid.
  int checkPassiveMove(int seat, int pBoard, int pFrom, int dir, int steps) {
    if (seat == 0 && pBoard != 0 && pBoard != 1) return -1;
    if (seat == 1 && pBoard != 2 && pBoard != 3) return -1;
    if (pFrom < 0 || pFrom >= 16) return -1;
    if (dir < 0 || dir >= 8) return -1;
    if (steps != 1 && steps != 2) return -1;

    final myStone = seat + 1;
    final b = boards[pBoard];
    if (b[pFrom] != myStone) return -1;

    final (dr, dc) = kShobuDirs[dir];
    final r0 = pFrom ~/ 4;
    final c0 = pFrom % 4;
    for (var k = 1; k <= steps; k++) {
      final nr = r0 + k * dr;
      final nc = c0 + k * dc;
      if (!inBounds(nr, nc)) return -1;
      // Passive move may NOT touch or push any stone.
      if (b[nr * 4 + nc] != 0) return -1;
    }
    return (r0 + steps * dr) * 4 + (c0 + steps * dc);
  }

  /// Validate an aggressive move on [aBoard] (given [pBoard]) from [aFrom] along [dir] for [steps].
  /// Returns `(aTo, pushedEnemyCell, pushedDestCell)` or `null` if invalid.
  /// `pushedEnemyCell` is -1 if no stone was pushed; `pushedDestCell` is -1 if pushed off the board.
  (int aTo, int pushedCell, int pushedDest)? checkAggressiveMove(
    int seat,
    int pBoard,
    int aBoard,
    int aFrom,
    int dir,
    int steps,
  ) {
    if (aBoard < 0 || aBoard >= 4) return null;
    if ((aBoard % 2) == (pBoard % 2)) return null; // Must be opposite shade
    if (aFrom < 0 || aFrom >= 16) return null;
    if (dir < 0 || dir >= 8) return null;
    if (steps != 1 && steps != 2) return null;

    final myStone = seat + 1;
    final oppStone = 2 - seat;
    final b = boards[aBoard];
    if (b[aFrom] != myStone) return null;

    final (dr, dc) = kShobuDirs[dir];
    final r0 = aFrom ~/ 4;
    final c0 = aFrom % 4;
    final endR = r0 + steps * dr;
    final endC = c0 + steps * dc;
    if (!inBounds(endR, endC)) return null;

    var enemyCount = 0;
    var enemyCell = -1;
    for (var k = 1; k <= steps; k++) {
      final nr = r0 + k * dr;
      final nc = c0 + k * dc;
      final cell = nr * 4 + nc;
      final v = b[cell];
      if (v == myStone) return null; // Blocked by own stone
      if (v == oppStone) {
        enemyCount++;
        enemyCell = cell;
      }
    }

    if (enemyCount > 1) return null; // Cannot push 2 stones

    final aTo = endR * 4 + endC;
    if (enemyCount == 0) {
      return (aTo, -1, -1);
    }

    // Single enemy stone pushed ahead to (endR + dr, endC + dc)
    final pushR = endR + dr;
    final pushC = endC + dc;
    if (!inBounds(pushR, pushC)) {
      // Pushed right off the edge of the 4x4 board!
      return (aTo, enemyCell, -1);
    }
    final pushDest = pushR * 4 + pushC;
    if (b[pushDest] != 0) {
      // Second stone blocks the push
      return null;
    }
    return (aTo, enemyCell, pushDest);
  }

  /// Enumerate all legal synchronized (Passive + Aggressive) moves for [seat].
  List<ShobuMove> legalMovesFor(int seat) {
    final res = <ShobuMove>[];
    final myStone = seat + 1;
    for (final pb in homeBoardsFor(seat)) {
      final bPass = boards[pb];
      for (var pf = 0; pf < 16; pf++) {
        if (bPass[pf] != myStone) continue;
        for (var dir = 0; dir < 8; dir++) {
          for (var steps = 1; steps <= 2; steps++) {
            final pTo = checkPassiveMove(seat, pb, pf, dir, steps);
            if (pTo < 0) break; // If 1 step is blocked/out, 2 steps in same dir is also invalid
            for (final ab in aggressiveBoardsFor(pb)) {
              final bAgg = boards[ab];
              for (var af = 0; af < 16; af++) {
                if (bAgg[af] != myStone) continue;
                final agg = checkAggressiveMove(seat, pb, ab, af, dir, steps);
                if (agg != null) {
                  final (aTo, pushedCell, pushedDest) = agg;
                  res.add(ShobuMove(
                    pBoard: pb,
                    pFrom: pf,
                    pTo: pTo,
                    aBoard: ab,
                    aFrom: af,
                    aTo: aTo,
                    dir: dir,
                    steps: steps,
                    pushed: pushedCell >= 0,
                    pushedOff: pushedCell >= 0 && pushedDest < 0,
                  ));
                }
              }
            }
          }
        }
      }
    }
    return res;
  }

  int countStonesOnBoard(int boardIdx, int seat) {
    final target = seat + 1;
    var count = 0;
    for (final v in boards[boardIdx]) {
      if (v == target) count++;
    }
    return count;
  }

  /// Parse direction index 0..7 from int, [dr, dc], or compass string.
  int _parseDir(Object? raw) {
    if (raw is int || raw is num) return asInt(raw);
    if (raw is List && raw.length == 2) {
      final dr = asInt(raw[0], 99);
      final dc = asInt(raw[1], 99);
      for (var i = 0; i < kShobuDirs.length; i++) {
        if (kShobuDirs[i] == (dr, dc)) return i;
      }
    }
    if (raw is String) {
      final up = raw.toUpperCase();
      const map = {'N': 0, 'NE': 1, 'E': 2, 'SE': 3, 'S': 4, 'SW': 5, 'W': 6, 'NW': 7};
      if (map.containsKey(up)) return map[up]!;
      return int.tryParse(raw) ?? -1;
    }
    return -1;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行棋');

    final type = asStr(action['type']);
    if (type != 'move') throw GameError('未知操作类型：$type');

    final pb = asInt(action['pBoard']);
    final pf = asInt(action['pFrom']);
    final ab = asInt(action['aBoard']);
    final af = asInt(action['aFrom']);
    final dir = _parseDir(action['dir']);
    final steps = asInt(action['steps']);

    final pTo = checkPassiveMove(seat, pb, pf, dir, steps);
    if (pTo < 0) {
      throw GameError('消极步不合法：必须在己方主场棋盘上沿无阻挡直线移动 1~2 格');
    }

    final agg = checkAggressiveMove(seat, pb, ab, af, dir, steps);
    if (agg == null) {
      throw GameError('积极步不合法：必须在异色棋盘上沿相同方向与步数移动，且至多推走 1 枚敌子');
    }

    final (aTo, pushedCell, pushedDest) = agg;
    final myStone = seat + 1;
    final oppStone = 2 - seat;

    // Execute passive move
    boards[pb][pf] = 0;
    boards[pb][pTo] = myStone;

    // Execute aggressive move
    boards[ab][af] = 0;
    if (pushedCell >= 0) {
      boards[ab][pushedCell] = 0;
      if (pushedDest >= 0) {
        boards[ab][pushedDest] = oppStone;
      }
    }
    boards[ab][aTo] = myStone;

    final pushedOff = pushedCell >= 0 && pushedDest < 0;
    plyCount++;

    lastMove = {
      'seat': seat,
      'pBoard': pb,
      'pFrom': pf,
      'pTo': pTo,
      'aBoard': ab,
      'aFrom': af,
      'aTo': aTo,
      'dir': dir,
      'steps': steps,
      'pushed': pushedCell >= 0,
      'pushedOff': pushedOff,
    };

    if (pushedOff) {
      host.log('${name(seat)} 向${kShobuDirNames[dir]}移动 $steps 步，在棋盘 #${ab + 1} 将一枚敌方石子推下棋盘！');
    } else if (pushedCell >= 0) {
      host.log('${name(seat)} 向${kShobuDirNames[dir]}移动 $steps 步，并在棋盘 #${ab + 1} 推动敌子');
    } else {
      host.log('${name(seat)} 向${kShobuDirNames[dir]}同步移动 $steps 步');
    }

    // Check win condition: any board has 0 enemy stones remaining
    for (var bIdx = 0; bIdx < 4; bIdx++) {
      if (countStonesOnBoard(bIdx, 1 - seat) == 0) {
        over = true;
        winner = seat;
        finalPlacings = rankWinners(2, [seat]);
        resultText = '${name(seat)} 清空了棋盘 #${bIdx + 1} 上的全部敌方石子，获得胜利！';
        host.log('游戏结束：$resultText');
        return;
      }
    }

    final nextSeat = 1 - seat;
    if (legalMovesFor(nextSeat).isEmpty) {
      over = true;
      winner = seat;
      finalPlacings = rankWinners(2, [seat]);
      resultText = '${name(nextSeat)} 无合法步可走，${name(seat)} 获胜！';
      host.log('游戏结束：$resultText');
      return;
    }

    // Prevent endless shuffling in bot games via ply limit adjudication
    if (plyCount >= 160) {
      _adjudicateByStones();
      return;
    }

    turn = nextSeat;
  }

  void _adjudicateByStones() {
    over = true;
    // Compare lowest enemy stone count on any single board, then total stones
    var min0 = 4, min1 = 4;
    var tot0 = 0, tot1 = 0;
    for (var b = 0; b < 4; b++) {
      final c0 = countStonesOnBoard(b, 0);
      final c1 = countStonesOnBoard(b, 1);
      if (c0 < min0) min0 = c0;
      if (c1 < min1) min1 = c1;
      tot0 += c0;
      tot1 += c1;
    }
    int? win;
    if (min1 != min0) {
      // Lower minimum stones means closer to being wiped out on that board
      win = min1 < min0 ? 0 : 1;
    } else if (tot0 != tot1) {
      win = tot0 > tot1 ? 0 : 1;
    }
    winner = win;
    if (win != null) {
      finalPlacings = rankWinners(2, [win]);
      resultText = '回合上限裁定：${name(win)} 凭借石子优势获胜！';
    } else {
      finalPlacings = [1, 1];
      resultText = '达到回合上限，双方势均力敌平局！';
    }
    host.log('游戏结束：$resultText');
  }

  @override
  void resign(int seat) {
    if (over) return;
    over = true;
    winner = 1 - seat;
    finalPlacings = rankWinners(2, [winner!]);
    resultText = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(resultText!);
  }

  @override
  void agreeDraw() {
    if (over) return;
    over = true;
    winner = null;
    finalPlacings = [1, 1];
    resultText = '双方协议和棋';
    host.log(resultText!);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final moves = over ? const <ShobuMove>[] : legalMovesFor(turn);
    return {
      'boards': [
        for (final b in boards) List<int>.of(b),
      ],
      'stoneCounts': [
        [for (var b = 0; b < 4; b++) countStonesOnBoard(b, 0)],
        [for (var b = 0; b < 4; b++) countStonesOnBoard(b, 1)],
      ],
      'turn': turn,
      'plyCount': plyCount,
      'legalMoves': [
        for (final m in moves)
          {
            'pBoard': m.pBoard,
            'pFrom': m.pFrom,
            'pTo': m.pTo,
            'aBoard': m.aBoard,
            'aFrom': m.aFrom,
            'aTo': m.aTo,
            'dir': m.dir,
            'steps': m.steps,
            'pushed': m.pushed,
            'pushedOff': m.pushedOff,
          },
      ],
      'lastMove': lastMove,
      'over': over,
      'winner': winner,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMovesFor(seat);
    if (moves.isEmpty) return null;

    // Precompute opponent stone counts per board
    final oppCounts = [for (var b = 0; b < 4; b++) countStonesOnBoard(b, 1 - seat)];

    // Always take an immediate winning push off the board
    for (final m in moves) {
      if (m.pushedOff && oppCounts[m.aBoard] <= 1) {
        return m.toAction();
      }
    }

    if (botLevel == 0) {
      // Even level 0 takes a push-off 65% of the time so games finish briskly
      final pushOffs = moves.where((m) => m.pushedOff).toList();
      if (pushOffs.isNotEmpty && rng.nextDouble() < 0.65) {
        return pushOffs[rng.nextInt(pushOffs.length)].toAction();
      }
      return moves[rng.nextInt(moves.length)].toAction();
    }

    ShobuMove best = moves.first;
    var bestScore = -1000000;
    final oppStone = 2 - seat;

    for (final m in moves) {
      var sc = rng.nextInt(9);
      final oppRem = oppCounts[m.aBoard];

      if (m.pushedOff) {
        // Huge reward for eliminating an enemy stone, amplified when few remain on that board
        sc += 1200 + (5 - oppRem) * 450;
      } else if (m.pushed) {
        sc += 180 + (5 - oppRem) * 60;
      }

      // Centrality bonus for our landing squares so our stones stay mobile and safe from edges
      final pr = m.pTo ~/ 4, pc = m.pTo % 4;
      final ar = m.aTo ~/ 4, ac = m.aTo % 4;
      if (pr >= 1 && pr <= 2 && pc >= 1 && pc <= 2) sc += 25;
      if (ar >= 1 && ar <= 2 && ac >= 1 && ac <= 2) sc += 20;

      // Approach enemy stones on aggressive board
      final bAgg = boards[m.aBoard];
      var minDist = 10;
      for (var idx = 0; idx < 16; idx++) {
        if (bAgg[idx] == oppStone) {
          final er = idx ~/ 4, ec = idx % 4;
          final d = (ar - er).abs() + (ac - ec).abs();
          if (d < minDist) minDist = d;
        }
      }
      sc += (6 - minDist) * (6 - oppRem) * 6;

      if (sc > bestScore) {
        bestScore = sc;
        best = m;
      }
    }

    return best.toAction();
  }
}
