import 'dart:math';

import '../../src/engine.dart';

const List<String> projectLShapeIds = [
  'L1_dot',
  'L2_bar',
  'L3_I',
  'L3_L',
  'L4_O',
  'L4_I',
  'L4_L',
  'L4_T',
  'L4_Z',
];

const List<String> projectLShapeNames = [
  '1格黄点',
  '2格绿条',
  '3格蓝直',
  '3格橙角',
  '4格红方',
  '4格青长',
  '4格紫L',
  '4格粉T',
  '4格靛Z',
];

const List<String> projectLShapeEmojis = [
  '🟨',
  '🟩',
  '🟦',
  '🟧',
  '🟥',
  '🩵',
  '🟪',
  '🩷',
  '🟪',
];

class ProjectLPuzzle {
  static const int size = 4;

  final int id;
  final int tier; // 0: White (1..2 VP), 1: Black (3..5 VP)
  final int vp;
  final int rewardShape; // 0..8 polyomino shape index
  final List<List<bool>> recessed; // 4x4 true where cells need to be filled
  final List<List<int>> grid; // 4x4: 0 if empty/border, shape+1 (1..9) if filled
  final List<int> placedShapes; // shapes currently placed on this puzzle

  ProjectLPuzzle({
    required this.id,
    required this.tier,
    required this.vp,
    required this.rewardShape,
    required this.recessed,
    List<List<int>>? grid,
    List<int>? placedShapes,
  })  : grid = grid ??
            List.generate(size, (_) => List.filled(size, 0)),
        placedShapes = placedShapes ?? <int>[];

  int get totalRecessed {
    var cnt = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (recessed[r][c]) cnt++;
      }
    }
    return cnt;
  }

  int get emptyRecessed {
    var cnt = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (recessed[r][c] && grid[r][c] == 0) cnt++;
      }
    }
    return cnt;
  }

  bool get isComplete => emptyRecessed == 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'vp': vp,
        'rewardShape': rewardShape,
        'recessed': [
          for (var r = 0; r < size; r++) List<bool>.of(recessed[r]),
        ],
        'grid': [
          for (var r = 0; r < size; r++) List<int>.of(grid[r]),
        ],
        'placedShapes': List<int>.of(placedShapes),
        'emptyRecessed': emptyRecessed,
        'totalRecessed': totalRecessed,
      };
}

class ProjectLGame extends GameEngine {
  static const int maxActivePuzzles = 4;
  static const int numShapes = 9;
  static const int actionsPerTurn = 3;

  static const List<List<(int, int)>> polyominoShapes = [
    [(0, 0)], // 0: L1_dot
    [(0, 0), (0, 1)], // 1: L2_bar
    [(0, 0), (0, 1), (0, 2)], // 2: L3_I
    [(0, 0), (0, 1), (1, 0)], // 3: L3_L
    [(0, 0), (0, 1), (1, 0), (1, 1)], // 4: L4_O
    [(0, 0), (0, 1), (0, 2), (0, 3)], // 5: L4_I
    [(0, 0), (0, 1), (0, 2), (1, 0)], // 6: L4_L
    [(0, 0), (0, 1), (0, 2), (1, 1)], // 7: L4_T
    [(0, 0), (0, 1), (1, 1), (1, 2)], // 8: L4_Z
  ];

  static int shapeLevel(int shape) {
    if (shape == 0) return 1;
    if (shape == 1) return 2;
    if (shape == 2 || shape == 3) return 3;
    return 4;
  }

  static List<(int, int)> normalizeCells(List<(int, int)> cells) {
    if (cells.isEmpty) return const [];
    var minR = cells[0].$1;
    var minC = cells[0].$2;
    for (final (r, c) in cells) {
      if (r < minR) minR = r;
      if (c < minC) minC = c;
    }
    final shifted = [for (final (r, c) in cells) (r - minR, c - minC)]
      ..sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
    return shifted;
  }

  static List<List<(int, int)>> allOrientations(int shape) {
    final baseShape = polyominoShapes[shape];
    final result = <List<(int, int)>>[];
    final seen = <String>{};
    for (var flip = 0; flip < 2; flip++) {
      for (var rot = 0; rot < 4; rot++) {
        final transformed = <(int, int)>[];
        for (final (r0, c0) in baseShape) {
          var r = r0;
          var c = flip == 1 ? -c0 : c0;
          for (var k = 0; k < rot; k++) {
            final nr = c;
            final nc = -r;
            r = nr;
            c = nc;
          }
          transformed.add((r, c));
        }
        final norm = normalizeCells(transformed);
        final key = norm.map((e) => '${e.$1},${e.$2}').join(';');
        if (seen.add(key)) {
          result.add(norm);
        }
      }
    }
    return result;
  }

  static bool matchesShape(List<(int, int)> cells, int shape) {
    if (shape < 0 || shape >= numShapes) return false;
    final base = polyominoShapes[shape];
    if (cells.length != base.length) return false;
    if (cells.toSet().length != cells.length) return false;
    final norm = normalizeCells(cells);
    final key = norm.map((e) => '${e.$1},${e.$2}').join(';');
    for (final o in allOrientations(shape)) {
      final oKey = o.map((e) => '${e.$1},${e.$2}').join(';');
      if (key == oKey) return true;
    }
    return false;
  }

  late final int deckSize;
  late List<List<int>> reserve; // reserve[seat][0..8]
  late List<List<ProjectLPuzzle>> activePuzzles; // max 4 per seat
  late List<int> completedCount;
  late List<int> score;

  final List<ProjectLPuzzle> whiteDeck = [];
  final List<ProjectLPuzzle> blackDeck = [];
  final List<ProjectLPuzzle> whiteMarket = [];
  final List<ProjectLPuzzle> blackMarket = [];

  int round = 1;
  int turn = 0;
  int actionsLeft = actionsPerTurn;
  bool usedMaster = false;
  bool finalRoundTriggered = false;
  bool over = false;
  String lastAction = '几何方阵引擎构筑开启';

  ProjectLGame(super.setup) : deckSize = setup.opt<int>('deckSize', 24);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<List<bool>> _maskFromCoords(List<(int, int)> coords) {
    final m = List.generate(4, (_) => List.filled(4, false));
    for (final (r, c) in coords) {
      m[r][c] = true;
    }
    return m;
  }

  void _buildDecks() {
    final whiteTemplates = <(int, int, List<(int, int)>)>[
      (1, 1, [(1, 1), (1, 2), (2, 1)]),
      (1, 2, [(1, 0), (1, 1), (1, 2)]),
      (1, 3, [(0, 1), (1, 1), (2, 1), (2, 2)]),
      (2, 3, [(1, 1), (1, 2), (2, 1), (2, 2)]),
      (2, 4, [(0, 1), (0, 2), (1, 1), (1, 2), (2, 1)]),
      (2, 5, [(1, 0), (1, 1), (1, 2), (1, 3), (2, 1)]),
      (2, 6, [(0, 1), (1, 1), (1, 2), (2, 1), (2, 2)]),
      (2, 7, [(1, 0), (1, 1), (1, 2), (2, 0), (2, 1)]),
    ];
    final blackTemplates = <(int, int, List<(int, int)>)>[
      (
        3,
        4,
        [(0, 1), (0, 2), (1, 1), (1, 2), (2, 1), (2, 2)]
      ),
      (
        3,
        6,
        [(0, 0), (0, 1), (0, 2), (1, 0), (1, 1), (1, 2)]
      ),
      (
        4,
        7,
        [(0, 1), (1, 0), (1, 1), (1, 2), (2, 0), (2, 1), (2, 2)]
      ),
      (
        4,
        8,
        [(0, 0), (0, 1), (1, 0), (1, 1), (1, 2), (2, 1), (2, 2)]
      ),
      (
        4,
        5,
        [(0, 1), (0, 2), (1, 0), (1, 1), (1, 2), (1, 3), (2, 1), (2, 2)]
      ),
      (
        5,
        4,
        [
          (0, 1),
          (0, 2),
          (1, 0),
          (1, 1),
          (1, 2),
          (2, 0),
          (2, 1),
          (2, 2),
          (3, 1),
        ]
      ),
    ];

    whiteDeck.clear();
    blackDeck.clear();
    var id = 1;
    final half = max(6, deckSize ~/ 2);
    for (var i = 0; i < half; i++) {
      final (vp, rew, coords) = whiteTemplates[i % whiteTemplates.length];
      whiteDeck.add(ProjectLPuzzle(
        id: id++,
        tier: 0,
        vp: vp,
        rewardShape: rew,
        recessed: _maskFromCoords(coords),
      ));
    }
    for (var i = 0; i < half; i++) {
      final (vp, rew, coords) = blackTemplates[i % blackTemplates.length];
      blackDeck.add(ProjectLPuzzle(
        id: id++,
        tier: 1,
        vp: vp,
        rewardShape: rew,
        recessed: _maskFromCoords(coords),
      ));
    }
    whiteDeck.shuffle(rng);
    blackDeck.shuffle(rng);
  }

  void _refillMarkets() {
    while (whiteMarket.length < 4 && whiteDeck.isNotEmpty) {
      whiteMarket.add(whiteDeck.removeLast());
    }
    while (blackMarket.length < 4 && blackDeck.isNotEmpty) {
      blackMarket.add(blackDeck.removeLast());
    }
    if (blackDeck.isEmpty && blackMarket.length < 4) {
      finalRoundTriggered = true;
    }
  }

  @override
  void start() {
    // Each player starts with 1 L1_dot (shape 0) and 1 L2_bar (shape 1)
    reserve = List.generate(players, (_) {
      final r = List.filled(numShapes, 0);
      r[0] = 1;
      r[1] = 1;
      return r;
    });
    activePuzzles = List.generate(players, (_) => <ProjectLPuzzle>[]);
    completedCount = List.filled(players, 0);
    score = List.filled(players, 0);

    _buildDecks();
    whiteMarket.clear();
    blackMarket.clear();
    finalRoundTriggered = false;
    _refillMarkets();

    round = 1;
    turn = 0;
    actionsLeft = actionsPerTurn;
    usedMaster = false;
    over = false;
    lastAction = '第 1 轮开始，每回合可执行 3 个行动';
  }

  /// Finds all valid cell placements for [shape] on [puzzle].
  static List<List<(int, int)>> validPlacementsOnPuzzle(
    ProjectLPuzzle puzzle,
    int shape,
  ) {
    final res = <List<(int, int)>>[];
    final orients = allOrientations(shape);
    for (final o in orients) {
      var maxR = 0;
      var maxC = 0;
      for (final (dr, dc) in o) {
        if (dr > maxR) maxR = dr;
        if (dc > maxC) maxC = dc;
      }
      for (var r0 = 0; r0 + maxR < ProjectLPuzzle.size; r0++) {
        for (var c0 = 0; c0 + maxC < ProjectLPuzzle.size; c0++) {
          var ok = true;
          final cells = <(int, int)>[];
          for (final (dr, dc) in o) {
            final r = r0 + dr;
            final c = c0 + dc;
            if (!puzzle.recessed[r][c] || puzzle.grid[r][c] != 0) {
              ok = false;
              break;
            }
            cells.add((r, c));
          }
          if (ok) res.add(cells);
        }
      }
    }
    return res;
  }

  String? validatePlaceOnPuzzle(
    int seat,
    int slot,
    int shape,
    List<(int, int)> cells,
  ) {
    if (slot < 0 || slot >= activePuzzles[seat].length) {
      return '无效的谜题槽位';
    }
    if (shape < 0 || shape >= numShapes) {
      return '无效的几何块编号';
    }
    if (reserve[seat][shape] <= 0) {
      return '库存中没有 ${projectLShapeEmojis[shape]}${projectLShapeNames[shape]}';
    }
    if (!matchesShape(cells, shape)) {
      return '所选格子与 ${projectLShapeNames[shape]} 的形状不匹配';
    }
    final puzzle = activePuzzles[seat][slot];
    for (final (r, c) in cells) {
      if (r < 0 || r >= ProjectLPuzzle.size || c < 0 || c >= ProjectLPuzzle.size) {
        return '格子坐标越界';
      }
      if (!puzzle.recessed[r][c]) {
        return '($r,$c) 不是谜题凹槽区域';
      }
      if (puzzle.grid[r][c] != 0) {
        return '($r,$c) 已被其他几何块占据';
      }
    }
    return null;
  }

  void _applyPlace(int seat, int slot, int shape, List<(int, int)> cells) {
    reserve[seat][shape]--;
    final puzzle = activePuzzles[seat][slot];
    for (final (r, c) in cells) {
      puzzle.grid[r][c] = shape + 1;
    }
    puzzle.placedShapes.add(shape);
  }

  /// Checks all active puzzles of [seat], returning pieces & granting VP + reward for completed ones!
  List<String> checkCompletions(int seat) {
    final notes = <String>[];
    for (var i = activePuzzles[seat].length - 1; i >= 0; i--) {
      final p = activePuzzles[seat][i];
      if (p.isComplete) {
        // 1. Return all placed pieces back to reserve[seat]
        for (final sh in p.placedShapes) {
          reserve[seat][sh]++;
        }
        // 2. Score puzzle VP
        score[seat] += p.vp;
        completedCount[seat]++;
        // 3. Gain reward piece
        reserve[seat][p.rewardShape]++;
        activePuzzles[seat].removeAt(i);
        notes.add(
            '完成谜题#${p.id}(+${p.vp}分，获${projectLShapeEmojis[p.rewardShape]}${projectLShapeNames[p.rewardShape]}，归还${p.placedShapes.length}块)');
      }
    }
    return notes;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'draft':
        if (activePuzzles[seat].length >= maxActivePuzzles) {
          throw GameError('面前活跃谜题已达上限 ($maxActivePuzzles 块)');
        }
        final tier = asInt(action['tier'], 0);
        final slot = asInt(action['slot'], 0);
        final market = tier == 1 ? blackMarket : whiteMarket;
        if (slot < 0 || slot >= market.length) {
          throw GameError('无效的市场谜题编号');
        }
        final p = market.removeAt(slot);
        activePuzzles[seat].add(p);
        _refillMarkets();
        actionsLeft--;
        lastAction =
            '${name(seat)} 拿取了${tier == 1 ? '黑' : '白'}色谜题#${p.id}（${p.vp}分，奖励${projectLShapeEmojis[p.rewardShape]}）';
        host.log(lastAction);

      case 'gain_l1':
        reserve[seat][0]++;
        actionsLeft--;
        lastAction = '${name(seat)} 获得了 1 块 🟨1格黄点';
        host.log(lastAction);

      case 'upgrade':
        final fromSh = asInt(action['from'], -1);
        final toSh = asInt(action['to'], -1);
        if (fromSh < 0 ||
            fromSh >= numShapes ||
            toSh < 0 ||
            toSh >= numShapes ||
            fromSh == toSh) {
          throw GameError('无效的升级形状编号');
        }
        if (reserve[seat][fromSh] <= 0) {
          throw GameError('库存中没有 ${projectLShapeNames[fromSh]} 可供升级');
        }
        if (shapeLevel(toSh) > shapeLevel(fromSh) + 1) {
          throw GameError('每次升级最多提升 1 个等级');
        }
        reserve[seat][fromSh]--;
        reserve[seat][toSh]++;
        actionsLeft--;
        lastAction =
            '${name(seat)} 将 ${projectLShapeEmojis[fromSh]}${projectLShapeNames[fromSh]} 升级为 ${projectLShapeEmojis[toSh]}${projectLShapeNames[toSh]}';
        host.log(lastAction);

      case 'place':
        final slot = asInt(action['slot'], -1);
        final shape = asInt(action['shape'], -1);
        final rawCells = action['cells'];
        List<(int, int)>? cells;
        if (rawCells is List && rawCells.isNotEmpty) {
          cells = [
            for (final item in rawCells)
              if (item is List && item.length >= 2)
                (asInt(item[0], -1), asInt(item[1], -1)),
          ];
        } else if (slot >= 0 &&
            slot < activePuzzles[seat].length &&
            shape >= 0 &&
            shape < numShapes) {
          final valid = validPlacementsOnPuzzle(activePuzzles[seat][slot], shape);
          if (valid.isNotEmpty) cells = valid.first;
        }
        if (cells == null) {
          throw GameError('没有合法的嵌入位置');
        }
        final err = validatePlaceOnPuzzle(seat, slot, shape, cells);
        if (err != null) throw GameError(err);

        _applyPlace(seat, slot, shape, cells);
        final doneNotes = checkCompletions(seat);
        actionsLeft--;
        final doneStr = doneNotes.isNotEmpty ? ' · ${doneNotes.join('，')}' : '';
        lastAction =
            '${name(seat)} 将 ${projectLShapeEmojis[shape]}${projectLShapeNames[shape]} 嵌入谜题$doneStr';
        host.log(lastAction);

      case 'master':
        if (usedMaster) {
          throw GameError('每回合最多只能执行 1 次大师行动(Master Action)');
        }
        if (activePuzzles[seat].isEmpty) {
          throw GameError('当前没有活跃谜题可执行大师行动');
        }
        final rawPlacements = action['placements'];
        final planned = <(int, int, List<(int, int)>)>[];

        if (rawPlacements is List && rawPlacements.isNotEmpty) {
          final seenSlots = <int>{};
          final tempRes = List<int>.of(reserve[seat]);
          for (final item in rawPlacements) {
            if (item is! Map) throw GameError('大师行动格式无效');
            final s = asInt(item['slot'], -1);
            final sh = asInt(item['shape'], -1);
            if (!seenSlots.add(s)) {
              throw GameError('大师行动中每个活跃谜题最多只能放置 1 块几何块');
            }
            if (s < 0 || s >= activePuzzles[seat].length) {
              throw GameError('无效的谜题槽位');
            }
            if (sh < 0 || sh >= numShapes || tempRes[sh] <= 0) {
              throw GameError('库存几何块不足');
            }
            final rcList = item['cells'];
            List<(int, int)>? cells;
            if (rcList is List && rcList.isNotEmpty) {
              cells = [
                for (final c in rcList)
                  if (c is List && c.length >= 2)
                    (asInt(c[0], -1), asInt(c[1], -1)),
              ];
            } else {
              final vp = validPlacementsOnPuzzle(activePuzzles[seat][s], sh);
              if (vp.isNotEmpty) cells = vp.first;
            }
            if (cells == null) throw GameError('无法放置几何块');
            final err = validatePlaceOnPuzzle(seat, s, sh, cells);
            if (err != null) throw GameError(err);
            tempRes[sh]--;
            planned.add((s, sh, cells));
          }
        } else {
          // Auto-plan best largest piece for each active puzzle
          final tempRes = List<int>.of(reserve[seat]);
          for (var s = 0; s < activePuzzles[seat].length; s++) {
            final p = activePuzzles[seat][s];
            for (var sh = numShapes - 1; sh >= 0; sh--) {
              if (tempRes[sh] <= 0) continue;
              final vp = validPlacementsOnPuzzle(p, sh);
              if (vp.isNotEmpty) {
                tempRes[sh]--;
                planned.add((s, sh, vp.first));
                break;
              }
            }
          }
          if (planned.isEmpty) {
            throw GameError('当前库存没有可放入活跃谜题的几何块');
          }
        }

        for (final (s, sh, cells) in planned) {
          _applyPlace(seat, s, sh, cells);
        }
        usedMaster = true;
        final doneNotes = checkCompletions(seat);
        actionsLeft--;
        final doneStr = doneNotes.isNotEmpty ? ' · ${doneNotes.join('，')}' : '';
        lastAction =
            '${name(seat)} 发动✨大师行动，向 ${planned.length} 块谜题同步嵌入几何块$doneStr';
        host.log(lastAction);

      default:
        throw GameError('未知操作: $type');
    }

    if (actionsLeft <= 0) {
      _advanceTurn();
    }
  }

  void _advanceTurn() {
    actionsLeft = actionsPerTurn;
    usedMaster = false;
    if (turn + 1 < players) {
      turn++;
      return;
    }
    turn = 0;
    if (finalRoundTriggered ||
        round >= 10 ||
        (whiteMarket.isEmpty && blackMarket.isEmpty)) {
      over = true;
      lastAction = '几何方阵终局结算完成！总分最高者获胜';
      host.log(lastAction);
      return;
    }
    round++;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. If we have >= 2 active puzzles and haven't used Master Action, check if Master can place >= 2 pieces
    if (!usedMaster && activePuzzles[seat].length >= 2) {
      final tempRes = List<int>.of(reserve[seat]);
      var canPlaceCount = 0;
      for (final p in activePuzzles[seat]) {
        for (var sh = numShapes - 1; sh >= 0; sh--) {
          if (tempRes[sh] <= 0) continue;
          if (validPlacementsOnPuzzle(p, sh).isNotEmpty) {
            tempRes[sh]--;
            canPlaceCount++;
            break;
          }
        }
      }
      if (canPlaceCount >= 2) {
        return {'type': 'master'};
      }
    }

    // 2. If we have fewer than 3 active puzzles, draft a puzzle
    if (activePuzzles[seat].length < 3) {
      final totalPieces = reserve[seat].fold<int>(0, (a, b) => a + b);
      if (totalPieces >= 4 && blackMarket.isNotEmpty) {
        return {'type': 'draft', 'tier': 1, 'slot': 0};
      }
      if (whiteMarket.isNotEmpty) {
        return {'type': 'draft', 'tier': 0, 'slot': 0};
      }
      if (blackMarket.isNotEmpty) {
        return {'type': 'draft', 'tier': 1, 'slot': 0};
      }
    }

    // 3. Try single 'place' on an active puzzle
    for (var s = 0; s < activePuzzles[seat].length; s++) {
      final p = activePuzzles[seat][s];
      for (var sh = numShapes - 1; sh >= 0; sh--) {
        if (reserve[seat][sh] <= 0) continue;
        final vp = validPlacementsOnPuzzle(p, sh);
        if (vp.isNotEmpty) {
          return {
            'type': 'place',
            'slot': s,
            'shape': sh,
            'cells': [
              for (final (r, c) in vp.first) [r, c],
            ],
          };
        }
      }
    }

    // 4. Upgrade a smaller piece if we have >= 2 pieces
    for (var sh = 0; sh <= 3; sh++) {
      if (reserve[seat][sh] >= 2) {
        final nextSh = sh == 0 ? 1 : (sh == 1 ? 2 : 4);
        return {'type': 'upgrade', 'from': sh, 'to': nextSh};
      }
    }

    // 5. Fallback: gain L1 piece
    return {'type': 'gain_l1'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'turn': turn,
      'actionsLeft': actionsLeft,
      'usedMaster': usedMaster,
      'finalRoundTriggered': finalRoundTriggered,
      'over': over,
      'lastAction': lastAction,
      'whiteDeckCount': whiteDeck.length,
      'blackDeckCount': blackDeck.length,
      'whiteMarket': [for (final p in whiteMarket) p.toJson()],
      'blackMarket': [for (final p in blackMarket) p.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'completedCount': completedCount[s],
            'reserve': List<int>.of(reserve[s]),
            'activePuzzles': [
              for (final p in activePuzzles[s]) p.toJson(),
            ],
          },
      ],
    };
  }
}
