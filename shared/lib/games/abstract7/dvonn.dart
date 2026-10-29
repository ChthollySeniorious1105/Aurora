import 'dart:math';

import '../../src/engine.dart';

/// Standard 49-cell elongated hexagonal board for DVONN:
/// 5 rows (`r = -2..2`) of lengths `9, 10, 11, 10, 9`.
final List<(int, int)> dvonnStandardCoords = () {
  final list = <(int, int)>[];
  for (var r = -2; r <= 2; r++) {
    final qMin = max(-5, -5 - r);
    final qMax = min(5, 5 - r);
    for (var q = qMin; q <= qMax; q++) {
      list.add((q, r));
    }
  }
  return List<(int, int)>.unmodifiable(list);
}();

/// Compact 37-cell hexagonal board (`|q| <= 3, |r| <= 3, |q + r| <= 3`).
final List<(int, int)> dvonnCompactCoords = () {
  final list = <(int, int)>[];
  for (var r = -3; r <= 3; r++) {
    final qMin = max(-3, -3 - r);
    final qMax = min(3, 3 - r);
    for (var q = qMin; q <= qMax; q++) {
      list.add((q, r));
    }
  }
  return List<(int, int)>.unmodifiable(list);
}();

final Map<(int, int), int> _stdIndex = {
  for (var i = 0; i < dvonnStandardCoords.length; i++) dvonnStandardCoords[i]: i,
};

final Map<(int, int), int> _cmpIndex = {
  for (var i = 0; i < dvonnCompactCoords.length; i++) dvonnCompactCoords[i]: i,
};

List<(int, int)> dvonnCoordsFor(String layout) =>
    layout == 'compact' ? dvonnCompactCoords : dvonnStandardCoords;

int dvonnIndexFor(String layout, int q, int r) =>
    (layout == 'compact' ? _cmpIndex : _stdIndex)[(q, r)] ?? -1;

const List<(int, int)> dvonnDirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
  (1, -1),
  (-1, 1),
];

String dvonnCellLabel(String layout, int idx) {
  final coords = dvonnCoordsFor(layout);
  if (idx < 0 || idx >= coords.length) return '?';
  final (q, r) = coords[idx];
  final rMin = layout == 'compact' ? -3 : -2;
  final qShift = layout == 'compact' ? 3 : 5;
  final rowChar = String.fromCharCode(65 + (r - rMin));
  final colNum = q + qShift + 1;
  return '$rowChar$colNum';
}

/// 德沃恩棋（DVONN）— Kris Burm 星盘计划经典堆叠与红源断连棋
class Dvonn extends GameEngine {
  static const int dvonnPieceCount = 3;

  String layout = 'standard';
  String setupMode = 'random';
  late List<(int, int)> coords;

  /// Top piece owner per cell:
  /// -1 = empty
  ///  0 = Seat 0 (White)
  ///  1 = Seat 1 (Black)
  ///  2 = Unclaimed Red DVONN piece ('D')
  late List<int> top;

  /// Stack height per cell (`0` if empty, `>= 1` if occupied).
  late List<int> height;

  /// True if the stack at cell `i` contains at least one Red DVONN piece ('D').
  late List<bool> hasDvonn;

  /// `'place'` (manual alternating placement) or `'stack'` (main stacking & collapse phase).
  String phase = 'stack';
  int placedCount = 0;
  int turn = 0;
  int plies = 0;

  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Dvonn(super.setup);

  int indexOf(int q, int r) => dvonnIndexFor(layout, q, r);

  @override
  void start() {
    final optLayout = setup.opt<String>('layout', 'standard');
    layout = optLayout == 'compact' ? 'compact' : 'standard';
    final rawSetup = setup.options['setup'] ?? setup.options['setupMode'] ?? 'random';
    setupMode = rawSetup == 'manual' ? 'manual' : 'random';

    coords = dvonnCoordsFor(layout);
    final n = coords.length;
    top = List.filled(n, -1);
    height = List.filled(n, 0);
    hasDvonn = List.filled(n, false);
    placedCount = 0;
    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    result = '';

    if (setupMode == 'manual') {
      phase = 'place';
      note = '布子阶段：先由双方轮流放置 3 枚红源（DVONN）棋子，再轮流放满黑白棋子（当前 0/$n）';
    } else {
      phase = 'stack';
      final perPlayer = (n - dvonnPieceCount) ~/ 2;
      final pool = <int>[
        for (var i = 0; i < dvonnPieceCount; i++) 2,
        for (var i = 0; i < perPlayer; i++) 0,
        for (var i = 0; i < perPlayer; i++) 1,
      ];
      pool.shuffle(rng);
      for (var i = 0; i < n; i++) {
        final p = pool[i];
        top[i] = p;
        height[i] = 1;
        hasDvonn[i] = p == 2;
      }
      placedCount = n;
      note = '随机布阵完成（3 枚红源棋子 + 双方各 $perPlayer 枚棋子），由白方（${name(0)}）先行堆叠移动！';
    }
  }

  /// Number of adjacent hexes (out of 6 directions) that are on-board and currently occupied.
  /// Any piece on the board perimeter has `< 6` on-board neighbors, so `occupiedNeighborCount < 6`
  /// holds if and only if the cell is on the perimeter OR has at least 1 empty adjacent hex!
  int occupiedNeighborCount(int idx) {
    if (idx < 0 || idx >= coords.length) return 6;
    final (q, r) = coords[idx];
    var count = 0;
    for (final (dq, dr) in dvonnDirs) {
      final nIdx = indexOf(q + dq, r + dr);
      if (nIdx != -1 && height[nIdx] > 0) {
        count++;
      }
    }
    return count;
  }

  bool isMobile(int seat, int idx) {
    if (idx < 0 || idx >= coords.length) return false;
    if (height[idx] <= 0 || top[idx] != seat) return false;
    return occupiedNeighborCount(idx) < 6;
  }

  /// Legal target indices for moving the stack at [from].
  /// Must move in one of the 6 straight hex directions by EXACTLY `height[from]` steps,
  /// and must land on an occupied cell (`height[to] > 0`).
  List<int> legalTargets(int from) {
    if (from < 0 || from >= coords.length || height[from] <= 0) return const [];
    final owner = top[from];
    if (owner != 0 && owner != 1) return const [];
    if (occupiedNeighborCount(from) >= 6) return const [];

    final h = height[from];
    final (q0, r0) = coords[from];
    final out = <int>[];
    for (final (dq, dr) in dvonnDirs) {
      final tIdx = indexOf(q0 + dq * h, r0 + dr * h);
      if (tIdx != -1 && height[tIdx] > 0) {
        out.add(tIdx);
      }
    }
    return out;
  }

  bool hasAnyLegalMove(int seat) {
    if (phase == 'place') {
      return height.any((h) => h == 0);
    }
    for (var i = 0; i < coords.length; i++) {
      if (top[i] == seat && height[i] > 0 && legalTargets(i).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Runs BFS from all occupied cells containing at least one Red DVONN piece (`hasDvonn[i] == true`).
  /// Removes all occupied stacks that are disconnected from all DVONN pieces and returns their indices.
  List<int> collapseDisconnected() {
    final n = coords.length;
    final visited = List<bool>.filled(n, false);
    final queue = <int>[];
    for (var i = 0; i < n; i++) {
      if (height[i] > 0 && hasDvonn[i]) {
        visited[i] = true;
        queue.add(i);
      }
    }
    var head = 0;
    while (head < queue.length) {
      final u = queue[head++];
      final (uq, ur) = coords[u];
      for (final (dq, dr) in dvonnDirs) {
        final v = indexOf(uq + dq, ur + dr);
        if (v != -1 && height[v] > 0 && !visited[v]) {
          visited[v] = true;
          queue.add(v);
        }
      }
    }
    final collapsed = <int>[];
    for (var i = 0; i < n; i++) {
      if (height[i] > 0 && !visited[i]) {
        collapsed.add(i);
        top[i] = -1;
        height[i] = 0;
        hasDvonn[i] = false;
      }
    }
    return collapsed;
  }

  /// Total pieces controlled by [seat] (sum of heights of all stacks whose top piece is [seat]).
  int scoreFor(int seat) {
    var total = 0;
    for (var i = 0; i < coords.length; i++) {
      if (height[i] > 0 && top[i] == seat) {
        total += height[i];
      }
    }
    return total;
  }

  int stackCountFor(int seat) {
    var cnt = 0;
    for (var i = 0; i < coords.length; i++) {
      if (height[i] > 0 && top[i] == seat) cnt++;
    }
    return cnt;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');

    final t = asStr(action['type']);
    final sideName = seat == 0 ? '白方' : '黑方';

    if (phase == 'place') {
      if (t != 'place') throw GameError('当前为手动布子阶段，请放置棋子');
      final cell = asInt(action['cell'] ?? action['to'], -1);
      if (cell < 0 || cell >= coords.length) throw GameError('无效的棋盘位置');
      if (height[cell] > 0) throw GameError('该格已有棋子，请选择空格放置');

      final isDvonnPiece = placedCount < dvonnPieceCount;
      final pieceType = isDvonnPiece ? 2 : seat;
      top[cell] = pieceType;
      height[cell] = 1;
      hasDvonn[cell] = isDvonnPiece;
      placedCount++;
      plies++;

      lastAction = {
        'type': 'place',
        'seat': seat,
        'cell': cell,
        'piece': isDvonnPiece ? 'D' : '$seat',
      };

      final pieceLabel = isDvonnPiece ? '红源棋子(D)' : (seat == 0 ? '白子' : '黑子');
      if (placedCount >= coords.length) {
        phase = 'stack';
        turn = 0;
        note = '${name(seat)} 在 ${dvonnCellLabel(layout, cell)} 放置$pieceLabel；全盘布满，进入堆叠移动阶段！';
      } else {
        turn = 1 - seat;
        note = '${name(seat)} 在 ${dvonnCellLabel(layout, cell)} 放置$pieceLabel（已放 $placedCount/${coords.length}）';
      }
      return;
    }

    if (t != 'move') throw GameError('请选择己方外围或未包围棋垛进行直线移动');
    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= coords.length || to < 0 || to >= coords.length) {
      throw GameError('请选择有效的起点与终点');
    }
    if (height[from] <= 0 || top[from] != seat) {
      throw GameError('起点必须是你控制的棋子或棋垛');
    }
    if (occupiedNeighborCount(from) >= 6) {
      throw GameError('该棋垛被六面完全包围，无法移动');
    }
    final legal = legalTargets(from);
    if (!legal.contains(to)) {
      throw GameError('非法移动：必须沿六角直线精确移动 ${height[from]} 步且落在有子格上');
    }

    final movedHeight = height[from];
    final collapsed = _executeMoveAndCollapse(seat, from, to);
    plies++;

    lastAction = {
      'type': 'move',
      'seat': seat,
      'from': from,
      'to': to,
      'steps': movedHeight,
      'newHeight': height[to],
      'collapsed': collapsed,
    };

    final collapseText = collapsed.isEmpty ? '' : '，切断连接触发 ${collapsed.length} 处断连坍塌！';
    var nextNote =
        '${name(seat)}（$sideName）移垛 ${dvonnCellLabel(layout, from)}→${dvonnCellLabel(layout, to)}（跨 $movedHeight 步，新垛高 ${height[to]}）$collapseText';

    final nextSeat = 1 - seat;
    if (hasAnyLegalMove(nextSeat)) {
      turn = nextSeat;
      note = nextNote;
    } else if (hasAnyLegalMove(seat)) {
      turn = seat;
      note = '$nextNote；${name(nextSeat)} 无合法移动自动跳过，继续由 ${name(seat)} 行动！';
    } else {
      note = nextNote;
      _finishGame();
    }
  }

  List<int> _executeMoveAndCollapse(int seat, int from, int to) {
    top[to] = seat;
    height[to] += height[from];
    hasDvonn[to] = hasDvonn[to] || hasDvonn[from];

    top[from] = -1;
    height[from] = 0;
    hasDvonn[from] = false;

    return collapseDisconnected();
  }

  void _finishGame() {
    final s0 = scoreFor(0);
    final s1 = scoreFor(1);
    if (s0 != s1) {
      final w = s0 > s1 ? 0 : 1;
      final wSide = w == 0 ? '白方' : '黑方';
      _finish(w, '双方均无合法移动，${name(w)}（$wSide）控制总子数 $s0:$s1 获胜！');
    } else {
      _finish(2, '双方均无合法移动，控制总子数 $s0:$s1 完全平手，和棋！');
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
      'layout': layout,
      'setupMode': setupMode,
      'phase': phase,
      'placedCount': placedCount,
      'top': List<int>.of(top),
      'height': List<int>.of(height),
      'hasDvonn': List<bool>.of(hasDvonn),
      'turn': turn,
      'plies': plies,
      'scores': [scoreFor(0), scoreFor(1)],
      'stacks': [stackCountFor(0), stackCountFor(1)],
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

    if (phase == 'place') {
      final empty = <int>[];
      for (var i = 0; i < coords.length; i++) {
        if (height[i] == 0) empty.add(i);
      }
      if (empty.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'place', 'cell': empty[rng.nextInt(empty.length)]};
      }
      // Prefer inner cells for DVONN pieces and near-DVONN cells for player pieces
      empty.sort((a, b) {
        final (qa, ra) = coords[a];
        final (qb, rb) = coords[b];
        final da = qa.abs() + ra.abs() + (qa + ra).abs();
        final db = qb.abs() + rb.abs() + (qb + rb).abs();
        return da.compareTo(db);
      });
      final pool = empty.take(min(10, empty.length)).toList();
      return {'type': 'place', 'cell': pool[rng.nextInt(pool.length)]};
    }

    final allMoves = <(int, int)>[];
    for (var i = 0; i < coords.length; i++) {
      if (top[i] != seat || height[i] <= 0) continue;
      for (final t in legalTargets(i)) {
        allMoves.add((i, t));
      }
    }
    if (allMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = allMoves[rng.nextInt(allMoves.length)];
      return {'type': 'move', 'from': pick.$1, 'to': pick.$2};
    }

    final savedTop = List<int>.of(top);
    final savedHeight = List<int>.of(height);
    final savedDvonn = List<bool>.of(hasDvonn);
    final opp = 1 - seat;

    var bestScore = -1e12;
    var bestMove = allMoves.first;

    for (final (f, t) in allMoves) {
      final targetWasOpp = top[t] == opp;
      final targetWasDvonn = top[t] == 2;
      final targetHeight = height[t];

      _executeMoveAndCollapse(seat, f, t);

      final myScore = scoreFor(seat);
      final oppScore = scoreFor(opp);
      var sc = (myScore - oppScore) * 12.0 + rng.nextDouble() * 1.5;

      if (targetWasOpp) sc += targetHeight * 8.0;
      if (targetWasDvonn) sc += 7.0;
      if (hasDvonn[t] && top[t] == seat) sc += 5.0;

      // In hard mode, also reward mobility and penalize creating a stack with 0 legal targets if it's too tall
      if (botLevel >= 2) {
        final newTargets = legalTargets(t).length;
        sc += newTargets * 3.5;
        if (!hasAnyLegalMove(opp)) sc += 30.0;
      }

      if (sc > bestScore) {
        bestScore = sc;
        bestMove = (f, t);
      }

      top.setAll(0, savedTop);
      height.setAll(0, savedHeight);
      hasDvonn.setAll(0, savedDvonn);
    }

    return {'type': 'move', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
