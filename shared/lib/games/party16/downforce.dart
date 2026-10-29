import 'dart:math';

import '../../src/engine.dart';

const List<String> kDownforceCars = [
  '🟥 红车',
  '🟦 蓝车',
  '🟩 绿车',
  '🟨 黄车',
  '🟪 紫车',
  '⬛ 黑车',
];

const List<int> kDownforceFinishPrizes = [12, 9, 6, 4, 2, 0];

const List<List<int>> kDownforceBetPayouts = [
  [9, 6, 3], // Line 1: 1st=$9M, 2nd=$6M, 3rd=$3M
  [6, 4, 2], // Line 2: 1st=$6M, 2nd=$4M, 3rd=$2M
  [3, 2, 1], // Line 3: 1st=$3M, 2nd=$2M, 3rd=$1M
];

class DownforceGame extends GameEngine {
  DownforceGame(super.setup);

  int trackLen = 36;
  List<int> chicanes = [7, 15, 23, 31];
  List<int> betLines = [9, 18, 27];

  String phase = 'auction'; // 'auction', 'race', 'bet', 'over'
  int turn = 0;

  // Phase 1: Car Auction
  int auctionCar = 0; // 0..5
  late List<int?> currentBids; // currentBids[seat] for auctionCar
  List<int?> carOwner = List<int?>.filled(6, null);
  late List<List<int>> ownedCars;
  late List<int> auctionCost;

  // Phase 2: Race & Betting
  List<int> carPos = [0, 0, 0, 0, 0, 0];
  List<int> carLane = [0, 1, 0, 1, 0, 1];
  List<int> finishOrder = [];

  late List<List<Map<int, int>>> hands; // hands[seat] = list of speed cards
  List<Map<int, int>> speedDeck = [];

  int betStage = 0; // 0, 1, 2 (how many betting lines have been triggered)
  late List<List<int?>> bets; // bets[seat][0..2] = car index 0..5

  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  List<int> get currentStandings {
    final order = List<int>.of(finishOrder);
    final rem = [
      for (var c = 0; c < 6; c++)
        if (!order.contains(c)) c,
    ]..sort((a, b) {
        final cmp = carPos[b].compareTo(carPos[a]);
        return cmp != 0 ? cmp : carLane[a].compareTo(carLane[b]);
      });
    return [...order, ...rem];
  }

  List<int> get scores {
    final standings = currentStandings;
    return [
      for (var s = 0; s < players; s++) _calcWinnings(s, standings),
    ];
  }

  int _calcWinnings(int seat, List<int> standings) {
    var total = -auctionCost[seat];
    for (var c = 0; c < 6; c++) {
      if (carOwner[c] == seat) {
        final rank = standings.indexOf(c);
        if (rank >= 0 && rank < kDownforceFinishPrizes.length) {
          total += kDownforceFinishPrizes[rank];
        }
      }
    }
    for (var line = 0; line < 3; line++) {
      final betCar = bets[seat][line];
      if (betCar != null) {
        final rank = standings.indexOf(betCar);
        if (rank >= 0 && rank < 3) {
          total += kDownforceBetPayouts[line][rank];
        }
      }
    }
    return total;
  }

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'auction') return [turn];
    if (phase == 'race') return [turn];
    if (phase == 'bet') {
      return [
        for (var s = 0; s < players; s++)
          if (bets[s][betStage] == null) s,
      ];
    }
    return const [];
  }

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    trackLen = fast ? 26 : 36;
    chicanes = fast ? [5, 11, 17, 22] : [7, 15, 23, 31];
    betLines = fast ? [6, 13, 20] : [9, 18, 27];

    phase = 'auction';
    turn = 0;
    auctionCar = 0;
    currentBids = List<int?>.filled(players, null);
    carOwner = List<int?>.filled(6, null);
    ownedCars = [for (var s = 0; s < players; s++) <int>[]];
    auctionCost = List<int>.filled(players, 0);

    carPos = [0, 0, 0, 0, 0, 0];
    carLane = [0, 1, 0, 1, 0, 1];
    finishOrder = [];

    betStage = 0;
    bets = [
      for (var s = 0; s < players; s++) <int?>[null, null, null],
    ];

    _buildSpeedDeck();
    hands = [
      for (var s = 0; s < players; s++)
        [
          for (var i = 0; i < 4; i++) _drawSpeedCard(),
        ],
    ];

    _over = false;
    lastEvent =
        '🏎️ 极速方程式开幕！第 1 阶段【百万美元赛车竞拍】：当前竞拍 ${kDownforceCars[0]}，轮到 ${name(turn)} 出价！';
    host.log(lastEvent);
  }

  void _buildSpeedDeck() {
    final cards = <Map<int, int>>[];
    for (var i = 0; i < 36; i++) {
      final order = shuffled([0, 1, 2, 3, 4, 5], rng);
      final count = 4 + (i % 3); // 4, 5, or 6 cars on each card
      const speeds = [6, 5, 4, 3, 2, 1];
      final map = <int, int>{};
      for (var j = 0; j < count; j++) {
        map[order[j]] = speeds[j];
      }
      cards.add(map);
    }
    speedDeck = cards;
  }

  Map<int, int> _drawSpeedCard() {
    if (speedDeck.isEmpty) _buildSpeedDeck();
    return speedDeck.removeLast();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'auction') {
      if (seat != turn) throw GameError('还没轮到你出价');
      if (type != 'bid') throw GameError('竞拍阶段请出价 (bid)');

      final amount = asInt(action['amount'], asInt(action['bid'], -1));
      if (amount < 1 || amount > 6) {
        throw GameError('竞拍出价必须在 \$1M ~ \$6M 之间');
      }
      currentBids[seat] = amount;

      if (currentBids.every((b) => b != null)) {
        _resolveCarAuction();
      } else {
        turn = (turn + 1) % players;
      }
      return;
    }

    if (phase == 'race') {
      if (seat != turn) throw GameError('还没轮到你出牌');
      if (type != 'play') throw GameError('比赛阶段请打出速度卡 (play)');

      final cardIdx = asInt(action['cardIdx'], 0);
      if (cardIdx < 0 || cardIdx >= hands[seat].length) {
        throw GameError('无效的手牌索引');
      }
      final card = hands[seat].removeAt(cardIdx);
      hands[seat].add(_drawSpeedCard());

      final movedCount = moveCarsByCard(card);
      if (movedCount == 0) {
        // Ensure forward race progress if all listed cars were blocked behind a chicane
        final unfin = [
          for (var c = 0; c < 6; c++)
            if (carPos[c] < trackLen) c,
        ]..sort((a, b) => carPos[b].compareTo(carPos[a]));
        if (unfin.isNotEmpty) {
          moveSingleCar(unfin.first, 1);
        }
      }

      lastEvent =
          '🏎️ ${name(seat)} 打出速度卡推进赛车！当前领跑位置：${carPos.reduce(max)}/$trackLen。';
      host.log(lastEvent);

      // Check if lead car crossed the next Betting Line!
      final leadPos = carPos.reduce(max);
      if (betStage < 3 && leadPos >= betLines[betStage] && finishOrder.length < 6) {
        phase = 'bet';
        lastEvent =
            '🏁 领跑赛车越过第 ${betStage + 1} 条押注线（第 ${betLines[betStage]} 格）！请全体玩家秘密押注前三名赛车！';
        host.log(lastEvent);
        return;
      }

      if (_checkRaceEnd()) return;
      turn = (turn + 1) % players;
      return;
    }

    if (phase == 'bet') {
      if (type != 'bet') throw GameError('押注阶段请选择押注赛车 (bet)');
      if (bets[seat][betStage] != null) throw GameError('你已完成本轮押注');

      final car = asInt(action['car'], -1);
      if (car < 0 || car >= 6) throw GameError('赛车编号必须在 0~5 之间');

      bets[seat][betStage] = car;
      lastEvent = '${name(seat)} 完成了第 ${betStage + 1} 线秘密押注！';
      host.log(lastEvent);

      if (waitingFor.isEmpty) {
        final finishedLine = betStage + 1;
        betStage++;
        if (_checkRaceEnd()) return;
        // Check if lead car also already crossed the next betting line
        final leadPos = carPos.reduce(max);
        if (betStage < 3 && leadPos >= betLines[betStage]) {
          lastEvent =
              '🏁 第 $finishedLine 线押注完成！领跑赛车已同时越过第 ${betStage + 1} 条押注线，请继续秘密押注！';
          host.log(lastEvent);
          return;
        }
        phase = 'race';
        turn = (turn + 1) % players;
        lastEvent = '🏁 第 $finishedLine 线全员押注完毕，比赛继续！轮到 ${name(turn)} 出牌。';
        host.log(lastEvent);
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _resolveCarAuction() {
    var winner = 0;
    var bestScore = -1;
    final remainingCarsAfterThis = 5 - auctionCar;
    final carlessPlayers = [
      for (var s = 0; s < players; s++)
        if (ownedCars[s].isEmpty) s,
    ];
    final mustGiveToCarless =
        carlessPlayers.isNotEmpty && carlessPlayers.length > remainingCarsAfterThis;

    for (var s = 0; s < players; s++) {
      if (mustGiveToCarless && !carlessPlayers.contains(s)) continue;
      final b = currentBids[s] ?? 1;
      // Tie-break in favor of players with fewer owned cars
      final score = b * 10 - ownedCars[s].length;
      if (score > bestScore) {
        bestScore = score;
        winner = s;
      }
    }

    final winningBid = currentBids[winner] ?? 1;
    carOwner[auctionCar] = winner;
    ownedCars[winner].add(auctionCar);
    auctionCost[winner] += winningBid;

    final wonCarName = kDownforceCars[auctionCar];
    auctionCar++;
    currentBids = List<int?>.filled(players, null);

    if (auctionCar >= 6) {
      phase = 'race';
      turn = 0;
      lastEvent =
          '🔨 ${name(winner)} 以 \$${winningBid}M 拍下 $wonCarName！6 辆赛车全部名花有主，正式发车进入竞速阶段！';
      host.log(lastEvent);
    } else {
      turn = 0;
      lastEvent =
          '🔨 ${name(winner)} 以 \$${winningBid}M 拍下 $wonCarName！接下来竞拍 ${kDownforceCars[auctionCar]}。';
      host.log(lastEvent);
    }
  }

  /// Moves all cars listed on [card] in descending speed order.
  /// Returns total spaces moved across all cars.
  int moveCarsByCard(Map<int, int> card) {
    final entries = card.entries.toList()
      ..sort((a, b) {
        final cmp = b.value.compareTo(a.value);
        return cmp != 0 ? cmp : carPos[b.key].compareTo(carPos[a.key]);
      });
    var totalMoved = 0;
    for (final entry in entries) {
      totalMoved += moveSingleCar(entry.key, entry.value);
    }
    return totalMoved;
  }

  /// Moves [car] forward up to [steps] spaces, respecting 2-lane straights
  /// and 1-lane Chicane chokepoints.
  int moveSingleCar(int car, int steps) {
    if (car < 0 || car >= 6 || carPos[car] >= trackLen) return 0;
    var moved = 0;
    for (var i = 0; i < steps; i++) {
      final nextPos = carPos[car] + 1;
      if (nextPos >= trackLen) {
        carPos[car] = trackLen;
        carLane[car] = 0;
        if (!finishOrder.contains(car)) {
          finishOrder.add(car);
        }
        moved++;
        break;
      }
      final carsAtNext = [
        for (var c = 0; c < 6; c++)
          if (c != car && carPos[c] == nextPos) c,
      ];
      final maxLanes = chicanes.contains(nextPos) ? 1 : 2;
      if (carsAtNext.length >= maxLanes) {
        // Blocked by Chicane chokepoint or full lanes!
        break;
      }
      carPos[car] = nextPos;
      final usedLanes = {for (final c in carsAtNext) carLane[c]};
      carLane[car] = usedLanes.contains(0) ? 1 : 0;
      moved++;
    }
    return moved;
  }

  bool _checkRaceEnd() {
    if (finishOrder.length >= 5 || carPos.every((p) => p >= trackLen)) {
      for (final c in currentStandings) {
        if (!finishOrder.contains(c)) {
          finishOrder.add(c);
        }
      }
      // Auto-fill any unplaced bets with leading car if race finished early
      for (var l = betStage; l < 3; l++) {
        for (var s = 0; s < players; s++) {
          bets[s][l] ??= finishOrder.first;
        }
      }
      betStage = 3;
      _over = true;
      phase = 'over';
      final sc = scores;
      final best = sc.reduce(max);
      final winners = [
        for (var s = 0; s < players; s++)
          if (sc[s] == best) name(s),
      ];
      lastEvent =
          '🏆 极速方程式冲线结算！冠军赛车：${kDownforceCars[finishOrder.first]}！总奖金赢家：${winners.join("、")}（\$${best}M）！';
      host.log(lastEvent);
      return true;
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'auction') {
      final targetQuota = (6 / players).ceil();
      if (ownedCars[seat].isEmpty) {
        return {'type': 'bid', 'amount': 3 + (seat % 2)};
      }
      if (ownedCars[seat].length >= targetQuota) {
        return {'type': 'bid', 'amount': 1};
      }
      return {'type': 'bid', 'amount': 2};
    }

    if (phase == 'race') {
      final myCars = ownedCars[seat].toSet();
      var bestIdx = 0;
      var bestVal = -999;
      for (var i = 0; i < hands[seat].length; i++) {
        final card = hands[seat][i];
        var val = 0;
        card.forEach((car, spd) {
          if (myCars.contains(car)) {
            val += spd * 3;
          } else {
            val += spd;
          }
        });
        if (val > bestVal) {
          bestVal = val;
          bestIdx = i;
        }
      }
      return {'type': 'play', 'cardIdx': bestIdx};
    }

    if (phase == 'bet') {
      final standings = currentStandings;
      // Bet on the leading car or our highest positioned owned car
      final leadCar = standings.first;
      return {'type': 'bet', 'car': leadCar};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'trackLen': trackLen,
        'chicanes': List<int>.of(chicanes),
        'betLines': List<int>.of(betLines),
        'phase': phase,
        'turn': turn,
        'auctionCar': auctionCar,
        'carOwner': List<int?>.of(carOwner),
        'ownedCars': [for (var s = 0; s < players; s++) List<int>.of(ownedCars[s])],
        'auctionCost': List<int>.of(auctionCost),
        'carPos': List<int>.of(carPos),
        'carLane': List<int>.of(carLane),
        'finishOrder': List<int>.of(finishOrder),
        'standings': currentStandings,
        'hand': seat >= 0 && seat < players
            ? [
                for (final card in hands[seat])
                  {for (final e in card.entries) '${e.key}': e.value},
              ]
            : const <Map<String, int>>[],
        'betStage': betStage,
        'bets': [
          for (var s = 0; s < players; s++)
            [
              for (var l = 0; l < 3; l++)
                (_over || s == seat) ? bets[s][l] : (bets[s][l] != null ? -1 : null),
            ],
        ],
        'scores': scores,
        'waitingFor': waitingFor,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
