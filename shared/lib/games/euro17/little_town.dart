import '../../src/engine.dart';

const List<String> littleTownTerrainNames = ['草地', '木材', '石头', '鱼塘', '麦田'];
const List<String> littleTownTerrainEmojis = ['🌿', '🌲', '🪨', '🐟', '🌾'];

const List<String> littleTownResNames = ['木材', '石头', '鲜鱼', '小麦'];
const List<String> littleTownResEmojis = ['🌲', '🪨', '🐟', '🌾'];

class LittleTownBuildingCard {
  final int id;
  final String name;
  final String emoji;
  final List<int> costRes; // [wood, stone] (length 2 or 4)
  final int costCoins;
  final int buildVp;
  final List<int> inRes; // [wood, stone, fish, wheat] needed to activate
  final int inCoins;
  final List<int> outRes; // [wood, stone, fish, wheat] produced
  final int outCoins;
  final int outVp;

  const LittleTownBuildingCard({
    required this.id,
    required this.name,
    required this.emoji,
    this.costRes = const [0, 0, 0, 0],
    this.costCoins = 0,
    required this.buildVp,
    this.inRes = const [0, 0, 0, 0],
    this.inCoins = 0,
    this.outRes = const [0, 0, 0, 0],
    this.outCoins = 0,
    this.outVp = 0,
  });

  String get costDesc {
    final parts = <String>[];
    for (var i = 0; i < 4 && i < costRes.length; i++) {
      if (costRes[i] > 0) parts.add('${costRes[i]}${littleTownResEmojis[i]}');
    }
    if (costCoins > 0) parts.add('$costCoins🪙');
    return parts.isEmpty ? '免费' : parts.join('+');
  }

  String get effectDesc {
    final inParts = <String>[];
    for (var i = 0; i < 4 && i < inRes.length; i++) {
      if (inRes[i] > 0) inParts.add('${inRes[i]}${littleTownResEmojis[i]}');
    }
    if (inCoins > 0) inParts.add('$inCoins🪙');

    final outParts = <String>[];
    for (var i = 0; i < 4 && i < outRes.length; i++) {
      if (outRes[i] > 0) outParts.add('+${outRes[i]}${littleTownResEmojis[i]}');
    }
    if (outCoins > 0) outParts.add('+$outCoins🪙');
    if (outVp > 0) outParts.add('+$outVp⭐');

    final outStr = outParts.join(' ');
    return inParts.isEmpty ? outStr : '${inParts.join("+")}➔$outStr';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'costRes': costRes,
        'costCoins': costCoins,
        'costDesc': costDesc,
        'buildVp': buildVp,
        'inRes': inRes,
        'inCoins': inCoins,
        'outRes': outRes,
        'outCoins': outCoins,
        'outVp': outVp,
        'effectDesc': effectDesc,
      };
}

class LittleTownPlacedBuilding {
  final int owner;
  final LittleTownBuildingCard card;

  const LittleTownPlacedBuilding({
    required this.owner,
    required this.card,
  });

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'cardId': card.id,
        'card': card.toJson(),
      };
}

class LittleTownGame extends GameEngine {
  static const int rows = 6;
  static const int cols = 8;

  // All 8 surrounding squares: max(|dr|, |dc|) == 1
  static const List<(int, int)> dirs8 = [
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
  ];

  // Default 6x8 Valley Map:
  // 0: 🌿 草地, 1: 🌲 木材, 2: 🪨 石头, 3: 🐟 鱼塘, 4: 🌾 麦田
  static const List<List<int>> defaultMap = [
    [1, 0, 0, 3, 0, 0, 2, 0],
    [0, 0, 4, 0, 0, 1, 0, 0],
    [0, 2, 0, 0, 0, 0, 3, 0],
    [0, 3, 0, 0, 0, 0, 1, 0],
    [0, 0, 1, 0, 0, 4, 0, 0],
    [0, 2, 0, 0, 3, 0, 0, 2],
  ];

  late final int maxRounds;
  late final int workersPerPlayer;

  late List<List<int>> map;
  late List<List<LittleTownPlacedBuilding?>> buildings;
  late List<List<int>> workersOnMap; // -1 if empty, else seat 0..players-1
  late List<LittleTownBuildingCard> market;

  /// Resources per player: `[wood 🌲, stone 🪨, fish 🐟, wheat 🌾]`
  late List<List<int>> res;
  late List<int> coins;
  late List<int> vp;
  late List<int> workersLeft;
  late List<int> buildingsBuilt;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '小小建筑师山谷开拓开启';

  LittleTownGame(super.setup)
      : maxRounds = setup.opt<int>('rounds', 4),
        workersPerPlayer = setup.players == 2 ? 4 : 3;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<LittleTownBuildingCard> _buildMarket() {
    const allCards = [
      LittleTownBuildingCard(
        id: 1,
        name: '黄金麦田',
        emoji: '🌾',
        costRes: [1, 0, 0, 0],
        buildVp: 2,
        outRes: [0, 0, 0, 1],
      ),
      LittleTownBuildingCard(
        id: 2,
        name: '伐木工坊',
        emoji: '🪓',
        costRes: [1, 1, 0, 0],
        buildVp: 3,
        outRes: [1, 0, 0, 0],
        outCoins: 1,
      ),
      LittleTownBuildingCard(
        id: 3,
        name: '采石矿场',
        emoji: '⛏️',
        costRes: [2, 0, 0, 0],
        buildVp: 3,
        outRes: [0, 1, 0, 0],
        outCoins: 1,
      ),
      LittleTownBuildingCard(
        id: 4,
        name: '河畔渔屋',
        emoji: '🎣',
        costRes: [1, 1, 0, 0],
        buildVp: 3,
        outRes: [0, 0, 2, 0],
      ),
      LittleTownBuildingCard(
        id: 5,
        name: '风车磨坊',
        emoji: '🥖',
        costRes: [2, 1, 0, 0],
        buildVp: 4,
        inRes: [0, 0, 0, 1],
        outVp: 2,
        outCoins: 2,
      ),
      LittleTownBuildingCard(
        id: 6,
        name: '鲜鱼酒馆',
        emoji: '🍺',
        costRes: [1, 2, 0, 0],
        buildVp: 4,
        inRes: [0, 0, 1, 0],
        outVp: 2,
        outCoins: 2,
      ),
      LittleTownBuildingCard(
        id: 7,
        name: '商会金库',
        emoji: '🏦',
        costRes: [1, 2, 0, 0],
        buildVp: 4,
        outCoins: 3,
      ),
      LittleTownBuildingCard(
        id: 8,
        name: '皇家钟楼',
        emoji: '🕰️',
        costRes: [2, 2, 0, 0],
        buildVp: 5,
        outVp: 2,
      ),
      LittleTownBuildingCard(
        id: 9,
        name: '木器作坊',
        emoji: '🪑',
        costRes: [2, 1, 0, 0],
        buildVp: 4,
        inRes: [1, 0, 0, 0],
        outVp: 3,
      ),
      LittleTownBuildingCard(
        id: 10,
        name: '石雕圣堂',
        emoji: '⛪',
        costRes: [1, 3, 0, 0],
        buildVp: 6,
        inRes: [0, 1, 0, 0],
        outVp: 3,
      ),
      LittleTownBuildingCard(
        id: 11,
        name: '丰收谷仓',
        emoji: '🏡',
        costRes: [2, 0, 0, 0],
        buildVp: 3,
        outRes: [0, 0, 1, 1],
      ),
      LittleTownBuildingCard(
        id: 12,
        name: '山谷集市',
        emoji: '🎪',
        costRes: [2, 2, 0, 0],
        buildVp: 5,
        inCoins: 1,
        outVp: 3,
      ),
    ];
    return shuffled(allCards, rng);
  }

  @override
  void start() {
    map = [
      for (final row in defaultMap) List<int>.of(row),
    ];
    buildings = List.generate(
      rows,
      (_) => List.filled(cols, null),
    );
    workersOnMap = List.generate(
      rows,
      (_) => List.filled(cols, -1),
    );
    market = _buildMarket();

    res = List.generate(players, (_) => [1, 1, 1, 1]);
    coins = List.filled(players, 3);
    vp = List.filled(players, 0);
    workersLeft = List.filled(players, workersPerPlayer);
    buildingsBuilt = List.filled(players, 0);
    score = List.filled(players, 0);

    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，请派遣工匠八邻采集/激活建筑，或消耗资源建造新建筑';
  }

  int calcScore(int seat) => vp[seat] + (coins[seat] ~/ 3);

  bool isEmptyGrass(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    return map[r][c] == 0 && buildings[r][c] == null && workersOnMap[r][c] == -1;
  }

  bool canAffordBuilding(int seat, LittleTownBuildingCard card) {
    for (var i = 0; i < 4 && i < card.costRes.length; i++) {
      if (res[seat][i] < card.costRes[i]) return false;
    }
    return coins[seat] >= card.costCoins;
  }

  bool _canAffordActivation(int seat, LittleTownPlacedBuilding b) {
    final fee = b.owner == seat ? 0 : 1;
    if (coins[seat] < fee + b.card.inCoins) return false;
    for (var i = 0; i < 4 && i < b.card.inRes.length; i++) {
      if (res[seat][i] < b.card.inRes[i]) return false;
    }
    return true;
  }

  void _activateBuilding(int seat, LittleTownPlacedBuilding b) {
    if (!_canAffordActivation(seat, b)) return;
    if (b.owner != seat) {
      coins[seat] -= 1;
      coins[b.owner] += 1;
    }
    coins[seat] -= b.card.inCoins;
    for (var i = 0; i < 4 && i < b.card.inRes.length; i++) {
      res[seat][i] -= b.card.inRes[i];
    }
    for (var i = 0; i < 4 && i < b.card.outRes.length; i++) {
      res[seat][i] += b.card.outRes[i];
    }
    coins[seat] += b.card.outCoins;
    vp[seat] += b.card.outVp;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    if (workersLeft[seat] <= 0) throw GameError('本轮工匠已用完');

    final type = asStr(action['type']);
    switch (type) {
      case 'gather':
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (!isEmptyGrass(r, c)) {
          throw GameError('位置 ($r, $c) 不是空闲草地，无法派遣工匠采集');
        }

        workersLeft[seat]--;
        workersOnMap[r][c] = seat;

        final gainedRes = [0, 0, 0, 0];
        var activatedCount = 0;

        // First collect natural terrain resources from all 8 surrounding squares
        for (final (dr, dc) in dirs8) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final t = map[nr][nc];
          if (t >= 1 && t <= 4) {
            res[seat][t - 1]++;
            gainedRes[t - 1]++;
          }
        }

        // Next activate all adjacent Buildings in the 8 surrounding squares
        for (final (dr, dc) in dirs8) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final b = buildings[nr][nc];
          if (b != null && _canAffordActivation(seat, b)) {
            _activateBuilding(seat, b);
            activatedCount++;
          }
        }

        for (var s = 0; s < players; s++) {
          score[s] = calcScore(s);
        }

        final resParts = <String>[
          for (var i = 0; i < 4; i++)
            if (gainedRes[i] > 0) '+${gainedRes[i]}${littleTownResEmojis[i]}',
        ];
        final resStr = resParts.isEmpty ? '无自然产出' : resParts.join(' ');
        final bldStr =
            activatedCount > 0 ? '，并激活 $activatedCount 座相邻建筑' : '';
        lastAction =
            '${name(seat)} 派遣工匠至 ($r,$c) 八邻采集获得 [$resStr]$bldStr';
        host.log(lastAction);
        _advanceTurn();

      case 'build':
        final mIdx = asInt(action['marketIdx'], -1);
        if (mIdx < 0 || mIdx >= market.length) {
          throw GameError('无效的市场建筑编号: $mIdx');
        }
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (!isEmptyGrass(r, c)) {
          throw GameError('位置 ($r, $c) 不是空闲草地，无法在此建造建筑');
        }
        final card = market[mIdx];
        if (!canAffordBuilding(seat, card)) {
          throw GameError('建造 ${card.name} 所需的资源不足 (需 ${card.costDesc})');
        }

        workersLeft[seat]--;
        for (var i = 0; i < 4 && i < card.costRes.length; i++) {
          res[seat][i] -= card.costRes[i];
        }
        coins[seat] -= card.costCoins;
        vp[seat] += card.buildVp;
        buildingsBuilt[seat]++;

        market.removeAt(mIdx);
        buildings[r][c] = LittleTownPlacedBuilding(owner: seat, card: card);
        score[seat] = calcScore(seat);

        lastAction =
            '${name(seat)} 在 ($r,$c) 建造了 ${card.emoji}${card.name} (+${card.buildVp}⭐)';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  /// Feeds each player's workers at the end of a round (`1 🐟` or `1 🌾` per worker,
  /// or `-3` VP per unfed worker).
  void feedAllWorkers() {
    for (var s = 0; s < players; s++) {
      var needed = workersPerPlayer;
      final useFish = res[s][2] < needed ? res[s][2] : needed;
      res[s][2] -= useFish;
      needed -= useFish;

      final useWheat = res[s][3] < needed ? res[s][3] : needed;
      res[s][3] -= useWheat;
      needed -= useWheat;

      if (needed > 0) {
        vp[s] -= needed * 3;
      }
      score[s] = calcScore(s);
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (workersLeft[nextSeat] > 0) {
        turn = nextSeat;
        return;
      }
    }

    // End of Round: feed workers and clear workers from map
    feedAllWorkers();
    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '小小建筑师 4 轮建造全部结束！总分最高者获胜';
      host.log(lastAction);
      return;
    }

    round++;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        workersOnMap[r][c] = -1;
      }
    }
    for (var s = 0; s < players; s++) {
      workersLeft[s] = workersPerPlayer;
    }
    turn = (round - 1) % players;
    lastAction = '第 $round 轮开始，工匠已供养完毕并全部收回';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Check if we can build a high-value building on a good grass square
    int bestMarketIdx = -1;
    int bestBuildVp = -1;
    for (var i = 0; i < market.length; i++) {
      if (canAffordBuilding(seat, market[i]) && market[i].buildVp > bestBuildVp) {
        bestBuildVp = market[i].buildVp;
        bestMarketIdx = i;
      }
    }
    if (bestMarketIdx >= 0) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (isEmptyGrass(r, c)) {
            return {
              'type': 'build',
              'marketIdx': bestMarketIdx,
              'r': r,
              'c': c,
            };
          }
        }
      }
    }

    // 2. Otherwise pick the best empty grass square to gather from 8 surrounding squares
    int bestR = 0;
    int bestC = 0;
    int bestVal = -999999;

    final foodAvailable = res[seat][2] + res[seat][3];
    final needFood = foodAvailable < workersPerPlayer;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!isEmptyGrass(r, c)) continue;
        var val = 0;
        for (final (dr, dc) in dirs8) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final t = map[nr][nc];
          if (t == 1 || t == 2) {
            val += 4;
          } else if (t == 3 || t == 4) {
            val += needFood ? 7 : 3;
          }
          final b = buildings[nr][nc];
          if (b != null) {
            if (b.owner == seat) {
              val += 6 + b.card.outVp * 3;
            } else if (coins[seat] >= 1) {
              val += 3 + b.card.outVp * 2;
            }
          }
        }
        if (val > bestVal) {
          bestVal = val;
          bestR = r;
          bestC = c;
        }
      }
    }

    return {
      'type': 'gather',
      'r': bestR,
      'c': bestC,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'workersPerPlayer': workersPerPlayer,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'map': map,
      'buildings': [
        for (var r = 0; r < rows; r++)
          [
            for (var c = 0; c < cols; c++) buildings[r][c]?.toJson(),
          ],
      ],
      'workersOnMap': workersOnMap,
      'market': [for (final c in market) c.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'vp': vp[s],
            'coins': coins[s],
            'res': List<int>.of(res[s]),
            'workersLeft': workersLeft[s],
            'buildingsBuilt': buildingsBuilt[s],
          },
      ],
    };
  }
}
