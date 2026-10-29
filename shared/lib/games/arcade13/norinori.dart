import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a13_util.dart';

class NorinoriPuzzle {
  final int size;
  /// `size × size` grid of Region IDs `0..regionCount-1`.
  final List<List<int>> regions;
  /// Metadata for each Region `0..regionCount-1`: `{'id', 'cells', 'anchor', 'size'}`.
  final List<Map<String, dynamic>> regionList;
  /// Flat `size * size` solution (`0` = White, `1` = Black `■`).
  final List<int> solutionBoard;

  const NorinoriPuzzle({
    required this.size,
    required this.regions,
    required this.regionList,
    required this.solutionBoard,
  });

  int get regionCount => regionList.length;

  List<int> get regionMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) regions[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class NorinoriAnalysis {
  final Set<int> satisfiedRegions;
  final Set<int> violatedRegions;
  final List<int> regionBlackCounts;
  final Set<int> validDominoCells;
  final Set<int> isolatedBlackCells;
  final Set<int> crowdedBlackCells;
  final int blackCount;
  final int dotCount;
  final int totalRegions;

  const NorinoriAnalysis({
    required this.satisfiedRegions,
    required this.violatedRegions,
    required this.regionBlackCounts,
    required this.validDominoCells,
    required this.isolatedBlackCells,
    required this.crowdedBlackCells,
    required this.blackCount,
    required this.dotCount,
    required this.totalRegions,
  });

  Set<int> get conflictCells => {
        ...isolatedBlackCells,
        ...crowdedBlackCells,
      };

  bool get isSolved =>
      totalRegions > 0 &&
      satisfiedRegions.length == totalRegions &&
      violatedRegions.isEmpty &&
      isolatedBlackCells.isEmpty &&
      crowdedBlackCells.isEmpty &&
      blackCount == totalRegions * 2 &&
      validDominoCells.length == blackCount;
}

class NorinoriSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  static NorinoriAnalysis analyze(NorinoriPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final rCount = puz.regionCount;

    final satisfiedRegions = <int>{};
    final violatedRegions = <int>{};
    final regionBlackCounts = List<int>.filled(rCount, 0);
    final validDominoCells = <int>{};
    final isolatedBlackCells = <int>{};
    final crowdedBlackCells = <int>{};

    var blackCount = 0;
    var dotCount = 0;

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
        final regId = puz.regions[i ~/ size][i % size];
        if (regId >= 0 && regId < rCount) {
          regionBlackCounts[regId]++;
        }
      } else if (v == 2) {
        dotCount++;
      }
    }

    // 1. Check each Region for EXACTLY 2 Black cells
    for (var regId = 0; regId < rCount; regId++) {
      final cnt = regionBlackCounts[regId];
      if (cnt == 2) {
        satisfiedRegions.add(regId);
      } else if (cnt > 2) {
        violatedRegions.add(regId);
      }
    }

    // 2. Check orthogonal Black neighbors of every Black cell (must be EXACTLY 1)
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (!isBlack(board, idx)) continue;
        final blackNbs = <int>[];
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (isBlack(board, nIdx)) {
            blackNbs.add(nIdx);
          }
        }
        if (blackNbs.isEmpty) {
          isolatedBlackCells.add(idx);
        } else if (blackNbs.length > 1) {
          crowdedBlackCells.add(idx);
          crowdedBlackCells.addAll(blackNbs);
        } else {
          validDominoCells.add(idx);
        }
      }
    }

    // Any cell in crowdedBlackCells is not a valid isolated 1x2 domino cell
    validDominoCells.removeAll(crowdedBlackCells);

    return NorinoriAnalysis(
      satisfiedRegions: satisfiedRegions,
      violatedRegions: violatedRegions,
      regionBlackCounts: regionBlackCounts,
      validDominoCells: validDominoCells,
      isolatedBlackCells: isolatedBlackCells,
      crowdedBlackCells: crowdedBlackCells,
      blackCount: blackCount,
      dotCount: dotCount,
      totalRegions: rCount,
    );
  }

  static bool isSolved(NorinoriPuzzle puz, List<int> board) {
    final n = puz.size * puz.size;
    if (board.length != n) return false;
    return analyze(puz, board).isSolved;
  }

  static bool _canPlaceDomino(int size, List<int> sol, int r1, int c1, int r2, int c2) {
    if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size) return false;
    if (r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) return false;
    final i1 = r1 * size + c1;
    final i2 = r2 * size + c2;
    if (sol[i1] != 0 || sol[i2] != 0) return false;

    for (final (r, c) in [(r1, c1), (r2, c2)]) {
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (nIdx != i1 && nIdx != i2 && sol[nIdx] == 1) {
          return false;
        }
      }
    }
    return true;
  }

  /// Generates a guaranteed-valid Norinori puzzle for [size] (`5` or `6`).
  static NorinoriPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final sol = List<int>.filled(n, 0);
    final regMap = List<int>.filled(n, -1);
    var regionCount = 0;

    // 1. Place one 3x2 or 2x3 cross-boundary domino pair so at least two regions
    // have their 2 Black cells paired across a region border!
    final horizontalBlock = rng.nextBool();
    if (horizontalBlock) {
      // 3 rows x 2 cols block: top & bottom rows are 1x2 dominoes, middle row is White;
      // left column is Region 0, right column is Region 1.
      final r0 = rng.nextInt(size - 2);
      final c0 = rng.nextInt(size - 1);
      sol[r0 * size + c0] = 1;
      sol[r0 * size + c0 + 1] = 1;
      sol[(r0 + 2) * size + c0] = 1;
      sol[(r0 + 2) * size + c0 + 1] = 1;
      for (var dr = 0; dr < 3; dr++) {
        regMap[(r0 + dr) * size + c0] = 0;
        regMap[(r0 + dr) * size + c0 + 1] = 1;
      }
      regionCount = 2;
    } else {
      // 2 rows x 3 cols block: left & right cols are 2x1 dominoes, middle col is White;
      // top row is Region 0, bottom row is Region 1.
      final r0 = rng.nextInt(size - 1);
      final c0 = rng.nextInt(size - 2);
      sol[r0 * size + c0] = 1;
      sol[(r0 + 1) * size + c0] = 1;
      sol[r0 * size + c0 + 2] = 1;
      sol[(r0 + 1) * size + c0 + 2] = 1;
      for (var dc = 0; dc < 3; dc++) {
        regMap[r0 * size + c0 + dc] = 0;
        regMap[(r0 + 1) * size + c0 + dc] = 1;
      }
      regionCount = 2;
    }

    // 2. Place additional non-touching 1x2 / 2x1 Black Dominoes in unassigned space
    final candidateDominoes = <(int, int, int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (c + 1 < size) candidateDominoes.add((r, c, r, c + 1));
        if (r + 1 < size) candidateDominoes.add((r, c, r + 1, c));
      }
    }
    candidateDominoes.shuffle(rng);

    final targetRegions = size <= 5 ? 5 : 6;
    for (final (r1, c1, r2, c2) in candidateDominoes) {
      if (regionCount >= targetRegions) break;
      final i1 = r1 * size + c1, i2 = r2 * size + c2;
      if (regMap[i1] != -1 || regMap[i2] != -1) continue;
      if (!_canPlaceDomino(size, sol, r1, c1, r2, c2)) continue;
      sol[i1] = 1;
      sol[i2] = 1;
      regMap[i1] = regionCount;
      regMap[i2] = regionCount;
      regionCount++;
    }

    // 3. Grow all Region cores 0..regionCount-1 into remaining White cells
    final regSizes = List<int>.filled(regionCount, 0);
    for (var i = 0; i < n; i++) {
      if (regMap[i] >= 0) regSizes[regMap[i]]++;
    }

    while (regMap.any((r) => r == -1)) {
      final frontier = <(int, int)>[];
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final idx = r * size + c;
          if (regMap[idx] != -1) continue;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nReg = regMap[nr * size + nc];
            if (nReg != -1) {
              frontier.add((idx, nReg));
            }
          }
        }
      }
      if (frontier.isEmpty) break;
      frontier.shuffle(rng);
      frontier.sort((a, b) => regSizes[a.$2].compareTo(regSizes[b.$2]));
      final (pickCell, pickReg) = frontier.first;
      regMap[pickCell] = pickReg;
      regSizes[pickReg]++;
    }

    // Build regions grid and regionList metadata
    final regions = [
      for (var r = 0; r < size; r++)
        [for (var c = 0; c < size; c++) regMap[r * size + c]],
    ];

    final cellsByReg = List<List<int>>.generate(regionCount, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      cellsByReg[regMap[i]].add(i);
    }

    final regionList = <Map<String, dynamic>>[
      for (var regId = 0; regId < regionCount; regId++)
        {
          'id': regId,
          'cells': cellsByReg[regId],
          'anchor': cellsByReg[regId].first,
          'size': cellsByReg[regId].length,
        },
    ];

    // Sanity check connectivity of each region
    assert(() {
      for (var regId = 0; regId < regionCount; regId++) {
        final cells = cellsByReg[regId].toSet();
        final q = Queue<int>()..add(cells.first);
        final vis = <int>{cells.first};
        while (q.isNotEmpty) {
          final cur = q.removeFirst();
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final nxt = nr * size + nc;
              if (cells.contains(nxt) && vis.add(nxt)) q.add(nxt);
            }
          }
        }
        if (vis.length != cells.length) return false;
      }
      return true;
    }());

    return NorinoriPuzzle(
      size: size,
      regions: regions,
      regionList: regionList,
      solutionBoard: sol,
    );
  }
}

/// 多米诺双格竞速 (Norinori Race, 1-6 人).
class NorinoriGame extends GameEngine {
  NorinoriGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late NorinoriPuzzle currentPuzzle;
  late List<NorinoriPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a13Placings(ranking, players) : null;

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

    currentPuzzle = NorinoriSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) NorinoriPlayer(size * size)];

    host.log('多米诺双格竞速开始（$size×$size 网格，共 $totalRounds 题）！每个区域涂黑恰好 2 格且所有黑格两两配成 1×2 多米诺！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = NorinoriSolver.generatePuzzle(size, rng);
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
    return a13Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'toggle':
      case 'set':
      case 'shade':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else if (type == 'shade') {
          p.board[idx] = p.board[idx] == 1 ? 0 : 1;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (NorinoriSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出多米诺双格谜题，+$pts 分！');
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
    ranking = a13Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a13Winners(ranking!, name)}');
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
        if ((p.board[i] == 1) != (sol[i] == 1)) i,
    ];
    if (diff.isNotEmpty) {
      final pick = diff[rng.nextInt(diff.length)];
      return {
        'type': 'toggle',
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
    final an = NorinoriSolver.analyze(puz, myBoard);
    final totalCells = size * size;
    final totalRegions = puz.regionCount;

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
      'regionList': puz.regionList,
      'totalRegions': totalRegions,
      'board': myBoard,
      'regionBlackCounts': an.regionBlackCounts,
      'satisfiedRegions': an.satisfiedRegions.toList()..sort(),
      'violatedRegions': an.violatedRegions.toList()..sort(),
      'validDominoCells': an.validDominoCells.toList()..sort(),
      'isolatedBlackCells': an.isolatedBlackCells.toList()..sort(),
      'crowdedBlackCells': an.crowdedBlackCells.toList()..sort(),
      'satisfiedRegionCount': an.satisfiedRegions.length,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = NorinoriSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedRegions': pAn.satisfiedRegions.length,
              'totalRegions': totalRegions,
              'blackCount': pAn.blackCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class NorinoriPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  NorinoriPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
