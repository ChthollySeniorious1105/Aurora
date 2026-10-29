import 'dart:math';

import '../../src/engine.dart';

const List<String> kSpices = ['chili', 'wasabi', 'pepper'];

String spiceName(String s) {
  switch (s) {
    case 'chili':
      return '🌶️ 红椒';
    case 'wasabi':
      return '🟢 芥末';
    case 'pepper':
      return '⚫ 胡椒';
    case 'WILD_SPICE':
      return '🌈 百搭香料';
    case 'WILD_NUM':
      return '🔢 百搭数字';
    default:
      return s;
  }
}

class SpicyGame extends GameEngine {
  SpicyGame(super.setup);

  late List<Map<String, dynamic>> deck;
  late List<List<Map<String, dynamic>>> hands;
  final List<Map<String, dynamic>> stack = [];

  String? topClaimSpice;
  int? topClaimNum;
  int? lastPlayer;
  int? _provisionalTrophySeat;

  late List<int> wonCards;
  late List<int> trophies;
  int trophiesLeft = 3;

  int turn = 0;
  int stepCount = 0;
  Map<String, dynamic>? lastChallenge;
  String lastActionText = '';

  bool _over = false;
  List<int>? _placings;
  String resultText = '';

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  List<int> get scores => [
        for (var s = 0; s < players; s++) wonCards[s] + trophies[s] * 10,
      ];

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    final copiesPerNumber = fast ? 2 : 3;

    final rawDeck = <Map<String, dynamic>>[];
    var idCounter = 1;
    for (final sp in kSpices) {
      for (var n = 1; n <= 10; n++) {
        for (var c = 0; c < copiesPerNumber; c++) {
          rawDeck.add({
            'id': idCounter++,
            'type': 'normal',
            'kind': 'normal',
            'spice': sp,
            'num': n,
          });
        }
      }
    }
    for (var i = 0; i < 5; i++) {
      rawDeck.add({
        'id': idCounter++,
        'type': 'WILD_SPICE',
        'kind': 'WILD_SPICE',
        'spice': 'WILD_SPICE',
        'num': 0,
      });
      rawDeck.add({
        'id': idCounter++,
        'type': 'WILD_NUM',
        'kind': 'WILD_NUM',
        'spice': 'WILD_NUM',
        'num': 0,
      });
    }

    final shuffledAll = shuffled(rawDeck, rng);
    // Keep a World's End cutoff so the deck size is bounded (standard ~48 cards, fast ~32 cards total after deal)
    final maxDeckAfterDeal = fast ? 24 : 38;
    hands = [for (var s = 0; s < players; s++) <Map<String, dynamic>>[]];
    var cursor = 0;
    for (var s = 0; s < players; s++) {
      for (var k = 0; k < 6 && cursor < shuffledAll.length; k++) {
        hands[s].add(shuffledAll[cursor++]);
      }
    }
    final remaining = shuffledAll.sublist(cursor);
    deck = remaining.take(min(remaining.length, maxDeckAfterDeal)).toList();

    stack.clear();
    topClaimSpice = null;
    topClaimNum = null;
    lastPlayer = null;
    _provisionalTrophySeat = null;

    wonCards = List<int>.filled(players, 0);
    trophies = List<int>.filled(players, 0);
    trophiesLeft = 3;
    turn = 0;
    stepCount = 0;
    lastChallenge = null;
    lastActionText = '游戏开始，请由 ${name(0)} 以 1..3 点任意香料开牌或摸牌。';
    _over = false;
    _placings = null;
    resultText = '';

    host.log('猫吃三椒 Spicy 开始！每人6张手牌，质疑只检定你指定的单一属性（香料或数字）！');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  bool isLegalClaim(String spice, int number) {
    if (!kSpices.contains(spice)) return false;
    if (number < 1 || number > 10) return false;
    if (stack.isEmpty || topClaimSpice == null || topClaimNum == null) {
      return number >= 1 && number <= 3;
    }
    if (spice != topClaimSpice) return false;
    if (topClaimNum == 10) {
      return number >= 1 && number <= 3;
    }
    return number > topClaimNum! && number <= 10;
  }

  static bool checkAttribute(
    Map<String, dynamic> card,
    String claimedSpice,
    int claimedNum,
    String attr,
  ) {
    final type = asStr(card['type']);
    final sp = asStr(card['spice']);
    final isWildSpice = type == 'WILD_SPICE' || sp == 'WILD_SPICE';
    final isWildNum = type == 'WILD_NUM' || sp == 'WILD_NUM';

    if (attr == 'spice') {
      if (isWildSpice) return true;
      if (isWildNum) return false;
      return sp == claimedSpice;
    } else if (attr == 'num') {
      if (isWildNum) return true;
      if (isWildSpice) return false;
      return asInt(card['num']) == claimedNum;
    }
    return false;
  }

  void _confirmPendingTrophyIfAny() {
    final p = _provisionalTrophySeat;
    if (p == null) return;
    _provisionalTrophySeat = null;
    if (trophies[p] >= 2 || trophiesLeft <= 0) {
      _finishGame('${name(p)} 夺得奖杯，满足终局条件！');
      return;
    }
    // Refill empty hand up to 6 cards
    for (var i = 0; i < 6 && deck.isNotEmpty; i++) {
      hands[p].add(deck.removeLast());
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (type == 'challenge') {
      if (stack.isEmpty || lastPlayer == null || topClaimSpice == null || topClaimNum == null) {
        throw GameError('当前桌面没有可质疑的卡牌');
      }
      if (seat < 0 || seat >= players) throw GameError('无效座位');
      if (seat == lastPlayer) throw GameError('不能质疑自己刚打出的牌');
      final attr = asStr(action['attr']);
      if (attr != 'spice' && attr != 'num') {
        throw GameError('质疑必须指定 attr 为 spice（香料）或 num（数字）');
      }

      final topCard = stack.last;
      final declarer = lastPlayer!;
      final cSpice = topClaimSpice!;
      final cNum = topClaimNum!;
      final passed = checkAttribute(topCard, cSpice, cNum, attr);

      final int winner;
      final int loser;
      if (passed) {
        winner = declarer;
        loser = seat;
        if (_provisionalTrophySeat == declarer) {
          _confirmPendingTrophyIfAny();
        }
      } else {
        winner = seat;
        loser = declarer;
        if (_provisionalTrophySeat == declarer) {
          // Bluff on final card was caught! Revoke provisional trophy
          trophies[declarer] = max(0, trophies[declarer] - 1);
          trophiesLeft++;
          _provisionalTrophySeat = null;
        }
      }

      final stackCount = stack.length;
      wonCards[winner] += stackCount;
      stack.clear();
      topClaimSpice = null;
      topClaimNum = null;
      lastPlayer = null;

      // Loser draws 2 penalty cards
      var drawn = 0;
      for (var i = 0; i < 2 && deck.isNotEmpty; i++) {
        hands[loser].add(deck.removeLast());
        drawn++;
      }

      final attrLabel = attr == 'spice' ? '香料' : '数字';
      lastChallenge = {
        'challenger': seat,
        'declarer': declarer,
        'attr': attr,
        'claimedSpice': cSpice,
        'claimedNum': cNum,
        'actualCard': topCard,
        'passed': passed,
        'winner': winner,
        'loser': loser,
        'wonCount': stackCount,
      };
      lastActionText =
          '${name(seat)} 质疑 ${name(declarer)} 的【$attrLabel】：翻开实牌【${_cardLabel(topCard)}】，${passed ? "实话！${name(declarer)}" : "吹牛被抓！${name(seat)}"} 赢得牌堆 $stackCount 分，${name(loser)} 罚摸 $drawn 张牌！';
      host.log(lastActionText);

      turn = loser;
      stepCount++;
      _checkEndConditions();
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');

    if (type == 'draw') {
      _confirmPendingTrophyIfAny();
      if (_over) return;

      if (deck.isNotEmpty) {
        hands[seat].add(deck.removeLast());
      }
      lastActionText = '${name(seat)} 摸了 1 张牌。';
      host.log(lastActionText);

      turn = (turn + 1) % players;
      if (turn == lastPlayer) {
        // Everyone else drew around the table; declarer may play on top without self-challenge
        lastPlayer = null;
      }
      stepCount++;
      _checkEndConditions();
      return;
    }

    if (type == 'play') {
      _confirmPendingTrophyIfAny();
      if (_over) return;

      final idx = asInt(action['cardIdx'], -1);
      if (idx < 0 || idx >= hands[seat].length) {
        throw GameError('无效的手牌索引 ($idx)');
      }
      final spice = asStr(action['spice']);
      final number = asInt(action['num'], -1);
      if (!isLegalClaim(spice, number)) {
        throw GameError('宣称的香料或点数不符合递增规则（空牌堆须声明 1..3，非空须同香料且点数更大，10 之后回到 1..3）');
      }

      final card = hands[seat].removeAt(idx);
      stack.add(card);
      topClaimSpice = spice;
      topClaimNum = number;
      lastPlayer = seat;

      var trophyNote = '';
      if (hands[seat].isEmpty && trophiesLeft > 0) {
        trophies[seat]++;
        trophiesLeft--;
        _provisionalTrophySeat = seat;
        trophyNote = '（手牌出空，夺得 +10 VP 奖杯！）';
      }

      lastActionText = '${name(seat)} 暗出 1 张牌，宣称【${spiceName(spice)} $number】$trophyNote';
      host.log(lastActionText);

      turn = (turn + 1) % players;
      stepCount++;
      _checkEndConditions();
      return;
    }

    throw GameError('未知操作：$type');
  }

  String _cardLabel(Map<String, dynamic> c) {
    final t = asStr(c['type']);
    if (t == 'WILD_SPICE') return '🌈 百搭香料';
    if (t == 'WILD_NUM') return '🔢 百搭数字';
    return '${spiceName(asStr(c['spice']))} ${c['num']}';
  }

  void _checkEndConditions() {
    if (_over) return;
    for (var s = 0; s < players; s++) {
      if (trophies[s] >= 2 && _provisionalTrophySeat == null) {
        _finishGame('${name(s)} 率先收集 2 座奖杯，游戏结束！');
        return;
      }
    }
    if (trophiesLeft <= 0 && _provisionalTrophySeat == null) {
      _finishGame('3 座奖杯已全部颁发，游戏结束！');
      return;
    }
    if (deck.isEmpty || stepCount >= 120) {
      _finishGame('牌库耗尽（触发世界末日卡），游戏结束！');
      return;
    }
  }

  void _finishGame(String reason) {
    _over = true;
    final sc = scores;
    _placings = rankByScore(sc);
    final winners = [
      for (var s = 0; s < players; s++)
        if (_placings![s] == 1) '${name(s)}(${sc[s]}分)',
    ];
    resultText = '$reason 最终胜者：${winners.join("、")}！';
    host.log('猫吃三椒结束：$resultText');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    // 1. Consider challenging if stack is non-empty and we didn't play the last card
    if (stack.isNotEmpty && lastPlayer != null && lastPlayer != seat && topClaimSpice != null && topClaimNum != null) {
      final declarer = lastPlayer!;
      final declarerEmptied = hands[declarer].isEmpty;
      final stackBig = stack.length >= 4;
      final claimHigh = topClaimNum! >= 9;
      final challengeProb = declarerEmptied
          ? 0.65
          : (stackBig ? 0.42 : (claimHigh ? 0.35 : 0.18));
      if (rng.nextDouble() < challengeProb) {
        final attr = rng.nextBool() ? 'num' : 'spice';
        return {'type': 'challenge', 'attr': attr};
      }
    }

    final h = hands[seat];
    if (h.isEmpty) {
      return {'type': 'draw'};
    }

    // Determine valid claim target (spice, legalNumbers)
    final String targetSpice;
    final List<int> legalNums;
    if (stack.isEmpty || topClaimSpice == null || topClaimNum == null) {
      // Pick spice we hold most of
      final counts = <String, int>{for (final sp in kSpices) sp: 0};
      for (final c in h) {
        final sp = asStr(c['spice']);
        if (counts.containsKey(sp)) counts[sp] = counts[sp]! + 1;
      }
      targetSpice = kSpices.reduce((a, b) => (counts[a] ?? 0) >= (counts[b] ?? 0) ? a : b);
      legalNums = const [1, 2, 3];
    } else {
      targetSpice = topClaimSpice!;
      if (topClaimNum == 10) {
        legalNums = const [1, 2, 3];
      } else {
        legalNums = [for (var n = topClaimNum! + 1; n <= 10; n++) n];
      }
    }

    // Try to find an exact matching card or wild card in hand
    for (var i = 0; i < h.length; i++) {
      final c = h[i];
      final sp = asStr(c['spice']);
      final numVal = asInt(c['num']);
      if (sp == targetSpice && legalNums.contains(numVal)) {
        return {'type': 'play', 'cardIdx': i, 'spice': targetSpice, 'num': numVal};
      }
    }
    for (var i = 0; i < h.length; i++) {
      final c = h[i];
      final t = asStr(c['type']);
      if (t == 'WILD_SPICE' || t == 'WILD_NUM') {
        return {'type': 'play', 'cardIdx': i, 'spice': targetSpice, 'num': legalNums.first};
      }
    }

    // Half matched card (either right spice or right number) -> play as semi-bluff
    for (var i = 0; i < h.length; i++) {
      final c = h[i];
      if (asStr(c['spice']) == targetSpice) {
        return {'type': 'play', 'cardIdx': i, 'spice': targetSpice, 'num': legalNums.first};
      }
      final numVal = asInt(c['num']);
      if (legalNums.contains(numVal)) {
        return {'type': 'play', 'cardIdx': i, 'spice': targetSpice, 'num': numVal};
      }
    }

    // Either bluff with first card or draw
    if (rng.nextDouble() < 0.55) {
      return {
        'type': 'play',
        'cardIdx': rng.nextInt(h.length),
        'spice': targetSpice,
        'num': legalNums.first,
      };
    }
    return {'type': 'draw'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'turn': turn,
      'deckCount': deck.length,
      'stackCount': stack.length,
      'topClaimSpice': topClaimSpice,
      'topClaimNum': topClaimNum,
      'lastPlayer': lastPlayer,
      'trophiesLeft': trophiesLeft,
      'trophies': trophies,
      'wonCards': wonCards,
      'scores': scores,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hands': [
        for (var s = 0; s < players; s++)
          (_over || seat == s)
              ? [for (final c in hands[s]) Map<String, dynamic>.of(c)]
              : const <Map<String, dynamic>>[],
      ],
      'myHand': (seat >= 0 && seat < players)
          ? [for (final c in hands[seat]) Map<String, dynamic>.of(c)]
          : const <Map<String, dynamic>>[],
      'lastChallenge': lastChallenge,
      'lastActionText': lastActionText,
      'waitingFor': waitingFor,
      'over': _over,
      'resultText': resultText,
    };
  }
}
