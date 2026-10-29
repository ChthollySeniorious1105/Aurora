import '../../src/engine.dart';

const String tarotRules = '''
# 法国塔罗牌 Jeu de Tarot 规则说明

## 牌组与三大关键牌（Oudlers / Bouts）
- **78 张法国塔罗标准牌组**：
  - **21 张编号主牌（Atouts / Trumps）**：`T1`（小主牌 Le Petit）至 `T21`（世界 Le Monde），编号越大牌力越强。
  - **1 张愚者（L'Excuse，`T0`）**：特殊免死百搭牌，可在任何一墩代替跟牌打出；愚者永远不会赢下该墩，但打出后直接归入**打出者自己阵营的得分牌堆**！
  - **56 张四门副牌（S/H/D/C）**：每门 14 张，从小到大依次为 `1 < 2 < ... < 9 < 10(T) < 侍从(J) < 骑士(C) < 王后(Q) < 国王(K)`。
- **三大关键牌（3 Oudlers：`T1`、`T21`、`T0`）**：
  - 庄家（Declarer）本局最终需要达到的获胜分数线，完全取决于庄家得分堆中拿到了几张关键牌（Oudlers）：
    - **0 张关键牌**：需满 **56 分**
    - **1 张关键牌**：需满 **51 分**
    - **2 张关键牌**：需满 **41 分**
    - **3 张关键牌**：需满 **36 分**
- **单牌分值（全牌组总计 91 分）**：
  - 三大关键牌（`T0, T1, T21`）与四张国王（`K`）：各 **4.5 分**
  - 王后（`Q`）：各 **3.5 分**；骑士（`C`）：各 **2.5 分**；侍从（`J`）：各 **1.5 分**
  - 其余所有数牌与普通主牌：各 **0.5 分**

## 对局流程
1. **叫牌阶段（`bid`）**：
   - 3~4 人局每人发 24/18 张牌，留 **6 张底牌（Chien）**；5 人局每人发 15 张牌，留 **3 张底牌（Chien）**。
   - 玩家按顺序叫牌竞争独庄（Declarer），其余玩家自动组成联合防守方（Defenders）：
     - `1`：**小契约（Petite，×1 倍）**——看底并换入同等张数暗扣入庄家得分堆；
     - `2`：**守护契约（Garde，×2 倍）**——看底并换入同等张数暗扣入庄家得分堆；
     - `3`：**无底守护（Garde sans，×4 倍）**——不看底牌，底牌直接归入庄家得分堆并立即开打！
2. **换底阶段（`chien`）**：
   - 小契约/守护契约下，庄家拿起底牌后，必须扣下相同张数（6 或 3 张）放入自己的得分堆。
   - **扣底铁律**：三大关键牌（`T0, T1, T21`）与国王（`K`）绝不可扣底；主牌（`T2..T20`）只有在手中没有其他可扣副牌时才允许扣底。
3. **出牌吃墩阶段（`play`）**：
   - **严格跟花与强制上打（Overtrump）**：
     - 若首引为副牌花色：有该花色必须跟出（无需强行压过）；若该副牌断门，手中若有主牌（`T1..T21`）**必须毙牌（出主牌）**，且若持有比桌面当前最高主牌更大的主牌，**必须强制上打（Overtrump）**！
     - 若首引为主牌：必须跟出主牌，且若能压过桌面最高主牌同样**必须强制上打**！
     - **愚者（`T0`）**：任何时刻均可打出；若首引打出愚者，则由第 2 位出牌者决定本墩引牌花色。
4. **小主牌终墩奖惩（Petit au Bout）**：
   - 若 `T1`（小主牌）在**最后一墩**被打出，赢下最后一墩的一方将获得 **10 × 契约倍数** 的额外加分（或扣分）！
''';

const List<String> kTarotSuits = ['S', 'H', 'D', 'C'];
const List<String> kTarotSideRanks = [
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  'T',
  'J',
  'C',
  'Q',
  'K',
];

const Set<String> kTarotOudlers = {'T0', 'T1', 'T21'};

const Map<int, String> kTarotContractNames = {
  1: '小契约 Petite (×1)',
  2: '守护契约 Garde (×2)',
  3: '无底守护 Garde sans (×4)',
};

const Map<int, int> kTarotMultipliers = {
  1: 1,
  2: 2,
  3: 4,
};

/// Build the 78-card French Tarot deck (56 side-suit cards + 21 Trumps T1..T21 + Fool T0).
List<String> buildTarotDeck() => [
      'T0',
      for (var t = 1; t <= 21; t++) 'T$t',
      for (final s in kTarotSuits)
        for (final r in kTarotSideRanks) '$r$s',
    ];

bool isTarotFool(String card) => card == 'T0';

bool isTarotTrump(String card) =>
    card.length >= 2 &&
    card.startsWith('T') &&
    card != 'T0' &&
    int.tryParse(card.substring(1)) != null;

int tarotTrumpNumber(String card) =>
    isTarotTrump(card) ? (int.tryParse(card.substring(1)) ?? 0) : 0;

bool isTarotOudler(String card) => kTarotOudlers.contains(card);

/// Returns `'FOOL'`, `'TRUMP'`, or side suit `'S'|'H'|'D'|'C'`.
String tarotCardSuit(String card) {
  if (card == 'T0') return 'FOOL';
  if (isTarotTrump(card)) return 'TRUMP';
  return card.isNotEmpty ? card[card.length - 1] : '';
}

/// Side-suit rank strength 1..14 (`1..9`, `T`=10, `J`=11, `C`=12, `Q`=13, `K`=14).
int tarotSideRank(String card) {
  if (card == 'T0' || isTarotTrump(card) || card.length < 2) return 0;
  final r = card.substring(0, card.length - 1);
  if (r == 'A') return 1;
  final idx = kTarotSideRanks.indexOf(r);
  return idx >= 0 ? idx + 1 : 0;
}

bool isTarotKing(String card) => tarotSideRank(card) == 14;

/// Point value of a card in French Tarot (deck sum = 91.0).
double tarotCardPoints(String card) {
  if (isTarotOudler(card)) return 4.5;
  final sr = tarotSideRank(card);
  if (sr == 14) return 4.5; // King
  if (sr == 13) return 3.5; // Queen
  if (sr == 12) return 2.5; // Cavalier
  if (sr == 11) return 1.5; // Jack
  return 0.5;
}

/// Dynamic point target required for Declarer based on captured Oudlers (0..3).
int tarotTargetPoints(int oudlers) {
  switch (oudlers.clamp(0, 3)) {
    case 3:
      return 36;
    case 2:
      return 41;
    case 1:
      return 51;
    default:
      return 56;
  }
}

/// Computes the legal cards from [hand] given [currentTrick] cards.
List<String> getTarotLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> currentTrick,
) {
  if (hand.isEmpty) return const [];

  // Find the first non-Fool card in the trick to determine ledSuit
  String? ledSuit;
  var maxTrump = 0;
  for (final e in currentTrick) {
    final c = '${e['card']}';
    if (c == 'T0') continue;
    final s = tarotCardSuit(c);
    ledSuit ??= s;
    if (s == 'TRUMP') {
      final t = tarotTrumpNumber(c);
      if (t > maxTrump) maxTrump = t;
    }
  }

  // If trick is empty or only The Fool has been played so far, any card may be played
  if (ledSuit == null) {
    return List<String>.of(hand);
  }

  final hasFool = hand.contains('T0');
  final nonFool = hand.where((c) => c != 'T0').toList();
  final trumps = nonFool.where(isTarotTrump).toList();
  final higherTrumps =
      trumps.where((c) => tarotTrumpNumber(c) > maxTrump).toList();

  List<String> allowed;
  if (ledSuit == 'TRUMP') {
    if (higherTrumps.isNotEmpty) {
      allowed = higherTrumps;
    } else if (trumps.isNotEmpty) {
      allowed = trumps;
    } else {
      allowed = nonFool;
    }
  } else {
    final sameSuit =
        nonFool.where((c) => tarotCardSuit(c) == ledSuit).toList();
    if (sameSuit.isNotEmpty) {
      allowed = sameSuit;
    } else if (higherTrumps.isNotEmpty) {
      allowed = higherTrumps;
    } else if (trumps.isNotEmpty) {
      allowed = trumps;
    } else {
      allowed = nonFool;
    }
  }

  if (hasFool && !allowed.contains('T0')) {
    return ['T0', ...allowed];
  }
  return allowed;
}

/// Evaluates which seat won a completed Tarot trick.
/// The Fool ('T0') never wins a trick.
int resolveTarotTrickWinner(List<Map<String, dynamic>> trick) {
  String? ledSuit;
  var bestSeat = (trick.first['seat'] as num).toInt();
  var bestTrump = 0;
  var bestSideRank = 0;

  for (final e in trick) {
    final seat = (e['seat'] as num).toInt();
    final card = '${e['card']}';
    if (card == 'T0') continue;

    final suit = tarotCardSuit(card);
    if (ledSuit == null) {
      ledSuit = suit;
      bestSeat = seat;
      if (suit == 'TRUMP') {
        bestTrump = tarotTrumpNumber(card);
      } else {
        bestSideRank = tarotSideRank(card);
      }
      continue;
    }

    if (suit == 'TRUMP') {
      final t = tarotTrumpNumber(card);
      if (t > bestTrump) {
        bestTrump = t;
        bestSeat = seat;
      }
    } else if (bestTrump == 0 && suit == ledSuit) {
      final r = tarotSideRank(card);
      if (r > bestSideRank) {
        bestSideRank = r;
        bestSeat = seat;
      }
    }
  }

  return bestSeat;
}

class TarotGame extends GameEngine {
  TarotGame(super.setup);

  late int maxRounds;
  int round = 1;
  int dealer = 0;
  int forehand = 0;
  String phase = 'bid'; // 'bid' | 'chien' | 'play'
  int turn = 0;

  int declarer = -1;
  int contractBid = 0; // 1=Petite, 2=Garde, 3=Garde sans
  int bidsDone = 0;
  List<int> playerBids = []; // -1=pass, 0=waiting, 1..3=bid

  List<List<String>> hands = [];
  List<String> chien = [];
  List<String> revealedChien = [];
  List<String> declarerCaptured = [];
  List<String> defenderCaptured = [];

  int tricksPlayed = 0;
  int totalTricks = 18;
  List<int> tricksWon = [];
  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;

  List<int> scores = [];
  Map<String, dynamic>? lastHandSummary;
  bool _over = false;

  int get chienSize => players == 5 ? 3 : 6;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 3);
    scores = List<int>.filled(players, 0);
    dealer = 0;
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildTarotDeck(), rng);
    final cSize = chienSize;
    final handSize = (78 - cSize) ~/ players;
    totalTricks = handSize;

    hands = [
      for (var s = 0; s < players; s++)
        _sortHand(deck.sublist(s * handSize, (s + 1) * handSize)),
    ];
    chien = deck.sublist(players * handSize, 78);
    revealedChien = [];
    declarerCaptured = [];
    defenderCaptured = [];

    forehand = (dealer + 1) % players;
    turn = forehand;
    phase = 'bid';
    declarer = -1;
    contractBid = 0;
    bidsDone = 0;
    playerBids = List<int>.filled(players, 0);
    tricksPlayed = 0;
    tricksWon = List<int>.filled(players, 0);
    currentTrick = [];
    lastTrick = null;

    host.log('第 $round/$maxRounds 局开始，底牌（Chien）共 $cSize 张，${name(turn)} 先手叫牌。');
  }

  List<String> _sortHand(Iterable<String> cards) {
    final list = List<String>.of(cards);
    const suitOrder = {'FOOL': 0, 'TRUMP': 1, 'S': 2, 'H': 3, 'D': 4, 'C': 5};
    list.sort((a, b) {
      final sa = suitOrder[tarotCardSuit(a)] ?? 9;
      final sb = suitOrder[tarotCardSuit(b)] ?? 9;
      if (sa != sb) return sa.compareTo(sb);
      if (sa == 1) return tarotTrumpNumber(a).compareTo(tarotTrumpNumber(b));
      return tarotSideRank(a).compareTo(tarotSideRank(b));
    });
    return list;
  }

  List<String> legalCards(int seat) {
    if (seat < 0 || seat >= players) return const [];
    return getTarotLegalCards(hands[seat], currentTrick);
  }

  /// Legal cards in `hands[declarer]` that can be discarded into the Chien.
  List<String> legalChienDiscards(int seat) {
    if (seat < 0 || seat >= players) return const [];
    final hand = hands[seat];
    // Never discard Oudlers or Kings
    final nonProtected =
        hand.where((c) => !isTarotOudler(c) && !isTarotKing(c)).toList();
    final sideCards =
        nonProtected.where((c) => !isTarotTrump(c)).toList();
    // If sufficient side-suit cards exist, Trumps cannot be discarded
    if (sideCards.length >= chienSize) {
      return sideCards;
    }
    return nonProtected;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type == 'pass') {
        playerBids[seat] = -1;
        bidsDone++;
      } else if (type == 'bid') {
        final b = asInt(action['bid'], 0);
        if (b < 1 || b > 3 || b <= contractBid) {
          throw GameError('叫牌等级必须高于当前最高契约（1..3）');
        }
        contractBid = b;
        declarer = seat;
        playerBids[seat] = b;
        bidsDone++;
        host.log('${name(seat)} 叫出「${kTarotContractNames[b]}」！');
      } else {
        throw GameError('请叫牌（bid）或不叫（pass）');
      }

      if (bidsDone >= players || contractBid == 3) {
        _finishBidding();
      } else {
        turn = (turn + 1) % players;
      }
      return;
    }

    if (phase == 'chien') {
      if (type != 'discard_chien') {
        throw GameError('请从手牌中选择 $chienSize 张牌扣入底牌');
      }
      final raw = action['cards'] ?? action['discards'];
      if (raw is! List || raw.length != chienSize) {
        throw GameError('必须准确选择 $chienSize 张牌扣底');
      }
      final discards = [for (final c in raw) '$c'];
      final tempHand = List<String>.of(hands[seat]);
      for (final c in discards) {
        if (!tempHand.remove(c)) {
          throw GameError('手牌中没有 $c');
        }
        if (isTarotOudler(c) || isTarotKing(c)) {
          throw GameError('三大关键牌（T0/T1/T21）和国王（K）不能扣入底牌');
        }
      }

      // Check Trump discard rule: can only discard trumps if no non-King side cards remain in tempHand
      final discardedTrumps = discards.where(isTarotTrump).toList();
      if (discardedTrumps.isNotEmpty) {
        final remainingLegalSide = tempHand
            .where((c) => !isTarotOudler(c) && !isTarotKing(c) && !isTarotTrump(c))
            .isNotEmpty;
        if (remainingLegalSide) {
          throw GameError('手中仍有可扣的普通副牌时，不能将主牌扣入底牌');
        }
      }

      hands[seat] = _sortHand(tempHand);
      declarerCaptured.addAll(discards);
      phase = 'play';
      turn = forehand;
      host.log('独庄 ${name(declarer)} 完成扣底，由 ${name(turn)} 首引第 1 墩！');
      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请出牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('手牌中没有 $card');
      }
      final legal = legalCards(seat);
      if (!legal.contains(card)) {
        throw GameError('违反法国塔罗跟牌/强制毙牌/强制上打规则：$card');
      }

      hands[seat].remove(card);
      currentTrick.add({'seat': seat, 'card': card});

      if (currentTrick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      _resolveTrick();
      return;
    }

    throw GameError('未知阶段: $phase');
  }

  void _finishBidding() {
    if (declarer == -1) {
      // If everyone passed, forehand takes Petite (1) so the round plays out
      declarer = forehand;
      contractBid = 1;
      playerBids[declarer] = 1;
      host.log('全员不叫，由先手 ${name(declarer)} 默认担任小契约（Petite）独庄。');
    }

    if (contractBid == 3) {
      // Garde sans: Chien goes directly to Declarer's score pile unseen
      declarerCaptured.addAll(chien);
      chien.clear();
      phase = 'play';
      turn = forehand;
      host.log('${name(declarer)} 定约「无底守护 Garde sans ×4」，不看底牌直接开打！');
    } else {
      revealedChien = List<String>.of(chien);
      hands[declarer] = _sortHand([...hands[declarer], ...chien]);
      chien.clear();
      phase = 'chien';
      turn = declarer;
      host.log('${name(declarer)} 拿起 ${revealedChien.length} 张底牌，请扣下 ${revealedChien.length} 张牌。');
    }
  }

  void _resolveTrick() {
    final winner = resolveTarotTrickWinner(currentTrick);
    tricksPlayed++;
    tricksWon[winner]++;

    final isLastTrick = tricksPlayed >= totalTricks;
    var petitPlayed = false;

    for (final e in currentTrick) {
      final s = (e['seat'] as num).toInt();
      final c = '${e['card']}';
      if (c == 'T1') petitPlayed = true;
      if (c == 'T0') {
        // The Fool stays in its owner's score pile!
        if (s == declarer) {
          declarerCaptured.add(c);
        } else {
          defenderCaptured.add(c);
        }
      } else {
        if (winner == declarer) {
          declarerCaptured.add(c);
        } else {
          defenderCaptured.add(c);
        }
      }
    }

    lastTrick = {
      'winner': winner,
      'cards': List<Map<String, dynamic>>.of(currentTrick),
      'petitPlayed': petitPlayed,
    };
    currentTrick = [];

    if (isLastTrick) {
      _scoreHand(lastTrickWinner: winner, petitOnLastTrick: petitPlayed);
    } else {
      turn = winner;
    }
  }

  void _scoreHand({
    required int lastTrickWinner,
    required bool petitOnLastTrick,
  }) {
    final oudlers = declarerCaptured.where(isTarotOudler).toList();
    final oudlerCount = oudlers.length;
    final target = tarotTargetPoints(oudlerCount);
    final declPts =
        declarerCaptured.fold<double>(0, (s, c) => s + tarotCardPoints(c));
    final defPts =
        defenderCaptured.fold<double>(0, (s, c) => s + tarotCardPoints(c));

    final diff = declPts - target;
    final declarerWon = diff >= 0;
    final mult = kTarotMultipliers[contractBid] ?? 1;

    var petitBonus = 0;
    if (petitOnLastTrick) {
      petitBonus = (lastTrickWinner == declarer ? 10 : -10) * mult;
    }

    final baseContract =
        (25 + diff.abs().round()) * mult * (declarerWon ? 1 : -1) + petitBonus;

    final deltas = List<int>.filled(players, 0);
    for (var s = 0; s < players; s++) {
      if (s == declarer) {
        deltas[s] = baseContract * (players - 1);
      } else {
        deltas[s] = -baseContract;
      }
      scores[s] += deltas[s];
    }

    lastHandSummary = {
      'round': round,
      'declarer': declarer,
      'contractBid': contractBid,
      'oudlerCount': oudlerCount,
      'oudlers': oudlers,
      'targetPoints': target,
      'declarerPoints': declPts,
      'defenderPoints': defPts,
      'declarerWon': declarerWon,
      'petitBonus': petitBonus,
      'baseContract': baseContract,
      'deltas': deltas,
    };

    host.log(
      '第 $round 局结算：独庄 ${name(declarer)} 抓到 $oudlerCount 张关键牌（目标 $target 分），'
      '实得 ${declPts.toStringAsFixed(1)} 分，${declarerWon ? '定约成功' : '定约失败'}（独庄 ${deltas[declarer] >= 0 ? '+${deltas[declarer]}' : deltas[declarer]} 分）！',
    );

    if (round >= maxRounds) {
      _over = true;
      return;
    }

    round++;
    dealer = (dealer + 1) % players;
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
    final legalDiscards =
        (seat >= 0 && seat < players && phase == 'chien' && seat == turn)
            ? legalChienDiscards(seat)
            : const <String>[];

    final declOudlers = declarerCaptured.where(isTarotOudler).toList();
    final declPts =
        declarerCaptured.fold<double>(0, (s, c) => s + tarotCardPoints(c));

    return {
      'round': round,
      'maxRounds': maxRounds,
      'dealer': dealer,
      'forehand': forehand,
      'phase': phase,
      'turn': turn,
      'declarer': declarer,
      'contractBid': contractBid,
      'playerBids': List<int>.of(playerBids),
      'chienSize': chienSize,
      'revealedChien': List<String>.of(revealedChien),
      'tricksPlayed': tricksPlayed,
      'totalTricks': totalTricks,
      'tricksWon': List<int>.of(tricksWon),
      'declarerPoints': declPts,
      'declarerOudlers': declOudlers,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'currentTrick': List<Map<String, dynamic>>.of(currentTrick),
      'lastTrick': lastTrick,
      'scores': List<int>.of(scores),
      'myHand': myHand,
      'legalCards': legal,
      'legalDiscards': legalDiscards,
      'lastHandSummary': lastHandSummary,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      final hand = hands[seat];
      final oudlers = hand.where(isTarotOudler).length;
      final trumps = hand.where(isTarotTrump).length;
      var desired = 0;
      if (oudlers >= 2 && trumps >= 7) {
        desired = 2;
      } else if (oudlers >= 1 && trumps >= 5) {
        desired = 1;
      }
      if (desired > contractBid) {
        return {'type': 'bid', 'bid': desired};
      }
      return {'type': 'pass'};
    }

    if (phase == 'chien') {
      final candidates = List<String>.of(legalChienDiscards(seat));
      // Sort low point / non-trump cards first to discard into Chien
      candidates.sort((a, b) {
        final ta = isTarotTrump(a) ? 1 : 0;
        final tb = isTarotTrump(b) ? 1 : 0;
        if (ta != tb) return ta.compareTo(tb);
        return tarotSideRank(a).compareTo(tarotSideRank(b));
      });
      return {
        'type': 'discard_chien',
        'cards': candidates.take(chienSize).toList(),
      };
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      // Avoid playing T0 unless forced or last tricks, and protect T1 if unsafe
      final nonFool = legal.where((c) => c != 'T0').toList();
      final pool = nonFool.isNotEmpty ? nonFool : legal;
      if (botLevel == 0) {
        return {'type': 'play', 'card': pool[rng.nextInt(pool.length)]};
      }
      final sorted = List<String>.of(pool)
        ..sort((a, b) => tarotCardPoints(a).compareTo(tarotCardPoints(b)));
      return {'type': 'play', 'card': sorted.first};
    }

    return null;
  }
}
