import 'dart:math';

import '../../src/engine.dart';

const String pinochleRules = '''
# 皮诺克 Pinochle 规则

## 概述
皮诺克（Pinochle）是欧美极受欢迎的 48 张双副牌“亮牌组合（Meld）+ 吃墩（Trick-Taking）”经典纸牌游戏，支持 2～4 人同台竞技。

## 牌组与牌序
- 使用 **48 张特制双副牌**：黑桃（`S`）、红桃（`H`）、方片（`D`）、梅花（`C`）四门花色，每门花色各有 **两张** `9, 10(T), J, Q, K, A`（6 种点数 × 4 花色 × 2 副 = 48 张）。
- **特殊牌序（由大到小）**：`A > 10(T) > K > Q > J > 9`（注意 `10` 仅次于 `A`，高于 `K`！）。
- 当同一墩出现两张完全相同的牌时，**先出者大**。

## 阶段流程
1. **叫牌阶段（`bid`）**：
   - 每位玩家发 12 张手牌（2～3 人局剩余牌作为牌库 `stock`）。
   - 玩家从 `200` 分起叫（每次至少加 `10` 分：`200, 210, 220...`）或选择不叫（`pass`）。
   - 最高叫分者成为**庄家（Declarer）**并指定本局的**主花色（`trumpSuit`）**。
2. **亮牌组合阶段（`meld`）**：
   - 系统自动检测并展示所有玩家手牌中的经典皮诺克组合分（`meldPoints`）：
     - **主花色同花顺 Flush / Run（主花色 `A-T-K-Q-J`）**：`150` 分（双同花顺 `1500` 分）
     - **皇家婚姻 Royal Marriage（主花色 `K + Q`）**：`40` 分（已计入同花顺的 `K+Q` 不重复计分，额外第二对仍计 `40` 分）
     - **普通婚姻 Common Marriage（副花色同花 `K + Q`）**：每对 `20` 分
     - **皮诺克对 Pinochle（黑桃皇后 `QS` + 方片杰克 `JD`）**：`40` 分（**双皮诺克 Double Pinochle** 两对 `QS + JD` 高达 `300` 分！）
     - **四门同点 Arounds（集齐四门花色各一张）**：
       - 四 A（`Four Aces`）：`100` 分（八 A `1000` 分）
       - 四 K（`Four Kings`）：`80` 分（八 K `800` 分）
       - 四 Q（`Four Queens`）：`60` 分（八 Q `600` 分）
       - 四 J（`Four Jacks`）：`40` 分（八 J `400` 分）
     - **主九 Dix（主花色 `9`）**：每张 `10` 分
3. **吃墩阶段（`play`）**：
   - 共进行 12 墩，庄家首引第 1 墩。跟牌必须跟随首引花色（无该花色时可出任意牌）。
   - **吃墩计分（全场共 250 分）**：
     - 吃进的每张 `A`、`10(T)`、`K` 各计 **10 分**（`Q, J, 9` 为 0 分，共 24 张 × 10 = 240 分）。
     - 赢下 **最后一墩（第 12 墩）** 额外奖励 **+10 分**（2～3 人局未摸完的余牌一并归入末墩赢家）。
   - **局末结算**：
     - 若庄家 `亮牌分 + 吃墩分 >= 叫分`，庄家完成定约并获得该总分；若未达到叫分，庄家宕掉（Set），倒扣 `-叫分`！
     - 其余玩家获得各自的 `亮牌分 + 吃墩分`。
''';

const List<String> kPinochleSuits = ['S', 'H', 'D', 'C'];
const List<String> kPinochleRanks = ['9', 'J', 'Q', 'K', 'T', 'A'];

const Map<String, String> kPinochleSuitNames = {
  'S': '♠黑桃',
  'H': '♥红桃',
  'D': '♦方片',
  'C': '♣梅花',
};

String pinochleRank(String card) => card.substring(0, card.length - 1);
String pinochleSuit(String card) => card[card.length - 1];

int pinochleRankOrder(String rank) {
  switch (rank) {
    case '9':
      return 1;
    case 'J':
      return 2;
    case 'Q':
      return 3;
    case 'K':
      return 4;
    case 'T':
      return 5;
    case 'A':
      return 6;
    default:
      return 0;
  }
}

/// 10 points for every A, T, K; 0 for Q, J, 9.
int pinochleCardPoints(String card) {
  final r = pinochleRank(card);
  if (r == 'A' || r == 'T' || r == 'K') return 10;
  return 0;
}

List<String> buildPinochleDeck() => [
      for (var copy = 0; copy < 2; copy++)
        for (final s in kPinochleSuits)
          for (final r in kPinochleRanks) '$r$s',
    ];

class PinochleMeldResult {
  final int points;
  final List<Map<String, dynamic>> items;
  const PinochleMeldResult(this.points, this.items);
}

/// Evaluates all Pinochle meld combinations in [hand] given [trumpSuit].
PinochleMeldResult evaluatePinochleMelds(List<String> hand, String trumpSuit) {
  final counts = <String, int>{};
  for (final c in hand) {
    counts[c] = (counts[c] ?? 0) + 1;
  }
  int cnt(String r, String s) => counts['$r$s'] ?? 0;

  var total = 0;
  final items = <Map<String, dynamic>>[];

  void addMeld(String name, int pts) {
    if (pts <= 0) return;
    total += pts;
    items.add({'name': name, 'points': pts});
  }

  // Class 1: Trump Run / Marriages / Dix
  final runCount = [
    cnt('A', trumpSuit),
    cnt('T', trumpSuit),
    cnt('K', trumpSuit),
    cnt('Q', trumpSuit),
    cnt('J', trumpSuit),
  ].reduce(min);

  if (runCount >= 2) {
    addMeld('双主同花顺 Double Run', 1500);
  } else if (runCount == 1) {
    addMeld('主花色同花顺 Flush/Run', 150);
  }

  final royalMarriages = min(cnt('K', trumpSuit), cnt('Q', trumpSuit)) - runCount;
  if (royalMarriages > 0) {
    addMeld(
      royalMarriages == 2 ? '双皇家婚姻 ×2' : '皇家婚姻 Royal Marriage',
      40 * royalMarriages,
    );
  }

  for (final s in kPinochleSuits) {
    if (s == trumpSuit) continue;
    final m = min(cnt('K', s), cnt('Q', s));
    if (m > 0) {
      addMeld('${kPinochleSuitNames[s]}婚姻 Marriage', 20 * m);
    }
  }

  final dixCount = cnt('9', trumpSuit);
  if (dixCount > 0) {
    addMeld(dixCount == 2 ? '双主九 Dix ×2' : '主九 Dix', 10 * dixCount);
  }

  // Class 2: Pinochle (QS + JD)
  final pinochleCount = min(cnt('Q', 'S'), cnt('J', 'D'));
  if (pinochleCount >= 2) {
    addMeld('双皮诺克 Double Pinochle', 300);
  } else if (pinochleCount == 1) {
    addMeld('皮诺克 Pinochle (QS+JD)', 40);
  }

  // Class 3: Arounds (Four Aces / Kings / Queens / Jacks across all 4 suits)
  int aroundCount(String r) =>
      [for (final s in kPinochleSuits) cnt(r, s)].reduce(min);

  final aces = aroundCount('A');
  if (aces >= 2) {
    addMeld('八A满贯 Eight Aces', 1000);
  } else if (aces == 1) {
    addMeld('四门A Four Aces', 100);
  }

  final kings = aroundCount('K');
  if (kings >= 2) {
    addMeld('八K满贯 Eight Kings', 800);
  } else if (kings == 1) {
    addMeld('四门K Four Kings', 80);
  }

  final queens = aroundCount('Q');
  if (queens >= 2) {
    addMeld('八Q满贯 Eight Queens', 600);
  } else if (queens == 1) {
    addMeld('四门Q Four Queens', 60);
  }

  final jacks = aroundCount('J');
  if (jacks >= 2) {
    addMeld('八J满贯 Eight Jacks', 400);
  } else if (jacks == 1) {
    addMeld('四门J Four Jacks', 40);
  }

  return PinochleMeldResult(total, items);
}

class PinochleGame extends GameEngine {
  late int maxRounds;
  int round = 1;
  int dealer = 0;

  String phase = 'bid'; // 'bid' | 'meld' | 'play'
  int turn = 0;
  int leader = 0;

  late List<List<String>> hands;
  late List<String> stock;

  int currentBid = 190;
  int highBidder = -1;
  int declarer = 0;
  int bidValue = 200;
  String trumpSuit = 'S';
  late List<String> bidderTrumpChoice;
  late List<bool> passed;

  late List<int> meldPoints;
  late List<List<Map<String, dynamic>>> meldBreakdowns;
  late List<int> trickPoints;
  late List<int> tricksWon;
  late List<int> scores;

  int tricksPlayed = 0;
  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandSummary;

  bool _over = false;

  PinochleGame(super.setup) {
    maxRounds = setup.opt<int>('rounds', 2);
    scores = List.filled(players, 0);
  }

  int get forehand => (dealer + 1) % players;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    final deck = shuffled(buildPinochleDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++) deck.sublist(s * 12, (s + 1) * 12),
    ];
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
    stock = deck.sublist(players * 12);

    phase = 'bid';
    currentBid = 190;
    highBidder = -1;
    declarer = forehand;
    bidValue = 200;
    trumpSuit = 'S';
    bidderTrumpChoice = [
      for (var s = 0; s < players; s++) _bestTrumpForHand(hands[s]),
    ];
    passed = List.filled(players, false);

    meldPoints = List.filled(players, 0);
    meldBreakdowns = [for (var s = 0; s < players; s++) const []];
    trickPoints = List.filled(players, 0);
    tricksWon = List.filled(players, 0);

    tricksPlayed = 0;
    currentTrick = [];
    lastTrick = null;

    turn = forehand;
    leader = forehand;
    host.log('第 $round/$maxRounds 局开始，${name(forehand)} 先手叫牌');
  }

  String _bestTrumpForHand(List<String> hand) {
    var bestSuit = 'S';
    var bestScore = -1;
    for (final s in kPinochleSuits) {
      final meld = evaluatePinochleMelds(hand, s).points;
      final suitLen = hand.where((c) => pinochleSuit(c) == s).length;
      final score = meld + suitLen * 15;
      if (score > bestScore) {
        bestScore = score;
        bestSuit = s;
      }
    }
    return bestSuit;
  }

  void _sortHand(List<String> hand) {
    const suitOrd = {'S': 4, 'H': 3, 'D': 2, 'C': 1};
    hand.sort((a, b) {
      final sa = pinochleSuit(a) == trumpSuit
          ? 10
          : (suitOrd[pinochleSuit(a)] ?? 0);
      final sb = pinochleSuit(b) == trumpSuit
          ? 10
          : (suitOrd[pinochleSuit(b)] ?? 0);
      if (sa != sb) return sb.compareTo(sa);
      return pinochleRankOrder(pinochleRank(b))
          .compareTo(pinochleRankOrder(pinochleRank(a)));
    });
  }

  /// Computes and stores [meldPoints] and [meldBreakdowns] for all seats.
  void scoreMelds() {
    for (var s = 0; s < players; s++) {
      final res = evaluatePinochleMelds(hands[s], trumpSuit);
      meldPoints[s] = res.points;
      meldBreakdowns[s] = res.items;
    }
  }

  List<String> legalCards(int seat) {
    if (seat < 0 || seat >= players) return const [];
    final h = hands[seat];
    if (phase != 'play' || currentTrick.isEmpty) return List<String>.of(h);
    final ledCard = '${currentTrick.first['card']}';
    final ledSuit = pinochleSuit(ledCard);
    final sameSuit = h.where((c) => pinochleSuit(c) == ledSuit).toList();
    return sameSuit.isNotEmpty ? sameSuit : List<String>.of(h);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    final type = asStr(action['type']);

    if (phase == 'bid') {
      _handleBid(seat, type, action);
      return;
    }
    if (phase == 'meld') {
      _handleMeld(seat, type, action);
      return;
    }
    if (phase == 'play') {
      _handlePlay(seat, type, action);
      return;
    }
    throw GameError('未知阶段');
  }

  void _handleBid(int seat, String type, Map<String, dynamic> action) {
    if (type == 'bid') {
      final val = asInt(action['value']);
      if (val < 200 || val <= currentBid || val % 10 != 0) {
        throw GameError('叫分必须为 10 的倍数、至少 200 分且高于当前叫分');
      }
      final t = asStr(action['trump']);
      if (kPinochleSuits.contains(t)) {
        bidderTrumpChoice[seat] = t;
      }
      currentBid = val;
      highBidder = seat;
      host.log('${name(seat)} 叫分 $val');
      _advanceBid();
      return;
    }
    if (type == 'pass') {
      passed[seat] = true;
      host.log('${name(seat)} 不叫 (Pass)');
      _advanceBid();
      return;
    }
    throw GameError('叫牌阶段请使用 bid 或 pass');
  }

  void _advanceBid() {
    final active = [
      for (var s = 0; s < players; s++)
        if (!passed[s]) s,
    ];
    if (active.isEmpty) {
      _finalizeBid(highBidder >= 0 ? highBidder : forehand);
      return;
    }
    if (active.length == 1 && highBidder == active.first) {
      _finalizeBid(active.first);
      return;
    }
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!passed[next]) {
        turn = next;
        return;
      }
    }
    _finalizeBid(highBidder >= 0 ? highBidder : forehand);
  }

  void _finalizeBid(int winner) {
    declarer = winner;
    bidValue = currentBid >= 200 ? currentBid : 200;
    trumpSuit = bidderTrumpChoice[declarer];
    for (var s = 0; s < players; s++) {
      _sortHand(hands[s]);
    }
    scoreMelds();
    phase = 'meld';
    turn = declarer;
    host.log(
      '${name(declarer)} 以 $bidValue 分夺庄，定主花色 ${kPinochleSuitNames[trumpSuit]}！',
    );
  }

  void _handleMeld(int seat, String type, Map<String, dynamic> action) {
    if (type != 'meld' && type != 'confirm_meld' && type != 'set_trump') {
      throw GameError('亮牌阶段请确认组合 (meld)');
    }
    final t = asStr(action['trump']);
    if (kPinochleSuits.contains(t)) {
      trumpSuit = t;
      for (var s = 0; s < players; s++) {
        _sortHand(hands[s]);
      }
    }
    scoreMelds();
    if (type == 'set_trump') return;

    phase = 'play';
    leader = declarer;
    turn = declarer;
    host.log(
      '亮牌组合结算完成：${[for (var s = 0; s < players; s++) '${name(s)} +${meldPoints[s]}'].join('，')}',
    );
  }

  int _trickCardStrength(String card, String ledSuit) {
    final s = pinochleSuit(card);
    final r = pinochleRankOrder(pinochleRank(card));
    if (s == trumpSuit) return 100 + r;
    if (s == ledSuit) return 10 + r;
    return -1;
  }

  void _handlePlay(int seat, String type, Map<String, dynamic> action) {
    if (type != 'play') throw GameError('出牌阶段请使用 play');
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('你手里没有这张牌：$card');
    }
    final legal = legalCards(seat);
    if (!legal.contains(card)) {
      throw GameError('必须跟随首引花色出牌');
    }

    hands[seat].remove(card);
    currentTrick.add({'seat': seat, 'card': card});

    if (currentTrick.length < players) {
      turn = (turn + 1) % players;
      return;
    }

    // Resolve trick (strictly `>` so first of duplicate card wins!)
    final ledCard = '${currentTrick.first['card']}';
    final ledSuit = pinochleSuit(ledCard);
    var bestSeat = (currentTrick.first['seat'] as num).toInt();
    var bestCard = ledCard;
    var bestStrength = _trickCardStrength(ledCard, ledSuit);
    var pts = pinochleCardPoints(ledCard);

    for (var i = 1; i < currentTrick.length; i++) {
      final entry = currentTrick[i];
      final s = (entry['seat'] as num).toInt();
      final c = '${entry['card']}';
      pts += pinochleCardPoints(c);
      final st = _trickCardStrength(c, ledSuit);
      if (st > bestStrength) {
        bestStrength = st;
        bestSeat = s;
        bestCard = c;
      }
    }

    tricksPlayed++;
    final isLastTrick = tricksPlayed >= 12 || hands.every((h) => h.isEmpty);
    if (isLastTrick) {
      pts += 10; // +10 bonus for winning the 12th (last) trick
      if (stock.isNotEmpty) {
        for (final c in stock) {
          pts += pinochleCardPoints(c);
        }
        stock.clear();
      }
    }

    tricksWon[bestSeat]++;
    trickPoints[bestSeat] += pts;
    lastTrick = {
      'winner': bestSeat,
      'winningCard': bestCard,
      'points': pts,
      'cards': List<Map<String, dynamic>>.of(currentTrick),
    };
    currentTrick = [];
    leader = bestSeat;
    turn = bestSeat;

    if (isLastTrick) {
      _finishHand();
    }
  }

  void _finishHand() {
    final declTotal = meldPoints[declarer] + trickPoints[declarer];
    final declMade = declTotal >= bidValue;

    final deltas = List.filled(players, 0);
    for (var s = 0; s < players; s++) {
      if (s == declarer) {
        deltas[s] = declMade ? declTotal : -bidValue;
      } else {
        deltas[s] = meldPoints[s] + trickPoints[s];
      }
      scores[s] += deltas[s];
    }

    lastHandSummary = {
      'round': round,
      'declarer': declarer,
      'trumpSuit': trumpSuit,
      'bidValue': bidValue,
      'declarerMade': declMade,
      'meldPoints': List<int>.of(meldPoints),
      'trickPoints': List<int>.of(trickPoints),
      'deltas': deltas,
    };

    host.log(
      '第 $round 局结束：庄家 ${name(declarer)} 合共 $declTotal 分 '
      '(${declMade ? '达成叫分 +$declTotal' : '未达叫分 -$bidValue'})',
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
  Map<String, dynamic> view(int seat) => {
        'round': round,
        'maxRounds': maxRounds,
        'dealer': dealer,
        'forehand': forehand,
        'phase': phase,
        'turn': turn,
        'leader': leader,
        'declarer': declarer,
        'currentBid': currentBid,
        'highBidder': highBidder,
        'bidValue': bidValue,
        'trumpSuit': trumpSuit,
        'passed': List<bool>.of(passed),
        'meldPoints': List<int>.of(meldPoints),
        'meldBreakdowns': [
          for (final list in meldBreakdowns)
            [for (final m in list) Map<String, dynamic>.of(m)],
        ],
        'trickPoints': List<int>.of(trickPoints),
        'tricksWon': List<int>.of(tricksWon),
        'tricksPlayed': tricksPlayed,
        'scores': List<int>.of(scores),
        'stockCount': stock.length,
        'handCounts': [for (final h in hands) h.length],
        'myHand': seat >= 0 && seat < players
            ? List<String>.of(hands[seat])
            : const <String>[],
        'legalCards': seat == turn && phase == 'play'
            ? legalCards(seat)
            : const <String>[],
        'currentTrick': [
          for (final e in currentTrick) Map<String, dynamic>.of(e),
        ],
        'lastTrick': lastTrick,
        'lastHandSummary': lastHandSummary,
      };

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'bid') {
      final bestSuit = _bestTrumpForHand(hands[seat]);
      final estMeld = evaluatePinochleMelds(hands[seat], bestSuit).points;
      final maxBid = 190 + (estMeld ~/ 20) * 10;
      final nextBid = currentBid < 200 ? 200 : currentBid + 10;
      if (nextBid <= maxBid && nextBid <= 250) {
        return {'type': 'bid', 'value': nextBid, 'trump': bestSuit};
      }
      return {'type': 'pass'};
    }

    if (phase == 'meld') {
      return {'type': 'meld'};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      legal.sort(
        (a, b) => pinochleRankOrder(pinochleRank(b))
            .compareTo(pinochleRankOrder(pinochleRank(a))),
      );
      return {'type': 'play', 'card': legal.first};
    }

    return null;
  }
}
