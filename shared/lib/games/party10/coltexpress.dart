import 'dart:math';

import '../../src/engine.dart';

const List<String> kColtStarterDeck = [
  'move',
  'move',
  'climb',
  'climb',
  'punch',
  'shoot',
  'shoot',
  'rob',
  'rob',
  'marshal',
];

const Map<String, String> kColtCardNames = {
  'move': '移动',
  'climb': '攀爬',
  'punch': '出拳',
  'shoot': '开枪',
  'rob': '抢劫',
  'marshal': '警长',
  'bullet': '中弹(废牌)',
};

const List<String> kBanditNames = [
  '鬼影杰克',
  '红发贝尔',
  '独眼图科',
  '快枪多克',
  '狂风夏延',
  '铁腕Django',
];

class ColtExpressGame extends GameEngine {
  ColtExpressGame(super.setup);

  late int maxRounds;
  int round = 1;
  String phase = 'scheming'; // 'scheming' | 'stealin'
  bool over = false;

  /// Pattern of tunnel turns for the current round (true = face-down tunnel turn).
  late List<bool> roundTunnels;
  int schemeStep = 0; // 0..(roundTunnels.length * players - 1)
  int turn = 0;

  /// Bandit positions: car index (0 = Locomotive .. players-1 = Caboose) and roof flag.
  late List<int> carPos;
  late List<bool> onRoof;

  /// Marshal car index (always inside: roof = false).
  int marshalCar = 0;

  /// Loot on each car: insideLoot[car] and roofLoot[car], each a list of
  /// {'type': 'bag'|'gem'|'strongbox', 'value': int}.
  late List<List<Map<String, dynamic>>> insideLoot;
  late List<List<Map<String, dynamic>>> roofLoot;

  /// Loot collected by each player seat.
  late List<List<Map<String, dynamic>>> playerLoot;

  /// Card decks, hands, and discards per player.
  late List<List<String>> decks;
  late List<List<String>> hands;
  late List<List<String>> discards;

  /// Remaining bullets in cylinder (starts at 6) and shots fired count.
  late List<int> bulletsLeft;
  late List<int> shotsFired;
  late List<int> wounds;
  late List<int> gunslingerBonus;

  /// Shared action program stack for the round:
  /// {'seat': int, 'card': String, 'faceUp': bool, 'resolved': bool, 'summary': String?}
  final List<Map<String, dynamic>> programStack = [];
  int execIndex = 0;

  /// Action log of the current/last stealin' phase for display.
  final List<String> actionFeed = [];

  bool get isTunnelTurn =>
      phase == 'scheming' &&
      roundTunnels.isNotEmpty &&
      (schemeStep ~/ players) < roundTunnels.length &&
      roundTunnels[schemeStep ~/ players];

  int get schemeTurnIndex => schemeStep ~/ players;
  int get totalSchemeTurns => roundTunnels.length;

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 4);
    round = 1;
    over = false;

    carPos = List.generate(
      players,
      (s) => s.isEven ? players - 1 : max(1, players - 2),
    );
    onRoof = List.filled(players, false);
    marshalCar = 0;

    insideLoot = List.generate(players, (c) {
      if (c == 0) {
        return [
          {'type': 'strongbox', 'value': 1000},
          {'type': 'bag', 'value': 350},
        ];
      }
      final items = <Map<String, dynamic>>[
        {'type': 'bag', 'value': 250 + (rng.nextInt(6) * 50)},
        {'type': 'bag', 'value': 300 + (rng.nextInt(5) * 50)},
      ];
      if (c <= 2 || c == players - 1) {
        items.add({'type': 'gem', 'value': 500});
      }
      return items;
    });
    roofLoot = List.generate(players, (_) => <Map<String, dynamic>>[]);

    playerLoot = List.generate(
      players,
      (_) => [
        {'type': 'bag', 'value': 250},
      ],
    );

    decks = List.generate(players, (_) => <String>[]);
    hands = List.generate(players, (_) => <String>[]);
    discards = List.generate(
      players,
      (_) => List<String>.of(kColtStarterDeck),
    );

    bulletsLeft = List.filled(players, 6);
    shotsFired = List.filled(players, 0);
    wounds = List.filled(players, 0);
    gunslingerBonus = List.filled(players, 0);

    _startRound();
    host.log('疯狂快车发车！共 $players 节车厢，警长守在 0 号火车头守护 \$1000 钱箱！');
  }

  void _startRound() {
    phase = 'scheming';
    programStack.clear();
    execIndex = 0;
    schemeStep = 0;
    turn = (round - 1) % players;

    // 4 turns on standard rounds: normal, tunnel, normal, normal (last round ends with tunnel).
    roundTunnels = round == maxRounds
        ? [false, true, false, true]
        : [false, true, false, false];

    for (var s = 0; s < players; s++) {
      final allCards = <String>[
        ...decks[s],
        ...hands[s],
        ...discards[s],
      ];
      decks[s] = shuffled(allCards, rng);
      hands[s] = [];
      discards[s] = [];
      _drawCards(s, 6);
    }
  }

  void _drawCards(int seat, int count) {
    for (var i = 0; i < count; i++) {
      if (decks[seat].isEmpty) break;
      hands[seat].add(decks[seat].removeLast());
    }
  }

  List<Map<String, dynamic>> lootAt(int car, bool roof) =>
      roof ? roofLoot[car] : insideLoot[car];

  int lootScore(int seat) =>
      playerLoot[seat].fold<int>(0, (sum, it) => sum + (it['value'] as int));

  int totalScore(int seat) => lootScore(seat) + gunslingerBonus[seat];

  List<int> validMoveCars(int seat) {
    final c = carPos[seat];
    final maxStep = onRoof[seat] ? 3 : 1;
    return [
      for (var target = 0; target < players; target++)
        if (target != c && (target - c).abs() <= maxStep) target,
    ];
  }

  List<int> validMarshalCars() => [
        for (var target = 0; target < players; target++)
          if ((target - marshalCar).abs() == 1) target,
      ];

  List<int> validPunchTargets(int seat) => [
        for (var s = 0; s < players; s++)
          if (s != seat &&
              carPos[s] == carPos[seat] &&
              onRoof[s] == onRoof[seat])
            s,
      ];

  List<int> validShootTargets(int seat) {
    if (bulletsLeft[seat] <= 0) return const [];
    final myCar = carPos[seat];
    final myRoof = onRoof[seat];
    if (!myRoof) {
      // Inside: shoot bandits inside an adjacent car.
      return [
        for (var s = 0; s < players; s++)
          if (s != seat && !onRoof[s] && (carPos[s] - myCar).abs() == 1) s,
      ];
    } else {
      // On roof: line of sight in both directions (closest car with roof bandits in each direction).
      final targets = <int>[];
      // Look forward (towards locomotive 0).
      for (var c = myCar - 1; c >= 0; c--) {
        final inCar = [
          for (var s = 0; s < players; s++)
            if (s != seat && onRoof[s] && carPos[s] == c) s,
        ];
        if (inCar.isNotEmpty) {
          targets.addAll(inCar);
          break;
        }
      }
      // Look backward (towards caboose).
      for (var c = myCar + 1; c < players; c++) {
        final inCar = [
          for (var s = 0; s < players; s++)
            if (s != seat && onRoof[s] && carPos[s] == c) s,
        ];
        if (inCar.isNotEmpty) {
          targets.addAll(inCar);
          break;
        }
      }
      return targets;
    }
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前还没轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'scheming') {
      if (type == 'draw') {
        _drawCards(seat, 3);
        host.log('${name(seat)} 补充了 3 张手牌');
        _advanceScheming();
        return;
      }
      if (type == 'play') {
        var idx = asInt(action['index'], -1);
        final cardName = asStr(action['card']);
        if (idx < 0 && cardName.isNotEmpty) {
          idx = hands[seat].indexOf(cardName);
        }
        if (idx < 0 || idx >= hands[seat].length) {
          throw GameError('请选择有效的手牌');
        }
        final card = hands[seat][idx];
        if (card == 'bullet') {
          throw GameError('中弹伤害卡是废牌，无法打出！');
        }
        hands[seat].removeAt(idx);
        final faceUp = !isTunnelTurn;
        programStack.add({
          'seat': seat,
          'card': card,
          'faceUp': faceUp,
          'resolved': false,
          'summary': null,
        });
        if (faceUp) {
          host.log('${name(seat)} 编入了行动卡【${kColtCardNames[card] ?? card}】');
        } else {
          host.log('${name(seat)} 在隧道中暗置了 1 张行动卡');
        }
        _advanceScheming();
        return;
      }
      throw GameError('编程阶段请打出行动卡(play)或抽牌(draw)');
    }

    if (phase == 'stealin') {
      if (type != 'resolve' &&
          type != 'step' &&
          !kColtCardNames.containsKey(type)) {
        throw GameError('执行阶段请确认执行当前行动(resolve)');
      }
      final targetCar =
          action.containsKey('targetCar') ? asInt(action['targetCar']) : null;
      final targetSeat =
          action.containsKey('targetSeat') ? asInt(action['targetSeat']) : null;
      resolveCurrentCard(targetCar: targetCar, targetSeat: targetSeat);
      return;
    }

    throw GameError('未知阶段: $phase');
  }

  void _advanceScheming() {
    schemeStep++;
    if (schemeStep >= roundTunnels.length * players) {
      if (programStack.isEmpty) {
        _endRound();
        return;
      }
      phase = 'stealin';
      execIndex = 0;
      actionFeed.clear();
      turn = programStack[0]['seat'] as int;
      host.log('第 $round 轮进入【执行阶段】，按序结算 ${programStack.length} 张行动卡！');
      return;
    }
    final roundStart = (round - 1) % players;
    turn = (roundStart + (schemeStep % players)) % players;
  }

  /// Resolves `programStack[execIndex]` and advances `execIndex`.
  void resolveCurrentCard({int? targetCar, int? targetSeat}) {
    if (phase != 'stealin' || execIndex >= programStack.length) return;
    final entry = programStack[execIndex];
    final actor = entry['seat'] as int;
    final card = entry['card'] as String;
    entry['faceUp'] = true;
    entry['resolved'] = true;
    discards[actor].add(card);

    String summary;
    switch (card) {
      case 'climb':
        onRoof[actor] = !onRoof[actor];
        summary =
            '${name(actor)} ${onRoof[actor] ? "爬上了车顶" : "钻进了车厢内部"}（${carPos[actor]}号车）';
        if (!onRoof[actor] && carPos[actor] == marshalCar) {
          _applyMarshalEncounter(actor);
          summary += '，撞见警长中弹逃回车顶！';
        }
        break;

      case 'move':
        final validCars = validMoveCars(actor);
        if (validCars.isEmpty) {
          summary = '${name(actor)} 无法移动';
        } else {
          final chosen = (targetCar != null && validCars.contains(targetCar))
              ? targetCar
              : _bestMoveTarget(actor, validCars);
          carPos[actor] = chosen;
          summary =
              '${name(actor)} 移动到了 $chosen 号车${onRoof[actor] ? "车顶" : "车厢内"}';
          if (!onRoof[actor] && carPos[actor] == marshalCar) {
            _applyMarshalEncounter(actor);
            summary += '，遭遇警长中弹被赶上车顶！';
          }
        }
        break;

      case 'marshal':
        final validCars = validMarshalCars();
        final chosen = (targetCar != null && validCars.contains(targetCar))
            ? targetCar
            : _bestMarshalTarget(actor, validCars);
        marshalCar = chosen;
        summary = '${name(actor)} 将警长移动到了 $marshalCar 号车厢';
        final caught = <String>[];
        for (var s = 0; s < players; s++) {
          if (!onRoof[s] && carPos[s] == marshalCar) {
            _applyMarshalEncounter(s);
            caught.add(name(s));
          }
        }
        if (caught.isNotEmpty) {
          summary += '，警长开枪击伤了 ${caught.join("、")} 并将其赶上车顶！';
        }
        break;

      case 'rob':
        final pile = lootAt(carPos[actor], onRoof[actor]);
        if (pile.isEmpty) {
          summary = '${name(actor)} 试图抢劫，但当前位置空无一物！';
        } else {
          // Pick highest-value item at location.
          var bestIdx = 0;
          for (var i = 1; i < pile.length; i++) {
            if ((pile[i]['value'] as int) > (pile[bestIdx]['value'] as int)) {
              bestIdx = i;
            }
          }
          final item = pile.removeAt(bestIdx);
          playerLoot[actor].add(item);
          final label = _lootLabel(item['type'] as String);
          summary = '${name(actor)} 拾取了 $label（\$${item['value']}）！';
        }
        break;

      case 'punch':
        final targets = validPunchTargets(actor);
        if (targets.isEmpty) {
          summary = '${name(actor)} 挥出一拳，但同位置没有其他强盗！';
        } else {
          final victim = (targetSeat != null && targets.contains(targetSeat))
              ? targetSeat
              : targets.first;
          String dropText = '';
          if (playerLoot[victim].isNotEmpty) {
            // Drop highest value item.
            playerLoot[victim].sort(
              (a, b) => (a['value'] as int).compareTo(b['value'] as int),
            );
            final dropped = playerLoot[victim].removeLast();
            lootAt(carPos[victim], onRoof[victim]).add(dropped);
            dropText = '，打落了 ${_lootLabel(dropped['type'] as String)}（\$${dropped['value']}）';
          }
          final adj = [
            if (carPos[victim] + 1 < players) carPos[victim] + 1,
            if (carPos[victim] - 1 >= 0) carPos[victim] - 1,
          ];
          final dest = (targetCar != null && adj.contains(targetCar))
              ? targetCar
              : (adj.isNotEmpty ? adj.first : carPos[victim]);
          carPos[victim] = dest;
          summary =
              '${name(actor)} 一拳将 ${name(victim)} 击飞到 $dest 号车$dropText！';
          if (!onRoof[victim] && carPos[victim] == marshalCar) {
            _applyMarshalEncounter(victim);
            summary += ' ${name(victim)} 撞上警长再吃一枪逃上车顶！';
          }
        }
        break;

      case 'shoot':
        final targets = validShootTargets(actor);
        if (bulletsLeft[actor] <= 0) {
          summary = '${name(actor)} 扣动扳机，但左轮手枪已空！';
        } else if (targets.isEmpty) {
          summary = '${name(actor)} 拔枪四顾，但射程内没有目标！';
        } else {
          final victim = (targetSeat != null && targets.contains(targetSeat))
              ? targetSeat
              : targets.first;
          bulletsLeft[actor]--;
          shotsFired[actor]++;
          wounds[victim]++;
          discards[victim].add('bullet');
          summary =
              '${name(actor)} 开枪击中了 ${name(victim)}，塞入 1 张子弹伤害卡！';
        }
        break;

      default:
        summary = '${name(actor)} 执行了 $card';
    }

    entry['summary'] = summary;
    actionFeed.add(summary);
    host.log(summary);

    execIndex++;
    if (execIndex >= programStack.length) {
      _endRound();
    } else {
      turn = programStack[execIndex]['seat'] as int;
    }
  }

  void _applyMarshalEncounter(int seat) {
    wounds[seat]++;
    discards[seat].add('bullet');
    onRoof[seat] = true;
  }

  int _bestMoveTarget(int seat, List<int> validCars) {
    // Prefer moving toward car 0 (Locomotive) or a car with loot and no Marshal.
    var bestCar = validCars.first;
    var bestVal = -9999.0;
    for (final c in validCars) {
      final loot = lootAt(c, onRoof[seat]);
      final lootSum = loot.fold<int>(0, (s, e) => s + (e['value'] as int));
      var val = lootSum * 0.01 - c * 1.5;
      if (!onRoof[seat] && c == marshalCar) val -= 50;
      if (val > bestVal) {
        bestVal = val;
        bestCar = c;
      }
    }
    return bestCar;
  }

  int _bestMarshalTarget(int actor, List<int> validCars) {
    var bestCar = validCars.first;
    var bestVal = -9999;
    for (final c in validCars) {
      var val = 0;
      for (var s = 0; s < players; s++) {
        if (!onRoof[s] && carPos[s] == c) {
          val += (s == actor) ? -10 : 5;
        }
      }
      if (val > bestVal) {
        bestVal = val;
        bestCar = c;
      }
    }
    return bestCar;
  }

  String _lootLabel(String type) {
    switch (type) {
      case 'strongbox':
        return '列车钱箱';
      case 'gem':
        return '红宝石';
      default:
        return '钱袋';
    }
  }

  void _endRound() {
    if (round >= maxRounds) {
      over = true;
      final maxShots = shotsFired.fold<int>(0, max);
      if (maxShots > 0) {
        final winners = <String>[];
        for (var s = 0; s < players; s++) {
          if (shotsFired[s] == maxShots) {
            gunslingerBonus[s] = 1000;
            winners.add(name(s));
          }
        }
        host.log('神枪手奖（\$1000）授予射出 $maxShots 发子弹的：${winners.join("、")}！');
      }
      final scores = [for (var s = 0; s < players; s++) totalScore(s)];
      final best = scores.reduce(max);
      final champs = [
        for (var s = 0; s < players; s++)
          if (scores[s] == best) name(s),
      ];
      host.log('疯狂快车劫案结束！最高赏金 \$best，赢家：${champs.join("、")}！');
      return;
    }

    round++;
    _startRound();
    host.log('进入第 $round 轮【编程阶段】！');
  }

  @override
  Map<String, dynamic> view(int seat) {
    final visibleStack = [
      for (var i = 0; i < programStack.length; i++)
        () {
          final e = programStack[i];
          final owner = e['seat'] as int;
          final faceUp = e['faceUp'] == true;
          final resolved = e['resolved'] == true;
          final canSee = over ||
              faceUp ||
              resolved ||
              seat == owner ||
              (phase == 'stealin' && i <= execIndex);
          return {
            'index': i,
            'seat': owner,
            'card': canSee ? e['card'] : 'hidden',
            'faceUp': faceUp,
            'resolved': resolved,
            'summary': e['summary'],
          };
        }(),
    ];

    Map<String, dynamic>? pendingAction;
    if (phase == 'stealin' && !over && execIndex < programStack.length) {
      final entry = programStack[execIndex];
      final actor = entry['seat'] as int;
      final card = entry['card'] as String;
      pendingAction = {
        'index': execIndex,
        'seat': actor,
        'card': card,
        'validMoveCars': card == 'move'
            ? validMoveCars(actor)
            : (card == 'marshal' ? validMarshalCars() : const <int>[]),
        'validTargets': card == 'punch'
            ? validPunchTargets(actor)
            : (card == 'shoot' ? validShootTargets(actor) : const <int>[]),
      };
    }

    return {
      'round': round,
      'maxRounds': maxRounds,
      'phase': phase,
      'turn': turn,
      'over': over,
      'isTunnelTurn': isTunnelTurn,
      'schemeTurnIndex': schemeTurnIndex,
      'totalSchemeTurns': totalSchemeTurns,
      'roundTunnels': roundTunnels,
      'marshalCar': marshalCar,
      'carPos': List<int>.of(carPos),
      'onRoof': List<bool>.of(onRoof),
      'insideLoot': [
        for (var c = 0; c < players; c++)
          [for (final it in insideLoot[c]) Map<String, dynamic>.of(it)],
      ],
      'roofLoot': [
        for (var c = 0; c < players; c++)
          [for (final it in roofLoot[c]) Map<String, dynamic>.of(it)],
      ],
      'playerLootCount': [
        for (var s = 0; s < players; s++) playerLoot[s].length,
      ],
      'lootScores': [for (var s = 0; s < players; s++) lootScore(s)],
      'gunslingerBonus': List<int>.of(gunslingerBonus),
      'scores': [for (var s = 0; s < players; s++) totalScore(s)],
      'bulletsLeft': List<int>.of(bulletsLeft),
      'shotsFired': List<int>.of(shotsFired),
      'wounds': List<int>.of(wounds),
      'hand': (seat >= 0 && seat < players)
          ? List<String>.of(hands[seat])
          : const <String>[],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'deckCounts': [for (var s = 0; s < players; s++) decks[s].length],
      'programStack': visibleStack,
      'execIndex': execIndex,
      'pendingAction': pendingAction,
      'actionFeed': List<String>.of(actionFeed),
      'banditNames': [
        for (var s = 0; s < players; s++)
          kBanditNames[s % kBanditNames.length],
      ],
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings =>
      over ? rankByScore([for (var s = 0; s < players; s++) totalScore(s)]) : null;

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'stealin') {
      final entry = programStack[execIndex];
      final card = entry['card'] as String;
      if (card == 'move') {
        final cars = validMoveCars(seat);
        return {
          'type': 'resolve',
          if (cars.isNotEmpty) 'targetCar': _bestMoveTarget(seat, cars),
        };
      }
      if (card == 'marshal') {
        final cars = validMarshalCars();
        return {
          'type': 'resolve',
          if (cars.isNotEmpty) 'targetCar': _bestMarshalTarget(seat, cars),
        };
      }
      if (card == 'punch') {
        final targets = validPunchTargets(seat);
        return {
          'type': 'resolve',
          if (targets.isNotEmpty) 'targetSeat': targets.first,
        };
      }
      if (card == 'shoot') {
        final targets = validShootTargets(seat);
        return {
          'type': 'resolve',
          if (targets.isNotEmpty) 'targetSeat': targets.first,
        };
      }
      return {'type': 'resolve'};
    }

    // Phase == 'scheming'
    final hand = hands[seat];
    final playableIndices = [
      for (var i = 0; i < hand.length; i++)
        if (hand[i] != 'bullet') i,
    ];
    if (playableIndices.isEmpty) {
      return {'type': 'draw'};
    }

    if (botLevel == 0 && rng.nextDouble() < 0.3) {
      return {
        'type': 'play',
        'index': playableIndices[rng.nextInt(playableIndices.length)],
      };
    }

    // Score each card in hand based on current situation.
    var bestIdx = playableIndices.first;
    var bestVal = -999.0;
    final hasLootHere = lootAt(carPos[seat], onRoof[seat]).isNotEmpty;
    final canShootNow = validShootTargets(seat).isNotEmpty;
    final canPunchNow = validPunchTargets(seat).isNotEmpty;

    for (final idx in playableIndices) {
      final c = hand[idx];
      var v = rng.nextDouble() * 0.5;
      if (c == 'rob' && hasLootHere) v += 5.0;
      if (c == 'shoot' && canShootNow && bulletsLeft[seat] > 0) v += 4.5;
      if (c == 'punch' && canPunchNow) v += 4.0;
      if (c == 'move' && !hasLootHere) v += 3.5;
      if (c == 'marshal') v += 2.5;
      if (c == 'climb') v += 2.0;
      if (v > bestVal) {
        bestVal = v;
        bestIdx = idx;
      }
    }

    if (bestVal < 1.5 && decks[seat].isNotEmpty && hand.length <= 3) {
      return {'type': 'draw'};
    }
    return {'type': 'play', 'index': bestIdx};
  }
}
