import 'dart:collection';

import '../../src/engine.dart';

const String twixtRules = '''
# 桥联棋 TwixT 规则说明

## 游戏概述
桥联棋（TwixT）由传奇桌游设计师 Alex Randolph 于 1962 年创作，曾获德国年度游戏奖（Spiel des Jahres）特别奖，是公认最具代表性的**马步搭桥连接类（Connection Game）**抽象策略棋之一。
两名玩家分别执**红方（座位 0，先手，连接上下边界）**与**黑方（座位 1，后手，连接左右边界）**，在带孔棋盘上轮流插桩并自动架设马步桥。

## 棋盘与边界归属
- **四角禁区**：棋盘四个角孔 `(0, 0)`、`(0, N-1)`、`(N-1, 0)`、`(N-1, N-1)` 属于公共禁区，双方均不可落子。
- **红方边界（上下两行）**：顶行 `r = 0` 与底行 `r = N-1` 为红方专属边界；**黑方不可在顶行或底行落子**。
- **黑方边界（左右两列）**：左列 `c = 0` 与右列 `c = N-1` 为黑方专属边界；**红方不可在左列或右列落子**。
- **中央区域**：棋盘内部区域（`1 <= r <= N-2` 且 `1 <= c <= N-2`）双方均可自由落子。

## 落子与马步搭桥（Knight-Move Bridges）
- 每回合玩家在任意合法的空孔上放置 **1 枚己方棋桩（Peg）**。
- **自动架设马步桥**：落子后，系统会自动检查该棋桩与棋盘上所有已有的同色棋桩之间是否成**国际象棋马步（日字对角，即 `(|dr|, |dc|)` 为 `(1, 2)` 或 `(2, 1)`）**。
- **禁止交叉原则**：只要这段马步连线**没有与棋盘上已有的任何桥梁线段（无论敌我）发生几何交叉**，就会自动在这两枚同色棋桩之间架设一座己方桥梁！
- 如果存在已有桥梁阻挡（线段相交），则该马步桥无法架设。共享同一个端点的多座同色桥梁不算交叉，可以自由串联成链。

## 获胜条件
- **红方（座位 0）**：率先用**红方马步桥**构筑一条从**顶行（`r = 0`）连通到底行（`r = N-1`）**的不间断桥梁链，即刻获胜！
- **黑方（座位 1）**：率先用**黑方马步桥**构筑一条从**左列（`c = 0`）连通到右列（`c = N-1`）**的不间断桥梁链，即刻获胜！
- 注意：单纯棋桩相邻不算连通，必须通过**马步桥**连接才算有效通路。

## 房间选项
- **棋盘尺寸（size）**：支持 `12×12 标准` 与 `10×10 快速`。
''';

class TwixtGame extends GameEngine {
  late final int size;

  /// 0 = empty, 1 = Red (Player 0), 2 = Black (Player 1)
  late List<List<int>> board;

  /// Each bridge is [r1, c1, r2, c2, owner] where owner is 0 (Red) or 1 (Black).
  final List<List<int>> bridges = [];

  int turn = 0;
  int moveCount = 0;
  bool over = false;
  int? winner;
  String? winReason;
  List<List<int>> winningPath = [];
  Map<String, dynamic>? lastMove;

  TwixtGame(super.setup) {
    size = setup.opt<int>('size', 12);
  }

  static const List<(int, int)> knightMoves = [
    (-2, -1),
    (-2, 1),
    (-1, -2),
    (-1, 2),
    (1, -2),
    (1, 2),
    (2, -1),
    (2, 1),
  ];

  @override
  void start() {
    board = List.generate(size, (_) => List.filled(size, 0));
    bridges.clear();
    turn = 0;
    moveCount = 0;
    over = false;
    winner = null;
    winReason = null;
    winningPath = [];
    lastMove = null;
    host.log('桥联棋 TwixT 开始：${size}×$size 棋盘，红方连接上下边界，黑方连接左右边界！');
  }

  bool inBounds(int r, int c) => r >= 0 && r < size && c >= 0 && c < size;

  bool isCorner(int r, int c) =>
      (r == 0 || r == size - 1) && (c == 0 || c == size - 1);

  bool isValidHoleFor(int seat, int r, int c) {
    if (!inBounds(r, c) || isCorner(r, c)) return false;
    if (seat == 0) {
      // Red owns top/bottom rows; cannot place on left/right columns
      return c > 0 && c < size - 1;
    } else {
      // Black owns left/right columns; cannot place on top/bottom rows
      return r > 0 && r < size - 1;
    }
  }

  bool canPlace(int seat, int r, int c) =>
      isValidHoleFor(seat, r, c) && board[r][c] == 0;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= 2) throw GameError('无效座位');
    over = true;
    winner = 1 - seat;
    winReason = 'resign';
    host.log('${name(seat)} 认输，${name(winner!)} 获胜！');
  }

  @override
  bool get canDraw => !over;

  @override
  void agreeDraw() {
    if (over) throw GameError('游戏已结束');
    over = true;
    winner = -1;
    winReason = 'draw';
    host.log('双方同意和棋！');
  }

  @override
  List<int>? get placings {
    if (!over) return null;
    if (winner == 0) return const [1, 2];
    if (winner == 1) return const [2, 1];
    return const [1, 1];
  }

  static int _cross(int ax, int ay, int bx, int by, int cx, int cy) =>
      (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);

  static bool _onSegment(int ax, int ay, int bx, int by, int px, int py) =>
      px >= (ax < bx ? ax : bx) &&
      px <= (ax > bx ? ax : bx) &&
      py >= (ay < by ? ay : by) &&
      py <= (ay > by ? ay : by);

  /// Returns true if segment (r1, c1)-(r2, c2) strictly crosses or overlaps
  /// segment (r3, c3)-(r4, c4) (excluding a single shared endpoint).
  static bool segmentsIntersect(
    int r1,
    int c1,
    int r2,
    int c2,
    int r3,
    int c3,
    int r4,
    int c4,
  ) {
    // Sharing an endpoint is allowed (bridges chaining from the same peg)
    if ((r1 == r3 && c1 == c3) ||
        (r1 == r4 && c1 == c4) ||
        (r2 == r3 && c2 == c3) ||
        (r2 == r4 && c2 == c4)) {
      return false;
    }

    final d1 = _cross(r1, c1, r2, c2, r3, c3);
    final d2 = _cross(r1, c1, r2, c2, r4, c4);
    final d3 = _cross(r3, c3, r4, c4, r1, c1);
    final d4 = _cross(r3, c3, r4, c4, r2, c2);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }

    if (d1 == 0 && _onSegment(r1, c1, r2, c2, r3, c3)) return true;
    if (d2 == 0 && _onSegment(r1, c1, r2, c2, r4, c4)) return true;
    if (d3 == 0 && _onSegment(r3, c3, r4, c4, r1, c1)) return true;
    if (d4 == 0 && _onSegment(r3, c3, r4, c4, r2, c2)) return true;

    return false;
  }

  bool wouldCrossExistingBridge(int r1, int c1, int r2, int c2) {
    for (final b in bridges) {
      if (segmentsIntersect(r1, c1, r2, c2, b[0], b[1], b[2], b[3])) {
        return true;
      }
    }
    return false;
  }

  /// Finds a connected chain of bridges for [seat] from one owned border to the
  /// opposite owned border. Returns the list of [r, c] pegs along the path, or null.
  List<List<int>>? findWinningChain(int seat) {
    final adj = <int, List<int>>{};
    for (final b in bridges) {
      if (b[4] != seat) continue;
      final u = b[0] * size + b[1];
      final v = b[2] * size + b[3];
      (adj[u] ??= []).add(v);
      (adj[v] ??= []).add(u);
    }
    if (adj.isEmpty) return null;

    final queue = Queue<int>();
    final parent = <int, int>{};

    if (seat == 0) {
      for (var c = 1; c < size - 1; c++) {
        final u = c; // r == 0
        if (board[0][c] == 1 && adj.containsKey(u)) {
          queue.add(u);
          parent[u] = -1;
        }
      }
    } else {
      for (var r = 1; r < size - 1; r++) {
        final u = r * size; // c == 0
        if (board[r][0] == 2 && adj.containsKey(u)) {
          queue.add(u);
          parent[u] = -1;
        }
      }
    }

    int? targetNode;
    while (queue.isNotEmpty) {
      final curr = queue.removeFirst();
      final cr = curr ~/ size;
      final cc = curr % size;
      if ((seat == 0 && cr == size - 1) || (seat == 1 && cc == size - 1)) {
        targetNode = curr;
        break;
      }
      final neighbors = adj[curr];
      if (neighbors == null) continue;
      for (final nxt in neighbors) {
        if (!parent.containsKey(nxt)) {
          parent[nxt] = curr;
          queue.add(nxt);
        }
      }
    }

    if (targetNode == null) return null;

    final path = <List<int>>[];
    var cur = targetNode;
    while (cur != -1) {
      path.add([cur ~/ size, cur % size]);
      cur = parent[cur] ?? -1;
    }
    return path.reversed.toList();
  }

  bool hasAnyLegalMove(int seat) {
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (canPlace(seat, r, c)) return true;
      }
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你落子');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('无效操作类型');

    var r = asInt(action['r'], -1);
    var c = asInt(action['c'], -1);
    if ((r < 0 || c < 0) &&
        action['pos'] is List &&
        (action['pos'] as List).length >= 2) {
      final pos = action['pos'] as List;
      r = asInt(pos[0], -1);
      c = asInt(pos[1], -1);
    }

    if (!inBounds(r, c)) throw GameError('坐标超出棋盘范围');
    if (isCorner(r, c)) throw GameError('四角禁区不可落子');
    if (!isValidHoleFor(seat, r, c)) {
      throw GameError(
        seat == 0 ? '红方不可在左右两条黑方边界列落子' : '黑方不可在上下两条红方边界行落子',
      );
    }
    if (board[r][c] != 0) throw GameError('该孔位已有棋桩');

    final me = seat + 1;
    board[r][c] = me;
    moveCount++;

    final addedBridges = <List<int>>[];
    for (final (dr, dc) in knightMoves) {
      final nr = r + dr;
      final nc = c + dc;
      if (inBounds(nr, nc) && board[nr][nc] == me) {
        if (!wouldCrossExistingBridge(r, c, nr, nc)) {
          final b = <int>[r, c, nr, nc, seat];
          bridges.add(b);
          addedBridges.add(b);
        }
      }
    }

    lastMove = {
      'seat': seat,
      'r': r,
      'c': c,
      'bridgesAdded': addedBridges.length,
    };

    if (addedBridges.isNotEmpty) {
      host.log(
        '${name(seat)} 在 (${r + 1}, ${c + 1}) 落桩，自动架设 ${addedBridges.length} 座马步桥！',
      );
    }

    final chain = findWinningChain(seat);
    if (chain != null) {
      over = true;
      winner = seat;
      winReason = 'connect';
      winningPath = chain;
      host.log(
        '${name(seat)} 连通${seat == 0 ? "上下" : "左右"}边界马步桥链，获胜！',
      );
      return;
    }

    final nextSeat = 1 - seat;
    if (!hasAnyLegalMove(nextSeat)) {
      over = true;
      winner = -1;
      winReason = 'full';
      host.log('棋盘已无可落子孔位，双方和棋！');
      return;
    }

    turn = nextSeat;
  }

  @override
  Map<String, dynamic> view(int seat) {
    String? resultText;
    if (over) {
      if (winner == -1 || winner == null) {
        resultText = '双方和棋！';
      } else if (winReason == 'connect') {
        resultText =
            '${name(winner!)}（${winner == 0 ? "红方" : "黑方"}）连通边界获胜！';
      } else if (winReason == 'resign') {
        resultText = '${name(winner!)} 获胜（对手认输）！';
      } else {
        resultText = '${name(winner!)} 获胜！';
      }
    }

    final redPegs = <int>[0, 0];
    var redBridges = 0;
    var blackBridges = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (board[r][c] == 1) redPegs[0]++;
        if (board[r][c] == 2) redPegs[1]++;
      }
    }
    for (final b in bridges) {
      if (b[4] == 0) {
        redBridges++;
      } else {
        blackBridges++;
      }
    }

    return {
      'size': size,
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'bridges': [
        for (final b in bridges) List<int>.of(b),
      ],
      'pegCounts': redPegs,
      'bridgeCounts': [redBridges, blackBridges],
      'turn': turn,
      'moveCount': moveCount,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'winningPath': [
        for (final p in winningPath) List<int>.of(p),
      ],
      'lastMove': lastMove,
      'result': resultText,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final legal = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (canPlace(seat, r, c)) {
          legal.add((r, c));
        }
      }
    }
    if (legal.isEmpty) return null;

    // Opening move: place near center
    if (moveCount == 0) {
      final mid = size ~/ 2;
      if (canPlace(seat, mid, mid)) {
        return {'type': 'place', 'r': mid, 'c': mid};
      }
    }

    // Compute knight-graph shortest path distances from both borders for me and opp
    final (myDistA, myDistB) = _knightBorderDists(seat);
    final (oppDistA, oppDistB) = _knightBorderDists(1 - seat);

    int bestR = legal.first.$1;
    int bestC = legal.first.$2;
    double bestScore = double.negativeInfinity;

    final me = seat + 1;
    final opp = 2 - seat;
    final mid = (size - 1) / 2.0;

    for (final (r, c) in legal) {
      final idx = r * size + c;
      final dA = myDistA[idx];
      final dB = myDistB[idx];

      // How many new bridges would placing at (r, c) immediately form?
      var newBr = 0;
      for (final (dr, dc) in knightMoves) {
        final nr = r + dr;
        final nc = c + dc;
        if (inBounds(nr, nc) &&
            board[nr][nc] == me &&
            !wouldCrossExistingBridge(r, c, nr, nc)) {
          newBr++;
        }
      }

      // Immediate win if dA == 0 and dB == 0 via new bridges!
      if (dA + dB <= 1 && newBr >= 1) {
        var touchesA = (seat == 0 && r == 0) || (seat == 1 && c == 0);
        var touchesB =
            (seat == 0 && r == size - 1) || (seat == 1 && c == size - 1);
        if (dA == 0) touchesA = true;
        if (dB == 0) touchesB = true;
        if (touchesA && touchesB) {
          return {'type': 'place', 'r': r, 'c': c};
        }
      }

      var score = 0.0;
      // Strongly prefer cells on our shortest knight path between our two borders
      final myPathCost = dA + dB;
      if (myPathCost < 900) {
        score += (30 - myPathCost) * 220.0;
      }

      // Bonus for actually forming bridges now (advancing our connected chain)
      score += newBr * 320.0;
      if (newBr >= 2) score += 450.0;

      // Also value cells on opponent's shortest knight path to block/cross them
      if (isValidHoleFor(1 - seat, r, c)) {
        final odA = oppDistA[idx];
        final odB = oppDistB[idx];
        final oppPathCost = odA + odB;
        if (oppPathCost < 900) {
          score += (26 - oppPathCost) * (botLevel == 0 ? 60.0 : 145.0);
        }
        // Check if opponent would form bridges at (r, c)
        var oppBr = 0;
        for (final (dr, dc) in knightMoves) {
          final nr = r + dr;
          final nc = c + dc;
          if (inBounds(nr, nc) &&
              board[nr][nc] == opp &&
              !wouldCrossExistingBridge(r, c, nr, nc)) {
            oppBr++;
          }
        }
        if (oppBr >= 2) score += 380.0;
      }

      // Slight preference for central columns/rows
      final centerBias =
          size - ((r - mid).abs() + (c - mid).abs());
      score += centerBias * 6.0;

      // Penalize placing extra pegs on the same border if we already have a connected peg on that border
      if ((seat == 0 && (r == 0 || r == size - 1)) ||
          (seat == 1 && (c == 0 || c == size - 1))) {
        if (newBr == 0) {
          score -= 500.0;
        }
      }

      final jitter =
          botLevel == 0 ? rng.nextDouble() * 320.0 : rng.nextDouble() * 12.0;
      if (score + jitter > bestScore) {
        bestScore = score + jitter;
        bestR = r;
        bestC = c;
      }
    }

    return {'type': 'place', 'r': bestR, 'c': bestC};
  }

  /// Computes 0-1 BFS distances on the Knight-Move graph from Border A and Border B
  /// for player [seat].
  (List<int>, List<int>) _knightBorderDists(int seat) {
    const inf = 1000;
    final n = size * size;
    final distA = List<int>.filled(n, inf);
    final distB = List<int>.filled(n, inf);
    final me = seat + 1;

    void run01Bfs(List<int> dist, bool isSideA) {
      final dq = Queue<int>();
      for (var i = 0; i < size; i++) {
        final r = seat == 0 ? (isSideA ? 0 : size - 1) : i;
        final c = seat == 0 ? i : (isSideA ? 0 : size - 1);
        if (!isValidHoleFor(seat, r, c)) continue;
        final v = board[r][c];
        if (v != 0 && v != me) continue;
        final u = r * size + c;
        final cost = v == me ? 0 : 1;
        dist[u] = cost;
        if (cost == 0) {
          dq.addFirst(u);
        } else {
          dq.addLast(u);
        }
      }

      while (dq.isNotEmpty) {
        final u = dq.removeFirst();
        final d = dist[u];
        final r = u ~/ size;
        final c = u % size;
        for (final (dr, dc) in knightMoves) {
          final nr = r + dr;
          final nc = c + dc;
          if (!isValidHoleFor(seat, nr, nc)) continue;
          final nv = board[nr][nc];
          if (nv != 0 && nv != me) continue;
          if (wouldCrossExistingBridge(r, c, nr, nc)) continue;
          final nu = nr * size + nc;
          final w = nv == me ? 0 : 1;
          if (d + w < dist[nu]) {
            dist[nu] = d + w;
            if (w == 0) {
              dq.addFirst(nu);
            } else {
              dq.addLast(nu);
            }
          }
        }
      }
    }

    run01Bfs(distA, true);
    run01Bfs(distB, false);
    return (distA, distB);
  }
}
