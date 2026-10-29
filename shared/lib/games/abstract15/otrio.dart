import '../../src/engine.dart';

/// 三环同心棋 (Otrio) — Marbles Brain Workshop's 3×3 Concentric-Ring 3-Way Alignment strategy game.
class OtrioGame extends GameEngine {
  OtrioGame(super.setup);

  static const int boardSize = 3;
  static const int sizeCount = 3; // 0 = Small, 1 = Medium, 2 = Large

  static const List<List<(int, int)>> lines8 = [
    // 3 rows
    [(0, 0), (0, 1), (0, 2)],
    [(1, 0), (1, 1), (1, 2)],
    [(2, 0), (2, 1), (2, 2)],
    // 3 cols
    [(0, 0), (1, 0), (2, 0)],
    [(0, 1), (1, 1), (2, 1)],
    [(0, 2), (1, 2), (2, 2)],
    // 2 diagonals
    [(0, 0), (1, 1), (2, 2)],
    [(0, 2), (1, 1), (2, 0)],
  ];

  static const List<String> sizeLabels = ['小环', '中环', '大环'];
  static const List<String> colorNames = ['红方', '蓝方', '绿方', '紫方'];

  /// `rings[r][c][size]`:
  /// `0` = empty, `1..4` = player `seat + 1`.
  late List<List<List<int>>> rings;

  /// `reserve[seat]` = `[smallLeft, mediumLeft, largeLeft]`, initially `[3, 3, 3]`.
  late List<List<int>> reserve;

  /// Whether a seat has resigned / been eliminated.
  late List<bool> eliminated;

  int turn = 0;
  int turnCount = 0;
  bool _over = false;
  int? winner; // 0..players-1, or -1 for draw
  String? winReason;
  String? winKind; // 'concentric' | 'same_size' | 'ordered_size'
  List<Map<String, int>>? winLine;
  Map<String, dynamic>? lastMove;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) {
      return List<int>.filled(players, 1);
    }
    return rankWinners(players, [winner!]);
  }

  static int colorOfSeat(int seat) => seat + 1;

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  @override
  void start() {
    rings = List.generate(
      boardSize,
      (_) => List.generate(boardSize, (_) => List<int>.filled(sizeCount, 0)),
    );
    reserve = List.generate(players, (_) => [3, 3, 3]);
    eliminated = List<bool>.filled(players, false);
    turn = 0;
    turnCount = 0;
    _over = false;
    winner = null;
    winReason = null;
    winKind = null;
    winLine = null;
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players || eliminated[seat]) {
      throw GameError('当前座位无法认输');
    }
    eliminated[seat] = true;
    final active = [
      for (var s = 0; s < players; s++)
        if (!eliminated[s]) s,
    ];
    if (active.length <= 1) {
      _over = true;
      winner = active.isEmpty ? -1 : active.first;
      winReason = winner == -1
          ? '对局结束，平局！'
          : '${name(seat)} 认输，${name(winner!)} 获胜！';
      host.log(winReason!);
      return;
    }
    host.log('${name(seat)} 认输退出对局');
    if (turn == seat) {
      _advanceTurn();
    }
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '各方同意和棋';
    host.log(winReason!);
  }

  /// Checks if [seat] satisfies any of the 3 Otrio win conditions on [b].
  /// Returns `(winKind, winLine)` if won, or `null` otherwise.
  (String, List<Map<String, int>>)? checkWinForSeat(
    int seat, [
    List<List<List<int>>>? b,
  ]) {
    final grid = b ?? rings;
    final color = colorOfSeat(seat);

    // 1. Concentric Nest in 1 Cell: all 3 sizes (0, 1, 2) of `color` in the same (r, c)
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (grid[r][c][0] == color &&
            grid[r][c][1] == color &&
            grid[r][c][2] == color) {
          return (
            'concentric',
            [
              {'r': r, 'c': c, 'size': 0},
              {'r': r, 'c': c, 'size': 1},
              {'r': r, 'c': c, 'size': 2},
            ],
          );
        }
      }
    }

    // 2. Same-Size 3-in-a-Row along any of the 8 lines
    for (final line in lines8) {
      final (r0, c0) = line[0];
      final (r1, c1) = line[1];
      final (r2, c2) = line[2];
      for (var s = 0; s < sizeCount; s++) {
        if (grid[r0][c0][s] == color &&
            grid[r1][c1][s] == color &&
            grid[r2][c2][s] == color) {
          return (
            'same_size',
            [
              {'r': r0, 'c': c0, 'size': s},
              {'r': r1, 'c': c1, 'size': s},
              {'r': r2, 'c': c2, 'size': s},
            ],
          );
        }
      }

      // 3. Ordered-Size 3-in-a-Row: ascending [0, 1, 2] or descending [2, 1, 0]
      if (grid[r0][c0][0] == color &&
          grid[r1][c1][1] == color &&
          grid[r2][c2][2] == color) {
        return (
          'ordered_size',
          [
            {'r': r0, 'c': c0, 'size': 0},
            {'r': r1, 'c': c1, 'size': 1},
            {'r': r2, 'c': c2, 'size': 2},
          ],
        );
      }
      if (grid[r0][c0][2] == color &&
          grid[r1][c1][1] == color &&
          grid[r2][c2][0] == color) {
        return (
          'ordered_size',
          [
            {'r': r0, 'c': c0, 'size': 2},
            {'r': r1, 'c': c1, 'size': 1},
            {'r': r2, 'c': c2, 'size': 0},
          ],
        );
      }
    }

    return null;
  }

  List<Map<String, dynamic>> legalActionsFor(int seat) {
    if (_over || seat < 0 || seat >= players || eliminated[seat]) {
      return const [];
    }
    final res = reserve[seat];
    final actions = <Map<String, dynamic>>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        for (var s = 0; s < sizeCount; s++) {
          if (res[s] > 0 && rings[r][c][s] == 0) {
            actions.add({'type': 'place', 'r': r, 'c': c, 'size': s});
          }
        }
      }
    }
    return actions;
  }

  void _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final next = (turn + step) % players;
      if (!eliminated[next] && legalActionsFor(next).isNotEmpty) {
        turn = next;
        return;
      }
    }
    // No player has any legal placement left -> Draw
    _over = true;
    winner = -1;
    winReason = '所有玩家均已无可用圆环或棋盘已满，本局平局！';
    host.log(winReason!);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type != 'place') {
      throw GameError('未知操作类型：$type');
    }

    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    final s = asInt(action['size'], -1);

    if (!inBounds(r, c)) {
      throw GameError('坐标超出 3×3 棋盘范围');
    }
    if (s < 0 || s >= sizeCount) {
      throw GameError('圆环尺寸无效（必须为 0=小环, 1=中环, 2=大环）');
    }
    if (reserve[seat][s] <= 0) {
      throw GameError('你手中已经没有剩余的${sizeLabels[s]}了');
    }
    if (rings[r][c][s] != 0) {
      throw GameError('该位置的${sizeLabels[s]}槽位已被占据');
    }

    rings[r][c][s] = colorOfSeat(seat);
    reserve[seat][s]--;
    turnCount++;

    lastMove = {
      'type': 'place',
      'seat': seat,
      'r': r,
      'c': c,
      'size': s,
    };

    final win = checkWinForSeat(seat);
    if (win != null) {
      _over = true;
      winner = seat;
      winKind = win.$1;
      winLine = win.$2;
      final kindLabel = switch (winKind) {
        'concentric' => '同格三环同心嵌套',
        'same_size' => '同尺寸三环连线',
        'ordered_size' => '大小渐进三环连线',
        _ => '三环连珠',
      };
      winReason = '${name(seat)} 达成「$kindLabel」，获胜！';
      host.log(winReason!);
      return;
    }

    _advanceTurn();
  }

  bool _wouldWin(int seat, int r, int c, int s) {
    if (rings[r][c][s] != 0) return false;
    rings[r][c][s] = colorOfSeat(seat);
    final won = checkWinForSeat(seat) != null;
    rings[r][c][s] = 0;
    return won;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final actions = legalActionsFor(seat);
    if (actions.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      return actions[rng.nextInt(actions.length)];
    }

    // 1. Immediate winning placement for `seat`
    for (final a in actions) {
      final r = a['r'] as int;
      final c = a['c'] as int;
      final s = a['size'] as int;
      if (_wouldWin(seat, r, c, s)) {
        return a;
      }
    }

    // 2. Block an opponent's immediate winning placement (prioritizing next seats in turn order)
    for (var step = 1; step < players; step++) {
      final opp = (seat + step) % players;
      if (eliminated[opp]) continue;
      for (final a in actions) {
        final r = a['r'] as int;
        final c = a['c'] as int;
        final s = a['size'] as int;
        if (reserve[opp][s] > 0 && _wouldWin(opp, r, c, s)) {
          return a;
        }
      }
    }

    // 3. Heuristic scoring
    final myColor = colorOfSeat(seat);
    Map<String, dynamic>? bestAction;
    var bestScore = double.negativeInfinity;

    for (final a in actions) {
      final r = a['r'] as int;
      final c = a['c'] as int;
      final s = a['size'] as int;
      var score = 0.0;

      // Center cell (1, 1) and medium size (1) participate in the mostordered/diagonal lines
      if (r == 1 && c == 1) {
        score += s == 1 ? 14.0 : 9.0;
      } else if ((r == 0 || r == 2) && (c == 0 || c == 2)) {
        score += 5.0;
      } else {
        score += 3.0;
      }

      // Bonus for concentric progress in cell (r, c)
      var ownInCell = 0;
      var blockedInCell = false;
      for (var sz = 0; sz < sizeCount; sz++) {
        if (sz == s) continue;
        final v = rings[r][c][sz];
        if (v == myColor) {
          ownInCell++;
        } else if (v != 0) {
          blockedInCell = true;
        }
      }
      if (!blockedInCell) {
        score += ownInCell * 10.0;
      }

      // Bonus for creating two-way threats after placing
      rings[r][c][s] = myColor;
      var threats = 0;
      for (var nr = 0; nr < boardSize; nr++) {
        for (var nc = 0; nc < boardSize; nc++) {
          for (var ns = 0; ns < sizeCount; ns++) {
            if (rings[nr][nc][ns] == 0 &&
                reserve[seat][ns] - (ns == s ? 1 : 0) > 0 &&
                _wouldWin(seat, nr, nc, ns)) {
              threats++;
            }
          }
        }
      }
      rings[r][c][s] = 0;
      score += threats * 18.0;

      score += rng.nextDouble() * 2.0;
      if (score > bestScore) {
        bestScore = score;
        bestAction = a;
      }
    }

    return bestAction ?? actions.first;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final actions = !_over ? legalActionsFor(turn) : const <Map<String, dynamic>>[];
    return {
      'boardSize': boardSize,
      'turn': turn,
      'turnCount': turnCount,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'winKind': winKind,
      'winLine': winLine,
      'rings': [
        for (final row in rings)
          [
            for (final cell in row) List<int>.of(cell),
          ],
      ],
      'reserve': [
        for (final r in reserve) List<int>.of(r),
      ],
      'eliminated': List<bool>.of(eliminated),
      'legalActions': actions,
      'lastMove': lastMove,
    };
  }
}
