import '../../src/engine.dart';

class PickominoGame extends GameEngine {
  PickominoGame(super.setup);

  /// Return the Worm value (1..4 🐛) of tile [t] (21..36).
  static int wormValue(int t) {
    if (t < 21) return 0;
    return ((t - 21) ~/ 4 + 1).clamp(1, 4);
  }

  /// Return the point value of a die face (1..5 -> 1..5, 6='🐛' -> 5).
  static int facePoints(int face) => face == 6 ? 5 : face;

  static String faceLabel(int face) => face == 6 ? '🐛(5)' : '$face';

  int maxRounds = 12;
  int round = 1;
  int turn = 0;
  String phase = 'act'; // 'act' | 'over'

  /// Sub-step within a player's turn: 'keep' (must pick a face from currentRoll) | 'decide' (can 'roll' or 'claim').
  String step = 'keep';

  /// Active face-up tiles on the central Grill (sorted ascending, starts 21..36).
  late List<int> grillTiles;

  /// Grill tiles that have been flipped face-down (removed from play due to Busts).
  late List<int> flippedTiles;

  /// Vertical Tile Stack per player: stacks[seat].last is the visible & stealable TOP tile!
  late List<List<int>> stacks;

  /// Number of unlocked dice remaining for the active player (starts at 8).
  int diceRemaining = 8;

  /// Currently rolled unlocked dice faces (1..6, where 6 = 🐛 Worm).
  late List<int> currentRoll;

  /// Distinct faces (1..6) already locked by the active player this turn.
  late List<int> lockedFaces;

  /// All dice locked by the active player this turn.
  late List<int> lockedDice;

  /// Current point sum of lockedDice (where face 6 = 🐛 counts as 5 points!).
  int lockedSum = 0;

  /// Computed total Worm scores per player.
  late List<int> scores;

  String lastEvent = '虫虫烧烤派对开炉！投掷 8 颗骰子，必须保留至少 1 个 🐛虫虫(6) 才能拿取烧烤砖或抢夺对手顶层砖！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    recalcScores();
    final tieAdjusted = <num>[
      for (var s = 0; s < players; s++)
        scores[s] * 100 + (stacks[s].isEmpty ? 0 : stacks[s].fold<int>(0, (a, b) => a > b ? a : b)),
    ];
    return rankByScore(tieAdjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    return [turn];
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    maxRounds = mode == 'fast' ? 8 : 12;
    round = 1;
    turn = 0;
    phase = 'act';

    grillTiles = [for (var t = 21; t <= 36; t++) t];
    flippedTiles = <int>[];
    stacks = [for (var s = 0; s < players; s++) <int>[]];
    scores = List<int>.filled(players, 0);

    _startTurn(0);
    host.log('【虫虫烧烤派对】16 块虫虫烧烤砖 (21~36) 已上架！凑齐点数抢夺对手栈顶烤砖！');
  }

  void _startTurn(int seat) {
    turn = seat;
    diceRemaining = 8;
    lockedFaces = <int>[];
    lockedDice = <int>[];
    lockedSum = 0;
    step = 'keep';
    currentRoll = _rollDice(diceRemaining);
  }

  List<int> _rollDice(int count) {
    final out = <int>[
      for (var i = 0; i < count; i++) rng.nextInt(6) + 1,
    ]..sort();
    return out;
  }

  void recalcScores() {
    for (var s = 0; s < players; s++) {
      var sum = 0;
      for (final t in stacks[s]) {
        sum += wormValue(t);
      }
      scores[s] = sum;
    }
  }

  /// Distinct faces in `currentRoll` that are NOT yet in `lockedFaces`.
  List<int> keepableFaces() {
    final out = <int>{};
    for (final f in currentRoll) {
      if (!lockedFaces.contains(f)) {
        out.add(f);
      }
    }
    final list = out.toList()..sort();
    return list;
  }

  /// Return the opponent seat whose top tile equals [sum], or -1 if none.
  int stealableOpponentForSum(int seat, int sum) {
    for (var s = 0; s < players; s++) {
      if (s == seat) continue;
      if (stacks[s].isNotEmpty && stacks[s].last == sum) {
        return s;
      }
    }
    return -1;
  }

  /// Return the highest central Grill tile `<= sum`, or -1 if none.
  int claimableGrillTileForSum(int sum) {
    var best = -1;
    for (final t in grillTiles) {
      if (t <= sum && t > best) {
        best = t;
      }
    }
    return best;
  }

  /// Whether [seat] can currently execute `{'type': 'claim'}`.
  bool canClaimNow(int seat) {
    if (!lockedFaces.contains(6)) return false;
    return stealableOpponentForSum(seat, lockedSum) != -1 ||
        claimableGrillTileForSum(lockedSum) != -1;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'keep':
        _handleKeep(seat, action);
        break;
      case 'roll':
        _handleRoll(seat);
        break;
      case 'claim':
        _handleClaim(seat);
        break;
      default:
        throw GameError('未知操作：$type');
    }
  }

  void _handleKeep(int seat, Map<String, dynamic> action) {
    final face = asInt(action['face'], -1);
    if (face < 1 || face > 6) {
      throw GameError('骰面必须在 1~6 之间（6 代表 🐛虫虫）');
    }
    if (lockedFaces.contains(face)) {
      throw GameError('本回合已经保留过【${faceLabel(face)}】了，每次必须选择尚未保留的骰面');
    }
    if (!currentRoll.contains(face)) {
      throw GameError('当前掷出的骰子中没有【${faceLabel(face)}】');
    }

    final count = currentRoll.where((d) => d == face).length;
    lockedFaces.add(face);
    for (var i = 0; i < count; i++) {
      lockedDice.add(face);
    }
    final pts = count * facePoints(face);
    lockedSum += pts;
    diceRemaining -= count;
    currentRoll = <int>[];
    step = 'decide';

    // If no dice remain AND player cannot claim any tile, they automatically BUST!
    if (diceRemaining <= 0 && !canClaimNow(seat)) {
      final reason = !lockedFaces.contains(6)
          ? '未保留任何 🐛虫虫(6)'
          : '总点数 $lockedSum 不足以拿取任何烧烤砖';
      _applyBust(seat, reason: '骰子全部用完但$reason');
      return;
    }

    lastEvent =
        '🎲 ${name(seat)} 锁定 $count 颗【${faceLabel(face)}】（+$pts 点，累计 $lockedSum 点，剩余 $diceRemaining 颗骰子）！';
    host.log(lastEvent);
  }

  void _handleRoll(int seat) {
    // If currentRoll is already populated and all faces are already in lockedFaces, trigger Bust immediately
    if (currentRoll.isNotEmpty && keepableFaces().isEmpty) {
      _applyBust(seat, reason: '掷出的骰面 [${currentRoll.map(faceLabel).join(",")}] 全部已保留过');
      return;
    }
    if (diceRemaining <= 0) {
      throw GameError('没有剩余骰子可重掷，请拿取虫虫砖');
    }

    currentRoll = _rollDice(diceRemaining);
    step = 'keep';

    // Check if every rolled face is already in lockedFaces -> BUST!
    if (keepableFaces().isEmpty) {
      final rollText = currentRoll.map(faceLabel).join(' ');
      _applyBust(seat, reason: '重掷出 [$rollText] 均已锁定过');
      return;
    }

    lastEvent =
        '🎲 ${name(seat)} 重掷剩余 $diceRemaining 颗骰子：${currentRoll.map(faceLabel).join(" ")}（已累计 $lockedSum 点）！';
    host.log(lastEvent);
  }

  void _handleClaim(int seat) {
    if (!lockedFaces.contains(6)) {
      throw GameError('必须至少锁定 1 颗 🐛虫虫(6) 才能拿取烧烤砖');
    }

    final sum = lockedSum;
    final victim = stealableOpponentForSum(seat, sum);
    if (victim != -1) {
      final stolenTile = stacks[victim].removeLast();
      stacks[seat].add(stolenTile);
      recalcScores();
      final worms = wormValue(stolenTile);
      lastEvent =
          '🦅 ${name(seat)} 以精准点数 $sum 抢走 ${name(victim)} 栈顶的【#$stolenTile 号砖 (${"🐛" * worms})】！';
      host.log(lastEvent);
      _advanceTurn();
      return;
    }

    final grillTile = claimableGrillTileForSum(sum);
    if (grillTile != -1) {
      grillTiles.remove(grillTile);
      stacks[seat].add(grillTile);
      recalcScores();
      final worms = wormValue(grillTile);
      lastEvent =
          '🍖 ${name(seat)} 以点数 $sum 从中央烤架拿取【#$grillTile 号砖 (${"🐛" * worms})】置于个人栈顶！';
      host.log(lastEvent);
      _advanceTurn();
      return;
    }

    throw GameError('当前点数 $sum 无法拿取烤架砖或抢夺对手顶层砖');
  }

  /// Apply BUST penalty for [seat]:
  /// 1. Return [seat]'s top tile from `stacks[seat]` back to `grillTiles`.
  /// 2. Flip the highest Grill Tile face-down (removing it from `grillTiles` into `flippedTiles`).
  void _applyBust(int seat, {required String reason}) {
    var returnNote = '';
    if (stacks[seat].isNotEmpty) {
      final returned = stacks[seat].removeLast();
      if (!grillTiles.contains(returned)) {
        grillTiles.add(returned);
        grillTiles.sort();
      }
      returnNote = '，退回栈顶【#$returned 号砖】至烤架';
    }

    var flipNote = '';
    if (grillTiles.isNotEmpty) {
      grillTiles.sort();
      final highest = grillTiles.removeLast();
      flippedTiles.add(highest);
      flipNote = '，并将烤架最高砖【#$highest】翻面作废';
    }

    recalcScores();
    lastEvent = '💥 ${name(seat)} 爆煲 BUST（$reason）$returnNote$flipNote！';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _advanceTurn() {
    recalcScores();
    if (grillTiles.isEmpty) {
      _endGame();
      return;
    }

    final nextSeat = (turn + 1) % players;
    if (nextSeat == 0) {
      round++;
      if (round > maxRounds) {
        _endGame();
        return;
      }
    }
    _startTurn(nextSeat);
  }

  void _endGame() {
    phase = 'over';
    recalcScores();
    var bestSeat = 0;
    for (var s = 1; s < players; s++) {
      if (scores[s] > scores[bestSeat]) bestSeat = s;
    }
    lastEvent =
        '🏆 虫虫烧烤派对圆满收官！${name(bestSeat)} 以 ${scores[bestSeat]} 条美味虫虫 (🐛) 夺得烧烤之王！';
    host.log(lastEvent);
  }

  @override
  Map<String, dynamic> view(int seat) {
    recalcScores();
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'phase': phase,
      'step': step,
      'grillTiles': List<int>.of(grillTiles),
      'flippedTiles': List<int>.of(flippedTiles),
      'topTiles': [
        for (var s = 0; s < players; s++) stacks[s].isEmpty ? null : stacks[s].last,
      ],
      'stackSizes': [
        for (var s = 0; s < players; s++) stacks[s].length,
      ],
      'stacks': [
        for (var s = 0; s < players; s++) List<int>.of(stacks[s]),
      ],
      'diceRemaining': diceRemaining,
      'currentRoll': List<int>.of(currentRoll),
      'keepableFaces': keepableFaces(),
      'lockedFaces': List<int>.of(lockedFaces),
      'lockedDice': List<int>.of(lockedDice),
      'lockedSum': lockedSum,
      'hasWorm': lockedFaces.contains(6),
      'canClaim': canClaimNow(turn),
      'stealableSeat': stealableOpponentForSum(turn, lockedSum),
      'claimableGrillTile': claimableGrillTileForSum(lockedSum),
      'scores': List<int>.of(scores),
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn) return null;

    if (step == 'keep') {
      final keepable = keepableFaces();
      if (keepable.isEmpty) {
        return {'type': 'roll'};
      }
      // Prefer keeping Worm (6) if we don't have one yet and rolled at least one 6
      if (!lockedFaces.contains(6) && keepable.contains(6)) {
        return {'type': 'keep', 'face': 6};
      }
      // Otherwise pick the face that yields the highest total points in this roll
      var bestFace = keepable.first;
      var bestPts = -1;
      for (final f in keepable) {
        final cnt = currentRoll.where((d) => d == f).length;
        final pts = cnt * facePoints(f);
        if (pts >= bestPts) {
          bestPts = pts;
          bestFace = f;
        }
      }
      return {'type': 'keep', 'face': bestFace};
    }

    // step == 'decide'
    if (canClaimNow(seat)) {
      // Claim immediately if we can steal an opponent's top tile or if we have <= 3 dice left or lockedSum >= 24
      if (stealableOpponentForSum(seat, lockedSum) != -1 ||
          diceRemaining <= 3 ||
          lockedSum >= 24) {
        return {'type': 'claim'};
      }
    }

    if (diceRemaining > 0) {
      return {'type': 'roll'};
    }

    if (canClaimNow(seat)) {
      return {'type': 'claim'};
    }

    return {'type': 'roll'};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    stacks[seat].clear();
    recalcScores();
    scores[seat] = -100;
    phase = 'over';
    lastEvent = '${name(seat)} 中途退出烧烤派对，游戏结束！';
    host.log(lastEvent);
  }
}
