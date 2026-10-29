import '../../src/engine.dart';

/// Money denominations in High Society (representing 1,000 .. 25,000 Francs, sum = 106).
const List<int> kHighSocietyMoney = [1, 2, 3, 4, 6, 8, 10, 12, 15, 20, 25];

class StatusCard {
  final String id;
  final String name;
  final String kind; // 'luxury' | 'mult' | 'disgrace'
  final int value; // 1..10 for luxury, 2 for mult, -5 for passe, 0 otherwise
  final bool darkGreen;
  final String desc;

  const StatusCard({
    required this.id,
    required this.name,
    required this.kind,
    required this.value,
    required this.darkGreen,
    required this.desc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'kind': kind,
        'value': value,
        'darkGreen': darkGreen,
        'desc': desc,
      };
}

const List<StatusCard> kHighSocietyDeck = [
  // 10 Luxury cards (1..10)
  StatusCard(id: 'lux_1', name: '香槟美酒', kind: 'luxury', value: 1, darkGreen: false, desc: '+1 声望'),
  StatusCard(id: 'lux_2', name: '法式高级香水', kind: 'luxury', value: 2, darkGreen: false, desc: '+2 声望'),
  StatusCard(id: 'lux_3', name: '米其林晚宴', kind: 'luxury', value: 3, darkGreen: false, desc: '+3 声望'),
  StatusCard(id: 'lux_4', name: '蒙特卡洛豪赌', kind: 'luxury', value: 4, darkGreen: false, desc: '+4 声望'),
  StatusCard(id: 'lux_5', name: '高定时装礼服', kind: 'luxury', value: 5, darkGreen: false, desc: '+5 声望'),
  StatusCard(id: 'lux_6', name: '里维埃拉度假', kind: 'luxury', value: 6, darkGreen: false, desc: '+6 声望'),
  StatusCard(id: 'lux_7', name: '印象派名画', kind: 'luxury', value: 7, darkGreen: false, desc: '+7 声望'),
  StatusCard(id: 'lux_8', name: '典藏老爷车', kind: 'luxury', value: 8, darkGreen: false, desc: '+8 声望'),
  StatusCard(id: 'lux_9', name: '皇家纯血赛马', kind: 'luxury', value: 9, darkGreen: false, desc: '+9 声望'),
  StatusCard(id: 'lux_10', name: '远洋豪华游艇', kind: 'luxury', value: 10, darkGreen: false, desc: '+10 声望'),
  // 3 Dark-Green Prestige Multipliers (x2)
  StatusCard(id: 'mult_1', name: '上流头衔 ×2', kind: 'mult', value: 2, darkGreen: true, desc: '总声望 ×2（深绿终局牌）'),
  StatusCard(id: 'mult_2', name: '皇室勋章 ×2', kind: 'mult', value: 2, darkGreen: true, desc: '总声望 ×2（深绿终局牌）'),
  StatusCard(id: 'mult_3', name: '社交巨擘 ×2', kind: 'mult', value: 2, darkGreen: true, desc: '总声望 ×2（深绿终局牌）'),
  // 3 Disgrace cards
  StatusCard(id: 'faux_pas', name: '社交失礼 Faux Pas', kind: 'disgrace', value: 0, darkGreen: false, desc: '厄运：弃掉 1 张奢华品卡'),
  StatusCard(id: 'passe', name: '坐吃山空 Passé', kind: 'disgrace', value: -5, darkGreen: false, desc: '厄运：声望 -5'),
  StatusCard(id: 'scandale', name: '惊天丑闻 Scandale', kind: 'disgrace', value: 0, darkGreen: true, desc: '厄运：总声望 ÷2（深绿终局牌）'),
];

class HighSocietyGame extends GameEngine {
  HighSocietyGame(super.setup);

  late List<List<int>> hands;
  late List<List<int>> bids;
  late List<List<StatusCard>> won;
  late List<StatusCard> deck;
  late List<bool> inAuction;
  late List<bool> pendingFauxPas;

  StatusCard? currentCard;
  int darkGreenCount = 0;
  int turn = 0;
  int auctionStarter = 0;
  String phase = 'auction'; // 'auction' | 'faux_pas' | 'end'
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  int bidSum(int seat) => bids[seat].fold(0, (a, b) => a + b);
  int handSum(int seat) => hands[seat].fold(0, (a, b) => a + b);

  int get highestBid {
    var m = 0;
    for (var s = 0; s < players; s++) {
      final b = bidSum(s);
      if (b > m) m = b;
    }
    return m;
  }

  /// Calculates current prestige for [seat].
  int prestigeOf(int seat) {
    var base = 0;
    var mults = 0;
    var hasPasse = false;
    var hasScandale = false;
    for (final c in won[seat]) {
      if (c.kind == 'luxury') {
        base += c.value;
      } else if (c.kind == 'mult') {
        mults++;
      } else if (c.id == 'passe') {
        hasPasse = true;
      } else if (c.id == 'scandale') {
        hasScandale = true;
      }
    }
    if (hasPasse) base -= 5;
    if (base < 0) base = 0;
    var total = base;
    for (var i = 0; i < mults; i++) {
      total *= 2;
    }
    if (hasScandale) {
      total = total ~/ 2;
    }
    return total;
  }

  /// Lowest remaining money sum across all players.
  int get lowestMoney {
    var m = handSum(0);
    for (var s = 1; s < players; s++) {
      final h = handSum(s);
      if (h < m) m = h;
    }
    return m;
  }

  /// Whether [seat] is eliminated for having the lowest remaining money at game end.
  bool isPoorest(int seat) => handSum(seat) == lowestMoney;

  @override
  void start() {
    hands = [for (var s = 0; s < players; s++) List<int>.of(kHighSocietyMoney)];
    bids = [for (var s = 0; s < players; s++) <int>[]];
    won = [for (var s = 0; s < players; s++) <StatusCard>[]];
    inAuction = List<bool>.filled(players, true);
    pendingFauxPas = List<bool>.filled(players, false);
    deck = shuffled(kHighSocietyDeck, rng);
    // Ensure the very first card doesn't immediately end the game on 4th dark green
    if (deck.take(4).every((c) => c.darkGreen)) {
      final nonGreenIdx = deck.lastIndexWhere((c) => !c.darkGreen);
      if (nonGreenIdx > 0) {
        final tmp = deck[0];
        deck[0] = deck[nonGreenIdx];
        deck[nonGreenIdx] = tmp;
      }
    }
    darkGreenCount = 0;
    turn = 0;
    auctionStarter = 0;
    _over = false;
    flipNextCard();
  }

  void flipNextCard() {
    if (deck.isEmpty) {
      _endGame('状态牌堆已摸空，游戏结束！');
      return;
    }
    final card = deck.removeAt(0);
    currentCard = card;
    if (card.darkGreen) {
      darkGreenCount++;
      if (darkGreenCount >= 4) {
        lastEvent = '翻出第 4 张深绿牌【${card.name}】，游戏立即结束！';
        host.log(lastEvent);
        _endGame(lastEvent);
        return;
      }
    }
    for (var s = 0; s < players; s++) {
      bids[s].clear();
      inAuction[s] = true;
    }
    phase = 'auction';
    turn = auctionStarter;
    final mode = card.kind == 'disgrace' ? '反向拍卖（最先跳过者拿走厄运卡，其余人失去已出支票）' : '正向拍卖（出价最高者得牌，跳过者收回支票）';
    lastEvent = '翻开【${card.name}】($mode)';
    host.log(lastEvent);
  }

  void _endGame(String reason) {
    _over = true;
    phase = 'end';
    // Return any leftover bids on table if ended abruptly
    for (var s = 0; s < players; s++) {
      if (bids[s].isNotEmpty) {
        hands[s].addAll(bids[s]);
        hands[s].sort();
        bids[s].clear();
      }
    }
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'faux_pas' || phase == 'auction') return [turn];
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');
    final type = asStr(action['type']);

    if (phase == 'faux_pas') {
      if (type != 'discard_luxury') throw GameError('请选择要弃掉的奢华品卡');
      final cardId = asStr(action['card']);
      final luxuries = won[seat].where((c) => c.kind == 'luxury').toList();
      StatusCard? target;
      for (final c in luxuries) {
        if (c.id == cardId) {
          target = c;
          break;
        }
      }
      if (target == null) {
        final idx = asInt(action['index'], -1);
        if (idx >= 0 && idx < luxuries.length) {
          target = luxuries[idx];
        }
      }
      if (target == null) throw GameError('无效的奢华品卡选择');
      won[seat].remove(target);
      lastEvent = '${name(seat)} 因【社交失礼】弃掉了【${target.name}】';
      host.log(lastEvent);
      flipNextCard();
      return;
    }

    if (phase != 'auction' || currentCard == null) {
      throw GameError('当前不在拍卖阶段');
    }

    if (type == 'bid') {
      final rawCards = asIntList(action['cards']);
      if (rawCards.isEmpty) throw GameError('请至少选择 1 张支票加注');
      final tempHand = List<int>.of(hands[seat]);
      var addSum = 0;
      for (final c in rawCards) {
        if (!tempHand.remove(c)) {
          throw GameError('你手中没有面值 $c 的支票');
        }
        addSum += c;
      }
      final newTotal = bidSum(seat) + addSum;
      final curHigh = highestBid;
      if (newTotal <= curHigh) {
        throw GameError('加注后的总出价 ($newTotal) 必须严格高于当前最高出价 ($curHigh)');
      }
      for (final c in rawCards) {
        hands[seat].remove(c);
        bids[seat].add(c);
      }
      hands[seat].sort();
      bids[seat].sort();
      lastEvent = '${name(seat)} 加注至 ${newTotal}k 法郎';
      host.log(lastEvent);
      _advanceTurn();
      return;
    }

    if (type == 'pass') {
      final card = currentCard!;
      if (card.kind != 'disgrace') {
        // Normal Auction: passing player takes back their bid cards
        inAuction[seat] = false;
        hands[seat].addAll(bids[seat]);
        hands[seat].sort();
        bids[seat].clear();

        final remaining = [for (var s = 0; s < players; s++) if (inAuction[s]) s];
        if (remaining.length == 1) {
          final winner = remaining.first;
          final spent = bidSum(winner);
          bids[winner].clear(); // Winner spends/discards all bid cards
          auctionStarter = winner;
          if (card.kind == 'luxury' && pendingFauxPas[winner]) {
            pendingFauxPas[winner] = false;
            lastEvent = '${name(winner)} 以 ${spent}k 拍下【${card.name}】，但因【社交失礼】立即将其弃掉！';
            host.log(lastEvent);
          } else {
            won[winner].add(card);
            lastEvent = '${name(winner)} 花费 ${spent}k 法郎拍下【${card.name}】！';
            host.log(lastEvent);
          }
          flipNextCard();
        } else {
          lastEvent = '${name(seat)} 放弃竞拍并收回支票';
          host.log(lastEvent);
          _advanceTurn();
        }
      } else {
        // Reverse Auction: FIRST player to pass takes the Disgrace card and keeps their money;
        // EVERY OTHER PLAYER loses all money they already bid on the table!
        hands[seat].addAll(bids[seat]);
        hands[seat].sort();
        bids[seat].clear();
        for (var s = 0; s < players; s++) {
          if (s != seat) {
            bids[s].clear();
          }
        }
        won[seat].add(card);
        auctionStarter = seat;
        lastEvent = '${name(seat)} 选择跳过并收下厄运卡【${card.name}】，其余玩家失去桌面出价！';
        host.log(lastEvent);

        if (card.id == 'faux_pas') {
          final luxuries = won[seat].where((c) => c.kind == 'luxury').toList();
          if (luxuries.isEmpty) {
            pendingFauxPas[seat] = true;
            flipNextCard();
          } else if (luxuries.length == 1) {
            final removed = luxuries.first;
            won[seat].remove(removed);
            lastEvent = '${name(seat)} 因【社交失礼】弃掉了【${removed.name}】';
            host.log(lastEvent);
            flipNextCard();
          } else {
            phase = 'faux_pas';
            turn = seat;
          }
        } else {
          flipNextCard();
        }
      }
      return;
    }

    throw GameError('未知操作：$type');
  }

  void _advanceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (inAuction[next]) {
        turn = next;
        return;
      }
    }
  }

  /// Composite score for ranking at game end: non-poorest players always rank above poorest players.
  List<int> _rankingScores() {
    final allPoorest = [for (var s = 0; s < players; s++) isPoorest(s)].every((x) => x);
    return [
      for (var s = 0; s < players; s++)
        ((!allPoorest && isPoorest(s)) ? -1000000 : 0) + prestigeOf(s) * 1000 + handSum(s),
    ];
  }

  @override
  List<int>? get placings => _over ? rankByScore(_rankingScores()) : null;

  @override
  Map<String, dynamic> view(int seat) {
    final minM = lowestMoney;
    return {
      'phase': phase,
      'turn': turn,
      'auctionStarter': auctionStarter,
      'darkGreenCount': darkGreenCount,
      'deckCount': deck.length,
      'currentCard': currentCard?.toJson(),
      'highestBid': highestBid,
      'inAuction': inAuction,
      'bids': bids,
      'bidSums': [for (var s = 0; s < players; s++) bidSum(s)],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'myHand': seat >= 0 && seat < players ? hands[seat] : const <int>[],
      'myMoney': seat >= 0 && seat < players ? handSum(seat) : 0,
      'won': [
        for (var s = 0; s < players; s++) [for (final c in won[s]) c.toJson()],
      ],
      'pendingFauxPas': pendingFauxPas,
      'prestige': [for (var s = 0; s < players; s++) prestigeOf(s)],
      'lastEvent': lastEvent,
      if (_over) ...{
        'moneyLeft': [for (var s = 0; s < players; s++) handSum(s)],
        'lowestMoney': minM,
        'poorest': [for (var s = 0; s < players; s++) isPoorest(s)],
        'placings': placings,
      },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'faux_pas') {
      final luxuries = won[seat].where((c) => c.kind == 'luxury').toList();
      luxuries.sort((a, b) => a.value.compareTo(b.value));
      return {'type': 'discard_luxury', 'card': luxuries.first.id};
    }

    final card = currentCard;
    if (card == null) return null;
    final hand = hands[seat];
    final curHigh = highestBid;
    final myBid = bidSum(seat);
    final needed = curHigh + 1 - myBid;

    if (hand.isEmpty) {
      return {'type': 'pass'};
    }

    // Find single card that can beat curHigh with minimum waste
    int? bestSingle;
    for (final c in hand) {
      if (c >= needed) {
        bestSingle = c;
        break;
      }
    }

    final myRemainingTotal = handSum(seat) + myBid;
    // Valuation heuristic based on card type and botLevel
    var maxWillingTotal = 0;
    if (card.kind == 'luxury') {
      maxWillingTotal = card.value * 2 + (botLevel == 0 ? 4 : 2);
    } else if (card.kind == 'mult') {
      maxWillingTotal = 18;
    } else {
      // Disgrace card: willing to bid a small amount to avoid taking it
      maxWillingTotal = card.id == 'scandale' ? 14 : 8;
    }

    // Never spend so much that we drop dangerously low on total money unless botLevel == 0
    if (botLevel > 0 && myRemainingTotal - (curHigh + 1) < 22) {
      return {'type': 'pass'};
    }

    if (bestSingle != null && myBid + bestSingle <= maxWillingTotal) {
      if (botLevel == 0 && rng.nextDouble() < 0.25) {
        return {'type': 'pass'};
      }
      return {
        'type': 'bid',
        'cards': [bestSingle],
      };
    }

    return {'type': 'pass'};
  }
}
