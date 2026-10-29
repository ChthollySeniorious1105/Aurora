import 'dart:math';

import '../../src/engine.dart';

/// Six axial hex directions: (dq, dr).
const List<(int, int)> gipfDirs = [
  (1, 0),
  (0, 1),
  (-1, 1),
  (-1, 0),
  (0, -1),
  (1, -1),
];

/// Three canonical axial line axes for 4-in-a-row detection.
const List<(int, int)> gipfLineAxes = [
  (1, 0),
  (0, 1),
  (1, -1),
];

/// Hex distance from center (0, 0) in axial coordinates (q, r).
int gipfHexDist(int q, int r) => max(q.abs(), max(r.abs(), (q + r).abs()));

/// True if (q, r) is one of the 37 interior board cells (radius <= 3).
bool gipfIsInterior(int q, int r) => gipfHexDist(q, r) <= 3;

/// True if (q, r) is one of the 24 outer rim entry points (radius == 4).
bool gipfIsRim(int q, int r) => gipfHexDist(q, r) == 4;

String gipfKey(int q, int r) => '$q,$r';

/// All 37 interior cells of the radius-3 hex board.
final List<(int, int)> gipfInteriorCells = [
  for (var r = -3; r <= 3; r++)
    for (var q = -3; q <= 3; q++)
      if (gipfIsInterior(q, r)) (q, r),
];

/// All 24 outer rim entry points at radius 4.
final List<(int, int)> gipfRimCells = [
  for (var r = -4; r <= 4; r++)
    for (var q = -4; q <= 4; q++)
      if (gipfIsRim(q, r)) (q, r),
];

class GipfPushMove {
  final int fromQ;
  final int fromR;
  final int dq;
  final int dr;
  const GipfPushMove(this.fromQ, this.fromR, this.dq, this.dr);

  Map<String, dynamic> toAction() => {
        'type': 'push',
        'fromQ': fromQ,
        'fromR': fromR,
        'dq': dq,
        'dr': dr,
      };
}

/// 吉普夫棋 (GIPF) — Kris Burm's flagship Project GIPF game.
class GipfGame extends GameEngine {
  GipfGame(super.setup);

  /// Board keyed by '$q,$r' -> 0 (empty), 1 (White / seat 0), 2 (Black / seat 1).
  final Map<String, int> board = {};

  /// Pieces remaining in each player's reserve.
  late List<int> reserve;

  /// Opponent pieces permanently captured by each player.
  final List<int> captured = [0, 0];

  int turn = 0;
  int turnCount = 0;
  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  Map<String, dynamic>? lastMove;

  bool get isQuick => setup.opt<String>('mode', 'standard') == 'quick';
  int get initialReserve => isQuick ? 12 : 15;
  int get maxTurns => isQuick ? 140 : 200;

  int pieceAt(int q, int r) => board[gipfKey(q, r)] ?? 0;
  void setPieceAt(int q, int r, int v) {
    if (gipfIsInterior(q, r)) {
      board[gipfKey(q, r)] = v;
    }
  }

  @override
  void start() {
    board.clear();
    for (final (q, r) in gipfInteriorCells) {
      board[gipfKey(q, r)] = 0;
    }
    // 6 corners of ring 3 alternate White (1) and Black (2).
    setPieceAt(3, 0, 1);
    setPieceAt(0, 3, 2);
    setPieceAt(-3, 3, 1);
    setPieceAt(-3, 0, 2);
    setPieceAt(0, -3, 1);
    setPieceAt(3, -3, 2);

    reserve = [initialReserve, initialReserve];
    captured[0] = 0;
    captured[1] = 0;
    turn = 0;
    turnCount = 0;
    _over = false;
    winner = null;
    winReason = null;
    lastMove = null;
  }

  /// Check if pushing from rim `(fromQ, fromR)` along `(dq, dr)` is legal.
  /// Returns the list of interior coordinates from `(fromQ + dq, fromR + dr)` up to
  /// and including the first empty interior cell, or null if illegal.
  List<(int, int)>? traceShiftLine(int fromQ, int fromR, int dq, int dr) {
    if (!gipfIsRim(fromQ, fromR)) return null;
    if (!gipfDirs.contains((dq, dr))) return null;
    final startQ = fromQ + dq;
    final startR = fromR + dr;
    if (!gipfIsInterior(startQ, startR)) return null;

    final path = <(int, int)>[];
    var q = startQ;
    var r = startR;
    while (gipfIsInterior(q, r)) {
      path.add((q, r));
      if (pieceAt(q, r) == 0) {
        return path; // Found the first empty cell!
      }
      q += dq;
      r += dr;
    }
    // Line is completely full all the way to the opposite rim.
    return null;
  }

  List<GipfPushMove> legalMoves([int? forSeat]) {
    final s = forSeat ?? turn;
    if (_over || reserve[s] <= 0) return const [];
    final moves = <GipfPushMove>[];
    for (final (q0, r0) in gipfRimCells) {
      for (final (dq, dr) in gipfDirs) {
        if (traceShiftLine(q0, r0, dq, dr) != null) {
          moves.add(GipfPushMove(q0, r0, dq, dr));
        }
      }
    }
    return moves;
  }

  /// Find and resolve any 4+ in a row along all 3 hex line axes.
  /// Prioritizes `activeSeat` first, then `1 - activeSeat`.
  /// Returns details of removed cells for UI highlight and logs.
  List<Map<String, dynamic>> resolveFourInARows(int activeSeat) {
    final events = <Map<String, dynamic>>[];
    final order = [activeSeat, 1 - activeSeat];

    var changed = true;
    while (changed) {
      changed = false;
      for (final owner in order) {
        final targetColor = owner + 1;
        final found = _findFirstFourInARowForColor(targetColor);
        if (found != null) {
          var recycledCount = 0;
          var capturedCount = 0;
          final removedCoords = <List<int>>[];
          for (final (q, r) in found) {
            final c = pieceAt(q, r);
            if (c == 0) continue;
            setPieceAt(q, r, 0);
            removedCoords.add([q, r]);
            if (c == targetColor) {
              reserve[owner]++;
              recycledCount++;
            } else {
              captured[owner]++;
              capturedCount++;
            }
          }
          events.add({
            'owner': owner,
            'recycled': recycledCount,
            'captured': capturedCount,
            'cells': removedCoords,
          });
          changed = true;
          break; // Re-scan from activeSeat priority
        }
      }
    }
    return events;
  }

  /// Scans all lines along the 3 canonical axes for a contiguous segment of >= 4
  /// pieces of `targetColor`. When found, returns the maximal contiguous run of
  /// non-empty pieces along that line containing the 4+ segment.
  List<(int, int)>? _findFirstFourInARowForColor(int targetColor) {
    for (final (dq, dr) in gipfLineAxes) {
      // Enumerate all lines parallel to (dq, dr)
      for (final (startQ, startR) in gipfInteriorCells) {
        // A canonical line start is an interior cell whose predecessor (-dq, -dr) is NOT interior
        if (gipfIsInterior(startQ - dq, startR - dr)) continue;

        final line = <(int, int)>[];
        var q = startQ;
        var r = startR;
        while (gipfIsInterior(q, r)) {
          line.add((q, r));
          q += dq;
          r += dr;
        }

        // Look for 4+ contiguous of targetColor on this line
        var i = 0;
        while (i < line.length) {
          final (qi, ri) = line[i];
          if (pieceAt(qi, ri) != targetColor) {
            i++;
            continue;
          }
          var j = i;
          while (j < line.length && pieceAt(line[j].$1, line[j].$2) == targetColor) {
            j++;
          }
          final runLen = j - i;
          if (runLen >= 4) {
            // Expand left and right along the same line to include all contiguous occupied cells of EITHER color
            var left = i;
            while (left > 0 && pieceAt(line[left - 1].$1, line[left - 1].$2) != 0) {
              left--;
            }
            var right = j - 1;
            while (right + 1 < line.length && pieceAt(line[right + 1].$1, line[right + 1].$2) != 0) {
              right++;
            }
            return line.sublist(left, right + 1);
          }
          i = j;
        }
      }
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    final type = asStr(action['type']);
    if (type != 'push') throw GameError('未知操作类型');

    if (reserve[seat] <= 0) {
      throw GameError('储备区已无棋子');
    }

    final fromQ = asInt(action['fromQ'], 999);
    final fromR = asInt(action['fromR'], 999);
    final dq = asInt(action['dq'], 999);
    final dr = asInt(action['dr'], 999);

    final shiftPath = traceShiftLine(fromQ, fromR, dq, dr);
    if (shiftPath == null) {
      throw GameError('非法推入方向或该排已满');
    }

    // Shift pieces forward from the empty cell end back to the entry cell
    for (var i = shiftPath.length - 1; i > 0; i--) {
      final (toQ, toR) = shiftPath[i];
      final (prevQ, prevR) = shiftPath[i - 1];
      setPieceAt(toQ, toR, pieceAt(prevQ, prevR));
    }
    final (entryQ, entryR) = shiftPath.first;
    setPieceAt(entryQ, entryR, seat + 1);
    reserve[seat]--;
    turnCount++;

    final captureEvents = resolveFourInARows(seat);

    lastMove = {
      'seat': seat,
      'fromQ': fromQ,
      'fromR': fromR,
      'dq': dq,
      'dr': dr,
      'entryQ': entryQ,
      'entryR': entryR,
      'shifted': [
        for (final (q, r) in shiftPath) [q, r]
      ],
      'captures': captureEvents,
    };

    if (captureEvents.isNotEmpty) {
      for (final ev in captureEvents) {
        final o = ev['owner'] as int;
        final rec = ev['recycled'] as int;
        final cap = ev['captured'] as int;
        host.log('${name(o)} 连成四子！回收 $rec 枚己方棋子${cap > 0 ? '，俘获 $cap 枚对方棋子' : ''}');
      }
    }

    final nextSeat = 1 - seat;
    turn = nextSeat;

    // Win Condition: First player whose reserve[seat] == 0 at the start of their turn loses immediately!
    if (reserve[nextSeat] <= 0) {
      _over = true;
      winner = seat;
      winReason = '${name(nextSeat)} 回合开始时储备区已无棋子，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (legalMoves(nextSeat).isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(nextSeat)} 无合法推入方向，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (turnCount >= maxTurns) {
      _over = true;
      final score0 = captured[0] * 10 + reserve[0];
      final score1 = captured[1] * 10 + reserve[1];
      if (score0 > score1) {
        winner = 0;
        winReason = '达到回合上限，${name(0)} 凭借俘获与储备优势获胜！';
      } else if (score1 > score0) {
        winner = 1;
        winReason = '达到回合上限，${name(1)} 凭借俘获与储备优势获胜！';
      } else {
        winner = -1;
        winReason = '达到回合上限，双方势均力敌握手言和！';
      }
      host.log(winReason!);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final rimInfo = <Map<String, dynamic>>[];
    for (final (q0, r0) in gipfRimCells) {
      final dirs = <Map<String, dynamic>>[];
      for (final (dq, dr) in gipfDirs) {
        final nq = q0 + dq;
        final nr = r0 + dr;
        if (!gipfIsInterior(nq, nr)) continue;
        dirs.add({
          'dq': dq,
          'dr': dr,
          'toQ': nq,
          'toR': nr,
          'legal': !_over && reserve[turn] > 0 && traceShiftLine(q0, r0, dq, dr) != null,
        });
      }
      rimInfo.add({
        'q': q0,
        'r': r0,
        'dirs': dirs,
      });
    }

    return {
      'board': Map<String, int>.from(board),
      'cells': [
        for (final (q, r) in gipfInteriorCells)
          {
            'q': q,
            'r': r,
            'color': pieceAt(q, r),
          }
      ],
      'rimPoints': rimInfo,
      'reserve': List<int>.from(reserve),
      'captured': List<int>.from(captured),
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
      return moves[rng.nextInt(moves.length)].toAction();
    }

    var bestScore = -1e9;
    final bestMoves = <GipfPushMove>[];

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

    final pick = bestMoves[rng.nextInt(bestMoves.length)];
    return pick.toAction();
  }

  double _evaluateMove(int seat, GipfPushMove m) {
    final savedBoard = Map<String, int>.from(board);
    final savedReserve = List<int>.from(reserve);
    final savedCaptured = List<int>.from(captured);

    final shiftPath = traceShiftLine(m.fromQ, m.fromR, m.dq, m.dr)!;
    final pushedCellsCount = shiftPath.length - 1;
    for (var i = shiftPath.length - 1; i > 0; i--) {
      final (toQ, toR) = shiftPath[i];
      final (prevQ, prevR) = shiftPath[i - 1];
      setPieceAt(toQ, toR, pieceAt(prevQ, prevR));
    }
    final (entryQ, entryR) = shiftPath.first;
    setPieceAt(entryQ, entryR, seat + 1);
    reserve[seat]--;

    resolveFourInARows(seat);

    final opp = 1 - seat;
    var score = 0.0;

    // Immediate win if opponent has 0 reserve
    if (reserve[opp] <= 0) {
      score += 10000.0;
    }
    // Immediate loss if we have 0 reserve (unless opponent already lost)
    if (reserve[seat] <= 0 && reserve[opp] > 0) {
      score -= 5000.0;
    }

    final capDiff = (captured[seat] - savedCaptured[seat]) - (captured[opp] - savedCaptured[opp]);
    final resDiff = (reserve[seat] - savedReserve[seat]) - (reserve[opp] - savedReserve[opp]);

    score += capDiff * 120.0;
    score += resDiff * 35.0;

    // Reward pushing existing pieces (creates dynamics and captures)
    score += pushedCellsCount * 6.0;

    // Evaluate board alignments (2-in-a-row, 3-in-a-row, centrality)
    final myColor = seat + 1;
    final oppColor = opp + 1;
    for (final (q, r) in gipfInteriorCells) {
      final c = pieceAt(q, r);
      if (c == 0) continue;
      final centerBonus = (3 - gipfHexDist(q, r)) * 1.5;
      if (c == myColor) {
        score += centerBonus;
      } else {
        score -= centerBonus;
      }
    }

    score += _linePotential(myColor) * 8.0;
    score -= _linePotential(oppColor) * 10.0;

    board
      ..clear()
      ..addAll(savedBoard);
    reserve
      ..clear()
      ..addAll(savedReserve);
    captured
      ..clear()
      ..addAll(savedCaptured);

    return score + rng.nextDouble() * 0.5;
  }

  double _linePotential(int targetColor) {
    var total = 0.0;
    for (final (dq, dr) in gipfLineAxes) {
      for (final (startQ, startR) in gipfInteriorCells) {
        if (gipfIsInterior(startQ - dq, startR - dr)) continue;
        var q = startQ;
        var r = startR;
        var run = 0;
        while (gipfIsInterior(q, r)) {
          if (pieceAt(q, r) == targetColor) {
            run++;
            if (run == 2) total += 1.0;
            if (run == 3) total += 4.0;
          } else {
            run = 0;
          }
          q += dq;
          r += dr;
        }
      }
    }
    return total;
  }
}
