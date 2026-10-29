import 'dart:math';

import '../../src/engine.dart';

const List<String> kMysteriumSuspects = [
  '🎩 魔术师·红礼帽',
  '🤡 小丑·彩球',
  '🦁 驯兽师·金鞭',
  '🎪 空中飞人·蓝羽',
  '🔮 占卜师·紫水晶',
  '🗡️ 飞刀手·银刃',
  '🔥 吞火者·烈焰',
  '🎭 哑剧演员·白面',
  '🥁 乐队指挥·绿礼服',
];

const List<String> kMysteriumLocations = [
  '⛺ 主帐篷·红顶',
  '🎡 摩天轮·彩灯',
  '🦁 猛兽笼·金锁',
  '🎠 旋转木马·蓝顶',
  '🔮 占卜篷车·紫帘',
  '🎯 飞镖摊·银靶',
  '🍿 爆米花车·火炉',
  '🪞 哈哈镜迷宫·白镜',
  '🎟️ 售票亭·绿窗',
];

const List<String> kMysteriumVisions = [
  '🌹 猩红玫瑰与高帽',
  '🎈 彩绘气球与笑脸',
  '👑 黄金狮爪与锁链',
  '🕊️ 蔚蓝飞鸟与秋千',
  '🌙 紫夜星辰与水晶',
  '⚡ 寒光利刃与标靶',
  '🔥 炽热火炬与浓烟',
  '🪞 苍白假面与镜影',
  '🎺 翠绿号角与节拍',
  '🩸 暗红丝绒与魔杖',
  '🌟 金黄彩带与滚球',
  '🐯 咆哮猛虎与铁笼',
  '☁️ 高空云梯与蓝羽',
  '🕯️ 神秘紫烛与塔罗',
  '🗡️ 旋转银刀与木牌',
  '💥 爆裂火星与铜炉',
  '🎭 双面石膏与迷廊',
  '🥁 盛装乐鼓与绿帐',
];

class MysteriumParkGame extends GameEngine {
  MysteriumParkGame(super.setup);

  int guideSeat = 0;
  int stage = 1; // 1: Suspects, 2: Locations, 3: Finale
  String phase = 'clue'; // 'clue', 'guess', 'finale', 'over'
  int turnUsed = 1;
  int maxTurns = 6;

  List<int> suspects = [0, 1, 2, 3, 4, 5, 6, 7, 8];
  List<int> locations = [0, 1, 2, 3, 4, 5, 6, 7, 8];

  int witnessSlot = 0;
  late List<int> targetSlot; // targetSlot[seat] in 0..8 for psychics
  late List<bool> gridCleared; // gridCleared[0..8]
  late List<bool> stageSolved; // stageSolved[seat]
  late List<int?> currentClue; // currentClue[seat] vision id
  late List<int?> currentGuess; // currentGuess[seat] slot 0..8
  late List<int> solvedSuspect; // solvedSuspect[seat]
  late List<int> solvedLocation; // solvedLocation[seat]

  List<int> guideHand = [];
  List<int> visionDeck = [];

  // Round 3 ('finale') state
  List<Map<String, int>> finaleCandidates = []; // 3 pairs of {'suspect': s, 'location': l}
  int finaleCulprit = 0; // 0..2
  List<int> finaleClues = []; // 3 vision cards
  late List<int?> votes; // votes[seat] in 0..2
  bool teamWon = false;

  late List<int> scores;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'clue') {
      return [guideSeat];
    }
    if (phase == 'guess') {
      return [
        for (var s = 0; s < players; s++)
          if (s != guideSeat && !stageSolved[s] && currentGuess[s] == null) s,
      ];
    }
    if (phase == 'finale') {
      return [
        for (var s = 0; s < players; s++)
          if (votes[s] == null) s,
      ];
    }
    return const [];
  }

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    maxTurns = fast ? 5 : 6;
    guideSeat = 0;
    turnUsed = 1;
    scores = List<int>.filled(players, 0);
    solvedSuspect = List<int>.filled(players, 0);
    solvedLocation = List<int>.filled(players, 0);
    votes = List<int?>.filled(players, null);
    teamWon = false;
    _over = false;

    suspects = [for (var i = 0; i < 9; i++) i];
    locations = [for (var i = 0; i < 9; i++) i];

    _refillVisionDeck();
    guideHand = [for (var i = 0; i < 7; i++) _drawVision()];

    _startStage(1);
    lastEvent =
        '🎪 诡秘马戏团开幕！${name(guideSeat)} 担任馆长幽灵，第 1 轮（调查 9 名嫌疑人）开始！';
    host.log(lastEvent);
  }

  void _refillVisionDeck() {
    visionDeck = shuffled([for (var i = 0; i < kMysteriumVisions.length; i++) i], rng);
  }

  int _drawVision() {
    if (visionDeck.isEmpty) _refillVisionDeck();
    return visionDeck.removeLast();
  }

  void _startStage(int newStage) {
    stage = newStage;
    phase = 'clue';
    gridCleared = List<bool>.filled(9, false);
    stageSolved = [for (var s = 0; s < players; s++) s == guideSeat];
    currentClue = List<int?>.filled(players, null);
    currentGuess = List<int?>.filled(players, null);

    final slots = shuffled([for (var i = 0; i < 9; i++) i], rng);
    witnessSlot = slots[0];
    targetSlot = List<int>.filled(players, 0);
    var idx = 1;
    for (var s = 0; s < players; s++) {
      if (s == guideSeat) continue;
      targetSlot[s] = slots[idx++];
    }
    _ensureGuideHasMatchingVisions();
  }

  void _ensureGuideHasMatchingVisions() {
    for (var s = 0; s < players; s++) {
      if (s == guideSeat || stageSolved[s]) continue;
      final tSlot = targetSlot[s];
      final cardId = stage == 1 ? suspects[tSlot] : locations[tSlot];
      if (!guideHand.any((v) => v % 9 == cardId)) {
        if (guideHand.isNotEmpty) {
          guideHand[0] = cardId;
        } else {
          guideHand.add(cardId);
        }
      }
    }
  }

  void _startFinale() {
    stage = 3;
    phase = 'finale';
    votes = List<int?>.filled(players, null);

    // Build 3 Final Suspect + Location pairs
    final usedSuspects = <int>[];
    final usedLocations = <int>[];
    for (var s = 0; s < players; s++) {
      if (s == guideSeat) continue;
      if (!usedSuspects.contains(solvedSuspect[s])) {
        usedSuspects.add(solvedSuspect[s]);
      }
      if (!usedLocations.contains(solvedLocation[s])) {
        usedLocations.add(solvedLocation[s]);
      }
    }
    for (var i = 0; i < 9 && usedSuspects.length < 3; i++) {
      if (!usedSuspects.contains(suspects[i])) usedSuspects.add(suspects[i]);
    }
    for (var i = 0; i < 9 && usedLocations.length < 3; i++) {
      if (!usedLocations.contains(locations[i])) usedLocations.add(locations[i]);
    }

    finaleCandidates = [
      for (var i = 0; i < 3; i++)
        {
          'suspect': usedSuspects[i],
          'location': usedLocations[i],
        },
    ];
    finaleCulprit = rng.nextInt(3);
    final culpritPair = finaleCandidates[finaleCulprit];
    finaleClues = [
      culpritPair['suspect']!,
      9 + culpritPair['location']!,
      (culpritPair['suspect']! + 9) % kMysteriumVisions.length,
    ];
    lastEvent =
        '🔮 进入第 3 轮【终局推理】！3 组最终嫌犯+地点组合已锁定，请全体玩家根据 3 张终局幻景线索投票指认最终真凶！';
    host.log(lastEvent);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'clue') {
      if (seat != guideSeat) throw GameError('当前由幽灵馆长给出幻景线索卡');
      if (type != 'clue') throw GameError('请打出幻景线索卡 (clue)');

      var targetPsychic = asInt(action['seat'], -1);
      if (targetPsychic < 0) {
        targetPsychic = [
          for (var s = 0; s < players; s++)
            if (s != guideSeat && !stageSolved[s] && currentClue[s] == null) s,
        ].firstOrNull ??
            -1;
      }
      if (targetPsychic <= 0 ||
          targetPsychic >= players ||
          targetPsychic == guideSeat ||
          stageSolved[targetPsychic]) {
        throw GameError('无效的通灵师目标座位');
      }

      final vision = asInt(action['vision'], 0);
      if (vision < 0 || vision >= kMysteriumVisions.length) {
        throw GameError('无效的幻景卡编号');
      }

      currentClue[targetPsychic] = vision;
      final handIdx = guideHand.indexOf(vision);
      if (handIdx >= 0) {
        guideHand.removeAt(handIdx);
        guideHand.add(_drawVision());
      }

      lastEvent =
          '👻 幽灵馆长向 ${name(targetPsychic)} 揭示了幻景线索：【${kMysteriumVisions[vision]}】';
      host.log(lastEvent);

      final allClued = [
        for (var s = 0; s < players; s++)
          if (s != guideSeat && !stageSolved[s]) s,
      ].every((s) => currentClue[s] != null);

      if (allClued) {
        phase = 'guess';
        currentGuess = List<int?>.filled(players, null);
        lastEvent =
            '🔮 所有幻景线索已发放！请各位通灵师在 3×3 调查矩阵上放置水晶球猜测（猜中 👁️ 目击者可立即重猜）！';
        host.log(lastEvent);
      }
      return;
    }

    if (phase == 'guess') {
      if (seat == guideSeat || stageSolved[seat] || currentGuess[seat] != null) {
        throw GameError('当前不需要你放置水晶球');
      }
      if (type != 'guess') throw GameError('请放置水晶球猜测位置 (guess)');

      final slot = asInt(action['slot'], -1);
      if (slot < 0 || slot >= 9) throw GameError('位置必须在 0~8 之间');
      if (gridCleared[slot]) throw GameError('该位置的卡牌已被排除');
      if (currentGuess.contains(slot)) {
        throw GameError('该位置已有其他通灵师放置了水晶球');
      }

      // Check Innocent Witness!
      if (slot == witnessSlot) {
        gridCleared[slot] = true;
        scores[seat] += 2;
        scores[guideSeat] += 1;
        lastEvent =
            '👁️ ${name(seat)} 发现了无辜目击者（位置 ${slot + 1}）！目击者已被排除 (+2分)，请 ${name(seat)} 立即重新猜测！';
        host.log(lastEvent);
        return;
      }

      currentGuess[seat] = slot;
      final cardName = stage == 1
          ? kMysteriumSuspects[suspects[slot]]
          : kMysteriumLocations[locations[slot]];
      lastEvent = '${name(seat)} 将水晶球放在了位置 ${slot + 1}（$cardName）。';
      host.log(lastEvent);

      if (waitingFor.isEmpty) {
        _resolveGuessesEndOfTurn();
      }
      return;
    }

    if (phase == 'finale') {
      if (type != 'vote') throw GameError('终局阶段请投票指认凶手组合 (vote)');
      if (votes[seat] != null) throw GameError('你已经投过票了');

      final cand = asInt(action['candidate'], -1);
      if (cand < 0 || cand >= 3) throw GameError('候选编号必须在 0~2 之间');
      votes[seat] = cand;
      lastEvent = '${name(seat)} 完成了终局秘投！';
      host.log(lastEvent);

      if (waitingFor.isEmpty) {
        _resolveFinale();
      }
      return;
    }

    throw GameError('未知阶段：$phase');
  }

  void _resolveGuessesEndOfTurn() {
    final correctNames = <String>[];
    final wrongNames = <String>[];

    for (var s = 0; s < players; s++) {
      if (s == guideSeat || stageSolved[s]) continue;
      final gSlot = currentGuess[s];
      if (gSlot == null) continue;

      if (gSlot == targetSlot[s]) {
        stageSolved[s] = true;
        gridCleared[gSlot] = true;
        if (stage == 1) {
          solvedSuspect[s] = suspects[gSlot];
        } else {
          solvedLocation[s] = locations[gSlot];
        }
        final bonus = 4 + max<int>(1, maxTurns - turnUsed + 1);
        scores[s] += bonus;
        scores[guideSeat] += 3;
        correctNames.add('${name(s)}(+$bonus分)');
      } else {
        wrongNames.add(name(s));
        // Eliminate false card from 3x3 grid unless it is another psychic's unsolved target
        final isAnotherTarget = [
          for (var other = 0; other < players; other++)
            if (other != guideSeat && !stageSolved[other] && targetSlot[other] == gSlot) other,
        ].isNotEmpty;
        if (!isAnotherTarget) {
          gridCleared[gSlot] = true;
        }
      }
    }

    final allSolved = [
      for (var s = 0; s < players; s++)
        if (s != guideSeat) stageSolved[s],
    ].every((b) => b);

    if (allSolved) {
      if (stage == 1) {
        _startStage(2);
        lastEvent =
            '✨ 全员成功锁定嫌疑人（${correctNames.join("、")}）！进入第 2 轮：调查 9 处马戏团案发地点！';
        host.log(lastEvent);
      } else {
        _startFinale();
      }
      return;
    }

    turnUsed++;
    if (turnUsed > maxTurns) {
      // Auto-complete remaining targets so Finale is reached
      for (var s = 0; s < players; s++) {
        if (s == guideSeat || stageSolved[s]) continue;
        stageSolved[s] = true;
        if (stage == 1) {
          solvedSuspect[s] = suspects[targetSlot[s]];
        } else {
          solvedLocation[s] = locations[targetSlot[s]];
        }
      }
      if (stage == 1) {
        turnUsed = maxTurns;
        _startStage(2);
        lastEvent = '⏰ 第 1 轮回合耗尽，进入第 2 轮马戏团地点调查！';
        host.log(lastEvent);
      } else {
        _startFinale();
      }
      return;
    }

    // Next turn in current stage
    phase = 'clue';
    currentClue = List<int?>.filled(players, null);
    currentGuess = List<int?>.filled(players, null);
    _ensureGuideHasMatchingVisions();
    lastEvent =
        '第 ${turnUsed - 1} 回合结算：猜中 [${correctNames.isEmpty ? "无" : correctNames.join("、")}]，排除错误项 [${wrongNames.isEmpty ? "无" : wrongNames.join("、")}]。进入第 $turnUsed/$maxTurns 回合！';
    host.log(lastEvent);
  }

  void _resolveFinale() {
    var correctPsychics = 0;
    final totalPsychics = max(1, players - 1);
    for (var s = 0; s < players; s++) {
      if (votes[s] == finaleCulprit) {
        if (s == guideSeat) {
          scores[s] += 4;
        } else {
          correctPsychics++;
          scores[s] += 8;
          scores[guideSeat] += 3;
        }
      }
    }
    teamWon = correctPsychics * 2 >= totalPsychics;
    _over = true;
    phase = 'over';

    final pair = finaleCandidates[finaleCulprit];
    final suspName = kMysteriumSuspects[pair['suspect']!];
    final locName = kMysteriumLocations[pair['location']!];
    lastEvent =
        '🎉 终局揭晓！真凶组合为 #$finaleCulprit【$suspName + $locName】！${teamWon ? "通灵调查团大获全胜" : "真凶逃脱"}！';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'clue' && seat == guideSeat) {
      for (var s = 0; s < players; s++) {
        if (s == guideSeat || stageSolved[s] || currentClue[s] != null) continue;
        final tSlot = targetSlot[s];
        final cardId = stage == 1 ? suspects[tSlot] : locations[tSlot];
        final matchVision = guideHand.firstWhere(
          (v) => v % 9 == cardId,
          orElse: () => cardId,
        );
        return {'type': 'clue', 'seat': s, 'vision': matchVision};
      }
    }

    if (phase == 'guess' && seat != guideSeat) {
      final clue = currentClue[seat];
      final available = [
        for (var i = 0; i < 9; i++)
          if (!gridCleared[i] && !currentGuess.contains(i)) i,
      ];
      if (available.isEmpty) return null;

      if (clue != null && botLevel >= 1) {
        final desiredCard = clue % 9;
        for (final slot in available) {
          final cardId = stage == 1 ? suspects[slot] : locations[slot];
          if (cardId == desiredCard && slot != witnessSlot) {
            return {'type': 'guess', 'slot': slot};
          }
        }
      }
      return {'type': 'guess', 'slot': available[rng.nextInt(available.length)]};
    }

    if (phase == 'finale') {
      if (seat == guideSeat || (botLevel >= 1 && finaleClues.isNotEmpty)) {
        final hintedSuspect = finaleClues.first % 9;
        final idx = finaleCandidates.indexWhere((c) => c['suspect'] == hintedSuspect);
        if (idx >= 0) {
          return {'type': 'vote', 'candidate': idx};
        }
      }
      return {'type': 'vote', 'candidate': rng.nextInt(3)};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final isGuideOrOver = seat == guideSeat || _over;
    return {
      'guideSeat': guideSeat,
      'stage': stage,
      'phase': phase,
      'turnUsed': turnUsed,
      'maxTurns': maxTurns,
      'suspects': List<int>.of(suspects),
      'locations': List<int>.of(locations),
      'gridCleared': List<bool>.of(gridCleared),
      'stageSolved': List<bool>.of(stageSolved),
      'currentClue': List<int?>.of(currentClue),
      'currentGuess': List<int?>.of(currentGuess),
      'solvedSuspect': List<int>.of(solvedSuspect),
      'solvedLocation': List<int>.of(solvedLocation),
      'witnessSlot': isGuideOrOver ? witnessSlot : null,
      'targetSlot': isGuideOrOver ? List<int>.of(targetSlot) : null,
      'guideHand': seat == guideSeat ? List<int>.of(guideHand) : const <int>[],
      'finaleCandidates': [
        for (final c in finaleCandidates) Map<String, int>.of(c),
      ],
      'finaleClues': List<int>.of(finaleClues),
      'finaleCulprit': isGuideOrOver ? finaleCulprit : null,
      'votes': [
        for (var s = 0; s < players; s++)
          (_over || s == seat) ? votes[s] : (votes[s] != null ? -1 : null),
      ],
      'teamWon': teamWon,
      'scores': List<int>.of(scores),
      'waitingFor': waitingFor,
      'lastEvent': lastEvent,
      'over': _over,
    };
  }
}
