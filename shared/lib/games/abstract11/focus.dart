import '../../src/engine.dart';

/// Four orthogonal directions (dr, dc): N, S, E, W.
const List<(int, int)> focusDirs = [
  (-1, 0),
  (1, 0),
  (0, 1),
  (0, -1),
];

/// True if `(r, c)` is a playable cell on the Focus board (`size` = 8 for standard, 6 for quick).
bool focusIsPlayable(int r, int c, int size) {
  if (r < 0 || r >= size || c < 0 || c >= size) return false;
  if (size == 6) return true; // 6x6 quick board has all 36 cells playable
  // 8x8 board with 4 corner triangles of 3 cells clipped (64 - 12 = 52 cells)
  if (r + c < 2) return false;
  if (r + (size - 1 - c) < 2) return false;
  if ((size - 1 - r) + c < 2) return false;
  if ((size - 1 - r) + (size - 1 - c) < 2) return false;
  return true;
}

/// 焦点叠塔棋 (Focus / Domination) — Sid Sackson's Spiel des Jahres 1981 classic.
class FocusGame extends GameEngine {
  FocusGame(super.setup);

  late int boardSize;
  late int targetCaptures;

  /// `board[r][c]` is the stack of pieces from bottom to top (`0` = White, `1` = Black).
  late List<List<List<int>>> board;

  /// Reserve pieces held by each player (`reserve[0]`, `reserve[1]`).
  final List<int> reserve = [0, 0];

  /// Enemy pieces permanently captured by each player (`captured[0]`, `captured[1]`).
  final List<int> captured = [0, 0];

  int turn = 0;
  int turnCount = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  Map<String, dynamic>? lastMove;

  bool get isQuick => setup.opt<String>('mode', 'standard') == 'quick';
  int get maxTurns => isQuick ? 160 : 240;

  bool isPlayable(int r, int c) => focusIsPlayable(r, c, boardSize);

  List<int> stackAt(int r, int c) => board[r][c];

  int? controllerOf(int r, int c) {
    if (!isPlayable(r, c)) return null;
    final st = board[r][c];
    return st.isEmpty ? null : st.last;
  }

  @override
  void start() {
    boardSize = isQuick ? 6 : 8;
    targetCaptures = isQuick ? 4 : 6;
    board = List.generate(
      boardSize,
      (_) => List.generate(boardSize, (_) => <int>[]),
    );

    // Initialize symmetric pattern of 18 White (0) and 18 Black (1) single pieces
    // in the central 6x6 region (rows 1..6, cols 1..6 on 8x8; rows 0..5, cols 0..5 on 6x6).
    final offset = boardSize == 8 ? 1 : 0;
    for (var dr = 0; dr < 6; dr++) {
      for (var dc = 0; dc < 6; dc++) {
        final pairEven = (dc % 4) < 2;
        final color = (dr.isEven == pairEven) ? 0 : 1;
        board[offset + dr][offset + dc].add(color);
      }
    }

    reserve[0] = 0;
    reserve[1] = 0;
    captured[0] = 0;
    captured[1] = 0;
    turn = 0;
    turnCount = 0;
    _over = false;
    winner = null;
    winReason = null;
    lastMove = null;
  }

  /// Apply the 5-piece stack overflow rule at `(r, c)` for `activeSeat`.
  /// Returns `(recycledToReserve, capturedEnemy)`.
  (int, int) resolveOverflow(int r, int c, int activeSeat) {
    final st = board[r][c];
    var addedReserve = 0;
    var addedCapture = 0;
    while (st.length > 5) {
      final bottom = st.removeAt(0);
      if (bottom == activeSeat) {
        reserve[activeSeat]++;
        addedReserve++;
      } else {
        captured[activeSeat]++;
        addedCapture++;
      }
    }
    return (addedReserve, addedCapture);
  }

  /// All legal moves (stack moves + reserve drops) for `forSeat`.
  List<Map<String, dynamic>> legalMoves([int? forSeat]) {
    final s = forSeat ?? turn;
    if (_over) return const [];
    final moves = <Map<String, dynamic>>[];

    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (!isPlayable(r, c)) continue;
        final st = board[r][c];
        if (st.isNotEmpty && st.last == s) {
          for (var k = 1; k <= st.length; k++) {
            for (final (dr, dc) in focusDirs) {
              final tr = r + dr * k;
              final tc = c + dc * k;
              if (isPlayable(tr, tc)) {
                moves.add({
                  'type': 'move',
                  'fromR': r,
                  'fromC': c,
                  'toR': tr,
                  'toC': tc,
                  'count': k,
                });
              }
            }
          }
        }
      }
    }

    if (reserve[s] > 0) {
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          if (isPlayable(r, c)) {
            moves.add({
              'type': 'drop',
              'r': r,
              'c': c,
            });
          }
        }
      }
    }

    return moves;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    var addedRes = 0;
    var addedCap = 0;

    if (type == 'move') {
      final fromR = asInt(action['fromR'], -1);
      final fromC = asInt(action['fromC'], -1);
      final toR = asInt(action['toR'], -1);
      final toC = asInt(action['toC'], -1);
      final count = asInt(action['count'], -1);

      if (!isPlayable(fromR, fromC) || !isPlayable(toR, toC)) {
        throw GameError('坐标超出有效棋盘范围');
      }
      final src = board[fromR][fromC];
      if (src.isEmpty || src.last != seat) {
        throw GameError('只能移动顶部为己方棋子的叠塔');
      }
      if (count < 1 || count > src.length) {
        throw GameError('移动层数不合法');
      }
      final dr = (toR - fromR).abs();
      final dc = (toC - fromC).abs();
      if (!((dr == count && dc == 0) || (dr == 0 && dc == count))) {
        throw GameError('必须沿正交方向精确移动 $count 步');
      }

      final movingSlice = src.sublist(src.length - count);
      src.removeRange(src.length - count, src.length);
      board[toR][toC].addAll(movingSlice);

      final (res, cap) = resolveOverflow(toR, toC, seat);
      addedRes = res;
      addedCap = cap;

      lastMove = {
        'type': 'move',
        'seat': seat,
        'fromR': fromR,
        'fromC': fromC,
        'toR': toR,
        'toC': toC,
        'count': count,
        'recycled': addedRes,
        'captured': addedCap,
      };
    } else if (type == 'drop') {
      if (reserve[seat] <= 0) {
        throw GameError('储备区没有可用棋子');
      }
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (!isPlayable(r, c)) {
        throw GameError('目标格不在有效棋盘内');
      }
      reserve[seat]--;
      board[r][c].add(seat);

      final (res, cap) = resolveOverflow(r, c, seat);
      addedRes = res;
      addedCap = cap;

      lastMove = {
        'type': 'drop',
        'seat': seat,
        'r': r,
        'c': c,
        'recycled': addedRes,
        'captured': addedCap,
      };
    } else {
      throw GameError('未知操作类型');
    }

    turnCount++;
    if (addedRes > 0 || addedCap > 0) {
      host.log('${name(seat)} 触发五层溢出：回收 $addedRes 枚储备棋子，俘获 $addedCap 枚敌方棋子');
    }

    if (captured[seat] >= targetCaptures) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 率先俘获 ${captured[seat]} 枚敌方棋子获胜！';
      host.log(winReason!);
      return;
    }

    final nextSeat = 1 - seat;
    turn = nextSeat;

    if (legalMoves(nextSeat).isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(nextSeat)} 已无受控叠塔且无储备棋子可下，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (turnCount >= maxTurns) {
      _over = true;
      final s0 = captured[0] * 100 + countControlledStacks(0) * 5 + reserve[0];
      final s1 = captured[1] * 100 + countControlledStacks(1) * 5 + reserve[1];
      if (s0 > s1) {
        winner = 0;
        winReason = '达到回合上限，${name(0)} 凭借俘获与控塔优势获胜！';
      } else if (s1 > s0) {
        winner = 1;
        winReason = '达到回合上限，${name(1)} 凭借俘获与控塔优势获胜！';
      } else {
        winner = -1;
        winReason = '达到回合上限，双方战成平局！';
      }
      host.log(winReason!);
    }
  }

  int countControlledStacks(int seat) {
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (isPlayable(r, c) && board[r][c].isNotEmpty && board[r][c].last == seat) {
          count++;
        }
      }
    }
    return count;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'boardSize': boardSize,
      'targetCaptures': targetCaptures,
      'board': [
        for (var r = 0; r < boardSize; r++)
          [
            for (var c = 0; c < boardSize; c++)
              isPlayable(r, c) ? List<int>.from(board[r][c]) : null,
          ]
      ],
      'reserve': List<int>.from(reserve),
      'captured': List<int>.from(captured),
      'controlled': [countControlledStacks(0), countControlledStacks(1)],
      'turn': turn,
      'turnCount': turnCount,
      'maxTurns': maxTurns,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'lastMove': lastMove,
      'mode': isQuick ? 'quick' : 'standard',
    };
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return [1, 1];
    return rankWinners(2, [winner!]);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final moves = legalMoves(seat);
    if (moves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      return moves[rng.nextInt(moves.length)];
    }

    var bestScore = -1e9;
    final bestMoves = <Map<String, dynamic>>[];

    for (final m in moves) {
      final score = _evaluateMove(seat, m);
      if (score > bestScore + 1e-6) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(m);
      } else if ((score - bestScore).abs() <= 1e-6) {
        bestMoves.add(m);
      }
    }

    return bestMoves[rng.nextInt(bestMoves.length)];
  }

  double _evaluateMove(int seat, Map<String, dynamic> m) {
    final opp = 1 - seat;
    final type = m['type'] as String;
    var score = 0.0;

    if (type == 'move') {
      final fromR = m['fromR'] as int;
      final fromC = m['fromC'] as int;
      final toR = m['toR'] as int;
      final toC = m['toC'] as int;
      final k = m['count'] as int;

      final src = board[fromR][fromC];
      final dst = board[toR][toC];

      final movingSlice = src.sublist(src.length - k);
      final remainingSrc = src.sublist(0, src.length - k);
      final combined = <int>[...dst, ...movingSlice];

      // Check overflow captures & reserves
      var simCap = 0;
      var simRes = 0;
      if (combined.length > 5) {
        final overflowCount = combined.length - 5;
        for (var i = 0; i < overflowCount; i++) {
          if (combined[i] == seat) {
            simRes++;
          } else {
            simCap++;
          }
        }
      }

      if (captured[seat] + simCap >= targetCaptures) {
        return 100000.0;
      }

      score += simCap * 160.0;
      score += simRes * 45.0;

      // Landing on an opponent-controlled stack takes control of all its pieces!
      if (dst.isNotEmpty && dst.last == opp) {
        score += 35.0 + dst.length * 10.0;
      } else if (dst.isNotEmpty && dst.last == seat) {
        // Building taller stacks up to 5 helps overflow on next turn
        score += 12.0 + dst.length * 4.0;
      }

      // Leaving our own color exposed vs opponent's color exposed at source
      if (remainingSrc.isNotEmpty) {
        if (remainingSrc.last == seat) {
          score += 18.0; // Kept control of both source and destination!
        } else {
          score -= 14.0 + remainingSrc.length * 4.0;
        }
      }
    } else if (type == 'drop') {
      final r = m['r'] as int;
      final c = m['c'] as int;
      final dst = board[r][c];
      final combined = <int>[...dst, seat];

      var simCap = 0;
      var simRes = 0;
      if (combined.length > 5) {
        final bottom = combined.first;
        if (bottom == seat) {
          simRes++;
        } else {
          simCap++;
        }
      }

      if (captured[seat] + simCap >= targetCaptures) {
        return 100000.0;
      }

      score += simCap * 160.0;
      score += simRes * 35.0;
      if (dst.isNotEmpty && dst.last == opp) {
        score += 40.0 + dst.length * 12.0;
      } else {
        score -= 15.0; // Prefer keeping reserve for tactical captures/hijacks
      }
    }

    return score + rng.nextDouble() * 0.5;
  }
}
