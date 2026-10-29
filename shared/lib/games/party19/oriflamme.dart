import '../../src/engine.dart';

class OriflammeGame extends GameEngine {
  OriflammeGame(super.setup);

  static const List<Map<String, Object>> cardDefs = [
    {
      'id': 0,
      'name': '弓箭手',
      'emoji': '🏹',
      'desc': '射杀队列最左端或最右端的 1 张牌（+1 VP）',
    },
    {
      'id': 1,
      'name': '刺客',
      'emoji': '🗡️',
      'desc': '刺杀队列中任意位置的 1 张牌（+1 VP）',
    },
    {
      'id': 2,
      'name': '皇室密令',
      'emoji': '👑',
      'desc': '立即获得 +2 VP，并将本牌移出队列',
    },
    {
      'id': 3,
      'name': '领主',
      'emoji': '🏰',
      'desc': '获得 +1 VP，每有 1 张相邻己方卡牌额外 +1 VP',
    },
    {
      'id': 4,
      'name': '间谍',
      'emoji': '🕵️',
      'desc': '从相邻卡牌拥有者处窃取 1 VP',
    },
    {
      'id': 5,
      'name': '士兵',
      'emoji': '⚔️',
      'desc': '斩杀相邻（左或右）的 1 张牌（+1 VP）',
    },
    {
      'id': 6,
      'name': '伏击',
      'emoji': '💣',
      'desc': '暗置被杀时反杀攻击者并获 +4 VP；主动翻开获 +1 VP',
    },
  ];

  int totalRounds = 6;
  int round = 1;
  int firstPlayer = 0;
  int placedCount = 0;
  int turn = 0;
  int resolveIdx = 0;
  String phase = 'place'; // 'place' | 'resolve' | 'over'

  /// Each player's hand of Intrigue Card IDs (0..6).
  late List<List<int>> hands;

  /// Central Intrigue Queue: each item is {'owner': int, 'card': int, 'revealed': bool, 'tokens': int}.
  late List<Map<String, dynamic>> queue;

  /// Player influence (VP) scores.
  late List<int> scores;

  String lastEvent = '王权烈焰开启！请按顺位将 1 张权谋卡暗置放入队列左端或右端！';

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

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    totalRounds = mode == 'fast' ? 4 : 6;
    round = 1;
    firstPlayer = 0;
    placedCount = 0;
    turn = 0;
    resolveIdx = 0;
    phase = 'place';

    hands = [
      for (var s = 0; s < players; s++) <int>[0, 1, 2, 3, 4, 5, 6],
    ];
    queue = <Map<String, dynamic>>[];
    scores = List<int>.filled(players, 1); // Each family starts with 1 Influence VP

    lastEvent = '第 1/$totalRounds 轮【暗置入列阶段】：请 ${name(turn)} 选择 1 张手牌暗置放入队列左端或右端！';
    host.log('【王权烈焰】法国年度游戏大奖权谋名作开启！暗置堆叠阴谋或翻开引爆技能！');
  }

  String cardLabel(int c) {
    if (c < 0 || c >= cardDefs.length) return '❓暗置卡';
    return '${cardDefs[c]['emoji']}${cardDefs[c]['name']}';
  }

  /// Legal target indices in `queue` when activating card `c` at `idx`.
  List<int> validTargetsFor(int idx, int c) {
    final len = queue.length;
    if (idx < 0 || idx >= len) return const <int>[];
    switch (c) {
      case 0: // 🏹 弓箭手: first or last card in queue
        final set = <int>{0, len - 1};
        if (len > 1) set.remove(idx);
        final list = set.toList()..sort();
        return list;
      case 1: // 🗡️ 刺客: any other card in queue
        return [
          for (var i = 0; i < len; i++)
            if (i != idx) i,
        ];
      case 4: // 🕵️ 间谍: adjacent card
      case 5: // ⚔️ 士兵: adjacent card
        return [
          if (idx - 1 >= 0) idx - 1,
          if (idx + 1 < len) idx + 1,
        ];
      default:
        return const <int>[];
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'place':
        _handlePlace(seat, action);
        break;
      case 'keep_hidden':
        _handleKeepHidden(seat);
        break;
      case 'reveal':
        _handleReveal(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handlePlace(int seat, Map<String, dynamic> action) {
    if (phase != 'place') throw GameError('当前不是暗置入列阶段');
    final c = asInt(action['card'], -1);
    final pos = asStr(action['pos'], 'right');
    if (!hands[seat].contains(c)) {
      throw GameError('你手中没有这张权谋卡');
    }
    if (pos != 'left' && pos != 'right') {
      throw GameError('入列位置必须是 left 或 right');
    }

    hands[seat].remove(c);
    final entry = <String, dynamic>{
      'owner': seat,
      'card': c,
      'revealed': false,
      'tokens': 0,
    };

    if (pos == 'left') {
      queue.insert(0, entry);
    } else {
      queue.add(entry);
    }

    placedCount++;
    final posLabel = pos == 'left' ? '⬅️队列左端' : '➡️队列右端';

    if (placedCount >= players) {
      phase = 'resolve';
      resolveIdx = 0;
      turn = queue[0]['owner'] as int;
      lastEvent =
          '🎴 ${name(seat)} 将卡牌暗置放入$posLabel。入列完毕，进入从左至右结算阶段！请 ${name(turn)} 结算第 1 张牌！';
      host.log(lastEvent);
    } else {
      turn = (turn + 1) % players;
      lastEvent = '🎴 ${name(seat)} 将 1 张权谋卡暗置放入$posLabel（当前队列共 ${queue.length} 张牌）。';
      host.log(lastEvent);
    }
  }

  void _handleKeepHidden(int seat) {
    if (phase != 'resolve') throw GameError('当前不是队列结算阶段');
    if (resolveIdx < 0 || resolveIdx >= queue.length) {
      throw GameError('队列索引无效');
    }
    final item = queue[resolveIdx];
    if (item['owner'] != seat) {
      throw GameError('这张卡牌不属于你');
    }

    final newTokens = (item['tokens'] as int) + 1;
    item['tokens'] = newTokens;
    lastEvent = '🤫 ${name(seat)} 保持队列第 ${resolveIdx + 1} 张牌暗置，在牌上叠加 +1 权谋指示物（现存 $newTokens 枚）！';
    host.log(lastEvent);

    resolveIdx++;
    _advanceResolveOrRound();
  }

  void _handleReveal(int seat, Map<String, dynamic> action) {
    if (phase != 'resolve') throw GameError('当前不是队列结算阶段');
    if (resolveIdx < 0 || resolveIdx >= queue.length) {
      throw GameError('队列索引无效');
    }
    final item = queue[resolveIdx];
    if (item['owner'] != seat) {
      throw GameError('这张卡牌不属于你');
    }

    final cardId = item['card'] as int;
    final stackedTokens = item['tokens'] as int;
    item['revealed'] = true;
    item['tokens'] = 0;
    if (stackedTokens > 0) {
      scores[seat] += stackedTokens;
    }

    final validTargets = validTargetsFor(resolveIdx, cardId);
    var targetIdx = asInt(action['targetIdx'], -1);
    if (validTargets.isNotEmpty) {
      if (action.containsKey('targetIdx') && targetIdx != -1) {
        if (!validTargets.contains(targetIdx)) {
          throw GameError('目标位置无法被【${cardLabel(cardId)}】指定');
        }
      } else {
        // Default to first enemy target, or first valid target
        targetIdx = validTargets.firstWhere(
          (idx) => queue[idx]['owner'] != seat,
          orElse: () => validTargets.first,
        );
      }
    }

    final tokenMsg = stackedTokens > 0 ? '（收走牌上 $stackedTokens 分）' : '';

    switch (cardId) {
      case 0: // 🏹 弓箭手
      case 1: // 🗡️ 刺客
      case 5: // ⚔️ 士兵
        if (targetIdx >= 0 && targetIdx < queue.length && targetIdx != resolveIdx) {
          _executeKill(seat, cardId, targetIdx, tokenMsg);
        } else {
          lastEvent = '🔥 ${name(seat)} 翻开【${cardLabel(cardId)}】$tokenMsg，但场上无有效击杀目标。';
          host.log(lastEvent);
          resolveIdx++;
        }
        break;

      case 2: // 👑 皇室密令: +2 VP & discard self from queue
        scores[seat] += 2;
        queue.removeAt(resolveIdx);
        lastEvent = '👑 ${name(seat)} 翻开【皇室密令】$tokenMsg，宣读诏书获得 +2 VP 并功成身退！';
        host.log(lastEvent);
        // Since queue[resolveIdx] was removed, resolveIdx already points to the next card!
        break;

      case 3: // 🏰 领主: +1 VP + 1 per adjacent friendly card
        var gain = 1;
        if (resolveIdx - 1 >= 0 && queue[resolveIdx - 1]['owner'] == seat) {
          gain++;
        }
        if (resolveIdx + 1 < queue.length && queue[resolveIdx + 1]['owner'] == seat) {
          gain++;
        }
        scores[seat] += gain;
        lastEvent = '🏰 ${name(seat)} 翻开【领主】$tokenMsg，凭借相邻家族势力共获得 +$gain VP！';
        host.log(lastEvent);
        resolveIdx++;
        break;

      case 4: // 🕵️ 间谍: steal 1 VP from adjacent card owner
        if (targetIdx >= 0 && targetIdx < queue.length) {
          final victim = queue[targetIdx]['owner'] as int;
          if (victim != seat && scores[victim] > 0) {
            scores[victim]--;
          }
          scores[seat]++;
          lastEvent = '🕵️ ${name(seat)} 翻开【间谍】$tokenMsg，从 ${name(victim)} 处窃取 1 VP！';
        } else {
          scores[seat]++;
          lastEvent = '🕵️ ${name(seat)} 翻开【间谍】$tokenMsg，秘密收集情报获得 +1 VP！';
        }
        host.log(lastEvent);
        resolveIdx++;
        break;

      case 6: // 💣 伏击: voluntary reveal gives +1 VP
        scores[seat] += 1;
        lastEvent = '💣 ${name(seat)} 主动解除【伏击】$tokenMsg，获得 +1 VP！';
        host.log(lastEvent);
        resolveIdx++;
        break;
    }

    _advanceResolveOrRound();
  }

  void _executeKill(int attackerSeat, int attackerCard, int targetIdx, String tokenMsg) {
    final targetItem = queue[targetIdx];
    final targetOwner = targetItem['owner'] as int;
    final targetCard = targetItem['card'] as int;
    final targetRevealed = targetItem['revealed'] == true;
    final targetTokens = targetItem['tokens'] as int;

    // Check 💣 Ambush (card 6) counter-kill when attacked while face-down!
    if (!targetRevealed && targetCard == 6) {
      scores[targetOwner] += 4 + targetTokens;
      // Remove both the attacker and the triggered Ambush (or remove attacker at resolveIdx and reveal/remove Ambush)
      final highIdx = resolveIdx > targetIdx ? resolveIdx : targetIdx;
      final lowIdx = resolveIdx < targetIdx ? resolveIdx : targetIdx;
      queue.removeAt(highIdx);
      queue.removeAt(lowIdx);
      if (targetIdx < resolveIdx) {
        resolveIdx--;
      }
      lastEvent =
          '💣 惊天伏击！${name(attackerSeat)} 的【${cardLabel(attackerCard)}】$tokenMsg 刺向第 ${targetIdx + 1} 张暗牌，却触发 ${name(targetOwner)} 的【💣伏击】反杀攻击者并斩获 +${4 + targetTokens} VP！';
      host.log(lastEvent);
      return;
    }

    // Normal kill: attacker gains +1 VP, target card is removed from queue
    scores[attackerSeat] += 1;
    queue.removeAt(targetIdx);
    if (targetIdx < resolveIdx) {
      // Because an earlier card was removed, our current card shifted left by 1,
      // so moving to the card after our current card keeps resolveIdx at the same numerical value!
    } else {
      resolveIdx++;
    }
    lastEvent =
        '⚔️ ${name(attackerSeat)} 翻开【${cardLabel(attackerCard)}】$tokenMsg，击杀 ${name(targetOwner)} 的【${cardLabel(targetCard)}】获得 +1 VP！';
    host.log(lastEvent);
  }

  void _advanceResolveOrRound() {
    if (resolveIdx < queue.length) {
      turn = queue[resolveIdx]['owner'] as int;
      return;
    }

    // Current round's resolve phase is complete!
    if (round < totalRounds) {
      round++;
      firstPlayer = (firstPlayer + 1) % players;
      turn = firstPlayer;
      placedCount = 0;
      resolveIdx = 0;
      phase = 'place';
      // Refill any empty hand just in case
      for (var s = 0; s < players; s++) {
        if (hands[s].isEmpty) {
          hands[s] = <int>[0, 1, 2, 3, 4, 5, 6];
        }
      }
      lastEvent = '$lastEvent · 🔄 进入第 $round/$totalRounds 轮【暗置入列阶段】，轮到 ${name(turn)} 行动！';
    } else {
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent = '🏆 王权烈焰 6 轮权谋终局！${name(bestSeat)} 以 ${scores[bestSeat]} 点王权影响力登基加冕！';
      host.log(lastEvent);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    final revealAll = phase == 'over';

    final maskedQueue = <Map<String, dynamic>>[
      for (var i = 0; i < queue.length; i++)
        {
          'idx': i,
          'owner': queue[i]['owner'] as int,
          'revealed': queue[i]['revealed'] == true,
          'tokens': queue[i]['tokens'] as int,
          // Strictly hide face-down cards owned by other players!
          'card': (revealAll || queue[i]['revealed'] == true || queue[i]['owner'] == seat)
              ? (queue[i]['card'] as int)
              : -1,
        },
    ];

    List<int> activeValidTargets = const <int>[];
    if (phase == 'resolve' &&
        validPlayer &&
        seat == turn &&
        resolveIdx >= 0 &&
        resolveIdx < queue.length) {
      activeValidTargets = validTargetsFor(resolveIdx, queue[resolveIdx]['card'] as int);
    }

    return {
      'round': round,
      'totalRounds': totalRounds,
      'turn': turn,
      'phase': phase,
      'resolveIdx': resolveIdx,
      'cardDefs': cardDefs,
      'myHand': validPlayer ? List<int>.of(hands[seat]) : const <int>[],
      'handCounts': [
        for (var s = 0; s < players; s++) hands[s].length,
      ],
      'queue': maskedQueue,
      'validTargets': activeValidTargets,
      'scores': List<int>.of(scores),
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'place') {
      final myHand = hands[seat];
      if (myHand.isEmpty) return null;
      final card = myHand[rng.nextInt(myHand.length)];
      final pos = rng.nextBool() ? 'left' : 'right';
      return {'type': 'place', 'card': card, 'pos': pos};
    }

    if (phase == 'resolve') {
      if (resolveIdx < 0 || resolveIdx >= queue.length) return null;
      final item = queue[resolveIdx];
      final card = item['card'] as int;
      final revealed = item['revealed'] == true;
      final tokens = item['tokens'] as int;

      // Ambush (6): keep hidden unless it's the final round or has many tokens!
      if (!revealed && card == 6 && round < totalRounds && tokens < 2) {
        return {'type': 'keep_hidden'};
      }

      // If not yet revealed and no tokens, sometimes accumulate 1 token first
      if (!revealed && tokens == 0 && round < totalRounds && card == 2 && rng.nextBool()) {
        return {'type': 'keep_hidden'};
      }

      final targets = validTargetsFor(resolveIdx, card);
      if (targets.isNotEmpty) {
        final enemyTargets = targets.where((idx) => queue[idx]['owner'] != seat).toList();
        if (enemyTargets.isEmpty && (card == 0 || card == 1 || card == 5)) {
          // Avoid killing own cards! Keep hidden instead
          return {'type': 'keep_hidden'};
        }
        final pick = enemyTargets.isNotEmpty ? enemyTargets.first : targets.first;
        return {'type': 'reveal', 'targetIdx': pick};
      }

      return {'type': 'reveal'};
    }

    return null;
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    lastEvent = '${name(seat)} 放弃王权争夺，游戏结束！';
    host.log(lastEvent);
  }
}
