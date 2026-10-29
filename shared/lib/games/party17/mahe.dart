import '../../src/engine.dart';

const List<String> kTurtleNames = [
  '🟢 翡翠海龟',
  '🟡 琥珀海龟',
  '🔵 深海海龟',
  '🟣 珊瑚海龟',
  '🟠 骄阳海龟',
  '🔴 熔岩海龟',
];

class MaheGame extends GameEngine {
  MaheGame(super.setup);

  static const int trackLen = 21;

  int turn = 0; // which turtle's turn it is to move
  int turnCount = 0;
  late int maxTurns;
  String phase = 'roll'; // 'roll' | 'over'

  /// Position (0..20) of each turtle seat.
  late List<int> pos;

  /// Ordered stacks at each space 0..20: [bottomSeat, ..., topSeat].
  /// Space 0 does not piggyback, only spaces 1..20 form stacks.
  late List<List<int>> stacks;

  /// Current dice rolled this turn (1 to 3 dice).
  List<int> dice = <int>[];

  /// Deck of Egg cards (values 1..6).
  late List<int> eggDeck;

  /// Claimed Egg cards per player.
  late List<List<int>> eggs;

  /// Total score per player.
  late List<int> scores;

  bool lastBusted = false;
  List<int> lastRolledDice = <int>[];
  String lastEvent = '马埃岛海龟竞速开始！第1颗骰子已掷出，选择【见好就收】或【继续加骰】！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    return rankByScore(scores);
  }

  /// Synchronize pos and stacks in case unit tests mutated one of them directly.
  void _syncBoard() {
    for (var p = 1; p < trackLen; p++) {
      for (final s in stacks[p]) {
        if (s >= 0 && s < players) {
          pos[s] = p;
        }
      }
    }
    for (var s = 0; s < players; s++) {
      final p = pos[s].clamp(0, trackLen - 1);
      pos[s] = p;
      // Remove s from any other stack != p
      for (var other = 0; other < trackLen; other++) {
        if (other != p) stacks[other].remove(s);
      }
      if (p > 0 && !stacks[p].contains(s)) {
        stacks[p].add(s);
      }
    }
  }

  /// The seat that controls decisions on [turn]'s turn (top turtle of [turn]'s stack).
  int get controller {
    _syncBoard();
    final p = pos[turn];
    if (p > 0 && stacks[p].isNotEmpty) {
      return stacks[p].last;
    }
    return turn;
  }

  /// The group of turtles that will move (or bust) on [turn]'s turn:
  /// [turn] and all turtles stacked on top of [turn].
  List<int> get movingGroup {
    _syncBoard();
    final p = pos[turn];
    if (p <= 0) return [turn];
    final st = stacks[p];
    final idx = st.indexOf(turn);
    if (idx == -1) return [turn];
    return List<int>.of(st.sublist(idx));
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [controller];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    final deckSize = mode == 'fast' ? 10 : 15;
    maxTurns = mode == 'fast' ? players * 12 : players * 18;

    turn = 0;
    turnCount = 0;
    phase = 'roll';
    pos = List<int>.filled(players, 0);
    stacks = List.generate(trackLen, (_) => <int>[]);
    eggs = List.generate(players, (_) => <int>[]);
    scores = List<int>.filled(players, 0);

    eggDeck = <int>[
      for (var i = 0; i < deckSize; i++) (i % 6) + 1,
    ]..shuffle(rng);

    dice = <int>[rng.nextInt(6) + 1];
    lastRolledDice = List<int>.of(dice);
    lastBusted = false;
    lastEvent = '${name(turn)} 的回合：首颗骰子掷出 ${dice.first} 点！';
    host.log('【马埃岛海龟竞速】开赛！环形海岛共 21 格，点数和 ≤7 即可乘以骰子数狂飙！');
  }

  int get diceSum => dice.fold<int>(0, (a, b) => a + b);
  int get moveSteps => diceSum * dice.length;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    _syncBoard();
    final ctrl = controller;
    if (seat != ctrl && seat != turn) {
      throw GameError('当前由栈顶海龟 ${name(ctrl)} 做出决策');
    }

    final type = asStr(action['type']);
    if (type == 'stop') {
      if (dice.isEmpty) {
        dice = <int>[rng.nextInt(6) + 1];
      }
      final steps = moveSteps;
      lastRolledDice = List<int>.of(dice);
      lastBusted = false;
      _advanceMovingGroup(steps, ctrl);
      _nextTurn();
      return;
    }

    if (type == 'roll') {
      if (dice.length >= 3) {
        throw GameError('最多只能投掷 3 颗骰子');
      }
      final forced = asInt(action['die'], -1);
      final d = (forced >= 1 && forced <= 6) ? forced : (rng.nextInt(6) + 1);
      dice.add(d);
      lastRolledDice = List<int>.of(dice);
      final sum = diceSum;

      if (sum > 7) {
        // BUST! Moving group washes back to space 0
        lastBusted = true;
        final grp = movingGroup;
        for (final s in grp) {
          final oldP = pos[s];
          stacks[oldP].remove(s);
          pos[s] = 0;
        }
        lastEvent =
            '💥 ${name(ctrl)} 掷出第 ${dice.length} 颗骰子（$dice，总和 $sum > 7）爆点！海龟 ${grp.map(name).join("、")} 冲回起点 0！';
        host.log(lastEvent);
        _nextTurn();
        return;
      }

      lastBusted = false;
      if (dice.length == 3) {
        // 3rd die and sum <= 7: automatically advance sum * 3 spaces!
        final steps = moveSteps;
        _advanceMovingGroup(steps, ctrl);
        _nextTurn();
        return;
      }

      // dice.length is 1 or 2 and sum <= 7: player may now 'stop' or 'roll'
      lastEvent =
          '🎲 ${name(ctrl)} 掷出第 ${dice.length} 颗骰子 $d（当前 $dice，可前进 $moveSteps 格），继续加骰或见好就收？';
      host.log(lastEvent);
      return;
    }

    throw GameError('未知操作：$type');
  }

  void _advanceMovingGroup(int steps, int ctrl) {
    final grp = movingGroup;
    final oldP = pos[turn];
    for (final s in grp) {
      stacks[oldP].remove(s);
    }

    final rawNew = oldP + steps;
    String eggMsg = '';
    int newP = rawNew;
    if (rawNew >= trackLen) {
      newP = rawNew % trackLen;
      final reward = eggDeck.isNotEmpty ? eggDeck.removeLast() : 7;
      eggs[ctrl].add(reward);
      scores[ctrl] += reward;
      // If carrying other turtles, bottom turtle also gets +1 bonus egg point
      for (final s in grp) {
        if (s != ctrl) scores[s] += 1;
      }
      eggMsg = ' 🥚冲过产卵滩（21格）！栈顶 ${name(ctrl)} 收获 +$reward 海龟蛋分！';
      if (eggDeck.isEmpty) {
        // Final bonus egg (+7) claimed
        final bonus = 7;
        eggs[ctrl].add(bonus);
        scores[ctrl] += bonus;
        eggMsg += '（夺得最后一枚 +$bonus 金蛋！）';
      }
    }

    for (final s in grp) {
      pos[s] = newP;
    }
    if (newP > 0) {
      stacks[newP].addAll(grp);
    }

    lastEvent =
        '🐢 ${name(ctrl)} 率领 [${grp.map(name).join("→")}] 以 $dice（×${dice.length}）前进 $steps 格至第 $newP 格！$eggMsg';
    host.log(lastEvent);
  }

  void _nextTurn() {
    turnCount += 1;
    if (eggDeck.isEmpty || turnCount >= maxTurns) {
      phase = 'over';
      host.log('【马埃岛海龟竞速】比赛结束！');
      return;
    }
    turn = (turn + 1) % players;
    dice = <int>[rng.nextInt(6) + 1];
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    scores[seat] = -100;
    phase = 'over';
    host.log('${name(seat)} 认输，比赛结束。');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || !waitingFor.contains(seat)) return null;
    if (dice.isEmpty) return {'type': 'roll'};

    final sum = diceSum;
    final count = dice.length;
    final curP = pos[turn];

    // If current move already crosses >= 21, always stop and claim the egg!
    if (curP + sum * count >= trackLen) {
      return {'type': 'stop'};
    }

    if (count == 1) {
      // With d1 <= 3, safe chance for 2nd die is high (4/6 to 6/6)
      if (sum <= 3) return {'type': 'roll'};
      if (sum == 4 && rng.nextDouble() < 0.5) return {'type': 'roll'};
      return {'type': 'stop'};
    }

    if (count == 2) {
      // With sum <= 3, 3rd die has >= 4/6 chance not to bust
      if (sum <= 3) return {'type': 'roll'};
      if (sum == 4 && rng.nextDouble() < 0.35) return {'type': 'roll'};
      return {'type': 'stop'};
    }

    return {'type': 'stop'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    _syncBoard();
    return {
      'turn': turn,
      'controller': controller,
      'turnCount': turnCount,
      'maxTurns': maxTurns,
      'phase': phase,
      'pos': List<int>.of(pos),
      'stacks': [for (final st in stacks) List<int>.of(st)],
      'movingGroup': movingGroup,
      'dice': List<int>.of(dice),
      'diceSum': diceSum,
      'moveSteps': moveSteps,
      'lastRolledDice': List<int>.of(lastRolledDice),
      'lastBusted': lastBusted,
      'eggDeckCount': eggDeck.length,
      'topEggHint': eggDeck.isNotEmpty ? eggDeck.last : 7,
      'eggs': [for (var s = 0; s < players; s++) List<int>.of(eggs[s])],
      'scores': List<int>.of(scores),
      'lastEvent': lastEvent,
      'canAct': !isOver && (seat == controller || seat == turn),
    };
  }
}
