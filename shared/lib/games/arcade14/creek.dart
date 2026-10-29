import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a14_util.dart';

class CreekPuzzle {
  final int size;
  /// `(size + 1) × (size + 1)` grid of Vertex Clues (`0..4`, or `-1` if no clue).
  final List<List<int>> vertexClues;
  /// Flat `size * size` solution (`0` = White Creek, `1` = Black Bank `■`).
  final List<int> solutionBoard;

  const CreekPuzzle({
    required this.size,
    required this.vertexClues,
    required this.solutionBoard,
  });

  int get vSize => size + 1;

  List<int> get vertexCluesFlat => [
        for (var vr = 0; vr <= size; vr++)
          for (var vc = 0; vc <= size; vc++) vertexClues[vr][vc],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class CreekAnalysis {
  final Set<int> satisfiedVertices;
  final Set<int> violatedVertices;
  final Set<int> pendingVertices;
  final List<int> vertexBlackCounts;
  final Set<int> isolatedWhiteCells;
  final bool whiteConnected;
  final int totalClues;
  final int blackCount;
  final int whiteCount;
  final int dotCount;

  const CreekAnalysis({
    required this.satisfiedVertices,
    required this.violatedVertices,
    required this.pendingVertices,
    required this.vertexBlackCounts,
    required this.isolatedWhiteCells,
    required this.whiteConnected,
    required this.totalClues,
    required this.blackCount,
    required this.whiteCount,
    required this.dotCount,
  });

  bool get isSolved =>
      totalClues > 0 &&
      satisfiedVertices.length == totalClues &&
      violatedVertices.isEmpty &&
      pendingVertices.isEmpty &&
      whiteConnected;
}

class CreekSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  static bool isBlack(List<int> board, int idx) =>
      idx >= 0 && idx < board.length && board[idx] == 1;

  /// Counts Black (`== 1`) cells among the `1..4` cells touching vertex `(vr, vc)`
  /// (`(vr - 1, vc - 1)`, `(vr - 1, vc)`, `(vr, vc - 1)`, `(vr, vc)`).
  static int countBlackAroundVertex(int size, List<int> board, int vr, int vc) {
    var cnt = 0;
    for (var dr = -1; dr <= 0; dr++) {
      for (var dc = -1; dc <= 0; dc++) {
        final r = vr + dr;
        final c = vc + dc;
        if (r >= 0 && r < size && c >= 0 && c < size) {
          if (isBlack(board, r * size + c)) cnt++;
        }
      }
    }
    return cnt;
  }

  static CreekAnalysis analyze(CreekPuzzle puz, List<int> board) {
    final size = puz.size;
    final vSize = size + 1;
    final n = size * size;
    final vTotal = vSize * vSize;

    final satisfiedVertices = <int>{};
    final violatedVertices = <int>{};
    final pendingVertices = <int>{};
    final vertexBlackCounts = List<int>.filled(vTotal, 0);
    final isolatedWhiteCells = <int>{};

    var totalClues = 0;
    var blackCount = 0;
    var whiteCount = 0;
    var dotCount = 0;
    final whiteIndices = <int>[];

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
      } else {
        whiteCount++;
        whiteIndices.add(i);
        if (v == 2) dotCount++;
      }
    }

    // 1. Check all Vertex Clues
    for (var vr = 0; vr <= size; vr++) {
      for (var vc = 0; vc <= size; vc++) {
        final vIdx = vr * vSize + vc;
        final cnt = countBlackAroundVertex(size, board, vr, vc);
        vertexBlackCounts[vIdx] = cnt;
        final clue = puz.vertexClues[vr][vc];
        if (clue < 0) continue;
        totalClues++;
        if (cnt == clue) {
          satisfiedVertices.add(vIdx);
        } else if (cnt > clue) {
          violatedVertices.add(vIdx);
        } else {
          pendingVertices.add(vIdx);
        }
      }
    }

    // 2. Check White Creek single orthogonal connected component
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

    return CreekAnalysis(
      satisfiedVertices: satisfiedVertices,
      violatedVertices: violatedVertices,
      pendingVertices: pendingVertices,
      vertexBlackCounts: vertexBlackCounts,
      isolatedWhiteCells: isolatedWhiteCells,
      whiteConnected: whiteConnected,
      totalClues: totalClues,
      blackCount: blackCount,
      whiteCount: whiteCount,
      dotCount: dotCount,
    );
  }

  static bool isSolved(CreekPuzzle puz, List<int> board) {
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

  /// Generates a guaranteed-valid Creek puzzle for [size] (`5` or `6`).
  static CreekPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final sol = List<int>.filled(n, 0);
    final targetBlacks = size <= 5 ? (9 + rng.nextInt(4)) : (13 + rng.nextInt(5));

    final candidates = [for (var i = 0; i < n; i++) i]..shuffle(rng);
    var placedBlacks = 0;

    for (final idx in candidates) {
      if (placedBlacks >= targetBlacks) break;
      sol[idx] = 1;
      if (_isWhiteConnected(size, sol)) {
        placedBlacks++;
      } else {
        sol[idx] = 0;
      }
    }

    final vertexClues = [
      for (var vr = 0; vr <= size; vr++) List<int>.filled(size + 1, -1),
    ];

    final allVerts = <(int, int)>[
      for (var vr = 0; vr <= size; vr++)
        for (var vc = 0; vc <= size; vc++) (vr, vc),
    ]..shuffle(rng);

    final targetClues = size <= 5 ? 14 : 19;
    var exposed = 0;
    var positiveClues = 0;

    // First expose vertices that avoid overcrowding 4 mutually adjacent clues while covering cells
    for (final (vr, vc) in allVerts) {
      if (exposed >= targetClues) break;
      final cnt = countBlackAroundVertex(size, sol, vr, vc);
      // Prefer interior vertices or vertices with non-zero counts early
      if (positiveClues < 4 && cnt == 0) continue;
      vertexClues[vr][vc] = cnt;
      exposed++;
      if (cnt > 0) positiveClues++;
    }

    // Ensure every cell touches at least one exposed vertex clue
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final hasClue = vertexClues[r][c] >= 0 ||
            vertexClues[r][c + 1] >= 0 ||
            vertexClues[r + 1][c] >= 0 ||
            vertexClues[r + 1][c + 1] >= 0;
        if (!hasClue) {
          final vr = r + rng.nextInt(2);
          final vc = c + rng.nextInt(2);
          final cnt = countBlackAroundVertex(size, sol, vr, vc);
          vertexClues[vr][vc] = cnt;
          if (cnt > 0) positiveClues++;
        }
      }
    }

    if (positiveClues == 0) {
      for (var vr = 0; vr <= size; vr++) {
        for (var vc = 0; vc <= size; vc++) {
          final cnt = countBlackAroundVertex(size, sol, vr, vc);
          if (cnt > 0) {
            vertexClues[vr][vc] = cnt;
            break;
          }
        }
      }
    }

    return CreekPuzzle(
      size: size,
      vertexClues: vertexClues,
      solutionBoard: sol,
    );
  }
}

/// 溪流交点竞速 (Creek Race, 1-6 人).
class CreekGame extends GameEngine {
  CreekGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late CreekPuzzle currentPuzzle;
  late List<CreekPlayer> ps;
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

    currentPuzzle = CreekSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) CreekPlayer(size * size)];

    host.log('溪流交点竞速开始（$size×$size 网格，共 $totalRounds 题）！按格点交点计数涂黑河岸，保持全部白格溪流单连通！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = CreekSolver.generatePuzzle(size, rng);
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
        if (CreekSolver.isSolved(currentPuzzle, p.board)) {
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
    host.log('${name(seat)} 第 $roundSolvers 个解出溪流交点谜题，+$pts 分！');
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
    final an = CreekSolver.analyze(puz, myBoard);
    final totalCells = size * size;

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'vSize': puz.vSize,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'vertexClues': puz.vertexClues,
      'vertexCluesFlat': puz.vertexCluesFlat,
      'totalClues': an.totalClues,
      'board': myBoard,
      'vertexBlackCounts': an.vertexBlackCounts,
      'satisfiedVertices': an.satisfiedVertices.toList()..sort(),
      'violatedVertices': an.violatedVertices.toList()..sort(),
      'pendingVertices': an.pendingVertices.toList()..sort(),
      'isolatedWhiteCells': an.isolatedWhiteCells.toList()..sort(),
      'whiteConnected': an.whiteConnected,
      'satisfiedClueCount': an.satisfiedVertices.length,
      'blackCount': an.blackCount,
      'whiteCount': an.whiteCount,
      'dotCount': an.dotCount,
      'totalCells': totalCells,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = CreekSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedClues': pAn.satisfiedVertices.length,
              'totalClues': pAn.totalClues,
              'blackCount': pAn.blackCount,
              'whiteConnected': pAn.whiteConnected,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class CreekPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  CreekPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
