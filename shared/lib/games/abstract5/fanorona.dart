import 'dart:math';

import '../../src/engine.dart';

const List<(int, int)> fanoronaOrthoDirs = [
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
];

const List<(int, int)> fanoronaAllDirs = [
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
  (-1, -1),
  (-1, 1),
  (1, -1),
  (1, 1),
];

String fanoronaCoord(int cols, int rows, int cell) {
  if (cell < 0 || cell >= cols * rows) return '?';
  final r = cell ~/ cols, c = cell % cols;
  return '${String.fromCharCode(65 + c)}${rows - r}';
}

class FanoronaMove {
  final int from;
  final int to;
  final String? capture; // 'approach', 'withdraw', or null (Paika)
  final List<int> capturedCells;

  const FanoronaMove({
    required this.from,
    required this.to,
    this.capture,
    this.capturedCells = const [],
  });

  Map<String, dynamic> toAction() => {
        'type': 'move',
        'from': from,
        'to': to,
        if (capture != null) 'capture': capture,
      };

  Map<String, dynamic> toJson() => {
        'from': from,
        'to': to,
        'capture': capture,
        'capturedCells': capturedCells,
      };
}

class Fanorona extends GameEngine {
  static const int rows = 5;
  late int cols; // 5 (5x5) or 9 (9x5)
  late String sizeMode;

  /// Board of length `cols * rows`: -1 = empty, 0 = Seat 0 (White, bottom), 1 = Seat 1 (Black, top).
  late List<int> board;

  int turn = 0; // Seat 0 (White) moves first
  int plies = 0;
  static const int maxPlies = 160;

  /// Multi-capture chain state during a single turn:
  /// When `chainPos >= 0`, only the piece at [chainPos] may continue capturing, or player may `end_turn`.
  int chainPos = -1;
  List<int> visited = [];
  (int, int)? lastDir;

  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Fanorona(super.setup);

  /// Intersections `(r, c)` where `(r + c) % 2 == 0` are strong points (8-connected).
  /// Intersections where `(r + c) % 2 == 1` are weak points (4-connected).
  bool isStrongPoint(int r, int c) => (r + c).isEven;

  List<(int, int)> dirsAt(int r, int c) => isStrongPoint(r, c) ? fanoronaAllDirs : fanoronaOrthoDirs;

  int _parseCell(Object? v) {
    if (v is List && v.length >= 2) {
      final r = asInt(v[0], -1), c = asInt(v[1], -1);
      if (r < 0 || r >= rows || c < 0 || c >= cols) return -1;
      return r * cols + c;
    }
    final idx = asInt(v, -1);
    return (idx >= 0 && idx < cols * rows) ? idx : -1;
  }

  @override
  void start() {
    final optSize = setup.opt<String>('size', '9x5');
    sizeMode = (optSize == '5x5') ? '5x5' : '9x5';
    cols = sizeMode == '5x5' ? 5 : 9;
    board = List.filled(cols * rows, -1);

    // Top 2 rows (0, 1) = Seat 1 (Black)
    for (var r = 0; r < 2; r++) {
      for (var c = 0; c < cols; c++) {
        board[r * cols + c] = 1;
      }
    }
    // Bottom 2 rows (3, 4) = Seat 0 (White)
    for (var r = 3; r < 5; r++) {
      for (var c = 0; c < cols; c++) {
        board[r * cols + c] = 0;
      }
    }
    // Middle row (r = 2): alternating pieces with center empty
    final midCol = cols ~/ 2;
    for (var c = 0; c < cols; c++) {
      if (c == midCol) {
        board[2 * cols + c] = -1;
      } else if (c < midCol) {
        board[2 * cols + c] = c.isEven ? 1 : 0;
      } else {
        board[2 * cols + c] = (c - 1).isEven ? 1 : 0;
      }
    }

    turn = 0;
    plies = 0;
    chainPos = -1;
    visited = [];
    lastDir = null;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    note = '白方先行：沿棋盘线移动 1 步，通过【撞击吃（Approach）】或【后撤吃（Withdrawal）】成串消灭敌子！';
    result = '';
  }

  int countPieces(int seat) {
    var count = 0;
    for (final p in board) {
      if (p == seat) count++;
    }
    return count;
  }

  bool isStepConnected(int from, int to) {
    if (from < 0 || from >= cols * rows || to < 0 || to >= cols * rows || from == to) {
      return false;
    }
    final r0 = from ~/ cols, c0 = from % cols;
    final r1 = to ~/ cols, c1 = to % cols;
    final dr = r1 - r0, dc = c1 - c0;
    if (dr.abs() > 1 || dc.abs() > 1) return false;
    return dirsAt(r0, c0).contains((dr, dc));
  }

  /// Contiguous opponent pieces captured by Approach when moving `from -> to`.
  List<int> approachCaptures(int seat, int from, int to) {
    if (!isStepConnected(from, to) || board[to] != -1) return const [];
    final opp = 1 - seat;
    final r0 = from ~/ cols, c0 = from % cols;
    final r1 = to ~/ cols, c1 = to % cols;
    final dr = r1 - r0, dc = c1 - c0;
    final out = <int>[];
    var r = r1 + dr, c = c1 + dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && board[r * cols + c] == opp) {
      out.add(r * cols + c);
      r += dr;
      c += dc;
    }
    return out;
  }

  /// Contiguous opponent pieces captured by Withdrawal when moving `from -> to`.
  List<int> withdrawalCaptures(int seat, int from, int to) {
    if (!isStepConnected(from, to) || board[to] != -1) return const [];
    final opp = 1 - seat;
    final r0 = from ~/ cols, c0 = from % cols;
    final r1 = to ~/ cols, c1 = to % cols;
    final dr = r1 - r0, dc = c1 - c0;
    final out = <int>[];
    var r = r0 - dr, c = c0 - dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols && board[r * cols + c] == opp) {
      out.add(r * cols + c);
      r -= dr;
      c -= dc;
    }
    return out;
  }

  /// All legal moves for [seat] in the current turn state (respecting mandatory capture and chain rules).
  List<FanoronaMove> legalMoves(int seat) {
    if (_over) return const [];
    if (seat == turn && chainPos >= 0) {
      return _legalChainMovesFrom(seat, chainPos);
    }

    final captures = <FanoronaMove>[];
    final paikas = <FanoronaMove>[];

    for (var from = 0; from < board.length; from++) {
      if (board[from] != seat) continue;
      final r0 = from ~/ cols, c0 = from % cols;
      for (final (dr, dc) in dirsAt(r0, c0)) {
        final r1 = r0 + dr, c1 = c0 + dc;
        if (r1 < 0 || r1 >= rows || c1 < 0 || c1 >= cols) continue;
        final to = r1 * cols + c1;
        if (board[to] != -1) continue;

        final app = approachCaptures(seat, from, to);
        final wit = withdrawalCaptures(seat, from, to);
        if (app.isNotEmpty) {
          captures.add(FanoronaMove(from: from, to: to, capture: 'approach', capturedCells: app));
        }
        if (wit.isNotEmpty) {
          captures.add(FanoronaMove(from: from, to: to, capture: 'withdraw', capturedCells: wit));
        }
        if (app.isEmpty && wit.isEmpty) {
          paikas.add(FanoronaMove(from: from, to: to));
        }
      }
    }

    // Mandatory capture: if any capture move exists, Paika moves are forbidden
    return captures.isNotEmpty ? captures : paikas;
  }

  List<FanoronaMove> _legalChainMovesFrom(int seat, int from) {
    if (from < 0 || from >= board.length || board[from] != seat) return const [];
    final out = <FanoronaMove>[];
    final r0 = from ~/ cols, c0 = from % cols;
    for (final (dr, dc) in dirsAt(r0, c0)) {
      if (lastDir != null && lastDir == (dr, dc)) continue; // Cannot repeat same direction
      final r1 = r0 + dr, c1 = c0 + dc;
      if (r1 < 0 || r1 >= rows || c1 < 0 || c1 >= cols) continue;
      final to = r1 * cols + c1;
      if (board[to] != -1 || visited.contains(to)) continue; // Cannot revisit square in same turn

      final app = approachCaptures(seat, from, to);
      final wit = withdrawalCaptures(seat, from, to);
      if (app.isNotEmpty) {
        out.add(FanoronaMove(from: from, to: to, capture: 'approach', capturedCells: app));
      }
      if (wit.isNotEmpty) {
        out.add(FanoronaMove(from: from, to: to, capture: 'withdraw', capturedCells: wit));
      }
    }
    return out;
  }

  bool hasAnyCaptureMove(int seat) {
    final moves = legalMoves(seat);
    return moves.isNotEmpty && moves.first.capture != null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'move');

    if (t == 'end_turn') {
      if (chainPos < 0) {
        throw GameError('当前未处于连续吃子阶段，不能直接结束回合');
      }
      final sideName = seat == 0 ? '白方' : '黑方';
      note = '${name(seat)}（$sideName）结束连续吃子，回合交予对手';
      _advanceTurnAfterChain(seat);
      return;
    }

    if (t != 'move') throw GameError('未知操作');

    final from = _parseCell(action['from']);
    final to = _parseCell(action['to']);
    if (from < 0 || to < 0) {
      throw GameError('请选择要移动的己方棋子与相邻目标交点');
    }
    if (chainPos >= 0 && from != chainPos) {
      throw GameError('连续追击中只能继续移动当前棋子 ${fanoronaCoord(cols, rows, chainPos)}（或点“结束追击”）');
    }
    if (board[from] != seat) {
      throw GameError('必须选择你自己的棋子');
    }
    if (board[to] != -1) {
      throw GameError('目标点必须为空');
    }
    if (!isStepConnected(from, to)) {
      throw GameError('只能沿棋盘实线向相邻交点移动 1 步（弱交点不能走斜线）');
    }

    final r0 = from ~/ cols, c0 = from % cols;
    final r1 = to ~/ cols, c1 = to % cols;
    final dir = (r1 - r0, c1 - c0);

    if (chainPos >= 0) {
      if (visited.contains(to)) {
        throw GameError('同一回合连续吃子不能重复踏入已走过的交点');
      }
      if (lastDir != null && lastDir == dir) {
        throw GameError('连续吃子不能连续两次沿完全相同的方向移动');
      }
    }

    final app = approachCaptures(seat, from, to);
    final wit = withdrawalCaptures(seat, from, to);
    final reqCap = action['capture'] as String?;

    final allLegal = legalMoves(seat);
    final mustCapture = allLegal.isNotEmpty && allLegal.first.capture != null;

    if (mustCapture && app.isEmpty && wit.isEmpty) {
      throw GameError('有吃必吃：当前存在吃子走法，不能走普通无吃子步（Paika）');
    }

    String? chosenType;
    List<int> captured = const [];

    if (app.isNotEmpty || wit.isNotEmpty) {
      if (reqCap == 'approach') {
        if (app.isEmpty) throw GameError('该移动无法触发撞击吃子（Approach）');
        chosenType = 'approach';
        captured = app;
      } else if (reqCap == 'withdraw') {
        if (wit.isEmpty) throw GameError('该移动无法触发后撤吃子（Withdrawal）');
        chosenType = 'withdraw';
        captured = wit;
      } else {
        // Default when not disambiguated: prefer whichever is non-empty (or approach if both)
        if (app.isNotEmpty) {
          chosenType = 'approach';
          captured = app;
        } else {
          chosenType = 'withdraw';
          captured = wit;
        }
      }
    } else if (reqCap != null) {
      throw GameError('该步移动无法吃子');
    }

    // Apply move and captures
    board[from] = -1;
    board[to] = seat;
    for (final c in captured) {
      board[c] = -1;
    }
    plies++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'capture': chosenType,
      'captured': captured,
    };

    final sideName = seat == 0 ? '白方' : '黑方';
    final coordFrom = fanoronaCoord(cols, rows, from);
    final coordTo = fanoronaCoord(cols, rows, to);

    if (chosenType == null) {
      note = '${name(seat)}（$sideName）巡行移动 $coordFrom→$coordTo';
      _advanceTurnAfterChain(seat);
      return;
    }

    final capTypeLabel = chosenType == 'approach' ? '撞击吃' : '后撤吃';
    note = '${name(seat)}（$sideName）$coordFrom→$coordTo $capTypeLabel ${captured.length} 子（${captured.map((c) => fanoronaCoord(cols, rows, c)).join('、')}）';

    // Check if opponent is wiped out
    final opp = 1 - seat;
    if (countPieces(opp) == 0) {
      _finish(seat, '${name(seat)}（$sideName）全歼对手棋子，获胜！');
      return;
    }

    // Update chain state and check if another capture is available from [to]
    if (visited.isEmpty) visited.add(from);
    visited.add(to);
    chainPos = to;
    lastDir = dir;

    final nextChainMoves = _legalChainMovesFrom(seat, to);
    if (nextChainMoves.isNotEmpty && plies < maxPlies) {
      note = '$note — 可继续追击吃子或点击“结束追击”';
      return;
    }

    _advanceTurnAfterChain(seat);
  }

  void _advanceTurnAfterChain(int seat) {
    chainPos = -1;
    visited = [];
    lastDir = null;
    final opp = 1 - seat;

    if (countPieces(opp) == 0) {
      _finish(seat, '${name(seat)} 全歼对手棋子，获胜！');
      return;
    }

    turn = opp;
    if (legalMoves(opp).isEmpty) {
      _finish(seat, '${name(opp)} 无合法移动，${name(seat)} 获胜！');
      return;
    }

    if (plies >= maxPlies) {
      final p0 = countPieces(0);
      final p1 = countPieces(1);
      if (p0 > p1) {
        _finish(0, '达到 $maxPlies 手回合上限，白方剩余棋子 $p0 : $p1 领先，${name(0)} 获胜！');
      } else if (p1 > p0) {
        _finish(1, '达到 $maxPlies 手回合上限，黑方剩余棋子 $p1 : $p0 领先，${name(1)} 获胜！');
      } else {
        _finish(2, '达到 $maxPlies 手回合上限，双方剩余棋子均为 $p0 枚，握手言和！');
      }
    }
  }

  void _finish(int w, String msg) {
    _over = true;
    winner = w;
    chainPos = -1;
    visited = [];
    lastDir = null;
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
    final moves = _over ? const <FanoronaMove>[] : legalMoves(turn);
    return {
      'cols': cols,
      'rows': rows,
      'sizeMode': sizeMode,
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'maxPlies': maxPlies,
      'chainPos': chainPos,
      'visited': List<int>.of(visited),
      'mustCapture': moves.isNotEmpty && moves.first.capture != null,
      'legalMoves': [for (final m in moves) m.toJson()],
      'counts': [countPieces(0), countPieces(1)],
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
    if (moves.isEmpty) {
      if (chainPos >= 0) return {'type': 'end_turn'};
      return null;
    }

    if (botLevel == 0 && rng.nextDouble() < 0.40) {
      final pick = moves[rng.nextInt(moves.length)];
      return pick.toAction();
    }

    final opp = 1 - seat;
    final saved = List<int>.of(board);
    var bestScore = -1e12;
    var bestMove = moves.first;

    for (final m in moves) {
      board[m.from] = -1;
      board[m.to] = seat;
      for (final c in m.capturedCells) {
        board[c] = -1;
      }

      if (countPieces(opp) == 0) {
        board.setAll(0, saved);
        return m.toAction();
      }

      // Score by captured pieces, strong point landing, and minimizing opponent counter-captures
      final r1 = m.to ~/ cols, c1 = m.to % cols;
      double score = m.capturedCells.length * 25.0 + (isStrongPoint(r1, c1) ? 3.5 : 0.0) + rng.nextDouble() * 1.5;

      // Check how many opponent pieces can capture after this move
      if (botLevel >= 1) {
        var maxOppCap = 0;
        for (var i = 0; i < board.length; i++) {
          if (board[i] != opp) continue;
          final or0 = i ~/ cols, oc0 = i % cols;
          for (final (dr, dc) in dirsAt(or0, oc0)) {
            final or1 = or0 + dr, oc1 = oc0 + dc;
            if (or1 < 0 || or1 >= rows || oc1 < 0 || oc1 >= cols) continue;
            final oto = or1 * cols + oc1;
            if (board[oto] != -1) continue;
            final a = approachCaptures(opp, i, oto).length;
            final w = withdrawalCaptures(opp, i, oto).length;
            maxOppCap = max(maxOppCap, max(a, w));
          }
        }
        score -= maxOppCap * 10.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = m;
      }

      board.setAll(0, saved);
    }

    return bestMove.toAction();
  }
}
