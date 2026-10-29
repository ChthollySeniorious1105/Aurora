import 'dart:math';

import '../../src/engine.dart';

class CelestiaGame extends GameEngine {
  CelestiaGame(super.setup);

  static const List<String> cityNames = [
    '云端港',
    '齿轮岛',
    '风车镇',
    '水晶城',
    '蒸汽堡',
    '浮空苑',
    '星辉城',
    '黄金城',
    '光耀之都',
  ];

  static const List<int> cityDice = [2, 2, 2, 3, 3, 3, 4, 4, 4];
  static const List<int> cityPoints = [1, 2, 4, 6, 9, 12, 15, 20, 25];

  static const List<String> hazardNames = [
    '指南针',
    '避雷针',
    '雾笛',
    '火炮',
    '涡轮增压器',
  ];

  late int targetScore;
  int voyage = 0;
  int cityIndex = 0;
  int captain = 0;
  int voyageStartCaptain = 0;
  List<int> aboard = [];
  List<int> pendingPassengers = [];
  List<int> hazards = [];
  String phase = 'passengers';

  final List<Object> deck = [];
  final List<Object> discard = [];
  late List<List<Object>> hands;
  late List<int> scores;
  late List<List<int>> treasures;
  String lastEvent = '';
  bool _over = false;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'passengers') {
      return pendingPassengers.isNotEmpty ? [pendingPassengers.first] : const [];
    }
    if (phase == 'captain') {
      return [captain];
    }
    return const [];
  }

  void _initDeck() {
    deck.clear();
    discard.clear();
    for (var h = 0; h < 4; h++) {
      for (var i = 0; i < 17; i++) {
        deck.add(h);
      }
    }
    for (var i = 0; i < 8; i++) {
      deck.add(4); // Wildcard Turbo
    }
    for (var i = 0; i < 4; i++) {
      deck.add('jetpack');
      deck.add('eject');
    }
    deck.shuffle(rng);
  }

  Object _drawCard() {
    if (deck.isEmpty && discard.isNotEmpty) {
      deck.addAll(discard);
      discard.clear();
      deck.shuffle(rng);
    }
    if (deck.isEmpty) {
      for (var h = 0; h < 4; h++) {
        deck.add(h);
      }
      deck.shuffle(rng);
    }
    return deck.removeLast();
  }

  @override
  void start() {
    targetScore = setup.opt<int>('target', 50);
    hands = List.generate(players, (_) => <Object>[]);
    scores = List.filled(players, 0);
    treasures = List.generate(players, (_) => <int>[]);
    _initDeck();

    final startHandSize = players <= 3 ? 8 : 6;
    for (var s = 0; s < players; s++) {
      for (var i = 0; i < startHandSize; i++) {
        hands[s].add(_drawCard());
      }
    }

    voyage = 0;
    voyageStartCaptain = 0;
    _over = false;
    _beginVoyage(initial: true);
  }

  void _beginVoyage({bool initial = false}) {
    if (scores.any((s) => s >= targetScore) || voyage >= 40) {
      _over = true;
      phase = 'over';
      pendingPassengers = [];
      lastEvent = '航程结束，最终结算完成！';
      host.log(lastEvent);
      return;
    }

    voyage++;
    if (!initial) {
      for (var s = 0; s < players; s++) {
        hands[s].add(_drawCard());
      }
      voyageStartCaptain = (voyageStartCaptain + 1) % players;
    }

    cityIndex = 0;
    aboard = [for (var i = 0; i < players; i++) i];
    captain = voyageStartCaptain;
    _rollAndSetupCityStep();
  }

  void _rollAndSetupCityStep() {
    final diceCount = cityDice[cityIndex];
    hazards = [for (var i = 0; i < diceCount; i++) rng.nextInt(4)];
    pendingPassengers = [
      for (var i = 1; i < players; i++)
        if (aboard.contains((captain + i) % players)) (captain + i) % players,
    ];
    phase = pendingPassengers.isNotEmpty ? 'passengers' : 'captain';
  }

  /// Minimum number of Wildcard Turbos (4) seat needs to cover current [hazards],
  /// or -1 if seat does not have enough matching Equipment + Wildcards.
  int minWildNeeded(int seat) {
    final req = List.filled(4, 0);
    for (final d in hazards) {
      if (d >= 0 && d < 4) req[d]++;
    }
    final have = List.filled(5, 0);
    for (final c in hands[seat]) {
      if (c is int && c >= 0 && c <= 4) have[c]++;
    }
    var deficit = 0;
    for (var h = 0; h < 4; h++) {
      if (req[h] > have[h]) {
        deficit += req[h] - have[h];
      }
    }
    if (have[4] < deficit) return -1;
    return deficit;
  }

  bool canNavigate(int seat) => minWildNeeded(seat) >= 0;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('当前未轮到你操作');

    final type = asStr(action['type']);

    if (type == 'eject') {
      final target = asInt(action['target']);
      if (!hands[seat].contains('eject')) {
        throw GameError('你手中没有弹射卡');
      }
      if (target < 0 || target >= players || target == seat || target == captain || !aboard.contains(target)) {
        throw GameError('只能弹射船上除船长和自己以外的乘客');
      }
      hands[seat].remove('eject');
      discard.add('eject');
      aboard.remove(target);
      pendingPassengers.remove(target);
      final pts = cityPoints[cityIndex];
      scores[target] += pts;
      treasures[target].add(pts);
      lastEvent = '${name(seat)} 使用弹射卡将 ${name(target)} 弹下飞艇（获得 $pts 分）！';
      host.log(lastEvent);
      if (phase == 'passengers' && pendingPassengers.isEmpty) {
        phase = 'captain';
      }
      return;
    }

    if (phase == 'passengers') {
      if (type == 'stay') {
        pendingPassengers.removeAt(0);
        lastEvent = '${name(seat)} 选择留在飞艇继续前进';
        if (pendingPassengers.isEmpty) {
          phase = 'captain';
        }
        return;
      }
      if (type == 'bail') {
        pendingPassengers.removeAt(0);
        aboard.remove(seat);
        final pts = cityPoints[cityIndex];
        scores[seat] += pts;
        treasures[seat].add(pts);
        lastEvent = '${name(seat)} 在${cityNames[cityIndex]}跳船，收获 $pts 分宝藏！';
        host.log(lastEvent);
        if (pendingPassengers.isEmpty) {
          phase = 'captain';
        }
        return;
      }
      throw GameError('未知乘客操作');
    }

    if (phase == 'captain') {
      if (type == 'bail') {
        if (aboard.length != 1 || aboard.first != captain) {
          throw GameError('船上还有其他乘客时船长不能跳船');
        }
        final pts = cityPoints[cityIndex];
        scores[captain] += pts;
        treasures[captain].add(pts);
        lastEvent = '船长 ${name(captain)} 独自在${cityNames[cityIndex]}跳船，收获 $pts 分！';
        host.log(lastEvent);
        _beginVoyage();
        return;
      }

      if (type == 'navigate') {
        final req = List.filled(4, 0);
        for (final d in hazards) {
          if (d >= 0 && d < 4) req[d]++;
        }
        final have = List.filled(5, 0);
        for (final c in hands[captain]) {
          if (c is int && c >= 0 && c <= 4) have[c]++;
        }
        var deficit = 0;
        for (var h = 0; h < 4; h++) {
          if (req[h] > have[h]) {
            deficit += req[h] - have[h];
          }
        }
        if (have[4] < deficit) {
          throw GameError('船长装备卡不足以克服当前危机');
        }
        final useWild = action.containsKey('useWild') ? asInt(action['useWild'], deficit) : deficit;
        if (useWild < deficit || useWild > have[4] || useWild > hazards.length) {
          throw GameError('使用的涡轮增压器数量不合法');
        }

        final spend = [for (var h = 0; h < 4; h++) min(req[h], have[h])];
        var extraWild = useWild - deficit;
        for (var h = 0; h < 4 && extraWild > 0; h++) {
          final cut = min(spend[h], extraWild);
          spend[h] -= cut;
          extraWild -= cut;
        }

        for (var h = 0; h < 4; h++) {
          for (var i = 0; i < spend[h]; i++) {
            hands[captain].remove(h);
            discard.add(h);
          }
        }
        for (var i = 0; i < useWild; i++) {
          hands[captain].remove(4);
          discard.add(4);
        }

        cityIndex++;
        if (cityIndex >= 8) {
          final finalPts = cityPoints[8];
          for (final s in aboard) {
            scores[s] += finalPts;
            treasures[s].add(finalPts);
          }
          lastEvent = '飞艇成功抵达终点${cityNames[8]}！船上玩家各获 $finalPts 分！';
          host.log(lastEvent);
          _beginVoyage();
          return;
        }

        for (var i = 1; i <= players; i++) {
          final cand = (captain + i) % players;
          if (aboard.contains(cand)) {
            captain = cand;
            break;
          }
        }
        lastEvent = '飞艇安全抵达${cityNames[cityIndex]}（${cityPoints[cityIndex]}分），新船长：${name(captain)}';
        host.log(lastEvent);
        _rollAndSetupCityStep();
        return;
      }

      if (type == 'crash') {
        final jetpackSavers = <String>[];
        for (final s in aboard) {
          if (hands[s].remove('jetpack')) {
            discard.add('jetpack');
            final pts = max(2, cityPoints[cityIndex]);
            scores[s] += pts;
            treasures[s].add(pts);
            jetpackSavers.add('${name(s)}(+$pts)');
          }
        }
        final extra = jetpackSavers.isEmpty ? '' : '（喷气背包获救：${jetpackSavers.join('、')}）';
        lastEvent = '飞艇在${cityNames[cityIndex]}遭遇危机坠毁！$extra';
        host.log(lastEvent);
        _beginVoyage();
        return;
      }

      throw GameError('未知船长操作');
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'passengers') {
      final curPts = cityPoints[cityIndex];
      if (scores[seat] + curPts >= targetScore) {
        return {'type': 'bail'};
      }
      if (hands[seat].contains('eject') && botLevel >= 1) {
        for (final other in aboard) {
          if (other != seat && other != captain && scores[other] >= scores[seat] && curPts <= 4) {
            return {'type': 'eject', 'target': other};
          }
        }
      }
      final capCards = hands[captain].length;
      final needed = hazards.length;
      if (cityIndex >= 1 && capCards < needed) {
        return {'type': 'bail'};
      }
      if (cityIndex >= 4 && curPts >= 9 && (capCards <= needed + 1 || rng.nextDouble() < 0.45)) {
        return {'type': 'bail'};
      }
      if (cityIndex >= 6 && rng.nextDouble() < 0.65) {
        return {'type': 'bail'};
      }
      return {'type': 'stay'};
    }

    if (phase == 'captain') {
      final minW = minWildNeeded(seat);
      if (minW >= 0) {
        return {'type': 'navigate', 'useWild': minW};
      }
      if (aboard.length == 1 && cityPoints[cityIndex] >= 2) {
        return {'type': 'bail'};
      }
      return {'type': 'crash'};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = seat >= 0 && seat < players ? hands[seat] : const <Object>[];
    final counts = <String, int>{
      '0': 0,
      '1': 0,
      '2': 0,
      '3': 0,
      '4': 0,
      'jetpack': 0,
      'eject': 0,
    };
    for (final c in myHand) {
      final k = '$c';
      counts[k] = (counts[k] ?? 0) + 1;
    }

    return {
      'voyage': voyage,
      'targetScore': targetScore,
      'cityIndex': cityIndex,
      'cities': [
        for (var i = 0; i < 9; i++)
          {
            'index': i,
            'name': cityNames[i],
            'dice': cityDice[i],
            'points': cityPoints[i],
          },
      ],
      'captain': captain,
      'aboard': List<int>.of(aboard),
      'pendingPassengers': List<int>.of(pendingPassengers),
      'hazards': List<int>.of(hazards),
      'phase': phase,
      'scores': List<int>.of(scores),
      'handSizes': [for (var s = 0; s < players; s++) hands[s].length],
      'hand': [for (final c in myHand) c],
      'handCounts': counts,
      'canNavigate': seat >= 0 && seat < players ? canNavigate(seat) : false,
      'minWild': seat >= 0 && seat < players ? minWildNeeded(seat) : -1,
      'deckCount': deck.length,
      'lastEvent': lastEvent,
      'waitingFor': waitingFor,
      'over': _over,
      if (_over) 'placings': placings,
    };
  }
}
