import '../../src/engine.dart';

/// Builds the 109-card Linko! (Abluxxen) deck:
/// - Ranks `1..13`: `8` copies each (`104` cards)
/// - Rank `14` (`'X'` Joker): `5` copies (`5` cards)
/// Total = `109` cards.
List<int> buildLinkoDeck() => [
      for (var r = 1; r <= 13; r++)
        for (var c = 0; c < 8; c++) r,
      for (var j = 0; j < 5; j++) 14,
    ];

String linkoCardLabel(int rank) => rank == 14 ? 'X' : '$rank';

/// Computes all legal set plays `(rank, count, jokers)` from [hand].
List<Map<String, int>> linkoLegalPlays(List<int> hand) {
  if (hand.isEmpty) return const [];
  final counts = <int, int>{};
  for (final c in hand) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  final jokersInHand = counts[14] ?? 0;
  final out = <Map<String, int>>[];

  for (var r = 1; r <= 13; r++) {
    final nat = counts[r] ?? 0;
    if (nat <= 0) continue;
    for (var n = 1; n <= nat; n++) {
      for (var j = 0; j <= jokersInHand; j++) {
        out.add({
          'rank': r,
          'count': n + j,
          'jokers': j,
        });
      }
    }
  }

  // Playing pure Jokers as rank 14 ('X')
  for (var j = 1; j <= jokersInHand; j++) {
    out.add({
      'rank': 14,
      'count': j,
      'jokers': j,
    });
  }

  // Sort by larger count, then higher rank, then fewer jokers
  out.sort((a, b) {
    final cCmp = b['count']!.compareTo(a['count']!);
    if (cCmp != 0) return cCmp;
    final rCmp = b['rank']!.compareTo(a['rank']!);
    if (rCmp != 0) return rCmp;
    return a['jokers']!.compareTo(b['jokers']!);
  });
  return out;
}

/// Checks whether a set of `count == playedCount` and `rank == playedRank`
/// snatches an opponent's set of `oppCount` and `oppRank`:
/// Must have **EXACT SAME card count (`oppCount == playedCount`)** AND
/// **STRICTLY LOWER rank (`oppRank < playedRank`)**!
bool linkoCanSnatch({
  required int playedRank,
  required int playedCount,
  required int oppRank,
  required int oppCount,
}) =>
    oppCount == playedCount && oppRank < playedRank;

/// Computes the Linko! round score for a seat:
/// `(+1 pt per card in tableau) - (1 pt per card remaining in hand)`.
int linkoScoreSeat(List<Map<String, dynamic>> seatTableau, List<int> seatHand) {
  final tabCards = seatTableau.fold<int>(
    0,
    (sum, s) => sum + asInt(s['count'], (s['cards'] as List?)?.length ?? 0),
  );
  return tabCards - seatHand.length;
}

class LinkoGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;

  /// Current phase:
  /// - `'play'`: Active player plays a set of equal-rank cards from hand to tableau
  /// - `'snatch'`: Active player resolves pending snatched opponent sets (`'take'` vs `'return'`)
  String phase = 'play';

  List<int> deck = [];
  List<int> pool = []; // 6-card face-up market pool
  late List<List<int>> hands;
  late List<List<Map<String, dynamic>>> tableau;
  late List<int> scores;

  List<Map<String, dynamic>> pendingSnatches = [];
  List<String> actionLog = [];
  Map<String, dynamic>? lastRoundSummary;
  int turnsInRound = 0;

  bool _over = false;
  List<int>? _placings;

  LinkoGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 2);
    hands = List.generate(players, (_) => <int>[]);
    tableau = List.generate(players, (_) => <Map<String, dynamic>>[]);
    scores = List.filled(players, 0);
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
    _startRound();
  }

  void _sortHand(List<int> hand) {
    hand.sort();
  }

  void _refillPool() {
    while (pool.length < 6 && deck.isNotEmpty) {
      pool.add(deck.removeLast());
    }
    pool.sort();
  }

  List<int> _drawReplenishCards(int count) {
    final drawn = <int>[];
    for (var i = 0; i < count; i++) {
      if (pool.isNotEmpty) {
        // Take highest card from face-up pool and immediately refill pool from deck
        pool.sort();
        drawn.add(pool.removeLast());
        _refillPool();
      } else if (deck.isNotEmpty) {
        drawn.add(deck.removeLast());
      }
    }
    return drawn;
  }

  void _startRound() {
    deck = shuffled(buildLinkoDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = [for (var i = 0; i < 13; i++) deck.removeLast()];
      _sortHand(hands[s]);
      tableau[s] = [];
    }
    pool = [for (var i = 0; i < 6; i++) deck.removeLast()]..sort();
    pendingSnatches = [];
    actionLog = [];
    turnsInRound = 0;
    phase = 'play';
    turn = startPlayer;

    host.log('第 $round/$totalRounds 局开始：每人 13 张手牌，市场明牌池 6 张');
  }

  int tableauCardCount(int seat) => tableau[seat].fold<int>(
        0,
        (sum, s) => sum + asInt(s['count'], 0),
      );

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'play') {
      if (type != 'play') throw GameError('当前请出牌 (play)');
      final rank = asInt(action['rank'], 0);
      final count = asInt(action['count'], 0);
      final jokers = asInt(action['jokers'], 0);

      if (rank < 1 || rank > 14 || count < 1 || jokers < 0 || jokers > count) {
        throw GameError('无效的出牌参数');
      }
      if (rank == 14 && jokers != count) {
        throw GameError('纯百搭牌组 (X=14) 必须全部由百搭牌组成');
      }
      if (rank < 14 && jokers == count) {
        throw GameError('普通点数牌组至少需要 1 张对应自然点数牌');
      }

      final naturalNeeded = rank == 14 ? 0 : (count - jokers);
      final natHave = hands[seat].where((c) => c == rank).length;
      final jokHave = hands[seat].where((c) => c == 14).length;

      if (natHave < naturalNeeded) {
        throw GameError('手牌中没有足够的点数 $rank（需要 $naturalNeeded 张）');
      }
      if (jokHave < jokers) {
        throw GameError('手牌中没有足够的百搭牌 X（需要 $jokers 张）');
      }

      final playedCards = <int>[];
      for (var i = 0; i < naturalNeeded; i++) {
        hands[seat].remove(rank);
        playedCards.add(rank);
      }
      for (var i = 0; i < jokers; i++) {
        hands[seat].remove(14);
        playedCards.add(14);
      }

      final newSet = <String, dynamic>{
        'rank': rank,
        'count': count,
        'jokers': jokers,
        'cards': playedCards,
      };
      tableau[seat].add(newSet);
      actionLog.add(
        '${name(seat)} 打出 $count 张 [${linkoCardLabel(rank)}]${jokers > 0 && rank < 14 ? " (含$jokers张X)" : ""}',
      );

      // Linko Snatch Check: scan all opponents in turn order for equal-count, strictly lower-rank sets!
      pendingSnatches = [];
      for (var off = 1; off < players; off++) {
        final opp = (seat + off) % players;
        final remainingSets = <Map<String, dynamic>>[];
        for (final oppSet in tableau[opp]) {
          final oppRank = asInt(oppSet['rank'], 0);
          final oppCount = asInt(oppSet['count'], 0);
          if (linkoCanSnatch(
            playedRank: rank,
            playedCount: count,
            oppRank: oppRank,
            oppCount: oppCount,
          )) {
            pendingSnatches.add({
              'snatcher': seat,
              'victim': opp,
              'rank': oppRank,
              'count': oppCount,
              'jokers': asInt(oppSet['jokers'], 0),
              'cards': List<int>.of((oppSet['cards'] as List).cast<int>()),
            });
          } else {
            remainingSets.add(oppSet);
          }
        }
        tableau[opp] = remainingSets;
      }

      // If caller supplied an immediate snatchChoice on 'play', resolve all pending snatches right away
      final immediateChoice = asStr(action['snatchChoice']);
      if (pendingSnatches.isNotEmpty &&
          (immediateChoice == 'take' || immediateChoice == 'return')) {
        final disc = asBool(action['discard']);
        while (pendingSnatches.isNotEmpty) {
          _applySnatchResolution(seat, immediateChoice, discard: disc);
        }
        _finishTurnAfterSnatches();
        return;
      }

      if (pendingSnatches.isNotEmpty) {
        phase = 'snatch';
        host.log(
          '${name(seat)} 的 $count×[${linkoCardLabel(rank)}] 触发林科抢牌 (Linko Snatch)，共抢下 ${pendingSnatches.length} 组同张数低点牌！',
        );
        return;
      }

      _finishTurnAfterSnatches();
      return;
    }

    if (phase == 'snatch') {
      if (type != 'snatch_choice') {
        throw GameError('请选择抢牌处理方式 (snatch_choice)');
      }
      final choice = asStr(action['choice'], 'take');
      if (choice != 'take' && choice != 'return') {
        throw GameError('抢牌选项必须为 take (收入手牌) 或 return (退回对方)');
      }
      final disc = asBool(action['discard']);
      _applySnatchResolution(seat, choice, discard: disc);
      if (pendingSnatches.isEmpty) {
        _finishTurnAfterSnatches();
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _applySnatchResolution(
    int snatcher,
    String choice, {
    bool discard = false,
  }) {
    if (pendingSnatches.isEmpty) return;
    final sn = pendingSnatches.removeAt(0);
    final victim = asInt(sn['victim'], 0);
    final count = asInt(sn['count'], 1);
    final rank = asInt(sn['rank'], 1);
    final cards = List<int>.of((sn['cards'] as List).cast<int>());

    if (choice == 'take') {
      // Snatcher takes the snatched cards into hand; victim replenishes `count` cards from pool/deck!
      hands[snatcher].addAll(cards);
      _sortHand(hands[snatcher]);
      final repl = _drawReplenishCards(count);
      hands[victim].addAll(repl);
      _sortHand(hands[victim]);
      actionLog.add(
        '⚡ ${name(snatcher)} 将 ${name(victim)} 的 $count×[${linkoCardLabel(rank)}] 抢入手牌（${name(victim)} 补摸 ${repl.length} 张）',
      );
    } else {
      // Snatcher forces victim to take snatched cards back into hand (or discard them for replacements)
      if (discard) {
        final repl = _drawReplenishCards(count);
        hands[victim].addAll(repl);
        _sortHand(hands[victim]);
        actionLog.add(
          '⚡ ${name(snatcher)} 迫使 ${name(victim)} 弃掉被抢的 $count×[${linkoCardLabel(rank)}] 并重摸 ${repl.length} 张',
        );
      } else {
        hands[victim].addAll(cards);
        _sortHand(hands[victim]);
        actionLog.add(
          '⚡ ${name(snatcher)} 将被抢的 $count×[${linkoCardLabel(rank)}] 退回 ${name(victim)} 手牌（使其手牌负分增加）',
        );
      }
    }
  }

  void _finishTurnAfterSnatches() {
    phase = 'play';
    turnsInRound += 1;

    // Round ends immediately when any player empties their hand or the draw deck runs out
    final emptySeat = hands.indexWhere((h) => h.isEmpty);
    if (emptySeat >= 0 || deck.isEmpty || turnsInRound >= players * 18) {
      _finishRound(
        reason: emptySeat >= 0
            ? '${name(emptySeat)} 出完所有手牌！'
            : '牌库摸空，本局结束！',
      );
      return;
    }

    turn = (turn + 1) % players;
  }

  void _finishRound({required String reason}) {
    final tableauCounts = [for (var s = 0; s < players; s++) tableauCardCount(s)];
    final handPenalties = [for (var s = 0; s < players; s++) hands[s].length];
    final roundScores = [
      for (var s = 0; s < players; s++)
        linkoScoreSeat(tableau[s], hands[s]),
    ];

    for (var s = 0; s < players; s++) {
      scores[s] += roundScores[s];
    }

    lastRoundSummary = {
      'round': round,
      'reason': reason,
      'tableauCounts': tableauCounts,
      'handPenalties': handPenalties,
      'roundScores': roundScores,
      'scores': List<int>.of(scores),
    };
    host.log('第 $round 局结算：$reason');

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'snatch' && pendingSnatches.isNotEmpty) {
      final sn = pendingSnatches.first;
      final r = asInt(sn['rank'], 1);
      // If snatched cards are high rank (>= 10) and our hand isn't empty, take them;
      // if our hand is empty or small (going out!) or snatched cards are low, return them to victim!
      if (hands[seat].isEmpty || hands[seat].length <= 3 || r < 9) {
        return {'type': 'snatch_choice', 'choice': 'return'};
      }
      return {'type': 'snatch_choice', 'choice': 'take'};
    }

    final plays = linkoLegalPlays(hands[seat]);
    if (plays.isEmpty) return null;

    if (botLevel == 0) {
      final p = plays[rng.nextInt(plays.length)];
      return {
        'type': 'play',
        'rank': p['rank'],
        'count': p['count'],
        'jokers': p['jokers'],
      };
    }

    // Score each candidate play: prefer plays that empty hand, snatch opponent sets, or shed multiple cards
    Map<String, int> bestPlay = plays.first;
    var bestScore = -999999;

    for (final p in plays) {
      final r = p['rank']!;
      final k = p['count']!;
      final j = p['jokers']!;
      var val = k * 25 + r * 3 - j * 8;
      if (k == hands[seat].length) {
        val += 1000; // Immediately empties hand!
      }
      for (var s = 0; s < players; s++) {
        if (s == seat) continue;
        for (final oppSet in tableau[s]) {
          if (linkoCanSnatch(
            playedRank: r,
            playedCount: k,
            oppRank: asInt(oppSet['rank'], 0),
            oppCount: asInt(oppSet['count'], 0),
          )) {
            val += 45 * k;
          }
        }
      }
      if (val > bestScore) {
        bestScore = val;
        bestPlay = p;
      }
    }

    return {
      'type': 'play',
      'rank': bestPlay['rank'],
      'count': bestPlay['count'],
      'jokers': bestPlay['jokers'],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? List<int>.of(hands[seat])
        : <int>[];
    final myPlays = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? linkoLegalPlays(myHand)
        : const <Map<String, int>>[];

    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'turn': turn,
      'deckCount': deck.length,
      'pool': List<int>.of(pool),
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'tableauCounts': [for (var s = 0; s < players; s++) tableauCardCount(s)],
      'tableau': [
        for (var s = 0; s < players; s++)
          [for (final set in tableau[s]) Map<String, dynamic>.of(set)],
      ],
      'hand': myHand,
      'legalPlays': myPlays,
      'pendingSnatches': [
        for (final sn in pendingSnatches) Map<String, dynamic>.of(sn),
      ],
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
