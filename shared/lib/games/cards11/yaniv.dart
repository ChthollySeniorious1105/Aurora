import '../../src/engine.dart';

const String yanivRules = '''
# 雅尼夫 Yaniv 规则

## 概述
雅尼夫（Yaniv）是风靡全球背包客圈子的以色列快节奏低分比拼与“反杀（Assaf）”纸牌游戏，支持 2～5 人同局较量。玩家通过组合弃牌不断压低手牌总点数，并在总点数 `<= 7` 时果断喊出 **“Yaniv!”**，但必须提防对手潜伏更低点数触发 **“Assaf!（反杀 +30 罚分）”**！

## 牌组与点数
- 使用标准 **54 张扑克牌**（含大小王 `BJ`、`RJ`）：
  - **大小王（`BJ / RJ`）**：`0` 点（且可在同花顺中充当百搭牌）
  - **A**：`1` 点
  - **2 ～ 10(`T`)**：面值 `2 ～ 10` 点
  - **J、Q、K**：均为 `10` 点

## 回合行动
每位玩家开局发 5 张手牌，牌桌翻开 1 张初始弃牌。轮到自己时必须二选一：
1. **换牌（Discard & Draw）**：
   - **先弃牌**：打出以下任意一种合法牌型：
     - **单张**：任意 1 张手牌；
     - **同点对/多张（Set）**：2 张或以上点数相同的牌（如 `7♠ 7♥` 或 `Q♠ Q♦ Q♣`）；
     - **同花顺（Run）**：3 张或以上同花色且点数连续的牌（`A-2-3` 至 `J-Q-K`，大小王 `BJ/RJ` 可充当任意百搭缺口）。
   - **再摸 1 张牌**：从**摸牌堆顶（`deck`）**或**上家刚打出的弃牌（`discard`）**中摸取 1 张牌加入手牌。
2. **宣告 `"Yaniv!"`**：
   - 当你回合开始且当前手牌总点数 **`<= 7` 点** 时，可不换牌直接宣告 **“Yaniv!”**，全员亮牌结算：
   - **成功宣告**：若你的手牌总点数 **严格低于** 场上每一位对手，你本局得 **`0` 罚分**，其余玩家各自加上其手牌点数作为罚分。
   - **ASSAF!（反杀）**：若场上 **有任何一名对手的手牌总点数 `<=` 你的点数**，即触发 **反杀（Assaf）**！宣告者不仅要加上自身手牌点数，还要额外承受 **`+30` 罚分**；而全场点数最低的对手得 **`0` 罚分**！

## 整 50 / 100 减半奖励与胜负
- **精准减半奖励（Halving Bonus）**：每局结算加分后，若某位玩家的累计罚分 **恰好停在 `50` 分或 `100` 分**，其罚分将立即减半（`50 → 25`，`100 → 50`）！
- **胜负判定**：当有玩家的累计罚分 **超过淘汰分线 `targetLimit`**（标准 `100` 分 / 快速 `60` 分）时整场游戏结束，累计罚分最低的玩家获胜！
''';

const List<String> kYanivSuits = ['S', 'H', 'D', 'C'];
const List<String> kYanivRanks = [
  'A', '2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K',
];

bool yanivIsJoker(String card) => card == 'BJ' || card == 'RJ';

String yanivRank(String card) =>
    yanivIsJoker(card) ? card : card.substring(0, card.length - 1);

String yanivSuit(String card) =>
    yanivIsJoker(card) ? '' : card[card.length - 1];

int yanivRankIndex(String rank) {
  switch (rank) {
    case 'A':
      return 1;
    case '2':
      return 2;
    case '3':
      return 3;
    case '4':
      return 4;
    case '5':
      return 5;
    case '6':
      return 6;
    case '7':
      return 7;
    case '8':
      return 8;
    case '9':
      return 9;
    case 'T':
      return 10;
    case 'J':
      return 11;
    case 'Q':
      return 12;
    case 'K':
      return 13;
    default:
      return 0;
  }
}

int yanivCardValue(String card) {
  if (yanivIsJoker(card)) return 0;
  final r = yanivRank(card);
  if (r == 'A') return 1;
  if (r == 'T' || r == 'J' || r == 'Q' || r == 'K') return 10;
  return int.tryParse(r) ?? 0;
}

int yanivHandSum(Iterable<String> cards) =>
    cards.fold<int>(0, (sum, c) => sum + yanivCardValue(c));

/// Checks if [cards] is a legal Yaniv discard:
/// - 1 single card
/// - 2+ cards of the same rank (jokers allowed as wildcards)
/// - 3+ consecutive same-suit cards (jokers allowed as wildcards in runs)
bool isValidYanivDiscard(List<String> cards) {
  if (cards.isEmpty) return false;
  if (cards.length == 1) return true;
  if (cards.toSet().length != cards.length) return false;

  final nonJokers = cards.where((c) => !yanivIsJoker(c)).toList();
  final jokers = cards.length - nonJokers.length;
  if (nonJokers.isEmpty) return true; // ['BJ', 'RJ']

  // Check same-rank set (2+ cards)
  final firstRank = yanivRank(nonJokers.first);
  if (nonJokers.every((c) => yanivRank(c) == firstRank)) {
    return true;
  }

  // Check 3+ same-suit consecutive run
  if (cards.length < 3) return false;
  final suit = yanivSuit(nonJokers.first);
  if (!nonJokers.every((c) => yanivSuit(c) == suit)) return false;

  final indices = nonJokers.map((c) => yanivRankIndex(yanivRank(c))).toList()
    ..sort();
  for (var i = 1; i < indices.length; i++) {
    if (indices[i] == indices[i - 1]) return false;
  }
  final span = indices.last - indices.first + 1;
  final neededJokers = span - nonJokers.length;
  return neededJokers <= jokers;
}

List<String> buildYanivDeck() => [
      for (final s in kYanivSuits)
        for (final r in kYanivRanks) '$r$s',
      'BJ',
      'RJ',
    ];

class YanivGame extends GameEngine {
  late int targetLimit;
  int round = 1;
  int turn = 0;

  late List<List<String>> hands;
  late List<String> deck;
  late List<String> discardPile;
  late List<String> lastDiscard;
  late List<int> scores;

  Map<String, dynamic>? lastRoundSummary;
  bool _over = false;

  YanivGame(super.setup) {
    targetLimit = setup.opt<int>('targetLimit', 100);
    scores = List.filled(players, 0);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores, lowWins: true) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    _startRound(starter: 0);
  }

  void _startRound({required int starter}) {
    final all = shuffled(buildYanivDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++) all.sublist(s * 5, (s + 1) * 5),
    ];
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
    final firstUp = all[players * 5];
    lastDiscard = [firstUp];
    discardPile = [firstUp];
    deck = all.sublist(players * 5 + 1);
    turn = starter % players;
  }

  void _sortHand(List<String> hand) {
    hand.sort((a, b) {
      final va = yanivCardValue(a);
      final vb = yanivCardValue(b);
      if (va != vb) return va.compareTo(vb);
      return a.compareTo(b);
    });
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    final type = asStr(action['type']);

    if (type == 'yaniv') {
      _handleYaniv(seat);
      return;
    }
    if (type == 'play') {
      _handlePlay(seat, action);
      return;
    }
    throw GameError('未知操作，请使用 play 或 yaniv');
  }

  void _handleYaniv(int caller) {
    final callerSum = yanivHandSum(hands[caller]);
    if (callerSum > 7) {
      throw GameError('手牌总点数必须 <= 7 才能宣告 Yaniv（当前 $callerSum 点）');
    }

    final sums = [for (var s = 0; s < players; s++) yanivHandSum(hands[s])];
    final oppSums = [
      for (var s = 0; s < players; s++)
        if (s != caller) sums[s],
    ];
    final minOppSum = oppSums.reduce((a, b) => a < b ? a : b);
    final assaf = minOppSum <= callerSum;

    final deltas = List.filled(players, 0);
    final halved = List.filled(players, false);
    final assafBy = <int>[];

    if (!assaf) {
      deltas[caller] = 0;
      for (var s = 0; s < players; s++) {
        if (s != caller) deltas[s] = sums[s];
      }
    } else {
      deltas[caller] = 30 + callerSum;
      for (var s = 0; s < players; s++) {
        if (s == caller) continue;
        if (sums[s] <= callerSum && sums[s] == minOppSum) {
          deltas[s] = 0;
          assafBy.add(s);
        } else {
          deltas[s] = sums[s];
        }
      }
    }

    for (var s = 0; s < players; s++) {
      scores[s] += deltas[s];
      if (deltas[s] > 0 && (scores[s] == 50 || scores[s] == 100)) {
        scores[s] = scores[s] ~/ 2;
        halved[s] = true;
      }
    }

    final roundWinner = assaf ? assafBy.first : caller;
    lastRoundSummary = {
      'round': round,
      'caller': caller,
      'callerSum': callerSum,
      'assaf': assaf,
      'assafBy': assafBy,
      'handSums': sums,
      'revealedHands': [for (final h in hands) List<String>.of(h)],
      'deltas': deltas,
      'halved': halved,
      'scoresAfter': List<int>.of(scores),
    };

    if (assaf) {
      host.log(
        '⚡ ASSAF 反杀！${name(caller)} 宣告 Yaniv ($callerSum 点)，'
        '被 ${assafBy.map(name).join('、')} ($minOppSum 点) 反杀罚 +${deltas[caller]} 分！',
      );
    } else {
      host.log('🎉 ${name(caller)} 成功宣告 Yaniv ($callerSum 点)，本局 0 罚分！');
    }
    for (var s = 0; s < players; s++) {
      if (halved[s]) {
        host.log('✨ ${name(s)} 精准踩中整分线，罚分减半至 ${scores[s]} 分！');
      }
    }

    if (scores.any((sc) => sc > targetLimit)) {
      _over = true;
      return;
    }

    round++;
    _startRound(starter: roundWinner);
  }

  void _handlePlay(int seat, Map<String, dynamic> action) {
    final rawCards = action['cards'];
    if (rawCards is! List || rawCards.isEmpty) {
      throw GameError('请选择至少 1 张要打出的手牌');
    }
    final cards = [for (final c in rawCards) '$c'];
    for (final c in cards) {
      if (!hands[seat].contains(c)) {
        throw GameError('你手里没有这张牌：$c');
      }
    }
    if (!isValidYanivDiscard(cards)) {
      throw GameError('弃牌组合不合法：仅限单张、同点对/多张、或 3 张以上同花顺');
    }

    final drawFrom = asStr(action['drawFrom'], 'deck');
    if (drawFrom != 'deck' && drawFrom != 'discard') {
      throw GameError('摸牌来源必须是 deck 或 discard');
    }

    String drawn;
    if (drawFrom == 'discard') {
      if (lastDiscard.isEmpty) {
        throw GameError('当前弃牌堆没有可摸的牌');
      }
      final requested = asStr(action['drawCard']);
      if (requested.isNotEmpty && lastDiscard.contains(requested)) {
        drawn = requested;
      } else {
        drawn = lastDiscard.first;
      }
      discardPile.remove(drawn);
    } else {
      if (deck.isEmpty) {
        _replenishDeck();
      }
      if (deck.isEmpty) {
        // Fallback if all cards are held
        drawn = lastDiscard.first;
      } else {
        drawn = deck.removeLast();
      }
    }

    for (final c in cards) {
      hands[seat].remove(c);
    }
    hands[seat].add(drawn);
    _sortHand(hands[seat]);

    lastDiscard = List<String>.of(cards);
    discardPile.addAll(cards);

    turn = (turn + 1) % players;
  }

  void _replenishDeck() {
    final keep = lastDiscard.toSet();
    final recycle = discardPile.where((c) => !keep.contains(c)).toList();
    if (recycle.isEmpty) return;
    discardPile = List<String>.of(lastDiscard);
    deck = shuffled(recycle, rng);
  }

  /// Enumerates all valid discard combinations from [hand], sorted by highest points shed.
  List<List<String>> bestLegalDiscards(List<String> hand) {
    final results = <List<String>>[];
    for (final c in hand) {
      results.add([c]);
    }
    // Same-rank sets
    final byRank = <String, List<String>>{};
    for (final c in hand) {
      if (yanivIsJoker(c)) continue;
      byRank.putIfAbsent(yanivRank(c), () => []).add(c);
    }
    for (final list in byRank.values) {
      if (list.length >= 2) {
        results.add(List<String>.of(list));
      }
    }
    // 3+ runs in same suit
    final jokers = hand.where(yanivIsJoker).toList();
    for (final s in kYanivSuits) {
      final suited = hand
          .where((c) => !yanivIsJoker(c) && yanivSuit(c) == s)
          .toList()
        ..sort(
          (a, b) => yanivRankIndex(yanivRank(a))
              .compareTo(yanivRankIndex(yanivRank(b))),
        );
      for (var i = 0; i < suited.length; i++) {
        for (var j = i + 1; j < suited.length; j++) {
          final slice = suited.sublist(i, j + 1);
          if (slice.length >= 3 && isValidYanivDiscard(slice)) {
            results.add(slice);
          } else if (slice.length >= 2 && jokers.isNotEmpty) {
            final withJ = [...slice, jokers.first];
            if (isValidYanivDiscard(withJ)) {
              results.add(withJ);
            }
          }
        }
      }
    }
    results.sort((a, b) => yanivHandSum(b).compareTo(yanivHandSum(a)));
    return results;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand =
        seat >= 0 && seat < players ? List<String>.of(hands[seat]) : const <String>[];
    final mySum = yanivHandSum(myHand);
    return {
      'round': round,
      'targetLimit': targetLimit,
      'turn': turn,
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'myHand': myHand,
      'mySum': mySum,
      'canYaniv': seat == turn && myHand.isNotEmpty && mySum <= 7,
      'deckCount': deck.length,
      'lastDiscard': List<String>.of(lastDiscard),
      'lastRoundSummary': lastRoundSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final h = hands[seat];
    final sum = yanivHandSum(h);
    if (sum <= 7) {
      return {'type': 'yaniv'};
    }

    final candidates = bestLegalDiscards(h);
    // Prioritize:
    // 1. Any discard that immediately brings remaining hand sum <= 5
    // 2. Multi-card discards (sets/runs of length >= 2) to shrink hand size!
    // 3. Highest point single card
    candidates.sort((a, b) {
      final remA = sum - yanivHandSum(a);
      final remB = sum - yanivHandSum(b);
      final readyA = remA <= 5 ? 1 : 0;
      final readyB = remB <= 5 ? 1 : 0;
      if (readyA != readyB) return readyB.compareTo(readyA);
      final multiA = a.length >= 2 ? 1 : 0;
      final multiB = b.length >= 2 ? 1 : 0;
      if (multiA != multiB) return multiB.compareTo(multiA);
      return yanivHandSum(b).compareTo(yanivHandSum(a));
    });

    final chosen = candidates.firstWhere(
      (combo) => combo.every((c) => !yanivIsJoker(c)),
      orElse: () => candidates.first,
    );

    final remaining = List<String>.of(h);
    for (final c in chosen) {
      remaining.remove(c);
    }

    var drawFrom = 'deck';
    String? drawCard;
    if (lastDiscard.isNotEmpty) {
      final sortedDiscard = List<String>.of(lastDiscard)
        ..sort((a, b) => yanivCardValue(a).compareTo(yanivCardValue(b)));
      final bestUp = sortedDiscard.first;
      final minDiscarded = chosen
          .map(yanivCardValue)
          .reduce((a, b) => a < b ? a : b);
      // Draw from discard if it strictly lowers card value OR pairs with a remaining card (when shedding a higher card)
      final pairsWithRemaining = !yanivIsJoker(bestUp) &&
          remaining.any((r) => !yanivIsJoker(r) && yanivRank(r) == yanivRank(bestUp));
      if (yanivCardValue(bestUp) < minDiscarded &&
          (yanivCardValue(bestUp) <= 2 ||
              (pairsWithRemaining && remaining.length >= 2))) {
        drawFrom = 'discard';
        drawCard = bestUp;
      }
    }

    return {
      'type': 'play',
      'cards': chosen,
      'drawFrom': drawFrom,
      if (drawCard != null) 'drawCard': drawCard,
    };
  }
}
