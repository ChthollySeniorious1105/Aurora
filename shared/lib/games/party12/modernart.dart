import 'dart:math';

import '../../src/engine.dart';

class ArtistDef {
  final int id;
  final String name;
  final String enName;
  final int cardCount;
  const ArtistDef(this.id, this.name, this.enName, this.cardCount);
}

const List<ArtistDef> kModernArtArtists = [
  ArtistDef(0, '莱特金属', 'Lite Metal', 12),
  ArtistDef(1, '小野洋子', 'Yoko', 13),
  ArtistDef(2, '克里斯汀', 'Christin', 14),
  ArtistDef(3, '卡尔·吉特', 'Karl Gitter', 15),
  ArtistDef(4, '克里普托', 'Krypto', 16),
];

const List<String> kAuctionTypes = ['open', 'once', 'sealed', 'fixed', 'double'];

const Map<String, String> kAuctionTypeLabels = {
  'open': '公开竞拍',
  'once': '一轮竞价',
  'sealed': '暗标竞拍',
  'fixed': '一口价',
  'double': '联合双拍',
};

class PaintingCard {
  final int id;
  final int artist; // 0..4
  final String auctionType; // 'open' | 'once' | 'sealed' | 'fixed' | 'double'
  final String title;

  const PaintingCard({
    required this.id,
    required this.artist,
    required this.auctionType,
    required this.title,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'artist': artist,
        'artistName': kModernArtArtists[artist].name,
        'auctionType': auctionType,
        'auctionLabel': kAuctionTypeLabels[auctionType] ?? auctionType,
        'title': title,
      };
}

List<PaintingCard> buildModernArtDeck() {
  const titles = [
    ['赛博霓虹', '铬合金之梦', '量子棱镜', '机械脉搏', '冷光矩阵', '钛金风暴', '超导回响', '液态水银', '未来遗迹', '激光几何', '齿轮交响', '星际装甲'],
    ['静谧折纸', '枯山水影', '浮世微风', '月下竹林', '墨染樱吹', '禅意空庭', '纸鹤千羽', '雾海孤舟', '水墨苔痕', '风铃絮语', '白砂涟漪', '茶烟一缕', '落叶归根'],
    ['绯红狂想', '午夜巴黎', '天鹅绒之吻', '黄金华尔兹', '蔷薇迷宫', '蒙马特高地', '香槟泡沫', '紫罗兰夜曲', '丝绸幻影', '歌剧魅影', '塞纳河畔', '琉璃花窗', '印象日出', '芭蕾舞伶'],
    ['解构方格', '极简线条', '原色碰撞', '包豪斯之窗', '正负空间', '几何秩序', '垂直律动', '黄金分割', '黑白张力', '不对称平衡', '立方体变奏', '网格迷城', '纯粹形态', '视觉错觉', '抽象坐标'],
    ['神秘符号', '暗网图腾', '像素崩坏', '混沌算法', '虚空之眼', '迷因狂潮', '加密信标', '幻觉光谱', '高维投影', '奇点降临', '幽灵协议', '量子纠缠', '神经漫游', '数字废墟', '未知代码', '终极谜题'],
  ];
  final cards = <PaintingCard>[];
  var nextId = 1;
  for (final a in kModernArtArtists) {
    for (var i = 0; i < a.cardCount; i++) {
      final type = kAuctionTypes[i % kAuctionTypes.length];
      final title = titles[a.id][i % titles[a.id].length];
      cards.add(PaintingCard(
        id: nextId++,
        artist: a.id,
        auctionType: type,
        title: title,
      ));
    }
  }
  return cards;
}

class ModernArtGame extends GameEngine {
  late int maxSeasons;
  int season = 1;

  final List<PaintingCard> deck = [];
  late List<List<PaintingCard>> hands;
  late List<int> cash;

  /// Paintings bought by each player in the current season: seasonPaintings[seat][artist]
  late List<List<int>> seasonPaintings;

  /// Total paintings of each artist played onto the market this season (5th triggers immediate season end)
  List<int> seasonCount = List.filled(5, 0);

  /// Cumulative market value of each artist across completed seasons
  List<int> cumulativeValue = List.filled(5, 0);

  /// History of season valuations: each entry is List<int> of bonus [0/10/20/30] per artist
  final List<List<int>> seasonHistory = [];

  /// Phase: 'play' | 'set_price' | 'open' | 'once' | 'sealed' | 'fixed' | 'end'
  String phase = 'play';
  int turnSeat = 0;

  /// Current auction state
  int sellerSeat = 0;
  List<PaintingCard> activeCards = [];
  String activeAuctionType = 'open';
  int highBid = 0;
  int highBidder = -1;
  int fixedPrice = 0;

  /// Order of remaining bidders for 'open', 'once', 'fixed'
  List<int> bidderQueue = [];

  /// Secret bids for 'sealed' auction: null if not yet submitted
  List<int?> sealedBids = [];

  Map<String, dynamic>? lastAuctionResult;
  Map<String, dynamic>? lastSeasonSummary;

  ModernArtGame(super.setup);

  int get currentBidder => bidderQueue.isNotEmpty ? bidderQueue.first : -1;

  @override
  void start() {
    maxSeasons = setup.opt<int>('seasons', 4);
    season = 1;
    deck
      ..clear()
      ..addAll(shuffled(buildModernArtDeck(), rng));
    hands = List.generate(players, (_) => <PaintingCard>[]);
    cash = List.filled(players, 100);
    seasonPaintings = List.generate(players, (_) => List.filled(5, 0));
    seasonCount = List.filled(5, 0);
    cumulativeValue = List.filled(5, 0);
    seasonHistory.clear();
    lastAuctionResult = null;
    lastSeasonSummary = null;

    _dealForSeason(1);
    turnSeat = 0;
    phase = 'play';
    host.log('现代艺术开始！共 $maxSeasons 个赛季，每位收藏家初始资金 \$100。');
  }

  int _cardsToDeal(int s) {
    if (s == 1) {
      return players == 3 ? 10 : (players == 4 ? 9 : 8);
    } else if (s == 2 || s == 3) {
      return players == 3 ? 6 : (players == 4 ? 4 : 3);
    }
    return 0;
  }

  void _dealForSeason(int s) {
    final count = _cardsToDeal(s);
    for (var i = 0; i < count; i++) {
      for (var p = 0; p < players; p++) {
        if (deck.isNotEmpty) {
          hands[p].add(deck.removeLast());
        }
      }
    }
    // Ensure at least one player has a card if deck is non-empty
    if (hands.every((h) => h.isEmpty) && deck.isNotEmpty) {
      for (var p = 0; p < players && deck.isNotEmpty; p++) {
        hands[p].add(deck.removeLast());
      }
    }
  }

  @override
  bool get isOver => phase == 'end';

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    switch (phase) {
      case 'play':
        return [turnSeat];
      case 'set_price':
        return [sellerSeat];
      case 'open':
      case 'once':
      case 'fixed':
        return currentBidder >= 0 ? [currentBidder] : const [];
      case 'sealed':
        return [
          for (var s = 0; s < players; s++)
            if (sealedBids[s] == null) s
        ];
      default:
        return const [];
    }
  }

  PaintingCard _findAndRemoveCard(int seat, Object? cardIdOrIdx) {
    final h = hands[seat];
    if (h.isEmpty) throw GameError('你手中没有画作牌');
    final id = asInt(cardIdOrIdx, -1);
    final byIdIdx = h.indexWhere((c) => c.id == id);
    if (byIdIdx >= 0) return h.removeAt(byIdIdx);
    if (id >= 0 && id < h.length) return h.removeAt(id);
    throw GameError('未找到指定的画作牌');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('当前不是你的行动阶段');

    final type = asStr(action['type']);

    if (phase == 'play') {
      if (type != 'play' && type != 'play_double') {
        throw GameError('请打出一张画作进行拍卖');
      }
      final rawCard = action['cardId'] ?? action['card'] ?? action['index'];
      final primary = _findAndRemoveCard(seat, rawCard);
      sellerSeat = seat;
      activeCards = [primary];
      activeAuctionType = primary.auctionType;

      // Optional 2nd card attachment when playing a 'double' painting
      final rawSecond = action['secondCardId'] ?? action['secondCard'] ?? action['secondIndex'];
      if (primary.auctionType == 'double' && rawSecond != null) {
        final idx2 = hands[seat].indexWhere(
          (c) => c.id == asInt(rawSecond, -1),
        );
        PaintingCard? second;
        if (idx2 >= 0) {
          second = hands[seat][idx2];
          if (second.artist != primary.artist) {
            hands[seat].add(primary);
            throw GameError('联合双拍的第二幅画必须是同一位画家的作品');
          }
          hands[seat].removeAt(idx2);
        } else {
          final i2 = asInt(rawSecond, -1);
          if (i2 >= 0 && i2 < hands[seat].length) {
            if (hands[seat][i2].artist != primary.artist) {
              hands[seat].add(primary);
              throw GameError('联合双拍的第二幅画必须是同一位画家的作品');
            }
            second = hands[seat].removeAt(i2);
          } else {
            hands[seat].add(primary);
            throw GameError('未找到联合双拍的第二幅画作');
          }
        }
        activeCards.add(second);
        activeAuctionType = second.auctionType == 'double' ? 'open' : second.auctionType;
      } else if (primary.auctionType == 'double') {
        activeAuctionType = 'open';
      }

      final artist = primary.artist;
      seasonCount[artist] += activeCards.length;
      final artistName = kModernArtArtists[artist].name;

      // Check 5th painting immediate season-end rule!
      if (seasonCount[artist] >= 5) {
        host.log('${name(seat)} 打出【$artistName】的第 ${seasonCount[artist]} 幅作品，本季立即结束（该画作不进行拍卖）！');
        _endSeason();
        return;
      }

      host.log('${name(seat)} 拿出 ${activeCards.length} 幅【$artistName】画作，进行【${kAuctionTypeLabels[activeAuctionType]}】！');

      if (activeAuctionType == 'fixed') {
        final p = asInt(action['price'], -1);
        if (p >= 1 && p <= max(1, cash[sellerSeat])) {
          _startFixedAuction(min(p, cash[sellerSeat]));
        } else {
          phase = 'set_price';
        }
      } else {
        _beginAuction(activeAuctionType);
      }
      return;
    }

    if (phase == 'set_price') {
      if (type != 'set_price' && type != 'price') {
        throw GameError('请设定一口价金额');
      }
      final maxPrice = max(1, cash[sellerSeat]);
      final p = asInt(action['price'] ?? action['amount'], -1);
      if (p < 1 || p > maxPrice) {
        throw GameError('一口价必须在 1 到 ${cash[sellerSeat]} 之间');
      }
      _startFixedAuction(min(p, cash[sellerSeat]));
      return;
    }

    if (phase == 'open') {
      if (type == 'pass') {
        bidderQueue.removeAt(0);
        if (bidderQueue.isEmpty || (bidderQueue.length == 1 && bidderQueue.first == highBidder)) {
          _resolveStandardAuction();
        }
        return;
      }
      if (type == 'bid') {
        final amount = asInt(action['amount'] ?? action['bid'], -1);
        if (amount <= highBid) throw GameError('出价必须高于当前最高价 \$$highBid');
        if (amount > cash[seat]) throw GameError('出价不能超过你的现金 \$${cash[seat]}');
        highBid = amount;
        highBidder = seat;
        // Move current bidder to the back of the active bidder queue
        final s = bidderQueue.removeAt(0);
        bidderQueue.add(s);
        // Remove any other players who cannot outbid highBid
        bidderQueue.removeWhere((b) => b != highBidder && cash[b] <= highBid);
        if (bidderQueue.length <= 1) {
          _resolveStandardAuction();
        }
        return;
      }
      throw GameError('公开竞拍请出价(bid)或放弃(pass)');
    }

    if (phase == 'once') {
      if (type == 'pass') {
        bidderQueue.removeAt(0);
        if (bidderQueue.isEmpty) {
          _resolveStandardAuction();
        }
        return;
      }
      if (type == 'bid') {
        final amount = asInt(action['amount'] ?? action['bid'], -1);
        if (amount <= highBid) throw GameError('出价必须高于当前最高价 \$$highBid');
        if (amount > cash[seat]) throw GameError('出价不能超过你的现金 \$${cash[seat]}');
        highBid = amount;
        highBidder = seat;
        bidderQueue.removeAt(0);
        if (bidderQueue.isEmpty) {
          _resolveStandardAuction();
        }
        return;
      }
      throw GameError('一轮竞价请出价(bid)或放弃(pass)');
    }

    if (phase == 'sealed') {
      if (type != 'bid' && type != 'sealed_bid') {
        throw GameError('暗标竞拍请提交暗标金额(bid)');
      }
      final amount = asInt(action['amount'] ?? action['bid'], -1);
      if (amount < 0 || amount > cash[seat]) {
        throw GameError('暗标金额必须在 0 到 ${cash[seat]} 之间');
      }
      sealedBids[seat] = amount;
      if (sealedBids.every((b) => b != null)) {
        // Determine highest bidder; ties broken clockwise starting from sellerSeat
        var bestBid = 0;
        var bestSeat = -1;
        for (var i = 0; i < players; i++) {
          final s = (sellerSeat + i) % players;
          final b = sealedBids[s] ?? 0;
          if (b > bestBid) {
            bestBid = b;
            bestSeat = s;
          }
        }
        highBid = bestBid;
        highBidder = bestSeat;
        _resolveStandardAuction();
      }
      return;
    }

    if (phase == 'fixed') {
      if (type == 'buy' || type == 'accept') {
        if (cash[seat] < fixedPrice) {
          throw GameError('你的现金不足以支付一口价 \$$fixedPrice');
        }
        highBid = fixedPrice;
        highBidder = seat;
        _resolveStandardAuction();
        return;
      }
      if (type == 'pass') {
        bidderQueue.removeAt(0);
        if (bidderQueue.isEmpty) {
          // Seller must buy from the bank at fixedPrice
          highBid = min(fixedPrice, cash[sellerSeat]);
          highBidder = sellerSeat;
          _resolveStandardAuction();
        }
        return;
      }
      throw GameError('一口价请选择购买(buy)或放弃(pass)');
    }
  }

  void _startFixedAuction(int price) {
    fixedPrice = price;
    highBid = price;
    highBidder = -1;
    bidderQueue = [
      for (var i = 1; i < players; i++) (sellerSeat + i) % players
    ];
    phase = 'fixed';
    host.log('${name(sellerSeat)} 设定一口价为 \$$fixedPrice！');
  }

  void _beginAuction(String auctionType) {
    highBid = 0;
    highBidder = -1;
    fixedPrice = 0;
    if (auctionType == 'open') {
      bidderQueue = [
        for (var i = 1; i <= players; i++) (sellerSeat + i) % players
      ];
      phase = 'open';
    } else if (auctionType == 'once') {
      bidderQueue = [
        for (var i = 1; i <= players; i++) (sellerSeat + i) % players
      ];
      phase = 'once';
    } else if (auctionType == 'sealed') {
      sealedBids = List.filled(players, null);
      phase = 'sealed';
    }
  }

  void _resolveStandardAuction() {
    final artist = activeCards.first.artist;
    final count = activeCards.length;
    final artistName = kModernArtArtists[artist].name;

    int winner;
    int price;
    if (highBidder < 0 || highBid <= 0) {
      winner = sellerSeat;
      price = 0;
      seasonPaintings[winner][artist] += count;
      host.log('无人出价，${name(winner)} 免费获得 $count 幅【$artistName】画作。');
    } else if (highBidder == sellerSeat) {
      winner = sellerSeat;
      price = highBid;
      cash[sellerSeat] -= price;
      seasonPaintings[winner][artist] += count;
      host.log('${name(sellerSeat)} 以 \$$price 向银行买下自己的 $count 幅【$artistName】画作。');
    } else {
      winner = highBidder;
      price = highBid;
      cash[winner] -= price;
      cash[sellerSeat] += price;
      seasonPaintings[winner][artist] += count;
      host.log('${name(winner)} 以 \$$price 向 ${name(sellerSeat)} 购得 $count 幅【$artistName】画作！');
    }

    lastAuctionResult = {
      'seller': sellerSeat,
      'winner': winner,
      'price': price,
      'artist': artist,
      'count': count,
      'auctionType': activeAuctionType,
    };
    activeCards = [];

    // Advance to next player with cards in hand
    if (hands.every((h) => h.isEmpty)) {
      host.log('所有玩家手牌已打空，本季结束！');
      _endSeason();
      return;
    }

    for (var i = 1; i <= players; i++) {
      final next = (sellerSeat + i) % players;
      if (hands[next].isNotEmpty) {
        turnSeat = next;
        break;
      }
    }
    phase = 'play';
  }

  void _endSeason() {
    // Rank artists with at least 1 painting this season by seasonCount desc, tiebreak by smaller artist id
    final activeArtists = [
      for (var a = 0; a < 5; a++)
        if (seasonCount[a] > 0) a
    ];
    activeArtists.sort((a, b) {
      final cmp = seasonCount[b].compareTo(seasonCount[a]);
      return cmp != 0 ? cmp : a.compareTo(b);
    });

    final seasonBonus = List.filled(5, 0);
    const bonuses = [30, 20, 10];
    for (var i = 0; i < activeArtists.length && i < 3; i++) {
      final a = activeArtists[i];
      seasonBonus[a] = bonuses[i];
      cumulativeValue[a] += bonuses[i];
    }
    seasonHistory.add(List.of(seasonBonus));

    // All players sell their purchased Season paintings at each Artist's cumulative value
    final earnings = List.filled(players, 0);
    for (var s = 0; s < players; s++) {
      var gain = 0;
      for (var a = 0; a < 5; a++) {
        if (seasonPaintings[s][a] > 0 && cumulativeValue[a] > 0) {
          gain += seasonPaintings[s][a] * cumulativeValue[a];
        }
        seasonPaintings[s][a] = 0;
      }
      cash[s] += gain;
      earnings[s] = gain;
    }

    lastSeasonSummary = {
      'season': season,
      'seasonCount': List.of(seasonCount),
      'seasonBonus': seasonBonus,
      'cumulativeValue': List.of(cumulativeValue),
      'earnings': earnings,
    };

    host.log('第 $season 季结算完成！当前各画家累计市场价值：'
        '${[for (var a = 0; a < 5; a++) '${kModernArtArtists[a].name}\$${cumulativeValue[a]}'].join('、')}。');

    activeCards = [];
    if (season >= maxSeasons) {
      phase = 'end';
      host.log('现代艺术全部 $maxSeasons 季结束！最终现金最高者获胜！');
      return;
    }

    season++;
    seasonCount = List.filled(5, 0);
    _dealForSeason(season);

    if (hands.every((h) => h.isEmpty)) {
      phase = 'end';
      return;
    }

    for (var i = 1; i <= players; i++) {
      final next = (sellerSeat + i) % players;
      if (hands[next].isNotEmpty) {
        turnSeat = next;
        break;
      }
    }
    phase = 'play';
  }

  int _estimatedCardValue(int artist) {
    final currentCount = seasonCount[artist];
    final projectedBonus = currentCount >= 3 ? 30 : (currentCount >= 1 ? 20 : 10);
    return cumulativeValue[artist] + projectedBonus;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'play') {
      final h = hands[seat];
      if (h.isEmpty) return null;
      if (botLevel == 0) {
        final c = h[rng.nextInt(h.length)];
        return {'type': 'play', 'cardId': c.id};
      }
      // Prefer playing an artist we have multiple of or high market momentum
      var bestCard = h.first;
      var bestScore = -999;
      for (final c in h) {
        final score = seasonCount[c.artist] * 10 + cumulativeValue[c.artist] + seasonPaintings[seat][c.artist] * 15;
        if (score > bestScore) {
          bestScore = score;
          bestCard = c;
        }
      }
      if (bestCard.auctionType == 'double') {
        final partner = h.where((c) => c.id != bestCard.id && c.artist == bestCard.artist && c.auctionType != 'double').toList();
        if (partner.isNotEmpty && seasonCount[bestCard.artist] <= 2) {
          return {
            'type': 'play',
            'cardId': bestCard.id,
            'secondCardId': partner.first.id,
          };
        }
      }
      return {'type': 'play', 'cardId': bestCard.id};
    }

    final artist = activeCards.isNotEmpty ? activeCards.first.artist : 0;
    final estTotal = _estimatedCardValue(artist) * max(1, activeCards.length);
    final maxAffordable = cash[seat];

    if (phase == 'set_price') {
      final target = (estTotal * 0.65).round().clamp(1, max(1, maxAffordable));
      return {'type': 'set_price', 'price': target};
    }

    if (phase == 'open' || phase == 'once') {
      final limit = min(maxAffordable, (estTotal * (botLevel == 0 ? 0.5 : 0.75)).round());
      if (highBid + 4 <= limit && (phase == 'once' || rng.nextDouble() < 0.65)) {
        final nextBid = min(limit, highBid + 3 + rng.nextInt(5));
        if (nextBid > highBid && nextBid <= maxAffordable) {
          return {'type': 'bid', 'amount': nextBid};
        }
      }
      return {'type': 'pass'};
    }

    if (phase == 'sealed') {
      final limit = min(maxAffordable, (estTotal * 0.6).round());
      final bid = limit > 0 ? rng.nextInt(limit + 1) : 0;
      return {'type': 'bid', 'amount': bid};
    }

    if (phase == 'fixed') {
      if (maxAffordable >= fixedPrice && fixedPrice <= (estTotal * 0.85).round()) {
        return {'type': 'buy'};
      }
      return {'type': 'pass'};
    }

    return null;
  }

  @override
  List<int>? get placings => isOver ? rankByScore(cash) : null;

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = seat >= 0 && seat < players
        ? [for (final c in hands[seat]) c.toJson()]
        : const <Map<String, dynamic>>[];

    return {
      'phase': phase,
      'season': season,
      'maxSeasons': maxSeasons,
      'turnSeat': turnSeat,
      'sellerSeat': sellerSeat,
      'currentBidder': currentBidder,
      'cash': cash,
      'hand': myHand,
      'handCounts': [for (final h in hands) h.length],
      'deckCount': deck.length,
      'seasonPaintings': seasonPaintings,
      'seasonCount': seasonCount,
      'cumulativeValue': cumulativeValue,
      'seasonHistory': seasonHistory,
      'activeCards': [for (final c in activeCards) c.toJson()],
      'activeAuctionType': activeAuctionType,
      'highBid': highBid,
      'highBidder': highBidder,
      'fixedPrice': fixedPrice,
      'mySealedBid': (seat >= 0 && seat < sealedBids.length) ? sealedBids[seat] : null,
      'sealedSubmitted': [for (final b in sealedBids) b != null],
      'lastAuctionResult': lastAuctionResult,
      'lastSeasonSummary': lastSeasonSummary,
      'waitingFor': waitingFor,
    };
  }
}
