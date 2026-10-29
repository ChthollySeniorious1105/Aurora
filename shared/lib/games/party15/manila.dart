import 'dart:math';

import '../../src/engine.dart';

const List<String> kManilaCargos = [
  '🟢 玉器',
  '🟣 丝绸',
  '🟠 肉豆蔻',
  '🟡 人参',
];

const List<int> kManilaPayouts = [36, 30, 24, 18];

const List<List<int>> kManilaSeatCosts = [
  [3, 4, 5, 5], // 0: Jade (4 seats)
  [3, 4, 5], // 1: Silk (3 seats)
  [2, 3, 4], // 2: Nutmeg (3 seats)
  [1, 2, 3], // 3: Ginseng (3 seats)
];

const List<int> kManilaPortCosts = [4, 3, 2];
const List<int> kManilaPortPayouts = [6, 8, 15];
const List<int> kManilaShipyardCosts = [4, 3, 2];
const List<int> kManilaShipyardPayouts = [6, 8, 15];
const int kManilaPirateCost = 5;
const int kManilaInsuranceBonus = 10;

class ManilaGame extends GameEngine {
  ManilaGame(super.setup);

  late List<int> pesos;
  late List<List<int>> stocks; // stocks[seat][0..3]
  List<int> stockPrice = [0, 0, 0, 0];

  int voyage = 1;
  int maxVoyages = 4;
  String phase = 'bid'; // 'bid', 'place', 'over'
  int turn = 0;

  // Bidding state
  int harborMaster = 0;
  int highBid = 0;
  int highBidder = 0;
  late List<bool> passed;
  int? pendingHmStock;
  List<int>? pendingHmPositions;

  // Voyage board state
  List<int> boatPos = [3, 2, 2, 2]; // sum == 9, each 0..5
  late List<List<int?>> boatSeats;
  List<int?> portSeats = [null, null, null];
  List<int?> shipyardSeats = [null, null, null];
  List<int> pirates = [];
  int? insuranceSeat;

  int placeRound = 1;
  int placedInRound = 0;
  List<int> lastDice = [];
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  List<int> get scores => [
        for (var s = 0; s < players; s++)
          pesos[s] +
              <int>[
                for (var c = 0; c < 4; c++) stocks[s][c] * max<int>(5, stockPrice[c]),
              ].fold<int>(0, (a, b) => a + b),
      ];

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    maxVoyages = fast ? 3 : 4;
    pesos = List<int>.filled(players, 30);
    stocks = [
      for (var s = 0; s < players; s++) [0, 0, 0, 0],
    ];
    final deck = <int>[
      for (var c = 0; c < 4; c++)
        for (var i = 0; i < 5; i++) c,
    ]..shuffle(rng);
    var idx = 0;
    for (var s = 0; s < players; s++) {
      stocks[s][deck[idx++]]++;
      stocks[s][deck[idx++]]++;
    }
    stockPrice = [0, 0, 0, 0];
    voyage = 1;
    _over = false;
    _startVoyageBidding(0);
    lastEvent = '马尼拉海运启航！第 1 航次港务长竞拍开始，轮到 ${name(turn)} 出价。';
    host.log(lastEvent);
  }

  void _startVoyageBidding(int startSeat) {
    phase = 'bid';
    turn = startSeat;
    harborMaster = startSeat;
    highBid = 0;
    highBidder = startSeat;
    passed = List<bool>.filled(players, false);
    pendingHmStock = null;
    pendingHmPositions = null;
    _resetVoyageBoard();
  }

  void _resetVoyageBoard() {
    boatPos = [3, 2, 2, 2]; // sum == 9, each 0..5
    boatSeats = [
      for (var b = 0; b < 4; b++) List<int?>.filled(kManilaSeatCosts[b].length, null),
    ];
    portSeats = [null, null, null];
    shipyardSeats = [null, null, null];
    pirates = [];
    insuranceSeat = null;
    placeRound = 1;
    placedInRound = 0;
    lastDice = [];
  }

  void _finalizeHarborMaster(int winner, int price) {
    harborMaster = winner;
    pesos[winner] = max(0, pesos[winner] - price);

    // Harbor Master optionally buys 1 stock share at max(5, stockPrice[c])
    final buyCargo = pendingHmStock ?? _bestAffordableStock(winner);
    if (buyCargo != null && buyCargo >= 0 && buyCargo < 4) {
      final shareCost = max(5, stockPrice[buyCargo]);
      if (pesos[winner] >= shareCost) {
        pesos[winner] -= shareCost;
        stocks[winner][buyCargo]++;
      }
    }

    // Set initial boat positions (sum == 9, each 0..5)
    if (pendingHmPositions != null && _validInitialPositions(pendingHmPositions!)) {
      boatPos = List<int>.of(pendingHmPositions!);
    } else {
      boatPos = _chooseInitialPositionsFor(winner);
    }

    phase = 'place';
    placeRound = 1;
    placedInRound = 0;
    turn = harborMaster;
    lastEvent =
        '${name(harborMaster)} 以 $price 比索当选第 $voyage 航次港务长，设定货船初始位置为 $boatPos！';
    host.log(lastEvent);
  }

  int? _bestAffordableStock(int seat) {
    for (var c = 0; c < 4; c++) {
      final cost = max(5, stockPrice[c]);
      if (pesos[seat] >= cost + 6) return c;
    }
    return null;
  }

  List<int> _chooseInitialPositionsFor(int seat) {
    // Prioritize cargos that [seat] owns shares in; sum must be 9, each 0..5
    final order = [0, 1, 2, 3]
      ..sort((a, b) {
        final cmp = stocks[seat][b].compareTo(stocks[seat][a]);
        return cmp != 0 ? cmp : a.compareTo(b);
      });
    final pos = [0, 0, 0, 0];
    const preset = [4, 3, 2, 0];
    for (var i = 0; i < 4; i++) {
      pos[order[i]] = preset[i];
    }
    return pos;
  }

  bool _validInitialPositions(List<int> pos) {
    if (pos.length != 4) return false;
    var sum = 0;
    for (final p in pos) {
      if (p < 0 || p > 5) return false;
      sum += p;
    }
    return sum == 9;
  }

  void _advanceBidTurn() {
    final active = [
      for (var s = 0; s < players; s++)
        if (!passed[s]) s,
    ];
    if (active.isEmpty) {
      _finalizeHarborMaster(highBidder, highBid);
      return;
    }
    if (active.length == 1 && (highBid > 0 || passed.where((p) => p).length == players - 1)) {
      _finalizeHarborMaster(active.first, highBid);
      return;
    }
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!passed[next]) {
        turn = next;
        return;
      }
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type == 'pass' || (type == 'bid' && asInt(action['amount'], 0) <= 0)) {
        passed[seat] = true;
        lastEvent = '${name(seat)} 放弃竞拍港务长。';
        host.log(lastEvent);
        _advanceBidTurn();
        return;
      }
      if (type == 'bid') {
        final amount = asInt(action['amount']);
        if (amount <= highBid) {
          throw GameError('出价必须高于当前最高价 $highBid 比索');
        }
        if (amount > pesos[seat]) {
          throw GameError('比索不足（当前拥有 ${pesos[seat]} 比索）');
        }
        highBid = amount;
        highBidder = seat;
        if (action.containsKey('stock')) {
          pendingHmStock = asInt(action['stock']);
        }
        if (action['positions'] is List) {
          final pos = asIntList(action['positions']);
          if (!_validInitialPositions(pos)) {
            throw GameError('初始船位必须是4个0~5之间的整数，且总和等于9');
          }
          pendingHmPositions = pos;
        }
        lastEvent = '${name(seat)} 出价 $amount 比索竞拍港务长！';
        host.log(lastEvent);
        // Check if everyone else already passed
        final othersActive = [
          for (var s = 0; s < players; s++)
            if (s != seat && !passed[s]) s,
        ];
        if (othersActive.isEmpty) {
          _finalizeHarborMaster(seat, highBid);
        } else {
          _advanceBidTurn();
        }
        return;
      }
      throw GameError('竞拍阶段请出价(bid)或跳过(pass)');
    }

    if (phase == 'place') {
      if (type == 'set_boats' || type == 'harbor_master') {
        if (seat != harborMaster || placeRound != 1 || placedInRound != 0) {
          throw GameError('只有港务长在本航次首次派遣前可调整货船初始位置');
        }
        final pos = asIntList(action['positions']);
        if (!_validInitialPositions(pos)) {
          throw GameError('初始船位必须是4个0~5之间的整数，且总和等于9');
        }
        boatPos = pos;
        lastEvent = '港务长 ${name(seat)} 设定货船初始位置为 $boatPos。';
        host.log(lastEvent);
        return;
      }

      if (type == 'pass') {
        lastEvent = '${name(seat)} 本轮跳过派遣同伙。';
        host.log(lastEvent);
        _afterPlayerPlace();
        return;
      }

      if (type != 'place') {
        throw GameError('未知操作：$type');
      }

      final spot = asStr(action['spot'], 'boat');
      switch (spot) {
        case 'boat':
          final b = asInt(action['boat']);
          if (b < 0 || b >= 4) throw GameError('无效的货船编号');
          if (boatPos[b] >= 14) throw GameError('该货船已抵达港口');
          var seatIdx = asInt(action['seatIndex'], -1);
          if (seatIdx < 0) {
            seatIdx = boatSeats[b].indexWhere((s) => s == null);
          }
          if (seatIdx < 0 || seatIdx >= boatSeats[b].length || boatSeats[b][seatIdx] != null) {
            throw GameError('该货船舱位已满或无效');
          }
          final cost = kManilaSeatCosts[b][seatIdx];
          if (pesos[seat] < cost) throw GameError('比索不足（需要 $cost 比索）');
          pesos[seat] -= cost;
          boatSeats[b][seatIdx] = seat;
          lastEvent = '${name(seat)} 花费 $cost 比索登上 ${kManilaCargos[b]}（${seatIdx + 1}号舱位）。';
          host.log(lastEvent);

        case 'port':
          var idx = asInt(action['index'], -1);
          if (idx < 0) {
            idx = portSeats.indexWhere((s) => s == null);
          }
          if (idx < 0 || idx >= 3 || portSeats[idx] != null) {
            throw GameError('该港口码头位已被占用');
          }
          final cost = kManilaPortCosts[idx];
          if (pesos[seat] < cost) throw GameError('比索不足（需要 $cost 比索）');
          pesos[seat] -= cost;
          portSeats[idx] = seat;
          lastEvent =
              '${name(seat)} 花费 $cost 比索入驻港口 ${idx + 1} 号码头（到港奖励 +${kManilaPortPayouts[idx]} 比索）。';
          host.log(lastEvent);

        case 'shipyard':
          var idx = asInt(action['index'], -1);
          if (idx < 0) {
            idx = shipyardSeats.indexWhere((s) => s == null);
          }
          if (idx < 0 || idx >= 3 || shipyardSeats[idx] != null) {
            throw GameError('该修船厂位已被占用');
          }
          final cost = kManilaShipyardCosts[idx];
          if (pesos[seat] < cost) throw GameError('比索不足（需要 $cost 比索）');
          pesos[seat] -= cost;
          shipyardSeats[idx] = seat;
          lastEvent =
              '${name(seat)} 花费 $cost 比索入驻修船厂 ${idx + 1} 号位（沉船奖励 +${kManilaShipyardPayouts[idx]} 比索）。';
          host.log(lastEvent);

        case 'pirate':
          if (pirates.length >= 2) throw GameError('海盗湾名额已满');
          if (pesos[seat] < kManilaPirateCost) {
            throw GameError('比索不足（需要 $kManilaPirateCost 比索）');
          }
          pesos[seat] -= kManilaPirateCost;
          pirates.add(seat);
          lastEvent = '${name(seat)} 花费 $kManilaPirateCost 比索加入🏴‍☠️海盗湾（13格劫船）！';
          host.log(lastEvent);

        case 'insurance':
          if (insuranceSeat != null) throw GameError('保险公司已被占用');
          insuranceSeat = seat;
          pesos[seat] += kManilaInsuranceBonus;
          lastEvent = '${name(seat)} 入驻🛡️保险公司，立即领取 +$kManilaInsuranceBonus 比索（需承担沉船修船费）！';
          host.log(lastEvent);

        default:
          throw GameError('未知的派遣位置：$spot');
      }

      _afterPlayerPlace();
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _afterPlayerPlace() {
    placedInRound++;
    if (placedInRound < players) {
      turn = (turn + 1) % players;
      return;
    }

    // All players placed in this round -> roll 4 dice!
    lastDice = [for (var b = 0; b < 4; b++) 1 + rng.nextInt(6)];
    for (var b = 0; b < 4; b++) {
      if (boatPos[b] < 14) {
        boatPos[b] += lastDice[b];
      }
    }

    // Check Pirate space 13 on round 2 (board empty seat)
    if (placeRound == 2 && pirates.isNotEmpty) {
      for (var b = 0; b < 4; b++) {
        if (boatPos[b] == 13) {
          final emptyIdx = boatSeats[b].indexWhere((s) => s == null);
          if (emptyIdx >= 0 && pirates.isNotEmpty) {
            boatSeats[b][emptyIdx] = pirates.first;
          }
        }
      }
    }

    if (placeRound < 3 && boatPos.any((p) => p < 14)) {
      final rolledRound = placeRound;
      placeRound++;
      placedInRound = 0;
      turn = harborMaster;
      lastEvent = '第 $rolledRound 轮掷骰 $lastDice，当前船位 $boatPos！进入第 $placeRound 轮派遣。';
      host.log(lastEvent);
      return;
    }

    // End of 3rd roll (or all boats arrived) -> Settle Voyage!
    _settleVoyage();
  }

  void _settleVoyage() {
    var arrivedCount = 0;
    var wreckedCount = 0;

    for (var b = 0; b < 4; b++) {
      if (boatPos[b] == 13 && pirates.isNotEmpty) {
        // Hijacked by Pirates on space 13!
        final share = kManilaPayouts[b] ~/ pirates.length;
        for (final p in pirates) {
          pesos[p] += share;
        }
        // Hijacked boat is plundered
        wreckedCount++;
      } else if (boatPos[b] >= 14) {
        // Arrived at Port!
        arrivedCount++;
        final crew = [
          for (final s in boatSeats[b])
            if (s != null) s,
        ];
        if (crew.isNotEmpty) {
          final share = kManilaPayouts[b] ~/ crew.length;
          for (final s in crew) {
            pesos[s] += share;
          }
        }
        // Advance Stock Price (+5 when < 10, +10 when >= 10, max 30)
        final inc = stockPrice[b] < 10 ? 5 : 10;
        stockPrice[b] = min(30, stockPrice[b] + inc);
      } else {
        // Wrecked (< 14)
        wreckedCount++;
      }
    }

    // Port payouts (+6 / +8 / +15)
    for (var i = 0; i < min(3, arrivedCount); i++) {
      final s = portSeats[i];
      if (s != null) {
        pesos[s] += kManilaPortPayouts[i];
      }
    }

    // Shipyard payouts (+6 / +8 / +15) & Insurance liability
    var repairLiability = 0;
    for (var i = 0; i < min(3, wreckedCount); i++) {
      final payout = kManilaShipyardPayouts[i];
      repairLiability += payout;
      final s = shipyardSeats[i];
      if (s != null) {
        pesos[s] += payout;
      }
    }
    if (insuranceSeat != null && repairLiability > 0) {
      pesos[insuranceSeat!] = max(0, pesos[insuranceSeat!] - repairLiability);
    }

    // Check game end
    if (voyage >= maxVoyages || stockPrice.any((p) => p >= 30)) {
      _over = true;
      phase = 'over';
      final sc = scores;
      final best = sc.reduce(max);
      final winners = [
        for (var s = 0; s < players; s++)
          if (sc[s] == best) name(s),
      ];
      lastEvent =
          '第 $voyage 航次结算完成（到港 $arrivedCount 艘，失事 $wreckedCount 艘）！终局获胜：${winners.join('、')}（$best 比索）！';
      host.log(lastEvent);
      return;
    }

    final finishedVoyage = voyage;
    voyage++;
    final nextStarter = (harborMaster + 1) % players;
    _startVoyageBidding(nextStarter);
    lastEvent =
        '第 $finishedVoyage 航次结算完成（到港 $arrivedCount 艘，股价 $stockPrice）！开始第 $voyage 航次港务长竞拍。';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      final maxWilling = botLevel == 0 ? 3 : 6;
      if (highBid < maxWilling && pesos[seat] > highBid + 10) {
        return {'type': 'bid', 'amount': highBid + 1};
      }
      return {'type': 'pass'};
    }

    if (phase == 'place') {
      // 1. Insurance is free and gives +10 Pesos immediately
      if (insuranceSeat == null && placeRound == 1) {
        return {'type': 'place', 'spot': 'insurance'};
      }

      // 2. Place on best positioned boat that has an empty affordable seat
      final boatsByPos = [0, 1, 2, 3]..sort((a, b) => boatPos[b].compareTo(boatPos[a]));
      for (final b in boatsByPos) {
        if (boatPos[b] >= 14 || boatPos[b] < 2) continue;
        final seatIdx = boatSeats[b].indexWhere((s) => s == null);
        if (seatIdx >= 0 && pesos[seat] >= kManilaSeatCosts[b][seatIdx]) {
          return {'type': 'place', 'spot': 'boat', 'boat': b, 'seatIndex': seatIdx};
        }
      }

      // 3. Port slot
      final portIdx = portSeats.indexWhere((s) => s == null);
      if (portIdx >= 0 && pesos[seat] >= kManilaPortCosts[portIdx]) {
        return {'type': 'place', 'spot': 'port', 'index': portIdx};
      }

      // 4. Shipyard slot
      final yardIdx = shipyardSeats.indexWhere((s) => s == null);
      if (yardIdx >= 0 && pesos[seat] >= kManilaShipyardCosts[yardIdx]) {
        return {'type': 'place', 'spot': 'shipyard', 'index': yardIdx};
      }

      // 5. Any affordable boat seat
      for (var b = 0; b < 4; b++) {
        if (boatPos[b] >= 14) continue;
        final seatIdx = boatSeats[b].indexWhere((s) => s == null);
        if (seatIdx >= 0 && pesos[seat] >= kManilaSeatCosts[b][seatIdx]) {
          return {'type': 'place', 'spot': 'boat', 'boat': b, 'seatIndex': seatIdx};
        }
      }

      if (insuranceSeat == null) {
        return {'type': 'place', 'spot': 'insurance'};
      }

      return {'type': 'pass'};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'turn': turn,
        'phase': phase,
        'voyage': voyage,
        'maxVoyages': maxVoyages,
        'harborMaster': harborMaster,
        'highBid': highBid,
        'highBidder': highBidder,
        'passed': List<bool>.of(passed),
        'pesos': List<int>.of(pesos),
        'stocks': [for (var s = 0; s < players; s++) List<int>.of(stocks[s])],
        'stockPrice': List<int>.of(stockPrice),
        'boatPos': List<int>.of(boatPos),
        'boatSeats': [for (var b = 0; b < 4; b++) List<int?>.of(boatSeats[b])],
        'portSeats': List<int?>.of(portSeats),
        'shipyardSeats': List<int?>.of(shipyardSeats),
        'pirates': List<int>.of(pirates),
        'insuranceSeat': insuranceSeat,
        'placeRound': placeRound,
        'placedInRound': placedInRound,
        'lastDice': List<int>.of(lastDice),
        'scores': scores,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
