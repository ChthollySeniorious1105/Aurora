import '../../src/engine.dart';

/// Terrain types on the 8x8 Kingdom Map:
/// 0: 空地 Empty
/// 1: 森林 Forest 🌲
/// 2: 村落 Village 🏘️
/// 3: 农田 Farm 🌾
/// 4: 水域 Water 💧
/// 5: 山脉 Mountain ⛰️
/// 6: 魔物 Monster 👹
const List<String> kTerrainNames = [
  '空地',
  '森林',
  '村落',
  '农田',
  '水域',
  '山脉',
  '魔物',
];

const List<String> kTerrainEmojis = [
  '⬜',
  '🌲',
  '🏘️',
  '🌾',
  '💧',
  '⛰️',
  '👹',
];

const List<String> kSeasonNames = [
  '春季 (A+B)',
  '夏季 (B+C)',
  '秋季 (C+D)',
  '冬季 (D+A)',
];

const List<(int, int)> kMountainCoords = [
  (1, 2),
  (2, 6),
  (4, 4),
  (5, 1),
  (6, 5),
];

class EdictDef {
  final String id;
  final String name;
  final String desc;
  const EdictDef(this.id, this.name, this.desc);
}

const List<EdictDef> kEdictDefs = [
  EdictDef('sentinel_wood', '哨兵森林', '位于地图四条边缘上的每格森林(🌲)得 1 分，含至少2格森林的每行额外得 1 分'),
  EdictDef('greenbough', '翠绿林海', '每格与山脉(⛰️)正交相邻的森林(🌲)得 2 分，其余每满2格森林得 1 分'),
  EdictDef('greengold_plains', '繁华聚落', '每个正交连通面积 ≥3 的村落(🏘️)群得 5 分，面积 ≥5 得 8 分'),
  EdictDef('shieldgate', '百业村落', '每格正交邻接至少 2 种其他非空地形的村落(🏘️)得 2 分'),
  EdictDef('canal_lake', '河谷良田', '与水域(💧)正交相邻的每格农田(🌾)得 2 分，与农田正交相邻的每格水域得 1 分'),
  EdictDef('mages_valley', '高山湖泊', '与山脉(⛰️)正交相邻的每格水域(💧)得 2 分，与山脉正交相邻的每格农田(🌾)得 1 分'),
  EdictDef('borderlands', '广袤疆域', '每条填满非空地形的完整行或完整列各得 6 分'),
  EdictDef('lost_barony', '开拓领地', '地图上每有 4 格已绘制的非魔物地形（森林/村落/农田/水域）得 2 分'),
];

class ExploreCardDef {
  final String id;
  final String name;
  final int time;
  final List<int> terrainOptions;
  final List<List<List<int>>> shapes;
  final bool isMonster;
  final bool firstShapeGivesCoin;

  const ExploreCardDef({
    required this.id,
    required this.name,
    required this.time,
    required this.terrainOptions,
    required this.shapes,
    this.isMonster = false,
    this.firstShapeGivesCoin = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'time': time,
        'terrainOptions': terrainOptions,
        'shapes': shapes,
        'isMonster': isMonster,
        'firstShapeGivesCoin': firstShapeGivesCoin,
      };
}

const List<ExploreCardDef> kExploreDeck = [
  ExploreCardDef(
    id: 'treetop_village',
    name: '树梢村落',
    time: 2,
    terrainOptions: [1, 2],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [1, 0],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 2],
      ],
    ],
    firstShapeGivesCoin: true,
  ),
  ExploreCardDef(
    id: 'farmland_stream',
    name: '农田溪流',
    time: 1,
    terrainOptions: [3, 4],
    shapes: [
      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 1],
      ],
    ],
    firstShapeGivesCoin: true,
  ),
  ExploreCardDef(
    id: 'marsh_woods',
    name: '林间湿地',
    time: 2,
    terrainOptions: [1, 4],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 1],
        [1, 2],
      ],
    ],
  ),
  ExploreCardDef(
    id: 'homestead',
    name: '边陲庄园',
    time: 2,
    terrainOptions: [2, 3],
    shapes: [
      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
        [1, 1],
      ],
    ],
    firstShapeGivesCoin: true,
  ),
  ExploreCardDef(
    id: 'forgotten_forest',
    name: '遗忘森林',
    time: 1,
    terrainOptions: [1],
    shapes: [
      [
        [0, 0],
        [1, 1],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 0],
      ],
    ],
    firstShapeGivesCoin: true,
  ),
  ExploreCardDef(
    id: 'fishing_hamlet',
    name: '渔人聚落',
    time: 2,
    terrainOptions: [2, 4],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [0, 1],
        [0, 2],
        [0, 3],
      ],
    ],
  ),
  ExploreCardDef(
    id: 'orchard',
    name: '丰饶果园',
    time: 2,
    terrainOptions: [1, 3],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [1, 0],
      ],
      [
        [0, 1],
        [1, 0],
        [1, 1],
        [1, 2],
      ],
    ],
  ),
  ExploreCardDef(
    id: 'outpost_ruins',
    name: '荒野驿站',
    time: 1,
    terrainOptions: [1, 2, 3, 4],
    shapes: [
      [
        [0, 0],
      ],
      [
        [0, 0],
        [0, 1],
      ],
    ],
  ),
  ExploreCardDef(
    id: 'great_river',
    name: '蜿蜒大河',
    time: 1,
    terrainOptions: [4],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
      [
        [0, 0],
        [0, 1],
        [1, 1],
      ],
    ],
    firstShapeGivesCoin: true,
  ),
  ExploreCardDef(
    id: 'hilltop_granary',
    name: '高地谷仓',
    time: 2,
    terrainOptions: [2, 3, 4],
    shapes: [
      [
        [0, 0],
        [0, 1],
      ],
      [
        [0, 0],
        [1, 0],
        [1, 1],
        [2, 0],
      ],
    ],
  ),
];

const List<ExploreCardDef> kMonsterAmbushCards = [
  ExploreCardDef(
    id: 'goblin_attack',
    name: '哥布林袭击',
    time: 1,
    terrainOptions: [6],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [1, 0],
      ],
    ],
    isMonster: true,
  ),
  ExploreCardDef(
    id: 'bugbear_assault',
    name: '大地精突袭',
    time: 1,
    terrainOptions: [6],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [0, 2],
      ],
    ],
    isMonster: true,
  ),
  ExploreCardDef(
    id: 'kobold_onslaught',
    name: '狗头人伏击',
    time: 1,
    terrainOptions: [6],
    shapes: [
      [
        [0, 0],
        [0, 1],
        [1, 1],
      ],
    ],
    isMonster: true,
  ),
  ExploreCardDef(
    id: 'gnoll_raid',
    name: '豺狼人入侵',
    time: 1,
    terrainOptions: [6],
    shapes: [
      [
        [0, 0],
        [0, 1],
      ],
    ],
    isMonster: true,
  ),
];

/// Normalize a list of [r, c] cells so minimum r and minimum c are 0, sorted lexicographically.
List<(int, int)> normalizeCells(Iterable<(int, int)> cells) {
  final list = cells.toList();
  if (list.isEmpty) return const [];
  var minR = list.first.$1;
  var minC = list.first.$2;
  for (final (r, c) in list) {
    if (r < minR) minR = r;
    if (c < minC) minC = c;
  }
  final norm = [for (final (r, c) in list) (r - minR, c - minC)];
  norm.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return norm;
}

/// Generate all 8 dihedral (rotation + reflection) normalized orientations of a shape.
List<List<(int, int)>> allOrientations(List<List<int>> rawShape) {
  final base = [for (final p in rawShape) (p[0], p[1])];
  final seen = <String>{};
  final result = <List<(int, int)>>[];
  for (var flip = 0; flip < 2; flip++) {
    for (var rot = 0; rot < 4; rot++) {
      final transformed = <(int, int)>[];
      for (var (r, c) in base) {
        if (flip == 1) c = -c;
        for (var k = 0; k < rot; k++) {
          final nr = c;
          final nc = -r;
          r = nr;
          c = nc;
        }
        transformed.add((r, c));
      }
      final norm = normalizeCells(transformed);
      final key = norm.map((e) => '${e.$1},${e.$2}').join(';');
      if (seen.add(key)) {
        result.add(norm);
      }
    }
  }
  return result;
}

/// Returns the index of the matched shape in [shapes] (0, 1, ...) or -1 if none match.
int matchShapeIndex(List<(int, int)> placedCells, List<List<List<int>>> shapes) {
  final normPlaced = normalizeCells(placedCells);
  for (var i = 0; i < shapes.length; i++) {
    final orientations = allOrientations(shapes[i]);
    for (final o in orientations) {
      if (o.length != normPlaced.length) continue;
      var same = true;
      for (var k = 0; k < o.length; k++) {
        if (o[k].$1 != normPlaced[k].$1 || o[k].$2 != normPlaced[k].$2) {
          same = false;
          break;
        }
      }
      if (same) return i;
    }
  }
  return -1;
}

/// Find all valid placements of [shapes] on an 8x8 [map].
List<List<(int, int)>> findValidPlacements(
    List<List<int>> map, List<List<List<int>>> shapes) {
  final valid = <List<(int, int)>>[];
  for (final shape in shapes) {
    for (final orient in allOrientations(shape)) {
      for (var r0 = 0; r0 < 8; r0++) {
        for (var c0 = 0; c0 < 8; c0++) {
          var ok = true;
          final cells = <(int, int)>[];
          for (final (dr, dc) in orient) {
            final r = r0 + dr;
            final c = c0 + dc;
            if (r < 0 || r >= 8 || c < 0 || c >= 8 || map[r][c] != 0) {
              ok = false;
              break;
            }
            cells.add((r, c));
          }
          if (ok) valid.add(cells);
        }
      }
    }
  }
  return valid;
}

/// Count how many Mountain (5) cells on [map] have all 4 orthogonal neighbors non-empty (!= 0).
int countSurroundedMountains(List<List<int>> map) {
  var count = 0;
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      if (map[r][c] != 5) continue;
      var surrounded = true;
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
          if (map[nr][nc] == 0) {
            surrounded = false;
            break;
          }
        }
      }
      if (surrounded) count++;
    }
  }
  return count;
}

/// Count empty cells (0) orthogonally adjacent to at least one Monster (6).
int countMonsterPenalty(List<List<int>> map) {
  var penalty = 0;
  for (var r = 0; r < 8; r++) {
    for (var c = 0; c < 8; c++) {
      if (map[r][c] != 0) continue;
      var adjMonster = false;
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && map[nr][nc] == 6) {
          adjMonster = true;
          break;
        }
      }
      if (adjMonster) penalty++;
    }
  }
  return penalty;
}

/// Score a single Edict on an 8x8 [map].
int scoreEdict(String edictId, List<List<int>> map) {
  switch (edictId) {
    case 'sentinel_wood':
      var pts = 0;
      for (var r = 0; r < 8; r++) {
        var rowForests = 0;
        for (var c = 0; c < 8; c++) {
          if (map[r][c] == 1) {
            rowForests++;
            if (r == 0 || r == 7 || c == 0 || c == 7) pts += 1;
          }
        }
        if (rowForests >= 2) pts += 1;
      }
      return pts;

    case 'greenbough':
      var adjMtn = 0;
      var otherForest = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (map[r][c] != 1) continue;
          var nearMtn = false;
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && map[nr][nc] == 5) {
              nearMtn = true;
              break;
            }
          }
          if (nearMtn) {
            adjMtn++;
          } else {
            otherForest++;
          }
        }
      }
      return adjMtn * 2 + (otherForest ~/ 2);

    case 'greengold_plains':
      final visited = List.generate(8, (_) => List.filled(8, false));
      var pts = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (map[r][c] != 2 || visited[r][c]) continue;
          var size = 0;
          final q = <(int, int)>[(r, c)];
          visited[r][c] = true;
          while (q.isNotEmpty) {
            final (cr, cc) = q.removeLast();
            size++;
            for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
              final nr = cr + dr, nc = cc + dc;
              if (nr >= 0 &&
                  nr < 8 &&
                  nc >= 0 &&
                  nc < 8 &&
                  !visited[nr][nc] &&
                  map[nr][nc] == 2) {
                visited[nr][nc] = true;
                q.add((nr, nc));
              }
            }
          }
          if (size >= 5) {
            pts += 8;
          } else if (size >= 3) {
            pts += 5;
          }
        }
      }
      return pts;

    case 'shieldgate':
      var pts = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          if (map[r][c] != 2) continue;
          final adjTypes = <int>{};
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
              final t = map[nr][nc];
              if (t != 0 && t != 2) adjTypes.add(t);
            }
          }
          if (adjTypes.length >= 2) pts += 2;
        }
      }
      return pts;

    case 'canal_lake':
      var pts = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final t = map[r][c];
          if (t != 3 && t != 4) continue;
          final target = t == 3 ? 4 : 3;
          var hasTarget = false;
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && map[nr][nc] == target) {
              hasTarget = true;
              break;
            }
          }
          if (hasTarget) pts += (t == 3 ? 2 : 1);
        }
      }
      return pts;

    case 'mages_valley':
      var pts = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final t = map[r][c];
          if (t != 3 && t != 4) continue;
          var nearMtn = false;
          for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
            final nr = r + dr, nc = c + dc;
            if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8 && map[nr][nc] == 5) {
              nearMtn = true;
              break;
            }
          }
          if (nearMtn) pts += (t == 4 ? 2 : 1);
        }
      }
      return pts;

    case 'borderlands':
      var fullLines = 0;
      for (var r = 0; r < 8; r++) {
        if (map[r].every((cell) => cell != 0)) fullLines++;
      }
      for (var c = 0; c < 8; c++) {
        var full = true;
        for (var r = 0; r < 8; r++) {
          if (map[r][c] == 0) {
            full = false;
            break;
          }
        }
        if (full) fullLines++;
      }
      return fullLines * 6;

    case 'lost_barony':
    default:
      var filled = 0;
      for (var r = 0; r < 8; r++) {
        for (var c = 0; c < 8; c++) {
          final t = map[r][c];
          if (t >= 1 && t <= 4) filled++;
        }
      }
      return (filled ~/ 4) * 2;
  }
}

class CartographersGame extends GameEngine {
  CartographersGame(super.setup);

  /// 8x8 map per seat: maps[seat][r][c]
  late List<List<List<int>>> maps;

  /// Current gold coins per seat
  late List<int> coins;

  /// Bonus coins earned from choosing coin-shapes (in addition to surrounded mountains)
  late List<int> shapeCoins;

  /// Total score per seat
  late List<int> scores;

  /// Season score breakdown: seasonScores[seat][season]
  late List<List<int>> seasonScores;

  /// Whether each seat has placed on the current Explore card
  late List<bool> placedThisTurn;

  /// 4 Edict defs chosen for A, B, C, D
  late List<EdictDef> edicts;

  /// Season 0..3 (0=Spring, 1=Summer, 2=Autumn, 3=Winter)
  int season = 0;
  int seasonTime = 0;
  late List<int> seasonThresholds;

  late List<ExploreCardDef> currentDeck;
  late ExploreCardDef currentCard;
  int turnNumber = 1;
  String lastLog = '';
  bool over = false;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return [
      for (var s = 0; s < players; s++)
        if (!placedThisTurn[s]) s
    ];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    seasonThresholds = mode == 'fast' ? [5, 5, 4, 4] : [7, 7, 6, 5];

    maps = List.generate(players, (_) {
      final m = List.generate(8, (_) => List<int>.filled(8, 0));
      for (final (r, c) in kMountainCoords) {
        m[r][c] = 5;
      }
      return m;
    });

    coins = List<int>.filled(players, 0);
    shapeCoins = List<int>.filled(players, 0);
    scores = List<int>.filled(players, 0);
    seasonScores = List.generate(players, (_) => List<int>.filled(4, 0));
    placedThisTurn = List<bool>.filled(players, false);

    final shuffledEdicts = shuffled(kEdictDefs, rng);
    edicts = shuffledEdicts.sublist(0, 4);

    season = 0;
    seasonTime = 0;
    turnNumber = 1;
    over = false;

    _startSeasonDeck();
    _drawNextExploreCard();
    lastLog =
        '制图师开始！四季诏令：A【${edicts[0].name}】 B【${edicts[1].name}】 C【${edicts[2].name}】 D【${edicts[3].name}】';
    host.log(lastLog);
  }

  void _startSeasonDeck() {
    final pool = <ExploreCardDef>[
      ...kExploreDeck,
      kMonsterAmbushCards[season % kMonsterAmbushCards.length],
    ];
    currentDeck = shuffled(pool, rng);
  }

  void _drawNextExploreCard() {
    if (currentDeck.isEmpty) {
      _startSeasonDeck();
    }
    currentCard = currentDeck.removeLast();
    for (var s = 0; s < players; s++) {
      placedThisTurn[s] = false;
    }
  }

  /// Recomputes coins[seat] from surrounded mountains + shapeCoins[seat].
  void updateCoinsForSeat(int seat) {
    final mtnCoins = countSurroundedMountains(maps[seat]);
    coins[seat] = mtnCoins + shapeCoins[seat];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (placedThisTurn[seat]) throw GameError('本回合你已完成绘制');

    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作类型: $type');

    final terrain = asInt(action['terrain'], -1);
    if (!currentCard.terrainOptions.contains(terrain)) {
      throw GameError('当前探索卡不允许绘制该地形');
    }

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.isEmpty) {
      throw GameError('请选择要绘制的地图格子');
    }

    final cells = <(int, int)>[];
    final seen = <int>{};
    for (final item in rawCells) {
      int r = -1, c = -1;
      if (item is List && item.length >= 2) {
        r = asInt(item[0], -1);
        c = asInt(item[1], -1);
      } else if (item is Map) {
        r = asInt(item['r'] ?? item['row'], -1);
        c = asInt(item['c'] ?? item['col'], -1);
      }
      if (r < 0 || r >= 8 || c < 0 || c >= 8) {
        throw GameError('坐标超出 8×8 地图范围');
      }
      final key = r * 8 + c;
      if (!seen.add(key)) {
        throw GameError('不能包含重复的格子坐标');
      }
      if (maps[seat][r][c] != 0) {
        throw GameError('格子 ($r, $c) 不是空地，无法覆盖绘制');
      }
      cells.add((r, c));
    }

    final matchedIdx = matchShapeIndex(cells, currentCard.shapes);
    if (matchedIdx < 0) {
      // Allow 1x1 fallback if player explicitly places 1 cell when no full shape fits or as emergency 1x1
      final validAny = findValidPlacements(maps[seat], currentCard.shapes);
      if (validAny.isNotEmpty && cells.length != 1) {
        throw GameError('所选格子形状与当前探索卡不匹配');
      }
      if (cells.length != 1) {
        throw GameError('所选格子形状与当前探索卡不匹配');
      }
    }

    // Apply terrain onto map
    for (final (r, c) in cells) {
      maps[seat][r][c] = terrain;
    }
    if (matchedIdx == 0 && currentCard.firstShapeGivesCoin) {
      shapeCoins[seat]++;
    }
    updateCoinsForSeat(seat);
    placedThisTurn[seat] = true;

    // If all players have placed, advance turn / season
    if (waitingFor.isEmpty) {
      _finishTurn();
    }
  }

  void _finishTurn() {
    seasonTime += currentCard.time;
    turnNumber++;
    final threshold = seasonThresholds[season];

    if (seasonTime >= threshold) {
      _scoreCurrentSeason();
      if (season >= 3) {
        over = true;
        final best = scores.reduce((a, b) => a > b ? a : b);
        final winners = [
          for (var s = 0; s < players; s++)
            if (scores[s] == best) name(s)
        ];
        lastLog = '冬季结算完成！最终赢家：${winners.join("、")}（$best 分）';
        host.log(lastLog);
        return;
      } else {
        season++;
        seasonTime = 0;
        _startSeasonDeck();
      }
    }
    _drawNextExploreCard();
  }

  void _scoreCurrentSeason() {
    final edictA = edicts[season % 4];
    final edictB = edicts[(season + 1) % 4];
    for (var s = 0; s < players; s++) {
      updateCoinsForSeat(s);
      final ptsA = scoreEdict(edictA.id, maps[s]);
      final ptsB = scoreEdict(edictB.id, maps[s]);
      final coinPts = coins[s];
      final monsterPen = countMonsterPenalty(maps[s]);
      final total = ptsA + ptsB + coinPts - monsterPen;
      seasonScores[s][season] = total;
      scores[s] += total;
    }
    lastLog =
        '${kSeasonNames[season]} 结算完成（计分诏令：${edictA.name} + ${edictB.name} + 金币 - 魔物扣分）';
    host.log(lastLog);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final mySeat = seat >= 0 && seat < players ? seat : 0;
    final samplePlacements =
        findValidPlacements(maps[mySeat], currentCard.shapes);

    return {
      'maps': [
        for (var s = 0; s < players; s++)
          [
            for (final row in maps[s]) [...row]
          ]
      ],
      'coins': [...coins],
      'scores': [...scores],
      'seasonScores': [
        for (final ss in seasonScores) [...ss]
      ],
      'monsterPenalties': [
        for (var s = 0; s < players; s++) countMonsterPenalty(maps[s])
      ],
      'placedThisTurn': [...placedThisTurn],
      'season': season,
      'seasonName': kSeasonNames[season],
      'seasonTime': seasonTime,
      'seasonThreshold': seasonThresholds[season],
      'turnNumber': turnNumber,
      'edicts': [
        for (var i = 0; i < edicts.length; i++)
          {
            'slot': const ['A', 'B', 'C', 'D'][i],
            'id': edicts[i].id,
            'name': edicts[i].name,
            'desc': edicts[i].desc,
            'activeThisSeason': i == season % 4 || i == (season + 1) % 4,
          }
      ],
      'currentCard': currentCard.toJson(),
      'samplePlacement': samplePlacements.isNotEmpty
          ? [
              for (final (r, c) in samplePlacements.first) [r, c]
            ]
          : const <List<int>>[],
      'lastLog': lastLog,
      'over': over,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || placedThisTurn[seat]) {
      return null;
    }
    final map = maps[seat];
    final terrain = currentCard.terrainOptions[
        rng.nextInt(currentCard.terrainOptions.length)];
    final placements = findValidPlacements(map, currentCard.shapes);

    if (placements.isNotEmpty) {
      // On normal/hard difficulty, prefer placements adjacent to mountains or monsters to seal them
      if (botLevel >= 1 && placements.length > 1) {
        List<(int, int)>? best;
        var bestScore = -999;
        final limit = placements.length < 25 ? placements.length : 25;
        for (var i = 0; i < limit; i++) {
          final p = placements[i];
          var sc = p.length * 2;
          for (final (r, c) in p) {
            for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
              final nr = r + dr, nc = c + dc;
              if (nr >= 0 && nr < 8 && nc >= 0 && nc < 8) {
                if (map[nr][nc] == 5) sc += 3; // near mountain
                if (map[nr][nc] == 6) sc += 4; // cover monster neighbor
              }
            }
          }
          if (sc > bestScore) {
            bestScore = sc;
            best = p;
          }
        }
        if (best != null) {
          return {
            'type': 'place',
            'terrain': terrain,
            'cells': [
              for (final (r, c) in best) [r, c]
            ],
          };
        }
      }
      final chosen = placements[rng.nextInt(placements.length)];
      return {
        'type': 'place',
        'terrain': terrain,
        'cells': [
          for (final (r, c) in chosen) [r, c]
        ],
      };
    }

    // Fallback: pick any single empty cell
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (map[r][c] == 0) {
          return {
            'type': 'place',
            'terrain': terrain,
            'cells': [
              [r, c]
            ],
          };
        }
      }
    }
    return null;
  }
}
