import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a9_util.dart';

class HitoriPuzzle {
  final int size;
  /// Flat `size * size` grid of numbers `1..size`.
  final List<int> grid;
  /// Valid shading solution (`0` unshaded, `1` shaded black).
  final List<int> solutionMask;

  const HitoriPuzzle({
    required this.size,
    required this.grid,
    required this.solutionMask,
  });

  List<List<int>> get numbers => [
        for (var r = 0; r < size; r++)
          [for (var c = 0; c < size; c++) grid[r * size + c]],
      ];
}

class HitoriAnalysis {
  final Set<int> duplicateCells;
  final Set<int> adjacentBlackCells;
  final Set<int> disconnectedWhiteCells;
  final bool whiteConnected;
  final int cleanRows;
  final int cleanCols;
  final int unshadedCount;
  final int shadedCount;

  const HitoriAnalysis({
    required this.duplicateCells,
    required this.adjacentBlackCells,
    required this.disconnectedWhiteCells,
    required this.whiteConnected,
    required this.cleanRows,
    required this.cleanCols,
    required this.unshadedCount,
    required this.shadedCount,
  });

  int get cleanLines => cleanRows + cleanCols;

  bool get isSolved =>
      unshadedCount > 0 &&
      duplicateCells.isEmpty &&
      adjacentBlackCells.isEmpty &&
      whiteConnected;
}

class HitoriSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static HitoriAnalysis analyze(HitoriPuzzle puz, List<int> marks) {
    final size = puz.size;
    final n = size * size;
    final duplicateCells = <int>{};
    final adjacentBlackCells = <int>{};

    var cleanRows = 0;
    for (var r = 0; r < size; r++) {
      final seen = <int, int>{};
      var rowClean = true;
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final m = idx < marks.length ? marks[idx] : 0;
        if (m == 1) continue; // shaded black
        final numVal = puz.grid[idx];
        if (seen.containsKey(numVal)) {
          rowClean = false;
          duplicateCells.add(idx);
          duplicateCells.add(seen[numVal]!);
        } else {
          seen[numVal] = idx;
        }
      }
      if (rowClean) cleanRows++;
    }

    var cleanCols = 0;
    for (var c = 0; c < size; c++) {
      final seen = <int, int>{};
      var colClean = true;
      for (var r = 0; r < size; r++) {
        final idx = r * size + c;
        final m = idx < marks.length ? marks[idx] : 0;
        if (m == 1) continue; // shaded black
        final numVal = puz.grid[idx];
        if (seen.containsKey(numVal)) {
          colClean = false;
          duplicateCells.add(idx);
          duplicateCells.add(seen[numVal]!);
        } else {
          seen[numVal] = idx;
        }
      }
      if (colClean) cleanCols++;
    }

    var unshadedCount = 0;
    var shadedCount = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final m = idx < marks.length ? marks[idx] : 0;
        if (m == 1) {
          shadedCount++;
          for (var d = 0; d < 4; d++) {
            final nr = r + dr[d], nc = c + dc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nIdx = nr * size + nc;
            final nm = nIdx < marks.length ? marks[nIdx] : 0;
            if (nm == 1) {
              adjacentBlackCells.add(idx);
              adjacentBlackCells.add(nIdx);
            }
          }
        } else {
          unshadedCount++;
        }
      }
    }

    // Find connected components of unshaded (!= 1) cells
    final visited = List<bool>.filled(n, false);
    List<int> largestComp = const [];
    final allUnshaded = <int>[];

    for (var i = 0; i < n; i++) {
      final m = i < marks.length ? marks[i] : 0;
      if (m == 1) continue;
      allUnshaded.add(i);
      if (visited[i]) continue;
      final comp = <int>[];
      final q = Queue<int>()..add(i);
      visited[i] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        comp.add(cur);
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + dr[d], nc = c + dc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          final nm = nIdx < marks.length ? marks[nIdx] : 0;
          if (nm != 1 && !visited[nIdx]) {
            visited[nIdx] = true;
            q.add(nIdx);
          }
        }
      }
      if (comp.length > largestComp.length) {
        largestComp = comp;
      }
    }

    final largestSet = largestComp.toSet();
    final disconnectedWhiteCells = <int>{
      for (final idx in allUnshaded)
        if (!largestSet.contains(idx)) idx,
    };
    final whiteConnected =
        unshadedCount > 0 && largestComp.length == unshadedCount;

    return HitoriAnalysis(
      duplicateCells: duplicateCells,
      adjacentBlackCells: adjacentBlackCells,
      disconnectedWhiteCells: disconnectedWhiteCells,
      whiteConnected: whiteConnected,
      cleanRows: cleanRows,
      cleanCols: cleanCols,
      unshadedCount: unshadedCount,
      shadedCount: shadedCount,
    );
  }

  static bool isSolved(HitoriPuzzle puz, List<int> marks) {
    if (marks.length != puz.size * puz.size) return false;
    return analyze(puz, marks).isSolved;
  }

  static bool _isWhiteConnected(List<int> mask, int size) {
    final n = size * size;
    var start = -1;
    var whiteTotal = 0;
    for (var i = 0; i < n; i++) {
      if (mask[i] != 1) {
        whiteTotal++;
        if (start == -1) start = i;
      }
    }
    if (whiteTotal == 0) return false;

    final visited = List<bool>.filled(n, false);
    final q = Queue<int>()..add(start);
    visited[start] = true;
    var reached = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      reached++;
      final r = cur ~/ size, c = cur % size;
      for (var d = 0; d < 4; d++) {
        final nr = r + dr[d], nc = c + dc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (mask[nIdx] != 1 && !visited[nIdx]) {
          visited[nIdx] = true;
          q.add(nIdx);
        }
      }
    }
    return reached == whiteTotal;
  }

  /// Generates a 100% guaranteed-valid Hitori puzzle for [size] (`5` or `6`).
  static HitoriPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;

    // 1. Construct a randomized Latin square of order `size` (digits 1..size)
    final rowPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final colPerm = [for (var i = 0; i < size; i++) i]..shuffle(rng);
    final symPerm = [for (var i = 1; i <= size; i++) i]..shuffle(rng);

    final latin = List<int>.filled(n, 1);
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        latin[r * size + c] = symPerm[(rowPerm[r] + colPerm[c]) % size];
      }
    }

    // 2. Build a valid shading mask with no adjacent 1s and connected 0s
    final mask = List<int>.filled(n, 0);
    final targetShaded = size <= 5 ? 5 : 7;
    final candidates = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    var shaded = 0;

    for (final idx in candidates) {
      if (shaded >= targetShaded) break;
      final r = idx ~/ size, c = idx % size;

      // Check no orthogonally adjacent shaded cell
      var adjBlack = false;
      for (var d = 0; d < 4; d++) {
        final nr = r + dr[d], nc = c + dc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          if (mask[nr * size + nc] == 1) {
            adjBlack = true;
            break;
          }
        }
      }
      if (adjBlack) continue;

      // Ensure row and col retain at least 2 unshaded cells
      var rowWhite = 0, colWhite = 0;
      for (var k = 0; k < size; k++) {
        if (k != c && mask[r * size + k] == 0) rowWhite++;
        if (k != r && mask[k * size + c] == 0) colWhite++;
      }
      if (rowWhite < 2 || colWhite < 2) continue;

      mask[idx] = 1;
      if (_isWhiteConnected(mask, size)) {
        shaded++;
      } else {
        mask[idx] = 0;
      }
    }

    // Fallback if somehow fewer than 2 cells were shaded
    if (shaded == 0) {
      mask[0] = 1;
    }

    // 3. Fill `0` cells with Latin square numbers, and `1` cells with duplicates
    // copied from an unshaded cell in the same row or column.
    final grid = List<int>.of(latin);
    for (var idx = 0; idx < n; idx++) {
      if (mask[idx] != 1) continue;
      final r = idx ~/ size, c = idx % size;
      final rowPeers = <int>[
        for (var cc = 0; cc < size; cc++)
          if (cc != c && mask[r * size + cc] == 0) grid[r * size + cc],
      ];
      final colPeers = <int>[
        for (var rr = 0; rr < size; rr++)
          if (rr != r && mask[rr * size + c] == 0) grid[rr * size + c],
      ];
      final pool = (rng.nextBool() && rowPeers.isNotEmpty)
          ? rowPeers
          : (colPeers.isNotEmpty ? colPeers : rowPeers);
      if (pool.isNotEmpty) {
        grid[idx] = pool[rng.nextInt(pool.length)];
      }
    }

    return HitoriPuzzle(
      size: size,
      grid: grid,
      solutionMask: mask,
    );
  }
}

/// 数独涂黑竞速 (Hitori Race, 1-6 人).
class HitoriGame extends GameEngine {
  HitoriGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late HitoriPuzzle currentPuzzle;
  late List<HitoriPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.marks];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a9Placings(ranking, players) : null;

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

    currentPuzzle = HitoriSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) HitoriPlayer(size * size)];

    host.log('数独涂黑竞速开始（$size×$size 网格，共 $totalRounds 题）！涂黑重复数字，保持黑格不相邻且白格全连通！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = HitoriSolver.generatePuzzle(size, rng);
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
    return a9Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  int _resolveCellIndex(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return r * size + c;
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
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
      case 'toggle':
      case 'set':
        final idx = _resolveCellIndex(a);
        if (a.containsKey('val')) {
          final v = asInt(a['val']);
          if (v < 0 || v > 2) throw GameError('状态值必须为 0、1 或 2');
          p.marks[idx] = v;
        } else {
          p.marks[idx] = (p.marks[idx] + 1) % 3;
        }
        moves++;
        if (HitoriSolver.isSolved(currentPuzzle, p.marks)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.marks.fillRange(0, p.marks.length, 0);
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
    host.log('${name(seat)} 第 $roundSolvers 个完成数独涂黑，+$pts 分！');
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
    ranking = a9Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a9Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentPuzzle.solutionMask;

    if (botLevel <= 0 && rng.nextInt(14) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if ((p.marks[i] == 1) != (sol[i] == 1)) i,
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
    final myMarks = me?.marks ?? List<int>.filled(size * size, 0);
    final analysis = HitoriSolver.analyze(puz, myMarks);
    final totalLines = 2 * size;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'grid': puz.grid,
      'marks': myMarks,
      'duplicates': analysis.duplicateCells.toList()..sort(),
      'adjBlacks': analysis.adjacentBlackCells.toList()..sort(),
      'disconnected': analysis.disconnectedWhiteCells.toList()..sort(),
      'whiteConnected': analysis.whiteConnected,
      'cleanLines': analysis.cleanLines,
      'totalLines': totalLines,
      'shadedCount': analysis.shadedCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = HitoriSolver.analyze(puz, ps[s].marks);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'cleanLines': pAn.cleanLines,
              'totalLines': totalLines,
              'dups': pAn.duplicateCells.length,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class HitoriPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> marks;

  HitoriPlayer(int cellCount) : marks = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    marks = List<int>.filled(cellCount, 0);
  }
}
