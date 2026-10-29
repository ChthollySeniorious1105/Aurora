import 'dart:math';

import '../../src/engine.dart';

const List<String> diamondsSuits = ['D', 'H', 'S', 'C'];

const Map<String, String> diamondsSuitNames = {
  'D': '♦方块(直接入库/转存保险箱)',
  'H': '♥红桃(从供应堆拿1钻入展示室)',
  'S': '♠黑桃(展示室转存1钻入保险箱)',
  'C': '♣梅花(偷对手展示室1钻入自己展示室)',
};

const Map<String, String> diamondsSuitShortNames = {
  'D': '♦方块',
  'H': '♥红桃',
  'S': '♠黑桃',
  'C': '♣梅花',
};

/// Builds the 60-card Diamonds deck: 4 suits (`D, H, S, C`) × ranks `1..15`.
List<String> buildDiamondsDeck() => [
      for (final s in diamondsSuits)
        for (var r = 1; r <= 15; r++) '$r$s',
    ];

String diamondsCardSuit(String card) => card.substring(card.length - 1);

int diamondsCardRank(String card) =>
    int.tryParse(card.substring(0, card.length - 1)) ?? 1;

class DiamondsGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;

  /// Current phase: `'play'`
  String phase = 'play';

  List<String> deck = [];
  late List<List<String>> hands;
  late List<int> showroom; // Visible crystals (+1 pt each)
  late List<int> vault; // Safe crystals (+2 pts each)
  late List<int> scores; // vault[s] * 2 + showroom[s] * 1

  late List<List<String>> wonCards; // Cards won in tricks this hand per seat
  late List<int> tricksWon;

  int trickNumber = 1;
  int totalTricksInRound = 10;
  int leader = 0;
  List<Map<String, dynamic>> currentTrick = [];
  List<Map<String, dynamic>> lastTrick = [];

  List<String> actionLog = [];
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  DiamondsGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <String>[]);
    showroom = List.filled(players, 3);
    vault = List.filled(players, 1);
    scores = List.filled(players, 5);
    wonCards = List.generate(players, (_) => <String>[]);
    tricksWon = List.filled(players, 0);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [
      for (var i = 0; i < players; i++)
        if (i != seat) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    for (var s = 0; s < players; s++) {
      showroom[s] = 3;
      vault[s] = 1;
    }
    _recomputeScores();
    _startRound();
  }

  void _recomputeScores() {
    for (var s = 0; s < players; s++) {
      scores[s] = vault[s] * 2 + showroom[s];
    }
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final sa = diamondsSuits.indexOf(diamondsCardSuit(a));
      final sb = diamondsSuits.indexOf(diamondsCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      return diamondsCardRank(a).compareTo(diamondsCardRank(b));
    });
  }

  void _startRound() {
    deck = shuffled(buildDiamondsDeck(), rng);
    totalTricksInRound = 10;
    for (var s = 0; s < players; s++) {
      hands[s] = [for (var i = 0; i < totalTricksInRound; i++) deck.removeLast()];
      _sortHand(hands[s]);
      wonCards[s] = [];
      tricksWon[s] = 0;
    }
    trickNumber = 1;
    leader = startPlayer;
    turn = startPlayer;
    currentTrick = [];
    lastTrick = [];
    actionLog = [];
    phase = 'play';
    host.log('第 $round/$totalRounds 局开始：每人 10 张牌，无主花色，垫牌与赢墩均可触发钻石行动！');
  }

  /// Executes the Suit Action of [suit] (`'D'`, `'H'`, `'S'`, or `'C'`) for [seat].
  void triggerSuitAction(
    int seat,
    String suit, {
    int? targetSeat,
    String reason = '',
  }) {
    final prefix = reason.isNotEmpty ? '[$reason] ' : '';
    switch (suit) {
      case 'D':
        // Move 1 crystal from showroom into vault (or from supply into vault if showroom is empty)
        if (showroom[seat] > 0) {
          showroom[seat] -= 1;
          vault[seat] += 1;
          actionLog.add(
            '$prefix♦ ${name(seat)} 触发方块行动：将 1 颗钻石从展示室锁入保险箱 (+2分安全)',
          );
        } else {
          vault[seat] += 1;
          actionLog.add(
            '$prefix♦ ${name(seat)} 触发方块行动（展示室为空）：直接从供应堆拿 1 颗钻石锁入保险箱 (+2分)',
          );
        }
      case 'H':
        // Take 1 crystal from supply into showroom
        showroom[seat] += 1;
        actionLog.add(
          '$prefix♥ ${name(seat)} 触发红桃行动：从供应堆拿取 1 颗钻石放入展示室 (+1分)',
        );
      case 'S':
        // Move 1 crystal from showroom into vault
        if (showroom[seat] > 0) {
          showroom[seat] -= 1;
          vault[seat] += 1;
          actionLog.add(
            '$prefix♠ ${name(seat)} 触发黑桃行动：将展示室 1 颗钻石转存进保险箱 (+1净分)',
          );
        } else {
          actionLog.add(
            '$prefix♠ ${name(seat)} 触发黑桃行动（展示室无钻石可转存）',
          );
        }
      case 'C':
        // Steal 1 crystal from an opponent's showroom into your showroom (or from supply if all opponents have 0)
        int? victim;
        if (targetSeat != null &&
            targetSeat >= 0 &&
            targetSeat < players &&
            targetSeat != seat &&
            showroom[targetSeat] > 0) {
          victim = targetSeat;
        } else {
          var bestShowroom = 0;
          for (var s = 0; s < players; s++) {
            if (s != seat && showroom[s] > bestShowroom) {
              bestShowroom = showroom[s];
              victim = s;
            }
          }
        }
        if (victim != null) {
          showroom[victim] -= 1;
          showroom[seat] += 1;
          actionLog.add(
            '$prefix♣ ${name(seat)} 触发梅花行动：从 ${name(victim)} 的展示室偷取 1 颗钻石放入自己展示室！',
          );
        } else {
          showroom[seat] += 1;
          actionLog.add(
            '$prefix♣ ${name(seat)} 触发梅花行动（对手展示室均空）：从供应堆拿取 1 颗钻石放入展示室',
          );
        }
    }
    _recomputeScores();
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (hand.isEmpty) return const [];
    if (currentTrick.isEmpty) return List<String>.of(hand);
    final ledSuit = diamondsCardSuit(asStr(currentTrick.first['card']));
    final sameSuit =
        hand.where((c) => diamondsCardSuit(c) == ledSuit).toList();
    return sameSuit.isNotEmpty ? sameSuit : List<String>.of(hand);
  }

  Map<String, int> wonSuitCountsForSeat(int seat) {
    final counts = {for (final s in diamondsSuits) s: 0};
    for (final c in wonCards[seat]) {
      final s = diamondsCardSuit(c);
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type != 'play') throw GameError('当前请出牌 (play)');

    final card = asStr(action['card']);
    final legal = legalCards(seat);
    if (!legal.contains(card)) {
      throw GameError('有花必跟！手中有领出花色时必须跟出同花色牌');
    }

    final ledSuit = currentTrick.isEmpty
        ? diamondsCardSuit(card)
        : diamondsCardSuit(asStr(currentTrick.first['card']));
    final playedSuit = diamondsCardSuit(card);
    final isOffSuit = currentTrick.isNotEmpty && playedSuit != ledSuit;

    hands[seat].remove(card);
    currentTrick.add({'seat': seat, 'card': card});

    // 1. Off-suit play immediately triggers the Suit Action of the played card!
    if (isOffSuit) {
      final stealTarget = action['targetSeat'] is num
          ? asInt(action['targetSeat'])
          : null;
      triggerSuitAction(
        seat,
        playedSuit,
        targetSeat: stealTarget,
        reason: '缺门垫牌',
      );
    }

    if (currentTrick.length < players) {
      turn = (turn + 1) % players;
      return;
    }

    _resolveTrick();
  }

  void _resolveTrick() {
    final ledSuit = diamondsCardSuit(asStr(currentTrick.first['card']));
    var winner = asInt(currentTrick.first['seat']);
    var bestRank = -1;
    final trickCards = <String>[];

    for (final e in currentTrick) {
      final s = asInt(e['seat']);
      final c = asStr(e['card']);
      trickCards.add(c);
      if (diamondsCardSuit(c) == ledSuit) {
        final r = diamondsCardRank(c);
        if (r > bestRank) {
          bestRank = r;
          winner = s;
        }
      }
    }

    tricksWon[winner] += 1;
    wonCards[winner].addAll(trickCards);
    lastTrick = List<Map<String, dynamic>>.of(currentTrick);
    currentTrick = [];

    // 2. Winner of each trick triggers the Suit Action of the winning (led) suit!
    triggerSuitAction(
      winner,
      ledSuit,
      reason: '第$trickNumber墩赢墩($bestRank$ledSuit)',
    );

    if (trickNumber >= totalTricksInRound || hands.every((h) => h.isEmpty)) {
      _finishRound();
      return;
    }

    trickNumber += 1;
    leader = winner;
    turn = winner;
  }

  void _finishRound() {
    // 3. End-of-hand Suit Majority actions + 0-trick Diamond×2 bonus!
    final suitWinners = <String, List<int>>{};
    for (final suit in diamondsSuits) {
      var maxCount = 0;
      for (var s = 0; s < players; s++) {
        final cnt =
            wonCards[s].where((c) => diamondsCardSuit(c) == suit).length;
        if (cnt > maxCount) maxCount = cnt;
      }
      final leaders = <int>[];
      if (maxCount > 0) {
        for (var s = 0; s < players; s++) {
          final cnt =
              wonCards[s].where((c) => diamondsCardSuit(c) == suit).length;
          if (cnt == maxCount) {
            leaders.add(s);
            triggerSuitAction(
              s,
              suit,
              reason: '局末${diamondsSuitShortNames[suit]}最多($maxCount张)',
            );
          }
        }
      }
      suitWinners[suit] = leaders;
    }

    // Any player with 0 tricks won triggers ♦ Diamonds twice!
    for (var s = 0; s < players; s++) {
      if (tricksWon[s] == 0) {
        triggerSuitAction(s, 'D', reason: '零墩补偿1');
        triggerSuitAction(s, 'D', reason: '零墩补偿2');
      }
    }

    _recomputeScores();
    lastRoundSummary = {
      'round': round,
      'tricksWon': List<int>.of(tricksWon),
      'suitWinners': suitWinners,
      'showroom': List<int>.of(showroom),
      'vault': List<int>.of(vault),
      'scores': List<int>.of(scores),
    };

    host.log(
      '第 $round 局结束：${[
        for (var s = 0; s < players; s++)
          '${name(s)} 保险箱${vault[s]}×2+展示室${showroom[s]}=${scores[s]}分'
      ].join('，')}',
    );

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('钻石大盗比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final legal = legalCards(seat);
    if (legal.isEmpty) return null;
    if (botLevel == 0 || legal.length == 1) {
      return {'type': 'play', 'card': legal.first};
    }

    if (currentTrick.isEmpty) {
      // Lead highest card, preferring D or S if showroom has crystals, else H/C
      final sorted = List<String>.of(legal)
        ..sort((a, b) => diamondsCardRank(b).compareTo(diamondsCardRank(a)));
      return {'type': 'play', 'card': sorted.first};
    }

    final ledSuit = diamondsCardSuit(asStr(currentTrick.first['card']));
    final followingSuit = diamondsCardSuit(legal.first) == ledSuit;

    if (!followingSuit) {
      // Off-suit play triggers suit action! Prefer D (or S if showroom > 0), then C/H, using lowest rank card
      int suitPriority(String s) {
        if (s == 'D') return 40;
        if (s == 'S' && showroom[seat] > 0) return 35;
        if (s == 'C') return 25;
        if (s == 'H') return 20;
        return 10;
      }

      final sorted = List<String>.of(legal)
        ..sort((a, b) {
          final pa = suitPriority(diamondsCardSuit(a));
          final pb = suitPriority(diamondsCardSuit(b));
          if (pa != pb) return pb.compareTo(pa);
          return diamondsCardRank(a).compareTo(diamondsCardRank(b));
        });
      return {'type': 'play', 'card': sorted.first};
    }

    // Following suit: try to win with smallest winning card, or play lowest card
    var maxInTrick = -1;
    for (final e in currentTrick) {
      final c = asStr(e['card']);
      if (diamondsCardSuit(c) == ledSuit) {
        maxInTrick = max(maxInTrick, diamondsCardRank(c));
      }
    }
    final winners =
        legal.where((c) => diamondsCardRank(c) > maxInTrick).toList()
          ..sort((a, b) => diamondsCardRank(a).compareTo(diamondsCardRank(b)));
    if (winners.isNotEmpty) {
      return {'type': 'play', 'card': winners.first};
    }
    final lowest = List<String>.of(legal)
      ..sort((a, b) => diamondsCardRank(a).compareTo(diamondsCardRank(b)));
    return {'type': 'play', 'card': lowest.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myHand = hasSeat ? List<String>.of(hands[seat]) : <String>[];
    final myLegal = (hasSeat && seat == turn && phase == 'play')
        ? legalCards(seat)
        : const <String>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'turn': turn,
      'trickNumber': trickNumber,
      'totalTricksInRound': totalTricksInRound,
      'leader': leader,
      'showroom': List<int>.of(showroom),
      'vault': [
        for (var s = 0; s < players; s++)
          (_over || s == seat) ? vault[s] : vault[s],
      ],
      'scores': List<int>.of(scores),
      'tricksWon': List<int>.of(tricksWon),
      'wonSuitCounts': [
        for (var s = 0; s < players; s++) wonSuitCountsForSeat(s),
      ],
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'legalCards': myLegal,
      'currentTrick': [
        for (final e in currentTrick) Map<String, dynamic>.of(e),
      ],
      'lastTrick': [
        for (final e in lastTrick) Map<String, dynamic>.of(e),
      ],
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
