import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a14_util.dart';

class ShingokiPuzzle {
  final int size;
  /// `size × size` vertex grid of Traffic Light Clues: `null` if not a clue vertex,
  /// or `{'color': 'W'|'B', 'len': k}` (`k >= 2`).
  final List<List<Map<String, dynamic>?>> clues;
  /// `size × (size - 1)` horizontal loop segments (`0` or `1`).
  final List<List<int>> solutionHSegs;
  /// `(size - 1) × size` vertical loop segments (`0` or `1`).
  final List<List<int>> solutionVSegs;

  const ShingokiPuzzle({
    required this.size,
    required this.clues,
    required this.solutionHSegs,
    required this.solutionVSegs,
  });

  List<Map<String, dynamic>?> get cluesFlat => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) clues[r][c],
      ];

  List<List<int>> get initialHSegs => [
        for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
      ];

  List<List<int>> get initialVSegs => [
        for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
      ];
}

class ShingokiAnalysis {
  final Set<int> satisfiedClues;
  final Set<int> violatedClues;
  final Set<int> unvisitedClues;
  final Set<int> badDegreeVertices;
  final List<int> clueRaySums;
  final int totalClues;
  final int activeSegCount;
  final int componentCount;
  final bool isSingleLoop;

  const ShingokiAnalysis({
    required this.satisfiedClues,
    required this.violatedClues,
    required this.unvisitedClues,
    required this.badDegreeVertices,
    required this.clueRaySums,
    required this.totalClues,
    required this.activeSegCount,
    required this.componentCount,
    required this.isSingleLoop,
  });

  bool get isSolved =>
      totalClues > 0 &&
      satisfiedClues.length == totalClues &&
      violatedClues.isEmpty &&
      unvisitedClues.isEmpty &&
      badDegreeVertices.isEmpty &&
      isSingleLoop;
}

class ShingokiSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool hasEdgeInDir(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
    int r,
    int c,
    int dir,
  ) {
    if (r < 0 || r >= size || c < 0 || c >= size) return false;
    switch (dir) {
      case 0: // Up
        return r > 0 &&
            r - 1 < vSegs.length &&
            c < vSegs[r - 1].length &&
            vSegs[r - 1][c] == 1;
      case 1: // Right
        return c < size - 1 &&
            r < hSegs.length &&
            c < hSegs[r].length &&
            hSegs[r][c] == 1;
      case 2: // Down
        return r < size - 1 &&
            r < vSegs.length &&
            c < vSegs[r].length &&
            vSegs[r][c] == 1;
      case 3: // Left
        return c > 0 &&
            r < hSegs.length &&
            c - 1 < hSegs[r].length &&
            hSegs[r][c - 1] == 1;
      default:
        return false;
    }
  }

  static List<int> incidentDirs(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
    int r,
    int c,
  ) =>
      [
        for (var d = 0; d < 4; d++)
          if (hasEdgeInDir(size, hSegs, vSegs, r, c, d)) d,
      ];

  /// Computes the length of the straight ray of active edges starting at `(r, c)`
  /// in direction `dir` (`0: 上, 1: 右, 2: 下, 3: 左`).
  static int rayLength(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
    int r,
    int c,
    int dir,
  ) {
    var len = 0;
    var cr = r;
    var cc = c;
    while (hasEdgeInDir(size, hSegs, vSegs, cr, cc, dir)) {
      len++;
      cr += orthoDr[dir];
      cc += orthoDc[dir];
    }
    return len;
  }

  static ShingokiAnalysis analyze(
    ShingokiPuzzle puz,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final size = puz.size;
    final n = size * size;
    final satisfiedClues = <int>{};
    final violatedClues = <int>{};
    final unvisitedClues = <int>{};
    final badDegreeVertices = <int>{};
    final clueRaySums = List<int>.filled(n, 0);

    final neighbors = [for (var i = 0; i < n; i++) <int>[]];
    var activeSegCount = 0;

    for (var r = 0; r < size; r++) {
      final row = r < hSegs.length ? hSegs[r] : const <int>[];
      for (var c = 0; c < size - 1; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = r * size + (c + 1);
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      final row = r < vSegs.length ? vSegs[r] : const <int>[];
      for (var c = 0; c < size; c++) {
        if (c < row.length && row[c] == 1) {
          activeSegCount++;
          final a = r * size + c;
          final b = (r + 1) * size + c;
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    for (var i = 0; i < n; i++) {
      final deg = neighbors[i].length;
      if (deg != 0 && deg != 2) {
        badDegreeVertices.add(i);
      }
    }

    final visited = List<bool>.filled(n, false);
    var componentCount = 0;
    for (var i = 0; i < n; i++) {
      if (neighbors[i].isEmpty || visited[i]) continue;
      componentCount++;
      final q = Queue<int>()..add(i);
      visited[i] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        for (final nxt in neighbors[cur]) {
          if (!visited[nxt]) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }

    final isSingleLoop = activeSegCount >= 4 &&
        badDegreeVertices.isEmpty &&
        componentCount == 1;

    var totalClues = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final clue = puz.clues[r][c];
        if (clue == null) continue;
        totalClues++;
        final idx = r * size + c;
        final color = asStr(clue['color'], 'B');
        final targetLen = asInt(clue['len'], 2);
        final dirs = incidentDirs(size, hSegs, vSegs, r, c);

        if (dirs.isEmpty) {
          unvisitedClues.add(idx);
          continue;
        }
        if (dirs.length != 2) {
          for (final d in dirs) {
            clueRaySums[idx] += rayLength(size, hSegs, vSegs, r, c, d);
          }
          violatedClues.add(idx);
          continue;
        }

        final d1 = dirs[0], d2 = dirs[1];
        final isStraight = (d1 + 2) % 4 == d2;
        final len1 = rayLength(size, hSegs, vSegs, r, c, d1);
        final len2 = rayLength(size, hSegs, vSegs, r, c, d2);
        final sumLen = len1 + len2;
        clueRaySums[idx] = sumLen;

        final colorMatches = color == 'W' ? isStraight : !isStraight;
        if (colorMatches && sumLen == targetLen) {
          satisfiedClues.add(idx);
        } else {
          violatedClues.add(idx);
        }
      }
    }

    return ShingokiAnalysis(
      satisfiedClues: satisfiedClues,
      violatedClues: violatedClues,
      unvisitedClues: unvisitedClues,
      badDegreeVertices: badDegreeVertices,
      clueRaySums: clueRaySums,
      totalClues: totalClues,
      activeSegCount: activeSegCount,
      componentCount: componentCount,
      isSingleLoop: isSingleLoop,
    );
  }

  static bool isSolved(
    ShingokiPuzzle puz,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) =>
      analyze(puz, hSegs, vSegs).isSolved;

  static (List<List<int>>, List<List<int>>) _boundarySegmentsFromFaces(
    int size,
    List<List<bool>> faces,
  ) {
    final fSize = size - 1;
    final hSegs = [
      for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0),
    ];
    final vSegs = [
      for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0),
    ];

    bool faceAt(int fr, int fc) {
      if (fr < 0 || fr >= fSize || fc < 0 || fc >= fSize) return false;
      return faces[fr][fc];
    }

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (faceAt(r - 1, c) != faceAt(r, c)) {
          hSegs[r][c] = 1;
        }
      }
    }

    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (faceAt(r, c - 1) != faceAt(r, c)) {
          vSegs[r][c] = 1;
        }
      }
    }

    return (hSegs, vSegs);
  }

  static (List<int>, bool) _loopVerticesIfValid(
    int size,
    List<List<int>> hSegs,
    List<List<int>> vSegs,
  ) {
    final n = size * size;
    final neighbors = [for (var i = 0; i < n; i++) <int>[]];
    var segCount = 0;

    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (hSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = r * size + (c + 1);
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (vSegs[r][c] == 1) {
          segCount++;
          final a = r * size + c, b = (r + 1) * size + c;
          neighbors[a].add(b);
          neighbors[b].add(a);
        }
      }
    }

    if (segCount < 8) return (const [], false);

    final loopVertices = <int>[];
    for (var i = 0; i < n; i++) {
      final deg = neighbors[i].length;
      if (deg == 2) {
        loopVertices.add(i);
      } else if (deg != 0) {
        return (const [], false);
      }
    }
    if (loopVertices.isEmpty) return (const [], false);

    final vis = List<bool>.filled(n, false);
    final q = Queue<int>()..add(loopVertices.first);
    vis[loopVertices.first] = true;
    var visitedCount = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      visitedCount++;
      for (final nxt in neighbors[cur]) {
        if (!vis[nxt]) {
          vis[nxt] = true;
          q.add(nxt);
        }
      }
    }
    return (loopVertices, visitedCount == loopVertices.length);
  }

  /// Generates a guaranteed-valid Shingoki puzzle for [size] (`5` or `6`).
  static ShingokiPuzzle generatePuzzle(int size, Random rng) {
    final fSize = size - 1;
    final faces = [
      for (var r = 0; r < fSize; r++) List<bool>.filled(fSize, true),
    ];

    final targetCarves = size <= 5 ? (2 + rng.nextInt(4)) : (3 + rng.nextInt(5));
    var carved = 0;

    for (var step = 0; step < 18 && carved < targetCarves; step++) {
      final candidates = <(int, int)>[];
      for (var r = 0; r < fSize; r++) {
        for (var c = 0; c < fSize; c++) {
          if (!faces[r][c]) continue;
          final onBoundary = r == 0 ||
              r == fSize - 1 ||
              c == 0 ||
              c == fSize - 1 ||
              !faces[r - 1][c] ||
              !faces[r + 1][c] ||
              !faces[r][c - 1] ||
              !faces[r][c + 1];
          if (onBoundary) candidates.add((r, c));
        }
      }
      if (candidates.length <= 4) break;
      candidates.shuffle(rng);

      for (final (fr, fc) in candidates) {
        faces[fr][fc] = false;
        final (candH, candV) = _boundarySegmentsFromFaces(size, faces);
        final (loopVerts, validLoop) = _loopVerticesIfValid(size, candH, candV);
        if (validLoop && loopVerts.length >= size * 2) {
          carved++;
          break;
        } else {
          faces[fr][fc] = true;
        }
      }
    }

    final (solH, solV) = _boundarySegmentsFromFaces(size, faces);
    final (loopVerts, _) = _loopVerticesIfValid(size, solH, solV);

    final whiteCandidates = <int>[];
    final blackCandidates = <int>[];

    for (final idx in loopVerts) {
      final r = idx ~/ size, c = idx % size;
      final dirs = incidentDirs(size, solH, solV, r, c);
      if (dirs.length != 2) continue;
      final isStraight = (dirs[0] + 2) % 4 == dirs[1];
      if (isStraight) {
        whiteCandidates.add(idx);
      } else {
        blackCandidates.add(idx);
      }
    }

    whiteCandidates.shuffle(rng);
    blackCandidates.shuffle(rng);

    final targetClues = size <= 5 ? 6 : 8;
    final selected = <int>{};

    // Ensure a good mix of 'W' (straight) and 'B' (turn) traffic light clues
    final wPick = min(whiteCandidates.length, targetClues ~/ 2);
    for (var i = 0; i < wPick; i++) {
      selected.add(whiteCandidates[i]);
    }
    for (final idx in blackCandidates) {
      if (selected.length >= targetClues) break;
      selected.add(idx);
    }
    for (final idx in whiteCandidates) {
      if (selected.length >= targetClues) break;
      selected.add(idx);
    }

    final clues = [
      for (var r = 0; r < size; r++)
        List<Map<String, dynamic>?>.filled(size, null),
    ];

    for (final idx in selected) {
      final r = idx ~/ size, c = idx % size;
      final dirs = incidentDirs(size, solH, solV, r, c);
      final d1 = dirs[0], d2 = dirs[1];
      final isStraight = (d1 + 2) % 4 == d2;
      final len1 = rayLength(size, solH, solV, r, c, d1);
      final len2 = rayLength(size, solH, solV, r, c, d2);
      clues[r][c] = {
        'color': isStraight ? 'W' : 'B',
        'len': len1 + len2,
      };
    }

    return ShingokiPuzzle(
      size: size,
      clues: clues,
      solutionHSegs: solH,
      solutionVSegs: solV,
    );
  }
}

/// 信号灯回路竞速 (Shingoki Race, 1-6 人).
class ShingokiGame extends GameEngine {
  ShingokiGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late ShingokiPuzzle currentPuzzle;
  late List<ShingokiPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a14Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 220, _ => 420 };

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

    currentPuzzle = ShingokiSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) ShingokiPlayer(size)];

    host.log('信号灯回路竞速开始（$size×$size 格点，共 $totalRounds 题）！白灯直行、黑灯转弯，两侧直段总长匹配信号灯数字！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = ShingokiSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size);
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
    return a14Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
      case 'edge':
      case 'seg':
        if (a.containsKey('r1') && a.containsKey('c1') && a.containsKey('r2') && a.containsKey('c2')) {
          final r1 = asInt(a['r1']), c1 = asInt(a['c1']);
          final r2 = asInt(a['r2']), c2 = asInt(a['c2']);
          if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size || r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) {
            throw GameError('线段端点超出棋盘范围');
          }
          if ((r1 - r2).abs() + (c1 - c2).abs() != 1) {
            throw GameError('只能在正交相邻的两个格点之间连线');
          }
          if (r1 == r2) {
            final mc = min(c1, c2);
            if (a.containsKey('val')) {
              p.hSegs[r1][mc] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.hSegs[r1][mc] = p.hSegs[r1][mc] == 1 ? 0 : 1;
            }
          } else {
            final mr = min(r1, r2);
            if (a.containsKey('val')) {
              p.vSegs[mr][c1] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.vSegs[mr][c1] = p.vSegs[mr][c1] == 1 ? 0 : 1;
            }
          }
        } else {
          final dir = asStr(a['dir'], 'h');
          final r = asInt(a['r']);
          final c = asInt(a['c']);
          if (dir == 'h') {
            if (r < 0 || r >= size || c < 0 || c >= size - 1) {
              throw GameError('水平线段坐标超出棋盘范围');
            }
            if (a.containsKey('val')) {
              p.hSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.hSegs[r][c] = p.hSegs[r][c] == 1 ? 0 : 1;
            }
          } else if (dir == 'v') {
            if (r < 0 || r >= size - 1 || c < 0 || c >= size) {
              throw GameError('垂直线段坐标超出棋盘范围');
            }
            if (a.containsKey('val')) {
              p.vSegs[r][c] = asInt(a['val']) != 0 ? 1 : 0;
            } else {
              p.vSegs[r][c] = p.vSegs[r][c] == 1 ? 0 : 1;
            }
          } else {
            throw GameError('线段方向必须为 h 或 v');
          }
        }
        moves++;
        if (ShingokiSolver.isSolved(currentPuzzle, p.hSegs, p.vSegs)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.clearAll();
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
    host.log('${name(seat)} 第 $roundSolvers 个解出信号灯回路谜题，+$pts 分！');
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
    ranking = a14Ranking(players, (a, b) {
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
    host.log('游戏结束（$why）！冠军：${a14Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;

    if (botLevel <= 0 && rng.nextInt(18) == 0) {
      return {'type': 'pass'};
    }

    final edgeDiffs = <Map<String, dynamic>>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size - 1; c++) {
        if (p.hSegs[r][c] != puz.solutionHSegs[r][c]) {
          edgeDiffs.add({
            'type': 'edge',
            'r1': r,
            'c1': c,
            'r2': r,
            'c2': c + 1,
          });
        }
      }
    }
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size; c++) {
        if (p.vSegs[r][c] != puz.solutionVSegs[r][c]) {
          edgeDiffs.add({
            'type': 'edge',
            'r1': r,
            'c1': c,
            'r2': r + 1,
            'c2': c,
          });
        }
      }
    }

    if (edgeDiffs.isNotEmpty) {
      return edgeDiffs[rng.nextInt(edgeDiffs.length)];
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myH = me?.hSegs ?? puz.initialHSegs;
    final myV = me?.vSegs ?? puz.initialVSegs;
    final an = ShingokiSolver.analyze(puz, myH, myV);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'clues': puz.clues,
      'cluesFlat': puz.cluesFlat,
      'totalClues': an.totalClues,
      'hSegs': [for (final r in myH) List<int>.of(r)],
      'vSegs': [for (final r in myV) List<int>.of(r)],
      'clueRaySums': an.clueRaySums,
      'satisfiedClues': an.satisfiedClues.toList()..sort(),
      'violatedClues': an.violatedClues.toList()..sort(),
      'unvisitedClues': an.unvisitedClues.toList()..sort(),
      'badDegreeVertices': an.badDegreeVertices.toList()..sort(),
      'satisfiedClueCount': an.satisfiedClues.length,
      'activeSegCount': an.activeSegCount,
      'componentCount': an.componentCount,
      'isSingleLoop': an.isSingleLoop,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = ShingokiSolver.analyze(puz, ps[s].hSegs, ps[s].vSegs);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClues': pAn.satisfiedClues.length,
              'totalClues': pAn.totalClues,
              'activeSegCount': pAn.activeSegCount,
              'isSingleLoop': pAn.isSingleLoop,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class ShingokiPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;

  List<List<int>> hSegs;
  List<List<int>> vSegs;

  ShingokiPlayer(int size)
      : hSegs = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)],
        vSegs = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];

  void clearAll() {
    for (final row in hSegs) {
      row.fillRange(0, row.length, 0);
    }
    for (final row in vSegs) {
      row.fillRange(0, row.length, 0);
    }
  }

  void resetForRound(int size) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    hSegs = [for (var r = 0; r < size; r++) List<int>.filled(size - 1, 0)];
    vSegs = [for (var r = 0; r < size - 1; r++) List<int>.filled(size, 0)];
  }
}
