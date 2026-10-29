import 'dart:math';

import '../../src/engine.dart';

/// Radius-4 hexagonal grid (61 cells) for YINSH.
/// Axial coordinates `(q, r)` with `|q| <= 4`, `|r| <= 4`, `|q + r| <= 4`.
const int yinshRadius = 4;

final List<(int, int)> yinshCoords = () {
  final list = <(int, int)>[];
  for (var r = -yinshRadius; r <= yinshRadius; r++) {
    final qMin = max(-yinshRadius, -yinshRadius - r);
    final qMax = min(yinshRadius, yinshRadius - r);
    for (var q = qMin; q <= qMax; q++) {
      list.add((q, r));
    }
  }
  return List<(int, int)>.unmodifiable(list);
}();

final Map<(int, int), int> _coordToIndex = {
  for (var i = 0; i < yinshCoords.length; i++) yinshCoords[i]: i,
};

int yinshIndex(int q, int r) => _coordToIndex[(q, r)] ?? -1;

const List<(int, int)> yinshDirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
  (1, -1),
  (-1, 1),
];

/// Precomputed maximal lines along the 3 hex axes (`(1,0)`, `(0,1)`, `(1,-1)`).
final List<List<int>> yinshLines = () {
  final lines = <List<int>>[];
  const axes = [(1, 0), (0, 1), (1, -1)];
  for (final (dq, dr) in axes) {
    for (var i = 0; i < yinshCoords.length; i++) {
      final (q, r) = yinshCoords[i];
      // Start of a maximal line if stepping backward goes off-board
      if (yinshIndex(q - dq, r - dr) != -1) continue;
      final line = <int>[];
      var cq = q, cr = r;
      while (true) {
        final idx = yinshIndex(cq, cr);
        if (idx == -1) break;
        line.add(idx);
        cq += dq;
        cr += dr;
      }
      if (line.length >= 5) {
        lines.add(List<int>.unmodifiable(line));
      }
    }
  }
  return List<List<int>>.unmodifiable(lines);
}();

String yinshCellLabel(int idx) {
  if (idx < 0 || idx >= yinshCoords.length) return '?';
  final (q, r) = yinshCoords[idx];
  final rowChar = String.fromCharCode(65 + (r + yinshRadius)); // A..I
  final colNum = q + yinshRadius + 1; // 1..9
  return '$rowChar$colNum';
}

class Yinsh extends GameEngine {
  static const int ringsPerPlayer = 5;
  static const int maxPlies = 180;

  late int targetRings;

  /// 61-cell hex board:
  /// -1 = empty
  ///  0 = Player 0 Marker (White disk)
  ///  1 = Player 1 Marker (Black disk)
  ///  2 = Player 0 Ring (White ring)
  ///  3 = Player 1 Ring (Black ring)
  late List<int> board;

  /// `'setup'` (placing 5 rings per player) or `'play'` (moving rings & flipping markers).
  String phase = 'setup';
  int ringsPlaced = 0;
  int turn = 0;
  int plies = 0;

  /// Trophy Rings scored by each player (`scores[seat]` reaches `targetRings` to win).
  List<int> scores = [0, 0];

  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Yinsh(super.setup);

  static bool isMarker(int v) => v == 0 || v == 1;
  static bool isRing(int v) => v == 2 || v == 3;
  static int ringOwner(int v) => isRing(v) ? v - 2 : -1;

  @override
  void start() {
    final optTarget = setup.opt<int>('target', 3);
    targetRings = (optTarget == 1) ? 1 : 3;
    board = List.filled(yinshCoords.length, -1);
    phase = 'setup';
    ringsPlaced = 0;
    turn = 0;
    plies = 0;
    scores = [0, 0];
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    note = '布环阶段：请双方轮流在星盘空位上放置 5 枚星环（当前 0/10）';
    result = '';
  }

  int countRings(int seat) {
    final target = 2 + seat;
    var count = 0;
    for (final v in board) {
      if (v == target) count++;
    }
    return count;
  }

  int countMarkers(int seat) {
    var count = 0;
    for (final v in board) {
      if (v == seat) count++;
    }
    return count;
  }

  /// Legal destinations for moving a Ring from [from] along any of the 6 hex directions.
  /// Rules:
  /// - Cannot jump over or land on any Ring.
  /// - Can move across any number of empty cells before encountering a Marker.
  /// - Once it jumps over 1 or more contiguous Markers, it MUST land on the
  ///   FIRST empty cell immediately beyond those contiguous Markers.
  List<int> legalTargets(int from) {
    final out = <int>[];
    if (from < 0 || from >= board.length || !isRing(board[from])) return out;
    final (q0, r0) = yinshCoords[from];

    for (final (dq, dr) in yinshDirs) {
      var cq = q0 + dq, cr = r0 + dr;
      var jumpedMarkers = false;
      while (true) {
        final idx = yinshIndex(cq, cr);
        if (idx == -1) break;
        final v = board[idx];
        if (isRing(v)) {
          // Cannot jump over or land on any Ring
          break;
        }
        if (!jumpedMarkers) {
          if (v == -1) {
            out.add(idx);
          } else {
            // Encountered first marker in a contiguous chain
            jumpedMarkers = true;
          }
        } else {
          if (v == -1) {
            // Must land on the first empty cell after the contiguous markers!
            out.add(idx);
            break;
          }
          // Otherwise v is another marker in the contiguous group; keep jumping
        }
        cq += dq;
        cr += dr;
      }
    }
    return out;
  }

  /// Returns the cells strictly between [from] and [to] that contain Markers (which will be flipped).
  List<int> markersBetween(int from, int to) {
    if (from < 0 || from >= board.length || to < 0 || to >= board.length || from == to) {
      return const [];
    }
    final (q0, r0) = yinshCoords[from];
    final (q1, r1) = yinshCoords[to];
    final dq = q1 - q0, dr = r1 - r0;
    final steps = max(dq.abs(), max(dr.abs(), (dq + dr).abs()));
    if (steps <= 1) return const [];
    if (dq != 0 && dr != 0 && dq + dr != 0) return const [];
    final stepQ = dq ~/ steps, stepR = dr ~/ steps;
    final flipped = <int>[];
    for (var s = 1; s < steps; s++) {
      final idx = yinshIndex(q0 + stepQ * s, r0 + stepR * s);
      if (idx != -1 && isMarker(board[idx])) {
        flipped.add(idx);
      }
    }
    return flipped;
  }

  bool hasAnyLegalMove(int seat) {
    if (phase == 'setup') {
      return board.any((v) => v == -1);
    }
    final ringVal = 2 + seat;
    for (var i = 0; i < board.length; i++) {
      if (board[i] == ringVal && legalTargets(i).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Finds the first 5-in-a-row of markers belonging to [seat], or null if none.
  List<int>? findFiveInARow(int seat) {
    for (final line in yinshLines) {
      var run = <int>[];
      for (final idx in line) {
        if (board[idx] == seat) {
          run.add(idx);
          if (run.length == 5) return run;
        } else {
          run = <int>[];
        }
      }
    }
    return null;
  }

  int _pickRingToRemove(int seat, {int preferred = -1}) {
    final ringVal = 2 + seat;
    if (preferred >= 0 && preferred < board.length && board[preferred] == ringVal) {
      return preferred;
    }
    // Pick the ring with fewest legal moves (least mobile / edge ring)
    var bestIdx = -1;
    var bestMobility = 999;
    for (var i = 0; i < board.length; i++) {
      if (board[i] == ringVal) {
        final m = legalTargets(i).length;
        if (m < bestMobility) {
          bestMobility = m;
          bestIdx = i;
        }
      }
    }
    return bestIdx;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');

    final t = asStr(action['type']);
    final sideName = seat == 0 ? '白方' : '黑方';

    if (phase == 'setup') {
      if (t != 'place_ring') throw GameError('当前为布环阶段，请放置星环');
      final cell = asInt(action['cell'], -1);
      if (cell < 0 || cell >= board.length) throw GameError('无效的星盘坐标');
      if (board[cell] != -1) throw GameError('该位置已有棋子，请选择空位放置星环');

      board[cell] = 2 + seat;
      ringsPlaced++;
      plies++;
      lastAction = {
        'type': 'place_ring',
        'seat': seat,
        'cell': cell,
      };

      if (ringsPlaced >= ringsPerPlayer * 2) {
        phase = 'play';
        turn = 0;
        note = '${name(seat)}（$sideName）在 ${yinshCellLabel(cell)} 放环；布环完成，进入行棋阶段！';
      } else {
        turn = 1 - seat;
        note = '${name(seat)}（$sideName）在 ${yinshCellLabel(cell)} 放置星环（已放 $ringsPlaced/${ringsPerPlayer * 2}）';
      }
      return;
    }

    if (t != 'move_ring') throw GameError('请选择一枚己方星环并沿直线移动');
    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= board.length || to < 0 || to >= board.length) {
      throw GameError('请选择有效的起点与终点');
    }
    if (board[from] != 2 + seat) {
      throw GameError('起点必须是你自己的星环');
    }
    final legal = legalTargets(from);
    if (!legal.contains(to)) {
      throw GameError('非法的星环移动（不可越过星环；若跳过标记则必须停在紧邻的第一个空位）');
    }

    final flipped = _executeRingMove(seat, from, to);
    plies++;

    final scoredLines = <List<int>>[];
    final removedRings = <int>[];
    final preferredRing = asInt(action['trophyRing'], -1);

    // Resolve 5-in-a-row: active player first, then opponent
    for (final p in [seat, 1 - seat]) {
      while (scores[p] < targetRings) {
        final five = findFiveInARow(p);
        if (five == null) break;
        for (final c in five) {
          board[c] = -1;
        }
        scoredLines.add(five);
        scores[p]++;
        final ringIdx = _pickRingToRemove(p, preferred: p == seat ? preferredRing : -1);
        if (ringIdx != -1) {
          board[ringIdx] = -1;
          removedRings.add(ringIdx);
        }
      }
      if (scores[p] >= targetRings) break;
    }

    lastAction = {
      'type': 'move_ring',
      'seat': seat,
      'from': from,
      'to': to,
      'flipped': flipped,
      'scoredLines': scoredLines,
      'removedRings': removedRings,
    };

    final flipText = flipped.isEmpty ? '' : '，翻转 ${flipped.length} 枚标记';
    final scoreText = scoredLines.isEmpty ? '' : '，达成五连收回星环！';
    note = '${name(seat)}（$sideName）移环 ${yinshCellLabel(from)}→${yinshCellLabel(to)}$flipText$scoreText';

    // Check win condition
    for (final p in [seat, 1 - seat]) {
      if (scores[p] >= targetRings) {
        final pSide = p == 0 ? '白方' : '黑方';
        _finish(p, '${name(p)}（$pSide）率先集齐 ${scores[p]} 枚战利星环，获胜！');
        return;
      }
    }

    final nextSeat = 1 - seat;
    if (!hasAnyLegalMove(nextSeat) || plies >= maxPlies) {
      _finishByTiebreaker(
        !hasAnyLegalMove(nextSeat) ? '棋盘已无合法移动' : '达到回合上限',
      );
      return;
    }

    turn = nextSeat;
  }

  List<int> _executeRingMove(int seat, int from, int to) {
    final flipped = markersBetween(from, to);
    board[from] = seat; // Leave a marker of seat's color at `from`
    for (final idx in flipped) {
      board[idx] = 1 - board[idx];
    }
    board[to] = 2 + seat; // Move ring to `to`
    return flipped;
  }

  void _finishByTiebreaker(String prefix) {
    if (scores[0] != scores[1]) {
      final w = scores[0] > scores[1] ? 0 : 1;
      _finish(w, '$prefix，${name(w)} 战利星环（${scores[0]}:${scores[1]}）领先获胜！');
      return;
    }
    final m0 = countMarkers(0), m1 = countMarkers(1);
    if (m0 != m1) {
      final w = m0 > m1 ? 0 : 1;
      _finish(w, '$prefix，双方星环战平，${name(w)} 盘面标记数（$m0:$m1）占优获胜！');
      return;
    }
    _finish(2, '$prefix，双方星环与标记数完全相同，握手言和！');
  }

  void _finish(int w, String msg) {
    _over = true;
    winner = w;
    result = msg;
    note = msg;
    if (w == 2) {
      _placings = [1, 1];
    } else {
      _placings = rankWinners(players, [w]);
    }
    host.log(msg);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    final w = 1 - seat;
    _finish(w, '${name(seat)} 认输，${name(w)} 获胜！');
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _finish(2, '双方议和');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'phase': phase,
      'targetRings': targetRings,
      'ringsPlaced': ringsPlaced,
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'scores': List<int>.of(scores),
      'markers': [countMarkers(0), countMarkers(1)],
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  int _maxRunLength(int seat) {
    var best = 0;
    for (final line in yinshLines) {
      var cur = 0;
      for (final idx in line) {
        if (board[idx] == seat) {
          cur++;
          if (cur > best) best = cur;
        } else {
          cur = 0;
        }
      }
    }
    return best;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'setup') {
      final empty = <int>[];
      for (var i = 0; i < board.length; i++) {
        if (board[i] == -1) empty.add(i);
      }
      if (empty.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'place_ring', 'cell': empty[rng.nextInt(empty.length)]};
      }
      // Prefer central hexes for higher mobility
      empty.sort((a, b) {
        final (qa, ra) = yinshCoords[a];
        final (qb, rb) = yinshCoords[b];
        final da = qa.abs() + ra.abs() + (qa + ra).abs();
        final db = qb.abs() + rb.abs() + (qb + rb).abs();
        return da.compareTo(db);
      });
      final pool = empty.take(min(12, empty.length)).toList();
      return {'type': 'place_ring', 'cell': pool[rng.nextInt(pool.length)]};
    }

    final allMoves = <(int, int)>[];
    final ringVal = 2 + seat;
    for (var i = 0; i < board.length; i++) {
      if (board[i] != ringVal) continue;
      for (final t in legalTargets(i)) {
        allMoves.add((i, t));
      }
    }
    if (allMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.4) {
      final pick = allMoves[rng.nextInt(allMoves.length)];
      return {'type': 'move_ring', 'from': pick.$1, 'to': pick.$2};
    }

    final saved = List<int>.of(board);
    final opp = 1 - seat;
    var bestScore = -1e12;
    var bestMove = allMoves.first;

    for (final (f, t) in allMoves) {
      _executeRingMove(seat, f, t);
      final myFive = findFiveInARow(seat) != null;
      final oppFive = findFiveInARow(opp) != null;
      if (myFive && !oppFive) {
        board.setAll(0, saved);
        return {'type': 'move_ring', 'from': f, 'to': t};
      }

      final myRun = _maxRunLength(seat);
      final oppRun = _maxRunLength(opp);
      final myMarkers = countMarkers(seat);
      final oppMarkers = countMarkers(opp);

      var score = (myMarkers - oppMarkers) * 4.0 +
          myRun * 14.0 -
          oppRun * 16.0 +
          rng.nextDouble() * 2.0;
      if (myFive) score += 200.0;
      if (oppFive) score -= 260.0;

      if (score > bestScore) {
        bestScore = score;
        bestMove = (f, t);
      }
      board.setAll(0, saved);
    }

    return {'type': 'move_ring', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
