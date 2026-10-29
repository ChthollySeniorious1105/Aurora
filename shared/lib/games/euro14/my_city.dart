import 'dart:math';

import '../../src/engine.dart';
import 'isle_of_cats.dart';

const List<String> myCityTerrainNames = [
  '草地',
  '树木',
  '岩石',
  '金矿',
  '高山',
];

const List<String> myCityTerrainEmojis = [
  '🟩',
  '🌳',
  '🪨',
  '🪙',
  '⛰️',
];

const List<String> myCityBuildingNames = [
  '无',
  '住宅',
  '商业楼',
  '工厂',
];

const List<String> myCityBuildingEmojis = [
  '·',
  '🟨',
  '🟥',
  '🟦',
];

class MyCityCard {
  final int id;
  final int color; // 1: Yellow, 2: Red, 3: Blue
  final String name;
  final List<(int, int)> shape;

  const MyCityCard({
    required this.id,
    required this.color,
    required this.name,
    required this.shape,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color,
        'name': name,
        'shape': [
          for (final (r, c) in shape) [r, c],
        ],
      };
}

class MyCityGame extends GameEngine {
  static const int gridSize = 8;

  /// Initial 8x8 terrain layout:
  /// 0: Meadow (🟩), 1: Tree (🌳), 2: Rock (🪨), 3: Gold (🪙), 4: Mountain (⛰️)
  static const List<List<int>> defaultTerrain = [
    [4, 4, 1, 0, 0, 2, 1, 4],
    [4, 1, 0, 3, 0, 0, 2, 1],
    [1, 0, 2, 0, 0, 3, 0, 0],
    [0, 0, 0, 1, 2, 0, 0, 1],
    [1, 0, 0, 2, 1, 0, 0, 0],
    [0, 0, 3, 0, 0, 2, 0, 1],
    [1, 2, 0, 0, 3, 0, 1, 4],
    [4, 1, 2, 0, 0, 1, 4, 4],
  ];

  /// Cells orthogonally adjacent to the central River dividing North Bank (r <= 3) and South Bank (r >= 4).
  static final List<(int, int)> riverCells = [
    for (var c = 0; c < gridSize; c++) (3, c),
    for (var c = 0; c < gridSize; c++) (4, c),
  ];

  late final int maxCards;
  late List<List<List<int>>> board; // Terrain: 0..4
  late List<List<List<int>>> building; // 0: none, 1..3: Building Color
  late List<int> passPenalties;
  late List<bool> retired;
  late List<bool> actedThisCard;
  late List<int> score;

  final List<MyCityCard> deck = [];
  MyCityCard? currentCard;
  int cardIndex = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '我的城市建设揭幕';

  MyCityGame(super.setup) : maxCards = setup.opt<int>('cards', 18);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static const List<(String, List<(int, int)>)> _shapes = [
    ('双联屋', [(0, 0), (0, 1)]),
    ('三联排屋', [(0, 0), (0, 1), (0, 2)]),
    ('转角楼', [(0, 0), (0, 1), (1, 0)]),
    ('方庭院', [(0, 0), (0, 1), (1, 0), (1, 1)]),
    ('长街坊', [(0, 0), (0, 1), (0, 2), (1, 0)]),
    ('丁字楼', [(0, 0), (0, 1), (0, 2), (1, 1)]),
  ];

  List<MyCityCard> _buildDeck() {
    final raw = <MyCityCard>[];
    var id = 1;
    for (var color = 1; color <= 3; color++) {
      for (final (title, shape) in _shapes) {
        raw.add(MyCityCard(
          id: id++,
          color: color,
          name: '${myCityBuildingNames[color]}·$title',
          shape: shape,
        ));
      }
    }
    final s = shuffled(raw, rng);
    return s.take(maxCards).toList();
  }

  @override
  void start() {
    board = List.generate(
      players,
      (_) => [
        for (var r = 0; r < gridSize; r++) List<int>.of(defaultTerrain[r]),
      ],
    );
    building = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, 0)),
    );
    passPenalties = List.filled(players, 0);
    retired = List.filled(players, false);
    actedThisCard = List.filled(players, false);
    score = List.filled(players, 0);

    deck
      ..clear()
      ..addAll(_buildDeck());
    cardIndex = 1;
    currentCard = deck.isNotEmpty ? deck.removeLast() : null;
    turn = 0;
    over = false;
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
  }

  static List<(int, int)> orthoNeighbors(int r, int c) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    return [
      for (final (dr, dc) in dirs)
        if (r + dr >= 0 && r + dr < gridSize && c + dc >= 0 && c + dc < gridSize)
          (r + dr, c + dc),
    ];
  }

  static bool isRiverAdjacentCell(int r, int c) => r == 3 || r == 4;

  static bool crossesRiver(List<(int, int)> cells) {
    var hasNorthBank = false;
    var hasSouthBank = false;
    for (final (r, _) in cells) {
      if (r <= 3) hasNorthBank = true;
      if (r >= 4) hasSouthBank = true;
    }
    return hasNorthBank && hasSouthBank;
  }

  bool hasAnyBuilding(int seat) {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (building[seat][r][c] > 0) return true;
      }
    }
    return false;
  }

  bool canBuildCells(int seat, List<(int, int)> cells, List<(int, int)> shape) {
    if (!IsleOfCatsGame.matchesShape(cells, shape)) return false;
    if (crossesRiver(cells)) return false;

    for (final (r, c) in cells) {
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
      if (building[seat][r][c] != 0) return false;
      if (board[seat][r][c] == 4) return false; // Impassable Mountain (⛰️)
    }

    if (!hasAnyBuilding(seat)) {
      // First building must touch a cell orthogonally adjacent to the River
      for (final (r, c) in cells) {
        if (isRiverAdjacentCell(r, c)) return true;
      }
      return false;
    }

    // Subsequent buildings must be orthogonally adjacent to an existing building
    for (final (r, c) in cells) {
      for (final (nr, nc) in orthoNeighbors(r, c)) {
        if (building[seat][nr][nc] > 0) return true;
      }
    }
    return false;
  }

  List<List<(int, int)>> validPlacements(int seat, [List<(int, int)>? shape]) {
    final targetShape = shape ?? currentCard?.shape;
    if (targetShape == null) return const [];
    final results = <List<(int, int)>>[];
    final orients = IsleOfCatsGame.allOrientations(targetShape);
    for (final o in orients) {
      var maxDr = 0;
      var maxDc = 0;
      for (final (dr, dc) in o) {
        if (dr > maxDr) maxDr = dr;
        if (dc > maxDc) maxDc = dc;
      }
      for (var r0 = 0; r0 + maxDr < gridSize; r0++) {
        for (var c0 = 0; c0 + maxDc < gridSize; c0++) {
          final cells = [for (final (dr, dc) in o) (r0 + dr, c0 + dc)];
          if (canBuildCells(seat, cells, targetShape)) {
            results.add(cells);
          }
        }
      }
    }
    return results;
  }

  int calcVisibleTrees(int seat) {
    var count = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[seat][r][c] == 1 && building[seat][r][c] == 0) count++;
      }
    }
    return count;
  }

  int calcVisibleRocks(int seat) {
    var count = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[seat][r][c] == 2 && building[seat][r][c] == 0) count++;
      }
    }
    return count;
  }

  int calcEmptyMeadows(int seat) {
    var count = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[seat][r][c] == 0 && building[seat][r][c] == 0) count++;
      }
    }
    return count;
  }

  int calcCoveredGold(int seat) {
    var count = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (board[seat][r][c] == 3 && building[seat][r][c] > 0) count++;
      }
    }
    return count;
  }

  int calcSquareBlocks(int seat) {
    final used = List.generate(gridSize, (_) => List.filled(gridSize, false));
    var blocks = 0;
    for (var r = 0; r < gridSize - 1; r++) {
      for (var c = 0; c < gridSize - 1; c++) {
        if (used[r][c] || used[r + 1][c] || used[r][c + 1] || used[r + 1][c + 1]) {
          continue;
        }
        final col = building[seat][r][c];
        if (col >= 1 &&
            col <= 3 &&
            building[seat][r + 1][c] == col &&
            building[seat][r][c + 1] == col &&
            building[seat][r + 1][c + 1] == col) {
          blocks++;
          used[r][c] = true;
          used[r + 1][c] = true;
          used[r][c + 1] = true;
          used[r + 1][c + 1] = true;
        }
      }
    }
    return blocks;
  }

  int calcScore(int seat) {
    return calcVisibleTrees(seat) -
        calcVisibleRocks(seat) -
        calcEmptyMeadows(seat) +
        calcCoveredGold(seat) * 2 +
        calcSquareBlocks(seat) * 4 -
        passPenalties[seat];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');
    if (currentCard == null) throw GameError('没有当前建筑卡');

    final type = asStr(action['type']);
    switch (type) {
      case 'build':
        final rawCells = action['cells'];
        if (rawCells is! List || rawCells.length != currentCard!.shape.length) {
          throw GameError('建造格数与当前建筑卡不符');
        }
        final cells = <(int, int)>[];
        for (final item in rawCells) {
          if (item is! List || item.length < 2) {
            throw GameError('坐标格式错误');
          }
          cells.add((asInt(item[0], -1), asInt(item[1], -1)));
        }
        if (crossesRiver(cells)) {
          throw GameError('单个建筑不能横跨河流');
        }
        if (!canBuildCells(seat, cells, currentCard!.shape)) {
          throw GameError('不满足我的城市建造规则（首栋须邻河、后续须邻接已有建筑且不可覆盖高山）');
        }

        var goldGained = 0;
        for (final (r, c) in cells) {
          building[seat][r][c] = currentCard!.color;
          if (board[seat][r][c] == 3) {
            goldGained++;
          }
        }
        actedThisCard[seat] = true;
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 建造了 ${myCityBuildingEmojis[currentCard!.color]}${currentCard!.name}${goldGained > 0 ? ' (覆盖金矿 +${goldGained * 2}分)' : ''}';
        host.log(lastAction);
        _advanceTurn();

      case 'pass':
        passPenalties[seat] += 1;
        actedThisCard[seat] = true;
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 跳过本张建筑卡 (-1分)';
        host.log(lastAction);
        _advanceTurn();

      case 'retire':
        retired[seat] = true;
        actedThisCard[seat] = true;
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 宣布本轮封顶休整 (0惩罚)';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    for (var step = 1; step <= players; step++) {
      final cand = (turn + step) % players;
      if (!retired[cand] && !actedThisCard[cand]) {
        turn = cand;
        return;
      }
    }

    // All non-retired players have acted on currentCard
    if (retired.every((r) => r) || deck.isEmpty) {
      over = true;
      currentCard = null;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '我的城市建设竣工！最高总分获胜';
      host.log(lastAction);
      return;
    }

    currentCard = deck.removeLast();
    cardIndex++;
    for (var s = 0; s < players; s++) {
      actedThisCard[s] = retired[s];
    }
    for (var s = 0; s < players; s++) {
      final cand = (cardIndex - 1 + s) % players;
      if (!retired[cand]) {
        turn = cand;
        return;
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn || currentCard == null) return null;
    final placements = validPlacements(seat, currentCard!.shape);
    if (placements.isEmpty) {
      return {'type': 'retire'};
    }

    if (botLevel == 0) {
      final chosen = placements[rng.nextInt(placements.length)];
      return {
        'type': 'build',
        'cells': [
          for (final (r, c) in chosen) [r, c],
        ],
      };
    }

    var bestVal = -999999;
    var bestCells = placements.first;
    final col = currentCard!.color;
    final limit = min(placements.length, botLevel >= 2 ? 24 : 10);
    for (var i = 0; i < limit; i++) {
      final cells = placements[i];
      var val = cells.length * 2;
      for (final (r, c) in cells) {
        final t = board[seat][r][c];
        if (t == 3) val += 10; // Gold (+2 VP)
        if (t == 2) val += 6; // Cover Rock (+1 VP saved)
        if (t == 0) val += 5; // Cover Meadow (+1 VP saved)
        if (t == 1) val -= 5; // Covering Tree loses 1 VP
        for (final (nr, nc) in orthoNeighbors(r, c)) {
          if (building[seat][nr][nc] == col) val += 4; // Helps form 2x2 same-color block
        }
      }
      if (val > bestVal) {
        bestVal = val;
        bestCells = cells;
      }
    }

    return {
      'type': 'build',
      'cells': [
        for (final (r, c) in bestCells) [r, c],
      ],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validList = (!over && seat >= 0 && seat < players && currentCard != null)
        ? validPlacements(seat, currentCard!.shape)
        : const <List<(int, int)>>[];

    return {
      'gridSize': gridSize,
      'cardIndex': cardIndex,
      'maxCards': maxCards,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'currentCard': currentCard?.toJson(),
      'riverCells': [
        for (final (r, c) in riverCells) [r, c],
      ],
      'validPlacements': [
        for (final pl in validList.take(20))
          [
            for (final (r, c) in pl) [r, c],
          ],
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'retired': retired[s],
            'passPenalties': passPenalties[s],
            'trees': calcVisibleTrees(s),
            'rocks': calcVisibleRocks(s),
            'emptyMeadows': calcEmptyMeadows(s),
            'coveredGold': calcCoveredGold(s),
            'squareBlocks': calcSquareBlocks(s),
            'board': [
              for (var r = 0; r < gridSize; r++) List<int>.of(board[s][r]),
            ],
            'building': [
              for (var r = 0; r < gridSize; r++) List<int>.of(building[s][r]),
            ],
          },
      ],
    };
  }
}
