import '../../src/engine.dart';

const String bohnanzaRules = '''
# 种豆得豆 Bohnanza 规则

## 概述
《种豆得豆》（Bohnanza）是乌玫瑰山（Uwe Rosenberg）设计的殿堂级德式卡牌经典，支持 2～5 人游玩。游戏的核心灵魂在于 **“手牌顺序绝对锁定”** —— 你永远只能打出左手第 1 张牌（`hand[0]`），摸到的新牌也永远只能放到手牌最末尾！

## 八大豆子品种与收获表（Bohdometer）
整副牌共 **104 张豆子牌**，卡牌张数越稀少，变现金币所需的颗数就越少：
- `0` **花园豆（Garden Bean，共 6 张）**：2 颗 = 2 金币，3 颗 = 3 金币
- `1` **红豆（Red Bean，共 8 张）**：2 颗 = 1 金，3 颗 = 2 金，4 颗 = 3 金，5 颗 = 4 金
- `2` **乌眼豆（Black-Eyed Bean，共 10 张）**：2 颗 = 1 金，4 颗 = 2 金，5 颗 = 3 金，6 颗 = 4 金
- `3` **大豆（Soy Bean，共 12 张）**：2 颗 = 1 金，4 颗 = 2 金，6 颗 = 3 金，7 颗 = 4 金
- `4` **绿豆（Green Bean，共 14 张）**：3 颗 = 1 金，5 颗 = 2 金，6 颗 = 3 金，7 颗 = 4 金
- `5` **臭豆（Stink Bean，共 16 张）**：3 颗 = 1 金，5 颗 = 2 金，7 颗 = 3 金，8 颗 = 4 金
- `6` **辣椒豆（Chili Bean，共 18 张）**：3 颗 = 1 金，6 颗 = 2 金，8 颗 = 3 金，9 颗 = 4 金
- `7` **蓝豆（Blue Bean，共 20 张）**：4 颗 = 1 金，6 颗 = 2 金，8 颗 = 3 金，10 颗 = 4 金

## 黄金铁律与护豆规则
1. **手牌顺序锁定（Golden Rule）**：任何时候不得调换手牌顺序！种豆只能种手牌最前面的第 1 张（`hand[0]`），回合末摸牌一律塞进手牌最末尾（`hand.add`）。
2. **豆田限制与扩建**：每位玩家开局拥有 **2 块豆田**（可花费 `3` 枚金币购买 **第 3 块豆田**）。每块豆田同一时间只能种植同一种类的豆子。
3. **护豆规则（Bean Protection Rule）**：你可以随时收割自己的某块豆田腾出空位，但 **只要你名下有任何一块豆田里有 `>= 2` 颗豆子，你就绝不能收割只有 `1` 颗豆子的豆田**！

## 回合流程
1. **阶段一：种手牌豆（`plant`）**：
   - 你 **必须** 将当前第 1 张手牌（`hand[0]`）种入空田或同品种豆田（若无合适豆田，必须先按护豆规则收割一块豆田）。
   - 种下第 1 张后，你可以 **自选** 是否继续种新的第 1 张手牌（最多共种 2 张），或点击结束种豆（`done_plant`）。
2. **阶段二：集市翻牌与赠换（`market`）**：
   - 从牌库顶翻开 **2 张豆子牌** 放入集市（`market[0..1]`）。
   - 当前玩家可以将集市豆子种入自己的豆田，或 **赠送/交换（`gift_market`）** 给其他玩家种下（所有集市豆子都必须被种入豆田）。
3. **阶段三：后置补牌**：
   - 集市豆子全部安置完毕后，当前玩家从牌库摸 **3 张牌** 依次放入手牌 **最末尾**，回合结束。
   - 当牌库耗尽达到设定轮数时，全员自动收割所有剩余豆田，金币最多者获胜！
''';

class BeanVariety {
  final int id;
  final String nameZh;
  final String nameEn;
  final String emoji;
  final int totalCards;

  /// Minimum bean count required for [1G, 2G, 3G, 4G] (null = tier not available).
  final List<int?> thresholds;

  const BeanVariety({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    required this.emoji,
    required this.totalCards,
    required this.thresholds,
  });
}

const List<BeanVariety> kBeanVarieties = [
  BeanVariety(
    id: 0,
    nameZh: '花园豆',
    nameEn: 'Garden Bean',
    emoji: '🌸',
    totalCards: 6,
    thresholds: [null, 2, 3, null],
  ),
  BeanVariety(
    id: 1,
    nameZh: '红豆',
    nameEn: 'Red Bean',
    emoji: '🫘',
    totalCards: 8,
    thresholds: [2, 3, 4, 5],
  ),
  BeanVariety(
    id: 2,
    nameZh: '乌眼豆',
    nameEn: 'Black-Eyed',
    emoji: '👁️',
    totalCards: 10,
    thresholds: [2, 4, 5, 6],
  ),
  BeanVariety(
    id: 3,
    nameZh: '大豆',
    nameEn: 'Soy Bean',
    emoji: '🌾',
    totalCards: 12,
    thresholds: [2, 4, 6, 7],
  ),
  BeanVariety(
    id: 4,
    nameZh: '绿豆',
    nameEn: 'Green Bean',
    emoji: '🫛',
    totalCards: 14,
    thresholds: [3, 5, 6, 7],
  ),
  BeanVariety(
    id: 5,
    nameZh: '臭豆',
    nameEn: 'Stink Bean',
    emoji: '🍄',
    totalCards: 16,
    thresholds: [3, 5, 7, 8],
  ),
  BeanVariety(
    id: 6,
    nameZh: '辣椒豆',
    nameEn: 'Chili Bean',
    emoji: '🌶️',
    totalCards: 18,
    thresholds: [3, 6, 8, 9],
  ),
  BeanVariety(
    id: 7,
    nameZh: '蓝豆',
    nameEn: 'Blue Bean',
    emoji: '🫐',
    totalCards: 20,
    thresholds: [4, 6, 8, 10],
  ),
];

/// Calculates how much Gold is earned when harvesting [count] beans of variety [beanId].
int bohnanzaHarvestGold(int beanId, int count) {
  if (beanId < 0 || beanId >= kBeanVarieties.length || count <= 0) return 0;
  final th = kBeanVarieties[beanId].thresholds;
  var gold = 0;
  for (var g = 0; g < th.length; g++) {
    final req = th[g];
    if (req != null && count >= req) {
      gold = g + 1;
    }
  }
  return gold;
}

List<int> buildBohnanzaDeck() => [
      for (final v in kBeanVarieties)
        for (var i = 0; i < v.totalCards; i++) v.id,
    ];

class BohnanzaGame extends GameEngine {
  late int maxCycles;
  int currentCycle = 1;
  int turn = 0;

  /// `'plant'` (Step 1) or `'market'` (Step 2).
  String step = 'plant';
  String get phase => step;
  set phase(String v) => step = v;

  int plantedThisTurn = 0;

  late List<List<int>> hands;
  late List<List<List<int>>> fields;
  late List<int> gold;
  late List<int> deck;
  late List<int> discardPile;
  List<int> market = [];

  bool _over = false;

  BohnanzaGame(super.setup) {
    maxCycles = setup.opt<int>('deckCycles', 1);
    gold = List.filled(players, 0);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(gold) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final all = shuffled(buildBohnanzaDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++) all.sublist(s * 5, (s + 1) * 5),
    ];
    fields = [
      for (var s = 0; s < players; s++) [<int>[], <int>[]],
    ];
    deck = all.sublist(players * 5);
    discardPile = [];
    market = [];
    turn = 0;
    step = 'plant';
    plantedThisTurn = 0;
    host.log('种豆得豆开始！手牌顺序严格锁定，每人起始 5 张豆牌与 2 块豆田。');
  }

  /// Checks if field [f] of [seat] can be legally harvested (Bean Protection Rule).
  bool canHarvestField(int seat, int f) {
    if (seat < 0 || seat >= players) return false;
    final pFields = fields[seat];
    if (f < 0 || f >= pFields.length) return false;
    if (pFields[f].isEmpty) return false;
    if (pFields[f].length == 1 && pFields.any((fld) => fld.length >= 2)) {
      return false;
    }
    return true;
  }

  /// Checks if [bean] can be planted directly into field [f] of [seat].
  bool canPlantInField(int seat, int f, int bean) {
    if (seat < 0 || seat >= players) return false;
    final pFields = fields[seat];
    if (f < 0 || f >= pFields.length) return false;
    return pFields[f].isEmpty || pFields[f].first == bean;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    final type = asStr(action['type']);

    if (type == 'buy_field') {
      if (fields[seat].length >= 3) {
        throw GameError('每人最多只能拥有 3 块豆田');
      }
      if (gold[seat] < 3) {
        throw GameError('购买第 3 块豆田需要 3 枚金币');
      }
      gold[seat] -= 3;
      fields[seat].add(<int>[]);
      host.log('${name(seat)} 花费 3 金币扩建了第 3 块豆田！');
      return;
    }

    if (type == 'harvest') {
      final f = asInt(action['field']);
      _harvestField(seat, f);
      return;
    }

    if (step == 'plant') {
      _handlePlantStep(seat, type, action);
      return;
    }
    if (step == 'market') {
      _handleMarketStep(seat, type, action);
      return;
    }
    throw GameError('未知阶段');
  }

  void _harvestField(int seat, int f) {
    if (f < 0 || f >= fields[seat].length) {
      throw GameError('无效的豆田编号');
    }
    final fld = fields[seat][f];
    if (fld.isEmpty) {
      throw GameError('该豆田为空，无法收割');
    }
    if (fld.length == 1 && fields[seat].any((other) => other.length >= 2)) {
      throw GameError('护豆规则：存在至少 2 颗豆子的豆田时，不能收割只有 1 颗豆子的豆田！');
    }
    final bean = fld.first;
    final count = fld.length;
    final earned = bohnanzaHarvestGold(bean, count);
    gold[seat] += earned;
    final discarded = count - earned;
    for (var i = 0; i < discarded; i++) {
      discardPile.add(bean);
    }
    fld.clear();
    host.log(
      '${name(seat)} 收割了 $count 颗${kBeanVarieties[bean].nameZh}，获得 +$earned 金币',
    );
  }

  void _handlePlantStep(int seat, String type, Map<String, dynamic> action) {
    if (type == 'done_plant') {
      if (plantedThisTurn < 1 && hands[seat].isNotEmpty) {
        throw GameError('每回合必须至少种下第 1 张手牌（hand[0]）');
      }
      _enterMarketStep();
      return;
    }

    if (type == 'plant') {
      if (hands[seat].isEmpty) {
        throw GameError('手牌已空，无法继续种豆');
      }
      if (plantedThisTurn >= 2) {
        throw GameError('每回合最多只能种 2 张手牌');
      }
      final f = asInt(action['field']);
      if (f < 0 || f >= fields[seat].length) {
        throw GameError('无效的豆田编号');
      }
      final bean = hands[seat].first; // Strictly hand[0]!
      if (!canPlantInField(seat, f, bean)) {
        throw GameError('该豆田已种有不同品种的豆子，请先收割或选择其他豆田');
      }
      hands[seat].removeAt(0);
      fields[seat][f].add(bean);
      plantedThisTurn++;
      host.log('${name(seat)} 在豆田 ${f + 1} 种下了 1 颗${kBeanVarieties[bean].nameZh}');

      if (plantedThisTurn >= 2 || hands[seat].isEmpty) {
        _enterMarketStep();
      }
      return;
    }

    throw GameError('种豆阶段请使用 plant、harvest、buy_field 或 done_plant');
  }

  void _enterMarketStep() {
    step = 'market';
    market = [];
    for (var i = 0; i < 2; i++) {
      final c = _drawOneFromDeck();
      if (c != null) market.add(c);
    }
    if (market.isEmpty) {
      _finishTurnAndDraw();
    }
  }

  void _handleMarketStep(int seat, String type, Map<String, dynamic> action) {
    if (type == 'done_plant') {
      // Friendly no-op if called right after 2nd plant auto-advanced to market
      return;
    }

    if (type == 'plant_market' || type == 'plant') {
      if (market.isEmpty) {
        _finishTurnAndDraw();
        return;
      }
      final idx = asInt(action['index'], 0).clamp(0, market.length - 1);
      final f = asInt(action['field']);
      if (f < 0 || f >= fields[seat].length) {
        throw GameError('无效的豆田编号');
      }
      final bean = market[idx];
      if (!canPlantInField(seat, f, bean)) {
        throw GameError('该豆田已种有其他品种豆子，请先收割或选择匹配豆田');
      }
      market.removeAt(idx);
      fields[seat][f].add(bean);
      host.log('${name(seat)} 将集市的${kBeanVarieties[bean].nameZh}种入豆田 ${f + 1}');
      if (market.isEmpty) {
        _finishTurnAndDraw();
      }
      return;
    }

    if (type == 'gift_market' || type == 'swap_market') {
      if (market.isEmpty) {
        _finishTurnAndDraw();
        return;
      }
      final idx = asInt(action['index'], 0).clamp(0, market.length - 1);
      final target = asInt(action['target'], (seat + 1) % players);
      if (target < 0 || target >= players || target == seat) {
        throw GameError('请选择一名其他玩家作为赠换对象');
      }
      final bean = market.removeAt(idx);
      _autoPlantOnSeat(target, bean);
      host.log('${name(seat)} 将集市的${kBeanVarieties[bean].nameZh}赠予 ${name(target)} 种下');
      if (market.isEmpty) {
        _finishTurnAndDraw();
      }
      return;
    }

    throw GameError('集市阶段请使用 plant_market、gift_market 或 harvest');
  }

  void _autoPlantOnSeat(int seat, int bean) {
    // 1. Matching field
    for (var f = 0; f < fields[seat].length; f++) {
      if (fields[seat][f].isNotEmpty && fields[seat][f].first == bean) {
        fields[seat][f].add(bean);
        return;
      }
    }
    // 2. Empty field
    for (var f = 0; f < fields[seat].length; f++) {
      if (fields[seat][f].isEmpty) {
        fields[seat][f].add(bean);
        return;
      }
    }
    // 3. Harvest a legal field and plant
    var bestField = 0;
    for (var f = 0; f < fields[seat].length; f++) {
      if (canHarvestField(seat, f)) {
        bestField = f;
        break;
      }
    }
    _harvestField(seat, bestField);
    fields[seat][bestField].add(bean);
  }

  void _finishTurnAndDraw() {
    // Draw 3 cards to the BACK of active player's hand
    for (var i = 0; i < 3; i++) {
      final c = _drawOneFromDeck();
      if (c == null) break;
      hands[turn].add(c);
    }

    if (deck.isEmpty && currentCycle >= maxCycles) {
      _endGameHarvestAll();
      return;
    }

    turn = (turn + 1) % players;
    step = 'plant';
    plantedThisTurn = 0;
    if (hands[turn].isEmpty) {
      _enterMarketStep();
    }
  }

  int? _drawOneFromDeck() {
    if (deck.isEmpty) {
      if (currentCycle < maxCycles && discardPile.isNotEmpty) {
        currentCycle++;
        deck = shuffled(discardPile, rng);
        discardPile = [];
        host.log('牌库已重洗，进入第 $currentCycle/$maxCycles 轮牌库');
      } else {
        return null;
      }
    }
    if (deck.isEmpty) return null;
    return deck.removeLast();
  }

  void _endGameHarvestAll() {
    for (var s = 0; s < players; s++) {
      for (var f = 0; f < fields[s].length; f++) {
        final fld = fields[s][f];
        if (fld.isNotEmpty) {
          final bean = fld.first;
          final count = fld.length;
          gold[s] += bohnanzaHarvestGold(bean, count);
          fld.clear();
        }
      }
    }
    _over = true;
    host.log(
      '牌库耗尽，全员收割结算：${[for (var s = 0; s < players; s++) '${name(s)} ${gold[s]}金币'].join('，')}',
    );
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'step': step,
        'phase': step,
        'turn': turn,
        'plantedThisTurn': plantedThisTurn,
        'currentCycle': currentCycle,
        'maxCycles': maxCycles,
        'deckCount': deck.length,
        'discardCount': discardPile.length,
        'gold': List<int>.of(gold),
        'handCounts': [for (final h in hands) h.length],
        'myHand': seat >= 0 && seat < players
            ? List<int>.of(hands[seat])
            : const <int>[],
        'fields': [
          for (final pFields in fields)
            [for (final fld in pFields) List<int>.of(fld)],
        ],
        'market': List<int>.of(market),
      };

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (step == 'plant') {
      if (hands[seat].isEmpty) {
        return {'type': 'done_plant'};
      }
      final firstBean = hands[seat].first;

      // Try matching field first
      for (var f = 0; f < fields[seat].length; f++) {
        if (fields[seat][f].isNotEmpty && fields[seat][f].first == firstBean) {
          return {'type': 'plant', 'field': f};
        }
      }

      // If already planted 1 card and new hand[0] doesn't match an existing field,
      // only plant into an empty field; otherwise stop planting!
      for (var f = 0; f < fields[seat].length; f++) {
        if (fields[seat][f].isEmpty) {
          return {'type': 'plant', 'field': f};
        }
      }

      if (plantedThisTurn >= 1) {
        return {'type': 'done_plant'};
      }

      // Must plant at least 1 card: consider buying 3rd field if affordable, else harvest a legal field
      if (fields[seat].length < 3 && gold[seat] >= 3 && botLevel >= 1) {
        return {'type': 'buy_field'};
      }

      var bestHarvest = -1;
      var bestGold = -1;
      for (var f = 0; f < fields[seat].length; f++) {
        if (!canHarvestField(seat, f)) continue;
        final fld = fields[seat][f];
        final g = bohnanzaHarvestGold(fld.first, fld.length);
        if (g > bestGold) {
          bestGold = g;
          bestHarvest = f;
        }
      }
      return {'type': 'harvest', 'field': bestHarvest >= 0 ? bestHarvest : 0};
    }

    if (step == 'market') {
      if (market.isEmpty) {
        return {'type': 'plant_market', 'index': 0, 'field': 0};
      }
      final bean = market.first;
      // Plant if it matches one of our fields or an empty field
      for (var f = 0; f < fields[seat].length; f++) {
        if (fields[seat][f].isNotEmpty && fields[seat][f].first == bean) {
          return {'type': 'plant_market', 'index': 0, 'field': f};
        }
      }
      for (var f = 0; f < fields[seat].length; f++) {
        if (fields[seat][f].isEmpty) {
          return {'type': 'plant_market', 'index': 0, 'field': f};
        }
      }
      // Otherwise gift it to an opponent so we don't uproot our own fields
      return {'type': 'gift_market', 'index': 0, 'target': (seat + 1) % players};
    }

    return null;
  }
}
