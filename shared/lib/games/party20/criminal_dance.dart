import '../../src/engine.dart';

class CriminalDanceGame extends GameEngine {
  CriminalDanceGame(super.setup);

  static const Map<String, Map<String, String>> cardInfo = {
    'first_finder': {
      'name': '第一发现人',
      'emoji': '🥇',
      'desc': '首回合必须打出以开启案件调查',
    },
    'culprit': {
      'name': '犯人',
      'emoji': '🦹',
      'desc': '只能在手牌剩最后1张时打出；打出即逃脱成功，犯人与共犯获胜！',
    },
    'detective': {
      'name': '侦探',
      'emoji': '🕵️',
      'desc': '手牌≤3张时打出并指认1名玩家；若其持有犯人且无不在场证明则侦探方获胜！',
    },
    'dog': {
      'name': '警犬',
      'emoji': '🐕',
      'desc': '嗅探并弃置目标玩家1张手牌；若嗅出【犯人】则警犬立即破案获胜！',
    },
    'alibi': {
      'name': '不在场证明',
      'emoji': '👤',
      'desc': '留在手中时，即使持有【犯人】被侦探指认也可免于定罪',
    },
    'accomplice': {
      'name': '共犯',
      'emoji': '🎭',
      'desc': '打出后加入犯人阵营，与犯人共享胜负',
    },
    'witness': {
      'name': '目击者',
      'emoji': '👁️',
      'desc': '秘密查看目标玩家的全部手牌，记录在个人情报中',
    },
    'info_exchange': {
      'name': '信息交换',
      'emoji': '🔄',
      'desc': '所有玩家同时将1张手牌传给下家',
    },
    'trade': {
      'name': '交易',
      'emoji': '🤝',
      'desc': '与指定目标玩家互相交换1张手牌',
    },
    'rumor': {
      'name': '流言',
      'emoji': '📢',
      'desc': '所有玩家同时从右手边邻居处随机抽取1张手牌',
    },
    'civilian': {
      'name': '普通人',
      'emoji': '🧑',
      'desc': '无特殊效果，用于消耗手牌或掩护身份',
    },
  };

  int totalRounds = 2;
  int round = 1;
  int turn = 0;
  bool firstTurn = true;
  String phase = 'play'; // 'play' | 'over'

  /// Each seat's hidden hand of card keys.
  late List<List<String>> hands;

  /// Private intelligence peeked by each seat: `intel[seat][targetSeat] = List<String>`.
  late List<Map<int, List<String>>> intel;

  /// Seats that have played `'accomplice'` in the current round.
  final Set<int> accomplices = {};

  /// Public discard/played card history in current round.
  final List<Map<String, dynamic>> playedPile = [];

  /// Cumulative scores across rounds.
  late List<int> scores;

  String? lastWinnerSide; // 'good' | 'culprit'
  String lastEvent = '犯人在跳舞开启！手握【🥇第一发现人】的玩家必须首回合出牌！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    return rankByScore(scores);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [turn];
  }

  static String cardLabel(String key) {
    final info = cardInfo[key];
    if (info == null) return key;
    return '${info['emoji']}${info['name']}';
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 2);
    round = 1;
    scores = List<int>.filled(players, 0);
    _startRound();
    host.log('【犯人在跳舞】推理派对名作开启！共 $totalRounds 局，犯人卡牌将在众人手中暗中流转！');
  }

  void _startRound() {
    final totalCards = players * 4;
    final deck = <String>[
      'first_finder',
      'culprit',
      'detective',
      'dog',
      'alibi',
      'accomplice',
      'witness',
      'info_exchange',
      'trade',
      'rumor',
      'alibi',
      'detective',
    ];
    const extras = [
      'witness',
      'trade',
      'info_exchange',
      'rumor',
      'alibi',
      'civilian',
      'dog',
      'witness',
      'trade',
      'rumor',
      'civilian',
      'civilian',
    ];
    var extraIdx = 0;
    while (deck.length < totalCards) {
      deck.add(extras[extraIdx % extras.length]);
      extraIdx++;
    }
    final activeDeck = deck.sublist(0, totalCards)..shuffle(rng);

    hands = [
      for (var s = 0; s < players; s++)
        activeDeck.sublist(s * 4, (s + 1) * 4),
    ];
    intel = [for (var s = 0; s < players; s++) <int, List<String>>{}];
    accomplices.clear();
    playedPile.clear();
    phase = 'play';
    firstTurn = true;

    // Player holding 'first_finder' starts Turn 1
    turn = 0;
    for (var s = 0; s < players; s++) {
      if (hands[s].contains('first_finder')) {
        turn = s;
        break;
      }
    }

    lastEvent = '第 $round/$totalRounds 局开始！请持有【🥇第一发现人】的 ${name(turn)} 打出首张牌开启调查！';
  }

  /// Legal cards in `hands[seat]` that `seat` is allowed to play right now.
  List<String> playableCards(int seat) {
    if (seat < 0 || seat >= players) return const [];
    final h = hands[seat];
    if (h.isEmpty) return const [];
    if (firstTurn && h.contains('first_finder')) {
      return const ['first_finder'];
    }
    final out = <String>[];
    for (final c in h) {
      if (c == 'culprit' && h.length > 1) continue;
      if (c == 'detective' && h.length > 3) continue;
      if (!out.contains(c)) out.add(c);
    }
    if (out.isEmpty) {
      // Fallback if hand only has restricted cards (e.g. >3 cards all detective/culprit)
      for (final c in h) {
        if (c != 'culprit' || h.length == 1) {
          if (!out.contains(c)) out.add(c);
        }
      }
      if (out.isEmpty) out.add(h.first);
    }
    return out;
  }

  List<int> validTargets(int seat) => [
        for (var s = 0; s < players; s++)
          if (s != seat && hands[s].isNotEmpty) s,
      ];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你出牌');

    final type = asStr(action['type']);
    if (type != 'play') {
      throw GameError('未知操作：$type');
    }

    final card = asStr(action['card']);
    if (!hands[seat].contains(card)) {
      throw GameError('你手中没有【${cardLabel(card)}】');
    }

    if (firstTurn && hands[seat].contains('first_finder') && card != 'first_finder') {
      throw GameError('首回合必须打出【🥇第一发现人】开启调查！');
    }

    if (card == 'culprit' && hands[seat].length > 1) {
      throw GameError('【🦹犯人】只能在手牌只剩最后 1 张时打出！');
    }

    final legal = playableCards(seat);
    if (card == 'detective' && hands[seat].length > 3 && !legal.contains('detective')) {
      throw GameError('【🕵️侦探】只能在手牌不超过 3 张时打出！');
    }

    final targets = validTargets(seat);
    final target = asInt(action['target'], -1);
    final needsTarget =
        (card == 'detective' || card == 'dog' || card == 'witness' || card == 'trade') &&
            targets.isNotEmpty;
    if (needsTarget && !targets.contains(target)) {
      throw GameError('请选择一名持有手牌的有效目标玩家');
    }

    // Remove played card from seat's hand
    hands[seat].remove(card);
    firstTurn = false;
    playedPile.add({
      'seat': seat,
      'card': card,
      'target': target >= 0 ? target : null,
    });

    switch (card) {
      case 'first_finder':
        lastEvent = '🥇 ${name(seat)} 打出【第一发现人】，案发现场调查正式开启！';
        host.log(lastEvent);
        break;

      case 'culprit':
        // Played as the last card in hand -> Culprit & Accomplices win immediately!
        _endRound(
          winnerSide: 'culprit',
          culpritSeat: seat,
          heroSeat: seat,
          reason: '🦹 ${name(seat)} 在最后 1 张手牌亮出【犯人】华丽逃脱！犯人阵营大获全胜！',
        );
        return;

      case 'accomplice':
        accomplices.add(seat);
        lastEvent = '🎭 ${name(seat)} 打出【共犯】，暗中投靠犯人阵营！';
        host.log(lastEvent);
        break;

      case 'detective':
        if (target >= 0) {
          final hasCulprit = hands[target].contains('culprit');
          final hasAlibi = hands[target].contains('alibi');
          if (hasCulprit && !hasAlibi) {
            _endRound(
              winnerSide: 'good',
              culpritSeat: target,
              heroSeat: seat,
              reason:
                  '🕵️ ${name(seat)} 打出【侦探】精准指认 ${name(target)}！${name(target)} 手握【犯人】且无不在场证明，当场落网！',
            );
            return;
          } else if (hasCulprit && hasAlibi) {
            lastEvent =
                '🕵️ ${name(seat)} 指认 ${name(target)} 为犯人，但 ${name(target)} 手握【👤不在场证明】从容化解了指控！';
            host.log(lastEvent);
          } else {
            lastEvent = '🕵️ ${name(seat)} 指认 ${name(target)}，但 ${name(target)} 并非犯人！';
            host.log(lastEvent);
          }
        }
        break;

      case 'dog':
        if (target >= 0 && hands[target].isNotEmpty) {
          final tHand = hands[target];
          String inspected;
          final reqCard = asStr(action['inspectCard']);
          final reqIdx = asInt(action['cardIdx'], -1);
          if (reqCard.isNotEmpty && tHand.contains(reqCard)) {
            inspected = reqCard;
          } else if (reqIdx >= 0 && reqIdx < tHand.length) {
            inspected = tHand[reqIdx];
          } else {
            inspected = tHand[rng.nextInt(tHand.length)];
          }
          intel[seat][target] = [inspected];
          if (inspected == 'culprit') {
            _endRound(
              winnerSide: 'good',
              culpritSeat: target,
              heroSeat: seat,
              reason: '🐕 ${name(seat)} 放出【警犬】直接嗅出 ${name(target)} 手中的【🦹犯人】！警犬立下头功破案获胜！',
            );
            return;
          } else {
            tHand.remove(inspected);
            playedPile.add({
              'seat': target,
              'card': inspected,
              'discardedByDog': true,
            });
            lastEvent =
                '🐕 ${name(seat)} 的【警犬】嗅探并弃置了 ${name(target)} 的 1 张【${cardLabel(inspected)}】，未发现犯人！';
            host.log(lastEvent);
          }
        }
        break;

      case 'witness':
        if (target >= 0) {
          intel[seat][target] = List<String>.of(hands[target]);
          lastEvent = '👁️ ${name(seat)} 打出【目击者】，秘密查看了 ${name(target)} 的全部 ${hands[target].length} 张手牌！';
          host.log(lastEvent);
        }
        break;

      case 'info_exchange':
        _resolveInfoExchange(seat, action);
        break;

      case 'trade':
        _resolveTrade(seat, target, action);
        break;

      case 'rumor':
        _resolveRumor(seat);
        break;

      case 'alibi':
      case 'civilian':
        lastEvent = '🃏 ${name(seat)} 打出了【${cardLabel(card)}】。';
        host.log(lastEvent);
        break;
    }

    _advanceTurn();
  }

  void _resolveInfoExchange(int actorSeat, Map<String, dynamic> action) {
    final activeSeats = [
      for (var s = 0; s < players; s++)
        if (hands[s].isNotEmpty) s,
    ];
    if (activeSeats.length >= 2) {
      final chosen = <int, String>{};
      for (final s in activeSeats) {
        final h = hands[s];
        final reqGive = s == actorSeat ? asStr(action['giveCard']) : '';
        if (reqGive.isNotEmpty && h.contains(reqGive)) {
          chosen[s] = reqGive;
        } else {
          chosen[s] = h.first;
        }
      }
      for (var i = 0; i < activeSeats.length; i++) {
        final from = activeSeats[i];
        final to = activeSeats[(i + 1) % activeSeats.length];
        final c = chosen[from]!;
        hands[from].remove(c);
        hands[to].add(c);
      }
    }
    lastEvent = '🔄 ${name(actorSeat)} 发动【信息交换】，所有玩家同时将 1 张手牌传给了下家！';
    host.log(lastEvent);
  }

  void _resolveTrade(int seat, int target, Map<String, dynamic> action) {
    if (target >= 0 && hands[seat].isNotEmpty && hands[target].isNotEmpty) {
      final reqGive = asStr(action['giveCard']);
      final myCard = (reqGive.isNotEmpty && hands[seat].contains(reqGive))
          ? reqGive
          : hands[seat].first;
      final tIdx = asInt(action['targetCardIdx'], -1);
      final theirCard = (tIdx >= 0 && tIdx < hands[target].length)
          ? hands[target][tIdx]
          : hands[target][rng.nextInt(hands[target].length)];
      hands[seat].remove(myCard);
      hands[target].remove(theirCard);
      hands[seat].add(theirCard);
      hands[target].add(myCard);
      lastEvent = '🤝 ${name(seat)} 发动【交易】，与 ${name(target)} 互相交换了 1 张手牌！';
      host.log(lastEvent);
    } else {
      lastEvent = '🤝 ${name(seat)} 打出【交易】（无手牌可交换）。';
      host.log(lastEvent);
    }
  }

  void _resolveRumor(int actorSeat) {
    final activeSeats = [
      for (var s = 0; s < players; s++)
        if (hands[s].isNotEmpty) s,
    ];
    if (activeSeats.length >= 2) {
      final drawn = <int, String>{};
      for (var i = 0; i < activeSeats.length; i++) {
        final receiver = activeSeats[i];
        final rightNeighbor = activeSeats[(i - 1 + activeSeats.length) % activeSeats.length];
        final rh = hands[rightNeighbor];
        drawn[receiver] = rh[rng.nextInt(rh.length)];
      }
      for (var i = 0; i < activeSeats.length; i++) {
        final receiver = activeSeats[i];
        final rightNeighbor = activeSeats[(i - 1 + activeSeats.length) % activeSeats.length];
        final c = drawn[receiver]!;
        hands[rightNeighbor].remove(c);
      }
      for (final e in drawn.entries) {
        hands[e.key].add(e.value);
      }
    }
    lastEvent = '📢 ${name(actorSeat)} 散播【流言】，每位玩家同时从右邻手中随机抽取了 1 张牌！';
    host.log(lastEvent);
  }

  void _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final next = (turn + step) % players;
      if (hands[next].isNotEmpty) {
        turn = next;
        return;
      }
    }
    // No player has any cards left
    _endRound(
      winnerSide: 'culprit',
      culpritSeat: turn,
      heroSeat: turn,
      reason: '🦹 调查牌全部耗尽，犯人趁乱成功逃逸！',
    );
  }

  void _endRound({
    required String winnerSide,
    required int culpritSeat,
    required int heroSeat,
    required String reason,
  }) {
    lastWinnerSide = winnerSide;
    if (winnerSide == 'culprit') {
      scores[culpritSeat] += 4;
      for (final acc in accomplices) {
        if (acc != culpritSeat) scores[acc] += 3;
      }
    } else {
      scores[heroSeat] += 4;
      for (var s = 0; s < players; s++) {
        if (s != culpritSeat && !accomplices.contains(s) && s != heroSeat) {
          scores[s] += 2;
        }
      }
    }

    host.log(reason);
    if (round < totalRounds) {
      round++;
      _startRound();
      lastEvent = '$reason · 🔄 进入第 $round/$totalRounds 局调查！';
    } else {
      phase = 'over';
      lastEvent = '$reason · 🏆 全场 $totalRounds 局调查结束！';
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    final revealAll = isOver;

    return {
      'round': round,
      'totalRounds': totalRounds,
      'turn': turn,
      'firstTurn': firstTurn,
      'phase': phase,
      'cardInfo': cardInfo,
      // Strictly hide other players' hands!
      'myHand': validPlayer ? List<String>.of(hands[seat]) : const <String>[],
      'playable': validPlayer && seat == turn ? playableCards(seat) : const <String>[],
      'validTargets': validPlayer && seat == turn ? validTargets(seat) : const <int>[],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'revealedHands': revealAll
          ? [for (var s = 0; s < players; s++) List<String>.of(hands[s])]
          : null,
      // Strictly show only `seat`'s own private witness/dog intel!
      'intel': validPlayer
          ? {
              for (final e in intel[seat].entries)
                '${e.key}': List<String>.of(e.value),
            }
          : const <String, dynamic>{},
      'accomplices': accomplices.toList()..sort(),
      'playedPile': playedPile,
      'scores': List<int>.of(scores),
      'lastWinnerSide': lastWinnerSide,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;
    final legal = playableCards(seat);
    if (legal.isEmpty) return null;

    final targets = validTargets(seat);
    final myIntel = intel[seat];

    // If bot knows who holds 'culprit' from its own private `intel[seat]`, play dog or detective!
    int? knownCulpritTarget;
    for (final e in myIntel.entries) {
      if (targets.contains(e.key) && e.value.contains('culprit')) {
        knownCulpritTarget = e.key;
        break;
      }
    }

    if (knownCulpritTarget != null && !hands[seat].contains('culprit') && !accomplices.contains(seat)) {
      if (legal.contains('dog')) {
        return {'type': 'play', 'card': 'dog', 'target': knownCulpritTarget};
      }
      if (legal.contains('detective')) {
        return {'type': 'play', 'card': 'detective', 'target': knownCulpritTarget};
      }
    }

    // Pick a card to play (if holding culprit, avoid playing alibi until forced)
    var card = legal.first;
    if (hands[seat].contains('culprit') && legal.length > 1 && card == 'alibi') {
      card = legal[1];
    }

    if ((card == 'detective' || card == 'dog' || card == 'witness' || card == 'trade') &&
        targets.isNotEmpty) {
      final pickTarget = knownCulpritTarget ?? targets[rng.nextInt(targets.length)];
      return {'type': 'play', 'card': card, 'target': pickTarget};
    }

    return {'type': 'play', 'card': card};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] -= 50;
    phase = 'over';
    lastEvent = '${name(seat)} 放弃案件推理，对局结束！';
    host.log(lastEvent);
  }
}
