import 'dart:math';

import '../../src/engine.dart';

class PowerCardDef {
  final String id;
  final String name;
  final int cost;
  final String kind; // 'keep' or 'discard'
  final String desc;
  const PowerCardDef(this.id, this.name, this.cost, this.kind, this.desc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cost': cost,
        'kind': kind,
        'desc': desc,
      };
}

const List<PowerCardDef> tokyoPowerCards = [
  PowerCardDef('acid_attack', '酸液吐息', 6, 'keep', '掷出爪击时伤害 +1'),
  PowerCardDef('armor_plating', '装甲镀层', 4, 'keep', '受到的伤害减少 1 点'),
  PowerCardDef('giant_brain', '巨型大脑', 5, 'keep', '每回合重掷次数 +1'),
  PowerCardDef('regeneration', '再生能力', 4, 'keep', '通过红心回血时额外 +1 生命'),
  PowerCardDef('jets', '喷气背包', 5, 'keep', '撤离东京时回复 2 点生命并 +1 能量'),
  PowerCardDef('energy_hoarder', '能量囤积', 3, 'keep', '回合结束时每有 6 点能量 +1 分'),
  PowerCardDef('skyscraper', '摩天大楼破坏者', 4, 'discard', '立即获得 2 分'),
  PowerCardDef('nuclear_reactor', '核能反应堆', 6, 'discard', '立即获得 2 分和 3 点能量'),
  PowerCardDef('high_altitude_bombing', '高空轰炸', 5, 'discard', '对所有其他怪兽造成 2 点伤害'),
  PowerCardDef('healing_ray', '治疗射线', 4, 'discard', '立即回复 3 点生命（东京内也有效）'),
  PowerCardDef('alien_tech', '外星科技', 3, 'keep', '购买超能力卡费用 -1（最低 1）'),
  PowerCardDef('alpha_monster', '霸主怪兽', 5, 'keep', '掷出爪击攻击时额外 +1 分'),
  PowerCardDef('urbavore', '城市掠食者', 4, 'keep', '在东京开始回合 +1 分且在东京内爪击 +1'),
  PowerCardDef('friend_of_children', '能量增幅器', 3, 'keep', '通过闪电获得能量时额外 +1 能量'),
  PowerCardDef('even_bigger', '巨兽进化', 4, 'keep', '生命上限 +2 并立即回复 2 点生命'),
  PowerCardDef('gourmet', '美食家', 4, 'keep', '结算至少 3 个「1」时额外 +2 分'),
  PowerCardDef('fire_blast', '烈焰冲击', 3, 'discard', '对所有其他怪兽造成 1 点伤害并 +1 分'),
  PowerCardDef('energize', '超载充能', 7, 'discard', '立即获得 9 点能量'),
];

final Map<String, PowerCardDef> tokyoCardById = {
  for (final c in tokyoPowerCards) c.id: c,
};

const List<String> kTokyoDieFaces = ['1', '2', '3', 'claw', 'heart', 'energy'];

const List<String> kMonsterNames = [
  '哥斯拉大王',
  '机械巨喵',
  '外星霸主',
  '变异巨猿',
  '深海巨妖',
  '宇宙魔龙',
];

class TokyoKing extends GameEngine {
  late int targetVp;
  late List<int> hp;
  late List<int> maxHp;
  late List<int> vp;
  late List<int> energy;
  late List<bool> alive;
  late List<List<String>> ownedCards;
  late List<int> elimOrder;
  int _elimSeq = 0;

  int tokyoCity = -1;
  int tokyoBay = -1;
  int turn = 0;
  String phase = 'roll'; // 'roll' | 'yield' | 'buy' | 'end'
  int rollsLeft = 2;
  List<String> dice = [];
  List<int> yieldQueue = [];

  List<String> deck = [];
  List<String> discard = [];
  List<String> market = [];

  String lastAction = '';
  bool over = false;
  List<int> winners = [];
  int roundCount = 1;

  TokyoKing(super.setup);

  int get aliveCount => alive.where((a) => a).length;
  bool get bayActive => aliveCount >= 5;
  bool inTokyo(int seat) => tokyoCity == seat || tokyoBay == seat;

  bool hasCard(int seat, String cardId) =>
      seat >= 0 && seat < players && ownedCards[seat].contains(cardId);

  int maxRerollsFor(int seat) => 2 + (hasCard(seat, 'giant_brain') ? 1 : 0);

  int cardCostFor(int seat, PowerCardDef card) {
    var c = card.cost;
    if (hasCard(seat, 'alien_tech')) c = max(1, c - 1);
    return c;
  }

  @override
  void start() {
    targetVp = setup.opt<int>('targetVp', 20);
    hp = List.filled(players, 10);
    maxHp = List.filled(players, 10);
    vp = List.filled(players, 0);
    energy = List.filled(players, 0);
    alive = List.filled(players, true);
    ownedCards = [for (var i = 0; i < players; i++) <String>[]];
    elimOrder = List.filled(players, 0);
    _elimSeq = 0;
    tokyoCity = -1;
    tokyoBay = -1;
    turn = 0;
    over = false;
    winners = [];
    roundCount = 1;

    // Build deck (2 copies of each card for ample variety in 2-6p games)
    final allIds = <String>[
      for (final c in tokyoPowerCards) ...[c.id, c.id],
    ];
    deck = shuffled(allIds, rng);
    discard = [];
    market = [];
    _refillMarket();

    _beginTurn(0, isFirstTurn: true);
  }

  void _refillMarket() {
    while (market.length < 3) {
      if (deck.isEmpty) {
        if (discard.isEmpty) break;
        deck = shuffled(discard, rng);
        discard.clear();
      }
      market.add(deck.removeLast());
    }
  }

  String _rollOne() => kTokyoDieFaces[rng.nextInt(kTokyoDieFaces.length)];

  void _beginTurn(int seat, {bool isFirstTurn = false}) {
    turn = seat;
    yieldQueue.clear();
    if (inTokyo(seat)) {
      var gain = 2;
      if (hasCard(seat, 'urbavore')) gain += 1;
      vp[seat] += gain;
      host.log('${name(seat)} 在东京开始回合，获得 +$gain 分！');
      if (_checkWin()) return;
    }
    rollsLeft = maxRerollsFor(seat);
    dice = [for (var i = 0; i < 6; i++) _rollOne()];
    phase = 'roll';
    if (isFirstTurn) {
      lastAction = '游戏开始，轮到 ${name(seat)} 掷骰';
    } else {
      lastAction = '轮到 ${name(seat)} 掷骰';
    }
  }

  bool get hasEmptyTokyoSlot {
    if (tokyoCity == -1) return true;
    if (bayActive && tokyoBay == -1) return true;
    return false;
  }

  void enterTokyo(int seat) {
    if (inTokyo(seat) || !alive[seat]) return;
    if (tokyoCity == -1) {
      tokyoCity = seat;
      vp[seat] += 1;
      host.log('${name(seat)} 进驻东京市，获得 +1 分！');
    } else if (bayActive && tokyoBay == -1) {
      tokyoBay = seat;
      vp[seat] += 1;
      host.log('${name(seat)} 进驻东京湾，获得 +1 分！');
    }
  }

  void _applyDamage(int target, int rawDamage, {required bool fromClaw}) {
    if (!alive[target] || rawDamage <= 0) return;
    var dmg = rawDamage;
    if (hasCard(target, 'armor_plating')) {
      dmg = max(0, dmg - 1);
    }
    if (dmg <= 0) return;
    hp[target] = max(0, hp[target] - dmg);
    if (hp[target] <= 0) {
      alive[target] = false;
      _elimSeq++;
      elimOrder[target] = _elimSeq;
      if (tokyoCity == target) tokyoCity = -1;
      if (tokyoBay == target) tokyoBay = -1;
      host.log('${name(target)} 生命归零，被淘汰出局！');
      _checkBayRule();
    } else if (fromClaw && inTokyo(target)) {
      if (!yieldQueue.contains(target)) {
        yieldQueue.add(target);
      }
    }
  }

  void _checkBayRule() {
    if (!bayActive && tokyoBay != -1) {
      final occupant = tokyoBay;
      tokyoBay = -1;
      if (tokyoCity == -1 && alive[occupant]) {
        tokyoCity = occupant;
        host.log('存活怪兽不超过 4 只，东京湾关闭，${name(occupant)} 移入东京市');
      } else {
        host.log('存活怪兽不超过 4 只，东京湾关闭，${name(occupant)} 离开东京湾');
      }
    }
  }

  bool _checkWin() {
    if (over) return true;
    final aliveSeats = [for (var s = 0; s < players; s++) if (alive[s]) s];
    if (aliveSeats.isEmpty) {
      over = true;
      phase = 'end';
      winners = [turn];
      return true;
    }
    if (aliveSeats.length == 1) {
      over = true;
      phase = 'end';
      winners = [aliveSeats.first];
      lastAction = '${name(winners.first)} 成为最后存活的怪兽，赢得胜利！';
      host.log(lastAction);
      return true;
    }
    final reached = [for (final s in aliveSeats) if (vp[s] >= targetVp) s];
    if (reached.isNotEmpty) {
      final bestVp = reached.map((s) => vp[s]).reduce(max);
      winners = [for (final s in reached) if (vp[s] == bestVp) s];
      over = true;
      phase = 'end';
      lastAction = '${winners.map(name).join('、')} 率先达到 ${bestVp} 分，赢得胜利！';
      host.log(lastAction);
      return true;
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'roll') {
      if (seat != turn) throw GameError('还没轮到你行动');
      if (type == 'reroll') {
        if (rollsLeft <= 0) throw GameError('重掷次数已用完，请结算骰子');
        final rawKeep = action['keep'];
        if (rawKeep is! List) throw GameError('请指定要保留的骰子');
        final keepSet = <int>{};
        for (final k in rawKeep) {
          final idx = asInt(k);
          if (idx >= 0 && idx < dice.length) keepSet.add(idx);
        }
        if (keepSet.length >= dice.length) {
          throw GameError('请至少重掷 1 颗骰子，或直接结算');
        }
        for (var i = 0; i < dice.length; i++) {
          if (!keepSet.contains(i)) {
            dice[i] = _rollOne();
          }
        }
        rollsLeft--;
        lastAction = '${name(seat)} 进行了重掷（剩余 $rollsLeft 次）';
        return;
      }
      if (type == 'resolve') {
        _resolveDice(seat);
        return;
      }
      throw GameError('未知操作');
    }

    if (phase == 'yield') {
      if (yieldQueue.isEmpty || seat != yieldQueue.first) {
        throw GameError('当前无需你响应撤离');
      }
      if (type != 'stay' && type != 'yield') {
        throw GameError('请选择留守东京或撤离东京');
      }
      yieldQueue.removeAt(0);
      if (type == 'yield') {
        if (tokyoCity == seat) tokyoCity = -1;
        if (tokyoBay == seat) tokyoBay = -1;
        if (hasCard(seat, 'jets')) {
          hp[seat] = min(maxHp[seat], hp[seat] + 2);
          energy[seat] += 1;
        }
        host.log('${name(seat)} 选择撤离东京！');
        if (!inTokyo(turn) && alive[turn]) {
          enterTokyo(turn);
        }
      } else {
        host.log('${name(seat)} 选择留守东京！');
      }

      if (_checkWin()) return;
      if (yieldQueue.isEmpty) {
        if (hasEmptyTokyoSlot && !inTokyo(turn) && alive[turn]) {
          enterTokyo(turn);
          if (_checkWin()) return;
        }
        phase = 'buy';
        lastAction = '${name(turn)} 进入购卡阶段';
      }
      return;
    }

    if (phase == 'buy') {
      if (seat != turn) throw GameError('还没轮到你行动');
      if (type == 'buy') {
        var idx = asInt(action['index'], -1);
        final cardId = asStr(action['card']);
        if (idx < 0 && cardId.isNotEmpty) {
          idx = market.indexOf(cardId);
        }
        if (idx < 0 || idx >= market.length) {
          throw GameError('无效的市场卡牌');
        }
        final cid = market[idx];
        final def = tokyoCardById[cid]!;
        final cost = cardCostFor(seat, def);
        if (energy[seat] < cost) {
          throw GameError('能量不足（需要 $cost 点能量）');
        }
        energy[seat] -= cost;
        market.removeAt(idx);
        _refillMarket();
        _applyBoughtCard(seat, def);
        lastAction = '${name(seat)} 购买了【${def.name}】';
        host.log(lastAction);
        _checkWin();
        return;
      }
      if (type == 'sweep') {
        if (energy[seat] < 2) throw GameError('刷新市场需要 2 点能量');
        energy[seat] -= 2;
        discard.addAll(market);
        market.clear();
        _refillMarket();
        lastAction = '${name(seat)} 花费 2 能量刷新了市场';
        host.log(lastAction);
        return;
      }
      if (type == 'end_turn') {
        _endTurn(seat);
        return;
      }
      throw GameError('未知操作');
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _resolveDice(int seat) {
    final counts = <String, int>{for (final f in kTokyoDieFaces) f: 0};
    for (final d in dice) {
      counts[d] = (counts[d] ?? 0) + 1;
    }

    final summaryParts = <String>[];

    // 1. Score numbers 1, 2, 3
    var vpGain = 0;
    for (final numFace in const ['1', '2', '3']) {
      final c = counts[numFace] ?? 0;
      if (c >= 3) {
        final base = int.parse(numFace);
        vpGain += base + (c - 3);
      }
    }
    if ((counts['1'] ?? 0) >= 3 && hasCard(seat, 'gourmet')) {
      vpGain += 2;
    }
    if (vpGain > 0) {
      vp[seat] += vpGain;
      summaryParts.add('+$vpGain分');
    }

    // 2. Energy
    var engGain = counts['energy'] ?? 0;
    if (engGain > 0 && hasCard(seat, 'friend_of_children')) {
      engGain += 1;
    }
    if (engGain > 0) {
      energy[seat] += engGain;
      summaryParts.add('+$engGain⚡');
    }

    // 3. Heart (only if NOT in Tokyo!)
    final heartCount = counts['heart'] ?? 0;
    if (heartCount > 0 && !inTokyo(seat)) {
      var heal = heartCount;
      if (hasCard(seat, 'regeneration')) heal += 1;
      final before = hp[seat];
      hp[seat] = min(maxHp[seat], hp[seat] + heal);
      final actualHeal = hp[seat] - before;
      if (actualHeal > 0) {
        summaryParts.add('+$actualHeal❤️');
      }
    }

    // 4. Claws
    final clawCount = counts['claw'] ?? 0;
    var dmg = clawCount;
    if (clawCount > 0) {
      if (hasCard(seat, 'acid_attack')) dmg += 1;
      if (inTokyo(seat) && hasCard(seat, 'urbavore')) dmg += 1;
      if (hasCard(seat, 'alpha_monster')) {
        vp[seat] += 1;
        summaryParts.add('霸主+1分');
      }
    }

    yieldQueue.clear();
    if (dmg > 0) {
      summaryParts.add('$dmg爪击');
      if (inTokyo(seat)) {
        // Attack all alive monsters outside Tokyo
        for (var s = 0; s < players; s++) {
          if (s != seat && alive[s] && !inTokyo(s)) {
            _applyDamage(s, dmg, fromClaw: true);
          }
        }
      } else {
        // Attack monsters inside Tokyo
        final targets = <int>[
          if (tokyoCity != -1) tokyoCity,
          if (tokyoBay != -1) tokyoBay,
        ];
        if (targets.isEmpty) {
          enterTokyo(seat);
        } else {
          for (final t in targets) {
            _applyDamage(t, dmg, fromClaw: true);
          }
          if (hasEmptyTokyoSlot && !inTokyo(seat) && alive[seat]) {
            enterTokyo(seat);
          }
        }
      }
    }

    final detail = summaryParts.isEmpty ? '无收益' : summaryParts.join('，');
    lastAction = '${name(seat)} 结算骰子：$detail';
    host.log(lastAction);

    if (_checkWin()) return;

    if (yieldQueue.isNotEmpty) {
      phase = 'yield';
    } else {
      phase = 'buy';
    }
  }

  void _applyBoughtCard(int seat, PowerCardDef def) {
    if (def.kind == 'keep') {
      ownedCards[seat].add(def.id);
      if (def.id == 'even_bigger') {
        maxHp[seat] += 2;
        hp[seat] = min(maxHp[seat], hp[seat] + 2);
      }
    } else {
      discard.add(def.id);
      switch (def.id) {
        case 'skyscraper':
          vp[seat] += 2;
          break;
        case 'nuclear_reactor':
          vp[seat] += 2;
          energy[seat] += 3;
          break;
        case 'high_altitude_bombing':
          for (var s = 0; s < players; s++) {
            if (s != seat && alive[s]) {
              _applyDamage(s, 2, fromClaw: false);
            }
          }
          break;
        case 'healing_ray':
          hp[seat] = min(maxHp[seat], hp[seat] + 3);
          break;
        case 'fire_blast':
          vp[seat] += 1;
          for (var s = 0; s < players; s++) {
            if (s != seat && alive[s]) {
              _applyDamage(s, 1, fromClaw: false);
            }
          }
          break;
        case 'energize':
          energy[seat] += 9;
          break;
      }
    }
  }

  void _endTurn(int seat) {
    if (hasCard(seat, 'energy_hoarder')) {
      final bonus = energy[seat] ~/ 6;
      if (bonus > 0) {
        vp[seat] += bonus;
        host.log('${name(seat)} 触发【能量囤积】获得 +$bonus 分');
      }
    }
    if (_checkWin()) return;

    // Advance to next alive seat
    var next = (seat + 1) % players;
    for (var i = 0; i < players; i++) {
      if (alive[next]) break;
      next = (next + 1) % players;
    }
    if (next <= seat) roundCount++;
    if (roundCount > 120) {
      // Safety cap for extreme stalemates
      over = true;
      phase = 'end';
      final bestScore = [
        for (var s = 0; s < players; s++)
          if (alive[s]) vp[s] * 100 + hp[s] else -1
      ].reduce(max);
      winners = [
        for (var s = 0; s < players; s++)
          if (alive[s] && vp[s] * 100 + hp[s] == bestScore) s
      ];
      return;
    }
    _beginTurn(next);
  }

  @override
  List<int> get waitingFor {
    if (over) return const [];
    if (phase == 'yield' && yieldQueue.isNotEmpty) {
      return [yieldQueue.first];
    }
    return [turn];
  }

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    final scores = List<num>.generate(players, (s) {
      if (winners.contains(s)) return 1000000;
      if (alive[s]) return 10000 + vp[s] * 100 + hp[s];
      return elimOrder[s];
    });
    return rankByScore(scores);
  }

  @override
  bool get canResign => !over && players == 2;

  @override
  void resign(int seat) {
    if (!canResign || seat < 0 || seat >= players) throw GameError('无法认输');
    alive[seat] = false;
    hp[seat] = 0;
    over = true;
    phase = 'end';
    winners = [1 - seat];
    lastAction = '${name(seat)} 认输，${name(1 - seat)} 获胜！';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'targetVp': targetVp,
      'turn': turn,
      'phase': phase,
      'rollsLeft': rollsLeft,
      'dice': List<String>.of(dice),
      'tokyoCity': tokyoCity,
      'tokyoBay': tokyoBay,
      'bayActive': bayActive,
      'yieldQueue': List<int>.of(yieldQueue),
      'lastAction': lastAction,
      'over': over,
      'winners': List<int>.of(winners),
      'market': [
        for (final id in market) tokyoCardById[id]!.toJson(),
      ],
      'deckCount': deck.length,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'monster': kMonsterNames[s % kMonsterNames.length],
            'hp': hp[s],
            'maxHp': maxHp[s],
            'vp': vp[s],
            'energy': energy[s],
            'alive': alive[s],
            'inTokyo': inTokyo(s),
            'cards': [
              for (final id in ownedCards[s]) tokyoCardById[id]!.toJson(),
            ],
          },
      ],
      if (over)
        'final': [
          for (var s = 0; s < players; s++)
            {
              'seat': s,
              'name': name(s),
              'vp': vp[s],
              'hp': hp[s],
              'alive': alive[s],
              'win': winners.contains(s),
            },
        ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || !waitingFor.contains(seat)) return null;

    if (phase == 'yield') {
      // Yield if HP is low (<= 4 in normal/hard, or random in easy)
      if (botLevel == 0) {
        return {'type': rng.nextBool() ? 'yield' : 'stay'};
      }
      final shouldYield = hp[seat] <= (botLevel == 2 ? 5 : 4) && vp[seat] < targetVp - 2;
      return {'type': shouldYield ? 'yield' : 'stay'};
    }

    if (phase == 'roll') {
      if (rollsLeft <= 0) {
        return {'type': 'resolve'};
      }
      if (botLevel == 0) {
        if (rng.nextBool()) return {'type': 'resolve'};
        final keep = <int>[];
        for (var i = 0; i < dice.length; i++) {
          if (rng.nextBool()) keep.add(i);
        }
        if (keep.length == dice.length) return {'type': 'resolve'};
        return {'type': 'reroll', 'keep': keep};
      }

      // Smart keep selection
      final counts = <String, int>{};
      for (final d in dice) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
      final keep = <int>[];
      final needHeal = !inTokyo(seat) && hp[seat] <= 6;
      for (var i = 0; i < dice.length; i++) {
        final d = dice[i];
        if (d == 'claw') {
          if (hp[seat] >= 5 || inTokyo(seat)) keep.add(i);
        } else if (d == 'heart') {
          if (needHeal) keep.add(i);
        } else if (d == 'energy') {
          if (hp[seat] > 4) keep.add(i);
        } else if (d == '3' || d == '2' || d == '1') {
          if ((counts[d] ?? 0) >= 2 || (d == '3' && botLevel == 2)) {
            keep.add(i);
          }
        }
      }
      if (keep.length >= dice.length) {
        return {'type': 'resolve'};
      }
      return {'type': 'reroll', 'keep': keep};
    }

    if (phase == 'buy') {
      // Check if we can buy any card in market
      final affordable = <int>[];
      for (var i = 0; i < market.length; i++) {
        final def = tokyoCardById[market[i]]!;
        final cost = cardCostFor(seat, def);
        if (energy[seat] >= cost) {
          // Don't buy duplicate keep cards
          if (def.kind == 'keep' && hasCard(seat, def.id)) continue;
          affordable.add(i);
        }
      }
      if (affordable.isNotEmpty) {
        if (botLevel == 2) {
          affordable.sort((a, b) =>
              tokyoCardById[market[b]]!.cost.compareTo(tokyoCardById[market[a]]!.cost));
        }
        return {'type': 'buy', 'index': affordable.first};
      }
      return {'type': 'end_turn'};
    }

    return null;
  }
}
