import 'dart:math';

import '../../src/engine.dart';
import 'a11_util.dart';

class SuguruRegion {
  final int id;
  /// Sorted flat cell indices (`r * size + c`) belonging to this polyomino region (`1..5` cells).
  final List<int> cells;

  const SuguruRegion({
    required this.id,
    required this.cells,
  });

  int get size => cells.length;
  int get anchorCell => cells.first;

  Map<String, dynamic> toJson() => {
        'id': id,
        'cells': cells,
        'size': size,
        'anchor': anchorCell,
      };
}

class SuguruPuzzle {
  final int size;
  /// 2D `size × size` region IDs (`0..regionList.length-1`).
  final List<List<int>> regions;
  /// Flat `size * size` list mapping each cell index to its region ID.
  final List<int> regionMap;
  final List<SuguruRegion> regionList;
  /// 2D `size × size` fixed clues (`0` = empty, `1..5` = given digit).
  final List<List<int>> clues;
  /// Flat `size * size` valid Suguru solution of `1..5`.
  final List<int> solutionBoard;

  const SuguruPuzzle({
    required this.size,
    required this.regions,
    required this.regionMap,
    required this.regionList,
    required this.clues,
    required this.solutionBoard,
  });

  List<int> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];
}

class SuguruAnalysis {
  final Set<int> regionDuplicateCells;
  final Set<int> adjacentTouchCells;
  final Set<int> violatedClueCells;
  final Set<int> satisfiedRegions;
  final Set<int> violatedRegions;
  final int filledCount;
  final int totalRegions;

  const SuguruAnalysis({
    required this.regionDuplicateCells,
    required this.adjacentTouchCells,
    required this.violatedClueCells,
    required this.satisfiedRegions,
    required this.violatedRegions,
    required this.filledCount,
    required this.totalRegions,
  });

  Set<int> get conflictCells => {
        ...regionDuplicateCells,
        ...adjacentTouchCells,
        ...violatedClueCells,
      };

  bool get isSolved =>
      filledCount > 0 &&
      regionDuplicateCells.isEmpty &&
      adjacentTouchCells.isEmpty &&
      violatedClueCells.isEmpty &&
      satisfiedRegions.length == totalRegions;
}

class SuguruSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];
  static const List<int> adj8Dr = [-1, -1, -1, 0, 0, 1, 1, 1];
  static const List<int> adj8Dc = [-1, 0, 1, -1, 1, -1, 0, 1];

  static SuguruAnalysis analyze(SuguruPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final regionDuplicateCells = <int>{};
    final adjacentTouchCells = <int>{};
    final violatedClueCells = <int>{};
    final satisfiedRegions = <int>{};
    final violatedRegions = <int>{};

    var filledCount = 0;
    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v >= 1 && v <= 5) filledCount++;
      final r = i ~/ size, c = i % size;
      final fixed = puz.clues[r][c];
      if (fixed > 0 && v != fixed) {
        violatedClueCells.add(i);
      }
    }

    // 1. Check 8-way adjacent cells for identical digits
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final v = idx < board.length ? board[idx] : 0;
        if (v < 1 || v > 5) continue;
        for (var d = 0; d < 8; d++) {
          final nr = r + adj8Dr[d], nc = c + adj8Dc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          final nv = nIdx < board.length ? board[nIdx] : 0;
          if (nv == v) {
            adjacentTouchCells.add(idx);
            adjacentTouchCells.add(nIdx);
          }
        }
      }
    }

    // 2. Check each region of size K contains 1..K with no duplicates
    for (final reg in puz.regionList) {
      final k = reg.size;
      final seen = <int, int>{};
      var regComplete = true;
      var regValid = true;
      for (final idx in reg.cells) {
        final v = idx < board.length ? board[idx] : 0;
        if (v < 1 || v > 5) {
          regComplete = false;
          continue;
        }
        if (v > k) {
          regValid = false;
          regionDuplicateCells.add(idx);
        }
        if (seen.containsKey(v)) {
          regValid = false;
          regionDuplicateCells.add(idx);
          regionDuplicateCells.add(seen[v]!);
        } else {
          seen[v] = idx;
        }
      }
      if (!regValid) {
        violatedRegions.add(reg.id);
      } else if (regComplete && seen.length == k) {
        satisfiedRegions.add(reg.id);
      }
    }

    return SuguruAnalysis(
      regionDuplicateCells: regionDuplicateCells,
      adjacentTouchCells: adjacentTouchCells,
      violatedClueCells: violatedClueCells,
      satisfiedRegions: satisfiedRegions,
      violatedRegions: violatedRegions,
      filledCount: filledCount,
      totalRegions: puz.regionList.length,
    );
  }

  static bool isSolved(SuguruPuzzle puz, List<int> board) {
    final size = puz.size;
    if (board.length != size * size) return false;
    final an = analyze(puz, board);
    return an.filledCount == size * size &&
        an.regionDuplicateCells.isEmpty &&
        an.adjacentTouchCells.isEmpty &&
        an.violatedClueCells.isEmpty &&
        an.satisfiedRegions.length == puz.regionList.length;
  }

  /// Generates a random contiguous polyomino partition of [size]×[size] where
  /// each region has size `1..5` (preferring `3..5`).
  static (List<int>, List<SuguruRegion>) _partitionGrid(int size, Random rng) {
    final n = size * size;
    final regMap = List<int>.filled(n, -1);
    final cellsByReg = <List<int>>[];

    int unassignedOrthoCount(int idx) {
      final r = idx ~/ size, c = idx % size;
      var cnt = 0;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size && regMap[nr * size + nc] == -1) {
          cnt++;
        }
      }
      return cnt;
    }

    while (true) {
      // Pick an unassigned cell with minimum unassigned orthogonal neighbors
      final unassigned = <int>[for (var i = 0; i < n; i++) if (regMap[i] == -1) i];
      if (unassigned.isEmpty) break;
      unassigned.shuffle(rng);
      unassigned.sort((a, b) => unassignedOrthoCount(a).compareTo(unassignedOrthoCount(b)));

      final start = unassigned.first;
      final regId = cellsByReg.length;
      final targetSize = const [4, 5, 5, 4, 5, 3][rng.nextInt(6)];
      final cells = <int>[start];
      regMap[start] = regId;

      while (cells.length < targetSize) {
        final frontier = <int>[];
        for (final cur in cells) {
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nIdx = nr * size + nc;
            if (regMap[nIdx] == -1 && !frontier.contains(nIdx)) {
              frontier.add(nIdx);
            }
          }
        }
        if (frontier.isEmpty) break;
        frontier.shuffle(rng);
        frontier.sort((a, b) => unassignedOrthoCount(a).compareTo(unassignedOrthoCount(b)));
        final pick = frontier.first;
        regMap[pick] = regId;
        cells.add(pick);
      }
      cellsByReg.add(cells);
    }

    // Merge any tiny region (size 1 or 2) into an adjacent region if combined size <= 5
    var merged = true;
    while (merged) {
      merged = false;
      for (var rId = 0; rId < cellsByReg.length; rId++) {
        final cells = cellsByReg[rId];
        if (cells.isEmpty || cells.length > 2) continue;
        final neighborRegs = <int>[];
        for (final idx in cells) {
          final r = idx ~/ size, c = idx % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nReg = regMap[nr * size + nc];
            if (nReg != rId &&
                cellsByReg[nReg].isNotEmpty &&
                cellsByReg[nReg].length + cells.length <= 5 &&
                !neighborRegs.contains(nReg)) {
              neighborRegs.add(nReg);
            }
          }
        }
        if (neighborRegs.isNotEmpty) {
          final targetReg = neighborRegs[rng.nextInt(neighborRegs.length)];
          for (final idx in cells) {
            regMap[idx] = targetReg;
            cellsByReg[targetReg].add(idx);
          }
          cells.clear();
          merged = true;
        }
      }
    }

    // Compact region IDs to 0..numRegions-1
    final finalRegs = <SuguruRegion>[];
    final compactMap = List<int>.filled(n, 0);
    for (final cells in cellsByReg) {
      if (cells.isEmpty) continue;
      cells.sort();
      final newId = finalRegs.length;
      for (final idx in cells) {
        compactMap[idx] = newId;
      }
      finalRegs.add(SuguruRegion(id: newId, cells: cells));
    }

    return (compactMap, finalRegs);
  }

  /// Solves a Suguru region partition using MRV backtracking + forward checking.
  static List<int>? _solvePartition(
    int size,
    List<int> regMap,
    List<SuguruRegion> regList,
    Random rng, {
    int maxNodes = 2500,
  }) {
    final n = size * size;
    final board = List<int>.filled(n, 0);
    final adj8 = List<List<int>>.generate(n, (idx) {
      final r = idx ~/ size, c = idx % size;
      final list = <int>[];
      for (var d = 0; d < 8; d++) {
        final nr = r + adj8Dr[d], nc = c + adj8Dc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          list.add(nr * size + nc);
        }
      }
      return list;
    });

    int allowedMask(int idx) {
      final reg = regList[regMap[idx]];
      var mask = (1 << reg.size) - 1;
      for (final other in reg.cells) {
        final v = board[other];
        if (v > 0) mask &= ~(1 << (v - 1));
      }
      for (final nb in adj8[idx]) {
        final v = board[nb];
        if (v > 0) mask &= ~(1 << (v - 1));
      }
      return mask;
    }

    int popCount(int m) {
      var x = m, c = 0;
      while (x != 0) {
        x &= x - 1;
        c++;
      }
      return c;
    }

    var nodes = 0;

    bool dfs(int filled) {
      if (filled == n) return true;
      if (++nodes > maxNodes) return false;

      var bestIdx = -1;
      var bestMask = 0;
      var bestCount = 99;

      for (var i = 0; i < n; i++) {
        if (board[i] != 0) continue;
        final m = allowedMask(i);
        if (m == 0) return false;
        final cnt = popCount(m);
        if (cnt < bestCount) {
          bestCount = cnt;
          bestIdx = i;
          bestMask = m;
          if (cnt == 1) break;
        }
      }

      // Verify every region still has a valid cell for each unplaced digit 1..K
      for (final reg in regList) {
        var placedMask = 0;
        var unionAvail = 0;
        for (final idx in reg.cells) {
          final v = board[idx];
          if (v > 0) {
            placedMask |= 1 << (v - 1);
          } else {
            unionAvail |= allowedMask(idx);
          }
        }
        final fullMask = (1 << reg.size) - 1;
        if ((placedMask | unionAvail) != fullMask) return false;
      }

      final digits = <int>[
        for (var d = 1; d <= 5; d++)
          if ((bestMask & (1 << (d - 1))) != 0) d,
      ];
      if (digits.length > 1) digits.shuffle(rng);

      for (final d in digits) {
        board[bestIdx] = d;
        if (dfs(filled + 1)) return true;
        board[bestIdx] = 0;
        if (nodes > maxNodes) return false;
      }
      return false;
    }

    return dfs(0) ? board : null;
  }

  /// Generates a guaranteed-valid Suguru puzzle for [size] (`5` or `6`).
  static SuguruPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    List<int>? regMap;
    List<SuguruRegion>? regList;
    List<int>? sol;

    for (var attempt = 0; attempt < 60; attempt++) {
      final (rm, rl) = _partitionGrid(size, rng);
      final s = _solvePartition(size, rm, rl, rng);
      if (s != null) {
        regMap = rm;
        regList = rl;
        sol = s;
        break;
      }
    }

    // Deterministic fallback partition if needed
    if (sol == null || regMap == null || regList == null) {
      if (size == 5) {
        regMap = [
          0, 0, 0, 1, 1,
          0, 0, 2, 1, 1,
          3, 2, 2, 2, 1,
          3, 3, 2, 4, 4,
          3, 3, 4, 4, 4,
        ];
        sol = [
          1, 2, 5, 1, 2,
          3, 4, 3, 4, 3,
          1, 5, 1, 2, 5,
          2, 4, 4, 3, 1,
          3, 5, 1, 2, 4,
        ];
      } else {
        regMap = [
          0, 0, 0, 1, 1, 1,
          0, 0, 2, 2, 1, 1,
          3, 3, 2, 2, 4, 4,
          3, 3, 2, 5, 4, 4,
          3, 6, 6, 5, 5, 4,
          7, 6, 6, 5, 5, 7,
        ];
        // Rebuild region list & solve
      }
      final byId = <int, List<int>>{};
      for (var i = 0; i < n; i++) {
        byId.putIfAbsent(regMap[i], () => <int>[]).add(i);
      }
      regList = [
        for (var id = 0; id < byId.length; id++)
          SuguruRegion(id: id, cells: byId[id]!..sort()),
      ];
      sol ??= _solvePartition(size, regMap, regList, rng, maxNodes: 20000)!;
    }

    final regions2D = [
      for (var r = 0; r < size; r++)
        [for (var c = 0; c < size; c++) regMap[r * size + c]],
    ];

    // Expose 1 clue per region of size >= 2 (so plenty of cells remain empty)
    final clues = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    for (final reg in regList) {
      if (reg.size >= 2) {
        final pick = reg.cells[rng.nextInt(reg.cells.length)];
        clues[pick ~/ size][pick % size] = sol[pick];
      }
    }

    return SuguruPuzzle(
      size: size,
      regions: regions2D,
      regionMap: regMap,
      regionList: regList,
      clues: clues,
      solutionBoard: sol,
    );
  }
}

/// 数块邻格互斥竞速 (Suguru Race, 1-6 人).
class SuguruGame extends GameEngine {
  SuguruGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late SuguruPuzzle currentPuzzle;
  late List<SuguruPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a11Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 250, _ => 450 };

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

    currentPuzzle = SuguruSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) SuguruPlayer(currentPuzzle.cluesFlat)];

    host.log('数块邻格互斥竞速开始（$size×$size 网格，共 $totalRounds 题）！填入 1～K 填满各数块且八方向邻格严禁同数！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = SuguruSolver.generatePuzzle(size, rng);
    }
    final cluesFlat = currentPuzzle.cluesFlat;
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(cluesFlat);
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
    return a11Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'set':
      case 'toggle':
        final (r, c) = _resolveCell(a);
        if (currentPuzzle.clues[r][c] > 0) {
          throw GameError('题目固定数字不可修改');
        }
        final idx = r * size + c;
        final regId = currentPuzzle.regionMap[idx];
        final regSize = currentPuzzle.regionList[regId].size.clamp(1, 5);
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 5) {
            throw GameError('数字必须在 0～5 之间');
          }
          p.board[idx] = v;
        } else {
          p.board[idx] = (p.board[idx] + 1) % (regSize + 1);
        }
        moves++;
        if (SuguruSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        final cluesFlat = currentPuzzle.cluesFlat;
        for (var i = 0; i < p.board.length; i++) {
          p.board[i] = cluesFlat[i];
        }
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
    host.log('${name(seat)} 第 $roundSolvers 个解出数块谜题，+$pts 分！');
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
    ranking = a11Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a11Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentPuzzle.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if (p.board[i] != sol[i]) i,
    ];
    if (diff.isNotEmpty) {
      final pick = diff[rng.nextInt(diff.length)];
      return {
        'type': 'set',
        'r': pick ~/ size,
        'c': pick % size,
        'val': sol[pick],
      };
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myBoard = me?.board ?? puz.cluesFlat;
    final an = SuguruSolver.analyze(puz, myBoard);
    final totalCells = size * size;
    final totalRegions = puz.regionList.length;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'regions': puz.regions,
      'regionMap': puz.regionMap,
      'regionList': [for (final reg in puz.regionList) reg.toJson()],
      'clues': puz.clues,
      'cluesFlat': puz.cluesFlat,
      'board': myBoard,
      'regionDuplicates': an.regionDuplicateCells.toList()..sort(),
      'adjacentTouches': an.adjacentTouchCells.toList()..sort(),
      'satisfiedRegions': an.satisfiedRegions.toList()..sort(),
      'violatedRegions': an.violatedRegions.toList()..sort(),
      'satisfiedRegionCount': an.satisfiedRegions.length,
      'totalRegions': totalRegions,
      'filledCount': an.filledCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = SuguruSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'filled': pAn.filledCount,
              'totalCells': totalCells,
              'satisfiedRegions': pAn.satisfiedRegions.length,
              'totalRegions': totalRegions,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class SuguruPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  SuguruPlayer(List<int> initialClues) : board = List<int>.of(initialClues);

  void resetForRound(List<int> initialClues) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.of(initialClues);
  }
}
