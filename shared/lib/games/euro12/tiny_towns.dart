import 'dart:math';

import '../../src/ai.dart';
import '../../src/engine.dart';

const List<String> ttResourceNames = ['木材', '小麦', '砖块', '玻璃', '石材'];
const List<String> ttResourceEmojis = ['🟫', '🟨', '🟥', '🟦', '⬜'];

class TinyBuildingDef {
  final int id; // 10..17
  final String name;
  final String emoji;
  final List<int> recipe; // Required resource multiset (0..4)
  final String desc;

  const TinyBuildingDef({
    required this.id,
    required this.name,
    required this.emoji,
    required this.recipe,
    required this.desc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'recipe': recipe,
        'desc': desc,
      };
}

const List<TinyBuildingDef> tinyBuildingDefs = [
  TinyBuildingDef(
    id: 10,
    name: '农舍',
    emoji: '🏠',
    recipe: [1, 3, 2], // Wheat, Glass, Brick
    desc: '若被🌾农场供给则得 3 分',
  ),
  TinyBuildingDef(
    id: 11,
    name: '农场',
    emoji: '🌾',
    recipe: [1, 1, 0, 0], // Wheat, Wheat, Wood, Wood
    desc: '可为城镇内最多 4 座🏠农舍提供粮食',
  ),
  TinyBuildingDef(
    id: 12,
    name: '教堂',
    emoji: '⛪',
    recipe: [4, 3, 2, 2], // Stone, Glass, Brick, Brick
    desc: '每座已获供给的🏠农舍提供 4 分',
  ),
  TinyBuildingDef(
    id: 13,
    name: '酒馆',
    emoji: '🍺',
    recipe: [2, 2, 3], // Brick, Brick, Glass
    desc: '按全镇🍺酒馆总数计 2/5/9/14/20 分',
  ),
  TinyBuildingDef(
    id: 14,
    name: '剧院',
    emoji: '🎭',
    recipe: [0, 4, 0, 3], // Wood, Stone, Wood, Glass
    desc: '同行同列每种不同建筑类型得 1 分',
  ),
  TinyBuildingDef(
    id: 15,
    name: '水井',
    emoji: '⛲',
    recipe: [0, 4], // Wood, Stone
    desc: '每座正交相邻的🏠农舍得 1 分',
  ),
  TinyBuildingDef(
    id: 16,
    name: '仓库',
    emoji: '🏛️',
    recipe: [4, 0, 2], // Stone, Wood, Brick
    desc: '得 2 分，且可作为任意万能资源参与合成',
  ),
  TinyBuildingDef(
    id: 17,
    name: '纪念碑',
    emoji: '🗽',
    recipe: [4, 3, 0, 1], // Stone, Glass, Wood, Wheat
    desc: '得 6 分，且免除城镇空位与剩余资源扣分',
  ),
];

final Map<int, TinyBuildingDef> tinyBuildingById = {
  for (final b in tinyBuildingDefs) b.id: b,
};

class TinyTownsGame extends GameEngine {
  TinyTownsGame(super.setup);

  static const int gridSize = 4;

  final _ai = AiSlot();

  late bool useMonument;

  /// `grid[seat][r][c]`:
  /// -1 = Empty
  /// 0..4 = Resource cube
  /// 10..17 = Constructed building
  late List<List<List<int>>> grid;

  late List<bool> finished;
  late List<bool> placedRes;
  late List<bool> stepDone;
  late List<int> score;

  int builderSeat = 0;
  int? calledRes;
  String phase = 'call'; // 'call' or 'place'
  int round = 1;
  bool _over = false;
  int? resignedSeat;
  String lastAction = '游戏开始，请总建筑师指定本轮资源！';

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
    return rankByScore(score);
  }

  List<TinyBuildingDef> get activeBuildingDefs => [
        for (final b in tinyBuildingDefs)
          if (b.id != 17 || useMonument) b,
      ];

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'call') {
      return [builderSeat];
    }
    return [
      for (var s = 0; s < players; s++)
        if (!finished[s] && !stepDone[s]) s,
    ];
  }

  @override
  void start() {
    useMonument = setup.opt<bool>('monument', false);
    grid = [
      for (var s = 0; s < players; s++)
        [
          for (var r = 0; r < gridSize; r++) List<int>.filled(gridSize, -1),
        ],
    ];
    finished = List<bool>.filled(players, false);
    placedRes = List<bool>.filled(players, false);
    stepDone = List<bool>.filled(players, false);
    score = List<int>.filled(players, 0);
    builderSeat = 0;
    calledRes = null;
    phase = 'call';
    round = 1;
    for (var s = 0; s < players; s++) {
      recalcScore(s);
    }
  }

  bool hasEmptyCell(int seat) {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (grid[seat][r][c] == -1) return true;
      }
    }
    return false;
  }

  /// Checks if [cells] is a single orthogonally-connected set of distinct coordinates on the 4x4 grid.
  bool isConnectedGroup(List<(int, int)> cells) {
    if (cells.isEmpty) return false;
    final set = cells.toSet();
    if (set.length != cells.length) return false;
    for (final (r, c) in set) {
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
    }
    final visited = <(int, int)>{cells.first};
    final q = <(int, int)>[cells.first];
    while (q.isNotEmpty) {
      final (cr, cc) = q.removeLast();
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final next = (cr + dr, cc + dc);
        if (set.contains(next) && visited.add(next)) {
          q.add(next);
        }
      }
    }
    return visited.length == set.length;
  }

  /// Checks if the cells on `grid[seat]` match the building's recipe multiset (16 = Trading Post acts as wild).
  bool canBuildRecipe(
      int seat, int buildingId, List<(int, int)> cells, (int, int) target) {
    final def = tinyBuildingById[buildingId];
    if (def == null) return false;
    if (buildingId == 17 && !useMonument) return false;
    if (cells.length != def.recipe.length) return false;
    if (!cells.contains(target)) return false;
    if (!isConnectedGroup(cells)) return false;

    // Monument (17) is unique per player
    if (buildingId == 17) {
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          if (grid[seat][r][c] == 17) return false;
        }
      }
    }

    final remainingReq = List<int>.of(def.recipe);
    var wilds = 0;
    for (final (r, c) in cells) {
      final v = grid[seat][r][c];
      if (v >= 0 && v <= 4) {
        final idx = remainingReq.indexOf(v);
        if (idx < 0) return false;
        remainingReq.removeAt(idx);
      } else if (v == 16) {
        wilds++;
      } else {
        return false;
      }
    }
    return remainingReq.length <= wilds;
  }

  /// Enumerates all valid building placements currently available on `grid[seat]`.
  List<Map<String, dynamic>> findValidBuilds(int seat) {
    final results = <Map<String, dynamic>>[];
    final resourceCells = <(int, int)>[];
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final v = grid[seat][r][c];
        if ((v >= 0 && v <= 4) || v == 16) {
          resourceCells.add((r, c));
        }
      }
    }
    if (resourceCells.length < 2) return results;

    for (final def in activeBuildingDefs) {
      final k = def.recipe.length;
      if (resourceCells.length < k) continue;
      // Find connected combinations of size k
      void search(int startIdx, List<(int, int)> chosen) {
        if (chosen.length == k) {
          final target = chosen.first;
          if (canBuildRecipe(seat, def.id, chosen, target)) {
            results.add({
              'type': 'build',
              'building': def.id,
              'cells': [
                for (final (r, c) in chosen) [r, c]
              ],
              'at': [target.$1, target.$2],
            });
          }
          return;
        }
        for (var i = startIdx; i < resourceCells.length; i++) {
          chosen.add(resourceCells[i]);
          search(i + 1, chosen);
          chosen.removeLast();
        }
      }

      search(0, <(int, int)>[]);
    }
    return results;
  }

  /// Calculates and updates [seat]'s current Town score.
  int recalcScore(int seat) {
    var cottages = 0;
    var farms = 0;
    var abbeys = 0;
    var taverns = 0;
    var tradingPosts = 0;
    var monuments = 0;
    var penalties = 0;

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final v = grid[seat][r][c];
        if (v < 10) {
          penalties++;
        } else if (v == 10) {
          cottages++;
        } else if (v == 11) {
          farms++;
        } else if (v == 12) {
          abbeys++;
        } else if (v == 13) {
          taverns++;
        } else if (v == 16) {
          tradingPosts++;
        } else if (v == 17) {
          monuments++;
        }
      }
    }

    final fedCottages = min(cottages, farms * 4);
    var total = 0;
    // 10: Cottage (3 VP per fed Cottage)
    total += fedCottages * 3;
    // 12: Abbey (4 VP per fed Cottage)
    total += abbeys * (fedCottages * 4);
    // 13: Tavern (2 / 5 / 9 / 14 / 20 VP)
    const tavernTable = [0, 2, 5, 9, 14, 20];
    total += tavernTable[min(taverns, 5)];
    // 16: Trading Post (2 VP each)
    total += tradingPosts * 2;
    // 17: Monument (6 VP each)
    total += monuments * 6;

    // 14: Theater & 15: Well (positional scoring)
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final v = grid[seat][r][c];
        if (v == 14) {
          // 1 VP per distinct building type in same Row & Col (excluding Theater 14)
          final distinctTypes = <int>{};
          for (var i = 0; i < gridSize; i++) {
            final rv = grid[seat][r][i];
            if (rv >= 10 && rv != 14) distinctTypes.add(rv);
            final cv = grid[seat][i][c];
            if (cv >= 10 && cv != 14) distinctTypes.add(cv);
          }
          total += distinctTypes.length;
        } else if (v == 15) {
          // 1 VP per orthogonally adjacent Cottage (10)
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr;
            final nc = c + dc;
            if (nr >= 0 &&
                nr < gridSize &&
                nc >= 0 &&
                nc < gridSize &&
                grid[seat][nr][nc] == 10) {
              total += 1;
            }
          }
        }
      }
    }

    // Empty / unbuilt resource penalty (-1 VP each unless Monument built)
    if (monuments == 0) {
      total -= penalties;
    }

    score[seat] = total;
    return total;
  }

  void _checkStepCompletion(int seat) {
    recalcScore(seat);
    if (placedRes[seat]) {
      final builds = findValidBuilds(seat);
      if (builds.isEmpty) {
        stepDone[seat] = true;
        if (!hasEmptyCell(seat)) {
          finished[seat] = true;
        }
      }
    }
    _checkPhaseAdvance();
  }

  void _checkPhaseAdvance() {
    if (phase != 'place') return;
    final anyWaiting = [
      for (var s = 0; s < players; s++)
        if (!finished[s] && !stepDone[s]) s,
    ];
    if (anyWaiting.isNotEmpty) return;

    // Check if any active player now has 0 empty cells and no valid builds
    for (var s = 0; s < players; s++) {
      if (!finished[s] && !hasEmptyCell(s) && findValidBuilds(s).isEmpty) {
        finished[s] = true;
      }
    }

    if (finished.every((f) => f)) {
      _endGame();
      return;
    }

    // Advance builderSeat to next non-finished player
    for (var i = 1; i <= players; i++) {
      final cand = (builderSeat + i) % players;
      if (!finished[cand]) {
        builderSeat = cand;
        break;
      }
    }
    calledRes = null;
    phase = 'call';
    round++;
  }

  void _endGame() {
    _over = true;
    for (var s = 0; s < players; s++) {
      recalcScore(s);
    }
    host.log('小小城镇建设完毕！最终得分：${[
      for (var s = 0; s < players; s++) '${name(s)} ${score[s]}分'
    ].join('，')}');
  }

  List<(int, int)> _parseCoords(Object? raw) {
    if (raw is! List) return const [];
    final out = <(int, int)>[];
    for (final e in raw) {
      if (e is List && e.length >= 2) {
        out.add((asInt(e[0], -1), asInt(e[1], -1)));
      } else if (e is Map) {
        out.add((asInt(e['r'], -1), asInt(e['c'], -1)));
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (finished[seat]) throw GameError('你的城镇已竣工');

    final type = asStr(action['type']);

    // Allow building at any time if valid recipe exists on player's grid
    if (type == 'build') {
      final bId = asInt(action['building'], -1);
      final cells = _parseCoords(action['cells']);
      if (cells.isEmpty) throw GameError('请选择合成所需的资源格');
      final rawAt = action['at'];
      final (int, int) target = (rawAt is List && rawAt.length >= 2)
          ? (asInt(rawAt[0], -1), asInt(rawAt[1], -1))
          : cells.first;

      if (!canBuildRecipe(seat, bId, cells, target)) {
        throw GameError('所选资源不满足该建筑配方或未正交连通');
      }

      for (final (r, c) in cells) {
        grid[seat][r][c] = -1;
      }
      grid[seat][target.$1][target.$2] = bId;
      final def = tinyBuildingById[bId]!;
      recalcScore(seat);
      lastAction =
          '${name(seat)} 在 (${target.$1},${target.$2}) 建造了 ${def.emoji}${def.name}！';
      host.log(lastAction);

      if (phase == 'place' && placedRes[seat]) {
        _checkStepCompletion(seat);
      }
      return;
    }

    if (type == 'call_resource') {
      // If all active players already placed their resource, allow next builder to call immediately
      if (phase == 'place' &&
          [for (var s = 0; s < players; s++) if (!finished[s]) s]
              .every((s) => placedRes[s])) {
        for (var s = 0; s < players; s++) {
          stepDone[s] = true;
        }
        _checkPhaseAdvance();
      }
      if (phase != 'call' || seat != builderSeat) {
        throw GameError('当前不是你指定资源的阶段');
      }
      final res = asInt(action['res'], -1);
      if (res < 0 || res > 4) throw GameError('资源类型无效');

      calledRes = res;
      phase = 'place';
      for (var s = 0; s < players; s++) {
        if (!finished[s] && !hasEmptyCell(s) && findValidBuilds(s).isEmpty) {
          finished[s] = true;
        }
        placedRes[s] = finished[s];
        stepDone[s] = finished[s];
      }
      lastAction =
          '总建筑师 ${name(seat)} 宣布本轮资源：${ttResourceEmojis[res]}${ttResourceNames[res]}';
      host.log(lastAction);
      _checkPhaseAdvance();
      return;
    }

    if (type == 'place_res') {
      if (phase != 'place') throw GameError('请先等待总建筑师宣布资源');
      if (placedRes[seat]) throw GameError('本轮你已放置过资源');
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) {
        throw GameError('坐标超出范围');
      }
      if (grid[seat][r][c] != -1) {
        throw GameError('必须将资源放置在空地上');
      }

      grid[seat][r][c] = calledRes!;
      placedRes[seat] = true;
      lastAction =
          '${name(seat)} 将 ${ttResourceEmojis[calledRes!]}${ttResourceNames[calledRes!]} 放在 ($r,$c)';
      host.log(lastAction);
      _checkStepCompletion(seat);
      return;
    }

    if (type == 'end_step' || type == 'pass' || type == 'finish_town') {
      if (type == 'finish_town' || !hasEmptyCell(seat)) {
        finished[seat] = true;
        placedRes[seat] = true;
        stepDone[seat] = true;
        recalcScore(seat);
        lastAction = '${name(seat)} 宣布城镇竣工！';
        host.log(lastAction);
        _checkPhaseAdvance();
        return;
      }
      if (phase == 'place' && placedRes[seat]) {
        stepDone[seat] = true;
        _checkPhaseAdvance();
        return;
      }
      throw GameError('请先放置本轮的资源方块');
    }

    throw GameError('未知操作: $type');
  }

  Map<String, dynamic> _heuristicMove(int seat) {
    // 1. If we can build right now, should we?
    final builds = findValidBuilds(seat);
    if (builds.isNotEmpty) {
      if (botLevel == 0) return builds.first;
      // Prefer high-scoring buildings: Monument(17) > Cottage(10)/Farm(11)/Abbey(12)/Tavern(13) > Well(15)
      builds.sort((a, b) {
        int priority(int id) {
          if (id == 17) return 100;
          if (id == 11) {
            final hasFarm = grid[seat].any((row) => row.contains(11));
            return hasFarm ? 20 : 90;
          }
          if (id == 10) return 85;
          if (id == 12) return 80;
          if (id == 13) return 78;
          if (id == 14) return 75;
          if (id == 16) return 70;
          return 60;
        }

        return priority(asInt(b['building']))
            .compareTo(priority(asInt(a['building'])));
      });
      return builds.first;
    }

    // 2. If in 'call' phase, choose a resource needed for a recipe
    if (phase == 'call' && seat == builderSeat) {
      final counts = List<int>.filled(5, 0);
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          final v = grid[seat][r][c];
          if (v >= 0 && v <= 4) counts[v]++;
        }
      }
      // Pick resource we have the least of to complete diverse recipes
      var bestRes = 0;
      for (var res = 1; res < 5; res++) {
        if (counts[res] < counts[bestRes]) bestRes = res;
      }
      return {'type': 'call_resource', 'res': bestRes};
    }

    // 3. If in 'place' phase and haven't placed resource yet
    if (phase == 'place' && !placedRes[seat]) {
      final empties = <(int, int)>[];
      for (var r = 0; r < gridSize; r++) {
        for (var c = 0; c < gridSize; c++) {
          if (grid[seat][r][c] == -1) empties.add((r, c));
        }
      }
      if (empties.isEmpty) {
        return {'type': 'finish_town'};
      }
      if (botLevel == 0) {
        return {'type': 'place_res', 'r': empties.first.$1, 'c': empties.first.$2};
      }
      // Prefer placing adjacent to existing resources to form connected recipes!
      var bestSpot = empties.first;
      var bestScore = -999;
      for (final (r, c) in empties) {
        grid[seat][r][c] = calledRes!;
        final validAfter = findValidBuilds(seat).length;
        var adjRes = 0;
        for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < gridSize && nc >= 0 && nc < gridSize) {
            final nv = grid[seat][nr][nc];
            if (nv >= 0 && nv <= 4) adjRes++;
          }
        }
        grid[seat][r][c] = -1;
        final val = validAfter * 50 + adjRes * 10;
        if (val > bestScore) {
          bestScore = val;
          bestSpot = (r, c);
        }
      }
      return {'type': 'place_res', 'r': bestSpot.$1, 'c': bestSpot.$2};
    }

    return {'type': 'end_step'};
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;
    if (aiOn) {
      final r = _ai.poll(
        setup.ai!,
        'tt:$round:$phase:$seat:${placedRes[seat]}',
        () => AiRequest(
          system: '你在玩《小小城镇 Tiny Towns》。',
          prompt: '当前阶段 $phase，你的分数 ${score[seat]}。',
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
      'useMonument': useMonument,
      'buildings': [for (final b in activeBuildingDefs) b.toJson()],
      'builderSeat': builderSeat,
      'calledRes': calledRes,
      'phase': phase,
      'round': round,
      'over': _over,
      'lastAction': lastAction,
      'score': score,
      'finished': finished,
      'placedRes': placedRes,
      'stepDone': stepDone,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': score[s],
            'finished': finished[s],
            'placedRes': placedRes[s],
            'stepDone': stepDone[s],
            'grid': grid[s],
            'validBuilds': findValidBuilds(s),
          },
      ],
    };
  }
}
