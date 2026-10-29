import '../../src/engine.dart';

const List<String> doppelkopfSuits = ['C', 'S', 'H', 'D'];
const List<String> doppelkopfRanks = ['T', 'J', 'Q', 'K', 'A'];
const List<String> doppelkopfContracts = [
  'normal',
  'solo_D',
  'solo_H',
  'solo_S',
  'solo_C',
  'solo_queens',
];

const Map<String, String> doppelkopfContractNames = {
  'normal': 'Normalspiel 标准局 (♦主 · 秘密♣Q搭档)',
  'solo_D': 'Diamant-Solo ♦ 方块独庄 (1v3)',
  'solo_H': 'Herz-Solo ♥ 红心独庄 (1v3)',
  'solo_S': 'Pik-Solo ♠ 黑桃独庄 (1v3)',
  'solo_C': 'Kreuz-Solo ♣ 梅花独庄 (1v3)',
  'solo_queens': 'Damensolo 👑 皇后独庄 (仅Q为主 · 1v3)',
};

const Map<String, String> doppelkopfSuitNames = {
  'C': '♣ 梅花',
  'S': '♠ 黑桃',
  'H': '♥ 红心',
  'D': '♦ 方块',
};

/// Strips the `_0` / `_1` copy suffix from a Doppelkopf card code (e.g. `'TC_0'` -> `'TC'`).
String doppelkopfBaseCard(String card) {
  final idx = card.indexOf('_');
  return idx >= 0 ? card.substring(0, idx) : card;
}

String doppelkopfCardRank(String card) {
  final base = doppelkopfBaseCard(card);
  return base.length >= 2 ? base.substring(0, base.length - 1) : '';
}

String doppelkopfCardSuit(String card) {
  final base = doppelkopfBaseCard(card);
  return base.length >= 2 ? base[base.length - 1] : '';
}

/// Builds the 40-card Doppelkopf deck (`2` copies each of `T, J, Q, K, A` in `C, S, H, D`).
List<String> buildDoppelkopfDeck() => [
      for (final copy in const [0, 1])
        for (final s in doppelkopfSuits)
          for (final r in doppelkopfRanks) '${r}${s}_$copy',
    ];

/// Card points in Doppelkopf (`A=11, T=10, K=4, Q=3, J=2`, total `240` across 40 cards).
int doppelkopfCardPoints(String card) {
  return switch (doppelkopfCardRank(card)) {
    'A' => 11,
    'T' => 10,
    'K' => 4,
    'Q' => 3,
    'J' => 2,
    _ => 0,
  };
}

/// Base trump suit for [contract] ('D' for 'normal'/'solo_D', 'H'/'S'/'C' for suit solos, null for 'solo_queens').
String? doppelkopfTrumpSuit(String contract) {
  return switch (contract) {
    'normal' || 'solo_D' => 'D',
    'solo_H' => 'H',
    'solo_S' => 'S',
    'solo_C' => 'C',
    _ => null,
  };
}

/// Whether [card] is a trump card under [contract].
/// - In `'solo_queens'`: ONLY Queens (`QC, QS, QH, QD`) are trumps (8 cards).
/// - In `'normal'` and `'solo_D'|'solo_H'|'solo_S'|'solo_C'`:
///   - `TH` (Dullen ♥10)
///   - All Queens (`QC, QS, QH, QD`)
///   - All Jacks (`JC, JS, JH, JD`)
///   - Remaining cards (`A, T, K`) of the base trump suit.
bool isDoppelkopfTrump(String card, [String contract = 'normal']) {
  final base = doppelkopfBaseCard(card);
  final r = doppelkopfCardRank(base);
  final s = doppelkopfCardSuit(base);
  if (contract == 'solo_queens') {
    return r == 'Q';
  }
  if (base == 'TH') return true; // Dullen (♥10)
  if (r == 'Q' || r == 'J') return true;
  final ts = doppelkopfTrumpSuit(contract);
  return ts != null && s == ts;
}

/// Effective suit of [card] for trick-following: `'TRUMP'` if trump, else `'C' | 'S' | 'H' | 'D'`.
String doppelkopfEffectiveSuit(String card, [String contract = 'normal']) =>
    isDoppelkopfTrump(card, contract) ? 'TRUMP' : doppelkopfCardSuit(card);

int _suitOrderIndex(String suit) => switch (suit) {
      'C' => 4,
      'S' => 3,
      'H' => 2,
      'D' => 1,
      _ => 0,
    };

int _nonTrumpRankOrder(String rank) => switch (rank) {
      'A' => 5,
      'T' => 4,
      'K' => 3,
      'Q' => 2,
      'J' => 1,
      _ => 0,
    };

/// Relative strength among trump cards (higher is stronger):
/// `TH (40) > QC(34) > QS(33) > QH(32) > QD(31) > JC(24) > JS(23) > JH(22) > JD(21) > A(5) > T(4) > K(3)`.
int doppelkopfTrumpOrder(String card, [String contract = 'normal']) {
  final base = doppelkopfBaseCard(card);
  final r = doppelkopfCardRank(base);
  final s = doppelkopfCardSuit(base);
  if (contract == 'solo_queens') {
    return r == 'Q' ? 30 + _suitOrderIndex(s) : 0;
  }
  if (base == 'TH') return 40; // Dullen (♥10) is the highest trump!
  if (r == 'Q') return 30 + _suitOrderIndex(s);
  if (r == 'J') return 20 + _suitOrderIndex(s);
  return _nonTrumpRankOrder(r); // A(5) > T(4) > K(3) of trump suit
}

/// Trick-taking strength of [card] given [contract] and [leadEffectiveSuit].
int doppelkopfCardStrength(
  String card,
  String contract,
  String leadEffectiveSuit,
) {
  if (isDoppelkopfTrump(card, contract)) {
    return 100 + doppelkopfTrumpOrder(card, contract);
  }
  if (doppelkopfCardSuit(card) == leadEffectiveSuit) {
    return 10 + _nonTrumpRankOrder(doppelkopfCardRank(card));
  }
  return 0;
}

/// Determines the winning seat of [trick] under [contract].
/// Uses strict `>` so the second-played identical card loses to the first-played identical card!
int doppelkopfTrickWinner(
  List<Map<String, dynamic>> trick, [
  String contract = 'normal',
]) {
  if (trick.isEmpty) return 0;
  final firstCard = asStr(trick.first['card']);
  final leadEff = doppelkopfEffectiveSuit(firstCard, contract);
  var bestSeat = asInt(trick.first['seat'], 0);
  var bestStr = doppelkopfCardStrength(firstCard, contract, leadEff);
  for (var i = 1; i < trick.length; i++) {
    final c = asStr(trick[i]['card']);
    final str = doppelkopfCardStrength(c, contract, leadEff);
    if (str > bestStr) {
      bestStr = str;
      bestSeat = asInt(trick[i]['seat'], 0);
    }
  }
  return bestSeat;
}

class DoppelkopfGame extends GameEngine {
  late int totalRounds;
  int round = 1;
  int forehand = 0;
  int leader = 0;
  int turn = 0;
  String phase = 'contract'; // 'contract' | 'play'
  String contract = 'normal'; // 'normal' | 'solo_D' | 'solo_H' | 'solo_S' | 'solo_C' | 'solo_queens'
  int? soloDeclarer;
  int passCount = 0;

  late List<List<String>> hands;
  late List<int> scores;
  late List<int> handPoints;
  late List<int> tricksWon;
  late List<bool> isReTeam;
  late List<bool> teamRevealed;
  bool reCalled = false;
  bool kontraCalled = false;
  int fuchsCaughtRe = 0;
  int fuchsCaughtKontra = 0;
  bool karlchenRe = false;
  bool karlchenKontra = false;

  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;
  int trickNumber = 1;

  bool _over = false;
  List<int>? _placings;

  DoppelkopfGame(super.setup) {
    totalRounds = setup.opt<int>('rounds', 4);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    handPoints = List.filled(players, 0);
    tricksWon = List.filled(players, 0);
    isReTeam = List.filled(players, false);
    teamRevealed = List.filled(players, false);
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
    final deck = shuffled(buildDoppelkopfDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(s * 10, (s + 1) * 10);
      handPoints[s] = 0;
      tricksWon[s] = 0;
      isReTeam[s] = hands[s].any((c) => doppelkopfBaseCard(c) == 'QC');
      teamRevealed[s] = false;
      _sortHand(hands[s]);
    }
    phase = 'contract';
    contract = 'normal';
    soloDeclarer = null;
    passCount = 0;
    reCalled = false;
    kontraCalled = false;
    fuchsCaughtRe = 0;
    fuchsCaughtKontra = 0;
    karlchenRe = false;
    karlchenKontra = false;
    leader = forehand;
    turn = forehand;
    trick = [];
    trickNumber = 1;
    host.log('第 $round/$totalRounds 局开始，由 ${name(forehand)} 先叫牌 (Vorbehalt)');
  }

  void _sortHand(List<String> hand) {
    final c = contract;
    hand.sort((a, b) {
      final ta = isDoppelkopfTrump(a, c);
      final tb = isDoppelkopfTrump(b, c);
      if (ta != tb) return ta ? -1 : 1;
      if (ta && tb) {
        final cmp = doppelkopfTrumpOrder(b, c).compareTo(doppelkopfTrumpOrder(a, c));
        if (cmp != 0) return cmp;
        return a.compareTo(b);
      }
      final sa = doppelkopfSuits.indexOf(doppelkopfCardSuit(a));
      final sb = doppelkopfSuits.indexOf(doppelkopfCardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      final ra = _nonTrumpRankOrder(doppelkopfCardRank(a));
      final rb = _nonTrumpRankOrder(doppelkopfCardRank(b));
      if (ra != rb) return rb.compareTo(ra);
      return a.compareTo(b);
    });
  }

  void _beginPlay(String chosenContract, {int? declarer}) {
    contract = chosenContract;
    soloDeclarer = declarer;
    if (chosenContract == 'normal') {
      for (var s = 0; s < players; s++) {
        isReTeam[s] = hands[s].any((c) => doppelkopfBaseCard(c) == 'QC');
        teamRevealed[s] = false;
      }
    } else {
      for (var s = 0; s < players; s++) {
        isReTeam[s] = (s == declarer);
        teamRevealed[s] = true;
      }
    }
    phase = 'play';
    leader = forehand;
    turn = forehand;
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
  }

  List<String> legalCards(int seat) {
    final hand = hands[seat];
    if (trick.isEmpty) return List<String>.of(hand);
    final leadEff = doppelkopfEffectiveSuit(asStr(trick.first['card']), contract);
    final matching =
        hand.where((card) => doppelkopfEffectiveSuit(card, contract) == leadEff).toList();
    return matching.isNotEmpty ? matching : List<String>.of(hand);
  }

  bool canCallRe(int seat) =>
      phase == 'play' &&
      !reCalled &&
      isReTeam[seat] &&
      hands[seat].length >= 9;

  bool canCallKontra(int seat) =>
      phase == 'play' &&
      !kontraCalled &&
      !isReTeam[seat] &&
      hands[seat].length >= 9;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'play' && (type == 'call_re' || type == 'call_kontra')) {
      if (type == 'call_re') {
        if (!canCallRe(seat)) {
          throw GameError('当前无法宣告 Re（仅庄家方 Re 可在前两墩宣告一次）');
        }
        reCalled = true;
        teamRevealed[seat] = true;
        host.log('${name(seat)} 高喊「Re!」(庄家方翻倍宣告)');
        return;
      } else {
        if (!canCallKontra(seat)) {
          throw GameError('当前无法宣告 Kontra（仅闲家方 Kontra 可在前两墩宣告一次）');
        }
        kontraCalled = true;
        teamRevealed[seat] = true;
        host.log('${name(seat)} 高喊「Kontra!」(闲家方反击翻倍)');
        return;
      }
    }

    if (seat != turn) throw GameError('还没轮到你行动');

    if (phase == 'contract') {
      if (type == 'pass' || type == 'normal' || type == 'gesund') {
        passCount += 1;
        if (passCount >= players) {
          _beginPlay('normal');
          host.log('四家均宣告 Gesund，开启标准局（持有 ♣Q 为秘密 Re 方）');
          return;
        }
        turn = (turn + 1) % players;
        host.log('${name(seat)} 宣告 Gesund (正常局)');
        return;
      }

      String chosen = type == 'contract' ? asStr(action['contract']) : type;
      if (chosen == 'solo') {
        final suit = asStr(action['suit'], 'D');
        chosen = suit == 'queens' ? 'solo_queens' : 'solo_${suit.toUpperCase()}';
      }

      if (const ['solo_D', 'solo_H', 'solo_S', 'solo_C', 'solo_queens'].contains(chosen)) {
        _beginPlay(chosen, declarer: seat);
        host.log('${name(seat)} 宣告 ${doppelkopfContractNames[chosen]}');
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
      if (contract == 'normal' && doppelkopfBaseCard(card) == 'QC') {
        teamRevealed[seat] = true;
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
    final winner = doppelkopfTrickWinner(trick, contract);
    final winnerIsRe = isReTeam[winner];
    var pts = 0;
    var fuchsInTrick = 0;

    for (final entry in trick) {
      final c = asStr(entry['card']);
      final pSeat = asInt(entry['seat']);
      pts += doppelkopfCardPoints(c);

      // Fuchs gefangen: capturing an opponent's AD ('AD_0' or 'AD_1') in normal game
      if (contract == 'normal' &&
          doppelkopfBaseCard(c) == 'AD' &&
          isReTeam[pSeat] != winnerIsRe) {
        fuchsInTrick += 1;
        if (winnerIsRe) {
          fuchsCaughtRe += 1;
        } else {
          fuchsCaughtKontra += 1;
        }
      }
    }

    // Karlchen: JC ('JC_0' or 'JC_1') winning the 10th (last) trick in normal game
    var karlchenWon = false;
    if (trickNumber == 10 && contract == 'normal') {
      final winningEntry = trick.firstWhere((e) => asInt(e['seat']) == winner);
      if (doppelkopfBaseCard(asStr(winningEntry['card'])) == 'JC') {
        karlchenWon = true;
        if (winnerIsRe) {
          karlchenRe = true;
        } else {
          karlchenKontra = true;
        }
      }
    }

    handPoints[winner] += pts;
    tricksWon[winner] += 1;

    lastTrick = {
      'winner': winner,
      'points': pts,
      'fuchsCaught': fuchsInTrick,
      'karlchen': karlchenWon,
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

  void resolveRound() {
    var rePts = 0;
    var reTricks = 0;
    final reSeats = <int>[];
    for (var s = 0; s < players; s++) {
      teamRevealed[s] = true;
      if (isReTeam[s]) {
        rePts += handPoints[s];
        reTricks += tricksWon[s];
        reSeats.add(s);
      }
    }
    final kontraPts = 240 - rePts;
    final kontraTricks = 10 - reTricks;

    // Re needs >= 121 points to win (Kontra wins with >= 120)
    final reWon = rePts >= 121;
    final loserPts = reWon ? kontraPts : rePts;
    final loserTricks = reWon ? kontraTricks : reTricks;

    var baseVal = 1; // Grundwert
    if (!reWon && contract == 'normal') {
      baseVal += 1; // Gegen die Alten (+1)
    }
    if (loserPts < 90) baseVal += 1; // Keine 90 (Schneider)
    if (loserPts < 60) baseVal += 1; // Keine 60
    if (loserPts < 30) baseVal += 1; // Keine 30
    if (loserTricks == 0) baseVal += 1; // Schwarz

    var multiplier = 1;
    if (reCalled) multiplier *= 2;
    if (kontraCalled) multiplier *= 2;

    final mainValue = baseVal * multiplier;
    // Net bonus points in direction of Re: positive favors Re, negative favors Kontra
    final specialNetForRe =
        (fuchsCaughtRe - fuchsCaughtKontra) + (karlchenRe ? 1 : 0) - (karlchenKontra ? 1 : 0);
    final netReScore = (reWon ? mainValue : -mainValue) + specialNetForRe;
    final gameValue = netReScore.abs();

    final roundDelta = List<int>.filled(players, 0);
    if (reSeats.length == 1) {
      // 1v3 (Solo or Silent Wedding with both QCs)
      final soloSeat = reSeats.first;
      for (var s = 0; s < players; s++) {
        roundDelta[s] = (s == soloSeat) ? 3 * netReScore : -netReScore;
      }
    } else {
      // 2v2 Normal Game
      for (var s = 0; s < players; s++) {
        roundDelta[s] = isReTeam[s] ? netReScore : -netReScore;
      }
    }

    for (var s = 0; s < players; s++) {
      scores[s] += roundDelta[s];
    }

    lastHandSummary = {
      'round': round,
      'contract': contract,
      'reSeats': reSeats,
      'rePoints': rePts,
      'kontraPoints': kontraPts,
      'reWon': reWon,
      'reCalled': reCalled,
      'kontraCalled': kontraCalled,
      'fuchsCaughtRe': fuchsCaughtRe,
      'fuchsCaughtKontra': fuchsCaughtKontra,
      'karlchenRe': karlchenRe,
      'karlchenKontra': karlchenKontra,
      'gameValue': gameValue,
      'netReScore': netReScore,
      'roundDelta': roundDelta,
    };

    host.log('第 $round 局结算：Re方 $rePts 分 vs Kontra方 $kontraPts 分 — '
        '${reWon ? "Re方获胜" : "Kontra方获胜"} (局分 ${netReScore >= 0 ? "+" : ""}$netReScore)');

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
      final qCount = hand.where((c) => doppelkopfCardRank(c) == 'Q').length;
      if (qCount >= 6) {
        return {'type': 'solo_queens'};
      }
      for (final s in const ['H', 'S', 'C']) {
        final trumps = hand.where((c) => isDoppelkopfTrump(c, 'solo_$s')).length;
        if (trumps >= 8) {
          return {'type': 'solo_$s'};
        }
      }
      return {'type': 'pass'};
    }

    if (phase == 'play') {
      // Strong Re hand calls Re on first trick
      if (canCallRe(seat) && botLevel >= 1) {
        final highTrumps =
            hand.where((c) => doppelkopfTrumpOrder(c, contract) >= 31).length;
        if (highTrumps >= 4) {
          return {'type': 'call_re'};
        }
      }

      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }

      if (trick.isEmpty) {
        // Lead non-trump Aces first if available, else high trump
        final aces = legal
            .where((c) => !isDoppelkopfTrump(c, contract) && doppelkopfCardRank(c) == 'A')
            .toList();
        if (aces.isNotEmpty) {
          return {'type': 'play', 'card': aces.first};
        }
        return {'type': 'play', 'card': legal.first};
      }

      final leadEff = doppelkopfEffectiveSuit(asStr(trick.first['card']), contract);
      final curWinner = doppelkopfTrickWinner(trick, contract);
      final curBestStr = doppelkopfCardStrength(
        asStr(trick.firstWhere((e) => e['seat'] == curWinner)['card']),
        contract,
        leadEff,
      );
      final winning = legal
          .where((c) => doppelkopfCardStrength(c, contract, leadEff) > curBestStr)
          .toList();
      if (winning.isNotEmpty) {
        winning.sort((a, b) => doppelkopfCardStrength(a, contract, leadEff)
            .compareTo(doppelkopfCardStrength(b, contract, leadEff)));
        return {'type': 'play', 'card': winning.first};
      }
      // Cannot win trick: avoid throwing Fox (AD) if possible, play lowest point card
      final sorted = List<String>.of(legal)
        ..sort((a, b) {
          final fa = doppelkopfBaseCard(a) == 'AD' ? 100 : doppelkopfCardPoints(a);
          final fb = doppelkopfBaseCard(b) == 'AD' ? 100 : doppelkopfCardPoints(b);
          return fa.compareTo(fb);
        });
      return {'type': 'play', 'card': sorted.first};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (seat >= 0 && seat < players && seat == turn && phase == 'play')
        ? legalCards(seat)
        : <String>[];
    final myTeam = (seat >= 0 && seat < players)
        ? (isReTeam[seat] ? 'Re' : 'Kontra')
        : null;
    final visibleTeams = <String?>[
      for (var s = 0; s < players; s++)
        (teamRevealed[s] || s == seat) ? (isReTeam[s] ? 'Re' : 'Kontra') : null,
    ];
    return {
      'round': round,
      'totalRounds': totalRounds,
      'phase': phase,
      'forehand': forehand,
      'leader': leader,
      'turn': turn,
      'contract': contract,
      'contractName': doppelkopfContractNames[contract] ?? contract,
      'soloDeclarer': soloDeclarer,
      'trickNumber': trickNumber,
      'scores': List<int>.of(scores),
      'handPoints': List<int>.of(handPoints),
      'tricksWon': List<int>.of(tricksWon),
      'handCounts': [for (final h in hands) h.length],
      'hand': (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[],
      'legal': myLegal,
      'myTeam': myTeam,
      'visibleTeams': visibleTeams,
      'canCallRe': (seat >= 0 && seat < players) && canCallRe(seat),
      'canCallKontra': (seat >= 0 && seat < players) && canCallKontra(seat),
      'reCalled': reCalled,
      'kontraCalled': kontraCalled,
      'fuchsCaughtRe': fuchsCaughtRe,
      'fuchsCaughtKontra': fuchsCaughtKontra,
      'karlchenRe': karlchenRe,
      'karlchenKontra': karlchenKontra,
      'trick': [for (final e in trick) Map<String, dynamic>.of(e)],
      'lastTrick': lastTrick,
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
