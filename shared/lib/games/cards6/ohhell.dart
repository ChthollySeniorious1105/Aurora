import '../../src/engine.dart';

const List<String> _suits = ['S', 'H', 'D', 'C'];
const List<String> _ranks = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
const Map<String, String> _suitNames = {'S': '♠黑桃', 'H': '♥红桃', 'D': '♦方片', 'C': '♣梅花'};

List<String> ohDeck() => [
      for (final s in _suits)
        for (final r in _ranks) '$r$s',
    ];

/// Rank value 2..14 (2=2 .. T=10, J=11, Q=12, K=13, A=14).
int ohRank(String card) {
  if (card.length < 2) return 0;
  final r = card.substring(0, card.length - 1);
  final idx = _ranks.indexOf(r);
  return idx >= 0 ? idx + 2 : 0;
}

String ohSuit(String card) => card.isEmpty ? '' : card[card.length - 1];

void ohSort(List<String> cards, String trumpSuit) {
  cards.sort((a, b) {
    final sa = ohSuit(a) == trumpSuit ? -1 : _suits.indexOf(ohSuit(a));
    final sb = ohSuit(b) == trumpSuit ? -1 : _suits.indexOf(ohSuit(b));
    if (sa != sb) return sa.compareTo(sb);
    return ohRank(a).compareTo(ohRank(b));
  });
}

/// Returns true if [challenger] beats [currentBest] given [leadSuit] and [trumpSuit].
bool ohBeats(String challenger, String currentBest, String leadSuit, String trumpSuit) {
  final sc = ohSuit(challenger);
  final sb = ohSuit(currentBest);
  if (sc == sb) return ohRank(challenger) > ohRank(currentBest);
  if (sc == trumpSuit) return true;
  if (sb == trumpSuit) return false;
  if (sc == leadSuit && sb != leadSuit) return true;
  return false;
}

/// 猜墩牌 (Oh Hell) 3~6人精确合约吃墩游戏
class OhHell extends GameEngine {
  OhHell(super.setup);

  String scheduleMode = 'short'; // 'short' | 'full'
  String scoringMode = 'standard'; // 'standard' | 'penalty'
  List<int> roundCards = [5, 6, 7, 6, 5];

  int roundIndex = 0;
  int dealer = 0;
  int turn = 0;
  String phase = 'bid'; // bid | play | over

  List<List<String>> hands = [];
  String trumpCard = '';
  String trumpSuit = 'S';

  List<int> bids = [];
  List<int> tricksWon = [];
  List<int> scores = [];

  List<Map<String, dynamic>> currentTrick = [];
  String leadSuit = '';
  Map<String, dynamic>? lastTrick;
  Map<String, dynamic>? lastRoundResult;
  final List<Map<String, dynamic>> history = [];
  final List<String> log = [];

  int get cardsThisRound => roundCards[roundIndex];
  int get totalRounds => roundCards.length;

  void _log(String msg) {
    log.add(msg);
    if (log.length > 12) log.removeAt(0);
    host.log(msg);
  }

  @override
  bool get isOver => phase == 'over';

  @override
  List<int> get waitingFor => isOver ? const [] : [turn];

  @override
  List<int>? get placings => isOver ? rankByScore(scores) : null;

  /// Returns the forbidden bid for [seat] under the Hook Rule (庄家禁手), or null if none.
  int? forbiddenBidFor(int seat) {
    if (phase != 'bid' || seat != turn) return null;
    final placedCount = bids.where((b) => b >= 0).length;
    if (placedCount != players - 1) return null;
    final sumPrev = bids.where((b) => b >= 0).fold<int>(0, (a, b) => a + b);
    final forbidden = cardsThisRound - sumPrev;
    if (forbidden >= 0 && forbidden <= cardsThisRound) return forbidden;
    return null;
  }

  @override
  void start() {
    scheduleMode = setup.opt<String>('schedule', 'short');
    scoringMode = setup.opt<String>('scoring', 'standard');
    roundCards = scheduleMode == 'full' ? [1, 2, 3, 4, 5, 6, 7] : [5, 6, 7, 6, 5];
    roundIndex = 0;
    dealer = rng.nextInt(players);
    scores = List.filled(players, 0);
    history.clear();
    _log('猜墩牌开始：共 ${roundCards.length} 局（${roundCards.join('-')} 张），庄家禁手开启');
    _startRound();
  }

  void _startRound() {
    final n = cardsThisRound;
    final deck = shuffled(ohDeck(), rng);
    hands = [
      for (var s = 0; s < players; s++) deck.sublist(s * n, (s + 1) * n),
    ];
    trumpCard = deck[players * n];
    trumpSuit = ohSuit(trumpCard);
    for (final h in hands) {
      ohSort(h, trumpSuit);
    }
    bids = List.filled(players, -1);
    tricksWon = List.filled(players, 0);
    currentTrick = [];
    leadSuit = '';
    lastTrick = null;
    phase = 'bid';
    turn = (dealer + 1) % players;
    _log('第 ${roundIndex + 1}/$totalRounds 局（每人 $n 张）：翻出王牌 $trumpCard（${_suitNames[trumpSuit] ?? trumpSuit}），${name(dealer)} 坐庄');
  }

  List<String> legalCards(int seat) {
    final h = hands[seat];
    if (currentTrick.isEmpty || leadSuit.isEmpty) return List.of(h);
    final follow = h.where((c) => ohSuit(c) == leadSuit).toList();
    return follow.isNotEmpty ? follow : List.of(h);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (seat < 0 || seat >= players) throw GameError('无效座位');
    if (isOver) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final type = asStr(action['type']);

    if (phase == 'bid') {
      if (type != 'bid') throw GameError('当前为叫墩阶段，请叫墩');
      final b = asInt(action['bid'], -1);
      final n = cardsThisRound;
      if (b < 0 || b > n) {
        throw GameError('叫墩数必须在 0 到 $n 之间');
      }
      final forbidden = forbiddenBidFor(seat);
      if (forbidden != null && b == forbidden) {
        throw GameError('庄家禁手：总叫墩数不能等于本局总墩数 $n（禁止叫 $forbidden 墩）');
      }
      bids[seat] = b;
      _log('${name(seat)} 叫 $b 墩');

      if (bids.every((x) => x >= 0)) {
        final totalBids = bids.fold<int>(0, (a, x) => a + x);
        final diff = totalBids > n ? '超叫 ${totalBids - n} 墩' : '少叫 ${n - totalBids} 墩';
        _log('叫墩完毕：共叫 $totalBids/$n 墩（$diff），${name((dealer + 1) % players)} 先出牌');
        phase = 'play';
        turn = (dealer + 1) % players;
      } else {
        turn = (turn + 1) % players;
      }
      return;
    }

    if (phase == 'play') {
      if (type != 'play') throw GameError('请打出一张手牌');
      final card = asStr(action['card']);
      if (!hands[seat].contains(card)) {
        throw GameError('你手中没有这张牌');
      }
      if (currentTrick.isNotEmpty && leadSuit.isNotEmpty) {
        if (ohSuit(card) != leadSuit && hands[seat].any((c) => ohSuit(c) == leadSuit)) {
          throw GameError('必须跟出领出花色（${_suitNames[leadSuit] ?? leadSuit}）');
        }
      }
      hands[seat].remove(card);
      if (currentTrick.isEmpty) {
        leadSuit = ohSuit(card);
      }
      currentTrick.add({'seat': seat, 'card': card});

      if (currentTrick.length < players) {
        turn = (turn + 1) % players;
        return;
      }

      // Resolve trick winner
      var bestSeat = currentTrick.first['seat'] as int;
      var bestCard = currentTrick.first['card'] as String;
      for (var i = 1; i < currentTrick.length; i++) {
        final s = currentTrick[i]['seat'] as int;
        final c = currentTrick[i]['card'] as String;
        if (ohBeats(c, bestCard, leadSuit, trumpSuit)) {
          bestSeat = s;
          bestCard = c;
        }
      }
      tricksWon[bestSeat]++;
      lastTrick = {
        'winner': bestSeat,
        'winCard': bestCard,
        'leadSuit': leadSuit,
        'plays': List.of(currentTrick),
      };
      _log('${name(bestSeat)} 以 $bestCard 赢得第 ${tricksWon.fold<int>(0, (a, b) => a + b)} 墩（已赢 ${tricksWon[bestSeat]}/${bids[bestSeat]} 墩）');
      currentTrick = [];
      leadSuit = '';

      if (hands.any((h) => h.isNotEmpty)) {
        turn = bestSeat;
        return;
      }

      // End of round scoring
      _finishRound();
      return;
    }
  }

  void _finishRound() {
    final n = cardsThisRound;
    final deltas = List<int>.filled(players, 0);
    final parts = <String>[];
    for (var s = 0; s < players; s++) {
      final b = bids[s];
      final w = tricksWon[s];
      if (w == b) {
        deltas[s] = 10 + b;
      } else if (scoringMode == 'penalty') {
        deltas[s] = -(w - b).abs();
      } else {
        deltas[s] = 0;
      }
      scores[s] += deltas[s];
      final sign = deltas[s] >= 0 ? '+${deltas[s]}' : '${deltas[s]}';
      parts.add('${name(s)}($w/$b墩 $sign)');
    }
    final roundRecord = {
      'round': roundIndex + 1,
      'cards': n,
      'trump': trumpCard,
      'bids': List.of(bids),
      'won': List.of(tricksWon),
      'deltas': deltas,
      'scores': List.of(scores),
    };
    lastRoundResult = roundRecord;
    history.add(roundRecord);
    _log('第 ${roundIndex + 1} 局结算：${parts.join('，')}');

    if (roundIndex + 1 >= roundCards.length) {
      phase = 'over';
      turn = -1;
      final p = placings!;
      final winners = [
        for (var s = 0; s < players; s++)
          if (p[s] == 1) name(s),
      ];
      _log('全场比赛结束！冠军：${winners.join('、')}');
    } else {
      roundIndex++;
      dealer = (dealer + 1) % players;
      _startRound();
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isPlayer = seat >= 0 && seat < players;
    final legal = isPlayer && phase == 'play' && turn == seat ? legalCards(seat) : <String>[];
    return {
      'phase': phase,
      'roundIndex': roundIndex,
      'roundNo': roundIndex + 1,
      'totalRounds': totalRounds,
      'roundCards': roundCards,
      'cardsThisRound': cardsThisRound,
      'scoringMode': scoringMode,
      'dealer': dealer,
      'turn': turn,
      'trumpCard': trumpCard,
      'trumpSuit': trumpSuit,
      'hand': isPlayer ? hands[seat] : <String>[],
      'legalCards': legal,
      'handCounts': [for (final h in hands) h.length],
      'bids': bids,
      'forbiddenBid': forbiddenBidFor(turn),
      'tricksWon': tricksWon,
      'scores': scores,
      'currentTrick': currentTrick,
      'leadSuit': leadSuit,
      'lastTrick': lastTrick,
      'lastRoundResult': lastRoundResult,
      'history': history,
      'placings': placings,
      'log': log,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'bid') {
      final n = cardsThisRound;
      final h = hands[seat];
      final forbidden = forbiddenBidFor(seat);
      var est = 0.0;
      for (final c in h) {
        final r = ohRank(c);
        final isTrump = ohSuit(c) == trumpSuit;
        if (isTrump) {
          if (r >= 12) {
            est += 0.85;
          } else if (r >= 9) {
            est += 0.6;
          } else {
            est += 0.35;
          }
        } else {
          if (r == 14) {
            est += 0.75;
          } else if (r == 13) {
            est += 0.45;
          } else if (r == 12) {
            est += 0.2;
          }
        }
      }
      var b = est.round().clamp(0, n);
      if (botLevel == 0 && rng.nextInt(3) == 0) {
        b = rng.nextInt(n + 1);
      }
      if (forbidden != null && b == forbidden) {
        if (b > 0 && (b == n || est < b)) {
          b = b - 1;
        } else if (b < n) {
          b = b + 1;
        } else {
          b = b - 1;
        }
      }
      return {'type': 'bid', 'bid': b};
    }

    if (phase == 'play') {
      final legal = legalCards(seat);
      if (legal.isEmpty) return null;
      if (botLevel == 0 || legal.length == 1) {
        return {'type': 'play', 'card': legal[rng.nextInt(legal.length)]};
      }
      final wantMore = tricksWon[seat] < bids[seat];
      if (currentTrick.isEmpty) {
        // Leading a trick
        legal.sort((a, b) {
          final va = (ohSuit(a) == trumpSuit ? 20 : 0) + ohRank(a);
          final vb = (ohSuit(b) == trumpSuit ? 20 : 0) + ohRank(b);
          return va.compareTo(vb);
        });
        return {'type': 'play', 'card': wantMore ? legal.last : legal.first};
      }

      // Following in a trick
      var curBest = currentTrick.first['card'] as String;
      for (var i = 1; i < currentTrick.length; i++) {
        final c = currentTrick[i]['card'] as String;
        if (ohBeats(c, curBest, leadSuit, trumpSuit)) curBest = c;
      }
      final winning = legal.where((c) => ohBeats(c, curBest, leadSuit, trumpSuit)).toList();
      final losing = legal.where((c) => !ohBeats(c, curBest, leadSuit, trumpSuit)).toList();

      int cardCost(String c) => (ohSuit(c) == trumpSuit ? 20 : 0) + ohRank(c);
      winning.sort((a, b) => cardCost(a).compareTo(cardCost(b)));
      losing.sort((a, b) => cardCost(a).compareTo(cardCost(b)));

      if (wantMore) {
        if (winning.isNotEmpty) {
          return {'type': 'play', 'card': winning.first}; // Cheapest winner
        }
        return {'type': 'play', 'card': losing.first}; // Dump cheapest loser
      } else {
        if (losing.isNotEmpty) {
          return {'type': 'play', 'card': losing.last}; // Shed highest safe loser
        }
        return {'type': 'play', 'card': winning.first}; // Forced to win: play lowest winner
      }
    }
    return null;
  }
}

const String ohHellRules = '''
# 猜墩牌 (Oh Hell)
经典欧美精确合约吃墩扑克游戏（支持 3~6 人），使用一副 52 张标准扑克牌（无大小王）。不仅要赢牌，更要**分毫不差地命中自己预测的赢墩数**！

# 赛程与发牌
- **短赛程（5 局）**：每局发牌张数依次为 `5 - 6 - 7 - 6 - 5` 张。
- **标准赛程（7 局）**：每局发牌张数依次为 `1 - 2 - 3 - 4 - 5 - 6 - 7` 张。
- 每局发牌后，从剩余牌堆翻开 1 张牌作为本局的**王牌（Trump）**，其花色即为本局王牌花色。牌点从大到小依次为：`A > K > Q > J > 10 > 9 > 8 > 7 > 6 > 5 > 4 > 3 > 2`。

# 叫墩阶段与庄家禁手（Hook Rule）
- 从庄家左手边玩家开始，按顺时针顺序依次叫墩（预测自己本局能赢几墩，范围 `0 ~ N`）。
- **庄家禁手规则（Hook Rule）**：最后一位叫墩的庄家，**严禁**令全场所有玩家的叫墩总和恰好等于本局总墩数 `N`！这保证了每一局必定至少有一名玩家无法达成自己的合约，令牌局充满博弈与阻击乐趣。

# 出牌吃墩阶段
- 庄家左手边玩家率先领出第 1 墩牌，其余玩家按顺时针顺序各出 1 张牌：
  - **必须跟花色**：若手中持有与本墩领出牌相同花色的牌，必须跟出该花色。
  - 若手中没有领出花色，可打出任意花色的牌（包括王牌毙牌或副牌垫牌）。
- **本墩胜者**：若本墩有人打出王牌花色，则最大的王牌获胜；否则最大的领出花色牌获胜。本墩胜者获得 1 墩，并领出下一墩。

# 计分与胜负
- 每局所有手牌打完后进行结算：
  - **猜中墩数（赢墩数 == 叫墩数）**：得 **`10 + 叫墩数`** 分（即使叫 0 墩且成功 0 墩，也能得 10 分！）。
  - **猜错墩数（赢墩数 != 叫墩数）**：
    - 标准模式：得 **0 分**。
    - 罚分模式：扣除差值 **`-|赢墩数 - 叫墩数|`** 分。
- 全部局数结束后，累计总分最高的玩家获胜！
''';
