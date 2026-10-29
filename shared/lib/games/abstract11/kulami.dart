import '../../src/engine.dart';

/// 17 rectangular wooden planks partitioning the 8x8 (64-hole) Kulami board.
/// Areas:
/// - 4 planks of area 6 (2x3): IDs 0, 5, 10, 16
/// - 5 planks of area 4 (2x2): IDs 1, 4, 6, 9, 11
/// - 4 planks of area 3 (1x3): IDs 2, 3, 12, 13
/// - 4 planks of area 2 (1x2 / 2x1): IDs 7, 8, 14, 15
/// Total: 4*6 + 5*4 + 4*3 + 4*2 = 24 + 20 + 12 + 8 = 64 holes.
const List<List<int>> kulamiDefaultPlankGrid = [
  [0, 0, 0, 1, 1, 2, 2, 2],
  [0, 0, 0, 1, 1, 3, 3, 3],
  [4, 4, 5, 5, 5, 6, 6, 7],
  [4, 4, 5, 5, 5, 6, 6, 7],
  [8, 9, 9, 10, 10, 10, 11, 11],
  [8, 9, 9, 10, 10, 10, 11, 11],
  [12, 12, 12, 14, 14, 16, 16, 16],
  [13, 13, 13, 15, 15, 16, 16, 16],
];

const List<int> kulamiPlankAreas = [
  6, // 0: 2x3
  4, // 1: 2x2
  3, // 2: 1x3
  3, // 3: 1x3
  4, // 4: 2x2
  6, // 5: 2x3
  4, // 6: 2x2
  2, // 7: 2x1
  2, // 8: 2x1
  4, // 9: 2x2
  6, // 10: 2x3
  4, // 11: 2x2
  3, // 12: 1x3
  3, // 13: 1x3
  2, // 14: 1x2
  2, // 15: 1x2
  6, // 16: 2x3
];

/// 库拉米木板棋 (Kulami) — Andreas Kuhnekath's Mensa Select abstract strategy game.
class KulamiGame extends GameEngine {
  KulamiGame(super.setup);

  /// `plankId[r][c]` in `0..16`.
  late List<List<int>> plankId;

  /// `board[r][c]`: `-1` empty, `0` Red (seat 0), `1` Black (seat 1).
  late List<List<int>> board;

  /// Remaining marbles for each player.
  late List<int> remaining;

  int turn = 0;
  int turnCount = 0;
  (int, int)? lastMove;
  int lastPlankId = -1;
  int prevPlankId = -1;

  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;

  bool get isQuick => setup.opt<String>('mode', 'standard') == 'quick';
  int get maxMarbles => isQuick ? 22 : 28;

  @override
  void start() {
    plankId = [
      for (final row in kulamiDefaultPlankGrid) List<int>.from(row),
    ];
    board = List.generate(8, (_) => List.filled(8, -1));
    remaining = [maxMarbles, maxMarbles];
    turn = 0;
    turnCount = 0;
    lastMove = null;
    lastPlankId = -1;
    prevPlankId = -1;
    _over = false;
    winner = null;
    winReason = null;
  }

  /// True if hole `(r, c)` is a legal placement for the current state.
  bool isLegalPlace(int r, int c) {
    if (_over) return false;
    if (r < 0 || r >= 8 || c < 0 || c >= 8) return false;
    if (board[r][c] != -1) return false;
    if (lastMove == null) return true; // Turn 1: any hole
    final (lastR, lastC) = lastMove!;
    if (r != lastR && c != lastC) return false;
    final pid = plankId[r][c];
    if (pid == lastPlankId || pid == prevPlankId) return false;
    return true;
  }

  List<(int, int)> legalMoves() {
    if (_over || remaining[turn] <= 0) return const [];
    final out = <(int, int)>[];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (isLegalPlace(r, c)) {
          out.add((r, c));
        }
      }
    }
    return out;
  }

  /// Owner of each plank `0..16`: `0` if seat 0 has strictly more marbles,
  /// `1` if seat 1 has strictly more marbles, `-1` if tied or empty.
  List<int> computePlankOwners() {
    final c0 = List<int>.filled(17, 0);
    final c1 = List<int>.filled(17, 0);
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final v = board[r][c];
        final p = plankId[r][c];
        if (v == 0) c0[p]++;
        if (v == 1) c1[p]++;
      }
    }
    return [
      for (var p = 0; p < 17; p++)
        if (c0[p] > c1[p]) 0 else if (c1[p] > c0[p]) 1 else -1,
    ];
  }

  /// Plank Majority scores for `[seat0, seat1]`.
  List<int> computePlankScores() {
    final owners = computePlankOwners();
    var s0 = 0;
    var s1 = 0;
    for (var p = 0; p < 17; p++) {
      if (owners[p] == 0) s0 += kulamiPlankAreas[p];
      if (owners[p] == 1) s1 += kulamiPlankAreas[p];
    }
    return [s0, s1];
  }

  /// Size of the largest orthogonally (N, S, E, W) connected component of `seat`'s marbles.
  int computeLargestTerritory(int seat) {
    final visited = List.generate(8, (_) => List.filled(8, false));
    var best = 0;
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] == seat && !visited[r][c]) {
          var size = 0;
          final q = <(int, int)>[(r, c)];
          visited[r][c] = true;
          while (q.isNotEmpty) {
            final (cr, cc) = q.removeLast();
            size++;
            for (final (dr, dc) in dirs) {
              final nr = cr + dr;
              final nc = cc + dc;
              if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && !visited[nr][nc] && board[nr][nc] == seat) {
                visited[nr][nc] = true;
                q.add((nr, nc));
              }
            }
          }
          if (size > best) best = size;
        }
      }
    }
    return best;
  }

  /// Length of the longest contiguous line (horizontal, vertical, or diagonal) of `seat`'s marbles.
  int computeLongestLine(int seat) {
    var best = 0;
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (board[r][c] != seat) continue;
        for (final (dr, dc) in dirs) {
          var len = 0;
          var cr = r;
          var cc = c;
          while (cr >= 0 && cr < 8 && cc >= 0 && cc < 8 && board[cr][cc] == seat) {
            len++;
            cr += dr;
            cc += dc;
          }
          if (len > best) best = len;
        }
      }
    }
    return best;
  }

  /// Longest 5+ Line Bonus for `seat` (0 if longest line < 5, otherwise longest line length).
  int computeLineBonus(int seat) {
    final len = computeLongestLine(seat);
    return len >= 5 ? len : 0;
  }

  /// Total scores `[score0, score1]` combining:
  /// 1. Plank Majority (area 2, 3, 4, or 6 pts per won plank)
  /// 2. Largest Orthogonal Territory (size of largest orthogonally connected component)
  /// 3. Longest 5+ Line Bonus
  List<int> computeTotalScores() {
    final ps = computePlankScores();
    final t0 = computeLargestTerritory(0);
    final t1 = computeLargestTerritory(1);
    final l0 = computeLineBonus(0);
    final l1 = computeLineBonus(1);
    return [ps[0] + t0 + l0, ps[1] + t1 + l1];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作类型');

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    if (r < 0 || r >= 8 || c < 0 || c >= 8) {
      throw GameError('落子位置超出棋盘范围');
    }
    if (board[r][c] != -1) {
      throw GameError('该孔位已有弹珠');
    }
    if (lastMove != null) {
      final (lastR, lastC) = lastMove!;
      if (r != lastR && c != lastC) {
        throw GameError('必须落在对手上一手所在的行（第 ${lastR + 1} 行）或列（第 ${lastC + 1} 列）');
      }
      final pid = plankId[r][c];
      if (pid == lastPlankId) {
        throw GameError('不能落在对手刚下过的同一块木板上');
      }
      if (pid == prevPlankId) {
        throw GameError('不能落在上上回合刚下过的那块木板上');
      }
    }

    board[r][c] = seat;
    remaining[seat]--;
    prevPlankId = lastPlankId;
    lastPlankId = plankId[r][c];
    lastMove = (r, c);
    turnCount++;

    final nextSeat = 1 - seat;
    turn = nextSeat;

    final allPlaced = remaining[0] <= 0 && remaining[1] <= 0;
    final nextHasMoves = !allPlaced && remaining[nextSeat] > 0 && legalMoves().isNotEmpty;

    if (!nextHasMoves) {
      _finishGame(allPlaced ? '双方弹珠全部放完' : '${name(nextSeat)} 无合法落点');
    }
  }

  void _finishGame(String triggerReason) {
    _over = true;
    final ps = computePlankScores();
    final t0 = computeLargestTerritory(0);
    final t1 = computeLargestTerritory(1);
    final l0 = computeLineBonus(0);
    final l1 = computeLineBonus(1);
    final totals = [ps[0] + t0 + l0, ps[1] + t1 + l1];

    if (totals[0] > totals[1]) {
      winner = 0;
      winReason = '$triggerReason，终局结算 ${totals[0]} : ${totals[1]}，${name(0)} 获胜！';
    } else if (totals[1] > totals[0]) {
      winner = 1;
      winReason = '$triggerReason，终局结算 ${totals[0]} : ${totals[1]}，${name(1)} 获胜！';
    } else {
      // Tie-break by plank majority score, else draw
      if (ps[0] > ps[1]) {
        winner = 0;
        winReason = '$triggerReason，总分 ${totals[0]} 平，${name(0)} 凭木板多数分优势获胜！';
      } else if (ps[1] > ps[0]) {
        winner = 1;
        winReason = '$triggerReason，总分 ${totals[0]} 平，${name(1)} 凭木板多数分优势获胜！';
      } else {
        winner = -1;
        winReason = '$triggerReason，终局结算 ${totals[0]} : ${totals[1]} 平局！';
      }
    }
    host.log(winReason!);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final ps = computePlankScores();
    final t0 = computeLargestTerritory(0);
    final t1 = computeLargestTerritory(1);
    final len0 = computeLongestLine(0);
    final len1 = computeLongestLine(1);
    final b0 = len0 >= 5 ? len0 : 0;
    final b1 = len1 >= 5 ? len1 : 0;
    final totals = [ps[0] + t0 + b0, ps[1] + t1 + b1];
    final legals = legalMoves();

    return {
      'plankId': [
        for (final row in plankId) List<int>.from(row),
      ],
      'plankAreas': kulamiPlankAreas,
      'board': [
        for (final row in board) List<int>.from(row),
      ],
      'remaining': List<int>.from(remaining),
      'turn': turn,
      'turnCount': turnCount,
      'lastMove': lastMove == null ? null : {'r': lastMove!.$1, 'c': lastMove!.$2},
      'lastPlankId': lastPlankId,
      'prevPlankId': prevPlankId,
      'legalMoves': [
        for (final (r, c) in legals) [r, c]
      ],
      'plankOwners': computePlankOwners(),
      'plankScores': ps,
      'largestTerritory': [t0, t1],
      'longestLine': [len0, len1],
      'lineBonus': [b0, b1],
      'scores': totals,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'mode': isQuick ? 'quick' : 'standard',
    };
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return [1, 1];
    return rankWinners(2, [winner!]);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final moves = legalMoves();
    if (moves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      final (r, c) = moves[rng.nextInt(moves.length)];
      return {'type': 'place', 'r': r, 'c': c};
    }

    var bestScore = -1e9;
    final bestMoves = <(int, int)>[];

    for (final (r, c) in moves) {
      final s = _evaluateMove(seat, r, c);
      if (s > bestScore + 1e-6) {
        bestScore = s;
        bestMoves
          ..clear()
          ..add((r, c));
      } else if ((s - bestScore).abs() <= 1e-6) {
        bestMoves.add((r, c));
      }
    }

    final (br, bc) = bestMoves[rng.nextInt(bestMoves.length)];
    return {'type': 'place', 'r': br, 'c': bc};
  }

  double _evaluateMove(int seat, int r, int c) {
    final opp = 1 - seat;
    board[r][c] = seat;
    final totals = computeTotalScores();
    var diff = (totals[seat] - totals[opp]).toDouble();

    // Bonus fororthogonal adjacency to own marbles
    const ortho = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (final (dr, dc) in ortho) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && board[nr][nc] == seat) {
        diff += 1.5;
      }
    }

    board[r][c] = -1;
    return diff + rng.nextDouble() * 0.3;
  }
}
