import 'dart:math';

import '../../src/engine.dart';

class MarbleColorInfo {
  final int id;
  final String name;
  final String emoji;
  const MarbleColorInfo(this.id, this.name, this.emoji);
}

const List<MarbleColorInfo> kMarbleColors = [
  MarbleColorInfo(0, '龙烟', '🔴'),
  MarbleColorInfo(1, '仙泪', '🔵'),
  MarbleColorInfo(2, '星尘', '🟡'),
  MarbleColorInfo(3, '魔液', '⚫'),
];

class PotionTemplate {
  final int type;
  final String name;
  final String emoji;
  final int vp;
  final List<int> need; // [red, blue, yellow, black]
  final String drinkDesc;
  const PotionTemplate(
    this.type,
    this.name,
    this.emoji,
    this.vp,
    this.need,
    this.drinkDesc,
  );
}

const List<PotionTemplate> kPotionTemplates = [
  PotionTemplate(0, '智慧灵药', '🧪', 4, [1, 1, 1, 0], '饮用：从1号轨道底端额外摄取1颗弹珠并+1分'),
  PotionTemplate(1, '爆裂魔药', '🔥', 6, [2, 0, 1, 1], '饮用：从当前各轨道底端摄取最多2颗弹珠'),
  PotionTemplate(2, '冰霜仙露', '❄️', 7, [0, 2, 2, 0], '饮用：盲抽2颗弹珠注入烧瓶并+2炼金分'),
  PotionTemplate(3, '雷霆秘药', '⚡', 8, [1, 1, 2, 1], '饮用：为当前1瓶药水自动补满最多2颗所需弹珠'),
  PotionTemplate(4, '星界甘露', '🌟', 9, [2, 1, 0, 2], '饮用：夺取对手烧瓶池1颗弹珠（若无则盲抽1颗）并+2分'),
  PotionTemplate(5, '贤者圣水', '👑', 10, [1, 2, 1, 2], '饮用：直接获得+3炼金分并补满1颗所需弹珠'),
];

class PotionExplosionGame extends GameEngine {
  PotionExplosionGame(super.setup);

  late int targetSkillTokens;
  late int skillTokensLeft;
  int round = 1;
  int turn = 0;
  String phase = 'act'; // 'act' | 'over'

  /// 5-Lane Marble Dispenser: lanes[0..4], each holding 5 marbles of colors 0..3.
  late List<List<int>> lanes;

  /// Marble supply bag.
  late List<int> bag;

  /// 2 Active Potion Flasks per player: potions[seat][0..1].
  /// Each flask is {'type': int, 'name': String, 'emoji': String, 'vp': int, 'need': [c0,c1,c2,c3], 'filled': [c0,c1,c2,c3], 'desc': String}.
  late List<List<Map<String, dynamic>>> potions;

  /// Retort overflow pool per player (up to 3 marbles).
  late List<List<int>> pool;

  /// Completed potions per player: [{'type': int, 'name': String, 'emoji': String, 'vp': int, 'drunk': bool}].
  late List<List<Map<String, dynamic>>> completedPotions;

  /// Completed potion counts by type (0..5) per player.
  late List<List<int>> completedByType;

  /// Track whether seat already earned the 3-of-a-kind skill token for type t.
  late List<List<bool>> sameTypeAwarded;

  /// Track whether seat already earned the 5-distinct-types skill token.
  late List<bool> fiveDistinctAwarded;

  /// Professor Skill Tokens earned per player (+4 VP each).
  late List<int> skillTokens;

  /// Total scores per player.
  late List<int> scores;

  /// Last pick chain-reaction analytics.
  List<int> lastCollected = <int>[];
  int lastExplosions = 0;
  String lastEvent = '炼金考核开始！从 5 条轨道中拿取 1 颗弹珠触发同色碰撞连环爆炸！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final adjusted = <num>[
      for (var s = 0; s < players; s++)
        scores[s] * 100 + completedPotions[s].length * 10 + pool[s].length,
    ];
    return rankByScore(adjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [turn];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    targetSkillTokens = mode == 'fast' ? 4 : 6;
    skillTokensLeft = targetSkillTokens;
    round = 1;
    turn = 0;
    phase = 'act';

    bag = <int>[];
    _refillBag(80);

    lanes = List.generate(5, (_) => <int>[for (var i = 0; i < 5; i++) _drawFromBag()]);

    potions = [
      for (var s = 0; s < players; s++)
        [
          _drawNewPotion(),
          _drawNewPotion(),
        ],
    ];
    pool = [for (var s = 0; s < players; s++) <int>[]];
    completedPotions = [for (var s = 0; s < players; s++) <Map<String, dynamic>>[]];
    completedByType = [for (var s = 0; s < players; s++) List<int>.filled(6, 0)];
    sameTypeAwarded = [for (var s = 0; s < players; s++) List<bool>.filled(6, false)];
    fiveDistinctAwarded = List<bool>.filled(players, false);
    skillTokens = List<int>.filled(players, 0);
    scores = List<int>.filled(players, 0);
    lastCollected = <int>[];
    lastExplosions = 0;
    lastEvent = '魔法药水大爆炸开局！拿取 1 颗弹珠，若上下滑落的相邻弹珠同色即刻引发连环大爆炸！';
    host.log('【魔法药水大爆炸】炼金课堂开启！5 条弹珠轨道已装填完毕。');
  }

  void _refillBag([int count = 60]) {
    final extra = <int>[];
    for (var i = 0; i < count; i++) {
      extra.add(i % 4);
    }
    extra.shuffle(rng);
    bag.addAll(extra);
  }

  int _drawFromBag() {
    if (bag.isEmpty) {
      _refillBag(48);
    }
    return bag.removeLast();
  }

  Map<String, dynamic> _drawNewPotion([int? forceType]) {
    final t = forceType ?? rng.nextInt(kPotionTemplates.length);
    final tpl = kPotionTemplates[t % kPotionTemplates.length];
    return {
      'type': tpl.type,
      'name': tpl.name,
      'emoji': tpl.emoji,
      'vp': tpl.vp,
      'need': List<int>.of(tpl.need),
      'filled': <int>[0, 0, 0, 0],
      'desc': tpl.drinkDesc,
    };
  }

  /// Simulate picking (lane, idx) on a copy of lanes[lane] and return (collectedMarbles, explosionCount).
  (List<int>, int) previewPick(int lane, int idx) {
    if (lane < 0 || lane >= 5) return (const <int>[], 0);
    final work = List<int>.of(lanes[lane]);
    if (idx < 0 || idx >= work.length) return (const <int>[], 0);

    final collected = <int>[work.removeAt(idx)];
    var explosions = 0;
    var gap = idx;

    while (gap > 0 && gap < work.length && work[gap - 1] == work[gap]) {
      explosions++;
      final c = work[gap];
      var left = gap - 1;
      while (left > 0 && work[left - 1] == c) {
        left--;
      }
      var right = gap;
      while (right + 1 < work.length && work[right + 1] == c) {
        right++;
      }
      for (var k = left; k <= right; k++) {
        collected.add(work[k]);
      }
      work.removeRange(left, right + 1);
      gap = left;
    }

    return (collected, explosions);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);
    if (type == 'drink') {
      // Allow drinking an undrunk completed potion on your turn or immediately after completing one
      _handleDrink(seat, action);
      return;
    }

    if (seat != turn) throw GameError('还没轮到你行动');
    if (type == 'pick') {
      _handlePick(seat, action);
    } else {
      throw GameError('未知操作：$type');
    }
  }

  void _handlePick(int seat, Map<String, dynamic> action) {
    final l = asInt(action['lane'], -1);
    final i = asInt(action['idx'], -1);
    if (l < 0 || l >= 5) throw GameError('轨道编号必须在 0~4 之间');
    if (i < 0 || i >= lanes[l].length) throw GameError('弹珠位置必须在 0~${lanes[l].length - 1} 之间');

    final collected = <int>[lanes[l].removeAt(i)];
    var explosions = 0;
    var gap = i;

    // Chain-Reaction Explosion Rule:
    // Check if the marble immediately before gap (gap - 1) and the marble at gap have the EXACT SAME color c
    while (gap > 0 && gap < lanes[l].length && lanes[l][gap - 1] == lanes[l][gap]) {
      explosions++;
      final c = lanes[l][gap];
      var left = gap - 1;
      while (left > 0 && lanes[l][left - 1] == c) {
        left--;
      }
      var right = gap;
      while (right + 1 < lanes[l].length && lanes[l][right + 1] == c) {
        right++;
      }
      for (var k = left; k <= right; k++) {
        collected.add(lanes[l][k]);
      }
      lanes[l].removeRange(left, right + 1);
      gap = left;
    }

    // Refill top of lanes[l] from the bag only after all chain explosions finish
    while (lanes[l].length < 5) {
      lanes[l].insert(0, _drawFromBag());
    }

    lastCollected = List<int>.of(collected);
    lastExplosions = explosions;

    final completedNames = _allocateMarblesToPlayer(seat, collected);
    final marbleStr = collected.map((c) => kMarbleColors[c].emoji).join();
    final boomText = explosions > 0 ? '引发 $explosions 次连环大爆炸💥，' : '';
    final brewText = completedNames.isNotEmpty ? '，炼成【${completedNames.join("、")}】！' : '';
    lastEvent = '${name(seat)} 在第 ${l + 1} 轨拿取弹珠，${boomText}共获 ${collected.length} 颗 ($marbleStr)$brewText';
    host.log(lastEvent);

    _advanceTurn();
  }

  List<String> _allocateMarblesToPlayer(int seat, List<int> newMarbles) {
    final allMarbles = <int>[...pool[seat], ...newMarbles];
    pool[seat].clear();
    final leftovers = <int>[];
    final completedNames = <String>[];

    for (final c in allMarbles) {
      if (c < 0 || c >= 4) continue;
      var placed = false;
      for (var pIdx = 0; pIdx < potions[seat].length; pIdx++) {
        final flask = potions[seat][pIdx];
        final need = (flask['need'] as List).cast<int>();
        final filled = (flask['filled'] as List).cast<int>();
        if (filled[c] < need[c]) {
          filled[c]++;
          placed = true;
          if (_isFlaskComplete(need, filled)) {
            final pName = _completeFlask(seat, pIdx);
            completedNames.add(pName);
          }
          break;
        }
      }
      if (!placed) {
        leftovers.add(c);
      }
    }

    // Re-try leftovers in case a newly drawn potion needs them
    final finalOverflow = <int>[];
    for (final c in leftovers) {
      var placed = false;
      for (var pIdx = 0; pIdx < potions[seat].length; pIdx++) {
        final flask = potions[seat][pIdx];
        final need = (flask['need'] as List).cast<int>();
        final filled = (flask['filled'] as List).cast<int>();
        if (filled[c] < need[c]) {
          filled[c]++;
          placed = true;
          if (_isFlaskComplete(need, filled)) {
            final pName = _completeFlask(seat, pIdx);
            completedNames.add(pName);
          }
          break;
        }
      }
      if (!placed) {
        finalOverflow.add(c);
      }
    }

    // Up to 3 overflow marbles in Retort Pool
    for (final c in finalOverflow) {
      if (pool[seat].length < 3) {
        pool[seat].add(c);
      } else {
        bag.insert(0, c);
      }
    }

    return completedNames;
  }

  bool _isFlaskComplete(List<int> need, List<int> filled) {
    for (var c = 0; c < 4; c++) {
      if (filled[c] < need[c]) return false;
    }
    return true;
  }

  String _completeFlask(int seat, int slotIdx) {
    final flask = potions[seat][slotIdx];
    final type = (flask['type'] as num).toInt();
    final vp = (flask['vp'] as num).toInt();
    final pName = '${flask['emoji']}${flask['name']}';

    scores[seat] += vp;
    completedPotions[seat].add({
      'type': type,
      'name': flask['name'],
      'emoji': flask['emoji'],
      'vp': vp,
      'drunk': false,
    });
    if (type >= 0 && type < completedByType[seat].length) {
      completedByType[seat][type]++;
    }

    checkProfessorSkillTokens(seat);
    potions[seat][slotIdx] = _drawNewPotion();
    return pName;
  }

  /// Check & award Professor Skill Tokens (+4 VP for 3 of same type or 5 distinct types).
  void checkProfessorSkillTokens(int seat) {
    for (var t = 0; t < completedByType[seat].length; t++) {
      if (completedByType[seat][t] >= 3 && !sameTypeAwarded[seat][t]) {
        sameTypeAwarded[seat][t] = true;
        _awardSkillToken(seat, '同系药水专精(3瓶)');
      }
    }
    final distinctTypes = completedByType[seat].where((cnt) => cnt > 0).length;
    if (distinctTypes >= 5 && !fiveDistinctAwarded[seat]) {
      fiveDistinctAwarded[seat] = true;
      _awardSkillToken(seat, '五系博学炼金(5种)');
    }
  }

  void _awardSkillToken(int seat, String reason) {
    skillTokens[seat]++;
    scores[seat] += 4;
    if (skillTokensLeft > 0) {
      skillTokensLeft--;
    }
    host.log('🎓 ${name(seat)} 达成【$reason】，荣获教授技能奖章 (+4 VP)！');
  }

  void _handleDrink(int seat, Map<String, dynamic> action) {
    final pIdx = asInt(action['potionIdx'], 0);

    // If a test directly filled potions[seat][pIdx] to full without triggering _completeFlask yet, complete it first
    if (pIdx >= 0 && pIdx < potions[seat].length) {
      final flask = potions[seat][pIdx];
      final need = (flask['need'] as List).cast<int>();
      final filled = (flask['filled'] as List).cast<int>();
      if (_isFlaskComplete(need, filled)) {
        _completeFlask(seat, pIdx);
      }
    }

    Map<String, dynamic>? targetPotion;
    if (pIdx >= 0 &&
        pIdx < completedPotions[seat].length &&
        completedPotions[seat][pIdx]['drunk'] != true) {
      targetPotion = completedPotions[seat][pIdx];
    } else {
      for (final cp in completedPotions[seat]) {
        if (cp['drunk'] != true) {
          targetPotion = cp;
          break;
        }
      }
    }

    if (targetPotion == null) {
      throw GameError('没有尚未饮用的已完成药水');
    }

    targetPotion['drunk'] = true;
    final pType = (targetPotion['type'] as num?)?.toInt() ?? 0;
    final pTitle = '${targetPotion['emoji'] ?? '🧪'}${targetPotion['name'] ?? '魔药'}';

    final bonusMarbles = <int>[];
    var bonusVp = 0;

    switch (pType) {
      case 0: // 智慧灵药
        final m = lanes[0].removeLast();
        lanes[0].insert(0, _drawFromBag());
        bonusMarbles.add(m);
        bonusVp = 1;
        break;
      case 1: // 爆裂魔药
        for (var l = 0; l < 2; l++) {
          final m = lanes[l].removeLast();
          lanes[l].insert(0, _drawFromBag());
          bonusMarbles.add(m);
        }
        bonusVp = 1;
        break;
      case 2: // 冰霜仙露
        bonusMarbles.add(_drawFromBag());
        bonusMarbles.add(_drawFromBag());
        bonusVp = 2;
        break;
      case 3: // 雷霆秘药
        for (final flask in potions[seat]) {
          final need = (flask['need'] as List).cast<int>();
          final filled = (flask['filled'] as List).cast<int>();
          for (var c = 0; c < 4 && bonusMarbles.length < 2; c++) {
            if (filled[c] < need[c]) {
              bonusMarbles.add(c);
            }
          }
        }
        if (bonusMarbles.isEmpty) bonusMarbles.add(_drawFromBag());
        bonusVp = 1;
        break;
      case 4: // 星界甘露
        var stolen = -1;
        for (var s = 0; s < players; s++) {
          if (s != seat && pool[s].isNotEmpty) {
            stolen = pool[s].removeLast();
            break;
          }
        }
        bonusMarbles.add(stolen >= 0 ? stolen : _drawFromBag());
        bonusVp = 2;
        break;
      default: // 贤者圣水
        for (final flask in potions[seat]) {
          final need = (flask['need'] as List).cast<int>();
          final filled = (flask['filled'] as List).cast<int>();
          for (var c = 0; c < 4; c++) {
            if (filled[c] < need[c]) {
              bonusMarbles.add(c);
              break;
            }
          }
          if (bonusMarbles.isNotEmpty) break;
        }
        bonusVp = 3;
        break;
    }

    scores[seat] += bonusVp;
    _allocateMarblesToPlayer(seat, bonusMarbles);
    lastEvent = '🥂 ${name(seat)} 一饮而尽【$pTitle】，获得药效加成 (+$bonusVp VP 及额外弹珠)！';
    host.log(lastEvent);
    _checkEndCondition();
  }

  void _checkEndCondition() {
    final maxRounds = targetSkillTokens == 4 ? 10 : 14;
    if (skillTokensLeft <= 0 || round > maxRounds) {
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent = '🏆 炼金毕业典礼结束！${name(bestSeat)} 以 ${scores[bestSeat]} 分夺得首席炼金术士桂冠！';
      host.log(lastEvent);
    }
  }

  void _advanceTurn() {
    final next = (turn + 1) % players;
    if (next == 0) {
      round++;
    }
    turn = next;
    _checkEndCondition();
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'turn': turn,
      'phase': phase,
      'skillTokensLeft': skillTokensLeft,
      'targetSkillTokens': targetSkillTokens,
      'lanes': [
        for (final lane in lanes) List<int>.of(lane),
      ],
      'potions': [
        for (var s = 0; s < players; s++)
          [
            for (final p in potions[s])
              {
                'type': p['type'],
                'name': p['name'],
                'emoji': p['emoji'],
                'vp': p['vp'],
                'need': List<int>.of((p['need'] as List).cast<int>()),
                'filled': List<int>.of((p['filled'] as List).cast<int>()),
                'desc': p['desc'],
              },
          ],
      ],
      'pool': [
        for (final p in pool) List<int>.of(p),
      ],
      'completedPotions': [
        for (final cpList in completedPotions)
          [
            for (final cp in cpList) Map<String, dynamic>.of(cp),
          ],
      ],
      'completedByType': [
        for (final row in completedByType) List<int>.of(row),
      ],
      'skillTokens': List<int>.of(skillTokens),
      'scores': List<int>.of(scores),
      'lastCollected': List<int>.of(lastCollected),
      'lastExplosions': lastExplosions,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    // 1. Drink any undrunk completed potion first for free bonus marbles & VP
    for (var i = 0; i < completedPotions[seat].length; i++) {
      if (completedPotions[seat][i]['drunk'] != true) {
        return {'type': 'drink', 'potionIdx': i};
      }
    }

    // 2. Evaluate all 25 (lane, idx) picks and choose the one that maximizes needed marbles & explosions
    final neededColors = <int>[0, 0, 0, 0];
    for (final flask in potions[seat]) {
      final need = (flask['need'] as List).cast<int>();
      final filled = (flask['filled'] as List).cast<int>();
      for (var c = 0; c < 4; c++) {
        neededColors[c] += max(0, need[c] - filled[c]);
      }
    }

    var bestLane = 0;
    var bestIdx = 0;
    var bestVal = -1;

    for (var l = 0; l < 5; l++) {
      for (var i = 0; i < lanes[l].length; i++) {
        final (collected, explosions) = previewPick(l, i);
        final tempNeed = List<int>.of(neededColors);
        var useful = 0;
        for (final c in collected) {
          if (tempNeed[c] > 0) {
            tempNeed[c]--;
            useful += 3;
          } else {
            useful += 1;
          }
        }
        final val = useful * 10 + explosions * 8 + rng.nextInt(3);
        if (val > bestVal) {
          bestVal = val;
          bestLane = l;
          bestIdx = i;
        }
      }
    }

    return {'type': 'pick', 'lane': bestLane, 'idx': bestIdx};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -999;
    phase = 'over';
    lastEvent = '${name(seat)} 退出了炼金考场，游戏结束！';
    host.log(lastEvent);
  }
}
