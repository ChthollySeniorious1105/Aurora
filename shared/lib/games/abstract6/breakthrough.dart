import '../../src/engine.dart';

String breakthroughCoord(int size, int cell) {
  if (cell < 0 || cell >= size * size) return '?';
  final r = cell ~/ size, c = cell % size;
  return '${String.fromCharCode(65 + c)}${size - r}';
}

class Breakthrough extends GameEngine {
  late int size;

  /// Board of length `size * size`:
  /// `-1` = empty, `0` = Player 0 (Gold/White, starts bottom `r = size-2, size-1`, moves UP `dr = -1`),
  /// `1` = Player 1 (Dark/Black, starts top `r = 0, 1`, moves DOWN `dr = +1`).
  late List<int> board;

  int turn = 0;
  int plies = 0;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Breakthrough(super.setup);

  int forwardDir(int seat) => seat == 0 ? -1 : 1;
  int homeGoalRow(int seat) => seat == 0 ? 0 : size - 1;

  @override
  void start() {
    final optSize = setup.opt<int>('size', 8);
    size = (optSize == 6) ? 6 : 8;
    board = List.filled(size * size, -1);

    // Player 1 on top two rows (r = 0, 1)
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < size; c++) {
        board[r * size + c] = 1;
      }
    }
    // Player 0 on bottom two rows (r = size - 2, size - 1)
    for (var r = size - 2; r < size; r++) {
      for (var c = 0; c < size; c++) {
        board[r * size + c] = 0;
      }
    }

    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    note = '白金军（下）先行：直行入空位、斜前一步可入空或吃子，率先冲入敌方底线者立即获胜！';
    result = '';
  }

  int countPieces(int seat) {
    var count = 0;
    for (final p in board) {
      if (p == seat) count++;
    }
    return count;
  }

  /// Legal target squares for a piece at [from].
  /// - Straight forward `(r + dr, c)` ONLY if empty (`-1`).
  /// - Diagonally forward `(r + dr, c - 1)` and `(r + dr, c + 1)` if empty (`-1`) OR occupied by opponent (`1 - seat`).
  List<int> legalTargets(int from) {
    final out = <int>[];
    if (from < 0 || from >= size * size) return out;
    final seat = board[from];
    if (seat != 0 && seat != 1) return out;
    final r = from ~/ size, c = from % size;
    final nr = r + forwardDir(seat);
    if (nr < 0 || nr >= size) return out;

    // Straight forward: empty only
    final straight = nr * size + c;
    if (board[straight] == -1) {
      out.add(straight);
    }

    // Diagonal forward left & right: empty or opponent
    for (final dc in const [-1, 1]) {
      final nc = c + dc;
      if (nc >= 0 && nc < size) {
        final diag = nr * size + nc;
        if (board[diag] != seat) {
          out.add(diag);
        }
      }
    }
    return out;
  }

  bool isMoveLegal(int seat, int from, int to) {
    if (from < 0 || from >= size * size || to < 0 || to >= size * size) return false;
    if (board[from] != seat) return false;
    return legalTargets(from).contains(to);
  }

  bool hasAnyLegalMove(int seat) {
    for (var i = 0; i < board.length; i++) {
      if (board[i] == seat && legalTargets(i).isNotEmpty) return true;
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'move');
    if (t != 'move') throw GameError('未知操作');

    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= size * size || to < 0 || to >= size * size) {
      throw GameError('请选择要移动的己方棋子与目标格');
    }
    if (board[from] != seat) {
      throw GameError('必须选择你自己的棋子');
    }
    if (!legalTargets(from).contains(to)) {
      throw GameError('突破棋规则：只能向前直走一格（须为空格）或向斜前方走一格（可入空格或吃敌子）');
    }

    final captured = board[to] == (1 - seat);
    board[from] = -1;
    board[to] = seat;
    plies++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'captured': captured,
    };

    final sideName = seat == 0 ? '白金方' : '玄铁方';
    final capText = captured ? '（斜进击杀敌军）' : '';
    note = '${name(seat)}（$sideName）推进 ${breakthroughCoord(size, from)}→${breakthroughCoord(size, to)}$capText';

    final toRow = to ~/ size;
    if (toRow == homeGoalRow(seat)) {
      _finish(
        seat,
        '${name(seat)}（$sideName）成功突破防线冲抵敌方底线 ${breakthroughCoord(size, to)}，获胜！',
      );
      return;
    }

    final opp = 1 - seat;
    if (countPieces(opp) == 0) {
      _finish(seat, '${name(seat)}（$sideName）全歼敌方所有部队，获胜！');
      return;
    }

    if (!hasAnyLegalMove(opp)) {
      _finish(seat, '${name(opp)} 无路可走，${name(seat)} 获胜！');
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
      'size': size,
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'counts': [countPieces(0), countPieces(1)],
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  bool _isThreatenedAt(int seat, int cell) {
    final opp = 1 - seat;
    final r = cell ~/ size, c = cell % size;
    // An opponent piece can capture `cell` if it sits at `(r - forwardDir(opp), c ± 1)`
    final oppRow = r - forwardDir(opp);
    if (oppRow < 0 || oppRow >= size) return false;
    for (final dc in const [-1, 1]) {
      final nc = c + dc;
      if (nc >= 0 && nc < size && board[oppRow * size + nc] == opp) {
        return true;
      }
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final allMoves = <(int, int)>[];
    for (var i = 0; i < board.length; i++) {
      if (board[i] != seat) continue;
      for (final t in legalTargets(i)) {
        allMoves.add((i, t));
      }
    }
    if (allMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = allMoves[rng.nextInt(allMoves.length)];
      return {'type': 'move', 'from': pick.$1, 'to': pick.$2};
    }

    final goalRow = homeGoalRow(seat);
    final oppGoalRow = homeGoalRow(1 - seat);
    final opp = 1 - seat;
    var bestScore = -1e12;
    var bestMove = allMoves.first;

    for (final (f, t) in allMoves) {
      final tr = t ~/ size;
      // Immediate breakthrough win!
      if (tr == goalRow) {
        return {'type': 'move', 'from': f, 'to': t};
      }
      final capturedPiece = board[t];
      board[f] = -1;
      board[t] = seat;

      var score = rng.nextDouble() * 1.5;
      if (capturedPiece == opp) {
        score += 24.0;
        // Bonus for capturing an opponent runner close to our back rank!
        final oppDistToGoal = (tr - oppGoalRow).abs();
        if (oppDistToGoal <= 2) {
          score += (3 - oppDistToGoal) * 35.0;
        }
      }

      final myDistToGoal = (tr - goalRow).abs();
      score += (size - myDistToGoal) * 6.5;

      if (_isThreatenedAt(seat, t)) {
        score -= 16.0;
      } else if (myDistToGoal == 1) {
        // Unstoppable threat next turn!
        score += 90.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = (f, t);
      }

      board[f] = seat;
      board[t] = capturedPiece;
    }

    return {'type': 'move', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
