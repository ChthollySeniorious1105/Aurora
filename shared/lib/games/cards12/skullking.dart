import '../../src/engine.dart';

const String skullKingRules = '''
# 骷髅王 Skull King 规则说明

## 牌组构成（70 张海盗吃墩牌）
- **三门普通花色（共 42 张）**：黄金宝箱（`Y`）、紫罗兰（`P`）、绿鹦鹉（`G`），每门 `1..14`。
- **海盗黑旗主花色（`B`，14 张）**：黑旗 `1B..14B`，作为主牌（Trump）可压过任何三门普通花色的数牌。
- **五大特殊角色牌（共 14 张，任何时候均可无视跟花限制打出）**：
  - **白旗逃跑（`ESC` ×5）**：永远输掉该墩（若一整墩全员皆打白旗逃跑，则由该墩第 1 位引牌者赢下该墩）。
  - **海盗（`PIR` ×5）**：压过所有数牌（包括黑旗主花色 `B`）；若同一墩有多张海盗，先打出的海盗更大。
  - **美人鱼（`MER` ×2）**：压过所有数牌，但输给海盗；**唯一例外：美人鱼能诱惑并击败骷髅王（`SK`）**！若一墩中同时出现骷髅王、海盗与美人鱼，仍由最先打出的美人鱼获胜并斩获 **+40 额外奖励分**！
  - **骷髅王（`SK` ×1）**：海盗之王，压过所有海盗与数牌，每击败该墩中的 1 张海盗（含以海盗身份打出的女海盗）即可获得 **+30 额外奖励分**；仅会被美人鱼击败！
  - **女海盗（`TIG` ×1，Tigress）**：打出时由玩家自由选择本墩作为 **海盗（`pirate`）** 或 **白旗逃跑（`escape`）** 生效！

## 轮次与同时叫墩（Simultaneous Bid）
- **轮次发牌**：
  - 6 轮标准模式：第 1~6 轮分别发 `1, 2, 3, 4, 5, 6` 张牌；
  - 4 轮快速模式：第 1~4 轮分别发 `2, 3, 4, 5` 张牌。
- **同时叫墩阶段（`bid`）**：所有玩家查看手牌后，**同时暗叫**本轮预计赢下的准确墩数（`0..本轮手牌数`），全员锁定后同时亮出！
- **跟花规则（`play`）**：
  - 本墩第一张打出的数牌决定引牌花色（若首引白旗逃跑，则顺延看下一张；若在数牌出现前先打出了海盗/美人鱼/骷髅王，则本墩无花色限制）。
  - 持有引牌花色时，可打出该花色数牌**或任意特殊牌（`ESC/PIR/MER/SK/TIG`）**；仅当手中没有引牌花色数牌时，才可打出其他花色数牌或黑旗主牌。

## 计分规则（高风险高回报）
- **叫墩 `>= 1` 且准确命中（`tricksWon == bid`）**：获得 **`+20 × 叫墩数` + 本轮赢下的特殊牌击败奖励分**！
- **叫墩 `>= 1` 但未命中（`tricksWon != bid`）**：扣除 **`-10 × |叫墩数 - 实际赢墩数|`** 分（无任何奖励分）！
- **叫 `0` 墩（免战宣言）**：
  - 若成功 1 墩未赢（`tricksWon == 0`）：获得 **`+10 × 本轮手牌数`** 分！
  - 若意外赢下任意一墩（`tricksWon > 0`）：扣除 **`-10 × 本轮手牌数`** 分！
''';

const List<String> kSkullKingSuits = ['Y', 'P', 'G', 'B'];
const Set<String> kSkullKingSpecials = {'ESC', 'PIR', 'MER', 'SK', 'TIG'};

/// Build the 70-card Skull King deck.
List<String> buildSkullKingDeck() => [
      for (final s in kSkullKingSuits)
        for (var r = 1; r <= 14; r++) '$r$s',
      for (var i = 0; i < 5; i++) 'ESC',
      for (var i = 0; i < 5; i++) 'PIR',
      for (var i = 0; i < 2; i++) 'MER',
      'SK',
      'TIG',
    ];

bool isSkullKingSpecial(String card) => kSkullKingSpecials.contains(card);

/// Suit of a numbered Skull King card ('Y','P','G','B'), or '' for special cards.
String skullKingSuit(String card) {
  if (isSkullKingSpecial(card) || card.length < 2) return '';
  return card[card.length - 1];
}

/// Rank 1..14 of a numbered Skull King card, or 0 for special cards.
int skullKingRank(String card) {
  if (isSkullKingSpecial(card) || card.length < 2) return 0;
  return int.tryParse(card.substring(0, card.length - 1)) ?? 0;
}

/// Effective card code after resolving Tigress ('TIG') mode ('pirate' -> 'PIR', 'escape' -> 'ESC').
String skullKingEffectiveCard(String card, String? mode) {
  if (card == 'TIG') {
    return mode == 'escape' ? 'ESC' : 'PIR';
  }
  return card;
}

/// Determines the led suit of the current trick:
/// - null if empty or only Escapes played so far
/// - 'CHAR' if a character ('PIR','MER','SK') was played before any numbered card
/// - 'Y'|'P'|'G'|'B' if a numbered card was played first.
String? skullKingLedSuit(List<Map<String, dynamic>> currentTrick) {
  for (final e in currentTrick) {
    final eff = skullKingEffectiveCard('${e['card']}', e['mode'] as String?);
    if (eff == 'ESC') continue;
    if (eff == 'PIR' || eff == 'MER' || eff == 'SK') return 'CHAR';
    final s = skullKingSuit(eff);
    if (s.isNotEmpty) return s;
  }
  return null;
}

/// Returns legal cards from [hand] given [currentTrick].
List<String> getSkullKingLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> currentTrick,
) {
  final led = skullKingLedSuit(currentTrick);
  if (led == null || led == 'CHAR') {
    return List<String>.of(hand);
  }
  final hasLedSuit = hand.any((c) => skullKingSuit(c) == led);
  if (!hasLedSuit) {
    return List<String>.of(hand);
  }
  return hand
      .where((c) => isSkullKingSpecial(c) || skullKingSuit(c) == led)
      .toList();
}

class SkullKingTrickResolution {
  final int winnerSeat;
  final int bonusPoints;
  final String winningCard;

  const SkullKingTrickResolution({
    required this.winnerSeat,
    required this.bonusPoints,
    required this.winningCard,
  });
}

/// Resolves a completed Skull King trick, returning winner seat and bonus points:
/// - Mermaid beating Skull King: +40 bonus points
/// - Skull King beating Pirates: +30 bonus points per Pirate (including Tigress as Pirate)
SkullKingTrickResolution resolveSkullKingTrick(
  List<Map<String, dynamic>> trick,
) {
  var hasSk = false;
  var skSeat = -1;
  var firstMerSeat = -1;
  var firstPirSeat = -1;
  var pirateCount = 0;

  for (final e in trick) {
    final seat = (e['seat'] as num).toInt();
    final eff = skullKingEffectiveCard('${e['card']}', e['mode'] as String?);
    if (eff == 'SK') {
      hasSk = true;
      skSeat = seat;
    } else if (eff == 'MER') {
      if (firstMerSeat < 0) firstMerSeat = seat;
    } else if (eff == 'PIR') {
      if (firstPirSeat < 0) firstPirSeat = seat;
      pirateCount++;
    }
  }

  // 1. Both Skull King and Mermaid in trick -> first Mermaid lures Skull King (+40 pts)
  if (hasSk && firstMerSeat >= 0) {
    return SkullKingTrickResolution(
      winnerSeat: firstMerSeat,
      bonusPoints: 40,
      winningCard: 'MER',
    );
  }

  // 2. Skull King in trick (no Mermaid) -> Skull King wins (+30 pts per Pirate)
  if (hasSk) {
    return SkullKingTrickResolution(
      winnerSeat: skSeat,
      bonusPoints: 30 * pirateCount,
      winningCard: 'SK',
    );
  }

  // 3. Pirate in trick (no Skull King) -> first Pirate wins
  if (firstPirSeat >= 0) {
    return SkullKingTrickResolution(
      winnerSeat: firstPirSeat,
      bonusPoints: 0,
      winningCard: 'PIR',
    );
  }

  // 4. Mermaid in trick (no Pirate, no Skull King) -> first Mermaid wins
  if (firstMerSeat >= 0) {
    return SkullKingTrickResolution(
      winnerSeat: firstMerSeat,
      bonusPoints: 0,
      winningCard: 'MER',
    );
  }

  // 5. Only numbered cards and Escapes
  String? ledSuit;
  var bestSeat = (trick.first['seat'] as num).toInt();
  var bestCard = '${trick.first['card']}';
  var bestBlack = 0;
  var bestLedRank = 0;

  for (final e in trick) {
    final seat = (e['seat'] as num).toInt();
    final raw = '${e['card']}';
    final eff = skullKingEffectiveCard(raw, e['mode'] as String?);
    if (eff == 'ESC') continue;

    final suit = skullKingSuit(eff);
    final rank = skullKingRank(eff);
    ledSuit ??= suit;

    if (suit == 'B') {
      if (rank > bestBlack) {
        bestBlack = rank;
        bestSeat = seat;
        bestCard = raw;
      }
    } else if (bestBlack == 0 && suit == ledSuit) {
      if (rank > bestLedRank) {
        bestLedRank = rank;
        bestSeat = seat;
        bestCard = raw;
      }
    }
  }

  return SkullKingTrickResolution(
    winnerSeat: bestSeat,
    bonusPoints: 0,
    winningCard: bestCard,
  );
}

/// Calculates a player's round score given [bid], [tricksWon], [roundCards], and [bonusPoints].
int calculateSkullKingRoundScore({
  required int bid,
  required int tricksWon,
  required int roundCards,
  required int bonusPoints,
}) {
  if (bid == 0) {
    return tricksWon == 0 ? 10 * roundCards : -10 * roundCards;
  }
  if (tricksWon == bid) {
    return 20 * bid + bonusPoints;
  }
  return -10 * (bid - tricksWon).abs();
}

class SkullKingGame extends GameEngine {
  SkullKingGame(super.setup);

  late int maxRounds;
  late List<int> roundSchedule;
  int round = 1;
  int roundCards = 1;
  int startSeat = 0;
  int turn = 0;
  String phase = 'bid'; // 'bid' | 'play'

  List<List<String>> hands = [];
  List<int?> bids = [];
  List<int> tricksWon = [];
  List<int> roundBonus = [];
  int tricksPlayed = 0;

  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  List<int> scores = [];
  Map<String, dynamic>? lastRoundSummary;
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'bid') {
      return [
        for (var s = 0; s < players; s++)
          if (bids[s] == null) s,
      ];
    }
    return [turn];
  }

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 6);
    if (maxRounds == 4) {
      roundSchedule = const [2, 3, 4, 5];
    } else {
      roundSchedule = [for (var i = 1; i <= maxRounds; i++) i];
    }
    scores = List<int>.filled(players, 0);
    startSeat = 0;
    _startRound();
  }

  void _startRound() {
    roundCards = roundSchedule[(round - 1).clamp(0, roundSchedule.length - 1)];
    final deck = shuffled(buildSkullKingDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++)
        _sortHand(deck.sublist(s * roundCards, (s + 1) * roundCards)),
    ];
    bids = List<int?>.filled(players, null);
    tricksWon = List<int>.filled(players, 0);
    roundBonus = List<int>.filled(players, 0);
    tricksPlayed = 0;
    currentTrick = [];
    lastTrick = null;
    phase = 'bid';
    turn = startSeat;
    host.log('第 $round/$maxRounds 轮（每人 $roundCards 张牌）：请所有玩家同时叫墩（0..$roundCards）！');
  }

  List<String> _sortHand(Iterable<String> cards) {
    final list = List<String>.of(cards);
    const order = {
      'SK': 0,
      'MER': 1,
      'PIR': 2,
      'TIG': 3,
      'B': 4,
      'Y': 5,
      'P': 6,
      'G': 7,
      'ESC': 8,
    };
    list.sort((a, b) {
      final ka = isSkullKingSpecial(a) ? a : skullKingSuit(a);
      final kb = isSkullKingSpecial(b) ? b : skullKingSuit(b);
      final oa = order[ka] ?? 9;
      final ob = order[kb] ?? 9;
      if (oa != ob) return oa.compareTo(ob);
      return skullKingRank(b).compareTo(skullKingRank(a));
    });
    return list;
  }

  List<String> legalCards(int seat) {
    if (seat < 0 || seat >= players) return const [];
    return getSkullKingLegalCards(hands[seat], currentTrick);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type != 'bid') throw GameError('当前处于同时叫墩阶段，请叫墩');
      if (bids[seat] != null) throw GameError('你已经锁定了本轮叫墩');
      final b = asInt(action['bid'], -1);
      if (b < 0 || b > roundCards) {
        throw GameError('叫墩数必须在 0 到 $roundCards 之间');
      }
      bids[seat] = b;
      if (bids.every((x) => x != null)) {
        phase = 'play';
        turn = startSeat;
        final summary = [
          for (var s = 0; s < players; s++) '${name(s)}:${bids[s]}墩',
        ].join('，');
        host.log('全员亮出叫墩（$summary），由 ${name(turn)} 首引第 1 墩！');
      }
      return;
    }

    if (phase == 'play') {
      if (seat != turn) throw GameError('当前不是你的回合');
      if (type != 'play') throw GameError('请选择要打出的牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有 $card');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟随本墩首引花色或打出特殊牌');
      }

      String? mode;
      if (card == 'TIG') {
        final rawMode = asStr(action['mode'], 'pirate');
        if (rawMode != 'pirate' && rawMode != 'escape') {
          throw GameError('女海盗（TIG）必须选择作为 pirate（海盗）或 escape（白旗逃跑）');
        }
        mode = rawMode;
      }

      hands[seat].remove(card);
      currentTrick.add({
        'seat': seat,
        'card': card,
        if (mode != null) 'mode': mode,
      });

      if (currentTrick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知阶段: $phase');
  }

  void _resolveTrick() {
    final res = resolveSkullKingTrick(currentTrick);
    final winner = res.winnerSeat;
    tricksPlayed++;
    tricksWon[winner]++;
    roundBonus[winner] += res.bonusPoints;

    lastTrick = {
      'winner': winner,
      'winningCard': res.winningCard,
      'bonusPoints': res.bonusPoints,
      'cards': List<Map<String, dynamic>>.of(currentTrick),
    };
    currentTrick = [];

    if (tricksPlayed >= roundCards) {
      _scoreRound();
    } else {
      turn = winner;
    }
  }

  void _scoreRound() {
    final deltas = List<int>.filled(players, 0);
    for (var s = 0; s < players; s++) {
      final b = bids[s] ?? 0;
      deltas[s] = calculateSkullKingRoundScore(
        bid: b,
        tricksWon: tricksWon[s],
        roundCards: roundCards,
        bonusPoints: roundBonus[s],
      );
      scores[s] += deltas[s];
    }

    lastRoundSummary = {
      'round': round,
      'roundCards': roundCards,
      'bids': [for (final b in bids) b ?? 0],
      'tricksWon': List<int>.of(tricksWon),
      'roundBonus': List<int>.of(roundBonus),
      'deltas': deltas,
      'scores': List<int>.of(scores),
    };

    host.log(
      '第 $round 轮结算：'
      '${[for (var s = 0; s < players; s++) '${name(s)} (${tricksWon[s]}/${bids[s]}墩) ${deltas[s] >= 0 ? '+${deltas[s]}' : deltas[s]}分'].join('，')}',
    );

    if (round >= maxRounds) {
      _over = true;
      return;
    }

    round++;
    startSeat = (startSeat + 1) % players;
    _startRound();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players)
        ? List<String>.of(hands[seat])
        : const <String>[];
    final legal = (seat >= 0 && seat < players && phase == 'play' && seat == turn)
        ? legalCards(seat)
        : const <String>[];

    // Hide other players' exact bids until all bids are locked in
    final visibleBids = [
      for (var s = 0; s < players; s++)
        if (phase != 'bid' || s == seat) bids[s] else null,
    ];
    final bidLocked = [for (var s = 0; s < players; s++) bids[s] != null];

    return {
      'round': round,
      'maxRounds': maxRounds,
      'roundCards': roundCards,
      'phase': phase,
      'turn': turn,
      'startSeat': startSeat,
      'bids': visibleBids,
      'bidLocked': bidLocked,
      'tricksWon': List<int>.of(tricksWon),
      'roundBonus': List<int>.of(roundBonus),
      'tricksPlayed': tricksPlayed,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'currentTrick': List<Map<String, dynamic>>.of(currentTrick),
      'ledSuit': skullKingLedSuit(currentTrick),
      'lastTrick': lastTrick,
      'scores': List<int>.of(scores),
      'myHand': myHand,
      'legalCards': legal,
      'lastRoundSummary': lastRoundSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;

    if (phase == 'bid') {
      if (bids[seat] != null) return null;
      final hand = hands[seat];
      var est = 0;
      for (final c in hand) {
        if (c == 'SK' || c == 'PIR' || c == 'MER') {
          est++;
        } else if (skullKingSuit(c) == 'B' && skullKingRank(c) >= 10) {
          est++;
        }
      }
      return {'type': 'bid', 'bid': est.clamp(0, roundCards)};
    }

    if (phase == 'play') {
      if (seat != turn) return null;
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      final needMoreTricks = tricksWon[seat] < (bids[seat] ?? 0);

      // If we don't want more tricks, prefer ESC or TIG(escape) or lowest card
      if (!needMoreTricks) {
        if (legal.contains('ESC')) {
          return {'type': 'play', 'card': 'ESC'};
        }
        if (legal.contains('TIG')) {
          return {'type': 'play', 'card': 'TIG', 'mode': 'escape'};
        }
        final sortedLow = List<String>.of(legal)
          ..sort((a, b) => skullKingRank(a).compareTo(skullKingRank(b)));
        final pick = sortedLow.first;
        return {
          'type': 'play',
          'card': pick,
          if (pick == 'TIG') 'mode': 'escape',
        };
      }

      // Otherwise try to win the trick
      final pick = legal.first;
      return {
        'type': 'play',
        'card': pick,
        if (pick == 'TIG') 'mode': 'pirate',
      };
    }

    return null;
  }
}
