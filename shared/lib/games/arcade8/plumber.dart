import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a8_util.dart';

class PlumberPuzzle {
  final int size;
  /// Pipe types for each cell `0..size*size-1`: `'I'`, `'L'`, `'T'`, `'+'`, `'E'`.
  final List<String> types;
  /// Initial scrambled rotations (`0..3`).
  final List<int> initRots;
  /// Valid solution rotations (`0..3`).
  final List<int> solutionRots;
  /// Indices of Pressure Gauge Checkpoints (excluding source `0` and drain `size*size-1`).
  final List<int> gaugeIndices;

  const PlumberPuzzle({
    required this.size,
    required this.types,
    required this.initRots,
    required this.solutionRots,
    required this.gaugeIndices,
  });
}

class PlumberAnalysis {
  final Set<int> wetCells;
  final Set<int> leakCells;
  final Set<int> wetLeakCells;
  final Set<int> litGauges;
  final bool drainReached;
  final int totalCells;
  final int totalGauges;

  const PlumberAnalysis({
    required this.wetCells,
    required this.leakCells,
    required this.wetLeakCells,
    required this.litGauges,
    required this.drainReached,
    required this.totalCells,
    required this.totalGauges,
  });

  bool get isSolved =>
      drainReached &&
      litGauges.length == totalGauges &&
      wetCells.length == totalCells &&
      leakCells.isEmpty;
}

class PlumberSolver {
  /// Directions: 0 = North, 1 = East, 2 = South, 3 = West.
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static List<int> basePorts(String type) => switch (type) {
        'I' => const [0, 2],
        'L' => const [0, 1],
        'T' => const [0, 1, 2],
        '+' => const [0, 1, 2, 3],
        'E' => const [0],
        _ => const [0, 2],
      };

  static int openPortsMask(String type, int rot) {
    final shift = ((rot % 4) + 4) % 4;
    var mask = 0;
    for (final p in basePorts(type)) {
      mask |= 1 << ((p + shift) & 3);
    }
    return mask;
  }

  static (String, int) _tileFromMask(int mask) => switch (mask & 0xF) {
        0x1 => ('E', 0), // N
        0x2 => ('E', 1), // E
        0x4 => ('E', 2), // S
        0x8 => ('E', 3), // W
        0x5 => ('I', 0), // N, S
        0xA => ('I', 1), // E, W
        0x3 => ('L', 0), // N, E
        0x6 => ('L', 1), // E, S
        0xC => ('L', 2), // S, W
        0x9 => ('L', 3), // W, N
        0x7 => ('T', 0), // N, E, S
        0xE => ('T', 1), // E, S, W
        0xD => ('T', 2), // S, W, N
        0xB => ('T', 3), // W, N, E
        0xF => ('+', 0), // N, E, S, W
        _ => ('I', 0),
      };

  static PlumberAnalysis analyze(PlumberPuzzle puz, List<int> rots) {
    final size = puz.size;
    final n = size * size;
    final masks = List<int>.generate(
      n,
      (i) => openPortsMask(
        i < puz.types.length ? puz.types[i] : 'I',
        i < rots.length ? rots[i] : 0,
      ),
    );

    final leakCells = <int>{};
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        final m = masks[idx];
        for (var d = 0; d < 4; d++) {
          if ((m & (1 << d)) == 0) continue;
          final nr = r + dr[d], nc = c + dc[d];
          final opp = (d + 2) & 3;
          if (nr < 0 ||
              nr >= size ||
              nc < 0 ||
              nc >= size ||
              (masks[nr * size + nc] & (1 << opp)) == 0) {
            leakCells.add(idx);
            break;
          }
        }
      }
    }

    // BFS water flow from Source Valve (0, 0)
    final wetCells = <int>{0};
    final q = Queue<int>()..add(0);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final r = cur ~/ size, c = cur % size;
      final m = masks[cur];
      for (var d = 0; d < 4; d++) {
        if ((m & (1 << d)) == 0) continue;
        final nr = r + dr[d], nc = c + dc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        final opp = (d + 2) & 3;
        if ((masks[nIdx] & (1 << opp)) != 0 && wetCells.add(nIdx)) {
          q.add(nIdx);
        }
      }
    }

    final wetLeakCells = <int>{
      for (final idx in wetCells)
        if (leakCells.contains(idx)) idx,
    };

    final litGauges = <int>{
      for (final g in puz.gaugeIndices)
        if (wetCells.contains(g)) g,
    };

    return PlumberAnalysis(
      wetCells: wetCells,
      leakCells: leakCells,
      wetLeakCells: wetLeakCells,
      litGauges: litGauges,
      drainReached: wetCells.contains(n - 1),
      totalCells: n,
      totalGauges: puz.gaugeIndices.length,
    );
  }

  static bool isSolved(PlumberPuzzle puz, List<int> rots) {
    if (rots.length != puz.size * puz.size) return false;
    return analyze(puz, rots).isSolved;
  }

  static int _bitCount4(int m) =>
      (m & 1) + ((m >> 1) & 1) + ((m >> 2) & 1) + ((m >> 3) & 1);

  /// Generates a 100% guaranteed-valid Plumber puzzle for [size] (`5` or `6`).
  static PlumberPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final masks = List<int>.filled(n, 0);
    final visited = List<bool>.filled(n, false);

    // 1. Randomized DFS spanning tree so all N*N cells are connected
    void dfs(int cur) {
      visited[cur] = true;
      final r = cur ~/ size, c = cur % size;
      final dirs = [0, 1, 2, 3]..shuffle(rng);
      for (final d in dirs) {
        final nr = r + dr[d], nc = c + dc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (!visited[nIdx]) {
          final opp = (d + 2) & 3;
          masks[cur] |= 1 << d;
          masks[nIdx] |= 1 << opp;
          dfs(nIdx);
        }
      }
    }

    dfs(0);

    // 2. Connect adjacent degree-1 endpoints so most tiles are bends/tees/straights
    final order = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    for (final idx in order) {
      if (_bitCount4(masks[idx]) != 1) continue;
      final r = idx ~/ size, c = idx % size;
      final dirs = [0, 1, 2, 3]..shuffle(rng);
      for (final d in dirs) {
        if ((masks[idx] & (1 << d)) != 0) continue;
        final nr = r + dr[d], nc = c + dc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nIdx = nr * size + nc;
        if (_bitCount4(masks[nIdx]) <= 2) {
          final opp = (d + 2) & 3;
          masks[idx] |= 1 << d;
          masks[nIdx] |= 1 << opp;
          break;
        }
      }
    }

    final types = <String>[];
    final solRots = <int>[];
    for (var i = 0; i < n; i++) {
      final (t, rot) = _tileFromMask(masks[i]);
      types.add(t);
      solRots.add(rot);
    }

    // 3. Pick 2 or 3 gauge checkpoints
    final candidates = [
      for (var i = 1; i < n - 1; i++)
        if (types[i] != '+') i,
    ]..shuffle(rng);
    final gaugeCount = size <= 5 ? 2 : 3;
    final gauges = candidates.take(gaugeCount).toList()..sort();

    // 4. Scramble initial rotations so the puzzle is not already solved
    final initRots = List<int>.of(solRots);
    for (var i = 0; i < n; i++) {
      if (types[i] == '+') continue;
      if (rng.nextInt(4) != 0) {
        final step = types[i] == 'I' ? 1 : (1 + rng.nextInt(3));
        initRots[i] = (solRots[i] + step) & 3;
      }
    }

    final puz = PlumberPuzzle(
      size: size,
      types: types,
      initRots: initRots,
      solutionRots: solRots,
      gaugeIndices: gauges,
    );

    if (isSolved(puz, initRots)) {
      for (var i = 0; i < n; i++) {
        if (types[i] != '+') {
          initRots[i] = (solRots[i] + 1) & 3;
          break;
        }
      }
    }

    return puz;
  }
}

/// 水管工接管竞速 (Plumber Race, 1-6 人).
class PlumberGame extends GameEngine {
  PlumberGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late PlumberPuzzle currentPuzzle;
  late List<PlumberPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.rots];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a8Placings(ranking, players) : null;

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

    currentPuzzle = PlumberSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) PlumberPlayer(currentPuzzle.initRots)];

    host.log('水管工接管竞速开始（$size×$size 网格，共 $totalRounds 题）！旋转管道使水源连通排出口与全部水压表且零漏水！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = PlumberSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(currentPuzzle.initRots);
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
    return a8Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'rotate':
        final idx = _resolveCellIndex(a);
        if (a.containsKey('val')) {
          p.rots[idx] = ((asInt(a['val']) % 4) + 4) % 4;
        } else {
          final step = asInt(a['steps'], 1);
          p.rots[idx] = ((p.rots[idx] + step) % 4 + 4) % 4;
        }
        moves++;
        if (PlumberSolver.isSolved(currentPuzzle, p.rots)) {
          _markSolved(seat);
        }

      case 'reset':
      case 'clear':
        p.rots = List<int>.of(currentPuzzle.initRots);
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
    host.log('${name(seat)} 第 $roundSolvers 个接通高压水网，+$pts 分！');
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
    ranking = a8Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a8Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;

    if (botLevel <= 0 && rng.nextInt(14) == 0) {
      return {'type': 'pass'};
    }

    final misoriented = <int>[];
    for (var i = 0; i < p.rots.length; i++) {
      final curMask = PlumberSolver.openPortsMask(puz.types[i], p.rots[i]);
      final solMask = PlumberSolver.openPortsMask(puz.types[i], puz.solutionRots[i]);
      if (curMask != solMask) {
        misoriented.add(i);
      }
    }

    if (misoriented.isNotEmpty) {
      final pick = misoriented[rng.nextInt(misoriented.length)];
      return {
        'type': 'rotate',
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
    final myRots = me?.rots ?? List<int>.of(puz.initRots);
    final analysis = PlumberSolver.analyze(puz, myRots);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'types': puz.types,
      'rots': myRots,
      'gauges': puz.gaugeIndices,
      'wet': analysis.wetCells.toList()..sort(),
      'leaks': analysis.leakCells.toList()..sort(),
      'wetLeaks': analysis.wetLeakCells.toList()..sort(),
      'litGauges': analysis.litGauges.toList()..sort(),
      'drainReached': analysis.drainReached,
      'wetCount': analysis.wetCells.length,
      'totalCells': analysis.totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = PlumberSolver.analyze(puz, ps[s].rots);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'wetCount': pAn.wetCells.length,
              'totalCells': max(1, pAn.totalCells),
              'leaks': pAn.leakCells.length,
              'drain': pAn.drainReached,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class PlumberPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> rots;

  PlumberPlayer(List<int> initRots) : rots = List<int>.of(initRots);

  void resetForRound(List<int> initRots) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    rots = List<int>.of(initRots);
  }
}
