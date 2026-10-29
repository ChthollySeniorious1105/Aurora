import '../../src/engine.dart';

const List<String> aquaticaMantaNames = [
  '+2金币',
  '+2战力',
  '免费上升',
  '计分收纳',
];

const List<String> aquaticaMantaEmojis = [
  '🪙',
  '⚔️',
  '⬆️',
  '🏁',
];

class AquaticaCharacterCard {
  final int id;
  final String name;
  final String emoji;
  final int coins;
  final int strength;
  final int freeRises;

  const AquaticaCharacterCard({
    required this.id,
    required this.name,
    required this.emoji,
    this.coins = 0,
    this.strength = 0,
    this.freeRises = 0,
  });

  String get effectDesc {
    final parts = <String>[];
    if (coins > 0) parts.add('+${coins}🪙');
    if (strength > 0) parts.add('+${strength}⚔️');
    if (freeRises > 0) parts.add('+${freeRises}⬆️');
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'coins': coins,
        'strength': strength,
        'freeRises': freeRises,
        'effectDesc': effectDesc,
      };
}

class AquaticaLocationCard {
  final int id;
  final String name;
  final String emoji;
  final int buyCost; // 🪙 cost to buy
  final int conquerCost; // ⚔️ cost to conquer
  final int vp; // 3..8 VP when scored into Vault
  final int currentDepth; // 0..3 (maxDepth = 3)
  // Rewards when rising to depth 1, 2, 3:
  // 0: +2🪙, 1: +2⚔️, 2: +1⬆️, 3: +2⭐VP
  final List<int> depthRewards;

  const AquaticaLocationCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.buyCost,
    required this.conquerCost,
    required this.vp,
    this.currentDepth = 0,
    this.depthRewards = const [0, 1, 3],
  });

  static const int maxDepth = 3;

  static String rewardLabel(int r) => switch (r) {
        0 => '+2🪙',
        1 => '+2⚔️',
        2 => '+1⬆️',
        _ => '+2⭐',
      };

  String get depthsDesc =>
      [for (var i = 0; i < depthRewards.length; i++) 'D${i + 1}:${rewardLabel(depthRewards[i])}']
          .join(' ');

  AquaticaLocationCard copyWith({int? currentDepth}) => AquaticaLocationCard(
        id: id,
        name: name,
        emoji: emoji,
        buyCost: buyCost,
        conquerCost: conquerCost,
        vp: vp,
        currentDepth: currentDepth ?? this.currentDepth,
        depthRewards: depthRewards,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'buyCost': buyCost,
        'conquerCost': conquerCost,
        'vp': vp,
        'currentDepth': currentDepth,
        'maxDepth': maxDepth,
        'depthRewards': depthRewards,
        'depthsDesc': depthsDesc,
      };
}

class AquaticaGame extends GameEngine {
  static const int numDepthSlots = 3;
  static const int numMantas = 4;
  static const int marketSize = 5;

  late final int maxRounds;
  late List<AquaticaLocationCard> locationDeck;
  late List<AquaticaLocationCard> locationMarket;
  late List<List<AquaticaLocationCard?>> depthSlots; // depthSlots[seat][0..2]
  late List<List<AquaticaLocationCard>> vault; // scored locations
  late List<List<AquaticaCharacterCard>> hand;
  late List<List<AquaticaCharacterCard>> playedCards;
  late List<List<bool>> mantas; // mantas[seat][0..3] true = ready
  late List<int> coins;
  late List<int> strength;
  late List<int> freeRises;
  late List<int> bonusVp;
  late List<int> score;

  int round = 1;
  int turn = 0;
  int turnActions = 0;
  bool over = false;
  String lastAction = '深海国度探索开启';

  AquaticaGame(super.setup) : maxRounds = setup.opt<int>('rounds', 6);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<AquaticaCharacterCard> _startingHand() => const [
        AquaticaCharacterCard(
          id: 1,
          name: '深海采珠人',
          emoji: '🧜‍♀️',
          coins: 2,
          freeRises: 1,
        ),
        AquaticaCharacterCard(
          id: 2,
          name: '三叉戟禁卫',
          emoji: '🔱',
          strength: 2,
          freeRises: 1,
        ),
        AquaticaCharacterCard(
          id: 3,
          name: '潮汐贸易官',
          emoji: '🐚',
          coins: 3,
        ),
        AquaticaCharacterCard(
          id: 4,
          name: '巨鲨先锋',
          emoji: '🦈',
          strength: 3,
        ),
        AquaticaCharacterCard(
          id: 5,
          name: '洋流领航员',
          emoji: '🐬',
          coins: 1,
          strength: 1,
          freeRises: 2,
        ),
      ];

  List<AquaticaLocationCard> _buildLocationDeck() {
    const templates = [
      ('荧光珊瑚礁', '🪸', 2, 2, 4, [0, 2, 3]),
      ('亚特兰蒂斯遗迹', '🏛️', 4, 3, 6, [0, 1, 3]),
      ('深渊热液喷口', '🌋', 3, 2, 5, [1, 2, 3]),
      ('珍珠母贝海湾', '🦪', 2, 3, 4, [0, 0, 3]),
      ('海怪盘踞海沟', '🦑', 5, 3, 7, [1, 1, 3]),
      ('沉船宝藏峡谷', '⚓', 3, 3, 5, [0, 2, 3]),
      ('水母星光森林', '🪼', 2, 2, 4, [2, 0, 3]),
      ('寒流冰晶海窟', '🧊', 4, 4, 6, [1, 2, 3]),
      ('漩涡潮汐神殿', '🌀', 5, 4, 8, [0, 1, 3]),
      ('海马翡翠草甸', '🌿', 2, 1, 3, [0, 2, 3]),
      ('远古鲸骨墓园', '🐋', 4, 3, 6, [1, 0, 3]),
      ('皇家深海王庭', '👑', 5, 4, 8, [0, 2, 3]),
    ];
    final list = <AquaticaLocationCard>[];
    var id = 100;
    for (var copy = 0; copy < 2; copy++) {
      for (final (nm, em, buy, conq, vp, rewards) in templates) {
        list.add(AquaticaLocationCard(
          id: id++,
          name: nm,
          emoji: em,
          buyCost: buy,
          conquerCost: conq,
          vp: vp,
          depthRewards: rewards,
        ));
      }
    }
    return shuffled(list, rng);
  }

  void _refillMarket() {
    while (locationMarket.length < marketSize && locationDeck.isNotEmpty) {
      locationMarket.add(locationDeck.removeLast());
    }
  }

  @override
  void start() {
    locationDeck = _buildLocationDeck();
    locationMarket = [];
    _refillMarket();

    depthSlots = List.generate(
      players,
      (_) => List<AquaticaLocationCard?>.filled(numDepthSlots, null),
    );
    vault = List.generate(players, (_) => <AquaticaLocationCard>[]);
    hand = List.generate(players, (_) => List.of(_startingHand()));
    playedCards = List.generate(players, (_) => <AquaticaCharacterCard>[]);
    mantas = List.generate(players, (_) => List.filled(numMantas, true));
    coins = List.filled(players, 1);
    strength = List.filled(players, 1);
    freeRises = List.filled(players, 1);
    bonusVp = List.filled(players, 0);
    score = List.filled(players, 0);

    round = 1;
    turn = 0;
    turnActions = 0;
    over = false;
    lastAction = '第 1 轮开始，请打出海洋角色卡、翻转蝠鲼或探索海域';
  }

  int calcVaultVp(int seat) {
    var pts = 0;
    for (final loc in vault[seat]) {
      pts += loc.vp;
    }
    return pts;
  }

  int calcSlottedDepthVp(int seat) {
    var pts = 0;
    for (final loc in depthSlots[seat]) {
      if (loc != null) pts += loc.currentDepth;
    }
    return pts;
  }

  int calcScore(int seat) =>
      calcVaultVp(seat) + calcSlottedDepthVp(seat) + bonusVp[seat];

  void _applyDepthReward(int seat, int rewardCode) {
    switch (rewardCode) {
      case 0:
        coins[seat] += 2;
      case 1:
        strength[seat] += 2;
      case 2:
        freeRises[seat] += 1;
      default:
        bonusVp[seat] += 2;
    }
  }

  /// Rises `depthSlots[seat][slot]` by 1 level and grants that depth's reward.
  void _riseLocationAt(int seat, int slot) {
    final loc = depthSlots[seat][slot]!;
    final nextDepth = loc.currentDepth + 1;
    final rewardCode =
        loc.depthRewards[(nextDepth - 1).clamp(0, loc.depthRewards.length - 1)];
    depthSlots[seat][slot] = loc.copyWith(currentDepth: nextDepth);
    _applyDepthReward(seat, rewardCode);
    score[seat] = calcScore(seat);
  }

  int firstEmptySlot(int seat) {
    for (var i = 0; i < numDepthSlots; i++) {
      if (depthSlots[seat][i] == null) return i;
    }
    return -1;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'play_card':
        final idx = asInt(action['cardIdx'], -1);
        if (idx < 0 || idx >= hand[seat].length) {
          throw GameError('无效的手牌编号');
        }
        final card = hand[seat].removeAt(idx);
        playedCards[seat].add(card);
        coins[seat] += card.coins;
        strength[seat] += card.strength;
        freeRises[seat] += card.freeRises;
        turnActions++;
        lastAction =
            '${name(seat)} 打出 ${card.emoji}${card.name} (${card.effectDesc})';
        host.log(lastAction);

      case 'use_manta':
        final m = asInt(action['manta'], -1);
        if (m < 0 || m >= numMantas) {
          throw GameError('无效的蝠鲼编号');
        }
        if (!mantas[seat][m]) {
          throw GameError('该蝠鲼本轮已翻转使用过了');
        }
        mantas[seat][m] = false;
        switch (m) {
          case 0:
            coins[seat] += 2;
          case 1:
            strength[seat] += 2;
          case 2:
            freeRises[seat] += 1;
            final optSlot = asInt(action['slot'], -1);
            if (optSlot >= 0 &&
                optSlot < numDepthSlots &&
                depthSlots[seat][optSlot] != null &&
                depthSlots[seat][optSlot]!.currentDepth <
                    AquaticaLocationCard.maxDepth) {
              freeRises[seat] -= 1;
              _riseLocationAt(seat, optSlot);
            }
          case 3:
            bonusVp[seat] += 1;
            final optSlot = asInt(action['slot'], -1);
            if (optSlot >= 0 &&
                optSlot < numDepthSlots &&
                depthSlots[seat][optSlot] != null &&
                depthSlots[seat][optSlot]!.currentDepth >=
                    AquaticaLocationCard.maxDepth) {
              final loc = depthSlots[seat][optSlot]!;
              depthSlots[seat][optSlot] = null;
              vault[seat].add(loc);
            }
        }
        score[seat] = calcScore(seat);
        turnActions++;
        lastAction =
            '${name(seat)} 翻转蝠鲼【${aquaticaMantaEmojis[m]}${aquaticaMantaNames[m]}】';
        host.log(lastAction);

      case 'buy_loc':
        final mIdx = asInt(action['marketIdx'], -1);
        if (mIdx < 0 || mIdx >= locationMarket.length) {
          throw GameError('无效的市场海域编号');
        }
        final slot = asInt(action['slot'], firstEmptySlot(seat));
        if (slot < 0 || slot >= numDepthSlots || depthSlots[seat][slot] != null) {
          throw GameError('需要一个空的深海槽位来安放海域');
        }
        final loc = locationMarket[mIdx];
        if (coins[seat] < loc.buyCost) {
          throw GameError('金币 (🪙) 不足，需要 ${loc.buyCost}🪙');
        }
        coins[seat] -= loc.buyCost;
        locationMarket.removeAt(mIdx);
        _refillMarket();
        depthSlots[seat][slot] = loc.copyWith(currentDepth: 0);
        score[seat] = calcScore(seat);
        turnActions++;
        lastAction =
            '${name(seat)} 花费 ${loc.buyCost}🪙 购买了海域「${loc.emoji}${loc.name}」';
        host.log(lastAction);

      case 'conquer_loc':
        final mIdx = asInt(action['marketIdx'], -1);
        if (mIdx < 0 || mIdx >= locationMarket.length) {
          throw GameError('无效的市场海域编号');
        }
        final slot = asInt(action['slot'], firstEmptySlot(seat));
        if (slot < 0 || slot >= numDepthSlots || depthSlots[seat][slot] != null) {
          throw GameError('需要一个空的深海槽位来安放海域');
        }
        final loc = locationMarket[mIdx];
        if (strength[seat] < loc.conquerCost) {
          throw GameError('战力 (⚔️) 不足，需要 ${loc.conquerCost}⚔️');
        }
        strength[seat] -= loc.conquerCost;
        locationMarket.removeAt(mIdx);
        _refillMarket();
        depthSlots[seat][slot] = loc.copyWith(currentDepth: 0);
        score[seat] = calcScore(seat);
        turnActions++;
        lastAction =
            '${name(seat)} 耗费 ${loc.conquerCost}⚔️ 征服了海域「${loc.emoji}${loc.name}」';
        host.log(lastAction);

      case 'rise':
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= numDepthSlots) {
          throw GameError('无效的深海槽位编号');
        }
        final loc = depthSlots[seat][slot];
        if (loc == null) {
          throw GameError('该深海槽位为空');
        }
        if (loc.currentDepth >= AquaticaLocationCard.maxDepth) {
          throw GameError('${loc.name} 已达最高深度，请执行计分收纳 (score_loc)');
        }
        if (freeRises[seat] <= 0) {
          throw GameError('没有可用的上升次数 (⬆️)');
        }
        freeRises[seat] -= 1;
        _riseLocationAt(seat, slot);
        final updated = depthSlots[seat][slot]!;
        turnActions++;
        lastAction =
            '${name(seat)} 将「${updated.emoji}${updated.name}」上升至深度 ${updated.currentDepth}/3';
        host.log(lastAction);

      case 'score_loc':
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= numDepthSlots) {
          throw GameError('无效的深海槽位编号');
        }
        final loc = depthSlots[seat][slot];
        if (loc == null) {
          throw GameError('该深海槽位为空');
        }
        if (loc.currentDepth < AquaticaLocationCard.maxDepth) {
          throw GameError(
              '${loc.name} 当前深度为 ${loc.currentDepth}/3，需升至满深度 3 才可计分收纳');
        }
        depthSlots[seat][slot] = null;
        vault[seat].add(loc);
        score[seat] = calcScore(seat);
        turnActions++;
        lastAction =
            '${name(seat)} 收纳满深度海域「${loc.emoji}${loc.name}」入宝库 (+${loc.vp}分)！';
        host.log(lastAction);

      case 'recall':
        hand[seat].addAll(playedCards[seat]);
        playedCards[seat].clear();
        for (var m = 0; m < numMantas; m++) {
          mantas[seat][m] = true;
        }
        freeRises[seat] += 1;
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 召回全部海洋角色卡并重置 4 枚蝠鲼！';
        host.log(lastAction);
        _advanceTurn();

      case 'end_turn':
        freeRises[seat] += 1;
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 结束回合';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    turnActions = 0;
    if (turn + 1 < players) {
      turn++;
      return;
    }
    turn = 0;
    if (round >= maxRounds || locationMarket.isEmpty) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '深海国度终局结算完成！总分最高的海洋领主获胜';
      host.log(lastAction);
      return;
    }
    round++;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // Cap actions per turn so bot always finishes its turn cleanly
    if (turnActions >= 5) {
      if (hand[seat].isEmpty && playedCards[seat].isNotEmpty) {
        return {'type': 'recall'};
      }
      return {'type': 'end_turn'};
    }

    // 1. Score any slotted location that has reached maxDepth (3)
    for (var s = 0; s < numDepthSlots; s++) {
      final loc = depthSlots[seat][s];
      if (loc != null && loc.currentDepth >= AquaticaLocationCard.maxDepth) {
        return {'type': 'score_loc', 'slot': s};
      }
    }

    // 2. Rise any slotted location if we have freeRises > 0
    if (freeRises[seat] > 0) {
      for (var s = 0; s < numDepthSlots; s++) {
        final loc = depthSlots[seat][s];
        if (loc != null && loc.currentDepth < AquaticaLocationCard.maxDepth) {
          return {'type': 'rise', 'slot': s};
        }
      }
    }

    // 3. Conquer or Buy a location into an empty depth slot if affordable
    final emptySlot = firstEmptySlot(seat);
    if (emptySlot >= 0 && locationMarket.isNotEmpty) {
      for (var m = 0; m < locationMarket.length; m++) {
        if (strength[seat] >= locationMarket[m].conquerCost) {
          return {'type': 'conquer_loc', 'marketIdx': m, 'slot': emptySlot};
        }
        if (coins[seat] >= locationMarket[m].buyCost) {
          return {'type': 'buy_loc', 'marketIdx': m, 'slot': emptySlot};
        }
      }
    }

    // 4. Flip a ready Manta Ray if needed
    for (var m = 0; m < numMantas; m++) {
      if (mantas[seat][m]) {
        return {'type': 'use_manta', 'manta': m};
      }
    }

    // 5. Play a character card from hand if we haven't acted much yet
    if (hand[seat].isNotEmpty && turnActions < 2) {
      return {'type': 'play_card', 'cardIdx': 0};
    }

    // 6. Recall if hand is empty, else end turn
    if (hand[seat].isEmpty && playedCards[seat].isNotEmpty) {
      return {'type': 'recall'};
    }
    return {'type': 'end_turn'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'locationMarket': [for (final loc in locationMarket) loc.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'vaultVp': calcVaultVp(s),
            'bonusVp': bonusVp[s],
            'coins': coins[s],
            'strength': strength[s],
            'freeRises': freeRises[s],
            'mantas': List<bool>.of(mantas[s]),
            'depthSlots': [
              for (final loc in depthSlots[s]) loc?.toJson(),
            ],
            'vault': [for (final loc in vault[s]) loc.toJson()],
            'handCount': hand[s].length,
            'hand': (s == seat || seat < 0 || over)
                ? [for (final c in hand[s]) c.toJson()]
                : const [],
            'playedCards': [for (final c in playedCards[s]) c.toJson()],
          },
      ],
    };
  }
}
