import 'dart:math';

import '../../src/engine.dart';

const String calicoRules = '''
# 猫咪与花被 (Calico) 规则说明

## 游戏概述
《猫咪与花被》(Calico) 是一款兼具色彩与花纹双重属性的六边形拼布策略桌游（支持 1~4 人）。每位玩家拥有一块 5×5 的六边形花被版图，外圈预印有初始花布边框，内部设有 3 个室内设计目标格以及若干空白拼布格。玩家通过每回合从手牌缝制 1 块布片并从中央市场补充 1 块布片，达成设计目标、缝上彩色纽扣并吸引可爱的猫咪前来打盹！

## 双重属性布片
- 每块布片同时拥有 **颜色 (0..5)** 与 **图案 (0..5)** 两种属性：
  - 6 种颜色：0 靛蓝、1 琥珀黄、2 珊瑚红、3 薄荷绿、4 薰衣草紫、5 樱花粉。
  - 6 种图案：0 条纹、1 波点、2 碎花、3 格纹、4 藤蔓、5 星芒。

## 回合流程
- 每位玩家手中始终持有 2 块布片（`hands[seat][0..1]`），中央市场展示 3 块面朝上的布片（`market[0..2]`）。
- 轮到自己时，必须执行一个复合行动：
  1. **缝制布片**：从手牌的 2 块布片中选择 1 块，放置到自己花被版图上的任意 1 个空白格 `(r, c)`。
  2. **补充手牌**：从中央市场的 3 块布片中选择 1 块加入手牌，随后从布袋自动翻开 1 块新布片补满市场。
- 当所有玩家花被上的空白格全部填满时，游戏立即结束并进行三层终局计分。

## 三层计分规则
1. **室内设计目标（Goal Cells，位于 `(1,2)`、`(2,1)`、`(2,3)`）**：
   - 每个目标格周围环绕着 6 个相邻花布格，印有特定分布要求：
     - `AAA-BBB`：6 个相邻格分成 2 组，每组各 3 个相同属性（3+3）。
     - `AA-BB-CC`：6 个相邻格分成 3 组，每组各 2 个相同属性（2+2+2）。
     - `A-B-C-D-E-F`：6 个相邻格的 6 个属性互不相同（1+1+1+1+1+1）。
   - 若相邻 6 格的 **颜色分布** 符合目标要求，或 **图案分布** 符合目标要求，獲得蓝章 **7 分**；
   - 若 **颜色分布与图案分布同时符合** 目标要求，获得金章 **11 分**！
2. **彩色纽扣与彩虹纽扣（Color Buttons）**：
   - 花被上每形成一个由 **至少 3 块同色布片** 相连组成的连通区域（含边框预印布片），即可在该区域缝上 1 枚对应颜色的纽扣，每枚纽扣价值 **+3 分**。
   - 若你在全部 6 种颜色上都至少获得了 1 枚纽扣，额外获得 1 枚 **彩虹纽扣（+3 分）**！
3. **吸引猫咪（Cats）**：
   - 场上共有 3 只猫咪，每只猫咪偏爱 2 种特定图案，并要求不同大小的同图案连通群：
     - **米莉 (Millie)**：要求 **≥ 3 块** 相连的偏爱图案布片，每吸引 1 只得 **+3 分**。
     - **提比特 (Tibbit)**：要求 **≥ 4 块** 相连的偏爱图案布片，每吸引 1 只得 **+5 分**。
     - **椰子 (Coconut)**：要求 **≥ 5 块** 相连的偏爱图案布片，每吸引 1 只得 **+7 分**。

## 房间选项
- **猫咪配置 (`catSetup`)**：可选新手推荐猫咪图案分配或每局随机分配猫咪偏爱图案。
''';

class CalicoCat {
  final String id;
  final String name;
  final int minSize;
  final int vp;
  final List<int> patterns;

  const CalicoCat({
    required this.id,
    required this.name,
    required this.minSize,
    required this.vp,
    required this.patterns,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'minSize': minSize,
        'vp': vp,
        'patterns': patterns,
      };
}

class Calico extends GameEngine {
  static const int boardSize = 5;
  static const List<String> colorNames = ['靛蓝', '琥珀', '珊瑚', '薄荷', '紫藤', '樱粉'];
  static const List<String> patternNames = ['条纹', '波点', '碎花', '格纹', '藤蔓', '星芒'];

  static const List<(int, int, String)> goalDefs = [
    (1, 2, 'AAA-BBB'),
    (2, 1, 'AA-BB-CC'),
    (2, 3, 'A-B-C-D-E-F'),
  ];

  /// 10 interior / inner-border playable cells on the 5×5 quilt board.
  static const Set<(int, int)> initialEmptyCells = {
    (0, 2),
    (1, 1),
    (1, 3),
    (2, 0),
    (2, 2),
    (2, 4),
    (3, 1),
    (3, 2),
    (3, 3),
    (4, 2),
  };

  /// Exact 6 non-goal patch neighbors for each of the 3 interior Goal cells.
  static List<(int, int)> goalNeighbors(int gr, int gc) {
    if (gr == 1 && gc == 2) {
      return const [(0, 1), (0, 2), (0, 3), (1, 1), (1, 3), (2, 2)];
    }
    if (gr == 2 && gc == 1) {
      return const [(1, 0), (1, 1), (2, 0), (2, 2), (3, 0), (3, 1)];
    }
    if (gr == 2 && gc == 3) {
      return const [(1, 3), (1, 4), (2, 2), (2, 4), (3, 2), (3, 3)];
    }
    return hexNeighbors(gr, gc);
  }

  /// Odd-r offset hex neighbors inside 5×5.
  static List<(int, int)> hexNeighbors(int r, int c) {
    final deltas = r.isOdd
        ? const [(-1, 0), (-1, 1), (0, -1), (0, 1), (1, 0), (1, 1)]
        : const [(-1, -1), (-1, 0), (0, -1), (0, 1), (1, -1), (1, 0)];
    final out = <(int, int)>[];
    for (final (dr, dc) in deltas) {
      final nr = r + dr;
      final nc = c + dc;
      if (nr >= 0 && nr < boardSize && nc >= 0 && nc < boardSize) {
        out.add((nr, nc));
      }
    }
    return out;
  }

  late List<List<List<Map<String, dynamic>?>>> quilt;
  late List<List<Map<String, int>>> hands;
  late List<Map<String, int>> market;
  late List<Map<String, int>> bag;
  late List<CalicoCat> cats;

  int turn = 0;
  int round = 1;
  bool over = false;
  int resignedSeat = -1;
  final List<String> recent = [];

  Calico(super.setup);

  void _log(String msg) {
    host.log(msg);
    recent.add(msg);
    if (recent.length > 12) recent.removeAt(0);
  }

  @override
  void start() {
    final randomCats = setup.opt<String>('catSetup', 'standard') == 'random';
    final patOrder = [0, 1, 2, 3, 4, 5];
    if (randomCats) {
      patOrder.shuffle(rng);
    }
    cats = [
      CalicoCat(id: 'millie', name: '米莉', minSize: 3, vp: 3, patterns: [patOrder[0], patOrder[1]]),
      CalicoCat(id: 'tibbit', name: '提比特', minSize: 4, vp: 5, patterns: [patOrder[2], patOrder[3]]),
      CalicoCat(id: 'coconut', name: '椰子', minSize: 5, vp: 7, patterns: [patOrder[4], patOrder[5]]),
    ];

    bag = [
      for (var copy = 0; copy < 3; copy++)
        for (var c = 0; c < 6; c++)
          for (var p = 0; p < 6; p++) {'color': c, 'pattern': p},
    ];
    bag.shuffle(rng);

    quilt = List.generate(players, (seat) {
      return List.generate(boardSize, (r) {
        return List.generate(boardSize, (c) {
          for (final (gr, gc, gType) in goalDefs) {
            if (r == gr && c == gc) {
              return <String, dynamic>{'goal': gType, 'color': -1, 'pattern': -1};
            }
          }
          if (initialEmptyCells.contains((r, c))) {
            return null;
          }
          final borderColor = (r * 2 + c + seat) % 6;
          final borderPattern = (r + c * 2 + seat) % 6;
          return <String, dynamic>{
            'color': borderColor,
            'pattern': borderPattern,
            'border': true,
          };
        });
      });
    });

    hands = List.generate(players, (_) => [_drawTile(), _drawTile()]);
    market = [_drawTile(), _drawTile(), _drawTile()];
    turn = 0;
    round = 1;
    over = false;
    _log('猫咪与花被开始！缝制花布完成目标、收集纽扣并吸引猫咪。');
  }

  Map<String, int> _drawTile() {
    if (bag.isEmpty) {
      return {'color': rng.nextInt(6), 'pattern': rng.nextInt(6)};
    }
    return Map<String, int>.of(bag.removeLast());
  }

  int emptySpacesOf(int seat) {
    var count = 0;
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (quilt[seat][r][c] == null) count++;
      }
    }
    return count;
  }

  static bool matchesGoalDistribution(List<int> values, String goalType) {
    if (values.length < 6 || values.any((v) => v < 0)) return false;
    final freq = <int, int>{};
    for (final v in values) {
      freq[v] = (freq[v] ?? 0) + 1;
    }
    final counts = freq.values.toList()..sort();
    switch (goalType) {
      case 'AAA-BBB':
        return counts.length == 2 && counts[0] == 3 && counts[1] == 3;
      case 'AA-BB-CC':
        return counts.length == 3 && counts[0] == 2 && counts[1] == 2 && counts[2] == 2;
      case 'A-B-C-D-E-F':
        return counts.length == 6;
      default:
        return false;
    }
  }

  /// Evaluates the 3 interior goals for [seat].
  List<Map<String, dynamic>> evaluateGoals(int seat) {
    final res = <Map<String, dynamic>>[];
    for (final (gr, gc, defaultGoal) in goalDefs) {
      final cell = quilt[seat][gr][gc];
      final goalType = (cell?['goal'] as String?) ?? defaultGoal;
      final nbs = goalNeighbors(gr, gc);
      final colors = <int>[];
      final patterns = <int>[];
      var complete = nbs.length == 6;
      for (final (nr, nc) in nbs) {
        final nb = quilt[seat][nr][nc];
        if (nb == null || (nb['color'] as int? ?? -1) < 0) {
          complete = false;
          break;
        }
        colors.add(nb['color'] as int);
        patterns.add(nb['pattern'] as int);
      }
      final colorOk = complete && matchesGoalDistribution(colors, goalType);
      final patternOk = complete && matchesGoalDistribution(patterns, goalType);
      final vp = (colorOk && patternOk)
          ? 11
          : (colorOk || patternOk)
              ? 7
              : 0;
      res.add({
        'r': gr,
        'c': gc,
        'goal': goalType,
        'colorOk': colorOk,
        'patternOk': patternOk,
        'vp': vp,
      });
    }
    return res;
  }

  /// Finds all connected components of a given attribute ('color' or 'pattern').
  List<Map<String, dynamic>> _findGroups(int seat, String attr) {
    final visited = List.generate(boardSize, (_) => List.filled(boardSize, false));
    final groups = <Map<String, dynamic>>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (visited[r][c]) continue;
        final cell = quilt[seat][r][c];
        final val = cell?[attr] as int? ?? -1;
        if (val < 0) continue;
        final comp = <(int, int)>[];
        final q = <(int, int)>[(r, c)];
        visited[r][c] = true;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          comp.add((cr, cc));
          for (final (nr, nc) in hexNeighbors(cr, cc)) {
            if (visited[nr][nc]) continue;
            final nCell = quilt[seat][nr][nc];
            if ((nCell?[attr] as int? ?? -1) == val) {
              visited[nr][nc] = true;
              q.add((nr, nc));
            }
          }
        }
        groups.add({
          'value': val,
          'size': comp.length,
          'cells': [
            for (final (cr, cc) in comp) {'r': cr, 'c': cc}
          ],
        });
      }
    }
    return groups;
  }

  Map<String, dynamic> scoreBreakdown(int seat) {
    final goals = evaluateGoals(seat);
    final goalVp = goals.fold<int>(0, (s, g) => s + (g['vp'] as int));

    final colorGroups = _findGroups(seat, 'color');
    final buttonsByColor = List<int>.filled(6, 0);
    var buttonCount = 0;
    for (final g in colorGroups) {
      final size = g['size'] as int;
      final c = g['value'] as int;
      if (size >= 3 && c >= 0 && c < 6) {
        buttonsByColor[c]++;
        buttonCount++;
      }
    }
    final rainbow = buttonsByColor.every((cnt) => cnt > 0);
    final buttonVp = buttonCount * 3 + (rainbow ? 3 : 0);

    final patternGroups = _findGroups(seat, 'pattern');
    final catCounts = List<int>.filled(cats.length, 0);
    var catVp = 0;
    for (final g in patternGroups) {
      final size = g['size'] as int;
      final pat = g['value'] as int;
      for (var ci = 0; ci < cats.length; ci++) {
        final cat = cats[ci];
        if (cat.patterns.contains(pat) && size >= cat.minSize) {
          catCounts[ci]++;
          catVp += cat.vp;
        }
      }
    }

    return {
      'seat': seat,
      'goals': goals,
      'goalVp': goalVp,
      'buttonsByColor': buttonsByColor,
      'buttonCount': buttonCount,
      'rainbow': rainbow,
      'buttonVp': buttonVp,
      'catCounts': catCounts,
      'catVp': catVp,
      'total': goalVp + buttonVp + catVp,
    };
  }

  int scoreOf(int seat) => scoreBreakdown(seat)['total'] as int;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');
    final type = asStr(action['type']);
    if (type != 'place') throw GameError('无效操作类型');

    final h = asInt(action['handIdx'], 0);
    final r = asInt(action['r'], -1);
    final c = asInt(action['c'], -1);
    final m = asInt(action['marketIdx'], 0);

    if (h < 0 || h >= hands[seat].length) throw GameError('无效的手牌索引');
    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) throw GameError('坐标超出花被范围');
    if (quilt[seat][r][c] != null) throw GameError('该格子已有布片或是目标格');
    if (m < 0 || m >= market.length) throw GameError('无效的市场索引');

    final placed = hands[seat][h];
    quilt[seat][r][c] = {
      'color': placed['color']!,
      'pattern': placed['pattern']!,
    };

    final drafted = market[m];
    hands[seat][h] = drafted;
    market[m] = _drawTile();

    _log('${name(seat)} 在 ($r,$c) 缝制了【${colorNames[placed['color']!]}-${patternNames[placed['pattern']!]}】，并拿取【${colorNames[drafted['color']!]}-${patternNames[drafted['pattern']!]}】');

    _advanceTurn();
  }

  void _advanceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (emptySpacesOf(next) > 0) {
        if (next <= turn) round++;
        turn = next;
        return;
      }
    }
    over = true;
    final scores = [for (var s = 0; s < players; s++) scoreOf(s)];
    final best = scores.reduce(max);
    final winners = [for (var s = 0; s < players; s++) if (scores[s] == best) name(s)];
    _log('花被缝制完成！${winners.join('、')} 以 $best 分获胜！');
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final empties = <(int, int)>[];
    for (var r = 0; r < boardSize; r++) {
      for (var c = 0; c < boardSize; c++) {
        if (quilt[seat][r][c] == null) empties.add((r, c));
      }
    }
    if (empties.isEmpty) return null;

    if (botLevel == 0) {
      final (r, c) = empties[rng.nextInt(empties.length)];
      return {
        'type': 'place',
        'handIdx': rng.nextInt(hands[seat].length),
        'r': r,
        'c': c,
        'marketIdx': rng.nextInt(market.length),
      };
    }

    var bestScore = -1000000;
    Map<String, dynamic>? bestMove;
    for (var h = 0; h < hands[seat].length; h++) {
      final tile = hands[seat][h];
      for (final (r, c) in empties) {
        quilt[seat][r][c] = {'color': tile['color']!, 'pattern': tile['pattern']!};
        final sc = scoreOf(seat) * 100;
        var adjBonus = 0;
        for (final (nr, nc) in hexNeighbors(r, c)) {
          final nb = quilt[seat][nr][nc];
          if (nb != null) {
            if (nb['color'] == tile['color']) adjBonus += 15;
            if (nb['pattern'] == tile['pattern']) adjBonus += 18;
          }
        }
        quilt[seat][r][c] = null;
        for (var m = 0; m < market.length; m++) {
          final totalVal = sc + adjBonus + (botLevel >= 2 ? m : rng.nextInt(5));
          if (totalVal > bestScore) {
            bestScore = totalVal;
            bestMove = {'type': 'place', 'handIdx': h, 'r': r, 'c': c, 'marketIdx': m};
          }
        }
      }
    }
    return bestMove;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final breakdowns = [for (var s = 0; s < players; s++) scoreBreakdown(s)];
    return {
      'phase': over ? 'over' : 'play',
      'turn': turn,
      'round': round,
      'cats': [for (final c in cats) c.toJson()],
      'market': market,
      'bagCount': bag.length,
      'hand': seat >= 0 && seat < players ? hands[seat] : const <Map<String, int>>[],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'seat': s,
            'quilt': quilt[s],
            'handCount': hands[s].length,
            'emptyCount': emptySpacesOf(s),
            'score': breakdowns[s]['total'],
            'breakdown': breakdowns[s],
          },
      ],
      'placings': placings,
      'resigned': resignedSeat,
      'recent': recent,
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    if (resignedSeat >= 0 && players == 2) {
      return rankWinners(players, [1 - resignedSeat]);
    }
    return rankByScore([for (var s = 0; s < players; s++) scoreOf(s)]);
  }

  @override
  bool get canResign => players >= 2;

  @override
  void resign(int seat) {
    if (over || seat < 0 || seat >= players) throw GameError('无法认输');
    resignedSeat = seat;
    over = true;
    _log('${name(seat)} 认输');
  }
}
