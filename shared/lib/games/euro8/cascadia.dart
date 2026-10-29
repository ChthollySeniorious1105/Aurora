import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

const List<String> cascadiaTerrainNames = ['山脉', '森林', '草原', '湿地', '河流'];
const List<String> cascadiaAnimalNames = ['棕熊', '麋鹿', '大马哈鱼', '红尾鵟', '赤狐'];

/// Axial hex neighbors: (dr, dc)
const List<(int, int)> cascadiaHexDirs = [
  (0, 1),
  (1, 0),
  (1, -1),
  (0, -1),
  (-1, 0),
  (-1, 1),
];

class CascadiaTile {
  final int id;
  final List<int> terrains;
  final List<int> allowedAnimals;

  const CascadiaTile({
    required this.id,
    required this.terrains,
    required this.allowedAnimals,
  });

  bool get isKeystone => terrains.length == 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'terrains': terrains,
        'allowedAnimals': allowedAnimals,
        'isKeystone': isKeystone,
      };
}

class CascadiaHex {
  final int r;
  final int c;
  final List<int> terrains;
  final List<int> allowedAnimals;
  final bool isKeystone;
  int? animal;

  CascadiaHex({
    required this.r,
    required this.c,
    required this.terrains,
    required this.allowedAnimals,
    required this.isKeystone,
    this.animal,
  });

  bool get hasAnimal => animal != null;

  bool canAcceptAnimal(int a) => !hasAnimal && allowedAnimals.contains(a);

  Map<String, dynamic> toJson() => {
        'r': r,
        'c': c,
        'terrains': terrains,
        'allowedAnimals': allowedAnimals,
        'isKeystone': isKeystone,
        'animal': animal,
        'hasAnimal': hasAnimal,
      };
}

class CascadiaMarketPair {
  CascadiaTile tile;
  int animal;

  CascadiaMarketPair({required this.tile, required this.animal});

  Map<String, dynamic> toJson() => {
        'tile': tile.toJson(),
        'animal': animal,
        'animalName': cascadiaAnimalNames[animal],
      };
}

const String cascadiaRules = '''
# 卡斯卡迪亚之旅（Cascadia）规则说明

- **游戏概述**：2022年德国年度桌游大奖（Spiel des Jahres）得主！1至4名玩家在太平洋西北部的卡斯卡迪亚地区拼放栖息地六边形板块并安置野生动物标记，构筑最和谐的自然生态圈。
- **五种地形与五种野生动物**：
  - 栖息地地形：`0: 山脉`、`1: 森林`、`2: 草原`、`3: 湿地`、`4: 河流`。
  - 野生动物物种：`0: 棕熊 (Bear)`、`1: 麋鹿 (Elk)`、`2: 大马哈鱼 (Salmon)`、`3: 红尾鵟 (Hawk)`、`4: 赤狐 (Fox)`。
- **开局设置**：
  - 每位玩家拥有由 3 个相连六边形组成的起始栖息地（`grids[seat]`）以及 `2` 枚自然标记（松果，`natureTokens[seat]`）。
  - 中央市场始终展示 4 组「栖息地板块 + 野生动物标记」组合（`market[0..3]`）。
- **回合流程**：
  - 标准模式共进行 `20` 轮（快速模式 `12` 轮）。
  - 在你的回合，从中央市场选择 1 组同列搭配（`pairIdx: 0..3`）；或者花费 `1` 枚自然标记，自由任选 1 块栖息地板块（`tileIdx: 0..3`）搭配任意 1 枚动物标记（`animalIdx: 0..3`）。
  - 你也可以花费 `1` 枚自然标记刷新市场上全部 4 枚动物标记；若市场上有恰好 3 枚相同动物，每回合可免费刷新一次。
  - **放置板块与动物**：将选中的栖息地板块放置在自己版图中与已有板块相邻的空位（`r, c`）；随后可将选中的野生动物放置在自己版图中任意没有动物且允许该物种栖息的板块上（若放置在单一地形的「关键栖息地 Keystone」板块上，立即获得 `+1` 枚自然标记！）。若无可放置位置也可弃置该动物标记。
- **终局计分**：
  - **棕熊（Bear）**：统计恰好由 2 只相邻棕熊组成且不接触其他棕熊的棕熊对数，1/2/3/4 对分别得 `4 / 11 / 19 / 27` 分。
  - **麋鹿（Elk）**：每个相连麋鹿群按规模 1/2/3/4 只分别得 `2 / 5 / 9 / 13` 分。
  - **大马哈鱼（Salmon）**：每条回游鱼群（鱼群中每条鱼最多接触 2 条其他大马哈鱼）按长度 1..6+ 分别得 `2 / 5 / 8 / 12 / 16 / 20` 分。
  - **红尾鵟（Hawk）**：统计不与任何其他红尾鵟相邻的独立红尾鵟数量，1/2/3/4/5/6/7/8+ 只分别得 `2 / 5 / 8 / 11 / 14 / 18 / 22 / 26` 分。
  - **赤狐（Fox）**：每只赤狐周围相邻的每种不同野生动物物种各得 `1` 分（每只赤狐最高 5 分）。
  - **地形走廊与多数奖励**：每种地形计算你版图中最大相连区域格数（每格 `1` 分），并根据各玩家在该地形的最大走廊规模颁发多数奖励（第一名 `+2` 分，多人局第二名 `+1` 分；单人模式达到 7 格得 `+2` 分）。
  - **自然标记**：每枚剩余的自然标记价值 `+1` 分。总分最高者获胜！
''';

class Cascadia extends GameEngine {
  Cascadia(super.setup);

  late int maxRounds;
  int round = 1;
  int turn = 0;
  bool over = false;

  late List<Map<(int, int), CascadiaHex>> grids;
  late List<int> natureTokens;
  final List<CascadiaTile> tileDeck = [];
  final List<int> animalBag = [];
  final List<CascadiaMarketPair> market = [];
  bool culledThisTurn = false;
  String lastAction = '';
  Map<String, dynamic>? result;

  @override
  bool get isOver => over;

  @override
  bool get canResign => players > 1 && !over;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [
      for (var s = 0; s < players; s++) s == seat ? -1 : (breakdown[s]['total'] as int),
    ];
    final ranks = rankByScore(scores);
    result = {
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'placings': ranks,
      'resigned': seat,
    };
    _placings = ranks;
  }

  List<int>? _placings;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 20);
    round = 1;
    turn = 0;
    over = false;
    culledThisTurn = false;
    natureTokens = List<int>.filled(players, 2);
    grids = List.generate(players, (_) => <(int, int), CascadiaHex>{});

    _initDeckAndBag();
    _dealStarterHabitats();
    _refillMarket();
    lastAction = '卡斯卡迪亚之旅开始！共 $maxRounds 轮';
    host.log(lastAction);
  }

  void _initDeckAndBag() {
    tileDeck.clear();
    var id = 1;
    // 25 Keystone tiles (5 of each terrain, paired with each wildlife species)
    for (var t = 0; t < 5; t++) {
      for (var i = 0; i < 5; i++) {
        final a = (t + i) % 5;
        tileDeck.add(CascadiaTile(id: id++, terrains: [t], allowedAnimals: [a]));
      }
    }
    // 60 Dual-terrain tiles (6 copies of each of the 10 terrain pairs)
    for (var t1 = 0; t1 < 5; t1++) {
      for (var t2 = t1 + 1; t2 < 5; t2++) {
        for (var copy = 0; copy < 6; copy++) {
          final a1 = (t1 + copy) % 5;
          final a2 = (t2 + copy + 1) % 5;
          final animals = <int>{a1, a2};
          if (animals.length < 2) animals.add((a1 + 2) % 5);
          if (copy >= 3) {
            final a3 = (t1 + t2 + copy) % 5;
            animals.add(a3);
          }
          tileDeck.add(CascadiaTile(
            id: id++,
            terrains: [t1, t2],
            allowedAnimals: animals.toList()..sort(),
          ));
        }
      }
    }
    tileDeck.shuffle(rng);

    animalBag.clear();
    for (var a = 0; a < 5; a++) {
      for (var i = 0; i < 20; i++) {
        animalBag.add(a);
      }
    }
    animalBag.shuffle(rng);
  }

  int _drawAnimal() {
    if (animalBag.isEmpty) {
      for (var a = 0; a < 5; a++) {
        for (var i = 0; i < 10; i++) {
          animalBag.add(a);
        }
      }
      animalBag.shuffle(rng);
    }
    return animalBag.removeLast();
  }

  CascadiaTile _drawTile() {
    if (tileDeck.isEmpty) {
      final t1 = rng.nextInt(5);
      final t2 = (t1 + 1 + rng.nextInt(4)) % 5;
      return CascadiaTile(
        id: 900 + rng.nextInt(100),
        terrains: [t1, t2],
        allowedAnimals: [t1, t2],
      );
    }
    return tileDeck.removeLast();
  }

  void _dealStarterHabitats() {
    // 5 canonical starter habitats; each has 1 Keystone at (0,0) and 2 dual-terrain hexes at (1,-1) and (1,0)
    final starterOrder = shuffled([0, 1, 2, 3, 4], rng);
    for (var s = 0; s < players; s++) {
      final base = starterOrder[s % 5];
      final t0 = base;
      final t1 = (base + 1) % 5;
      final t2 = (base + 2) % 5;
      final t3 = (base + 3) % 5;
      final t4 = (base + 4) % 5;
      grids[s][(0, 0)] = CascadiaHex(
        r: 0,
        c: 0,
        terrains: [t0],
        allowedAnimals: [t0],
        isKeystone: true,
      );
      grids[s][(1, -1)] = CascadiaHex(
        r: 1,
        c: -1,
        terrains: [t1, t2],
        allowedAnimals: [t1, t2, t3],
        isKeystone: false,
      );
      grids[s][(1, 0)] = CascadiaHex(
        r: 1,
        c: 0,
        terrains: [t3, t4],
        allowedAnimals: [t3, t4],
        isKeystone: false,
      );
    }
  }

  void _refillMarket() {
    while (market.length < 4) {
      market.add(CascadiaMarketPair(tile: _drawTile(), animal: _drawAnimal()));
    }
    _checkAutoFourOfAKind();
  }

  void _checkAutoFourOfAKind() {
    // Auto-clear if all 4 wildlife tokens are identical (up to 3 times to prevent infinite loops)
    for (var attempt = 0; attempt < 3; attempt++) {
      if (market.length == 4 &&
          market[0].animal == market[1].animal &&
          market[1].animal == market[2].animal &&
          market[2].animal == market[3].animal) {
        final old = market[0].animal;
        for (var i = 0; i < 4; i++) {
          animalBag.insert(0, old);
        }
        animalBag.shuffle(rng);
        for (var i = 0; i < 4; i++) {
          market[i].animal = _drawAnimal();
        }
      } else {
        break;
      }
    }
  }

  /// Returns which wildlife species has exactly 3 tokens in the market, or -1 if none.
  int threeOfAKindSpecies() {
    final counts = List<int>.filled(5, 0);
    for (final p in market) {
      counts[p.animal]++;
    }
    for (var a = 0; a < 5; a++) {
      if (counts[a] == 3) return a;
    }
    return -1;
  }

  /// All empty hexes `(r, c)` adjacent to at least one existing hex in `grids[seat]`.
  List<(int, int)> validPlacementHexes(int seat) {
    final grid = grids[seat];
    final out = <(int, int)>{};
    for (final pos in grid.keys) {
      for (final d in cascadiaHexDirs) {
        final nr = pos.$1 + d.$1;
        final nc = pos.$2 + d.$2;
        if (!grid.containsKey((nr, nc))) {
          out.add((nr, nc));
        }
      }
    }
    final list = out.toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return list;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type == 'wipe_animals') {
      if (natureTokens[seat] <= 0) throw GameError('自然标记不足，无法刷新动物标记');
      natureTokens[seat]--;
      for (var i = 0; i < market.length; i++) {
        animalBag.insert(0, market[i].animal);
      }
      animalBag.shuffle(rng);
      for (var i = 0; i < market.length; i++) {
        market[i].animal = _drawAnimal();
      }
      _checkAutoFourOfAKind();
      lastAction = '${name(seat)} 花费 1 枚自然标记刷新了市场上的所有动物标记';
      host.log(lastAction);
      return;
    }

    if (type == 'cull_free') {
      final species = threeOfAKindSpecies();
      if (species < 0 || culledThisTurn) {
        throw GameError('当前无法免费刷新 3 枚相同动物');
      }
      culledThisTurn = true;
      for (var i = 0; i < market.length; i++) {
        if (market[i].animal == species) {
          animalBag.insert(0, species);
        }
      }
      animalBag.shuffle(rng);
      for (var i = 0; i < market.length; i++) {
        if (market[i].animal == species) {
          market[i].animal = _drawAnimal();
        }
      }
      _checkAutoFourOfAKind();
      lastAction = '${name(seat)} 免费刷新了 3 枚相同的${cascadiaAnimalNames[species]}标记';
      host.log(lastAction);
      return;
    }

    if (type == 'turn' || type == 'play') {
      final pairIdx = asInt(action['pairIdx'], -1);
      final tileIdx = asInt(action['tileIdx'], pairIdx);
      final animalIdx = asInt(action['animalIdx'], tileIdx);
      if (tileIdx < 0 || tileIdx >= market.length || animalIdx < 0 || animalIdx >= market.length) {
        throw GameError('无效的市场槽位选择');
      }
      final splitPick = tileIdx != animalIdx || asBool(action['useToken']);
      if (splitPick && natureTokens[seat] <= 0) {
        throw GameError('自然标记不足，无法自由跨列搭配板块与动物');
      }

      if (action['r'] == null || action['c'] == null) {
        throw GameError('请指定栖息地板块的放置坐标');
      }
      final r = asInt(action['r'], 999999);
      final c = asInt(action['c'], 999999);
      final grid = grids[seat];
      if (grid.containsKey((r, c))) {
        throw GameError('该位置已有栖息地板块');
      }
      final isAdjacent = cascadiaHexDirs.any((d) => grid.containsKey((r + d.$1, c + d.$2)));
      if (!isAdjacent) {
        throw GameError('新栖息地板块必须与已有板块相邻');
      }

      final chosenTile = market[tileIdx].tile;
      final chosenAnimal = market[animalIdx].animal;

      // Validate animal placement before mutating state
      final hasAnimalCoord = action['animalR'] != null && action['animalC'] != null && !asBool(action['discardAnimal']);
      final ar = hasAnimalCoord ? asInt(action['animalR'], 999999) : null;
      final ac = hasAnimalCoord ? asInt(action['animalC'], 999999) : null;

      if (hasAnimalCoord) {
        if (ar == r && ac == c) {
          if (!chosenTile.allowedAnimals.contains(chosenAnimal)) {
            throw GameError('该栖息地板块不支持放置${cascadiaAnimalNames[chosenAnimal]}');
          }
        } else {
          final targetHex = grid[(ar!, ac!)];
          if (targetHex == null) {
            throw GameError('指定的动物放置位置不存在栖息地板块');
          }
          if (!targetHex.canAcceptAnimal(chosenAnimal)) {
            throw GameError('该栖息地板块无法放置${cascadiaAnimalNames[chosenAnimal]}');
          }
        }
      }

      if (splitPick) {
        natureTokens[seat]--;
      }

      // Place the habitat tile
      final placedHex = CascadiaHex(
        r: r,
        c: c,
        terrains: chosenTile.terrains,
        allowedAnimals: chosenTile.allowedAnimals,
        isKeystone: chosenTile.isKeystone,
      );
      grid[(r, c)] = placedHex;

      // Place the wildlife token if coordinates provided
      var gainedToken = false;
      if (hasAnimalCoord) {
        final targetHex = grid[(ar!, ac!)]!;
        targetHex.animal = chosenAnimal;
        if (targetHex.isKeystone) {
          natureTokens[seat]++;
          gainedToken = true;
        }
      } else {
        animalBag.insert(0, chosenAnimal);
      }

      // Update market: replace drafted tile & animal
      if (tileIdx == animalIdx) {
        market.removeAt(tileIdx);
      } else {
        market[tileIdx].tile = _drawTile();
        market[animalIdx].animal = _drawAnimal();
      }
      // In solo mode, discard the rightmost remaining pair before refilling
      if (players == 1 && market.isNotEmpty) {
        market.removeLast();
      }
      _refillMarket();

      final terrainLabel = chosenTile.terrains.map((t) => cascadiaTerrainNames[t]).join('/');
      final animalMsg = hasAnimalCoord
          ? '并安置了${cascadiaAnimalNames[chosenAnimal]}${gainedToken ? "（获得+1自然标记）" : ""}'
          : '并弃置了${cascadiaAnimalNames[chosenAnimal]}';
      lastAction = '${name(seat)} 放置了【$terrainLabel】板块于($r,$c)，$animalMsg';
      host.log(lastAction);

      _advanceTurn();
      return;
    }

    throw GameError('未知操作类型: $type');
  }

  void _advanceTurn() {
    culledThisTurn = false;
    turn = (turn + 1) % players;
    if (turn == 0) {
      if (round >= maxRounds) {
        _finishGame();
        return;
      }
      round++;
    }
  }

  void _finishGame() {
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [for (var s = 0; s < players; s++) breakdown[s]['total'] as int];
    // Break ties with remaining natureTokens (multiply by 100 for ranking)
    final tieBreakScores = [
      for (var s = 0; s < players; s++) scores[s] * 100 + natureTokens[s],
    ];
    _placings = rankByScore(tieBreakScores);
    result = {
      'scores': scores,
      'breakdown': breakdown,
      'placings': _placings,
    };
    host.log('游戏结束！最终得分：${[for (var s = 0; s < players; s++) "${name(s)} ${scores[s]}分"].join("，")}');
  }

  // ==================== Scoring Functions ====================

  /// Bear (0): pairs of size == 2 not touching other bears -> 4 / 11 / 19 / 27 pts
  static int scoreBears(Map<(int, int), CascadiaHex> grid) {
    final visited = <(int, int)>{};
    var pairs = 0;
    for (final entry in grid.entries) {
      if (entry.value.animal != 0 || visited.contains(entry.key)) continue;
      final comp = _animalComponent(grid, entry.key, 0, visited);
      if (comp.length == 2) {
        pairs++;
      }
    }
    const table = [0, 4, 11, 19, 27];
    return table[min(pairs, 4)];
  }

  /// Elk (1): contiguous groups -> 2 / 5 / 9 / 13 pts
  static int scoreElk(Map<(int, int), CascadiaHex> grid) {
    final visited = <(int, int)>{};
    var pts = 0;
    const table = [0, 2, 5, 9, 13];
    for (final entry in grid.entries) {
      if (entry.value.animal != 1 || visited.contains(entry.key)) continue;
      final comp = _animalComponent(grid, entry.key, 1, visited);
      var sz = comp.length;
      while (sz >= 4) {
        pts += 13;
        sz -= 4;
      }
      pts += table[sz];
    }
    return pts;
  }

  /// Salmon (2): runs of salmon where each salmon in the component touches <= 2 salmon -> 2/5/8/12/16/20 pts
  static int scoreSalmon(Map<(int, int), CascadiaHex> grid) {
    final visited = <(int, int)>{};
    var pts = 0;
    const table = [0, 2, 5, 8, 12, 16, 20];
    for (final entry in grid.entries) {
      if (entry.value.animal != 2 || visited.contains(entry.key)) continue;
      final comp = _animalComponent(grid, entry.key, 2, visited);
      // Verify every salmon in the run touches at most 2 other salmon
      var validRun = true;
      for (final pos in comp) {
        var adjSalmon = 0;
        for (final d in cascadiaHexDirs) {
          final nHex = grid[(pos.$1 + d.$1, pos.$2 + d.$2)];
          if (nHex != null && nHex.animal == 2) adjSalmon++;
        }
        if (adjSalmon > 2) {
          validRun = false;
          break;
        }
      }
      if (validRun) {
        pts += table[min(comp.length, 6)];
      }
    }
    return pts;
  }

  /// Hawk (3): isolated hawks not adjacent to another hawk -> 2/5/8/11/14/18/22/26 pts
  static int scoreHawks(Map<(int, int), CascadiaHex> grid) {
    var isolated = 0;
    for (final entry in grid.entries) {
      if (entry.value.animal != 3) continue;
      final pos = entry.key;
      final touchesHawk = cascadiaHexDirs.any((d) {
        final nHex = grid[(pos.$1 + d.$1, pos.$2 + d.$2)];
        return nHex != null && nHex.animal == 3;
      });
      if (!touchesHawk) isolated++;
    }
    const table = [0, 2, 5, 8, 11, 14, 18, 22, 26];
    return table[min(isolated, 8)];
  }

  /// Fox (4): 1 pt per distinct adjacent wildlife species around each fox
  static int scoreFoxes(Map<(int, int), CascadiaHex> grid) {
    var pts = 0;
    for (final entry in grid.entries) {
      if (entry.value.animal != 4) continue;
      final pos = entry.key;
      final adjSpecies = <int>{};
      for (final d in cascadiaHexDirs) {
        final nHex = grid[(pos.$1 + d.$1, pos.$2 + d.$2)];
        if (nHex != null && nHex.animal != null) {
          adjSpecies.add(nHex.animal!);
        }
      }
      pts += adjSpecies.length;
    }
    return pts;
  }

  static List<(int, int)> _animalComponent(
    Map<(int, int), CascadiaHex> grid,
    (int, int) start,
    int species,
    Set<(int, int)> visited,
  ) {
    final comp = <(int, int)>[];
    final q = Queue<(int, int)>()..add(start);
    visited.add(start);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      comp.add(cur);
      for (final d in cascadiaHexDirs) {
        final nxt = (cur.$1 + d.$1, cur.$2 + d.$2);
        if (!visited.contains(nxt)) {
          final nHex = grid[nxt];
          if (nHex != null && nHex.animal == species) {
            visited.add(nxt);
            q.add(nxt);
          }
        }
      }
    }
    return comp;
  }

  /// Largest contiguous group of hexes containing [terrain] (`0..4`).
  static int largestCorridor(Map<(int, int), CascadiaHex> grid, int terrain) {
    final visited = <(int, int)>{};
    var best = 0;
    for (final entry in grid.entries) {
      if (!entry.value.terrains.contains(terrain) || visited.contains(entry.key)) continue;
      var count = 0;
      final q = Queue<(int, int)>()..add(entry.key);
      visited.add(entry.key);
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        count++;
        for (final d in cascadiaHexDirs) {
          final nxt = (cur.$1 + d.$1, cur.$2 + d.$2);
          if (!visited.contains(nxt)) {
            final nHex = grid[nxt];
            if (nHex != null && nHex.terrains.contains(terrain)) {
              visited.add(nxt);
              q.add(nxt);
            }
          }
        }
      }
      if (count > best) best = count;
    }
    return best;
  }

  /// Computes full score breakdown for all seats.
  List<Map<String, dynamic>> computeScoreBreakdown() {
    final corridors = [
      for (var s = 0; s < players; s++)
        [for (var t = 0; t < 5; t++) largestCorridor(grids[s], t)],
    ];
    final bonuses = List.generate(players, (_) => List<int>.filled(5, 0));

    for (var t = 0; t < 5; t++) {
      final vals = [for (var s = 0; s < players; s++) corridors[s][t]];
      if (players == 1) {
        if (vals[0] >= 7) bonuses[0][t] = 2;
      } else if (players == 2) {
        final maxV = vals.reduce(max);
        if (maxV > 0) {
          final winners = [for (var s = 0; s < players; s++) if (vals[s] == maxV) s];
          if (winners.length == 1) {
            bonuses[winners[0]][t] = 2;
          } else {
            for (final w in winners) {
              bonuses[w][t] = 1;
            }
          }
        }
      } else {
        final maxV = vals.reduce(max);
        if (maxV > 0) {
          final winners = [for (var s = 0; s < players; s++) if (vals[s] == maxV) s];
          if (winners.length == 1) {
            bonuses[winners[0]][t] = 2;
            var secondMax = 0;
            for (var s = 0; s < players; s++) {
              if (s != winners[0] && vals[s] > secondMax) secondMax = vals[s];
            }
            if (secondMax > 0) {
              final seconds = [for (var s = 0; s < players; s++) if (vals[s] == secondMax) s];
              if (seconds.length == 1) {
                bonuses[seconds[0]][t] = 1;
              }
            }
          } else if (winners.length == 2) {
            for (final w in winners) {
              bonuses[w][t] = 2;
            }
          } else {
            for (final w in winners) {
              bonuses[w][t] = 1;
            }
          }
        }
      }
    }

    final out = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final g = grids[s];
      final bear = scoreBears(g);
      final elk = scoreElk(g);
      final salmon = scoreSalmon(g);
      final hawk = scoreHawks(g);
      final fox = scoreFoxes(g);
      final wildlifeList = [bear, elk, salmon, hawk, fox];
      final wildlifeTotal = bear + elk + salmon + hawk + fox;
      final corridorTotal = corridors[s].fold<int>(0, (a, b) => a + b);
      final bonusTotal = bonuses[s].fold<int>(0, (a, b) => a + b);
      final tokenPts = natureTokens[s];
      final total = wildlifeTotal + corridorTotal + bonusTotal + tokenPts;

      out.add({
        'wildlife': wildlifeList,
        'wildlifeTotal': wildlifeTotal,
        'corridors': corridors[s],
        'corridorBonuses': bonuses[s],
        'corridorTotal': corridorTotal,
        'bonusTotal': bonusTotal,
        'natureTokens': tokenPts,
        'total': total,
      });
    }
    return out;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final breakdown = computeScoreBreakdown();
    final validHexes = [
      for (final pos in validPlacementHexes(turn)) {'r': pos.$1, 'c': pos.$2},
    ];
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'tilesLeft': tileDeck.length,
      'culledThisTurn': culledThisTurn,
      'threeOfAKind': threeOfAKindSpecies(),
      'market': [for (final p in market) p.toJson()],
      'natureTokens': natureTokens,
      'grids': [
        for (var s = 0; s < players; s++)
          [for (final h in grids[s].values) h.toJson()],
      ],
      'validHexes': validHexes,
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'lastAction': lastAction,
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final candidates = validPlacementHexes(seat);
    if (candidates.isEmpty || market.isEmpty) return null;

    // Simple bot (level 0): pick a random pair and place on a valid hex
    if (botLevel == 0) {
      final pIdx = rng.nextInt(market.length);
      final pos = candidates[rng.nextInt(candidates.length)];
      final pair = market[pIdx];
      (int, int)? animalPos;
      if (pair.tile.allowedAnimals.contains(pair.animal)) {
        animalPos = pos;
      } else {
        for (final e in grids[seat].entries) {
          if (e.value.canAcceptAnimal(pair.animal)) {
            animalPos = e.key;
            break;
          }
        }
      }
      return {
        'type': 'turn',
        'pairIdx': pIdx,
        'r': pos.$1,
        'c': pos.$2,
        if (animalPos != null) 'animalR': animalPos.$1,
        if (animalPos != null) 'animalC': animalPos.$2,
      };
    }

    // Normal/Hard bot: evaluate candidate (pairIdx, placement pos, animal placement pos)
    Map<String, dynamic>? bestAction;
    var bestVal = -999999;
    final g = grids[seat];

    for (var pIdx = 0; pIdx < market.length; pIdx++) {
      final pair = market[pIdx];
      final tile = pair.tile;
      final animal = pair.animal;

      // Find up to 8 promising hex positions
      final posSample = candidates.length <= 10 ? candidates : candidates.sublist(0, 10);
      for (final pos in posSample) {
        // Count how many adjacent hexes share a terrain with this tile
        var terrainMatch = 0;
        for (final d in cascadiaHexDirs) {
          final nh = g[(pos.$1 + d.$1, pos.$2 + d.$2)];
          if (nh != null && nh.terrains.any((t) => tile.terrains.contains(t))) {
            terrainMatch += 2;
          }
        }

        // Find possible hexes for placing `animal`
        final animalTargets = <(int, int)?>[null];
        if (tile.allowedAnimals.contains(animal)) {
          animalTargets.add(pos);
        }
        for (final e in g.entries) {
          if (e.value.canAcceptAnimal(animal)) {
            animalTargets.add(e.key);
            if (animalTargets.length >= 6) break;
          }
        }

        for (final aPos in animalTargets) {
          // Temporarily apply
          final tempHex = CascadiaHex(
            r: pos.$1,
            c: pos.$2,
            terrains: tile.terrains,
            allowedAnimals: tile.allowedAnimals,
            isKeystone: tile.isKeystone,
          );
          g[pos] = tempHex;
          CascadiaHex? modifiedHex;
          var tokenGain = 0;
          if (aPos != null) {
            modifiedHex = g[aPos]!;
            modifiedHex.animal = animal;
            if (modifiedHex.isKeystone) tokenGain = 2;
          }

          final score = scoreBears(g) +
              scoreElk(g) +
              scoreSalmon(g) +
              scoreHawks(g) +
              scoreFoxes(g) +
              terrainMatch +
              tokenGain +
              (aPos != null ? 3 : 0);

          // Revert
          if (modifiedHex != null) modifiedHex.animal = null;
          g.remove(pos);

          if (score > bestVal) {
            bestVal = score;
            bestAction = {
              'type': 'turn',
              'pairIdx': pIdx,
              'r': pos.$1,
              'c': pos.$2,
              if (aPos != null) 'animalR': aPos.$1,
              if (aPos != null) 'animalC': aPos.$2,
            };
          }
        }
      }
    }

    return bestAction ??
        {
          'type': 'turn',
          'pairIdx': 0,
          'r': candidates.first.$1,
          'c': candidates.first.$2,
        };
  }
}
