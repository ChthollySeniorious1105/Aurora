import '../../src/engine.dart';

const List<String> schafkopfSuits = ['C', 'S', 'H', 'D'];
const List<String> schafkopfRanks = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
const List<String> schafkopfContracts = [
  'ruf',
  'wenz',
  'solo_C',
  'solo_S',
  'solo_H',
  'solo_D',
];

const Map<String, String> schafkopfContractNames = {
  'ruf': 'Rufspiel 呼唤A搭档 (红心主)',
  'wenz': 'Wenz 温茨独庄 (仅4张J主)',
  'solo_C': 'Solo ♣ 梅花独庄',
  'solo_S': 'Solo ♠ 黑桃独庄',
  'solo_H': 'Solo ♥ 红心独庄',
  'solo_D': 'Solo ♦ 方块独庄',
};

const Map<String, String> schafkopfSuitNames = {
  'C': '♣ 梅花(橡子)',
  'S': '♠ 黑桃(树叶)',
  'H': '♥ 红心',
  'D': '♦ 方块(铃铛)',
};

String schafkopfCardRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String schafkopfCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

List<String> buildSchafkopfDeck() => [
      for (final s in schafkopfSuits)
        for (final r in schafkopfRanks) '$r$s',
    ];

/// Card point values in Schafkopf (total 120 across 32 cards).
int schafkopfCardPoints(String card) {
  return switch (schafkopfCardRank(card)) {
    'A' => 11,
    'T' => 10,
    'K' => 4,
    'Q' => 3, // Ober
    'J' => 2, // Unter
    _ => 0,
  };
}

/// Base trump suit for [contract] ('H' for 'ruf', 'C'/'S'/'H'/'D' for 'solo_*', null for 'wenz').
String? schafkopfTrumpSuit(String contract) {
  if (contract == 'ruf') return 'H';
  if (contract.startsWith('solo_') && contract.length == 6) {
    return contract.substring(5);
  }
  return null;
}

/// Whether [card] is a trump card under [contract].
/// - In 'wenz': only the 4 Unters (JC, JS, JH, JD) are trumps (4 trumps).
/// - In 'ruf' and 'solo_*': all 4 Obers (QC, QS, QH, QD), all 4 Unters (JC, JS, JH, JD),
///   plus the 6 remaining cards of the trump suit are trumps (14 trumps).
bool isSchafkopfTrump(String card, String contract) {
  final r = schafkopfCardRank(card);
  final s = schafkopfCardSuit(card);
  if (contract == 'wenz') {
    return r == 'J';
  }
  if (r == 'Q' || r == 'J') return true;
  final trumpSuit = schafkopfTrumpSuit(contract);
  return trumpSuit != null && s == trumpSuit;
}

/// Effective suit of [card] for trick-following: 'TRUMP' if trump, else printed suit ('C','S','H','D').
String schafkopfEffectiveSuit(String card, String contract) =>
    isSchafkopfTrump(card, contract) ? 'TRUMP' : schafkopfCardSuit(card);

int _suitOrderIndex(String suit) => switch (suit) {
      'C' => 4,
      'S' => 3,
      'H' => 2,
      'D' => 1,
      _ => 0,
    };

int _nonTrumpRankOrder(String rank) => switch (rank) {
      'A' => 8,
      'T' => 7,
      'K' => 6,
      'Q' => 5, // Only non-trump in Wenz
      'J' => 4,
      '9' => 3,
      '8' => 2,
      '7' => 1,
      _ => 0,
    };

/// Relative strength among trump cards (higher is stronger).
int schafkopfTrumpOrder(String card, String contract) {
  final r = schafkopfCardRank(card);
  final s = schafkopfCardSuit(card);
  if (r == 'Q' && contract != 'wenz') {
    return 30 + _suitOrderIndex(s); // QC(34) > QS(33) > QH(32) > QD(31)
  }
  if (r == 'J') {
    return 20 + _suitOrderIndex(s); // JC(24) > JS(23) > JH(22) > JD(21)
  }
  return _nonTrumpRankOrder(r); // A(8) > T(7) > K(6) > 9(3) > 8(2) > 7(1)
}

/// Trick-taking strength of [card] given [contract] and [leadEffectiveSuit].
int schafkopfCardStrength(String card, String contract, String leadEffectiveSuit) {
  if (isSchafkopfTrump(card, contract)) {
    return 100 + schafkopfTrumpOrder(card, contract);
  }
  if (schafkopfCardSuit(card) == leadEffectiveSuit) {
    return 10 + _nonTrumpRankOrder(schafkopfCardRank(card));
  }
  return 0;
}

/// Returns the winning seat of a trick under [contract].
int schafkopfTrickWinner(List<Map<String, dynamic>> trick, String contract) {
  if (trick.isEmpty) return 0;
  final firstCard = asStr(trick.first['card']);
  final leadEff = schafkopfEffectiveSuit(firstCard, contract);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = schafkopfCardStrength(firstCard, contract, leadEff);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = schafkopfCardStrength(c, contract, leadEff);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

class SchafkopfGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int forehand = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'contract'; // 'contract' | 'play'
  String? contract; // 'ruf' | 'wenz' | 'solo_C' | 'solo_S' | 'solo_H' | 'solo_D'
  String? calledAce; // 'AC' | 'AS' | 'AD' when contract == 'ruf'
  int declarer = 0;
  int? partner;
  bool calledAceRevealed = false;
  int passCount = 0;

  late List<List<String>> hands;
  late List<int> scores;
  late List<int> handPoints;
  late List<int> tricksWon;
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  SchafkopfGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 4);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    handPoints = List.filled(players, 0);
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
    final winners = [for (var i = 0; i < players; i++) if (i != seat) i];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildSchafkopfDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 8, (s + 1) * 8);
      _sortHand(hands[s]);
      handPoints[s] = 0;
      tricksWon[s] = 0;
    }
    phase = 'contract';
    contract = null;
    calledAce = null;
    declarer = forehand;
    partner = null;
    calledAceRevealed = false;
    passCount = 0;
    leader = forehand;
    turn = forehand;
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始，由 ${name(forehand)} 先叫牌');
  }

  void _sortHand(List<String> hand) {
    final c = contract ?? 'ruf';
    hand.sort((a, b) {
      final ta = isSchafkopfTrump(a, c);
      final tb = isSchafkopfTrump(b, c);
      if (ta != tb) return ta ? -1 : 1;
      if (ta && tb) {
        return schafkopfTrumpOrder(b, c).compareTo(schafkopfTrumpOrder(a, c));
      }
      final sa = schafkopfSuits.indexOf(schafkopfCardSuit(a));
      final sb = schafkopfSuits.indexOf(schafkopfCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      return _nonTrumpRankOrder(schafkopfCardRank(b))
          .compareTo(_nonTrumpRankOrder(schafkopfCardRank(a)));
    });
  }

  /// Non-Heart Aces ('AC', 'AS', 'AD') that [seat] does NOT hold in hand.
  List<String> callableAces(int seat) {
    final h = hands[seat];
    final missing = <String>[
      for (final s in const ['C', 'S', 'D'])
        if (!h.contains('A$s')) 'A$s',
    ];
    // Prefer suits where player holds at least one non-trump card of that suit
    final withSideCard = missing.where((ace) {
      final suit = schafkopfCardSuit(ace);
      return h.any((c) => !isSchafkopfTrump(c, 'ruf') && schafkopfCardSuit(c) == suit);
    }).toList();
    return withSideCard.isNotEmpty ? withSideCard : missing;
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);
    final c = contract ?? 'ruf';
    final leadEff = schafkopfEffectiveSuit(asStr(trick.first['card']), c);
    final matching = hand.where((card) => schafkopfEffectiveSuit(card, c) == leadEff).toList();
    return matching.isNotEmpty ? matching : List<String>.of(hand);
  }

  void _beginPlay(int decl, String chosenContract, {String? ace}) {
    declarer = decl;
    contract = chosenContract;
    calledAce = ace;
    partner = null;
    calledAceRevealed = false;
    if (chosenContract == 'ruf' && ace != null) {
      for (var s = 0; s < players; s++) {
        if (s != decl && hands[s].contains(ace)) {
          partner = s;
          break;
        }
      }
    }
    phase = 'play';
    leader = forehand;
    turn = forehand;
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'contract') {
      if (type == 'pass') {
        passCount += 1;
        if (passCount >= players) {
          // All 4 passed: forehand plays default Rufspiel (or Heart Solo if holding all 3 Aces)
          final aces = callableAces(forehand);
          if (aces.isNotEmpty) {
            _beginPlay(forehand, 'ruf', ace: aces.first);
            host.log('四家均不叫，由先手 ${name(forehand)} 开启呼唤局 (${aces.first})');
          } else {
            _beginPlay(forehand, 'solo_H');
            host.log('四家均不叫，由先手 ${name(forehand)} 开启红心独庄');
          }
          return;
        }
        turn = (turn + 1) % players;
        host.log('${name(seat)} 选择不叫 (Pass)');
        return;
      }

      String chosen = type == 'contract' ? asStr(action['contract']) : type;
      if (chosen == 'solo') {
        final suit = asStr(action['suit'], 'H').toUpperCase();
        chosen = 'solo_$suit';
      }

      if (chosen == 'ruf') {
        var ace = asStr(action['ace']).toUpperCase();
        if (ace.length == 1 && const ['C', 'S', 'D'].contains(ace)) {
          ace = 'A$ace';
        }
        if (ace.isEmpty) {
          final avail = callableAces(seat);
          if (avail.isNotEmpty) ace = avail.first;
        }
        if (!const ['AC', 'AS', 'AD'].contains(ace)) {
          throw GameError('呼唤A必须选择非红心A (AC / AS / AD)');
        }
        if (hands[seat].contains(ace)) {
          throw GameError('不能呼唤自己手中已持有的 $ace');
        }
        _beginPlay(seat, 'ruf', ace: ace);
        host.log('${name(seat)} 宣告 Rufspiel，呼唤搭档牌：$ace');
        return;
      }

      if (chosen == 'wenz') {
        _beginPlay(seat, 'wenz');
        host.log('${name(seat)} 宣告 Wenz（温茨独庄 1v3）');
        return;
      }

      if (const ['solo_C', 'solo_S', 'solo_H', 'solo_D'].contains(chosen)) {
        _beginPlay(seat, chosen);
        host.log('${name(seat)} 宣告 ${schafkopfContractNames[chosen]}（1v3）');
        return;
      }

      throw GameError('无效的叫牌操作：$chosen');
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请出牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有该张牌');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟出领出花色或主牌');
      }

      hands[seat].remove(card);
      if (contract == 'ruf' && card == calledAce) {
        calledAceRevealed = true;
      }
      trick.add({'seat': seat, 'card': card});

      if (trick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知阶段');
  }

  void _resolveTrick() {
    final c = contract ?? 'ruf';
    final winner = schafkopfTrickWinner(trick, c);
    var pts = 0;
    for (final entry in trick) {
      pts += schafkopfCardPoints(asStr(entry['card']));
    }
    handPoints[winner] += pts;
    tricksWon[winner] += 1;

    lastTrick = {
      'winner': winner,
      'points': pts,
      'cards': [for (final e in trick) Map<String, dynamic>.of(e)],
    };

    trick = [];
    leader = winner;
    turn = winner;
    trickNumber += 1;

    if (hands.every((h) => h.isEmpty)) {
      resolveRound();
    }
  }

  List<int> get declarerTeam => [
        declarer,
        if (contract == 'ruf' && partner != null && partner != declarer) partner!,
      ];

  void resolveRound() {
    final team = declarerTeam.toSet();
    var declPts = 0;
    var declTricks = 0;
    for (final s in team) {
      declPts += handPoints[s];
      declTricks += tricksWon[s];
    }
    final defPts = 120 - declPts;
    final defTricks = 8 - declTricks;
    final declarerWon = declPts >= 61;

    final schneider = declarerWon ? (declPts >= 91) : (declPts <= 30);
    final schwarz = declarerWon
        ? (declPts == 120 || defTricks == 0)
        : (declPts == 0 || declTricks == 0);

    final baseTariff = (contract == 'ruf') ? 10 : 20;
    final tariff = baseTariff + (schneider ? 10 : 0) + (schwarz ? 10 : 0);

    final roundDelta = List<int>.filled(players, 0);
    if (team.length == 2) {
      // 2v2 Rufspiel
      for (var s = 0; s < players; s++) {
        final isDeclSide = team.contains(s);
        roundDelta[s] = (isDeclSide == declarerWon) ? tariff : -tariff;
      }
    } else {
      // 1v3 Solo / Wenz
      for (var s = 0; s < players; s++) {
        if (s == declarer) {
          roundDelta[s] = declarerWon ? 3 * tariff : -3 * tariff;
        } else {
          roundDelta[s] = declarerWon ? -tariff : tariff;
        }
      }
    }

    for (var s = 0; s < players; s++) {
      scores[s] += roundDelta[s];
    }
    calledAceRevealed = true;

    lastHandSummary = {
      'round': round,
      'contract': contract,
      'calledAce': calledAce,
      'declarer': declarer,
      'partner': partner,
      'declarerPoints': declPts,
      'defenderPoints': defPts,
      'declarerWon': declarerWon,
      'schneider': schneider,
      'schwarz': schwarz,
      'tariff': tariff,
      'roundDelta': roundDelta,
    };

    final tag = schwarz
        ? ' (Schwarz 全胜!)'
        : (schneider ? ' (Schneider 91+!)' : '');
    host.log('第 $round 局结算：庄家方 $declPts 分 vs 防守方 $defPts 分 — '
        '${declarerWon ? "庄家方获胜" : "防守方获胜"}$tag');

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    } else {
      round += 1;
      forehand = (forehand + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final hand = hands[seat];

    if (phase == 'contract') {
      final jCount = hand.where((c) => schafkopfCardRank(c) == 'J').length;
      if (jCount >= 3) {
        return {'type': 'wenz'};
      }
      for (final s in schafkopfSuits) {
        final trumps = hand.where((c) => isSchafkopfTrump(c, 'solo_$s')).length;
        if (trumps >= 6) {
          return {'type': 'solo', 'suit': s};
        }
      }
      final heartTrumps = hand.where((c) => isSchafkopfTrump(c, 'ruf')).length;
      final aces = callableAces(seat);
      if (heartTrumps >= 4 && aces.isNotEmpty) {
        return {'type': 'ruf', 'ace': aces.first};
      }
      return {'type': 'pass'};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      final c = contract ?? 'ruf';
      if (trick.isEmpty) {
        legal.sort((a, b) =>
            schafkopfCardStrength(b, c, schafkopfEffectiveSuit(b, c))
                .compareTo(schafkopfCardStrength(a, c, schafkopfEffectiveSuit(a, c))));
        return {'type': 'play', 'card': legal.first};
      }
      final leadEff = schafkopfEffectiveSuit(asStr(trick.first['card']), c);
      final curWinner = schafkopfTrickWinner(trick, c);
      final curBestStr = schafkopfCardStrength(
        asStr(trick.firstWhere((e) => e['seat'] == curWinner)['card']),
        c,
        leadEff,
      );
      final winning = legal
          .where((card) => schafkopfCardStrength(card, c, leadEff) > curBestStr)
          .toList();
      if (winning.isNotEmpty) {
        winning.sort((a, b) => schafkopfCardStrength(a, c, leadEff)
            .compareTo(schafkopfCardStrength(b, c, leadEff)));
        return {'type': 'play', 'card': winning.first};
      }
      legal.sort((a, b) => schafkopfCardPoints(a).compareTo(schafkopfCardPoints(b)));
      return {'type': 'play', 'card': legal.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    final myCallableAces = (seat >= 0 && seat < players)
        ? [
            for (final s in const ['C', 'S', 'D'])
              if (!hands[seat].contains('A$s')) 'A$s',
          ]
        : <String>[];
    final partnerVisible = calledAceRevealed || seat == partner;
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'forehand': forehand,
      'leader': leader,
      'turn': turn,
      'contract': contract,
      'contractName': contract != null ? schafkopfContractNames[contract!] : null,
      'calledAce': calledAce,
      'declarer': declarer,
      'partner': partnerVisible ? partner : null,
      'calledAceRevealed': calledAceRevealed,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'handPoints': List<int>.of(handPoints),
      'tricksWon': List<int>.of(tricksWon),
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'callableAces': myCallableAces,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
