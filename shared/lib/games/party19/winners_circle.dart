import '../../src/engine.dart';

class WinnersCircleGame extends GameEngine {
  WinnersCircleGame(super.setup);

  static const int horseCount = 7;
  static const int finishLine = 18;

  static const List<String> horseNames = [
    '🔴 烈焰良驹',
    '🔵 疾风飞骥',
    '🟢 翡翠骏马',
    '🟡 黄金战驹',
    '🟣 紫电追风',
    '🟠 橙光奔雷',
    '⚪ 白银稳蹄',
  ];

  /// 4-symbol speed profiles: [0: 🐎 马头, 1: 🏇 骑师, 2: 🧲 马蹄铁, 3: 🥕 胡萝卜]
  static const List<List<int>> speeds = [
    [6, 2, 2, 1],
    [5, 3, 2, 1],
    [4, 4, 2, 1],
    [4, 3, 3, 1],
    [4, 3, 2, 2],
    [3, 3, 3, 2],
    [3, 3, 3, 3],
  ];

  static const List<String> symbolNames = [
    '🐎 马头',
    '🏇 骑师',
    '🧲 马蹄铁',
    '🥕 胡萝卜',
  ];

  /// Odds payout table for [1st, 2nd, 3rd] place indexed by total chips on horse (1..5+ chips).
  static const List<List<int>> oddsTable = [
    [10, 7, 5, 4, 3], // 1st place
    [6, 4, 3, 2, 1], // 2nd place
    [4, 3, 2, 1, 1], // 3rd place
  ];

  int totalRaces = 3;
  int race = 1;
  int cycle = 1;
  int turn = 0;
  int dieFace = 0;
  String phase = 'bet'; // 'bet' | 'race' | 'over'

  /// Track positions for the 7 horses (0..18+).
  late List<int> horsePos;

  /// Whether horse h has moved in the current cycle.
  late List<bool> movedInCycle;

  /// Horses that have crossed the finish line (>= 18) in order of finish.
  late List<int> finishOrder;

  /// Remaining Bet Chips in each player's hand for the current race: starts as [0, 1, 2].
  late List<List<int>> availableChips;

  /// Bets placed on each horse h: each element is {'seat': int, 'chip': int}.
  late List<List<Map<String, int>>> bets;

  /// Player cumulative scores across races.
  late List<int> scores;

  /// Summary of the most recently finished race.
  Map<String, dynamic>? lastRaceSummary;

  String lastEvent = '皇家赛马会开幕！请各位马主依次暗置押注筹码（0 虚张声势 / 1 注 / 2 注）！';

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
    totalRaces = mode == 'fast' ? 2 : 3;
    race = 1;
    scores = List<int>.filled(players, 0);
    lastRaceSummary = null;
    _initRace(startSeat: 0);
    host.log('【皇家赛马会】共 $totalRaces 场大赛开启！7 匹名驹各怀四象速度分布，每轮循环每匹马仅跑一次！');
  }

  void _initRace({required int startSeat}) {
    phase = 'bet';
    cycle = 1;
    turn = startSeat % players;
    dieFace = rng.nextInt(4);
    horsePos = List<int>.filled(horseCount, 0);
    movedInCycle = List<bool>.filled(horseCount, false);
    finishOrder = <int>[];
    availableChips = [
      for (var s = 0; s < players; s++) <int>[0, 1, 2],
    ];
    bets = [
      for (var h = 0; h < horseCount; h++) <Map<String, int>>[],
    ];
    lastEvent = '第 $race/$totalRaces 场赛前押注阶段：轮到 ${name(turn)} 放置押注筹码（0 虚张 / 1 注 / 2 注）！';
  }

  /// Compute payout multiplier for a horse finishing at [rank] (0=1st, 1=2nd, 2=3rd)
  /// with [totalChips] placed on it.
  int payoutMultiplier(int rank, int totalChips) {
    if (rank < 0 || rank >= 3 || totalChips <= 0) return 0;
    final idx = (totalChips - 1).clamp(0, oddsTable[rank].length - 1);
    return oddsTable[rank][idx];
  }

  /// List of horses eligible to move in the current cycle.
  List<int> movableHorses() {
    final out = <int>[];
    for (var h = 0; h < horseCount; h++) {
      if (horsePos[h] < finishLine && !movedInCycle[h]) {
        out.add(h);
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'bet':
        _handleBet(seat, action);
        break;
      case 'move':
        _handleMove(seat, action);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleBet(int seat, Map<String, dynamic> action) {
    if (phase != 'bet') throw GameError('当前不是赛前押注阶段');
    final h = asInt(action['horse'], -1);
    final chip = asInt(action['chip'], -1);
    if (h < 0 || h >= horseCount) {
      throw GameError('赛马编号必须在 0~6 之间');
    }
    if (!availableChips[seat].contains(chip)) {
      throw GameError('你手中没有面值为 $chip 的押注筹码');
    }

    availableChips[seat].remove(chip);
    bets[h].add({'seat': seat, 'chip': chip});

    final allPlaced = availableChips.every((chips) => chips.isEmpty);
    if (allPlaced) {
      phase = 'race';
      turn = (turn + 1) % players;
      dieFace = rng.nextInt(4);
      lastEvent =
          '📢 押注完毕，第 $race 场正式开闸！${name(turn)} 掷出【${symbolNames[dieFace]}】，请选择 1 匹本轮尚未移动的赛马推进！';
      host.log(lastEvent);
    } else {
      for (var i = 1; i <= players; i++) {
        final next = (turn + i) % players;
        if (availableChips[next].isNotEmpty) {
          turn = next;
          break;
        }
      }
      lastEvent = '💰 ${name(seat)} 在【${horseNames[h]}】上暗置了 1 枚押注筹码（当前共 ${bets[h].length} 枚筹码）。';
      host.log(lastEvent);
    }
  }

  void _handleMove(int seat, Map<String, dynamic> action) {
    if (phase != 'race') throw GameError('当前不是赛跑阶段');
    final h = asInt(action['horse'], -1);
    if (h < 0 || h >= horseCount) {
      throw GameError('赛马编号必须在 0~6 之间');
    }
    if (horsePos[h] >= finishLine) {
      throw GameError('该赛马已经冲过终点线');
    }
    if (movedInCycle[h]) {
      throw GameError('该赛马在本轮循环中已经移动过了，每匹马每轮循环仅限跑一次');
    }

    final step = speeds[h][dieFace];
    final oldPos = horsePos[h];
    var target = oldPos + step;
    var dropBackNote = '';

    if (target >= finishLine) {
      target = finishLine + finishOrder.length;
      horsePos[h] = target;
      finishOrder.add(h);
    } else {
      // If landing on an occupied track space (< 18 and > 0), drop back to first empty space behind it
      while (target > 0 && _isSpaceOccupied(target, excludeHorse: h)) {
        target--;
      }
      if (target < oldPos + step) {
        dropBackNote = '（前方拥堵退至第 $target 格）';
      }
      horsePos[h] = target;
    }

    movedInCycle[h] = true;

    // Check if 3 horses have crossed the Finish Line (>= 18)
    if (finishOrder.length >= 3) {
      _settleRace(seat, h, step, oldPos, target);
      return;
    }

    // Check if all remaining unfinished horses have moved in this cycle
    var cycleResetNote = '';
    if (movableHorses().isEmpty) {
      resetCycleIfNeeded();
      cycle++;
      cycleResetNote = ' · 🔄 7 匹赛马全部跑完本轮，开启第 $cycle 轮循环！';
    }

    turn = (turn + 1) % players;
    final prevSymbol = symbolNames[dieFace];
    dieFace = rng.nextInt(4);

    final finishNote = horsePos[h] >= finishLine
        ? ' 🏁 冲线夺得第 ${finishOrder.indexOf(h) + 1} 名！'
        : '';
    lastEvent =
        '🏇 ${name(seat)} 凭【$prevSymbol】驱动【${horseNames[h]}】前进 $step 步 ($oldPos→${horsePos[h] >= finishLine ? finishLine : horsePos[h]})$dropBackNote$finishNote$cycleResetNote';
    host.log(lastEvent);
  }

  bool _isSpaceOccupied(int pos, {required int excludeHorse}) {
    if (pos <= 0 || pos >= finishLine) return false;
    for (var i = 0; i < horseCount; i++) {
      if (i != excludeHorse && horsePos[i] == pos) return true;
    }
    return false;
  }

  /// Reset movedInCycle if all unfinished horses have moved.
  void resetCycleIfNeeded() {
    for (var i = 0; i < horseCount; i++) {
      movedInCycle[i] = horsePos[i] >= finishLine;
    }
  }

  void _settleRace(int moverSeat, int lastHorse, int step, int oldPos, int target) {
    final gains = List<int>.filled(players, 0);
    final podiumDetails = <String>[];

    for (var rank = 0; rank < 3 && rank < finishOrder.length; rank++) {
      final h = finishOrder[rank];
      final totalChips = bets[h].length;
      final mult = payoutMultiplier(rank, totalChips);
      for (final b in bets[h]) {
        final s = b['seat']!;
        final chipVal = b['chip']!;
        final payout = chipVal * mult;
        gains[s] += payout;
        scores[s] += payout;
      }
      final medal = rank == 0 ? '🥇冠军' : (rank == 1 ? '🥈亚军' : '🥉季军');
      podiumDetails.add('$medal ${horseNames[h]} (共$totalChips枚筹码, 赔率×$mult)');
    }

    lastRaceSummary = {
      'race': race,
      'podium': List<int>.of(finishOrder.take(3)),
      'gains': gains,
      'podiumText': podiumDetails.join(' | '),
    };

    if (race < totalRaces) {
      final finishedRace = race;
      race++;
      final nextStarter = (moverSeat + 1) % players;
      _initRace(startSeat: nextStarter);
      lastEvent =
          '🏆 第 $finishedRace 场冲线结算：${podiumDetails.join("，")}！现进入第 $race/$totalRaces 场赛前押注！';
      host.log(lastEvent);
    } else {
      phase = 'over';
      var bestSeat = 0;
      for (var s = 1; s < players; s++) {
        if (scores[s] > scores[bestSeat]) bestSeat = s;
      }
      lastEvent =
          '🏆 皇家赛马会圆满落幕！${podiumDetails.join("，")}！${name(bestSeat)} 以总奖金 ${scores[bestSeat]} 分摘得总冠军！';
      host.log(lastEvent);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    final revealAllChips = phase == 'over';

    return {
      'race': race,
      'totalRaces': totalRaces,
      'cycle': cycle,
      'turn': turn,
      'dieFace': dieFace,
      'dieSymbol': symbolNames[dieFace],
      'phase': phase,
      'horseNames': horseNames,
      'speeds': speeds,
      'horsePos': List<int>.of(horsePos),
      'movedInCycle': List<bool>.of(movedInCycle),
      'finishOrder': List<int>.of(finishOrder),
      'myChips': validPlayer ? List<int>.of(availableChips[seat]) : const <int>[],
      'chipCounts': [
        for (var s = 0; s < players; s++) availableChips[s].length,
      ],
      'bets': [
        for (var h = 0; h < horseCount; h++)
          [
            for (final b in bets[h])
              {
                'seat': b['seat']!,
                // Secret bet chip value: only visible to owner or when game is over!
                'chip': (revealAllChips || b['seat'] == seat) ? b['chip']! : -1,
              },
          ],
      ],
      'betCounts': [
        for (var h = 0; h < horseCount; h++) bets[h].length,
      ],
      'oddsPreview': [
        for (var h = 0; h < horseCount; h++)
          [
            payoutMultiplier(0, bets[h].isEmpty ? 1 : bets[h].length),
            payoutMultiplier(1, bets[h].isEmpty ? 1 : bets[h].length),
            payoutMultiplier(2, bets[h].isEmpty ? 1 : bets[h].length),
          ],
      ],
      'scores': List<int>.of(scores),
      'lastRaceSummary': lastRaceSummary,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (phase == 'bet') {
      final chips = availableChips[seat];
      if (chips.isEmpty) return null;
      final chip = chips.last; // Place 2, then 1, then 0
      var bestHorse = 0;
      var bestVal = -999999;

      for (var h = 0; h < horseCount; h++) {
        final avgSpeed = speeds[h][0] + speeds[h][1] + speeds[h][2] + speeds[h][3];
        final currentChips = bets[h].length;
        int val;
        if (chip == 0) {
          // Bluff chip: place on horses where others have bet to dilute their odds
          val = currentChips * 15 + avgSpeed + rng.nextInt(5);
        } else {
          // Real bet chip: prefer high-odds horses with few chips & solid speed
          final estMult = payoutMultiplier(0, currentChips + 1);
          val = estMult * 12 + avgSpeed * 2 - currentChips * 8 + rng.nextInt(4);
        }
        if (val > bestVal) {
          bestVal = val;
          bestHorse = h;
        }
      }
      return {'type': 'bet', 'horse': bestHorse, 'chip': chip};
    }

    if (phase == 'race') {
      final movable = movableHorses();
      if (movable.isEmpty) return null;

      var bestHorse = movable.first;
      var bestScore = -999999;

      for (final h in movable) {
        final step = speeds[h][dieFace];
        var myChipSum = 0;
        for (final b in bets[h]) {
          if (b['seat'] == seat) myChipSum += b['chip']!;
        }
        final totalChips = bets[h].length;
        // If we hold real chips on horse h, push it forward on big rolls;
        // if we hold 0 chips on horse h, move it when it rolls poorly!
        int score;
        if (myChipSum > 0) {
          score = myChipSum * step * 20 + horsePos[h] * 2;
        } else {
          score = (6 - step) * (totalChips + 1) * 8 - horsePos[h];
        }
        score += rng.nextInt(5);
        if (score > bestScore) {
          bestScore = score;
          bestHorse = h;
        }
      }
      return {'type': 'move', 'horse': bestHorse};
    }

    return null;
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    lastEvent = '${name(seat)} 认输离场，赛马会结束！';
    host.log(lastEvent);
  }
}
