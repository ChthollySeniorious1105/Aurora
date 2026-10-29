import 'dart:math';

import '../../src/engine.dart';
import 'a3_util.dart';

/// Solver and board utilities for Mahjong Connect (连连看, <= 3 segments / <= 2 turns).
class MjConnectSolver {
  /// Tile symbols (index 1..16).
  static const symbols = [
    '',
    '一万', '二万', '三万', '四万', '五万', '六万', '七万', '八万',
    '东', '南', '西', '北', '中', '发', '白', '春',
  ];

  static const mahjongCodes = [
    '',
    '1m', '2m', '3m', '4m', '5m', '6m', '7m', '8m',
    '1z', '2z', '3z', '4z', '7z', '6z', '5z', '0p',
  ];

  /// Returns true if `(x, y)` is outside the grid (on the 1-cell border) or empty (`grid == 0`).
  static bool isEmpty(List<int> grid, int w, int h, int x, int y) {
    if (x < 0 || x >= w || y < 0 || y >= h) return true;
    return grid[y * w + x] == 0;
  }

  /// Returns true if all cells strictly between `(x1, y1)` and `(x2, y2)` on
  /// the same row or column are empty.
  static bool clearSegment(List<int> grid, int w, int h, int x1, int y1, int x2, int y2) {
    if (x1 == x2) {
      final lo = min(y1, y2), hi = max(y1, y2);
      for (var y = lo + 1; y < hi; y++) {
        if (!isEmpty(grid, w, h, x1, y)) return false;
      }
      return true;
    }
    if (y1 == y2) {
      final lo = min(x1, x2), hi = max(x1, x2);
      for (var x = lo + 1; x < hi; x++) {
        if (!isEmpty(grid, w, h, x, y1)) return false;
      }
      return true;
    }
    return false;
  }

  /// Finds a path of at most 3 straight orthogonal segments (<= 2 turns)
  /// between cell [a] and cell [b], passing only through empty cells or the
  /// 1-cell outer border (`x in -1..w, y in -1..h`).
  /// Returns the list of vertices `[(x1,y1), ..., (x2,y2)]` or null.
  static List<(int, int)>? findPath(List<int> grid, int w, int h, int a, int b) {
    if (a < 0 || b < 0 || a >= w * h || b >= w * h || a == b) return null;
    if (grid[a] == 0 || grid[b] == 0 || grid[a] != grid[b]) return null;
    final x1 = a % w, y1 = a ~/ w;
    final x2 = b % w, y2 = b ~/ w;

    // 1. 0 turns (1 segment)
    if ((x1 == x2 || y1 == y2) && clearSegment(grid, w, h, x1, y1, x2, y2)) {
      return [(x1, y1), (x2, y2)];
    }

    // 2. 1 turn (2 segments)
    if (x1 != x2 && y1 != y2) {
      if (isEmpty(grid, w, h, x1, y2) &&
          clearSegment(grid, w, h, x1, y1, x1, y2) &&
          clearSegment(grid, w, h, x1, y2, x2, y2)) {
        return [(x1, y1), (x1, y2), (x2, y2)];
      }
      if (isEmpty(grid, w, h, x2, y1) &&
          clearSegment(grid, w, h, x1, y1, x2, y1) &&
          clearSegment(grid, w, h, x2, y1, x2, y2)) {
        return [(x1, y1), (x2, y1), (x2, y2)];
      }
    }

    // 3. 2 turns (3 segments) — pick shortest total Manhattan length
    List<(int, int)>? best;
    var bestLen = 999999;

    // Bridge along column cx: (x1,y1) -> (cx,y1) -> (cx,y2) -> (x2,y2)
    if (y1 != y2) {
      for (var cx = -1; cx <= w; cx++) {
        if (cx == x1 || cx == x2) continue;
        if (!isEmpty(grid, w, h, cx, y1) || !isEmpty(grid, w, h, cx, y2)) continue;
        if (!clearSegment(grid, w, h, x1, y1, cx, y1)) continue;
        if (!clearSegment(grid, w, h, cx, y1, cx, y2)) continue;
        if (!clearSegment(grid, w, h, cx, y2, x2, y2)) continue;
        final len = (x1 - cx).abs() + (y1 - y2).abs() + (cx - x2).abs();
        if (len < bestLen) {
          bestLen = len;
          best = [(x1, y1), (cx, y1), (cx, y2), (x2, y2)];
        }
      }
    }

    // Bridge along row cy: (x1,y1) -> (x1,cy) -> (x2,cy) -> (x2,y2)
    if (x1 != x2) {
      for (var cy = -1; cy <= h; cy++) {
        if (cy == y1 || cy == y2) continue;
        if (!isEmpty(grid, w, h, x1, cy) || !isEmpty(grid, w, h, x2, cy)) continue;
        if (!clearSegment(grid, w, h, x1, y1, x1, cy)) continue;
        if (!clearSegment(grid, w, h, x1, cy, x2, cy)) continue;
        if (!clearSegment(grid, w, h, x2, cy, x2, y2)) continue;
        final len = (y1 - cy).abs() + (x1 - x2).abs() + (cy - y2).abs();
        if (len < bestLen) {
          bestLen = len;
          best = [(x1, y1), (x1, cy), (x2, cy), (x2, y2)];
        }
      }
    }

    return best;
  }

  /// Finds any valid eliminable pair `(a, b, path)` on [grid], or null if deadlocked.
  static (int, int, List<(int, int)>)? findAnyPair(List<int> grid, int w, int h) {
    final byType = <int, List<int>>{};
    for (var i = 0; i < grid.length; i++) {
      final v = grid[i];
      if (v != 0) byType.putIfAbsent(v, () => []).add(i);
    }
    for (final indices in byType.values) {
      for (var i = 0; i < indices.length; i++) {
        for (var j = i + 1; j < indices.length; j++) {
          final a = indices[i], b = indices[j];
          final p = findPath(grid, w, h, a, b);
          if (p != null) return (a, b, p);
        }
      }
    }
    return null;
  }

  /// Shuffles the remaining non-zero tiles in [grid] in-place and guarantees
  /// that at least one valid pair can be connected.
  static void shuffleRemaining(List<int> grid, int w, int h, Random rng) {
    final occupied = <int>[];
    final vals = <int>[];
    for (var i = 0; i < grid.length; i++) {
      if (grid[i] != 0) {
        occupied.add(i);
        vals.add(grid[i]);
      }
    }
    if (occupied.length < 2) return;

    for (var tries = 0; tries < 25; tries++) {
      vals.shuffle(rng);
      for (var k = 0; k < occupied.length; k++) {
        grid[occupied[k]] = vals[k];
      }
      if (findAnyPair(grid, w, h) != null) return;
    }

    // Deterministic fallback: find any two occupied positions that can connect
    // if given the same value, and swap a matching value into the second slot.
    for (var i = 0; i < occupied.length; i++) {
      for (var j = i + 1; j < occupied.length; j++) {
        final a = occupied[i], b = occupied[j];
        final savedB = grid[b];
        grid[b] = grid[a];
        final path = findPath(grid, w, h, a, b);
        grid[b] = savedB;
        if (path != null) {
          // Find another slot k != i that holds the same value as grid[a]
          final matchIdx = occupied.firstWhere((idx) => idx != a && grid[idx] == grid[a]);
          final tmp = grid[b];
          grid[b] = grid[matchIdx];
          grid[matchIdx] = tmp;
          return;
        }
      }
    }
  }
}

/// 连连看竞速 (1-6 人).
class MjConnect extends GameEngine {
  MjConnect(super.setup);

  static const maxManualShuffles = 3;
  static const shufflePenalty = 2;
  static const maxSec = 300;

  late String sizeOpt;
  late int w, h;
  late int totalPairs;
  late List<int> initialGrid;
  late List<MjConnectPlayer> ps;
  int sec = 0;
  int moves = 0;
  bool over = false;
  int _resigns = 0;
  List<Map<String, dynamic>>? ranking;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a3Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs {
    final base = switch (sizeOpt) { 'small' => 550, 'large' => 750, _ => 650 };
    return switch (botLevel) { 0 => base * 3 ~/ 2, 2 => base * 3 ~/ 5, _ => base };
  }

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    p.resignNo = ++_resigns;
    host.log('${name(seat)} 认输');
    final still = [for (var s = 0; s < players; s++) if (ps[s].resignNo == 0) s];
    if (still.isEmpty || (players > 1 && still.length <= 1)) {
      _finish(still.isEmpty ? '所有人都已认输' : '其他人都已认输');
    }
  }

  @override
  void start() {
    final s = setup.opt<String>('size', 'medium');
    sizeOpt = (s == 'small' || s == 'large') ? s : 'medium';
    final dims = switch (sizeOpt) {
      'small' => (6, 4, 8),
      'large' => (8, 6, 16),
      _ => (6, 6, 12),
    };
    w = dims.$1;
    h = dims.$2;
    final distinctTypes = dims.$3;
    totalPairs = (w * h) ~/ 2;

    final deck = <int>[];
    for (var i = 0; i < totalPairs; i++) {
      final t = 1 + (i % distinctTypes);
      deck.add(t);
      deck.add(t);
    }
    deck.shuffle(rng);
    MjConnectSolver.shuffleRemaining(deck, w, h, rng);
    initialGrid = List<int>.of(deck);

    ps = [
      for (var i = 0; i < players; i++) MjConnectPlayer(List<int>.of(initialGrid)),
    ];
    host.log('连连看竞速开始（$w×$h，共 $totalPairs 对牌）！两次转弯内连通相同图案即可消除，最先清空棋盘者获胜！');
    host.schedule(1000, _clock);
  }

  void _clock() {
    if (over) return;
    sec++;
    if (sec >= maxSec) {
      _finish('时间到');
      return;
    }
    host.schedule(1000, _clock);
  }

  bool _active(int s) => ps[s].resignNo == 0 && !ps[s].done;

  @override
  List<int> get waitingFor =>
      over ? const [] : a3Rotated([for (var s = 0; s < players; s++) if (_active(s)) s], moves);

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.done) throw GameError('你已清空棋盘');

    switch (type) {
      case 'pair':
      case 'connect':
      case 'match':
        final idxA = asInt(a['a']);
        final idxB = asInt(a['b']);
        _eliminatePair(seat, idxA, idxB);

      case 'tap':
        final idx = asInt(a['i']);
        if (idx < 0 || idx >= w * h || p.grid[idx] == 0) {
          throw GameError('请选择棋盘上的有效牌');
        }
        if (p.sel < 0 || p.grid[p.sel] == 0) {
          p.sel = idx;
          moves++;
          return;
        }
        if (p.sel == idx) {
          p.sel = -1;
          moves++;
          return;
        }
        final prev = p.sel;
        if (p.grid[prev] == p.grid[idx] && MjConnectSolver.findPath(p.grid, w, h, prev, idx) != null) {
          p.sel = -1;
          _eliminatePair(seat, prev, idx);
        } else {
          p.sel = idx;
          moves++;
        }

      case 'shuffle':
        if (p.shufflesLeft <= 0) throw GameError('洗牌次数已用完');
        p.shufflesLeft--;
        p.manualShuffles++;
        p.score = max(0, p.score - shufflePenalty);
        p.sel = -1;
        p.lastPath = null;
        p.lastPair = null;
        MjConnectSolver.shuffleRemaining(p.grid, w, h, rng);
        moves++;

      default:
        throw GameError('未知操作');
    }
  }

  void _eliminatePair(int seat, int idxA, int idxB) {
    final p = ps[seat];
    if (idxA < 0 || idxB < 0 || idxA >= w * h || idxB >= w * h || idxA == idxB) {
      throw GameError('请选择两张不同的牌');
    }
    if (p.grid[idxA] == 0 || p.grid[idxB] == 0) {
      throw GameError('所选位置没有牌');
    }
    if (p.grid[idxA] != p.grid[idxB]) {
      throw GameError('两张牌图案不同');
    }
    final path = MjConnectSolver.findPath(p.grid, w, h, idxA, idxB);
    if (path == null) {
      throw GameError('无法在两次转弯内连通');
    }
    p.grid[idxA] = 0;
    p.grid[idxB] = 0;
    p.sel = -1;
    p.cleared++;
    p.score += 10;
    p.lastPair = [idxA, idxB];
    p.lastPath = [
      for (final (x, y) in path) [x, y],
    ];
    moves++;

    if (p.cleared >= totalPairs) {
      p.done = true;
      p.doneSec = sec;
      host.log('${name(seat)} 清空了所有牌！');
      _finish('${name(seat)} 率先清空棋盘');
      return;
    }

    // Auto-shuffle if no valid pairs remain on this player's board
    if (MjConnectSolver.findAnyPair(p.grid, w, h) == null) {
      MjConnectSolver.shuffleRemaining(p.grid, w, h, rng);
      p.autoShuffles++;
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a3Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.done != pb.done) return pa.done ? -1 : 1;
      if (pa.cleared != pb.cleared) return pb.cleared - pa.cleared;
      if (pa.score != pb.score) return pb.score - pa.score;
      return pa.doneSec - pb.doneSec;
    }, (s) => {
          'cleared': ps[s].cleared,
          'total': totalPairs,
          'score': ps[s].score,
          'done': ps[s].done,
          'time': ps[s].done ? ps[s].doneSec : null,
          'shuffles': ps[s].manualShuffles,
        });
    host.log('游戏结束（$why）！冠军：${a3Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_active(seat)) return null;
    final p = ps[seat];
    // Easy bot occasionally uses a manual shuffle if available
    if (botLevel <= 0 && p.shufflesLeft > 0 && rng.nextInt(18) == 0) {
      return {'type': 'shuffle'};
    }
    final pair = MjConnectSolver.findAnyPair(p.grid, w, h);
    if (pair != null) {
      return {'type': 'pair', 'a': pair.$1, 'b': pair.$2};
    }
    if (p.shufflesLeft > 0) {
      return {'type': 'shuffle'};
    }
    return {'type': 'idle'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final hint = (me != null && !over && !me.done) ? MjConnectSolver.findAnyPair(me.grid, w, h) : null;
    return {
      'phase': over ? 'over' : 'play',
      'size': sizeOpt,
      'w': w,
      'h': h,
      'sec': sec,
      'maxSec': maxSec,
      'totalPairs': totalPairs,
      'g': me?.grid ?? initialGrid,
      'sel': seat >= 0 && seat < players ? ps[seat].sel : -1,
      'lastPair': me?.lastPair,
      'lastPath': me?.lastPath,
      'shufflesLeft': me?.shufflesLeft ?? 0,
      'autoShuffles': me?.autoShuffles ?? 0,
      'hint': hint != null ? [hint.$1, hint.$2] : null,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'cleared': ps[s].cleared,
            'score': ps[s].score,
            'done': ps[s].done,
            'out': ps[s].resignNo > 0,
            'shuffles': ps[s].shufflesLeft,
            'autoShuffles': ps[s].autoShuffles,
            'time': ps[s].done ? ps[s].doneSec : null,
          },
      ],
      'final': ranking,
    };
  }
}

class MjConnectPlayer {
  final List<int> grid;
  MjConnectPlayer(this.grid);

  int sel = -1;
  int cleared = 0;
  int score = 0;
  int shufflesLeft = MjConnect.maxManualShuffles;
  int manualShuffles = 0;
  int autoShuffles = 0;
  bool done = false;
  int doneSec = 0;
  int resignNo = 0;
  List<int>? lastPair;
  List<List<int>>? lastPath;
}
