import 'dart:math';

import '../../src/engine.dart';

typedef AbHex = (int, int);

/// 6 axial directions: 0=E(右), 1=NE(右上), 2=NW(左上), 3=W(左), 4=SW(左下), 5=SE(右下).
const List<AbHex> abDirs = [
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, 0),
  (-1, 1),
  (0, 1),
];

const List<String> abDirNames = ['右', '右上', '左上', '左', '左下', '右下'];

bool abOnBoard(int q, int r) => q >= -4 && q <= 4 && r >= -4 && r <= 4 && (q + r).abs() <= 4;

int abDistCenter(int q, int r) => max(q.abs(), max(r.abs(), (q + r).abs()));

/// All 61 hex cells of the radius-4 board, ordered by r (-4..4) then q.
final List<AbHex> abaloneCells = [
  for (var r = -4; r <= 4; r++)
    for (var q = max(-4, -4 - r); q <= min(4, 4 - r); q++) (q, r),
];

final Map<AbHex, int> _cellToIndex = {
  for (var i = 0; i < abaloneCells.length; i++) abaloneCells[i]: i,
};

int abIndex(int q, int r) => _cellToIndex[(q, r)] ?? -1;

String abCoord(int q, int r) {
  final rowChar = String.fromCharCode(65 + (4 - r)); // A..I from bottom to top
  final colNum = q + 5 + min(0, r);
  return '$rowChar$colNum';
}

class AbaloneMove {
  /// Own marbles sorted canonically (for in-line moves, ordered from tail to head along [dir]).
  final List<AbHex> marbles;
  final int dir;
  final bool inLine;
  final List<AbHex> pushed;
  final bool ejects;

  const AbaloneMove({
    required this.marbles,
    required this.dir,
    required this.inLine,
    this.pushed = const [],
    this.ejects = false,
  });

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'marbles': [
          for (final (q, r) in marbles) [q, r]
        ],
        'dir': dir,
      };
}

class Abalone extends GameEngine {
  static const int winEjected = 6;
  static const int maxPlies = 200;

  /// 61 cells: -1 = empty, 0 = Black (seat 0), 1 = White (seat 1).
  final List<int> board = List.filled(61, -1);

  /// Number of opponent marbles ejected by each color [blackEjected, whiteEjected].
  final List<int> ejected = [0, 0];

  /// Recent position hashes (updated only in start/handle for undo determinism).
  final List<int> recentHashes = [];

  int turn = 0; // 0 = Black, 1 = White
  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Abalone(super.setup);

  String get layout => setup.opt<String>('layout', 'standard');

  int at(int q, int r) {
    final idx = abIndex(q, r);
    return idx < 0 ? -1 : board[idx];
  }

  void setAt(int q, int r, int v) {
    final idx = abIndex(q, r);
    if (idx >= 0) board[idx] = v;
  }

  @override
  void start() {
    board.fillRange(0, 61, -1);
    ejected[0] = 0;
    ejected[1] = 0;
    recentHashes.clear();

    if (layout == 'belgian') {
      // Belgian Daisy: two 7-marble daisies per player in opposite corners
      void placeDaisy(int cq, int cr, int color) {
        setAt(cq, cr, color);
        for (final (dq, dr) in abDirs) {
          setAt(cq + dq, cr + dr, color);
        }
      }

      placeDaisy(-3, 3, 0);
      placeDaisy(3, -3, 0);
      placeDaisy(0, -3, 1);
      placeDaisy(0, 3, 1);
    } else {
      // Standard layout
      for (var q = -4; q <= 0; q++) {
        setAt(q, 4, 0);
      }
      for (var q = -4; q <= 1; q++) {
        setAt(q, 3, 0);
      }
      for (var q = -2; q <= 0; q++) {
        setAt(q, 2, 0);
      }

      for (var q = 0; q <= 4; q++) {
        setAt(q, -4, 1);
      }
      for (var q = -1; q <= 4; q++) {
        setAt(q, -3, 1);
      }
      for (var q = 0; q <= 2; q++) {
        setAt(q, -2, 1);
      }
    }

    turn = 0;
    plies = 0;
    recentHashes.add(_hashBoard(0));
    note = '黑方先行，先将对方 6 枚棋子推出棋盘者获胜';
  }

  int _hashBoard(int nextTurn) {
    var h = nextTurn + 17;
    for (var i = 0; i < 61; i++) {
      h = (h * 37 + board[i] + 2) & 0x3FFFFFFF;
    }
    return h;
  }

  /// Validates whether [rawCells] (1..3 own marbles of [color]) can move in [dir] (`0..5`).
  /// Returns the normalized [AbaloneMove] if legal, or null if illegal.
  AbaloneMove? validateMove(int color, List<AbHex> rawCells, int dir) {
    if (dir < 0 || dir >= 6) return null;
    if (rawCells.isEmpty || rawCells.length > 3) return null;
    final unique = rawCells.toSet();
    if (unique.length != rawCells.length) return null;
    for (final (q, r) in unique) {
      if (!abOnBoard(q, r) || at(q, r) != color) return null;
    }

    final (dq, dr) = abDirs[dir];

    if (unique.length == 1) {
      final m = unique.first;
      final nq = m.$1 + dq, nr = m.$2 + dr;
      if (!abOnBoard(nq, nr) || at(nq, nr) != -1) return null;
      return AbaloneMove(marbles: [m], dir: dir, inLine: true);
    }

    // Check collinearity & contiguity for 2 or 3 marbles
    int? lineAxis; // 0, 1, or 2
    List<AbHex>? orderedAlongAxis;
    for (var axis = 0; axis < 3; axis++) {
      final (aq, ar) = abDirs[axis];
      for (final start in unique) {
        final m1 = (start.$1 + aq, start.$2 + ar);
        if (!unique.contains(m1)) continue;
        if (unique.length == 2) {
          lineAxis = axis;
          orderedAlongAxis = [start, m1];
          break;
        } else {
          final m2 = (start.$1 + aq * 2, start.$2 + ar * 2);
          if (unique.contains(m2)) {
            lineAxis = axis;
            orderedAlongAxis = [start, m1, m2];
            break;
          }
        }
      }
      if (lineAxis != null) break;
    }
    if (lineAxis == null || orderedAlongAxis == null) return null;

    final isInLine = dir == lineAxis || dir == lineAxis + 3;
    if (isInLine) {
      // Order from tail to head along `dir`
      final marbles = dir == lineAxis ? orderedAlongAxis : orderedAlongAxis.reversed.toList();
      final k = marbles.length;
      final head = marbles.last;
      final ahead1 = (head.$1 + dq, head.$2 + dr);
      if (!abOnBoard(ahead1.$1, ahead1.$2)) return null;
      final occ1 = at(ahead1.$1, ahead1.$2);
      if (occ1 == -1) {
        return AbaloneMove(marbles: marbles, dir: dir, inLine: true);
      }
      if (occ1 == color) {
        return null; // Blocked by own marble
      }
      // Sumito check: occ1 is opponent (1 - color)
      final opp = 1 - color;
      final pushed = <AbHex>[ahead1];
      var cur = (ahead1.$1 + dq, ahead1.$2 + dr);
      while (abOnBoard(cur.$1, cur.$2) && at(cur.$1, cur.$2) == opp && pushed.length <= k) {
        pushed.add(cur);
        cur = (cur.$1 + dq, cur.$2 + dr);
      }
      if (pushed.length >= k) return null; // Need strictly more marbles (2>1, 3>1, 3>2)
      if (!abOnBoard(cur.$1, cur.$2)) {
        // Pushed off-board -> ejected!
        return AbaloneMove(marbles: marbles, dir: dir, inLine: true, pushed: pushed, ejects: true);
      }
      if (at(cur.$1, cur.$2) != -1) {
        return null; // Blocked behind opponent marbles
      }
      return AbaloneMove(marbles: marbles, dir: dir, inLine: true, pushed: pushed, ejects: false);
    } else {
      // Broadside move: every marble must step into an empty on-board cell
      for (final (q, r) in orderedAlongAxis) {
        final nq = q + dq, nr = r + dr;
        if (!abOnBoard(nq, nr) || at(nq, nr) != -1) return null;
      }
      return AbaloneMove(marbles: orderedAlongAxis, dir: dir, inLine: false);
    }
  }

  /// Generates all legal moves for [color].
  List<AbaloneMove> legalMoves(int color) {
    final out = <AbaloneMove>[];
    final own = <AbHex>[
      for (final c in abaloneCells)
        if (at(c.$1, c.$2) == color) c,
    ];
    final ownSet = own.toSet();

    // 1-marble groups
    for (final m in own) {
      for (var d = 0; d < 6; d++) {
        final mv = validateMove(color, [m], d);
        if (mv != null) out.add(mv);
      }
    }
    // 2-marble and 3-marble groups along axes 0, 1, 2
    for (final m in own) {
      for (var axis = 0; axis < 3; axis++) {
        final (aq, ar) = abDirs[axis];
        final m1 = (m.$1 + aq, m.$2 + ar);
        if (!ownSet.contains(m1)) continue;
        for (var d = 0; d < 6; d++) {
          final mv2 = validateMove(color, [m, m1], d);
          if (mv2 != null) out.add(mv2);
        }
        final m2 = (m.$1 + aq * 2, m.$2 + ar * 2);
        if (!ownSet.contains(m2)) continue;
        for (var d = 0; d < 6; d++) {
          final mv3 = validateMove(color, [m, m1, m2], d);
          if (mv3 != null) out.add(mv3);
        }
      }
    }
    return out;
  }

  void _applyMove(int color, AbaloneMove mv) {
    final (dq, dr) = abDirs[mv.dir];
    if (mv.pushed.isEmpty) {
      for (final (q, r) in mv.marbles) {
        setAt(q, r, -1);
      }
      for (final (q, r) in mv.marbles) {
        setAt(q + dq, r + dr, color);
      }
    } else {
      // In-line Sumito push
      final tail = mv.marbles.first;
      setAt(tail.$1, tail.$2, -1);
      final firstPushed = mv.pushed.first;
      setAt(firstPushed.$1, firstPushed.$2, color);
      if (mv.ejects) {
        ejected[color]++;
      } else {
        final lastPushed = mv.pushed.last;
        setAt(lastPushed.$1 + dq, lastPushed.$2 + dr, 1 - color);
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    if (asStr(action['type']) != 'move') throw GameError('未知操作');

    final rawList = action['marbles'];
    if (rawList is! List || rawList.isEmpty || rawList.length > 3) {
      throw GameError('请选择 1~3 枚同一直线相邻的己方棋子');
    }
    final cells = <AbHex>[];
    for (final item in rawList) {
      if (item is List && item.length >= 2) {
        cells.add((asInt(item[0]), asInt(item[1])));
      } else {
        final idx = asInt(item);
        if (idx >= 0 && idx < abaloneCells.length) {
          cells.add(abaloneCells[idx]);
        }
      }
    }
    final dir = asInt(action['dir']);
    final mv = validateMove(seat, cells, dir);
    if (mv == null) throw GameError('非法移动');

    _applyMove(seat, mv);
    plies++;

    final (dq, dr) = abDirs[dir];
    final toCells = [
      for (final (q, r) in mv.marbles) [q + dq, r + dr]
    ];
    lastAction = {
      'seat': seat,
      'dir': dir,
      'from': [
        for (final (q, r) in mv.marbles) [q, r]
      ],
      'to': toCells,
      'pushed': [
        for (final (q, r) in mv.pushed) [q, r]
      ],
      'ejects': mv.ejects,
    };

    final pushDesc = mv.ejects
        ? '，将对方 1 枚棋子推出棋盘！（${ejected[seat]}/$winEjected）'
        : (mv.pushed.isNotEmpty ? '，推动对方 ${mv.pushed.length} 枚棋子' : '');
    note = '${name(seat)} 向${abDirNames[dir]}${mv.inLine ? '推进' : '平移'} ${mv.marbles.length} 枚棋子$pushDesc';

    if (ejected[seat] >= winEjected) {
      _finish(seat, '${name(seat)} 率先推出 $winEjected 枚对方棋子获胜！');
      return;
    }

    if (plies >= maxPlies) {
      if (ejected[0] != ejected[1]) {
        final w = ejected[0] > ejected[1] ? 0 : 1;
        _finish(w, '达到回合上限，${name(w)} 以推出 ${ejected[w]}:${ejected[1 - w]} 获胜！');
      } else {
        _finish(2, '达到回合上限，双方推出棋子数相同（${ejected[0]}:${ejected[1]}），判和');
      }
      return;
    }

    turn = 1 - turn;
    recentHashes.add(_hashBoard(turn));
    if (recentHashes.length > 24) {
      recentHashes.removeAt(0);
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
    return {
      'board': List<int>.of(board),
      'ejected': List<int>.of(ejected),
      'winEjected': winEjected,
      'layout': layout,
      'turn': turn,
      'plies': plies,
      'maxPlies': maxPlies,
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

    // Immediate winning ejection
    for (final mv in moves) {
      if (mv.ejects && ejected[seat] + 1 >= winEjected) {
        return mv.toAction();
      }
    }

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      return moves[rng.nextInt(moves.length)].toAction();
    }

    // Compute opponent center of mass so bot marches toward opponent marbles
    var oppQ = 0.0, oppR = 0.0;
    var oppCount = 0;
    final opp = 1 - seat;
    for (var i = 0; i < 61; i++) {
      if (board[i] == opp) {
        oppQ += abaloneCells[i].$1;
        oppR += abaloneCells[i].$2;
        oppCount++;
      }
    }
    if (oppCount > 0) {
      oppQ /= oppCount;
      oppR /= oppCount;
    }

    final (dq0, dr0) = abDirs[0];
    var bestScore = -9999999.0;
    var bestMove = moves.first;
    final saved = List<int>.of(board);
    final savedEj0 = ejected[0], savedEj1 = ejected[1];

    for (final mv in moves) {
      var score = rng.nextDouble() * 12;
      final (dq, dr) = abDirs[mv.dir];

      if (mv.ejects) {
        score += 25000;
      } else if (mv.pushed.isNotEmpty) {
        final lastP = mv.pushed.last;
        final oldDist = abDistCenter(lastP.$1, lastP.$2);
        final newDist = abDistCenter(lastP.$1 + dq, lastP.$2 + dr);
        score += 1200 * mv.pushed.length + (newDist - oldDist) * 550 + newDist * 180;
      }

      // Group size bonus
      score += mv.marbles.length * (mv.inLine ? 95 : 55);

      // Center control + approaching opponent cluster
      for (final (q, r) in mv.marbles) {
        final oldD = abDistCenter(q, r);
        final newD = abDistCenter(q + dq, r + dr);
        score += (oldD - newD) * 65;
        if (newD == 4 && !mv.ejects) score -= 90;

        final oldOppD = (q - oppQ).abs() + (r - oppR).abs();
        final newOppD = (q + dq - oppQ).abs() + (r + dr - oppR).abs();
        score += (oldOppD - newOppD) * 35;
      }

      if (botLevel >= 1) {
        _applyMove(seat, mv);
        final h = _hashBoard(1 - seat);
        if (recentHashes.contains(h)) {
          score -= 4000;
        }
        board.setAll(0, saved);
        ejected[0] = savedEj0;
        ejected[1] = savedEj1;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = mv;
      }
    }
    // ignore unused
    final _ = dq0 + dr0;
    return bestMove.toAction();
  }
}
