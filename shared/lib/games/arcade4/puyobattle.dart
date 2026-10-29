import 'dart:math';

import '../../src/engine.dart';

/// 魔法气泡对战 (Puyo Puyo Battle) — 2..4 players simultaneous falling-pair puzzle battle.
///
/// Grid per player: 6 columns (0..5) x 12 rows (0..11, row 0 = top, row 11 = bottom).
/// Cell values:
///   0 = Empty
///   1 = Red (红)
///   2 = Green (绿)
///   3 = Blue (蓝)
///   4 = Yellow (黄)
///   5 = Gray Garbage Puyo (障碍气泡)
///
/// Orientations (`rot` 0..3):
///   0 = sub above main: main at (r, col), sub at (r - 1, col)
///   1 = sub right of main: main at (r, col), sub at (r, col + 1)
///   2 = sub below main: main at (r - 1, col), sub at (r, col)
///   3 = sub left of main: main at (r, col), sub at (r, col - 1)
class PuyoBattle extends GameEngine {
  static const int cols = 6;
  static const int rows = 12;
  static const int spawnCol = 2;
  static const int garbageColor = 5;

  late final int numColors;
  late final bool highGarbage;

  /// Shared sequence of pairs `(mainColor, subColor)` so all players get the same pieces.
  final List<(int, int)> pieceQueue = [];

  /// Per-player 12x6 grid (`grids[seat][r * cols + c]`).
  late final List<List<int>> grids;
  late final List<bool> alive;
  late final List<int> scores;
  late final List<int> maxChains;
  late final List<int> pendingGarbage;
  late final List<int> pieceIndex;
  late final List<int> curCol;
  late final List<int> curRot;
  late final List<bool> actedInWave;
  late final List<int> survivalWave;
  late final List<String> lastEvents;

  int wave = 1;
  bool _over = false;
  List<int>? _placings;

  PuyoBattle(super.setup) {
    numColors = setup.opt<int>('colors', 4).clamp(3, 4);
    highGarbage = setup.opt<String>('garbageRate', 'normal') == 'high';
  }

  @override
  int get botDelayMs => 450;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  bool get canResign => true;

  @override
  void start() {
    grids = List.generate(players, (_) => List.filled(rows * cols, 0));
    alive = List.filled(players, true);
    scores = List.filled(players, 0);
    maxChains = List.filled(players, 0);
    pendingGarbage = List.filled(players, 0);
    pieceIndex = List.filled(players, 0);
    curCol = List.filled(players, spawnCol);
    curRot = List.filled(players, 0);
    actedInWave = List.filled(players, false);
    survivalWave = List.filled(players, 0);
    lastEvents = List.filled(players, '准备落下气泡');
    _ensureQueue(128);
    host.log('魔法气泡对战开始！4 个同色气泡相连即可消除，连锁可向对手发送障碍气泡！');
  }

  void _ensureQueue(int minLen) {
    while (pieceQueue.length < minLen) {
      final m = 1 + setup.rng.nextInt(numColors);
      final s = 1 + setup.rng.nextInt(numColors);
      pieceQueue.add((m, s));
    }
  }

  (int, int) currentPair(int seat) => pieceQueue[pieceIndex[seat] % pieceQueue.length];

  (int, int) nextPair(int seat, [int offset = 1]) =>
      pieceQueue[(pieceIndex[seat] + offset) % pieceQueue.length];

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    return [
      for (var s = 0; s < players; s++)
        if (alive[s] && !actedInWave[s]) s,
    ];
  }

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players || !alive[seat]) {
      throw GameError('当前无法认输');
    }
    alive[seat] = false;
    actedInWave[seat] = true;
    survivalWave[seat] = -1;
    lastEvents[seat] = '认输退出';
    host.log('${name(seat)} 认输退出了对战');
    _checkWaveOrEnd();
  }

  /// Clamp column for a given rotation so both puyos stay in `0..cols-1`.
  static int clampColForRot(int col, int rot) {
    final r = rot & 3;
    var c = col.clamp(0, cols - 1);
    if (r == 1 && c >= cols - 1) c = cols - 2;
    if (r == 3 && c <= 0) c = 1;
    return c;
  }

  /// Check if dropping in `(col, rot)` has room at the top of the grid.
  static bool canDropAt(List<int> grid, int col, int rot) {
    final r = rot & 3;
    final c = clampColForRot(col, r);
    if (c != col) return false;
    if (r == 0 || r == 2) {
      // Vertical pair needs at least 1 empty cell in column (ideally 2, but even 1 top cell allows partial/top placement)
      return grid[c] == 0;
    } else {
      final sc = r == 1 ? c + 1 : c - 1;
      return grid[c] == 0 && grid[sc] == 0;
    }
  }

  /// Apply gravity to `grid` in-place: every Puyo falls to the lowest available row in its column.
  static bool applyGravity(List<int> grid) {
    var moved = false;
    for (var c = 0; c < cols; c++) {
      var writeRow = rows - 1;
      for (var r = rows - 1; r >= 0; r--) {
        final v = grid[r * cols + c];
        if (v != 0) {
          if (writeRow != r) {
            grid[writeRow * cols + c] = v;
            grid[r * cols + c] = 0;
            moved = true;
          }
          writeRow--;
        }
      }
    }
    return moved;
  }

  /// Place a pair `(mainColor, subColor)` at `(col, rot)` onto `grid` and apply initial gravity.
  /// Returns false if the target column(s) cannot accept the pair at all.
  static bool placePair(List<int> grid, int mainColor, int subColor, int col, int rot) {
    final r = rot & 3;
    final c = clampColForRot(col, r);
    if (c != col) return false;

    int lowestEmptyRow(int column) {
      for (var row = rows - 1; row >= 0; row--) {
        if (grid[row * cols + column] == 0) return row;
      }
      return -1;
    }

    if (r == 0) {
      // sub above main
      final mr = lowestEmptyRow(c);
      if (mr < 0) return false;
      grid[mr * cols + c] = mainColor;
      final sr = lowestEmptyRow(c);
      if (sr >= 0) {
        grid[sr * cols + c] = subColor;
      }
      return true;
    } else if (r == 2) {
      // sub below main
      final sr = lowestEmptyRow(c);
      if (sr < 0) return false;
      grid[sr * cols + c] = subColor;
      final mr = lowestEmptyRow(c);
      if (mr >= 0) {
        grid[mr * cols + c] = mainColor;
      }
      return true;
    } else {
      final sc = r == 1 ? c + 1 : c - 1;
      final mr = lowestEmptyRow(c);
      final sr = lowestEmptyRow(sc);
      if (mr < 0 || sr < 0) return false;
      grid[mr * cols + c] = mainColor;
      grid[sr * cols + sc] = subColor;
      return true;
    }
  }

  /// Resolve all gravity + chain pops on `grid` in-place.
  /// Returns `(chains, totalClearedColored, totalClearedGarbage, scoreGained, garbageGenerated)`.
  static (int, int, int, int, int) resolveChains(List<int> grid, {bool highGarbage = false}) {
    var chains = 0;
    var totalColored = 0;
    var totalGarbage = 0;
    var totalScore = 0;
    var totalGarbageGen = 0;

    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    while (true) {
      applyGravity(grid);

      final visited = List.filled(rows * cols, false);
      final toPopColored = <int>[];
      final colorsInStep = <int>{};
      var groupsInStep = 0;

      for (var idx = 0; idx < rows * cols; idx++) {
        final color = grid[idx];
        if (color < 1 || color > 4 || visited[idx]) continue;
        // BFS for orthogonal same-colored group
        final comp = <int>[idx];
        visited[idx] = true;
        var head = 0;
        while (head < comp.length) {
          final cur = comp[head++];
          final cr = cur ~/ cols;
          final cc = cur % cols;
          for (final (dr, dc) in dirs) {
            final nr = cr + dr;
            final nc = cc + dc;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final nIdx = nr * cols + nc;
            if (!visited[nIdx] && grid[nIdx] == color) {
              visited[nIdx] = true;
              comp.add(nIdx);
            }
          }
        }
        if (comp.length >= 4) {
          groupsInStep++;
          colorsInStep.add(color);
          toPopColored.addAll(comp);
        }
      }

      if (toPopColored.isEmpty) break;

      chains++;
      final poppedSet = toPopColored.toSet();
      final adjacentGarbage = <int>{};

      // Find all Gray Garbage Puyos orthogonally adjacent to any popping colored Puyo
      for (final idx in toPopColored) {
        final cr = idx ~/ cols;
        final cc = idx % cols;
        for (final (dr, dc) in dirs) {
          final nr = cr + dr;
          final nc = cc + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final nIdx = nr * cols + nc;
          if (grid[nIdx] == garbageColor && !poppedSet.contains(nIdx)) {
            adjacentGarbage.add(nIdx);
          }
        }
      }

      for (final idx in toPopColored) {
        grid[idx] = 0;
      }
      for (final idx in adjacentGarbage) {
        grid[idx] = 0;
      }

      final stepCleared = toPopColored.length;
      totalColored += stepCleared;
      totalGarbage += adjacentGarbage.length;

      final chainPower = switch (chains) {
        1 => 1,
        2 => 8,
        3 => 16,
        4 => 32,
        5 => 64,
        _ => 64 + (chains - 5) * 32,
      };
      final colorBonus = (colorsInStep.length - 1) * 3;
      final groupBonus = (groupsInStep - 1) * 2 + (stepCleared - 4);
      final mult = (chainPower + colorBonus + groupBonus).clamp(1, 999);
      totalScore += stepCleared * 10 * mult;

      // Garbage generated by this chain step
      final baseGarbage = switch (chains) {
        1 => max(1, stepCleared - 3 + (groupsInStep - 1) * 2),
        2 => 6 + (stepCleared - 4),
        3 => 12 + (stepCleared - 4) * 2,
        4 => 24 + (stepCleared - 4) * 2,
        _ => 24 + (chains - 4) * 18 + (stepCleared - 4) * 2,
      };
      totalGarbageGen += highGarbage ? ((baseGarbage * 3 + 1) ~/ 2) : baseGarbage;
    }

    applyGravity(grid);
    return (chains, totalColored, totalGarbage, totalScore, totalGarbageGen);
  }

  /// Drop up to 18 pending garbage puyos onto `seat`'s board.
  void _dropIncomingGarbage(int seat) {
    final pending = pendingGarbage[seat];
    if (pending <= 0) return;
    final dropCount = min(pending, 18);
    pendingGarbage[seat] -= dropCount;

    final grid = grids[seat];
    final fullRows = dropCount ~/ cols;
    final rem = dropCount % cols;

    int lowestEmpty(int c) {
      for (var r = rows - 1; r >= 0; r--) {
        if (grid[r * cols + c] == 0) return r;
      }
      return -1;
    }

    for (var i = 0; i < fullRows; i++) {
      for (var c = 0; c < cols; c++) {
        final r = lowestEmpty(c);
        if (r >= 0) grid[r * cols + c] = garbageColor;
      }
    }
    if (rem > 0) {
      final colOrder = shuffled([0, 1, 2, 3, 4, 5], rng);
      for (var i = 0; i < rem; i++) {
        final c = colOrder[i];
        final r = lowestEmpty(c);
        if (r >= 0) grid[r * cols + c] = garbageColor;
      }
    }
    applyGravity(grid);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players || !alive[seat]) {
      throw GameError('你已出局，无法操作');
    }
    if (actedInWave[seat]) {
      throw GameError('本轮已落下气泡，请等待其他玩家');
    }

    final type = asStr(action['type']);
    if (type == 'move') {
      final dir = asInt(action['dir'], 0);
      if (dir != -1 && dir != 1) throw GameError('移动方向无效');
      curCol[seat] = clampColForRot(curCol[seat] + dir, curRot[seat]);
      return;
    }
    if (type == 'rotate') {
      final dir = asInt(action['dir'], 1);
      final nextRot = (curRot[seat] + (dir >= 0 ? 1 : 3)) & 3;
      curRot[seat] = nextRot;
      curCol[seat] = clampColForRot(curCol[seat], nextRot);
      return;
    }
    if (type != 'drop') {
      throw GameError('未知操作类型');
    }

    final reqRot = action.containsKey('rot') ? (asInt(action['rot'], curRot[seat]) & 3) : curRot[seat];
    final reqCol = action.containsKey('col')
        ? clampColForRot(asInt(action['col'], curCol[seat]), reqRot)
        : clampColForRot(curCol[seat], reqRot);

    final grid = grids[seat];
    final (mainC, subC) = currentPair(seat);

    // Check if any valid placement exists on the board
    var anyValid = false;
    for (var r = 0; r < 4 && !anyValid; r++) {
      for (var c = 0; c < cols; c++) {
        if (canDropAt(grid, c, r)) {
          anyValid = true;
          break;
        }
      }
    }

    if (anyValid && !canDropAt(grid, reqCol, reqRot)) {
      throw GameError('该列已满，无法在此位置落下');
    }

    curCol[seat] = reqCol;
    curRot[seat] = reqRot;
    actedInWave[seat] = true;
    pieceIndex[seat]++;
    _ensureQueue(pieceIndex[seat] + 4);

    if (!anyValid) {
      // Topped out immediately
      alive[seat] = false;
      survivalWave[seat] = wave;
      lastEvents[seat] = '顶部溢出，淘汰出局！';
      host.log('${name(seat)} 棋盘已满，淘汰出局！');
      _checkWaveOrEnd();
      return;
    }

    placePair(grid, mainC, subC, reqCol, reqRot);
    final (chains, clearedColored, clearedGarbage, gainedScore, genGarbage) =
        resolveChains(grid, highGarbage: highGarbage);

    scores[seat] += gainedScore;
    if (chains > maxChains[seat]) {
      maxChains[seat] = chains;
    }

    if (chains > 0) {
      // Counter own pending garbage first (相杀)
      final offset = min(genGarbage, pendingGarbage[seat]);
      pendingGarbage[seat] -= offset;
      final netSent = genGarbage - offset;

      if (netSent > 0) {
        for (var opp = 0; opp < players; opp++) {
          if (opp != seat && alive[opp]) {
            pendingGarbage[opp] += netSent;
          }
        }
      }

      final parts = <String>['$chains 连锁！消除 $clearedColored 颗气泡'];
      if (clearedGarbage > 0) parts.add('击碎 $clearedGarbage 颗障碍');
      if (offset > 0) parts.add('相杀抵消 $offset 颗障碍');
      if (netSent > 0) parts.add('发送 $netSent 颗障碍气泡');
      lastEvents[seat] = parts.join(' · ');
      if (chains >= 2 || netSent >= 4) {
        host.log('${name(seat)} 打出 ${parts.join('，')}！');
      }
    } else {
      // If no chain occurred, any pending garbage falls onto the board
      if (pendingGarbage[seat] > 0) {
        final before = pendingGarbage[seat];
        _dropIncomingGarbage(seat);
        final dropped = before - pendingGarbage[seat];
        lastEvents[seat] = '落子完成 · 承受 $dropped 颗障碍气泡';
      } else {
        lastEvents[seat] = '落子第 ${reqCol + 1} 列';
      }
    }

    // Reset cursor to default spawn for next piece
    curCol[seat] = spawnCol;
    curRot[seat] = 0;

    // Check if spawn column (col 2, row 0) is now blocked
    if (grid[spawnCol] != 0) {
      alive[seat] = false;
      survivalWave[seat] = wave;
      lastEvents[seat] = '${lastEvents[seat]} · 出生点被堵淘汰！';
      host.log('${name(seat)} 出生点（第 3 列顶部）被堵住，淘汰出局！');
    }

    _checkWaveOrEnd();
  }

  void _checkWaveOrEnd() {
    final aliveSeats = [for (var s = 0; s < players; s++) if (alive[s]) s];
    if (aliveSeats.length <= 1) {
      _finishGame();
      return;
    }

    // Check if all alive players have acted in this wave
    if (aliveSeats.every((s) => actedInWave[s])) {
      wave++;
      for (final s in aliveSeats) {
        actedInWave[s] = false;
        // Sudden death pressure after wave 22 so games always conclude briskly
        if (wave > 22) {
          pendingGarbage[s] += 2 + (wave - 22) ~/ 3;
        }
      }
    }
  }

  void _finishGame() {
    _over = true;
    for (var s = 0; s < players; s++) {
      if (alive[s]) {
        survivalWave[s] = wave + 1000;
      }
    }
    final composite = [
      for (var s = 0; s < players; s++) survivalWave[s] * 1000000 + scores[s],
    ];
    _placings = rankByScore(composite);
    final winners = [for (var s = 0; s < players; s++) if (_placings![s] == 1) name(s)];
    host.log('游戏结束！获胜者：${winners.join('、')}');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !alive[seat] || actedInWave[seat]) return null;
    final grid = grids[seat];
    final (mainC, subC) = currentPair(seat);

    final candidates = <(int, int, double)>[];
    for (var rot = 0; rot < 4; rot++) {
      for (var col = 0; col < cols; col++) {
        if (clampColForRot(col, rot) != col) continue;
        if (!canDropAt(grid, col, rot)) continue;

        final sim = List<int>.of(grid);
        if (!placePair(sim, mainC, subC, col, rot)) continue;
        final (chains, clearedC, clearedG, gainedScore, genGarbage) =
            resolveChains(sim, highGarbage: highGarbage);

        // If this move causes self top-out at spawnCol, heavily penalize
        if (sim[spawnCol] != 0) {
          candidates.add((col, rot, -1e9 + gainedScore));
          continue;
        }

        var eval = 0.0;
        // Reward chains & garbage countering
        eval += chains * 450.0 + clearedC * 45.0 + clearedG * 60.0 + genGarbage * 35.0;

        // Reward connected same-color groups (2 or 3 in a group) for chain building
        eval += _evaluateBoardStructure(sim) * (botLevel == 2 ? 1.4 : 1.0);

        // Penalize column heights, especially the center spawn column
        var maxH = 0;
        for (var c = 0; c < cols; c++) {
          var h = 0;
          for (var r = 0; r < rows; r++) {
            if (sim[r * cols + c] != 0) {
              h = rows - r;
              break;
            }
          }
          if (h > maxH) maxH = h;
          eval -= h * (c == spawnCol ? 28.0 : 8.0);
        }
        if (maxH >= 10) eval -= (maxH - 9) * 180.0;

        // Small jitter so bots don't play identically
        eval += rng.nextDouble() * (botLevel == 0 ? 500.0 : 5.0);
        candidates.add((col, rot, eval));
      }
    }

    if (candidates.isEmpty) {
      return {'type': 'drop', 'col': spawnCol, 'rot': 0};
    }

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = candidates[rng.nextInt(candidates.length)];
      return {'type': 'drop', 'col': pick.$1, 'rot': pick.$2};
    }

    candidates.sort((a, b) => b.$3.compareTo(a.$3));
    final best = candidates.first;
    return {'type': 'drop', 'col': best.$1, 'rot': best.$2};
  }

  static double _evaluateBoardStructure(List<int> grid) {
    var score = 0.0;
    final visited = List.filled(rows * cols, false);
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    for (var idx = 0; idx < rows * cols; idx++) {
      final color = grid[idx];
      if (color < 1 || color > 4 || visited[idx]) continue;
      final comp = <int>[idx];
      visited[idx] = true;
      var head = 0;
      while (head < comp.length) {
        final cur = comp[head++];
        final cr = cur ~/ cols;
        final cc = cur % cols;
        for (final (dr, dc) in dirs) {
          final nr = cr + dr;
          final nc = cc + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final nIdx = nr * cols + nc;
          if (!visited[nIdx] && grid[nIdx] == color) {
            visited[nIdx] = true;
            comp.add(nIdx);
          }
        }
      }
      if (comp.length == 2) score += 22.0;
      if (comp.length == 3) score += 75.0;
    }
    return score;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final playersView = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final cur = currentPair(s);
      final n1 = nextPair(s, 1);
      final n2 = nextPair(s, 2);
      playersView.add({
        'seat': s,
        'grid': List<int>.of(grids[s]),
        'alive': alive[s],
        'score': scores[s],
        'maxChain': maxChains[s],
        'pendingGarbage': pendingGarbage[s],
        'curPair': [cur.$1, cur.$2],
        'next1': [n1.$1, n1.$2],
        'next2': [n2.$1, n2.$2],
        'col': curCol[s],
        'rot': curRot[s],
        'acted': actedInWave[s],
        'lastEvent': lastEvents[s],
      });
    }
    return {
      'cols': cols,
      'rows': rows,
      'spawnCol': spawnCol,
      'numColors': numColors,
      'wave': wave,
      'players': playersView,
      'waitingFor': waitingFor,
      'over': _over,
      if (_placings != null) 'placings': _placings,
    };
  }
}
