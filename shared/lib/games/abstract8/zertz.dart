import '../../src/engine.dart';

const String zertzRules = '''
# 游戏概述
- **泽茨棋 (ZÈRTZ)** 是 GIPF 计划系列中荣获门萨优选奖的双人抽象策略棋类。
- 双方共用同一个弹珠供应池（**6 白、8 灰、10 黑**），没有固定的“己方棋子”，棋盘也会随着每回合移走外圈棋环而不断缩小！

# 胜利条件
- 标准模式：率先在个人俘获区收集到以下任意一组弹珠即立刻获胜：
  - **4 颗白珠**，或 **5 颗灰珠**，或 **6 颗黑珠**，或 **白、灰、黑各 3 颗**。
- 快速模式：率先收集到 **3 白**、**4 灰**、**5 黑** 或 **各 2 颗** 即立刻获胜。

# 回合流程
- 每回合必须在以下两种行动中执行其一（**强制吃子优先**）：
- **规则 A：强制跳吃 (`capture`)**
  - 若棋盘上任意位置存在一颗弹珠可以沿六角网格直线跳过相邻的一颗弹珠，并落入正后方紧邻的空棋环中，当前玩家**必须执行跳吃**。
  - 被跳过的弹珠收入当前玩家的个人俘获区。
  - **连跳规则**：若落定后的同一颗弹珠还能继续跳吃其他弹珠，必须使用该弹珠继续连跳，直到无法再跳为止。
- **规则 B：放珠并移环 (`place`)**
  - 当且仅当棋盘上没有任何合法跳吃时执行：
  1. **放置弹珠**：从公共供应池中选择一颗弹珠（白/灰/黑）放入任意一个空棋环；若公共供应池已空，则必须从自己的个人俘获区中拿出一颗弹珠放入空棋环。
  2. **移除外环**：从棋盘边缘移走一个**空的自由外环**（周围 6 个方向中至少有连续 2 个方向没有相邻棋环，可以在不惊动其他棋环的情况下滑出）。
- **孤岛奖励（隔离俘获）**：
  - 当移走棋环导致棋盘上某一块或多块相连的棋环区域与其他棋环断开（或本身已是独立区域），且该连通区域内的**所有棋环都装有弹珠（无空环）**时，触发该状态的玩家将立刻俘获该孤岛上的全部弹珠，并将这些棋环一并移出棋盘！

# 其他规则
- 支持悔棋、认输与求和。
''';

class ZertzCell {
  final int index;
  final int q;
  final int r;
  bool hasRing = true;
  String? marble; // 'W', 'G', 'B', or null

  ZertzCell({
    required this.index,
    required this.q,
    required this.r,
  });
}

class ZertzGame extends GameEngine {
  ZertzGame(super.setup);

  static const List<(int, int)> hexDirs = [
    (1, 0),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (0, -1),
    (1, -1),
  ];

  static const List<String> colors = ['W', 'G', 'B'];

  late String mode; // 'standard' | 'quick'
  late int boardSize; // 37 | 48
  final List<ZertzCell> cells = [];
  final Map<(int, int), int> coordToIdx = {};

  final Map<String, int> supply = {'W': 6, 'G': 8, 'B': 10};
  final List<Map<String, int>> captured = [
    {'W': 0, 'G': 0, 'B': 0},
    {'W': 0, 'G': 0, 'B': 0},
  ];

  int turn = 0;
  int? mustContinueFrom; // cell index when in multi-jump chain
  bool _over = false;
  int? winner; // 0, 1, or null for draw
  String? winReason;
  Map<String, dynamic>? lastMove;
  int stepCount = 0;

  Map<String, int> get goalTargets => mode == 'quick'
      ? const {'W': 3, 'G': 4, 'B': 5, 'EACH': 2}
      : const {'W': 4, 'G': 5, 'B': 6, 'EACH': 3};

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  @override
  void resign(int seat) {
    if (_over) return;
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) return;
    _over = true;
    winner = null;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    boardSize = setup.opt<int>('board', 37);
    cells.clear();
    coordToIdx.clear();

    var idx = 0;
    final maxCoord = boardSize == 48 ? 4 : 3;
    for (var r = -3; r <= maxCoord; r++) {
      for (var q = -3; q <= maxCoord; q++) {
        final s = q + r;
        if (s >= -3 && s <= maxCoord) {
          final cell = ZertzCell(index: idx, q: q, r: r);
          cells.add(cell);
          coordToIdx[(q, r)] = idx;
          idx++;
        }
      }
    }

    supply['W'] = 6;
    supply['G'] = 8;
    supply['B'] = 10;
    for (var s = 0; s < 2; s++) {
      captured[s]['W'] = 0;
      captured[s]['G'] = 0;
      captured[s]['B'] = 0;
    }
    turn = 0;
    mustContinueFrom = null;
    _over = false;
    winner = null;
    winReason = null;
    lastMove = null;
    stepCount = 0;
  }

  int? neighborOf(int cellIdx, int dir) {
    final c = cells[cellIdx];
    final (dq, dr) = hexDirs[dir];
    final nIdx = coordToIdx[(c.q + dq, c.r + dr)];
    if (nIdx == null || !cells[nIdx].hasRing) return null;
    return nIdx;
  }

  /// A vacant ring is free (removable) if at least 2 contiguous directions
  /// around its hex perimeter have no ring.
  bool isFreeVacantRing(int cellIdx) {
    if (cellIdx < 0 || cellIdx >= cells.length) return false;
    final c = cells[cellIdx];
    if (!c.hasRing || c.marble != null) return false;
    for (var d = 0; d < 6; d++) {
      final n1 = neighborOf(cellIdx, d);
      final n2 = neighborOf(cellIdx, (d + 1) % 6);
      if (n1 == null && n2 == null) return true;
    }
    return false;
  }

  List<int> freeVacantRings({int? excludeCell}) {
    final res = <int>[];
    for (final c in cells) {
      if (c.index == excludeCell) continue;
      if (!c.hasRing || c.marble != null) continue;
      if (isFreeVacantRing(c.index)) {
        res.add(c.index);
      }
    }
    if (res.isNotEmpty) return res;
    // Fallback if all outer perimeter rings are occupied by marbles: allow any perimeter vacant ring, or any remaining vacant ring
    for (final c in cells) {
      if (c.index == excludeCell) continue;
      if (!c.hasRing || c.marble != null) continue;
      for (var d = 0; d < 6; d++) {
        if (neighborOf(c.index, d) == null) {
          res.add(c.index);
          break;
        }
      }
    }
    if (res.isNotEmpty) return res;
    return [
      for (final c in cells)
        if (c.index != excludeCell && c.hasRing && c.marble == null) c.index,
    ];
  }

  List<int> vacantRings() => [
        for (final c in cells)
          if (c.hasRing && c.marble == null) c.index,
      ];

  /// Returns all legal jump captures `(from, mid, to)` from [onlyFrom] (or any ring if null).
  List<({int from, int mid, int to})> legalCaptures({int? onlyFrom}) {
    final res = <({int from, int mid, int to})>[];
    final startIndices = onlyFrom != null ? [onlyFrom] : [for (var i = 0; i < cells.length; i++) i];
    for (final f in startIndices) {
      if (f < 0 || f >= cells.length) continue;
      final fc = cells[f];
      if (!fc.hasRing || fc.marble == null) continue;
      for (var d = 0; d < 6; d++) {
        final mid = neighborOf(f, d);
        if (mid == null || cells[mid].marble == null) continue;
        final to = neighborOf(mid, d);
        if (to == null || cells[to].marble != null) continue;
        res.add((from: f, mid: mid, to: to));
      }
    }
    return res;
  }

  List<String> availableColorsFor(int seat) {
    final supTotal = (supply['W'] ?? 0) + (supply['G'] ?? 0) + (supply['B'] ?? 0);
    if (supTotal > 0) {
      return [for (final c in colors) if ((supply[c] ?? 0) > 0) c];
    }
    return [for (final c in colors) if ((captured[seat][c] ?? 0) > 0) c];
  }

  bool hasWon(int seat) {
    final cap = captured[seat];
    final w = cap['W'] ?? 0;
    final g = cap['G'] ?? 0;
    final b = cap['B'] ?? 0;
    final t = goalTargets;
    if (w >= t['W']!) return true;
    if (g >= t['G']!) return true;
    if (b >= t['B']!) return true;
    final each = t['EACH']!;
    if (w >= each && g >= each && b >= each) return true;
    return false;
  }

  String _winGoalDesc(int seat) {
    final cap = captured[seat];
    final w = cap['W'] ?? 0;
    final g = cap['G'] ?? 0;
    final b = cap['B'] ?? 0;
    final t = goalTargets;
    final each = t['EACH']!;
    if (w >= t['W']!) return '集齐 $w 颗白珠';
    if (g >= t['G']!) return '集齐 $g 颗灰珠';
    if (b >= t['B']!) return '集齐 $b 颗黑珠';
    if (w >= each && g >= each && b >= each) return '集齐白、灰、黑各 $each 颗';
    return '达成目标';
  }

  /// Checks all connected components of remaining rings. Any component where
  /// every ring has a marble is isolated/filled: [seat] captures all those marbles
  /// and removes those rings. Returns list of captured cell indices.
  List<int> _checkIsolationCaptures(int seat) {
    final visited = List<bool>.filled(cells.length, false);
    final isolatedCells = <int>[];

    for (var i = 0; i < cells.length; i++) {
      if (!cells[i].hasRing || visited[i]) continue;
      final comp = <int>[];
      final queue = <int>[i];
      visited[i] = true;
      var allFilled = true;

      var head = 0;
      while (head < queue.length) {
        final cur = queue[head++];
        comp.add(cur);
        if (cells[cur].marble == null) {
          allFilled = false;
        }
        for (var d = 0; d < 6; d++) {
          final nxt = neighborOf(cur, d);
          if (nxt != null && !visited[nxt]) {
            visited[nxt] = true;
            queue.add(nxt);
          }
        }
      }

      if (allFilled && comp.isNotEmpty) {
        for (final idx in comp) {
          final m = cells[idx].marble!;
          captured[seat][m] = (captured[seat][m] ?? 0) + 1;
          cells[idx].marble = null;
          cells[idx].hasRing = false;
          isolatedCells.add(idx);
        }
      }
    }
    return isolatedCells;
  }

  double _progressScore(int seat) {
    final cap = captured[seat];
    final w = cap['W'] ?? 0;
    final g = cap['G'] ?? 0;
    final b = cap['B'] ?? 0;
    final t = goalTargets;
    final each = t['EACH']!;
    final pW = w / t['W']!;
    final pG = g / t['G']!;
    final pB = b / t['B']!;
    final pEach = (w.clamp(0, each) + g.clamp(0, each) + b.clamp(0, each)) / (3 * each);
    var best = pW;
    if (pG > best) best = pG;
    if (pB > best) best = pB;
    if (pEach > best) best = pEach;
    return best * 100 + (w * 3 + g * 2 + b * 1.5);
  }

  void _checkStalemateOrEnd() {
    if (_over) return;
    if (hasWon(0)) {
      _over = true;
      winner = 0;
      winReason = '${name(0)} ${_winGoalDesc(0)}获胜！';
      host.log(winReason!);
      return;
    }
    if (hasWon(1)) {
      _over = true;
      winner = 1;
      winReason = '${name(1)} ${_winGoalDesc(1)}获胜！';
      host.log(winReason!);
      return;
    }

    final caps = legalCaptures(onlyFrom: mustContinueFrom);
    if (caps.isNotEmpty) return;

    final vac = vacantRings();
    final cols = availableColorsFor(turn);
    if (vac.isEmpty || cols.isEmpty) {
      // No moves left: check if all remaining rings are filled
      _checkIsolationCaptures(1 - turn);
      if (hasWon(0) || hasWon(1)) {
        final wSeat = hasWon(1 - turn) ? (1 - turn) : (hasWon(0) ? 0 : 1);
        _over = true;
        winner = wSeat;
        winReason = '${name(wSeat)} ${_winGoalDesc(wSeat)}获胜！';
        host.log(winReason!);
        return;
      }
      _over = true;
      final s0 = _progressScore(0);
      final s1 = _progressScore(1);
      if ((s0 - s1).abs() < 1e-6) {
        winner = null;
        winReason = '棋盘无空环可落子，双方进度相同判和';
      } else {
        winner = s0 > s1 ? 0 : 1;
        winReason = '棋盘已满，${name(winner!)} 收集进度领先获胜';
      }
      host.log(winReason!);
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    final caps = legalCaptures(onlyFrom: mustContinueFrom);

    if (caps.isNotEmpty) {
      if (type != 'capture') {
        throw GameError('存在可跳吃的弹珠，必须执行强制跳吃');
      }
      final from = asInt(action['from'], -1);
      final to = asInt(action['to'], -1);
      final match = caps.where((c) => c.from == from && c.to == to).toList();
      if (match.isEmpty) {
        throw GameError('非法的跳吃位置');
      }
      final jump = match.first;
      final jumperColor = cells[jump.from].marble!;
      final capturedColor = cells[jump.mid].marble!;

      cells[jump.from].marble = null;
      cells[jump.mid].marble = null;
      cells[jump.to].marble = jumperColor;
      captured[seat][capturedColor] = (captured[seat][capturedColor] ?? 0) + 1;
      stepCount++;

      final colorLabel = _colorName(capturedColor);
      host.log('${name(seat)} 跳吃俘获了 1 颗$colorLabel');

      lastMove = {
        'type': 'capture',
        'seat': seat,
        'from': jump.from,
        'mid': jump.mid,
        'to': jump.to,
        'captured': capturedColor,
      };

      if (hasWon(seat)) {
        mustContinueFrom = null;
        _over = true;
        winner = seat;
        winReason = '${name(seat)} ${_winGoalDesc(seat)}获胜！';
        host.log(winReason!);
        return;
      }

      // Check if same marble can continue jumping
      final nextJumps = legalCaptures(onlyFrom: jump.to);
      if (nextJumps.isNotEmpty) {
        mustContinueFrom = jump.to;
      } else {
        mustContinueFrom = null;
        turn = 1 - turn;
        _checkStalemateOrEnd();
      }
      return;
    }

    if (type != 'place') {
      throw GameError('当前无可跳吃弹珠，请放置弹珠并移除外圈空环');
    }

    final color = asStr(action['color']).toUpperCase();
    final placeCell = asInt(action['placeCell'] ?? action['cell'], -1);
    final removeCell = asInt(action['removeCell'] ?? action['ring'], -1);

    final availCols = availableColorsFor(seat);
    if (!availCols.contains(color)) {
      throw GameError('所选弹珠颜色不可用');
    }
    if (placeCell < 0 || placeCell >= cells.length || !cells[placeCell].hasRing || cells[placeCell].marble != null) {
      throw GameError('必须将弹珠放置在空棋环上');
    }

    final freeAfterPlace = freeVacantRings(excludeCell: placeCell);
    if (freeAfterPlace.isNotEmpty) {
      if (!freeAfterPlace.contains(removeCell)) {
        throw GameError('必须选择一个可自由滑出的外圈空棋环移除');
      }
    }

    // Deduct marble from supply (or player's captured pool if supply is empty)
    final supTotal = (supply['W'] ?? 0) + (supply['G'] ?? 0) + (supply['B'] ?? 0);
    final fromPool = supTotal > 0 ? 'supply' : 'captured';
    if (supTotal > 0) {
      supply[color] = (supply[color] ?? 0) - 1;
    } else {
      captured[seat][color] = (captured[seat][color] ?? 0) - 1;
    }

    cells[placeCell].marble = color;
    final isolated = <int>[];
    isolated.addAll(_checkIsolationCaptures(seat));

    var removedIdx = -1;
    if (freeAfterPlace.isNotEmpty &&
        removeCell >= 0 &&
        removeCell < cells.length &&
        cells[removeCell].hasRing &&
        cells[removeCell].marble == null) {
      cells[removeCell].hasRing = false;
      removedIdx = removeCell;
      isolated.addAll(_checkIsolationCaptures(seat));
    }

    stepCount++;
    lastMove = {
      'type': 'place',
      'seat': seat,
      'color': color,
      'fromPool': fromPool,
      'placeCell': placeCell,
      'removeCell': removedIdx,
      'isolated': isolated,
    };

    if (isolated.isNotEmpty) {
      host.log('${name(seat)} 放入${_colorName(color)}并移环，触发孤岛俘获 ${isolated.length} 颗弹珠！');
    } else {
      host.log('${name(seat)} 放入${_colorName(color)}并移除外环');
    }

    if (hasWon(seat)) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} ${_winGoalDesc(seat)}获胜！';
      host.log(winReason!);
      return;
    }

    turn = 1 - turn;
    _checkStalemateOrEnd();
  }

  String _colorName(String c) => switch (c) {
        'W' => '白珠',
        'G' => '灰珠',
        'B' => '黑珠',
        _ => '弹珠',
      };

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final caps = legalCaptures(onlyFrom: mustContinueFrom);
    if (caps.isNotEmpty) {
      if (botLevel == 0) {
        final pick = caps[rng.nextInt(caps.length)];
        return {'type': 'capture', 'from': pick.from, 'to': pick.to};
      }
      // Prefer captures that win immediately or enable multi-jumps or capture high-value marbles ('W' > 'G' > 'B')
      ({int from, int mid, int to}) best = caps.first;
      var bestScore = -1e9;
      for (final c in caps) {
        final capColor = cells[c.mid].marble!;
        var score = switch (capColor) {
          'W' => 35.0,
          'G' => 25.0,
          _ => 18.0,
        };
        final curCount = captured[seat][capColor] ?? 0;
        final target = goalTargets[capColor] ?? 4;
        if (curCount + 1 >= target) score += 1000.0;

        // Check if multi-jump is available after this jump
        final origFrom = cells[c.from].marble;
        final origMid = cells[c.mid].marble;
        cells[c.from].marble = null;
        cells[c.mid].marble = null;
        cells[c.to].marble = origFrom;
        final followUps = legalCaptures(onlyFrom: c.to);
        if (followUps.isNotEmpty) score += 45.0 * followUps.length;
        final oppJumps = legalCaptures();
        if (botLevel >= 2 && followUps.isEmpty) {
          score -= 12.0 * oppJumps.length;
        }
        cells[c.from].marble = origFrom;
        cells[c.mid].marble = origMid;
        cells[c.to].marble = null;

        score += rng.nextDouble() * 2.0;
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }
      return {'type': 'capture', 'from': best.from, 'to': best.to};
    }

    final vac = vacantRings();
    final cols = availableColorsFor(seat);
    if (vac.isEmpty || cols.isEmpty) return null;

    if (botLevel == 0) {
      final pCell = vac[rng.nextInt(vac.length)];
      final col = cols[rng.nextInt(cols.length)];
      final free = freeVacantRings(excludeCell: pCell);
      final rCell = free.isEmpty ? -1 : free[rng.nextInt(free.length)];
      return {
        'type': 'place',
        'color': col,
        'placeCell': pCell,
        'removeCell': rCell,
      };
    }

    // Evaluate candidate (color, placeCell, removeCell) moves:
    // Avoid giving opponent immediate captures, and prefer isolating filled components!
    final colorChoice = cols.contains('B')
        ? 'B'
        : (cols.contains('G') ? 'G' : cols.first);

    var bestP = vac.first;
    var bestR = -1;
    var bestCol = colorChoice;
    var bestScore = -1e9;

    final candidatePlaces = shuffled(vac, rng);
    final maxPlaceChecks = candidatePlaces.length > 16 ? 16 : candidatePlaces.length;

    for (var i = 0; i < maxPlaceChecks; i++) {
      final p = candidatePlaces[i];
      final free = freeVacantRings(excludeCell: p);
      final rCandidates = free.isEmpty ? const [-1] : (free.length > 8 ? shuffled(free, rng).sublist(0, 8) : free);

      for (final r in rCandidates) {
        for (final col in cols) {
          // Simulate placing at p and removing ring at r
          cells[p].marble = col;
          if (r >= 0) cells[r].hasRing = false;

          final oppCaptures = legalCaptures();
          var score = 0.0;
          if (oppCaptures.isNotEmpty) {
            // Opponent gets mandatory capture! Penalize heavily especially for 'W'
            final givePenalty = col == 'W' ? 60.0 : (col == 'G' ? 40.0 : 25.0);
            score -= givePenalty + oppCaptures.length * 15.0;
          } else {
            // Prefer placing low-value marbles ('B' > 'G' > 'W') so we don't feed White marbles
            score += col == 'B' ? 8.0 : (col == 'G' ? 5.0 : 1.0);
          }

          // Check if this move creates an isolated filled component!
          if (botLevel >= 1) {
            final isoCount = _countPotentialIsolatedMarbles();
            if (isoCount > 0) {
              score += 120.0 * isoCount;
            }
          }

          if (r >= 0) cells[r].hasRing = true;
          cells[p].marble = null;

          score += rng.nextDouble() * 1.5;
          if (score > bestScore) {
            bestScore = score;
            bestP = p;
            bestR = r;
            bestCol = col;
          }
        }
      }
    }

    return {
      'type': 'place',
      'color': bestCol,
      'placeCell': bestP,
      'removeCell': bestR,
    };
  }

  int _countPotentialIsolatedMarbles() {
    final visited = List<bool>.filled(cells.length, false);
    var count = 0;
    for (var i = 0; i < cells.length; i++) {
      if (!cells[i].hasRing || visited[i]) continue;
      final comp = <int>[];
      final q = <int>[i];
      visited[i] = true;
      var allFilled = true;
      var head = 0;
      while (head < q.length) {
        final cur = q[head++];
        comp.add(cur);
        if (cells[cur].marble == null) allFilled = false;
        for (var d = 0; d < 6; d++) {
          final nxt = neighborOf(cur, d);
          if (nxt != null && !visited[nxt]) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
      if (allFilled) count += comp.length;
    }
    return count;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final caps = _over ? const <({int from, int mid, int to})>[] : legalCaptures(onlyFrom: mustContinueFrom);
    final freeRings = _over || caps.isNotEmpty ? const <int>[] : freeVacantRings();
    return {
      'mode': mode,
      'boardSize': boardSize,
      'turn': turn,
      'mustContinueFrom': mustContinueFrom,
      'mustCapture': caps.isNotEmpty,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'stepCount': stepCount,
      'goals': goalTargets,
      'supply': Map<String, int>.of(supply),
      'captured': [
        Map<String, int>.of(captured[0]),
        Map<String, int>.of(captured[1]),
      ],
      'availableColors': _over ? const <String>[] : availableColorsFor(turn),
      'cells': [
        for (final c in cells)
          {
            'index': c.index,
            'q': c.q,
            'r': c.r,
            'ring': c.hasRing,
            'marble': c.marble,
          },
      ],
      'legalCaptures': [
        for (final c in caps) {'from': c.from, 'mid': c.mid, 'to': c.to},
      ],
      'freeRings': freeRings,
      'lastMove': lastMove,
    };
  }
}
