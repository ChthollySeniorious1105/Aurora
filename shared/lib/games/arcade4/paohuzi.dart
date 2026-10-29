import '../../src/engine.dart';

/// All 20 Zipai card types: s1..s10 (小写一..十), b1..b10 (大写壹..拾).
const List<String> phzAllTypes = [
  's1', 's2', 's3', 's4', 's5', 's6', 's7', 's8', 's9', 's10',
  'b1', 'b2', 'b3', 'b4', 'b5', 'b6', 'b7', 'b8', 'b9', 'b10',
];

const List<String> _smallLabels = ['一', '二', '三', '四', '五', '六', '七', '八', '九', '十'];
const List<String> _bigLabels = ['壹', '贰', '叁', '肆', '伍', '陆', '柒', '捌', '玖', '拾'];

bool isBigCard(String code) => code.startsWith('b');

int cardRank(String code) => int.tryParse(code.length > 1 ? code.substring(1) : '') ?? 0;

/// Red characters (红字): 二/七/十 (s2, s7, s10) and 贰/柒/拾 (b2, b7, b10).
bool isRedCard(String code) {
  final r = cardRank(code);
  return r == 2 || r == 7 || r == 10;
}

int cardIndex(String code) {
  final r = cardRank(code);
  if (r < 1 || r > 10) return -1;
  return isBigCard(code) ? (10 + r - 1) : (r - 1);
}

String codeFromIndex(int idx) => idx < 10 ? 's${idx + 1}' : 'b${idx - 9}';

String cardLabel(String code) {
  final r = cardRank(code);
  if (r < 1 || r > 10) return code;
  return isBigCard(code) ? _bigLabels[r - 1] : _smallLabels[r - 1];
}

class PhzMeld {
  final String type; // 'ti', 'wei', 'pao', 'peng', 'chi', 'kan', 'jiang'
  final List<String> cards;
  final int huxi;

  const PhzMeld(this.type, this.cards, this.huxi);

  Map<String, dynamic> toJson({bool hideCards = false}) => {
        'type': type,
        'cards': hideCards ? [for (var i = 0; i < cards.length; i++) 'back'] : cards,
        'huxi': huxi,
      };
}

/// 跑胡子 / 字牌 (Paohuzi) — 3-player 80-card traditional Chinese Zipai engine.
class Paohuzi extends GameEngine {
  late final int minHuxi;
  late final int totalRounds;

  int round = 1;
  int dealer = 0;
  int turn = 0;

  /// Phases:
  /// - `'discard'`: `turn` must discard a card from hand (or declare initial `hu` if dealer has 天胡).
  /// - `'claim'`: an `activeCard` is on the table (either discarded or drawn from wall) and one or more seats may claim `hu`, `pao`, `peng`, `chi`, or `pass`.
  /// - `'roundEnd'`: interim settlement between rounds; waiting for players to send `nextRound`.
  String phase = 'discard';

  List<String> wall = [];
  late List<List<String>> hands;
  late List<List<PhzMeld>> melds;
  late List<List<String>> discards;
  late List<int> scores;

  String? activeCard;
  int activeFrom = -1;
  String activeSource = ''; // 'discard' or 'draw'

  /// Per-seat available claim actions during `'claim'` phase:
  /// `{seat: {'hu': bool, 'pao': bool, 'peng': bool, 'chi': List<List<String>>}}`
  final Map<int, Map<String, dynamic>> claimOptions = {};

  /// Per-seat chosen claim action during `'claim'` phase before resolution.
  final Map<int, Map<String, dynamic>> chosenClaims = {};

  final Set<int> readyNext = {};
  Map<String, dynamic>? lastRoundResult;
  String statusText = '';

  bool _over = false;
  List<int>? _placings;

  Paohuzi(super.setup) {
    minHuxi = setup.opt<int>('minHuxi', 15);
    totalRounds = setup.opt<int>('rounds', 4);
  }

  @override
  int get botDelayMs => 400;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  bool get canResign => true;

  @override
  void start() {
    scores = List.filled(players, 0);
    round = 1;
    dealer = 0;
    _startRound();
  }

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('当前无法认输');
    scores[seat] -= 30;
    for (var s = 0; s < players; s++) {
      if (s != seat) scores[s] += 15;
    }
    _over = true;
    _placings = rankByScore(scores);
    statusText = '${name(seat)} 认输，牌局结束！';
    host.log(statusText);
  }

  /// Build and shuffle the 80-card Zipai deck.
  List<String> buildDeck() {
    final deck = <String>[];
    for (final t in phzAllTypes) {
      for (var k = 0; k < 4; k++) {
        deck.add(t);
      }
    }
    return shuffled(deck, rng);
  }

  void _startRound() {
    final deck = buildDeck();
    hands = List.generate(players, (_) => <String>[]);
    melds = List.generate(players, (_) => <PhzMeld>[]);
    discards = List.generate(players, (_) => <String>[]);
    claimOptions.clear();
    chosenClaims.clear();
    readyNext.clear();
    activeCard = null;
    activeFrom = -1;
    activeSource = '';

    var cursor = 0;
    for (var s = 0; s < players; s++) {
      final count = s == dealer ? 21 : 20;
      hands[s].addAll(deck.sublist(cursor, cursor + count));
      cursor += count;
      _extractInitialTi(s);
      _sortHand(hands[s]);
    }
    wall = deck.sublist(cursor); // 19 cards

    turn = dealer;
    phase = 'discard';
    statusText = '第 $round/$totalRounds 局：庄家 ${name(dealer)} 先出牌';
    host.log('第 $round 局开始，${name(dealer)} 坐庄（底牌 ${wall.length} 张）。');
  }

  /// Extract any 4-of-a-kind dealt initially into a `ti` meld.
  void _extractInitialTi(int seat) {
    final counts = <String, int>{};
    for (final c in hands[seat]) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      if (entry.value == 4) {
        final code = entry.key;
        hands[seat].removeWhere((c) => c == code);
        final hx = computeMeldHuxi('ti', [code, code, code, code]);
        melds[seat].add(PhzMeld('ti', [code, code, code, code], hx));
      }
    }
  }

  static void _sortHand(List<String> hand) {
    hand.sort((a, b) => cardIndex(a).compareTo(cardIndex(b)));
  }

  /// Calculate HuXi (胡息) of a meld.
  static int computeMeldHuxi(String type, List<String> cards) {
    if (cards.isEmpty) return 0;
    final big = isBigCard(cards.first);
    switch (type) {
      case 'ti':
        return big ? 12 : 9;
      case 'pao':
        return big ? 9 : 6;
      case 'wei':
      case 'kan':
        return big ? 6 : 3;
      case 'peng':
        return big ? 3 : 1;
      case 'chi':
        if (cards.length != 3) return 0;
        final b0 = isBigCard(cards[0]);
        final b1 = isBigCard(cards[1]);
        final b2 = isBigCard(cards[2]);
        if (b0 != b1 || b1 != b2) {
          // Mixed-case Jiao (绞牌) has 0 HuXi
          return 0;
        }
        final ranks = [cardRank(cards[0]), cardRank(cards[1]), cardRank(cards[2])]..sort();
        if (ranks[0] == 1 && ranks[1] == 2 && ranks[2] == 3) {
          return b0 ? 6 : 3;
        }
        if (ranks[0] == 2 && ranks[1] == 7 && ranks[2] == 10) {
          return b0 ? 6 : 3;
        }
        return 0;
      default:
        return 0;
    }
  }

  /// Validate whether 3 cards form a legal `chi` meld (sequence, 2-7-10, or mixed-case Jiao).
  static bool isValidChiMeld(List<String> cards) {
    if (cards.length != 3) return false;
    final r0 = cardRank(cards[0]);
    final r1 = cardRank(cards[1]);
    final r2 = cardRank(cards[2]);
    if (r0 < 1 || r1 < 1 || r2 < 1) return false;
    final b0 = isBigCard(cards[0]);
    final b1 = isBigCard(cards[1]);
    final b2 = isBigCard(cards[2]);

    if (b0 == b1 && b1 == b2) {
      final ranks = [r0, r1, r2]..sort();
      if (ranks[0] + 1 == ranks[1] && ranks[1] + 1 == ranks[2]) return true;
      if (ranks[0] == 2 && ranks[1] == 7 && ranks[2] == 10) return true;
      return false;
    } else {
      // Mixed-case Jiao (绞牌): all 3 must share the exact same rank (2 small + 1 big or 2 big + 1 small)
      return r0 == r1 && r1 == r2;
    }
  }

  /// Find all legal 2-card combinations `[c1, c2]` from `hand` (excluding 3-of-a-kind Kan)
  /// that form a valid Chi meld with `targetCard`.
  static List<List<String>> findChiCombinations(List<String> hand, String targetCard) {
    final counts = List.filled(20, 0);
    for (final c in hand) {
      final idx = cardIndex(c);
      if (idx >= 0) counts[idx]++;
    }
    // 3-of-a-kind in hand (坎) cannot be broken for Chi
    for (var i = 0; i < 20; i++) {
      if (counts[i] >= 3) counts[i] = 0;
    }

    final tIdx = cardIndex(targetCard);
    if (tIdx < 0) return const [];
    final big = tIdx >= 10;
    final base = big ? 10 : 0;
    final r = (tIdx % 10) + 1;

    final out = <List<String>>[];
    final seen = <String>{};

    void addCombo(int idxA, int idxB) {
      if (idxA < 0 || idxA >= 20 || idxB < 0 || idxB >= 20) return;
      if (idxA == idxB) {
        if (counts[idxA] < 2) return;
      } else {
        if (counts[idxA] < 1 || counts[idxB] < 1) return;
      }
      final a = codeFromIndex(idxA);
      final b = codeFromIndex(idxB);
      final pair = [a, b]..sort((x, y) => cardIndex(x).compareTo(cardIndex(y)));
      final key = '${pair[0]},${pair[1]}';
      if (seen.add(key)) {
        out.add(pair);
      }
    }

    // 1. Consecutive same-case sequences: (r-2, r-1), (r-1, r+1), (r+1, r+2)
    if (r >= 3) addCombo(base + r - 3, base + r - 2);
    if (r >= 2 && r <= 9) addCombo(base + r - 2, base + r);
    if (r <= 8) addCombo(base + r, base + r + 1);

    // 2. 2-7-10 same-case sequence
    if (r == 2) addCombo(base + 6, base + 9);
    if (r == 7) addCombo(base + 1, base + 9);
    if (r == 10) addCombo(base + 1, base + 6);

    // 3. Mixed-case Jiao (绞牌) of same rank `r`
    final sameIdx = base + (r - 1);
    final oppIdx = (big ? 0 : 10) + (r - 1);
    // 2 of opposite case + targetCard
    addCombo(oppIdx, oppIdx);
    // 1 of same case + 1 of opposite case + targetCard
    addCombo(sameIdx, oppIdx);

    return out;
  }

  /// Exposed HuXi for `seat`.
  int exposedHuxi(int seat) => melds[seat].fold(0, (s, m) => s + m.huxi);

  /// Check if `exposedMelds` + `hand` (+ optional `claimCard`) can form a winning hand
  /// with total HuXi >= `minHuxi`.
  /// Returns `(totalHuxi, fullMeldList)` if winnable, or `null` if not.
  static (int, List<PhzMeld>)? findWinningSolution(
    List<PhzMeld> exposedMelds,
    List<String> hand, {
    String? claimCard,
    bool selfDrawn = true,
    int minHuxi = 15,
  }) {
    final workingExposed = List<PhzMeld>.of(exposedMelds);
    final counts = List.filled(20, 0);
    for (final c in hand) {
      final idx = cardIndex(c);
      if (idx >= 0) counts[idx]++;
    }

    var claimIdx = -1;
    if (claimCard != null) {
      claimIdx = cardIndex(claimCard);
      if (claimIdx >= 0) {
        // Check if claimCard upgrades an existing exposed Wei or Peng
        final upgradeIdx = workingExposed.indexWhere(
          (m) => (m.type == 'wei' || m.type == 'peng') && m.cards.isNotEmpty && m.cards.first == claimCard,
        );
        if (upgradeIdx >= 0) {
          final old = workingExposed[upgradeIdx];
          final newType = (old.type == 'wei' && selfDrawn) ? 'ti' : 'pao';
          final newCards = [claimCard, claimCard, claimCard, claimCard];
          workingExposed[upgradeIdx] = PhzMeld(newType, newCards, computeMeldHuxi(newType, newCards));
          claimIdx = -1; // consumed into exposed meld
        } else {
          counts[claimIdx]++;
        }
      }
    }

    final totalRem = counts.fold(0, (a, b) => a + b);
    // Remaining cards after any 4-card melds must be either 3*k (no pair) or 3*k + 2 (1 pair)
    final baseHuxi = workingExposed.fold(0, (s, m) => s + m.huxi);

    (int, List<PhzMeld>)? best;

    void search(int startIdx, bool usedPair, int currentHuxi, List<PhzMeld> built) {
      var idx = startIdx;
      while (idx < 20 && counts[idx] == 0) {
        idx++;
      }
      if (idx >= 20) {
        final allMelds = [...workingExposed, ...built];
        // A valid winning hand has at least 6 melds (or 7 groups including pair) and >= minHuxi
        if (currentHuxi >= minHuxi && allMelds.length >= 6) {
          if (best == null || currentHuxi > best!.$1) {
            best = (currentHuxi, allMelds);
          }
        }
        return;
      }

      final code = codeFromIndex(idx);
      final big = idx >= 10;
      final base = big ? 10 : 0;
      final r = (idx % 10) + 1;

      // 1. 4-of-a-kind (Ti or Pao)
      if (counts[idx] == 4) {
        counts[idx] -= 4;
        final mType = (claimIdx == idx && !selfDrawn) ? 'pao' : 'ti';
        final cards = [code, code, code, code];
        final hx = computeMeldHuxi(mType, cards);
        built.add(PhzMeld(mType, cards, hx));
        search(idx, usedPair, currentHuxi + hx, built);
        built.removeLast();
        counts[idx] += 4;
      }

      // 2. 3-of-a-kind (Kan / Wei / Peng)
      if (counts[idx] >= 3) {
        counts[idx] -= 3;
        final mType = (claimIdx == idx && !selfDrawn) ? 'peng' : 'kan';
        final cards = [code, code, code];
        final hx = computeMeldHuxi(mType, cards);
        built.add(PhzMeld(mType, cards, hx));
        search(idx, usedPair, currentHuxi + hx, built);
        built.removeLast();
        counts[idx] += 3;
      }

      // 3. Pair (Jiang / 眼) when needed
      if (!usedPair && counts[idx] >= 2) {
        counts[idx] -= 2;
        built.add(PhzMeld('jiang', [code, code], 0));
        search(idx, true, currentHuxi, built);
        built.removeLast();
        counts[idx] += 2;
      }

      // 4. 1-2-3 sequence
      if (r == 1 && counts[base + 1] > 0 && counts[base + 2] > 0) {
        counts[idx]--;
        counts[base + 1]--;
        counts[base + 2]--;
        final cards = [codeFromIndex(idx), codeFromIndex(base + 1), codeFromIndex(base + 2)];
        final hx = computeMeldHuxi('chi', cards);
        built.add(PhzMeld('chi', cards, hx));
        search(idx, usedPair, currentHuxi + hx, built);
        built.removeLast();
        counts[idx]++;
        counts[base + 1]++;
        counts[base + 2]++;
      }

      // 5. 2-7-10 sequence
      if (r == 2 && counts[base + 6] > 0 && counts[base + 9] > 0) {
        counts[idx]--;
        counts[base + 6]--;
        counts[base + 9]--;
        final cards = [codeFromIndex(idx), codeFromIndex(base + 6), codeFromIndex(base + 9)];
        final hx = computeMeldHuxi('chi', cards);
        built.add(PhzMeld('chi', cards, hx));
        search(idx, usedPair, currentHuxi + hx, built);
        built.removeLast();
        counts[idx]++;
        counts[base + 6]++;
        counts[base + 9]++;
      }

      // 6. Other consecutive sequence (r, r+1, r+2) for r >= 2..8
      if (r >= 2 && r <= 8 && counts[idx + 1] > 0 && counts[idx + 2] > 0) {
        counts[idx]--;
        counts[idx + 1]--;
        counts[idx + 2]--;
        final cards = [codeFromIndex(idx), codeFromIndex(idx + 1), codeFromIndex(idx + 2)];
        built.add(PhzMeld('chi', cards, 0));
        search(idx, usedPair, currentHuxi, built);
        built.removeLast();
        counts[idx]++;
        counts[idx + 1]++;
        counts[idx + 2]++;
      }

      // 7. Mixed-case Jiao (绞牌): same rank with small + big
      if (!big) {
        final bigIdx = idx + 10;
        if (counts[idx] >= 2 && counts[bigIdx] >= 1) {
          counts[idx] -= 2;
          counts[bigIdx] -= 1;
          final bCode = codeFromIndex(bigIdx);
          built.add(PhzMeld('chi', [code, code, bCode], 0));
          search(idx, usedPair, currentHuxi, built);
          built.removeLast();
          counts[idx] += 2;
          counts[bigIdx] += 1;
        }
        if (counts[idx] >= 1 && counts[bigIdx] >= 2) {
          counts[idx] -= 1;
          counts[bigIdx] -= 2;
          final bCode = codeFromIndex(bigIdx);
          built.add(PhzMeld('chi', [code, bCode, bCode], 0));
          search(idx, usedPair, currentHuxi, built);
          built.removeLast();
          counts[idx] += 1;
          counts[bigIdx] += 2;
        }
      }
    }

    // Check whether a pair is allowed (either totalRem % 3 == 2, or a 4-card meld is in hand)
    final hasFourInHand = counts.any((c) => c == 4);
    final allowPair = (totalRem % 3 == 2) || hasFourInHand;
    search(0, !allowPair, baseHuxi, []);
    return best;
  }

  /// Cards in `hand` that are legal to discard (3-of-a-kind Kan cannot be discarded unless all cards are in Kan).
  static List<String> discardableCards(List<String> hand) {
    final counts = <String, int>{};
    for (final c in hand) {
      counts[c] = (counts[c] ?? 0) + 1;
    }
    final nonKan = [for (final c in hand) if ((counts[c] ?? 0) < 3) c];
    return nonKan.isNotEmpty ? nonKan : List<String>.of(hand);
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'roundEnd') {
      return [for (var s = 0; s < players; s++) if (!readyNext.contains(s)) s];
    }
    if (phase == 'discard') {
      return [turn];
    }
    if (phase == 'claim') {
      return [
        for (final s in claimOptions.keys)
          if (!chosenClaims.containsKey(s)) s,
      ];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'roundEnd') {
      if (type != 'nextRound') throw GameError('请点击继续进入下一局');
      readyNext.add(seat);
      if (readyNext.length >= players) {
        round++;
        if (round > totalRounds) {
          _over = true;
          _placings = rankByScore(scores);
        } else {
          _startRound();
        }
      }
      return;
    }

    if (phase == 'discard') {
      if (seat != turn) throw GameError('还没轮到你出牌');
      if (type == 'hu') {
        final sol = findWinningSolution(melds[seat], hands[seat], selfDrawn: true, minHuxi: minHuxi);
        if (sol == null) throw GameError('当前手牌未达到胡牌条件（需至少 $minHuxi 胡息）');
        _settleHu(seat, sol.$1, sol.$2, selfDrawn: true);
        return;
      }
      if (type != 'discard') throw GameError('请出一张手牌');
      final card = asStr(action['card']);
      final allowed = discardableCards(hands[seat]);
      if (!allowed.contains(card)) {
        throw GameError(hands[seat].contains(card) ? '坎牌（三张相同）不可拆开打出' : '手牌中没有这张牌');
      }
      hands[seat].remove(card);
      activeCard = card;
      activeFrom = seat;
      activeSource = 'discard';
      statusText = '${name(seat)} 打出 ${cardLabel(card)}';
      _openClaimWindowForCard(card, fromSeat: seat, isSelfDraw: false);
      return;
    }

    if (phase == 'claim') {
      final opts = claimOptions[seat];
      if (opts == null || chosenClaims.containsKey(seat)) {
        throw GameError('当前无需你响应');
      }
      if (type == 'pass') {
        chosenClaims[seat] = {'type': 'pass'};
      } else if (type == 'hu') {
        if (opts['hu'] != true) throw GameError('当前无法胡牌');
        chosenClaims[seat] = {'type': 'hu'};
      } else if (type == 'pao') {
        if (opts['pao'] != true) throw GameError('当前无法跑牌');
        chosenClaims[seat] = {'type': 'pao'};
      } else if (type == 'peng') {
        if (opts['peng'] != true) throw GameError('当前无法碰牌');
        chosenClaims[seat] = {'type': 'peng'};
      } else if (type == 'chi') {
        final chiList = (opts['chi'] as List?)?.cast<List<String>>() ?? const [];
        if (chiList.isEmpty) throw GameError('当前无法吃牌');
        final rawCards = action['cards'];
        List<String> picked;
        if (rawCards is List && rawCards.length == 2) {
          picked = [asStr(rawCards[0]), asStr(rawCards[1])]
            ..sort((a, b) => cardIndex(a).compareTo(cardIndex(b)));
          final match = chiList.any((pair) => pair[0] == picked[0] && pair[1] == picked[1]);
          if (!match) throw GameError('所选吃牌组合无效');
        } else {
          picked = chiList.first;
        }
        chosenClaims[seat] = {'type': 'chi', 'cards': picked};
      } else {
        throw GameError('未知响应类型');
      }

      _tryResolveClaims();
      return;
    }

    throw GameError('当前阶段无法执行此操作');
  }

  void _openClaimWindowForCard(String card, {required int fromSeat, required bool isSelfDraw}) {
    claimOptions.clear();
    chosenClaims.clear();

    // If self-drawn from wall, check mandatory Ti / Wei for `fromSeat` first (unless they can Hu)
    if (isSelfDraw) {
      final inHandCount = hands[fromSeat].where((c) => c == card).length;
      final hasWeiIdx = melds[fromSeat].indexWhere((m) => m.type == 'wei' && m.cards.first == card);
      if (inHandCount == 3 || hasWeiIdx >= 0) {
        // Automatic Ti (提)!
        if (hasWeiIdx >= 0) {
          melds[fromSeat].removeAt(hasWeiIdx);
        } else {
          hands[fromSeat].removeWhere((c) => c == card);
        }
        final hx = computeMeldHuxi('ti', [card, card, card, card]);
        melds[fromSeat].add(PhzMeld('ti', [card, card, card, card], hx));
        activeCard = null;
        statusText = '${name(fromSeat)} 摸牌提 ${cardLabel(card)}（+$hx 胡）';
        host.log(statusText);
        // Check if after Ti they can immediately Hu or need to discard
        _afterMeldAction(fromSeat, isFourCardMeld: true);
        return;
      }
      if (inHandCount == 2) {
        // Automatic Wei (偎)!
        hands[fromSeat].removeWhere((c) => c == card);
        final hx = computeMeldHuxi('wei', [card, card, card]);
        melds[fromSeat].add(PhzMeld('wei', [card, card, card], hx));
        activeCard = null;
        statusText = '${name(fromSeat)} 摸牌偎 ${cardLabel(card)}（+$hx 胡）';
        host.log(statusText);
        _afterMeldAction(fromSeat, isFourCardMeld: false);
        return;
      }
    }

    // Build claim options for all seats in turn order starting from `fromSeat`
    for (var offset = 0; offset < players; offset++) {
      final s = (fromSeat + offset) % players;
      final canHu = findWinningSolution(
            melds[s],
            hands[s],
            claimCard: card,
            selfDrawn: isSelfDraw && s == fromSeat,
            minHuxi: minHuxi,
          ) !=
          null;

      final inHand = hands[s].where((c) => c == card).length;
      final hasWei = melds[s].any((m) => m.type == 'wei' && m.cards.first == card);
      final hasPeng = melds[s].any((m) => m.type == 'peng' && m.cards.first == card);

      // Pao: 3 in hand or exposed Wei (any source), or exposed Peng (when drawn from wall)
      final canPao = (s != fromSeat && (inHand == 3 || hasWei)) ||
          (isSelfDraw && (inHand == 3 || hasWei || hasPeng));

      // Peng: 2 in hand (from opponent discard or drawn card)
      final canPeng = (s != fromSeat || isSelfDraw) && inHand == 2 && !(isSelfDraw && s == fromSeat);

      // Chi: allowed for `fromSeat` (if self-drawn) or `(fromSeat + 1) % players` (下家)
      final canChiSeat = (isSelfDraw && s == fromSeat) || s == (fromSeat + 1) % players;
      final chiCombos = canChiSeat ? findChiCombinations(hands[s], card) : const <List<String>>[];

      if (canHu || canPao || canPeng || chiCombos.isNotEmpty) {
        claimOptions[s] = {
          'hu': canHu,
          'pao': canPao,
          'peng': canPeng,
          'chi': chiCombos,
        };
      }
    }

    if (claimOptions.isEmpty) {
      // Nobody can claim this card -> goes to discard pile and next player draws from wall
      discards[fromSeat].add(card);
      activeCard = null;
      _drawNextFromWall((fromSeat + 1) % players);
      return;
    }

    phase = 'claim';
  }

  void _tryResolveClaims() {
    if (chosenClaims.length < claimOptions.length) {
      // Check if the highest-priority remaining unclaimed option is strictly lower than an already chosen Hu
      return;
    }

    final card = activeCard!;
    final fromSeat = activeFrom;
    final isSelfDraw = activeSource == 'draw';

    int priorityOf(String t) => switch (t) {
          'hu' => 4,
          'pao' => 3,
          'peng' => 2,
          'chi' => 1,
          _ => 0,
        };

    var bestSeat = -1;
    var bestPrio = 0;
    Map<String, dynamic>? bestAction;
    for (var offset = 0; offset < players; offset++) {
      final s = (fromSeat + offset) % players;
      final c = chosenClaims[s];
      if (c == null) continue;
      final p = priorityOf(asStr(c['type']));
      if (p > bestPrio) {
        bestPrio = p;
        bestSeat = s;
        bestAction = c;
      }
    }

    claimOptions.clear();
    chosenClaims.clear();

    if (bestSeat < 0 || bestPrio == 0) {
      // Everyone passed
      discards[fromSeat].add(card);
      activeCard = null;
      _drawNextFromWall((fromSeat + 1) % players);
      return;
    }

    // Execute the winning claim for `bestSeat`
    if (bestPrio == 4) {
      // Hu!
      final sol = findWinningSolution(
        melds[bestSeat],
        hands[bestSeat],
        claimCard: card,
        selfDrawn: isSelfDraw && bestSeat == fromSeat,
        minHuxi: minHuxi,
      )!;
      activeCard = null;
      _settleHu(bestSeat, sol.$1, sol.$2, selfDrawn: isSelfDraw && bestSeat == fromSeat);
      return;
    }

    if (bestPrio == 3) {
      // Pao!
      final weiOrPengIdx = melds[bestSeat].indexWhere(
        (m) => (m.type == 'wei' || m.type == 'peng') && m.cards.first == card,
      );
      if (weiOrPengIdx >= 0) {
        melds[bestSeat].removeAt(weiOrPengIdx);
      } else {
        hands[bestSeat].removeWhere((c) => c == card);
      }
      final hx = computeMeldHuxi('pao', [card, card, card, card]);
      melds[bestSeat].add(PhzMeld('pao', [card, card, card, card], hx));
      activeCard = null;
      statusText = '${name(bestSeat)} 跑 ${cardLabel(card)}（+$hx 胡）';
      host.log(statusText);
      _afterMeldAction(bestSeat, isFourCardMeld: true);
      return;
    }

    if (bestPrio == 2) {
      // Peng!
      var removed = 0;
      hands[bestSeat].removeWhere((c) => c == card && ++removed <= 2);
      final hx = computeMeldHuxi('peng', [card, card, card]);
      melds[bestSeat].add(PhzMeld('peng', [card, card, card], hx));
      activeCard = null;
      statusText = '${name(bestSeat)} 碰 ${cardLabel(card)}（+$hx 胡）';
      host.log(statusText);
      _afterMeldAction(bestSeat, isFourCardMeld: false);
      return;
    }

    if (bestPrio == 1 && bestAction != null) {
      // Chi!
      final pair = (bestAction['cards'] as List).cast<String>();
      for (final c in pair) {
        final idx = hands[bestSeat].indexOf(c);
        if (idx >= 0) hands[bestSeat].removeAt(idx);
      }
      final meldCards = [pair[0], pair[1], card]..sort((a, b) => cardIndex(a).compareTo(cardIndex(b)));
      final hx = computeMeldHuxi('chi', meldCards);
      melds[bestSeat].add(PhzMeld('chi', meldCards, hx));
      activeCard = null;
      statusText = '${name(bestSeat)} 吃 ${meldCards.map(cardLabel).join("")}${hx > 0 ? "（+$hx 胡）" : ""}';
      host.log(statusText);
      _afterMeldAction(bestSeat, isFourCardMeld: false);
    }
  }

  void _afterMeldAction(int seat, {required bool isFourCardMeld}) {
    // Check if player can immediately Hu after Ti/Wei
    final sol = findWinningSolution(melds[seat], hands[seat], selfDrawn: true, minHuxi: minHuxi);
    if (sol != null && hands[seat].isEmpty) {
      _settleHu(seat, sol.$1, sol.$2, selfDrawn: true);
      return;
    }
    // If player has cards to discard (in Paohuzi, after Peng/Chi/Wei or first Ti/Pao when hand has >= 2 cards)
    if (hands[seat].length >= 2 && (!isFourCardMeld || hands[seat].length % 3 == 0)) {
      turn = seat;
      phase = 'discard';
    } else if (hands[seat].isNotEmpty && !isFourCardMeld) {
      turn = seat;
      phase = 'discard';
    } else {
      _drawNextFromWall((seat + 1) % players);
    }
  }

  void _drawNextFromWall(int nextSeat) {
    if (wall.isEmpty) {
      // 荒庄 (Draw round)
      lastRoundResult = {
        'round': round,
        'winner': -1,
        'huxi': 0,
        'delta': List.filled(players, 0),
        'text': '底牌摸完，本局荒庄（流局）！',
      };
      statusText = '底牌摸完，本局荒庄！';
      host.log(statusText);
      dealer = (dealer + 1) % players;
      if (round >= totalRounds) {
        _over = true;
        _placings = rankByScore(scores);
      } else {
        phase = 'roundEnd';
      }
      return;
    }

    final drawn = wall.removeLast();
    turn = nextSeat;
    activeCard = drawn;
    activeFrom = nextSeat;
    activeSource = 'draw';
    statusText = '${name(nextSeat)} 摸牌 ${cardLabel(drawn)}';
    _openClaimWindowForCard(drawn, fromSeat: nextSeat, isSelfDraw: true);
  }

  void _settleHu(int winSeat, int totalHuxi, List<PhzMeld> winMelds, {required bool selfDrawn}) {
    final basePts = ((totalHuxi - minHuxi).clamp(0, 100) + 10) * (selfDrawn ? 2 : 1);
    final delta = List.filled(players, 0);
    for (var s = 0; s < players; s++) {
      if (s == winSeat) {
        delta[s] = basePts * (players - 1);
      } else {
        delta[s] = -basePts;
      }
      scores[s] += delta[s];
    }

    lastRoundResult = {
      'round': round,
      'winner': winSeat,
      'selfDrawn': selfDrawn,
      'huxi': totalHuxi,
      'delta': delta,
      'melds': [for (final m in winMelds) m.toJson()],
      'text': '${name(winSeat)} ${selfDrawn ? "自摸" : "胡牌"}（$totalHuxi 胡息，+${delta[winSeat]} 分）！',
    };
    statusText = lastRoundResult!['text'] as String;
    host.log(statusText);
    dealer = winSeat;

    if (round >= totalRounds) {
      _over = true;
      _placings = rankByScore(scores);
    } else {
      phase = 'roundEnd';
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;
    if (phase == 'roundEnd') {
      return readyNext.contains(seat) ? null : {'type': 'nextRound'};
    }
    if (phase == 'discard') {
      if (seat != turn) return null;
      if (findWinningSolution(melds[seat], hands[seat], selfDrawn: true, minHuxi: minHuxi) != null) {
        return {'type': 'hu'};
      }
      final legal = discardableCards(hands[seat]);
      if (legal.isEmpty) return null;
      return {'type': 'discard', 'card': _pickBestDiscard(hands[seat], legal)};
    }
    if (phase == 'claim') {
      final opts = claimOptions[seat];
      if (opts == null || chosenClaims.containsKey(seat)) return null;
      if (opts['hu'] == true) return {'type': 'hu'};
      if (opts['pao'] == true) return {'type': 'pao'};
      if (opts['peng'] == true) {
        // Always Peng if it gives HuXi (all Pengs give 1 or 3 HuXi!)
        return {'type': 'peng'};
      }
      final chiList = (opts['chi'] as List?)?.cast<List<String>>() ?? const [];
      if (chiList.isNotEmpty && activeCard != null) {
        // Prefer Chi combinations that yield HuXi (1-2-3 or 2-7-10)
        for (final pair in chiList) {
          final hx = computeMeldHuxi('chi', [pair[0], pair[1], activeCard!]);
          if (hx > 0) {
            return {'type': 'chi', 'cards': pair};
          }
        }
        if (botLevel >= 1 && exposedHuxi(seat) >= minHuxi - 6 && rng.nextDouble() < 0.5) {
          return {'type': 'chi', 'cards': chiList.first};
        }
      }
      return {'type': 'pass'};
    }
    return null;
  }

  String _pickBestDiscard(List<String> hand, List<String> legal) {
    final counts = List.filled(20, 0);
    for (final c in hand) {
      final idx = cardIndex(c);
      if (idx >= 0) counts[idx]++;
    }

    var bestCard = legal.first;
    var bestKeepScore = 1e9;

    for (final c in legal) {
      final idx = cardIndex(c);
      final r = cardRank(c);
      final big = isBigCard(c);
      final base = big ? 10 : 0;
      var keep = 0.0;

      // Pair in hand -> useful for Peng/Wei/Jiang
      if (counts[idx] == 2) keep += 40.0;
      // Red cards (2, 7, 10) or 1-2-3 cards can form HuXi sequences
      if (r == 1 || r == 2 || r == 3 || r == 7 || r == 10) keep += (big ? 22.0 : 14.0);
      // Adjacent same-case cards
      if (r > 1 && counts[base + r - 2] > 0) keep += 10.0;
      if (r < 10 && counts[base + r] > 0) keep += 10.0;
      // Opposite-case same-rank card for Jiao
      final oppIdx = (big ? 0 : 10) + (r - 1);
      if (counts[oppIdx] > 0) keep += 8.0;

      keep += rng.nextDouble() * 3.0;
      if (keep < bestKeepScore) {
        bestKeepScore = keep;
        bestCard = c;
      }
    }
    return bestCard;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myClaim = (seat >= 0 && phase == 'claim' && !chosenClaims.containsKey(seat)) ? claimOptions[seat] : null;
    final canInitialHu = seat >= 0 &&
        phase == 'discard' &&
        turn == seat &&
        findWinningSolution(melds[seat], hands[seat], selfDrawn: true, minHuxi: minHuxi) != null;

    return {
      'round': round,
      'totalRounds': totalRounds,
      'minHuxi': minHuxi,
      'dealer': dealer,
      'turn': turn,
      'phase': phase,
      'wallCount': wall.length,
      'activeCard': activeCard,
      'activeFrom': activeFrom,
      'activeSource': activeSource,
      'status': statusText,
      'hand': seat >= 0 && seat < players ? List<String>.of(hands[seat]) : const <String>[],
      'discardable': seat >= 0 && seat < players && phase == 'discard' && turn == seat
          ? discardableCards(hands[seat])
          : const <String>[],
      'canHuNow': canInitialHu,
      'claimOptions': myClaim,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'handCount': hands[s].length,
            'exposedHuxi': exposedHuxi(s),
            'score': scores[s],
            'melds': [
              for (final m in melds[s]) m.toJson(),
            ],
            'discards': List<String>.of(discards[s]),
          },
      ],
      if (lastRoundResult != null) 'roundResult': lastRoundResult,
      'waitingFor': waitingFor,
      'over': _over,
      if (_placings != null) 'placings': _placings,
    };
  }
}
