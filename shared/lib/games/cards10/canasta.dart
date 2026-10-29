import '../../src/engine.dart';

const String canastaRules = '''
# 卡纳斯塔（Canasta）规则说明

## 游戏概述
卡纳斯塔（Canasta）是源自南美的经典拉米（Rummy）系组牌游戏，支持 2～4 人对战。核心目标是收集同点数的牌组成至少 7 张的大牌组——**卡纳斯塔（Canasta，“篮子”）**，以赢取高额奖分！

## 牌组与特殊牌（108 张）
- 使用两副标准扑克牌（104 张）加 4 张王牌（2 张小王 BJ、2 张大王 RJ），共 **108 张牌**。
- **百搭牌（Wildcards）**：所有的 **2**（共 8 张）和 **大小王**（共 4 张）均为百搭牌，可替代 4～A 的任意自然牌参与组牌。
- **红 3（♥3、♦3，奖分牌）**：抽到或起手拿到红 3 时自动亮出置于面前，并从牌堆补抽一张；每张红 3 在结算时固定奖励 **+100 分**！
- **黑 3（♠3、♣3，封锁牌）**：打出黑 3 到弃牌堆顶会封锁（Block/Freeze）弃牌堆，使下家无法在该回合捡起弃牌堆。

## 单牌分值
- **大小王（Joker）**：50 分
- **2、A**：20 分
- **8、9、10、J、Q、K**：10 分
- **4、5、6、7、黑 3**：5 分

## 回合流程
每个玩家的回合分为两个步骤：
1. **摸牌阶段（Draw）**：二选一：
   - **摸牌堆（Draw Stock）**：从牌堆摸 **2 张牌**加入手牌。
   - **收弃牌堆（Take Pile）**：若弃牌堆顶不是黑 3 或百搭牌，且你能立即用手中 **至少 2 张同点数的自然牌** 与弃牌堆顶牌组出新牌组（或将其贴入你已有的同点数牌组），即可把**整个弃牌堆**收入手中并完成该次出牌！
2. **组牌与弃牌阶段（Play）**：
   - **组牌（Meld）**：打出 3 张及以上同点数（4～A）的牌组成牌组，每个牌组必须包含 **至少 2 张自然牌** 且 **最多 3 张百搭牌**；也可以向自己已有的同点数牌组追加自然牌或百搭牌。
   - **卡纳斯塔（Canasta）**：当任意牌组达到 **7 张及以上** 时即完成一个卡纳斯塔：
     - **纯篮（Natural Canasta，不含百搭牌）**：额外奖励 **+500 分**！
     - **混篮（Mixed Canasta，含 1～3 张百搭牌）**：额外奖励 **+300 分**！
   - **弃牌（Discard）**：打出一张手牌到弃牌堆，结束回合。

## 出局（Going Out）与结算
- 当一名玩家已至少完成 **1 个卡纳斯塔** 且手牌全部出完（组牌出完或弃掉最后一张牌），即宣告**出局（Going Out）**，获得 **+100 分出局奖**，本局立即结束。
- 若牌堆被摸空，本局也会在当前弃牌后结束。
- **本局得分** = 纯篮奖分（500/个）+ 混篮奖分（300/个）+ 红3奖分（100/张）+ 出局奖（100）+ 台面牌组内所有牌面分值总和 - 手中剩余牌面分值总和。
''';

class Canasta extends GameEngine {
  Canasta(super.setup);

  static const List<String> suits = ['S', 'H', 'D', 'C'];
  static const List<String> allRanks = ['2', '3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];
  static const List<String> meldRanks = ['4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A'];

  static bool isJoker(String c) => c == 'BJ' || c == 'RJ';
  static String cardRank(String c) => isJoker(c) ? 'JOKER' : c.substring(0, c.length - 1);
  static String cardSuit(String c) => isJoker(c) ? '' : c[c.length - 1];
  static bool isWild(String c) => isJoker(c) || cardRank(c) == '2';
  static bool isRedThree(String c) => c == '3H' || c == '3D';
  static bool isBlackThree(String c) => c == '3S' || c == '3C';

  static int cardPoints(String c) {
    if (isJoker(c)) return 50;
    final r = cardRank(c);
    if (r == '2' || r == 'A') return 20;
    if (const {'8', '9', 'T', 'J', 'Q', 'K'}.contains(r)) return 10;
    return 5; // 4..7 and Black 3
  }

  static List<String> buildDeck() {
    final d = <String>[];
    for (var copy = 0; copy < 2; copy++) {
      for (final s in suits) {
        for (final r in allRanks) {
          d.add('$r$s');
        }
      }
      d.add('BJ');
      d.add('RJ');
    }
    return d; // 108 cards
  }

  static void sortHand(List<String> hand) {
    int order(String c) {
      if (c == 'RJ') return 100;
      if (c == 'BJ') return 99;
      final r = cardRank(c);
      if (r == '2') return 98;
      if (r == '3') return 1;
      return meldRanks.indexOf(r) + 10;
    }

    hand.sort((a, b) {
      final oa = order(a);
      final ob = order(b);
      if (oa != ob) return ob.compareTo(oa);
      return a.compareTo(b);
    });
  }

  late int targetHands;
  int handNo = 0;
  int dealer = 0;
  int turn = 0;
  String phase = 'draw'; // 'draw' | 'play' | 'handEnd' | 'over'
  List<List<String>> hands = [];
  List<Map<String, List<String>>> melds = [];
  List<List<String>> redThrees = [];
  List<String> stock = [];
  List<String> discardPile = [];
  List<int> scores = [];
  List<bool> ready = [];
  Map<String, dynamic>? result;
  List<String> logs = [];
  int resignedBy = -1;

  void _log(String msg) {
    logs.add(msg);
    if (logs.length > 30) logs.removeAt(0);
    host.log(msg);
  }

  @override
  void start() {
    targetHands = setup.opt<int>('hands', 1);
    scores = List.filled(players, 0);
    handNo = 0;
    dealer = 0;
    resignedBy = -1;
    _startHand();
  }

  void _startHand() {
    handNo++;
    if (handNo > 1) dealer = (dealer + 1) % players;
    stock = shuffled(buildDeck(), rng);
    hands = List.generate(players, (_) => <String>[]);
    melds = List.generate(players, (_) => <String, List<String>>{});
    redThrees = List.generate(players, (_) => <String>[]);
    discardPile = [];

    final dealCount = players == 2 ? 15 : (players == 3 ? 13 : 11);
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < dealCount; i++) {
        _drawCardToHand(s);
      }
      sortHand(hands[s]);
    }

    // Flip initial discard card (replace if Red 3 or Wildcard)
    while (stock.isNotEmpty) {
      final c = stock.removeLast();
      if (isRedThree(c)) {
        redThrees[dealer].add(c);
        continue;
      }
      discardPile.add(c);
      if (!isWild(c) && !isBlackThree(c)) break;
    }

    turn = (dealer + 1) % players;
    phase = 'draw';
    ready = List.filled(players, false);
    result = null;
    _log('第 $handNo 局卡纳斯塔开始！牌堆剩余 ${stock.length} 张。');
  }

  void _drawCardToHand(int seat) {
    while (stock.isNotEmpty) {
      final c = stock.removeLast();
      if (isRedThree(c)) {
        redThrees[seat].add(c);
        continue;
      }
      hands[seat].add(c);
      return;
    }
  }

  void extractRedThrees(int seat) {
    while (true) {
      final idx = hands[seat].indexWhere(isRedThree);
      if (idx < 0) break;
      final c = hands[seat].removeAt(idx);
      redThrees[seat].add(c);
      _drawCardToHand(seat);
    }
  }

  bool hasCanasta(int seat) => melds[seat].values.any((m) => m.length >= 7);

  int countCanastas(int seat, {required bool natural}) => melds[seat]
      .values
      .where((m) => m.length >= 7 && (natural ? !m.any(isWild) : m.any(isWild)))
      .length;

  bool canTakePile(int seat) {
    if (phase != 'draw' || seat != turn || discardPile.isEmpty) return false;
    final top = discardPile.last;
    if (isBlackThree(top) || isWild(top) || isRedThree(top)) return false;
    final r = cardRank(top);
    if (!meldRanks.contains(r)) return false;
    final existing = melds[seat][r];
    final natCount = hands[seat].where((c) => cardRank(c) == r).length;
    if (existing == null && natCount < 2) return false;

    final addedToHand = discardPile.sublist(0, discardPile.length - 1).where((c) => !isRedThree(c)).length;
    final removedFromHand = existing != null ? 0 : 2;
    final newHandSize = hands[seat].length + addedToHand - removedFromHand;
    final newMeldSize = (existing?.length ?? 0) + (existing != null ? 1 : 3);
    final willHaveCanasta = hasCanasta(seat) || newMeldSize >= 7;
    if (!willHaveCanasta && newHandSize < 2) return false;
    return true;
  }

  static bool _hasAllCards(List<String> hand, List<String> sub) {
    final copy = List.of(hand);
    for (final c in sub) {
      if (!copy.remove(c)) return false;
    }
    return true;
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'handEnd') {
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
    final winner = (seat + 1) % players;
    result = {
      'handNo': handNo,
      'winner': winner,
      'wentOut': -1,
      'resigned': seat,
      'scores': List.of(scores),
      'breakdown': const [],
    };
    _log('${name(seat)} 认输！');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'handEnd') {
      if (type != 'continue') throw GameError('请点击继续下一局');
      if (seat < 0 || seat >= players || ready[seat]) throw GameError('已准备');
      ready[seat] = true;
      if (ready.every((x) => x)) {
        _startHand();
      }
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');

    if (phase == 'draw') {
      if (type == 'draw_stock') {
        if (stock.isEmpty) {
          _endHand(wentOut: -1);
          return;
        }
        _drawCardToHand(seat);
        _drawCardToHand(seat);
        sortHand(hands[seat]);
        phase = 'play';
        _log('${name(seat)} 从牌堆摸了牌（牌堆剩 ${stock.length} 张）。');
        return;
      }
      if (type == 'take_pile') {
        if (!canTakePile(seat)) {
          throw GameError('当前无法收取弃牌堆（需堆顶非黑3/百搭，且手牌至少有2张同点自然牌或已有对应牌组）');
        }
        final top = discardPile.removeLast();
        final r = cardRank(top);
        final countTaken = discardPile.length + 1;
        for (final c in discardPile) {
          if (isRedThree(c)) {
            redThrees[seat].add(c);
          } else {
            hands[seat].add(c);
          }
        }
        discardPile.clear();
        if (melds[seat].containsKey(r)) {
          melds[seat][r]!.add(top);
        } else {
          final m = <String>[top];
          for (var i = 0; i < 2; i++) {
            final idx = hands[seat].indexWhere((c) => cardRank(c) == r);
            m.add(hands[seat].removeAt(idx));
          }
          melds[seat][r] = m;
        }
        sortHand(hands[seat]);
        phase = 'play';
        _log('${name(seat)} 用 $r 牌组收走了整个弃牌堆（共 $countTaken 张）！');
        if (hands[seat].isEmpty && hasCanasta(seat)) {
          _endHand(wentOut: seat);
        }
        return;
      }
      throw GameError('摸牌阶段请选择 draw_stock 或 take_pile');
    }

    if (phase == 'play') {
      if (type == 'meld') {
        final rawCards = action['cards'];
        if (rawCards is! List || rawCards.isEmpty) throw GameError('请选择要组牌的手牌');
        final cards = [for (final x in rawCards) '$x'];
        if (!_hasAllCards(hands[seat], cards)) throw GameError('手牌中不包含所选的牌');

        var rank = asStr(action['rank']);
        final naturalsInCards = cards.where((c) => !isWild(c)).toList();
        if (rank.isEmpty && naturalsInCards.isNotEmpty) {
          rank = cardRank(naturalsInCards.first);
        }
        if (!meldRanks.contains(rank)) {
          throw GameError('组牌点数必须是 4～A 之一');
        }
        for (final c in cards) {
          if (!isWild(c) && cardRank(c) != rank) {
            throw GameError('牌组中不能混入其他点数的自然牌（$c 不是 $rank）');
          }
        }

        final existing = melds[seat][rank];
        final combined = <String>[...?existing, ...cards];
        if (combined.length < 3) {
          throw GameError('新建牌组至少需要 3 张牌');
        }
        final natCount = combined.where((c) => !isWild(c)).length;
        final wildCount = combined.where(isWild).length;
        if (natCount < 2) {
          throw GameError('牌组中至少需要 2 张自然牌');
        }
        if (wildCount > 3) {
          throw GameError('一个牌组最多只能包含 3 张百搭牌');
        }

        // Check if player will have at least 1 Canasta after this meld
        final willHaveCanasta = combined.length >= 7 ||
            melds[seat].entries.any((e) => e.key != rank && e.value.length >= 7);
        final remCards = hands[seat].length - cards.length;
        if (remCards == 0 && !willHaveCanasta) {
          throw GameError('至少完成 1 个卡纳斯塔（7张篮）后才能出完所有手牌');
        }
        if (remCards == 1 && !willHaveCanasta && stock.isNotEmpty) {
          throw GameError('未完成卡纳斯塔前，手牌至少需保留 2 张');
        }

        for (final c in cards) {
          hands[seat].remove(c);
        }
        final wasCanasta = existing != null && existing.length >= 7;
        melds[seat][rank] = combined;
        final isNowCanasta = combined.length >= 7;
        if (!wasCanasta && isNowCanasta) {
          final kind = wildCount == 0 ? '纯篮（+500分）' : '混篮（+300分）';
          _log('${name(seat)} 完成了 $rank 的卡纳斯塔【$kind】！');
        } else {
          _log('${name(seat)} 组牌 $rank（当前 ${combined.length} 张）。');
        }

        if (hands[seat].isEmpty && hasCanasta(seat)) {
          _endHand(wentOut: seat);
        }
        return;
      }

      if (type == 'discard') {
        final card = asStr(action['card']);
        if (!hands[seat].contains(card)) throw GameError('手牌中没有这张牌');
        if (hands[seat].length == 1 && !hasCanasta(seat) && stock.isNotEmpty) {
          throw GameError('至少完成 1 个卡纳斯塔（7张篮）后才能打出最后一张牌出局');
        }
        hands[seat].remove(card);
        discardPile.add(card);
        _log('${name(seat)} 弃置了 $card。');

        if (hands[seat].isEmpty && hasCanasta(seat)) {
          _endHand(wentOut: seat);
          return;
        }
        if (stock.isEmpty) {
          _endHand(wentOut: -1);
          return;
        }
        turn = (turn + 1) % players;
        phase = 'draw';
        return;
      }

      throw GameError('出牌阶段请选择 meld 或 discard');
    }
  }

  void _endHand({required int wentOut}) {
    final breakdown = <Map<String, dynamic>>[];
    var bestSeat = 0;
    for (var s = 0; s < players; s++) {
      final natCanastas = countCanastas(s, natural: true);
      final mixCanastas = countCanastas(s, natural: false);
      final canastaBonus = natCanastas * 500 + mixCanastas * 300;
      final red3Bonus = redThrees[s].length * 100;
      final goingOutBonus = wentOut == s ? 100 : 0;
      var meldPts = 0;
      for (final m in melds[s].values) {
        for (final c in m) {
          meldPts += cardPoints(c);
        }
      }
      var handPenalty = 0;
      for (final c in hands[s]) {
        handPenalty += cardPoints(c);
      }
      final delta = canastaBonus + red3Bonus + goingOutBonus + meldPts - handPenalty;
      scores[s] += delta;
      breakdown.add({
        'seat': s,
        'naturalCanastas': natCanastas,
        'mixedCanastas': mixCanastas,
        'canastaBonus': canastaBonus,
        'redThrees': redThrees[s].length,
        'red3Bonus': red3Bonus,
        'goingOutBonus': goingOutBonus,
        'meldPoints': meldPts,
        'handPenalty': handPenalty,
        'delta': delta,
        'total': scores[s],
      });
      if (scores[s] > scores[bestSeat]) bestSeat = s;
    }

    result = {
      'handNo': handNo,
      'wentOut': wentOut,
      'winner': bestSeat,
      'scores': List.of(scores),
      'breakdown': breakdown,
    };
    if (wentOut >= 0) {
      _log('${name(wentOut)} 成功出局（+100分）！本局结算完成。');
    } else {
      _log('牌堆摸空，本局结束！');
    }

    if (handNo >= targetHands) {
      phase = 'over';
    } else {
      phase = 'handEnd';
      ready = List.filled(players, false);
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver) return null;
    if (phase == 'handEnd') {
      return ready[seat] ? null : {'type': 'continue'};
    }
    if (seat != turn) return null;

    if (phase == 'draw') {
      if (canTakePile(seat) && (botLevel >= 1 || discardPile.length >= 2)) {
        return {'type': 'take_pile'};
      }
      return {'type': 'draw_stock'};
    }

    final h = hands[seat];
    if (h.isEmpty) return null;

    // Try adding matching natural cards to existing melds
    for (final entry in melds[seat].entries) {
      final r = entry.key;
      final matching = h.where((c) => cardRank(c) == r).toList();
      if (matching.isNotEmpty) {
        final willHaveCanasta = (entry.value.length + matching.length) >= 7 || hasCanasta(seat);
        var takeCount = matching.length;
        if (!willHaveCanasta && h.length - takeCount < 2) {
          takeCount = h.length - 2;
        }
        if (takeCount > 0) {
          return {'type': 'meld', 'rank': r, 'cards': matching.sublist(0, takeCount)};
        }
      }
    }

    // Try forming a new natural meld of >= 3 cards
    for (final r in meldRanks) {
      if (melds[seat].containsKey(r)) continue;
      final matching = h.where((c) => cardRank(c) == r).toList();
      if (matching.length >= 3) {
        final willHaveCanasta = matching.length >= 7 || hasCanasta(seat);
        var takeCount = matching.length;
        if (!willHaveCanasta && h.length - takeCount < 2) {
          takeCount = h.length - 2;
        }
        if (takeCount >= 3) {
          return {'type': 'meld', 'rank': r, 'cards': matching.sublist(0, takeCount)};
        }
      }
    }

    // Try using wildcards to complete a 7-card Canasta on an existing meld, or create a meld if hand is big
    final wilds = h.where(isWild).toList();
    if (wilds.isNotEmpty) {
      for (final entry in melds[seat].entries) {
        final r = entry.key;
        final m = entry.value;
        final curWilds = m.where(isWild).length;
        final maxAddWild = 3 - curWilds;
        final neededForCanasta = 7 - m.length;
        if (neededForCanasta > 0 && neededForCanasta <= maxAddWild && neededForCanasta <= wilds.length) {
          final addW = wilds.sublist(0, neededForCanasta);
          return {'type': 'meld', 'rank': r, 'cards': addW};
        }
      }
      // Or if we have a pair of naturals + wilds and >= 6 cards in hand
      if (h.length >= 6) {
        for (final r in meldRanks) {
          if (melds[seat].containsKey(r)) continue;
          final matching = h.where((c) => cardRank(c) == r).toList();
          if (matching.length == 2) {
            final meldCards = [...matching, wilds.first];
            if (h.length - meldCards.length >= 2) {
              return {'type': 'meld', 'rank': r, 'cards': meldCards};
            }
          }
        }
      }
    }

    // Discard step: pick best discard card
    // Prefer Black 3, else a singleton natural card, else any non-wild, else any card
    final black3s = h.where(isBlackThree).toList();
    if (black3s.isNotEmpty) {
      return {'type': 'discard', 'card': black3s.first};
    }
    final nonWilds = h.where((c) => !isWild(c)).toList();
    if (nonWilds.isNotEmpty) {
      nonWilds.sort((a, b) {
        final ca = h.where((x) => cardRank(x) == cardRank(a)).length;
        final cb = h.where((x) => cardRank(x) == cardRank(b)).length;
        if (ca != cb) return ca.compareTo(cb);
        return cardPoints(a).compareTo(cardPoints(b));
      });
      return {'type': 'discard', 'card': nonWilds.first};
    }
    return {'type': 'discard', 'card': h.first};
  }

  List<Map<String, dynamic>> _serializeMelds(int s) {
    final list = <Map<String, dynamic>>[];
    for (final r in meldRanks) {
      final cards = melds[s][r];
      if (cards == null || cards.isEmpty) continue;
      final wildCount = cards.where(isWild).length;
      list.add({
        'rank': r,
        'cards': List.of(cards),
        'isCanasta': cards.length >= 7,
        'isNatural': wildCount == 0,
        'wildCount': wildCount,
      });
    }
    return list;
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
      'handNo': handNo,
      'targetHands': targetHands,
      'dealer': dealer,
      'turn': turn,
      'stockCount': stock.length,
      'discardTop': discardPile.isNotEmpty ? discardPile.last : null,
      'discardCount': discardPile.length,
      'discardPreview': discardPile.length <= 5
          ? List.of(discardPile)
          : discardPile.sublist(discardPile.length - 5),
      'pileBlocked': discardPile.isEmpty ||
          isBlackThree(discardPile.last) ||
          isWild(discardPile.last),
      'canTakePile': vSeat >= 0 ? canTakePile(vSeat) : false,
      'hand': vSeat >= 0 ? List.of(hands[vSeat]) : const <String>[],
      'counts': [for (var s = 0; s < players; s++) hands[s].length],
      'melds': [for (var s = 0; s < players; s++) _serializeMelds(s)],
      'redThrees': [for (var s = 0; s < players; s++) List.of(redThrees[s])],
      'hasCanasta': [for (var s = 0; s < players; s++) hasCanasta(s)],
      'scores': List.of(scores),
      'ready': List.of(ready),
      'result': result,
      'winner': isOver ? (resignedBy >= 0 ? (resignedBy + 1) % players : best) : -1,
      'resigned': resignedBy >= 0,
      'log': List.of(logs),
    };
  }
}
