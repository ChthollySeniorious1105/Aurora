import 'dart:math';

import '../../src/engine.dart';

const List<String> claimFactionCodes = ['G', 'K', 'U', 'D', 'M'];

const Map<int, String> claimFactionNames = {
  0: '👹 哥布林 (Goblins)',
  1: '⚔️ 骑士 (Knights)',
  2: '💀 亡灵 (Undead)',
  3: '⛏️ 矮人 (Dwarves)',
  4: '🎭 变形怪 (Doppelgängers)',
};

const Map<int, String> claimFactionPowers = {
  0: '👹 哥布林 (14张: 五张0 + 1~9)：人海战术，但领出时会被任何跟牌的骑士直接斩杀',
  1: '⚔️ 骑士 (0~9)：若先手领出哥布林，后手跟出任意骑士无视点数必胜',
  2: '💀 亡灵 (0~9)：第1阶段打出的亡灵牌不弃置，由该墩赢家立即收入得分堆',
  3: '⛏️ 矮人 (0~9)：第2阶段打出的矮人牌归本墩输家收入得分堆',
  4: '🎭 变形怪 (0~9)：百搭随从，后手跟牌时可跟任意领出阵营并视为该阵营花色',
};

/// Returns faction index `0..4` (`0: Goblins, 1: Knights, 2: Undead, 3: Dwarves, 4: Doppelgängers`).
int claimCardFaction(String card) {
  if (card.isEmpty) return -1;
  return switch (card[0].toUpperCase()) {
    'G' || '0' => 0,
    'K' || '1' => 1,
    'U' || '2' => 2,
    'D' || '3' => 3,
    'M' || '4' => 4,
    _ => -1,
  };
}

/// Returns rank `0..9` of [card].
int claimCardRank(String card) {
  if (card.length < 2) return 0;
  final base = card.split('_').first;
  return int.tryParse(base.substring(1)) ?? 0;
}

String makeClaimCard(int faction, int rank, [int? copy]) {
  final prefix = claimFactionCodes[faction];
  if (copy != null) return '$prefix${rank}_$copy';
  return '$prefix$rank';
}

/// Builds the 52-card Claim deck:
/// - `0` Goblins (14 cards): five `0`s (`G0_0`..`G0_4`) + `G1`..`G9`
/// - `1` Knights (8 cards): `K2`..`K9`
/// - `2` Undead (10 cards): `U0`..`U9`
/// - `3` Dwarves (10 cards): `D0`..`D9`
/// - `4` Doppelgängers (10 cards): `M0`..`M9`
List<String> buildClaimDeck() => [
      for (var copy = 0; copy < 5; copy++) 'G0_$copy',
      for (var r = 1; r <= 9; r++) 'G$r',
      for (var r = 2; r <= 9; r++) 'K$r',
      for (var r = 0; r <= 9; r++) 'U$r',
      for (var r = 0; r <= 9; r++) 'D$r',
      for (var r = 0; r <= 9; r++) 'M$r',
    ];

/// Determines the winning seat of a 2-card [trick] in Claim:
/// 1. Knights Power: If a Goblin (`faction == 0`) was led and a Knight (`faction == 1`) is played as follower,
///    the follower Knight automatically beats the Goblin regardless of rank!
/// 2. Doppelgängers Power: A Doppelgänger (`faction == 4`) played as follower takes on the led faction.
/// 3. If both cards have the same effective faction, higher rank wins (ties are won by the leader).
/// 4. Otherwise, the leader wins.
int claimTrickWinner(List<Map<String, dynamic>> trick) {
  if (trick.isEmpty) return 0;
  if (trick.length == 1) return asInt(trick.first['seat'], 0);

  final s0 = asInt(trick[0]['seat'], 0);
  final s1 = asInt(trick[1]['seat'], 1);
  final c0 = asStr(trick[0]['card']);
  final c1 = asStr(trick[1]['card']);
  final f0 = claimCardFaction(c0);
  final f1 = claimCardFaction(c1);
  final r0 = claimCardRank(c0);
  final r1 = claimCardRank(c1);

  // Knights power: any Knight played as follower slays a led Goblin regardless of rank!
  if (f0 == 0 && f1 == 1) {
    return s1;
  }

  // Doppelgängers power: when played as follower, takes on the led faction
  final eff1 = (f1 == 4) ? f0 : f1;
  if (eff1 == f0) {
    return r1 > r0 ? s1 : s0;
  }
  return s0;
}

/// Evaluates who wins the vote for [faction] (`0` for seat 0, `1` for seat 1, `-1` if neither holds any card).
/// More cards in [faction] wins; ties (with >= 1 card) are broken by the highest rank card in that faction!
int claimEvaluateFactionVote(
  List<String> seat0Cards,
  List<String> seat1Cards,
  int faction,
) {
  final f0 = seat0Cards.where((c) => claimCardFaction(c) == faction).toList();
  final f1 = seat1Cards.where((c) => claimCardFaction(c) == faction).toList();
  if (f0.isEmpty && f1.isEmpty) return -1;
  if (f0.length != f1.length) {
    return f0.length > f1.length ? 0 : 1;
  }
  final max0 = f0.map(claimCardRank).reduce(max);
  final max1 = f1.map(claimCardRank).reduce(max);
  if (max0 != max1) {
    return max0 > max1 ? 0 : 1;
  }
  return 0;
}

class ClaimGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int dealer = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'phase1'; // 'phase1' | 'phase2'
  String? prizeCard;
  List<String> followerDeck = [];

  late List<List<String>> hands;
  late List<List<String>> phase2Hands;
  late List<List<int>> scorePile; // scorePile[seat][faction] = count of scored cards
  late List<List<String>> scoreCards; // scoreCards[seat] = all scored card codes
  late List<int> scores; // Match points (faction votes won across rounds)
  late List<int> factionVotes; // Faction votes won in last/current round [seat0, seat1]
  late List<int> factionWinners; // Winner seat (0, 1, or -1) for each of the 5 factions
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastRoundSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  ClaimGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 1);
    hands = List.generate(players, (_) => <String>[]);
    phase2Hands = List.generate(players, (_) => <String>[]);
    scorePile = List.generate(players, (_) => List<int>.filled(5, 0));
    scoreCards = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    factionVotes = List.filled(players, 0);
    factionWinners = List.filled(5, -1);
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
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildClaimDeck(), rng);
    hands[0] = deck.sublist(0, 13);
    hands[1] = deck.sublist(13, 26);
    followerDeck = deck.sublist(26); // 26 cards
    prizeCard = followerDeck.removeAt(0);

    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
      phase2Hands[s] = [];
      scorePile[s] = List<int>.filled(5, 0);
      scoreCards[s] = [];
      factionVotes[s] = 0;
    }
    factionWinners = List.filled(5, -1);
    phase = 'phase1';
    leader = dealer;
    turn = leader;
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始 — 第1阶段（招募随从），翻开奖励牌：$prizeCard');
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final fa = claimCardFaction(a);
      final fb = claimCardFaction(b);
      if (fa != fb) return fa.compareTo(fb);
      final ra = claimCardRank(a);
      final rb = claimCardRank(b);
      if (ra != rb) return rb.compareTo(ra);
      return a.compareTo(b);
    });
  }

  void addScoreCard(int seat, String card) {
    scoreCards[seat].add(card);
    final f = claimCardFaction(card);
    if (f >= 0 && f < 5) {
      scorePile[seat][f] += 1;
    }
  }

  /// Legal cards for [seat]:
  /// - When leading (`trick.isEmpty`): any card in hand.
  /// - When following (`trick.isNotEmpty`):
  ///   - If holding at least one card of `leadFaction`, must play a card of `leadFaction`
  ///     OR a Doppelgänger (`faction == 4`)!
  ///   - If holding NO cards of `leadFaction`, may play ANY card in hand!
  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);

    final leadCard = asStr(trick.first['card']);
    final leadFaction = claimCardFaction(leadCard);
    final hasLeadFaction = hand.any((c) => claimCardFaction(c) == leadFaction);
    if (!hasLeadFaction) {
      return List<String>.of(hand);
    }

    return hand
        .where((c) {
          final f = claimCardFaction(c);
          return f == leadFaction || f == 4; // Led faction or Doppelgänger wildcard
        })
        .toList();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (type != 'play') throw GameError('请出牌');

    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('手牌中没有该张牌');
    }
    final legal = legalCards(seat);
    if (!legal.contains(card)) {
      throw GameError('必须跟出领出阵营花色（或打出变形怪 🎭）');
    }

    hands[seat].remove(card);
    trick.add({'seat': seat, 'card': card});

    if (trick.length < players) {
      turn = 1 - seat;
      return;
    }

    _resolveTrick();
  }

  void _resolveTrick() {
    final winner = claimTrickWinner(trick);
    final loser = 1 - winner;
    final playedCards = [for (final e in trick) asStr(e['card'])];

    var undeadScored = 0;
    var dwarvesToLoser = 0;
    String? wonPrize;

    if (phase == 'phase1') {
      // Undead (faction 2) played during Phase 1 go directly to the trick winner's Score Pile!
      for (final c in playedCards) {
        if (claimCardFaction(c) == 2) {
          addScoreCard(winner, c);
          undeadScored += 1;
        }
      }
      // Winner takes face-up prizeCard; loser takes top blind card from followerDeck
      if (prizeCard != null) {
        wonPrize = prizeCard;
        phase2Hands[winner].add(prizeCard!);
        _sortHand(phase2Hands[winner]);
      }
      if (followerDeck.isNotEmpty) {
        final blindCard = followerDeck.removeAt(0);
        phase2Hands[loser].add(blindCard);
        _sortHand(phase2Hands[loser]);
      }
    } else {
      // Phase 2: Dwarves (faction 3) go to the trick LOSER's Score Pile; all other cards go to WINNER's Score Pile!
      for (final c in playedCards) {
        if (claimCardFaction(c) == 3) {
          addScoreCard(loser, c);
          dwarvesToLoser += 1;
        } else {
          addScoreCard(winner, c);
        }
      }
    }

    lastTrick = {
      'phase': phase,
      'winner': winner,
      'loser': loser,
      'prizeCard': wonPrize,
      'undeadScored': undeadScored,
      'dwarvesToLoser': dwarvesToLoser,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;

    if (phase == 'phase1') {
      if (hands[0].isNotEmpty && hands[1].isNotEmpty) {
        trickNumber += 1;
        prizeCard = followerDeck.isNotEmpty ? followerDeck.removeAt(0) : null;
      } else {
        // Transition to Phase 2!
        phase = 'phase2';
        prizeCard = null;
        trickNumber = 1;
        for (var s = 0; s < players; s++) {
          hands[s] = List<String>.of(phase2Hands[s]);
          _sortHand(hands[s]);
          phase2Hands[s].clear();
        }
        host.log('第1阶段结束！进入第2阶段（争夺王座），双方使用招募到的 13 张随从手牌对决！');
      }
      return;
    }

    // Phase 2
    if (hands[0].isNotEmpty && hands[1].isNotEmpty) {
      trickNumber += 1;
      return;
    }

    resolveRound();
  }

  void resolveRound() {
    factionVotes = [0, 0];
    factionWinners = List.filled(5, -1);

    for (var f = 0; f < 5; f++) {
      final f0Cards = scoreCards[0].where((c) => claimCardFaction(c) == f).toList();
      final f1Cards = scoreCards[1].where((c) => claimCardFaction(c) == f).toList();
      final c0 = f0Cards.isNotEmpty ? f0Cards.length : scorePile[0][f];
      final c1 = f1Cards.isNotEmpty ? f1Cards.length : scorePile[1][f];
      scorePile[0][f] = c0;
      scorePile[1][f] = c1;

      int w = -1;
      if (c0 > c1) {
        w = 0;
      } else if (c1 > c0) {
        w = 1;
      } else if (c0 > 0) {
        w = claimEvaluateFactionVote(f0Cards, f1Cards, f);
      }
      factionWinners[f] = w;
      if (w == 0 || w == 1) {
        factionVotes[w] += 1;
      }
    }

    scores[0] += factionVotes[0];
    scores[1] += factionVotes[1];

    lastRoundSummary = {
      'round': round,
      'scorePile': [for (final p in scorePile) List<int>.of(p)],
      'factionWinners': List<int>.of(factionWinners),
      'factionVotes': List<int>.of(factionVotes),
      'roundWinner': factionVotes[0] > factionVotes[1]
          ? 0
          : (factionVotes[1] > factionVotes[0] ? 1 : -1),
    };

    host.log('第 $round 局结算：${name(0)} 赢得 ${factionVotes[0]} 个阵营支持 vs '
        '${name(1)} 赢得 ${factionVotes[1]} 个阵营支持');

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      dealer = 1 - dealer;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final legal = legalCards(seat);
    if (legal.isEmpty) return null;
    if (botLevel == 0) {
      return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
    }

    if (phase == 'phase1') {
      final wantPrize = prizeCard != null &&
          (claimCardRank(prizeCard!) >= 6 || claimCardFaction(prizeCard!) == 4);
      if (trick.isEmpty) {
        final sorted = List<String>.of(legal)
          ..sort((a, b) => claimCardRank(a).compareTo(claimCardRank(b)));
        return {'type': 'play', 'card': wantPrize ? sorted.last : sorted.first};
      } else {
        final leadCard = asStr(trick.first['card']);
        final winning = legal.where((c) {
          final sim = [
            {'seat': 1 - seat, 'card': leadCard},
            {'seat': seat, 'card': c},
          ];
          return claimTrickWinner(sim) == seat;
        }).toList();
        if (wantPrize && winning.isNotEmpty) {
          winning.sort((a, b) => claimCardRank(a).compareTo(claimCardRank(b)));
          return {'type': 'play', 'card': winning.first};
        }
        // Dump low non-Doppelgänger card
        final losing = List<String>.of(legal)
          ..sort((a, b) => claimCardRank(a).compareTo(claimCardRank(b)));
        return {'type': 'play', 'card': losing.first};
      }
    }

    // Phase 2 strategy: avoid winning Dwarves (3), try to win other factions
    if (trick.isEmpty) {
      final nonDwarves = legal.where((c) => claimCardFaction(c) != 3).toList();
      if (nonDwarves.isNotEmpty) {
        nonDwarves.sort((a, b) => claimCardRank(b).compareTo(claimCardRank(a)));
        return {'type': 'play', 'card': nonDwarves.first};
      }
      return {'type': 'play', 'card': legal.first};
    } else {
      final leadCard = asStr(trick.first['card']);
      final leadIsDwarf = claimCardFaction(leadCard) == 3;
      final winning = legal.where((c) {
        final sim = [
          {'seat': 1 - seat, 'card': leadCard},
          {'seat': seat, 'card': c},
        ];
        return claimTrickWinner(sim) == seat;
      }).toList();
      final losing = legal.where((c) => !winning.contains(c)).toList();

      if (leadIsDwarf && losing.isNotEmpty) {
        // Lose the trick on purpose so Dwarves go to our own Score Pile!
        losing.sort((a, b) => claimCardRank(b).compareTo(claimCardRank(a)));
        return {'type': 'play', 'card': losing.first};
      }
      if (winning.isNotEmpty) {
        winning.sort((a, b) => claimCardRank(a).compareTo(claimCardRank(b)));
        return {'type': 'play', 'card': winning.first};
      }
      final low = List<String>.of(legal)
        ..sort((a, b) => claimCardRank(a).compareTo(claimCardRank(b)));
      return {'type': 'play', 'card': low.first};
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn)
        ? legalCards(seat)
        : <String>[];
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'dealer': dealer,
      'leader': leader,
      'turn': turn,
      'prizeCard': prizeCard,
      'followerDeckCount': followerDeck.length,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'scorePile': [for (final p in scorePile) List<int>.of(p)],
      'factionVotes': List<int>.of(factionVotes),
      'factionWinners': List<int>.of(factionWinners),
      'handCounts': [for (final h in hands) h.length],
      'phase2HandCounts': [for (final h in phase2Hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'phase2Hand': (seat >= 0 && seat < players)
          ? List<String>.of(phase2Hands[seat])
          : <String>[],
      'legal': myLegal,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
