import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

/// 蜿蜒连边棋 (Slither) — Corey Clark's Slide + Placement & No-Diagonal-Crosscut Connection game.
class SlitherGame extends GameEngine {
  SlitherGame(super.setup);

  static const List<(int, int)> ortho4 = [
    (-1, 0),
    (1, 0),
    (0, -1),
    (0, 1),
  ];

  static const List<(int, int)> dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  late String mode;
  late int boardSize;

  /// `board[r][c]`:
  /// `0` = empty
  /// `1` = Player 0 (白方, connects Top `r == 0` to Bottom `r == boardSize - 1`)
  /// `2` = Player 1 (黑方, connects Left `c == 0` to Right `c == boardSize - 1`)
  late List<List<int>> board;

  int turn = 0;
  int turnCount = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  List<Map<String, int>>? winChain;
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
    if (winner == null || winner == -1) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  static int colorOfSeat(int seat) => seat + 1;

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  int stoneCount(int seat) {
    final color = colorOfSeat(seat);
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (board[r][c] == color) count++;
      }
    }
    return count;
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    boardSize = mode == 'quick' ? 6 : 7;
    board = List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));
    turn = 0;
    turnCount = 0;
    _over = false;
    winner = null;
    winReason = null;
    winChain = null;
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  /// The No-Diagonal-Touch Invariant (禁斜角孤立接触铁律):
  /// For every pair of diagonally adjacent cells `(r, col)` and `(r+1, col±1)`
  /// both holding [color], at least one of their two shared orthogonal neighbors
  /// (`(r, col±1)` or `(r+1, col)`) MUST also hold [color].
  static bool checkNoDiagonalTouchGrid(List<List<int>> grid, int size, int color) {
    for (var r = 0; r < size - 1; r++) {
      final row0 = grid[r];
      final row1 = grid[r + 1];
      for (var c = 0; c < size; c++) {
        if (row0[c] != color) continue;
        if (c + 1 < size && row1[c + 1] == color) {
          if (row0[c + 1] != color && row1[c] != color) {
            return false;
          }
        }
        if (c - 1 >= 0 && row1[c - 1] == color) {
          if (row0[c - 1] != color && row1[c] != color) {
            return false;
          }
        }
      }
    }
    return true;
  }

  bool satisfiesNoDiagonalTouch(int color, [List<List<int>>? b]) =>
      checkNoDiagonalTouchGrid(b ?? board, boardSize, color);

  /// Validates whether a turn `(fromR, fromC) -> (toR, toC)` plus placement `(placeR, placeC)`
  /// is legal for [seat] on the current board.
  bool isTurnLegal(
    int seat,
    int fromR,
    int fromC,
    int toR,
    int toC,
    int placeR,
    int placeC,
  ) {
    if (!inBounds(placeR, placeC)) return false;
    final color = colorOfSeat(seat);

    if (fromR == -1) {
      if (board[placeR][placeC] != 0) return false;
      board[placeR][placeC] = color;
      final ok = checkNoDiagonalTouchGrid(board, boardSize, color);
      board[placeR][placeC] = 0;
      return ok;
    }

    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return false;
    if (board[fromR][fromC] != color) return false;
    if (board[toR][toC] != 0) return false;
    final dist = max((toR - fromR).abs(), (toC - fromC).abs());
    if (dist != 1) return false;

    // Apply slide temporarily
    board[fromR][fromC] = 0;
    board[toR][toC] = color;

    if (board[placeR][placeC] != 0) {
      board[toR][toC] = 0;
      board[fromR][fromC] = color;
      return false;
    }

    board[placeR][placeC] = color;
    final ok = checkNoDiagonalTouchGrid(board, boardSize, color);

    // Restore board in reverse order
    board[placeR][placeC] = 0;
    board[toR][toC] = 0;
    board[fromR][fromC] = color;
    return ok;
  }

  /// Checks if [seat] has formed an orthogonally connected chain between their two goal edges.
  /// Returns the shortest connecting chain of `[{'r': r, 'c': c}, ...]` if won, or `null`.
  List<Map<String, int>>? findWinningChain(int seat) {
    final color = colorOfSeat(seat);
    final visited = List.generate(boardSize, (_) => List<bool>.filled(boardSize, false));
    final parentR = List.generate(boardSize, (_) => List<int>.filled(boardSize, -1));
    final parentC = List.generate(boardSize, (_) => List<int>.filled(boardSize, -1));
    final q = Queue<(int, int)>();

    if (seat == 0) {
      // Top (r == 0) to Bottom (r == boardSize - 1)
      for (var c = 0; c < boardSize; c++) {
        if (board[0][c] == color) {
          visited[0][c] = true;
          q.add((0, c));
        }
      }
    } else {
      // Left (c == 0) to Right (c == boardSize - 1)
      for (var r = 0; r < boardSize; r++) {
        if (board[r][0] == color) {
          visited[r][0] = true;
          q.add((r, 0));
        }
      }
    }

    while (q.isNotEmpty) {
      final (r, c) = q.removeFirst();
      final reachedGoal = seat == 0 ? (r == boardSize - 1) : (c == boardSize - 1);
      if (reachedGoal) {
        final path = <Map<String, int>>[];
        var cr = r;
        var cc = c;
        while (cr != -1 && cc != -1) {
          path.add({'r': cr, 'c': cc});
          final pr = parentR[cr][cc];
          final pc = parentC[cr][cc];
          cr = pr;
          cc = pc;
        }
        return path.reversed.toList();
      }

      for (final (dr, dc) in ortho4) {
        final nr = r + dr;
        final nc = c + dc;
        if (inBounds(nr, nc) && !visited[nr][nc] && board[nr][nc] == color) {
          visited[nr][nc] = true;
          parentR[nr][nc] = r;
          parentC[nr][nc] = c;
          q.add((nr, nc));
        }
      }
    }
    return null;
  }

  bool hasConnectedWin(int seat) => findWinningChain(seat) != null;

  /// Enumerates legal actions for [seat].
  /// If [includeSlides] is true, includes both no-slide and slide+place turns.
  List<Map<String, dynamic>> legalActionsFor(int seat, {bool includeSlides = true}) {
    if (_over) return const [];
    final color = colorOfSeat(seat);
    final actions = <Map<String, dynamic>>[];

    // 1. No-slide placements
    for (var pr = 0; pr < boardSize; pr++) {
      for (var pc = 0; pc < boardSize; pc++) {
        if (board[pr][pc] != 0) continue;
        board[pr][pc] = color;
        if (checkNoDiagonalTouchGrid(board, boardSize, color)) {
          actions.add({
            'type': 'turn',
            'fromR': -1,
            'fromC': -1,
            'toR': -1,
            'toC': -1,
            'placeR': pr,
            'placeC': pc,
          });
        }
        board[pr][pc] = 0;
      }
    }

    if (!includeSlides) return actions;

    // 2. Slide 1 friendly stone 1 step (8-way) + place 1 new stone
    for (var r1 = 0; r1 < boardSize; r1++) {
      for (var c1 = 0; c1 < boardSize; c1++) {
        if (board[r1][c1] != color) continue;
        for (final (dr, dc) in dirs8) {
          final r2 = r1 + dr;
          final c2 = c1 + dc;
          if (!inBounds(r2, c2) || board[r2][c2] != 0) continue;

          board[r1][c1] = 0;
          board[r2][c2] = color;

          for (var pr = 0; pr < boardSize; pr++) {
            for (var pc = 0; pc < boardSize; pc++) {
              if ((pr == r1 && pc == c1) || board[pr][pc] != 0) continue;
              board[pr][pc] = color;
              if (checkNoDiagonalTouchGrid(board, boardSize, color)) {
                actions.add({
                  'type': 'turn',
                  'fromR': r1,
                  'fromC': c1,
                  'toR': r2,
                  'toC': c2,
                  'placeR': pr,
                  'placeC': pc,
                });
              }
              board[pr][pc] = 0;
            }
          }

          board[r2][c2] = 0;
          board[r1][c1] = color;
        }
      }
    }

    return actions;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type != 'turn') {
      throw GameError('未知操作类型：$type');
    }

    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);
    final placeR = asInt(action['placeR'], -1);
    final placeC = asInt(action['placeC'], -1);

    if (!inBounds(placeR, placeC)) {
      throw GameError('落子坐标超出棋盘范围');
    }

    if (!isTurnLegal(seat, fromR, fromC, toR, toC, placeR, placeC)) {
      throw GameError('非法操作：违反禁斜角孤立接触铁律（同色斜角接触处必须有至少一枚公共正交邻格同色子）或移动/落子位置不合法');
    }

    final color = colorOfSeat(seat);
    if (fromR != -1) {
      board[fromR][fromC] = 0;
      board[toR][toC] = color;
    }
    board[placeR][placeC] = color;

    turnCount++;
    lastMove = {
      'type': 'turn',
      'seat': seat,
      'fromR': fromR,
      'fromC': fromC,
      'toR': toR,
      'toC': toC,
      'placeR': placeR,
      'placeC': placeC,
    };

    final chain = findWinningChain(seat);
    if (chain != null) {
      _over = true;
      winner = seat;
      winChain = chain;
      final edgeDesc = seat == 0 ? '上下两端' : '左右两端';
      winReason = '${name(seat)} 成功贯通棋盘$edgeDesc，大获全胜！';
      host.log(winReason!);
      return;
    }

    final oppSeat = 1 - seat;
    final oppChain = findWinningChain(oppSeat);
    if (oppChain != null) {
      _over = true;
      winner = oppSeat;
      winChain = oppChain;
      winReason = '${name(oppSeat)} 贯通棋盘获胜！';
      host.log(winReason!);
      return;
    }

    // Check if opponent has any legal turn left
    if (legalActionsFor(oppSeat, includeSlides: false).isEmpty &&
        legalActionsFor(oppSeat, includeSlides: true).isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(oppSeat)} 已无合法落子位置，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    turn = oppSeat;
  }

  /// Computes 0-1 BFS minimum empty cells needed for [seat] to connect their two edges,
  /// and populates [onShortestPath] with empty cells that lie on a minimum-cost path.
  int _connectionEval(int seat, List<List<bool>> onShortestPath) {
    final n = boardSize;
    final myColor = colorOfSeat(seat);
    const inf = 9999;

    final distA = List.generate(n, (_) => List<int>.filled(n, inf));
    final distB = List.generate(n, (_) => List<int>.filled(n, inf));

    void run01Bfs(List<(int, int)> starts, List<List<int>> dist) {
      final dq = Queue<(int, int)>();
      for (final (sr, sc) in starts) {
        final v = board[sr][sc];
        if (v != 0 && v != myColor) continue;
        final cost = v == myColor ? 0 : 1;
        dist[sr][sc] = cost;
        if (cost == 0) {
          dq.addFirst((sr, sc));
        } else {
          dq.addLast((sr, sc));
        }
      }
      while (dq.isNotEmpty) {
        final (r, c) = dq.removeFirst();
        final d = dist[r][c];
        for (final (dr, dc) in ortho4) {
          final nr = r + dr;
          final nc = c + dc;
          if (!inBounds(nr, nc)) continue;
          final v = board[nr][nc];
          if (v != 0 && v != myColor) continue;
          final w = v == myColor ? 0 : 1;
          if (d + w < dist[nr][nc]) {
            dist[nr][nc] = d + w;
            if (w == 0) {
              dq.addFirst((nr, nc));
            } else {
              dq.addLast((nr, nc));
            }
          }
        }
      }
    }

    if (seat == 0) {
      run01Bfs([for (var c = 0; c < n; c++) (0, c)], distA);
      run01Bfs([for (var c = 0; c < n; c++) (n - 1, c)], distB);
    } else {
      run01Bfs([for (var r = 0; r < n; r++) (r, 0)], distA);
      run01Bfs([for (var r = 0; r < n; r++) (r, n - 1)], distB);
    }

    var minCost = inf;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final v = board[r][c];
        if (v != 0 && v != myColor) continue;
        final cellCost = v == myColor ? 0 : 1;
        final total = distA[r][c] + distB[r][c] - cellCost;
        if (total < minCost) minCost = total;
      }
    }

    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (board[r][c] == 0) {
          final total = distA[r][c] + distB[r][c] - 1;
          onShortestPath[r][c] = total <= minCost + 1;
        } else {
          onShortestPath[r][c] = false;
        }
      }
    }

    return minCost;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final noSlide = legalActionsFor(seat, includeSlides: false);
    final color = colorOfSeat(seat);
    final oppSeat = 1 - seat;

    if (botLevel == 0 && noSlide.isNotEmpty && rng.nextDouble() < 0.35) {
      return noSlide[rng.nextInt(noSlide.length)];
    }

    // 1. Check if any no-slide action immediately wins
    for (final a in noSlide) {
      final pr = a['placeR'] as int;
      final pc = a['placeC'] as int;
      board[pr][pc] = color;
      final won = hasConnectedWin(seat);
      board[pr][pc] = 0;
      if (won) return a;
    }

    final myPath = List.generate(boardSize, (_) => List<bool>.filled(boardSize, false));
    final oppPath = List.generate(boardSize, (_) => List<bool>.filled(boardSize, false));
    final baseMyCost = _connectionEval(seat, myPath);
    final baseOppCost = _connectionEval(oppSeat, oppPath);

    // 2. Build candidate list: all no-slide actions + targeted slide+place actions
    final candidates = <Map<String, dynamic>>[...noSlide];

    // Add slide+place actions where the placement is on `myPath` or `oppPath`
    for (var r1 = 0; r1 < boardSize; r1++) {
      for (var c1 = 0; c1 < boardSize; c1++) {
        if (board[r1][c1] != color) continue;
        for (final (dr, dc) in dirs8) {
          final r2 = r1 + dr;
          final c2 = c1 + dc;
          if (!inBounds(r2, c2) || board[r2][c2] != 0) continue;

          board[r1][c1] = 0;
          board[r2][c2] = color;

          for (var pr = 0; pr < boardSize; pr++) {
            for (var pc = 0; pc < boardSize; pc++) {
              if ((pr == r1 && pc == c1) || board[pr][pc] != 0) continue;
              if (!myPath[pr][pc] && !oppPath[pr][pc] && candidates.length > 80) {
                continue;
              }
              board[pr][pc] = color;
              if (checkNoDiagonalTouchGrid(board, boardSize, color)) {
                final won = hasConnectedWin(seat);
                final act = {
                  'type': 'turn',
                  'fromR': r1,
                  'fromC': c1,
                  'toR': r2,
                  'toC': c2,
                  'placeR': pr,
                  'placeC': pc,
                };
                if (won) {
                  board[pr][pc] = 0;
                  board[r2][c2] = 0;
                  board[r1][c1] = color;
                  return act;
                }
                if (candidates.length < 120) {
                  candidates.add(act);
                }
              }
              board[pr][pc] = 0;
            }
          }

          board[r2][c2] = 0;
          board[r1][c1] = color;
        }
      }
    }

    if (candidates.isEmpty) {
      final all = legalActionsFor(seat, includeSlides: true);
      if (all.isEmpty) return null;
      return all[rng.nextInt(all.length)];
    }

    final dummyPath = List.generate(boardSize, (_) => List<bool>.filled(boardSize, false));
    final center = (boardSize - 1) / 2.0;
    Map<String, dynamic>? bestAction;
    var bestScore = double.negativeInfinity;

    for (final a in candidates) {
      final fr = a['fromR'] as int;
      final fc = a['fromC'] as int;
      final tr = a['toR'] as int;
      final tc = a['toC'] as int;
      final pr = a['placeR'] as int;
      final pc = a['placeC'] as int;

      if (fr != -1) {
        board[fr][fc] = 0;
        board[tr][tc] = color;
      }
      board[pr][pc] = color;

      final newMyCost = _connectionEval(seat, dummyPath);
      final newOppCost = _connectionEval(oppSeat, dummyPath);

      board[pr][pc] = 0;
      if (fr != -1) {
        board[tr][tc] = 0;
        board[fr][fc] = color;
      }

      if (newMyCost == 0) return a;

      var score = (baseMyCost - newMyCost) * 40.0 + (newOppCost - baseOppCost) * 32.0;
      if (myPath[pr][pc]) score += 12.0;
      if (oppPath[pr][pc]) score += 10.0;

      // Centrality bonus
      final distCenter = (pr - center).abs() + (pc - center).abs();
      score += (boardSize - distCenter) * 1.5;

      // Slight preference for clean placement unless sliding improves connection cost
      if (fr != -1) score -= 1.5;

      score += rng.nextDouble() * 2.0;
      if (score > bestScore) {
        bestScore = score;
        bestAction = a;
      }
    }

    return bestAction ?? candidates.first;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final noSlide = !_over ? legalActionsFor(turn, includeSlides: false) : const <Map<String, dynamic>>[];
    return {
      'mode': mode,
      'boardSize': boardSize,
      'turn': turn,
      'turnCount': turnCount,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'winChain': winChain,
      'stones': [stoneCount(0), stoneCount(1)],
      'board': [
        for (final row in board) List<int>.of(row),
      ],
      'legalActions': noSlide,
      'lastMove': lastMove,
    };
  }
}
