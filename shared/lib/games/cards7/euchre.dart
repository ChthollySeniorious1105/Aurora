import '../../src/engine.dart';

const String euchreRules = '''
# 尤克牌 (Euchre) 规则说明

## 基本配置
- **人数与组队**：4人固定搭档对抗，座位 0 与 2 为一队（蓝队），座位 1 与 3 为另一队（红队）。
- **牌库构成**：使用 24 张标准扑克牌，包含黑桃 (♠)、红桃 (♥)、方块 (♦)、梅花 (♣) 四种花色的 `9, 10, J, Q, K, A`。
- **发牌与底牌**：每局由庄家给每位玩家发 5 张手牌，剩余 4 张作为底牌（Kitty），并将底牌顶部的第 1 张翻开亮出（Up-card）。

## 正副司令规则 (Right & Left Bower)
确定主花色（Trump）后，主花色与同色花色的两张 `J` 成为最强王牌：
- **正司令 (Right Bower)**：主花色的 `J`，为全场最大的第 1 强牌。
- **副司令 (Left Bower)**：与主花色**同颜色**另一花色的 `J`（黑桃♠ ↔ 梅花♣，红桃♥ ↔ 方块♦），为全场第 2 强牌。
- **关键归属规则**：副司令在整局打牌期间，其**实际花色（Effective Suit）完全视为主花色**，而不再属于原本印制的花色！跟牌时必须按实际花色跟牌。
- **大小顺序**：
  - 主花色：`正司令 (主J) > 副司令 (同色J) > A > K > Q > 10 > 9`（共 7 张主牌）。
  - 副花色：`A > K > Q > J（若非副司令） > 10 > 9`。

## 叫主流程
1. **第一轮叫牌 (bid1)**：从庄家左手边开始顺时针表态：
   - **上牌定主 (Order Up)**：令翻开的底牌花色成为本局主花色。叫主者所在队伍成为**庄方（Makers）**，另一队为**守方（Defenders）**。随后进入庄家换牌阶段（`dealer_discard`），庄家将翻开的底牌收入手牌并弃掉 1 张牌（保持 5 张手牌）。
   - **过牌 (Pass)**：不叫主。若 4 人全部选择过牌，则将翻开的底牌扣下，进入第二轮叫牌。
2. **第二轮叫牌 (bid2)**：仍从庄家左手边开始顺时针表态：
   - **指定主花色 (Call)**：任选一种**不同于第一轮被扣下底牌花色**的花色作为主花色。
   - **庄家必叫 (Stick the Dealer)**：若开启此选项，第二轮前 3 人都过牌时，庄家必须指定一种主花色，不可过牌；若关闭此选项且 4 人全过，则换下家洗牌重发。
3. **独打 (Going Alone)**：在第一轮上牌或第二轮指定主花色时，叫主玩家可同时宣言“独打（Alone）”。独打时，叫主者的同伴本局袖手旁观（不参与出牌），由叫主者 1 人单挑对方 2 人！

## 出牌与跟牌 (Play)
- 共进行 5 墩（Tricks）。第 1 墩由庄家左手边第一位参与本局的玩家首引（若该座位因同伴独打而旁观，则顺延至下一位）。
- **必须跟花色**：后续出牌者若持有与首引牌**实际花色**相同的牌，必须跟出该花色（切记副司令属于主花色！）；若无首引花色，可出任意牌（含主牌毙牌或垫牌）。
- **赢墩判定**：若有人打出主花色牌，则最大的主花色牌赢墩；若无人出主牌，则最大的首引花色牌赢墩。赢墩者获得下一墩的领出权。

## 计分与胜负
5 墩打完后按庄方（Makers）赢得的墩数计分：
- **庄方赢 3 或 4 墩**：庄方完成合约，得 **+1 分**。
- **庄方全赢 5 墩 (March)**：庄方得 **+2 分**；若为**独打 (Alone)** 全赢 5 墩，庄方得 **+4 分**！
- **守方赢 3 墩及以上 (Euchred / 反噬)**：庄方合约失败，守方得 **+2 分**！
- 率先达到目标分数（10分标准 / 5分快速）的队伍获胜。
''';

const List<String> kEuchreSuits = ['S', 'H', 'D', 'C'];
const List<String> kEuchreRanks = ['9', 'T', 'J', 'Q', 'K', 'A'];

String euchreSuitOf(String card) => card.substring(card.length - 1);
String euchreRankOf(String card) => card.substring(0, card.length - 1);

String sameColorSuit(String suit) {
  switch (suit) {
    case 'S':
      return 'C';
    case 'C':
      return 'S';
    case 'H':
      return 'D';
    case 'D':
      return 'H';
    default:
      return suit;
  }
}

bool isRightBower(String card, String? trumpSuit) =>
    trumpSuit != null && card == 'J$trumpSuit';

bool isLeftBower(String card, String? trumpSuit) =>
    trumpSuit != null && card == 'J${sameColorSuit(trumpSuit)}';

/// Effective suit of [card] given [trumpSuit].
/// The Left Bower's effective suit IS [trumpSuit], not its printed suit!
String effectiveSuit(String card, String? trumpSuit) {
  if (trumpSuit != null && isLeftBower(card, trumpSuit)) {
    return trumpSuit;
  }
  return euchreSuitOf(card);
}

int _baseRankVal(String rank) {
  switch (rank) {
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
    case 'A':
      return 14;
    default:
      return 0;
  }
}

/// Power of [card] in a trick where [ledSuit] (already effective suit) was led
/// and [trumpSuit] is trump.
int euchreCardPower(String card, {required String ledSuit, required String trumpSuit}) {
  if (isRightBower(card, trumpSuit)) return 100;
  if (isLeftBower(card, trumpSuit)) return 90;
  final eff = effectiveSuit(card, trumpSuit);
  final rv = _baseRankVal(euchreRankOf(card));
  if (eff == trumpSuit) return 50 + rv;
  if (eff == ledSuit) return 10 + rv;
  return 0;
}

List<String> buildEuchreDeck() => [
      for (final s in kEuchreSuits)
        for (final r in kEuchreRanks) '$r$s',
    ];

class Euchre extends GameEngine {
  late int targetScore;
  late bool stickDealer;

  int handNumber = 1;
  int dealer = 0;
  int turn = 1;
  String phase = 'bid1'; // 'bid1', 'dealer_discard', 'bid2', 'play', 'over'

  List<List<String>> hands = [[], [], [], []];
  List<String> kitty = [];
  String? upCard;
  String? turnedDownSuit;
  String? trumpSuit;

  int makerSeat = -1;
  int makerTeam = -1;
  bool goingAlone = false;
  int aloneSeat = -1;
  int sittingOutSeat = -1;

  int passesInRound = 0;
  int redealCount = 0;

  int trickNum = 1;
  List<Map<String, dynamic>> currentTrick = [];
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastHandResult;

  List<int> tricksWon = [0, 0, 0, 0];
  List<int> teamTricks = [0, 0];
  List<int> teamScores = [0, 0];

  bool _over = false;
  int _winnerTeam = -1;

  Euchre(super.setup) {
    targetScore = setup.opt<int>('target', 10);
    stickDealer = setup.opt<bool>('stickDealer', true);
  }

  @override
  bool get isOver => _over;

  @override
  bool get canResign => !_over;

  @override
  void resign(int seat) {
    if (_over) throw GameError('游戏已结束');
    _over = true;
    phase = 'over';
    _winnerTeam = 1 - (seat % 2);
    host.log('${name(seat)} 认输，${_winnerTeam == 0 ? "蓝队(0&2)" : "红队(1&3)"} 获胜！');
  }

  @override
  List<int>? get placings {
    if (!_over) return null;
    final winners = _winnerTeam == 0 ? const [0, 2] : const [1, 3];
    return rankWinners(4, winners);
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  void start() {
    dealer = 0;
    dealHand();
  }

  void dealHand() {
    final deck = shuffled(buildEuchreDeck(), rng);
    hands = [
      for (var s = 0; s < 4; s++) deck.sublist(s * 5, (s + 1) * 5),
    ];
    kitty = deck.sublist(20, 24);
    upCard = kitty.first;
    turnedDownSuit = null;
    trumpSuit = null;
    makerSeat = -1;
    makerTeam = -1;
    goingAlone = false;
    aloneSeat = -1;
    sittingOutSeat = -1;
    passesInRound = 0;
    trickNum = 1;
    currentTrick = [];
    tricksWon = [0, 0, 0, 0];
    teamTricks = [0, 0];
    phase = 'bid1';
    turn = (dealer + 1) % 4;
    _sortAllHands();
  }

  void _sortAllHands() {
    for (var s = 0; s < 4; s++) {
      hands[s].sort((a, b) {
        final sa = effectiveSuit(a, trumpSuit);
        final sb = effectiveSuit(b, trumpSuit);
        if (sa != sb) {
          if (sa == trumpSuit) return -1;
          if (sb == trumpSuit) return 1;
          return kEuchreSuits.indexOf(sa).compareTo(kEuchreSuits.indexOf(sb));
        }
        final pa = trumpSuit != null
            ? euchreCardPower(a, ledSuit: sa, trumpSuit: trumpSuit!)
            : _baseRankVal(euchreRankOf(a));
        final pb = trumpSuit != null
            ? euchreCardPower(b, ledSuit: sb, trumpSuit: trumpSuit!)
            : _baseRankVal(euchreRankOf(b));
        return pb.compareTo(pa);
      });
    }
  }

  int nextActiveSeat(int from) {
    var s = (from + 1) % 4;
    while (s == sittingOutSeat) {
      s = (s + 1) % 4;
    }
    return s;
  }

  void _setMaker(int seat, String suit, bool alone) {
    trumpSuit = suit;
    makerSeat = seat;
    makerTeam = seat % 2;
    goingAlone = alone;
    aloneSeat = alone ? seat : -1;
    sittingOutSeat = alone ? (seat + 2) % 4 : -1;
    _sortAllHands();
  }

  void startPlayPhase() {
    phase = 'play';
    trickNum = 1;
    currentTrick = [];
    tricksWon = [0, 0, 0, 0];
    teamTricks = [0, 0];
    var first = (dealer + 1) % 4;
    if (first == sittingOutSeat) {
      first = nextActiveSeat(first);
    }
    turn = first;
    _sortAllHands();
  }

  List<String> legalPlays(int seat) {
    final h = hands[seat];
    if (currentTrick.isEmpty || trumpSuit == null) return List.of(h);
    final ledCard = currentTrick.first['card'] as String;
    final ledSuit = effectiveSuit(ledCard, trumpSuit);
    final follow = h.where((c) => effectiveSuit(c, trumpSuit) == ledSuit).toList();
    return follow.isNotEmpty ? follow : List.of(h);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (phase == 'bid1') {
      if (type == 'order_up') {
        if (upCard == null) throw GameError('当前没有可上牌的底牌');
        final alone = asBool(action['alone']);
        final suit = euchreSuitOf(upCard!);
        _setMaker(seat, suit, alone);
        hands[dealer].add(upCard!);
        _sortAllHands();
        phase = 'dealer_discard';
        turn = dealer;
        host.log('${name(seat)} 令庄家拾起 $upCard 定主 ${_suitName(suit)}${alone ? "（独打！）" : ""}');
        return;
      }
      if (type == 'pass') {
        passesInRound++;
        if (passesInRound >= 4) {
          turnedDownSuit = euchreSuitOf(upCard!);
          phase = 'bid2';
          passesInRound = 0;
          turn = (dealer + 1) % 4;
          host.log('第一轮无人叫主，底牌 $upCard 扣下，进入自由选主阶段');
        } else {
          turn = (turn + 1) % 4;
        }
        return;
      }
      throw GameError('第一轮叫牌只能选择 order_up 或 pass');
    }

    if (phase == 'dealer_discard') {
      if (type != 'discard') throw GameError('庄家请选择一张手牌弃掉');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手里没有这张牌：$card');
      hands[seat].remove(card);
      startPlayPhase();
      return;
    }

    if (phase == 'bid2') {
      if (type == 'call') {
        final suit = asStr(action['suit']);
        if (!kEuchreSuits.contains(suit)) throw GameError('无效的花色：$suit');
        if (suit == turnedDownSuit) {
          throw GameError('第二轮不能选择已被扣下的底牌花色 ${_suitName(suit)}');
        }
        final alone = asBool(action['alone']);
        _setMaker(seat, suit, alone);
        host.log('${name(seat)} 指定主花色为 ${_suitName(suit)}${alone ? "（独打！）" : ""}');
        startPlayPhase();
        return;
      }
      if (type == 'pass') {
        if (passesInRound >= 3 && stickDealer) {
          throw GameError('庄家必叫开启时，庄家必须指定一种主花色');
        }
        passesInRound++;
        if (passesInRound >= 4) {
          redealCount++;
          dealer = (dealer + 1) % 4;
          host.log('第二轮无人叫主，轮换庄家重新发牌');
          dealHand();
        } else {
          turn = (turn + 1) % 4;
        }
        return;
      }
      throw GameError('第二轮叫牌只能选择 call 或 pass');
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('出牌阶段请打出合法手牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手里没有这张牌：$card');
      final legal = legalPlays(seat);
      if (!legal.contains(card)) {
        throw GameError('必须跟出首引花色（注意副司令归属主花色）');
      }

      hands[seat].remove(card);
      currentTrick.add({'seat': seat, 'card': card});

      final needed = goingAlone ? 3 : 4;
      if (currentTrick.length < needed) {
        turn = nextActiveSeat(seat);
        return;
      }

      // Resolve trick
      final ledCard = currentTrick.first['card'] as String;
      final ledSuit = effectiveSuit(ledCard, trumpSuit);
      var bestSeat = currentTrick.first['seat'] as int;
      var bestCard = ledCard;
      var bestPower = euchreCardPower(ledCard, ledSuit: ledSuit, trumpSuit: trumpSuit!);

      for (var i = 1; i < currentTrick.length; i++) {
        final playSeat = currentTrick[i]['seat'] as int;
        final playCard = currentTrick[i]['card'] as String;
        final p = euchreCardPower(playCard, ledSuit: ledSuit, trumpSuit: trumpSuit!);
        if (p > bestPower) {
          bestPower = p;
          bestSeat = playSeat;
          bestCard = playCard;
        }
      }

      tricksWon[bestSeat]++;
      teamTricks[bestSeat % 2]++;
      lastTrick = {
        'trick': trickNum,
        'leader': currentTrick.first['seat'],
        'winner': bestSeat,
        'winningCard': bestCard,
        'ledSuit': ledSuit,
        'cards': [
          for (final item in currentTrick) {'seat': item['seat'], 'card': item['card']},
        ],
      };
      currentTrick = [];

      if (trickNum < 5) {
        trickNum++;
        turn = bestSeat;
        return;
      }

      // Hand complete -> score hand
      _scoreCompletedHand();
      return;
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _scoreCompletedHand() {
    final mTricks = teamTricks[makerTeam];
    final defTeam = 1 - makerTeam;
    int pts;
    int winTeam;
    String reason;

    if (mTricks == 5) {
      pts = goingAlone ? 4 : 2;
      winTeam = makerTeam;
      reason = goingAlone ? '独打全胜 (Lone March) +4' : '全胜五墩 (March) +2';
    } else if (mTricks >= 3) {
      pts = 1;
      winTeam = makerTeam;
      reason = '叫主成功 ($mTricks/5墩) +1';
    } else {
      pts = 2;
      winTeam = defTeam;
      reason = '防守反噬 (Euchred!) +2';
    }

    teamScores[winTeam] += pts;
    lastHandResult = {
      'hand': handNumber,
      'makerSeat': makerSeat,
      'makerTeam': makerTeam,
      'trumpSuit': trumpSuit,
      'goingAlone': goingAlone,
      'makerTricks': mTricks,
      'defenderTricks': teamTricks[defTeam],
      'scoringTeam': winTeam,
      'points': pts,
      'reason': reason,
    };
    host.log('第 $handNumber 局结算：$reason，比分 蓝队 ${teamScores[0]} : ${teamScores[1]} 红队');

    if (teamScores[winTeam] >= targetScore) {
      _over = true;
      phase = 'over';
      _winnerTeam = winTeam;
      host.log('比赛结束！${_winnerTeam == 0 ? "蓝队(0&2)" : "红队(1&3)"} 率先达到 $targetScore 分获胜！');
    } else {
      handNumber++;
      redealCount = 0;
      dealer = (dealer + 1) % 4;
      dealHand();
    }
  }

  String _suitName(String? s) {
    switch (s) {
      case 'S':
        return '♠黑桃';
      case 'H':
        return '♥红桃';
      case 'D':
        return '♦方块';
      case 'C':
        return '♣梅花';
      default:
        return '-';
    }
  }

  int _evaluateHandForTrump(List<String> hand, String suit) {
    var score = 0;
    for (final c in hand) {
      if (isRightBower(c, suit)) {
        score += 35;
      } else if (isLeftBower(c, suit)) {
        score += 30;
      } else if (effectiveSuit(c, suit) == suit) {
        final r = euchreRankOf(c);
        score += r == 'A' ? 22 : (r == 'K' ? 16 : (r == 'Q' ? 14 : 11));
      } else if (euchreRankOf(c) == 'A') {
        score += 10;
      }
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    final h = hands[seat];

    if (phase == 'bid1') {
      final suit = euchreSuitOf(upCard!);
      var str = _evaluateHandForTrump(h, suit);
      if (dealer % 2 == seat % 2) str += 8; // partner or self picks up upCard
      final threshold = botLevel == 0 ? 60 : 52;
      if (str >= threshold) {
        final alone = str >= 92;
        return {'type': 'order_up', 'alone': alone};
      }
      return {'type': 'pass'};
    }

    if (phase == 'dealer_discard') {
      // Discard weakest non-trump card (or weakest card overall)
      final sorted = List.of(h)
        ..sort((a, b) {
          final pa = euchreCardPower(a, ledSuit: effectiveSuit(a, trumpSuit), trumpSuit: trumpSuit!);
          final pb = euchreCardPower(b, ledSuit: effectiveSuit(b, trumpSuit), trumpSuit: trumpSuit!);
          return pa.compareTo(pb);
        });
      return {'type': 'discard', 'card': sorted.first};
    }

    if (phase == 'bid2') {
      final candidates = kEuchreSuits.where((s) => s != turnedDownSuit).toList();
      var bestSuit = candidates.first;
      var bestScore = -1;
      for (final s in candidates) {
        final sc = _evaluateHandForTrump(h, s);
        if (sc > bestScore) {
          bestScore = sc;
          bestSuit = s;
        }
      }
      final mustCall = (passesInRound >= 3 && stickDealer) || redealCount >= 2;
      if (mustCall || bestScore >= 52) {
        return {'type': 'call', 'suit': bestSuit, 'alone': bestScore >= 92};
      }
      return {'type': 'pass'};
    }

    if (phase == 'play') {
      final legal = legalPlays(seat);
      if (legal.length == 1 || botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      if (currentTrick.isEmpty) {
        // Lead highest card
        final sorted = List.of(legal)
          ..sort((a, b) {
            final pa = euchreCardPower(a, ledSuit: effectiveSuit(a, trumpSuit), trumpSuit: trumpSuit!);
            final pb = euchreCardPower(b, ledSuit: effectiveSuit(b, trumpSuit), trumpSuit: trumpSuit!);
            return pb.compareTo(pa);
          });
        return {'type': 'play', 'card': sorted.first};
      } else {
        final ledCard = currentTrick.first['card'] as String;
        final ledSuit = effectiveSuit(ledCard, trumpSuit);
        var bestSeatSoFar = currentTrick.first['seat'] as int;
        var bestPowSoFar = euchreCardPower(ledCard, ledSuit: ledSuit, trumpSuit: trumpSuit!);
        for (var i = 1; i < currentTrick.length; i++) {
          final s = currentTrick[i]['seat'] as int;
          final c = currentTrick[i]['card'] as String;
          final p = euchreCardPower(c, ledSuit: ledSuit, trumpSuit: trumpSuit!);
          if (p > bestPowSoFar) {
            bestPowSoFar = p;
            bestSeatSoFar = s;
          }
        }
        final partnerWinning = (bestSeatSoFar % 2) == (seat % 2);
        final sortedAsc = List.of(legal)
          ..sort((a, b) => euchreCardPower(a, ledSuit: ledSuit, trumpSuit: trumpSuit!)
              .compareTo(euchreCardPower(b, ledSuit: ledSuit, trumpSuit: trumpSuit!)));
        if (partnerWinning) {
          return {'type': 'play', 'card': sortedAsc.first};
        }
        final winners = sortedAsc
            .where((c) => euchreCardPower(c, ledSuit: ledSuit, trumpSuit: trumpSuit!) > bestPowSoFar)
            .toList();
        if (winners.isNotEmpty) {
          return {'type': 'play', 'card': winners.first};
        }
        return {'type': 'play', 'card': sortedAsc.first};
      }
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < 4) ? List<String>.of(hands[seat]) : const <String>[];
    final myLegal = (seat >= 0 && seat < 4 && seat == turn && phase == 'play')
        ? legalPlays(seat)
        : const <String>[];

    return {
      'phase': phase,
      'handNumber': handNumber,
      'dealer': dealer,
      'turn': turn,
      'targetScore': targetScore,
      'stickDealer': stickDealer,
      'upCard': phase == 'bid1' || phase == 'dealer_discard' ? upCard : null,
      'turnedDownSuit': turnedDownSuit,
      'trumpSuit': trumpSuit,
      'rightBower': trumpSuit != null ? 'J$trumpSuit' : null,
      'leftBower': trumpSuit != null ? 'J${sameColorSuit(trumpSuit!)}' : null,
      'makerSeat': makerSeat,
      'makerTeam': makerTeam,
      'goingAlone': goingAlone,
      'aloneSeat': aloneSeat,
      'sittingOutSeat': sittingOutSeat,
      'trickNum': trickNum,
      'currentTrick': [
        for (final item in currentTrick)
          {
            'seat': item['seat'],
            'card': item['card'],
            'effectiveSuit': effectiveSuit(item['card'] as String, trumpSuit),
          },
      ],
      'lastTrick': lastTrick,
      'lastHandResult': lastHandResult,
      'tricksWon': List<int>.of(tricksWon),
      'teamTricks': List<int>.of(teamTricks),
      'teamScores': List<int>.of(teamScores),
      'handCounts': [for (var s = 0; s < 4; s++) hands[s].length],
      'kittyCount': kitty.length,
      'hand': myHand,
      'legalPlays': myLegal,
      'winnerTeam': _winnerTeam,
      'over': _over,
    };
  }
}
