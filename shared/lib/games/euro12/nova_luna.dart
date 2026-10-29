import '../../src/ai.dart';
import '../../src/engine.dart';

const List<String> novaColorNames = ['青', '黄', '红', '蓝'];
const List<String> novaColorEmojis = ['🩵', '🟨', '🟥', '🟦'];

class NovaTile {
  final int id;
  final int color; // 0: Cyan, 1: Yellow, 2: Red, 3: Blue
  final int cost; // 1..7
  final List<List<int>> tasks; // Each task is a list of 1..4 color indices (0..3)

  const NovaTile({
    required this.id,
    required this.color,
    required this.cost,
    required this.tasks,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color,
        'cost': cost,
        'tasks': tasks,
      };
}

class PlacedNovaTile {
  final NovaTile tile;
  final List<bool> doneTasks;

  PlacedNovaTile(this.tile)
      : doneTasks = List<bool>.filled(tile.tasks.length, false);

  Map<String, dynamic> toJson() => {
        'tile': tile.toJson(),
        'doneTasks': doneTasks,
      };
}

/// Build the 68-tile Nova Luna deck (17 tiles per color, costs 1..7).
List<NovaTile> buildNovaDeck() {
  final out = <NovaTile>[];
  var id = 1;
  for (var col = 0; col < 4; col++) {
    final c1 = (col + 1) % 4;
    final c2 = (col + 2) % 4;
    final c3 = (col + 3) % 4;
    final specs = <(int, List<List<int>>)>[
      (1, const []),
      (2, [
        [col],
        [c1]
      ]),
      (2, [
        [c2, c2]
      ]),
      (3, [
        [col, c1],
        [c2]
      ]),
      (3, [
        [c1, c1],
        [c3, c3]
      ]),
      (3, [
        [col, c2, c3]
      ]),
      (4, [
        [col, col],
        [c1, c2]
      ]),
      (4, [
        [c1, c1, c1],
        [c2]
      ]),
      (4, [
        [c2, c3],
        [col, c1]
      ]),
      (5, [
        [col, col, col],
        [c1, c1]
      ]),
      (5, [
        [c1, c2, c3],
        [col, c2]
      ]),
      (5, [
        [c3, c3, c3],
        [c1, c2]
      ]),
      (6, [
        [col, col, c1],
        [c2, c2, c3],
        [c1]
      ]),
      (6, [
        [0, 1, 2, 3],
        [col, c3]
      ]),
      (6, [
        [c1, c1, c2, c2],
        [c3, c3]
      ]),
      (7, [
        [col, col, col, col],
        [c1, c2, c3]
      ]),
      (7, [
        [c1, c1, c1],
        [c2, c2, c2],
        [c3, c3]
      ]),
    ];
    for (final (cost, tasks) in specs) {
      out.add(NovaTile(id: id++, color: col, cost: cost, tasks: tasks));
    }
  }
  return out;
}

class NovaLunaGame extends GameEngine {
  NovaLunaGame(super.setup);

  static const int gridSize = 7;

  final _ai = AiSlot();

  late int initialDisks;
  late List<NovaTile> deck;

  /// 12-space Moon Wheel (`wheel[moonPos]` is always null).
  late List<NovaTile?> wheel;
  int moonPos = 0;

  /// Time track position per player (`0..`).
  late List<int> timePos;

  /// Stack order for ties on the time track: earlier in [timeOrder] = higher on stack (acts first when tied).
  late List<int> timeOrder;

  /// Remaining disks per player (`initialDisks` down to `0`).
  late List<int> disksLeft;

  /// Placed disks count (score) per player.
  late List<int> score;

  /// Personal 7x7 tableau per player.
  late List<List<List<PlacedNovaTile?>>> tableau;

  int turn = 0;
  int stepCount = 0;
  bool _over = false;
  int? resignedSeat;
  String lastAction = '新月升起，请落后最多的玩家从月轮顺时针前 3 枚板块中选择！';

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over && players > 1;

  @override
  void resign(int seat) {
    if (_over) return;
    resignedSeat = seat;
    _over = true;
    host.log('${name(seat)} 认输');
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (resignedSeat != null) {
      final winners = [
        for (var i = 0; i < players; i++)
          if (i != resignedSeat) i
      ];
      return rankWinners(players, winners);
    }
    // Fewer disksLeft wins; tie-breaker: further behind on time track (smaller timePos), then earlier in timeOrder
    final rankVals = [
      for (var s = 0; s < players; s++)
        (initialDisks - disksLeft[s]) * 10000 -
            timePos[s] * 10 -
            timeOrder.indexOf(s),
    ];
    return rankByScore(rankVals);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    initialDisks = setup.opt<int>('disks', 16);
    deck = shuffled(buildNovaDeck(), rng);
    wheel = List<NovaTile?>.filled(12, null);
    moonPos = 0;
    for (var i = 1; i < 12; i++) {
      if (deck.isNotEmpty) {
        wheel[i] = deck.removeLast();
      }
    }

    timePos = List<int>.filled(players, 0);
    timeOrder = [for (var s = 0; s < players; s++) s];
    disksLeft = List<int>.filled(players, initialDisks);
    score = List<int>.filled(players, 0);
    tableau = [
      for (var s = 0; s < players; s++)
        [
          for (var r = 0; r < gridSize; r++)
            List<PlacedNovaTile?>.filled(gridSize, null),
        ],
    ];
    turn = _computeNextTurn();
  }

  int _computeNextTurn() {
    var bestSeat = timeOrder.first;
    var bestTime = timePos[bestSeat];
    for (final s in timeOrder) {
      if (timePos[s] < bestTime) {
        bestTime = timePos[s];
        bestSeat = s;
      }
    }
    return bestSeat;
  }

  /// Number of tiles currently on the 12-space Moon Wheel.
  int get wheelTileCount => wheel.where((t) => t != null).length;

  /// Up to 3 clockwise non-empty wheel slot indices starting after [moonPos].
  List<int> availableWheelSlots() {
    final out = <int>[];
    for (var offset = 1; offset < 12; offset++) {
      final idx = (moonPos + offset) % 12;
      if (wheel[idx] != null) {
        out.add(idx);
        if (out.length == 3) break;
      }
    }
    return out;
  }

  /// Whether the active player may optionally refill the Moon Wheel (`<= 2` tiles on wheel and `deck.isNotEmpty`).
  bool get canRefill => wheelTileCount <= 2 && deck.isNotEmpty;

  void _refillWheel() {
    for (var offset = 1; offset < 12; offset++) {
      final idx = (moonPos + offset) % 12;
      if (wheel[idx] == null && deck.isNotEmpty) {
        wheel[idx] = deck.removeLast();
      }
    }
  }

  bool hasAnyTile(int seat) {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (tableau[seat][r][c] != null) return true;
      }
    }
    return false;
  }

  /// Returns all valid `(r, c)` coordinates where [seat] can place a new tile.
  List<(int, int)> validPlacements(int seat) {
    if (!hasAnyTile(seat)) {
      // First tile can go anywhere on the 7x7 tableau (center 3,3 preferred)
      return [
        for (var r = 0; r < gridSize; r++)
          for (var c = 0; c < gridSize; c++) (r, c),
      ];
    }
    final adj = <(int, int)>[];
    final anyEmpty = <(int, int)>[];
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (tableau[seat][r][c] != null) continue;
        anyEmpty.add((r, c));
        var hasOrtho = false;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 &&
              nr < gridSize &&
              nc >= 0 &&
              nc < gridSize &&
              tableau[seat][nr][nc] != null) {
            hasOrtho = true;
            break;
          }
        }
        if (hasOrtho) adj.add((r, c));
      }
    }
    return adj.isNotEmpty ? adj : anyEmpty;
  }

  bool canPlaceAt(int seat, int r, int c) {
    if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
    if (tableau[seat][r][c] != null) return false;
    return validPlacements(seat).contains((r, c));
  }

  /// Size of orthogonally connected color [targetColor] chains adjacent to `(tr, tc)` (excluding `(tr, tc)` itself).
  int adjacentColorChainCount(int seat, int tr, int tc, int targetColor) {
    final visited = <(int, int)>{(tr, tc)};
    var count = 0;
    for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
      final sr = tr + dr;
      final sc = tc + dc;
      if (sr < 0 || sr >= gridSize || sc < 0 || sc >= gridSize) continue;
      final startCell = tableau[seat][sr][sc];
      if (startCell == null ||
          startCell.tile.color != targetColor ||
          visited.contains((sr, sc))) {
        continue;
      }
      // BFS through orthogonally connected tiles of targetColor
      final q = <(int, int)>[(sr, sc)];
      visited.add((sr, sc));
      while (q.isNotEmpty) {
        final (cr, cc) = q.removeLast();
        count++;
        for (final (or, oc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = cr + or;
          final nc = cc + oc;
          if (nr < 0 || nr >= gridSize || nc < 0 || nc >= gridSize) continue;
          if (visited.contains((nr, nc))) continue;
          final nextCell = tableau[seat][nr][nc];
          if (nextCell != null && nextCell.tile.color == targetColor) {
            visited.add((nr, nc));
            q.add((nr, nc));
          }
        }
      }
    }
    return count;
  }

  /// Re-evaluates all tasks across [seat]'s tableau and returns how many new tasks were completed.
  int recalcTasks(int seat) {
    var newlyCompleted = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final placed = tableau[seat][r][c];
        if (placed == null) continue;
        for (var tIdx = 0; tIdx < placed.tile.tasks.length; tIdx++) {
          if (placed.doneTasks[tIdx]) continue;
          final req = placed.tile.tasks[tIdx];
          final needed = <int, int>{};
          for (final col in req) {
            needed[col] = (needed[col] ?? 0) + 1;
          }
          var ok = true;
          for (final entry in needed.entries) {
            if (adjacentColorChainCount(seat, r, c, entry.key) < entry.value) {
              ok = false;
              break;
            }
          }
          if (ok) {
            placed.doneTasks[tIdx] = true;
            if (disksLeft[seat] > 0) {
              disksLeft[seat]--;
              newlyCompleted++;
            }
          }
        }
      }
    }
    score[seat] = initialDisks - disksLeft[seat];
    return newlyCompleted;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type == 'refill') {
      if (!canRefill) {
        throw GameError('只有当月轮剩余板块不超过 2 枚且牌库非空时才能补牌');
      }
      _refillWheel();
      lastAction = '${name(seat)} 刷新了新月轮盘！';
      host.log(lastAction);
      return;
    }

    if (type == 'pick') {
      final slot = asInt(action['wheelSlot'], -1);
      final avail = availableWheelSlots();
      if (!avail.contains(slot)) {
        throw GameError('只能选择月标🌙顺时针方向前 3 枚板块之一');
      }
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (!canPlaceAt(seat, r, c)) {
        throw GameError('必须放置在已有板块正交相邻的空格上');
      }

      final tile = wheel[slot]!;
      wheel[slot] = null;
      moonPos = slot;

      // Advance time track and place player on TOP of stack at new position
      timePos[seat] += tile.cost;
      timeOrder.remove(seat);
      timeOrder.insert(0, seat);

      tableau[seat][r][c] = PlacedNovaTile(tile);
      final doneNow = recalcTasks(seat);
      stepCount++;

      final doneMsg = doneNow > 0 ? '，完成 $doneNow 项任务（剩余 ${disksLeft[seat]} 枚圆盘）！' : '';
      lastAction =
          '${name(seat)} 拿取了 ${novaColorEmojis[tile.color]}${novaColorNames[tile.color]}色(耗时${tile.cost}) 放置在 ($r,$c)$doneMsg';
      host.log(lastAction);

      // Immediate victory if disksLeft reaches 0
      if (disksLeft[seat] <= 0) {
        _over = true;
        host.log('🎉 ${name(seat)} 放完了所有圆盘，赢得《新月任务》胜利！');
        return;
      }

      // Auto-refill wheel if empty
      if (wheelTileCount == 0 && deck.isNotEmpty) {
        _refillWheel();
        host.log('新月轮盘已空，自动补满板块！');
      }

      final nextSeat = _computeNextTurn();
      if (wheelTileCount == 0 || validPlacements(nextSeat).isEmpty) {
        _over = true;
        host.log('新月轮盘板块耗尽，游戏结束！');
        return;
      }

      turn = nextSeat;
      return;
    }

    throw GameError('未知操作: $type');
  }

  Map<String, dynamic> _heuristicMove(int seat) {
    final avail = availableWheelSlots();
    final spots = validPlacements(seat);
    if (avail.isEmpty || spots.isEmpty) {
      if (canRefill) return {'type': 'refill'};
    }

    if (botLevel == 0) {
      final slot = avail.first;
      final spot = spots.contains((3, 3)) ? (3, 3) : spots.first;
      return {
        'type': 'pick',
        'wheelSlot': slot,
        'r': spot.$1,
        'c': spot.$2,
      };
    }

    var bestVal = -999999;
    Map<String, dynamic>? bestMove;

    for (final slot in avail) {
      final tile = wheel[slot]!;
      for (final (r, c) in spots) {
        // Temporarily simulate placement
        final savedDisks = disksLeft[seat];
        final savedDone = <((int, int), List<bool>)>[];
        for (var rr = 0; rr < gridSize; rr++) {
          for (var cc = 0; cc < gridSize; cc++) {
            final p = tableau[seat][rr][cc];
            if (p != null) {
              savedDone.add(((rr, cc), List<bool>.of(p.doneTasks)));
            }
          }
        }
        tableau[seat][r][c] = PlacedNovaTile(tile);
        final newlyDone = recalcTasks(seat);

        // Also reward same-color adjacency and low time cost
        var sameColAdj = 0;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
            final nb = tableau[seat][nr][nc];
            if (nb != null && nb.tile.color == tile.color) sameColAdj++;
          }
        }
        final centerBias = 6 - (r - 3).abs() - (c - 3).abs();
        final val = newlyDone * 120 +
            sameColAdj * 18 -
            tile.cost * 8 +
            centerBias;

        // Restore state
        tableau[seat][r][c] = null;
        disksLeft[seat] = savedDisks;
        score[seat] = initialDisks - savedDisks;
        for (final ((rr, cc), dt) in savedDone) {
          final p = tableau[seat][rr][cc]!;
          for (var i = 0; i < dt.length; i++) {
            p.doneTasks[i] = dt[i];
          }
        }

        if (val > bestVal) {
          bestVal = val;
          bestMove = {
            'type': 'pick',
            'wheelSlot': slot,
            'r': r,
            'c': c,
          };
        }
      }
    }

    return bestMove ??
        {
          'type': 'pick',
          'wheelSlot': avail.first,
          'r': spots.first.$1,
          'c': spots.first.$2,
        };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    if (aiOn) {
      final r = _ai.poll(
        setup.ai!,
        'nl:$stepCount:$seat',
        () => AiRequest(
          system: '你在玩《新月任务 Nova Luna》。',
          prompt: '当前时间轨位置 ${timePos[seat]}，剩余圆盘 ${disksLeft[seat]}。',
        ),
      );
      if (r.pending) return null;
    }
    return _heuristicMove(seat);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'gridSize': gridSize,
      'initialDisks': initialDisks,
      'deckCount': deck.length,
      'moonPos': moonPos,
      'wheel': [for (final t in wheel) t?.toJson()],
      'availableSlots': availableWheelSlots(),
      'canRefill': canRefill,
      'timePos': timePos,
      'timeOrder': timeOrder,
      'disksLeft': disksLeft,
      'score': score,
      'turn': turn,
      'over': _over,
      'lastAction': lastAction,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'timePos': timePos[s],
            'disksLeft': disksLeft[s],
            'score': score[s],
            'validPlacements': [
              for (final (r, c) in validPlacements(s)) [r, c]
            ],
            'tableau': [
              for (var r = 0; r < gridSize; r++)
                [
                  for (var c = 0; c < gridSize; c++)
                    tableau[s][r][c]?.toJson(),
                ],
            ],
          },
      ],
    };
  }
}
