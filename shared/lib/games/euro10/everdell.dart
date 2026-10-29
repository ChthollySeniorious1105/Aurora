import 'dart:math';

import '../../src/engine.dart';

/// 4 Resources in Everdell:
/// 0: 树枝 Twig 🪵, 1: 树脂 Resin 💧, 2: 鹅卵石 Pebble 🪨, 3: 浆果 Berry 🍓
const List<String> evResourceNames = ['树枝', '树脂', '鹅卵石', '浆果'];
const List<String> evResourceEmojis = ['🪵', '💧', '🪨', '🍓'];

/// 4 Seasons:
/// 0: 冬季 Winter, 1: 春季 Spring, 2: 夏季 Summer, 3: 秋季 Autumn
const List<String> evSeasonNames = ['冬季', '春季', '夏季', '秋季'];

class EvCard {
  final int id;
  final String name;
  final bool isCritter; // false = Construction 建筑, true = Critter 动物居民
  final bool unique; // true = Unique 独特, false = Common 普通
  final String category; // 'green' 绿生产, 'tan' 褐旅行, 'blue' 蓝治理, 'red' 红目的地, 'purple' 紫繁荣
  final List<int> cost; // [twig, resin, pebble, berry]
  final int vp;
  final String pairedName; // paired Critter (if Construction) or paired Construction (if Critter)
  final String effectCode;
  final String effectDesc;

  const EvCard({
    required this.id,
    required this.name,
    required this.isCritter,
    required this.unique,
    required this.category,
    required this.cost,
    required this.vp,
    required this.pairedName,
    required this.effectCode,
    required this.effectDesc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isCritter': isCritter,
        'unique': unique,
        'category': category,
        'cost': cost,
        'vp': vp,
        'pairedName': pairedName,
        'effectCode': effectCode,
        'effectDesc': effectDesc,
      };
}

class EvCitySlot {
  final int cardId;
  bool occupied; // for Construction: true once used to play its paired Critter for free

  EvCitySlot({required this.cardId, this.occupied = false});

  EvCard get card => evCards[cardId];

  Map<String, dynamic> toJson() => {
        ...card.toJson(),
        'cardId': cardId,
        'occupied': occupied,
      };
}

class EvLocation {
  final int id;
  final String name;
  final String desc;
  final bool shared; // true = multiple workers allowed

  const EvLocation(this.id, this.name, this.desc, {this.shared = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'desc': desc,
        'shared': shared,
      };
}

const List<EvLocation> evLocations = [
  EvLocation(0, '森林采集处', '获得 2🪵树枝 + 1💧树脂 + 1🍓浆果'),
  EvLocation(1, '树枝滩', '获得 3🪵树枝'),
  EvLocation(2, '树脂林', '获得 2💧树脂 + 抽 1 张牌'),
  EvLocation(3, '鹅卵石溪', '获得 1🪨鹅卵石 + 1🍓浆果'),
  EvLocation(4, '浆果丛', '获得 2🍓浆果 + 抽 1 张牌', shared: true),
  EvLocation(5, '避风港', '弃最多 2 张手牌并获得 1🪵 + 1🍓 + 抽 1 张牌', shared: true),
  EvLocation(6, '远征之旅', '秋季专属：弃 2 张手牌（若不足则全弃）获得 +4 远征分⭐', shared: true),
];

const List<EvCard> evCards = [
  // Pair 0 & 1: 农场 <-> 农夫
  EvCard(
    id: 0,
    name: '农场',
    isCritter: false,
    unique: false,
    category: 'green',
    cost: [2, 1, 0, 0],
    vp: 1,
    pairedName: '农夫',
    effectCode: 'prod_berry1',
    effectDesc: '生产：获得 1 个🍓浆果。可免费招募【农夫】。',
  ),
  EvCard(
    id: 1,
    name: '农夫',
    isCritter: true,
    unique: false,
    category: 'green',
    cost: [0, 0, 0, 2],
    vp: 2,
    pairedName: '农场',
    effectCode: 'prod_any1_vp1',
    effectDesc: '生产：获得 1🪵树枝与 1 分奖章（若已有农场则终局额外 +1 分）。',
  ),
  // Pair 2 & 3: 矿场 <-> 矿工鼹鼠
  EvCard(
    id: 2,
    name: '矿场',
    isCritter: false,
    unique: false,
    category: 'green',
    cost: [1, 1, 1, 0],
    vp: 2,
    pairedName: '矿工鼹鼠',
    effectCode: 'prod_pebble1',
    effectDesc: '生产：获得 1 个🪨鹅卵石。可免费招募【矿工鼹鼠】。',
  ),
  EvCard(
    id: 3,
    name: '矿工鼹鼠',
    isCritter: true,
    unique: false,
    category: 'green',
    cost: [0, 0, 0, 3],
    vp: 3,
    pairedName: '矿场',
    effectCode: 'prod_pebble1_twig1',
    effectDesc: '生产：获得 1🪨鹅卵石与 1🪵树枝。',
  ),
  // Pair 4 & 5: 树脂厂 <-> 树脂工
  EvCard(
    id: 4,
    name: '树脂厂',
    isCritter: false,
    unique: false,
    category: 'green',
    cost: [1, 1, 0, 0],
    vp: 1,
    pairedName: '树脂工',
    effectCode: 'prod_resin1',
    effectDesc: '生产：获得 1 个💧树脂。可免费招募【树脂工】。',
  ),
  EvCard(
    id: 5,
    name: '树脂工',
    isCritter: true,
    unique: false,
    category: 'green',
    cost: [0, 0, 0, 3],
    vp: 2,
    pairedName: '树脂厂',
    effectCode: 'prod_resin2',
    effectDesc: '生产：获得 2 个💧树脂。',
  ),
  // Pair 6 & 7: 客栈 <-> 旅店老板
  EvCard(
    id: 6,
    name: '客栈',
    isCritter: false,
    unique: false,
    category: 'red',
    cost: [2, 1, 0, 0],
    vp: 2,
    pairedName: '旅店老板',
    effectCode: 'inn_draw1_berry1',
    effectDesc: '目的地：打出时获得 1🍓浆果并抽 1 张牌。可免费招募【旅店老板】。',
  ),
  EvCard(
    id: 7,
    name: '旅店老板',
    isCritter: true,
    unique: true,
    category: 'blue',
    cost: [0, 0, 0, 1],
    vp: 1,
    pairedName: '客栈',
    effectCode: 'gov_berry1',
    effectDesc: '治理：打出时及后续每次打出动物时获得 1🍓浆果。',
  ),
  // Pair 8 & 9: 法院 <-> 法官
  EvCard(
    id: 8,
    name: '法院',
    isCritter: false,
    unique: true,
    category: 'blue',
    cost: [1, 1, 2, 0],
    vp: 2,
    pairedName: '法官',
    effectCode: 'gov_build_res',
    effectDesc: '治理：每次打出建筑时获得 1🪵树枝或 1💧树脂。可免费招募【法官】。',
  ),
  EvCard(
    id: 9,
    name: '法官',
    isCritter: true,
    unique: true,
    category: 'blue',
    cost: [0, 0, 0, 3],
    vp: 2,
    pairedName: '法院',
    effectCode: 'gov_vp1',
    effectDesc: '治理：每次打出卡牌时获得 +1 分奖章。',
  ),
  // Pair 10 & 11: 城堡 <-> 国王
  EvCard(
    id: 10,
    name: '城堡',
    isCritter: false,
    unique: true,
    category: 'purple',
    cost: [2, 3, 3, 0],
    vp: 4,
    pairedName: '国王',
    effectCode: 'pros_common_con',
    effectDesc: '繁荣：终局时城市中每座普通建筑额外 +1 分。可免费招募【国王】。',
  ),
  EvCard(
    id: 11,
    name: '国王',
    isCritter: true,
    unique: true,
    category: 'purple',
    cost: [0, 0, 0, 6],
    vp: 4,
    pairedName: '城堡',
    effectCode: 'pros_purple',
    effectDesc: '繁荣：终局时城市中每张紫色繁荣卡额外 +1 分，并立即得 +2 分奖章。',
  ),
  // Pair 12 & 13: 钟楼 <-> 历史学家
  EvCard(
    id: 12,
    name: '钟楼',
    isCritter: false,
    unique: true,
    category: 'blue',
    cost: [3, 0, 1, 0],
    vp: 0,
    pairedName: '历史学家',
    effectCode: 'clock_vp3',
    effectDesc: '治理：打出时获得 3 分奖章。可免费招募【历史学家】。',
  ),
  EvCard(
    id: 13,
    name: '历史学家',
    isCritter: true,
    unique: true,
    category: 'blue',
    cost: [0, 0, 0, 2],
    vp: 1,
    pairedName: '钟楼',
    effectCode: 'gov_draw1',
    effectDesc: '治理：每次打出卡牌后抽 1 张牌。',
  ),
  // Pair 14 & 15: 杂货铺 <-> 店主
  EvCard(
    id: 14,
    name: '杂货铺',
    isCritter: false,
    unique: false,
    category: 'green',
    cost: [1, 1, 1, 0],
    vp: 1,
    pairedName: '店主',
    effectCode: 'prod_berry2',
    effectDesc: '生产：获得 2 个🍓浆果。可免费招募【店主】。',
  ),
  EvCard(
    id: 15,
    name: '店主',
    isCritter: true,
    unique: true,
    category: 'blue',
    cost: [0, 0, 0, 2],
    vp: 1,
    pairedName: '杂货铺',
    effectCode: 'gov_berry1',
    effectDesc: '治理：每次打出动物后获得 1 个🍓浆果。',
  ),
  // Pair 16 & 17: 邮局 <-> 邮政鸽
  EvCard(
    id: 16,
    name: '邮局',
    isCritter: false,
    unique: false,
    category: 'red',
    cost: [1, 2, 0, 0],
    vp: 2,
    pairedName: '邮政鸽',
    effectCode: 'post_draw2',
    effectDesc: '目的地：打出时抽 2 张牌并获得 1🍓浆果。可免费招募【邮政鸽】。',
  ),
  EvCard(
    id: 17,
    name: '邮政鸽',
    isCritter: true,
    unique: false,
    category: 'tan',
    cost: [0, 0, 0, 2],
    vp: 0,
    pairedName: '邮局',
    effectCode: 'tan_vp2_draw1',
    effectDesc: '旅行：打出时获得 2 分奖章并抽 1 张牌。',
  ),
  // Pair 18 & 19: 学校 <-> 教师
  EvCard(
    id: 18,
    name: '学校',
    isCritter: false,
    unique: true,
    category: 'purple',
    cost: [2, 2, 0, 0],
    vp: 2,
    pairedName: '教师',
    effectCode: 'pros_common_crit',
    effectDesc: '繁荣：终局时城市中每名普通动物额外 +1 分。可免费招募【教师】。',
  ),
  EvCard(
    id: 19,
    name: '教师',
    isCritter: true,
    unique: false,
    category: 'green',
    cost: [0, 0, 0, 2],
    vp: 2,
    pairedName: '学校',
    effectCode: 'prod_draw1_berry1',
    effectDesc: '生产：抽 1 张牌并获得 1🍓浆果。',
  ),
  // Pair 20 & 21: 瞭望塔 <-> 流浪者
  EvCard(
    id: 20,
    name: '瞭望塔',
    isCritter: false,
    unique: true,
    category: 'red',
    cost: [1, 1, 1, 0],
    vp: 2,
    pairedName: '流浪者',
    effectCode: 'lookout_res',
    effectDesc: '目的地：打出时获得 1🪵 + 1💧 + 1🍓。可免费招募【流浪者】。',
  ),
  EvCard(
    id: 21,
    name: '流浪者',
    isCritter: true,
    unique: false,
    category: 'tan',
    cost: [0, 0, 0, 2],
    vp: 1,
    pairedName: '瞭望塔',
    effectCode: 'tan_draw3',
    effectDesc: '旅行：打出时抽 3 张牌。',
  ),
  // Pair 22 & 23: 剧场 <-> 吟游诗人
  EvCard(
    id: 22,
    name: '剧场',
    isCritter: false,
    unique: true,
    category: 'purple',
    cost: [3, 1, 1, 0],
    vp: 3,
    pairedName: '吟游诗人',
    effectCode: 'pros_unique_crit',
    effectDesc: '繁荣：终局时城市中每名独特动物额外 +1 分。可免费招募【吟游诗人】。',
  ),
  EvCard(
    id: 23,
    name: '吟游诗人',
    isCritter: true,
    unique: true,
    category: 'tan',
    cost: [0, 0, 0, 3],
    vp: 0,
    pairedName: '剧场',
    effectCode: 'tan_vp4',
    effectDesc: '旅行：歌咏传说，打出时立即获得 4 分奖章！',
  ),
];

const String everdellRules = '''
# 仙境幽谷 (Everdell)

## 游戏简介
《仙境幽谷》是一款极具童话意境的森林工人放置与卡牌城市构筑桌游。玩家带领小动物工人在永恒之树下收集资源、建造建筑、招募动物居民，在从冬季到秋季的四季更迭中建设最多 15 张卡牌的梦幻幽谷城市。

## 核心资源与区域
- **4 种资源**：0 树枝 🪵、1 树脂 💧、2 鹅卵石 🪨、3 浆果 🍓（建筑主要消耗树枝/树脂/鹅卵石，动物居民消耗浆果）。
- **中央草地 (`meadow[0..7]`)**：始终展示 8 张公共卡牌；玩家既可从手牌打牌，也可直接从草地打牌（打出后立即从牌库补满 8 张）。
- **工人行动点 (`locations`)**：包括森林采集处、树枝滩、树脂林、鹅卵石溪、浆果丛、避风港以及秋季专属的【远征之旅】。
- **个人城市 (`city[seat]`)**：每位玩家的城市最多容纳 15 张卡牌。

## 建筑—动物免费配对联动 (Critter-Construction Pairing)
每座建筑都有其专属配对的动物居民（如：`农场 ↔ 农夫`、`矿场 ↔ 矿工鼹鼠`、`树脂厂 ↔ 树脂工`、`客栈 ↔ 旅店老板`、`法院 ↔ 法官`、`城堡 ↔ 国王`、`钟楼 ↔ 历史学家` 等）。
若你的城市中已建有某座**未占用 (`occupied == false`)** 的配对建筑，你可以将该建筑标记为已占用 (`occupied = true`)，从而**免费（0 浆果）**将对应的动物居民招募进城！

## 回合行动（三选一）
轮到你时，可执行以下 3 项行动之一：
1. **放置工人 (`place_worker`)**：将 1 名可用工人派往某个行动点，获取对应的资源、手牌或远征分数。
2. **打出卡牌 (`play_card`)**：从手牌 (`hand`) 或中央草地 (`meadow`) 选择一张卡牌，支付其费用（或使用配对建筑免费招募动物）打入城市，并立即触发其生产/旅行/治理效果。
3. **准备换季 (`prepare_season`)**：当你的可用工人全部派完后，可选择准备换季：
   - **进入春季 (Season 1)**：收回所有已放置工人，新增 `+1` 名工人（共 3 名），并激活城市中所有**绿色生产卡 (`green`)**！
   - **进入夏季 (Season 2)**：收回所有已放置工人，新增 `+1` 名工人（共 4 名），并从草地免费抽取最多 2 张卡牌！
   - **进入秋季 (Season 3)**：收回所有已放置工人，新增 `+2` 名工人（共 6 名），并激活城市中所有**绿色生产卡 (`green`)**！
   - **秋季结束**：在秋季完成所有操作后选择结束本局 (`finished = true`)。

## 终局计分
当所有玩家均完成秋季后游戏结束，总分由 **城市卡牌基础分 + 紫色繁荣卡额外奖励分 + 分数奖章 (`pointTokens`) + 远征分数 (`journeyVp`)** 构成，最高者获胜！
''';

class Everdell extends GameEngine {
  Everdell(super.setup);

  int turn = 0;
  bool over = false;

  List<int> deck = [];
  List<int> meadow = [];
  late List<List<int>> hand;
  late List<List<int>> resources; // [twig, resin, pebble, berry]
  late List<List<EvCitySlot>> city;
  late List<int> season; // 0..3
  late List<int> workersTotal;
  late List<int> workersAvail;
  late List<List<int>> workerLocs; // locations currently occupied by seat's workers
  late List<int> pointTokens;
  late List<int> journeyVp;
  late List<bool> finished;
  String lastAction = '仙境幽谷开启，凛冬将尽，万物待兴！';

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    for (var i = 0; i < players; i++) {
      final s = (turn + i) % players;
      if (!finished[s]) return [s];
    }
    return const [];
  }

  @override
  List<int>? get placings => over ? rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]) : null;

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    // Build deck (3 copies of common cards, 2 copies of unique cards)
    final raw = <int>[];
    for (final c in evCards) {
      final copies = c.unique ? 2 : 3;
      for (var k = 0; k < copies; k++) {
        raw.add(c.id);
      }
    }
    deck = shuffled(raw, rng);
    meadow = [for (var i = 0; i < 8; i++) _drawCard()];

    hand = List.generate(players, (_) => <int>[]);
    resources = List.generate(
      players,
      (_) => fast ? [2, 2, 1, 2] : [2, 1, 1, 2],
    );
    city = List.generate(players, (_) => <EvCitySlot>[]);
    season = List.filled(players, fast ? 1 : 0);
    workersTotal = List.filled(players, fast ? 3 : 2);
    workersAvail = List.filled(players, fast ? 3 : 2);
    workerLocs = List.generate(players, (_) => <int>[]);
    pointTokens = List.filled(players, 0);
    journeyVp = List.filled(players, 0);
    finished = List.filled(players, false);

    for (var s = 0; s < players; s++) {
      final count = min(8, 5 + s);
      for (var i = 0; i < count; i++) {
        hand[s].add(_drawCard());
      }
    }
    turn = 0;
  }

  int _drawCard() {
    if (deck.isEmpty) {
      deck = shuffled([for (var i = 0; i < evCards.length; i++) i], rng);
    }
    return deck.removeLast();
  }

  void _refillMeadow() {
    while (meadow.length < 8) {
      meadow.add(_drawCard());
    }
  }

  void _addHand(int seat, int count) {
    for (var i = 0; i < count; i++) {
      if (hand[seat].length < 8) {
        hand[seat].add(_drawCard());
      }
    }
  }

  bool isLocationAvailable(int seat, int locId) {
    if (locId < 0 || locId >= evLocations.length) return false;
    final loc = evLocations[locId];
    if (locId == 6 && season[seat] < 3) return false; // Journey only in Autumn
    if (loc.shared) return true;
    for (var s = 0; s < players; s++) {
      if (workerLocs[s].contains(locId)) return false;
    }
    return true;
  }

  int findUnoccupiedPairIndex(int seat, EvCard critter) {
    if (!critter.isCritter) return -1;
    for (var i = 0; i < city[seat].length; i++) {
      final slot = city[seat][i];
      if (!slot.occupied && slot.card.name == critter.pairedName) {
        return i;
      }
    }
    return -1;
  }

  bool canAffordCard(int seat, EvCard card, {bool allowPair = true}) {
    if (city[seat].length >= 15) return false;
    if (card.unique && city[seat].any((s) => s.cardId == card.id)) {
      return false;
    }
    if (card.isCritter && allowPair && findUnoccupiedPairIndex(seat, card) >= 0) {
      return true;
    }
    for (var r = 0; r < 4; r++) {
      if (resources[seat][r] < card.cost[r]) return false;
    }
    return true;
  }

  void _triggerCardEffect(int seat, EvCard card) {
    switch (card.effectCode) {
      case 'prod_berry1':
        resources[seat][3] += 1;
      case 'prod_any1_vp1':
        resources[seat][0] += 1;
        pointTokens[seat] += 1;
      case 'prod_pebble1':
        resources[seat][2] += 1;
      case 'prod_pebble1_twig1':
        resources[seat][2] += 1;
        resources[seat][0] += 1;
      case 'prod_resin1':
        resources[seat][1] += 1;
      case 'prod_resin2':
        resources[seat][1] += 2;
      case 'prod_berry2':
        resources[seat][3] += 2;
      case 'prod_draw1_berry1':
        resources[seat][3] += 1;
        _addHand(seat, 1);
      case 'inn_draw1_berry1':
        resources[seat][3] += 1;
        _addHand(seat, 1);
      case 'gov_berry1':
        resources[seat][3] += 1;
      case 'clock_vp3':
        pointTokens[seat] += 3;
      case 'post_draw2':
        resources[seat][3] += 1;
        _addHand(seat, 2);
      case 'tan_vp2_draw1':
        pointTokens[seat] += 2;
        _addHand(seat, 1);
      case 'lookout_res':
        resources[seat][0] += 1;
        resources[seat][1] += 1;
        resources[seat][3] += 1;
      case 'tan_draw3':
        _addHand(seat, 3);
      case 'tan_vp4':
        pointTokens[seat] += 4;
      case 'pros_purple':
        pointTokens[seat] += 2;
    }
  }

  void _triggerGovernanceOnPlay(int seat, EvCard played) {
    for (final slot in city[seat]) {
      final c = slot.card;
      if (c.effectCode == 'gov_build_res' && !played.isCritter) {
        resources[seat][0] += 1;
      } else if (c.effectCode == 'gov_vp1') {
        pointTokens[seat] += 1;
      } else if (c.effectCode == 'gov_draw1') {
        _addHand(seat, 1);
      } else if (c.effectCode == 'gov_berry1' && played.isCritter && c.id != played.id) {
        resources[seat][3] += 1;
      }
    }
  }

  void _activateGreenProduction(int seat) {
    for (final slot in city[seat]) {
      if (slot.card.category == 'green') {
        _triggerCardEffect(seat, slot.card);
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players || finished[seat]) throw GameError('你已完成所有季节');
    if (waitingFor.isNotEmpty && seat != waitingFor.first) {
      throw GameError('还没轮到你行动');
    }

    final type = asStr(action['type']);
    switch (type) {
      case 'place_worker':
        if (workersAvail[seat] <= 0) throw GameError('没有可用的工人，请打出卡牌或准备换季');
        final locId = asInt(action['loc'], -1);
        if (!isLocationAvailable(seat, locId)) {
          throw GameError('该行动点当前不可用或已被占用');
        }
        workersAvail[seat]--;
        workerLocs[seat].add(locId);
        switch (locId) {
          case 0: // 森林采集处
            resources[seat][0] += 2;
            resources[seat][1] += 1;
            resources[seat][3] += 1;
          case 1: // 树枝滩
            resources[seat][0] += 3;
          case 2: // 树脂林
            resources[seat][1] += 2;
            _addHand(seat, 1);
          case 3: // 鹅卵石溪
            resources[seat][2] += 1;
            resources[seat][3] += 1;
          case 4: // 浆果丛
            resources[seat][3] += 2;
            _addHand(seat, 1);
          case 5: // 避风港
            final discardCount = min(2, hand[seat].length);
            for (var i = 0; i < discardCount; i++) {
              hand[seat].removeLast();
            }
            resources[seat][0] += 1;
            resources[seat][3] += 1;
            _addHand(seat, 1);
          case 6: // 远征之旅
            final discardCount = min(2, hand[seat].length);
            for (var i = 0; i < discardCount; i++) {
              hand[seat].removeLast();
            }
            journeyVp[seat] += 4;
        }
        lastAction = '${name(seat)} 派遣工人前往【${evLocations[locId].name}】';
        _advanceTurn(seat);

      case 'play_card':
        if (city[seat].length >= 15) throw GameError('城市已满 15 张卡牌上限');
        final source = asStr(action['source'], 'hand');
        final idx = asInt(action['idx'], -1);
        int cardId;
        if (source == 'meadow') {
          if (idx < 0 || idx >= meadow.length) throw GameError('无效的草地卡牌索引');
          cardId = meadow[idx];
        } else {
          if (idx < 0 || idx >= hand[seat].length) throw GameError('无效的手牌索引');
          cardId = hand[seat][idx];
        }
        final card = evCards[cardId];
        if (card.unique && city[seat].any((s) => s.cardId == card.id)) {
          throw GameError('城市中已有独特卡牌【${card.name}】');
        }

        final wantPair = action['usePair'] != false;
        final pairIdx = (card.isCritter && wantPair) ? findUnoccupiedPairIndex(seat, card) : -1;
        if (pairIdx >= 0) {
          city[seat][pairIdx].occupied = true;
        } else {
          for (var r = 0; r < 4; r++) {
            if (resources[seat][r] < card.cost[r]) {
              throw GameError('资源不足，无法打出【${card.name}】');
            }
          }
          for (var r = 0; r < 4; r++) {
            resources[seat][r] -= card.cost[r];
          }
        }

        if (source == 'meadow') {
          meadow[idx] = _drawCard();
          _refillMeadow();
        } else {
          hand[seat].removeAt(idx);
        }

        city[seat].add(EvCitySlot(cardId: cardId));
        _triggerCardEffect(seat, card);
        _triggerGovernanceOnPlay(seat, card);
        lastAction = pairIdx >= 0
            ? '${name(seat)} 通过【${card.pairedName}】免费招募了【${card.name}】！'
            : '${name(seat)} 在城市中打出了【${card.name}】';
        _advanceTurn(seat);

      case 'prepare_season':
      case 'pass':
        if (season[seat] < 3) {
          // Recall workers and advance season
          workerLocs[seat].clear();
          season[seat]++;
          if (season[seat] == 1) {
            // Spring: +1 worker & activate green production
            workersTotal[seat] += 1;
            workersAvail[seat] = workersTotal[seat];
            _activateGreenProduction(seat);
            lastAction = '${name(seat)} 迎来春季🌸：收回工人，新增 1 名工人并触发所有绿色生产卡！';
          } else if (season[seat] == 2) {
            // Summer: +1 worker & draw 2 cards from meadow
            workersTotal[seat] += 1;
            workersAvail[seat] = workersTotal[seat];
            for (var i = 0; i < 2 && hand[seat].length < 8; i++) {
              if (meadow.isNotEmpty) {
                hand[seat].add(meadow.removeAt(0));
                _refillMeadow();
              }
            }
            lastAction = '${name(seat)} 迎来夏季☀️：收回工人，新增 1 名工人并从草地抽取卡牌！';
          } else if (season[seat] == 3) {
            // Autumn: +2 workers & activate green production
            workersTotal[seat] += 2;
            workersAvail[seat] = workersTotal[seat];
            _activateGreenProduction(seat);
            lastAction = '${name(seat)} 迎来秋季🍂：收回工人，新增 2 名工人并触发所有绿色生产卡！';
          }
        } else {
          finished[seat] = true;
          lastAction = '${name(seat)} 结束了秋季建设，当前总分 ${scoreOf(seat)} 分';
        }
        _advanceTurn(seat);

      default:
        throw GameError('未知的仙境幽谷行动: $type');
    }
  }

  void _advanceTurn(int actedSeat) {
    for (var i = 1; i <= players; i++) {
      final next = (actedSeat + i) % players;
      if (!finished[next]) {
        turn = next;
        return;
      }
    }
    over = true;
    host.log('仙境幽谷结束！最终得分：${[for (var s = 0; s < players; s++) '${name(s)} ${scoreOf(s)}分'].join('，')}');
  }

  int cardBaseScore(int seat) => city[seat].fold(0, (s, slot) => s + slot.card.vp);

  int prosperityBonusScore(int seat) {
    var bonus = 0;
    final hasFarm = city[seat].any((s) => s.cardId == 0);
    for (final slot in city[seat]) {
      final c = slot.card;
      if (c.id == 1 && hasFarm) {
        bonus += 1;
      } else if (c.effectCode == 'pros_common_con') {
        bonus += city[seat].where((x) => !x.card.isCritter && !x.card.unique).length;
      } else if (c.effectCode == 'pros_purple') {
        bonus += city[seat].where((x) => x.card.category == 'purple').length;
      } else if (c.effectCode == 'pros_common_crit') {
        bonus += city[seat].where((x) => x.card.isCritter && !x.card.unique).length;
      } else if (c.effectCode == 'pros_unique_crit') {
        bonus += city[seat].where((x) => x.card.isCritter && x.card.unique).length;
      }
    }
    return bonus;
  }

  int scoreOf(int seat) =>
      cardBaseScore(seat) + prosperityBonusScore(seat) + pointTokens[seat] + journeyVp[seat];

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': waitingFor.isEmpty ? turn : waitingFor.first,
      'over': over,
      'lastAction': lastAction,
      'deckCount': deck.length,
      'meadow': [for (final id in meadow) evCards[id].toJson()],
      'meadowIds': meadow,
      'locations': [
        for (final loc in evLocations)
          {
            ...loc.toJson(),
            'occupants': [
              for (var s = 0; s < players; s++)
                for (final l in workerLocs[s])
                  if (l == loc.id) s,
            ],
          },
      ],
      'season': season,
      'workersTotal': workersTotal,
      'workersAvail': workersAvail,
      'workerLocs': workerLocs,
      'resources': resources,
      'city': [
        for (var s = 0; s < players; s++) [for (final slot in city[s]) slot.toJson()],
      ],
      'hand': seat >= 0 && seat < players ? [for (final id in hand[seat]) evCards[id].toJson()] : const [],
      'handIds': seat >= 0 && seat < players ? hand[seat] : const [],
      'handCounts': [for (var s = 0; s < players; s++) hand[s].length],
      'pointTokens': pointTokens,
      'journeyVp': journeyVp,
      'finished': finished,
      'scores': [for (var s = 0; s < players; s++) scoreOf(s)],
      'breakdown': [
        for (var s = 0; s < players; s++)
          {
            'cards': cardBaseScore(s),
            'prosperity': prosperityBonusScore(s),
            'tokens': pointTokens[s],
            'journey': journeyVp[s],
            'total': scoreOf(s),
          },
      ],
    };
  }

  int pointTokensOf(int s) => pointTokens[s];

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || finished[seat]) return null;

    // 1. Try playing a free paired Critter or affordable high-value card from meadow or hand
    if (city[seat].length < 15) {
      for (var i = 0; i < meadow.length; i++) {
        final c = evCards[meadow[i]];
        if (canAffordCard(seat, c)) {
          return {'type': 'play_card', 'source': 'meadow', 'idx': i};
        }
      }
      for (var i = 0; i < hand[seat].length; i++) {
        final c = evCards[hand[seat][i]];
        if (canAffordCard(seat, c)) {
          return {'type': 'play_card', 'source': 'hand', 'idx': i};
        }
      }
    }

    // 2. If workers available, place a worker on the best available location
    if (workersAvail[seat] > 0) {
      if (season[seat] == 3 && city[seat].length >= 10 && isLocationAvailable(seat, 6)) {
        return {'type': 'place_worker', 'loc': 6};
      }
      for (final locId in const [0, 3, 2, 1, 4, 5, 6]) {
        if (isLocationAvailable(seat, locId)) {
          return {'type': 'place_worker', 'loc': locId};
        }
      }
    }

    // 3. Prepare for next season (or finish in Autumn)
    return {'type': 'prepare_season'};
  }
}
