import 'dart:math';

import '../../src/engine.dart';

const List<(int, int)> amazonsDirs = [
  (-1, -1),
  (-1, 0),
  (-1, 1),
  (0, -1),
  (0, 1),
  (1, -1),
  (1, 0),
  (1, 1),
];

String amazonsCoord(int size, int cell) {
  if (cell < 0 || cell >= size * size) return '?';
  final r = cell ~/ size, c = cell % size;
  return '${String.fromCharCode(65 + c)}${size - r}';
}

class AmazonsMove {
  final int from;
  final int to;
  final int arrow;
  const AmazonsMove(this.from, this.to, this.arrow);

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'from': from,
        'to': to,
        'arrow': arrow,
      };
}

class Amazons extends GameEngine {
  late int size;

  /// Board of length `size * size`: -1 = empty, 0 = White Amazon (seat 0),
  /// 1 = Black Amazon (seat 1), 2 = Burned Arrow.
  late List<int> board;

  int turn = 0; // 0 = White (first), 1 = Black (second)
  int plies = 0;
  int arrowCount = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Amazons(super.setup);

  int _parseCell(Object? v) {
    if (v is List && v.length >= 2) {
      final r = asInt(v[0], -1), c = asInt(v[1], -1);
      if (r < 0 || r >= size || c < 0 || c >= size) return -1;
      return r * size + c;
    }
    final idx = asInt(v, -1);
    return (idx >= 0 && idx < size * size) ? idx : -1;
  }

  @override
  void start() {
    final optSize = setup.opt<int>('size', 8);
    size = (optSize == 10) ? 10 : 8;
    board = List.filled(size * size, -1);

    // Standard symmetrical starting coordinates for 4 Amazons per side
    final c1 = size == 10 ? 3 : 2;
    final c2 = size - 1 - c1; // 6 for 10x10, 5 for 8x8

    // Seat 0 (White, bottom): (N-1, c1), (N-1, c2), (c2, 0), (c2, N-1)
    board[(size - 1) * size + c1] = 0;
    board[(size - 1) * size + c2] = 0;
    board[c2 * size + 0] = 0;
    board[c2 * size + (size - 1)] = 0;

    // Seat 1 (Black, top): (0, c1), (0, c2), (c1, 0), (c1, N-1)
    board[0 * size + c1] = 1;
    board[0 * size + c2] = 1;
    board[c1 * size + 0] = 1;
    board[c1 * size + (size - 1)] = 1;

    turn = 0;
    plies = 0;
    arrowCount = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    note = '白方先行：先移动 1 枚亚马逊女战士，再从落点发射 1 支火焰箭封锁棋盘格';
    result = '';
  }

  /// Returns all squares reachable from [origin] by Queen movement (8 straight rays).
  /// [ignoreCell] is treated as empty (used when shooting an arrow after moving from [ignoreCell]).
  List<int> queenReachable(int origin, {int ignoreCell = -1}) {
    final out = <int>[];
    if (origin < 0 || origin >= size * size) return out;
    final r0 = origin ~/ size, c0 = origin % size;
    for (final (dr, dc) in amazonsDirs) {
      var r = r0 + dr, c = c0 + dc;
      while (r >= 0 && r < size && c >= 0 && c < size) {
        final idx = r * size + c;
        if (board[idx] != -1 && idx != ignoreCell) break;
        out.add(idx);
        r += dr;
        c += dc;
      }
    }
    return out;
  }

  bool isLineMoveLegal(int origin, int target, {int ignoreCell = -1}) {
    if (origin < 0 || origin >= size * size) return false;
    if (target < 0 || target >= size * size || origin == target) return false;
    final r0 = origin ~/ size, c0 = origin % size;
    final r1 = target ~/ size, c1 = target % size;
    final dr = r1 - r0, dc = c1 - c0;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return false;
    final stepR = dr.sign, stepC = dc.sign;
    var r = r0 + stepR, c = c0 + stepC;
    while (true) {
      final idx = r * size + c;
      if (board[idx] != -1 && idx != ignoreCell) return false;
      if (idx == target) return true;
      r += stepR;
      c += stepC;
    }
  }

  List<int> piecesOf(int seat) => [
        for (var i = 0; i < board.length; i++)
          if (board[i] == seat) i,
      ];

  bool hasAnyLegalMove(int seat) {
    for (var i = 0; i < board.length; i++) {
      if (board[i] != seat) continue;
      final r0 = i ~/ size, c0 = i % size;
      for (final (dr, dc) in amazonsDirs) {
        final r = r0 + dr, c = c0 + dc;
        if (r >= 0 && r < size && c >= 0 && c < size && board[r * size + c] == -1) {
          return true;
        }
      }
    }
    return false;
  }

  /// Counts total Queen-ray mobility for [seat] on the current board.
  int queenMobility(int seat) {
    var total = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != seat) continue;
      final r0 = i ~/ size, c0 = i % size;
      for (final (dr, dc) in amazonsDirs) {
        var r = r0 + dr, c = c0 + dc;
        while (r >= 0 && r < size && c >= 0 && c < size && board[r * size + c] == -1) {
          total++;
          r += dr;
          c += dc;
        }
      }
    }
    return total;
  }

  /// Counts immediate adjacent empty squares (King mobility) for [seat], heavily weighting trapped pieces.
  int kingMobilityScore(int seat) {
    var score = 0;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != seat) continue;
      final r0 = i ~/ size, c0 = i % size;
      var deg = 0;
      for (final (dr, dc) in amazonsDirs) {
        final r = r0 + dr, c = c0 + dc;
        if (r >= 0 && r < size && c >= 0 && c < size && board[r * size + c] == -1) {
          deg++;
        }
      }
      if (deg == 0) {
        score -= 40;
      } else if (deg == 1) {
        score -= 12;
      } else {
        score += deg * 4;
      }
    }
    return score;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'move');
    if (t != 'move') throw GameError('未知操作');

    final from = _parseCell(action['from']);
    final to = _parseCell(action['to']);
    final arrow = _parseCell(action['arrow']);
    if (from < 0 || to < 0 || arrow < 0) {
      throw GameError('请依次选择己方女战士、移动目标格与箭矢封锁格');
    }
    if (board[from] != seat) {
      throw GameError('必须选择你自己的亚马逊女战士');
    }
    if (!isLineMoveLegal(from, to)) {
      throw GameError('移动路径必须沿八方向直线且途中不能有棋子或箭矢阻挡');
    }
    if (!isLineMoveLegal(to, arrow, ignoreCell: from)) {
      throw GameError('射箭路径必须从新落点沿八方向直线且途中无阻挡');
    }

    board[from] = -1;
    board[to] = seat;
    board[arrow] = 2;
    plies++;
    arrowCount++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'arrow': arrow,
    };

    final sideName = seat == 0 ? '白方' : '黑方';
    note = '${name(seat)}（$sideName）移动 ${amazonsCoord(size, from)}→${amazonsCoord(size, to)}，射箭封锁 ${amazonsCoord(size, arrow)}';

    final nextSeat = 1 - seat;
    if (!hasAnyLegalMove(nextSeat)) {
      _finish(seat, '${name(nextSeat)} 所有亚马逊女战士均被封锁无路可走，${name(seat)} 获胜！');
      return;
    }

    turn = nextSeat;
  }

  void _finish(int w, String msg) {
    _over = true;
    winner = w;
    result = msg;
    note = msg;
    if (w == 2) {
      _placings = [1, 1];
    } else {
      _placings = rankWinners(players, [w]);
    }
    host.log(msg);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    final w = 1 - seat;
    _finish(w, '${name(seat)} 认输，${name(w)} 获胜！');
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _finish(2, '双方议和');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'size': size,
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'arrowCount': arrowCount,
      'myMobility': queenMobility(turn),
      'oppMobility': queenMobility(1 - turn),
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final opp = 1 - seat;
    final ownPieces = piecesOf(seat);
    final oppPieces = piecesOf(opp);

    // Stage 1: Evaluate all legal (from, to) queen moves and keep top candidates
    final candidateMoves = <(int, int, double)>[];
    for (final f in ownPieces) {
      final targets = queenReachable(f);
      if (targets.isEmpty) continue;
      board[f] = -1;
      for (final t in targets) {
        board[t] = seat;
        final myQ = queenMobility(seat);
        final oppQ = queenMobility(opp);
        final myK = kingMobilityScore(seat);
        final oppK = kingMobilityScore(opp);
        final score = (myQ * 1.2 - oppQ * 1.6) + (myK - oppK * 1.5) + rng.nextDouble() * 2.0;
        candidateMoves.add((f, t, score));
        board[t] = -1;
      }
      board[f] = seat;
    }

    if (candidateMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = candidateMoves[rng.nextInt(candidateMoves.length)];
      final arrows = queenReachable(pick.$2, ignoreCell: pick.$1);
      final a = arrows[rng.nextInt(arrows.length)];
      return AmazonsMove(pick.$1, pick.$2, a).toAction();
    }

    candidateMoves.sort((a, b) => b.$3.compareTo(a.$3));
    final limit = min(candidateMoves.length, botLevel >= 2 ? 28 : 18);

    var bestScore = -1e12;
    var bestMove = AmazonsMove(candidateMoves.first.$1, candidateMoves.first.$2, candidateMoves.first.$1);

    for (var i = 0; i < limit; i++) {
      final (f, t, _) = candidateMoves[i];
      board[f] = -1;
      board[t] = seat;

      final arrows = queenReachable(t);
      for (final a in arrows) {
        board[a] = 2;

        // Instant win check: opponent has 0 legal moves
        if (!hasAnyLegalMove(opp)) {
          board[a] = -1;
          board[t] = -1;
          board[f] = seat;
          return AmazonsMove(f, t, a).toAction();
        }

        final myQ = queenMobility(seat);
        final oppQ = queenMobility(opp);
        final myK = kingMobilityScore(seat);
        final oppK = kingMobilityScore(opp);

        // Bonus for shooting arrows adjacent to active opponent Amazons
        var adjBonus = 0.0;
        final ar = a ~/ size, ac = a % size;
        for (final op in oppPieces) {
          final or = op ~/ size, oc = op % size;
          final dist = max((ar - or).abs(), (ac - oc).abs());
          if (dist == 1) {
            adjBonus += 9.0;
          } else if (dist == 2) {
            adjBonus += 3.0;
          }
        }

        final score = (myQ * 1.3 - oppQ * 2.1) + (myK * 1.2 - oppK * 2.2) + adjBonus + rng.nextDouble() * 1.5;
        if (score > bestScore) {
          bestScore = score;
          bestMove = AmazonsMove(f, t, a);
        }

        board[a] = -1;
      }

      board[t] = -1;
      board[f] = seat;
    }

    return bestMove.toAction();
  }
}
