import '../../src/engine.dart';

const String germanWhistRules = '''
# 德国惠斯特（German Whist）规则说明

## 游戏概述
德国惠斯特（German Whist）是经典的双人 52 张扑克牌两阶段吃墩对决游戏。牌局分为独特的【前 13 墩夺牌战（Forhand）】与【后 13 墩决胜战（Endgame）】两个阶段，兼具手牌运营、明牌记忆与终局算牌博弈。

## 牌组与发牌
- 使用标准 52 张扑克牌（无大小王），花色为黑桃（♠）、红桃（♥）、方块（♦）、梅花（♣）。
- 点数从大到小依次为：A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2。
- 开局每位玩家发 13 张手牌，剩余 26 张牌组成牌堆（Stock）。
- 翻开牌堆顶的第一张牌作为明牌（Up-card），**该张牌的花色即为整局的主花色（Trump Suit）**！

## 第一阶段：前 13 墩夺牌战（Forhand，牌堆未空时）
- 由非庄家先领出第一墩牌。
- 遵循标准吃墩规则：跟牌者若手中有领出花色，**必须跟出同花色**；若无领出花色，可垫任意副牌或用主花色毙牌（将吃）。
- 同花色比点数大小；有主花色参与时，最大主花色获胜；否则最大的领出花色获胜。
- **第一阶段赢墩不计分**，而是争夺牌堆中的牌：
  - **本墩赢家**：获得当前牌堆顶翻开的明牌（Up-card）加入手牌（双方都知道这张牌在赢家手中）！
  - **本墩输家**：暗摸牌堆下一张暗牌加入手牌（不向对手展示）！
  - 随后翻开牌堆新的顶牌作为下一墩争夺的明牌。
- 每墩结束双方各补 1 张牌，手牌始终维持 13 张，赢墩者领出下一墩。

## 第二阶段：后 13 墩决胜战（Endgame，牌堆摸空后）
- 前 13 墩结束时，26 张牌堆全部摸完，双方各持 13 张手牌（且清楚记得对手在第一阶段赢走的所有明牌）。
- 接着进行后 13 墩决胜战，规则同样为标准吃墩，不再摸牌。
- **计分规则**：后 13 墩中赢得超过 6 墩（即 7 墩及以上）的玩家赢得本局，获得 **（后 13 墩赢墩数 - 6）分**！

## 房间选项
- **局数（hands）**：支持 1 局决胜 或 3 局积分赛，总分高者获胜。
''';

class GermanWhist extends GameEngine {
  GermanWhist(super.setup);

  static const List<String> suits = ['S', 'H', 'D', 'C'];
  static const List<String> ranks = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
  static const Map<String, String> suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方块', 'C': '♣梅花'};

  static String cardSuit(String c) => c[c.length - 1];
  static String cardRank(String c) => c.substring(0, c.length - 1);
  static int rankVal(String c) => ranks.indexOf(cardRank(c)) + 2;

  static List<String> buildDeck() => [
        for (final s in suits)
          for (final r in ranks) '$r$s',
      ];

  static void sortHand(List<String> hand, String trumpSuit) {
    int suitOrder(String s) {
      if (s == trumpSuit) return 0;
      return suits.indexOf(s) + 1;
    }

    hand.sort((a, b) {
      final sa = suitOrder(cardSuit(a));
      final sb = suitOrder(cardSuit(b));
      if (sa != sb) return sa.compareTo(sb);
      return rankVal(b).compareTo(rankVal(a));
    });
  }

  static int trickWinner(String c0, int s0, String c1, int s1, String trumpSuit) {
    final suit0 = cardSuit(c0);
    final suit1 = cardSuit(c1);
    if (suit0 == suit1) {
      return rankVal(c1) > rankVal(c0) ? s1 : s0;
    }
    if (suit1 == trumpSuit) return s1;
    return s0;
  }

  late int targetHands;
  int handNo = 0;
  int dealer = 0;
  List<List<String>> hands = [[], []];
  List<String> stock = [];
  String trumpSuit = 'S';
  String firstUpCard = 'AS';
  String phase = 'forhand'; // 'forhand' | 'endgame' | 'handEnd' | 'over'
  int turn = 0;
  int trickLeader = 0;
  List<Map<String, dynamic>> trick = [];
  Map<String, dynamic>? lastTrick;
  List<int> phase1Tricks = [0, 0];
  List<int> phase2Tricks = [0, 0];
  List<int> scores = [0, 0];
  List<List<String>> knownUpCards = [[], []];
  List<bool> ready = [false, false];
  Map<String, dynamic>? result;
  List<String> logs = [];
  int resignedBy = -1;

  String? get upCard => stock.isNotEmpty ? stock.first : null;

  void _log(String msg) {
    logs.add(msg);
    if (logs.length > 30) logs.removeAt(0);
    host.log(msg);
  }

  @override
  void start() {
    targetHands = setup.opt<int>('hands', 1);
    scores = [0, 0];
    handNo = 0;
    dealer = 0;
    resignedBy = -1;
    _startHand();
  }

  void _startHand() {
    handNo++;
    if (handNo > 1) dealer = 1 - dealer;
    final deck = shuffled(buildDeck(), rng);
    hands = [
      deck.sublist(0, 13),
      deck.sublist(13, 26),
    ];
    stock = deck.sublist(26, 52);
    firstUpCard = stock.first;
    trumpSuit = cardSuit(firstUpCard);
    sortHand(hands[0], trumpSuit);
    sortHand(hands[1], trumpSuit);
    phase = 'forhand';
    trickLeader = 1 - dealer;
    turn = trickLeader;
    trick = [];
    lastTrick = null;
    phase1Tricks = [0, 0];
    phase2Tricks = [0, 0];
    knownUpCards = [[], []];
    ready = [false, false];
    result = null;
    _log('第 $handNo 局开始！翻开首张明牌 $firstUpCard，主花色为 ${suitNames[trumpSuit]}。');
  }

  List<String> legalCards(int seat) {
    final h = hands[seat];
    if (trick.isEmpty) return List.of(h);
    final ledSuit = cardSuit(trick.first['card'] as String);
    final sameSuit = h.where((c) => cardSuit(c) == ledSuit).toList();
    return sameSuit.isNotEmpty ? sameSuit : List.of(h);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'handEnd') {
      return [
        for (var s = 0; s < 2; s++)
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
    if (resignedBy >= 0) return rankWinners(2, [1 - resignedBy]);
    return rankByScore(scores);
  }

  @override
  bool get canResign => !isOver;

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= 2) throw GameError('当前无法认输');
    resignedBy = seat;
    phase = 'over';
    result = {
      'handNo': handNo,
      'winner': 1 - seat,
      'resigned': seat,
      'points': 0,
      'phase1Tricks': List.of(phase1Tricks),
      'phase2Tricks': List.of(phase2Tricks),
      'scores': List.of(scores),
    };
    _log('${name(seat)} 认输，${name(1 - seat)} 获胜！');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'handEnd') {
      if (type != 'continue') throw GameError('请点击继续下一局');
      if (seat < 0 || seat >= 2 || ready[seat]) throw GameError('已准备');
      ready[seat] = true;
      if (ready.every((x) => x)) {
        _startHand();
      }
      return;
    }

    if (seat != turn) throw GameError('还没轮到你出牌');
    if (type != 'play') throw GameError('无效操作');
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) throw GameError('手牌中没有这张牌');

    if (trick.isNotEmpty) {
      final ledSuit = cardSuit(trick.first['card'] as String);
      if (cardSuit(card) != ledSuit && hands[seat].any((c) => cardSuit(c) == ledSuit)) {
        throw GameError('必须跟出领出花色（${suitNames[ledSuit]}）');
      }
    }

    hands[seat].remove(card);
    knownUpCards[seat].remove(card);
    trick.add({'seat': seat, 'card': card});

    if (trick.length == 1) {
      turn = 1 - seat;
      return;
    }

    // Resolve completed trick of 2 cards
    final c0 = trick[0]['card'] as String;
    final s0 = trick[0]['seat'] as int;
    final c1 = trick[1]['card'] as String;
    final s1 = trick[1]['seat'] as int;
    final winner = trickWinner(c0, s0, c1, s1, trumpSuit);
    final loser = 1 - winner;

    if (phase == 'forhand') {
      phase1Tricks[winner]++;
      final wonUp = stock.removeAt(0);
      final drawnDown = stock.removeAt(0);
      hands[winner].add(wonUp);
      knownUpCards[winner].add(wonUp);
      hands[loser].add(drawnDown);
      sortHand(hands[0], trumpSuit);
      sortHand(hands[1], trumpSuit);
      lastTrick = {
        'cards': List.of(trick),
        'winner': winner,
        'upCard': wonUp,
        'phase': 'forhand',
      };
      _log('${name(winner)} 赢下本墩，收入明牌 $wonUp；${name(loser)} 暗摸1张。');
      trick = [];
      trickLeader = winner;
      turn = winner;
      if (stock.isEmpty) {
        phase = 'endgame';
        _log('前 13 墩结束，牌堆摸空！进入后 13 墩决胜战！');
      }
    } else {
      phase2Tricks[winner]++;
      lastTrick = {
        'cards': List.of(trick),
        'winner': winner,
        'upCard': null,
        'phase': 'endgame',
      };
      _log('${name(winner)} 赢下决胜墩（后半程 ${phase2Tricks[winner]} 墩）。');
      trick = [];
      trickLeader = winner;
      turn = winner;
      if (hands[0].isEmpty && hands[1].isEmpty) {
        _finishHand();
      }
    }
  }

  void _finishHand() {
    final w = phase2Tricks[0] > 6 ? 0 : 1;
    final pts = phase2Tricks[w] - 6;
    scores[w] += pts;
    result = {
      'handNo': handNo,
      'winner': w,
      'points': pts,
      'phase1Tricks': List.of(phase1Tricks),
      'phase2Tricks': List.of(phase2Tricks),
      'scores': List.of(scores),
    };
    _log('第 $handNo 局结束：${name(w)} 在后 13 墩赢下 ${phase2Tricks[w]} 墩，获得 +$pts 分！');
    if (handNo >= targetHands && scores[0] != scores[1]) {
      phase = 'over';
    } else if (handNo >= targetHands) {
      // Even if tied after targetHands, end the game (or if single-hand it never ties because 13 is odd)
      phase = 'over';
    } else {
      phase = 'handEnd';
      ready = [false, false];
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    if (phase == 'handEnd') {
      return ready[seat] ? null : {'type': 'continue'};
    }
    if (seat != turn) return null;
    final legals = legalCards(seat);
    if (legals.isEmpty) return null;
    if (botLevel == 0 || legals.length == 1) {
      return {'type': 'play', 'card': legals[rng.nextInt(legals.length)]};
    }

    // Score a card's intrinsic power
    int cardPower(String c) => (cardSuit(c) == trumpSuit ? 20 : 0) + rankVal(c);
    final sorted = List.of(legals)..sort((a, b) => cardPower(a).compareTo(cardPower(b)));

    if (phase == 'forhand') {
      final up = upCard;
      final wantUp = up != null && (cardSuit(up) == trumpSuit || rankVal(up) >= 10);
      if (trick.isEmpty) {
        // Leading in Phase 1
        if (wantUp) {
          // Lead a strong non-trump or medium card to fight for the desirable upCard
          final nonTrumps = sorted.where((c) => cardSuit(c) != trumpSuit).toList();
          if (nonTrumps.isNotEmpty) {
            return {'type': 'play', 'card': nonTrumps.last};
          }
          return {'type': 'play', 'card': sorted.last};
        } else {
          // Duck undesirable low upCard: lead a low non-trump
          return {'type': 'play', 'card': sorted.first};
        }
      } else {
        // Following in Phase 1
        final ledCard = trick.first['card'] as String;
        final ledSeat = trick.first['seat'] as int;
        final winning = sorted.where((c) => trickWinner(ledCard, ledSeat, c, seat, trumpSuit) == seat).toList();
        final losing = sorted.where((c) => trickWinner(ledCard, ledSeat, c, seat, trumpSuit) != seat).toList();
        if (wantUp) {
          if (winning.isNotEmpty) return {'type': 'play', 'card': winning.first};
          return {'type': 'play', 'card': losing.first};
        } else {
          if (losing.isNotEmpty) {
            return {'type': 'play', 'card': botLevel >= 2 ? losing.last : losing.first};
          }
          return {'type': 'play', 'card': winning.first};
        }
      }
    } else {
      // Phase 2 ('endgame'): every trick counts!
      if (trick.isEmpty) {
        final nonTrumps = sorted.where((c) => cardSuit(c) != trumpSuit).toList();
        if (nonTrumps.isNotEmpty && rankVal(nonTrumps.last) >= 13) {
          return {'type': 'play', 'card': nonTrumps.last};
        }
        return {'type': 'play', 'card': sorted[sorted.length ~/ 2]};
      } else {
        final ledCard = trick.first['card'] as String;
        final ledSeat = trick.first['seat'] as int;
        final winning = sorted.where((c) => trickWinner(ledCard, ledSeat, c, seat, trumpSuit) == seat).toList();
        if (winning.isNotEmpty) {
          return {'type': 'play', 'card': winning.first};
        }
        return {'type': 'play', 'card': sorted.first};
      }
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final vSeat = seat >= 0 && seat < 2 ? seat : -1;
    final overallWinner = scores[0] == scores[1]
        ? (resignedBy >= 0 ? 1 - resignedBy : -1)
        : (scores[0] > scores[1] ? 0 : 1);
    return {
      'phase': phase,
      'handNo': handNo,
      'targetHands': targetHands,
      'dealer': dealer,
      'turn': turn,
      'trickLeader': trickLeader,
      'trumpSuit': trumpSuit,
      'firstUpCard': firstUpCard,
      'upCard': upCard,
      'stockCount': stock.length,
      'faceDownStockCount': stock.isEmpty ? 0 : stock.length - 1,
      'hand': vSeat >= 0 ? List.of(hands[vSeat]) : const <String>[],
      'legal': vSeat >= 0 && vSeat == turn && (phase == 'forhand' || phase == 'endgame')
          ? legalCards(vSeat)
          : const <String>[],
      'counts': [hands[0].length, hands[1].length],
      'knownUpCards': [List.of(knownUpCards[0]), List.of(knownUpCards[1])],
      'trick': List.of(trick),
      'lastTrick': lastTrick,
      'phase1Tricks': List.of(phase1Tricks),
      'phase2Tricks': List.of(phase2Tricks),
      'scores': List.of(scores),
      'ready': List.of(ready),
      'result': result,
      'winner': isOver ? overallWinner : -1,
      'resigned': resignedBy >= 0,
      'log': List.of(logs),
    };
  }
}
