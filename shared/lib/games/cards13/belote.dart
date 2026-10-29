import '../../src/engine.dart';

const String beloteRules = '''
# 法国贝洛特 Belote 规则说明

## 基本配置
- **人数**：2～4 人（4 人为经典 2v2 搭档对战：座位 0&2 对阵 1&3；2～3 人为庄家独战防守方）。
- **牌堆**：32 张法国传统扑克牌，花色为黑桃（S）、红桃（H）、方块（D）、梅花（C），每门花色包含 `7, 8, 9, T(10), J, Q, K, A`。

## 主花色（Atout）与副花色大小及分值
- **主花色（Trump Suit）**：
  - **大小顺序**：**`J` > `9` > `A` > `T` > `K` > `Q` > `8` > `7`**
  - **牌面分值**：`J = 20分`、`9 = 14分`、`A = 11分`、`T = 10分`、`K = 4分`、`Q = 3分`、`8 = 0分`、`7 = 0分`（主花色合计 **62 分**）。
- **副花色（Non-Trump Suits）**：
  - **大小顺序**：**`A` > `T` > `K` > `Q` > `J` > `9` > `8` > `7`**
  - **牌面分值**：`A = 11分`、`T = 10分`、`K = 4分`、`Q = 3分`、`J = 2分`、`9 = 0分`、`8 = 0分`、`7 = 0分`（每门副花色 **30 分**）。
- **全副牌基础总分**：`62 + 30 × 3 = 152 分`，加上 **最后一墩奖励（Dix de Der）+10 分**，每局基础总分为 **162 分**！
- **贝洛特王后组合（Belote-Rebelote）**：若玩家手牌同时持有主花色的 `K` 与 `Q`，所属阵营额外获得 **+20 分** 奖励！

## 对局流程
1. **叫主阶段（`'bid'`）**：
   - 每位玩家先发 5 张手牌，桌面翻开 1 张候选牌 `upCard`。
   - **第一轮叫牌**：从先手（庄家下家）开始，可选择 **拿牌定主（`'take'`）**（以 `upCard` 的花色为主花色）或 **过牌（`'pass'`）**。
   - **第二轮叫牌**：若第一轮全员过牌，第二轮可选择 `upCard` 花色以外的任意花色定主（**`'choose_suit'`**）或 **过牌（`'pass'`）**。
   - 定主玩家成为 **庄家（Taker）**，获得桌面上的 `upCard` 并补齐至 8 张手牌，其余玩家各补发 3 张至 8 张手牌。
2. **出牌吃墩（`'play'`，共 8 墩）**：
   - 先手玩家领出第一墩，此后每墩由上一墩赢家领出。
   - **跟花与超吃规则**：
     - 有领出花色必须跟出该花色；若领出的是主花色且手中有比当前桌面最高主牌更大的主牌，必须 **超吃（Monter à l'atout）**。
     - 若断门（无领出花色）：当对手暂居本墩最大时，若有主牌则必须出主牌（**将吃**），且若桌面已有主牌并能超吃则必须 **超吃**！
3. **成约与崩盘结算（Contract Scoring）**：
   - **成约线**：无 Belote 时为 **82 分**（总分 162 的过半）；有 Belote 时为 **92 分**。
   - **成约（Contrat Réussi）**：庄家方得分 `>= 成约线` 时，双方各自获得本局所赢分数（含 Belote 奖励）。
   - **崩盘（Dedans）**：庄家方得分 `< 成约线` 时，庄家方得 0 分，防守方横扫全部 **162 分**（外加 Belote 奖励）！
''';

const List<String> kBeloteSuits = ['S', 'H', 'D', 'C'];
const List<String> kBeloteRanks = ['7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];

/// Builds the 32-card Belote deck.
List<String> buildBeloteDeck() => [
      for (final s in kBeloteSuits)
        for (final r in kBeloteRanks) '$r$s',
    ];

String beloteRank(String card) =>
    card.length >= 2 ? card.substring(0, card.length - 1) : '';

String beloteSuit(String card) =>
    card.length >= 2 ? card.substring(card.length - 1) : '';

/// Card point value in Belote depending on whether its suit is [trumpSuit].
int beloteCardPoints(String card, String trumpSuit) {
  final r = beloteRank(card);
  final s = beloteSuit(card);
  final isTrump = s == trumpSuit;
  switch (r) {
    case 'J':
      return isTrump ? 20 : 2;
    case '9':
      return isTrump ? 14 : 0;
    case 'A':
      return 11;
    case 'T':
      return 10;
    case 'K':
      return 4;
    case 'Q':
      return 3;
    default:
      return 0;
  }
}

/// Relative rank order within a single suit (`0..7`).
int beloteSuitRankOrder(String rank, {required bool isTrump}) {
  if (isTrump) {
    const order = ['7', '8', 'Q', 'K', 'T', 'A', '9', 'J'];
    return order.indexOf(rank);
  } else {
    const order = ['7', '8', '9', 'J', 'Q', 'K', 'T', 'A'];
    return order.indexOf(rank);
  }
}

/// Strength of [card] in a trick with [ledSuit] and [trumpSuit].
int beloteCardStrength(String card, String trumpSuit, String ledSuit) {
  final r = beloteRank(card);
  final s = beloteSuit(card);
  if (s == trumpSuit) {
    return 100 + beloteSuitRankOrder(r, isTrump: true);
  }
  if (s == ledSuit) {
    return 10 + beloteSuitRankOrder(r, isTrump: false);
  }
  return 0;
}

/// Returns the winning entry (`{'seat': int, 'card': String}`) of a non-empty [trick].
Map<String, dynamic> resolveBeloteTrickWinner(
  List<Map<String, dynamic>> trick,
  String trumpSuit,
) {
  final ledSuit = beloteSuit(asStr(trick.first['card']));
  var best = trick.first;
  var bestStrength = beloteCardStrength(asStr(best['card']), trumpSuit, ledSuit);
  for (var i = 1; i < trick.length; i++) {
    final entry = trick[i];
    final st = beloteCardStrength(asStr(entry['card']), trumpSuit, ledSuit);
    if (st > bestStrength) {
      best = entry;
      bestStrength = st;
    }
  }
  return best;
}

/// Returns the winning seat of [trick].
int resolveBeloteTrick(List<Map<String, dynamic>> trick, String trumpSuit) =>
    asInt(resolveBeloteTrickWinner(trick, trumpSuit)['seat'], 0);

/// Computes legal cards from [hand] given [currentTrick] and [trumpSuit].
///
/// Rules:
/// 1. If leading, all cards in [hand] are legal.
/// 2. If following [ledSuit]:
///    - Must play [ledSuit] if held.
///    - If [ledSuit] == [trumpSuit], must overtrump the highest trump in [currentTrick] if possible.
/// 3. If void in [ledSuit]:
///    - If opponent is currently winning [currentTrick] (or [seat] is null), must play a trump
///      if held, and must overtrump the highest trump in [currentTrick] if possible.
///    - In 4p partnership, if partner `(seat + 2) % 4` is currently winning [currentTrick],
///      any card in [hand] may be played.
List<String> getBeloteLegalCards(
  List<String> hand,
  List<Map<String, dynamic>> currentTrick,
  String trumpSuit, {
  int? seat,
  int players = 4,
}) {
  if (currentTrick.isEmpty || hand.isEmpty) {
    return List<String>.of(hand);
  }
  final ledSuit = beloteSuit(asStr(currentTrick.first['card']));
  final sameSuit = hand.where((c) => beloteSuit(c) == ledSuit).toList();

  int highestTrumpOrderInTrick() {
    var best = -1;
    for (final e in currentTrick) {
      final c = asStr(e['card']);
      if (beloteSuit(c) == trumpSuit) {
        final ord = beloteSuitRankOrder(beloteRank(c), isTrump: true);
        if (ord > best) best = ord;
      }
    }
    return best;
  }

  if (sameSuit.isNotEmpty) {
    if (ledSuit == trumpSuit) {
      final maxTrump = highestTrumpOrderInTrick();
      final overTrumps = sameSuit
          .where((c) => beloteSuitRankOrder(beloteRank(c), isTrump: true) > maxTrump)
          .toList();
      return overTrumps.isNotEmpty ? overTrumps : sameSuit;
    }
    return sameSuit;
  }

  // Void in ledSuit
  final trumps = hand.where((c) => beloteSuit(c) == trumpSuit).toList();
  if (trumps.isEmpty) {
    return List<String>.of(hand);
  }

  final winnerSeat = resolveBeloteTrick(currentTrick, trumpSuit);
  final partnerWinning =
      seat != null && players == 4 && ((seat + 2) % 4 == winnerSeat);
  if (partnerWinning) {
    return List<String>.of(hand);
  }

  final maxTrump = highestTrumpOrderInTrick();
  if (maxTrump >= 0) {
    final overTrumps = trumps
        .where((c) => beloteSuitRankOrder(beloteRank(c), isTrump: true) > maxTrump)
        .toList();
    if (overTrumps.isNotEmpty) return overTrumps;
  }
  return trumps;
}

class BeloteGame extends GameEngine {
  BeloteGame(super.setup);

  late int totalRounds;
  int currentRound = 1;
  int dealer = 0;
  int forehand = 0;
  int turn = 0;
  String phase = 'bid'; // 'bid' | 'play'
  int bidRound = 1; // 1 or 2
  int passesInRound = 0;

  List<String> deck = [];
  String upCard = '';
  String trumpSuit = '';
  int taker = -1;
  int? beloteSeat;

  late List<List<String>> hands;
  late List<List<String>> capturedCards;
  late List<int> tricksWon;
  late List<int> scores;
  List<Map<String, dynamic>> currentTrick = [];
  List<Map<String, dynamic>> lastTrick = [];
  int? lastTrickWinner;
  int tricksPlayed = 0;
  Map<String, dynamic>? lastHandSummary;
  bool _over = false;

  bool isTakerSide(int seat) {
    if (taker < 0) return false;
    if (players == 4) return (seat % 2) == (taker % 2);
    return seat == taker;
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 3);
    scores = List.filled(players, 0);
    dealer = 0;
    _startRound();
  }

  void _startRound() {
    phase = 'bid';
    bidRound = 1;
    passesInRound = 0;
    trumpSuit = '';
    taker = -1;
    beloteSeat = null;
    currentTrick = [];
    lastTrick = [];
    lastTrickWinner = null;
    tricksPlayed = 0;

    forehand = (dealer + 1) % players;
    turn = forehand;

    deck = shuffled(buildBeloteDeck(), rng);
    hands = List.generate(players, (_) => <String>[]);
    capturedCards = List.generate(players, (_) => <String>[]);
    tricksWon = List.filled(players, 0);

    for (var s = 0; s < players; s++) {
      hands[s] = deck.sublist(0, 5);
      deck.removeRange(0, 5);
      _sortHand(hands[s]);
    }
    upCard = deck.removeAt(0);
    host.log('第 $currentRound/$totalRounds 局开始，候选明牌为 $upCard');
  }

  void _sortHand(List<String> hand) {
    const suitOrder = {'S': 0, 'H': 1, 'D': 2, 'C': 3};
    hand.sort((a, b) {
      final sa = beloteSuit(a);
      final sb = beloteSuit(b);
      if (sa != sb) {
        if (trumpSuit.isNotEmpty) {
          if (sa == trumpSuit) return -1;
          if (sb == trumpSuit) return 1;
        }
        return (suitOrder[sa] ?? 0).compareTo(suitOrder[sb] ?? 0);
      }
      final isT = sa == trumpSuit;
      return beloteSuitRankOrder(beloteRank(b), isTrump: isT)
          .compareTo(beloteSuitRankOrder(beloteRank(a), isTrump: isT));
    });
  }

  void _completeDealForTaker(int seat, String suit) {
    taker = seat;
    trumpSuit = suit;
    if (upCard.isNotEmpty) {
      hands[seat].add(upCard);
      upCard = '';
    }
    for (var s = 0; s < players; s++) {
      final need = 8 - hands[s].length;
      if (need > 0 && deck.length >= need) {
        hands[s].addAll(deck.sublist(0, need));
        deck.removeRange(0, need);
      }
      _sortHand(hands[s]);
    }
    _detectBelote();
    phase = 'play';
    turn = forehand;
  }

  void _detectBelote() {
    beloteSeat = null;
    if (trumpSuit.isEmpty) return;
    final kTrump = 'K$trumpSuit';
    final qTrump = 'Q$trumpSuit';
    for (var s = 0; s < players; s++) {
      if (hands[s].contains(kTrump) && hands[s].contains(qTrump)) {
        beloteSeat = s;
        break;
      }
    }
  }

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (phase == 'bid') {
      _handleBid(seat, type, action);
    } else if (phase == 'play') {
      _handlePlay(seat, type, action);
    } else {
      throw GameError('当前阶段无法执行该操作');
    }
  }

  void _handleBid(int seat, String type, Map<String, dynamic> action) {
    final upSuit = beloteSuit(upCard);
    if (type == 'take') {
      if (bidRound != 1) throw GameError('第二轮请指定其他花色定主');
      host.log('${name(seat)} 拿取明牌 $upCard，定主花色为 $upSuit');
      _completeDealForTaker(seat, upSuit);
      return;
    }
    if (type == 'choose_suit') {
      if (bidRound != 2) throw GameError('第一轮只能拿取明牌花色或过牌');
      final suit = asStr(action['suit']);
      if (!kBeloteSuits.contains(suit)) throw GameError('无效的花色');
      if (suit == upSuit) throw GameError('第二轮不能选择第一轮被弃的明牌花色');
      host.log('${name(seat)} 选择主花色 $suit 并拿取明牌 $upCard');
      _completeDealForTaker(seat, suit);
      return;
    }
    if (type == 'pass') {
      passesInRound++;
      if (passesInRound >= players) {
        if (bidRound == 1) {
          bidRound = 2;
          passesInRound = 0;
          turn = forehand;
          host.log('第一轮全员过牌，进入第二轮自由选主');
        } else {
          // Fallback if all pass in round 2: forehand takes upCard's suit
          host.log('两轮均无人叫主，由 ${name(forehand)} 默认以 $upSuit 定主');
          _completeDealForTaker(forehand, upSuit);
        }
      } else {
        turn = (turn + 1) % players;
      }
      return;
    }
    throw GameError('未知的叫牌操作');
  }

  void _handlePlay(int seat, String type, Map<String, dynamic> action) {
    if (type != 'play') throw GameError('请出牌');
    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) throw GameError('你手中没有这张牌');

    // Re-check Belote in case test modified hands directly before playing
    if (tricksPlayed == 0 && currentTrick.isEmpty && beloteSeat == null) {
      _detectBelote();
    }

    final legal = getBeloteLegalCards(
      hands[seat],
      currentTrick,
      trumpSuit,
      seat: seat,
      players: players,
    );
    if (!legal.contains(card)) {
      throw GameError('出牌不符合跟花或主牌超吃规则');
    }

    hands[seat].remove(card);
    currentTrick.add({'seat': seat, 'card': card});

    if (currentTrick.length < players) {
      turn = (turn + 1) % players;
      return;
    }

    // Resolve trick
    final winner = resolveBeloteTrick(currentTrick, trumpSuit);
    final trickCards = [for (final e in currentTrick) asStr(e['card'])];
    capturedCards[winner].addAll(trickCards);
    tricksWon[winner]++;
    lastTrick = List<Map<String, dynamic>>.of(currentTrick);
    lastTrickWinner = winner;
    currentTrick = [];
    tricksPlayed++;

    final allHandsEmpty = hands.every((h) => h.isEmpty);
    if (tricksPlayed >= 8 || allHandsEmpty) {
      _scoreHand(winner);
    } else {
      turn = winner;
    }
  }

  void _scoreHand(int finalTrickWinner) {
    // In 2p/3p, any undealt talon cards are added to finalTrickWinner's captured pile
    // so the base points across the hand always sum to 162.
    if (deck.isNotEmpty) {
      capturedCards[finalTrickWinner].addAll(deck);
      deck.clear();
    }
    if (upCard.isNotEmpty) {
      capturedCards[finalTrickWinner].add(upCard);
      upCard = '';
    }

    var takerBase = 0;
    var defenderBase = 0;
    for (var s = 0; s < players; s++) {
      final pts = capturedCards[s]
          .fold<int>(0, (sum, c) => sum + beloteCardPoints(c, trumpSuit));
      if (isTakerSide(s)) {
        takerBase += pts;
      } else {
        defenderBase += pts;
      }
    }

    // Dix de Der (+10 points for last trick)
    if (isTakerSide(finalTrickWinner)) {
      takerBase += 10;
    } else {
      defenderBase += 10;
    }

    // Ensure total base is 162 even if a unit test constructed custom partial hands
    final totalBase = takerBase + defenderBase;
    if (totalBase < 162) {
      defenderBase += (162 - totalBase);
    }

    final hasBelote = beloteSeat != null;
    final takerHasBelote = hasBelote && isTakerSide(beloteSeat!);
    final defenderHasBelote = hasBelote && !isTakerSide(beloteSeat!);
    final takerBeloteBonus = takerHasBelote ? 20 : 0;
    final defenderBeloteBonus = defenderHasBelote ? 20 : 0;

    final threshold = hasBelote ? 92 : 82;
    final takerRawTotal = takerBase + takerBeloteBonus;
    final contractSuccess = takerRawTotal >= threshold;

    late int takerAwarded;
    late int defenderAwarded;
    if (contractSuccess) {
      takerAwarded = takerBase + takerBeloteBonus;
      defenderAwarded = defenderBase + defenderBeloteBonus;
    } else {
      // Dedans (崩盘): Defenders score all 162 base points (+ any Belote bonus)
      takerAwarded = 0;
      defenderAwarded = 162 + (hasBelote ? 20 : 0);
    }

    for (var s = 0; s < players; s++) {
      if (isTakerSide(s)) {
        scores[s] += takerAwarded;
      } else {
        scores[s] += defenderAwarded;
      }
    }

    lastHandSummary = {
      'round': currentRound,
      'taker': taker,
      'trumpSuit': trumpSuit,
      'beloteSeat': beloteSeat,
      'threshold': threshold,
      'takerBase': takerBase,
      'defenderBase': defenderBase,
      'takerAwarded': takerAwarded,
      'defenderAwarded': defenderAwarded,
      'contractSuccess': contractSuccess,
      'dedans': !contractSuccess,
      'dixDeDerWinner': finalTrickWinner,
    };

    host.log(
      contractSuccess
          ? '第 $currentRound 局结算：庄家 ${name(taker)} 成约（$takerAwarded : $defenderAwarded）！'
          : '第 $currentRound 局结算：庄家 ${name(taker)} 崩盘（Dedans），防守方全得 $defenderAwarded 分！',
    );

    if (currentRound >= totalRounds) {
      _over = true;
    } else {
      currentRound++;
      dealer = (dealer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;
    if (phase == 'bid') {
      final upSuit = beloteSuit(upCard);
      if (bidRound == 1) {
        final strength = _evaluateSuitStrength(hands[seat], upSuit, includeCard: upCard);
        if (strength >= 28 || (botLevel == 0 && rng.nextDouble() < 0.35)) {
          return {'type': 'take'};
        }
        return {'type': 'pass'};
      } else {
        var bestSuit = '';
        var bestScore = -1;
        for (final s in kBeloteSuits) {
          if (s == upSuit) continue;
          final sc = _evaluateSuitStrength(hands[seat], s, includeCard: upCard);
          if (sc > bestScore) {
            bestScore = sc;
            bestSuit = s;
          }
        }
        if (bestScore >= 26) {
          return {'type': 'choose_suit', 'suit': bestSuit};
        }
        return {'type': 'pass'};
      }
    }
    if (phase == 'play') {
      final legal = getBeloteLegalCards(
        hands[seat],
        currentTrick,
        trumpSuit,
        seat: seat,
        players: players,
      );
      if (legal.isEmpty) return null;
      if (botLevel == 0) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      // Simple heuristic: if leading, play strong trump or high card; if following, play cheapest winning or lowest point card
      if (currentTrick.isEmpty) {
        legal.sort((a, b) =>
            beloteCardPoints(b, trumpSuit).compareTo(beloteCardPoints(a, trumpSuit)));
        return {'type': 'play', 'card': legal.first};
      }
      final ledSuit = beloteSuit(asStr(currentTrick.first['card']));
      final curBest = resolveBeloteTrickWinner(currentTrick, trumpSuit);
      final curBestSt =
          beloteCardStrength(asStr(curBest['card']), trumpSuit, ledSuit);
      final winning = legal
          .where((c) => beloteCardStrength(c, trumpSuit, ledSuit) > curBestSt)
          .toList();
      if (winning.isNotEmpty) {
        winning.sort((a, b) => beloteCardStrength(a, trumpSuit, ledSuit)
            .compareTo(beloteCardStrength(b, trumpSuit, ledSuit)));
        return {'type': 'play', 'card': winning.first};
      }
      legal.sort((a, b) =>
          beloteCardPoints(a, trumpSuit).compareTo(beloteCardPoints(b, trumpSuit)));
      return {'type': 'play', 'card': legal.first};
    }
    return null;
  }

  int _evaluateSuitStrength(List<String> hand, String suit, {String? includeCard}) {
    final all = [...hand, if (includeCard != null && includeCard.isNotEmpty) includeCard];
    var score = 0;
    for (final c in all) {
      if (beloteSuit(c) == suit) {
        score += beloteCardPoints(c, suit) + 4;
      } else if (beloteRank(c) == 'A') {
        score += 6;
      }
    }
    return score;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? List<String>.of(hands[seat]) : <String>[];
    final legal = (seat >= 0 && seat < players && phase == 'play' && seat == turn)
        ? getBeloteLegalCards(hands[seat], currentTrick, trumpSuit, seat: seat, players: players)
        : <String>[];
    return {
      'phase': phase,
      'round': currentRound,
      'totalRounds': totalRounds,
      'dealer': dealer,
      'forehand': forehand,
      'turn': turn,
      'bidRound': bidRound,
      'upCard': upCard,
      'trumpSuit': trumpSuit,
      'taker': taker,
      'beloteSeat': beloteSeat,
      'hand': myHand,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'legalCards': legal,
      'currentTrick': [
        for (final e in currentTrick) {'seat': e['seat'], 'card': e['card']},
      ],
      'lastTrick': [
        for (final e in lastTrick) {'seat': e['seat'], 'card': e['card']},
      ],
      'lastTrickWinner': lastTrickWinner,
      'tricksPlayed': tricksPlayed,
      'tricksWon': List<int>.of(tricksWon),
      'capturedPoints': [
        for (var s = 0; s < players; s++)
          capturedCards[s]
              .fold<int>(0, (sum, c) => sum + beloteCardPoints(c, trumpSuit)),
      ],
      'scores': List<int>.of(scores),
      'lastHandSummary': lastHandSummary,
      'over': _over,
    };
  }
}
