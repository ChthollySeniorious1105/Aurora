import '../../src/engine.dart';

/// Build the 79 pyramid number cards: 1x'0', 1x'1', 2x'2', ..., 12x'12'.
List<String> buildFlip7NumberCards() {
  final cards = <String>['0'];
  for (var n = 1; n <= 12; n++) {
    for (var k = 0; k < n; k++) {
      cards.add('$n');
    }
  }
  return cards;
}

/// Build the full 94-card Flip 7 deck (79 numbers + 6 modifiers + 9 special cards).
List<String> buildFlip7FullDeck() {
  return [
    ...buildFlip7NumberCards(),
    '+2',
    '+4',
    '+6',
    '+8',
    '+10',
    'x2',
    'second_chance',
    'second_chance',
    'second_chance',
    'freeze',
    'freeze',
    'freeze',
    'flip3',
    'flip3',
    'flip3',
  ];
}

bool isFlip7NumberCard(String card) {
  final v = int.tryParse(card);
  return v != null && v >= 0 && v <= 12;
}

bool isFlip7ModifierCard(String card) =>
    card == '+2' ||
    card == '+4' ||
    card == '+6' ||
    card == '+8' ||
    card == '+10' ||
    card == 'x2';

/// Calculate round points for a player given their number cards, modifier cards, and bust status.
int calcFlip7RoundScore(
  List<int> numbers,
  List<String> modifiers, {
  bool busted = false,
}) {
  if (busted) return 0;
  var total = 0;
  for (final n in numbers) {
    total += n;
  }
  for (final m in modifiers) {
    if (m == 'x2') {
      total *= 2;
    }
  }
  for (final m in modifiers) {
    if (m == '+2') total += 2;
    if (m == '+4') total += 4;
    if (m == '+6') total += 6;
    if (m == '+8') total += 8;
    if (m == '+10') total += 10;
  }
  if (numbers.toSet().length >= 7) {
    total += 15;
  }
  return total;
}

class Flip7Game extends GameEngine {
  Flip7Game(super.setup);

  late List<String> deck;
  late List<String> discard;

  /// Face-up number cards (0..12) collected by each player this round
  late List<List<int>> numberCards;

  /// Face-up modifier cards ('+2', '+4', '+6', '+8', '+10', 'x2') per player this round
  late List<List<String>> modifiers;

  /// Whether each player holds a Second Chance (免死金牌) card this round
  late List<bool> hasSecondChance;

  /// Status per player this round: 'active', 'stayed', 'busted', 'flip7'
  late List<String> playerStatus;

  /// Total banked score across rounds
  late List<int> scores;

  /// Score earned in the most recently completed round
  late List<int> lastRoundScores;

  int round = 1;
  int dealer = 0;
  int turn = 0;
  late int targetScore;

  String lastCardDrawn = '';
  String lastActionText = '';
  int? lastFlip7Seat;
  bool over = false;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void start() {
    targetScore = setup.opt<int>('targetScore', 200);
    deck = shuffled(buildFlip7FullDeck(), rng);
    discard = <String>[];

    numberCards = List.generate(players, (_) => <int>[]);
    modifiers = List.generate(players, (_) => <String>[]);
    hasSecondChance = List<bool>.filled(players, false);
    playerStatus = List<String>.filled(players, 'active');
    scores = List<int>.filled(players, 0);
    lastRoundScores = List<int>.filled(players, 0);

    round = 1;
    dealer = 0;
    over = false;
    lastCardDrawn = '';
    lastFlip7Seat = null;

    _startNewRound(initial: true);
  }

  String _drawCard() {
    if (deck.isEmpty) {
      if (discard.isNotEmpty) {
        deck = shuffled(discard, rng);
        discard.clear();
      } else {
        deck = shuffled(buildFlip7FullDeck(), rng);
      }
    }
    return deck.removeLast();
  }

  void _startNewRound({bool initial = false}) {
    for (var s = 0; s < players; s++) {
      for (final n in numberCards[s]) {
        discard.add('$n');
      }
      discard.addAll(modifiers[s]);
      if (hasSecondChance[s]) discard.add('second_chance');
      numberCards[s] = <int>[];
      modifiers[s] = <String>[];
      hasSecondChance[s] = false;
      playerStatus[s] = 'active';
    }

    // Deal 1 initial number card to each player to open the round
    for (var i = 0; i < players; i++) {
      final s = (dealer + i) % players;
      var safety = 0;
      while (safety < 20) {
        safety++;
        final c = _drawCard();
        if (isFlip7NumberCard(c)) {
          numberCards[s].add(int.parse(c));
          break;
        } else {
          discard.add(c);
        }
      }
    }

    turn = dealer;
    if (initial) {
      lastActionText = '翻转七号开始！目标分数 $targetScore 分，第 1 轮发牌完毕。';
      host.log(lastActionText);
    }
  }

  int get currentRoundScoreForTurn =>
      calcFlip7RoundScore(numberCards[turn], modifiers[turn],
          busted: playerStatus[turn] == 'busted');

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前不是你的回合');
    if (playerStatus[seat] != 'active') throw GameError('你本轮已停牌或爆牌');

    final type = asStr(action['type']);
    if (type == 'stay') {
      playerStatus[seat] = 'stayed';
      final pts = calcFlip7RoundScore(numberCards[seat], modifiers[seat]);
      lastActionText = '${name(seat)} 选择【见好就收 (Stay)】，锁定本轮 $pts 分';
      host.log(lastActionText);
      _advanceOrEndRound();
      return;
    }

    if (type == 'hit') {
      final targetSeat = asInt(action['target'], seat);
      final roundEnded = _drawAndResolveForSeat(seat, freezeTarget: targetSeat);
      if (!roundEnded && !over) {
        _advanceOrEndRound();
      }
      return;
    }

    throw GameError('未知操作: $type（仅支持 hit 或 stay）');
  }

  /// Draws 1 card for [seat] and resolves it. Returns true if the round ended immediately (Flip 7).
  bool _drawAndResolveForSeat(int seat, {int? freezeTarget}) {
    final card = _drawCard();
    lastCardDrawn = card;

    if (isFlip7NumberCard(card)) {
      final numVal = int.parse(card);
      if (numberCards[seat].contains(numVal)) {
        if (hasSecondChance[seat]) {
          hasSecondChance[seat] = false;
          discard.add(card);
          discard.add('second_chance');
          lastActionText =
              '${name(seat)} 翻出重复数字【$numVal】，消耗【免死金牌】抵消爆牌！';
          host.log(lastActionText);
          return false;
        } else {
          discard.add(card);
          playerStatus[seat] = 'busted';
          lastActionText = '${name(seat)} 翻出重复数字【$numVal】，爆牌出局（本轮 0 分）！';
          host.log(lastActionText);
          return false;
        }
      } else {
        numberCards[seat].add(numVal);
        if (numberCards[seat].toSet().length >= 7) {
          playerStatus[seat] = 'flip7';
          lastFlip7Seat = seat;
          final pts = calcFlip7RoundScore(numberCards[seat], modifiers[seat]);
          lastActionText =
              '🎉 ${name(seat)} 翻出【$numVal】集齐 7 张不同数字牌，触发【FLIP 7 (+15分)】本轮立即结算（得 $pts 分）！';
          host.log(lastActionText);
          _endRound(flip7Seat: seat);
          return true;
        } else {
          lastActionText =
              '${name(seat)} 翻出数字【$numVal】（当前共 ${numberCards[seat].length}/7 张数字牌）';
          host.log(lastActionText);
          return false;
        }
      }
    }

    if (isFlip7ModifierCard(card)) {
      modifiers[seat].add(card);
      lastActionText = '${name(seat)} 翻出加分修饰牌【$card】！';
      host.log(lastActionText);
      return false;
    }

    if (card == 'second_chance') {
      if (!hasSecondChance[seat]) {
        hasSecondChance[seat] = true;
        lastActionText = '${name(seat)} 翻出【免死金牌 (Second Chance)】！';
      } else {
        // Give to another active player without one, or discard
        int recipient = -1;
        for (var i = 1; i < players; i++) {
          final other = (seat + i) % players;
          if (playerStatus[other] == 'active' && !hasSecondChance[other]) {
            recipient = other;
            break;
          }
        }
        if (recipient >= 0) {
          hasSecondChance[recipient] = true;
          lastActionText =
              '${name(seat)} 已有免死金牌，将新翻出的【免死金牌】转交给 ${name(recipient)}';
        } else {
          discard.add(card);
          lastActionText = '${name(seat)} 翻出额外的【免死金牌】（已弃置）';
        }
      }
      host.log(lastActionText);
      return false;
    }

    if (card == 'freeze') {
      discard.add(card);
      var target = (freezeTarget != null &&
              freezeTarget >= 0 &&
              freezeTarget < players &&
              playerStatus[freezeTarget] == 'active')
          ? freezeTarget
          : seat;
      playerStatus[target] = 'stayed';
      final pts = calcFlip7RoundScore(numberCards[target], modifiers[target]);
      lastActionText =
          '${name(seat)} 翻出【冰冻 (Freeze)】，${name(target)} 立即停牌并结算当前 $pts 分！';
      host.log(lastActionText);
      return false;
    }

    if (card == 'flip3') {
      discard.add(card);
      lastActionText = '${name(seat)} 翻出【连翻三张 (Flip Three)】！连续翻牌 3 次：';
      host.log(lastActionText);
      for (var k = 0; k < 3; k++) {
        if (playerStatus[seat] != 'active' || over) break;
        final ended = _drawAndResolveForSeat(seat);
        if (ended) return true;
      }
      return false;
    }

    return false;
  }

  void _advanceOrEndRound() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (playerStatus[next] == 'active') {
        turn = next;
        return;
      }
    }
    _endRound();
  }

  void _endRound({int? flip7Seat}) {
    for (var s = 0; s < players; s++) {
      final isBusted = playerStatus[s] == 'busted';
      final roundPts =
          calcFlip7RoundScore(numberCards[s], modifiers[s], busted: isBusted);
      lastRoundScores[s] = roundPts;
      scores[s] += roundPts;
    }

    final maxScore = scores.reduce((a, b) => a > b ? a : b);
    if (maxScore >= targetScore || round >= 25) {
      over = true;
      final winners = [
        for (var s = 0; s < players; s++)
          if (scores[s] == maxScore) name(s)
      ];
      lastActionText =
          '第 $round 轮结束！${winners.join("、")} 以 $maxScore 分达到目标，赢得翻转七号胜利！';
      host.log(lastActionText);
      return;
    }

    round++;
    dealer = (dealer + 1) % players;
    _startNewRound();
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'turn': turn,
      'dealer': dealer,
      'targetScore': targetScore,
      'deckCount': deck.length,
      'discardCount': discard.length,
      'numberCards': [
        for (final list in numberCards) [...list]
      ],
      'modifiers': [
        for (final list in modifiers) [...list]
      ],
      'hasSecondChance': [...hasSecondChance],
      'playerStatus': [...playerStatus],
      'currentRoundScores': [
        for (var s = 0; s < players; s++)
          calcFlip7RoundScore(
            numberCards[s],
            modifiers[s],
            busted: playerStatus[s] == 'busted',
          )
      ],
      'lastRoundScores': [...lastRoundScores],
      'scores': [...scores],
      'lastCardDrawn': lastCardDrawn,
      'lastActionText': lastActionText,
      'lastFlip7Seat': lastFlip7Seat,
      'over': over,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn || playerStatus[seat] != 'active') return null;

    final myNums = numberCards[seat];
    final myScore = calcFlip7RoundScore(myNums, modifiers[seat]);

    // If holding Second Chance, Always Hit! (0% chance of busting on next card!)
    if (hasSecondChance[seat]) {
      return {'type': 'hit'};
    }

    // If 6 distinct cards and close to Flip 7 bonus, weigh risk
    if (scores[seat] + myScore >= targetScore) {
      return {'type': 'stay'};
    }

    // Calculate approximate bust weight from face-up numbers (larger numbers have more copies in deck)
    final duplicateCopies = myNums.fold<int>(0, (acc, n) => acc + (n == 0 ? 0 : n - 1));
    final thresholdCopies = botLevel == 0
        ? 18
        : botLevel == 2
            ? 14
            : 16;

    if (myNums.length >= 5 || myScore >= 26 || duplicateCopies >= thresholdCopies) {
      return {'type': 'stay'};
    }

    return {'type': 'hit'};
  }
}
