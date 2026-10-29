import '../../src/engine.dart';

/// 拉斯维加斯 (Las Vegas) — 2-5人骰子区域多数与平局抵消博弈桌游
class LasVegasGame extends GameEngine {
  LasVegasGame(super.setup);

  static const List<String> casinoNames = [
    '1号·金沙娱乐场',
    '2号·百乐宫赌场',
    '3号·凯撒皇宫',
    '4号·威尼斯人',
    '5号·永利皇宫',
    '6号·米高梅大酒店',
  ];

  late int totalRounds;
  late bool useNeutral;

  int round = 1;
  int turn = 0;
  bool _over = false;
  String lastEvent = '';

  final List<int> banknoteDeck = [];
  late List<List<int>> casinoBanknotes; // 6 casinos -> sorted descending banknotes (in $k, e.g. 90 = $90k)
  late List<List<int>> casinoDice; // 6 casinos -> list of dice count per player
  late List<int> casinoNeutral; // 6 casinos -> neutral white dice count

  late List<int> remainingOwn;
  late List<int> remainingNeutral;
  late List<int> money; // total money in $k per player

  List<int> rolledOwn = [];
  List<int> rolledNeutral = [];
  List<int> rolledDice = [];
  List<Map<String, dynamic>> lastRoundSummary = [];

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  List<int>? get placings {
    if (!_over) return null;
    return rankByScore(money);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over) return;
    _over = true;
    money[seat] = -1;
    lastEvent = '${name(seat)} 认输';
    host.log(lastEvent);
  }

  @override
  void start() {
    totalRounds = setup.opt<int>('rounds', 4);
    useNeutral = setup.opt<bool>('neutral', false);
    money = List<int>.filled(players, 0);
    round = 1;
    _initBanknoteDeck();
    _startRound();
    host.log('拉斯维加斯开局！共 $totalRounds 轮${useNeutral ? '（开启中立白骰大老板变体）' : ''}。');
  }

  void _initBanknoteDeck() {
    banknoteDeck.clear();
    const values = [10, 20, 30, 40, 50, 60, 70, 80, 90];
    for (final v in values) {
      for (var i = 0; i < 6; i++) {
        banknoteDeck.add(v);
      }
    }
    banknoteDeck.shuffle(rng);
  }

  int _drawBanknote() {
    if (banknoteDeck.isEmpty) {
      _initBanknoteDeck();
    }
    return banknoteDeck.removeLast();
  }

  void _startRound() {
    casinoBanknotes = List.generate(6, (_) => <int>[]);
    casinoDice = List.generate(6, (_) => List<int>.filled(players, 0));
    casinoNeutral = List<int>.filled(6, 0);

    for (var c = 0; c < 6; c++) {
      var sum = 0;
      while (sum < 50) {
        final b = _drawBanknote();
        casinoBanknotes[c].add(b);
        sum += b;
      }
      casinoBanknotes[c].sort((a, b) => b.compareTo(a));
    }

    remainingOwn = List<int>.filled(players, 8);
    remainingNeutral = List<int>.filled(players, useNeutral ? 2 : 0);

    turn = (round - 1) % players;
    _rollForCurrentTurn();
    lastEvent = '第 $round/$totalRounds 轮开始，轮到 ${name(turn)} 投掷并放置骰子';
  }

  int totalRemainingDice(int seat) => remainingOwn[seat] + remainingNeutral[seat];

  void _rollForCurrentTurn() {
    rolledOwn = [
      for (var i = 0; i < remainingOwn[turn]; i++) 1 + rng.nextInt(6),
    ]..sort();
    rolledNeutral = [
      for (var i = 0; i < remainingNeutral[turn]; i++) 1 + rng.nextInt(6),
    ]..sort();
    rolledDice = [...rolledOwn, ...rolledNeutral]..sort();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你的回合');
    final type = asStr(action['type']);
    if (type != 'place') throw GameError('未知操作');

    final face = asInt(action['face'], 0);
    if (face < 1 || face > 6) throw GameError('请选择 1 到 6 号赌场');
    if (!rolledDice.contains(face)) {
      throw GameError('你当前投出的骰子中没有点数 $face');
    }

    final ownCnt = rolledOwn.where((d) => d == face).length;
    final neuCnt = rolledNeutral.where((d) => d == face).length;
    final cIdx = face - 1;

    remainingOwn[seat] -= ownCnt;
    casinoDice[cIdx][seat] += ownCnt;

    remainingNeutral[seat] -= neuCnt;
    casinoNeutral[cIdx] += neuCnt;

    final descParts = <String>[];
    if (ownCnt > 0) descParts.add('$ownCnt颗己方骰');
    if (neuCnt > 0) descParts.add('$neuCnt颗中立白骰');
    lastEvent = '${name(seat)} 将 ${descParts.join('+')} 押注到 $face 号赌场';

    _advanceTurn();
  }

  void _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final cand = (turn + step) % players;
      if (totalRemainingDice(cand) > 0) {
        turn = cand;
        _rollForCurrentTurn();
        return;
      }
    }
    // All players have 0 dice remaining -> resolve round!
    _resolveRound();
  }

  /// Resolves a single casino's payouts and returns a summary map.
  Map<String, dynamic> resolveSingleCasino(int cIdx, {bool applyMoney = true}) {
    final notes = List<int>.of(casinoBanknotes[cIdx])..sort((a, b) => b.compareTo(a));
    // Contenders: seat 0..players-1, and -1 for neutral
    final counts = <int, int>{};
    for (var s = 0; s < players; s++) {
      if (casinoDice[cIdx][s] > 0) {
        counts[s] = casinoDice[cIdx][s];
      }
    }
    if (useNeutral && casinoNeutral[cIdx] > 0) {
      counts[-1] = casinoNeutral[cIdx];
    }

    // Frequency of each non-zero dice count
    final freq = <int, int>{};
    for (final cnt in counts.values) {
      freq[cnt] = (freq[cnt] ?? 0) + 1;
    }

    final tiedSeats = <int>[];
    final uniqueContenders = <(int, int)>[]; // (seat, count)
    for (final entry in counts.entries) {
      if ((freq[entry.value] ?? 0) >= 2) {
        tiedSeats.add(entry.key);
      } else {
        uniqueContenders.add((entry.key, entry.value));
      }
    }

    uniqueContenders.sort((a, b) => b.$2.compareTo(a.$2));

    final awards = <Map<String, dynamic>>[];
    for (var i = 0; i < uniqueContenders.length && i < notes.length; i++) {
      final (seat, cnt) = uniqueContenders[i];
      final note = notes[i];
      if (applyMoney && seat >= 0) {
        money[seat] += note;
      }
      awards.add({
        'seat': seat,
        'dice': cnt,
        'banknote': note,
      });
    }

    return {
      'casino': cIdx + 1,
      'banknotes': notes,
      'tiedSeats': tiedSeats,
      'awards': awards,
    };
  }

  void _resolveRound() {
    lastRoundSummary = [];
    final logLines = <String>[];

    for (var c = 0; c < 6; c++) {
      final res = resolveSingleCasino(c, applyMoney: true);
      lastRoundSummary.add(res);
      final awards = res['awards'] as List<Map<String, dynamic>>;
      if (awards.isNotEmpty) {
        final items = awards.map((a) {
          final s = a['seat'] as int;
          final who = s < 0 ? '中立庄家' : name(s);
          return '$who(\$${a['banknote']}k)';
        }).join('、');
        logLines.add('${c + 1}号:$items');
      }
    }

    host.log('第 $round 轮结算：${logLines.isEmpty ? '全部平局抵消' : logLines.join('；')}');

    if (round >= totalRounds) {
      _over = true;
      rolledOwn = [];
      rolledNeutral = [];
      rolledDice = [];
      final p = placings!;
      final winners = [
        for (var s = 0; s < players; s++)
          if (p[s] == 1) '${name(s)}(\$${money[s]}k)',
      ];
      lastEvent = '全 $totalRounds 轮结束！大赢家：${winners.join('、')}';
      host.log(lastEvent);
      return;
    }

    round += 1;
    _startRound();
  }

  @override
  Map<String, dynamic> view(int seat) {
    final faceCounts = <String, Map<String, int>>{};
    for (var f = 1; f <= 6; f++) {
      final ownC = rolledOwn.where((d) => d == f).length;
      final neuC = rolledNeutral.where((d) => d == f).length;
      if (ownC + neuC > 0) {
        faceCounts['$f'] = {'own': ownC, 'neutral': neuC, 'total': ownC + neuC};
      }
    }

    return {
      'round': round,
      'totalRounds': totalRounds,
      'useNeutral': useNeutral,
      'turn': turn,
      'money': money,
      'remainingOwn': remainingOwn,
      'remainingNeutral': remainingNeutral,
      'casinoBanknotes': casinoBanknotes,
      'casinoDice': casinoDice,
      'casinoNeutral': casinoNeutral,
      'rolledOwn': rolledOwn,
      'rolledNeutral': rolledNeutral,
      'rolledDice': rolledDice,
      'faceCounts': faceCounts,
      'lastEvent': lastEvent,
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      if (_over) 'placings': placings,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn || rolledDice.isEmpty) return null;
    final availableFaces = rolledDice.toSet().toList()..sort();
    if (availableFaces.length == 1 || botLevel == 0) {
      final pick = availableFaces[rng.nextInt(availableFaces.length)];
      return {'type': 'place', 'face': pick};
    }

    // Evaluate each available face value
    var bestFace = availableFaces.first;
    var bestScore = -999999.0;

    for (final f in availableFaces) {
      final cIdx = f - 1;
      final ownAdd = rolledOwn.where((d) => d == f).length;
      final neuAdd = rolledNeutral.where((d) => d == f).length;

      final simMyDice = casinoDice[cIdx][seat] + ownAdd;
      final simNeuDice = casinoNeutral[cIdx] + neuAdd;
      final notes = casinoBanknotes[cIdx];
      final topNote = notes.isEmpty ? 0 : notes.first;

      // Check how we stand at casino cIdx after placing
      final allCounts = <int, int>{};
      for (var s = 0; s < players; s++) {
        final cnt = s == seat ? simMyDice : casinoDice[cIdx][s];
        if (cnt > 0) allCounts[s] = cnt;
      }
      if (useNeutral && simNeuDice > 0) {
        allCounts[-1] = simNeuDice;
      }

      final freq = <int, int>{};
      for (final cnt in allCounts.values) {
        freq[cnt] = (freq[cnt] ?? 0) + 1;
      }

      var score = 0.0;
      if (ownAdd > 0) {
        final myCnt = allCounts[seat] ?? 0;
        if ((freq[myCnt] ?? 0) == 1) {
          // Unique count: see which banknote rank we currently hold
          final higherUnique = allCounts.entries
              .where((e) => e.key != seat && (freq[e.value] ?? 0) == 1 && e.value > myCnt)
              .length;
          if (higherUnique < notes.length) {
            score += notes[higherUnique] * 2.0;
          }
        } else {
          // Tied right now
          score -= 15.0;
        }
        // Prefer not dumping too many dice at once early unless high payout
        score -= ownAdd * 4.5;
      }

      if (neuAdd > 0 && ownAdd == 0) {
        // Using neutral dice to tie an opponent's leader at a high-value casino is great!
        final tiedOpponent = allCounts.entries.any((e) => e.key >= 0 && e.key != seat && e.value == simNeuDice);
        if (tiedOpponent) {
          score += topNote * 1.8;
        } else {
          score += 10.0;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestFace = f;
      }
    }

    return {'type': 'place', 'face': bestFace};
  }
}
