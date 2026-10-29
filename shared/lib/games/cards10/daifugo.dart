import '../../src/engine.dart';

const String daifugoRules = '''
# 大富豪（Daifugo）规则说明

## 游戏概述
大富豪（Daifugo / 大贫民）是日本最具代表性的阶梯式跑得快/争上游扑克游戏，支持 3～6 人游玩。独具特色的【革命（Revolution）】、【8切（8-Giri）】、【黑桃3返王】与局间【大富豪/大贫民换牌】机制让战局充满逆转乐趣！

## 牌组与常规大小（54 张）
- 使用标准 54 张扑克牌（含小王 `BJ`、大王 `RJ`），按座位均匀发完所有牌。
- **常规点数顺序（从小到大）**：
  `3 < 4 < 5 < 6 < 7 < 8 < 9 < 10 < J < Q < K < A < 2 < 小王(BJ) < 大王(RJ)`。

## 出牌牌型
- 领出玩家可打出：**单张（1张）**、**对子（2张同点）**、**三张（3张同点）** 或 **四张同点（4张炸弹/革命）**。
- 大小王除了单出或双王同出外，也可作为百搭牌搭配同点数的自然牌一起打出。
- 跟牌玩家必须打出**张数完全相同**且**当前牌力严格更大**的同类型牌组，或者选择**要不起（Pass）**。
- 当除最后出牌者外的所有在场玩家均 Pass 时，清空台面，由最后出牌者（若其已出完则顺延至下家）开启新一轮领出。

## 核心特殊规则
1. **革命（Revolution）**：
   - 打出 **4 张同点数的牌（四张/炸弹）** 时，立即触发 **【革命】**（若已处于革命状态则触发【反革命】恢复正常）！
   - 革命期间，所有非王牌的大小顺序**完全颠倒**：`2 < A < K < Q < J < 10 < 9 < 8 < 7 < 6 < 5 < 4 < 3`，而大小王依然保持最大！
2. **8切（8-Giri）**：
   - 无论单张、对子还是多张，只要打出的牌组点数为 **8**，会**立即清空桌面（切牌）**，并由该玩家直接获得新一轮的领出权！
3. **黑桃 3 返王（♠3 Counter）**：
   - 当台面上是**单张大小王（BJ 或 RJ）**时，持有 **♠3（`3S`）** 的玩家可以打出单张 `3S` 管上王牌，并**立即清空桌面**获得领出权！

## 阶梯身份与局间换牌（进贡）
- 按每局出完手牌的先后顺序排定阶梯身份：第一名为**大富豪（Daifugo）**，最后一名为**大贫民（Daihinmin）**（4人以上还有富豪、平民、贫民）。
- 多局赛（`rounds = 3`）中，从第 2 局起开局时进行**身份换牌**：上局的**大贫民**自动向**大富豪**进贡手中**最大的 2 张牌**，随后由**大富豪**任选手中 **2 张牌**回赐给大贫民！
''';

class DaifugoPlay {
  final String rank;
  final int count;
  final List<String> cards;
  final bool isRevolution;
  final bool is8Giri;
  final bool isSingleSpade3;

  const DaifugoPlay({
    required this.rank,
    required this.count,
    required this.cards,
    required this.isRevolution,
    required this.is8Giri,
    required this.isSingleSpade3,
  });
}

class Daifugo extends GameEngine {
  Daifugo(super.setup);

  static const List<String> suits = ['S', 'H', 'D', 'C'];
  static const List<String> normalRanks = ['3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A', '2'];

  static bool isJoker(String c) => c == 'BJ' || c == 'RJ';
  static String cardRank(String c) => isJoker(c) ? c : c.substring(0, c.length - 1);

  static int baseRankValue(String rank) {
    if (rank == 'RJ') return 17;
    if (rank == 'BJ') return 16;
    final idx = normalRanks.indexOf(rank);
    return idx >= 0 ? idx + 3 : 0; // 3..15
  }

  /// Effective rank strength under [revolution].
  /// Normal: 3(3) < 4(4) < ... < 2(15) < BJ(16) < RJ(17)
  /// Revolution: 2(3) < A(4) < ... < 3(15) < BJ(16) < RJ(17)
  static int rankStrength(String rank, bool revolution) {
    final base = baseRankValue(rank);
    if (base >= 16) return base; // Jokers stay highest
    return revolution ? (18 - base) : base;
  }

  static int cardStrength(String card, bool revolution) => rankStrength(cardRank(card), revolution);

  static List<String> buildDeck() => [
        for (final r in normalRanks)
          for (final s in suits) '$r$s',
        'BJ',
        'RJ',
      ];

  static void sortHand(List<String> hand, {bool revolution = false}) {
    hand.sort((a, b) {
      final sa = cardStrength(a, revolution);
      final sb = cardStrength(b, revolution);
      if (sa != sb) return sa.compareTo(sb);
      return a.compareTo(b);
    });
  }

  static DaifugoPlay? classify(List<String> cards) {
    if (cards.isEmpty || cards.length > 5) return null;
    final jokers = cards.where(isJoker).toList();
    final naturals = cards.where((c) => !isJoker(c)).toList();
    String rank;
    if (naturals.isEmpty) {
      // Only jokers
      rank = jokers.every((c) => c == 'RJ') ? 'RJ' : 'BJ';
    } else {
      rank = cardRank(naturals.first);
      if (naturals.any((c) => cardRank(c) != rank)) return null;
    }
    return DaifugoPlay(
      rank: rank,
      count: cards.length,
      cards: List.of(cards),
      isRevolution: cards.length >= 4,
      is8Giri: rank == '8',
      isSingleSpade3: cards.length == 1 && cards.first == '3S',
    );
  }

  static bool _hasAllCards(List<String> hand, List<String> sub) {
    final copy = List.of(hand);
    for (final c in sub) {
      if (!copy.remove(c)) return false;
    }
    return true;
  }

  late int targetRounds;
  late bool spade3Rule;
  int roundNo = 0;
  int turn = 0;
  String phase = 'play'; // 'exchange' | 'play' | 'roundEnd' | 'over'
  bool revolution = false;
  List<List<String>> hands = [];
  Map<String, dynamic>? table; // {'seat': int, 'cards': List<String>, 'rank': String, 'count': int}
  int lastPlaySeat = -1;
  Set<int> passed = {};
  List<int> finishOrder = [];
  List<int> prevOrder = [];
  List<int> scores = [];
  List<String> titles = [];
  int exchangeDaifugo = -1;
  int exchangeDaihinmin = -1;
  List<String> exchangeTribute = [];
  Map<String, dynamic>? lastExchange;
  List<bool> ready = [];
  Map<String, dynamic>? result;
  List<String> logs = [];
  int resignedBy = -1;

  void _log(String msg) {
    logs.add(msg);
    if (logs.length > 30) logs.removeAt(0);
    host.log(msg);
  }

  String titleForRank(int rankIdx) {
    if (rankIdx == 0) return '大富豪';
    if (rankIdx == players - 1) return '大贫民';
    if (players >= 4 && rankIdx == 1) return '富豪';
    if (players >= 4 && rankIdx == players - 2) return '贫民';
    return '平民';
  }

  @override
  void start() {
    targetRounds = setup.opt<int>('rounds', 3);
    spade3Rule = setup.opt<bool>('spade3', true);
    scores = List.filled(players, 0);
    titles = List.filled(players, '平民');
    prevOrder = [];
    roundNo = 0;
    resignedBy = -1;
    _startRound();
  }

  void _startRound() {
    roundNo++;
    revolution = false;
    table = null;
    lastPlaySeat = -1;
    passed = {};
    finishOrder = [];
    exchangeTribute = [];
    lastExchange = null;
    result = null;
    ready = List.filled(players, false);

    final deck = shuffled(buildDeck(), rng);
    hands = List.generate(players, (_) => <String>[]);
    for (var i = 0; i < deck.length; i++) {
      hands[i % players].add(deck[i]);
    }
    for (var s = 0; s < players; s++) {
      sortHand(hands[s], revolution: false);
    }

    if (prevOrder.length == players) {
      startExchange(prevOrder.first, prevOrder.last);
    } else {
      phase = 'play';
      final holder3S = hands.indexWhere((h) => h.contains('3S'));
      turn = holder3S >= 0 ? holder3S : 0;
      _log('第 $roundNo 局大富豪开始！由 ${name(turn)} 先手出牌。');
    }
  }

  /// Starts the Daifugo <-> Daihinmin 2-card exchange between rounds.
  /// Daihinmin automatically gives their 2 strongest cards; Daifugo then chooses any 2 cards to return.
  void startExchange(int daifugoSeat, int daihinminSeat) {
    exchangeDaifugo = daifugoSeat;
    exchangeDaihinmin = daihinminSeat;
    sortHand(hands[daihinminSeat], revolution: false);
    final hLow = hands[daihinminSeat];
    final c1 = hLow.removeLast();
    final c2 = hLow.removeLast();
    exchangeTribute = [c1, c2];
    hands[daifugoSeat].addAll(exchangeTribute);
    sortHand(hands[daifugoSeat], revolution: false);
    phase = 'exchange';
    turn = daifugoSeat;
    _log('第 $roundNo 局换牌阶段：大贫民 ${name(daihinminSeat)} 向大富豪 ${name(daifugoSeat)} 进贡了最强牌 ${exchangeTribute.join(' ')}，等待大富豪回赐 2 张牌。');
  }

  void resetTrick() {
    table = null;
    lastPlaySeat = -1;
    passed.clear();
  }

  bool canBeatPlay(DaifugoPlay play) {
    if (table == null) return true;
    final tCount = asInt(table!['count'], 1);
    final tRank = asStr(table!['rank']);
    // Spade 3 Counter against single Joker
    if (spade3Rule && play.isSingleSpade3 && tCount == 1 && (tRank == 'BJ' || tRank == 'RJ')) {
      return true;
    }
    if (play.count != tCount) return false;
    return rankStrength(play.rank, revolution) > rankStrength(tRank, revolution);
  }

  int _nextActiveSeat(int from) {
    for (var i = 1; i <= players; i++) {
      final s = (from + i) % players;
      if (hands[s].isNotEmpty) return s;
    }
    return from;
  }

  int _nextUnpassedActiveSeat(int from) {
    for (var i = 1; i <= players; i++) {
      final s = (from + i) % players;
      if (s == lastPlaySeat) return -1;
      if (hands[s].isNotEmpty && !passed.contains(s)) return s;
    }
    return -1;
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'roundEnd') {
      return [
        for (var s = 0; s < players; s++)
          if (!ready[s]) s,
      ];
    }
    return [turn];
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int>? get placings {
    if (!isOver) return null;
    if (resignedBy >= 0) {
      return [for (var s = 0; s < players; s++) s == resignedBy ? players : 1];
    }
    return rankByScore(scores);
  }

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) throw GameError('当前无法认输');
    resignedBy = seat;
    phase = 'over';
    result = {
      'roundNo': roundNo,
      'order': List.of(finishOrder),
      'titles': List.of(titles),
      'scores': List.of(scores),
      'resigned': seat,
    };
    _log('${name(seat)} 认输！');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'roundEnd') {
      if (type != 'continue') throw GameError('请点击继续下一局');
      if (seat < 0 || seat >= players || ready[seat]) throw GameError('已准备');
      ready[seat] = true;
      if (ready.every((x) => x)) {
        _startRound();
      }
      return;
    }

    if (seat != turn) throw GameError('还没轮到你操作');

    if (phase == 'exchange') {
      if (type != 'exchange') throw GameError('请选择 2 张手牌回赐给大贫民');
      final raw = action['cards'];
      if (raw is! List || raw.length != 2) throw GameError('必须选择恰好 2 张手牌交换');
      final cards = [for (final x in raw) '$x'];
      if (!_hasAllCards(hands[seat], cards)) throw GameError('手牌中没有所选的牌');
      final daihinminSeat = exchangeDaihinmin >= 0
          ? exchangeDaihinmin
          : (prevOrder.isNotEmpty ? prevOrder.last : (seat + 1) % players);
      for (final c in cards) {
        hands[seat].remove(c);
        hands[daihinminSeat].add(c);
      }
      sortHand(hands[seat], revolution: revolution);
      sortHand(hands[daihinminSeat], revolution: revolution);
      lastExchange = {
        'daifugo': seat,
        'daihinmin': daihinminSeat,
        'tribute': List.of(exchangeTribute),
        'returned': cards,
      };
      phase = 'play';
      turn = daihinminSeat;
      _log('大富豪 ${name(seat)} 回赐了 2 张牌，正式开始第 $roundNo 局！由 ${name(turn)} 先手出牌。');
      return;
    }

    if (type == 'pass') {
      if (table == null) throw GameError('领出回合不能跳过，请出牌');
      passed.add(seat);
      _log('${name(seat)} 选择不出（Pass）。');
      final next = _nextUnpassedActiveSeat(seat);
      if (next < 0) {
        final leader = (lastPlaySeat >= 0 && hands[lastPlaySeat].isNotEmpty)
            ? lastPlaySeat
            : _nextActiveSeat(lastPlaySeat >= 0 ? lastPlaySeat : seat);
        resetTrick();
        turn = leader;
        _log('其余玩家均不出，桌面清空，由 ${name(turn)} 领出！');
      } else {
        turn = next;
      }
      return;
    }

    if (type == 'play') {
      final raw = action['cards'];
      if (raw is! List || raw.isEmpty) throw GameError('请选择要打出的牌');
      final cards = [for (final x in raw) '$x'];
      if (!_hasAllCards(hands[seat], cards)) throw GameError('手牌中不包含所选的牌');
      final play = classify(cards);
      if (play == null) throw GameError('出牌牌型不合法（需为同点数牌组）');
      if (!canBeatPlay(play)) {
        throw GameError('所选牌组无法管上当前台面的牌');
      }

      final isSpade3Counter = table != null &&
          spade3Rule &&
          play.isSingleSpade3 &&
          asInt(table!['count'], 1) == 1 &&
          (table!['rank'] == 'BJ' || table!['rank'] == 'RJ');

      for (final c in cards) {
        hands[seat].remove(c);
      }

      if (play.isRevolution) {
        revolution = !revolution;
        for (var s = 0; s < players; s++) {
          sortHand(hands[s], revolution: revolution);
        }
        _log('${name(seat)} 打出四张 ${play.rank}，发动【${revolution ? "革命" : "反革命"}】！点数大小反转！');
      }

      if (hands[seat].isEmpty) {
        finishOrder.add(seat);
        _log('${name(seat)} 出完手牌（第 ${finishOrder.length} 名）！');
      }

      final activeCount = hands.where((h) => h.isNotEmpty).length;
      if (activeCount <= 1) {
        _finishRound();
        return;
      }

      if (play.is8Giri) {
        resetTrick();
        turn = hands[seat].isNotEmpty ? seat : _nextActiveSeat(seat);
        _log('${name(seat)} 发动【8切】清空桌面，${name(turn)} 获得新的领出权！');
        return;
      }

      if (isSpade3Counter) {
        resetTrick();
        turn = hands[seat].isNotEmpty ? seat : _nextActiveSeat(seat);
        _log('${name(seat)} 打出【♠3 返王】击败单王并清空桌面，${name(turn)} 获得新的领出权！');
        return;
      }

      table = {
        'seat': seat,
        'cards': List.of(cards),
        'rank': play.rank,
        'count': play.count,
      };
      lastPlaySeat = seat;
      passed.clear();
      turn = _nextActiveSeat(seat);
      _log('${name(seat)} 打出 ${cards.join(" ")}。');
      return;
    }

    throw GameError('未知操作');
  }

  void _finishRound() {
    for (var s = 0; s < players; s++) {
      if (!finishOrder.contains(s)) finishOrder.add(s);
    }
    final roundPts = List.filled(players, 0);
    for (var i = 0; i < finishOrder.length; i++) {
      final s = finishOrder[i];
      final pts = (players - 1 - i) * 10;
      roundPts[s] = pts;
      scores[s] += pts;
      titles[s] = titleForRank(i);
    }
    prevOrder = List.of(finishOrder);
    result = {
      'roundNo': roundNo,
      'order': List.of(finishOrder),
      'titles': List.of(titles),
      'roundPoints': roundPts,
      'scores': List.of(scores),
    };
    _log('第 $roundNo 局结束！大富豪：${name(finishOrder.first)}，大贫民：${name(finishOrder.last)}。');
    if (roundNo >= targetRounds) {
      phase = 'over';
    } else {
      phase = 'roundEnd';
      ready = List.filled(players, false);
    }
  }

  /// Generates all legal plays from [hand] given the current [table] and [revolution].
  List<List<String>> legalPlays(List<String> hand) {
    final out = <List<String>>[];
    final byRank = <String, List<String>>{};
    final jokers = <String>[];
    for (final c in hand) {
      if (isJoker(c)) {
        jokers.add(c);
      } else {
        (byRank[cardRank(c)] ??= []).add(c);
      }
    }

    if (table == null) {
      // Leading: can play any natural group (1..4), or 4 of a kind using a joker, or single joker
      for (final entry in byRank.entries) {
        final cards = entry.value;
        for (var k = 1; k <= cards.length && k <= 4; k++) {
          out.add(cards.sublist(0, k));
        }
      }
      for (final j in jokers) {
        out.add([j]);
      }
      if (jokers.length >= 2) {
        out.add(jokers.sublist(0, 2));
      }
      return out;
    }

    final tCount = asInt(table!['count'], 1);
    final tRank = asStr(table!['rank']);
    final tStrength = rankStrength(tRank, revolution);

    // Spade 3 counter against single joker
    if (spade3Rule && tCount == 1 && (tRank == 'BJ' || tRank == 'RJ') && hand.contains('3S')) {
      out.add(['3S']);
    }

    for (final entry in byRank.entries) {
      final r = entry.key;
      final cards = entry.value;
      if (rankStrength(r, revolution) <= tStrength) continue;
      if (cards.length >= tCount) {
        out.add(cards.sublist(0, tCount));
      } else if (cards.length + jokers.length >= tCount) {
        final needJ = tCount - cards.length;
        out.add([...cards, ...jokers.sublist(0, needJ)]);
      }
    }

    if (tCount == 1) {
      for (final j in jokers) {
        if (rankStrength(j, revolution) > tStrength) {
          out.add([j]);
        }
      }
    } else if (tCount == 2 && jokers.length >= 2 && rankStrength('BJ', revolution) > tStrength) {
      out.add(jokers.sublist(0, 2));
    }

    return out;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    if (phase == 'roundEnd') {
      return ready[seat] ? null : {'type': 'continue'};
    }
    if (seat != turn) return null;

    final h = hands[seat];
    if (phase == 'exchange') {
      // Daifugo gives their 2 weakest cards (excluding 8s if possible)
      final sorted = List.of(h)
        ..sort((a, b) {
          final sa = cardStrength(a, false) + (cardRank(a) == '8' ? 5 : 0);
          final sb = cardStrength(b, false) + (cardRank(b) == '8' ? 5 : 0);
          return sa.compareTo(sb);
        });
      return {'type': 'exchange', 'cards': sorted.sublist(0, 2)};
    }

    final plays = legalPlays(h);
    if (plays.isEmpty) {
      return {'type': 'pass'};
    }

    // Sort plays by preference: prefer multi-card sets with weaker rank first to shed low cards
    plays.sort((a, b) {
      final pa = classify(a)!;
      final pb = classify(b)!;
      final sa = rankStrength(pa.rank, revolution);
      final sb = rankStrength(pb.rank, revolution);
      if (table == null && pa.count != pb.count) {
        return pb.count.compareTo(pa.count); // lead pairs/triples before singles
      }
      return sa.compareTo(sb);
    });

    if (botLevel == 0 && table != null && rng.nextDouble() < 0.25) {
      return {'type': 'pass'};
    }
    return {'type': 'play', 'cards': plays.first};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final vSeat = seat >= 0 && seat < players ? seat : -1;
    var best = 0;
    for (var s = 1; s < players; s++) {
      if (scores[s] > scores[best]) best = s;
    }
    return {
      'phase': phase,
      'roundNo': roundNo,
      'targetRounds': targetRounds,
      'spade3Rule': spade3Rule,
      'turn': turn,
      'revolution': revolution,
      'table': table,
      'lastPlaySeat': lastPlaySeat,
      'passed': passed.toList(),
      'hand': vSeat >= 0 ? List.of(hands[vSeat]) : const <String>[],
      'counts': [for (var s = 0; s < players; s++) hands[s].length],
      'titles': List.of(titles),
      'finishOrder': List.of(finishOrder),
      'prevOrder': List.of(prevOrder),
      'exchangeTribute': List.of(exchangeTribute),
      'lastExchange': lastExchange,
      'scores': List.of(scores),
      'ready': List.of(ready),
      'result': result,
      'winner': isOver ? (resignedBy >= 0 ? (resignedBy + 1) % players : best) : -1,
      'resigned': resignedBy >= 0,
      'log': List.of(logs),
    };
  }
}
