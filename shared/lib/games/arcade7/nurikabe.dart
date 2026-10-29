import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a7_util.dart';

class NurikabePuzzle {
  final int size;
  /// `0`: non-clue cell, `>0`: numbered island clue cell.
  final List<int> clues;
  /// Indices (`0..size*size-1`) of Black Sea cells (`1`) in a valid solution.
  final Set<int> solutionSea;

  const NurikabePuzzle({
    required this.size,
    required this.clues,
    required this.solutionSea,
  });
}

class NurikabeAnalysis {
  final Set<int> twoByTwoCells;
  final int seaCount;
  final int seaComponents;
  final bool seaConnected;
  final Map<int, int> clueIslandSize;
  final Map<int, bool> clueOk;
  final int orphanIslands;
  final int multiClueIslands;
  final int okClues;
  final int totalClues;

  const NurikabeAnalysis({
    required this.twoByTwoCells,
    required this.seaCount,
    required this.seaComponents,
    required this.seaConnected,
    required this.clueIslandSize,
    required this.clueOk,
    required this.orphanIslands,
    required this.multiClueIslands,
    required this.okClues,
    required this.totalClues,
  });

  bool get isSolved =>
      twoByTwoCells.isEmpty &&
      seaConnected &&
      orphanIslands == 0 &&
      multiClueIslands == 0 &&
      totalClues > 0 &&
      okClues == totalClues;
}

class NurikabeSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static bool isSeaCell(List<int> clues, List<int> board, int idx) =>
      clues[idx] == 0 && board[idx] == 1;

  /// Finds all cell indices belonging to any `2×2` block of Black Sea cells.
  static Set<int> findTwoByTwoSeaCells(List<int> clues, List<int> board, int size) {
    final bad = <int>{};
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        final i00 = r * size + c;
        final i01 = r * size + (c + 1);
        final i10 = (r + 1) * size + c;
        final i11 = (r + 1) * size + (c + 1);
        if (isSeaCell(clues, board, i00) &&
            isSeaCell(clues, board, i01) &&
            isSeaCell(clues, board, i10) &&
            isSeaCell(clues, board, i11)) {
          bad.add(i00);
          bad.add(i01);
          bad.add(i10);
          bad.add(i11);
        }
      }
    }
    return bad;
  }

  /// Performs full Nurikabe rule analysis on [clues] and [board].
  static NurikabeAnalysis analyze(List<int> clues, List<int> board, int size) {
    final n = size * size;
    final twoByTwo = findTwoByTwoSeaCells(clues, board, size);

    // 1. Analyze Black Sea connectivity
    var seaCount = 0;
    var seaComponents = 0;
    final visitedSea = List<bool>.filled(n, false);
    for (var i = 0; i < n; i++) {
      if (isSeaCell(clues, board, i)) {
        seaCount++;
        if (!visitedSea[i]) {
          seaComponents++;
          final q = Queue<int>()..add(i);
          visitedSea[i] = true;
          while (q.isNotEmpty) {
            final cur = q.removeFirst();
            final r = cur ~/ size, c = cur % size;
            for (var d = 0; d < 4; d++) {
              final nr = r + dr[d], nc = c + dc[d];
              if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
              final nIdx = nr * size + nc;
              if (!visitedSea[nIdx] && isSeaCell(clues, board, nIdx)) {
                visitedSea[nIdx] = true;
                q.add(nIdx);
              }
            }
          }
        }
      }
    }

    // 2. Analyze White Islands (all non-sea cells: clues[i] > 0 or board[i] != 1)
    final visitedWhite = List<bool>.filled(n, false);
    final clueIslandSize = <int, int>{};
    final clueOk = <int, bool>{};
    var orphanIslands = 0;
    var multiClueIslands = 0;
    var okClues = 0;
    var totalClues = 0;

    for (var i = 0; i < n; i++) {
      if (clues[i] > 0) totalClues++;
      if (!isSeaCell(clues, board, i) && !visitedWhite[i]) {
        final comp = <int>[];
        final compClues = <int>[];
        final q = Queue<int>()..add(i);
        visitedWhite[i] = true;
        while (q.isNotEmpty) {
          final cur = q.removeFirst();
          comp.add(cur);
          if (clues[cur] > 0) compClues.add(cur);
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + dr[d], nc = c + dc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nIdx = nr * size + nc;
            if (!visitedWhite[nIdx] && !isSeaCell(clues, board, nIdx)) {
              visitedWhite[nIdx] = true;
              q.add(nIdx);
            }
          }
        }

        if (compClues.isEmpty) {
          orphanIslands++;
        } else if (compClues.length == 1) {
          final cIdx = compClues.first;
          clueIslandSize[cIdx] = comp.length;
          final ok = comp.length == clues[cIdx];
          clueOk[cIdx] = ok;
          if (ok) okClues++;
        } else {
          multiClueIslands++;
          for (final cIdx in compClues) {
            clueIslandSize[cIdx] = comp.length;
            clueOk[cIdx] = false;
          }
        }
      }
    }

    return NurikabeAnalysis(
      twoByTwoCells: twoByTwo,
      seaCount: seaCount,
      seaComponents: seaComponents,
      seaConnected: seaCount > 0 && seaComponents == 1,
      clueIslandSize: clueIslandSize,
      clueOk: clueOk,
      orphanIslands: orphanIslands,
      multiClueIslands: multiClueIslands,
      okClues: okClues,
      totalClues: totalClues,
    );
  }

  /// Returns true if [board] satisfies all 3 Nurikabe rules for [clues]:
  /// 1. No `2×2` block of Black Sea cells (`1`),
  /// 2. All Black Sea cells (`1`) form a single orthogonally connected component,
  /// 3. Each orthogonally connected component of White cells contains exactly ONE
  ///    clue cell and has cell count equal to that clue number.
  static bool isSolved(List<int> clues, List<int> board, int size) {
    final n = size * size;
    if (clues.length != n || board.length != n) return false;
    for (var i = 0; i < n; i++) {
      if (clues[i] > 0 && board[i] == 1) return false;
    }
    return analyze(clues, board, size).isSolved;
  }

  static bool _wouldCreate2x2(List<int> sea, int size, int r, int c) {
    bool at(int rr, int cc) =>
        (rr == r && cc == c) ||
        (rr >= 0 && rr < size && cc >= 0 && cc < size && sea[rr * size + cc] == 1);

    for (var dr0 = -1; dr0 <= 0; dr0++) {
      for (var dc0 = -1; dc0 <= 0; dc0++) {
        final r0 = r + dr0, c0 = c + dc0;
        if (r0 >= 0 && r0 + 1 < size && c0 >= 0 && c0 + 1 < size) {
          if (at(r0, c0) && at(r0, c0 + 1) && at(r0 + 1, c0) && at(r0 + 1, c0 + 1)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static List<List<int>> _whiteComponents(List<int> sea, int size) {
    final n = size * size;
    final vis = List<bool>.filled(n, false);
    final comps = <List<int>>[];
    for (var i = 0; i < n; i++) {
      if (sea[i] == 0 && !vis[i]) {
        final comp = <int>[];
        final q = Queue<int>()..add(i);
        vis[i] = true;
        while (q.isNotEmpty) {
          final cur = q.removeFirst();
          comp.add(cur);
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + dr[d], nc = c + dc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final nIdx = nr * size + nc;
              if (sea[nIdx] == 0 && !vis[nIdx]) {
                vis[nIdx] = true;
                q.add(nIdx);
              }
            }
          }
        }
        comps.add(comp);
      }
    }
    return comps;
  }

  /// Generates a 100% guaranteed-valid Nurikabe puzzle for [size] (`5` or `7`).
  static NurikabePuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final maxIslandSize = size <= 5 ? 5 : 6;
    final minIslands = size <= 5 ? 3 : 5;
    final targetSeaMin = (n * 0.48).round();

    for (var attempt = 0; attempt < 30; attempt++) {
      final sea = List<int>.filled(n, 0);
      final startIdx = rng.nextInt(n);
      sea[startIdx] = 1;
      var seaCount = 1;

      while (true) {
        final comps = _whiteComponents(sea, size);
        final maxComp = comps.isEmpty ? 0 : comps.map((c) => c.length).reduce(max);
        if (seaCount >= targetSeaMin && maxComp <= maxIslandSize && comps.length >= minIslands) {
          break;
        }

        // Find all white cells adjacent to the current sea that don't create a 2x2 sea block
        final oversizedCells = <int>{
          for (final comp in comps)
            if (comp.length > maxIslandSize) ...comp,
        };

        final candidates = <int>[];
        final priority = <int>[];
        for (var i = 0; i < n; i++) {
          if (sea[i] != 0) continue;
          final r = i ~/ size, c = i % size;
          var adjSea = false;
          for (var d = 0; d < 4; d++) {
            final nr = r + dr[d], nc = c + dc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size && sea[nr * size + nc] == 1) {
              adjSea = true;
              break;
            }
          }
          if (!adjSea) continue;
          if (_wouldCreate2x2(sea, size, r, c)) continue;
          candidates.add(i);
          if (oversizedCells.contains(i)) {
            priority.add(i);
          }
        }

        if (candidates.isEmpty) break;
        final pool = priority.isNotEmpty ? priority : candidates;
        final pick = pool[rng.nextInt(pool.length)];
        sea[pick] = 1;
        seaCount++;
      }

      final comps = _whiteComponents(sea, size);
      final maxComp = comps.isEmpty ? 99 : comps.map((c) => c.length).reduce(max);
      if (comps.length >= minIslands && maxComp <= maxIslandSize) {
        final clues = List<int>.filled(n, 0);
        for (final comp in comps) {
          final clueCell = comp[rng.nextInt(comp.length)];
          clues[clueCell] = comp.length;
        }
        final solSea = <int>{
          for (var i = 0; i < n; i++)
            if (sea[i] == 1) i,
        };
        if (isSolved(clues, sea, size)) {
          return NurikabePuzzle(size: size, clues: clues, solutionSea: solSea);
        }
      }
    }

    // Guaranteed symmetric template fallback with random D4 transform
    final baseSea = size <= 5
        ? const [
            0, 1, 0, 0, 1,
            1, 1, 1, 0, 1,
            0, 0, 1, 1, 1,
            1, 1, 1, 0, 0,
            0, 0, 1, 0, 0,
          ]
        : const [
            0, 1, 0, 0, 1, 0, 0,
            1, 1, 1, 0, 1, 1, 0,
            0, 0, 1, 1, 0, 1, 1,
            1, 1, 1, 0, 0, 0, 1,
            0, 0, 1, 1, 1, 1, 1,
            0, 1, 1, 0, 1, 0, 0,
            0, 1, 0, 0, 1, 1, 0,
          ];
    final sym = rng.nextInt(8);
    final sea = List<int>.filled(n, 0);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final (tr, tc) = _transformCoord(r, c, size, sym);
        sea[tr * size + tc] = baseSea[r * size + c];
      }
    }
    final comps = _whiteComponents(sea, size);
    final clues = List<int>.filled(n, 0);
    for (final comp in comps) {
      final clueCell = comp[rng.nextInt(comp.length)];
      clues[clueCell] = comp.length;
    }
    final solSea = <int>{
      for (var i = 0; i < n; i++)
        if (sea[i] == 1) i,
    };
    return NurikabePuzzle(size: size, clues: clues, solutionSea: solSea);
  }

  static (int, int) _transformCoord(int r, int c, int size, int sym) {
    var rr = r, cc = c;
    if ((sym & 4) != 0) cc = size - 1 - cc;
    return switch (sym & 3) {
      1 => (cc, size - 1 - rr),
      2 => (size - 1 - rr, size - 1 - cc),
      3 => (size - 1 - cc, rr),
      _ => (rr, cc),
    };
  }
}

/// 数墙竞速 (Nurikabe Race, 1-6 人).
class NurikabeGame extends GameEngine {
  NurikabeGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late NurikabePuzzle currentPuzzle;
  late List<NurikabePlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a7Placings(ranking, players) : null;

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
    size = rawSize == 7 ? 7 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = NurikabeSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) NurikabePlayer(size * size)];

    host.log('数墙竞速开始（$size×$size 网格，共 $totalRounds 题）！划分连通黑海与定量白岛且避免 2×2 黑块即可过关！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = NurikabeSolver.generatePuzzle(size, rng);
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
    return a7Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveModifiableCellIndex(Map<String, dynamic> a) {
    int idx;
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      idx = r * size + c;
    } else {
      idx = asInt(a['i']);
      if (idx < 0 || idx >= size * size) {
        throw GameError('格子索引超出棋盘范围');
      }
    }
    if (currentPuzzle.clues[idx] > 0) {
      throw GameError('数字线索格固定为白色岛屿，不能涂黑或修改');
    }
    return idx;
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
        final idx = _resolveModifiableCellIndex(a);
        final val = asInt(a['val']);
        if (val < 0 || val > 2) {
          throw GameError('单元格状态值必须为 0、1 或 2');
        }
        p.board[idx] = val;
        moves++;
        if (NurikabeSolver.isSolved(currentPuzzle.clues, p.board, size)) {
          _markSolved(seat);
        }

      case 'toggle':
        final idx = _resolveModifiableCellIndex(a);
        final cur = p.board[idx];
        if (a.containsKey('mode')) {
          final mode = asInt(a['mode'], 1) == 2 ? 2 : 1;
          p.board[idx] = cur == mode ? 0 : mode;
        } else {
          p.board[idx] = (cur + 1) % 3;
        }
        moves++;
        if (NurikabeSolver.isSolved(currentPuzzle.clues, p.board, size)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个完成数墙划分，+$pts 分！');
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
    ranking = a7Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a7Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final solSea = currentPuzzle.solutionSea;

    final anyMarked = p.board.any((v) => v != 0);
    if (botLevel <= 0 && !anyMarked && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First clear any wrongly placed sea cell
    for (var i = 0; i < p.board.length; i++) {
      if (p.board[i] == 1 && !solSea.contains(i)) {
        return {'type': 'set', 'r': i ~/ size, 'c': i % size, 'val': 2};
      }
    }

    // Place a missing solution sea cell
    final missing = <int>[
      for (final idx in solSea)
        if (p.board[idx] != 1) idx,
    ];
    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'set', 'r': pick ~/ size, 'c': pick % size, 'val': 1};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final clues = currentPuzzle.clues;
    final myBoard = me?.board ?? List<int>.filled(size * size, 0);
    final analysis = NurikabeSolver.analyze(clues, myBoard, size);

    final clueOkList = <bool>[];
    final clueIslandSizes = <int>[];
    for (var i = 0; i < clues.length; i++) {
      if (clues[i] > 0) {
        clueOkList.add(analysis.clueOk[i] ?? false);
        clueIslandSizes.add(analysis.clueIslandSize[i] ?? 0);
      } else {
        clueOkList.add(true);
        clueIslandSizes.add(0);
      }
    }

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': clues,
      'board': myBoard,
      'twoByTwo': analysis.twoByTwoCells.toList()..sort(),
      'seaCount': analysis.seaCount,
      'seaComponents': analysis.seaComponents,
      'seaConnected': analysis.seaConnected,
      'clueOk': clueOkList,
      'clueIslandSizes': clueIslandSizes,
      'orphanIslands': analysis.orphanIslands,
      'multiClueIslands': analysis.multiClueIslands,
      'okClues': analysis.okClues,
      'totalClues': max(1, analysis.totalClues),
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = NurikabeSolver.analyze(clues, ps[s].board, size);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'okClues': pAn.okClues,
              'totalClues': max(1, pAn.totalClues),
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class NurikabePlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  NurikabePlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
