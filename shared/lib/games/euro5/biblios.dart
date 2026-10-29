import 'dart:math';

import '../../src/engine.dart';

/// 修道院藏书阁 (Biblios) — 2-4人中世纪手抄本赠予分配与暗标/明标拍卖桌游
class BibliosGame extends GameEngine {
  BibliosGame(super.setup);

  static const List<String> categoryNames = ['修士', '颜料', '经卷', '草药', '秘典'];
  static const List<String> tieLetters = ['A', 'B', 'C', 'D', 'E', 'F'];

  late String mode;
  final List<int> dice = [3, 3, 3, 3, 3]; // 5 categories, 1..6 points each

  final List<Map<String, dynamic>> deck = [];
  final List<Map<String, dynamic>> auctionPile = [];
  final List<Map<String, dynamic>> publicPool = [];
  late List<List<Map<String, dynamic>>> hands;

  int turn = 0; // Active gift turn owner or auction starter
  String phase = 'gift'; // 'gift' | 'auction' | 'end'
  String subPhase = 'allocate'; // 'allocate' | 'draft' | 'bidding'

  // Gift phase state
  Map<String, dynamic>? currentCard;
  int keepLeft = 1;
  int auctionLeft = 1;
  int publicLeft = 1;
  int draftSeat = 0;

  // Church card adjustment state (can interrupt allocate, draft, or auction win)
  int churchSeat = -1;
  int churchRemaining = 0;
  String resumeStep = ''; // 'after_allocate' | 'after_draft' | 'after_auction'

  // Auction phase state
  Map<String, dynamic>? auctionCard;
  int bidSeat = 0;
  int currentBid = 0;
  int highBidder = -1;
  final Set<int> passedSeats = {};

  bool _over = false;
  String lastEvent = '';
  late List<int> finalPoints;
  late List<int> finalGold;
  List<Map<String, dynamic>> categoryResults = [];

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (churchRemaining > 0 && churchSeat >= 0) return [churchSeat];
    if (phase == 'gift') {
      if (subPhase == 'allocate') return [turn];
      if (subPhase == 'draft') return [draftSeat];
    }
    if (phase == 'auction') {
      return [bidSeat];
    }
    return const [];
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    final keys = [
      for (var s = 0; s < players; s++) finalPoints[s] * 1000 + finalGold[s],
    ];
    return rankByScore(keys);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) return;
    _computeEndgameScoring();
    finalPoints[seat] = -99;
    _over = true;
    phase = 'end';
    lastEvent = '${name(seat)} 认输';
    host.log(lastEvent);
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    for (var i = 0; i < 5; i++) {
      dice[i] = 3;
    }
    hands = [for (var i = 0; i < players; i++) <Map<String, dynamic>>[]];
    finalPoints = List<int>.filled(players, 0);
    finalGold = List<int>.filled(players, 0);
    categoryResults = [];

    _buildDeck();
    turn = 0;
    phase = 'gift';
    _startGiftTurn();
    host.log('修道院藏书阁开局！第一阶段：赠予分配，第二阶段：藏书拍卖。');
  }

  void _buildDeck() {
    deck.clear();
    auctionPile.clear();
    publicPool.clear();

    var idSeq = 1;
    final allCards = <Map<String, dynamic>>[];

    // 1. 5 Categories (0..4): values 1..4 with tie-breaker letters A..F
    // Each category gets 9 cards with unique (val, tieRank)
    const catTemplates = <(int, String, int)>[
      (1, 'A', 6),
      (1, 'B', 5),
      (1, 'C', 4),
      (2, 'A', 6),
      (2, 'B', 5),
      (2, 'C', 4),
      (3, 'B', 5),
      (3, 'C', 4),
      (4, 'D', 3),
    ];
    for (var c = 0; c < 5; c++) {
      for (final (v, letter, tRank) in catTemplates) {
        allCards.add({
          'id': 'c_${idSeq++}',
          'type': 'cat',
          'cat': c,
          'catName': categoryNames[c],
          'val': v,
          'tie': letter,
          'tieRank': tRank,
          'name': '${categoryNames[c]} +$v ($letter)',
        });
      }
    }

    // 2. Gold cards (21 cards: 8x 1-gold, 8x 2-gold, 5x 3-gold)
    for (var i = 0; i < 8; i++) {
      allCards.add({'id': 'g_${idSeq++}', 'type': 'gold', 'val': 1, 'name': '金币 1'});
      allCards.add({'id': 'g_${idSeq++}', 'type': 'gold', 'val': 2, 'name': '金币 2'});
    }
    for (var i = 0; i < 5; i++) {
      allCards.add({'id': 'g_${idSeq++}', 'type': 'gold', 'val': 3, 'name': '金币 3'});
    }

    // 3. Church cards (9 cards: 6x 1-adjust, 3x 2-adjust)
    for (var i = 0; i < 6; i++) {
      allCards.add({'id': 'ch_${idSeq++}', 'type': 'church', 'adjusts': 1, 'name': '主教手谕(调骰×1)'});
    }
    for (var i = 0; i < 3; i++) {
      allCards.add({'id': 'ch_${idSeq++}', 'type': 'church', 'adjusts': 2, 'name': '教皇诏书(调骰×2)'});
    }

    allCards.shuffle(rng);

    // Give each player 1 starting 1-gold card and 1 starting 2-gold card so everyone has initial bidding liquidity
    for (var s = 0; s < players; s++) {
      hands[s].add({'id': 'init_g1_$s', 'type': 'gold', 'val': 1, 'name': '初始金币 1'});
      hands[s].add({'id': 'init_g2_$s', 'type': 'gold', 'val': 2, 'name': '初始金币 2'});
    }

    // Determine exact number of gift turns so deck size is an exact multiple of (players + 1)
    final turnsCount = mode == 'fast' ? (players * 2) : (players * 3);
    final neededForGift = turnsCount * (players + 1);
    for (var i = 0; i < neededForGift && i < allCards.length; i++) {
      deck.add(allCards[i]);
    }
    // Also place 2 extra cards straight into auctionPile
    for (var i = neededForGift; i < min(neededForGift + 2, allCards.length); i++) {
      auctionPile.add(allCards[i]);
    }
  }

  int playerGold(int seat) {
    var sum = 0;
    for (final c in hands[seat]) {
      if (c['type'] == 'gold') {
        sum += asInt(c['val'], 0);
      }
    }
    return sum;
  }

  void _startGiftTurn() {
    if (deck.length < players + 1) {
      _startAuctionPhase();
      return;
    }
    subPhase = 'allocate';
    keepLeft = 1;
    auctionLeft = 1;
    publicLeft = players - 1;
    publicPool.clear();
    currentCard = deck.removeLast();
    lastEvent = '赠予阶段：轮到 ${name(turn)} 抽牌并分配（共 ${players + 1} 张）';
  }

  void _acquireCard(int seat, Map<String, dynamic> card, String nextStep) {
    if (card['type'] == 'church') {
      churchSeat = seat;
      churchRemaining = asInt(card['adjusts'], 1);
      resumeStep = nextStep;
      lastEvent = '${name(seat)} 获得【${card['name']}】，请调整 $churchRemaining 次分类骰子点数';
      host.log(lastEvent);
      return;
    }
    hands[seat].add(card);
    _resumeAfterCard(nextStep);
  }

  void _resumeAfterCard(String step) {
    if (step == 'after_allocate') {
      _advanceAllocation();
    } else if (step == 'after_draft') {
      _advanceDraft();
    } else if (step == 'after_auction') {
      _nextAuctionCard();
    }
  }

  void _advanceAllocation() {
    final rem = keepLeft + auctionLeft + publicLeft;
    if (rem > 0) {
      currentCard = deck.removeLast();
      return;
    }
    currentCard = null;
    subPhase = 'draft';
    draftSeat = (turn + 1) % players;
    lastEvent = '${name(turn)} 完成分配，轮到 ${name(draftSeat)} 从公共池选牌';
  }

  void _advanceDraft() {
    if (publicPool.isEmpty) {
      turn = (turn + 1) % players;
      _startGiftTurn();
      return;
    }
    draftSeat = (draftSeat + 1) % players;
    if (draftSeat == turn) {
      draftSeat = (draftSeat + 1) % players;
    }
    lastEvent = '轮到 ${name(draftSeat)} 从公共池选择 1 张牌';
  }

  void _startAuctionPhase() {
    phase = 'auction';
    subPhase = 'bidding';
    currentCard = null;
    publicPool.clear();
    auctionPile.shuffle(rng);
    host.log('牌库已耗尽，进入第二阶段：修道院拍卖阶段（共 ${auctionPile.length} 张拍品）！');
    _nextAuctionCard();
  }

  void _nextAuctionCard() {
    if (auctionPile.isEmpty) {
      _finishGame();
      return;
    }
    auctionCard = auctionPile.removeLast();
    currentBid = 0;
    highBidder = -1;
    passedSeats.clear();
    bidSeat = turn;
    final isGoldCard = auctionCard!['type'] == 'gold';
    lastEvent = '拍卖品【${auctionCard!['name']}】亮相（以${isGoldCard ? '弃置手牌张数' : '手牌金币总额'}竞标），轮到 ${name(bidSeat)} 叫价';
  }

  int maxBidFor(int seat) {
    if (auctionCard == null) return 0;
    if (auctionCard!['type'] == 'gold') {
      return hands[seat].length;
    }
    return playerGold(seat);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    // 1. Church die adjustment takes priority
    if (churchRemaining > 0) {
      if (seat != churchSeat) throw GameError('正在等待 ${name(churchSeat)} 调整分类骰子');
      if (type != 'church') throw GameError('请先调整分类骰子点数');
      final cat = asInt(action['cat'], -1);
      final delta = asInt(action['delta'], 0);
      if (cat < 0 || cat >= 5) throw GameError('无效的分类选择');
      if (delta != 1 && delta != -1) throw GameError('每次只能 +1 或 -1');
      final nextVal = (dice[cat] + delta).clamp(1, 6);
      if (nextVal == dice[cat]) {
        // Check if any die can move in any direction
        final anyMovable = dice.any((d) => d > 1 || d < 6);
        if (anyMovable) throw GameError('该分类骰子已达上限或下限');
      }
      dice[cat] = nextVal;
      churchRemaining -= 1;
      lastEvent = '${name(seat)} 将【${categoryNames[cat]}】分值骰调整为 ${dice[cat]} 点';
      if (churchRemaining <= 0) {
        churchSeat = -1;
        final step = resumeStep;
        resumeStep = '';
        _resumeAfterCard(step);
      }
      return;
    }

    // 2. Phase 1: Gift
    if (phase == 'gift') {
      if (subPhase == 'allocate') {
        if (seat != turn) throw GameError('当前不是你的赠予回合');
        if (type != 'allocate') throw GameError('请选择卡牌去向');
        final dest = asStr(action['dest']);
        final card = currentCard!;
        if (dest == 'keep') {
          if (keepLeft <= 0) throw GameError('本回合留给自己的名额已用完');
          keepLeft -= 1;
          lastEvent = '${name(seat)} 将 1 张牌收入自己手中';
          _acquireCard(seat, card, 'after_allocate');
          return;
        }
        if (dest == 'auction') {
          if (auctionLeft <= 0) throw GameError('本回合放入暗拍堆的名额已用完');
          auctionLeft -= 1;
          auctionPile.add(card);
          lastEvent = '${name(seat)} 将 1 张牌暗置入拍卖堆';
          _advanceAllocation();
          return;
        }
        if (dest == 'public') {
          if (publicLeft <= 0) throw GameError('公共池名额已满');
          publicLeft -= 1;
          publicPool.add(card);
          lastEvent = '${name(seat)} 将【${card['name']}】明置入公共池';
          _advanceAllocation();
          return;
        }
        throw GameError('无效的分配去向');
      }

      if (subPhase == 'draft') {
        if (seat != draftSeat) throw GameError('还没轮到你从公共池选牌');
        if (type != 'draft') throw GameError('请从公共池选择一张牌');
        final idx = asInt(action['index'], -1);
        if (idx < 0 || idx >= publicPool.length) throw GameError('无效的公共池位置');
        final card = publicPool.removeAt(idx);
        lastEvent = '${name(seat)} 从公共池拿取了【${card['name']}】';
        _acquireCard(seat, card, 'after_draft');
        return;
      }
    }

    // 3. Phase 2: Auction
    if (phase == 'auction') {
      if (seat != bidSeat) throw GameError('还没轮到你竞价');
      if (type == 'pass') {
        passedSeats.add(seat);
        lastEvent = '${name(seat)} 放弃竞标';
        _advanceBidding();
        return;
      }
      if (type == 'bid') {
        final amount = asInt(action['amount'], 0);
        if (amount <= currentBid) {
          throw GameError('出价必须高于当前最高价 ($currentBid)');
        }
        final limit = maxBidFor(seat);
        if (amount > limit) {
          throw GameError('你的${auctionCard!['type'] == 'gold' ? '手牌数量' : '手牌金币'}不足以支付 $amount');
        }
        currentBid = amount;
        highBidder = seat;
        final unit = auctionCard!['type'] == 'gold' ? '张手牌' : '金';
        lastEvent = '${name(seat)} 出价 $amount $unit';
        _advanceBidding();
        return;
      }
      throw GameError('未知拍卖操作');
    }

    throw GameError('非法操作');
  }

  void _advanceBidding() {
    // If all players passed and nobody bid: discard auctionCard
    if (highBidder == -1 && passedSeats.length >= players) {
      lastEvent = '无人竞标【${auctionCard!['name']}】，拍品弃置';
      host.log(lastEvent);
      turn = (turn + 1) % players;
      _nextAuctionCard();
      return;
    }

    // If a highBidder exists and everyone else has passed: highBidder wins!
    if (highBidder != -1 && passedSeats.length >= players - 1) {
      _resolveAuctionWin();
      return;
    }

    // Find next active bidder who hasn't passed and isn't already the sole remaining highBidder
    for (var step = 1; step <= players; step++) {
      final cand = (bidSeat + step) % players;
      if (passedSeats.contains(cand)) continue;
      if (cand == highBidder && passedSeats.length >= players - 1) {
        _resolveAuctionWin();
        return;
      }
      if (cand != highBidder) {
        bidSeat = cand;
        return;
      }
    }
    _resolveAuctionWin();
  }

  void _resolveAuctionWin() {
    final winner = highBidder;
    final card = auctionCard!;
    auctionCard = null;
    turn = (turn + 1) % players;

    if (card['type'] == 'gold') {
      // Pay by discarding `currentBid` lowest-utility cards from hand
      _payWithCards(winner, currentBid);
      lastEvent = '${name(winner)} 弃置 $currentBid 张手牌拍下【${card['name']}】';
      host.log(lastEvent);
      _acquireCard(winner, card, 'after_auction');
    } else {
      // Pay `currentBid` gold using gold cards in hand
      _payWithGold(winner, currentBid);
      lastEvent = '${name(winner)} 支付 $currentBid 金拍下【${card['name']}】';
      host.log(lastEvent);
      _acquireCard(winner, card, 'after_auction');
    }
  }

  void _payWithCards(int seat, int count) {
    // Sort hand so least valuable cards are discarded first (low gold cards first, then low cat cards)
    hands[seat].sort((a, b) {
      final aIsGold = a['type'] == 'gold' ? 0 : 1;
      final bIsGold = b['type'] == 'gold' ? 0 : 1;
      if (aIsGold != bIsGold) return aIsGold.compareTo(bIsGold);
      return asInt(a['val'], 0).compareTo(asInt(b['val'], 0));
    });
    final removeCount = min(count, hands[seat].length);
    hands[seat].removeRange(0, removeCount);
  }

  void _payWithGold(int seat, int requiredGold) {
    if (requiredGold <= 0) return;
    final goldCards = hands[seat].where((c) => c['type'] == 'gold').toList()
      ..sort((a, b) => asInt(a['val'], 0).compareTo(asInt(b['val'], 0)));

    var paid = 0;
    final usedIds = <String>{};
    // First accumulate largest or smallest to cover requiredGold with minimal waste
    for (final g in goldCards) {
      if (paid >= requiredGold) break;
      paid += asInt(g['val'], 0);
      usedIds.add(asStr(g['id']));
    }
    // Check if any chosen smaller card is redundant (can be dropped while still >= requiredGold)
    for (final g in goldCards.reversed) {
      final id = asStr(g['id']);
      final v = asInt(g['val'], 0);
      if (usedIds.contains(id) && paid - v >= requiredGold) {
        paid -= v;
        usedIds.remove(id);
      }
    }
    hands[seat].removeWhere((c) => usedIds.contains(c['id']));
  }

  void _computeEndgameScoring() {
    finalPoints = List<int>.filled(players, 0);
    finalGold = [for (var s = 0; s < players; s++) playerGold(s)];
    categoryResults = [];

    for (var c = 0; c < 5; c++) {
      final sums = List<int>.filled(players, 0);
      final bestTieRank = List<int>.filled(players, 0);
      final bestTieLetter = List<String>.filled(players, '-');

      for (var s = 0; s < players; s++) {
        for (final card in hands[s]) {
          if (card['type'] == 'cat' && card['cat'] == c) {
            sums[s] += asInt(card['val'], 0);
            final tr = asInt(card['tieRank'], 0);
            if (tr > bestTieRank[s]) {
              bestTieRank[s] = tr;
              bestTieLetter[s] = asStr(card['tie'], '-');
            }
          }
        }
      }

      var winner = -1;
      var bestScoreKey = 0;
      for (var s = 0; s < players; s++) {
        if (sums[s] <= 0) continue;
        final key = sums[s] * 100 + bestTieRank[s];
        if (key > bestScoreKey) {
          bestScoreKey = key;
          winner = s;
        }
      }

      if (winner >= 0) {
        finalPoints[winner] += dice[c];
      }

      categoryResults.add({
        'cat': c,
        'catName': categoryNames[c],
        'die': dice[c],
        'sums': sums,
        'tieLetters': bestTieLetter,
        'winner': winner,
      });
    }
  }

  void _finishGame() {
    _computeEndgameScoring();
    _over = true;
    phase = 'end';
    final p = placings!;
    final winners = [
      for (var s = 0; s < players; s++)
        if (p[s] == 1) '${name(s)}(${finalPoints[s]}分/${finalGold[s]}金)',
    ];
    lastEvent = '藏书阁评选结束！获胜者：${winners.join('、')}';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic> view(int seat) {
    final visibleCurrent = currentCard == null
        ? null
        : (seat == turn || _over
            ? currentCard
            : {'id': 'hidden', 'type': 'hidden', 'name': '暗抽手稿'});

    return {
      'mode': mode,
      'phase': phase,
      'subPhase': subPhase,
      'turn': turn,
      'draftSeat': draftSeat,
      'churchSeat': churchSeat,
      'churchRemaining': churchRemaining,
      'dice': dice,
      'deckCount': deck.length,
      'auctionCount': auctionPile.length,
      'keepLeft': keepLeft,
      'auctionLeft': auctionLeft,
      'publicLeft': publicLeft,
      'currentCard': visibleCurrent,
      'publicPool': publicPool,
      'auctionCard': auctionCard,
      'bidSeat': bidSeat,
      'currentBid': currentBid,
      'highBidder': highBidder,
      'passedSeats': passedSeats.toList(),
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'myHand': seat >= 0 && seat < players ? hands[seat] : const [],
      'myGold': seat >= 0 && seat < players ? playerGold(seat) : 0,
      'maxBid': seat >= 0 && seat < players ? maxBidFor(seat) : 0,
      'lastEvent': lastEvent,
      'over': _over,
      if (_over) ...{
        'finalPoints': finalPoints,
        'finalGold': finalGold,
        'categoryResults': categoryResults,
        'allHands': hands,
        'placings': placings,
      },
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;

    // 1. Church die adjustment
    if (churchRemaining > 0 && seat == churchSeat) {
      // Find category where we have the most points in hand and die < 6
      var bestCat = 0;
      var bestMySum = -1;
      for (var c = 0; c < 5; c++) {
        if (dice[c] >= 6) continue;
        final mySum = hands[seat]
            .where((card) => card['type'] == 'cat' && card['cat'] == c)
            .fold<int>(0, (acc, card) => acc + asInt(card['val'], 0));
        if (mySum > bestMySum) {
          bestMySum = mySum;
          bestCat = c;
        }
      }
      if (dice[bestCat] < 6) {
        return {'type': 'church', 'cat': bestCat, 'delta': 1};
      }
      // Fallback: decrease a category we don't have
      for (var c = 0; c < 5; c++) {
        if (dice[c] > 1) return {'type': 'church', 'cat': c, 'delta': -1};
      }
      return {'type': 'church', 'cat': 0, 'delta': 1};
    }

    // 2. Phase 1: Gift
    if (phase == 'gift') {
      if (subPhase == 'allocate' && seat == turn && currentCard != null) {
        final options = <String>[
          if (keepLeft > 0) 'keep',
          if (auctionLeft > 0) 'auction',
          if (publicLeft > 0) 'public',
        ];
        if (options.length == 1) {
          return {'type': 'allocate', 'dest': options.first};
        }
        final c = currentCard!;
        final val = asInt(c['val'], 2);
        final isHigh = c['type'] == 'church' || val >= 3;
        final isMid = val == 2;
        if (isHigh && keepLeft > 0) return {'type': 'allocate', 'dest': 'keep'};
        if (isMid && auctionLeft > 0) return {'type': 'allocate', 'dest': 'auction'};
        if (!isHigh && publicLeft > 0) return {'type': 'allocate', 'dest': 'public'};
        return {'type': 'allocate', 'dest': options[rng.nextInt(options.length)]};
      }

      if (subPhase == 'draft' && seat == draftSeat && publicPool.isNotEmpty) {
        var bestIdx = 0;
        var bestVal = -1;
        for (var i = 0; i < publicPool.length; i++) {
          final c = publicPool[i];
          final v = c['type'] == 'church' ? 4 : asInt(c['val'], 1);
          if (v > bestVal) {
            bestVal = v;
            bestIdx = i;
          }
        }
        return {'type': 'draft', 'index': bestIdx};
      }
    }

    // 3. Phase 2: Auction
    if (phase == 'auction' && seat == bidSeat && auctionCard != null) {
      final limit = maxBidFor(seat);
      if (limit <= currentBid) {
        return {'type': 'pass'};
      }
      final card = auctionCard!;
      int worth;
      if (card['type'] == 'gold') {
        worth = max(1, asInt(card['val'], 1) - 1);
      } else if (card['type'] == 'church') {
        worth = 2;
      } else {
        final cat = asInt(card['cat'], 0);
        final dieVal = dice[cat];
        worth = max(1, (asInt(card['val'], 1) * dieVal) ~/ 3);
      }
      if (currentBid + 1 <= worth && currentBid + 1 <= limit) {
        return {'type': 'bid', 'amount': currentBid + 1};
      }
      return {'type': 'pass'};
    }

    return null;
  }
}
