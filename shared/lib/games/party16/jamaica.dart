import 'dart:math';

import '../../src/engine.dart';

class JamaicaSpace {
  final String name;
  final String type; // 'port', 'food', 'gold', 'lair'
  final int cost;
  const JamaicaSpace(this.name, this.type, this.cost);
}

const List<JamaicaSpace> kJamaicaTrack = [
  JamaicaSpace('⚓ 皇家港 Port Royal', 'port', 0),
  JamaicaSpace('🍞 朗姆酒湾', 'food', 2),
  JamaicaSpace('🪙 金币浅滩', 'gold', 2),
  JamaicaSpace('🏴‍☠️ 骷髅海盗穴', 'lair', 0),
  JamaicaSpace('🍞 椰林暗礁', 'food', 2),
  JamaicaSpace('🪙 沉船金湾', 'gold', 3),
  JamaicaSpace('🏴‍☠️ 黑胡子岩洞', 'lair', 0),
  JamaicaSpace('🍞 补给渔港', 'food', 3),
  JamaicaSpace('🪙 皇家税关', 'gold', 3),
  JamaicaSpace('🏴‍☠️ 幽灵船坞', 'lair', 0),
  JamaicaSpace('🍞 香蕉海湾', 'food', 2),
  JamaicaSpace('🪙 珊瑚金矿', 'gold', 4),
  JamaicaSpace('🏴‍☠️ 魔鬼三角洲', 'lair', 0),
  JamaicaSpace('🍞 甘蔗码头', 'food', 3),
  JamaicaSpace('🪙 黄金走私港', 'gold', 4),
  JamaicaSpace('🏴‍☠️ 血帆要塞', 'lair', 0),
  JamaicaSpace('🍞 风暴海峡', 'food', 3),
  JamaicaSpace('🪙 皇家港外海', 'gold', 3),
];

class JamaicaActionCard {
  final int id;
  final String morning;
  final String evening;
  final String label;
  const JamaicaActionCard(this.id, this.morning, this.evening, this.label);
}

const List<JamaicaActionCard> kJamaicaCards = [
  JamaicaActionCard(0, 'load_gold', 'move_fwd', '☀️装金币 · 🌙扬帆前进'),
  JamaicaActionCard(1, 'load_food', 'move_fwd', '☀️装干粮 · 🌙扬帆前进'),
  JamaicaActionCard(2, 'load_powder', 'move_fwd', '☀️装火药 · 🌙扬帆前进'),
  JamaicaActionCard(3, 'move_fwd', 'move_fwd', '☀️全速前进 · 🌙乘风破浪'),
  JamaicaActionCard(4, 'move_fwd', 'load_gold', '☀️扬帆前进 · 🌙装金币'),
  JamaicaActionCard(5, 'move_fwd', 'load_food', '☀️扬帆前进 · 🌙装干粮'),
  JamaicaActionCard(6, 'move_fwd', 'load_powder', '☀️扬帆前进 · 🌙装火药'),
  JamaicaActionCard(7, 'load_gold', 'load_food', '☀️装金币 · 🌙装干粮'),
  JamaicaActionCard(8, 'move_back', 'load_gold', '☀️战术倒船 · 🌙装金币'),
];

class JamaicaGame extends GameEngine {
  JamaicaGame(super.setup);

  static const int trackLen = 18;

  int round = 1;
  int maxRounds = 10;
  int captain = 0;
  String phase = 'roll'; // 'roll', 'choose', 'combat', 'over'

  List<int> rolledDice = [3, 4];
  int morningVal = 3;
  int eveningVal = 4;

  late List<int> pos; // 0..18 (18 = finished full lap back to Port Royal)
  late List<int> treasures;
  // holds[seat][0..2] -> {'type': 'gold'|'food'|'powder'|'empty', 'amount': 0..6}
  late List<List<Map<String, dynamic>>> holds;
  late List<List<int>> hands; // 3 action card IDs per player

  late List<int?> chosenCard;
  late List<int> chosenHold;
  List<int> _resolveQueue = [];

  // Naval Cannon Combat state
  int? combatAttacker;
  int? combatDefender;
  int? attackerPowder;
  int? defenderPowder;

  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  List<int> get scores => [
        for (var s = 0; s < players; s++)
          min(trackLen, pos[s]) * 2 +
              (pos[s] >= trackLen ? 10 : 0) +
              totalCargo(s, 'gold') * 2 +
              treasures[s] * 4,
      ];

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'roll') return [captain];
    if (phase == 'choose') {
      return [
        for (var s = 0; s < players; s++)
          if (chosenCard[s] == null) s,
      ];
    }
    if (phase == 'combat') {
      return [
        if (combatAttacker != null && attackerPowder == null) combatAttacker!,
        if (combatDefender != null && defenderPowder == null) combatDefender!,
      ];
    }
    return const [];
  }

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    maxRounds = fast ? 7 : 10;
    round = 1;
    captain = 0;
    pos = List<int>.filled(players, 0);
    treasures = List<int>.filled(players, 0);
    holds = [
      for (var s = 0; s < players; s++)
        [
          {'type': 'gold', 'amount': 3},
          {'type': 'food', 'amount': 3},
          {'type': 'powder', 'amount': 2},
        ],
    ];
    hands = [
      for (var s = 0; s < players; s++) [0, 1, 3],
    ];
    chosenCard = List<int?>.filled(players, null);
    chosenHold = List<int>.filled(players, 0);
    _over = false;
    _startRollPhase();
    lastEvent = '🏴‍☠️ 牙买加海盗赛船启航！第 1 轮由船长 ${name(captain)} 分配晨间与暮间行动骰！';
    host.log(lastEvent);
  }

  void _startRollPhase() {
    phase = 'roll';
    rolledDice = [1 + rng.nextInt(6), 1 + rng.nextInt(6)];
    morningVal = rolledDice[0];
    eveningVal = rolledDice[1];
    chosenCard = List<int?>.filled(players, null);
    chosenHold = List<int>.filled(players, 0);
    combatAttacker = null;
    combatDefender = null;
    attackerPowder = null;
    defenderPowder = null;
  }

  int totalCargo(int seat, String type) {
    var sum = 0;
    for (var h = 0; h < 3; h++) {
      if (holds[seat][h]['type'] == type) {
        sum += (holds[seat][h]['amount'] as num).toInt();
      }
    }
    return sum;
  }

  void loadCargo(int seat, String type, int amount, [int? preferredHold]) {
    if (amount <= 0) return;
    final clamped = min(6, amount);
    if (preferredHold != null && preferredHold >= 0 && preferredHold < 3) {
      if (holds[seat][preferredHold]['type'] == type) {
        final cur = (holds[seat][preferredHold]['amount'] as num).toInt();
        holds[seat][preferredHold]['amount'] = min(6, cur + clamped);
      } else {
        holds[seat][preferredHold] = {'type': type, 'amount': clamped};
      }
      return;
    }
    // Find matching hold with space, or empty hold, or smallest hold
    for (var h = 0; h < 3; h++) {
      if (holds[seat][h]['type'] == type) {
        final cur = (holds[seat][h]['amount'] as num).toInt();
        if (cur < 6) {
          holds[seat][h]['amount'] = min(6, cur + clamped);
          return;
        }
      }
    }
    for (var h = 0; h < 3; h++) {
      if (holds[seat][h]['type'] == 'empty' ||
          (holds[seat][h]['amount'] as num).toInt() == 0) {
        holds[seat][h] = {'type': type, 'amount': clamped};
        return;
      }
    }
    holds[seat][0] = {'type': type, 'amount': clamped};
  }

  int spendCargo(int seat, String type, int cost) {
    var rem = cost;
    for (var h = 0; h < 3 && rem > 0; h++) {
      if (holds[seat][h]['type'] == type) {
        final cur = (holds[seat][h]['amount'] as num).toInt();
        final take = min(cur, rem);
        final left = cur - take;
        rem -= take;
        if (left <= 0) {
          holds[seat][h] = {'type': 'empty', 'amount': 0};
        } else {
          holds[seat][h]['amount'] = left;
        }
      }
    }
    return cost - rem;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'roll') {
      if (seat != captain) throw GameError('当前由本轮船长分配晨昏骰子');
      if (type != 'assign_dice') throw GameError('请分配晨昏双骰 (assign_dice)');

      final m = asInt(action['morning'], rolledDice[0]);
      final e = asInt(action['evening'], rolledDice[1]);
      if (m < 1 || m > 6 || e < 1 || e > 6) {
        throw GameError('骰子点数必须在 1~6 之间');
      }
      morningVal = m;
      eveningVal = e;
      phase = 'choose';
      lastEvent =
          '🎲 船长 ${name(captain)} 设定：☀️晨间行动点数 = $morningVal，🌙暮间行动点数 = $eveningVal！请全体船长同时打出行动卡！';
      host.log(lastEvent);
      return;
    }

    if (phase == 'choose') {
      if (chosenCard[seat] != null) throw GameError('你本轮已经选定行动卡');
      if (type != 'play') throw GameError('请打出行动卡 (play)');

      final c = asInt(action['card'], hands[seat].first);
      if (c < 0 || c >= kJamaicaCards.length) {
        throw GameError('无效的行动卡编号');
      }
      final h = asInt(action['hold'], 0).clamp(0, 2);

      chosenCard[seat] = c;
      chosenHold[seat] = h;

      // Replace card in hand
      final idx = hands[seat].indexOf(c);
      final nextCard = (c + 3 + round + seat) % kJamaicaCards.length;
      if (idx >= 0) {
        hands[seat][idx] = nextCard;
      }

      if (waitingFor.isEmpty) {
        _resolveQueue = [for (var i = 0; i < players; i++) (captain + i) % players];
        _processNextInQueue();
      }
      return;
    }

    if (phase == 'combat') {
      if (seat != combatAttacker && seat != combatDefender) {
        throw GameError('你不在本次海战交火双方中');
      }
      if (type != 'combat' && type != 'fire') {
        throw GameError('请投入火药进行海战炮击 (combat)');
      }
      final maxPowder = totalCargo(seat, 'powder');
      final p = asInt(action['powder'], 0);
      if (p < 0 || p > maxPowder) {
        throw GameError('投入火药数量必须在 0~$maxPowder 之间');
      }
      spendCargo(seat, 'powder', p);
      if (seat == combatAttacker) {
        attackerPowder = p;
      } else {
        defenderPowder = p;
      }

      if (attackerPowder != null && defenderPowder != null) {
        _resolveCombat();
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _processNextInQueue() {
    while (_resolveQueue.isNotEmpty) {
      final s = _resolveQueue.removeAt(0);
      final cardId = chosenCard[s] ?? 0;
      final holdIdx = chosenHold[s];
      final card = kJamaicaCards[cardId];

      _applyStep(s, card.morning, morningVal, holdIdx);
      _applyStep(s, card.evening, eveningVal, (holdIdx + 1) % 3);

      // Check landing on another ship -> Naval Cannon Combat!
      if (pos[s] > 0 && pos[s] < trackLen) {
        final other = [
          for (var o = 0; o < players; o++)
            if (o != s && pos[o] == pos[s]) o,
        ].firstOrNull;
        if (other != null) {
          phase = 'combat';
          combatAttacker = s;
          combatDefender = other;
          attackerPowder = null;
          defenderPowder = null;
          lastEvent =
              '💥 炮火连天！${name(s)} 与 ${name(other)} 在第 ${pos[s]} 格【${kJamaicaTrack[pos[s]].name}】遭遇，爆发海战！';
          host.log(lastEvent);
          return;
        }
      }
    }

    _finishRound();
  }

  void _applyStep(int seat, String stepType, int val, int holdIdx) {
    switch (stepType) {
      case 'load_gold':
        loadCargo(seat, 'gold', val, holdIdx);
      case 'load_food':
        loadCargo(seat, 'food', val, holdIdx);
      case 'load_powder':
        loadCargo(seat, 'powder', val, holdIdx);
      case 'move_fwd':
        pos[seat] = min(trackLen, pos[seat] + val);
        _applySpaceEffect(seat);
      case 'move_back':
        pos[seat] = max(0, pos[seat] - val);
        _applySpaceEffect(seat);
    }
  }

  void _applySpaceEffect(int seat) {
    final p = pos[seat];
    if (p <= 0 || p >= trackLen) return;
    final sp = kJamaicaTrack[p];
    if (sp.type == 'lair') {
      treasures[seat]++;
    } else if (sp.type == 'food') {
      spendCargo(seat, 'food', sp.cost);
    } else if (sp.type == 'gold') {
      spendCargo(seat, 'gold', sp.cost);
    }
  }

  void _resolveCombat() {
    final att = combatAttacker!;
    final def = combatDefender!;
    final pAtt = attackerPowder ?? 0;
    final pDef = defenderPowder ?? 0;
    final rollAtt = 2 * (1 + rng.nextInt(6));
    final rollDef = 2 * (1 + rng.nextInt(6));
    final scoreAtt = pAtt * 2 + rollAtt;
    final scoreDef = pDef * 2 + rollDef;

    final winner = scoreAtt >= scoreDef ? att : def;
    final loser = winner == att ? def : att;

    var lootDesc = '对方船舱空空如也';
    if (treasures[loser] > 0) {
      treasures[loser]--;
      treasures[winner]++;
      lootDesc = '掠夺了 1 个🏴‍☠️宝藏箱';
    } else {
      for (var h = 0; h < 3; h++) {
        final t = holds[loser][h]['type'] as String;
        final amt = (holds[loser][h]['amount'] as num).toInt();
        if (t != 'empty' && amt > 0) {
          holds[loser][h] = {'type': 'empty', 'amount': 0};
          loadCargo(winner, t, amt);
          lootDesc = '掠夺了船舱物资 ($t ×$amt)';
          break;
        }
      }
    }

    combatAttacker = null;
    combatDefender = null;
    attackerPowder = null;
    defenderPowder = null;
    lastEvent =
        '⚔️ 海战结果：${name(winner)} 击败 ${name(loser)}，$lootDesc！';
    host.log(lastEvent);

    _processNextInQueue();
  }

  void _finishRound() {
    if (pos.any((p) => p >= trackLen) || round >= maxRounds) {
      _over = true;
      phase = 'over';
      final sc = scores;
      final best = sc.reduce(max);
      final winners = [
        for (var s = 0; s < players; s++)
          if (sc[s] == best) name(s),
      ];
      lastEvent =
          '⚓ 皇家港冲线结算！最终海盗王：${winners.join("、")}（总分 $best）！';
      host.log(lastEvent);
      return;
    }

    round++;
    captain = (captain + 1) % players;
    _startRollPhase();
    lastEvent =
        '🌊 第 ${round - 1} 轮航行结束！进入第 $round/$maxRounds 轮，轮到新任船长 ${name(captain)} 分配晨昏双骰。';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'roll') {
      final hi = max(rolledDice[0], rolledDice[1]);
      final lo = min(rolledDice[0], rolledDice[1]);
      return {'type': 'assign_dice', 'morning': hi, 'evening': lo};
    }

    if (phase == 'choose') {
      final hand = hands[seat];
      // Prefer forward movement card if we have enough food/gold, otherwise load + move
      var bestCard = hand.first;
      for (final c in hand) {
        final card = kJamaicaCards[c];
        if (card.morning == 'move_fwd' && card.evening == 'move_fwd') {
          bestCard = c;
          break;
        }
        if (card.evening == 'move_fwd') {
          bestCard = c;
        }
      }
      // Choose an empty hold or smallest hold
      var bestHold = 0;
      var minAmt = 99;
      for (var h = 0; h < 3; h++) {
        final amt = (holds[seat][h]['amount'] as num).toInt();
        if (amt < minAmt) {
          minAmt = amt;
          bestHold = h;
        }
      }
      return {'type': 'play', 'card': bestCard, 'hold': bestHold};
    }

    if (phase == 'combat') {
      final maxP = totalCargo(seat, 'powder');
      final spend = maxP > 0 ? min(maxP, 2) : 0;
      return {'type': 'combat', 'powder': spend};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) => {
        'round': round,
        'maxRounds': maxRounds,
        'captain': captain,
        'phase': phase,
        'rolledDice': List<int>.of(rolledDice),
        'morningVal': morningVal,
        'eveningVal': eveningVal,
        'pos': List<int>.of(pos),
        'treasures': List<int>.of(treasures),
        'holds': [
          for (var s = 0; s < players; s++)
            [
              for (var h = 0; h < 3; h++) Map<String, dynamic>.of(holds[s][h]),
            ],
        ],
        'hand': seat >= 0 && seat < players ? List<int>.of(hands[seat]) : const <int>[],
        'chosenCard': [
          for (var s = 0; s < players; s++)
            (phase != 'choose' || s == seat) ? chosenCard[s] : (chosenCard[s] != null ? -1 : null),
        ],
        'combatAttacker': combatAttacker,
        'combatDefender': combatDefender,
        'scores': scores,
        'waitingFor': waitingFor,
        'lastEvent': lastEvent,
        'over': _over,
      };
}
