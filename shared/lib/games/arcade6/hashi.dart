import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a6_util.dart';

class HashiIsland {
  final int id;
  final int r;
  final int c;
  final int clue;

  const HashiIsland({
    required this.id,
    required this.r,
    required this.c,
    required this.clue,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'r': r,
        'c': c,
        'clue': clue,
      };
}

class HashiPuzzle {
  final int size;
  final List<HashiIsland> islands;
  final Map<String, int> solutionBridges;

  const HashiPuzzle({
    required this.size,
    required this.islands,
    required this.solutionBridges,
  });
}

class HashiSolver {
  static const List<int> dr = [-1, 0, 1, 0];
  static const List<int> dc = [0, 1, 0, -1];

  static String pairKey(int a, int b) => a < b ? '$a:$b' : '$b:$a';

  static (int, int) parsePairKey(String key) {
    final idx = key.indexOf(':');
    return (int.parse(key.substring(0, idx)), int.parse(key.substring(idx + 1)));
  }

  /// Returns true if islands [a] and [b] share a row or column and have no
  /// other island strictly between them.
  static bool areVisible(List<HashiIsland> islands, int a, int b) {
    if (a < 0 || a >= islands.length || b < 0 || b >= islands.length || a == b) {
      return false;
    }
    final ia = islands[a];
    final ib = islands[b];
    if (ia.r == ib.r) {
      final minC = min(ia.c, ib.c);
      final maxC = max(ia.c, ib.c);
      for (final k in islands) {
        if (k.r == ia.r && k.c > minC && k.c < maxC) return false;
      }
      return true;
    }
    if (ia.c == ib.c) {
      final minR = min(ia.r, ib.r);
      final maxR = max(ia.r, ib.r);
      for (final k in islands) {
        if (k.c == ia.c && k.r > minR && k.r < maxR) return false;
      }
      return true;
    }
    return false;
  }

  /// Lists all orthogonally visible island pairs `(i1, i2)` with `i1 < i2`.
  static List<(int, int)> visiblePairs(List<HashiIsland> islands) {
    final out = <(int, int)>[];
    for (var i = 0; i < islands.length; i++) {
      for (var j = i + 1; j < islands.length; j++) {
        if (areVisible(islands, i, j)) {
          out.add((i, j));
        }
      }
    }
    return out;
  }

  /// Returns true if bridge `e1 = (u1, v1)` and bridge `e2 = (u2, v2)` cross orthogonally.
  static bool bridgesCross(List<HashiIsland> islands, (int, int) e1, (int, int) e2) {
    final a = islands[e1.$1], b = islands[e1.$2];
    final c = islands[e2.$1], d = islands[e2.$2];

    final e1Horiz = a.r == b.r;
    final e2Horiz = c.r == d.r;
    if (e1Horiz == e2Horiz) return false;

    final hA = e1Horiz ? a : c;
    final hB = e1Horiz ? b : d;
    final vA = e1Horiz ? c : a;
    final vB = e1Horiz ? d : b;

    final rH = hA.r;
    final cMin = min(hA.c, hB.c);
    final cMax = max(hA.c, hB.c);

    final cV = vA.c;
    final rMin = min(vA.r, vB.r);
    final rMax = max(vA.r, vB.r);

    return cMin < cV && cV < cMax && rMin < rH && rH < rMax;
  }

  /// Returns the set of pairKeys of active bridges that cross at least one other active bridge.
  static Set<String> crossingBridgeKeys(List<HashiIsland> islands, Map<String, int> bridges) {
    final active = <(String, (int, int))>[];
    for (final e in bridges.entries) {
      if (e.value > 0) {
        final pair = parsePairKey(e.key);
        if (areVisible(islands, pair.$1, pair.$2)) {
          active.add((e.key, pair));
        }
      }
    }
    final bad = <String>{};
    for (var i = 0; i < active.length; i++) {
      for (var j = i + 1; j < active.length; j++) {
        if (bridgesCross(islands, active[i].$2, active[j].$2)) {
          bad.add(active[i].$1);
          bad.add(active[j].$1);
        }
      }
    }
    return bad;
  }

  /// Computes the current connected bridge sum for each island `0..islands.length-1`.
  static List<int> islandDegrees(int islandCount, Map<String, int> bridges) {
    final deg = List<int>.filled(islandCount, 0);
    for (final e in bridges.entries) {
      final count = e.value;
      if (count <= 0) continue;
      final (u, v) = parsePairKey(e.key);
      if (u >= 0 && u < islandCount && v >= 0 && v < islandCount) {
        deg[u] += count;
        deg[v] += count;
      }
    }
    return deg;
  }

  /// Returns true if all islands form a single connected component via active bridges (`count > 0`).
  static bool isConnected(int islandCount, Map<String, int> bridges) {
    if (islandCount <= 1) return true;
    final adj = [for (var i = 0; i < islandCount; i++) <int>[]];
    for (final e in bridges.entries) {
      if (e.value <= 0) continue;
      final (u, v) = parsePairKey(e.key);
      if (u >= 0 && u < islandCount && v >= 0 && v < islandCount) {
        adj[u].add(v);
        adj[v].add(u);
      }
    }
    final visited = <int>{0};
    final q = Queue<int>()..add(0);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      for (final nxt in adj[cur]) {
        if (visited.add(nxt)) {
          q.add(nxt);
        }
      }
    }
    return visited.length == islandCount;
  }

  /// Returns true if:
  /// 1. Every island's connected bridge count equals its clue number,
  /// 2. No two bridges cross, and
  /// 3. All islands form a single connected component.
  static bool isSolved(List<HashiIsland> islands, Map<String, int> bridges) {
    if (islands.isEmpty) return false;
    final n = islands.length;
    for (final e in bridges.entries) {
      final c = e.value;
      if (c <= 0) continue;
      if (c > 2) return false;
      final (u, v) = parsePairKey(e.key);
      if (!areVisible(islands, u, v)) return false;
    }
    final deg = islandDegrees(n, bridges);
    for (var i = 0; i < n; i++) {
      if (deg[i] != islands[i].clue) return false;
    }
    if (crossingBridgeKeys(islands, bridges).isNotEmpty) return false;
    return isConnected(n, bridges);
  }

  /// Generates a guaranteed-solvable planar connected Hashiwokakero puzzle for [size] (`6` or `8`).
  static HashiPuzzle generatePuzzle(int size, Random rng) {
    final targetMin = size <= 6 ? 7 : 10;
    final targetMax = size <= 6 ? 9 : 13;

    for (var attempt = 0; attempt < 25; attempt++) {
      // 0 = empty water, 1 = island, 2 = reserved bridge corridor
      final grid = List<int>.filled(size * size, 0);
      final coords = <(int, int)>[];
      final edges = <(int, int)>[];

      // Start with an island near a random quadrant
      final r0 = rng.nextInt(size);
      final c0 = rng.nextInt(size);
      coords.add((r0, c0));
      grid[r0 * size + c0] = 1;

      final goalCount = targetMin + rng.nextInt(targetMax - targetMin + 1);

      while (coords.length < goalCount) {
        final candidates = <(int, int, int, int)>[]; // (fromIdx, nr, nc, dist)
        for (var i = 0; i < coords.length; i++) {
          final (r, c) = coords[i];
          for (var d = 0; d < 4; d++) {
            for (var dist = 1; dist < size; dist++) {
              final nr = r + dr[d] * dist;
              final nc = c + dc[d] * dist;
              if (nr < 0 || nr >= size || nc < 0 || nc >= size) break;
              final cell = grid[nr * size + nc];
              if (cell != 0) break; // blocked by island or existing bridge

              // Prefer dist >= 2 so bridges have visible water cells between islands
              if (dist >= 2) {
                candidates.add((i, nr, nc, dist));
              } else if (coords.length < 4) {
                // Only use dist == 1 if needed early on
                candidates.add((i, nr, nc, dist));
              }
            }
          }
        }
        // Prefer dist >= 2 candidates first
        final dist2Plus = [for (final c in candidates) if (c.$4 >= 2) c];
        final pool = dist2Plus.isNotEmpty ? dist2Plus : candidates;
        if (pool.isEmpty) break;

        final pick = pool[rng.nextInt(pool.length)];
        final (fromIdx, nr, nc, _) = pick;
        final (fr, fc) = coords[fromIdx];

        // Mark intermediate corridor cells as 2
        final stepR = (nr - fr).sign;
        final stepC = (nc - fc).sign;
        var cr = fr + stepR;
        var cc = fc + stepC;
        while (cr != nr || cc != nc) {
          grid[cr * size + cc] = 2;
          cr += stepR;
          cc += stepC;
        }
        grid[nr * size + nc] = 1;
        final newIdx = coords.length;
        coords.add((nr, nc));
        edges.add(fromIdx < newIdx ? (fromIdx, newIdx) : (newIdx, fromIdx));
      }

      if (coords.length < targetMin) continue;

      // Optionally add 1..2 planar cycle edges whose intermediate cells are all 0 (empty)
      final edgeSet = <String>{for (final e in edges) pairKey(e.$1, e.$2)};
      for (var i = 0; i < coords.length; i++) {
        for (var j = i + 1; j < coords.length; j++) {
          final key = pairKey(i, j);
          if (edgeSet.contains(key)) continue;
          final (r1, c1) = coords[i];
          final (r2, c2) = coords[j];
          if (r1 != r2 && c1 != c2) continue;
          final dist = (r1 - r2).abs() + (c1 - c2).abs();
          if (dist < 2) continue;
          final stepR = (r2 - r1).sign;
          final stepC = (c2 - c1).sign;
          var clear = true;
          var cr = r1 + stepR, cc = c1 + stepC;
          while (cr != r2 || cc != c2) {
            if (grid[cr * size + cc] != 0) {
              clear = false;
              break;
            }
            cr += stepR;
            cc += stepC;
          }
          if (clear && rng.nextDouble() < 0.45) {
            cr = r1 + stepR;
            cc = c1 + stepC;
            while (cr != r2 || cc != c2) {
              grid[cr * size + cc] = 2;
              cr += stepR;
              cc += stepC;
            }
            edges.add((i, j));
            edgeSet.add(key);
          }
        }
      }

      // Assign bridge multiplicity 1 or 2 to each edge
      final solBridges = <String, int>{};
      for (final (u, v) in edges) {
        solBridges[pairKey(u, v)] = rng.nextBool() ? 2 : 1;
      }

      final deg = islandDegrees(coords.length, solBridges);
      final islands = [
        for (var i = 0; i < coords.length; i++)
          HashiIsland(
            id: i,
            r: coords[i].$1,
            c: coords[i].$2,
            clue: deg[i],
          ),
      ];

      if (isSolved(islands, solBridges)) {
        return HashiPuzzle(
          size: size,
          islands: islands,
          solutionBridges: solBridges,
        );
      }
    }

    // Deterministic guaranteed fallback layout
    final fallbackCoords = size <= 6
        ? const [(0, 0), (0, 3), (0, 5), (2, 0), (2, 3), (4, 5), (5, 0), (5, 3)]
        : const [(0, 0), (0, 4), (0, 7), (2, 2), (2, 4), (2, 7), (4, 0), (4, 2), (6, 4), (6, 7), (7, 0)];
    final fallbackEdges = size <= 6
        ? const [(0, 1), (1, 2), (0, 3), (1, 4), (3, 4), (2, 5), (3, 6), (4, 7), (6, 7)]
        : const [(0, 1), (1, 2), (3, 4), (4, 5), (1, 4), (2, 5), (0, 6), (6, 7), (3, 7), (4, 8), (8, 9), (5, 9), (6, 10)];
    final solBridges = <String, int>{
      for (final (u, v) in fallbackEdges) pairKey(u, v): (u + v).isEven ? 2 : 1,
    };
    final deg = islandDegrees(fallbackCoords.length, solBridges);
    final islands = [
      for (var i = 0; i < fallbackCoords.length; i++)
        HashiIsland(id: i, r: fallbackCoords[i].$1, c: fallbackCoords[i].$2, clue: deg[i]),
    ];
    return HashiPuzzle(size: size, islands: islands, solutionBridges: solBridges);
  }
}

/// 数回连桥竞速 (Hashiwokakero Race, 1-6 人).
class HashiGame extends GameEngine {
  HashiGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late HashiPuzzle currentPuzzle;
  late List<HashiPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a6Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 780, 2 => 260, _ => 460 };

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
    final rawSize = setup.opt<int>('size', 6);
    size = rawSize == 8 ? 8 : 6;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = HashiSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) HashiPlayer()];

    host.log('数回连桥竞速开始（$size×$size 海域，共 $totalRounds 题）！连接全部岛屿且满足桥数要求即可过关！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = HashiSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound();
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
    return a6Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  (int, int) _validateVisiblePair(Map<String, dynamic> a) {
    final i1 = asInt(a['i1']);
    final i2 = asInt(a['i2']);
    final islands = currentPuzzle.islands;
    if (i1 < 0 || i1 >= islands.length || i2 < 0 || i2 >= islands.length || i1 == i2) {
      throw GameError('指定的岛屿编号无效');
    }
    if (!HashiSolver.areVisible(islands, i1, i2)) {
      throw GameError('这两座岛屿不在同一直线或中间有其他岛屿阻挡');
    }
    return i1 < i2 ? (i1, i2) : (i2, i1);
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
      case 'bridge':
        final (u, v) = _validateVisiblePair(a);
        final key = HashiSolver.pairKey(u, v);
        final cur = p.bridges[key] ?? 0;
        final next = (cur + 1) % 3;
        if (next == 0) {
          p.bridges.remove(key);
        } else {
          p.bridges[key] = next;
        }
        moves++;
        if (HashiSolver.isSolved(currentPuzzle.islands, p.bridges)) {
          _markSolved(seat);
        }

      case 'set_bridge':
        final (u, v) = _validateVisiblePair(a);
        final count = a.containsKey('count') ? asInt(a['count']) : asInt(a['val']);
        if (count < 0 || count > 2) {
          throw GameError('桥梁数量必须为 0、1 或 2');
        }
        final key = HashiSolver.pairKey(u, v);
        if (count == 0) {
          p.bridges.remove(key);
        } else {
          p.bridges[key] = count;
        }
        moves++;
        if (HashiSolver.isSolved(currentPuzzle.islands, p.bridges)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.bridges.clear();
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
    host.log('${name(seat)} 第 $roundSolvers 个连通全部岛屿，+$pts 分！');
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
    ranking = a6Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a6Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentPuzzle.solutionBridges;

    // Easy bot occasionally gives up at the start of a round
    if (botLevel <= 0 && p.bridges.isEmpty && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // First fix any erroneous bridge on the player's board
    for (final e in p.bridges.entries) {
      if (e.value <= 0) continue;
      final target = sol[e.key] ?? 0;
      if (e.value != target) {
        final (u, v) = HashiSolver.parsePairKey(e.key);
        return {'type': 'set_bridge', 'i1': u, 'i2': v, 'count': target};
      }
    }

    // Find all solution bridges not yet satisfied
    final missing = <(int, int, int)>[];
    for (final e in sol.entries) {
      final cur = p.bridges[e.key] ?? 0;
      if (cur != e.value) {
        final (u, v) = HashiSolver.parsePairKey(e.key);
        missing.add((u, v, e.value));
      }
    }

    if (missing.isNotEmpty) {
      final pick = missing[rng.nextInt(missing.length)];
      return {'type': 'set_bridge', 'i1': pick.$1, 'i2': pick.$2, 'count': pick.$3};
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final myBridges = me?.bridges ?? const <String, int>{};
    final islands = currentPuzzle.islands;
    final n = islands.length;
    final myDeg = HashiSolver.islandDegrees(n, myBridges);
    final crossingKeys = HashiSolver.crossingBridgeKeys(islands, myBridges);
    final connected = HashiSolver.isConnected(n, myBridges);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'islands': [
        for (var i = 0; i < n; i++)
          {
            ...islands[i].toJson(),
            'deg': myDeg[i],
            'ok': myDeg[i] == islands[i].clue,
          },
      ],
      'bridges': [
        for (final e in myBridges.entries)
          if (e.value > 0)
            () {
              final (u, v) = HashiSolver.parsePairKey(e.key);
              return {
                'i1': u,
                'i2': v,
                'count': e.value,
                'cross': crossingKeys.contains(e.key),
              };
            }(),
      ],
      'visiblePairs': [
        for (final (u, v) in HashiSolver.visiblePairs(islands))
          {'i1': u, 'i2': v},
      ],
      'connected': connected,
      'crossingCount': crossingKeys.length,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final deg = HashiSolver.islandDegrees(n, ps[s].bridges);
            final okIslands = [for (var i = 0; i < n; i++) if (deg[i] == islands[i].clue) i].length;
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'okIslands': okIslands,
              'totalIslands': n,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class HashiPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  final Map<String, int> bridges = {};

  void resetForRound() {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    bridges.clear();
  }
}
