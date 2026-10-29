import '../../src/engine.dart';

const List<String> guildTerrainNames = [
  '海洋',
  '平原',
  '山脉',
  '沙漠',
  '发现塔',
  '宝藏遗迹',
];

const List<String> guildTerrainEmojis = [
  '🌊',
  '🌾',
  '⛰️',
  '🏜️',
  '🗼',
  '🏚️',
];

class GuildExploreCard {
  final int id;
  final String name;
  final String emoji;
  final int terrainType; // 0: 🌊, 1: 🌾, 2: ⛰️, 3: 🏜️, -1: Wild/Era Power
  final int maxCells; // max explorer cubes to place

  const GuildExploreCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.terrainType,
    required this.maxCells,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'terrainType': terrainType,
        'terrainName':
            terrainType >= 0 ? guildTerrainNames[terrainType] : '任意地形',
        'terrainEmoji':
            terrainType >= 0 ? guildTerrainEmojis[terrainType] : '🧭',
        'maxCells': maxCells,
      };
}

class GuildExplorersGame extends GameEngine {
  static const int mapSize = 7;
  static const int capR = 3;
  static const int capC = 3;
  static const int cardsPerEra = 5;
  static const List<int> towerRewards = [4, 6, 8, 10];

  static const List<(int, int)> dirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  // 0: 🌊 海洋, 1: 🌾 平原, 2: ⛰️ 山脉, 3: 🏜️ 沙漠, 4: 🗼 发现塔, 5: 🏚️ 宝藏遗迹
  static const List<List<int>> defaultTerrain = [
    [4, 0, 5, 1, 1, 0, 4],
    [0, 3, 3, 2, 0, 2, 2],
    [5, 0, 1, 1, 3, 3, 5],
    [0, 2, 2, 1, 2, 0, 0],
    [5, 0, 3, 3, 1, 1, 5],
    [2, 2, 0, 2, 3, 3, 0],
    [4, 0, 1, 1, 5, 0, 4],
  ];

  late final int maxEras;
  late List<List<int>> terrain;
  late List<GuildExploreCard> eraDeck;
  late GuildExploreCard currentCard;

  /// Explorer cubes placed in the current Era (`explored[seat][r][c]`).
  /// Reset at the end of each Era (except Capital `(3, 3)`).
  late List<List<List<bool>>> explored;

  /// Permanent Villages (`villages[seat][r][c]`) — NEVER reset across Eras!
  late List<List<List<bool>>> villages;

  /// Discovery Towers discovered (`towers[seat][r][c]`) — persist across Eras.
  late List<List<List<bool>>> towers;

  /// Ruins looted in the current game (`ruins[seat][r][c]`).
  late List<List<List<bool>>> ruins;

  late List<bool> actedThisCard;
  late List<int> villageVp;
  late List<int> towerCoins;
  late List<int> treasureCoins;
  late List<int> score;

  int era = 1;
  int cardStep = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '探索者公会王国勘探开启';

  GuildExplorersGame(super.setup) : maxEras = setup.opt<int>('eras', 4);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<GuildExploreCard> _buildEraDeck(int eraNum) {
    final base = <GuildExploreCard>[
      const GuildExploreCard(
        id: 1,
        name: '平原开拓令',
        emoji: '🌾',
        terrainType: 1,
        maxCells: 3,
      ),
      const GuildExploreCard(
        id: 2,
        name: '山脉攀登令',
        emoji: '⛰️',
        terrainType: 2,
        maxCells: 2,
      ),
      const GuildExploreCard(
        id: 3,
        name: '沙漠远征令',
        emoji: '🏜️',
        terrainType: 3,
        maxCells: 2,
      ),
      const GuildExploreCard(
        id: 4,
        name: '远洋航海令',
        emoji: '🌊',
        terrainType: 0,
        maxCells: 3,
      ),
      GuildExploreCard(
        id: 10 + eraNum,
        name: '第$eraNum时代专精路线',
        emoji: '🧭',
        terrainType: -1,
        maxCells: 2,
      ),
    ];
    return shuffled(base, rng);
  }

  @override
  void start() {
    terrain = [
      for (final row in defaultTerrain) List<int>.of(row),
    ];
    explored = List.generate(
      players,
      (_) => List.generate(
        mapSize,
        (r) => List.generate(mapSize, (c) => r == capR && c == capC),
      ),
    );
    villages = List.generate(
      players,
      (_) => List.generate(mapSize, (_) => List.filled(mapSize, false)),
    );
    towers = List.generate(
      players,
      (_) => List.generate(mapSize, (_) => List.filled(mapSize, false)),
    );
    ruins = List.generate(
      players,
      (_) => List.generate(mapSize, (_) => List.filled(mapSize, false)),
    );

    actedThisCard = List.filled(players, false);
    villageVp = List.filled(players, 0);
    towerCoins = List.filled(players, 0);
    treasureCoins = List.filled(players, 0);
    score = List.filled(players, 0);

    era = 1;
    cardStep = 1;
    eraDeck = _buildEraDeck(era);
    currentCard = eraDeck.removeLast();
    turn = 0;
    over = false;
    lastAction =
        '第 1 时代开始！当前探索卡：${currentCard.emoji}${currentCard.name} (最多放置 ${currentCard.maxCells} 枚探索方块)';
  }

  int countVillages(int seat) {
    var cnt = 0;
    for (var r = 0; r < mapSize; r++) {
      for (var c = 0; c < mapSize; c++) {
        if (villages[seat][r][c]) cnt++;
      }
    }
    return cnt;
  }

  int countTowers(int seat) {
    var cnt = 0;
    for (var r = 0; r < mapSize; r++) {
      for (var c = 0; c < mapSize; c++) {
        if (towers[seat][r][c]) cnt++;
      }
    }
    return cnt;
  }

  int calcScore(int seat) =>
      villageVp[seat] + towerCoins[seat] + treasureCoins[seat];

  /// Returns true if `(r, c)` is orthogonally adjacent to `(3, 3)`, any Permanent Village,
  /// any already-explored cell for `seat`, or any cell in `tempExplored`.
  bool isConnectedToHubOrExplored(
    int seat,
    int r,
    int c, [
    Set<(int, int)> tempExplored = const {},
  ]) {
    if (villages[seat][r][c]) return true;
    for (final (dr, dc) in dirs) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr < 0 || nr >= mapSize || nc < 0 || nc >= mapSize) continue;
      if (nr == capR && nc == capC) return true;
      if (explored[seat][nr][nc]) return true;
      if (villages[seat][nr][nc]) return true;
      if (tempExplored.contains((nr, nc))) return true;
    }
    return false;
  }

  bool matchesCardTerrain(int r, int c, GuildExploreCard card) {
    final t = terrain[r][c];
    if (card.terrainType < 0) return true;
    if (t == card.terrainType) return true;
    // Discovery Towers (4) and Ruins (5) can be explored when reached
    if (t == 4 || t == 5) return true;
    return false;
  }

  /// Finds all legal single-step unexplored cells for `seat` given `tempExplored`.
  List<(int, int)> legalNextCells(
    int seat,
    GuildExploreCard card, [
    Set<(int, int)> tempExplored = const {},
  ]) {
    final matching = <(int, int)>[];
    final anyConnected = <(int, int)>[];
    for (var r = 0; r < mapSize; r++) {
      for (var c = 0; c < mapSize; c++) {
        if (explored[seat][r][c] || tempExplored.contains((r, c))) continue;
        if (!isConnectedToHubOrExplored(seat, r, c, tempExplored)) continue;
        anyConnected.add((r, c));
        if (matchesCardTerrain(r, c, card)) {
          matching.add((r, c));
        }
      }
    }
    return matching.isNotEmpty ? matching : anyConnected;
  }

  /// Returns the contiguous orthogonal region of cells sharing `terrain[startR][startC]`.
  List<(int, int)> contiguousRegion(int startR, int startC) {
    final t = terrain[startR][startC];
    final visited = <(int, int)>{(startR, startC)};
    final queue = <(int, int)>[(startR, startC)];
    while (queue.isNotEmpty) {
      final (cr, cc) = queue.removeLast();
      for (final (dr, dc) in dirs) {
        final nr = cr + dr;
        final nc = cc + dc;
        if (nr < 0 || nr >= mapSize || nc < 0 || nc >= mapSize) continue;
        if (terrain[nr][nc] == t && visited.add((nr, nc))) {
          queue.add((nr, nc));
        }
      }
    }
    return visited.toList();
  }

  /// Checks if the contiguous region of `🌾(1)/⛰️(2)/🏜️(3)` at `(r, c)` is now completely
  /// explored by `seat`; if so, places a Permanent Village (`🏠`) at `(r, c)`.
  bool _checkAndPlaceVillage(int seat, int r, int c) {
    final t = terrain[r][c];
    if (t < 1 || t > 3) return false;
    final region = contiguousRegion(r, c);
    for (final (rr, rc) in region) {
      if (rr == capR && rc == capC) continue;
      if (!explored[seat][rr][rc]) return false;
      if (villages[seat][rr][rc]) return false; // Region already has a village
    }
    final placeR = (r == capR && c == capC && region.length > 1)
        ? region.firstWhere((p) => p != (capR, capC)).$1
        : r;
    final placeC = (r == capR && c == capC && region.length > 1)
        ? region.firstWhere((p) => p != (capR, capC)).$2
        : c;
    villages[seat][placeR][placeC] = true;
    final vpGain = era + 1; // +2/+3/+4/+5 VP depending on Era
    villageVp[seat] += vpGain;
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type != 'explore') {
      throw GameError('未知操作: $type');
    }

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.isEmpty) {
      throw GameError('请至少选择 1 个要探索的地图格');
    }
    if (rawCells.length > currentCard.maxCells) {
      throw GameError('当前探索卡最多只能放置 ${currentCard.maxCells} 枚探索方块');
    }

    final chosen = <(int, int)>[];
    final tempSet = <(int, int)>{};

    // Check if player has any terrain-matching connected cell initially
    final hasStrictMatch = <bool>[];
    for (var i = 0; i < rawCells.length; i++) {
      final item = rawCells[i];
      int r = -1;
      int c = -1;
      if (item is List && item.length >= 2) {
        r = asInt(item[0], -1);
        c = asInt(item[1], -1);
      } else if (item is Map) {
        r = asInt(item['r'], -1);
        c = asInt(item['c'], -1);
      }
      if (r < 0 || r >= mapSize || c < 0 || c >= mapSize) {
        throw GameError('无效的地图坐标 ($r, $c)');
      }
      if (explored[seat][r][c] || tempSet.contains((r, c))) {
        throw GameError('地图格 ($r, $c) 在本时代已被探索');
      }
      if (!isConnectedToHubOrExplored(seat, r, c, tempSet)) {
        throw GameError('探索格 ($r, $c) 必须与王都(3,3)、永久村落(🏠)或已探索格正交相邻');
      }

      // Check terrain match (unless player has zero matching connected cells on map)
      var anyMatchAvailable = false;
      for (var mr = 0; mr < mapSize; mr++) {
        for (var mc = 0; mc < mapSize; mc++) {
          if (explored[seat][mr][mc] || tempSet.contains((mr, mc))) continue;
          if (isConnectedToHubOrExplored(seat, mr, mc, tempSet) &&
              matchesCardTerrain(mr, mc, currentCard)) {
            anyMatchAvailable = true;
            break;
          }
        }
        if (anyMatchAvailable) break;
      }

      if (anyMatchAvailable && !matchesCardTerrain(r, c, currentCard)) {
        throw GameError(
            '地图格 ($r, $c) 地形为${guildTerrainNames[terrain[r][c]]}，与当前探索卡(${currentCard.name})不匹配');
      }

      hasStrictMatch.add(anyMatchAvailable);
      chosen.add((r, c));
      tempSet.add((r, c));
    }

    // Commit exploration
    var newVillages = 0;
    var towerGain = 0;
    var ruinGain = 0;

    for (final (r, c) in chosen) {
      explored[seat][r][c] = true;
      final t = terrain[r][c];
      if (t >= 1 && t <= 3) {
        if (_checkAndPlaceVillage(seat, r, c)) {
          newVillages++;
        }
      } else if (t == 4 && !towers[seat][r][c]) {
        towers[seat][r][c] = true;
        final tc = countTowers(seat);
        final reward = towerRewards[(tc - 1).clamp(0, towerRewards.length - 1)];
        towerCoins[seat] += reward;
        towerGain += reward;
      } else if (t == 5 && !ruins[seat][r][c]) {
        ruins[seat][r][c] = true;
        final reward = 3 + era; // Treasure & Trade Route bonus (+4..7 coins)
        treasureCoins[seat] += reward;
        ruinGain += reward;
      }
    }

    actedThisCard[seat] = true;
    score[seat] = calcScore(seat);

    final extras = <String>[
      if (newVillages > 0) '建立 $newVillages 座🏠永久村落',
      if (towerGain > 0) '登顶🗼发现塔 +$towerGain🪙',
      if (ruinGain > 0) '发掘🏚️宝藏遗迹 +$ruinGain🪙',
    ];
    final extraStr = extras.isEmpty ? '' : '（${extras.join("，")}）';
    lastAction =
        '${name(seat)} 探索了 ${chosen.map((p) => "(${p.$1},${p.$2})").join(" ")}$extraStr';
    host.log(lastAction);
    _advanceTurn();
  }

  /// Performs the End-of-Era cleanup: removes all Explorer Cubes (except Capital `(3,3)`),
  /// while keeping all Permanent Villages (`villages[seat][r][c]`) on the map!
  void endCurrentEra() {
    for (var s = 0; s < players; s++) {
      // Each permanent village scores +1 VP at end of Era
      villageVp[s] += countVillages(s);
      for (var r = 0; r < mapSize; r++) {
        for (var c = 0; c < mapSize; c++) {
          explored[s][r][c] = (r == capR && c == capC);
        }
      }
      score[s] = calcScore(s);
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (!actedThisCard[nextSeat]) {
        turn = nextSeat;
        return;
      }
    }

    // All players have resolved the current Explore Card
    actedThisCard = List.filled(players, false);
    if (cardStep < cardsPerEra && eraDeck.isNotEmpty) {
      cardStep++;
      currentCard = eraDeck.removeLast();
      turn = (cardStep - 1) % players;
      return;
    }

    // End of Era!
    endCurrentEra();
    if (era >= maxEras) {
      over = true;
      lastAction = '探索者公会 4 个时代全部结束！总分最高者获胜';
      host.log(lastAction);
      return;
    }

    era++;
    cardStep = 1;
    eraDeck = _buildEraDeck(era);
    currentCard = eraDeck.removeLast();
    turn = (era - 1) % players;
    lastAction =
        '第 $era 时代开始！探索方块已收回，🏠永久村落保留为新起点。当前卡：${currentCard.emoji}${currentCard.name}';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final chosen = <List<int>>[];
    final tempSet = <(int, int)>{};

    for (var step = 0; step < currentCard.maxCells; step++) {
      final candidates = legalNextCells(seat, currentCard, tempSet);
      if (candidates.isEmpty) break;

      int bestR = candidates.first.$1;
      int bestC = candidates.first.$2;
      int bestVal = -999999;

      for (final (r, c) in candidates) {
        final t = terrain[r][c];
        var val = 10;
        if (t == 4 && !towers[seat][r][c]) {
          val += 50; // High priority for Discovery Towers 🗼
        } else if (t == 5 && !ruins[seat][r][c]) {
          val += 40; // High priority for Ruins 🏚️
        } else if (t >= 1 && t <= 3) {
          final reg = contiguousRegion(r, c);
          final rem = reg
              .where((p) =>
                  p != (capR, capC) &&
                  !explored[seat][p.$1][p.$2] &&
                  !tempSet.contains(p))
              .length;
          if (rem == 1) {
            val += 45; // Completes a contiguous region -> spawns a Permanent Village 🏠!
          } else if (rem == 2) {
            val += 25;
          }
        }
        if (val > bestVal) {
          bestVal = val;
          bestR = r;
          bestC = c;
        }
      }

      chosen.add([bestR, bestC]);
      tempSet.add((bestR, bestC));
    }

    return {
      'type': 'explore',
      'cells': chosen,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'era': era,
      'maxEras': maxEras,
      'cardStep': cardStep,
      'cardsPerEra': cardsPerEra,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'currentCard': currentCard.toJson(),
      'terrain': terrain,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'villageVp': villageVp[s],
            'towerCoins': towerCoins[s],
            'treasureCoins': treasureCoins[s],
            'villageCount': countVillages(s),
            'towerCount': countTowers(s),
            'explored': explored[s],
            'villages': villages[s],
            'towers': towers[s],
            'ruins': ruins[s],
          },
      ],
    };
  }
}
