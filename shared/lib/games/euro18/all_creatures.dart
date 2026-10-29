import 'dart:math';

import '../../src/engine.dart';

const List<String> creaturesResNames = ['木材', '石材', '芦苇'];
const List<String> creaturesResEmojis = ['🌲', '🪨', '🧱'];

const List<String> creaturesAnimalNames = ['绵羊', '野猪', '奶牛', '骏马'];
const List<String> creaturesAnimalEmojis = ['🐑', '🐗', '🐄', '🐎'];

class AllCreaturesSpecialBuilding {
  final int id;
  final String name;
  final String emoji;
  final List<int> costRes; // [wood, stone, reed]
  final int baseVp;
  final int capacity; // Animal holding capacity on this building tile
  final String bonusKind; // 'none', 'sheep', 'boar', 'cattle', 'horse', 'res', 'pasture'
  final String bonusDesc;

  const AllCreaturesSpecialBuilding({
    required this.id,
    required this.name,
    required this.emoji,
    required this.costRes,
    required this.baseVp,
    required this.capacity,
    this.bonusKind = 'none',
    required this.bonusDesc,
  });

  String get costDesc {
    final parts = <String>[];
    for (var i = 0; i < 3; i++) {
      if (costRes[i] > 0) parts.add('${costRes[i]}${creaturesResEmojis[i]}');
    }
    return parts.join('+');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'costRes': costRes,
        'costDesc': costDesc,
        'baseVp': baseVp,
        'capacity': capacity,
        'bonusKind': bonusKind,
        'bonusDesc': bonusDesc,
      };
}

class AllCreaturesCell {
  final String kind; // 'cottage', 'empty', 'pasture', 'building'
  final int stalls; // 0 or 1 (doubles pasture capacity)
  final bool hasTrough; // +2 capacity
  final AllCreaturesSpecialBuilding? building;

  const AllCreaturesCell({
    this.kind = 'empty',
    this.stalls = 0,
    this.hasTrough = false,
    this.building,
  });

  int get capacity {
    final troughBonus = hasTrough ? 2 : 0;
    switch (kind) {
      case 'cottage':
        return 1 + troughBonus;
      case 'pasture':
        final base = 2 * (stalls > 0 ? (1 << stalls) : 1);
        return base + troughBonus;
      case 'building':
        return (building?.capacity ?? 0) + troughBonus;
      case 'empty':
      default:
        return troughBonus;
    }
  }

  AllCreaturesCell copyWith({
    String? kind,
    int? stalls,
    bool? hasTrough,
    AllCreaturesSpecialBuilding? building,
  }) =>
      AllCreaturesCell(
        kind: kind ?? this.kind,
        stalls: stalls ?? this.stalls,
        hasTrough: hasTrough ?? this.hasTrough,
        building: building ?? this.building,
      );

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'stalls': stalls,
        'hasTrough': hasTrough,
        'capacity': capacity,
        'building': building?.toJson(),
      };
}

class AllCreaturesActionSpace {
  final String id;
  final String name;
  final String emoji;
  final String desc;
  final bool accumulates;
  int accWood;
  int accStone;
  int accReed;
  int accAnimalType; // -1 if none, else 0..3
  int accAnimalCount;
  int occupiedBy; // -1 if free, else seat

  AllCreaturesActionSpace({
    required this.id,
    required this.name,
    required this.emoji,
    required this.desc,
    this.accumulates = false,
    this.accWood = 0,
    this.accStone = 0,
    this.accReed = 0,
    this.accAnimalType = -1,
    this.accAnimalCount = 0,
    this.occupiedBy = -1,
  });

  String get currentRewardDesc {
    final parts = <String>[];
    if (accWood > 0) parts.add('+$accWood🌲');
    if (accStone > 0) parts.add('+$accStone🪨');
    if (accReed > 0) parts.add('+$accReed🧱');
    if (accAnimalType >= 0 && accAnimalCount > 0) {
      parts.add('+$accAnimalCount${creaturesAnimalEmojis[accAnimalType]}');
    }
    return parts.isEmpty ? desc : '${parts.join(" ")} ($desc)';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'desc': desc,
        'rewardDesc': currentRewardDesc,
        'accumulates': accumulates,
        'accWood': accWood,
        'accStone': accStone,
        'accReed': accReed,
        'accAnimalType': accAnimalType,
        'accAnimalCount': accAnimalCount,
        'occupiedBy': occupiedBy,
      };
}

class AllCreaturesGame extends GameEngine {
  static const int rows = 3;
  static const int cols = 4;
  static const int farmersPerRound = 3;

  late final int maxRounds;
  late List<AllCreaturesActionSpace> actionSpaces;
  late List<AllCreaturesSpecialBuilding> specialMarket;

  /// Personal 3x4 farmstead grid: `farm[seat][r][c]`.
  late List<List<List<AllCreaturesCell>>> farm;

  /// Resources per player: `[wood 🌲, stone 🪨, reed 🧱]`.
  late List<List<int>> res;

  /// Animals per player: `[sheep 🐑, boar 🐗, cattle 🐄, horse 🐎]`.
  late List<List<int>> animals;

  late List<int> farmersLeft;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '农家乐：牧场物语开启，请派遣农夫建设牧场与繁育牲畜';

  AllCreaturesGame(super.setup) : maxRounds = setup.opt<int>('rounds', 6);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  /// Category threshold bonus/penalty per animal type:
  /// `<=3: -3, 4..5: 0, 6..7: +1, 8+: +2 + (n - 8)`
  static int animalCategoryBonus(int count) {
    if (count <= 3) return -3;
    if (count <= 5) return 0;
    if (count <= 7) return 1;
    return 2 + (count - 8);
  }

  List<AllCreaturesSpecialBuilding> _buildSpecialMarket() {
    return [
      const AllCreaturesSpecialBuilding(
        id: 1,
        name: '半木结构农舍',
        emoji: '🏡',
        costRes: [2, 2, 1],
        baseVp: 5,
        capacity: 2,
        bonusKind: 'none',
        bonusDesc: '固定5分 · 可容纳2只动物',
      ),
      const AllCreaturesSpecialBuilding(
        id: 2,
        name: '丰收储藏谷仓',
        emoji: '🏚️',
        costRes: [2, 1, 1],
        baseVp: 3,
        capacity: 1,
        bonusKind: 'res',
        bonusDesc: '3分+容量1 · 每剩2个建材额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 3,
        name: '牧羊人木屋',
        emoji: '🛖',
        costRes: [2, 1, 0],
        baseVp: 2,
        capacity: 2,
        bonusKind: 'sheep',
        bonusDesc: '2分+容量2 · 每有2只🐑绵羊额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 4,
        name: '皇家骑术马厩',
        emoji: '🏇',
        costRes: [1, 2, 1],
        baseVp: 3,
        capacity: 2,
        bonusKind: 'horse',
        bonusDesc: '3分+容量2 · 每有1匹🐎骏马额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 5,
        name: '橡木野猪圈',
        emoji: '🐗',
        costRes: [2, 0, 1],
        baseVp: 2,
        capacity: 2,
        bonusKind: 'boar',
        bonusDesc: '2分+容量2 · 每有2头🐗野猪额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 6,
        name: '石砌挤奶庄园',
        emoji: '🏰',
        costRes: [1, 3, 1],
        baseVp: 4,
        capacity: 2,
        bonusKind: 'cattle',
        bonusDesc: '4分+容量2 · 每有2头🐄奶牛额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 7,
        name: '草原大风车',
        emoji: '🌬️',
        costRes: [2, 2, 0],
        baseVp: 3,
        capacity: 1,
        bonusKind: 'pasture',
        bonusDesc: '3分+容量1 · 每个围栏牧场额外+1分',
      ),
      const AllCreaturesSpecialBuilding(
        id: 8,
        name: '山谷畜牧会馆',
        emoji: '🏛️',
        costRes: [3, 2, 1],
        baseVp: 6,
        capacity: 3,
        bonusKind: 'none',
        bonusDesc: '6分 · 可容纳3只动物',
      ),
    ];
  }

  List<AllCreaturesActionSpace> _initActionSpaces() {
    return [
      AllCreaturesActionSpace(
        id: 'wood_forest',
        name: '森林伐木场',
        emoji: '🌲',
        desc: '每轮累积+3🌲木材',
        accumulates: true,
      ),
      AllCreaturesActionSpace(
        id: 'wood_grove',
        name: '林间柴堆',
        emoji: '🪵',
        desc: '每轮累积+2🌲木材',
        accumulates: true,
      ),
      AllCreaturesActionSpace(
        id: 'stone_quarry',
        name: '采石矿场',
        emoji: '🪨',
        desc: '每轮累积+2🪨石材',
        accumulates: true,
      ),
      AllCreaturesActionSpace(
        id: 'reed_pond',
        name: '河畔芦苇滩',
        emoji: '🧱',
        desc: '每轮累积+1🧱芦苇+1🌲木材',
        accumulates: true,
      ),
      AllCreaturesActionSpace(
        id: 'sheep_fence',
        name: '牧羊围栏处',
        emoji: '🐑',
        desc: '累积+1🐑绵羊，并可耗1🌲圈建牧场',
        accumulates: true,
        accAnimalType: 0,
      ),
      AllCreaturesActionSpace(
        id: 'boar_woods',
        name: '野猪林地',
        emoji: '🐗',
        desc: '每轮累积+1🐗野猪',
        accumulates: true,
        accAnimalType: 1,
      ),
      AllCreaturesActionSpace(
        id: 'cattle_meadow',
        name: '奶牛草场',
        emoji: '🐄',
        desc: '每轮累积+1🐄奶牛',
        accumulates: true,
        accAnimalType: 2,
      ),
      AllCreaturesActionSpace(
        id: 'horse_ranch',
        name: '良驹马场',
        emoji: '🐎',
        desc: '每轮累积+1🐎骏马',
        accumulates: true,
        accAnimalType: 3,
      ),
      AllCreaturesActionSpace(
        id: 'build_pasture',
        name: '扩建围栏牧场',
        emoji: '🌿',
        desc: '耗1🌲圈建牧场(容量+2)并获+1🐑',
      ),
      AllCreaturesActionSpace(
        id: 'build_stall',
        name: '建造畜棚',
        emoji: '🏠',
        desc: '耗2🌲或2🪨在牧场建畜棚(容量翻倍+2⭐)',
      ),
      AllCreaturesActionSpace(
        id: 'build_trough',
        name: '建造饮水槽',
        emoji: '🚰',
        desc: '获+1🧱并在农场建饮水槽(容量+2,+1⭐)',
      ),
      AllCreaturesActionSpace(
        id: 'build_special',
        name: '建造特殊建筑',
        emoji: '🏛️',
        desc: '支付建材在空地建造1座特殊建筑',
      ),
      AllCreaturesActionSpace(
        id: 'animal_market',
        name: '牲畜集市',
        emoji: '🎪',
        desc: '获+1🧱芦苇与自选1只良种动物',
      ),
      AllCreaturesActionSpace(
        id: 'farm_supply',
        name: '综合农牧补给',
        emoji: '🌾',
        desc: '获+1🌲+1🪨+1🧱并引1只稀缺动物',
      ),
    ];
  }

  void _replenishActionSpaces() {
    for (final sp in actionSpaces) {
      sp.occupiedBy = -1;
      switch (sp.id) {
        case 'wood_forest':
          sp.accWood += 3;
        case 'wood_grove':
          sp.accWood += 2;
        case 'stone_quarry':
          sp.accStone += 2;
        case 'reed_pond':
          sp.accReed += 1;
          sp.accWood += 1;
        case 'sheep_fence':
        case 'boar_woods':
        case 'cattle_meadow':
        case 'horse_ranch':
          sp.accAnimalCount += 1;
      }
    }
  }

  @override
  void start() {
    actionSpaces = _initActionSpaces();
    specialMarket = _buildSpecialMarket();

    farm = List.generate(
      players,
      (_) => List.generate(
        rows,
        (r) => List.generate(
          cols,
          (c) {
            if (r == 0 && c == 0) {
              return const AllCreaturesCell(kind: 'cottage');
            }
            if (r == 0 && c == 1) {
              return const AllCreaturesCell(kind: 'pasture');
            }
            return const AllCreaturesCell(kind: 'empty');
          },
        ),
      ),
    );

    res = List.generate(players, (_) => [2, 1, 1]);
    animals = List.generate(players, (_) => [1, 0, 0, 0]);
    farmersLeft = List.filled(players, farmersPerRound);
    score = List.filled(players, 0);

    _replenishActionSpaces();
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，累积行动格已补充木材、石材、芦苇与四类牲畜';
  }

  int totalCapacity(int seat) {
    var cap = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        cap += farm[seat][r][c].capacity;
      }
    }
    return cap;
  }

  int totalAnimals(int seat) =>
      animals[seat][0] + animals[seat][1] + animals[seat][2] + animals[seat][3];

  /// Caps `seat`'s total animals so `totalAnimals(seat) <= totalCapacity(seat)`.
  void capAnimalsToCapacity(int seat) {
    final cap = totalCapacity(seat);
    while (totalAnimals(seat) > cap) {
      // Remove 1 animal from the type with the highest count (or lowest index)
      var removeIdx = 0;
      for (var t = 0; t < 4; t++) {
        if (animals[seat][t] > 0) {
          removeIdx = t;
          break;
        }
      }
      animals[seat][removeIdx]--;
    }
  }

  /// End-of-round Breeding Phase:
  /// 1. First cap animals to `totalCapacity(seat)`.
  /// 2. Then for each animal type `0..3` (`sheep, boar, cattle, horse`), if the player
  ///    has `>= 2` of that animal AND free capacity (`totalAnimals(seat) < totalCapacity(seat)`),
  ///    breed `+1` newborn animal of that type!
  List<int> runBreedingForSeat(int seat) {
    capAnimalsToCapacity(seat);
    final newborn = [0, 0, 0, 0];
    for (var t = 0; t < 4; t++) {
      if (animals[seat][t] >= 2 && totalAnimals(seat) < totalCapacity(seat)) {
        animals[seat][t] += 1;
        newborn[t] = 1;
      }
    }
    score[seat] = calcScore(seat);
    return newborn;
  }

  void runBreedingPhase() {
    for (var s = 0; s < players; s++) {
      runBreedingForSeat(s);
    }
  }

  (int, int)? _findCellForPasture(int seat, int prefR, int prefC) {
    if (prefR >= 0 &&
        prefR < rows &&
        prefC >= 0 &&
        prefC < cols &&
        farm[seat][prefR][prefC].kind == 'empty') {
      return (prefR, prefC);
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (farm[seat][r][c].kind == 'empty') return (r, c);
      }
    }
    return null;
  }

  (int, int)? _findCellForStall(int seat, int prefR, int prefC) {
    if (prefR >= 0 &&
        prefR < rows &&
        prefC >= 0 &&
        prefC < cols &&
        farm[seat][prefR][prefC].kind == 'pasture' &&
        farm[seat][prefR][prefC].stalls == 0) {
      return (prefR, prefC);
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = farm[seat][r][c];
        if (cell.kind == 'pasture' && cell.stalls == 0) return (r, c);
      }
    }
    return null;
  }

  (int, int)? _findCellForTrough(int seat, int prefR, int prefC) {
    if (prefR >= 0 &&
        prefR < rows &&
        prefC >= 0 &&
        prefC < cols &&
        !farm[seat][prefR][prefC].hasTrough) {
      return (prefR, prefC);
    }
    // Prefer putting trough on a pasture first, then any cell without a trough
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = farm[seat][r][c];
        if (cell.kind == 'pasture' && !cell.hasTrough) return (r, c);
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!farm[seat][r][c].hasTrough) return (r, c);
      }
    }
    return null;
  }

  bool canAffordSpecial(int seat, AllCreaturesSpecialBuilding b) {
    for (var i = 0; i < 3; i++) {
      if (res[seat][i] < b.costRes[i]) return false;
    }
    return true;
  }

  Map<String, int> calcScoreBreakdown(int seat) {
    final a = animals[seat];
    final animalBaseVp = a[0] + a[1] + a[2] + a[3];
    var animalBonusVp = 0;
    for (var t = 0; t < 4; t++) {
      animalBonusVp += animalCategoryBonus(a[t]);
    }

    var pastureCount = 0;
    var stallCount = 0;
    var troughCount = 0;
    var buildingVp = 0;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final cell = farm[seat][r][c];
        if (cell.kind == 'pasture') pastureCount++;
        stallCount += cell.stalls;
        if (cell.hasTrough) troughCount++;
      }
    }

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final b = farm[seat][r][c].building;
        if (b == null) continue;
        buildingVp += b.baseVp;
        switch (b.bonusKind) {
          case 'sheep':
            buildingVp += a[0] ~/ 2;
          case 'boar':
            buildingVp += a[1] ~/ 2;
          case 'cattle':
            buildingVp += a[2] ~/ 2;
          case 'horse':
            buildingVp += a[3];
          case 'res':
            buildingVp += (res[seat][0] + res[seat][1] + res[seat][2]) ~/ 2;
          case 'pasture':
            buildingVp += pastureCount;
        }
      }
    }

    final infraVp = pastureCount * 1 + stallCount * 2 + troughCount * 1;
    final total = animalBaseVp + animalBonusVp + infraVp + buildingVp;
    return {
      'animalBaseVp': animalBaseVp,
      'animalBonusVp': animalBonusVp,
      'infraVp': infraVp,
      'buildingVp': buildingVp,
      'total': total,
    };
  }

  int calcScore(int seat) => calcScoreBreakdown(seat)['total']!;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    if (farmersLeft[seat] <= 0) throw GameError('本轮农夫已全部派遣完毕');

    final type = asStr(action['type']);
    if (type != 'take_action') {
      throw GameError('未知操作: $type');
    }

    final actionId = asStr(action['actionId']);
    final spIdx = actionSpaces.indexWhere((s) => s.id == actionId);
    if (spIdx < 0) {
      throw GameError('无效的行动格: $actionId');
    }
    final sp = actionSpaces[spIdx];
    if (sp.occupiedBy != -1) {
      throw GameError('行动格「${sp.name}」已被其他农夫占用');
    }

    final prefR = asInt(action['r'], -1);
    final prefC = asInt(action['c'], -1);
    var effectMsg = '';

    switch (sp.id) {
      case 'wood_forest':
      case 'wood_grove':
      case 'stone_quarry':
      case 'reed_pond':
        res[seat][0] += sp.accWood;
        res[seat][1] += sp.accStone;
        res[seat][2] += sp.accReed;
        effectMsg = '采集获得 ${sp.currentRewardDesc}';
        sp.accWood = 0;
        sp.accStone = 0;
        sp.accReed = 0;

      case 'sheep_fence':
        final gainedSheep = sp.accAnimalCount;
        sp.accAnimalCount = 0;
        // Optionally enclose a pasture if player has >= 1 wood and an empty cell
        final target = _findCellForPasture(seat, prefR, prefC);
        if (res[seat][0] >= 1 && target != null) {
          res[seat][0] -= 1;
          final (r, c) = target;
          farm[seat][r][c] = farm[seat][r][c].copyWith(kind: 'pasture');
          effectMsg = '获得 +$gainedSheep🐑 并在($r,$c)圈建围栏牧场';
        } else {
          effectMsg = '获得 +$gainedSheep🐑绵羊';
        }
        animals[seat][0] += gainedSheep;
        capAnimalsToCapacity(seat);

      case 'boar_woods':
      case 'cattle_meadow':
      case 'horse_ranch':
        final aType = sp.accAnimalType;
        final cnt = sp.accAnimalCount;
        sp.accAnimalCount = 0;
        animals[seat][aType] += cnt;
        capAnimalsToCapacity(seat);
        effectMsg = '获得 +$cnt${creaturesAnimalEmojis[aType]}${creaturesAnimalNames[aType]}';

      case 'build_pasture':
        final target = _findCellForPasture(seat, prefR, prefC);
        if (target == null) {
          throw GameError('农场已无空闲草地可圈建围栏牧场');
        }
        if (res[seat][0] < 1) {
          throw GameError('圈建围栏牧场需要至少 1🌲木材');
        }
        res[seat][0] -= 1;
        final (r, c) = target;
        farm[seat][r][c] = farm[seat][r][c].copyWith(kind: 'pasture');
        animals[seat][0] += 1;
        capAnimalsToCapacity(seat);
        effectMsg = '在($r,$c)圈建围栏牧场(容量+2)并获 +1🐑绵羊';

      case 'build_stall':
        final target = _findCellForStall(seat, prefR, prefC);
        if (target == null) {
          throw GameError('没有可加建畜棚的牧场（需先有未建畜棚的围栏牧场）');
        }
        if (res[seat][0] < 2 && res[seat][1] < 2) {
          throw GameError('建造畜棚需要 2🌲木材 或 2🪨石材');
        }
        if (res[seat][0] >= 2) {
          res[seat][0] -= 2;
        } else {
          res[seat][1] -= 2;
        }
        final (r, c) = target;
        farm[seat][r][c] = farm[seat][r][c].copyWith(stalls: 1);
        effectMsg = '在($r,$c)牧场建成🏠畜棚(容量翻倍至${farm[seat][r][c].capacity}，+2⭐)';

      case 'build_trough':
        res[seat][2] += 1; // Gain +1 reed first
        final target = _findCellForTrough(seat, prefR, prefC);
        if (target != null && res[seat][2] >= 1) {
          res[seat][2] -= 1;
          final (r, c) = target;
          farm[seat][r][c] = farm[seat][r][c].copyWith(hasTrough: true);
          effectMsg = '在($r,$c)安装🚰饮水槽(容量+2，+1⭐)';
        } else {
          effectMsg = '获得 +1🧱芦苇';
        }

      case 'build_special':
        if (specialMarket.isEmpty) {
          throw GameError('特殊建筑已全部售罄');
        }
        final target = _findCellForPasture(seat, prefR, prefC);
        if (target == null) {
          throw GameError('农场已无空闲地块可建造特殊建筑');
        }
        var bIdx = asInt(action['buildingIdx'], -1);
        if (bIdx < 0 || bIdx >= specialMarket.length) {
          bIdx = specialMarket.indexWhere((b) => canAffordSpecial(seat, b));
        }
        if (bIdx < 0 || !canAffordSpecial(seat, specialMarket[bIdx])) {
          throw GameError('建材不足，无法建造所选特殊建筑');
        }
        final b = specialMarket.removeAt(bIdx);
        for (var i = 0; i < 3; i++) {
          res[seat][i] -= b.costRes[i];
        }
        final (r, c) = target;
        farm[seat][r][c] = AllCreaturesCell(
          kind: 'building',
          hasTrough: farm[seat][r][c].hasTrough,
          building: b,
        );
        effectMsg = '在($r,$c)建成特殊建筑 ${b.emoji}${b.name} (+${b.baseVp}⭐, 容量+${b.capacity})';

      case 'animal_market':
        res[seat][2] += 1;
        var aType = asInt(action['animalType'], -1);
        if (aType < 0 || aType > 3) {
          // Pick animal type where player has 1 (to reach breeding pair 2!) or lowest count
          aType = 0;
          for (var t = 0; t < 4; t++) {
            if (animals[seat][t] == 1) {
              aType = t;
              break;
            }
            if (animals[seat][t] < animals[seat][aType]) {
              aType = t;
            }
          }
        }
        animals[seat][aType] += 1;
        capAnimalsToCapacity(seat);
        effectMsg = '获得 +1🧱芦苇 与 +1${creaturesAnimalEmojis[aType]}${creaturesAnimalNames[aType]}';

      case 'farm_supply':
        res[seat][0] += 1;
        res[seat][1] += 1;
        res[seat][2] += 1;
        var aType = 0;
        for (var t = 1; t < 4; t++) {
          if (animals[seat][t] < animals[seat][aType]) aType = t;
        }
        animals[seat][aType] += 1;
        capAnimalsToCapacity(seat);
        effectMsg =
            '获得 +1🌲+1🪨+1🧱 与 +1${creaturesAnimalEmojis[aType]}${creaturesAnimalNames[aType]}';
    }

    sp.occupiedBy = seat;
    farmersLeft[seat]--;
    score[seat] = calcScore(seat);
    lastAction = '${name(seat)} 派遣农夫至「${sp.emoji}${sp.name}」：$effectMsg';
    host.log(lastAction);
    _advanceTurn();
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (farmersLeft[nextSeat] > 0) {
        turn = nextSeat;
        return;
      }
    }

    // All players placed all 3 Farmers -> Run End-of-Round Breeding Phase!
    runBreedingPhase();

    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '农家乐：牧场物语 $maxRounds 轮繁殖与建设结束！总分最高者获胜';
      host.log(lastAction);
      return;
    }

    round++;
    for (var s = 0; s < players; s++) {
      farmersLeft[s] = farmersPerRound;
    }
    _replenishActionSpaces();
    turn = (round - 1) % players;
    lastAction = '第 ${round - 1} 轮繁殖阶段完成（成对牲畜各繁育+1幼崽），第 $round 轮开始！';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final freeCap = totalCapacity(seat) - totalAnimals(seat);

    // 1. If we can build a Special Building, high priority!
    final bSpace = actionSpaces.firstWhere((s) => s.id == 'build_special');
    if (bSpace.occupiedBy == -1 && _findCellForPasture(seat, -1, -1) != null) {
      for (var i = 0; i < specialMarket.length; i++) {
        if (canAffordSpecial(seat, specialMarket[i])) {
          final pos = _findCellForPasture(seat, -1, -1)!;
          return {
            'type': 'take_action',
            'actionId': 'build_special',
            'buildingIdx': i,
            'r': pos.$1,
            'c': pos.$2,
          };
        }
      }
    }

    // 2. If capacity is tight (freeCap <= 2), expand capacity via Pasture, Stall, or Trough!
    if (freeCap <= 2) {
      final pSpace = actionSpaces.firstWhere((s) => s.id == 'build_pasture');
      final pPos = _findCellForPasture(seat, -1, -1);
      if (pSpace.occupiedBy == -1 && res[seat][0] >= 1 && pPos != null) {
        return {
          'type': 'take_action',
          'actionId': 'build_pasture',
          'r': pPos.$1,
          'c': pPos.$2,
        };
      }
      final sSpace = actionSpaces.firstWhere((s) => s.id == 'build_stall');
      final sPos = _findCellForStall(seat, -1, -1);
      if (sSpace.occupiedBy == -1 &&
          (res[seat][0] >= 2 || res[seat][1] >= 2) &&
          sPos != null) {
        return {
          'type': 'take_action',
          'actionId': 'build_stall',
          'r': sPos.$1,
          'c': sPos.$2,
        };
      }
      final tSpace = actionSpaces.firstWhere((s) => s.id == 'build_trough');
      final tPos = _findCellForTrough(seat, -1, -1);
      if (tSpace.occupiedBy == -1 && tPos != null) {
        return {
          'type': 'take_action',
          'actionId': 'build_trough',
          'r': tPos.$1,
          'c': tPos.$2,
        };
      }
    }

    // 3. Evaluate all available action spaces
    String bestId = '';
    int bestVal = -999999;
    for (final sp in actionSpaces) {
      if (sp.occupiedBy != -1) continue;
      var val = 0;
      switch (sp.id) {
        case 'wood_forest':
        case 'wood_grove':
        case 'stone_quarry':
        case 'reed_pond':
          val = sp.accWood * 3 + sp.accStone * 4 + sp.accReed * 4;
        case 'sheep_fence':
          val = min(freeCap + 2, sp.accAnimalCount) * 6 +
              (res[seat][0] >= 1 ? 8 : 0);
        case 'boar_woods':
        case 'cattle_meadow':
        case 'horse_ranch':
          final t = sp.accAnimalType;
          final cur = animals[seat][t];
          final pairBonus = (cur < 2 && cur + sp.accAnimalCount >= 2) ? 10 : 0;
          val = min(freeCap, sp.accAnimalCount) * 6 + pairBonus;
        case 'build_pasture':
          if (res[seat][0] < 1 || _findCellForPasture(seat, -1, -1) == null) {
            continue;
          }
          val = 12;
        case 'build_stall':
          if ((res[seat][0] < 2 && res[seat][1] < 2) ||
              _findCellForStall(seat, -1, -1) == null) {
            continue;
          }
          val = 14;
        case 'build_trough':
          val = 11;
        case 'build_special':
          continue; // Checked above
        case 'animal_market':
          val = (freeCap > 0 ? 11 : 4);
        case 'farm_supply':
          val = 13;
      }
      if (val > bestVal) {
        bestVal = val;
        bestId = sp.id;
      }
    }

    return {
      'type': 'take_action',
      'actionId': bestId,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'actionSpaces': [for (final s in actionSpaces) s.toJson()],
      'specialMarket': [for (final b in specialMarket) b.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'breakdown': calcScoreBreakdown(s),
            'res': List<int>.of(res[s]),
            'animals': List<int>.of(animals[s]),
            'totalAnimals': totalAnimals(s),
            'totalCapacity': totalCapacity(s),
            'farmersLeft': farmersLeft[s],
            'farm': [
              for (var r = 0; r < rows; r++)
                [
                  for (var c = 0; c < cols; c++) farm[s][r][c].toJson(),
                ],
            ],
          },
      ],
    };
  }
}
