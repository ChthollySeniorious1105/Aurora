import '../../src/engine.dart';

/// All 12 lines of 5 cells on the 5×5 Quixo board (5 rows, 5 cols, 2 diagonals).
const List<List<int>> quixoLines = [
  // Rows
  [0, 1, 2, 3, 4],
  [5, 6, 7, 8, 9],
  [10, 11, 12, 13, 14],
  [15, 16, 17, 18, 19],
  [20, 21, 22, 23, 24],
  // Columns
  [0, 5, 10, 15, 20],
  [1, 6, 11, 16, 21],
  [2, 7, 12, 17, 22],
  [3, 8, 13, 18, 23],
  [4, 9, 14, 19, 24],
  // Diagonals
  [0, 6, 12, 18, 24],
  [4, 8, 12, 16, 20],
];

String quixoCoord(int cell) {
  if (cell < 0 || cell >= 25) return '?';
  final r = cell ~/ 5, c = cell % 5;
  return '${String.fromCharCode(65 + c)}${5 - r}';
}

class Quixo extends GameEngine {
  static const int size = 5;
  static const int maxPlies = 120;

  /// 5×5 board of 25 cubes:
  /// `0` = Blank, `1` = Player 0 (Cross/X), `2` = Player 1 (Circle/O).
  late List<int> board;

  int turn = 0;
  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  List<int> winningLine = const [];
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Quixo(super.setup);

  static bool isOuter(int cell) {
    if (cell < 0 || cell >= 25) return false;
    final r = cell ~/ 5, c = cell % 5;
    return r == 0 || r == 4 || c == 0 || c == 4;
  }

  bool canPick(int seat, int from) {
    if (!isOuter(from)) return false;
    final v = board[from];
    return v == 0 || v == seat + 1;
  }

  /// Valid push destinations `(tr, tc)` for a border cube at `from`:
  /// the ends of the same row `(r, 0)`, `(r, 4)` and the ends of the same
  /// column `(0, c)`, `(4, c)`, excluding `from` itself.
  List<int> legalTargets(int from) {
    if (!isOuter(from)) return const [];
    final r = from ~/ 5, c = from % 5;
    final candidates = <int>{
      r * 5 + 0,
      r * 5 + 4,
      0 * 5 + c,
      4 * 5 + c,
    }..remove(from);
    return candidates.toList();
  }

  bool isMoveLegal(int seat, int from, int to) {
    if (!canPick(seat, from)) return false;
    return legalTargets(from).contains(to);
  }

  @override
  void start() {
    board = List.filled(25, 0);
    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    winningLine = const [];
    lastAction = null;
    note = 'X 方先行：请从棋盘外圈选择一枚空白或己方符号方块，并从同行或同列一端推入！';
    result = '';
  }

  /// Shifts intermediate cubes between `from` and `to` 1 step toward `from`,
  /// and inserts the picked cube at `to` with top face `seat + 1`.
  List<int> applyPush(int seat, int from, int to) {
    final r = from ~/ 5, c = from % 5;
    final tr = to ~/ 5, tc = to % 5;
    final shifted = <int>[from];
    if (r == tr) {
      final dc = tc > c ? 1 : -1;
      for (var col = c; col != tc; col += dc) {
        board[r * 5 + col] = board[r * 5 + col + dc];
        shifted.add(r * 5 + col + dc);
      }
      board[tr * 5 + tc] = seat + 1;
    } else if (c == tc) {
      final dr = tr > r ? 1 : -1;
      for (var row = r; row != tr; row += dr) {
        board[row * 5 + c] = board[(row + dr) * 5 + c];
        shifted.add((row + dr) * 5 + c);
      }
      board[tr * 5 + tc] = seat + 1;
    }
    return shifted;
  }

  List<int>? findFiveInARow(int seat) {
    final target = seat + 1;
    for (final line in quixoLines) {
      var allMatch = true;
      for (final idx in line) {
        if (board[idx] != target) {
          allMatch = false;
          break;
        }
      }
      if (allMatch) return line;
    }
    return null;
  }

  int countSymbols(int seat) {
    final target = seat + 1;
    var count = 0;
    for (final v in board) {
      if (v == target) count++;
    }
    return count;
  }

  int maxInLine(int seat) {
    final target = seat + 1;
    final opp = (1 - seat) + 1;
    var best = 0;
    for (final line in quixoLines) {
      var cnt = 0;
      var blocked = false;
      for (final idx in line) {
        if (board[idx] == target) {
          cnt++;
        } else if (board[idx] == opp) {
          blocked = true;
        }
      }
      if (!blocked && cnt > best) best = cnt;
    }
    return best;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'push');
    if (t != 'push') throw GameError('未知操作');

    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= 25 || to < 0 || to >= 25) {
      throw GameError('请选择外圈方块与推入方向');
    }
    if (!isOuter(from)) {
      throw GameError('只能选择棋盘外圈（第一行/最后一行/第一列/最后一列）的方块');
    }
    if (!canPick(seat, from)) {
      throw GameError('只能拿起空白方块或印有你自己符号的方块');
    }
    if (!legalTargets(from).contains(to)) {
      throw GameError('必须从所选方块所在行或所在列的另一端推入');
    }

    final shifted = applyPush(seat, from, to);
    plies++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'shifted': shifted,
    };

    final sideSym = seat == 0 ? '✕' : '◯';
    note = '${name(seat)}（$sideSym）拿起外圈 ${quixoCoord(from)}，从 ${quixoCoord(to)} 端推入';

    // Official Quixo Rule:
    // If a push creates a 5-in-a-row for the OPPONENT, the OPPONENT wins immediately
    // (even if the active player also formed a 5-in-a-row on the same move)!
    final opp = 1 - seat;
    final oppLine = findFiveInARow(opp);
    if (oppLine != null) {
      winningLine = oppLine;
      final oppSym = opp == 0 ? '✕' : '◯';
      _finish(opp, '${name(seat)} 的推入直接促成了对手 ${name(opp)}（$oppSym）五连一线，${name(opp)} 获胜！');
      return;
    }

    final myLine = findFiveInARow(seat);
    if (myLine != null) {
      winningLine = myLine;
      _finish(seat, '${name(seat)}（$sideSym）成功连成五子一线，获胜！');
      return;
    }

    if (plies >= maxPlies) {
      final m0 = maxInLine(0), m1 = maxInLine(1);
      if (m0 != m1) {
        final w = m0 > m1 ? 0 : 1;
        _finish(w, '达到 $maxPlies 手回合上限，${name(w)} 连线威胁度占优获胜！');
      } else {
        _finish(2, '达到 $maxPlies 手回合上限，双方势均力敌握手言和！');
      }
      return;
    }

    turn = opp;
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
      'turn': turn,
      'plies': plies,
      'counts': [countSymbols(0), countSymbols(1)],
      'winningLine': winningLine,
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  double _evaluateBoard(int seat) {
    final mySym = seat + 1;
    final oppSym = (1 - seat) + 1;
    var score = 0.0;
    for (final line in quixoLines) {
      var myCnt = 0;
      var oppCnt = 0;
      for (final idx in line) {
        final v = board[idx];
        if (v == mySym) {
          myCnt++;
        } else if (v == oppSym) {
          oppCnt++;
        }
      }
      if (oppCnt == 0 && myCnt > 0) {
        score += myCnt * myCnt * 6.0;
      } else if (myCnt == 0 && oppCnt > 0) {
        score -= oppCnt * oppCnt * 7.5;
      }
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final allMoves = <(int, int)>[];
    for (var i = 0; i < 25; i++) {
      if (!canPick(seat, i)) continue;
      for (final t in legalTargets(i)) {
        allMoves.add((i, t));
      }
    }
    if (allMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = allMoves[rng.nextInt(allMoves.length)];
      return {'type': 'push', 'from': pick.$1, 'to': pick.$2};
    }

    final saved = List<int>.of(board);
    final opp = 1 - seat;
    var bestScore = -1e12;
    var bestMove = allMoves.first;

    for (final (f, t) in allMoves) {
      final wasBlank = saved[f] == 0;
      applyPush(seat, f, t);

      final oppWin = findFiveInARow(opp) != null;
      final myWin = findFiveInARow(seat) != null;
      if (myWin && !oppWin) {
        board.setAll(0, saved);
        return {'type': 'push', 'from': f, 'to': t};
      }

      var score = _evaluateBoard(seat) + (wasBlank ? 4.0 : 0.0) + rng.nextDouble() * 1.5;
      if (oppWin) score -= 10000.0;

      if (score > bestScore) {
        bestScore = score;
        bestMove = (f, t);
      }
      board.setAll(0, saved);
    }

    return {'type': 'push', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
