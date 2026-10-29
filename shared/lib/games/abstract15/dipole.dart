import 'dart:math';

import '../../src/engine.dart';

/// 偶极子棋 (Dipole) — Mark Steere's Stack-Splitting Distance-Equals-Count & All-Direction Capture game.
class DipoleGame extends GameEngine {
  DipoleGame(super.setup);

  static const int boardSize = 8;

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
  late int maxQuietMoves;
  late int maxTotalTurns;

  /// `owner[r][c]`: `0` = empty, `1` = Player 0 (白方, forward is `dr <= 0`), `2` = Player 1 (黑方, forward is `dr >= 0`).
  late List<List<int>> owner;

  /// `counts[r][c]`: number of checkers in the stack at `(r, c)` (`0` if empty).
  late List<List<int>> counts;

  List<int> captured = [0, 0];

  int turn = 0;
  int turnCount = 0;
  int quietMoves = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
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
  static bool isDarkSquare(int r, int c) => (r + c) % 2 == 1;

  bool inBounds(int r, int c) =>
      r >= 0 && r < boardSize && c >= 0 && c < boardSize;

  int totalCheckers(int seat) {
    final myColor = colorOfSeat(seat);
    var sum = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (owner[r][c] == myColor) {
          sum += counts[r][c];
        }
      }
    }
    return sum;
  }

  /// Helper to set a stack at `(r, c)` (for testing or setup).
  void setStack(int r, int c, int seatOwner, int count) {
    if (count <= 0 || seatOwner == 0) {
      owner[r][c] = 0;
      counts[r][c] = 0;
    } else {
      owner[r][c] = seatOwner;
      counts[r][c] = count;
    }
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    maxQuietMoves = mode == 'quick' ? 50 : 70;
    maxTotalTurns = mode == 'quick' ? 140 : 200;

    owner = List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));
    counts = List.generate(boardSize, (_) => List<int>.filled(boardSize, 0));

    // Player 0 (白方, 1) starts with 12 checkers on dark square (7, 4)
    owner[7][4] = 1;
    counts[7][4] = 12;

    // Player 1 (黑方, 2) starts with 12 checkers on dark square (0, 3)
    owner[0][3] = 2;
    counts[0][3] = 12;

    captured = [0, 0];
    turn = 0;
    turnCount = 0;
    quietMoves = 0;
    _over = false;
    winner = null;
    winReason = null;
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

  /// Validates an action `(fromR, fromC) -> (toR, toC)` with [count] checkers for [seat].
  /// Returns `'move'`, `'capture'`, or `null` if illegal.
  String? classifyAction(
    int seat,
    int fromR,
    int fromC,
    int toR,
    int toC,
    int count,
  ) {
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) return null;
    if (!isDarkSquare(fromR, fromC) || !isDarkSquare(toR, toC)) return null;

    final myColor = colorOfSeat(seat);
    final oppColor = colorOfSeat(1 - seat);

    if (owner[fromR][fromC] != myColor) return null;
    final stackHeight = counts[fromR][fromC];
    if (count < 1 || count > stackHeight) return null;

    final dr = toR - fromR;
    final dc = toC - fromC;
    if (dr == 0 && dc == 0) return null;

    // Must be along one of the 8 directions with Chebyshev distance == count
    final dist = max(dr.abs(), dc.abs());
    if (dist != count) return null;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return null;

    final destOwner = owner[toR][toC];
    final destCount = counts[toR][toC];

    if (destOwner == oppColor) {
      // All-direction capture: allowed in any of the 8 directions if enemy stack size <= count
      if (destCount <= count) {
        return 'capture';
      }
      return null;
    }

    // Non-capture ('move'): must be forward or sideways onto empty or friendly square
    final isForwardOrSideways = seat == 0 ? (dr <= 0) : (dr >= 0);
    if (!isForwardOrSideways) return null;

    if (destOwner == 0 || destOwner == myColor) {
      return 'move';
    }
    return null;
  }

  List<Map<String, dynamic>> legalActionsFor(int seat) {
    if (_over) return const [];
    final myColor = colorOfSeat(seat);
    final actions = <Map<String, dynamic>>[];

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (owner[r][c] != myColor) continue;
        final maxCount = counts[r][c];
        if (maxCount <= 0) continue;

        for (final (ur, uc) in dirs8) {
          final isDiag = ur != 0 && uc != 0;
          final stepIncrement = isDiag ? 1 : 2;
          for (var count = stepIncrement; count <= maxCount; count += stepIncrement) {
            final tr = r + count * ur;
            final tc = c + count * uc;
            if (!inBounds(tr, tc)) break;
            final kind = classifyAction(seat, r, c, tr, tc, count);
            if (kind != null) {
              actions.add({
                'type': kind,
                'fromR': r,
                'fromC': c,
                'toR': tr,
                'toC': tc,
                'count': count,
              });
            }
          }
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
    if (type != 'move' && type != 'capture') {
      throw GameError('未知操作类型：$type');
    }

    final fromR = asInt(action['fromR'], -1);
    final fromC = asInt(action['fromC'], -1);
    final toR = asInt(action['toR'], -1);
    final toC = asInt(action['toC'], -1);
    if (!inBounds(fromR, fromC) || !inBounds(toR, toC)) {
      throw GameError('坐标超出棋盘范围');
    }

    final dist = max((toR - fromR).abs(), (toC - fromC).abs());
    final count = action.containsKey('count') ? asInt(action['count'], -1) : dist;

    final kind = classifyAction(seat, fromR, fromC, toR, toC, count);
    if (kind == null) {
      throw GameError('非法行动：必须沿 8 个方向移动恰好等于分出棋子数的暗格距离，非吃子不可后退，吃子须大于等于敌方叠子数');
    }
    if (kind != type) {
      if (type == 'move' && kind == 'capture') {
        throw GameError('目标格为敌方棋子，请使用吃子操作（capture）');
      }
      if (type == 'capture' && kind == 'move') {
        throw GameError('目标格没有敌方棋子，无法执行吃子（capture）');
      }
    }

    final myColor = colorOfSeat(seat);
    final oppSeat = 1 - seat;

    // Remove `count` checkers from origin stack
    counts[fromR][fromC] -= count;
    if (counts[fromR][fromC] == 0) {
      owner[fromR][fromC] = 0;
    }

    var capturedCount = 0;
    if (kind == 'capture') {
      capturedCount = counts[toR][toC];
      captured[seat] += capturedCount;
      owner[toR][toC] = myColor;
      counts[toR][toC] = count;
      quietMoves = 0;
    } else {
      owner[toR][toC] = myColor;
      counts[toR][toC] += count;
      quietMoves++;
    }

    lastMove = {
      'type': kind,
      'seat': seat,
      'fromR': fromR,
      'fromC': fromC,
      'toR': toR,
      'toC': toC,
      'count': count,
      'captured': capturedCount,
    };

    turnCount++;

    if (totalCheckers(oppSeat) == 0) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 歼灭了全部敌方棋子，大获全胜！';
      host.log(winReason!);
      return;
    }

    final oppActions = legalActionsFor(oppSeat);
    if (oppActions.isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(oppSeat)} 已无合法行动，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (quietMoves >= maxQuietMoves || turnCount >= maxTotalTurns) {
      _adjudicate();
      return;
    }

    turn = oppSeat;
  }

  void _adjudicate() {
    _over = true;
    final c0 = totalCheckers(0);
    final c1 = totalCheckers(1);
    if (c0 != c1) {
      winner = c0 > c1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 剩余棋子更多（$c0 : $c1）获胜！';
    } else {
      winner = -1;
      winReason = '对局结束：双方剩余棋子相同（$c0 : $c1），平局！';
    }
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final actions = legalActionsFor(seat);
    if (actions.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      return actions[rng.nextInt(actions.length)];
    }

    final oppSeat = 1 - seat;
    final oppColor = colorOfSeat(oppSeat);
    final oppTotal = totalCheckers(oppSeat);
    final fDir = seat == 0 ? -1 : 1;
    final farEdgeRow = seat == 0 ? 0 : boardSize - 1;

    // Collect enemy stack positions for distance heuristics
    final enemyStacks = <(int, int, int)>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (owner[r][c] == oppColor && counts[r][c] > 0) {
          enemyStacks.add((r, c, counts[r][c]));
        }
      }
    }

    Map<String, dynamic>? bestAction;
    var bestScore = double.negativeInfinity;

    for (final a in actions) {
      final type = a['type'] as String;
      final fr = a['fromR'] as int;
      final tr = a['toR'] as int;
      final tc = a['toC'] as int;
      final count = a['count'] as int;

      var score = 0.0;

      if (type == 'capture') {
        final enemySize = counts[tr][tc];
        if (enemySize >= oppTotal) {
          return a; // Immediate victory!
        }
        score += 100.0 + enemySize * 28.0;
      } else {
        // Non-capture ('move')
        final dr = tr - fr;
        if (dr * fDir > 0) {
          // Advancing forward
          score += 12.0 + (dr.abs() * 2.0);
        } else {
          // Sideways move: slight penalty unless aligning with enemy
          score -= 4.0;
        }

        // Avoid stranding a single checker on the far edge where it can't move sideways
        final resultingDestHeight = counts[tr][tc] + count;
        if (tr == farEdgeRow && resultingDestHeight < 2) {
          score -= 35.0;
        }
      }

      // Bonus if the landing stack at (tr, tc) threatens an enemy stack in 8 directions
      final newHeight = type == 'capture' ? count : (counts[tr][tc] + count);
      for (final (er, ec, eSize) in enemyStacks) {
        if (er == tr && ec == tc) continue;
        final dR = er - tr;
        final dC = ec - tc;
        final cheb = max(dR.abs(), dC.abs());
        final aligned = dR == 0 || dC == 0 || dR.abs() == dC.abs();
        if (aligned && cheb <= newHeight && eSize <= cheb) {
          score += 22.0 + eSize * 5.0;
        } else {
          // Encourage approaching enemy stacks
          score += max(0.0, 10.0 - cheb) * 1.2;
        }
      }

      score += rng.nextDouble() * 2.5;
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
      'mode': mode,
      'boardSize': boardSize,
      'turn': turn,
      'turnCount': turnCount,
      'quietMoves': quietMoves,
      'maxQuietMoves': maxQuietMoves,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'captured': List<int>.of(captured),
      'checkers': [totalCheckers(0), totalCheckers(1)],
      'owner': [
        for (final row in owner) List<int>.of(row),
      ],
      'counts': [
        for (final row in counts) List<int>.of(row),
      ],
      'board': [
        for (var r = 0; r < boardSize; r++)
          [
            for (var c = 0; c < boardSize; c++)
              owner[r][c] == 1
                  ? counts[r][c]
                  : (owner[r][c] == 2 ? -counts[r][c] : 0),
          ],
      ],
      'legalActions': actions,
      'lastMove': lastMove,
    };
  }
}
