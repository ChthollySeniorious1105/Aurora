import 'dart:math';

import '../../src/engine.dart';

const List<(int, int)> loaDirs = [
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
  (-1, -1),
  (1, 1),
  (-1, 1),
  (1, -1),
];

String loaCoord(int cell) {
  if (cell < 0 || cell >= 64) return '?';
  final r = cell ~/ 8, c = cell % 8;
  return '${String.fromCharCode(65 + c)}${8 - r}';
}

class LoaMove {
  final int from;
  final int to;
  final int distance;
  final bool capture;
  const LoaMove(this.from, this.to, this.distance, {this.capture = false});

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'from': from,
        'to': to,
      };
}

class LinesOfAction extends GameEngine {
  static const int maxPlies = 160;

  /// 64 cells (8×8): -1 = empty, 0 = Black (seat 0), 1 = White (seat 1).
  final List<int> board = List.filled(64, -1);
  final List<int> recentHashes = [];

  int turn = 0; // 0 = Black, 1 = White
  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  LinesOfAction(super.setup);

  String get layout => setup.opt<String>('layout', 'standard');

  int _parseCell(Object? v) {
    if (v is List && v.length >= 2) {
      final r = asInt(v[0], -1), c = asInt(v[1], -1);
      if (r < 0 || r >= 8 || c < 0 || c >= 8) return -1;
      return r * 8 + c;
    }
    final idx = asInt(v, -1);
    return (idx >= 0 && idx < 64) ? idx : -1;
  }

  @override
  void start() {
    board.fillRange(0, 64, -1);
    recentHashes.clear();

    if (layout == 'scrambled') {
      // Scrambled Eggs layout: alternating Black and White along the 4 edges
      for (var c = 1; c <= 6; c++) {
        board[0 * 8 + c] = c.isOdd ? 0 : 1;
        board[7 * 8 + c] = (7 + c).isOdd ? 0 : 1;
      }
      for (var r = 1; r <= 6; r++) {
        board[r * 8 + 0] = r.isOdd ? 0 : 1;
        board[r * 8 + 7] = (r + 7).isOdd ? 0 : 1;
      }
    } else {
      // Standard layout: Black on top/bottom rows (cols 1..6), White on left/right cols (rows 1..6)
      for (var c = 1; c <= 6; c++) {
        board[0 * 8 + c] = 0;
        board[7 * 8 + c] = 0;
      }
      for (var r = 1; r <= 6; r++) {
        board[r * 8 + 0] = 1;
        board[r * 8 + 7] = 1;
      }
    }

    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    recentHashes.add(_hashBoard(0));
    note = '黑方先行：沿八方向移动，步数必须等于该整条直线上双方棋子的总数，率先将己方所有棋子八方向连成一片者获胜！';
    result = '';
  }

  int _hashBoard(int nextTurn) {
    var h = nextTurn + 23;
    for (var i = 0; i < 64; i++) {
      h = (h * 41 + board[i] + 2) & 0x3FFFFFFF;
    }
    return h;
  }

  /// Counts the total number of pieces (both Black and White) on the line passing
  /// through `(r0, c0)` in direction `(dr, dc)`.
  int linePieceCount(int r0, int c0, int dr, int dc) {
    var count = board[r0 * 8 + c0] != -1 ? 1 : 0;
    var r = r0 + dr, c = c0 + dc;
    while (r >= 0 && r < 8 && c >= 0 && c < 8) {
      if (board[r * 8 + c] != -1) count++;
      r += dr;
      c += dc;
    }
    r = r0 - dr;
    c = c0 - dc;
    while (r >= 0 && r < 8 && c >= 0 && c < 8) {
      if (board[r * 8 + c] != -1) count++;
      r -= dr;
      c -= dc;
    }
    return count;
  }

  /// Validates moving `seat`'s piece from [from] to [to].
  LoaMove? validateMove(int seat, int from, int to) {
    if (from < 0 || from >= 64 || to < 0 || to >= 64 || from == to) return null;
    if (board[from] != seat) return null;
    if (board[to] == seat) return null; // Cannot land on own piece

    final r0 = from ~/ 8, c0 = from % 8;
    final r1 = to ~/ 8, c1 = to % 8;
    final diffR = r1 - r0, diffC = c1 - c0;
    if (diffR != 0 && diffC != 0 && diffR.abs() != diffC.abs()) return null;

    final dr = diffR.sign, dc = diffC.sign;
    final dist = max(diffR.abs(), diffC.abs());
    final required = linePieceCount(r0, c0, dr, dc);
    if (dist != required) return null;

    final opp = 1 - seat;
    for (var step = 1; step < dist; step++) {
      final mr = r0 + dr * step, mc = c0 + dc * step;
      if (board[mr * 8 + mc] == opp) {
        return null; // Cannot jump over opponent piece
      }
    }

    return LoaMove(from, to, dist, capture: board[to] == opp);
  }

  /// Generates all legal moves for [seat].
  List<LoaMove> legalMoves(int seat) {
    final out = <LoaMove>[];
    final opp = 1 - seat;
    for (var from = 0; from < 64; from++) {
      if (board[from] != seat) continue;
      final r0 = from ~/ 8, c0 = from % 8;
      for (final (dr, dc) in loaDirs) {
        final dist = linePieceCount(r0, c0, dr, dc);
        final r1 = r0 + dr * dist, c1 = c0 + dc * dist;
        if (r1 < 0 || r1 >= 8 || c1 < 0 || c1 >= 8) continue;
        final to = r1 * 8 + c1;
        if (board[to] == seat) continue;
        var blocked = false;
        for (var step = 1; step < dist; step++) {
          if (board[(r0 + dr * step) * 8 + (c0 + dc * step)] == opp) {
            blocked = true;
            break;
          }
        }
        if (!blocked) {
          out.add(LoaMove(from, to, dist, capture: board[to] == opp));
        }
      }
    }
    return out;
  }

  /// Returns `(componentCount, largestComponentSize, totalPieces)` for [seat].
  (int, int, int) componentStats(int seat) {
    final pieces = <int>[
      for (var i = 0; i < 64; i++)
        if (board[i] == seat) i,
    ];
    if (pieces.length <= 1) {
      return (1, pieces.length, pieces.length);
    }
    var visitedMask = 0;
    var components = 0;
    var largest = 0;
    final queue = <int>[];

    for (var idx = 0; idx < pieces.length; idx++) {
      if ((visitedMask & (1 << idx)) != 0) continue;
      components++;
      visitedMask |= (1 << idx);
      queue
        ..clear()
        ..add(pieces[idx]);
      var head = 0;
      while (head < queue.length) {
        final cur = queue[head++];
        final cr = cur ~/ 8, cc = cur % 8;
        for (var j = 0; j < pieces.length; j++) {
          if ((visitedMask & (1 << j)) != 0) continue;
          final p = pieces[j];
          final pr = p ~/ 8, pc = p % 8;
          if ((cr - pr).abs() <= 1 && (cc - pc).abs() <= 1) {
            visitedMask |= (1 << j);
            queue.add(p);
          }
        }
      }
      if (queue.length > largest) {
        largest = queue.length;
      }
    }
    return (components, largest, pieces.length);
  }

  bool isConnected(int seat) => componentStats(seat).$1 <= 1;

  /// Evaluates spatial cohesion of [seat]'s pieces around their center of mass.
  double cohesionScore(int seat) {
    var sumR = 0.0, sumC = 0.0;
    final pieces = <int>[];
    for (var i = 0; i < 64; i++) {
      if (board[i] == seat) {
        pieces.add(i);
        sumR += i ~/ 8;
        sumC += i % 8;
      }
    }
    if (pieces.length <= 1) return 1000.0;
    final comR = sumR / pieces.length, comC = sumC / pieces.length;

    var distSum = 0.0;
    var centerBonus = 0.0;
    for (final p in pieces) {
      final r = p ~/ 8, c = p % 8;
      final d = max((r - comR).abs(), (c - comC).abs());
      distSum += d * d;
      // Slight preference for keeping center of mass near board center (3.5, 3.5)
      centerBonus -= ((r - 3.5).abs() + (c - 3.5).abs()) * 1.5;
    }
    final (comps, largest, total) = componentStats(seat);
    return -distSum * 14.0 - comps * 160.0 + (largest / total) * 240.0 + centerBonus;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'move');
    if (t != 'move') throw GameError('未知操作');

    final from = _parseCell(action['from']);
    final to = _parseCell(action['to']);
    if (from < 0 || to < 0) throw GameError('请选择要移动的棋子和目标格');

    final mv = validateMove(seat, from, to);
    if (mv == null) {
      throw GameError('非法移动：步数必须等于整条直线上双方棋子总数，且不能越过对方棋子或落在己方棋子上');
    }

    board[from] = -1;
    board[to] = seat;
    plies++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'distance': mv.distance,
      'capture': mv.capture,
    };

    final sideName = seat == 0 ? '黑方' : '白方';
    final capText = mv.capture ? '（吃子！）' : '';
    note = '${name(seat)}（$sideName）${loaCoord(from)}→${loaCoord(to)}（沿线共 ${mv.distance} 子）$capText';

    // Win check: moving player checked FIRST (if simultaneous connection via capture, moving player wins)
    if (isConnected(seat)) {
      _finish(seat, '${name(seat)}（$sideName）将所有棋子连成一片，立即获胜！');
      return;
    }
    final opp = 1 - seat;
    if (isConnected(opp)) {
      final oppSide = opp == 0 ? '黑方' : '白方';
      _finish(opp, '吃子后 ${name(opp)}（$oppSide）剩余棋子连成一片，${name(opp)} 获胜！');
      return;
    }

    final nextMoves = legalMoves(opp);
    if (nextMoves.isEmpty || plies >= maxPlies) {
      _resolveByConnectivity(nextMoves.isEmpty ? '${name(opp)} 无合法行动' : '达到回合上限');
      return;
    }

    turn = opp;
    recentHashes.add(_hashBoard(turn));
    if (recentHashes.length > 24) {
      recentHashes.removeAt(0);
    }
  }

  void _resolveByConnectivity(String reason) {
    final (c0, l0, _) = componentStats(0);
    final (c1, l1, _) = componentStats(1);
    if (c0 != c1) {
      final w = c0 < c1 ? 0 : 1;
      _finish(w, '$reason，${name(w)} 连通分块更少（$c0:$c1）获胜！');
    } else if (l0 != l1) {
      final w = l0 > l1 ? 0 : 1;
      _finish(w, '$reason，${name(w)} 最大连通棋群更大（$l0:$l1）获胜！');
    } else {
      _finish(2, '$reason，双方连通度完全相同，判和');
    }
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
    final s0 = componentStats(0);
    final s1 = componentStats(1);
    final moves = _over ? const <LoaMove>[] : legalMoves(turn);
    return {
      'board': List<int>.of(board),
      'layout': layout,
      'turn': turn,
      'plies': plies,
      'maxPlies': maxPlies,
      'components': [s0.$1, s1.$1],
      'largest': [s0.$2, s1.$2],
      'counts': [s0.$3, s1.$3],
      'legalMoves': [
        for (final m in moves) [m.from, m.to, m.distance, m.capture ? 1 : 0]
      ],
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
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;
    final opp = 1 - seat;

    // 1. Check for immediate connection win
    for (final mv in moves) {
      final prevTo = board[mv.to];
      board[mv.from] = -1;
      board[mv.to] = seat;
      final win = isConnected(seat);
      board[mv.from] = seat;
      board[mv.to] = prevTo;
      if (win) return mv.toAction();
    }

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      return moves[rng.nextInt(moves.length)].toAction();
    }

    var bestScore = -1e12;
    var bestMove = moves.first;

    for (final mv in moves) {
      final prevTo = board[mv.to];
      board[mv.from] = -1;
      board[mv.to] = seat;

      var score = rng.nextDouble() * 8.0;

      // Never gift opponent an immediate connection win via capture unless forced
      if (isConnected(opp)) {
        score -= 500000.0;
      } else {
        final myCohesion = cohesionScore(seat);
        final oppCohesion = cohesionScore(opp);
        score += myCohesion - oppCohesion * 0.65;

        // Avoid repeating recent board states
        final h = _hashBoard(opp);
        if (recentHashes.contains(h)) {
          score -= 3500.0;
        }

        // At hard level, check if opponent has a 1-move win reply
        if (botLevel >= 2) {
          final oppMoves = legalMoves(opp);
          for (final om in oppMoves) {
            final p2 = board[om.to];
            board[om.from] = -1;
            board[om.to] = opp;
            final oppWins = isConnected(opp);
            board[om.from] = opp;
            board[om.to] = p2;
            if (oppWins) {
              score -= 90000.0;
              break;
            }
          }
        }
      }

      board[mv.from] = seat;
      board[mv.to] = prevTo;

      if (score > bestScore) {
        bestScore = score;
        bestMove = mv;
      }
    }

    return bestMove.toAction();
  }
}
