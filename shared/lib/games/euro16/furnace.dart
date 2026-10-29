import '../../src/engine.dart';

const List<String> furnaceResourceNames = [
  '煤炭',
  '生铁',
  '石油',
];

const List<String> furnaceResourceEmojis = [
  '🪨',
  '🔩',
  '🛢️',
];

class FurnaceBid {
  final int seat;
  final int disc; // 1..4

  const FurnaceBid({required this.seat, required this.disc});

  Map<String, dynamic> toJson() => {
        'seat': seat,
        'disc': disc,
      };
}

class FurnaceFactoryCard {
  final int id;
  final String name;
  final String emoji;
  // Compensation granted per disc value `d` when outbid:
  // compType: 0=Coal, 1=Iron, 2=Oil, 3=Gear, 4=Money
  final int compType;
  final int compAmount;
  // Top extraction ability when activated in Production phase:
  final List<int> extractRes; // [coal, iron, oil]
  final int extractGears;
  final int extractMoney;
  // Bottom conversion ability (requires upgraded == true):
  final List<int> costRes; // [coal, iron, oil] required
  final List<int> outRes; // [coal, iron, oil] gained
  final int outMoney; // 💰 gained
  final bool upgraded;
  final bool usedThisRound;

  const FurnaceFactoryCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.compType,
    required this.compAmount,
    this.extractRes = const [0, 0, 0],
    this.extractGears = 0,
    this.extractMoney = 0,
    this.costRes = const [0, 0, 0],
    this.outRes = const [0, 0, 0],
    this.outMoney = 0,
    this.upgraded = false,
    this.usedThisRound = false,
  });

  String get compDesc {
    final sym = switch (compType) {
      0 => '🪨煤炭',
      1 => '🔩生铁',
      2 => '🛢️石油',
      3 => '⚙️齿轮',
      _ => '💰资金',
    };
    return 'd×$compAmount$sym';
  }

  String get extractDesc {
    final parts = <String>[];
    for (var i = 0; i < 3; i++) {
      if (extractRes[i] > 0) {
        parts.add('+${extractRes[i]}${furnaceResourceEmojis[i]}');
      }
    }
    if (extractGears > 0) parts.add('+${extractGears}⚙️');
    if (extractMoney > 0) parts.add('+${extractMoney}💰');
    return parts.isEmpty ? '无开采' : parts.join(' ');
  }

  String get convertDesc {
    final inParts = <String>[];
    for (var i = 0; i < 3; i++) {
      if (costRes[i] > 0) {
        inParts.add('${costRes[i]}${furnaceResourceEmojis[i]}');
      }
    }
    final outParts = <String>[];
    for (var i = 0; i < 3; i++) {
      if (outRes[i] > 0) {
        outParts.add('+${outRes[i]}${furnaceResourceEmojis[i]}');
      }
    }
    if (outMoney > 0) outParts.add('+${outMoney}💰');
    if (inParts.isEmpty && outParts.isEmpty) return '常驻产能';
    return '${inParts.join('+')} ➔ ${outParts.join(' ')}';
  }

  FurnaceFactoryCard copyWith({
    bool? upgraded,
    bool? usedThisRound,
  }) =>
      FurnaceFactoryCard(
        id: id,
        name: name,
        emoji: emoji,
        compType: compType,
        compAmount: compAmount,
        extractRes: extractRes,
        extractGears: extractGears,
        extractMoney: extractMoney,
        costRes: costRes,
        outRes: outRes,
        outMoney: outMoney,
        upgraded: upgraded ?? this.upgraded,
        usedThisRound: usedThisRound ?? this.usedThisRound,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'compType': compType,
        'compAmount': compAmount,
        'compDesc': compDesc,
        'extractRes': extractRes,
        'extractGears': extractGears,
        'extractMoney': extractMoney,
        'extractDesc': extractDesc,
        'costRes': costRes,
        'outRes': outRes,
        'outMoney': outMoney,
        'convertDesc': convertDesc,
        'upgraded': upgraded,
        'usedThisRound': usedThisRound,
      };
}

class FurnaceGame extends GameEngine {
  static const int marketSize = 5;

  late final int maxRounds;
  late List<FurnaceFactoryCard> deck;
  late List<FurnaceFactoryCard> market;
  late List<List<FurnaceBid>> bids; // bids[slot] on market[slot]
  late List<List<int>> discsLeft; // discsLeft[seat] = subset of [1, 2, 3, 4]
  late List<List<FurnaceFactoryCard>> factories;
  late List<List<int>> resources; // resources[seat] = [coal, iron, oil]
  late List<int> gears;
  late List<int> money;
  late List<bool> productionDone;

  int round = 1;
  int turn = 0;
  String phase = 'auction'; // 'auction' | 'production'
  bool over = false;
  String lastAction = '工业熔炉竞标开启';

  FurnaceGame(super.setup) : maxRounds = setup.opt<int>('rounds', 4);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(money) : null;

  List<FurnaceFactoryCard> _buildDeck() {
    const templates = [
      // (name, emoji, compType, compAmt, extractRes, extractGears, extractMoney, costRes, outRes, outMoney)
      ('蒸汽煤矿井', '⛏️', 0, 1, [2, 0, 0], 0, 0, [2, 0, 0], [0, 0, 0], 4),
      ('焦炭高炉厂', '🔥', 0, 1, [2, 0, 0], 0, 0, [2, 0, 0], [0, 1, 0], 2),
      ('乌拉尔铁矿', '🪨', 1, 1, [0, 1, 0], 0, 0, [0, 1, 0], [0, 0, 0], 4),
      ('贝塞麦炼钢厂', '🏗️', 1, 1, [1, 1, 0], 0, 0, [1, 1, 0], [0, 0, 0], 6),
      ('巴库油田井', '🛢️', 2, 1, [0, 0, 1], 0, 0, [0, 0, 1], [0, 0, 0], 5),
      ('帝国精炼厂', '⚗️', 2, 1, [0, 1, 0], 0, 0, [0, 1, 0], [0, 0, 1], 3),
      ('精密机械局', '⚙️', 3, 1, [1, 0, 0], 1, 0, [2, 0, 0], [0, 0, 0], 5),
      ('跨国铁路网', '🚂', 0, 2, [1, 0, 0], 0, 2, [1, 1, 0], [0, 0, 0], 6),
      ('重型造船坞', '🚢', 1, 1, [0, 1, 0], 0, 1, [0, 1, 1], [0, 0, 0], 8),
      ('火力发电站', '⚡', 0, 1, [2, 0, 0], 0, 1, [3, 0, 0], [0, 0, 0], 6),
      ('石化联合体', '🏭', 2, 1, [0, 0, 1], 0, 0, [1, 0, 1], [0, 0, 0], 7),
      ('皇家铸币厂', '🏦', 4, 2, [0, 0, 0], 0, 3, [0, 1, 0], [0, 0, 0], 4),
    ];
    final list = <FurnaceFactoryCard>[];
    var id = 10;
    for (var copy = 0; copy < 2; copy++) {
      for (final t in templates) {
        list.add(FurnaceFactoryCard(
          id: id++,
          name: t.$1,
          emoji: t.$2,
          compType: t.$3,
          compAmount: t.$4,
          extractRes: t.$5,
          extractGears: t.$6,
          extractMoney: t.$7,
          costRes: t.$8,
          outRes: t.$9,
          outMoney: t.$10,
        ));
      }
    }
    return shuffled(list, rng);
  }

  void _dealMarket() {
    market = [];
    while (market.length < marketSize && deck.isNotEmpty) {
      market.add(deck.removeLast());
    }
    bids = List.generate(market.length, (_) => <FurnaceBid>[]);
    for (var s = 0; s < players; s++) {
      discsLeft[s] = [1, 2, 3, 4];
      productionDone[s] = false;
    }
    phase = 'auction';
    turn = (round - 1) % players;
  }

  @override
  void start() {
    deck = _buildDeck();
    discsLeft = List.generate(players, (_) => [1, 2, 3, 4]);
    resources = List.generate(players, (_) => [1, 0, 0]);
    gears = List.filled(players, 1);
    money = List.filled(players, 0);
    productionDone = List.filled(players, false);

    // Every player starts with a personal Start-Up Factory (already upgraded)
    factories = List.generate(
      players,
      (s) => [
        FurnaceFactoryCard(
          id: s + 1,
          name: '初创工坊',
          emoji: '🔨',
          compType: 0,
          compAmount: 1,
          extractRes: const [1, 0, 0],
          extractGears: 1,
          costRes: const [1, 0, 0],
          outMoney: 2,
          upgraded: true,
        ),
      ],
    );

    round = 1;
    over = false;
    _dealMarket();
    lastAction = '第 1 轮竞标开始，请放置资本圆片 (1~4)';
  }

  /// Checks whether [seat] can legally place [disc] on `market[slot]`.
  bool canBidOnSlot(int seat, int slot, int disc) {
    if (slot < 0 || slot >= market.length) return false;
    if (!discsLeft[seat].contains(disc)) return false;
    final slotBids = bids[slot];
    // Rule: no two discs of the same player on the same card
    if (slotBids.any((b) => b.seat == seat)) return false;
    // Rule: no two discs of the same value on the same card
    if (slotBids.any((b) => b.disc == disc)) return false;
    return true;
  }

  void _grantCompensation(int seat, FurnaceFactoryCard card, int discVal) {
    final total = discVal * card.compAmount;
    switch (card.compType) {
      case 0:
      case 1:
      case 2:
        resources[seat][card.compType] += total;
      case 3:
        gears[seat] += total;
      default:
        money[seat] += total;
    }
  }

  /// Resolves all market cards once all players have placed their 4 discs.
  void resolveAuction() {
    for (var s = 0; s < market.length; s++) {
      final card = market[s];
      final slotBids = bids[s];
      if (slotBids.isEmpty) continue;

      // Highest disc wins the card; all non-highest discs gain d * compensation!
      var maxIdx = 0;
      for (var i = 1; i < slotBids.length; i++) {
        if (slotBids[i].disc > slotBids[maxIdx].disc) {
          maxIdx = i;
        }
      }

      for (var i = 0; i < slotBids.length; i++) {
        final b = slotBids[i];
        if (i == maxIdx) {
          factories[b.seat].add(card.copyWith(usedThisRound: false));
        } else {
          _grantCompensation(b.seat, card, b.disc);
        }
      }
    }

    // Transition to Production phase
    phase = 'production';
    for (var s = 0; s < players; s++) {
      productionDone[s] = false;
      for (var i = 0; i < factories[s].length; i++) {
        factories[s][i] = factories[s][i].copyWith(usedThisRound: false);
      }
    }
    turn = (round - 1) % players;
    lastAction = '第 $round 轮竞标结算完毕！进入工业流水线生产阶段';
    host.log(lastAction);
  }

  bool canAffordConversion(int seat, FurnaceFactoryCard card) {
    for (var i = 0; i < 3; i++) {
      if (resources[seat][i] < card.costRes[i]) return false;
    }
    return true;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (phase == 'auction') {
      if (type != 'bid') {
        throw GameError('当前处于竞标阶段，请放置资本圆片 (bid)');
      }
      final slot = asInt(action['slot'], -1);
      final disc = asInt(action['disc'], -1);
      if (slot < 0 || slot >= market.length) {
        throw GameError('无效的工厂卡槽位');
      }
      if (!discsLeft[seat].contains(disc)) {
        throw GameError('你手上没有数值为 $disc 的可用圆片');
      }
      if (bids[slot].any((b) => b.seat == seat)) {
        throw GameError('同一张工厂卡上不能放置两枚自己的圆片');
      }

      // Check if any slot allows a strictly non-colliding value for `disc`
      final hasStrictLegal = [
        for (var s = 0; s < market.length; s++)
          for (final d in discsLeft[seat])
            if (canBidOnSlot(seat, s, d)) true,
      ].isNotEmpty;

      if (hasStrictLegal && bids[slot].any((b) => b.disc == disc)) {
        throw GameError('同一张工厂卡上不能放置相同点数 ($disc) 的圆片');
      }

      discsLeft[seat].remove(disc);
      bids[slot].add(FurnaceBid(seat: seat, disc: disc));
      final card = market[slot];
      lastAction =
          '${name(seat)} 在 ${card.emoji}${card.name} 上放置了点数 $disc 的圆片';
      host.log(lastAction);

      // Find next player with discs left
      for (var offset = 1; offset <= players; offset++) {
        final nextSeat = (turn + offset) % players;
        if (discsLeft[nextSeat].isNotEmpty) {
          turn = nextSeat;
          return;
        }
      }
      resolveAuction();
      return;
    }

    // Phase == 'production'
    switch (type) {
      case 'upgrade':
        final idx = asInt(action['factoryIdx'], -1);
        if (idx < 0 || idx >= factories[seat].length) {
          throw GameError('无效的工厂编号');
        }
        final card = factories[seat][idx];
        if (card.upgraded) {
          throw GameError('${card.name} 已经完成扩建升级');
        }
        if (gears[seat] < 1) {
          throw GameError('齿轮 (⚙️) 不足，无法升级工厂');
        }
        gears[seat] -= 1;
        factories[seat][idx] = card.copyWith(upgraded: true);
        lastAction = '${name(seat)} 消耗 1⚙️ 升级了 ${card.emoji}${card.name}';
        host.log(lastAction);

      case 'activate':
        final idx = asInt(action['factoryIdx'], -1);
        if (idx < 0 || idx >= factories[seat].length) {
          throw GameError('无效的工厂编号');
        }
        final card = factories[seat][idx];
        if (card.usedThisRound) {
          throw GameError('${card.name} 本轮已经运转过了');
        }

        // 1. Gain top extraction
        for (var i = 0; i < 3; i++) {
          resources[seat][i] += card.extractRes[i];
        }
        gears[seat] += card.extractGears;
        money[seat] += card.extractMoney;

        // 2. If upgraded and player can afford bottom conversion, run conversion
        var converted = false;
        if (card.upgraded && canAffordConversion(seat, card)) {
          for (var i = 0; i < 3; i++) {
            resources[seat][i] -= card.costRes[i];
            resources[seat][i] += card.outRes[i];
          }
          money[seat] += card.outMoney;
          converted = true;
        }

        factories[seat][idx] = card.copyWith(usedThisRound: true);
        final convStr = converted ? ' 并完成精炼转化 (+${card.outMoney}💰)' : '';
        lastAction = '${name(seat)} 运转 ${card.emoji}${card.name}$convStr';
        host.log(lastAction);

      case 'end_production':
        // Automatically activate any remaining unused factories before ending
        for (var i = 0; i < factories[seat].length; i++) {
          final card = factories[seat][i];
          if (card.usedThisRound) continue;
          for (var r = 0; r < 3; r++) {
            resources[seat][r] += card.extractRes[r];
          }
          gears[seat] += card.extractGears;
          money[seat] += card.extractMoney;
          if (card.upgraded && canAffordConversion(seat, card)) {
            for (var r = 0; r < 3; r++) {
              resources[seat][r] -= card.costRes[r];
              resources[seat][r] += card.outRes[r];
            }
            money[seat] += card.outMoney;
          }
          factories[seat][i] = card.copyWith(usedThisRound: true);
        }
        productionDone[seat] = true;
        lastAction = '${name(seat)} 完成了本轮工业生产 (当前 💰${money[seat]})';
        host.log(lastAction);
        _advanceProductionTurn();

      default:
        throw GameError('未知的生产阶段操作: $type');
    }
  }

  void _advanceProductionTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (!productionDone[nextSeat]) {
        turn = nextSeat;
        return;
      }
    }

    if (round >= maxRounds) {
      over = true;
      // Sell leftover resources at 2 resources = 1 Money tie-breaker bonus
      lastAction = '工业熔炉终局结算完成！总资金 (💰) 最高者获胜';
      host.log(lastAction);
      return;
    }

    round++;
    _dealMarket();
    lastAction = '第 $round 轮开始，请放置资本圆片进行竞标';
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'auction') {
      // Prefer placing highest available disc on an uncontested or winnable card,
      // or lower disc on a card with strong compensation!
      for (final d in discsLeft[seat].reversed) {
        for (var s = 0; s < market.length; s++) {
          if (canBidOnSlot(seat, s, d)) {
            return {'type': 'bid', 'slot': s, 'disc': d};
          }
        }
      }
      // Fallback if all slots collide on value
      final d = discsLeft[seat].first;
      for (var s = 0; s < market.length; s++) {
        if (!bids[s].any((b) => b.seat == seat)) {
          return {'type': 'bid', 'slot': s, 'disc': d};
        }
      }
      return null;
    }

    // Production phase:
    // 1. Upgrade any un-upgraded factory if we have gears
    if (gears[seat] > 0) {
      for (var i = 0; i < factories[seat].length; i++) {
        if (!factories[seat][i].upgraded) {
          return {'type': 'upgrade', 'factoryIdx': i};
        }
      }
    }
    // 2. Activate any unused factory
    for (var i = 0; i < factories[seat].length; i++) {
      if (!factories[seat][i].usedThisRound) {
        return {'type': 'activate', 'factoryIdx': i};
      }
    }
    // 3. End production
    return {'type': 'end_production'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'phase': phase,
      'over': over,
      'lastAction': lastAction,
      'market': [
        for (var s = 0; s < market.length; s++)
          {
            ...market[s].toJson(),
            'bids': [for (final b in bids[s]) b.toJson()],
          },
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': money[s],
            'money': money[s],
            'gears': gears[s],
            'resources': List<int>.of(resources[s]),
            'discsLeft': List<int>.of(discsLeft[s]),
            'productionDone': productionDone[s],
            'factories': [for (final f in factories[s]) f.toJson()],
          },
      ],
    };
  }
}
