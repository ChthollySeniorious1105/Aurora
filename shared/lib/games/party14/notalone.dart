import 'dart:math';

import '../../src/engine.dart';

class NotAlonePlace {
  final int id;
  final String name;
  final String enName;
  final String emoji;
  final String desc;
  const NotAlonePlace(this.id, this.name, this.enName, this.emoji, this.desc);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enName': enName,
        'emoji': emoji,
        'desc': desc,
      };
}

const List<NotAlonePlace> kNotAlonePlaces = [
  NotAlonePlace(1, '母舰巢穴', 'Lair', '🛸', '拿回自己弃牌堆中的所有地点牌'),
  NotAlonePlace(2, '迷雾丛林', 'Jungle', '🌴', '拿回本牌及弃牌堆中的1张地点牌'),
  NotAlonePlace(3, '湍急河流', 'River', '🌊', '双重探索：恢复1点意志并拿回1张弃牌'),
  NotAlonePlace(4, '信号海滩', 'Beach', '🏖️', '推进救援飞船 +1 格'),
  NotAlonePlace(5, '探测车', 'Rover', '🛞', '从储备区解锁1张6~10号新地点牌入手'),
  NotAlonePlace(6, '庇护所', 'Shelter', '⛺', '恢复 +1 点意志力（上限3点）'),
  NotAlonePlace(7, '飞船残骸', 'Wreck', '🚀', '推进救援飞船 +1 格'),
  NotAlonePlace(8, '生命之源', 'Source', '💧', '为任意一名宇航员恢复 +1 点意志力'),
  NotAlonePlace(9, '远古神器', 'Artifact', '🔮', '推进救援飞船 +1 格并拿回1张弃牌'),
  NotAlonePlace(10, '绿洲信标', 'Oasis', '🏝️', '从弃牌堆拿回最多2张地点牌'),
];

NotAlonePlace placeById(int id) => kNotAlonePlaces[(id - 1).clamp(0, kNotAlonePlaces.length - 1)];

class NotAloneGame extends GameEngine {
  NotAloneGame(super.setup);

  late int rescueMax;
  late int rescueLeft;
  late int assimilationMax;
  late int assimilationLeft;

  late List<int> will;
  late List<List<int>> hands;
  late List<List<int>> discards;
  final Map<int, int> reserve = {};

  int round = 1;
  String phase = 'explore'; // 'explore' | 'hunt'

  late List<bool> acted;
  late List<int?> played;
  late List<bool> gaveUp;
  late List<int?> preferredRetrieve;
  late List<int?> preferredUnlock;
  late List<int?> preferredHeal;

  List<int> lastTargets = [];
  Map<String, dynamic>? lastResolution;

  bool _over = false;
  String? winnerSide; // 'creature' | 'hunted'
  String resultText = '';
  List<int>? _placings;

  bool get artemiaActive => rescueLeft <= 6 || round.isEven;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    final fast = setup.opt<String>('mode', 'standard') == 'fast';
    rescueMax = fast ? 8 : 11;
    rescueLeft = rescueMax;
    assimilationMax = 6 + players;
    assimilationLeft = assimilationMax;

    will = [
      for (var s = 0; s < players; s++) s == 0 ? 0 : 3,
    ];
    hands = [
      for (var s = 0; s < players; s++) s == 0 ? <int>[] : <int>[1, 2, 3, 4, 5],
    ];
    discards = [
      for (var s = 0; s < players; s++) <int>[],
    ];
    reserve.clear();
    final copies = max(1, players - 1);
    for (var loc = 6; loc <= 10; loc++) {
      reserve[loc] = copies;
    }

    round = 1;
    phase = 'explore';
    _resetRoundState();
    host.log('绝命异星开始！${name(0)} 扮演异形生物，其余玩家扮演落难宇航员（救援剩余 $rescueLeft 步，同化剩余 $assimilationLeft 步）。');
  }

  void _resetRoundState() {
    acted = [for (var s = 0; s < players; s++) s == 0];
    played = List<int?>.filled(players, null);
    gaveUp = List<bool>.filled(players, false);
    preferredRetrieve = List<int?>.filled(players, null);
    preferredUnlock = List<int?>.filled(players, null);
    preferredHeal = List<int?>.filled(players, null);
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'explore') {
      return [
        for (var s = 1; s < players; s++)
          if (!acted[s]) s,
      ];
    }
    if (phase == 'hunt') {
      return const [0];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'explore') {
      if (seat <= 0 || seat >= players) throw GameError('只有落难宇航员可以进行潜行阶段操作');
      if (acted[seat]) throw GameError('本回合你已行动');

      if (type == 'give_up') {
        will[seat] = 3;
        hands[seat].addAll(discards[seat]);
        hands[seat].sort();
        discards[seat].clear();
        played[seat] = null;
        gaveUp[seat] = true;
        acted[seat] = true;
        assimilationLeft = max(0, assimilationLeft - 1);
        host.log('${name(seat)} 选择放弃抵抗：意志力恢复至3并拿回所有弃牌，同化进度推进1格（剩余 $assimilationLeft）');
        if (assimilationLeft <= 0) {
          _finish('creature', '同化轨道抵达终点，异形生物 ${name(0)} 获胜！');
          return;
        }
      } else if (type == 'explore') {
        final loc = asInt(action['place']);
        if (!hands[seat].contains(loc)) {
          throw GameError('手牌中没有该地点牌 ($loc)');
        }
        hands[seat].remove(loc);
        played[seat] = loc;
        gaveUp[seat] = false;
        acted[seat] = true;
        preferredRetrieve[seat] = action['retrieve'] != null ? asInt(action['retrieve']) : null;
        preferredUnlock[seat] = action['unlock'] != null ? asInt(action['unlock']) : null;
        preferredHeal[seat] = action['healTarget'] != null ? asInt(action['healTarget']) : null;
      } else {
        throw GameError('未知潜行操作：$type');
      }

      if (waitingFor.isEmpty && !_over) {
        phase = 'hunt';
      }
      return;
    }

    if (phase == 'hunt') {
      if (seat != 0) throw GameError('等待异形生物进行狩猎');
      if (type != 'hunt') throw GameError('异形生物必须执行 hunt 操作');

      var rawTargets = asIntList(action['targets']);
      if (rawTargets.isEmpty && action['target'] != null) {
        rawTargets = [asInt(action['target'])];
      }
      final targets = <int>[];
      for (final t in rawTargets) {
        if (t < 1 || t > 10) throw GameError('狩猎地点必须在 1..10 之间');
        if (!targets.contains(t)) targets.add(t);
      }
      if (targets.isEmpty || targets.length > 2) {
        throw GameError('异形生物必须指定 1..2 个不重复的狩猎地点');
      }

      _resolveRound(targets);
      return;
    }

    throw GameError('当前阶段无法执行该操作');
  }

  void _resolveRound(List<int> targets) {
    lastTargets = List<int>.of(targets);
    final creatureTarget = targets.first;
    final artemiaTarget = targets.length > 1 ? targets[1] : null;

    final roundPlays = <String, dynamic>{};
    final events = <String>[];

    // 1. Resolve un-targeted Hunted locations first
    for (var s = 1; s < players; s++) {
      final loc = played[s];
      if (loc == null) {
        roundPlays['$s'] = {'gaveUp': true, 'place': null, 'caught': false};
        continue;
      }
      final caught = targets.contains(loc);
      roundPlays['$s'] = {
        'gaveUp': false,
        'place': loc,
        'placeName': placeById(loc).name,
        'caught': caught,
        'caughtBy': loc == creatureTarget ? 'creature' : (loc == artemiaTarget ? 'artemia' : null),
      };
      if (!caught) {
        final msg = _resolveSafePlace(s, loc);
        events.add('${name(s)} 成功探索【${placeById(loc).name}】：$msg');
      }
    }

    if (rescueLeft <= 0) {
      lastResolution = {
        'round': round,
        'targets': lastTargets,
        'plays': roundPlays,
        'events': events,
      };
      _finish('hunted', '宇航员通过地点能力推进救援飞船抵达，落难宇航员获胜！');
      return;
    }

    // 2. Resolve caught Hunted on targeted locations
    var creatureCaughtAny = false;
    for (var s = 1; s < players; s++) {
      final loc = played[s];
      if (loc == null || !targets.contains(loc)) continue;
      discards[s].add(loc);
      if (loc == creatureTarget) {
        creatureCaughtAny = true;
        will[s] = max(0, will[s] - 1);
        assimilationLeft = max(0, assimilationLeft - 1);
        var msg = '${name(s)} 在【${placeById(loc).name}】遭遇异形本体！失去1点意志力，同化进度推进1格';
        if (will[s] <= 0) {
          will[s] = 3;
          hands[s].addAll(discards[s]);
          hands[s].sort();
          discards[s].clear();
          assimilationLeft = max(0, assimilationLeft - 1);
          msg += '（意志耗尽崩溃，重置意志至3并拿回弃牌，同化再推进1格）';
        }
        events.add(msg);
      } else {
        // Caught by second token (TargetToken / ArtemiaToken)
        will[s] = max(0, will[s] - 1);
        assimilationLeft = max(0, assimilationLeft - 1);
        var msg = '${name(s)} 在【${placeById(loc).name}】遭遇阿忒弥亚狩猎标记！地点效果失效并失去1点意志力，同化推进1格';
        if (will[s] <= 0) {
          will[s] = 3;
          hands[s].addAll(discards[s]);
          hands[s].sort();
          discards[s].clear();
          assimilationLeft = max(0, assimilationLeft - 1);
          msg += '（意志耗尽崩溃，同化再推进1格）';
        }
        events.add(msg);
      }
    }

    if (!creatureCaughtAny && artemiaTarget == null) {
      events.add('异形生物巡视了【${placeById(creatureTarget).name}】，但未捕获任何宇航员。');
    }

    if (assimilationLeft <= 0) {
      lastResolution = {
        'round': round,
        'targets': lastTargets,
        'plays': roundPlays,
        'events': events,
      };
      _finish('creature', '异形生物成功同化所有宇航员，${name(0)} 获胜！');
      return;
    }

    // 3. End-of-round Rescue Ship step
    rescueLeft = max(0, rescueLeft - 1);
    events.add('回合结束，救援飞船前进1格（剩余 $rescueLeft 步）。');

    lastResolution = {
      'round': round,
      'targets': lastTargets,
      'plays': roundPlays,
      'events': events,
    };

    for (final e in events) {
      host.log(e);
    }

    if (rescueLeft <= 0) {
      _finish('hunted', '救援飞船成功降落阿忒弥亚星球，落难宇航员全员获救！');
      return;
    }

    round++;
    phase = 'explore';
    _resetRoundState();
  }

  String _resolveSafePlace(int s, int loc) {
    switch (loc) {
      case 1: // 母舰巢穴 Lair: retrieve all discarded place cards
        final count = discards[s].length;
        hands[s].addAll(discards[s]);
        discards[s].clear();
        discards[s].add(1);
        hands[s].sort();
        return '拿回弃牌堆全部 $count 张地点牌';
      case 2: // 迷雾丛林 Jungle: retrieve this card + 1 discarded card
        final r = _takeOneDiscard(s, preferredRetrieve[s]);
        hands[s].add(2);
        hands[s].sort();
        return r != null ? '收回迷雾丛林并拿回【${placeById(r).name}】' : '收回迷雾丛林';
      case 3: // 湍急河流 River: double explore (heal +1 & retrieve 1 discard or unlock 1)
        will[s] = min(3, will[s] + 1);
        final r = _takeOneDiscard(s, preferredRetrieve[s]);
        discards[s].add(3);
        if (r != null) {
          hands[s].sort();
          return '双重探索，恢复1点意志并拿回【${placeById(r).name}】';
        } else {
          final u = _unlockOne(s, preferredUnlock[s]);
          hands[s].sort();
          return u != null ? '双重探索，恢复1点意志并解锁【${placeById(u).name}】' : '双重探索，恢复1点意志';
        }
      case 4: // 信号海滩 Beach: advance Rescue Ship +1
        discards[s].add(4);
        rescueLeft = max(0, rescueLeft - 1);
        return '发送求救信号，救援飞船额外前进1格（剩余 $rescueLeft）';
      case 5: // 探测车 Rover: unlock a new Location 6..10 from reserve into hand
        discards[s].add(5);
        final u = _unlockOne(s, preferredUnlock[s]);
        if (u != null) {
          hands[s].sort();
          return '从储备区解锁新地点【${placeById(u).name}】加入手牌';
        }
        final r = _takeOneDiscard(s, preferredRetrieve[s]);
        hands[s].sort();
        return r != null ? '已拥有全部新地点，改为拿回【${placeById(r).name}】' : '探索探测车';
      case 6: // 庇护所 Shelter: heal +1 Willpower
        discards[s].add(6);
        will[s] = min(3, will[s] + 1);
        return '在庇护所休整，意志力恢复至 ${will[s]}';
      case 7: // 飞船残骸 Wreck: advance Rescue Ship +1
        discards[s].add(7);
        rescueLeft = max(0, rescueLeft - 1);
        return '修复残骸信标，救援飞船额外前进1格（剩余 $rescueLeft）';
      case 8: // 生命之源 Source: heal +1 Willpower to any Hunted
        discards[s].add(8);
        final pref = preferredHeal[s];
        int target = s;
        if (pref != null && pref > 0 && pref < players) {
          target = pref;
        } else {
          for (var p = 1; p < players; p++) {
            if (will[p] < will[target]) target = p;
          }
        }
        will[target] = min(3, will[target] + 1);
        return '生命之源为 ${name(target)} 恢复1点意志力（当前 ${will[target]}）';
      case 9: // 远古神器 Artifact: advance Rescue +1 & retrieve 1 card
        final r = _takeOneDiscard(s, preferredRetrieve[s]);
        discards[s].add(9);
        rescueLeft = max(0, rescueLeft - 1);
        hands[s].sort();
        return r != null
            ? '激活远古神器，救援飞船前进1格并拿回【${placeById(r).name}】'
            : '激活远古神器，救援飞船额外前进1格';
      case 10: // 绿洲信标 Oasis: retrieve 2 discarded cards
        final r1 = _takeOneDiscard(s, preferredRetrieve[s]);
        final r2 = _takeOneDiscard(s, null);
        discards[s].add(10);
        hands[s].sort();
        final got = [if (r1 != null) placeById(r1).name, if (r2 != null) placeById(r2).name];
        return got.isNotEmpty ? '在绿洲信标拿回 ${got.join("、")}' : '探索绿洲信标';
      default:
        discards[s].add(loc);
        return '完成探索';
    }
  }

  int? _takeOneDiscard(int s, int? preferred) {
    if (discards[s].isEmpty) return null;
    if (preferred != null && discards[s].contains(preferred)) {
      discards[s].remove(preferred);
      hands[s].add(preferred);
      return preferred;
    }
    // Default: pick highest value location in discard (or 4/7/9/2 priority)
    final priority = [9, 7, 4, 10, 2, 5, 6, 8, 3, 1];
    for (final p in priority) {
      if (discards[s].contains(p)) {
        discards[s].remove(p);
        hands[s].add(p);
        return p;
      }
    }
    final c = discards[s].removeLast();
    hands[s].add(c);
    return c;
  }

  int? _unlockOne(int s, int? preferred) {
    bool owns(int loc) => hands[s].contains(loc) || discards[s].contains(loc) || played[s] == loc;
    if (preferred != null &&
        preferred >= 6 &&
        preferred <= 10 &&
        (reserve[preferred] ?? 0) > 0 &&
        !owns(preferred)) {
      reserve[preferred] = reserve[preferred]! - 1;
      hands[s].add(preferred);
      return preferred;
    }
    const order = [9, 7, 10, 6, 8];
    for (final loc in order) {
      if ((reserve[loc] ?? 0) > 0 && !owns(loc)) {
        reserve[loc] = reserve[loc]! - 1;
        hands[s].add(loc);
        return loc;
      }
    }
    return null;
  }

  void _finish(String side, String reason) {
    _over = true;
    winnerSide = side;
    resultText = reason;
    if (side == 'creature') {
      _placings = rankWinners(players, const [0]);
    } else {
      _placings = rankWinners(players, [for (var s = 1; s < players; s++) s]);
    }
    host.log('游戏结束：$reason');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'explore' && seat > 0) {
      final h = hands[seat];
      if (h.isEmpty) {
        return {'type': 'give_up'};
      }
      // If willpower is 1 and only 1 card left while assimilation has room, consider give_up occasionally on easy
      if (botLevel >= 1) {
        // Prefer Rescue advancing cards (4, 7, 9) or Rover (5) or Jungle (2) or Lair (1) when discard is full
        final candidates = List<int>.of(h);
        if (botLevel == 2) {
          candidates.sort((a, b) => _placeScore(seat, b).compareTo(_placeScore(seat, a)));
          // Pick among top 2 to stay unpredictable against Creature
          final pickPool = candidates.take(min(2, candidates.length)).toList();
          final chosen = pickPool[rng.nextInt(pickPool.length)];
          return {'type': 'explore', 'place': chosen};
        }
        final chosen = candidates[rng.nextInt(candidates.length)];
        return {'type': 'explore', 'place': chosen};
      }
      return {'type': 'explore', 'place': h[rng.nextInt(h.length)]};
    }

    if (phase == 'hunt' && seat == 0) {
      // Creature bot only uses public information: discards[1..players-1], handCounts, rescueLeft, assimilationLeft
      final weights = <int, int>{for (var loc = 1; loc <= 10; loc++) loc: 1};
      for (var s = 1; s < players; s++) {
        final disc = discards[s];
        // Any basic card 1..5 not in discard might be in hand!
        for (var loc = 1; loc <= 5; loc++) {
          if (!disc.contains(loc)) {
            weights[loc] = (weights[loc] ?? 1) + (loc == 4 || loc == 5 || loc == 2 ? 4 : 2);
          }
        }
        if (disc.length >= 3 && !disc.contains(1)) {
          weights[1] = (weights[1] ?? 1) + 5; // Likely to play Lair (1)
        }
        for (var loc = 6; loc <= 10; loc++) {
          if (!disc.contains(loc) && (reserve[loc] ?? 0) < (players - 1)) {
            weights[loc] = (weights[loc] ?? 1) + (loc == 7 || loc == 9 ? 4 : 2);
          }
        }
      }
      final ranked = [for (var i = 1; i <= 10; i++) i]
        ..sort((a, b) => (weights[b] ?? 0).compareTo(weights[a] ?? 0));

      final first = botLevel == 0 ? (1 + rng.nextInt(5)) : ranked[rng.nextInt(min(3, ranked.length))];
      if (artemiaActive) {
        final remaining = [for (final x in ranked) if (x != first) x];
        final second = remaining[rng.nextInt(min(3, remaining.length))];
        return {
          'type': 'hunt',
          'targets': [first, second],
        };
      }
      return {
        'type': 'hunt',
        'targets': [first],
      };
    }
    return null;
  }

  int _placeScore(int s, int loc) {
    switch (loc) {
      case 9:
      case 7:
      case 4:
        return 10;
      case 5:
        return 8;
      case 2:
        return discards[s].isNotEmpty ? 9 : 6;
      case 1:
        return discards[s].length >= 3 ? 11 : 3;
      case 10:
        return discards[s].length >= 2 ? 9 : 4;
      case 6:
      case 8:
        return will[s] < 3 ? 8 : 4;
      case 3:
        return 7;
      default:
        return 5;
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'phase': phase,
      'rescueMax': rescueMax,
      'rescueLeft': rescueLeft,
      'assimilationMax': assimilationMax,
      'assimilationLeft': assimilationLeft,
      'artemiaActive': artemiaActive,
      'will': will,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hands': [
        for (var s = 0; s < players; s++)
          (_over || seat == s) ? List<int>.of(hands[s]) : <int>[],
      ],
      'myHand': (seat >= 0 && seat < players) ? List<int>.of(hands[seat]) : <int>[],
      'discards': [for (var s = 0; s < players; s++) List<int>.of(discards[s])],
      'reserve': {for (final e in reserve.entries) '${e.key}': e.value},
      'acted': acted,
      'gaveUp': gaveUp,
      'played': [
        for (var s = 0; s < players; s++)
          (_over || seat == s) ? played[s] : null,
      ],
      'places': [for (final p in kNotAlonePlaces) p.toJson()],
      'lastTargets': lastTargets,
      'lastResolution': lastResolution,
      'waitingFor': waitingFor,
      'over': _over,
      'winnerSide': winnerSide,
      'resultText': resultText,
    };
  }
}
