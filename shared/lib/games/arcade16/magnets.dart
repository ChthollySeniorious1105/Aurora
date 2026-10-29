import 'dart:math';

import '../../src/engine.dart';
import 'a16_util.dart';

class MagnetsPuzzle {
  final int size;
  final int slotCount;
  /// `size × size` grid of Domino Slot IDs `0..slotCount-1` (`-1` for the single `1×1` blocked cell when `size` is odd).
  final List<List<int>> slotId;
  /// Each Domino Slot `s` (`0..slotCount-1`) as `[idxA, idxB]` (`idxA < idxB`).
  final List<List<int>> slots;
  /// Exact count of `+` (`1`) cells in each row `0..size-1`.
  final List<int> rowPlus;
  /// Exact count of `-` (`2`) cells in each row `0..size-1`.
  final List<int> rowMinus;
  /// Exact count of `+` (`1`) cells in each column `0..size-1`.
  final List<int> colPlus;
  /// Exact count of `-` (`2`) cells in each column `0..size-1`.
  final List<int> colMinus;
  /// Flat `size * size` solution (`0` = Neutral, `1` = `+`, `2` = `-`).
  final List<int> solutionBoard;

  const MagnetsPuzzle({
    required this.size,
    required this.slotCount,
    required this.slotId,
    required this.slots,
    required this.rowPlus,
    required this.rowMinus,
    required this.colPlus,
    required this.colMinus,
    required this.solutionBoard,
  });

  List<int> get slotMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) slotId[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);

  /// Returns the partner flat cell index of [idx] in the same domino slot, or `-1` if blocked/invalid.
  int partnerCellIdx(int idx) {
    if (idx < 0 || idx >= size * size) return -1;
    final sid = slotId[idx ~/ size][idx % size];
    if (sid < 0 || sid >= slots.length) return -1;
    final pair = slots[sid];
    if (pair.length < 2) return -1;
    return pair[0] == idx ? pair[1] : pair[0];
  }
}

class MagnetsAnalysis {
  final Set<int> satisfiedSlots;
  final Set<int> violatedSlots;
  final Set<int> samePoleConflictCells;
  final List<int> rowPlusCounts;
  final List<int> rowMinusCounts;
  final List<int> colPlusCounts;
  final List<int> colMinusCounts;
  final Set<int> satisfiedRows;
  final Set<int> violatedRows;
  final Set<int> satisfiedCols;
  final Set<int> violatedCols;
  final int plusCount;
  final int minusCount;
  final int activeMagnetCount;
  final int slotCount;
  final int size;

  const MagnetsAnalysis({
    required this.satisfiedSlots,
    required this.violatedSlots,
    required this.samePoleConflictCells,
    required this.rowPlusCounts,
    required this.rowMinusCounts,
    required this.colPlusCounts,
    required this.colMinusCounts,
    required this.satisfiedRows,
    required this.violatedRows,
    required this.satisfiedCols,
    required this.violatedCols,
    required this.plusCount,
    required this.minusCount,
    required this.activeMagnetCount,
    required this.slotCount,
    required this.size,
  });

  bool get isSolved =>
      slotCount > 0 &&
      satisfiedSlots.length == slotCount &&
      violatedSlots.isEmpty &&
      samePoleConflictCells.isEmpty &&
      satisfiedRows.length == size &&
      satisfiedCols.length == size &&
      violatedRows.isEmpty &&
      violatedCols.isEmpty;
}

class MagnetsSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static MagnetsAnalysis analyze(MagnetsPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final slotCount = puz.slotCount;

    final satisfiedSlots = <int>{};
    final violatedSlots = <int>{};
    final samePoleConflictCells = <int>{};

    var activeMagnetCount = 0;

    // 1. Check each 1x2 / 2x1 Domino Slot is [0, 0], [1, 2], or [2, 1]
    for (var s = 0; s < slotCount; s++) {
      final pair = puz.slots[s];
      final u = pair[0], v = pair[1];
      final valU = u < board.length ? board[u] : 0;
      final valV = v < board.length ? board[v] : 0;
      if (valU == 0 && valV == 0) {
        satisfiedSlots.add(s);
      } else if ((valU == 1 && valV == 2) || (valU == 2 && valV == 1)) {
        satisfiedSlots.add(s);
        activeMagnetCount++;
      } else {
        violatedSlots.add(s);
        samePoleConflictCells.add(u);
        samePoleConflictCells.add(v);
      }
    }

    // 2. Count row/col + and - and check orthogonal same-pole adjacency
    final rowPlusCounts = List<int>.filled(size, 0);
    final rowMinusCounts = List<int>.filled(size, 0);
    final colPlusCounts = List<int>.filled(size, 0);
    final colMinusCounts = List<int>.filled(size, 0);
    var plusCount = 0;
    var minusCount = 0;

    for (var i = 0; i < n; i++) {
      final r = i ~/ size, c = i % size;
      final val = i < board.length ? board[i] : 0;
      if (puz.slotId[r][c] < 0 && val != 0) {
        samePoleConflictCells.add(i);
      }
      if (val == 1) {
        plusCount++;
        rowPlusCounts[r]++;
        colPlusCounts[c]++;
      } else if (val == 2) {
        minusCount++;
        rowMinusCounts[r]++;
        colMinusCounts[c]++;
      } else if (val != 0) {
        samePoleConflictCells.add(i);
      }

      if (val == 1 || val == 2) {
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          final nVal = nxt < board.length ? board[nxt] : 0;
          if (nVal == val) {
            samePoleConflictCells.add(i);
            samePoleConflictCells.add(nxt);
          }
        }
      }
    }

    // 3. Check row and column + / - counts
    final satisfiedRows = <int>{};
    final violatedRows = <int>{};
    for (var r = 0; r < size; r++) {
      final pCnt = rowPlusCounts[r], mCnt = rowMinusCounts[r];
      final pTarget = puz.rowPlus[r], mTarget = puz.rowMinus[r];
      if (pCnt == pTarget && mCnt == mTarget) {
        satisfiedRows.add(r);
      } else if (pCnt > pTarget || mCnt > mTarget) {
        violatedRows.add(r);
      }
    }

    final satisfiedCols = <int>{};
    final violatedCols = <int>{};
    for (var c = 0; c < size; c++) {
      final pCnt = colPlusCounts[c], mCnt = colMinusCounts[c];
      final pTarget = puz.colPlus[c], mTarget = puz.colMinus[c];
      if (pCnt == pTarget && mCnt == mTarget) {
        satisfiedCols.add(c);
      } else if (pCnt > pTarget || mCnt > mTarget) {
        violatedCols.add(c);
      }
    }

    return MagnetsAnalysis(
      satisfiedSlots: satisfiedSlots,
      violatedSlots: violatedSlots,
      samePoleConflictCells: samePoleConflictCells,
      rowPlusCounts: rowPlusCounts,
      rowMinusCounts: rowMinusCounts,
      colPlusCounts: colPlusCounts,
      colMinusCounts: colMinusCounts,
      satisfiedRows: satisfiedRows,
      violatedRows: violatedRows,
      satisfiedCols: satisfiedCols,
      violatedCols: violatedCols,
      plusCount: plusCount,
      minusCount: minusCount,
      activeMagnetCount: activeMagnetCount,
      slotCount: slotCount,
      size: size,
    );
  }

  static bool isSolved(MagnetsPuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  /// Generates a guaranteed-valid Magnets puzzle for [size] (`5` or `6`).
  static MagnetsPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetSlots = n ~/ 2;

    // Even-parity non-(0,0) candidate blocked cells for odd N
    final oddBlockedCandidates = <int>[
      if (size.isOdd) ...[
        (size - 1) * size + (size - 1),
        (size ~/ 2) * size + (size ~/ 2),
        (size - 1) * size,
        size - 1,
      ],
    ];

    for (var attempt = 0; attempt < 40; attempt++) {
      final slotFlat = List<int>.filled(n, -2);
      if (size.isOdd) {
        final blockedIdx = oddBlockedCandidates[rng.nextInt(oddBlockedCandidates.length)];
        slotFlat[blockedIdx] = -1;
      }

      final slots = <List<int>>[];
      var steps = 0;

      bool tileGrid() {
        if (++steps > 800) return false;
        var firstUncovered = -1;
        for (var i = 0; i < n; i++) {
          if (slotFlat[i] == -2) {
            firstUncovered = i;
            break;
          }
        }
        if (firstUncovered == -1) return true;

        final r = firstUncovered ~/ size, c = firstUncovered % size;
        final nbs = <int>[
          if (c + 1 < size && slotFlat[r * size + c + 1] == -2) r * size + c + 1,
          if (r + 1 < size && slotFlat[(r + 1) * size + c] == -2) (r + 1) * size + c,
        ]..shuffle(rng);

        for (final nb in nbs) {
          final sid = slots.length;
          slotFlat[firstUncovered] = sid;
          slotFlat[nb] = sid;
          slots.add([firstUncovered, nb]);
          if (tileGrid()) return true;
          slots.removeLast();
          slotFlat[firstUncovered] = -2;
          slotFlat[nb] = -2;
        }
        return false;
      }

      if (!tileGrid() || slots.length != targetSlots) continue;

      // Assign each domino slot either [1, 2], [2, 1], or [0, 0] with no same-pole adjacency
      final sol = List<int>.filled(n, 0);
      final slotOrder = [for (var s = 0; s < targetSlots; s++) s]..shuffle(rng);
      var activeMagnets = 0;

      bool canPlacePole(int idx, int pole) {
        if (pole == 0) return true;
        final r = idx ~/ size, c = idx % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            if (sol[nr * size + nc] == pole) return false;
          }
        }
        return true;
      }

      for (final s in slotOrder) {
        final u = slots[s][0], v = slots[s][1];
        // Prefer active magnets ~75% of the time when legal
        final options = <(int, int)>[
          (1, 2),
          (2, 1),
        ]..shuffle(rng);
        if (rng.nextInt(4) == 0 && activeMagnets >= targetSlots ~/ 2) {
          options.insert(0, (0, 0));
        } else {
          options.add((0, 0));
        }

        for (final (pU, pV) in options) {
          if (canPlacePole(u, pU) && canPlacePole(v, pV)) {
            sol[u] = pU;
            sol[v] = pV;
            if (pU != 0) activeMagnets++;
            break;
          }
        }
      }

      if (activeMagnets < (size <= 5 ? 6 : 9)) continue;

      final slotId = [
        for (var r = 0; r < size; r++)
          [for (var c = 0; c < size; c++) slotFlat[r * size + c]],
      ];
      final rowPlus = List<int>.filled(size, 0);
      final rowMinus = List<int>.filled(size, 0);
      final colPlus = List<int>.filled(size, 0);
      final colMinus = List<int>.filled(size, 0);

      for (var i = 0; i < n; i++) {
        final r = i ~/ size, c = i % size;
        if (sol[i] == 1) {
          rowPlus[r]++;
          colPlus[c]++;
        } else if (sol[i] == 2) {
          rowMinus[r]++;
          colMinus[c]++;
        }
      }

      final puz = MagnetsPuzzle(
        size: size,
        slotCount: targetSlots,
        slotId: slotId,
        slots: slots,
        rowPlus: rowPlus,
        rowMinus: rowMinus,
        colPlus: colPlus,
        colMinus: colMinus,
        solutionBoard: sol,
      );
      if (isSolved(puz, sol) && !isSolved(puz, puz.initialBoard)) {
        return puz;
      }
    }

    // Deterministic fallback
    final slotId = [
      for (var r = 0; r < size; r++) List<int>.filled(size, -1),
    ];
    final slots = <List<int>>[];
    if (size.isEven) {
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c += 2) {
          final sid = slots.length;
          slotId[r][c] = sid;
          slotId[r][c + 1] = sid;
          slots.add([r * size + c, r * size + c + 1]);
        }
      }
    } else {
      // Tile rows 0..size-1 cols 0..size-2 with horizontal dominoes, and last col rows 0..size-2 with vertical dominoes; (size-1, size-1) blocked
      for (var r = 0; r < size; r++) {
        for (var c = 0; c + 1 < size - 1; c += 2) {
          final sid = slots.length;
          slotId[r][c] = sid;
          slotId[r][c + 1] = sid;
          slots.add([r * size + c, r * size + c + 1]);
        }
      }
      for (var r = 0; r + 1 < size - 1; r += 2) {
        final c = size - 1;
        final sid = slots.length;
        slotId[r][c] = sid;
        slotId[r + 1][c] = sid;
        slots.add([r * size + c, (r + 1) * size + c]);
      }
    }

    final sol = List<int>.filled(n, 0);
    for (var s = 0; s < slots.length; s++) {
      if (s % 4 == 3) continue; // Leave every 4th slot neutral
      for (final idx in slots[s]) {
        final r = idx ~/ size, c = idx % size;
        sol[idx] = (r + c).isEven ? 1 : 2;
      }
    }

    final rowPlus = List<int>.filled(size, 0);
    final rowMinus = List<int>.filled(size, 0);
    final colPlus = List<int>.filled(size, 0);
    final colMinus = List<int>.filled(size, 0);
    for (var i = 0; i < n; i++) {
      final r = i ~/ size, c = i % size;
      if (sol[i] == 1) {
        rowPlus[r]++;
        colPlus[c]++;
      } else if (sol[i] == 2) {
        rowMinus[r]++;
        colMinus[c]++;
      }
    }

    return MagnetsPuzzle(
      size: size,
      slotCount: slots.length,
      slotId: slotId,
      slots: slots,
      rowPlus: rowPlus,
      rowMinus: rowMinus,
      colPlus: colPlus,
      colMinus: colMinus,
      solutionBoard: sol,
    );
  }
}

/// 磁铁正负极竞速 (Magnets Race, 1-6 人).
class MagnetsGame extends GameEngine {
  MagnetsGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late MagnetsPuzzle currentPuzzle;
  late List<MagnetsPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a16Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 240, _ => 440 };

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    p.resignNo = ++_resigns;
    p.status = 'resigned';
    host.log('${name(seat)} 认输');
    final still = [for (var s = 0; s < players; s++) if (ps[s].resignNo == 0) s];
    if (still.isEmpty || (players > 1 && still.length <= 1)) {
      _finish(still.isEmpty ? '所有人都已认输' : '其他人都已认输');
    } else {
      _checkRoundComplete();
    }
  }

  @override
  void start() {
    final rawSize = setup.opt<int>('size', 5);
    size = rawSize == 6 ? 6 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = MagnetsSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) MagnetsPlayer(size * size)];

    host.log('磁铁正负极竞速开始（$size×$size 网格，共 $totalRounds 题）！为多米诺骨牌填入 [+, -] 或保持中性，同极不相邻并匹配行列计数！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = MagnetsSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size * size);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本题时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a16Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  (int, int) _resolveCell(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return (r, c);
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
    }
    return (idx ~/ size, idx % size);
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'next') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.status != 'play') throw GameError('你已完成本题');

    switch (type) {
      case 'cycle':
      case 'toggle':
      case 'set':
        final (r, c) = _resolveCell(a);
        final sid = currentPuzzle.slotId[r][c];
        final idx = r * size + c;
        if (sid < 0) {
          if (a.containsKey('val') && asInt(a['val'], -1) == 0) {
            p.board[idx] = 0;
            moves++;
            return;
          }
          throw GameError('阻挡格不能放置磁铁');
        }
        final partnerIdx = currentPuzzle.partnerCellIdx(idx);
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('磁极状态必须在 0～2 之间');
          }
          p.board[idx] = v;
          if (partnerIdx >= 0 && a['raw'] != true) {
            p.board[partnerIdx] = switch (v) { 1 => 2, 2 => 1, _ => 0 };
          }
        } else {
          final nextVal = (p.board[idx] + 1) % 3;
          p.board[idx] = nextVal;
          if (partnerIdx >= 0) {
            p.board[partnerIdx] = switch (nextVal) { 1 => 2, 2 => 1, _ => 0 };
          }
        }
        moves++;
        if (MagnetsSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.board.fillRange(0, p.board.length, 0);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 题');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    roundSolvers++;
    final pts = switch (roundSolvers) {
      1 => 10,
      2 => 8,
      3 => 6,
      _ => 4,
    };
    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSolveSec += roundSec;
    host.log('${name(seat)} 第 $roundSolvers 个解出磁铁正负极谜题，+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 题');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'reason': reason,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
          },
      ],
    };

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 题已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a16Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalSolveSec - pb.totalSolveSec;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'sec': ps[s].totalSolveSec,
        });
    host.log('游戏结束（$why）！冠军：${a16Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;
    final sol = puz.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diffSlots = <int>[
      for (var s = 0; s < puz.slotCount; s++)
        if (p.board[puz.slots[s][0]] != sol[puz.slots[s][0]] ||
            p.board[puz.slots[s][1]] != sol[puz.slots[s][1]])
          puz.slots[s][0],
    ];
    if (diffSlots.isNotEmpty) {
      final pick = diffSlots[rng.nextInt(diffSlots.length)];
      return {
        'type': 'cycle',
        'r': pick ~/ size,
        'c': pick % size,
      };
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myBoard = me?.board ?? puz.initialBoard;
    final an = MagnetsSolver.analyze(puz, myBoard);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'slotCount': puz.slotCount,
      'slotId': puz.slotId,
      'slotMap': puz.slotMap,
      'slots': puz.slots,
      'rowPlus': puz.rowPlus,
      'rowMinus': puz.rowMinus,
      'colPlus': puz.colPlus,
      'colMinus': puz.colMinus,
      'board': myBoard,
      'satisfiedSlots': an.satisfiedSlots.toList()..sort(),
      'violatedSlots': an.violatedSlots.toList()..sort(),
      'samePoleConflictCells': an.samePoleConflictCells.toList()..sort(),
      'rowPlusCounts': an.rowPlusCounts,
      'rowMinusCounts': an.rowMinusCounts,
      'colPlusCounts': an.colPlusCounts,
      'colMinusCounts': an.colMinusCounts,
      'satisfiedRows': an.satisfiedRows.toList()..sort(),
      'violatedRows': an.violatedRows.toList()..sort(),
      'satisfiedCols': an.satisfiedCols.toList()..sort(),
      'violatedCols': an.violatedCols.toList()..sort(),
      'satisfiedSlotCount': an.satisfiedSlots.length,
      'plusCount': an.plusCount,
      'minusCount': an.minusCount,
      'activeMagnetCount': an.activeMagnetCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = MagnetsSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedLines': pAn.satisfiedRows.length + pAn.satisfiedCols.length,
              'totalLines': size * 2,
              'activeMagnets': pAn.activeMagnetCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class MagnetsPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  MagnetsPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
