import 'dart:math';

import '../../src/engine.dart';

const List<String> spiceNames = ['姜黄', '藏红花', '小豆蔻', '肉桂'];

class MerchantCard {
  final String id;
  final String name;
  final String kind; // 'produce' | 'upgrade' | 'trade'
  final List<int> gain; // length 4 for produce
  final int upgrades; // 2 or 3 for upgrade
  final List<int> give; // length 4 for trade
  final List<int> get; // length 4 for trade

  const MerchantCard.produce(this.id, this.name, this.gain)
      : kind = 'produce',
        upgrades = 0,
        give = const [0, 0, 0, 0],
        get = const [0, 0, 0, 0];

  const MerchantCard.upgrade(this.id, this.name, this.upgrades)
      : kind = 'upgrade',
        gain = const [0, 0, 0, 0],
        give = const [0, 0, 0, 0],
        get = const [0, 0, 0, 0];

  const MerchantCard.trade(this.id, this.name, this.give, this.get)
      : kind = 'trade',
        gain = const [0, 0, 0, 0],
        upgrades = 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'gain': gain,
        'upgrades': upgrades,
        'give': give,
        'get': get,
      };
}

class OrderCard {
  final String id;
  final List<int> cost; // [y, r, g, b]
  final int points;

  const OrderCard(this.id, this.cost, this.points);

  Map<String, dynamic> toJson() => {
        'id': id,
        'cost': cost,
        'points': points,
      };
}

const MerchantCard starterProduce2Y = MerchantCard.produce('produce_2y', '收获 2姜黄', [2, 0, 0, 0]);
const MerchantCard starterUpgrade2 = MerchantCard.upgrade('upgrade_2', '升级 2次', 2);

const List<MerchantCard> merchantCatalog = [
  // Produce cards
  MerchantCard.produce('prod_3y', '收获 3姜黄', [3, 0, 0, 0]),
  MerchantCard.produce('prod_4y', '收获 4姜黄', [4, 0, 0, 0]),
  MerchantCard.produce('prod_1r', '收获 1藏红花', [0, 1, 0, 0]),
  MerchantCard.produce('prod_1y1r', '收获 1姜黄1红', [1, 1, 0, 0]),
  MerchantCard.produce('prod_2y1r', '收获 2姜黄1红', [2, 1, 0, 0]),
  MerchantCard.produce('prod_2r', '收获 2藏红花', [0, 2, 0, 0]),
  MerchantCard.produce('prod_1g', '收获 1小豆蔻', [0, 0, 1, 0]),
  MerchantCard.produce('prod_1y1g', '收获 1姜黄1绿', [1, 0, 1, 0]),
  MerchantCard.produce('prod_1b', '收获 1肉桂', [0, 0, 0, 1]),
  // Upgrade card
  MerchantCard.upgrade('upgrade_3', '升级 3次', 3),
  MerchantCard.upgrade('upgrade_3b', '精炼 3次', 3),
  // Trade cards
  MerchantCard.trade('tr_2y_2r', '2黄 → 2红', [2, 0, 0, 0], [0, 2, 0, 0]),
  MerchantCard.trade('tr_3y_3r', '3黄 → 3红', [3, 0, 0, 0], [0, 3, 0, 0]),
  MerchantCard.trade('tr_2y_1g', '2黄 → 1绿', [2, 0, 0, 0], [0, 0, 1, 0]),
  MerchantCard.trade('tr_3y_1r1g', '3黄 → 1红1绿', [3, 0, 0, 0], [0, 1, 1, 0]),
  MerchantCard.trade('tr_3y_1b', '3黄 → 1褐', [3, 0, 0, 0], [0, 0, 0, 1]),
  MerchantCard.trade('tr_4y_2g', '4黄 → 2绿', [4, 0, 0, 0], [0, 0, 2, 0]),
  MerchantCard.trade('tr_4y_1g1b', '4黄 → 1绿1褐', [4, 0, 0, 0], [0, 0, 1, 1]),
  MerchantCard.trade('tr_5y_2b', '5黄 → 2褐', [5, 0, 0, 0], [0, 0, 0, 2]),
  MerchantCard.trade('tr_1r_3y', '1红 → 3黄', [0, 1, 0, 0], [3, 0, 0, 0]),
  MerchantCard.trade('tr_2r_3y1g', '2红 → 3黄1绿', [0, 2, 0, 0], [3, 0, 1, 0]),
  MerchantCard.trade('tr_2r_2g', '2红 → 2绿', [0, 2, 0, 0], [0, 0, 2, 0]),
  MerchantCard.trade('tr_2r_1b', '2红 → 1褐', [0, 2, 0, 0], [0, 0, 0, 1]),
  MerchantCard.trade('tr_3r_3g', '3红 → 3绿', [0, 3, 0, 0], [0, 0, 3, 0]),
  MerchantCard.trade('tr_3r_1g1b', '3红 → 1绿1褐', [0, 3, 0, 0], [0, 0, 1, 1]),
  MerchantCard.trade('tr_3r_2b', '3红 → 2褐', [0, 3, 0, 0], [0, 0, 0, 2]),
  MerchantCard.trade('tr_1g_2r', '1绿 → 2红', [0, 0, 1, 0], [0, 2, 0, 0]),
  MerchantCard.trade('tr_1g_4y1r', '1绿 → 4黄1红', [0, 0, 1, 0], [4, 1, 0, 0]),
  MerchantCard.trade('tr_2g_2r1b', '2绿 → 2红1褐', [0, 0, 2, 0], [0, 2, 0, 1]),
  MerchantCard.trade('tr_2g_2b', '2绿 → 2褐', [0, 0, 2, 0], [0, 0, 0, 2]),
  MerchantCard.trade('tr_3g_3b', '3绿 → 3褐', [0, 0, 3, 0], [0, 0, 0, 3]),
  MerchantCard.trade('tr_1b_2g', '1褐 → 2绿', [0, 0, 0, 1], [0, 0, 2, 0]),
  MerchantCard.trade('tr_1b_3r', '1褐 → 3红', [0, 0, 0, 1], [0, 3, 0, 0]),
  MerchantCard.trade('tr_1b_1g2r', '1褐 → 2红1绿', [0, 0, 0, 1], [0, 2, 1, 0]),
  MerchantCard.trade('tr_1b_2y1r1g', '1褐 → 2黄1红1绿', [0, 0, 0, 1], [2, 1, 1, 0]),
  MerchantCard.trade('tr_1y1r_1b', '1黄1红 → 1褐', [1, 1, 0, 0], [0, 0, 0, 1]),
  MerchantCard.trade('tr_2y1r_2g', '2黄1红 → 2绿', [2, 1, 0, 0], [0, 0, 2, 0]),
];

const List<OrderCard> orderCatalog = [
  OrderCard('ord_2y2r', [2, 2, 0, 0], 6),
  OrderCard('ord_3y2r', [3, 2, 0, 0], 7),
  OrderCard('ord_2y3r', [2, 3, 0, 0], 8),
  OrderCard('ord_4r', [0, 4, 0, 0], 8),
  OrderCard('ord_2y2g', [2, 0, 2, 0], 8),
  OrderCard('ord_3y2g', [3, 0, 2, 0], 9),
  OrderCard('ord_2r2g', [0, 2, 2, 0], 10),
  OrderCard('ord_5r', [0, 5, 0, 0], 10),
  OrderCard('ord_2y3g', [2, 0, 3, 0], 11),
  OrderCard('ord_3y2b', [3, 0, 0, 2], 11),
  OrderCard('ord_1y2r1g1b', [1, 2, 1, 1], 12),
  OrderCard('ord_4g', [0, 0, 4, 0], 12),
  OrderCard('ord_2r3g', [0, 2, 3, 0], 13),
  OrderCard('ord_2r2b', [0, 2, 0, 2], 12),
  OrderCard('ord_2y2g2b', [2, 0, 2, 2], 15),
  OrderCard('ord_2g2b', [0, 0, 2, 2], 14),
  OrderCard('ord_5g', [0, 0, 5, 0], 15),
  OrderCard('ord_1y1r1g1b', [1, 1, 1, 1], 9),
  OrderCard('ord_2y2r2g', [2, 2, 2, 0], 13),
  OrderCard('ord_2r2g2b', [0, 2, 2, 2], 17),
  OrderCard('ord_3b', [0, 0, 0, 3], 12),
  OrderCard('ord_4b', [0, 0, 0, 4], 16),
  OrderCard('ord_5b', [0, 0, 0, 5], 20),
  OrderCard('ord_2y3b', [2, 0, 0, 3], 14),
  OrderCard('ord_3g2b', [0, 0, 3, 2], 17),
  OrderCard('ord_2g3b', [0, 0, 2, 3], 18),
  OrderCard('ord_2y1r1g2b', [2, 1, 1, 2], 16),
  OrderCard('ord_1y1r2g2b', [1, 1, 2, 2], 17),
  OrderCard('ord_2y2r2b', [2, 2, 0, 2], 15),
  OrderCard('ord_3r2b', [0, 3, 0, 2], 14),
];

const String centurySpiceRules = '''
# 香料之路 (Century: Spice Road)

## 游戏目标
玩家扮演丝绸之路上的香料商队首领，通过生产、升级与交易香料，招募商人卡并完成高价值的香料订单。当有玩家完成达到目标数量（标准 5 张 / 快速 4 张）的订单时，完成当前轮次后游戏结束，总分最高者获胜。

## 四种香料等级
- **0 姜黄（黄）**：基础香料（终局不计分）
- **1 藏红花（红）**：终局每颗价值 **1 分**
- **2 小豆蔻（绿）**：终局每颗价值 **1 分**
- **3 肉桂（褐）**：最高级香料，终局每颗价值 **1 分**
- **商队容量限制**：每位玩家最多只能持有 **10 颗** 香料方块，超出部分将自动弃置低级香料（或按指定弃置）。

## 回合四选一行动
每到你的回合，必须从以下 4 项行动中选择 1 项执行：
1. **打出商人卡 (Play)**：从手牌打出 1 张商人卡到自己的已出牌区，执行卡牌效果：
   - **收获卡**：获得对应数量的香料。
   - **升级卡**：可将香料按等级提升（如黄→红→绿→褐），可对同一颗香料连续升级或分配给多颗香料。
   - **交易卡**：按牌面比例支付香料并换取目标香料，单次出牌可重复执行该交易公式 **1 次或多次**。
2. **招募商人卡 (Acquire)**：从市场 6 张商人卡中拿取第 `m` 张（索引 `0..5`）加入手牌。必须在它左侧的每张市场卡（`0..m-1`）上各放置 1 颗你的香料；若被拿取的卡上已有别人放的香料，你一并收入囊中。
3. **休整 (Rest)**：将自己面前所有已打出的商人卡全部收回手牌。
4. **完成订单 (Claim)**：支付与市场某张订单卡完全一致的香料，将该订单归入自己名下：
   - 完成最左侧（第 1 张）订单且金牌尚存时，额外获得 **1 枚金牌（+3 分）**。
   - 完成左数第 2 张订单且银牌尚存时，额外获得 **1 枚银牌（+1 分）**。

## 终局计分
- 已完成的所有订单卡分值总和
- 金牌每枚 **+3 分**，银牌每枚 **+1 分**
- 剩余的 **红、绿、褐** 香料每颗 **+1 分**（姜黄不计分）
''';

class CenturySpice extends GameEngine {
  static const int maxCaravan = 10;

  late final int targetOrders;

  final List<MerchantCard> merchantDeck = [];
  final List<OrderCard> orderDeck = [];

  final List<MerchantCard> market = [];
  final List<List<int>> marketSpices = []; // 6 x [y, r, g, b]
  final List<OrderCard> orders = [];

  late final List<List<int>> spices; // players x [y, r, g, b]
  late final List<List<MerchantCard>> hand;
  late final List<List<MerchantCard>> played;
  late final List<List<OrderCard>> claimedOrders;
  late final List<int> goldCoins;
  late final List<int> silverCoins;

  int goldRemaining = 0;
  int silverRemaining = 0;

  int round = 1;
  int turn = 0;
  bool lastRound = false;
  bool over = false;
  List<int>? _placings;
  Map<String, dynamic>? result;
  String lastAction = '';

  CenturySpice(super.setup) {
    targetOrders = setup.opt<int>('targetOrders', 5);
    spices = List.generate(players, (_) => [0, 0, 0, 0]);
    hand = List.generate(players, (_) => <MerchantCard>[]);
    played = List.generate(players, (_) => <MerchantCard>[]);
    claimedOrders = List.generate(players, (_) => <OrderCard>[]);
    goldCoins = List.filled(players, 0);
    silverCoins = List.filled(players, 0);
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    merchantDeck
      ..clear()
      ..addAll(shuffled(merchantCatalog, rng));
    orderDeck
      ..clear()
      ..addAll(shuffled(orderCatalog, rng));

    market.clear();
    marketSpices.clear();
    for (var i = 0; i < 6 && merchantDeck.isNotEmpty; i++) {
      market.add(merchantDeck.removeLast());
      marketSpices.add([0, 0, 0, 0]);
    }

    orders.clear();
    for (var i = 0; i < 5 && orderDeck.isNotEmpty; i++) {
      orders.add(orderDeck.removeLast());
    }

    goldRemaining = 2 * players;
    silverRemaining = 2 * players;

    // Starting spices per seat:
    // 0: 3Y, 1: 4Y, 2: 4Y, 3: 3Y+1R, 4: 3Y+1R
    const startSpices = [
      [3, 0, 0, 0],
      [4, 0, 0, 0],
      [4, 0, 0, 0],
      [3, 1, 0, 0],
      [3, 1, 0, 0],
    ];

    for (var s = 0; s < players; s++) {
      spices[s] = List<int>.of(startSpices[s.clamp(0, 4)]);
      hand[s] = [starterProduce2Y, starterUpgrade2];
      played[s] = [];
      claimedOrders[s] = [];
      goldCoins[s] = 0;
      silverCoins[s] = 0;
    }

    round = 1;
    turn = 0;
    lastRound = false;
    over = false;
    lastAction = '香料之路开始！轮到 ${name(0)} 行动';
    host.log(lastAction);
  }

  int totalSpices(int seat) =>
      spices[seat][0] + spices[seat][1] + spices[seat][2] + spices[seat][3];

  bool canAfford(int seat, List<int> cost, [int times = 1]) {
    for (var i = 0; i < 4; i++) {
      if (spices[seat][i] < cost[i] * times) return false;
    }
    return true;
  }

  int maxTradeTimes(int seat, MerchantCard card) {
    if (card.kind != 'trade') return 0;
    var maxT = 99;
    for (var i = 0; i < 4; i++) {
      if (card.give[i] > 0) {
        maxT = min(maxT, spices[seat][i] ~/ card.give[i]);
      }
    }
    return maxT == 99 ? 0 : maxT;
  }

  void _enforceCaravanLimit(int seat, [Object? dropRaw]) {
    if (totalSpices(seat) <= maxCaravan) return;
    if (dropRaw is List && dropRaw.length == 4) {
      final drop = asIntList(dropRaw);
      for (var t = 0; t < 4; t++) {
        final d = drop[t].clamp(0, spices[seat][t]);
        spices[seat][t] -= d;
      }
    }
    while (totalSpices(seat) > maxCaravan) {
      for (var t = 0; t < 4; t++) {
        if (spices[seat][t] > 0) {
          spices[seat][t]--;
          break;
        }
      }
    }
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'play':
        _handlePlay(seat, action);
        break;
      case 'acquire':
        _handleAcquire(seat, action);
        break;
      case 'rest':
        if (played[seat].isEmpty) throw GameError('没有已打出的卡牌可收回');
        hand[seat].addAll(played[seat]);
        final count = played[seat].length;
        played[seat].clear();
        lastAction = '${name(seat)} 休整并收回了 $count 张商人卡';
        _endTurn();
        break;
      case 'claim':
        _handleClaim(seat, action);
        break;
      default:
        throw GameError('未知行动类型：$type');
    }
  }

  void _handlePlay(int seat, Map<String, dynamic> action) {
    final idx = asInt(action['index'] ?? action['card']);
    if (idx < 0 || idx >= hand[seat].length) throw GameError('无效的手牌索引');
    final card = hand[seat][idx];

    if (card.kind == 'produce') {
      hand[seat].removeAt(idx);
      played[seat].add(card);
      for (var t = 0; t < 4; t++) {
        spices[seat][t] += card.gain[t];
      }
      _enforceCaravanLimit(seat, action['drop']);
      lastAction = '${name(seat)} 打出【${card.name}】';
      _endTurn();
      return;
    }

    if (card.kind == 'upgrade') {
      final rawSteps = action['steps'] ?? action['upgrades'] ?? action['from'];
      final tempSpices = List<int>.of(spices[seat]);
      if (rawSteps is List) {
        final steps = asIntList(rawSteps);
        if (steps.length > card.upgrades) {
          throw GameError('最多只能升级 ${card.upgrades} 次');
        }
        for (final lv in steps) {
          if (lv < 0 || lv >= 3) throw GameError('只能升级姜黄(0)、藏红花(1)或小豆蔻(2)');
          if (tempSpices[lv] <= 0) throw GameError('${spiceNames[lv]}数量不足以升级');
          tempSpices[lv]--;
          tempSpices[lv + 1]++;
        }
      } else {
        // Default auto-upgrade lowest available spices up to card.upgrades times
        for (var u = 0; u < card.upgrades; u++) {
          var upgraded = false;
          for (var lv = 0; lv < 3; lv++) {
            if (tempSpices[lv] > 0) {
              tempSpices[lv]--;
              tempSpices[lv + 1]++;
              upgraded = true;
              break;
            }
          }
          if (!upgraded) break;
        }
      }
      hand[seat].removeAt(idx);
      played[seat].add(card);
      spices[seat] = tempSpices;
      lastAction = '${name(seat)} 打出【${card.name}】升级香料';
      _endTurn();
      return;
    }

    if (card.kind == 'trade') {
      final times = asInt(action['times'], 1);
      if (times < 1) throw GameError('交易次数至少为 1');
      if (!canAfford(seat, card.give, times)) {
        throw GameError('香料不足以执行 $times 次【${card.name}】');
      }
      hand[seat].removeAt(idx);
      played[seat].add(card);
      for (var t = 0; t < 4; t++) {
        spices[seat][t] -= card.give[t] * times;
        spices[seat][t] += card.get[t] * times;
      }
      _enforceCaravanLimit(seat, action['drop']);
      lastAction = '${name(seat)} 打出【${card.name}】（执行 $times 次）';
      _endTurn();
      return;
    }
  }

  void _handleAcquire(int seat, Map<String, dynamic> action) {
    final m = asInt(action['index']);
    if (m < 0 || m >= market.length) throw GameError('无效的市场卡牌位置');
    if (totalSpices(seat) < m) throw GameError('香料不足，招募该卡需放置 $m 颗香料');

    final payList = _resolvePayment(seat, m, action['pay']);
    for (var k = 0; k < m; k++) {
      final tier = payList[k];
      spices[seat][tier]--;
      marketSpices[k][tier]++;
    }

    // Collect spices sitting on card m
    for (var t = 0; t < 4; t++) {
      spices[seat][t] += marketSpices[m][t];
    }

    final acquired = market.removeAt(m);
    marketSpices.removeAt(m);
    hand[seat].add(acquired);

    if (merchantDeck.isNotEmpty) {
      market.add(merchantDeck.removeLast());
      marketSpices.add([0, 0, 0, 0]);
    }

    _enforceCaravanLimit(seat, action['drop']);
    lastAction = '${name(seat)} 招募了商人卡【${acquired.name}】';
    _endTurn();
  }

  List<int> _resolvePayment(int seat, int m, Object? payRaw) {
    if (m == 0) return const [];
    if (payRaw is List && payRaw.isNotEmpty) {
      final list = asIntList(payRaw);
      // Try interpreting as m tier indices [c_0, ..., c_{m-1}]
      if (list.length == m && list.every((c) => c >= 0 && c < 4)) {
        final counts = [0, 0, 0, 0];
        for (final c in list) {
          counts[c]++;
        }
        if (canAfford(seat, counts)) {
          return list;
        }
      }
      // Try interpreting as 4-element count vector [py, pr, pg, pb]
      if (list.length == 4 &&
          list.every((c) => c >= 0) &&
          list[0] + list[1] + list[2] + list[3] == m &&
          canAfford(seat, list)) {
        final expanded = <int>[];
        for (var t = 0; t < 4; t++) {
          for (var i = 0; i < list[t]; i++) {
            expanded.add(t);
          }
        }
        return expanded;
      }
      throw GameError('支付的香料列表无效或数量不足');
    }

    // Default: pick m lowest-tier spices available
    final temp = List<int>.of(spices[seat]);
    final out = <int>[];
    while (out.length < m) {
      for (var t = 0; t < 4; t++) {
        if (temp[t] > 0) {
          temp[t]--;
          out.add(t);
          break;
        }
      }
    }
    return out;
  }

  void _handleClaim(int seat, Map<String, dynamic> action) {
    final o = asInt(action['index']);
    if (o < 0 || o >= orders.length) throw GameError('无效的订单卡位置');
    final ord = orders[o];
    if (!canAfford(seat, ord.cost)) throw GameError('香料不足以完成该订单');

    for (var t = 0; t < 4; t++) {
      spices[seat][t] -= ord.cost[t];
    }
    orders.removeAt(o);
    claimedOrders[seat].add(ord);

    var coinBonus = '';
    if (o == 0 && goldRemaining > 0) {
      goldCoins[seat]++;
      goldRemaining--;
      coinBonus = '（获得金牌 +3分）';
    } else if (o == 1 && silverRemaining > 0) {
      silverCoins[seat]++;
      silverRemaining--;
      coinBonus = '（获得银牌 +1分）';
    }

    if (orderDeck.isNotEmpty) {
      orders.add(orderDeck.removeLast());
    }

    lastAction = '${name(seat)} 完成了 ${ord.points} 分订单$coinBonus！';
    host.log(lastAction);

    if (claimedOrders[seat].length >= targetOrders && !lastRound) {
      lastRound = true;
      host.log('${name(seat)} 已完成 $targetOrders 张订单，本轮结束后结算终局！');
    }
    _endTurn();
  }

  void _endTurn() {
    final next = (turn + 1) % players;
    if (next == 0) {
      if (lastRound || orders.isEmpty) {
        _finishGame();
        return;
      }
      round++;
    }
    turn = next;
  }

  Map<String, int> scoreBreakdown(int seat) {
    final orderPts = claimedOrders[seat].fold(0, (s, o) => s + o.points);
    final coinPts = goldCoins[seat] * 3 + silverCoins[seat];
    final spicePts = spices[seat][1] + spices[seat][2] + spices[seat][3];
    final total = orderPts + coinPts + spicePts;
    return {
      'orders': orderPts,
      'coins': coinPts,
      'spices': spicePts,
      'total': total,
    };
  }

  int scoreOf(int seat) => scoreBreakdown(seat)['total']!;

  void _finishGame() {
    over = true;
    final breakdowns = [for (var s = 0; s < players; s++) scoreBreakdown(s)];
    final totals = [for (final b in breakdowns) b['total']!];
    _placings = rankByScore(totals);
    final winners = [
      for (var s = 0; s < players; s++)
        if (_placings![s] == 1) s,
    ];
    result = {
      'scores': totals,
      'breakdowns': breakdowns,
      'winners': winners,
      'placings': _placings,
    };
    host.log('游戏结束！胜者：${winners.map(name).join('、')}');
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isMe = seat >= 0 && seat < players;
    return {
      'round': round,
      'turn': turn,
      'lastRound': lastRound,
      'targetOrders': targetOrders,
      'merchantDeckCount': merchantDeck.length,
      'orderDeckCount': orderDeck.length,
      'goldRemaining': goldRemaining,
      'silverRemaining': silverRemaining,
      'lastAction': lastAction,
      'market': [
        for (var i = 0; i < market.length; i++)
          {
            ...market[i].toJson(),
            'spices': marketSpices[i],
          },
      ],
      'orders': [for (final o in orders) o.toJson()],
      'myHand': isMe ? [for (final c in hand[seat]) c.toJson()] : const [],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'spices': spices[s],
            'totalSpices': totalSpices(s),
            'handCount': hand[s].length,
            'played': [for (final c in played[s]) c.toJson()],
            'claimedCount': claimedOrders[s].length,
            'claimedOrders': [for (final o in claimedOrders[s]) o.toJson()],
            'goldCoins': goldCoins[s],
            'silverCoins': silverCoins[s],
            'score': scoreOf(s),
          },
      ],
      if (result != null) 'result': result,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. If we can claim an order card right now, claim the highest-value one!
    var bestOrderIdx = -1;
    var bestOrderVal = -1;
    for (var i = 0; i < orders.length; i++) {
      if (canAfford(seat, orders[i].cost)) {
        var val = orders[i].points * 10;
        if (i == 0 && goldRemaining > 0) val += 30;
        if (i == 1 && silverRemaining > 0) val += 10;
        if (val > bestOrderVal) {
          bestOrderVal = val;
          bestOrderIdx = i;
        }
      }
    }
    if (bestOrderIdx >= 0) {
      return {'type': 'claim', 'index': bestOrderIdx};
    }

    // Find target order we are closest to completing
    OrderCard? targetOrd;
    if (orders.isNotEmpty) {
      var minMissing = 999;
      for (final o in orders) {
        var miss = 0;
        for (var t = 0; t < 4; t++) {
          miss += max(0, o.cost[t] - spices[seat][t]) * (t + 1);
        }
        if (miss < minMissing) {
          minMissing = miss;
          targetOrd = o;
        }
      }
    }

    // 2. Acquire free market card (index 0) or cheap card (index 1) if hand + played is small
    final totalOwnedCards = hand[seat].length + played[seat].length;
    if (market.isNotEmpty && totalOwnedCards < 5 && (botLevel > 0 || rng.nextBool())) {
      final m0Spices = marketSpices[0][0] + marketSpices[0][1] + marketSpices[0][2] + marketSpices[0][3];
      if (totalOwnedCards < 4 || m0Spices >= 1) {
        return {'type': 'acquire', 'index': 0};
      }
      if (market.length > 1 && totalSpices(seat) >= 1 && totalOwnedCards < 4) {
        return {'type': 'acquire', 'index': 1};
      }
    }

    // 3. Evaluate playing a card from hand
    var bestPlayIdx = -1;
    var bestPlayScore = -999;
    Map<String, dynamic>? bestPlayAction;

    for (var i = 0; i < hand[seat].length; i++) {
      final c = hand[seat][i];
      if (c.kind == 'produce') {
        final gainVal = c.gain[0] + c.gain[1] * 2 + c.gain[2] * 3 + c.gain[3] * 4;
        final spaceLeft = maxCaravan - totalSpices(seat);
        final sc = spaceLeft >= 2 ? gainVal * 4 : gainVal;
        if (sc > bestPlayScore) {
          bestPlayScore = sc;
          bestPlayIdx = i;
          bestPlayAction = {'type': 'play', 'index': i};
        }
      } else if (c.kind == 'upgrade') {
        final temp = List<int>.of(spices[seat]);
        final steps = <int>[];
        for (var u = 0; u < c.upgrades; u++) {
          // Prefer upgrading a spice where we have surplus over targetOrd
          var picked = -1;
          for (var lv = 2; lv >= 0; lv--) {
            final need = targetOrd != null ? targetOrd.cost[lv] : 0;
            if (temp[lv] > need) {
              picked = lv;
              break;
            }
          }
          if (picked < 0) {
            for (var lv = 0; lv < 3; lv++) {
              if (temp[lv] > 0) {
                picked = lv;
                break;
              }
            }
          }
          if (picked >= 0) {
            temp[picked]--;
            temp[picked + 1]++;
            steps.add(picked);
          }
        }
        if (steps.isNotEmpty) {
          final sc = steps.length * 6;
          if (sc > bestPlayScore) {
            bestPlayScore = sc;
            bestPlayIdx = i;
            bestPlayAction = {'type': 'play', 'index': i, 'steps': steps};
          }
        }
      } else if (c.kind == 'trade') {
        final maxT = maxTradeTimes(seat, c);
        if (maxT >= 1) {
          final giveVal = c.give[0] + c.give[1] * 2 + c.give[2] * 3 + c.give[3] * 4;
          final getVal = c.get[0] + c.get[1] * 2 + c.get[2] * 3 + c.get[3] * 4;
          // Check if trade moves us closer to targetOrd
          var helps = getVal > giveVal;
          if (targetOrd != null) {
            var beforeDeficit = 0;
            var afterDeficit = 0;
            for (var t = 0; t < 4; t++) {
              beforeDeficit += max(0, targetOrd.cost[t] - spices[seat][t]) * (t + 1);
              final after = spices[seat][t] - c.give[t] + c.get[t];
              afterDeficit += max(0, targetOrd.cost[t] - after) * (t + 1);
            }
            if (afterDeficit < beforeDeficit) helps = true;
          }
          if (helps) {
            final sc = 15 + (getVal - giveVal) * 2;
            if (sc > bestPlayScore) {
              bestPlayScore = sc;
              bestPlayIdx = i;
              bestPlayAction = {'type': 'play', 'index': i, 'times': 1};
            }
          }
        }
      }
    }

    if (bestPlayIdx >= 0 && bestPlayAction != null && bestPlayScore > 0) {
      return bestPlayAction;
    }

    // 4. Rest if we have played cards
    if (played[seat].isNotEmpty) {
      return {'type': 'rest'};
    }

    // 5. Fallback: play first playable card or acquire card 0
    for (var i = 0; i < hand[seat].length; i++) {
      final c = hand[seat][i];
      if (c.kind == 'produce' || c.kind == 'upgrade') {
        return {'type': 'play', 'index': i};
      }
      if (c.kind == 'trade' && maxTradeTimes(seat, c) >= 1) {
        return {'type': 'play', 'index': i, 'times': 1};
      }
    }
    if (market.isNotEmpty) {
      return {'type': 'acquire', 'index': 0};
    }
    return {'type': 'play', 'index': 0};
  }
}
