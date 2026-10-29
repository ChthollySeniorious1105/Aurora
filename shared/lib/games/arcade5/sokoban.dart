import '../../src/engine.dart';
import 'a5_util.dart';

class SokobanLevel {
  final int id;
  final String name;
  final int w;
  final int h;
  final List<String> rows;
  final List<int> solution; // 0:上, 1:右, 2:下, 3:左

  const SokobanLevel({
    required this.id,
    required this.name,
    required this.w,
    required this.h,
    required this.rows,
    required this.solution,
  });
}

/// 18 hand-verified classic compact Sokoban levels (7x7 to 9x9).
const List<SokobanLevel> sokobanLevels = [
  SokobanLevel(
    id: 1,
    name: '初出茅庐',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#..G..#',
      r'#..$..#',
      r'#G.$@.#',
      r'#.....#',
      r'#.....#',
      r'#######',
    ],
    solution: [3, 3, 1, 0],
  ),
  SokobanLevel(
    id: 2,
    name: '双箱回廊',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#G...G#',
      r'#.$@$.#',
      r'#.....#',
      r'#..#..#',
      r'#.....#',
      r'#######',
    ],
    solution: [3, 2, 3, 0, 1, 1, 1, 2, 1, 0],
  ),
  SokobanLevel(
    id: 3,
    name: '转角遇到箱',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#G....#',
      r'#.$...#',
      r'#..@..#',
      r'#...$.#',
      r'#....G#',
      r'#######',
    ],
    solution: [0, 3, 2, 3, 0, 2, 1, 1, 1, 2, 3, 2, 1],
  ),
  SokobanLevel(
    id: 4,
    name: '三箱齐发',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#G.G.G#',
      r'#$.$.$#',
      r'#..@..#',
      r'#.....#',
      r'#.....#',
      r'#######',
    ],
    solution: [0, 2, 3, 3, 0, 2, 1, 1, 1, 1, 0],
  ),
  SokobanLevel(
    id: 5,
    name: '十字枢纽',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#..G..#',
      r'#..$..#',
      r'#G$@$G#',
      r'#..$..#',
      r'#..G..#',
      r'#######',
    ],
    solution: [0, 2, 2, 0, 3, 1, 1],
  ),
  SokobanLevel(
    id: 6,
    name: '对称仓库',
    w: 8,
    h: 7,
    rows: [
      r'########',
      r'#G....G#',
      r'#......#',
      r'#.$..$.#',
      r'#..@#..#',
      r'#......#',
      r'########',
    ],
    solution: [0, 3, 2, 3, 0, 0, 1, 1, 1, 2, 1, 2, 1, 0, 0],
  ),
  SokobanLevel(
    id: 7,
    name: '中庭迂回',
    w: 8,
    h: 8,
    rows: [
      r'########',
      r'#......#',
      r'#.G..G.#',
      r'#.#..#.#',
      r'#.$..$.#',
      r'#..@...#',
      r'#......#',
      r'########',
    ],
    solution: [
      3, 3, 0, 1, 2, 1, 0, 0, 1, 0, 3, // first box to (2,2)
      2, 2, 2, 1, 1, 1, 0, 3, 2, 3, 0, 0, 3, 0, 1, // second box to (2,5)
    ],
  ),
  SokobanLevel(
    id: 8,
    name: '双门通道',
    w: 8,
    h: 7,
    rows: [
      r'########',
      r'#.G..G.#',
      r'#.#..#.#',
      r'#..$$..#',
      r'#..@...#',
      r'#......#',
      r'########',
    ],
    solution: [0, 0, 1, 0, 3, 2, 2, 2, 1, 0, 0, 3, 0, 1],
  ),
  SokobanLevel(
    id: 9,
    name: '步步为营',
    w: 7,
    h: 8,
    rows: [
      r'#######',
      r'#..G..#',
      r'#.G.G.#',
      r'#..$..#',
      r'#.$@$.#',
      r'#.....#',
      r'#.....#',
      r'#######',
    ],
    solution: [0, 0, 2, 2, 2, 3, 0, 0, 2, 1, 2, 1, 0, 0],
  ),
  SokobanLevel(
    id: 10,
    name: '回字迷宫',
    w: 8,
    h: 8,
    rows: [
      r'########',
      r'#G....G#',
      r'#.$..$.#',
      r'#..##..#',
      r'#..##..#',
      r'#..$...#',
      r'#..@.G.#',
      r'########',
    ],
    solution: [3, 0, 1, 1, 3, 3, 0, 0, 0, 1, 0, 3, 1, 1, 2, 1, 2, 1, 0, 2, 2, 3, 2],
  ),
  SokobanLevel(
    id: 11,
    name: '四角归位',
    w: 7,
    h: 7,
    rows: [
      r'#######',
      r'#G...G#',
      r'#.$@$.#',
      r'#.....#',
      r'#.$.$.#',
      r'#G...G#',
      r'#######',
    ],
    solution: [3, 2, 3, 0, 1, 1, 1, 2, 1, 0, 2, 3, 3, 2, 3, 0, 3, 2, 1, 1, 1, 0, 1, 2],
  ),
  SokobanLevel(
    id: 12,
    name: '狭路相逢',
    w: 8,
    h: 7,
    rows: [
      r'########',
      r'#G.G.G.#',
      r'#.$....#',
      r'#..$...#',
      r'#...$..#',
      r'#....@.#',
      r'########',
    ],
    solution: [3, 3, 0, 1, 2, 1, 0, 0, 0, 2, 2, 3, 3, 0, 0, 3, 2, 3, 0],
  ),
  SokobanLevel(
    id: 13,
    name: '双翼展开',
    w: 9,
    h: 7,
    rows: [
      r'#########',
      r'#G..G..G#',
      r'#.......#',
      r'#..$.$..#',
      r'#...$...#',
      r'#...@...#',
      r'#########',
    ],
    solution: [0, 0, 0, 2, 3, 3, 2, 3, 0, 0, 2, 1, 1, 1, 1, 1, 2, 1, 0, 0],
  ),
  SokobanLevel(
    id: 14,
    name: '石柱迷阵',
    w: 9,
    h: 8,
    rows: [
      r'#########',
      r'#G.G.G..#',
      r'#.......#',
      r'#.#.#.#.#',
      r'#.$.$.$.#',
      r'#...@...#',
      r'#.......#',
      r'#########',
    ],
    solution: [
      3, 0, 3, 2, 3, 0, 0, 0, // left box to (1,1)
      2, 2, 2, 1, 1, 1, 1, 0, 3, 2, 3, 0, 0, 0, // center box to (1,3)
      2, 2, 2, 1, 1, 1, 1, 0, 3, 2, 3, 0, 0, 0, // right box to (1,5)
    ],
  ),
  SokobanLevel(
    id: 15,
    name: '曲径通幽',
    w: 8,
    h: 8,
    rows: [
      r'########',
      r'#G.....#',
      r'#..#...#',
      r'#.$....#',
      r'#..@#..#',
      r'#....$.#',
      r'#.....G#',
      r'########',
    ],
    solution: [0, 3, 2, 3, 0, 0, 2, 2, 1, 1, 2, 1, 1, 0, 1, 2],
  ),
  SokobanLevel(
    id: 16,
    name: '三岔路口',
    w: 8,
    h: 8,
    rows: [
      r'########',
      r'#..G...#',
      r'#..$...#',
      r'#G$@$G.#',
      r'#......#',
      r'#..##..#',
      r'#......#',
      r'########',
    ],
    solution: [0, 2, 3, 1, 1],
  ),
  SokobanLevel(
    id: 17,
    name: '平行推进',
    w: 8,
    h: 8,
    rows: [
      r'########',
      r'#G.GG.G#',
      r'#$.$$.$#',
      r'#..@...#',
      r'#......#',
      r'#.#..#.#',
      r'#......#',
      r'########',
    ],
    solution: [0, 2, 1, 0, 2, 1, 1, 0, 2, 3, 3, 3, 3, 3, 0],
  ),
  SokobanLevel(
    id: 18,
    name: '终极调度',
    w: 9,
    h: 9,
    rows: [
      r'#########',
      r'#...G...#',
      r'#...$...#',
      r'#.......#',
      r'#G$.@.$G#',
      r'#.......#',
      r'#...$...#',
      r'#...G...#',
      r'#########',
    ],
    solution: [0, 0, 2, 2, 2, 2, 0, 0, 3, 3, 1, 1, 1, 1],
  ),
];

class ParsedWarehouse {
  final int w;
  final int h;
  final List<bool> walls;
  final Set<int> goals;
  final int initialWorker;
  final List<int> initialBoxes;
  final int parSteps;
  final int parPushes;

  ParsedWarehouse({
    required this.w,
    required this.h,
    required this.walls,
    required this.goals,
    required this.initialWorker,
    required this.initialBoxes,
    required this.parSteps,
    required this.parPushes,
  });
}

class SokobanSolver {
  static const dr = [-1, 0, 1, 0];
  static const dc = [0, 1, 0, -1];

  static ParsedWarehouse parse(SokobanLevel lvl) {
    final w = lvl.w, h = lvl.h;
    final walls = List<bool>.filled(w * h, false);
    final goals = <int>{};
    final boxes = <int>[];
    var worker = 0;

    for (var r = 0; r < h; r++) {
      final row = lvl.rows[r];
      for (var c = 0; c < w; c++) {
        final idx = r * w + c;
        switch (row[c]) {
          case '#':
            walls[idx] = true;
          case 'G':
            goals.add(idx);
          case r'$':
            boxes.add(idx);
          case '*':
            goals.add(idx);
            boxes.add(idx);
          case '@':
            worker = idx;
          case '+':
            goals.add(idx);
            worker = idx;
        }
      }
    }

    // Compute parPushes from precomputed solution
    var curW = worker;
    final curBoxes = List<int>.of(boxes);
    var pushes = 0;
    for (final dir in lvl.solution) {
      final res = step(w, h, walls, curW, curBoxes, dir);
      if (res != null) {
        curW = res.$1;
        if (res.$2) pushes++;
      }
    }

    return ParsedWarehouse(
      w: w,
      h: h,
      walls: walls,
      goals: goals,
      initialWorker: worker,
      initialBoxes: boxes..sort(),
      parSteps: lvl.solution.length,
      parPushes: pushes,
    );
  }

  /// Attempts to move worker at [worker] in direction [dir] (0..3), mutating [boxes] in-place if pushed.
  /// Returns `(newWorker, pushedBox)` or `null` if blocked.
  static (int, bool)? step(
    int w,
    int h,
    List<bool> walls,
    int worker,
    List<int> boxes,
    int dir,
  ) {
    if (dir < 0 || dir >= 4) return null;
    final nr = (worker ~/ w) + dr[dir];
    final nc = (worker % w) + dc[dir];
    if (nr < 0 || nr >= h || nc < 0 || nc >= w) return null;
    final next = nr * w + nc;
    if (walls[next]) return null;

    final boxIdx = boxes.indexOf(next);
    if (boxIdx < 0) {
      return (next, false);
    }

    final br = nr + dr[dir];
    final bc = nc + dc[dir];
    if (br < 0 || br >= h || bc < 0 || bc >= w) return null;
    final behind = br * w + bc;
    if (walls[behind] || boxes.contains(behind)) return null;

    boxes[boxIdx] = behind;
    boxes.sort();
    return (next, true);
  }

  static bool allOnGoals(List<int> boxes, Set<int> goals) =>
      boxes.every(goals.contains);

  /// Verifies that [lvl]'s precomputed [lvl.solution] is 100% legal and ends
  /// with all boxes on goal squares.
  static bool verifyLevel(SokobanLevel lvl) {
    if (lvl.rows.length != lvl.h) return false;
    if (lvl.rows.any((r) => r.length != lvl.w)) return false;
    final pw = parse(lvl);
    if (pw.initialBoxes.isEmpty || pw.initialBoxes.length != pw.goals.length) return false;
    var worker = pw.initialWorker;
    final boxes = List<int>.of(pw.initialBoxes);
    for (final dir in lvl.solution) {
      final res = step(pw.w, pw.h, pw.walls, worker, boxes, dir);
      if (res == null) return false;
      worker = res.$1;
    }
    return allOnGoals(boxes, pw.goals);
  }
}

/// 推箱子竞速 (Sokoban Race, 1-6 人).
class SokobanGame extends GameEngine {
  SokobanGame(super.setup);

  static const roundMaxSec = 400;

  late int totalRounds;
  late List<SokobanLevel> matchLevels;

  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late SokobanLevel currentLevel;
  late ParsedWarehouse currentWarehouse;
  late List<SokobanPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a5Placings(ranking, players) : null;

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
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;
    final pool = List<SokobanLevel>.of(sokobanLevels)..shuffle(rng);
    matchLevels = pool.sublist(0, totalRounds);

    currentLevel = matchLevels[0];
    currentWarehouse = SokobanSolver.parse(currentLevel);
    ps = [for (var s = 0; s < players; s++) SokobanPlayer(currentWarehouse)];

    host.log('推箱子竞速开始（共 $totalRounds 关）！将所有箱子推到绿色目标点即可过关，越快完成且步数越少得分越高！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    currentLevel = matchLevels[r - 1];
    currentWarehouse = SokobanSolver.parse(currentLevel);

    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(currentWarehouse);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本关时间到');
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
    if (p.status != 'play') throw GameError('你已完成本关');

    final pw = currentWarehouse;

    switch (type) {
      case 'move':
        final dir = asInt(a['dir']);
        if (dir < 0 || dir >= 4) throw GameError('移动方向无效');
        final nr = (p.worker ~/ pw.w) + SokobanSolver.dr[dir];
        final nc = (p.worker % pw.w) + SokobanSolver.dc[dir];
        if (nr < 0 || nr >= pw.h || nc < 0 || nc >= pw.w) {
          throw GameError('超出仓库边界');
        }
        final next = nr * pw.w + nc;
        if (pw.walls[next]) {
          throw GameError('前方是墙壁，无法通行');
        }
        final boxIdx = p.boxes.indexOf(next);
        if (boxIdx >= 0) {
          final br = nr + SokobanSolver.dr[dir];
          final bc = nc + SokobanSolver.dc[dir];
          if (br < 0 || br >= pw.h || bc < 0 || bc >= pw.w) {
            throw GameError('箱子前方是边界，无法推动');
          }
          final behind = br * pw.w + bc;
          if (pw.walls[behind] || p.boxes.contains(behind)) {
            throw GameError('箱子前方受阻，无法推动');
          }
          p.pushHistory();
          p.boxes[boxIdx] = behind;
          p.boxes.sort();
          p.worker = next;
          p.steps++;
          p.pushes++;
          p.moveLog.add(dir);
        } else {
          p.pushHistory();
          p.worker = next;
          p.steps++;
          p.moveLog.add(dir);
        }
        moves++;
        if (SokobanSolver.allOnGoals(p.boxes, pw.goals)) {
          _markSolved(seat);
        }

      case 'undo':
        if (p.history.isEmpty) throw GameError('没有可撤销的步骤');
        p.popHistory();
        moves++;

      case 'reset':
        p.resetWorkspace(pw);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 关「${currentLevel.name}」');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    final pw = currentWarehouse;
    roundSolvers++;
    final basePts = switch (roundSolvers) {
      1 => 10,
      2 => 8,
      3 => 6,
      _ => 4,
    };
    final bonus = (p.pushes <= pw.parPushes && p.steps <= pw.parSteps)
        ? 2
        : (p.pushes <= pw.parPushes + 2 ? 1 : 0);
    final pts = basePts + bonus;

    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSteps += p.steps;
    p.totalPushes += p.pushes;
    host.log('${name(seat)} 第 $roundSolvers 个通关「${currentLevel.name}」（${p.steps}步/${p.pushes}推），+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 关');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'levelName': currentLevel.name,
      'reason': reason,
      'parSteps': currentWarehouse.parSteps,
      'parPushes': currentWarehouse.parPushes,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'steps': ps[s].steps,
            'pushes': ps[s].pushes,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
          },
      ],
    };

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 关已完成');
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
      if (pa.totalPushes != pb.totalPushes) return pa.totalPushes - pb.totalPushes;
      return pa.totalSteps - pb.totalSteps;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'steps': ps[s].totalSteps,
          'pushes': ps[s].totalPushes,
        });
    host.log('游戏结束（$why）！冠军：${a5Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final sol = currentLevel.solution;

    // Easy bot occasionally gives up at the start of a level
    if (botLevel <= 0 && p.moveLog.isEmpty && rng.nextInt(8) == 0) {
      return {'type': 'pass'};
    }

    // Check if player's moveLog is a clean prefix of the level's verified solution
    final k = p.moveLog.length;
    if (k < sol.length) {
      var matchesPrefix = true;
      for (var i = 0; i < k; i++) {
        if (p.moveLog[i] != sol[i]) {
          matchesPrefix = false;
          break;
        }
      }
      if (matchesPrefix) {
        return {'type': 'move', 'dir': sol[k]};
      }
    }

    // If a human player diverged from the solution before bot took over, reset once
    if (p.moveLog.isNotEmpty) {
      return {'type': 'reset'};
    }
    return sol.isNotEmpty ? {'type': 'move', 'dir': sol[0]} : {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final pw = currentWarehouse;
    final boxes = me?.boxes ?? pw.initialBoxes;
    final boxesOnGoal = boxes.where(pw.goals.contains).length;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'levelId': currentLevel.id,
      'levelName': currentLevel.name,
      'w': pw.w,
      'h': pw.h,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'walls': [for (var i = 0; i < pw.walls.length; i++) if (pw.walls[i]) i],
      'goals': pw.goals.toList()..sort(),
      'worker': me?.worker ?? pw.initialWorker,
      'boxes': boxes,
      'steps': me?.steps ?? 0,
      'pushes': me?.pushes ?? 0,
      'parSteps': pw.parSteps,
      'parPushes': pw.parPushes,
      'boxesOnGoal': boxesOnGoal,
      'totalBoxes': pw.goals.length,
      'canUndo': me != null && me.history.isNotEmpty && me.status == 'play' && !over,
      'canReset': me != null && me.steps > 0 && me.status == 'play' && !over,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'solved': ps[s].solvedCount,
            'status': ps[s].status,
            'steps': ps[s].steps,
            'pushes': ps[s].pushes,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
            'doneBoxes': ps[s].boxes.where(pw.goals.contains).length,
            'totalBoxes': pw.goals.length,
          },
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class SokobanPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSteps = 0;
  int totalPushes = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;

  late int worker;
  late List<int> boxes;
  int steps = 0;
  int pushes = 0;
  final List<int> moveLog = [];
  final List<(int, List<int>, int, int, int)> history = [];

  SokobanPlayer(ParsedWarehouse pw) {
    resetWorkspace(pw);
  }

  void resetForRound(ParsedWarehouse pw) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    resetWorkspace(pw);
  }

  void resetWorkspace(ParsedWarehouse pw) {
    worker = pw.initialWorker;
    boxes = List<int>.of(pw.initialBoxes);
    steps = 0;
    pushes = 0;
    moveLog.clear();
    history.clear();
  }

  void pushHistory() {
    history.add((worker, List<int>.of(boxes), steps, pushes, moveLog.length));
  }

  void popHistory() {
    if (history.isEmpty) return;
    final (prevW, prevBoxes, prevSteps, prevPushes, prevLogLen) = history.removeLast();
    worker = prevW;
    boxes = prevBoxes;
    steps = prevSteps;
    pushes = prevPushes;
    if (moveLog.length > prevLogLen) {
      moveLog.removeRange(prevLogLen, moveLog.length);
    }
  }
}
