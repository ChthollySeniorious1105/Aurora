import '../../src/engine.dart';

class StockCorpInfo {
  final int id;
  final String name;
  final String emoji;
  const StockCorpInfo(this.id, this.name, this.emoji);
}

const List<StockCorpInfo> kStockCorps = [
  StockCorpInfo(0, '苹果科技', '🍎'),
  StockCorpInfo(1, '闪电能源', '⚡'),
  StockCorpInfo(2, '极速汽车', '🚗'),
  StockCorpInfo(3, '基因医药', '🧬'),
  StockCorpInfo(4, '皇家金融', '🏦'),
  StockCorpInfo(5, '重工钢铁', '⛏️'),
];

/// Market card encoding:
/// 0..5 = 1 Share of Corp 0..5
/// 6 = 📈 行业利好 Boom (+2 price to best corp)
/// 7 = 📉 市场暴跌 Bust (-2 price to target corp)
String marketCardLabel(int card) {
  if (card >= 0 && card < 6) {
    return '${kStockCorps[card].emoji}${kStockCorps[card].name}股票';
  }
  if (card == 6) return '📈行业利好(+2)';
  return '📉市场暴跌(-2)';
}

class StockpileGame extends GameEngine {
  StockpileGame(super.setup);

  late int maxRounds;
  int round = 1;
  String phase = 'supply'; // 'supply' | 'bid' | 'sell' | 'over'

  /// Share prices of the 6 corporations (1..10, starts at 5).
  late List<int> prices;

  /// Regular unsplit shares: shares[seat][corp].
  late List<List<int>> shares;

  /// Split-protected shares: splitShares[seat][corp].
  late List<List<int>> splitShares;

  /// Player cash ($K).
  late List<int> cash;

  /// Total net worth scores.
  late List<int> scores;

  /// Forecast shift for each corporation 0..5 this round (+4, +2, +2, -1, -2, -3).
  late List<int> forecasts;
  int dividendCorp = -1;

  /// Secret insider corporation & shift per player seat.
  late List<int> insiderCorp;
  late List<int> insiderShift;

  /// Publicly revealed corporation & shift on the Market Board.
  int publicCorp = 0;
  int publicShift = 2;

  /// 2 Market Cards dealt to each player in 'supply' phase.
  late List<List<int>> supplyHands;
  late List<bool> supplied;

  /// N Stockpiles: each has 'up' (List<int>) and 'down' (List<int>).
  late List<Map<String, List<int>>> piles;

  /// Bidding state on the N stockpiles.
  late List<int> pileBidder;
  late List<int> pileBid;
  int turn = 0;
  int outbidCount = 0;

  /// Selling state in 'sell' phase.
  late List<bool> soldThisRound;

  String lastEvent = '新财年开始：查看你的专属内幕情报，向股票堆塞入 1 明 1 暗两张市场牌！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    return rankByScore(scores);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'supply') {
      return [
        for (var s = 0; s < players; s++)
          if (!supplied[s]) s,
      ];
    }
    if (phase == 'bid') {
      return [turn];
    }
    if (phase == 'sell') {
      return [
        for (var s = 0; s < players; s++)
          if (!soldThisRound[s]) s,
      ];
    }
    return const [];
  }

  @override
  void start() {
    final roundsOpt = setup.opt<int>('rounds', 6);
    maxRounds = roundsOpt == 4 ? 4 : 6;
    round = 1;

    prices = List<int>.filled(6, 5);
    shares = List.generate(players, (_) => List<int>.filled(6, 1));
    splitShares = List.generate(players, (_) => List<int>.filled(6, 0));
    cash = List<int>.filled(players, 20);
    scores = List<int>.filled(players, 50);

    _startRound();
    host.log('【股市大亨】开盘！6 大巨头初始股价 \$5，每位投资者持有 \$20 现金与各企业 1 股底仓。');
  }

  void _startRound() {
    phase = 'supply';
    supplied = List<bool>.filled(players, false);
    soldThisRound = List<bool>.filled(players, false);
    pileBidder = List<int>.filled(players, -1);
    pileBid = List<int>.filled(players, 0);
    turn = (round - 1) % players;
    outbidCount = 0;

    // Pair the 6 corporations with the 6 Forecast shifts: [+4, +2, +2(Div), -1, -2, -3]
    final corpsOrder = <int>[0, 1, 2, 3, 4, 5]..shuffle(rng);
    const shiftPool = <int>[4, 2, 2, -1, -2, -3];
    forecasts = List<int>.filled(6, 0);
    for (var i = 0; i < 6; i++) {
      forecasts[corpsOrder[i]] = shiftPool[i];
    }
    dividendCorp = corpsOrder[2]; // the second +2 is +2(Dividend)

    publicCorp = corpsOrder[0];
    publicShift = shiftPool[0];

    insiderCorp = List<int>.filled(players, 0);
    insiderShift = List<int>.filled(players, 0);
    for (var s = 0; s < players; s++) {
      final c = corpsOrder[(s + 1) % 6];
      insiderCorp[s] = c;
      insiderShift[s] = forecasts[c];
    }

    // Initialize N stockpiles with 1 face-up card each
    piles = List.generate(
      players,
      (p) => <String, List<int>>{
        'up': <int>[(p + round + rng.nextInt(6)) % 6],
        'down': <int>[],
      },
    );

    // Deal 2 Market Cards to each player
    supplyHands = List.generate(players, (_) {
      final c1 = rng.nextInt(6);
      final roll = rng.nextInt(8);
      final c2 = roll < 6 ? roll : (roll == 6 ? 6 : 7);
      return <int>[c1, c2];
    });

    _recalcScores();
  }

  void applyPriceShift(int corp, int delta, List<String> notes) {
    if (corp < 0 || corp >= 6) return;
    prices[corp] += delta;
    final info = kStockCorps[corp];
    if (prices[corp] > 10) {
      // Stock Split! Double regular shares into splitShares[seat][corp]
      prices[corp] = 6;
      for (var s = 0; s < players; s++) {
        if (shares[s][corp] > 0) {
          splitShares[s][corp] += shares[s][corp] * 2;
          shares[s][corp] = 0;
        }
      }
      notes.add('🚀${info.emoji}${info.name}突破10元触发【拆股】！全员持股翻倍转入拆股仓，股价重置为\$6');
    } else if (prices[corp] < 1) {
      // Bankruptcy! Wipe out unsplit shares[seat][corp] and reset price to 5
      prices[corp] = 5;
      for (var s = 0; s < players; s++) {
        shares[s][corp] = 0;
      }
      notes.add('💥${info.emoji}${info.name}跌破1元触发【破产清算】！普通股清零，股价重置为\$5');
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    final type = asStr(action['type']);

    if (phase == 'supply') {
      if (type != 'supply') throw GameError('当前为塞牌阶段（supply）');
      if (supplied[seat]) throw GameError('你本轮已塞过牌');
      final upPile = asInt(action['upPile']);
      final downPile = asInt(action['downPile']);
      if (upPile < 0 || upPile >= players || downPile < 0 || downPile >= players) {
        throw GameError('股票堆编号无效');
      }
      final hand = supplyHands[seat];
      final upCard = hand.isNotEmpty ? hand[0] : 0;
      final downCard = hand.length > 1 ? hand[1] : 1;
      piles[upPile]['up']!.add(upCard);
      piles[downPile]['down']!.add(downCard);
      supplied[seat] = true;

      if (supplied.every((x) => x)) {
        phase = 'bid';
        turn = (round - 1) % players;
        lastEvent = '全员塞牌完毕！进入【竞拍股票堆】阶段，由 ${name(turn)} 率先出价。';
        host.log(lastEvent);
      }
      return;
    }

    if (phase == 'bid') {
      if (seat != turn) throw GameError('当前还未轮到你竞拍');
      if (type != 'bid') throw GameError('请对股票堆出价（bid）');
      final p = asInt(action['pile']);
      final amount = asInt(action['amount']);
      if (p < 0 || p >= players) throw GameError('无效的股票堆编号');
      if (amount < 0 || amount > 25) throw GameError('出价必须在 \$0 ~ \$25 之间');

      if (pileBidder[p] == -1) {
        pileBidder[p] = seat;
        pileBid[p] = amount;
        lastEvent = '${name(seat)} 对 #${p + 1} 号股票堆出价 \$$amount。';
      } else {
        if (pileBidder[p] == seat) throw GameError('你已是该股票堆的最高出价者');
        if (amount <= pileBid[p] || outbidCount >= players) {
          throw GameError('超价竞标必须高于当前出价 \$${pileBid[p]}（或改投空余股票堆）');
        }
        final prev = pileBidder[p];
        pileBidder[p] = seat;
        pileBid[p] = amount;
        outbidCount += 1;
        lastEvent = '${name(seat)} 出价 \$$amount 抢下 #${p + 1} 号股票堆！${name(prev)} 被挤出并需重新竞标！';
      }
      host.log(lastEvent);

      _advanceBidOrResolve();
      return;
    }

    if (phase == 'sell') {
      if (type != 'sell') throw GameError('当前为内幕抛售阶段（sell）');
      if (soldThisRound[seat]) throw GameError('你本轮已完成抛售操作');
      final counts = asIntList(action['counts']);
      var gained = 0;
      var totalSold = 0;
      for (var c = 0; c < 6 && c < counts.length; c++) {
        final req = counts[c];
        if (req <= 0) continue;
        final sellCnt = req.clamp(0, shares[seat][c]);
        if (sellCnt > 0) {
          shares[seat][c] -= sellCnt;
          final rev = sellCnt * prices[c];
          cash[seat] += rev;
          gained += rev;
          totalSold += sellCnt;
        }
      }
      soldThisRound[seat] = true;
      if (totalSold > 0) {
        host.log('${name(seat)} 在大盘结算前抛售 $totalSold 股，套现 \$$gained！');
      }

      if (soldThisRound.every((x) => x)) {
        _resolveMarketForecasts();
      } else {
        _recalcScores();
      }
      return;
    }

    throw GameError('未知阶段或操作');
  }

  void _advanceBidOrResolve() {
    // Find next player who does not currently hold any pile
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!pileBidder.contains(next)) {
        turn = next;
        return;
      }
    }

    // All players hold a stockpile! Resolve stockpiles
    final notes = <String>[];
    for (var p = 0; p < players; p++) {
      final winner = pileBidder[p];
      if (winner < 0) continue;
      final cost = pileBid[p];
      cash[winner] = (cash[winner] - cost).clamp(0, 9999);
      final allCards = <int>[...piles[p]['up']!, ...piles[p]['down']!];
      for (final card in allCards) {
        if (card >= 0 && card < 6) {
          shares[winner][card] += 1;
        } else if (card == 6) {
          // Boom +2 to the corp winner holds the most of
          var bestCorp = 0;
          var bestHold = -1;
          for (var c = 0; c < 6; c++) {
            final h = shares[winner][c] + splitShares[winner][c];
            if (h > bestHold) {
              bestHold = h;
              bestCorp = c;
            }
          }
          applyPriceShift(bestCorp, 2, notes);
        } else if (card == 7) {
          // Bust -2 to the corp winner holds the least of
          var worstCorp = 5;
          var minHold = 999;
          for (var c = 0; c < 6; c++) {
            final h = shares[winner][c] + splitShares[winner][c];
            if (h < minHold) {
              minHold = h;
              worstCorp = c;
            }
          }
          applyPriceShift(worstCorp, -2, notes);
        }
      }
    }

    phase = 'sell';
    _recalcScores();
    lastEvent = '股票堆交割完成！${notes.isEmpty ? "" : "${notes.join("；")}。"}请在大盘结算前决定是否抛售股票！';
    host.log(lastEvent);
  }

  void _resolveMarketForecasts() {
    // Sync forecasts with insiderCorp/insiderShift in case unit test set them directly
    for (var s = 0; s < players; s++) {
      final c = insiderCorp[s];
      if (c >= 0 && c < 6) {
        forecasts[c] = insiderShift[s];
      }
    }
    if (publicCorp >= 0 && publicCorp < 6) {
      forecasts[publicCorp] = publicShift;
    }

    final notes = <String>[];
    for (var c = 0; c < 6; c++) {
      if (c == dividendCorp && forecasts[c] > 0) {
        for (var s = 0; s < players; s++) {
          final totalSh = shares[s][c] + splitShares[s][c];
          if (totalSh > 0) {
            cash[s] += totalSh * 2;
          }
        }
        notes.add('💰${kStockCorps[c].name}派发每股\$2分红');
      }
      applyPriceShift(c, forecasts[c], notes);
    }

    if (round >= maxRounds) {
      phase = 'over';
      _awardMajorityBonuses(notes);
      _recalcScores();
      lastEvent = '【股市大亨】终盘结算完成！${notes.join("；")}';
      host.log(lastEvent);
      return;
    }

    round += 1;
    final summary = notes.isEmpty ? '大盘平稳波动' : notes.join('；');
    _startRound();
    lastEvent = '📊上轮大盘结算：$summary。第 $round / $maxRounds 轮开始！';
    host.log(lastEvent);
  }

  void _awardMajorityBonuses(List<String> notes) {
    for (var c = 0; c < 6; c++) {
      var maxHold = 0;
      for (var s = 0; s < players; s++) {
        final h = shares[s][c] + splitShares[s][c];
        if (h > maxHold) maxHold = h;
      }
      if (maxHold > 0) {
        for (var s = 0; s < players; s++) {
          if (shares[s][c] + splitShares[s][c] == maxHold) {
            cash[s] += 10;
          }
        }
      }
    }
    notes.add('🏆六大企业最大股东获颁 +\$10 控股大奖');
  }

  void _recalcScores() {
    for (var s = 0; s < players; s++) {
      var portfolio = cash[s];
      for (var c = 0; c < 6; c++) {
        portfolio += (shares[s][c] + splitShares[s][c]) * prices[c];
      }
      scores[s] = portfolio;
    }
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    host.log('${name(seat)} 认输，游戏结束。');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || !waitingFor.contains(seat)) return null;

    if (phase == 'supply') {
      final p1 = rng.nextInt(players);
      final p2 = (p1 + 1) % players;
      return {'type': 'supply', 'upPile': p1, 'downPile': p2};
    }

    if (phase == 'bid') {
      // Find unclaimed piles first
      final emptyPiles = <int>[
        for (var p = 0; p < players; p++)
          if (pileBidder[p] == -1) p,
      ];
      final targetPile = emptyPiles.isNotEmpty
          ? emptyPiles[rng.nextInt(emptyPiles.length)]
          : 0;
      final amt = emptyPiles.isNotEmpty ? rng.nextInt(5) : (pileBid[targetPile] + 1).clamp(0, 25);
      return {'type': 'bid', 'pile': targetPile, 'amount': amt};
    }

    if (phase == 'sell') {
      // Only use public info + this seat's own insider info!
      final myCorp = insiderCorp[seat];
      final myShift = insiderShift[seat];
      final counts = List<int>.filled(6, 0);
      for (var c = 0; c < 6; c++) {
        // Sell if known negative forecast and danger of bankruptcy, or high price
        final knownShift = (c == myCorp)
            ? myShift
            : (c == publicCorp ? publicShift : 0);
        if ((knownShift < 0 && prices[c] + knownShift < 1) ||
            (prices[c] >= 8 && knownShift <= 0)) {
          counts[c] = shares[seat][c];
        }
      }
      return {'type': 'sell', 'counts': counts};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'phase': phase,
      'turn': turn,
      'prices': List<int>.of(prices),
      'shares': [for (var s = 0; s < players; s++) List<int>.of(shares[s])],
      'splitShares': [for (var s = 0; s < players; s++) List<int>.of(splitShares[s])],
      'cash': List<int>.of(cash),
      'scores': List<int>.of(scores),
      'publicCorp': publicCorp,
      'publicShift': publicShift,
      'dividendCorp': isOver ? dividendCorp : -1,
      'myInsiderCorp': seat >= 0 && seat < players ? insiderCorp[seat] : null,
      'myInsiderShift': seat >= 0 && seat < players ? insiderShift[seat] : null,
      'mySupplyHand': seat >= 0 && seat < players ? List<int>.of(supplyHands[seat]) : const <int>[],
      'supplied': List<bool>.of(supplied),
      'piles': [
        for (var p = 0; p < players; p++)
          {
            'up': List<int>.of(piles[p]['up']!),
            'downCount': piles[p]['down']!.length,
            'down': isOver || phase == 'sell' ? List<int>.of(piles[p]['down']!) : const <int>[],
          },
      ],
      'pileBidder': List<int>.of(pileBidder),
      'pileBid': List<int>.of(pileBid),
      'soldThisRound': List<bool>.of(soldThisRound),
      'lastEvent': lastEvent,
      'canAct': seat >= 0 && waitingFor.contains(seat),
    };
  }
}
