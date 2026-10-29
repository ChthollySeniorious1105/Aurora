import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a5_util.dart';

/// Wall bitmask constants:
/// Bit 0 (1): Top (上, dir=0)
/// Bit 1 (2): Right (右, dir=1)
/// Bit 2 (4): Bottom (下, dir=2)
/// Bit 3 (8): Left (左, dir=3)
class RicochetSolver {
  static const dr = [-1, 0, 1, 0];
  static const dc = [0, 1, 0, -1];
  static const robotNames = ['红', '绿', '蓝', '黄'];
  static const dirNames = ['上', '右', '下', '左'];

  static void addWall(List<int> walls, int size, int r, int c, int dir) {
    if (r < 0 || r >= size || c < 0 || c >= size) return;
    walls[r * size + c] |= (1 << dir);
    final nr = r + dr[dir], nc = c + dc[dir];
    if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
      walls[nr * size + nc] |= (1 << ((dir + 2) & 3));
    }
  }

  /// Builds a walled grid of [size] (10 or 12) with outer boundaries, edge spurs,
  /// and internal L-shaped walls across all four quadrants.
  /// Returns `(walls, pocketCells)` where `pocketCells` are the L-wall corner cells.
  static (List<int>, List<int>) buildBoard(int size, Random rng) {
    final walls = List<int>.filled(size * size, 0);

    // Outer borders
    for (var i = 0; i < size; i++) {
      addWall(walls, size, 0, i, 0); // top border
      addWall(walls, size, size - 1, i, 2); // bottom border
      addWall(walls, size, i, 0, 3); // left border
      addWall(walls, size, i, size - 1, 1); // right border
    }

    // Edge spurs (perpendicular walls sticking out from each outer wall)
    final s1 = 2 + rng.nextInt(2);
    final s2 = size - 3 - rng.nextInt(2);
    addWall(walls, size, 0, s1, 1);
    addWall(walls, size, 0, s2, 3);
    addWall(walls, size, size - 1, s1, 1);
    addWall(walls, size, size - 1, s2, 3);
    addWall(walls, size, s1, 0, 2);
    addWall(walls, size, s2, 0, 0);
    addWall(walls, size, s1, size - 1, 2);
    addWall(walls, size, s2, size - 1, 0);

    // Internal L-shaped corners distributed across the board
    final pockets = <int>[];
    void addL(int r, int c, int d1, int d2) {
      if (r <= 0 || r >= size - 1 || c <= 0 || c >= size - 1) return;
      addWall(walls, size, r, c, d1);
      addWall(walls, size, r, c, d2);
      pockets.add(r * size + c);
    }

    if (size == 10) {
      // 12 well-spaced L-walls on a 10x10 board
      addL(1, 2, 0, 1);
      addL(2, 4, 2, 3);
      addL(3, 1, 1, 2);
      addL(1, 7, 2, 1);
      addL(3, 6, 0, 3);
      addL(4, 8, 2, 3);
      addL(6, 1, 0, 1);
      addL(7, 3, 2, 1);
      addL(8, 2, 0, 3);
      addL(6, 7, 1, 2);
      addL(7, 5, 0, 1);
      addL(8, 8, 0, 3);
    } else {
      // 16 well-spaced L-walls on a 12x12 board
      addL(1, 2, 0, 1);
      addL(2, 4, 2, 3);
      addL(4, 1, 1, 2);
      addL(4, 4, 0, 1);
      addL(1, 8, 2, 1);
      addL(3, 7, 0, 3);
      addL(2, 10, 1, 2);
      addL(5, 9, 2, 3);
      addL(7, 1, 0, 1);
      addL(8, 4, 2, 1);
      addL(10, 2, 0, 3);
      addL(9, 5, 1, 2);
      addL(7, 8, 0, 3);
      addL(8, 10, 2, 1);
      addL(10, 7, 0, 1);
      addL(10, 9, 2, 3);
    }

    return (walls, pockets);
  }

  /// Slides robot [robotIdx] (0..3) in [dir] (0:上, 1:右, 2:下, 3:左) on [robots]
  /// until blocked by a wall, board boundary, or another robot.
  /// Returns the destination cell index.
  static int slide(List<int> walls, int size, List<int> robots, int robotIdx, int dir) {
    var cur = robots[robotIdx];
    final r0 = robots[0], r1 = robots[1], r2 = robots[2], r3 = robots[3];
    while ((walls[cur] & (1 << dir)) == 0) {
      final nr = (cur ~/ size) + dr[dir];
      final nc = (cur % size) + dc[dir];
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) break;
      final next = nr * size + nc;
      if (next == r0 || next == r1 || next == r2 || next == r3) break;
      cur = next;
    }
    return cur;
  }

  static int _pack(int r0, int r1, int r2, int r3) =>
      r0 | (r1 << 8) | (r2 << 16) | (r3 << 24);

  /// Finds a shortest move sequence `[{'robot': r, 'dir': d}, ...]` from [startRobots]
  /// such that `robots[targetRobot] == targetCell`, up to [maxDepth] moves (and [maxStates] states).
  static List<Map<String, int>>? solve(
    List<int> walls,
    int size,
    List<int> startRobots,
    int targetRobot,
    int targetCell, {
    int maxDepth = 6,
    int maxStates = 25000,
  }) {
    if (startRobots[targetRobot] == targetCell) return const [];

    final states = <int>[_pack(startRobots[0], startRobots[1], startRobots[2], startRobots[3])];
    final depths = <int>[0];
    final parents = <int>[-1];
    final moveCode = <int>[0]; // (robot << 2) | dir
    final visited = HashSet<int>()..add(states[0]);

    var head = 0;
    final cur = [0, 0, 0, 0];
    while (head < states.length && states.length < maxStates) {
      final st = states[head];
      final d = depths[head];
      if (d >= maxDepth) {
        head++;
        continue;
      }
      cur[0] = st & 0xFF;
      cur[1] = (st >> 8) & 0xFF;
      cur[2] = (st >> 16) & 0xFF;
      cur[3] = (st >> 24) & 0xFF;

      for (var r = 0; r < 4; r++) {
        final orig = cur[r];
        for (var dir = 0; dir < 4; dir++) {
          final dest = slide(walls, size, cur, r, dir);
          if (dest == orig) continue;
          cur[r] = dest;
          final nextSt = _pack(cur[0], cur[1], cur[2], cur[3]);
          cur[r] = orig;

          if (r == targetRobot && dest == targetCell) {
            // Reconstruct solution
            final out = <Map<String, int>>[
              {'robot': r, 'dir': dir},
            ];
            var p = head;
            while (p > 0) {
              final mc = moveCode[p];
              out.add({'robot': mc >> 2, 'dir': mc & 3});
              p = parents[p];
            }
            return out.reversed.toList();
          }

          if (d + 1 < maxDepth && visited.add(nextSt)) {
            states.add(nextSt);
            depths.add(d + 1);
            parents.add(head);
            moveCode.add((r << 2) | dir);
            if (states.length >= maxStates) break;
          }
        }
        if (states.length >= maxStates) break;
      }
      head++;
    }
    return null;
  }

  /// Explores from [startRobots] via BFS up to depth 6 and picks a target
  /// `(targetRobot, targetCell, shortestMoves, finalRobots)` guaranteed reachable
  /// in 2..6 slides.
  static (int, int, List<Map<String, int>>, List<int>) pickTarget(
    List<int> walls,
    int size,
    List<int> startRobots,
    List<int> pocketCells,
    Random rng, {
    Set<int> usedTargets = const {},
  }) {
    final states = <int>[_pack(startRobots[0], startRobots[1], startRobots[2], startRobots[3])];
    final depths = <int>[0];
    final parents = <int>[-1];
    final moveCode = <int>[0];
    final visited = HashSet<int>()..add(states[0]);

    // key = (robot << 8) | cell -> (depth, stateIdx)
    final firstHit = <int, (int, int)>{};
    for (var r = 0; r < 4; r++) {
      firstHit[(r << 8) | startRobots[r]] = (0, 0);
    }

    var head = 0;
    const maxDepth = 5;
    const maxStates = 12000;
    final cur = [0, 0, 0, 0];

    while (head < states.length && states.length < maxStates) {
      final st = states[head];
      final d = depths[head];
      if (d >= maxDepth) {
        head++;
        continue;
      }
      cur[0] = st & 0xFF;
      cur[1] = (st >> 8) & 0xFF;
      cur[2] = (st >> 16) & 0xFF;
      cur[3] = (st >> 24) & 0xFF;

      for (var r = 0; r < 4; r++) {
        final orig = cur[r];
        for (var dir = 0; dir < 4; dir++) {
          final dest = slide(walls, size, cur, r, dir);
          if (dest == orig) continue;
          cur[r] = dest;
          final nextSt = _pack(cur[0], cur[1], cur[2], cur[3]);
          cur[r] = orig;

          if (visited.add(nextSt)) {
            final idx = states.length;
            states.add(nextSt);
            depths.add(d + 1);
            parents.add(head);
            moveCode.add((r << 2) | dir);
            final hitKey = (r << 8) | dest;
            firstHit.putIfAbsent(hitKey, () => (d + 1, idx));
            if (states.length >= maxStates) break;
          }
        }
        if (states.length >= maxStates) break;
      }
      head++;
    }

    final pocketSet = pocketCells.toSet();
    final preferred = <(int, int, int)>[]; // (robot, cell, stateIdx)
    final secondary = <(int, int, int)>[];
    final fallback = <(int, int, int)>[];

    firstHit.forEach((key, val) {
      final r = key >> 8;
      final cell = key & 0xFF;
      final d = val.$1;
      final stIdx = val.$2;
      if (d >= 2 && d <= 6) {
        if (pocketSet.contains(cell) && !usedTargets.contains(key)) {
          preferred.add((r, cell, stIdx));
        } else if (!usedTargets.contains(key)) {
          secondary.add((r, cell, stIdx));
        } else {
          fallback.add((r, cell, stIdx));
        }
      } else if (d == 1) {
        fallback.add((r, cell, stIdx));
      }
    });

    final pool = preferred.isNotEmpty
        ? preferred
        : (secondary.isNotEmpty ? secondary : fallback);

    final chosen = pool[rng.nextInt(pool.length)];
    final targetRobot = chosen.$1;
    final targetCell = chosen.$2;
    var p = chosen.$3;

    final endSt = states[p];
    final finalRobots = [
      endSt & 0xFF,
      (endSt >> 8) & 0xFF,
      (endSt >> 16) & 0xFF,
      (endSt >> 24) & 0xFF,
    ];

    final moves = <Map<String, int>>[];
    while (p > 0) {
      final mc = moveCode[p];
      moves.add({'robot': mc >> 2, 'dir': mc & 3});
      p = parents[p];
    }
    return (targetRobot, targetCell, moves.reversed.toList(), finalRobots);
  }
}

/// 弹射机器人 (Ricochet Robots, 1-8 人).
class RicochetGame extends GameEngine {
  RicochetGame(super.setup);

  static const roundMaxSec = 240;

  late int totalRounds;
  late int size;
  late List<int> walls;
  late List<int> pocketCells;

  int round = 0;
  int roundSec = 0;
  int moves = 0;

  List<int> mainRobots = [0, 1, 2, 3];
  int targetRobot = 0;
  int targetCell = 0;
  List<Map<String, int>> currentSolution = const [];
  List<int> currentSolutionEndRobots = const [];
  final Set<int> _usedTargets = {};

  late List<RicochetPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get playerRobots => [for (final p in ps) p.robots];
  List<List<Map<String, int>>> get playerMoves => [for (final p in ps) p.moves];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a5Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 850, 2 => 320, _ => 550 };

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
    totalRounds = setup.opt<int>('rounds', 5) == 3 ? 3 : 5;
    size = setup.opt<int>('size', 10) == 12 ? 12 : 10;
    final (w, pockets) = RicochetSolver.buildBoard(size, rng);
    walls = w;
    pocketCells = pockets;

    // Place 4 initial robots on distinct random cells
    final allCells = [for (var i = 0; i < size * size; i++) i]..shuffle(rng);
    mainRobots = allCells.sublist(0, 4);

    ps = [for (var s = 0; s < players; s++) RicochetPlayer(mainRobots)];
    host.log('弹射机器人开始（$size×$size 棋盘，共 $totalRounds 局）！规划最短弹射路径将目标机器人送达终点！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    final (tRobot, tCell, sol, endRobots) = RicochetSolver.pickTarget(
      walls,
      size,
      mainRobots,
      pocketCells,
      rng,
      usedTargets: _usedTargets,
    );
    targetRobot = tRobot;
    targetCell = tCell;
    currentSolution = sol;
    currentSolutionEndRobots = endRobots;
    _usedTargets.add((tRobot << 8) | tCell);

    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(mainRobots);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本局时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a5Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'next') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.status != 'play') throw GameError('你已完成本局');

    switch (type) {
      case 'slide':
        final r = asInt(a['robot']);
        final dir = asInt(a['dir']);
        if (r < 0 || r >= 4) throw GameError('机器人编号无效');
        if (dir < 0 || dir >= 4) throw GameError('滑行方向无效');
        final dest = RicochetSolver.slide(walls, size, p.robots, r, dir);
        if (dest == p.robots[r]) {
          throw GameError('该方向已被墙壁或机器人阻挡');
        }
        p.pushHistory();
        p.robots[r] = dest;
        p.moves.add({'robot': r, 'dir': dir});
        moves++;
        if (p.robots[targetRobot] == targetCell) {
          _markSolved(seat);
        }

      case 'solve':
        final rawMoves = a['moves'];
        if (rawMoves is! List || rawMoves.isEmpty || rawMoves.length > 30) {
          throw GameError('提交的移动序列无效');
        }
        final simRobots = List<int>.of(mainRobots);
        final parsed = <Map<String, int>>[];
        for (final m in rawMoves) {
          if (m is! Map) throw GameError('步骤格式错误');
          final r = asInt(m['robot']);
          final dir = asInt(m['dir']);
          if (r < 0 || r >= 4 || dir < 0 || dir >= 4) {
            throw GameError('步骤参数无效');
          }
          final dest = RicochetSolver.slide(walls, size, simRobots, r, dir);
          if (dest == simRobots[r]) {
            throw GameError('步骤中包含无效的原地滑行');
          }
          simRobots[r] = dest;
          parsed.add({'robot': r, 'dir': dir});
        }
        if (simRobots[targetRobot] != targetCell) {
          throw GameError('该路线未能将目标机器人送达终点');
        }
        p.pushHistory();
        p.robots = simRobots;
        p.moves = parsed;
        moves++;
        _markSolved(seat);

      case 'undo':
        if (p.history.isEmpty) throw GameError('没有可撤销的步骤');
        p.popHistory();
        moves++;

      case 'reset':
        p.resetWorkspace(mainRobots);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 局');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    p.status = 'solved';
    p.solveSec = roundSec;
    host.log('${name(seat)} 用 ${p.moves.length} 步到达目标！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 局');
    }
  }

  void _endRound(String reason) {
    final solvedSeats = [
      for (var s = 0; s < players; s++)
        if (ps[s].status == 'solved') s,
    ];

    int? minMoves;
    int? winningSeat;
    for (final s in solvedSeats) {
      final len = ps[s].moves.length;
      if (minMoves == null || len < minMoves) {
        minMoves = len;
        winningSeat = s;
      }
    }

    final bestSeats = <int>[];
    for (var s = 0; s < players; s++) {
      final p = ps[s];
      if (p.status == 'solved' && minMoves != null) {
        if (p.moves.length == minMoves) {
          p.lastRoundPts = 2;
          bestSeats.add(s);
        } else {
          p.lastRoundPts = 1;
        }
        p.score += p.lastRoundPts;
        p.solvedCount++;
        p.totalMoves += p.moves.length;
      } else {
        p.lastRoundPts = 0;
      }
    }

    // Update main board robots to the winning solution's final positions
    if (winningSeat != null) {
      mainRobots = List<int>.of(ps[winningSeat].robots);
    } else if (currentSolutionEndRobots.length == 4) {
      mainRobots = List<int>.of(currentSolutionEndRobots);
    }

    lastRoundSummary = {
      'round': round,
      'reason': reason,
      'targetRobot': targetRobot,
      'targetCell': targetCell,
      'minMoves': minMoves ?? currentSolution.length,
      'bestSeats': bestSeats,
      'sol': currentSolution,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'moves': ps[s].moves.length,
            'pts': ps[s].lastRoundPts,
          },
      ],
    };

    if (bestSeats.isNotEmpty) {
      final names = [for (final s in bestSeats) name(s)].join('、');
      host.log('第 $round 局结算：$names 以最少 $minMoves 步获 +2 分！');
    } else {
      host.log('第 $round 局结算：无人解出（参考最短路径 ${currentSolution.length} 步）。');
    }

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 局已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a5Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalMoves - pb.totalMoves;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'moves': ps[s].totalMoves,
        });
    host.log('游戏结束（$why）！冠军：${a5Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];

    // Easy bot occasionally gives up or takes an extra slide at round start
    if (botLevel <= 0 && p.moves.isEmpty && rng.nextInt(7) == 0) {
      return {'type': 'pass'};
    }

    // Check if player's current robot positions match prefix k of currentSolution
    final k = p.moves.length;
    if (k < currentSolution.length) {
      final sim = List<int>.of(mainRobots);
      var prefixMatch = true;
      for (var i = 0; i < k; i++) {
        if (p.moves[i]['robot'] != currentSolution[i]['robot'] ||
            p.moves[i]['dir'] != currentSolution[i]['dir']) {
          prefixMatch = false;
          break;
        }
        final r = currentSolution[i]['robot']!;
        final d = currentSolution[i]['dir']!;
        sim[r] = RicochetSolver.slide(walls, size, sim, r, d);
      }
      if (prefixMatch &&
          sim[0] == p.robots[0] &&
          sim[1] == p.robots[1] &&
          sim[2] == p.robots[2] &&
          sim[3] == p.robots[3]) {
        final nextMove = currentSolution[k];
        return {'type': 'slide', 'robot': nextMove['robot'], 'dir': nextMove['dir']};
      }
    }

    // Otherwise try solving from current state or reset back to mainRobots
    final subSol = RicochetSolver.solve(walls, size, p.robots, targetRobot, targetCell, maxDepth: 4, maxStates: 4000);
    if (subSol != null && subSol.isNotEmpty) {
      return {'type': 'slide', 'robot': subSol.first['robot'], 'dir': subSol.first['dir']};
    }
    if (p.moves.isNotEmpty) {
      return {'type': 'reset'};
    }
    if (currentSolution.isNotEmpty) {
      return {'type': 'solve', 'moves': currentSolution};
    }
    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : null;
    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'walls': walls,
      'mainRobots': mainRobots,
      'targetRobot': targetRobot,
      'targetCell': targetCell,
      'parMoves': currentSolution.length,
      'robots': me?.robots ?? mainRobots,
      'moves': me?.moves ?? const <Map<String, int>>[],
      'canUndo': me != null && me.history.isNotEmpty && me.status == 'play' && !over,
      'canReset': me != null && me.moves.isNotEmpty && me.status == 'play' && !over,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'solved': ps[s].solvedCount,
            'status': ps[s].status,
            'moves': ps[s].moves.length,
            'pts': ps[s].lastRoundPts,
            'totalMoves': ps[s].totalMoves,
          },
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class RicochetPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalMoves = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int lastRoundPts = 0;
  int solveSec = 0;
  List<int> robots;
  List<Map<String, int>> moves = [];
  final List<(List<int>, List<Map<String, int>>)> history = [];

  RicochetPlayer(List<int> initialRobots) : robots = List<int>.of(initialRobots);

  void resetForRound(List<int> mainRobots) {
    if (resignNo == 0) status = 'play';
    solveSec = 0;
    resetWorkspace(mainRobots);
  }

  void resetWorkspace(List<int> mainRobots) {
    robots = List<int>.of(mainRobots);
    moves = [];
    history.clear();
  }

  void pushHistory() {
    history.add((List<int>.of(robots), [for (final m in moves) Map<String, int>.of(m)]));
  }

  void popHistory() {
    if (history.isEmpty) return;
    final (prevRobots, prevMoves) = history.removeLast();
    robots = prevRobots;
    moves = prevMoves;
  }
}
