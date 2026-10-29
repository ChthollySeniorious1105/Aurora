import '../../src/ai.dart';
import '../../src/engine.dart';

/// A polyomino tile definition in Bärenpark.
class BarenTileDef {
  final String key;
  final String name;
  final int tier; // 1: Green (🚧), 2: Animal House (🚚), 3: Outdoor Enclosure (🏗️)
  final String bearType; // 'green', 'koala', 'panda', 'polar', 'gobi'
  final List<(int, int)> cells;
  final String emoji;

  const BarenTileDef({
    required this.key,
    required this.name,
    required this.tier,
    required this.bearType,
    required this.cells,
    required this.emoji,
  });
}

const List<BarenTileDef> barenTileDefs = [
  // Tier 1: Green Areas (🚧 推土机)
  BarenTileDef(
    key: 'g1',
    name: '花坛绿地',
    tier: 1,
    bearType: 'green',
    cells: [(0, 0)],
    emoji: '🌳',
  ),
  BarenTileDef(
    key: 'g2',
    name: '林荫步道',
    tier: 1,
    bearType: 'green',
    cells: [(0, 0), (0, 1)],
    emoji: '🌲',
  ),
  BarenTileDef(
    key: 'g3',
    name: '拐角餐车',
    tier: 1,
    bearType: 'green',
    cells: [(0, 0), (1, 0), (1, 1)],
    emoji: '🍔',
  ),
  BarenTileDef(
    key: 'g4',
    name: '景观溪流',
    tier: 1,
    bearType: 'green',
    cells: [(0, 0), (0, 1), (0, 2)],
    emoji: '🏞️',
  ),
  // Tier 2: Animal Houses (🚚 水泥车)
  BarenTileDef(
    key: 'h_koala',
    name: '考拉馆',
    tier: 2,
    bearType: 'koala',
    cells: [(0, 0), (0, 1), (0, 2), (1, 1)],
    emoji: '🐨',
  ),
  BarenTileDef(
    key: 'h_panda',
    name: '熊猫馆',
    tier: 2,
    bearType: 'panda',
    cells: [(0, 0), (0, 1), (1, 1), (1, 2)],
    emoji: '🐼',
  ),
  BarenTileDef(
    key: 'h_polar',
    name: '北极熊馆',
    tier: 2,
    bearType: 'polar',
    cells: [(0, 0), (1, 0), (2, 0), (2, 1)],
    emoji: '🐻‍❄️',
  ),
  BarenTileDef(
    key: 'h_gobi',
    name: '戈壁熊馆',
    tier: 2,
    bearType: 'gobi',
    cells: [(0, 0), (0, 1), (1, 0), (1, 1)],
    emoji: '🐻',
  ),
  // Tier 3: Outdoor Enclosures (🏗️ 挖掘机)
  BarenTileDef(
    key: 'e_koala',
    name: '考拉生态园',
    tier: 3,
    bearType: 'koala',
    cells: [(0, 1), (1, 0), (1, 1), (1, 2), (2, 1)],
    emoji: '🐨',
  ),
  BarenTileDef(
    key: 'e_panda',
    name: '熊猫竹林苑',
    tier: 3,
    bearType: 'panda',
    cells: [(0, 0), (0, 2), (1, 0), (1, 1), (1, 2)],
    emoji: '🐼',
  ),
  BarenTileDef(
    key: 'e_polar',
    name: '极地冰川苑',
    tier: 3,
    bearType: 'polar',
    cells: [(0, 0), (0, 1), (1, 0), (1, 1), (2, 0)],
    emoji: '🐻‍❄️',
  ),
  BarenTileDef(
    key: 'e_gobi',
    name: '戈壁荒原苑',
    tier: 3,
    bearType: 'gobi',
    cells: [(0, 0), (1, 0), (1, 1), (2, 1), (2, 2)],
    emoji: '🐻',
  ),
];

final Map<String, BarenTileDef> barenTileByKey = {
  for (final d in barenTileDefs) d.key: d,
};

/// A tile instance with a specific VP value.
class BarenTile {
  final int id;
  final String key;
  final int vp;

  const BarenTile({required this.id, required this.key, required this.vp});

  BarenTileDef get def => barenTileByKey[key]!;

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': def.name,
        'tier': def.tier,
        'bearType': def.bearType,
        'emoji': def.emoji,
        'vp': vp,
        'cells': [
          for (final (r, c) in def.cells) [r, c]
        ],
      };
}

/// Transform polyomino cells by rotation (0..3) and horizontal flip (false/true),
/// normalized so minimum row and column are 0.
List<(int, int)> transformCells(List<(int, int)> base, int rot, bool flip) {
  final r0 = rot & 3;
  final pts = <(int, int)>[];
  for (var (r, c) in base) {
    if (flip) c = -c;
    for (var i = 0; i < r0; i++) {
      final nr = c;
      final nc = -r;
      r = nr;
      c = nc;
    }
    pts.add((r, c));
  }
  var minR = pts.first.$1;
  var minC = pts.first.$2;
  for (final (r, c) in pts) {
    if (r < minR) minR = r;
    if (c < minC) minC = c;
  }
  final out = [for (final (r, c) in pts) (r - minR, c - minC)];
  out.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return out;
}

class PlacedBarenTile {
  final BarenTile tile;
  final int r;
  final int c;
  final int rot;
  final bool flip;
  final List<(int, int)> absCells;

  const PlacedBarenTile({
    required this.tile,
    required this.r,
    required this.c,
    required this.rot,
    required this.flip,
    required this.absCells,
  });

  Map<String, dynamic> toJson() => {
        'tile': tile.toJson(),
        'r': r,
        'c': c,
        'rot': rot,
        'flip': flip,
        'absCells': [
          for (final (ar, ac) in absCells) [ar, ac]
        ],
      };
}

/// Printed icon codes on the Park Grid:
/// 0 = empty grass
/// 1 = 🚧 Wheelbarrow (Tier 1 Green Area)
/// 2 = 🚚 Cement Truck (Tier 2 Animal House)
/// 3 = 🏗️ Excavator (Tier 3 Outdoor Enclosure)
/// 4 = 🗽 Bear Statue Pit (CAN NEVER BE COVERED!)
class BarenparkGame extends GameEngine {
  BarenparkGame(super.setup);

  final _ai = AiSlot();

  late int rows;
  late int cols;
  late int zoneCols;
  late bool useAchievements;

  /// Printed icon layout per seat: `icons[seat][r][c]` in 0..4.
  late List<List<List<int>>> icons;

  /// Placed tile ID per cell (`null` if uncovered): `grid[seat][r][c]`.
  late List<List<List<String?>>> grid;

  /// Placed tiles list per player.
  late List<List<PlacedBarenTile>> placedTiles;

  /// Personal tile reserve per player.
  late List<List<BarenTile>> inventory;

  /// Central supply stacks keyed by BarenTileDef.key.
  late Map<String, List<BarenTile>> supply;

  /// Remaining Bear Statue VPs (descending).
  late List<int> statues;

  /// Statues earned per player per sub-zone (0..3 -> VP or null).
  late List<List<int?>> zoneStatues;

  /// Achievement stacks (if enabled): key -> remaining VPs.
  late Map<String, List<int>> achievementStacks;
  late List<Map<String, int>> playerAchievements;

  late List<int> score;
  late List<int> consecutivePasses;

  int turn = 0;
  int round = 1;
  bool finalRoundTriggered = false;
  int? triggerSeat;
  bool _over = false;
  int? resignedSeat;
  int _nextTileId = 1;
  String lastAction = '游戏开始，请建设你的熊熊公园！';

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over;

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
    // Tie-breaker: total VP, then remaining tile VPs in inventory
    final adj = [
      for (var s = 0; s < players; s++)
        score[s] * 100 +
            inventory[s].fold<int>(0, (a, t) => a + t.vp) +
            placedTiles[s].length,
    ];
    return rankByScore(adj);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  int zoneOf(int r, int c) {
    final zr = r ~/ 3;
    final zc = c ~/ zoneCols;
    return zr * 2 + zc;
  }

  List<List<int>> _buildParkIcons() {
    if (cols == 8) {
      // 6x8 grid: 4 zones of 3x4, each with 1 Pit (4) and construction icons (1..3)
      return [
        // Zone 0 (top-left, starter) & Zone 1 (top-right)
        [0, 1, 0, 0, 0, 2, 0, 3],
        [2, 0, 4, 1, 1, 0, 4, 0],
        [0, 1, 0, 2, 0, 3, 0, 1],
        // Zone 2 (bottom-left) & Zone 3 (bottom-right)
        [0, 2, 0, 3, 3, 0, 2, 0],
        [1, 4, 0, 1, 0, 4, 0, 2],
        [3, 0, 2, 0, 1, 0, 3, 0],
      ];
    } else {
      // 6x6 grid: 4 zones of 3x3, each with 1 Pit (4) and construction icons (1..3)
      return [
        [0, 1, 0, 0, 2, 3],
        [2, 4, 1, 1, 4, 0],
        [0, 2, 0, 0, 3, 1],
        [0, 3, 1, 3, 0, 2],
        [2, 4, 0, 0, 4, 1],
        [1, 0, 3, 2, 3, 0],
      ];
    }
  }

  BarenTile _makeTile(String key, int vp) =>
      BarenTile(id: _nextTileId++, key: key, vp: vp);

  @override
  void start() {
    final gridOpt = setup.opt<String>('gridSize', '8x6');
    useAchievements = setup.opt<bool>('achievements', true);
    rows = 6;
    cols = gridOpt == '6x6' ? 6 : 8;
    zoneCols = cols ~/ 2;

    icons = [
      for (var s = 0; s < players; s++) _buildParkIcons(),
    ];
    grid = [
      for (var s = 0; s < players; s++)
        [
          for (var r = 0; r < rows; r++) List<String?>.filled(cols, null),
        ],
    ];
    placedTiles = [for (var s = 0; s < players; s++) <PlacedBarenTile>[]];
    zoneStatues = [
      for (var s = 0; s < players; s++) List<int?>.filled(4, null),
    ];
    score = List<int>.filled(players, 0);
    consecutivePasses = List<int>.filled(players, 0);

    // Build supply scaled by player count
    final houseVps = switch (players) {
      2 => [8, 6, 4],
      3 => [8, 6, 5, 4],
      _ => [8, 6, 5, 4, 3],
    };
    final gobiHouseVps = switch (players) {
      2 => [7, 5, 3],
      3 => [7, 5, 4, 3],
      _ => [7, 5, 4, 3, 2],
    };
    supply = {
      'g1': [for (var i = 0; i < 16; i++) _makeTile('g1', 0)],
      'g2': [for (var i = 0; i < 10; i++) _makeTile('g2', 0)],
      'g3': [for (var i = 0; i < 8; i++) _makeTile('g3', 1)],
      'g4': [for (var i = 0; i < 8; i++) _makeTile('g4', 1)],
      'h_koala': [for (final v in houseVps) _makeTile('h_koala', v)],
      'h_panda': [for (final v in houseVps) _makeTile('h_panda', v)],
      'h_polar': [for (final v in houseVps) _makeTile('h_polar', v)],
      'h_gobi': [for (final v in gobiHouseVps) _makeTile('h_gobi', v)],
      'e_koala': [_makeTile('e_koala', 10), _makeTile('e_koala', 9), _makeTile('e_koala', 8)],
      'e_panda': [_makeTile('e_panda', 9), _makeTile('e_panda', 8), _makeTile('e_panda', 7)],
      'e_polar': [_makeTile('e_polar', 9), _makeTile('e_polar', 8), _makeTile('e_polar', 7)],
      'e_gobi': [_makeTile('e_gobi', 8), _makeTile('e_gobi', 7), _makeTile('e_gobi', 6)],
    };

    // Bear Statues stack (4 per player)
    statues = [
      16,
      14,
      12,
      10,
      8,
      6,
      4,
      2,
      if (players >= 3) ...[12, 10, 8, 6],
      if (players >= 4) ...[10, 8, 6, 4],
    ]..sort((a, b) => b.compareTo(a));

    achievementStacks = useAchievements
        ? {
            'ach_koala': [7, 5, 3],
            'ach_green': [6, 4, 2],
            'ach_diverse': [8, 5, 3],
          }
        : {};
    playerAchievements = [for (var s = 0; s < players; s++) <String, int>{}];

    // Each player starts with a 1x2 Green Walk and a 2x2 L Food Street (plus a 1x1 Green patch)
    inventory = [
      for (var s = 0; s < players; s++)
        [
          supply['g1']!.removeAt(0),
          supply['g2']!.removeAt(0),
          supply['g3']!.removeAt(0),
        ],
    ];
  }

  /// Checks whether [seat] can place [tile] with [rot]/[flip] anchored at `(r, c)`.
  bool canPlaceTile(int seat, BarenTile tile, int r, int c,
      {int rot = 0, bool flip = false}) {
    final shape = transformCells(tile.def.cells, rot, flip);
    var touchesExisting = false;
    var touchesZone0 = false;
    final hasExisting = placedTiles[seat].isNotEmpty;

    for (final (dr, dc) in shape) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) return false;
      // Cannot cover already occupied cells
      if (grid[seat][nr][nc] != null) return false;
      // Bear Statue Pits (icon == 4) CAN NEVER BE COVERED!
      if (icons[seat][nr][nc] == 4) return false;

      if (zoneOf(nr, nc) == 0) touchesZone0 = true;
      for (final (or, oc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final ar = nr + or;
        final ac = nc + oc;
        if (ar >= 0 &&
            ar < rows &&
            ac >= 0 &&
            ac < cols &&
            grid[seat][ar][ac] != null) {
          touchesExisting = true;
        }
      }
    }

    if (!hasExisting) {
      return touchesZone0;
    }
    return touchesExisting || touchesZone0;
  }

  /// Checks if a sub-zone [z] (0..3) has all non-pit cells covered for [seat].
  bool isZoneComplete(int seat, int z) {
    final rStart = (z ~/ 2) * 3;
    final cStart = (z % 2) * zoneCols;
    for (var r = rStart; r < rStart + 3; r++) {
      for (var c = cStart; c < cStart + zoneCols; c++) {
        if (icons[seat][r][c] == 4) continue; // Bear Statue Pit
        if (grid[seat][r][c] == null) return false;
      }
    }
    return true;
  }

  bool isParkComplete(int seat) =>
      [0, 1, 2, 3].every((z) => isZoneComplete(seat, z));

  BarenTile? _takeFromSupply(int maxTier, [String? preferredKey]) {
    if (preferredKey != null) {
      final def = barenTileByKey[preferredKey];
      if (def != null &&
          def.tier <= maxTier &&
          (supply[preferredKey]?.isNotEmpty ?? false)) {
        return supply[preferredKey]!.removeAt(0);
      }
    }
    // Otherwise pick highest-VP available tile from maxTier down to 1
    for (var t = maxTier; t >= 1; t--) {
      String? bestKey;
      var bestVp = -1;
      var bestSize = -1;
      for (final d in barenTileDefs) {
        if (d.tier != t) continue;
        final stack = supply[d.key];
        if (stack == null || stack.isEmpty) continue;
        final top = stack.first;
        if (top.vp > bestVp ||
            (top.vp == bestVp && d.cells.length > bestSize)) {
          bestVp = top.vp;
          bestSize = d.cells.length;
          bestKey = d.key;
        }
      }
      if (bestKey != null) {
        return supply[bestKey]!.removeAt(0);
      }
    }
    return null;
  }

  void _checkAchievements(int seat) {
    if (!useAchievements) return;
    final placed = placedTiles[seat];

    // 1. ach_koala: 3+ koala tiles placed
    if (!playerAchievements[seat].containsKey('ach_koala') &&
        (achievementStacks['ach_koala']?.isNotEmpty ?? false)) {
      final koalas =
          placed.where((p) => p.tile.def.bearType == 'koala').length;
      if (koalas >= 3) {
        final vp = achievementStacks['ach_koala']!.removeAt(0);
        playerAchievements[seat]['ach_koala'] = vp;
        host.log('${name(seat)} 达成「考拉乐园」成就 (+$vp 分)！');
      }
    }

    // 2. ach_green: 4+ green tiles placed
    if (!playerAchievements[seat].containsKey('ach_green') &&
        (achievementStacks['ach_green']?.isNotEmpty ?? false)) {
      final greens =
          placed.where((p) => p.tile.def.bearType == 'green').length;
      if (greens >= 4) {
        final vp = achievementStacks['ach_green']!.removeAt(0);
        playerAchievements[seat]['ach_green'] = vp;
        host.log('${name(seat)} 达成「生态绿洲」成就 (+$vp 分)！');
      }
    }

    // 3. ach_diverse: all 4 bear types placed
    if (!playerAchievements[seat].containsKey('ach_diverse') &&
        (achievementStacks['ach_diverse']?.isNotEmpty ?? false)) {
      final types = {
        for (final p in placed)
          if (p.tile.def.bearType != 'green') p.tile.def.bearType,
      };
      if (types.length >= 4) {
        final vp = achievementStacks['ach_diverse']!.removeAt(0);
        playerAchievements[seat]['ach_diverse'] = vp;
        host.log('${name(seat)} 达成「万熊齐聚」成就 (+$vp 分)！');
      }
    }
  }

  void _recalcScore(int seat) {
    var total = 0;
    for (final p in placedTiles[seat]) {
      total += p.tile.vp;
    }
    for (final st in zoneStatues[seat]) {
      if (st != null) total += st;
    }
    for (final v in playerAchievements[seat].values) {
      total += v;
    }
    score[seat] = total;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type == 'place') {
      final invIdx = asInt(action['invIdx'], 0);
      if (invIdx < 0 || invIdx >= inventory[seat].length) {
        throw GameError('选择的板块无效');
      }
      final r = asInt(action['r'], -1);
      final c = asInt(action['c'], -1);
      final rot = asInt(action['rot'], 0) & 3;
      final flip = asBool(action['flip']);
      final tile = inventory[seat][invIdx];

      if (!canPlaceTile(seat, tile, r, c, rot: rot, flip: flip)) {
        throw GameError('该位置不能放置此板块（不可越界、重叠或覆盖🗽熊雕像基座）');
      }

      inventory[seat].removeAt(invIdx);
      final shape = transformCells(tile.def.cells, rot, flip);
      final absCells = <(int, int)>[];
      final coveredTiers = <int>[];

      for (final (dr, dc) in shape) {
        final nr = r + dr;
        final nc = c + dc;
        grid[seat][nr][nc] = tile.key;
        absCells.add((nr, nc));
        final ic = icons[seat][nr][nc];
        if (ic >= 1 && ic <= 3) {
          coveredTiers.add(ic);
        }
      }

      placedTiles[seat].add(PlacedBarenTile(
        tile: tile,
        r: r,
        c: c,
        rot: rot,
        flip: flip,
        absCells: absCells,
      ));

      // Gain new tiles for covered construction icons (1: 🚧, 2: 🚚, 3: 🏗️)
      final rawGains = action['gains'];
      final gainKeys = rawGains is List
          ? [for (final g in rawGains) asStr(g)]
          : const <String>[];
      final gainedNames = <String>[];
      for (var i = 0; i < coveredTiers.length; i++) {
        final tier = coveredTiers[i];
        final pref = i < gainKeys.length ? gainKeys[i] : null;
        final gained = _takeFromSupply(tier, pref);
        if (gained != null) {
          inventory[seat].add(gained);
          gainedNames.add('${gained.def.emoji}${gained.def.name}');
        }
      }

      // Check sub-zone completion -> award Bear Statue!
      final newStatues = <int>[];
      for (var z = 0; z < 4; z++) {
        if (zoneStatues[seat][z] == null && isZoneComplete(seat, z)) {
          final stVp = statues.isNotEmpty ? statues.removeAt(0) : 2;
          zoneStatues[seat][z] = stVp;
          newStatues.add(stVp);
        }
      }

      _checkAchievements(seat);
      _recalcScore(seat);
      consecutivePasses[seat] = 0;

      final gainMsg =
          gainedNames.isEmpty ? '' : '，获得 ${gainedNames.join('、')}';
      final stMsg =
          newStatues.isEmpty ? '' : '，立起🗽熊雕像 (+${newStatues.join('/')}分)';
      lastAction =
          '${name(seat)} 放置了 ${tile.def.emoji}${tile.def.name}$gainMsg$stMsg';
      host.log(lastAction);

      if (!finalRoundTriggered && isParkComplete(seat)) {
        finalRoundTriggered = true;
        triggerSeat = seat;
        host.log('🎉 ${name(seat)} 填满了全部 4 个园区，触发终局回合！');
      }

      _advanceTurn();
      return;
    }

    if (type == 'pass') {
      consecutivePasses[seat]++;
      // Passing grants a 1x1 green tile if player doesn't already have >= 2 1x1 tiles
      final hasG1 = inventory[seat].where((t) => t.key == 'g1').length;
      if (hasG1 < 2) {
        final g1 = (supply['g1']?.isNotEmpty ?? false)
            ? supply['g1']!.removeAt(0)
            : _makeTile('g1', 0);
        inventory[seat].add(g1);
        lastAction = '${name(seat)} 跳过回合，领取了 1 块 🌳1×1 花坛绿地';
      } else {
        lastAction = '${name(seat)} 跳过回合';
      }
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    throw GameError('未知操作: $type');
  }

  void _advanceTurn() {
    final nextSeat = (turn + 1) % players;
    if (nextSeat == 0) round++;

    // End game if final round completed, or everyone passed twice, or round limit reached
    if ((finalRoundTriggered && nextSeat == triggerSeat) ||
        consecutivePasses.every((p) => p >= 2) ||
        round > 26) {
      _over = true;
      for (var s = 0; s < players; s++) {
        _recalcScore(s);
      }
      host.log('熊熊公园建设结束！最终得分：${[
        for (var s = 0; s < players; s++) '${name(s)} ${score[s]}分'
      ].join('，')}');
      return;
    }

    turn = nextSeat;
  }

  /// Find a legal placement for [seat] with heuristics.
  Map<String, dynamic>? _findBestMove(int seat) {
    final inv = inventory[seat];
    if (inv.isEmpty) return {'type': 'pass'};

    Map<String, dynamic>? bestMove;
    var bestVal = -999999;

    // For easy bots, just take the first legal placement
    for (var idx = 0; idx < inv.length; idx++) {
      final tile = inv[idx];
      for (final flip in const [false, true]) {
        for (var rot = 0; rot < 4; rot++) {
          final shape = transformCells(tile.def.cells, rot, flip);
          for (var r = 0; r < rows; r++) {
            for (var c = 0; c < cols; c++) {
              if (!canPlaceTile(seat, tile, r, c, rot: rot, flip: flip)) {
                continue;
              }
              if (botLevel == 0) {
                return {
                  'type': 'place',
                  'invIdx': idx,
                  'r': r,
                  'c': c,
                  'rot': rot,
                  'flip': flip,
                };
              }
              // Score this placement: tile VP + shape size * 3 + covered icons * 10
              var val = tile.vp * 10 + shape.length * 6;
              for (final (dr, dc) in shape) {
                final ic = icons[seat][r + dr][c + dc];
                if (ic == 3) val += 35;
                if (ic == 2) val += 25;
                if (ic == 1) val += 12;
              }
              if (val > bestVal) {
                bestVal = val;
                bestMove = {
                  'type': 'place',
                  'invIdx': idx,
                  'r': r,
                  'c': c,
                  'rot': rot,
                  'flip': flip,
                };
              }
            }
          }
        }
      }
    }

    return bestMove ?? {'type': 'pass'};
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    if (aiOn) {
      final r = _ai.poll(
        setup.ai!,
        'bp:$round:$seat:${placedTiles[seat].length}',
        () => AiRequest(
          system: '你在玩《熊熊公园 Bärenpark》。请返回 JSON 动作，如 {"type":"pass"}。',
          prompt: '当前分数 ${score[seat]}，手牌 ${inventory[seat].length} 张。',
        ),
      );
      if (r.pending) return null;
    }
    return _findBestMove(seat);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'rows': rows,
      'cols': cols,
      'zoneCols': zoneCols,
      'turn': turn,
      'round': round,
      'finalRoundTriggered': finalRoundTriggered,
      'over': _over,
      'lastAction': lastAction,
      'statues': statues,
      'useAchievements': useAchievements,
      'achievementStacks': achievementStacks,
      'supply': {
        for (final d in barenTileDefs)
          d.key: {
            'key': d.key,
            'name': d.name,
            'tier': d.tier,
            'bearType': d.bearType,
            'emoji': d.emoji,
            'count': supply[d.key]?.length ?? 0,
            'topVp':
                (supply[d.key]?.isNotEmpty ?? false) ? supply[d.key]!.first.vp : 0,
            'cells': [
              for (final (r, c) in d.cells) [r, c]
            ],
          },
      },
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'score': score[s],
            'icons': icons[s],
            'grid': grid[s],
            'placedTiles': [for (final p in placedTiles[s]) p.toJson()],
            'inventory': [for (final t in inventory[s]) t.toJson()],
            'zoneStatues': zoneStatues[s],
            'achievements': playerAchievements[s],
          },
      ],
    };
  }
}
