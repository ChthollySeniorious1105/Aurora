import '../../src/engine.dart';

const theMessageFactionNames = {
  'red': '潜伏战线',
  'blue': '军情处',
  'green': '神秘酱油',
};

const theMessageActionNames = {
  'lock': '锁定',
  'swap': '调包',
  'decrypt': '破译',
  'intercept': '截获',
  'counter': '识破',
  'transfer': '转移',
  'reinforce': '增援',
  'burn': '烧毁',
  'trap': '真伪莫辨',
};

const theMessageActionDesc = {
  'lock': '令一名目标玩家本回合被锁定，无法拒收情报',
  'swap': '用另一张手牌替换正在传递的情报（或行动阶段换牌）',
  'decrypt': '检视正在传递的情报真伪（或行动阶段侦查摸牌）',
  'intercept': '将情报截留转向（或行动阶段抽取他人手牌）',
  'counter': '解除自身锁定状态并摸 1 张牌',
  'transfer': '将面前的情报直接转向另一名存活玩家',
  'reinforce': '摸 1 + 自身黑情报数量张牌',
  'burn': '烧毁任意一名玩家面前的 1 张黑情报',
  'trap': '翻开牌库顶 1 张牌直接作为情报置入目标面前',
};

const theMessageColorNames = {
  'red': '红情报',
  'blue': '蓝情报',
  'black': '黑情报',
};

const theMessageDeliveryNames = {
  'direct': '直达',
  'text': '密电',
};

const theMessageCodenames = [
  '老鬼',
  '老枪',
  '顾晓梦',
  '李宁玉',
  '吴志国',
  '白小年',
  '金生火',
];

/// Unshuffled faction list for [n] players (4..7).
List<String> theMessageFactions(int n, {bool includeGreen = true}) {
  if (includeGreen) {
    switch (n) {
      case 4:
        return const ['red', 'blue', 'green', 'green'];
      case 5:
        return const ['red', 'red', 'blue', 'blue', 'green'];
      case 6:
        return const ['red', 'red', 'blue', 'blue', 'green', 'green'];
      default:
        return const ['red', 'red', 'red', 'blue', 'blue', 'blue', 'green'];
    }
  } else {
    switch (n) {
      case 4:
        return const ['red', 'red', 'blue', 'blue'];
      case 5:
        return const ['red', 'red', 'red', 'blue', 'blue'];
      case 6:
        return const ['red', 'red', 'red', 'blue', 'blue', 'blue'];
      default:
        return const ['red', 'red', 'red', 'red', 'blue', 'blue', 'blue'];
    }
  }
}

class MessageCard {
  final int id;
  final String action;
  final String color; // 'red', 'blue', 'black'
  final String delivery; // 'direct', 'text'

  const MessageCard({
    required this.id,
    required this.action,
    required this.color,
    required this.delivery,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'action': action,
        'color': color,
        'delivery': delivery,
      };
}

List<MessageCard> buildMessageDeck() {
  const actions = [
    'lock',
    'swap',
    'decrypt',
    'intercept',
    'counter',
    'transfer',
    'reinforce',
    'burn',
    'trap',
  ];
  const colors = ['red', 'red', 'red', 'blue', 'blue', 'blue', 'black', 'black'];
  final out = <MessageCard>[];
  var id = 1;
  for (final act in actions) {
    for (var i = 0; i < 8; i++) {
      out.add(MessageCard(
        id: id++,
        action: act,
        color: colors[i],
        delivery: i.isEven ? 'direct' : 'text',
      ));
    }
  }
  return out;
}

class TheMessage extends GameEngine {
  TheMessage(super.setup);

  late List<String> factions;
  late List<String> codenames;
  late List<bool> alive;
  late List<List<MessageCard>> hands;
  late List<List<MessageCard>> intel;

  List<MessageCard> deck = [];
  List<MessageCard> discardPile = [];

  int turn = 0;
  int turnCount = 0;

  /// Phases: action, receive, over
  String phase = 'action';

  int sender = -1;
  int currentTarget = -1;
  MessageCard? transitCard;
  final Set<int> locked = {};
  final Set<int> passedSeats = {};
  final Set<int> decryptedBy = {};
  late List<String?> lastPeekInfo;

  final List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? lastEvent;

  String winner = ''; // 'red', 'blue', 'green'
  List<int> winnerSeats = [];
  String reason = '';

  @override
  bool get isOver => phase == 'over';

  @override
  int get botDelayMs => 700;

  @override
  List<int>? get placings => isOver ? rankWinners(players, winnerSeats) : null;

  @override
  Set<int>? voiceListeners(int seat) {
    if (isOver || seat < 0 || seat >= players || alive[seat]) return null;
    return {for (var s = 0; s < players; s++) if (!alive[s]) s};
  }

  List<int> get aliveSeats => [for (var s = 0; s < players; s++) if (alive[s]) s];

  int intelCount(int seat, String color) =>
      intel[seat].where((c) => c.color == color).length;

  int coloredIntelCount(int seat) =>
      intel[seat].where((c) => c.color == 'red' || c.color == 'blue').length;

  @override
  void start() {
    final includeGreen = setup.opt<bool>('green', true);
    factions = shuffled(theMessageFactions(players, includeGreen: includeGreen), rng);
    codenames = shuffled(theMessageCodenames, rng).sublist(0, players);
    alive = List.filled(players, true);
    hands = [for (var i = 0; i < players; i++) <MessageCard>[]];
    intel = [for (var i = 0; i < players; i++) <MessageCard>[]];
    lastPeekInfo = List.filled(players, null);

    deck = shuffled(buildMessageDeck(), rng);
    discardPile = [];

    for (var s = 0; s < players; s++) {
      _drawCards(s, 3);
    }

    turn = rng.nextInt(players);
    host.log('风声开始！${players}人谍战局，${name(turn)}（代号：${codenames[turn]}）率先行动');
    _startTurn(turn);
  }

  void _ensureDeck(int count) {
    if (deck.length >= count) return;
    if (discardPile.isNotEmpty) {
      deck.addAll(shuffled(discardPile, rng));
      discardPile.clear();
    }
    if (deck.length < count) {
      deck.addAll(shuffled(buildMessageDeck(), rng));
    }
  }

  void _drawCards(int seat, int count) {
    _ensureDeck(count);
    for (var i = 0; i < count && deck.isNotEmpty; i++) {
      hands[seat].add(deck.removeLast());
    }
  }

  void _startTurn(int seat) {
    turn = seat;
    turnCount++;
    locked.clear();
    passedSeats.clear();
    decryptedBy.clear();
    transitCard = null;
    sender = seat;
    currentTarget = -1;
    _drawCards(seat, 2);
    phase = 'action';
  }

  void _nextTurn() {
    if (isOver) return;
    if (turnCount >= players * 14) {
      _settleByTiebreaker();
      return;
    }
    for (var i = 1; i <= players; i++) {
      final nxt = (turn + i) % players;
      if (alive[nxt]) {
        _startTurn(nxt);
        return;
      }
    }
  }

  void _settleByTiebreaker() {
    // Score each alive player by how close they are to their win condition
    int progress(int s) {
      if (!alive[s]) return -10;
      return switch (factions[s]) {
        'red' => intelCount(s, 'red') * 10 - intelCount(s, 'black'),
        'blue' => intelCount(s, 'blue') * 10 - intelCount(s, 'black'),
        _ => coloredIntelCount(s) * 10 - intelCount(s, 'black'),
      };
    }

    var bestSeat = 0;
    var bestScore = -999;
    for (var s = 0; s < players; s++) {
      final p = progress(s);
      if (p > bestScore) {
        bestScore = p;
        bestSeat = s;
      }
    }
    final winFac = factions[bestSeat];
    final winners = winFac == 'green'
        ? [bestSeat]
        : [for (var s = 0; s < players; s++) if (factions[s] == winFac) s];
    _finish(
      winFac,
      winners,
      '电台限时截获期满，${name(bestSeat)}（${theMessageFactionNames[winFac]}）掌握最多有效情报获胜！',
    );
  }

  void _finish(String winFaction, List<int> winners, String why) {
    winner = winFaction;
    winnerSeats = winners;
    reason = why;
    phase = 'over';
    host.log('游戏结束：$why');
  }

  bool canPass(int seat) {
    if (phase != 'receive' || seat != currentTarget) return false;
    if (locked.contains(seat)) return false;
    if (seat == sender && passedSeats.contains(seat)) return false;
    final otherAlive = [for (var s = 0; s < players; s++) if (alive[s] && s != seat) s];
    if (otherAlive.isEmpty) return false;
    return true;
  }

  List<int> eligibleOtherAlive(int seat) =>
      [for (var s = 0; s < players; s++) if (alive[s] && s != seat) s];

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    switch (phase) {
      case 'action':
        return [turn];
      case 'receive':
        return [currentTarget];
      default:
        return const [];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    if (seat < 0 || seat >= players || !alive[seat]) {
      throw GameError('你已阵亡或不在座位上');
    }
    final type = asStr(action['type']);

    switch (phase) {
      case 'action':
        if (seat != turn) throw GameError('还没轮到你的回合');
        if (type == 'play_action') {
          final idx = asInt(action['index']);
          if (idx < 0 || idx >= hands[seat].length) throw GameError('无效的手牌序号');
          final card = hands[seat].removeAt(idx);
          discardPile.add(card);
          final target = asInt(action['target'], -1);
          _executeActionCard(seat, card, target);
          if (isOver) return;
          if (hands[seat].isEmpty) {
            _drawCards(seat, 1);
          }
          return;
        }
        if (type == 'transmit') {
          final idx = asInt(action['index']);
          if (idx < 0 || idx >= hands[seat].length) throw GameError('请选择要传出的情报手牌');
          final target = asInt(action['target']);
          if (target < 0 || target >= players || target == seat || !alive[target]) {
            throw GameError('请选择一名其他存活玩家作为传递目标');
          }
          final card = hands[seat].removeAt(idx);
          transitCard = card;
          sender = seat;
          currentTarget = target;
          passedSeats
            ..clear()
            ..add(seat);
          decryptedBy
            ..clear()
            ..add(seat);
          phase = 'receive';
          host.log(
            '${name(seat)} 向 ${name(target)} 发出了一份【${theMessageDeliveryNames[card.delivery]}】情报',
          );
          return;
        }
        throw GameError('请打出功能牌或选择手牌传递情报');

      case 'receive':
        if (seat != currentTarget) throw GameError('当前不是你处理情报');
        if (type == 'use_card') {
          final idx = asInt(action['index']);
          if (idx < 0 || idx >= hands[seat].length) throw GameError('无效的手牌序号');
          final card = hands[seat][idx];
          _executeReceiveResponse(seat, idx, card, action);
          return;
        }
        if (type == 'accept') {
          final card = transitCard!;
          transitCard = null;
          _receiveIntel(seat, card, fromSeat: sender);
          if (!isOver) _nextTurn();
          return;
        }
        if (type == 'pass') {
          if (!canPass(seat)) {
            throw GameError('你已被锁定或情报已传回发报人，必须接收该情报');
          }
          passedSeats.add(seat);
          final nextSeat = _nextReceiveTarget(seat);
          currentTarget = nextSeat;
          host.log('${name(seat)} 拒收情报，将情报传给了 ${name(nextSeat)}');
          return;
        }
        throw GameError('请选择接收情报、拒收传递或打出响应牌');

      default:
        throw GameError('当前阶段无法执行此操作');
    }
  }

  int _nextReceiveTarget(int fromSeat) {
    for (var i = 1; i <= players; i++) {
      final cand = (fromSeat + i) % players;
      if (alive[cand] && !passedSeats.contains(cand)) {
        return cand;
      }
    }
    // All other alive players have passed -> returns to sender!
    if (alive[sender]) return sender;
    for (var i = 1; i <= players; i++) {
      final cand = (fromSeat + i) % players;
      if (alive[cand]) return cand;
    }
    return fromSeat;
  }

  void _executeActionCard(int seat, MessageCard card, int rawTarget) {
    final others = eligibleOtherAlive(seat);
    final target = (rawTarget >= 0 && rawTarget < players && alive[rawTarget] && rawTarget != seat)
        ? rawTarget
        : (others.isNotEmpty ? others[rng.nextInt(others.length)] : seat);

    switch (card.action) {
      case 'lock':
        locked.add(target);
        host.log('${name(seat)} 对 ${name(target)} 使用了【锁定】！');
        break;
      case 'reinforce':
        final drawN = 1 + intelCount(seat, 'black');
        _drawCards(seat, drawN);
        host.log('${name(seat)} 使用【增援】摸了 $drawN 张牌');
        break;
      case 'burn':
        int burnSeat = -1;
        if (rawTarget >= 0 && rawTarget < players && alive[rawTarget] && intelCount(rawTarget, 'black') > 0) {
          burnSeat = rawTarget;
        } else if (intelCount(seat, 'black') > 0) {
          burnSeat = seat;
        } else {
          for (var s = 0; s < players; s++) {
            if (alive[s] && intelCount(s, 'black') > 0) {
              burnSeat = s;
              break;
            }
          }
        }
        if (burnSeat >= 0) {
          final bIdx = intel[burnSeat].indexWhere((c) => c.color == 'black');
          if (bIdx >= 0) {
            final burned = intel[burnSeat].removeAt(bIdx);
            discardPile.add(burned);
            host.log('${name(seat)} 使用【烧毁】，销毁了 ${name(burnSeat)} 面前的 1 张黑情报！');
            break;
          }
        }
        _drawCards(seat, 1);
        host.log('${name(seat)} 使用【烧毁】重整线索，摸了 1 张牌');
        break;
      case 'trap':
        _ensureDeck(1);
        final top = deck.removeLast();
        host.log('${name(seat)} 对 ${name(target)} 发动【真伪莫辨】，翻开牌顶作为情报！');
        _receiveIntel(target, top, fromSeat: seat);
        break;
      case 'decrypt':
        if (hands[target].isNotEmpty) {
          final peeked = hands[target][rng.nextInt(hands[target].length)];
          lastPeekInfo[seat] =
              '侦查 ${name(target)} 手牌：${theMessageColorNames[peeked.color]}·${theMessageActionNames[peeked.action]}';
        }
        _drawCards(seat, 1);
        host.log('${name(seat)} 对 ${name(target)} 使用【破译】侦查并摸 1 张牌');
        break;
      case 'intercept':
        if (hands[target].length > 1) {
          final stolen = hands[target].removeAt(rng.nextInt(hands[target].length));
          hands[seat].add(stolen);
          host.log('${name(seat)} 使用【截获】抽取了 ${name(target)} 的 1 张手牌');
        } else {
          _drawCards(seat, 1);
          host.log('${name(seat)} 使用【截获】摸了 1 张牌');
        }
        break;
      case 'swap':
        _drawCards(seat, 1);
        host.log('${name(seat)} 使用【调包】更换了手牌情报');
        break;
      case 'transfer':
        locked.add(target);
        host.log('${name(seat)} 使用【转移】布置传递路线，锁定 ${name(target)}');
        break;
      case 'counter':
        locked.remove(seat);
        _drawCards(seat, 1);
        host.log('${name(seat)} 使用【识破】洞察局势并摸 1 张牌');
        break;
    }
  }

  void _executeReceiveResponse(int seat, int idx, MessageCard card, Map<String, dynamic> action) {
    switch (card.action) {
      case 'decrypt':
        hands[seat].removeAt(idx);
        discardPile.add(card);
        decryptedBy.add(seat);
        host.log('${name(seat)} 打出【破译】，秘密检视了面前的情报！');
        break;
      case 'counter':
        hands[seat].removeAt(idx);
        discardPile.add(card);
        locked.remove(seat);
        _drawCards(seat, 1);
        host.log('${name(seat)} 打出【识破】，解除了锁定状态并摸 1 张牌！');
        break;
      case 'swap':
        if (hands[seat].length < 2) {
          throw GameError('调包需要手中至少还有另一张牌用于替换');
        }
        hands[seat].removeAt(idx);
        discardPile.add(card);
        final swapIdx = asInt(action['swapIndex'], 0).clamp(0, hands[seat].length - 1);
        final newIntel = hands[seat].removeAt(swapIdx);
        if (transitCard != null) {
          hands[seat].add(transitCard!);
        }
        transitCard = newIntel;
        decryptedBy
          ..clear()
          ..add(seat);
        passedSeats.add(seat);
        currentTarget = _nextReceiveTarget(seat);
        host.log('${name(seat)} 打出【调包】替换了情报，并将其传给 ${name(currentTarget)}！');
        break;
      case 'transfer':
      case 'intercept':
        final others = eligibleOtherAlive(seat);
        if (others.isEmpty) throw GameError('没有可转移的目标');
        final rawT = asInt(action['target'], -1);
        final target = others.contains(rawT) ? rawT : others.first;
        hands[seat].removeAt(idx);
        discardPile.add(card);
        passedSeats.add(seat);
        currentTarget = target;
        host.log('${name(seat)} 打出【${theMessageActionNames[card.action]}】，将情报转向 ${name(target)}！');
        break;
      default:
        throw GameError('该卡牌不能在接收阶段响应使用');
    }
  }

  void _receiveIntel(int receiver, MessageCard card, {required int fromSeat}) {
    intel[receiver].add(card);
    lastEvent = {
      'receiver': receiver,
      'sender': fromSeat,
      'card': card.toJson(),
      'turn': turnCount,
    };
    history.add(lastEvent!);
    host.log(
      '${name(receiver)} 接收了来自 ${name(fromSeat)} 的情报：【${theMessageColorNames[card.color]}】（${theMessageActionNames[card.action]}）',
    );

    final blacks = intelCount(receiver, 'black');
    if (blacks >= 3) {
      alive[receiver] = false;
      host.log('💀 ${name(receiver)} 累积 3 张黑情报，阵亡出局！（身份：${theMessageFactionNames[factions[receiver]]}）');

      if (fromSeat != receiver && factions[fromSeat] == 'green' && alive[fromSeat]) {
        _finish(
          'green',
          [fromSeat],
          '神秘酱油 ${name(fromSeat)} 亲手传出第 3 张黑情报淘汰了 ${name(receiver)}，完成个人使命获胜！',
        );
        return;
      }

      final aliveR = [for (var s = 0; s < players; s++) if (alive[s] && factions[s] == 'red') s];
      final aliveB = [for (var s = 0; s < players; s++) if (alive[s] && factions[s] == 'blue') s];
      final aliveG = [for (var s = 0; s < players; s++) if (alive[s] && factions[s] == 'green') s];

      if (aliveR.isEmpty && aliveB.isEmpty) {
        if (aliveG.isNotEmpty) {
          _finish('green', aliveG, '潜伏战线与军情处全部覆没，神秘酱油生存获胜！');
        } else {
          _finish('red', [0], '全员阵亡，残局结算');
        }
        return;
      }
      if (aliveR.isEmpty && aliveG.isEmpty) {
        _finish(
          'blue',
          [for (var s = 0; s < players; s++) if (factions[s] == 'blue') s],
          '潜伏战线全员阵亡，军情处（蓝方）获胜！',
        );
        return;
      }
      if (aliveB.isEmpty && aliveG.isEmpty) {
        _finish(
          'red',
          [for (var s = 0; s < players; s++) if (factions[s] == 'red') s],
          '军情处全员阵亡，潜伏战线（红方）获胜！',
        );
        return;
      }
      return;
    }

    final fac = factions[receiver];
    if (fac == 'red' && intelCount(receiver, 'red') >= 3) {
      _finish(
        'red',
        [for (var s = 0; s < players; s++) if (factions[s] == 'red') s],
        '${name(receiver)} 集齐 3 张红情报，潜伏战线（红方）获胜！',
      );
      return;
    }
    if (fac == 'blue' && intelCount(receiver, 'blue') >= 3) {
      _finish(
        'blue',
        [for (var s = 0; s < players; s++) if (factions[s] == 'blue') s],
        '${name(receiver)} 集齐 3 张蓝情报，军情处（蓝方）获胜！',
      );
      return;
    }
    if (fac == 'green' && coloredIntelCount(receiver) >= 3) {
      _finish(
        'green',
        [receiver],
        '神秘酱油 ${name(receiver)} 集齐 3 张真情报，达成个人目标独立获胜！',
      );
      return;
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    final over = isOver;
    final canSeeTransit = transitCard != null && (over || (me && decryptedBy.contains(seat)));

    return {
      'phase': phase,
      'turn': turn,
      'turnCount': turnCount,
      'sender': sender,
      'currentTarget': currentTarget,
      'alive': alive,
      'codenames': codenames,
      'myFaction': me ? factions[seat] : null,
      'factions': [
        for (var s = 0; s < players; s++)
          (over || !alive[s] || s == seat) ? factions[s] : null,
      ],
      'hand': me ? [for (final c in hands[seat]) c.toJson()] : const <Map<String, dynamic>>[],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'intel': [
        for (var s = 0; s < players; s++) [for (final c in intel[s]) c.toJson()],
      ],
      'deckCount': deck.length,
      'discardCount': discardPile.length,
      'locked': locked.toList(),
      'passedSeats': passedSeats.toList(),
      'canPass': me ? canPass(seat) : false,
      'transitDelivery': transitCard?.delivery,
      'transitCard': canSeeTransit ? transitCard!.toJson() : null,
      'lastPeek': me ? lastPeekInfo[seat] : null,
      'lastEvent': lastEvent,
      'history': history,
      'winner': winner,
      'winnerSeats': winnerSeats,
      'reason': reason,
    };
  }

  // ---------------------------------------------------------------- Bot
  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || !alive[seat]) return null;
    final myFaction = factions[seat];
    final myHand = hands[seat];
    final others = eligibleOtherAlive(seat);

    switch (phase) {
      case 'action':
        if (seat != turn) return null;
        // 1. Consider playing beneficial action cards if hand has >= 2 cards
        if (myHand.length >= 2 && botLevel > 0) {
          final burnIdx = myHand.indexWhere((c) => c.action == 'burn');
          if (burnIdx >= 0 && intelCount(seat, 'black') > 0) {
            return {'type': 'play_action', 'index': burnIdx, 'target': seat};
          }
          final reinfIdx = myHand.indexWhere((c) => c.action == 'reinforce');
          if (reinfIdx >= 0 && myHand.length <= 4) {
            return {'type': 'play_action', 'index': reinfIdx};
          }
          final lockIdx = myHand.indexWhere((c) => c.action == 'lock');
          if (lockIdx >= 0 && locked.isEmpty && others.isNotEmpty) {
            final t = others[rng.nextInt(others.length)];
            return {'type': 'play_action', 'index': lockIdx, 'target': t};
          }
        }

        // 2. Choose a card and target to transmit
        if (others.isEmpty) return null;
        final wantColor = myFaction == 'red' ? 'red' : (myFaction == 'blue' ? 'blue' : '');
        // If we have a black card, send it to someone with black cards or high intel
        final blackIdx = myHand.indexWhere((c) => c.color == 'black');
        if (blackIdx >= 0 && (botLevel > 0 || rng.nextBool())) {
          final sortedTargets = List<int>.of(others)
            ..sort((a, b) => intel[b].length.compareTo(intel[a].length));
          return {'type': 'transmit', 'index': blackIdx, 'target': sortedTargets.first};
        }
        // Prefer sending our own faction color if we think it might come back or help a teammate
        final matchIdx = wantColor.isEmpty
            ? myHand.indexWhere((c) => c.color != 'black')
            : myHand.indexWhere((c) => c.color == wantColor);
        final chosenIdx = matchIdx >= 0 ? matchIdx : rng.nextInt(myHand.length);
        final chosenTarget = others[rng.nextInt(others.length)];
        return {'type': 'transmit', 'index': chosenIdx, 'target': chosenTarget};

      case 'receive':
        if (seat != currentTarget || transitCard == null) return null;
        final knowsCard = decryptedBy.contains(seat);

        // If bot has 'decrypt' in hand and doesn't know the card yet, use it on higher difficulty
        if (!knowsCard && botLevel > 0) {
          final decIdx = myHand.indexWhere((c) => c.action == 'decrypt');
          if (decIdx >= 0) {
            return {'type': 'use_card', 'index': decIdx};
          }
        }

        // Decide whether the incoming intelligence is desirable
        bool wantAccept;
        if (knowsCard) {
          final col = transitCard!.color;
          if (col == 'black') {
            wantAccept = false;
          } else if (myFaction == 'green') {
            wantAccept = true;
          } else {
            wantAccept = col == myFaction;
          }
        } else {
          // Unknown card: accept if we have low black count (< 2), pass if at 2 black cards
          final myBlacks = intelCount(seat, 'black');
          if (myBlacks >= 2) {
            wantAccept = false;
          } else {
            wantAccept = rng.nextDouble() < 0.65;
          }
        }

        if (wantAccept) {
          return {'type': 'accept'};
        }

        // Wants to avoid accepting: if locked, try 'counter' or 'transfer'
        if (!canPass(seat)) {
          final cntIdx = myHand.indexWhere((c) => c.action == 'counter');
          if (cntIdx >= 0 && locked.contains(seat)) {
            return {'type': 'use_card', 'index': cntIdx};
          }
          final trfIdx = myHand.indexWhere((c) => c.action == 'transfer' || c.action == 'intercept');
          if (trfIdx >= 0 && others.isNotEmpty) {
            return {'type': 'use_card', 'index': trfIdx, 'target': others.first};
          }
          return {'type': 'accept'};
        }

        return {'type': 'pass'};

      default:
        return null;
    }
  }
}
