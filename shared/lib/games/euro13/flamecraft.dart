import 'dart:math';

import '../../src/engine.dart';

const List<String> flameGoodNames = [
  '面包',
  '炙肉',
  '铁匠',
  '魔药',
  '植物',
  '水晶',
];

const List<String> flameGoodEmojis = [
  '🍞',
  '🥩',
  '🔨',
  '🧪',
  '🌿',
  '💎',
];

const List<String> flameDragonTypeNames = [
  '烘焙龙',
  '炙烤龙',
  '锻造龙',
  '炼金龙',
  '园艺龙',
  '晶耀龙',
];

const List<String> flameShopNames = [
  '暖炉面包坊',
  '烈焰烤肉铺',
  '龙鳞铁匠铺',
  '星辉魔药店',
  '翡翠温室苑',
  '晶簇珠宝行',
];

class FlameDragon {
  final int id;
  final int type; // 0..5
  final String name;

  const FlameDragon({
    required this.id,
    required this.type,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
      };
}

class FlameSpell {
  final int id;
  final String name;
  final int targetShop; // 0..5
  final List<int> cost; // length 6, total 3..5 Goods
  final int hearts; // 5..8

  const FlameSpell({
    required this.id,
    required this.name,
    required this.targetShop,
    required this.cost,
    required this.hearts,
  });

  int get totalCost => cost.fold<int>(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetShop': targetShop,
        'cost': List<int>.of(cost),
        'hearts': hearts,
      };
}

class FlameShop {
  final int id; // 0..5
  final String name;
  final int baseGood; // 0..5
  int enchantCount = 0;
  final List<FlameDragon> dragons = []; // up to 3 slotted Dragons

  FlameShop({
    required this.id,
    required this.name,
    required this.baseGood,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseGood': baseGood,
        'enchantCount': enchantCount,
        'dragons': [for (final d in dragons) d.toJson()],
      };
}

class FlamecraftGame extends GameEngine {
  late final int maxRounds;

  late List<FlameShop> shops;
  final List<FlameDragon> dragonDeck = [];
  final List<FlameDragon> park = []; // 5 Park Dragon cards
  final List<FlameSpell> spellDeck = [];
  final List<FlameSpell> spells = []; // 5 Enchantment Spells

  late List<List<int>> goods; // goods[seat][0..5]
  late List<int> coins;
  late List<int> hearts;
  late List<int> location; // shop index 0..5, or -1 at start
  late List<List<FlameDragon>> hand;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '魔法龙镇开集！欢迎工匠幼龙入驻街区';

  FlamecraftGame(super.setup) : maxRounds = setup.opt<int>('rounds', 8);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<FlameDragon> _buildDragonDeck() {
    final list = <FlameDragon>[];
    var id = 10;
    const suffixes = ['火苗', '炭宝', '星爪', '琥珀', '暖翼', '绒尾', '甜炉'];
    for (var t = 0; t < 6; t++) {
      for (final suf in suffixes) {
        list.add(FlameDragon(
          id: id++,
          type: t,
          name: '${flameGoodEmojis[t]}${flameDragonTypeNames[t]}·$suf',
        ));
      }
    }
    return shuffled(list, rng);
  }

  List<FlameSpell> _buildSpellDeck() {
    final list = <FlameSpell>[];
    var id = 100;
    const spellTitles = [
      ['黄金发酵咒', '麦香丰饶术', '千层酥皮阵', '蜜糖吐司颂', '晨曦烘焙引'],
      ['龙息炙烤术', '椒香盛宴咒', '焦糖脆皮诀', '熔岩浓汤咒', '烈火熏肉典'],
      ['秘银淬火诀', '星铁百炼阵', '精金回响咒', '熔炉不熄歌', '符文铁砧术'],
      ['月露蒸馏术', '虹彩秘药阵', '星辰灵液诀', '永昼甘露咒', '幻梦坩埚引'],
      ['四季常青咒', '万花绽放阵', '古树生机诀', '月光藤蔓颂', '翡冷翠秘术'],
      ['棱镜折射咒', '星钻共鸣阵', '极光切割诀', '虚空晶簇引', '永恒璀璨颂'],
    ];
    for (var s = 0; s < 6; s++) {
      for (var k = 0; k < 5; k++) {
        final cost = List<int>.filled(6, 0);
        // 3..5 total goods cost
        final total = 3 + (k % 3); // 3, 4, 5, 3, 4
        cost[s] = 2;
        cost[(s + k + 1) % 6] = total - 2;
        final h = 5 + (k % 4); // 5..8 hearts
        list.add(FlameSpell(
          id: id++,
          name: spellTitles[s][k],
          targetShop: s,
          cost: cost,
          hearts: h,
        ));
      }
    }
    return shuffled(list, rng);
  }

  @override
  void start() {
    shops = [
      for (var s = 0; s < 6; s++)
        FlameShop(
          id: s,
          name: flameShopNames[s],
          baseGood: s,
        )..dragons.add(FlameDragon(
            id: s + 1,
            type: s,
            name: '${flameGoodEmojis[s]}初始${flameDragonTypeNames[s]}',
          )),
    ];

    dragonDeck
      ..clear()
      ..addAll(_buildDragonDeck());
    park.clear();
    _refillPark();

    spellDeck
      ..clear()
      ..addAll(_buildSpellDeck());
    spells.clear();
    _refillSpells();

    goods = List.generate(players, (s) {
      final g = List<int>.filled(6, 0);
      g[s % 6] = 1;
      g[(s + 1) % 6] = 1;
      g[(s + 2) % 6] = 1;
      return g;
    });
    coins = List.filled(players, 1);
    hearts = List.filled(players, 0);
    location = List.filled(players, -1);
    hand = List.generate(players, (_) => <FlameDragon>[]);
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < 2; i++) {
        if (dragonDeck.isNotEmpty) {
          hand[s].add(dragonDeck.removeLast());
        }
      }
    }
    score = [for (var s = 0; s < players; s++) calcScore(s)];
  }

  void _refillPark() {
    while (park.length < 5 && dragonDeck.isNotEmpty) {
      park.add(dragonDeck.removeLast());
    }
  }

  void _refillSpells() {
    while (spells.length < 5 && spellDeck.isNotEmpty) {
      spells.add(spellDeck.removeLast());
    }
  }

  int totalGoods(int seat) => goods[seat].fold<int>(0, (a, b) => a + b);

  List<int> occupantsAtShop(int shopIdx, {int? excludeSeat}) => [
        for (var s = 0; s < players; s++)
          if (s != excludeSeat && location[s] == shopIdx) s,
      ];

  int visitFee(int seat, int shopIdx) =>
      occupantsAtShop(shopIdx, excludeSeat: seat).length;

  bool canAffordVisit(int seat, int shopIdx) =>
      totalGoods(seat) + coins[seat] >= visitFee(seat, shopIdx);

  bool canAffordSpellAtShop(int seat, int shopIdx, FlameSpell spell) {
    if (spell.targetShop != shopIdx) return false;
    final fee = visitFee(seat, shopIdx);
    // Calculate deficit of specific goods; surplus goods can pay visit fee, coins can pay either
    var deficit = 0;
    var surplusGoods = 0;
    for (var g = 0; g < 6; g++) {
      if (goods[seat][g] >= spell.cost[g]) {
        surplusGoods += goods[seat][g] - spell.cost[g];
      } else {
        deficit += spell.cost[g] - goods[seat][g];
      }
    }
    final remainingFee = max(0, fee - surplusGoods);
    return coins[seat] >= deficit + remainingFee;
  }

  void _payVisitFee(int seat, int shopIdx, {List<int>? reserveForSpell}) {
    final others = occupantsAtShop(shopIdx, excludeSeat: seat);
    for (final other in others) {
      // Pay 1 surplus good if possible, otherwise 1 good or 1 coin
      var paidGood = -1;
      for (var g = 0; g < 6; g++) {
        final reserve = reserveForSpell != null ? reserveForSpell[g] : 0;
        if (goods[seat][g] > reserve) {
          paidGood = g;
          break;
        }
      }
      if (paidGood == -1) {
        for (var g = 0; g < 6; g++) {
          if (goods[seat][g] > 0) {
            paidGood = g;
            break;
          }
        }
      }
      if (paidGood != -1 && (reserveForSpell == null || goods[seat][paidGood] > reserveForSpell[paidGood])) {
        goods[seat][paidGood]--;
        goods[other][paidGood]++;
      } else if (coins[seat] > 0) {
        coins[seat]--;
        coins[other]++;
      } else if (paidGood != -1) {
        goods[seat][paidGood]--;
        goods[other][paidGood]++;
      }
    }
  }

  void _paySpellCost(int seat, FlameSpell spell) {
    for (var g = 0; g < 6; g++) {
      final need = spell.cost[g];
      if (goods[seat][g] >= need) {
        goods[seat][g] -= need;
      } else {
        final short = need - goods[seat][g];
        goods[seat][g] = 0;
        coins[seat] -= short;
      }
    }
  }

  String fireUpDragon(int seat, FlameDragon d) {
    switch (d.type) {
      case 0: // 🍞 Bread: draw 1 dragon from park + 1 Bread
        goods[seat][0]++;
        if (park.isNotEmpty && hand[seat].length < 6) {
          hand[seat].add(park.removeAt(0));
          _refillPark();
          return '点火${d.name}(+1🍞+招募1龙)';
        }
        hearts[seat] += 1;
        return '点火${d.name}(+1🍞+1❤️)';
      case 1: // 🥩 Meat: +1 Heart + 1 Meat
        hearts[seat] += 1;
        goods[seat][1]++;
        return '点火${d.name}(+1❤️+1🥩)';
      case 2: // 🔨 Iron: +1 Anvil + 1 Crystal
        goods[seat][2]++;
        goods[seat][5]++;
        return '点火${d.name}(+1🔨+1💎)';
      case 3: // 🧪 Potion: +1 Coin + 1 Potion
        coins[seat]++;
        goods[seat][3]++;
        return '点火${d.name}(+1🪙+1🧪)';
      case 4: // 🌿 Plant: +2 Hearts
        hearts[seat] += 2;
        return '点火${d.name}(+2❤️)';
      case 5: // 💎 Crystal: +1 Coin + 1 Heart
      default:
        coins[seat]++;
        hearts[seat] += 1;
        return '点火${d.name}(+1🪙+1❤️)';
    }
  }

  int calcScore(int seat) =>
      hearts[seat] + coins[seat] + (totalGoods(seat) ~/ 3);

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    final shopIdx = asInt(action['shop'], -1);
    if (shopIdx < 0 || shopIdx >= shops.length) {
      throw GameError('请选择有效的店铺 (0..5)');
    }
    final shop = shops[shopIdx];

    if (type == 'gather') {
      if (!canAffordVisit(seat, shopIdx)) {
        throw GameError('物资不足以支付同店铺其他玩家的拜访礼 (每人 1 货物)');
      }
      final handIdx = asInt(action['handIdx'], -1);
      if (handIdx >= 0 &&
          (handIdx >= hand[seat].length || shop.dragons.length >= 3)) {
        throw GameError('无法安放该工匠龙（手牌索引无效或店铺龙位已满）');
      }

      _payVisitFee(seat, shopIdx);
      location[seat] = shopIdx;

      // 1. Gather shop base goods + enchant bonus + slotted dragon goods
      final baseGain = 1 + shop.enchantCount;
      goods[seat][shop.baseGood] += baseGain;
      for (final d in shop.dragons) {
        goods[seat][d.type]++;
      }

      // 2. Optionally slot 1 Dragon from hand into Shop
      var slotNote = '';
      if (handIdx >= 0) {
        final placed = hand[seat].removeAt(handIdx);
        shop.dragons.add(placed);
        final rewardHearts = shop.dragons.length >= 3 ? 3 : 2;
        hearts[seat] += rewardHearts;
        if (hand[seat].length < 2 && park.isNotEmpty) {
          hand[seat].add(park.removeAt(0));
          _refillPark();
        }
        slotNote = '，入驻${placed.name}(+$rewardHearts❤️)';
      }

      // 3. Fire Up 1 Dragon in Shop
      var fireNote = '';
      if (shop.dragons.isNotEmpty) {
        final fireSlot =
            asInt(action['fireSlot'], shop.dragons.length - 1).clamp(0, shop.dragons.length - 1);
        fireNote = '，${fireUpDragon(seat, shop.dragons[fireSlot])}';
      }

      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '${name(seat)} 造访【${shop.name}】采集物资$slotNote$fireNote';
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    if (type == 'enchant') {
      final spellSlot = asInt(action['spellSlot'], -1);
      if (spellSlot < 0 || spellSlot >= spells.length) {
        throw GameError('无效的附魔咒语编号');
      }
      final spell = spells[spellSlot];
      if (spell.targetShop != shopIdx) {
        throw GameError('该附魔咒语与所选店铺类型不匹配');
      }
      if (!canAffordSpellAtShop(seat, shopIdx, spell)) {
        throw GameError('货物与金币不足以施展该附魔咒语');
      }

      _payVisitFee(seat, shopIdx, reserveForSpell: spell.cost);
      _paySpellCost(seat, spell);
      location[seat] = shopIdx;

      spells.removeAt(spellSlot);
      _refillSpells();

      hearts[seat] += spell.hearts;
      shop.enchantCount++;

      // Fire up all dragons in the enchanted shop!
      for (final d in shop.dragons) {
        fireUpDragon(seat, d);
      }

      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction =
          '${name(seat)} 在【${shop.name}】施展附魔《${spell.name}》(+${spell.hearts}❤️ 并唤醒店内群龙！)';
      host.log(lastAction);
      _advanceTurn();
      return;
    }

    throw GameError('未知操作类型: $type');
  }

  void _advanceTurn() {
    final nextSeat = (turn + 1) % players;
    if (nextSeat == 0) {
      if (round >= maxRounds || spells.isEmpty) {
        over = true;
        for (var s = 0; s < players; s++) {
          score[s] = calcScore(s);
        }
        lastAction = '魔法龙镇盛典落幕！声望最高者荣膺护焰大师';
        host.log(lastAction);
        return;
      }
      round++;
    }
    turn = nextSeat;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Check if we can cast any Enchantment Spell (high reputation yield)
    if (botLevel >= 1) {
      for (var k = 0; k < spells.length; k++) {
        final sp = spells[k];
        if (canAffordSpellAtShop(seat, sp.targetShop, sp)) {
          return {
            'type': 'enchant',
            'shop': sp.targetShop,
            'spellSlot': k,
          };
        }
      }
    }

    // 2. Otherwise choose best shop to gather (+ slot a dragon if possible)
    var bestShop = 0;
    var bestVal = -999;
    for (var s = 0; s < shops.length; s++) {
      if (!canAffordVisit(seat, s)) continue;
      final sh = shops[s];
      var val = (1 + sh.enchantCount + sh.dragons.length) * 2 - visitFee(seat, s) * 2;
      if (sh.dragons.length < 3 && hand[seat].isNotEmpty) {
        val += (sh.dragons.length == 2 ? 9 : 6);
      }
      if (val > bestVal) {
        bestVal = val;
        bestShop = s;
      }
    }

    final chosenShop = shops[bestShop];
    final canSlot = chosenShop.dragons.length < 3 && hand[seat].isNotEmpty;
    return {
      'type': 'gather',
      'shop': bestShop,
      'handIdx': canSlot ? 0 : -1,
      'fireSlot': max(0, chosenShop.dragons.length - 1),
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
      'shops': [for (final sh in shops) sh.toJson()],
      'park': [for (final d in park) d.toJson()],
      'spells': [for (final sp in spells) sp.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'goods': List<int>.of(goods[s]),
            'coins': coins[s],
            'hearts': hearts[s],
            'location': location[s],
            'handCount': hand[s].length,
            'hand': [for (final d in hand[s]) d.toJson()],
            'score': score[s],
          },
      ],
    };
  }
}
