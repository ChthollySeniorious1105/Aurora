import '../../src/engine.dart';

/// Spanish suits in Mus:
/// - `'O'`: Oros (金币 ♦)
/// - `'C'`: Copas (圣杯 ♥)
/// - `'E'`: Espadas (宝剑 ♠)
/// - `'B'`: Bastos (权杖 ♣)
const List<String> musSuits = ['O', 'C', 'E', 'B'];

/// Raw ranks in the 40-card Spanish deck:
/// `A (1), 2, 3, 4, 5, 6, 7, J (10 Sota), Q (11 Caballo), K (12 Rey)`.
const List<String> musRawRanks = ['A', '2', '3', '4', '5', '6', '7', 'J', 'Q', 'K'];

/// Effective rank order in traditional 8-King Mus (`Mus a 8 reyes`),
/// where `3` counts as `K` and `2` counts as `A`:
/// `A/2 (1) < 4 (2) < 5 (3) < 6 (4) < 7 (5) < J (6) < Q (7) < K/3 (8)`.
const List<String> musEffectiveRanks = ['A', '4', '5', '6', '7', 'J', 'Q', 'K'];

const List<String> musStageNames = [
  'Grande (比大)',
  'Chica (比小)',
  'Pares (比对子)',
  'Juego / Punto (比31点)',
];

const Map<String, String> musSuitNames = {
  'O': '♦ 金币 (Oros)',
  'C': '♥ 圣杯 (Copas)',
  'E': '♠ 宝剑 (Espadas)',
  'B': '♣ 权杖 (Bastos)',
};

/// Builds the 40-card Spanish deck for Mus.
List<String> buildMusDeck() => [
      for (final s in musSuits)
        for (final r in musRawRanks) '$r$s',
    ];

String musCardRawRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : card;

String musCardSuit(String card) =>
    card.length >= 2 ? card[card.length - 1] : '';

/// In traditional 8-King Mus, `'3'` counts as `'K'` and `'2'` counts as `'A'`.
String musEffectiveRank(String cardOrRank) {
  final r = cardOrRank.length >= 2 ? musCardRawRank(cardOrRank) : cardOrRank;
  if (r == '3') return 'K';
  if (r == '2') return 'A';
  return r;
}

/// Numeric rank strength (`1..8`):
/// `A/2 = 1, 4 = 2, 5 = 3, 6 = 4, 7 = 5, J = 6, Q = 7, K/3 = 8`.
int musRankStrength(String cardOrRank) {
  final eff = musEffectiveRank(cardOrRank);
  return musEffectiveRanks.indexOf(eff) + 1;
}

/// Card value for Stage 3 (`Juego / Punto`):
/// `K, 3, Q, J = 10`; `7..4 = face value`; `A, 2 = 1`.
int musJuegoCardValue(String cardOrRank) {
  final eff = musEffectiveRank(cardOrRank);
  return switch (eff) {
    'K' || 'Q' || 'J' => 10,
    '7' => 7,
    '6' => 6,
    '5' => 5,
    '4' => 4,
    'A' => 1,
    _ => 0,
  };
}

/// Sum of the 4 cards in [hand] for `Juego / Punto` (`4..40`).
int musHandSum(List<String> hand) =>
    hand.fold<int>(0, (sum, c) => sum + musJuegoCardValue(c));

/// Stage 0 (`Grande`): Compare hands lexicographically from highest card to lowest.
/// Returns `> 0` if `handA` beats `handB`, `< 0` if `handB` beats `handA`, `0` if tied.
int musCompareGrande(List<String> handA, List<String> handB) {
  final a = [for (final c in handA) musRankStrength(c)]..sort((x, y) => y.compareTo(x));
  final b = [for (final c in handB) musRankStrength(c)]..sort((x, y) => y.compareTo(x));
  final len = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    if (a[i] != b[i]) return a[i].compareTo(b[i]);
  }
  return 0;
}

/// Stage 1 (`Chica`): Compare hands lexicographically from lowest card to highest.
/// Lower rank strength is better (`A/2` is best)!
/// Returns `> 0` if `handA` beats `handB`, `< 0` if `handB` beats `handA`, `0` if tied.
int musCompareChica(List<String> handA, List<String> handB) {
  final a = [for (final c in handA) musRankStrength(c)]..sort();
  final b = [for (final c in handB) musRankStrength(c)]..sort();
  final len = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    if (a[i] != b[i]) return b[i].compareTo(a[i]); // smaller strength wins
  }
  return 0;
}

/// Evaluates Stage 2 (`Pares`) for a 4-card [hand]:
/// - `'type'`: `'none'` (0), `'par'` (1: One Pair), `'medias'` (2: Three-of-a-Kind), `'duples'` (3: Two Pair or Four-of-a-Kind)
/// - `'tier'`: `0..3`
/// - `'high'`: primary pair/triplet rank strength (`1..8`)
/// - `'low'`: secondary pair rank strength (`1..8`, used for `'duples'`)
/// - `'bonus'`: natural Pares points (`1` for Par, `2` for Medias, `3` for Duples)
Map<String, dynamic> musEvaluatePares(List<String> hand) {
  final counts = <int, int>{};
  for (final c in hand) {
    final s = musRankStrength(c);
    counts[s] = (counts[s] ?? 0) + 1;
  }

  // Four of a kind counts as the highest Duples (two pairs of the same rank)
  for (final entry in counts.entries) {
    if (entry.value == 4) {
      return {
        'type': 'duples',
        'label': '双对 (Duples · 四条)',
        'tier': 3,
        'high': entry.key,
        'low': entry.key,
        'bonus': 3,
      };
    }
  }

  final pairs = counts.entries
      .where((e) => e.value == 2)
      .map((e) => e.key)
      .toList()
    ..sort((a, b) => b.compareTo(a));
  if (pairs.length == 2) {
    return {
      'type': 'duples',
      'label': '双对 (Duples)',
      'tier': 3,
      'high': pairs[0],
      'low': pairs[1],
      'bonus': 3,
    };
  }

  for (final entry in counts.entries) {
    if (entry.value == 3) {
      return {
        'type': 'medias',
        'label': '三条 (Medias)',
        'tier': 2,
        'high': entry.key,
        'low': 0,
        'bonus': 2,
      };
    }
  }

  if (pairs.length == 1) {
    return {
      'type': 'par',
      'label': '一对 (Par)',
      'tier': 1,
      'high': pairs[0],
      'low': 0,
      'bonus': 1,
    };
  }

  return {
    'type': 'none',
    'label': '无对 (Sin Pares)',
    'tier': 0,
    'high': 0,
    'low': 0,
    'bonus': 0,
  };
}

bool musHasPares(List<String> hand) =>
    (musEvaluatePares(hand)['tier'] as int) > 0;

/// Compares two hands in Stage 2 (`Pares`).
/// `Duples (3) > Medias (2) > Par (1) > None (0)`.
int musComparePares(List<String> handA, List<String> handB) {
  final a = musEvaluatePares(handA);
  final b = musEvaluatePares(handB);
  final tierA = a['tier'] as int;
  final tierB = b['tier'] as int;
  if (tierA != tierB) return tierA.compareTo(tierB);
  final highA = a['high'] as int;
  final highB = b['high'] as int;
  if (highA != highB) return highA.compareTo(highB);
  final lowA = a['low'] as int;
  final lowB = b['low'] as int;
  return lowA.compareTo(lowB);
}

/// Strength of a hand sum in Stage 3 (`Juego / Punto`):
/// - If `sum >= 31` (**Juego**):
///   Exact hierarchy: **`31 (Best!) > 32 > 40 > 37 > 36 > 35 > 34 > 33`**!
/// - If `sum < 31` (**Punto**):
///   Closest to `30` wins (`30 > 29 > ... > 4`).
int musJuegoStrength(int sum) {
  return switch (sum) {
    31 => 108,
    32 => 107,
    40 => 106,
    37 => 105,
    36 => 104,
    35 => 103,
    34 => 102,
    33 => 101,
    _ => sum,
  };
}

bool musHasJuego(List<String> hand) => musHandSum(hand) >= 31;

/// Natural bonus for Stage 3 (`Juego / Punto`):
/// - `31` ("La Una"): `3` pts
/// - `32..40` (other Juego): `2` pts
/// - `< 31` (Punto): `1` pt
int musJuegoNaturalBonus(List<String> hand) {
  final sum = musHandSum(hand);
  if (sum == 31) return 3;
  if (sum >= 32) return 2;
  return 1;
}

/// Compares two hands in Stage 3 (`Juego / Punto`).
int musCompareJuego(List<String> handA, List<String> handB) {
  final strA = musJuegoStrength(musHandSum(handA));
  final strB = musJuegoStrength(musHandSum(handB));
  return strA.compareTo(strB);
}

/// Side index for [seat]:
/// - In 4-player partnership mode: `seat % 2` (`0` for `0&2`, `1` for `1&3`).
/// - In 2-player or 3-player mode: `seat`.
int musSideOf(int seat, int players) => players == 4 ? (seat % 2) : seat;

class MusGame extends GameEngine {
  late int targetScore;
  int handNumber = 1;
  int dealer = 0;
  int mano = 1;
  int turn = 1;

  /// Current phase:
  /// - `'mus'`: Negotiating Mus (discard & redraw) vs Cortar (cut to betting)
  /// - `'discard'`: All players agreed to Mus and are selecting cards to discard
  /// - `'bet'`: Betting in `stage` (`0: Grande`, `1: Chica`, `2: Pares`, `3: Juego/Punto`)
  String phase = 'mus';
  int stage = 0;
  int musCutCount = 0;

  List<String> deck = [];
  List<String> discardPile = [];
  late List<List<String>> hands;
  late List<int> scores;
  late List<int> sideScores;

  // Mus negotiation & discard tracking
  List<bool> musAgreed = [];
  List<bool> discardDone = [];
  List<List<String>> pendingDiscards = [];

  // Stage betting state
  List<int> stageEligibleOrder = [];
  int stageTurnIdx = 0;
  int stageBet = 0; // 0 = no bet yet (En Paso), >0 = active bet amount
  int prevBet = 1; // points awarded to bettorSide if opponents fold (Deje)
  int bettorSeat = -1;
  int bettorSide = -1;
  bool ordagoActive = false;
  List<int> pendingResponders = [];

  /// Locked stage states for the 4 categories (`0..3`):
  /// `{ 'status': 'paso' | 'accepted' | 'folded' | 'skipped', 'stake': int, 'winnerSide': int }`
  List<Map<String, dynamic>> stageResults = [];
  List<String> actionLog = [];
  Map<String, dynamic>? lastHandSummary;

  bool _over = false;
  List<int>? _placings;

  MusGame(super.setup) {
    targetScore = setup.opt<int>('targetScore', 30);
    hands = List.generate(players, (_) => <String>[]);
    scores = List.filled(players, 0);
    sideScores = List.filled(numSides, 0);
    _resetStageResults();
  }

  int get numSides => players == 4 ? 2 : players;
  int sideOf(int seat) => musSideOf(seat, players);

  void _resetStageResults() {
    stageResults = [
      for (var i = 0; i < 4; i++)
        {
          'stage': i,
          'name': musStageNames[i],
          'status': 'pending',
          'stake': 1,
          'dejeSide': -1,
        },
    ];
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'discard') {
      return [
        for (var s = 0; s < players; s++)
          if (!discardDone[s]) s,
      ];
    }
    return [turn];
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final losingSide = sideOf(seat);
    final winners = [
      for (var i = 0; i < players; i++)
        if (sideOf(i) != losingSide) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startHand();
  }

  List<int> _seatsFromMano() => [
        for (var i = 0; i < players; i++) (mano + i) % players,
      ];

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final rCmp = musRankStrength(b).compareTo(musRankStrength(a));
      if (rCmp != 0) return rCmp;
      return musSuits.indexOf(musCardSuit(a)).compareTo(musSuits.indexOf(musCardSuit(b)));
    });
  }

  String _drawCard() {
    if (deck.isEmpty) {
      if (discardPile.isNotEmpty) {
        deck = shuffled(discardPile, rng);
        discardPile.clear();
      } else {
        deck = shuffled(buildMusDeck(), rng);
      }
    }
    return deck.removeLast();
  }

  void _startHand() {
    deck = shuffled(buildMusDeck(), rng);
    discardPile = [];
    mano = (dealer + 1) % players;
    for (var i = 0; i < players; i++) {
      final s = (mano + i) % players;
      hands[s] = [for (var c = 0; c < 4; c++) _drawCard()];
      _sortHand(hands[s]);
    }

    musCutCount = 0;
    actionLog = [];
    _resetStageResults();
    _enterMusPhase();
    host.log('第 $handNumber 局开始：${name(mano)} 为先手 (Mano)');
  }

  void _enterMusPhase() {
    phase = 'mus';
    musAgreed = List.filled(players, false);
    turn = mano;
  }

  void _enterBettingStage(int nextStage) {
    if (nextStage >= 4) {
      _resolveShowdown();
      return;
    }

    stage = nextStage;
    phase = 'bet';
    stageBet = 0;
    prevBet = 1;
    bettorSeat = -1;
    bettorSide = -1;
    ordagoActive = false;
    pendingResponders = [];

    final order = _seatsFromMano();
    if (stage == 0 || stage == 1) {
      stageEligibleOrder = order;
    } else if (stage == 2) {
      // Pares: only seats with at least one pair participate
      stageEligibleOrder = order.where((s) => musHasPares(hands[s])).toList();
      final eligibleSides = stageEligibleOrder.map(sideOf).toSet();
      if (eligibleSides.length < 2) {
        stageResults[2] = {
          'stage': 2,
          'name': musStageNames[2],
          'status': 'skipped',
          'stake': 0,
          'dejeSide': -1,
        };
        actionLog.add('Pares(比对子): 少于两方有对子，跳过叫注');
        _enterBettingStage(3);
        return;
      }
    } else {
      // Stage 3: Juego (>=31) if anyone has >=31, else Punto (<31)
      final juegoSeats = order.where((s) => musHasJuego(hands[s])).toList();
      if (juegoSeats.isNotEmpty) {
        stageEligibleOrder = juegoSeats;
        final eligibleSides = stageEligibleOrder.map(sideOf).toSet();
        if (eligibleSides.length < 2) {
          stageResults[3] = {
            'stage': 3,
            'name': 'Juego (比31点)',
            'status': 'skipped',
            'stake': 0,
            'dejeSide': -1,
          };
          actionLog.add('Juego(比31点): 仅单方拥有≥31点，自动获胜');
          _resolveShowdown();
          return;
        }
      } else {
        stageEligibleOrder = order;
      }
    }

    stageTurnIdx = 0;
    turn = stageEligibleOrder.first;
  }

  void _addSidePoints(int side, int pts) {
    if (pts <= 0 || _over) return;
    sideScores[side] += pts;
    for (var s = 0; s < players; s++) {
      scores[s] = sideScores[sideOf(s)];
    }
    if (sideScores[side] >= targetScore) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('比赛结束！');
    }
  }

  /// Finds the winning seat among [candidates] for [catStage] (`0..3`).
  /// Ties are broken by seat priority starting from `mano` (`_seatsFromMano()`).
  int bestSeatForStage(int catStage, [List<int>? candidates]) {
    final order = candidates ?? _seatsFromMano();
    var best = order.first;
    for (var i = 1; i < order.length; i++) {
      final s = order[i];
      final cmp = switch (catStage) {
        0 => musCompareGrande(hands[s], hands[best]),
        1 => musCompareChica(hands[s], hands[best]),
        2 => musComparePares(hands[s], hands[best]),
        _ => musCompareJuego(hands[s], hands[best]),
      };
      if (cmp > 0) {
        best = s;
      }
    }
    return best;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'mus') {
      if (seat != turn) throw GameError('还没轮到你表态');
      if (type == 'cortar') {
        actionLog.add('${name(seat)} 喊出 Cortar (不换牌，直接开赌)');
        host.log('${name(seat)} 选择 Cortar（切牌进入四项比拼）！');
        _enterBettingStage(0);
        return;
      }
      if (type == 'mus') {
        musAgreed[seat] = true;
        actionLog.add('${name(seat)} 选择 Mus (同意换牌)');
        if (musAgreed.every((v) => v)) {
          phase = 'discard';
          discardDone = List.filled(players, false);
          pendingDiscards = List.generate(players, (_) => <String>[]);
          host.log('全员同意 Mus！请选择要弃换的手牌');
        } else {
          final order = _seatsFromMano();
          final idx = order.indexOf(seat);
          turn = order[(idx + 1) % players];
        }
        return;
      }
      throw GameError('请表态 mus（同意换牌）或 cortar（切牌开赌）');
    }

    if (phase == 'discard') {
      if (discardDone[seat]) throw GameError('你已提交换牌');
      if (type != 'discard') throw GameError('请提交要弃换的手牌');
      final raw = (action['cards'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
      final tempHand = List<String>.of(hands[seat]);
      for (final c in raw) {
        if (!tempHand.remove(c)) {
          throw GameError('手牌中没有 $c');
        }
      }
      pendingDiscards[seat] = raw;
      discardDone[seat] = true;

      if (discardDone.every((v) => v)) {
        for (final s in _seatsFromMano()) {
          final disc = pendingDiscards[s];
          for (final c in disc) {
            hands[s].remove(c);
            discardPile.add(c);
          }
          for (var i = 0; i < disc.length; i++) {
            hands[s].add(_drawCard());
          }
          _sortHand(hands[s]);
        }
        musCutCount += 1;
        _enterMusPhase();
      }
      return;
    }

    if (phase == 'bet') {
      if (seat != turn) throw GameError('还没轮到你行动');
      _handleBetAction(seat, action);
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _handleBetAction(int seat, Map<String, dynamic> action) {
    final type = asStr(action['type']);
    final mySide = sideOf(seat);
    final stageLabel = musStageNames[stage];

    if (stageBet == 0) {
      // No bet yet in this stage
      if (type == 'pass') {
        actionLog.add('$stageLabel: ${name(seat)} 过牌 (Paso)');
        stageTurnIdx += 1;
        if (stageTurnIdx >= stageEligibleOrder.length) {
          stageResults[stage] = {
            'stage': stage,
            'name': stageLabel,
            'status': 'paso',
            'stake': 1,
            'dejeSide': -1,
          };
          _enterBettingStage(stage + 1);
        } else {
          turn = stageEligibleOrder[stageTurnIdx];
        }
        return;
      }

      if (type == 'envido' || type == 'raise') {
        final amount = asInt(action['amount'], 2).clamp(2, targetScore);
        stageBet = amount;
        prevBet = 1;
        bettorSeat = seat;
        bettorSide = mySide;
        ordagoActive = false;
        pendingResponders = stageEligibleOrder
            .where((s) => sideOf(s) != mySide)
            .toList();
        turn = pendingResponders.first;
        actionLog.add('$stageLabel: ${name(seat)} 叫注 Envido (+$amount分)');
        host.log('$stageLabel：${name(seat)} 喊出 Envido (+$amount 分)！');
        return;
      }

      if (type == 'ordago') {
        stageBet = targetScore;
        prevBet = 1;
        bettorSeat = seat;
        bettorSide = mySide;
        ordagoActive = true;
        pendingResponders = stageEligibleOrder
            .where((s) => sideOf(s) != mySide)
            .toList();
        turn = pendingResponders.first;
        actionLog.add('$stageLabel: ${name(seat)} 喊出 Órdago! (全押胜负)');
        host.log('$stageLabel：${name(seat)} 喊出「Órdago!」（一决胜负）！');
        return;
      }

      throw GameError('可选择 pass (过牌)、envido (加注) 或 ordago (全押)');
    }

    // Active bet on the table: responder must choose fold, accept, raise/envido, or ordago
    if (type == 'fold') {
      actionLog.add('$stageLabel: ${name(seat)} 选择 No quiero (不跟)');
      pendingResponders.remove(seat);
      if (pendingResponders.isEmpty) {
        // All opposing eligible players folded -> bettorSide scores prevBet immediately (Deje)
        stageResults[stage] = {
          'stage': stage,
          'name': stageLabel,
          'status': 'folded',
          'stake': prevBet,
          'dejeSide': bettorSide,
        };
        host.log('$stageLabel：对手弃牌 (No quiero)，加注方立即获得 +$prevBet 分 (Deje)！');
        _addSidePoints(bettorSide, prevBet);
        if (!_over) {
          _enterBettingStage(stage + 1);
        }
      } else {
        turn = pendingResponders.first;
      }
      return;
    }

    if (type == 'accept') {
      actionLog.add('$stageLabel: ${name(seat)} 选择 Quiero (跟注接受)');
      if (ordagoActive) {
        // Accepting an Órdago resolves the entire match immediately on this category!
        final winnerSeat = bestSeatForStage(stage, stageEligibleOrder);
        final winSide = sideOf(winnerSeat);
        stageResults[stage] = {
          'stage': stage,
          'name': stageLabel,
          'status': 'ordago_accepted',
          'stake': targetScore,
          'winnerSeat': winnerSeat,
          'winnerSide': winSide,
          'dejeSide': -1,
        };
        host.log('$stageLabel：${name(seat)} 接下 Órdago！${name(winnerSeat)} 胜出，直接赢得整场比赛！');
        _addSidePoints(winSide, targetScore);
        lastHandSummary = {
          'handNumber': handNumber,
          'ordagoStage': stage,
          'ordagoWinnerSeat': winnerSeat,
          'ordagoWinnerSide': winSide,
          'hands': [for (final h in hands) List<String>.of(h)],
          'stageResults': [for (final r in stageResults) Map<String, dynamic>.of(r)],
        };
        return;
      }

      stageResults[stage] = {
        'stage': stage,
        'name': stageLabel,
        'status': 'accepted',
        'stake': stageBet,
        'dejeSide': -1,
      };
      host.log('$stageLabel：${name(seat)} 接受下注（赌注 $stageBet 分锁定至摊牌）');
      _enterBettingStage(stage + 1);
      return;
    }

    if (!ordagoActive && (type == 'raise' || type == 'envido')) {
      final add = asInt(action['amount'], 2).clamp(2, targetScore);
      prevBet = stageBet;
      stageBet += add;
      bettorSeat = seat;
      bettorSide = mySide;
      pendingResponders = stageEligibleOrder
          .where((s) => sideOf(s) != mySide)
          .toList();
      turn = pendingResponders.first;
      actionLog.add('$stageLabel: ${name(seat)} 反加注 Reenvido (总注 $stageBet 分)');
      host.log('$stageLabel：${name(seat)} 反加注至 $stageBet 分！');
      return;
    }

    if (!ordagoActive && type == 'ordago') {
      prevBet = stageBet;
      stageBet = targetScore;
      bettorSeat = seat;
      bettorSide = mySide;
      ordagoActive = true;
      pendingResponders = stageEligibleOrder
          .where((s) => sideOf(s) != mySide)
          .toList();
      turn = pendingResponders.first;
      actionLog.add('$stageLabel: ${name(seat)} 升级为 Órdago! (全押胜负)');
      host.log('$stageLabel：${name(seat)} 反喊「Órdago!」（全押胜负）！');
      return;
    }

    throw GameError('当前请响应 accept (跟注)、fold (弃牌)${ordagoActive ? "" : "、raise (加注) 或 ordago (全押)"}');
  }

  void _resolveShowdown() {
    final breakdown = <Map<String, dynamic>>[];

    // 0: Grande & 1: Chica
    for (final cat in [0, 1]) {
      final res = stageResults[cat];
      final status = asStr(res['status']);
      if (status == 'folded') {
        breakdown.add({
          'stage': cat,
          'name': musStageNames[cat],
          'winnerSide': res['dejeSide'],
          'points': res['stake'],
          'note': '弃牌得分 (Deje)',
        });
        continue;
      }
      final winnerSeat = bestSeatForStage(cat);
      final winSide = sideOf(winnerSeat);
      final pts = asInt(res['stake'], 1);
      _addSidePoints(winSide, pts);
      breakdown.add({
        'stage': cat,
        'name': musStageNames[cat],
        'winnerSeat': winnerSeat,
        'winnerSide': winSide,
        'points': pts,
        'note': status == 'accepted' ? '接注摊牌' : '过牌比拼 (En Paso)',
      });
      if (_over) break;
    }

    // 2: Pares
    if (!_over) {
      final paresSeats = _seatsFromMano().where((s) => musHasPares(hands[s])).toList();
      if (paresSeats.isNotEmpty) {
        final res = stageResults[2];
        final status = asStr(res['status']);
        final int winSide;
        final int winnerSeat;
        if (status == 'folded') {
          winSide = asInt(res['dejeSide'], 0);
          winnerSeat = paresSeats.firstWhere(
            (s) => sideOf(s) == winSide,
            orElse: () => paresSeats.first,
          );
        } else {
          winnerSeat = bestSeatForStage(2, paresSeats);
          winSide = sideOf(winnerSeat);
        }
        var bonusPts = 0;
        for (var s = 0; s < players; s++) {
          if (sideOf(s) == winSide) {
            bonusPts += musEvaluatePares(hands[s])['bonus'] as int;
          }
        }
        final betPts = status == 'accepted' ? asInt(res['stake'], 0) : 0;
        final totalPts = betPts + bonusPts;
        _addSidePoints(winSide, totalPts);
        breakdown.add({
          'stage': 2,
          'name': musStageNames[2],
          'winnerSeat': winnerSeat,
          'winnerSide': winSide,
          'points': totalPts,
          'note': '牌型分+$bonusPts${betPts > 0 ? " · 赌注+$betPts" : ""}',
        });
      }
    }

    // 3: Juego / Punto
    if (!_over) {
      final order = _seatsFromMano();
      final juegoSeats = order.where((s) => musHasJuego(hands[s])).toList();
      final res = stageResults[3];
      final status = asStr(res['status']);

      if (juegoSeats.isNotEmpty) {
        final int winSide;
        final int winnerSeat;
        if (status == 'folded') {
          winSide = asInt(res['dejeSide'], 0);
          winnerSeat = juegoSeats.firstWhere(
            (s) => sideOf(s) == winSide,
            orElse: () => juegoSeats.first,
          );
        } else {
          winnerSeat = bestSeatForStage(3, juegoSeats);
          winSide = sideOf(winnerSeat);
        }
        var bonusPts = 0;
        for (var s = 0; s < players; s++) {
          if (sideOf(s) == winSide && musHasJuego(hands[s])) {
            bonusPts += musJuegoNaturalBonus(hands[s]);
          }
        }
        final betPts = status == 'accepted' ? asInt(res['stake'], 0) : 0;
        final totalPts = betPts + bonusPts;
        _addSidePoints(winSide, totalPts);
        breakdown.add({
          'stage': 3,
          'name': 'Juego (比31点)',
          'winnerSeat': winnerSeat,
          'winnerSide': winSide,
          'points': totalPts,
          'note': 'Juego奖分+$bonusPts${betPts > 0 ? " · 赌注+$betPts" : ""}',
        });
      } else {
        // Punto
        final int winSide;
        final int winnerSeat;
        if (status == 'folded') {
          winSide = asInt(res['dejeSide'], 0);
          winnerSeat = order.firstWhere((s) => sideOf(s) == winSide);
        } else {
          winnerSeat = bestSeatForStage(3, order);
          winSide = sideOf(winnerSeat);
        }
        const bonusPts = 1;
        final betPts = status == 'accepted' ? asInt(res['stake'], 0) : 0;
        final totalPts = betPts + bonusPts;
        _addSidePoints(winSide, totalPts);
        breakdown.add({
          'stage': 3,
          'name': 'Punto (比接近30点)',
          'winnerSeat': winnerSeat,
          'winnerSide': winSide,
          'points': totalPts,
          'note': 'Punto奖分+1${betPts > 0 ? " · 赌注+$betPts" : ""}',
        });
      }
    }

    lastHandSummary = {
      'handNumber': handNumber,
      'hands': [for (final h in hands) List<String>.of(h)],
      'breakdown': breakdown,
      'sideScores': List<int>.of(sideScores),
    };

    if (!_over) {
      handNumber += 1;
      dealer = (dealer + 1) % players;
      _startHand();
    }
  }

  double _handStageQuality(int seat, int catStage) {
    final h = hands[seat];
    if (catStage == 0) {
      final strengths = [for (final c in h) musRankStrength(c)]..sort((a, b) => b.compareTo(a));
      // Having two Kings or a King + Queen is strong in Grande
      return (strengths[0] * 10 + strengths[1]) / 88.0;
    }
    if (catStage == 1) {
      final strengths = [for (final c in h) musRankStrength(c)]..sort();
      // Having Aces/2s is strong in Chica
      return ((9 - strengths[0]) * 10 + (9 - strengths[1])) / 88.0;
    }
    if (catStage == 2) {
      final p = musEvaluatePares(h);
      final tier = p['tier'] as int;
      final high = p['high'] as int;
      return (tier * 10 + high) / 38.0;
    }
    final sum = musHandSum(h);
    if (sum == 31) return 1.0;
    if (sum == 32) return 0.9;
    if (sum >= 33) return 0.72;
    return (sum / 30.0).clamp(0.0, 0.75);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'mus') {
      final h = hands[seat];
      final hasGoodPares = (musEvaluatePares(h)['tier'] as int) >= 2;
      final has31 = musHandSum(h) == 31 || musHandSum(h) == 32;
      if (musCutCount >= 1 || hasGoodPares || has31 || rng.nextDouble() < 0.55) {
        return {'type': 'cortar'};
      }
      return {'type': 'mus'};
    }

    if (phase == 'discard') {
      final h = hands[seat];
      // Discard middle cards (4, 5, 6, 7) that aren't paired
      final counts = <String, int>{};
      for (final c in h) {
        final eff = musEffectiveRank(c);
        counts[eff] = (counts[eff] ?? 0) + 1;
      }
      final toDiscard = h.where((c) {
        final eff = musEffectiveRank(c);
        return (counts[eff] ?? 0) == 1 && eff != 'K' && eff != 'A';
      }).toList();
      return {'type': 'discard', 'cards': toDiscard};
    }

    if (phase == 'bet') {
      final q = _handStageQuality(seat, stage);
      if (stageBet == 0) {
        if (q >= 0.88 && rng.nextDouble() < 0.25) {
          return {'type': 'ordago'};
        }
        if (q >= 0.68 && rng.nextDouble() < 0.65) {
          return {'type': 'envido', 'amount': 2};
        }
        return {'type': 'pass'};
      } else {
        if (ordagoActive) {
          return q >= 0.82 ? {'type': 'accept'} : {'type': 'fold'};
        }
        if (q >= 0.85 && stageBet <= 6 && rng.nextDouble() < 0.35) {
          return {'type': 'raise', 'amount': 2};
        }
        if (q >= 0.58) {
          return {'type': 'accept'};
        }
        return {'type': 'fold'};
      }
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? List<String>.of(hands[seat])
        : <String>[];
    final myPares = myHand.isNotEmpty ? musEvaluatePares(myHand) : null;
    final mySum = myHand.isNotEmpty ? musHandSum(myHand) : 0;

    return {
      'handNumber': handNumber,
      'targetScore': targetScore,
      'dealer': dealer,
      'mano': mano,
      'turn': turn,
      'phase': phase,
      'stage': stage,
      'stageName': stage >= 0 && stage < musStageNames.length ? musStageNames[stage] : '',
      'stageBet': stageBet,
      'prevBet': prevBet,
      'bettorSeat': bettorSeat,
      'bettorSide': bettorSide,
      'ordagoActive': ordagoActive,
      'scores': List<int>.of(scores),
      'sideScores': List<int>.of(sideScores),
      'musAgreed': List<bool>.of(musAgreed),
      'discardDone': discardDone.isNotEmpty ? List<bool>.of(discardDone) : <bool>[],
      'paresDeclarations': [
        for (var s = 0; s < players; s++) musHasPares(hands[s]),
      ],
      'juegoDeclarations': [
        for (var s = 0; s < players; s++) musHasJuego(hands[s]),
      ],
      'handCounts': [for (final h in hands) h.length],
      'hand': myHand,
      'myPares': myPares,
      'mySum': mySum,
      'stageResults': [for (final r in stageResults) Map<String, dynamic>.of(r)],
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastHandSummary': lastHandSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
