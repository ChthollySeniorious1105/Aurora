import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a14_util.dart';

class HeyawakePuzzle {
  final int size;
  /// Rectangular rooms: `[{'id': id, 'r1': r1, 'c1': c1, 'r2': r2, 'c2': c2, 'clue': k}, ...]`.
  final List<Map<String, int>> rooms;
  /// `size × size` grid of Room IDs `0..rooms.length-1`.
  final List<List<int>> roomId;
  /// Flat `size * size` solution (`0` = White, `1` = Black `■`).
  final List<int> solutionBoard;

  const HeyawakePuzzle({
    required this.size,
    required this.rooms,
    required this.roomId,
    required this.solutionBoard,
  });

  int get roomCount => rooms.length;

  List<int> get roomMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) roomId[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class HeyawakeAnalysis {
  final Set<int> satisfiedRooms;
  final Set<int> violatedRooms;
  final List<int> roomBlackCounts;
  final Set<int> adjacentBlackCells;
  final Set<int> spanViolationCells;
  final Set<int> isolatedWhiteCells;
  final bool whiteConnected;
  final int blackCount;
  final int dotCount;
  final int totalRooms;

  const HeyawakeAnalysis({
    required this.satisfiedRooms,
    required this.violatedRooms,
    required this.roomBlackCounts,
    required this.adjacentBlackCells,
    required this.spanViolationCells,
    required this.isolatedWhiteCells,
    required this.whiteConnected,
    required this.blackCount,
    required this.dotCount,
    required this.totalRooms,
  });

  bool get isSolved =>
      totalRooms > 0 &&
      satisfiedRooms.length == totalRooms &&
      violatedRooms.isEmpty &&
      adjacentBlackCells.isEmpty &&
      spanViolationCells.isEmpty &&
      whiteConnected;
}

class HeyawakeSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  static HeyawakeAnalysis analyze(HeyawakePuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final rCount = puz.roomCount;

    final satisfiedRooms = <int>{};
    final violatedRooms = <int>{};
    final roomBlackCounts = List<int>.filled(rCount, 0);
    final adjacentBlackCells = <int>{};
    final spanViolationCells = <int>{};
    final isolatedWhiteCells = <int>{};

    var blackCount = 0;
    var dotCount = 0;
    final whiteIndices = <int>[];

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
        final rid = puz.roomId[i ~/ size][i % size];
        if (rid >= 0 && rid < rCount) {
          roomBlackCounts[rid]++;
        }
      } else {
        whiteIndices.add(i);
        if (v == 2) dotCount++;
      }
    }

    // 1. Room Clue check
    for (var rid = 0; rid < rCount; rid++) {
      final clue = puz.rooms[rid]['clue'] ?? -1;
      final cnt = roomBlackCounts[rid];
      if (clue < 0) {
        satisfiedRooms.add(rid);
      } else if (cnt == clue) {
        satisfiedRooms.add(rid);
      } else if (cnt > clue) {
        violatedRooms.add(rid);
      }
    }

    // 2. No Orthogonal Black Adjacency
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (!isBlack(board, idx)) continue;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nIdx = nr * size + nc;
          if (isBlack(board, nIdx)) {
            adjacentBlackCells.add(idx);
            adjacentBlackCells.add(nIdx);
          }
        }
      }
    }

    // 3. Connected White check
    var whiteConnected = false;
    if (whiteIndices.isNotEmpty) {
      final comps = <List<int>>[];
      final vis = List<bool>.filled(n, false);
      for (final start in whiteIndices) {
        if (vis[start]) continue;
        final comp = <int>[];
        final q = Queue<int>()..add(start);
        vis[start] = true;
        while (q.isNotEmpty) {
          final cur = q.removeFirst();
          comp.add(cur);
          final r = cur ~/ size, c = cur % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
            final nxt = nr * size + nc;
            if (!vis[nxt] && !isBlack(board, nxt)) {
              vis[nxt] = true;
              q.add(nxt);
            }
          }
        }
        comps.add(comp);
      }
      whiteConnected = comps.length == 1;
      if (comps.length > 1) {
        comps.sort((a, b) => b.length.compareTo(a.length));
        for (var i = 1; i < comps.length; i++) {
          isolatedWhiteCells.addAll(comps[i]);
        }
      }
    }

    // 4. No 3-Room White Span (crossing >= 2 room boundaries in a contiguous horizontal or vertical White run)
    // Horizontal runs
    for (var r = 0; r < size; r++) {
      var c = 0;
      while (c < size) {
        if (isBlack(board, r * size + c)) {
          c++;
          continue;
        }
        final cStart = c;
        var crossings = 0;
        c++;
        while (c < size && !isBlack(board, r * size + c)) {
          if (puz.roomId[r][c] != puz.roomId[r][c - 1]) {
            crossings++;
          }
          c++;
        }
        if (crossings >= 2) {
          for (var k = cStart; k < c; k++) {
            spanViolationCells.add(r * size + k);
          }
        }
      }
    }

    // Vertical runs
    for (var c = 0; c < size; c++) {
      var r = 0;
      while (r < size) {
        if (isBlack(board, r * size + c)) {
          r++;
          continue;
        }
        final rStart = r;
        var crossings = 0;
        r++;
        while (r < size && !isBlack(board, r * size + c)) {
          if (puz.roomId[r][c] != puz.roomId[r - 1][c]) {
            crossings++;
          }
          r++;
        }
        if (crossings >= 2) {
          for (var k = rStart; k < r; k++) {
            spanViolationCells.add(k * size + c);
          }
        }
      }
    }

    return HeyawakeAnalysis(
      satisfiedRooms: satisfiedRooms,
      violatedRooms: violatedRooms,
      roomBlackCounts: roomBlackCounts,
      adjacentBlackCells: adjacentBlackCells,
      spanViolationCells: spanViolationCells,
      isolatedWhiteCells: isolatedWhiteCells,
      whiteConnected: whiteConnected,
      blackCount: blackCount,
      dotCount: dotCount,
      totalRooms: rCount,
    );
  }

  static bool isSolved(HeyawakePuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  static bool _isWhiteConnected(int size, List<int> sol) {
    final n = size * size;
    var firstWhite = -1;
    var whiteCount = 0;
    for (var i = 0; i < n; i++) {
      if (sol[i] != 1) {
        whiteCount++;
        if (firstWhite < 0) firstWhite = i;
      }
    }
    if (whiteCount == 0) return false;
    final vis = List<bool>.filled(n, false);
    final q = Queue<int>()..add(firstWhite);
    vis[firstWhite] = true;
    var seen = 0;
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      seen++;
      final r = cur ~/ size, c = cur % size;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          final nxt = nr * size + nc;
          if (!vis[nxt] && sol[nxt] != 1) {
            vis[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }
    return seen == whiteCount;
  }

  static List<int>? _findValidShading(
    int size,
    List<List<int>> roomId,
    Random rng,
  ) {
    final n = size * size;
    final sol = List<int>.filled(n, 0);
    final minBlacks = size - 1;
    final maxBlacks = size <= 5 ? 8 : 11;
    var steps = 0;

    bool canBeWhite(int r, int c) {
      // Check horizontal White run ending at (r, c)
      var crossingsH = 0;
      var cc = c;
      while (cc > 0 && sol[r * size + (cc - 1)] == 0) {
        if (roomId[r][cc] != roomId[r][cc - 1]) {
          crossingsH++;
          if (crossingsH >= 2) return false;
        }
        cc--;
      }
      // Check vertical White run ending at (r, c)
      var crossingsV = 0;
      var rr = r;
      while (rr > 0 && sol[(rr - 1) * size + c] == 0) {
        if (roomId[rr][c] != roomId[rr - 1][c]) {
          crossingsV++;
          if (crossingsV >= 2) return false;
        }
        rr--;
      }
      return true;
    }

    bool canBeBlack(int r, int c, int currentBlacks) {
      if (currentBlacks >= maxBlacks) return false;
      if (r > 0 && sol[(r - 1) * size + c] == 1) return false;
      if (c > 0 && sol[r * size + (c - 1)] == 1) return false;
      return true;
    }

    bool dfs(int idx, int currentBlacks) {
      if (++steps > 4000) return false;
      if (idx == n) {
        if (currentBlacks < minBlacks) return false;
        return _isWhiteConnected(size, sol);
      }
      final r = idx ~/ size, c = idx % size;
      final tryBlackFirst = rng.nextInt(10) < 3;
      final choices = tryBlackFirst ? const [1, 0] : const [0, 1];
      for (final v in choices) {
        if (v == 0) {
          if (!canBeWhite(r, c)) continue;
          sol[idx] = 0;
          if (dfs(idx + 1, currentBlacks)) return true;
        } else {
          if (!canBeBlack(r, c, currentBlacks)) continue;
          sol[idx] = 1;
          if (dfs(idx + 1, currentBlacks + 1)) return true;
          sol[idx] = 0;
        }
      }
      return false;
    }

    if (dfs(0, 0)) return sol;
    return null;
  }

  /// Generates a guaranteed-valid Heyawake puzzle for [size] (`5` or `6`).
  static HeyawakePuzzle generatePuzzle(int size, Random rng) {
    const candidateDims = <(int, int)>[
      (2, 2),
      (1, 2),
      (2, 1),
      (1, 3),
      (3, 1),
      (2, 3),
      (3, 2),
    ];

    for (var attempt = 0; attempt < 40; attempt++) {
      final roomId = [
        for (var r = 0; r < size; r++) List<int>.filled(size, -1),
      ];
      final rawRooms = <Map<String, int>>[];

      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          if (roomId[r][c] != -1) continue;
          final fits = <(int, int)>[];
          for (final (h, w) in candidateDims) {
            if (r + h > size || c + w > size) continue;
            var ok = true;
            for (var dr = 0; dr < h && ok; dr++) {
              for (var dc = 0; dc < w; dc++) {
                if (roomId[r + dr][c + dc] != -1) {
                  ok = false;
                  break;
                }
              }
            }
            if (ok) fits.add((h, w));
          }
          final (pickH, pickW) =
              fits.isNotEmpty ? fits[rng.nextInt(fits.length)] : (1, 1);
          final id = rawRooms.length;
          for (var dr = 0; dr < pickH; dr++) {
            for (var dc = 0; dc < pickW; dc++) {
              roomId[r + dr][c + dc] = id;
            }
          }
          rawRooms.add({
            'id': id,
            'r1': r,
            'c1': c,
            'r2': r + pickH - 1,
            'c2': c + pickW - 1,
            'clue': 0,
          });
        }
      }

      if (rawRooms.length < 5) continue;

      final sol = _findValidShading(size, roomId, rng);
      if (sol == null) continue;

      for (var id = 0; id < rawRooms.length; id++) {
        final rm = rawRooms[id];
        var cnt = 0;
        for (var r = rm['r1']!; r <= rm['r2']!; r++) {
          for (var c = rm['c1']!; c <= rm['c2']!; c++) {
            if (sol[r * size + c] == 1) cnt++;
          }
        }
        rm['clue'] = cnt;
      }

      final puz = HeyawakePuzzle(
        size: size,
        rooms: rawRooms,
        roomId: roomId,
        solutionBoard: sol,
      );
      if (isSolved(puz, sol) && !isSolved(puz, puz.initialBoard)) {
        return puz;
      }
    }

    // Deterministic fallback
    final roomId = [
      for (var r = 0; r < size; r++) List<int>.filled(size, 0),
    ];
    final rooms = <Map<String, int>>[];
    var id = 0;
    for (var r = 0; r < size; r += 2) {
      final r2 = min(size - 1, r + 1);
      final cMid = size ~/ 2;
      for (var rr = r; rr <= r2; rr++) {
        for (var cc = 0; cc < cMid; cc++) {
          roomId[rr][cc] = id;
        }
      }
      rooms.add({'id': id, 'r1': r, 'c1': 0, 'r2': r2, 'c2': cMid - 1, 'clue': 0});
      id++;
      for (var rr = r; rr <= r2; rr++) {
        for (var cc = cMid; cc < size; cc++) {
          roomId[rr][cc] = id;
        }
      }
      rooms.add({'id': id, 'r1': r, 'c1': cMid, 'r2': r2, 'c2': size - 1, 'clue': 0});
      id++;
    }
    final sol = List<int>.filled(size * size, 0);
    for (var r = 0; r < size; r++) {
      final c = (r * 2 + 1) % size;
      if (r == 0 || sol[(r - 1) * size + c] == 0) {
        sol[r * size + c] = 1;
      }
    }
    for (final rm in rooms) {
      var cnt = 0;
      for (var r = rm['r1']!; r <= rm['r2']!; r++) {
        for (var c = rm['c1']!; c <= rm['c2']!; c++) {
          if (sol[r * size + c] == 1) cnt++;
        }
      }
      rm['clue'] = cnt;
    }
    return HeyawakePuzzle(
      size: size,
      rooms: rooms,
      roomId: roomId,
      solutionBoard: sol,
    );
  }
}

/// 分室涂黑竞速 (Heyawake Race, 1-6 人).
class HeyawakeGame extends GameEngine {
  HeyawakeGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late HeyawakePuzzle currentPuzzle;
  late List<HeyawakePlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a14Placings(ranking, players) : null;

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

    currentPuzzle = HeyawakeSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) HeyawakePlayer(size * size)];

    host.log('分室涂黑竞速开始（$size×$size 网格，共 $totalRounds 题）！满足房间黑格线索且禁止白格直线跨三室！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = HeyawakeSolver.generatePuzzle(size, rng);
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
    return a14Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
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
        if (HeyawakeSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出分室涂黑谜题，+$pts 分！');
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
    final an = HeyawakeSolver.analyze(puz, myBoard);
    final totalCells = size * size;
    final totalRooms = puz.roomCount;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'rooms': puz.rooms,
      'roomId': puz.roomId,
      'roomMap': puz.roomMap,
      'totalRooms': totalRooms,
      'board': myBoard,
      'roomBlackCounts': an.roomBlackCounts,
      'satisfiedRooms': an.satisfiedRooms.toList()..sort(),
      'violatedRooms': an.violatedRooms.toList()..sort(),
      'adjacentBlackCells': an.adjacentBlackCells.toList()..sort(),
      'spanViolationCells': an.spanViolationCells.toList()..sort(),
      'isolatedWhiteCells': an.isolatedWhiteCells.toList()..sort(),
      'whiteConnected': an.whiteConnected,
      'satisfiedRoomCount': an.satisfiedRooms.length,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = HeyawakeSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedRooms': pAn.satisfiedRooms.length,
              'totalRooms': totalRooms,
              'blackCount': pAn.blackCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class HeyawakePlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  HeyawakePlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
