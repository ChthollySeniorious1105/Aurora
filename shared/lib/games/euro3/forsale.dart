import 'dart:math';

import '../../src/engine.dart';

const List<String> kPropertyNames = [
  '', // 0 unused
  '纸箱屋', // 1
  '下水道', // 2
  '木制狗窝', // 3
  '露营帐篷', // 4
  '树洞小屋', // 5
  '茅草棚', // 6
  '北极冰屋', // 7
  '二手房车', // 8
  '集装箱房', // 9
  '林间木屋', // 10
  '老式公寓', // 11
  '乡间农舍', // 12
  '灯塔小屋', // 13
  '运河游艇', // 14
  '街角洋房', // 15
  '花园联排', // 16
  '湖畔别墅', // 17
  '现代复式', // 18
  '温泉山庄', // 19
  '顶层豪宅', // 20
  '海景大宅', // 21
  '贵族庄园', // 22
  '古典城堡', // 23
  '私人海岛', // 24
  '皇家宫殿', // 25
  '云端大厦', // 26
  '黄金金字塔', // 27
  '摩天大楼', // 28
  '海底城邦', // 29
  '太空站', // 30
];

String propertyName(int v) =>
    v >= 1 && v < kPropertyNames.length ? kPropertyNames[v] : '房产#$v';

const List<int> kAllChecks = [
  0, 0,
  2, 2,
  3, 3,
  4, 4,
  5, 5,
  6, 6,
  7, 7,
  8, 8,
  9, 9,
  10, 10,
  11, 11,
  12, 12,
  13, 13,
  14, 14,
  15, 15,
];

class ForSale extends GameEngine {
  late int initialCoins;
  late List<int> coins;
  late List<int> bids;
  late List<bool> inAuction;
  late List<List<int>> ownedProperties;
  late List<List<int>> wonChecks;
  late List<int> checkMoney;
  late List<int?> selectedProperty;

  List<int> propertyDeck = [];
  List<int> checkDeck = [];
  List<int> tableProperties = [];
  List<int> tableChecks = [];

  int turn = 0;
  int roundStarter = 0;
  int roundNum = 1;
  int totalRoundsPerPhase = 0;
  String phase = 'bid'; // 'bid' | 'sell' | 'end'

  List<Map<String, dynamic>> lastSellReveal = [];
  String lastAction = '';
  bool over = false;
  List<int> finalScores = [];

  ForSale(super.setup);

  int get currentHighBid => bids.isEmpty ? 0 : bids.reduce(max);

  @override
  void start() {
    final coinMode = setup.opt<String>('coins', 'standard');
    final baseCoins = players <= 4 ? 18 : 14;
    initialCoins = coinMode == 'rich' ? baseCoins + 4 : baseCoins;

    coins = List.filled(players, initialCoins);
    bids = List.filled(players, 0);
    inAuction = List.filled(players, true);
    ownedProperties = [for (var i = 0; i < players; i++) <int>[]];
    wonChecks = [for (var i = 0; i < players; i++) <int>[]];
    checkMoney = List.filled(players, 0);
    selectedProperty = List.filled(players, null);

    propertyDeck = shuffled([for (var v = 1; v <= 30; v++) v], rng);
    checkDeck = shuffled(kAllChecks, rng);

    // Remove remainder so deck is divisible by players (e.g. 2 removed in 4p)
    final rem = propertyDeck.length % players;
    if (rem > 0) {
      propertyDeck.removeRange(0, rem);
      checkDeck.removeRange(0, rem);
    }

    totalRoundsPerPhase = propertyDeck.length ~/ players;
    roundStarter = 0;
    roundNum = 0;
    phase = 'bid';
    over = false;
    lastSellReveal = [];
    _startBidRound();
  }

  void _startBidRound() {
    roundNum++;
    tableProperties = [
      for (var i = 0; i < players; i++) propertyDeck.removeLast(),
    ]..sort();
    bids = List.filled(players, 0);
    inAuction = List.filled(players, true);
    turn = roundStarter;
    lastAction = '第 $roundNum/$totalRoundsPerPhase 轮买房竞拍开始，轮到 ${name(turn)} 出价';
  }

  void _startSellRound() {
    roundNum++;
    tableChecks = [
      for (var i = 0; i < players; i++) checkDeck.removeLast(),
    ]..sort();
    selectedProperty = List.filled(players, null);
    lastAction = '第 $roundNum/$totalRoundsPerPhase 轮卖房变现：请同时暗选 1 张房产出售';
  }

  void _advanceBidder() {
    var next = (turn + 1) % players;
    for (var i = 0; i < players; i++) {
      if (inAuction[next]) {
        turn = next;
        return;
      }
      next = (next + 1) % players;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (seat != turn) throw GameError('还没轮到你竞拍');
      if (type == 'bid') {
        final amount = asInt(action['amount']);
        final high = currentHighBid;
        if (amount <= high) {
          throw GameError('出价必须高于当前最高出价（\$${high}k）');
        }
        if (amount > coins[seat]) {
          throw GameError('金币不足（你最多可出价 \$${coins[seat]}k）');
        }
        bids[seat] = amount;
        lastAction = '${name(seat)} 出价 \$${amount}k';
        host.log(lastAction);
        _advanceBidder();
        return;
      }
      if (type == 'pass') {
        final myBid = bids[seat];
        final cost = myBid ~/ 2;
        coins[seat] -= cost;
        bids[seat] = 0;
        inAuction[seat] = false;
        final lowProp = tableProperties.removeAt(0);
        ownedProperties[seat].add(lowProp);
        ownedProperties[seat].sort();

        final remaining = [
          for (var s = 0; s < players; s++)
            if (inAuction[s]) s
        ];
        if (remaining.length == 1) {
          final winner = remaining.first;
          final winBid = bids[winner];
          coins[winner] -= winBid;
          bids[winner] = 0;
          inAuction[winner] = false;
          final highProp = tableProperties.removeLast();
          ownedProperties[winner].add(highProp);
          ownedProperties[winner].sort();

          lastAction =
              '${name(seat)} 放弃（付 \$${cost}k 拿【$lowProp·${propertyName(lowProp)}】）；${name(winner)} 付 \$${winBid}k 竞得【$highProp·${propertyName(highProp)}】！';
          host.log(lastAction);

          roundStarter = winner;
          if (propertyDeck.length >= players) {
            _startBidRound();
          } else {
            phase = 'sell';
            roundNum = 0;
            _startSellRound();
          }
        } else {
          lastAction =
              '${name(seat)} 放弃竞价，支付 \$${cost}k 拿走【$lowProp·${propertyName(lowProp)}】';
          host.log(lastAction);
          _advanceBidder();
        }
        return;
      }
      throw GameError('请选择加注（bid）或放弃（pass）');
    }

    if (phase == 'sell') {
      if (seat < 0 || seat >= players || selectedProperty[seat] != null) {
        throw GameError('你本轮已选择过要出售的房产');
      }
      if (type != 'sell') throw GameError('请选择要出售的房产（sell）');
      final card = asInt(action['card']);
      if (!ownedProperties[seat].contains(card)) {
        throw GameError('你未拥有该房产牌');
      }
      selectedProperty[seat] = card;

      if (selectedProperty.every((c) => c != null)) {
        _resolveSellRound();
      } else {
        lastAction = '${name(seat)} 已暗选房产，等待其他玩家选择';
      }
      return;
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _resolveSellRound() {
    final order = [for (var s = 0; s < players; s++) s]
      ..sort((a, b) => selectedProperty[a]!.compareTo(selectedProperty[b]!));

    final reveal = <Map<String, dynamic>>[];
    final logParts = <String>[];
    for (var i = 0; i < players; i++) {
      final s = order[i];
      final prop = selectedProperty[s]!;
      final chk = tableChecks[i];
      ownedProperties[s].remove(prop);
      wonChecks[s].add(chk);
      checkMoney[s] += chk;
      reveal.add({
        'seat': s,
        'name': name(s),
        'property': prop,
        'propertyName': propertyName(prop),
        'check': chk,
      });
      logParts.add('${name(s)}(房产$prop→\$${chk}k)');
    }
    lastSellReveal = reveal;
    lastAction = '第 $roundNum 轮卖房结果：${logParts.join('，')}';
    host.log(lastAction);

    if (ownedProperties[0].isNotEmpty && checkDeck.length >= players) {
      _startSellRound();
    } else {
      _endGame();
    }
  }

  void _endGame() {
    over = true;
    phase = 'end';
    finalScores = [
      for (var s = 0; s < players; s++) checkMoney[s] + coins[s],
    ];
    final best = finalScores.reduce(max);
    final winNames = [
      for (var s = 0; s < players; s++)
        if (finalScores[s] == best) name(s)
    ].join('、');
    lastAction = '游戏结束！$winNames 以总资产 \$${best}k 赢得胜利！';
    host.log(lastAction);
  }

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'bid') return [turn];
    if (phase == 'sell') {
      return [
        for (var s = 0; s < players; s++)
          if (selectedProperty[s] == null) s
      ];
    }
    return const [];
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    // Tiebreaker: remaining coins
    final composite = [
      for (var s = 0; s < players; s++) finalScores[s] * 100 + coins[s],
    ];
    return rankByScore(composite);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'phase': phase,
      'turn': turn,
      'roundStarter': roundStarter,
      'roundNum': roundNum,
      'totalRounds': totalRoundsPerPhase,
      'highBid': currentHighBid,
      'tableProperties': [
        for (final p in tableProperties)
          {
            'value': p,
            'name': propertyName(p),
          },
      ],
      'tableChecks': List<int>.of(tableChecks),
      'propertyDeckCount': propertyDeck.length,
      'checkDeckCount': checkDeck.length,
      'lastSellReveal': lastSellReveal,
      'lastAction': lastAction,
      'over': over,
      'myProperties': seat >= 0 && seat < players
          ? [
              for (final p in ownedProperties[seat])
                {'value': p, 'name': propertyName(p)},
            ]
          : const [],
      'mySelectedProperty':
          seat >= 0 && seat < players ? selectedProperty[seat] : null,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'coins': coins[s],
            'bid': bids[s],
            'inAuction': inAuction[s],
            'propertyCount': ownedProperties[s].length,
            // In Phase 1 owned properties are face-up / public in For Sale,
            // in Phase 2 keep opponents' remaining properties hidden so secret play stays suspenseful
            'properties': (phase == 'bid' || s == seat || over)
                ? List<int>.of(ownedProperties[s])
                : const <int>[],
            'checkMoney': (s == seat || over) ? checkMoney[s] : null,
            'checkCount': wonChecks[s].length,
            'chosenSell': selectedProperty[s] != null,
            if (over) 'score': finalScores[s],
          },
      ],
      if (over)
        'final': [
          for (var s = 0; s < players; s++)
            {
              'seat': s,
              'name': name(s),
              'checkMoney': checkMoney[s],
              'coins': coins[s],
              'score': finalScores[s],
              'win': finalScores[s] == finalScores.reduce(max),
            },
        ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || !waitingFor.contains(seat)) return null;

    if (phase == 'bid') {
      final high = currentHighBid;
      final minNextBid = high + 1;
      if (minNextBid > coins[seat]) {
        return {'type': 'pass'};
      }
      if (botLevel == 0) {
        if (rng.nextBool()) {
          return {'type': 'bid', 'amount': minNextBid};
        }
        return {'type': 'pass'};
      }

      // Evaluate spread of tableProperties
      final lowProp = tableProperties.first;
      final highProp = tableProperties.last;
      final spread = highProp - lowProp;
      // Max reasonable bid based on spread and remaining rounds
      final maxReasonable = min(coins[seat], max(1, (spread ~/ 3) + (highProp ~/ 6)));
      if (minNextBid <= maxReasonable) {
        return {'type': 'bid', 'amount': minNextBid};
      }
      return {'type': 'pass'};
    }

    if (phase == 'sell') {
      final props = ownedProperties[seat];
      if (props.isEmpty) return null;
      if (props.length == 1 || botLevel == 0) {
        return {'type': 'sell', 'card': props[rng.nextInt(props.length)]};
      }

      // Smart Phase 2 heuristic using ONLY seat's own properties and tableChecks:
      // High check variance or high top check -> play high property;
      // Low top check -> dump lowest property!
      final topCheck = tableChecks.last;
      final lowCheck = tableChecks.first;
      if (topCheck >= 12 && (topCheck - lowCheck) >= 6) {
        return {'type': 'sell', 'card': props.last};
      }
      if (topCheck <= 6) {
        return {'type': 'sell', 'card': props.first};
      }
      return {'type': 'sell', 'card': props[props.length ~/ 2]};
    }

    return null;
  }
}
