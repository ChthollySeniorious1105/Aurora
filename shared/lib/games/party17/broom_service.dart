import '../../src/engine.dart';

class BroomRoleInfo {
  final int id;
  final String name;
  final String emoji;
  final String braveDesc;
  final String cowardDesc;
  const BroomRoleInfo(this.id, this.name, this.emoji, this.braveDesc, this.cowardDesc);
}

const List<BroomRoleInfo> kBroomRoles = [
  BroomRoleInfo(0, '山地魔女', '🏔️', '飞抵山地高塔并交付魔药：+8分 +1🪄', '飞抵山地并小幅采集：+3分'),
  BroomRoleInfo(1, '森林魔女', '🌲', '飞抵森林高塔并交付魔药：+7分 +1🪄', '飞抵森林并小幅采集：+3分'),
  BroomRoleInfo(2, '丘陵魔女', '⛰️', '飞抵丘陵高塔并交付魔药：+7分 +1🪄', '飞抵丘陵并小幅采集：+3分'),
  BroomRoleInfo(3, '原野魔女', '🌾', '飞抵原野高塔并交付魔药：+6分 +1🪄', '飞抵原野并小幅采集：+3分'),
  BroomRoleInfo(4, '紫药德鲁伊', '🟪', '熬制 2 瓶紫魔药 +1🪄 +3分', '熬制 1 瓶紫魔药 +1分'),
  BroomRoleInfo(5, '橙药德鲁伊', '🟧', '熬制 2 瓶橙魔药 +1🪄 +3分', '熬制 1 瓶橙魔药 +1分'),
  BroomRoleInfo(6, '绿药德鲁伊', '🟩', '熬制 2 瓶绿魔药 +1🪄 +3分', '熬制 1 瓶绿魔药 +1分'),
  BroomRoleInfo(7, '天气仙子', '⛈️', '驱散雷暴云海：+6闪电分 +2🪄', '收集微风魔力：+2分 +1🪄'),
];

class BroomRegionInfo {
  final int id;
  final String name;
  final String emoji;
  final int potionType; // 0..2 or -1 for cloud
  final int baseVp;
  const BroomRegionInfo(this.id, this.name, this.emoji, this.potionType, this.baseVp);
}

const List<BroomRegionInfo> kBroomRegions = [
  BroomRegionInfo(0, '险峰高塔', '🏔️', 0, 8),
  BroomRegionInfo(1, '迷雾森林', '🌲', 2, 7),
  BroomRegionInfo(2, '翡翠丘陵', '⛰️', 1, 7),
  BroomRegionInfo(3, '黄金原野', '🌾', 1, 6),
  BroomRegionInfo(4, '雷暴云海', '🌩️', -1, 6),
  BroomRegionInfo(5, '狂风峡谷', '⛈️', -1, 6),
  BroomRegionInfo(6, '远古冰峰', '🏔️', 0, 9),
  BroomRegionInfo(7, '幽暗密林', '🌲', 2, 8),
];

class BroomServiceGame extends GameEngine {
  BroomServiceGame(super.setup);

  late int maxRounds;
  int round = 1;
  int trick = 1;
  String phase = 'select'; // 'select' | 'lead' | 'follow' | 'over'

  int leader = 0;
  int turn = 0;
  int ledRole = -1;
  int braveSeat = -1;

  /// Followers in clockwise order who hold ledRole and must play it this trick.
  List<int> followQueue = <int>[];

  /// Selected hand of Role Cards per seat (0..7).
  late List<List<int>> hands;
  late List<bool> selectedThisRound;

  /// Potions [purple, orange, green] per seat.
  late List<List<int>> potions;

  /// Magic Wands (🪄) per seat.
  late List<int> wands;

  /// Dispelled Storm Clouds count per seat.
  late List<int> clouds;

  /// Delivered towers count per seat.
  late List<int> deliveries;

  /// Current witch region (0..7) per seat.
  late List<int> witchRegion;

  /// Remaining tower deliveries / storm clouds on the 8 regions.
  late List<int> regionTokens;

  /// Scores per seat.
  late List<int> scores;

  /// History of plays in the current trick: [{seat, role, mode, cancelled}].
  List<Map<String, dynamic>> trickPlays = <Map<String, dynamic>>[];

  String lastEvent = '新的一轮开始：请从 8 张角色卡中挑选 4 张作为本轮手牌！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final totals = <num>[
      for (var s = 0; s < players; s++)
        scores[s] + wands[s] + potions[s][0] + potions[s][1] + potions[s][2],
    ];
    return rankByScore(totals);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (phase == 'select') {
      return [
        for (var s = 0; s < players; s++)
          if (!selectedThisRound[s]) s,
      ];
    }
    if (phase == 'lead' || phase == 'follow') {
      return [turn];
    }
    return const [];
  }

  @override
  void start() {
    final roundsOpt = setup.opt<int>('rounds', 6);
    maxRounds = roundsOpt == 4 ? 4 : 6;
    round = 1;
    trick = 1;
    leader = 0;
    turn = 0;
    ledRole = -1;
    braveSeat = -1;
    phase = 'select';

    hands = List.generate(players, (_) => <int>[]);
    selectedThisRound = List<bool>.filled(players, false);
    potions = List.generate(players, (_) => <int>[1, 1, 1]);
    wands = List<int>.filled(players, 2);
    clouds = List<int>.filled(players, 0);
    deliveries = List<int>.filled(players, 0);
    witchRegion = List<int>.filled(players, 3);
    regionTokens = <int>[3, 3, 3, 3, 3, 3, 2, 2];
    scores = List<int>.filled(players, 10);
    trickPlays = <Map<String, dynamic>>[];

    host.log('【魔女速递】游戏开始！共 $maxRounds 轮，请挑选本轮的 4 张角色卡。');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    final type = asStr(action['type']);

    if (phase == 'select') {
      if (type != 'select') throw GameError('当前处于选牌阶段，请提交 4 张角色卡');
      if (selectedThisRound[seat]) throw GameError('你已完成本轮选牌');
      final raw = asIntList(action['roles']);
      final unique = <int>{};
      for (final r in raw) {
        if (r >= 0 && r < 8) unique.add(r);
      }
      if (unique.length != 4) {
        throw GameError('必须从 0..7 中选择恰好 4 张不同的角色卡');
      }
      hands[seat] = unique.toList()..sort();
      selectedThisRound[seat] = true;

      if (selectedThisRound.every((x) => x)) {
        trick = 1;
        _startNextTrick();
      }
      return;
    }

    if (phase == 'lead' || phase == 'follow') {
      if (seat != turn) throw GameError('当前还未轮到你出牌');
      if (type != 'play') throw GameError('请打出角色卡（play）');
      final r = asInt(action['role']);
      final mode = asStr(action['mode']);
      if (mode != 'brave' && mode != 'coward') {
        throw GameError('必须选择勇敢（brave）或稳妥（coward）模式');
      }
      if (!hands[seat].contains(r)) {
        throw GameError('你手中没有这张角色卡');
      }
      if (phase == 'follow' && r != ledRole) {
        throw GameError('跟牌阶段必须打出领出角色：${kBroomRoles[ledRole].name}');
      }

      hands[seat].remove(r);

      if (phase == 'lead') {
        ledRole = r;
        braveSeat = -1;
        trickPlays = <Map<String, dynamic>>[];
        if (mode == 'coward') {
          final msg = _applyCowardEffect(seat, r);
          trickPlays.add({'seat': seat, 'role': r, 'mode': 'coward', 'cancelled': false});
          lastEvent = '${name(seat)} 领出 ${kBroomRoles[r].emoji}${kBroomRoles[r].name}【稳妥】：$msg';
        } else {
          braveSeat = seat;
          trickPlays.add({'seat': seat, 'role': r, 'mode': 'brave', 'cancelled': false});
          lastEvent = '${name(seat)} 领出 ${kBroomRoles[r].emoji}${kBroomRoles[r].name}【勇敢宣告】！等待持有同角色的玩家表态…';
        }
        host.log(lastEvent);

        // Build follow queue of subsequent seats in clockwise order who hold ledRole
        followQueue = <int>[];
        for (var i = 1; i < players; i++) {
          final s = (leader + i) % players;
          if (hands[s].contains(ledRole)) {
            followQueue.add(s);
          }
        }
        if (followQueue.isNotEmpty) {
          phase = 'follow';
          turn = followQueue.removeAt(0);
        } else {
          _finishTrick();
        }
        return;
      }

      // phase == 'follow'
      if (mode == 'coward') {
        final msg = _applyCowardEffect(seat, r);
        trickPlays.add({'seat': seat, 'role': r, 'mode': 'coward', 'cancelled': false});
        lastEvent = '${name(seat)} 跟出 ${kBroomRoles[r].emoji}${kBroomRoles[r].name}【稳妥】：$msg';
      } else {
        final prevBrave = braveSeat;
        for (final p in trickPlays) {
          if (p['seat'] == prevBrave && p['mode'] == 'brave') {
            p['cancelled'] = true;
          }
        }
        braveSeat = seat;
        trickPlays.add({'seat': seat, 'role': r, 'mode': 'brave', 'cancelled': false});
        if (prevBrave != -1) {
          lastEvent =
              '${name(seat)} 跟出 ${kBroomRoles[r].emoji}${kBroomRoles[r].name}【勇敢拦截】！${name(prevBrave)} 的勇敢宣告被截胡落空！';
        } else {
          lastEvent = '${name(seat)} 跟出 ${kBroomRoles[r].emoji}${kBroomRoles[r].name}【勇敢宣告】！';
        }
      }
      host.log(lastEvent);

      if (followQueue.isNotEmpty) {
        turn = followQueue.removeAt(0);
      } else {
        _finishTrick();
      }
      return;
    }

    throw GameError('未知阶段或操作');
  }

  String _applyCowardEffect(int seat, int role) {
    if (role >= 0 && role <= 3) {
      // Witch coward: move to region and gain +3 VP (plus spend 1 potion if available for +1 extra VP)
      witchRegion[seat] = role;
      final pType = kBroomRegions[role].potionType;
      if (pType >= 0 && potions[seat][pType] > 0) {
        potions[seat][pType] -= 1;
        scores[seat] += 4;
        return '飞抵${kBroomRegions[role].name}并顺路送药（+4分）';
      }
      scores[seat] += 3;
      return '飞抵${kBroomRegions[role].name}巡视（+3分）';
    }
    if (role >= 4 && role <= 6) {
      final p = role - 4;
      potions[seat][p] += 1;
      scores[seat] += 1;
      return '稳妥熬制 1 瓶魔药（+1分）';
    }
    // Weather Fairy coward
    wands[seat] += 1;
    scores[seat] += 2;
    return '收集 1 根魔法棒 🪄（+2分）';
  }

  String _applyBraveEffect(int seat, int role) {
    if (role >= 0 && role <= 3) {
      witchRegion[seat] = role;
      deliveries[seat] += 1;
      final reg = kBroomRegions[role];
      final pType = reg.potionType;
      wands[seat] += 1;
      if (regionTokens[role] > 0) regionTokens[role] -= 1;
      if (pType >= 0 && potions[seat][pType] > 0) {
        potions[seat][pType] -= 1;
        final vp = reg.baseVp;
        scores[seat] += vp;
        return '向${reg.name}高塔交付专属魔药，斩获 +$vp 分与 +1🪄！';
      }
      final anyIdx = potions[seat].indexWhere((c) => c > 0);
      if (anyIdx != -1) {
        potions[seat][anyIdx] -= 1;
        final vp = reg.baseVp - 1;
        scores[seat] += vp;
        return '向${reg.name}高塔交付魔药，收获 +$vp 分与 +1🪄！';
      }
      scores[seat] += 5;
      return '飞抵${reg.name}高塔完成特派速递（+5分 +1🪄）！';
    }
    if (role >= 4 && role <= 6) {
      final p = role - 4;
      potions[seat][p] += 2;
      wands[seat] += 1;
      scores[seat] += 3;
      return '勇敢熬制 2 瓶魔药 +1🪄 +3分！';
    }
    // Weather Fairy brave
    clouds[seat] += 1;
    wands[seat] += 2;
    if (regionTokens[4] > 0) {
      regionTokens[4] -= 1;
    } else if (regionTokens[5] > 0) {
      regionTokens[5] -= 1;
    }
    scores[seat] += 6;
    return '驱散雷暴云海 🌩️，赢得 +6 闪电分与 +2🪄！';
  }

  void _finishTrick() {
    if (braveSeat != -1) {
      final msg = _applyBraveEffect(braveSeat, ledRole);
      lastEvent = '✨【勇敢结算】${name(braveSeat)} 独享 ${kBroomRoles[ledRole].name} 勇敢奖励：$msg';
      host.log(lastEvent);
      leader = braveSeat;
    } else {
      lastEvent = '本墩无人宣告勇敢，由 ${name(leader)} 继续担任下一墩领出者。';
    }

    // Check if any player still has cards in hand
    final anyCards = hands.any((h) => h.isNotEmpty);
    if (!anyCards) {
      if (round >= maxRounds) {
        phase = 'over';
        // Add end-of-game bonuses for clouds and remaining resources
        for (var s = 0; s < players; s++) {
          scores[s] += clouds[s] * 2 + wands[s];
        }
        host.log('【魔女速递】全部 $maxRounds 轮结束！');
        return;
      }
      round += 1;
      trick = 1;
      phase = 'select';
      selectedThisRound = List<bool>.filled(players, false);
      ledRole = -1;
      braveSeat = -1;
      trickPlays = <Map<String, dynamic>>[];
      lastEvent = '第 $round / $maxRounds 轮开始：请选择 4 张角色卡！';
      host.log(lastEvent);
      return;
    }

    trick += 1;
    _startNextTrick();
  }

  void _startNextTrick() {
    // Ensure leader has at least 1 card in hand; otherwise advance clockwise
    for (var i = 0; i < players; i++) {
      final candidate = (leader + i) % players;
      if (hands[candidate].isNotEmpty) {
        leader = candidate;
        break;
      }
    }
    turn = leader;
    ledRole = -1;
    braveSeat = -1;
    phase = 'lead';
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    host.log('${name(seat)} 认输，游戏结束。');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || !waitingFor.contains(seat)) return null;

    if (phase == 'select') {
      final pool = [0, 1, 2, 3, 4, 5, 6, 7]..shuffle(rng);
      final chosen = pool.sublist(0, 4)..sort();
      return {'type': 'select', 'roles': chosen};
    }

    if (phase == 'lead') {
      final h = hands[seat];
      if (h.isEmpty) return null;
      final r = h[rng.nextInt(h.length)];
      // Leader has players after them who might cancel brave; pick brave ~55% of time
      final mode = rng.nextDouble() < 0.55 ? 'brave' : 'coward';
      return {'type': 'play', 'role': r, 'mode': mode};
    }

    if (phase == 'follow') {
      // If last in followQueue or braveSeat is already claimed, taking brave is very strong!
      final isLastFollower = followQueue.isEmpty;
      final mode = (isLastFollower || braveSeat != -1 || rng.nextDouble() < 0.65)
          ? 'brave'
          : 'coward';
      return {'type': 'play', 'role': ledRole, 'mode': mode};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'trick': trick,
      'phase': phase,
      'leader': leader,
      'turn': turn,
      'ledRole': ledRole,
      'braveSeat': braveSeat,
      'myHand': seat >= 0 && seat < players ? List<int>.of(hands[seat]) : const <int>[],
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'selectedThisRound': List<bool>.of(selectedThisRound),
      'potions': [for (var s = 0; s < players; s++) List<int>.of(potions[s])],
      'wands': List<int>.of(wands),
      'clouds': List<int>.of(clouds),
      'deliveries': List<int>.of(deliveries),
      'witchRegion': List<int>.of(witchRegion),
      'regionTokens': List<int>.of(regionTokens),
      'scores': List<int>.of(scores),
      'trickPlays': [for (final p in trickPlays) Map<String, dynamic>.of(p)],
      'lastEvent': lastEvent,
      'canAct': seat >= 0 && waitingFor.contains(seat),
    };
  }
}
