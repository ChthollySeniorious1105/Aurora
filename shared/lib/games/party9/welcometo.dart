import 'dart:math';

import '../../src/engine.dart';

class WelcomeToGame extends GameEngine {
  WelcomeToGame(super.setup);

  static const List<int> streetLengths = [10, 11, 12];

  static const List<Set<int>> poolPlanSlots = [
    {2, 6, 8},
    {0, 3, 7},
    {1, 5, 10},
  ];

  static const List<String> effectNames = [
    '篱笆',
    '房产升值',
    '公园',
    '泳池',
    '临时工',
  ];

  static const List<List<int>> parkScores = [
    [0, 2, 4, 10],
    [0, 2, 4, 6, 14],
    [0, 2, 4, 6, 8, 18],
  ];

  static const List<int> poolScores = [0, 3, 6, 9, 13, 17, 21, 26, 31, 36];

  static const List<List<int>> estateScoreTable = [
    [1, 3],
    [2, 3, 4],
    [3, 4, 5, 6],
    [4, 5, 6, 7, 8],
    [5, 6, 7, 8, 10],
    [6, 7, 8, 10, 12],
  ];

  /// Refusal penalties: 0 refusals = 0, 1 refusal = 0, 2 refusals = -3, 3 refusals = -5.
  static const List<int> refusalPenalties = [0, 0, 3, 5];

  static const List<Map<String, dynamic>> cityPlans = [
    {'id': 0, 'name': '双联社区 (2+2)', 'sizes': [2, 2], 'first': 6, 'later': 3},
    {'id': 1, 'name': '阶梯街区 (1+2+3)', 'sizes': [1, 2, 3], 'first': 8, 'later': 4},
    {'id': 2, 'name': '豪华庄园 (3+4)', 'sizes': [3, 4], 'first': 10, 'later': 5},
  ];

  static const List<int> _numberDeckWeights = [
    1, 1, 1, // 1
    2, 2, 2, // 2
    3, 3, 3, 3, // 3
    4, 4, 4, 4, 4, // 4
    5, 5, 5, 5, 5, 5, // 5
    6, 6, 6, 6, 6, 6, 6, // 6
    7, 7, 7, 7, 7, 7, 7, 7, // 7
    8, 8, 8, 8, 8, 8, 8, 8, 8, // 8
    9, 9, 9, 9, 9, 9, 9, 9, // 9
    10, 10, 10, 10, 10, 10, 10, // 10
    11, 11, 11, 11, 11, 11, // 11
    12, 12, 12, 12, 12, // 12
    13, 13, 13, 13, // 13
    14, 14, 14, // 14
    15, 15, 15, // 15
  ];

  late int maxRounds;
  int round = 1;
  List<Map<String, int>> combos = [];

  late List<List<List<int>>> houses;
  late List<List<List<bool>>> fences;
  late List<List<List<bool>>> pools;
  late List<List<int>> parks;
  late List<List<int>> estateLevels;
  late List<int> tempsUsed;
  late List<int> refusals;
  late List<List<int>> planPoints;
  late List<bool> planAlreadyClaimed;
  late List<bool> acted;
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
    return [
      for (var s = 0; s < players; s++)
        if (!acted[s]) s,
    ];
  }

  static bool hasPoolPlan(int street, int slot) =>
      street >= 0 && street < 3 && poolPlanSlots[street].contains(slot);

  @override
  void start() {
    maxRounds = setup.opt<int>('rounds', 20);
    round = 1;
    _over = false;

    houses = [
      for (var s = 0; s < players; s++)
        [for (var st = 0; st < 3; st++) List<int>.filled(streetLengths[st], 0)],
    ];
    fences = [
      for (var s = 0; s < players; s++)
        [
          for (var st = 0; st < 3; st++)
            [for (var i = 0; i < streetLengths[st]; i++) i == streetLengths[st] - 1],
        ],
    ];
    pools = [
      for (var s = 0; s < players; s++)
        [for (var st = 0; st < 3; st++) List<bool>.filled(streetLengths[st], false)],
    ];
    parks = [for (var s = 0; s < players; s++) [0, 0, 0]];
    estateLevels = [for (var s = 0; s < players; s++) List<int>.filled(6, 0)];
    tempsUsed = List<int>.filled(players, 0);
    refusals = List<int>.filled(players, 0);
    planPoints = [for (var s = 0; s < players; s++) [0, 0, 0]];
    planAlreadyClaimed = [false, false, false];
    acted = List<bool>.filled(players, false);
    scores = List<int>.filled(players, 0);
    lastEvent = '第 1 轮开始，请选择门牌与施工组合！';

    _dealCombos();
  }

  void _dealCombos() {
    combos = [
      for (var i = 0; i < 3; i++)
        {
          'number': _numberDeckWeights[rng.nextInt(_numberDeckWeights.length)],
          'effect': rng.nextInt(5),
        },
    ];
  }

  /// Checks whether [finalNum] can be legally written at ([street], [slot]) for [seat].
  bool canWriteNumber(int seat, int street, int slot, int finalNum) {
    if (street < 0 || street >= 3) return false;
    final len = streetLengths[street];
    if (slot < 0 || slot >= len) return false;
    if (finalNum < 1 || finalNum > 17) return false;
    final row = houses[seat][street];
    if (row[slot] != 0) return false;
    for (var i = 0; i < slot; i++) {
      if (row[i] > 0 && row[i] >= finalNum) return false;
    }
    for (var i = slot + 1; i < len; i++) {
      if (row[i] > 0 && row[i] <= finalNum) return false;
    }
    return true;
  }

  /// Returns sizes of all completed estates (1..6) for [seat].
  /// A segment [start..end] on a street is a completed estate if its left boundary is fenced
  /// (start == 0 or fences[start-1]), its right boundary is fenced (end == len-1 or fences[end]),
  /// there are no internal fences, every house in [start..end] is > 0, and size is in 1..6.
  List<int> completedEstateSizes(int seat) {
    final result = <int>[];
    for (var st = 0; st < 3; st++) {
      final len = streetLengths[st];
      final row = houses[seat][st];
      final fRow = fences[seat][st];
      var segStart = 0;
      for (var i = 0; i < len; i++) {
        final isEnd = (i == len - 1) || fRow[i];
        if (isEnd) {
          final sz = i - segStart + 1;
          var allFilled = true;
          for (var k = segStart; k <= i; k++) {
            if (row[k] <= 0) {
              allFilled = false;
              break;
            }
          }
          if (allFilled && sz >= 1 && sz <= 6) {
            result.add(sz);
          }
          segStart = i + 1;
        }
      }
    }
    return result;
  }

  bool _satisfiesPlan(List<int> completedSizes, List<int> reqSizes) {
    final avail = List<int>.of(completedSizes);
    for (final r in reqSizes) {
      final idx = avail.indexOf(r);
      if (idx < 0) return false;
      avail.removeAt(idx);
    }
    return true;
  }

  Map<String, int> scoreBreakdown(int seat) {
    // 1. Parks
    var parkPts = 0;
    for (var st = 0; st < 3; st++) {
      final p = parks[seat][st].clamp(0, parkScores[st].length - 1);
      parkPts += parkScores[st][p];
    }

    // 2. Pools
    var poolCount = 0;
    for (var st = 0; st < 3; st++) {
      for (final b in pools[seat][st]) {
        if (b) poolCount++;
      }
    }
    final poolPts = poolScores[poolCount.clamp(0, poolScores.length - 1)];

    // 3. Completed Estates
    var estatePts = 0;
    final sizes = completedEstateSizes(seat);
    for (final sz in sizes) {
      final lvl = estateLevels[seat][sz - 1].clamp(0, estateScoreTable[sz - 1].length - 1);
      estatePts += estateScoreTable[sz - 1][lvl];
    }

    // 4. City Plans
    final planPts = planPoints[seat][0] + planPoints[seat][1] + planPoints[seat][2];

    // 5. Temp Agency bonus (1 pt per temp used, max 7)
    final tempPts = min(7, tempsUsed[seat]);

    // 6. Refusal penalty
    final refIdx = refusals[seat].clamp(0, refusalPenalties.length - 1);
    final penalty = refusalPenalties[refIdx];

    final total = max(0, parkPts + poolPts + estatePts + planPts + tempPts - penalty);
    return {
      'parks': parkPts,
      'pools': poolPts,
      'estates': estatePts,
      'plans': planPts,
      'temps': tempPts,
      'penalty': penalty,
      'total': total,
    };
  }

  int computeScore(int seat) => scoreBreakdown(seat)['total']!;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players || acted[seat]) {
      throw GameError('本轮你已完成操作');
    }

    final type = asStr(action['type']);
    if (type == 'refuse') {
      refusals[seat] = (refusals[seat] + 1).clamp(0, 3);
      acted[seat] = true;
      lastEvent = '${name(seat)} 拒签了工程许可（累计 ${refusals[seat]}/3）';
      _checkRoundEnd();
      return;
    }

    if (type == 'build') {
      final comboIdx = asInt(action['combo']);
      if (comboIdx < 0 || comboIdx >= combos.length) {
        throw GameError('无效的卡牌组合编号');
      }
      final street = asInt(action['street']);
      if (street < 0 || street >= 3) {
        throw GameError('无效的街道编号');
      }
      final len = streetLengths[street];
      final slot = asInt(action['slot']);
      if (slot < 0 || slot >= len) {
        throw GameError('无效的房屋槽位');
      }
      if (houses[seat][street][slot] != 0) {
        throw GameError('该地块已有房屋');
      }

      final baseNum = combos[comboIdx]['number']!;
      final effect = combos[comboIdx]['effect']!;
      var finalNum = baseNum;
      if (effect == 4) {
        final delta = asInt(action['delta'], 0);
        if (delta < -2 || delta > 2) {
          throw GameError('临时工调整值必须在 -2 到 +2 之间');
        }
        finalNum = baseNum + delta;
      }
      if (finalNum < 1 || finalNum > 17) {
        throw GameError('门牌号必须在 1..17 之间');
      }

      for (var i = 0; i < slot; i++) {
        if (houses[seat][street][i] > 0 && houses[seat][street][i] >= finalNum) {
          throw GameError('门牌号必须严格大于左侧已有房屋（${houses[seat][street][i]}）');
        }
      }
      for (var i = slot + 1; i < len; i++) {
        if (houses[seat][street][i] > 0 && houses[seat][street][i] <= finalNum) {
          throw GameError('门牌号必须严格小于右侧已有房屋（${houses[seat][street][i]}）');
        }
      }

      houses[seat][street][slot] = finalNum;

      if (effect == 0) {
        // Surveyor: build a fence on right of fIdx
        final fIdx = asInt(action['fence'], -1);
        final fStreet = asInt(action['fenceStreet'], street);
        if (fIdx >= 0 && fStreet >= 0 && fStreet < 3 && fIdx < streetLengths[fStreet] - 1) {
          fences[seat][fStreet][fIdx] = true;
        }
      } else if (effect == 1) {
        // Real Estate: upgrade estate size 1..6
        var sz = asInt(action['estateSize'], 0);
        if (sz < 1 || sz > 6) {
          sz = 2; // fallback
        }
        final maxLvl = estateScoreTable[sz - 1].length - 1;
        if (estateLevels[seat][sz - 1] < maxLvl) {
          estateLevels[seat][sz - 1]++;
        }
      } else if (effect == 2) {
        // Landscaper: +1 park on street
        final maxP = parkScores[street].length - 1;
        if (parks[seat][street] < maxP) {
          parks[seat][street]++;
        }
      } else if (effect == 3) {
        // Pool: build pool if slot has pool plan
        if (hasPoolPlan(street, slot)) {
          pools[seat][street][slot] = true;
        }
      } else if (effect == 4) {
        tempsUsed[seat]++;
      }

      acted[seat] = true;
      lastEvent = '${name(seat)} 在第 ${street + 1} 街填入了 $finalNum 号（${effectNames[effect]}）';
      _checkRoundEnd();
      return;
    }

    throw GameError('未知操作');
  }

  void _checkRoundEnd() {
    if (!acted.every((x) => x)) {
      for (var s = 0; s < players; s++) {
        scores[s] = computeScore(s);
      }
      return;
    }

    // Evaluate City Plan milestones simultaneously for this round
    final newlyClaimed = [false, false, false];
    for (var s = 0; s < players; s++) {
      final sizes = completedEstateSizes(s);
      for (var p = 0; p < 3; p++) {
        if (planPoints[s][p] == 0) {
          final req = (cityPlans[p]['sizes'] as List).cast<int>();
          if (_satisfiesPlan(sizes, req)) {
            final pts = planAlreadyClaimed[p]
                ? cityPlans[p]['later'] as int
                : cityPlans[p]['first'] as int;
            planPoints[s][p] = pts;
            newlyClaimed[p] = true;
            host.log('${name(s)} 达成城市规划「${cityPlans[p]['name']}」，获得 $pts 分！');
          }
        }
      }
    }
    for (var p = 0; p < 3; p++) {
      if (newlyClaimed[p]) planAlreadyClaimed[p] = true;
    }

    for (var s = 0; s < players; s++) {
      scores[s] = computeScore(s);
    }

    final anyRefusedOut = refusals.any((r) => r >= 3);
    final anyAllFilled = [for (var s = 0; s < players; s++) s]
        .any((s) => houses[s].every((st) => st.every((h) => h > 0)));

    if (anyRefusedOut || anyAllFilled || round >= maxRounds) {
      _over = true;
      lastEvent = '社区建设结束，最终得分结算完成！';
      host.log(lastEvent);
      return;
    }

    round++;
    acted.fillRange(0, players, false);
    _dealCombos();
    lastEvent = '第 $round 轮开始，请同时选择施工组合！';
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || acted[seat]) return null;

    Map<String, dynamic>? bestMove;
    var bestScore = -999999.0;
    final candidates = <Map<String, dynamic>>[];

    for (var c = 0; c < combos.length; c++) {
      final baseNum = combos[c]['number']!;
      final effect = combos[c]['effect']!;
      final deltas = effect == 4 ? const [0, -1, 1, -2, 2] : const [0];

      for (final d in deltas) {
        final finalNum = baseNum + d;
        if (finalNum < 1 || finalNum > 17) continue;

        for (var st = 0; st < 3; st++) {
          final len = streetLengths[st];
          for (var sl = 0; sl < len; sl++) {
            if (!canWriteNumber(seat, st, sl, finalNum)) continue;

            // Choose effect parameters
            var fIdx = -1;
            var estateSz = 2;
            if (effect == 0) {
              // Pick a good fence spot on st where adjacent house is filled and segment size <= 4
              for (var i = 0; i < len - 1; i++) {
                if (!fences[seat][st][i] &&
                    (houses[seat][st][i] > 0 || i == sl || houses[seat][st][i + 1] > 0)) {
                  fIdx = i;
                  break;
                }
              }
            } else if (effect == 1) {
              // Pick an estate size 2..4 that can still be upgraded
              for (final sz in const [2, 3, 4, 1, 5, 6]) {
                if (estateLevels[seat][sz - 1] < estateScoreTable[sz - 1].length - 1) {
                  estateSz = sz;
                  break;
                }
              }
            }

            final move = <String, dynamic>{
              'type': 'build',
              'combo': c,
              'street': st,
              'slot': sl,
              'fence': fIdx,
              'estateSize': estateSz,
              'delta': d,
            };
            candidates.add(move);

            final idealPos = (finalNum - 1) / 16.0 * (len - 1);
            var eval = -((sl - idealPos).abs() * 3.0);
            if (effect == 3 && hasPoolPlan(st, sl)) eval += 8.0;
            if (effect == 2 && parks[seat][st] < parkScores[st].length - 1) eval += 5.0;
            if (effect == 1) eval += 4.0;
            if (effect == 0 && fIdx >= 0) eval += 3.5;
            if (effect == 4) eval += 2.0;

            if (eval > bestScore) {
              bestScore = eval;
              bestMove = move;
            }
          }
        }
      }
    }

    if (candidates.isEmpty) {
      return {'type': 'refuse'};
    }
    if (botLevel == 0 && candidates.length > 1) {
      return candidates[rng.nextInt(candidates.length)];
    }
    return bestMove ?? candidates.first;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final s = seat >= 0 && seat < players ? seat : 0;
    return {
      'round': round,
      'maxRounds': maxRounds,
      'combos': [
        for (var i = 0; i < combos.length; i++)
          {
            'index': i,
            'number': combos[i]['number'],
            'effect': combos[i]['effect'],
            'effectName': effectNames[combos[i]['effect']!],
          },
      ],
      'poolPlans': [
        for (var st = 0; st < 3; st++) [for (final p in poolPlanSlots[st]) p],
      ],
      'cityPlans': [
        for (var p = 0; p < 3; p++)
          {
            ...cityPlans[p],
            'claimed': planAlreadyClaimed[p],
          },
      ],
      'mySeat': s,
      'houses': [for (final row in houses[s]) List<int>.of(row)],
      'fences': [for (final row in fences[s]) List<bool>.of(row)],
      'pools': [for (final row in pools[s]) List<bool>.of(row)],
      'parks': List<int>.of(parks[s]),
      'estateLevels': List<int>.of(estateLevels[s]),
      'tempsUsed': tempsUsed[s],
      'refusals': refusals[s],
      'planPoints': List<int>.of(planPoints[s]),
      'breakdown': scoreBreakdown(s),
      'allSheets': [
        for (var p = 0; p < players; p++)
          {
            'seat': p,
            'acted': acted[p],
            'score': scores[p],
            'refusals': refusals[p],
            'parks': List<int>.of(parks[p]),
            'houses': [for (final row in houses[p]) List<int>.of(row)],
            'fences': [for (final row in fences[p]) List<bool>.of(row)],
            'pools': [for (final row in pools[p]) List<bool>.of(row)],
            'breakdown': scoreBreakdown(p),
          },
      ],
      'scores': List<int>.of(scores),
      'acted': List<bool>.of(acted),
      'lastEvent': lastEvent,
      'waitingFor': waitingFor,
      'over': _over,
      if (_over) 'placings': placings,
    };
  }
}
