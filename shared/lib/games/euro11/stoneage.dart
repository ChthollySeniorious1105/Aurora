import 'dart:math';

import '../../src/engine.dart';

const String stoneAgeRules = '''
# 石器时代 (Stone Age) 规则说明

## 游戏概述
《石器时代》(Stone Age) 是经典德式工人放置与文明发展策略桌游（支持 2~4 人）。玩家率领远古部族，在每个回合轮流派遣族人前往农田、工具坊、育儿屋、狩猎场、资源产地（森林/砖坑/采石场/淘金河）、建筑工坊与文明卡牌区，通过投骰采集资源、建造房屋、收集科技符号与文明倍率，并在每轮结束时用食物喂养部族！

## 核心资源与部族属性
- **食物 (`food` 🍖)**：狩猎场产出（除数 2），用于每轮结束时喂养族人（每人消耗 1 食物）。
- **四种建筑资源**：
  - **木材 (`wood` 🪵)**：森林产出，投骰除数 **3**，基础价值 3 分。
  - **砖块 (`brick` 🧱)**：砖坑产出，投骰除数 **4**，基础价值 4 分。
  - **石料 (`stone` 🪨)**：采石场产出，投骰除数 **5**，基础价值 5 分。
  - **黄金 (`gold` 🪙)**：淘金河产出，投骰除数 **6**，基础价值 6 分。
- **三大发展轨道**：
  - **农业轨 (`agri`，0..10)**：每轮喂养阶段自动提供等量免消耗食物。
  - **工具值 (`tools`，0..6)**：每次采集资源投骰时，自动为骰点总和提供 `+tools` 加成。
  - **族人数量 (`workers`，5..10)**：每轮可派遣的族人总数。

## 回合流程（每轮分为 2 个阶段）
1. **派遣族人阶段 (`place`)**：
   - 从先手玩家开始轮流行动，每次选择 1 个地点派遣族人，直至所有人放完族人：
     - **农田 (`field`)**：限 1 人，农业 +1。
     - **工具坊 (`tool`)**：限 1 人，工具 +1。
     - **育儿屋 (`hut`)**：需同时派遣 **2 人**，族人上限 +1（最多 10 人）。
     - **狩猎场 (`hunt`)**：不限人数，每名族人投 1 颗骰子，总点数 ÷ 2 获得食物。
     - **森林 (`forest`) / 砖坑 (`brick`) / 采石场 (`stone`) / 淘金河 (`gold`)**：每个产地总容量 7 人（同一玩家每轮同一产地限派 1 次），按人数投骰 + 工具值，除以对应除数（3/4/5/6）获得资源。
     - **建筑工坊 (`building_0..3`)**：4 座建筑各限 1 人，支付对应资源建造房屋获得高额分数。
     - **文明卡牌 (`civ_0..3`)**：4 张文明卡各限 1 人，按列位置支付 `1..4` 个任意资源获取卡牌。
2. **结算与喂养阶段 (`resolve`)**：
   - 按顺位结算各玩家派遣的族人收益、建造房屋与购买文明卡。
   - **文明卡双体系终局计分**：
     - **绿色科技符号（8 种：陶艺/医药/天文/文字/音乐/纺织/交通/计时）**：不同种类科技符号数量为 K 时，获得 K×K 分！
     - **沙色人物倍率（农夫/工匠/建筑师/萨满）**：按你的 **农业 / 工具 / 已建建筑 / 族人数 × 卡面倍率** 获得终局加分！
   - **部族喂养**：每位玩家需消耗 `max(0, workers - agri)` 份食物；若食物不足，可用任意资源 1:1 抵扣，仍不足则扣除 **10 分** 饥荒惩罚。
''';

class SaBuilding {
  final String id;
  final String name;
  final List<int> cost; // [wood, brick, stone, gold]
  final int vp;

  const SaBuilding({
    required this.id,
    required this.name,
    required this.cost,
    required this.vp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cost': cost,
        'vp': vp,
      };
}

class SaCivCard {
  final String id;
  final String name;
  final String immediateText;
  final String immediateKind; // 'food' | 'wood' | 'brick' | 'stone' | 'gold' | 'agri' | 'tool' | 'vp'
  final int immediateAmount;
  final int? greenSymbol; // 0..7 for science symbols, null if sand multiplier
  final String? multiplierTrack; // 'agri' | 'tools' | 'buildings' | 'workers'
  final int multiplierValue;

  const SaCivCard({
    required this.id,
    required this.name,
    required this.immediateText,
    required this.immediateKind,
    required this.immediateAmount,
    this.greenSymbol,
    this.multiplierTrack,
    this.multiplierValue = 1,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'immediateText': immediateText,
        'immediateKind': immediateKind,
        'immediateAmount': immediateAmount,
        'greenSymbol': greenSymbol,
        'multiplierTrack': multiplierTrack,
        'multiplierValue': multiplierValue,
      };
}

class StoneAge extends GameEngine {
  static const List<String> greenSymbolNames = ['陶艺', '医药', '天文', '文字', '音乐', '纺织', '交通', '日晷'];

  static String normalizeLoc(String raw) {
    return switch (raw) {
      'wood' => 'forest',
      'clay' => 'brick',
      'quarry' => 'stone',
      'river' => 'gold',
      _ => raw,
    };
  }

  late List<int> food;
  late List<int> wood;
  late List<int> brick;
  late List<int> stone;
  late List<int> gold;
  late List<int> agri;
  late List<int> tools;
  late List<int> workers;
  late List<int> availableWorkers;
  late List<int> baseScore;
  late List<int> buildingsBuilt;
  late List<Set<int>> greenSymbols;
  late List<Map<String, int>> multipliers; // {'agri': x, 'tools': x, 'buildings': x, 'workers': x}

  /// Placements per location: locId -> Map<seat, count>
  final Map<String, Map<int, int>> placements = {};

  late List<SaBuilding?> buildings; // 4 slots
  late List<SaBuilding> buildingDeck;
  late List<SaCivCard?> civCards; // 4 slots (cost 1, 2, 3, 4 resources)
  late List<SaCivCard> civDeck;

  String phase = 'place'; // 'place' | 'resolve' | 'over'
  int round = 1;
  int maxRounds = 8;
  int firstPlayer = 0;
  int turn = 0;
  bool over = false;
  int resignedSeat = -1;
  final List<String> recent = [];

  StoneAge(super.setup);

  void _log(String msg) {
    host.log(msg);
    recent.add(msg);
    if (recent.length > 12) recent.removeAt(0);
  }

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 8);
    food = List.filled(players, 12);
    wood = List.filled(players, 1);
    brick = List.filled(players, 0);
    stone = List.filled(players, 0);
    gold = List.filled(players, 0);
    agri = List.filled(players, 0);
    tools = List.filled(players, 0);
    workers = List.filled(players, 5);
    availableWorkers = List.filled(players, 5);
    baseScore = List.filled(players, 0);
    buildingsBuilt = List.filled(players, 0);
    greenSymbols = List.generate(players, (_) => <int>{});
    multipliers = List.generate(
      players,
      (_) => {'agri': 0, 'tools': 0, 'buildings': 0, 'workers': 0},
    );

    buildingDeck = _buildBuildingDeck()..shuffle(rng);
    civDeck = _buildCivDeck()..shuffle(rng);

    buildings = [for (var i = 0; i < 4; i++) buildingDeck.removeLast()];
    civCards = [for (var i = 0; i < 4; i++) civDeck.removeLast()];

    _resetPlacements();
    phase = 'place';
    round = 1;
    firstPlayer = 0;
    turn = 0;
    over = false;
    _log('石器时代开始！共 $maxRounds 轮，请轮流派遣族人。');
  }

  List<SaBuilding> _buildBuildingDeck() {
    return [
      const SaBuilding(id: 'B1', name: '林间木屋', cost: [2, 1, 0, 0], vp: 10),
      const SaBuilding(id: 'B2', name: '陶土窑房', cost: [1, 2, 0, 0], vp: 11),
      const SaBuilding(id: 'B3', name: '巨石祭坛', cost: [1, 0, 2, 0], vp: 13),
      const SaBuilding(id: 'B4', name: '黄金图腾', cost: [1, 1, 0, 1], vp: 13),
      const SaBuilding(id: 'B5', name: '长老石屋', cost: [0, 2, 1, 0], vp: 13),
      const SaBuilding(id: 'B6', name: '猎手营寨', cost: [2, 0, 1, 0], vp: 11),
      const SaBuilding(id: 'B7', name: '河畔金殿', cost: [0, 1, 1, 1], vp: 15),
      const SaBuilding(id: 'B8', name: '太阳神庙', cost: [1, 1, 1, 0], vp: 12),
      const SaBuilding(id: 'B9', name: '氏族议事厅', cost: [2, 1, 1, 0], vp: 15),
      const SaBuilding(id: 'B10', name: '圣山石堡', cost: [0, 1, 2, 0], vp: 14),
      const SaBuilding(id: 'B11', name: '丰收谷仓', cost: [2, 2, 0, 0], vp: 14),
      const SaBuilding(id: 'B12', name: '远古王庭', cost: [1, 0, 1, 1], vp: 14),
    ];
  }

  List<SaCivCard> _buildCivDeck() {
    final list = <SaCivCard>[];
    var id = 1;
    for (var sym = 0; sym < 8; sym++) {
      list.add(SaCivCard(
        id: 'C${id++}',
        name: '远古${greenSymbolNames[sym]}',
        immediateText: '+3 食物',
        immediateKind: 'food',
        immediateAmount: 3,
        greenSymbol: sym,
      ));
      list.add(SaCivCard(
        id: 'C${id++}',
        name: '部族${greenSymbolNames[sym]}',
        immediateText: '+1 木材',
        immediateKind: 'wood',
        immediateAmount: 1,
        greenSymbol: sym,
      ));
    }
    const tracks = [
      ('agri', '农夫祭司', '农业', '+2 食物', 'food', 2),
      ('tools', '百工巧匠', '工具', '+1 工具', 'tool', 1),
      ('buildings', '巨石匠师', '建筑', '+3 分', 'vp', 3),
      ('workers', '部族萨满', '族人', '+1 砖块', 'brick', 1),
    ];
    for (final (tr, title, _, immTxt, immKind, immAmt) in tracks) {
      for (var mul = 1; mul <= 2; mul++) {
        list.add(SaCivCard(
          id: 'C${id++}',
          name: '$title×$mul',
          immediateText: immTxt,
          immediateKind: immKind,
          immediateAmount: immAmt,
          multiplierTrack: tr,
          multiplierValue: mul,
        ));
      }
    }
    return list;
  }

  void _resetPlacements() {
    placements.clear();
    for (final loc in const [
      'field',
      'tool',
      'hut',
      'hunt',
      'forest',
      'brick',
      'stone',
      'gold',
      'building_0',
      'building_1',
      'building_2',
      'building_3',
      'civ_0',
      'civ_1',
      'civ_2',
      'civ_3',
    ]) {
      placements[loc] = {};
    }
  }

  int totalWorkersAt(String loc) =>
      placements[loc]?.values.fold<int>(0, (a, b) => a + b) ?? 0;

  int seatWorkersAt(String loc, int seat) => placements[loc]?[seat] ?? 0;

  bool canPlaceAt(int seat, String rawLoc, int count) {
    final loc = normalizeLoc(rawLoc);
    if (!placements.containsKey(loc)) return false;
    if (availableWorkers[seat] < count || count <= 0) return false;

    switch (loc) {
      case 'field':
        return count == 1 && totalWorkersAt(loc) == 0 && agri[seat] < 10;
      case 'tool':
        return count == 1 && totalWorkersAt(loc) == 0 && tools[seat] < 6;
      case 'hut':
        return count == 2 && totalWorkersAt(loc) == 0 && workers[seat] < 10;
      case 'hunt':
        return count >= 1;
      case 'forest':
      case 'brick':
      case 'stone':
      case 'gold':
        return seatWorkersAt(loc, seat) == 0 && totalWorkersAt(loc) + count <= 7;
      default:
        if (loc.startsWith('building_')) {
          final idx = int.tryParse(loc.substring(9)) ?? -1;
          return idx >= 0 &&
              idx < 4 &&
              buildings[idx] != null &&
              count == 1 &&
              totalWorkersAt(loc) == 0;
        }
        if (loc.startsWith('civ_')) {
          final idx = int.tryParse(loc.substring(4)) ?? -1;
          return idx >= 0 &&
              idx < 4 &&
              civCards[idx] != null &&
              count == 1 &&
              totalWorkersAt(loc) == 0;
        }
        return false;
    }
  }

  int totalResourcesOf(int seat) =>
      wood[seat] + brick[seat] + stone[seat] + gold[seat];

  bool canAffordBuilding(int seat, SaBuilding b) {
    return wood[seat] >= b.cost[0] &&
        brick[seat] >= b.cost[1] &&
        stone[seat] >= b.cost[2] &&
        gold[seat] >= b.cost[3];
  }

  void _payGenericResources(int seat, int amount) {
    var rem = amount;
    void take(List<int> arr) {
      final t = min(rem, arr[seat]);
      arr[seat] -= t;
      rem -= t;
    }

    take(wood);
    take(brick);
    take(stone);
    take(gold);
  }

  Map<String, dynamic> scoreBreakdown(int seat) {
    final sciCount = greenSymbols[seat].length;
    final scienceVp = sciCount * sciCount;
    final m = multipliers[seat];
    final agriVp = (m['agri'] ?? 0) * agri[seat];
    final toolVp = (m['tools'] ?? 0) * tools[seat];
    final buildVp = (m['buildings'] ?? 0) * buildingsBuilt[seat];
    final workerVp = (m['workers'] ?? 0) * workers[seat];
    final mulVp = agriVp + toolVp + buildVp + workerVp;
    final resVp = totalResourcesOf(seat);
    final total = baseScore[seat] + scienceVp + mulVp + resVp;
    return {
      'seat': seat,
      'baseVp': baseScore[seat],
      'scienceCount': sciCount,
      'scienceVp': scienceVp,
      'multiplierVp': mulVp,
      'resourceVp': resVp,
      'total': total,
    };
  }

  int scoreOf(int seat) => scoreBreakdown(seat)['total'] as int;

  bool _hasUnresolvedPlacements(int seat) {
    for (final m in placements.values) {
      if ((m[seat] ?? 0) > 0) return true;
    }
    return false;
  }

  void _resolveSingleLoc(int seat, String loc) {
    final cnt = placements[loc]?[seat] ?? 0;
    if (cnt <= 0) return;
    placements[loc]!.remove(seat);

    switch (loc) {
      case 'field':
        agri[seat] = min(10, agri[seat] + 1);
        _log('${name(seat)} 结算【农田】：农业提升至 ${agri[seat]}');
      case 'tool':
        tools[seat] = min(6, tools[seat] + 1);
        _log('${name(seat)} 结算【工具坊】：工具提升至 +${tools[seat]}');
      case 'hut':
        workers[seat] = min(10, workers[seat] + 1);
        _log('${name(seat)} 结算【育儿屋】：部族人口增至 ${workers[seat]} 人');
      case 'hunt':
      case 'forest':
      case 'brick':
      case 'stone':
      case 'gold':
        final div = switch (loc) {
          'hunt' => 2,
          'forest' => 3,
          'brick' => 4,
          'stone' => 5,
          _ => 6,
        };
        var rollSum = 0;
        for (var i = 0; i < cnt; i++) {
          rollSum += 1 + rng.nextInt(6);
        }
        final total = rollSum + tools[seat];
        final gained = total ~/ div;
        switch (loc) {
          case 'hunt':
            food[seat] += gained;
            _log('${name(seat)} 在【狩猎场】投出 $rollSum+${tools[seat]}，获得 $gained 🍖食物');
          case 'forest':
            wood[seat] += gained;
            _log('${name(seat)} 在【森林】投出 $rollSum+${tools[seat]}，获得 $gained 🪵木材');
          case 'brick':
            brick[seat] += gained;
            _log('${name(seat)} 在【砖坑】投出 $rollSum+${tools[seat]}，获得 $gained 🧱砖块');
          case 'stone':
            stone[seat] += gained;
            _log('${name(seat)} 在【采石场】投出 $rollSum+${tools[seat]}，获得 $gained 🪨石料');
          case 'gold':
            gold[seat] += gained;
            _log('${name(seat)} 在【淘金河】投出 $rollSum+${tools[seat]}，获得 $gained 🪙黄金');
        }
      default:
        if (loc.startsWith('building_')) {
          final idx = int.parse(loc.substring(9));
          final b = buildings[idx];
          if (b != null && canAffordBuilding(seat, b)) {
            wood[seat] -= b.cost[0];
            brick[seat] -= b.cost[1];
            stone[seat] -= b.cost[2];
            gold[seat] -= b.cost[3];
            baseScore[seat] += b.vp;
            buildingsBuilt[seat]++;
            buildings[idx] = buildingDeck.isNotEmpty ? buildingDeck.removeLast() : null;
            _log('${name(seat)} 建造了【${b.name}】（+${b.vp} 分）！');
          } else {
            _log('${name(seat)} 资源不足，放弃建造房屋');
          }
        } else if (loc.startsWith('civ_')) {
          final idx = int.parse(loc.substring(4));
          final c = civCards[idx];
          final cost = idx + 1;
          if (c != null && totalResourcesOf(seat) >= cost) {
            _payGenericResources(seat, cost);
            _applyCivCard(seat, c);
            civCards[idx] = null;
            _log('${name(seat)} 获取文明卡【${c.name}】（${c.immediateText}）！');
          } else {
            _log('${name(seat)} 资源不足，放弃文明卡');
          }
        }
    }
  }

  void _applyCivCard(int seat, SaCivCard c) {
    switch (c.immediateKind) {
      case 'food':
        food[seat] += c.immediateAmount;
      case 'wood':
        wood[seat] += c.immediateAmount;
      case 'brick':
        brick[seat] += c.immediateAmount;
      case 'stone':
        stone[seat] += c.immediateAmount;
      case 'gold':
        gold[seat] += c.immediateAmount;
      case 'agri':
        agri[seat] = min(10, agri[seat] + c.immediateAmount);
      case 'tool':
        tools[seat] = min(6, tools[seat] + c.immediateAmount);
      case 'vp':
        baseScore[seat] += c.immediateAmount;
    }
    if (c.greenSymbol != null) {
      greenSymbols[seat].add(c.greenSymbol!);
    }
    if (c.multiplierTrack != null) {
      final tr = c.multiplierTrack!;
      multipliers[seat][tr] = (multipliers[seat][tr] ?? 0) + c.multiplierValue;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'place') {
      if (type != 'place') throw GameError('当前为派遣族人阶段');
      final rawLoc = asStr(action['loc']);
      final loc = normalizeLoc(rawLoc);
      final defaultCount = loc == 'hut' ? 2 : 1;
      final count = asInt(action['count'], defaultCount);
      if (!canPlaceAt(seat, loc, count)) {
        throw GameError('无法向该地点派遣 $count 名族人');
      }
      placements[loc]![seat] = (placements[loc]![seat] ?? 0) + count;
      availableWorkers[seat] -= count;
      _log('${name(seat)} 派遣 $count 名族人前往【${_locLabel(loc)}】');
      _advancePlaceTurn();
      return;
    }

    if (phase == 'resolve') {
      if (type != 'resolve' && type != 'resolve_all') {
        throw GameError('当前为结算行动阶段');
      }
      final rawLoc = action['loc'] is String ? normalizeLoc(action['loc'] as String) : '';
      if (rawLoc.isNotEmpty && (placements[rawLoc]?[seat] ?? 0) > 0) {
        _resolveSingleLoc(seat, rawLoc);
      } else {
        // Resolve all locations for this seat in strategic order:
        // tool/field/hut/hunt/resources first so gained resources can pay for buildings/civ cards!
        const order = [
          'field',
          'tool',
          'hut',
          'hunt',
          'forest',
          'brick',
          'stone',
          'gold',
          'civ_0',
          'civ_1',
          'civ_2',
          'civ_3',
          'building_0',
          'building_1',
          'building_2',
          'building_3',
        ];
        for (final k in order) {
          if ((placements[k]?[seat] ?? 0) > 0) {
            _resolveSingleLoc(seat, k);
          }
        }
      }
      _advanceResolveTurn();
      return;
    }

    throw GameError('未知阶段');
  }

  String _locLabel(String loc) => switch (loc) {
        'field' => '农田',
        'tool' => '工具坊',
        'hut' => '育儿屋',
        'hunt' => '狩猎场',
        'forest' => '森林',
        'brick' => '砖坑',
        'stone' => '采石场',
        'gold' => '淘金河',
        _ when loc.startsWith('building_') => '建筑工坊#${int.parse(loc.substring(9)) + 1}',
        _ when loc.startsWith('civ_') => '文明卡#${int.parse(loc.substring(4)) + 1}',
        _ => loc,
      };

  void _advancePlaceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (availableWorkers[next] > 0) {
        turn = next;
        return;
      }
    }
    phase = 'resolve';
    turn = firstPlayer;
    _advanceResolveTurn(stayIfCurrentHasWork: true);
  }

  void _advanceResolveTurn({bool stayIfCurrentHasWork = false}) {
    if (stayIfCurrentHasWork && _hasUnresolvedPlacements(turn)) {
      return;
    }
    for (var i = 0; i <= players; i++) {
      final next = (turn + i) % players;
      if (_hasUnresolvedPlacements(next)) {
        turn = next;
        return;
      }
    }
    _endRoundAndFeed();
  }

  void _endRoundAndFeed() {
    for (var s = 0; s < players; s++) {
      final need = max(0, workers[s] - agri[s]);
      if (food[s] >= need) {
        food[s] -= need;
      } else {
        final missing = need - food[s];
        food[s] = 0;
        if (totalResourcesOf(s) >= missing) {
          _payGenericResources(s, missing);
          _log('${name(s)} 使用 $missing 份资源抵扣部族口粮');
        } else {
          baseScore[s] = max(0, baseScore[s] - 10);
          _log('⚠️ ${name(s)} 食物短缺，承受 -10 分饥荒惩罚！');
        }
      }
    }

    // Refill civ cards (slide left and draw new)
    final remainingCiv = [for (final c in civCards) if (c != null) c];
    while (remainingCiv.length < 4 && civDeck.isNotEmpty) {
      remainingCiv.add(civDeck.removeLast());
    }
    final civShortage = remainingCiv.length < 4;
    civCards = [
      for (var i = 0; i < 4; i++) i < remainingCiv.length ? remainingCiv[i] : null,
    ];

    final buildingEmpty = buildings.any((b) => b == null);

    if (round >= maxRounds || civShortage || buildingEmpty) {
      over = true;
      phase = 'over';
      final scores = [for (var s = 0; s < players; s++) scoreOf(s)];
      final best = scores.reduce(max);
      final winners = [for (var s = 0; s < players; s++) if (scores[s] == best) name(s)];
      _log('石器时代结束！${winners.join('、')} 以 $best 分统领远古部族！');
      return;
    }

    round++;
    firstPlayer = (firstPlayer + 1) % players;
    turn = firstPlayer;
    phase = 'place';
    for (var s = 0; s < players; s++) {
      availableWorkers[s] = workers[s];
    }
    _resetPlacements();
    _log('🔥 第 $round / $maxRounds 轮开始，先手为 ${name(firstPlayer)}。');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'resolve') {
      return {'type': 'resolve'};
    }

    final avail = availableWorkers[seat];
    if (avail <= 0) return null;

    if (botLevel > 0) {
      // High-value exclusive spots first
      if (canPlaceAt(seat, 'field', 1) && agri[seat] < 5) {
        return {'type': 'place', 'loc': 'field', 'count': 1};
      }
      if (canPlaceAt(seat, 'tool', 1) && tools[seat] < 4) {
        return {'type': 'place', 'loc': 'tool', 'count': 1};
      }
      if (canPlaceAt(seat, 'hut', 2) && workers[seat] < 7) {
        return {'type': 'place', 'loc': 'hut', 'count': 2};
      }
      // Check buildings we can afford
      for (var i = 0; i < 4; i++) {
        final b = buildings[i];
        if (b != null && canPlaceAt(seat, 'building_$i', 1) && canAffordBuilding(seat, b)) {
          return {'type': 'place', 'loc': 'building_$i', 'count': 1};
        }
      }
      // Check civ cards we can afford
      for (var i = 0; i < 4; i++) {
        if (canPlaceAt(seat, 'civ_$i', 1) && totalResourcesOf(seat) >= i + 1) {
          return {'type': 'place', 'loc': 'civ_$i', 'count': 1};
        }
      }
      // Gather resources
      for (final resLoc in const ['forest', 'brick', 'stone', 'gold']) {
        final capLeft = 7 - totalWorkersAt(resLoc);
        final cnt = min(avail, min(3, capLeft));
        if (cnt > 0 && canPlaceAt(seat, resLoc, cnt)) {
          return {'type': 'place', 'loc': resLoc, 'count': cnt};
        }
      }
    }

    // Fallback: send remaining workers to Hunt
    return {'type': 'place', 'loc': 'hunt', 'count': avail};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final breakdowns = [for (var s = 0; s < players; s++) scoreBreakdown(s)];
    return {
      'phase': over ? 'over' : phase,
      'turn': turn,
      'round': round,
      'maxRounds': maxRounds,
      'firstPlayer': firstPlayer,
      'placements': {
        for (final e in placements.entries)
          e.key: {for (final se in e.value.entries) '${se.key}': se.value},
      },
      'buildings': [for (final b in buildings) b?.toJson()],
      'civCards': [for (final c in civCards) c?.toJson()],
      'buildingDeckCount': buildingDeck.length,
      'civDeckCount': civDeck.length,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'food': food[s],
            'wood': wood[s],
            'brick': brick[s],
            'stone': stone[s],
            'gold': gold[s],
            'agri': agri[s],
            'tools': tools[s],
            'workers': workers[s],
            'availableWorkers': availableWorkers[s],
            'buildingsBuilt': buildingsBuilt[s],
            'greenSymbols': greenSymbols[s].toList()..sort(),
            'multipliers': multipliers[s],
            'score': breakdowns[s]['total'],
            'breakdown': breakdowns[s],
          },
      ],
      'placings': placings,
      'resigned': resignedSeat,
      'recent': recent,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    if (resignedSeat >= 0 && players == 2) {
      return rankWinners(players, [1 - resignedSeat]);
    }
    return rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]);
  }

  @override
  bool get canResign => players >= 2;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    resignedSeat = seat;
    over = true;
    phase = 'over';
    _log('${name(seat)} 认输');
  }
}
