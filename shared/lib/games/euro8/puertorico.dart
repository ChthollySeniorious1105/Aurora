import 'dart:math';

import '../../src/engine.dart';

const List<String> prGoodNames = ['玉米', '靛蓝', '蔗糖', '烟草', '咖啡'];
const List<int> prGoodPrices = [0, 1, 2, 3, 4];

const List<String> prRoleNames = [
  '开拓者',
  '市长',
  '建筑师',
  '工艺师',
  '商人',
  '船长',
];

const List<String> prRoleDescs = [
  '选取种植园；特权：可改拿采石场',
  '分配船上拓荒者；特权：额外+1拓荒者',
  '建造城市建筑；特权：建造费用-1金币',
  '生产货物；特权：额外多拿1桶自产货物',
  '向交易所出售1桶货物；特权：售价+1金币',
  '装船运货换取胜利分；特权：首次装船+1分',
];

class PrBuildingDef {
  final int id;
  final String name;
  final String desc;
  final int cost;
  final int vp;
  final int capacity;
  final int? goodType; // 1..4 for production buildings, null for violet buildings
  final bool isLarge;

  const PrBuildingDef({
    required this.id,
    required this.name,
    required this.desc,
    required this.cost,
    required this.vp,
    required this.capacity,
    this.goodType,
    this.isLarge = false,
  });

  int get spaces => isLarge ? 2 : 1;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'cost': cost,
        'vp': vp,
        'capacity': capacity,
        'goodType': goodType,
        'isLarge': isLarge,
        'spaces': spaces,
      };
}

const List<PrBuildingDef> prCatalog = [
  // Production buildings
  PrBuildingDef(id: 0, name: '小靛蓝坊', desc: '生产最多1桶靛蓝', cost: 1, vp: 1, capacity: 1, goodType: 1),
  PrBuildingDef(id: 1, name: '小糖厂', desc: '生产最多1桶蔗糖', cost: 2, vp: 1, capacity: 1, goodType: 2),
  PrBuildingDef(id: 2, name: '大靛蓝坊', desc: '生产最多3桶靛蓝', cost: 3, vp: 2, capacity: 3, goodType: 1),
  PrBuildingDef(id: 3, name: '大糖厂', desc: '生产最多3桶蔗糖', cost: 4, vp: 2, capacity: 3, goodType: 2),
  PrBuildingDef(id: 4, name: '烟草作坊', desc: '生产最多3桶烟草', cost: 5, vp: 3, capacity: 3, goodType: 3),
  PrBuildingDef(id: 5, name: '咖啡烘焙坊', desc: '生产最多2桶咖啡', cost: 6, vp: 3, capacity: 2, goodType: 4),
  // Small / Medium Violet buildings
  PrBuildingDef(id: 6, name: '小市场', desc: '商人阶段出售货物+1金币', cost: 1, vp: 1, capacity: 1),
  PrBuildingDef(id: 7, name: '建筑工棚', desc: '开拓者阶段可拿取采石场', cost: 2, vp: 1, capacity: 1),
  PrBuildingDef(id: 8, name: '小仓库', desc: '船长阶段结束额外储存3桶货物', cost: 3, vp: 1, capacity: 1),
  PrBuildingDef(id: 9, name: '旅馆', desc: '新开拓的种植园/采石场自带1名拓荒者', cost: 4, vp: 2, capacity: 1),
  PrBuildingDef(id: 10, name: '事务所', desc: '商人阶段可出售交易所已有的同类货物', cost: 5, vp: 2, capacity: 1),
  PrBuildingDef(id: 11, name: '大市场', desc: '商人阶段出售货物+2金币', cost: 5, vp: 2, capacity: 1),
  PrBuildingDef(id: 12, name: '大仓库', desc: '船长阶段结束额外储存6桶货物', cost: 6, vp: 2, capacity: 1),
  PrBuildingDef(id: 13, name: '工厂', desc: '工艺师阶段生产2/3/4/5种货物获1/2/3/5金币', cost: 7, vp: 3, capacity: 1),
  PrBuildingDef(id: 14, name: '大学', desc: '新建造的建筑自带1名拓荒者', cost: 8, vp: 3, capacity: 1),
  PrBuildingDef(id: 15, name: '港口', desc: '船长阶段每次装船额外+1胜利分', cost: 8, vp: 3, capacity: 1),
  // Large 10-cost Violet buildings (occupy 2 spaces)
  PrBuildingDef(id: 16, name: '行会大厅', desc: '终局每个生产作坊额外得2分', cost: 10, vp: 4, capacity: 1, isLarge: true),
  PrBuildingDef(id: 17, name: '官邸', desc: '终局按种植园与采石场数量额外得4~7分', cost: 10, vp: 4, capacity: 1, isLarge: true),
  PrBuildingDef(id: 18, name: '要塞', desc: '终局每3名拓荒者额外得1分', cost: 10, vp: 4, capacity: 1, isLarge: true),
  PrBuildingDef(id: 19, name: '海关', desc: '终局每4枚胜利分筹码额外得1分', cost: 10, vp: 4, capacity: 1, isLarge: true),
  PrBuildingDef(id: 20, name: '市政厅', desc: '终局每座紫色功能建筑额外得1分', cost: 10, vp: 4, capacity: 1, isLarge: true),
];

class PrTile {
  final int type; // 0..4 = good plantation, 5 = Quarry
  bool manned;

  PrTile({required this.type, this.manned = false});

  bool get isQuarry => type == 5;
  String get name => type == 5 ? '采石场' : prGoodNames[type];

  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'isQuarry': isQuarry,
        'manned': manned,
      };
}

class PrBuiltBuilding {
  final PrBuildingDef def;
  int mannedCount;

  PrBuiltBuilding({required this.def, this.mannedCount = 0});

  bool get isManned => mannedCount > 0;

  Map<String, dynamic> toJson() => {
        ...def.toJson(),
        'mannedCount': mannedCount,
        'isManned': isManned,
      };
}

class PrCargoShip {
  final int capacity;
  int? goodType;
  int count;

  PrCargoShip({required this.capacity, this.goodType, this.count = 0});

  int get spaceLeft => capacity - count;
  bool get isFull => count >= capacity;

  Map<String, dynamic> toJson() => {
        'capacity': capacity,
        'goodType': goodType,
        'goodName': goodType != null ? prGoodNames[goodType!] : null,
        'count': count,
        'spaceLeft': spaceLeft,
      };
}

const String puertoRicoRules = '''
# 波多黎各（Puerto Rico）规则说明

- **游戏概述**：经典德式策略桌游代表作！2至5名玩家在加勒比海的波多黎各岛上轮流选择六大角色（开拓者、市长、建筑师、工艺师、商人、船长），开拓种植园、招募拓荒者、兴建城市建筑、生产并出售高价货物或装船远航换取胜利分（VP）。
- **五种货物**：
  - `0: 玉米（Corn）`：无需作坊即可直接由玉米田生产；交易所基础售价 `0` 金币，装船每桶 `1` VP。
  - `1: 靛蓝（Indigo）`：需靛蓝坊生产；交易所基础售价 `1` 金币，装船每桶 `1` VP。
  - `2: 蔗糖（Sugar）`：需糖厂生产；交易所基础售价 `2` 金币，装船每桶 `1` VP。
  - `3: 烟草（Tobacco）`：需烟草作坊生产；交易所基础售价 `3` 金币，装船每桶 `1` VP。
  - `4: 咖啡（Coffee）`：需咖啡烘焙坊生产；交易所基础售价 `4` 金币，装船每桶 `1` VP。
- **六大角色与特权**：
  - **0: 开拓者（Settler）**：按顺时针各选 1 块翻开的种植园；选角者特权（或拥有已入驻【建筑工棚】）可改拿【采石场】（建造建筑时抵扣费用）。
  - **1: 市长（Mayor）**：从移民船按序分配拓荒者并自动入驻各自建筑与种植园；选角者特权额外多拿 `1` 名拓荒者。
  - **2: 建筑师（Builder）**：按顺时针各自可花费金币建造 1 座城市建筑；选角者特权享建造费用 `-1` 金币。
  - **3: 工艺师（Craftsman）**：所有玩家同时从已入驻的种植园与对应生产作坊产出货物；选角者特权若产出了至少 1 桶货物，可额外多拿 `1` 桶自产类型的货物。
  - **4: 商人（Trader）**：按顺时针可向交易所（最多容纳 4 桶不同种类货物）出售 1 桶货物换取金币；选角者特权售价 `+1` 金币。
  - **5: 船长（Captain）**：按顺时针轮流将货物装上 3 艘货船（每艘船只能装载同一种货物，且不能有两艘船装同种货物），只要能装船就必须装船，每桶获 `1` VP；选角者特权首次装船额外 `+1` VP。船长阶段结束时满载货船清空，每人最多保留 1 桶未装船货物（拥有仓库可额外保留）。
- **轮次与终局条件**：
  - 每轮由总督（Governor）开始顺时针选角；每轮结束后，未被选择的角色牌上各放 `+1` 枚奖励金币，总督标记顺时针传递。
  - 当出现以下任一情况时，在当前轮结束时触发终局：① 胜利分（VP）筹码池耗尽；② 有玩家建满 12 格城市建筑；③ 拓荒者供应堆耗尽或达到轮数上限。
  - **终局计分**：累计装船 VP 筹码 + 城市建筑基础 VP + 已入驻大型紫色建筑（行会大厅、官邸、要塞、海关、市政厅）的额外加分，最高分者获胜！
''';

class PuertoRico extends GameEngine {
  PuertoRico(super.setup);

  late int maxRounds;
  int round = 1;
  int governor = 0;
  int roleTurnIndex = 0; // how many roles picked so far in this round
  int get rolesPerRound => players == 2 ? 4 : players;

  String phase = 'pick_role'; // 'pick_role', 'settler', 'builder', 'craftsman_bonus', 'trader', 'captain'
  int currentRole = -1;
  int rolePicker = 0;
  int actionCursor = 0; // index 0..players-1 relative to rolePicker, or seat in captain loop
  int turn = 0;
  bool over = false;

  late List<int> roleCoins;
  late Set<int> usedRoles;
  late List<int> doubloons;
  late List<int> vp;
  late List<List<int>> goods; // goods[seat][0..4]
  late List<int> goodsSupply;
  late List<List<PrTile>> plantations;
  late List<List<PrBuiltBuilding>> buildings;
  late List<int> totalColonists;

  final List<int> plantationDeck = [];
  final List<int> plantationMarket = [];
  int quarriesLeft = 8;
  late Map<int, int> buildingStock;
  final List<int> tradingHouse = [];
  late List<PrCargoShip> cargoShips;

  int vpPool = 75;
  int colonistSupply = 55;
  int colonistShip = 3;
  bool cityFull = false;
  bool colonistExhausted = false;
  bool captainPrivilegeUsed = false;
  List<int> craftsmanBonusOptions = [];

  String lastAction = '';
  Map<String, dynamic>? result;
  List<int>? _placings;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  bool get canResign => !over;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [
      for (var s = 0; s < players; s++) s == seat ? -999 : (breakdown[s]['total'] as int),
    ];
    _placings = rankByScore(scores);
    result = {
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'placings': _placings,
      'resigned': seat,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void start() {
    final quick = setup.opt<String>('mode', 'standard') == 'quick';
    maxRounds = quick ? 8 : 14;
    vpPool = quick ? (players * 15) : (players * 25 + 10);
    colonistSupply = players * 14;
    colonistShip = players;
    quarriesLeft = 8;

    round = 1;
    governor = 0;
    roleTurnIndex = 0;
    phase = 'pick_role';
    currentRole = -1;
    rolePicker = 0;
    turn = 0;
    over = false;
    cityFull = false;
    colonistExhausted = false;

    roleCoins = List<int>.filled(6, 0);
    usedRoles = <int>{};
    doubloons = List<int>.filled(players, players <= 3 ? 3 : 4);
    vp = List<int>.filled(players, 0);
    goods = List.generate(players, (_) => List<int>.filled(5, 0));
    goodsSupply = [10, 11, 11, 9, 9];
    plantations = List.generate(players, (_) => <PrTile>[]);
    buildings = List.generate(players, (_) => <PrBuiltBuilding>[]);
    totalColonists = List<int>.filled(players, 1);

    // Starting plantations: first half get Corn (0), second half get Indigo (1), already manned with 1 colonist!
    for (var s = 0; s < players; s++) {
      final startType = s < (players + 1) ~/ 2 ? 0 : 1;
      plantations[s].add(PrTile(type: startType, manned: true));
    }

    // Build plantation deck
    plantationDeck.clear();
    const counts = [10, 12, 11, 9, 8];
    for (var g = 0; g < 5; g++) {
      for (var i = 0; i < counts[g]; i++) {
        plantationDeck.add(g);
      }
    }
    plantationDeck.shuffle(rng);
    _refillPlantationMarket();

    // Building shop stock
    buildingStock = {
      for (final b in prCatalog)
        b.id: b.isLarge ? 1 : (b.goodType != null ? (b.capacity == 1 ? 3 : 2) : 2),
    };

    // 3 Cargo ships
    final baseCap = players <= 3 ? 4 : (players == 4 ? 5 : 6);
    cargoShips = [
      PrCargoShip(capacity: baseCap),
      PrCargoShip(capacity: baseCap + 1),
      PrCargoShip(capacity: baseCap + 2),
    ];
    tradingHouse.clear();

    lastAction = '波多黎各开始！总督为 ${name(governor)}';
    host.log(lastAction);
  }

  void _refillPlantationMarket() {
    plantationMarket.clear();
    while (plantationMarket.length < players + 1) {
      if (plantationDeck.isEmpty) {
        for (var g = 0; g < 5; g++) {
          for (var i = 0; i < 4; i++) {
            plantationDeck.add(g);
          }
        }
        plantationDeck.shuffle(rng);
      }
      plantationMarket.add(plantationDeck.removeLast());
    }
  }

  bool hasActiveBuilding(int seat, int buildingId) =>
      buildings[seat].any((b) => b.def.id == buildingId && b.isManned);

  int activeQuarries(int seat) =>
      plantations[seat].where((p) => p.isQuarry && p.manned).length;

  int occupiedCitySpaces(int seat) =>
      buildings[seat].fold<int>(0, (sum, b) => sum + b.def.spaces);

  int buildingCostFor(int seat, PrBuildingDef def, {required bool isBuilder}) {
    final builderDiscount = isBuilder ? 1 : 0;
    final quarryDiscount = min(activeQuarries(seat), def.vp);
    return max(0, def.cost - builderDiscount - quarryDiscount);
  }

  bool canBuild(int seat, PrBuildingDef def, {required bool isBuilder}) {
    if ((buildingStock[def.id] ?? 0) <= 0) return false;
    if (buildings[seat].any((b) => b.def.id == def.id)) return false;
    if (occupiedCitySpaces(seat) + def.spaces > 12) return false;
    return doubloons[seat] >= buildingCostFor(seat, def, isBuilder: isBuilder);
  }

  /// Auto-assigns `totalColonists[seat]` across buildings and plantations for maximum utility.
  void autoStaffColonists(int seat) {
    for (final b in buildings[seat]) {
      b.mannedCount = 0;
    }
    for (final p in plantations[seat]) {
      p.manned = false;
    }
    var rem = totalColonists[seat];
    if (rem <= 0) return;

    // 1. Pair production buildings and plantations from highest value (Coffee=4) down to Indigo=1
    for (var g = 4; g >= 1; g--) {
      final gTiles = plantations[seat].where((p) => p.type == g && !p.manned).toList();
      final gBuildings = buildings[seat].where((b) => b.def.goodType == g).toList();
      for (final b in gBuildings) {
        while (b.mannedCount < b.def.capacity && gTiles.isNotEmpty && rem >= 2) {
          b.mannedCount++;
          gTiles.removeLast().manned = true;
          rem -= 2;
        }
      }
    }

    // 2. Staff violet buildings (Large buildings first, then by cost descending)
    final violets = buildings[seat].where((b) => b.def.goodType == null).toList()
      ..sort((a, b) => b.def.cost.compareTo(a.def.cost));
    for (final b in violets) {
      if (rem <= 0) break;
      if (b.mannedCount < b.def.capacity) {
        b.mannedCount++;
        rem--;
      }
    }

    // 3. Staff Corn plantations (type 0) and Quarries (type 5)
    for (final p in plantations[seat]) {
      if (rem <= 0) break;
      if (!p.manned && (p.type == 0 || p.isQuarry)) {
        p.manned = true;
        rem--;
      }
    }

    // 4. Staff any remaining unstaffed building slots
    for (final b in buildings[seat]) {
      while (rem > 0 && b.mannedCount < b.def.capacity) {
        b.mannedCount++;
        rem--;
      }
    }

    // 5. Staff any remaining unstaffed plantations
    for (final p in plantations[seat]) {
      if (rem <= 0) break;
      if (!p.manned) {
        p.manned = true;
        rem--;
      }
    }
  }

  /// Computes how many barrels of each good `0..4` [seat] can currently produce.
  List<int> productionCapacity(int seat) {
    final cap = List<int>.filled(5, 0);
    // Corn (0) needs only manned Corn plantations
    cap[0] = plantations[seat].where((p) => p.type == 0 && p.manned).length;
    for (var g = 1; g <= 4; g++) {
      final pCount = plantations[seat].where((p) => p.type == g && p.manned).length;
      final bCount = buildings[seat]
          .where((b) => b.def.goodType == g)
          .fold<int>(0, (s, b) => s + b.mannedCount);
      cap[g] = min(pCount, bCount);
    }
    return cap;
  }

  /// Goods that [seat] can legally sell to the Trading House right now.
  List<int> tradableGoods(int seat) {
    if (tradingHouse.length >= 4) return const [];
    final hasOffice = hasActiveBuilding(seat, 10);
    return [
      for (var g = 0; g < 5; g++)
        if (goods[seat][g] > 0 && (hasOffice || !tradingHouse.contains(g))) g,
    ];
  }

  /// Valid `(goodType, shipIndex)` pairs that [seat] can load onto cargo ships.
  List<(int, int)> legalShipments(int seat) {
    final res = <(int, int)>[];
    for (var g = 0; g < 5; g++) {
      if (goods[seat][g] <= 0) continue;
      // Check if a ship already carries this good
      final existingIdx = cargoShips.indexWhere((s) => s.goodType == g);
      if (existingIdx >= 0) {
        if (!cargoShips[existingIdx].isFull) {
          res.add((g, existingIdx));
        }
      } else {
        // Can load onto any empty ship
        for (var i = 0; i < cargoShips.length; i++) {
          if (cargoShips[i].goodType == null) {
            res.add((g, i));
          }
        }
      }
    }
    return res;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'pick_role') {
      if (type != 'pick_role') throw GameError('当前阶段请选择角色');
      final r = asInt(action['role'], -1);
      if (r < 0 || r >= 6 || usedRoles.contains(r)) {
        throw GameError('该角色不可选或本轮已被选过');
      }
      usedRoles.add(r);
      currentRole = r;
      rolePicker = seat;
      final bonusCoins = roleCoins[r];
      roleCoins[r] = 0;
      doubloons[seat] += bonusCoins;

      lastAction = '${name(seat)} 选择了【${prRoleNames[r]}】${bonusCoins > 0 ? "（获得+$bonusCoins金币）" : ""}';
      host.log(lastAction);

      _beginRoleExecution(r);
      return;
    }

    if (phase == 'settler') {
      if (type == 'pass') {
        lastAction = '${name(seat)} 跳过开拓种植园';
        host.log(lastAction);
        _advanceSettler();
        return;
      }
      if (plantations[seat].length >= 12) {
        throw GameError('你的岛屿已满12格，请跳过');
      }
      final hasHospice = hasActiveBuilding(seat, 9);
      if (type == 'settler_quarry') {
        final canQuarry = seat == rolePicker || hasActiveBuilding(seat, 7);
        if (!canQuarry) throw GameError('只有开拓者或拥有已入驻【建筑工棚】才能拿取采石场');
        if (quarriesLeft <= 0) throw GameError('采石场已耗尽');
        quarriesLeft--;
        final freeCol = hasHospice && colonistSupply > 0;
        if (freeCol) {
          colonistSupply--;
          totalColonists[seat]++;
        }
        plantations[seat].add(PrTile(type: 5, manned: freeCol));
        autoStaffColonists(seat);
        lastAction = '${name(seat)} 拿取了【采石场】';
        host.log(lastAction);
        _advanceSettler();
        return;
      }
      if (type == 'settler_pick') {
        final idx = asInt(action['index'], -1);
        if (idx < 0 || idx >= plantationMarket.length) {
          throw GameError('无效的种植园索引');
        }
        final gType = plantationMarket.removeAt(idx);
        final freeCol = hasHospice && colonistSupply > 0;
        if (freeCol) {
          colonistSupply--;
          totalColonists[seat]++;
        }
        plantations[seat].add(PrTile(type: gType, manned: freeCol));
        autoStaffColonists(seat);
        lastAction = '${name(seat)} 开拓了【${prGoodNames[gType]}】种植园';
        host.log(lastAction);
        _advanceSettler();
        return;
      }
      throw GameError('开拓者阶段请选种植园、采石场或跳过');
    }

    if (phase == 'builder') {
      if (type == 'pass') {
        lastAction = '${name(seat)} 跳过建造';
        host.log(lastAction);
        _advanceBuilder();
        return;
      }
      if (type == 'build') {
        final bId = asInt(action['buildingId'], -1);
        if (bId < 0 || bId >= prCatalog.length) throw GameError('无效的建筑编号');
        final def = prCatalog[bId];
        final isBuilder = seat == rolePicker;
        if (!canBuild(seat, def, isBuilder: isBuilder)) {
          throw GameError('无法建造【${def.name}】（金币不足、已拥有同名建筑或城市已满）');
        }
        final cost = buildingCostFor(seat, def, isBuilder: isBuilder);
        doubloons[seat] -= cost;
        buildingStock[bId] = (buildingStock[bId] ?? 1) - 1;

        final hasUniv = hasActiveBuilding(seat, 14);
        final freeCol = hasUniv && colonistSupply > 0;
        if (freeCol) {
          colonistSupply--;
          totalColonists[seat]++;
        }
        buildings[seat].add(PrBuiltBuilding(def: def, mannedCount: freeCol ? 1 : 0));
        autoStaffColonists(seat);
        if (occupiedCitySpaces(seat) >= 12) {
          cityFull = true;
        }
        lastAction = '${name(seat)} 花费 $cost 金币建造了【${def.name}】';
        host.log(lastAction);
        _advanceBuilder();
        return;
      }
      throw GameError('建筑师阶段请选择建筑或跳过');
    }

    if (phase == 'craftsman_bonus') {
      if (type != 'craftsman_bonus') throw GameError('请选择工艺师特权额外生产的货物');
      final g = asInt(action['good'], -1);
      if (!craftsmanBonusOptions.contains(g)) {
        throw GameError('该货物不在可选特权生产列表中');
      }
      goods[seat][g]++;
      goodsSupply[g]--;
      lastAction = '${name(seat)} 使用工艺师特权额外获得了 1 桶【${prGoodNames[g]}】';
      host.log(lastAction);
      _finishCurrentRole();
      return;
    }

    if (phase == 'trader') {
      if (type == 'pass') {
        lastAction = '${name(seat)} 跳过出售货物';
        host.log(lastAction);
        _advanceTrader();
        return;
      }
      if (type == 'trade') {
        final g = asInt(action['good'], -1);
        final allowed = tradableGoods(seat);
        if (!allowed.contains(g)) {
          throw GameError('无法向交易所出售该货物');
        }
        goods[seat][g]--;
        tradingHouse.add(g);
        var price = prGoodPrices[g];
        if (seat == rolePicker) price += 1;
        if (hasActiveBuilding(seat, 6)) price += 1; // 小市场
        if (hasActiveBuilding(seat, 11)) price += 2; // 大市场
        doubloons[seat] += price;
        lastAction = '${name(seat)} 向交易所出售了 1 桶【${prGoodNames[g]}】，获得 $price 金币';
        host.log(lastAction);
        _advanceTrader();
        return;
      }
      throw GameError('商人阶段请选择出售货物或跳过');
    }

    if (phase == 'captain') {
      if (type != 'load_ship') throw GameError('船长阶段必须装船运货');
      final g = asInt(action['good'], -1);
      final sIdx = asInt(action['ship'], -1);
      final legal = legalShipments(seat);
      if (!legal.contains((g, sIdx))) {
        throw GameError('无效的装船选择');
      }
      final ship = cargoShips[sIdx];
      final amount = min(goods[seat][g], ship.spaceLeft);
      goods[seat][g] -= amount;
      ship.goodType = g;
      ship.count += amount;

      var gainedVp = amount;
      if (seat == rolePicker && !captainPrivilegeUsed) {
        gainedVp += 1;
        captainPrivilegeUsed = true;
      }
      if (hasActiveBuilding(seat, 15)) {
        gainedVp += 1; // 港口
      }
      vp[seat] += gainedVp;
      vpPool = max(0, vpPool - gainedVp);

      lastAction = '${name(seat)} 将 $amount 桶【${prGoodNames[g]}】装上 ${sIdx + 1} 号货船，获得 $gainedVp VP';
      host.log(lastAction);
      _advanceCaptain(seat);
      return;
    }

    throw GameError('未知阶段或操作');
  }

  void _beginRoleExecution(int r) {
    actionCursor = 0;
    if (r == 0) {
      // Settler
      phase = 'settler';
      turn = rolePicker;
      return;
    }
    if (r == 1) {
      // Mayor: distribute colonists and auto-staff
      var distributed = 0;
      if (colonistSupply > 0) {
        colonistSupply--;
        totalColonists[rolePicker]++;
        distributed++;
      }
      for (var i = 0; i < colonistShip; i++) {
        final target = (rolePicker + i) % players;
        totalColonists[target]++;
        distributed++;
      }
      var emptyCircles = 0;
      for (var s = 0; s < players; s++) {
        autoStaffColonists(s);
        for (final b in buildings[s]) {
          emptyCircles += (b.def.capacity - b.mannedCount);
        }
      }
      final nextShip = max(players, emptyCircles);
      if (colonistSupply < nextShip) {
        colonistShip = max(players, colonistSupply);
        colonistSupply = 0;
        colonistExhausted = true;
      } else {
        colonistShip = nextShip;
        colonistSupply -= nextShip;
      }
      lastAction = '${name(rolePicker)} 执行【市长】分配了 $distributed 名拓荒者，下轮移民船载有 $colonistShip 人';
      host.log(lastAction);
      _finishCurrentRole();
      return;
    }
    if (r == 2) {
      // Builder
      phase = 'builder';
      turn = rolePicker;
      return;
    }
    if (r == 3) {
      // Craftsman: produce goods for all players
      final pickerProducedTypes = <int>[];
      for (var i = 0; i < players; i++) {
        final s = (rolePicker + i) % players;
        final cap = productionCapacity(s);
        var typesProduced = 0;
        for (var g = 0; g < 5; g++) {
          final amt = min(cap[g], goodsSupply[g]);
          if (amt > 0) {
            goods[s][g] += amt;
            goodsSupply[g] -= amt;
            typesProduced++;
            if (s == rolePicker) pickerProducedTypes.add(g);
          } else if (cap[g] > 0 && s == rolePicker) {
            pickerProducedTypes.add(g);
          }
        }
        // Factory bonus
        if (hasActiveBuilding(s, 13) && typesProduced >= 2) {
          const factoryBonus = [0, 0, 1, 2, 3, 5];
          doubloons[s] += factoryBonus[min(typesProduced, 5)];
        }
      }
      craftsmanBonusOptions = [
        for (final g in pickerProducedTypes)
          if (goodsSupply[g] > 0) g,
      ];
      if (craftsmanBonusOptions.length == 1) {
        final g = craftsmanBonusOptions.first;
        goods[rolePicker][g]++;
        goodsSupply[g]--;
        lastAction = '${name(rolePicker)} 执行【工艺师】全体生产货物，并特权额外获得 1 桶【${prGoodNames[g]}】';
        host.log(lastAction);
        _finishCurrentRole();
      } else if (craftsmanBonusOptions.length > 1) {
        phase = 'craftsman_bonus';
        turn = rolePicker;
      } else {
        lastAction = '${name(rolePicker)} 执行【工艺师】全体生产货物';
        host.log(lastAction);
        _finishCurrentRole();
      }
      return;
    }
    if (r == 4) {
      // Trader
      phase = 'trader';
      actionCursor = -1;
      _advanceTrader();
      return;
    }
    if (r == 5) {
      // Captain
      phase = 'captain';
      captainPrivilegeUsed = false;
      _advanceCaptain(rolePicker - 1);
      return;
    }
  }

  void _advanceSettler() {
    actionCursor++;
    if (actionCursor >= players) {
      _refillPlantationMarket();
      _finishCurrentRole();
      return;
    }
    turn = (rolePicker + actionCursor) % players;
  }

  void _advanceBuilder() {
    actionCursor++;
    if (actionCursor >= players) {
      _finishCurrentRole();
      return;
    }
    turn = (rolePicker + actionCursor) % players;
  }

  void _advanceTrader() {
    while (true) {
      actionCursor++;
      if (actionCursor >= players || tradingHouse.length >= 4) {
        if (tradingHouse.length >= 4) {
          for (final g in tradingHouse) {
            goodsSupply[g]++;
          }
          tradingHouse.clear();
        }
        _finishCurrentRole();
        return;
      }
      final candidate = (rolePicker + actionCursor) % players;
      if (tradableGoods(candidate).isNotEmpty) {
        turn = candidate;
        return;
      }
    }
  }

  void _advanceCaptain(int lastSeat) {
    for (var offset = 1; offset <= players; offset++) {
      final candidate = (lastSeat + offset + players) % players;
      if (legalShipments(candidate).isNotEmpty) {
        turn = candidate;
        return;
      }
    }
    // No player can ship any more goods -> end of Captain phase:
    // 1. Spoilage (keep up to 1 barrel + 3 for Small Warehouse + 6 for Large Warehouse, highest value kept first)
    for (var s = 0; s < players; s++) {
      var keepLimit = 1;
      if (hasActiveBuilding(s, 8)) keepLimit += 3;
      if (hasActiveBuilding(s, 12)) keepLimit += 6;
      var remKeep = keepLimit;
      for (var g = 4; g >= 0; g--) {
        final k = min(goods[s][g], remKeep);
        final spoiled = goods[s][g] - k;
        if (spoiled > 0) {
          goods[s][g] = k;
          goodsSupply[g] += spoiled;
        }
        remKeep -= k;
      }
    }
    // 2. Empty full cargo ships
    for (final ship in cargoShips) {
      if (ship.isFull && ship.goodType != null) {
        goodsSupply[ship.goodType!] += ship.count;
        ship.goodType = null;
        ship.count = 0;
      }
    }
    _finishCurrentRole();
  }

  void _finishCurrentRole() {
    roleTurnIndex++;
    if (roleTurnIndex < rolesPerRound) {
      phase = 'pick_role';
      turn = (governor + roleTurnIndex) % players;
      return;
    }

    // End of round: put +1 doubloon on all unselected roles
    for (var r = 0; r < 6; r++) {
      if (!usedRoles.contains(r)) {
        roleCoins[r]++;
      }
    }
    usedRoles.clear();
    roleTurnIndex = 0;

    if (vpPool <= 0 || cityFull || colonistExhausted || round >= maxRounds) {
      _finishGame();
      return;
    }

    round++;
    governor = (governor + 1) % players;
    phase = 'pick_role';
    turn = governor;
  }

  void _finishGame() {
    over = true;
    final breakdown = computeScoreBreakdown();
    final scores = [for (var s = 0; s < players; s++) breakdown[s]['total'] as int];
    final tieBreakScores = [
      for (var s = 0; s < players; s++)
        scores[s] * 1000 + doubloons[s] + goods[s].fold<int>(0, (a, b) => a + b),
    ];
    _placings = rankByScore(tieBreakScores);
    result = {
      'scores': scores,
      'breakdown': breakdown,
      'placings': _placings,
    };
    host.log('波多黎各结束！最终得分：${[for (var s = 0; s < players; s++) "${name(s)} ${scores[s]}分"].join("，")}');
  }

  List<Map<String, dynamic>> computeScoreBreakdown() {
    final out = <Map<String, dynamic>>[];
    for (var s = 0; s < players; s++) {
      final chipVp = vp[s];
      final buildingVp = buildings[s].fold<int>(0, (sum, b) => sum + b.def.vp);
      var largeBonus = 0;
      // 16: 行会大厅 (2 VP per production building)
      if (hasActiveBuilding(s, 16)) {
        largeBonus += buildings[s].where((b) => b.def.goodType != null).length * 2;
      }
      // 17: 官邸 (4..7 VP based on island tiles count)
      if (hasActiveBuilding(s, 17)) {
        final cnt = plantations[s].length;
        largeBonus += cnt <= 9 ? 4 : (cnt == 10 ? 5 : (cnt == 11 ? 6 : 7));
      }
      // 18: 要塞 (1 VP per 3 colonists)
      if (hasActiveBuilding(s, 18)) {
        largeBonus += totalColonists[s] ~/ 3;
      }
      // 19: 海关 (1 VP per 4 VP chips)
      if (hasActiveBuilding(s, 19)) {
        largeBonus += chipVp ~/ 4;
      }
      // 20: 市政厅 (1 VP per violet building)
      if (hasActiveBuilding(s, 20)) {
        largeBonus += buildings[s].where((b) => b.def.goodType == null).length;
      }
      final total = chipVp + buildingVp + largeBonus;
      out.add({
        'chipVp': chipVp,
        'buildingVp': buildingVp,
        'largeBonus': largeBonus,
        'doubloons': doubloons[s],
        'total': total,
      });
    }
    return out;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final breakdown = computeScoreBreakdown();
    return {
      'round': round,
      'maxRounds': maxRounds,
      'governor': governor,
      'phase': phase,
      'currentRole': currentRole,
      'rolePicker': rolePicker,
      'turn': turn,
      'over': over,
      'vpPool': vpPool,
      'colonistSupply': colonistSupply,
      'colonistShip': colonistShip,
      'quarriesLeft': quarriesLeft,
      'roleCoins': roleCoins,
      'usedRoles': usedRoles.toList(),
      'plantationMarket': plantationMarket,
      'tradingHouse': tradingHouse,
      'cargoShips': [for (final s in cargoShips) s.toJson()],
      'buildingShop': [
        for (final b in prCatalog)
          {
            ...b.toJson(),
            'stock': buildingStock[b.id] ?? 0,
            'effectiveCost': seat >= 0
                ? buildingCostFor(seat, b, isBuilder: phase == 'builder' && seat == rolePicker)
                : b.cost,
          },
      ],
      'craftsmanBonusOptions': craftsmanBonusOptions,
      'playersData': [
        for (var s = 0; s < players; s++)
          {
            'doubloons': doubloons[s],
            'vp': vp[s], // visible in UI/summary
            'goods': goods[s],
            'colonists': totalColonists[s],
            'citySpaces': occupiedCitySpaces(s),
            'plantations': [for (final p in plantations[s]) p.toJson()],
            'buildings': [for (final b in buildings[s]) b.toJson()],
            'score': breakdown[s]['total'],
          },
      ],
      'scores': [for (var s = 0; s < players; s++) breakdown[s]['total']],
      'breakdown': breakdown,
      'lastAction': lastAction,
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'pick_role') {
      final avail = [for (var r = 0; r < 6; r++) if (!usedRoles.contains(r)) r];
      if (avail.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'pick_role', 'role': avail[rng.nextInt(avail.length)]};
      }
      var bestRole = avail.first;
      var bestScore = -999;
      final totalGoods = goods[seat].fold<int>(0, (a, b) => a + b);
      final prodCap = productionCapacity(seat).fold<int>(0, (a, b) => a + b);
      for (final r in avail) {
        var score = roleCoins[r] * 3;
        if (r == 5 && legalShipments(seat).isNotEmpty) score += totalGoods * 5 + 6;
        if (r == 4 && tradableGoods(seat).isNotEmpty) {
          final bestG = tradableGoods(seat).reduce(max);
          score += (prGoodPrices[bestG] + 1) * 4;
        }
        if (r == 3 && prodCap > 0) score += prodCap * 4 + 3;
        if (r == 2 && doubloons[seat] >= 2) score += doubloons[seat] * 2;
        if (r == 0 && plantations[seat].length < 12) score += 6;
        if (r == 1) score += 5;
        if (score > bestScore) {
          bestScore = score;
          bestRole = r;
        }
      }
      return {'type': 'pick_role', 'role': bestRole};
    }

    if (phase == 'settler') {
      if (plantations[seat].length >= 12) return {'type': 'pass'};
      final canQuarry = (seat == rolePicker || hasActiveBuilding(seat, 7)) && quarriesLeft > 0;
      if (canQuarry && activeQuarries(seat) < 2 && botLevel >= 1) {
        return {'type': 'settler_quarry'};
      }
      if (plantationMarket.isNotEmpty) {
        // Prefer plantation matching an unfulfilled production building, or Corn (0)
        var bestIdx = 0;
        for (var i = 0; i < plantationMarket.length; i++) {
          final g = plantationMarket[i];
          if (buildings[seat].any((b) => b.def.goodType == g) || g == 0) {
            bestIdx = i;
            break;
          }
        }
        return {'type': 'settler_pick', 'index': bestIdx};
      }
      return {'type': 'pass'};
    }

    if (phase == 'builder') {
      final isBuilder = seat == rolePicker;
      final buildable = [
        for (final b in prCatalog)
          if (canBuild(seat, b, isBuilder: isBuilder)) b,
      ];
      if (buildable.isEmpty) return {'type': 'pass'};
      if (botLevel == 0) {
        return {'type': 'build', 'buildingId': buildable[rng.nextInt(buildable.length)].id};
      }
      // Prioritize Large buildings, then production buildings matching owned plantations, then highest VP
      buildable.sort((a, b) {
        if (a.isLarge != b.isLarge) return b.isLarge ? 1 : -1;
        final aMatch = a.goodType != null && plantations[seat].any((p) => p.type == a.goodType);
        final bMatch = b.goodType != null && plantations[seat].any((p) => p.type == b.goodType);
        if (aMatch != bMatch) return bMatch ? 1 : -1;
        return b.vp.compareTo(a.vp);
      });
      return {'type': 'build', 'buildingId': buildable.first.id};
    }

    if (phase == 'craftsman_bonus') {
      final bestG = craftsmanBonusOptions.reduce(max);
      return {'type': 'craftsman_bonus', 'good': bestG};
    }

    if (phase == 'trader') {
      final tradable = tradableGoods(seat);
      if (tradable.isEmpty) return {'type': 'pass'};
      final bestG = tradable.reduce(max);
      return {'type': 'trade', 'good': bestG};
    }

    if (phase == 'captain') {
      final shipments = legalShipments(seat);
      if (shipments.isEmpty) return null;
      // Pick shipment that loads the most barrels
      var best = shipments.first;
      var bestAmt = 0;
      for (final sh in shipments) {
        final amt = min(goods[seat][sh.$1], cargoShips[sh.$2].spaceLeft);
        if (amt > bestAmt) {
          bestAmt = amt;
          best = sh;
        }
      }
      return {'type': 'load_ship', 'good': best.$1, 'ship': best.$2};
    }

    return null;
  }
}
