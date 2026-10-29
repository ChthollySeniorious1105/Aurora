import 'dart:math';

import '../../src/engine.dart';

const List<String> isleCatTypeNames = [
  '空舱',
  '蓝猫',
  '黄猫',
  '红猫',
  '紫猫',
  '绿猫',
  '奇兽Oshax',
  '宝藏',
];

const List<String> isleCatTypeEmojis = [
  '·',
  '🟦',
  '🟨',
  '🟥',
  '🟪',
  '🟩',
  '⬜',
  '🪙',
];

class IsleCatTile {
  final int id;
  final int color; // 1..5: Cat Family, 6: Oshax (⬜ chooses 1..5 when placed)
  final int field; // 0: Left Field (cost 3 Fish), 1: Right Field (cost 5 Fish)
  final List<(int, int)> shape;

  const IsleCatTile({
    required this.id,
    required this.color,
    required this.field,
    required this.shape,
  });

  int get fishCost => field == 0 ? 3 : 5;

  Map<String, dynamic> toJson() => {
        'id': id,
        'color': color,
        'field': field,
        'fishCost': fishCost,
        'shape': [
          for (final (r, c) in shape) [r, c],
        ],
      };
}

class IsleLessonCard {
  final int id;
  final int kind; // 0..5 lesson scoring types
  final int cost; // 1..3 Fish
  final String title;
  final String desc;

  const IsleLessonCard({
    required this.id,
    required this.kind,
    required this.cost,
    required this.title,
    required this.desc,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        'cost': cost,
        'title': title,
        'desc': desc,
      };
}

class IsleOfCatsGame extends GameEngine {
  static const int rows = 5;
  static const int cols = 9;
  static const int numRooms = 6;

  /// Partition of the 5x9 boat into 6 contiguous rooms (0..5).
  static const List<List<int>> roomMap = [
    [0, 0, 0, 2, 2, 2, 4, 4, 4],
    [0, 0, 0, 2, 2, 2, 4, 4, 4],
    [0, 1, 2, 2, 3, 3, 4, 4, 5],
    [1, 1, 1, 3, 3, 3, 5, 5, 5],
    [1, 1, 1, 3, 3, 3, 5, 5, 5],
  ];

  /// Pre-printed Rats (🐀) on the 5x9 boat.
  static const List<List<bool>> rats = [
    [false, true, false, false, false, false, false, false, false],
    [false, false, false, false, true, false, false, true, false],
    [false, false, true, false, false, true, false, false, true],
    [false, true, false, false, false, false, true, false, false],
    [false, false, false, false, true, false, false, false, false],
  ];

  /// Pre-printed Treasure Maps (1..5 matching Cat Family colors, 0 if none).
  static const List<List<int>> mapColor = [
    [0, 0, 1, 0, 0, 3, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 0, 0, 0, 0, 5, 0, 0],
    [0, 0, 0, 0, 0, 0, 0, 0, 0],
    [0, 0, 2, 0, 0, 4, 0, 0, 0],
  ];

  late final int maxDays;
  late List<List<List<int>>> boat; // 0: empty, 1..5: cat color, 6: Oshax, 7: Treasure
  late List<List<List<bool>>> isOshax;
  late List<int> fish;
  late List<int> permanentBaskets;
  late List<int> baskets;
  late List<int> rareTreasures;
  late List<List<IsleLessonCard>> lessons;
  late List<bool> passed;
  late List<int> score;

  final List<IsleCatTile> catDeck = [];
  final List<IsleCatTile> islandCats = [];
  final List<IsleLessonCard> lessonDeck = [];
  final List<IsleLessonCard> lessonMarket = [];

  int day = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '猫岛奇缘营救开启';

  IsleOfCatsGame(super.setup) : maxDays = setup.opt<int>('days', 5);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static const List<List<(int, int)>> _polyominoShapes = [
    [(0, 0), (0, 1), (0, 2)], // I3
    [(0, 0), (0, 1), (1, 0)], // L3
    [(0, 0), (0, 1), (1, 0), (1, 1)], // O4
    [(0, 0), (0, 1), (0, 2), (1, 0)], // L4
    [(0, 0), (0, 1), (0, 2), (1, 1)], // T4
    [(0, 0), (0, 1), (1, 1), (1, 2)], // Z4
    [(0, 0), (0, 1)], // Domino (agile cat)
  ];

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

  static List<List<(int, int)>> allOrientations(List<(int, int)> baseShape) {
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

  static bool matchesShape(List<(int, int)> cells, List<(int, int)> shape) {
    if (cells.length != shape.length) return false;
    final unique = cells.toSet();
    if (unique.length != cells.length) return false;
    final norm = normalizeCells(cells);
    final key = norm.map((e) => '${e.$1},${e.$2}').join(';');
    for (final o in allOrientations(shape)) {
      final oKey = o.map((e) => '${e.$1},${e.$2}').join(';');
      if (key == oKey) return true;
    }
    return false;
  }

  static List<(int, int)> orthoNeighbors(int r, int c) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    return [
      for (final (dr, dc) in dirs)
        if (r + dr >= 0 && r + dr < rows && c + dc >= 0 && c + dc < cols)
          (r + dr, c + dc),
    ];
  }

  List<IsleCatTile> _buildCatDeck() {
    final list = <IsleCatTile>[];
    var id = 1;
    for (var color = 1; color <= 5; color++) {
      for (var s = 0; s < _polyominoShapes.length; s++) {
        list.add(IsleCatTile(
          id: id++,
          color: color,
          field: s % 2,
          shape: _polyominoShapes[s],
        ));
        list.add(IsleCatTile(
          id: id++,
          color: color,
          field: (s + 1) % 2,
          shape: _polyominoShapes[s],
        ));
      }
    }
    // Add 6 Oshax tiles (color = 6)
    for (var i = 0; i < 6; i++) {
      list.add(IsleCatTile(
        id: id++,
        color: 6,
        field: i % 2,
        shape: _polyominoShapes[i % _polyominoShapes.length],
      ));
    }
    return shuffled(list, rng);
  }

  List<IsleLessonCard> _buildLessonDeck() {
    const templates = [
      (0, 2, '百猫图鉴', '船上每有 1 种颜色的猫，终局 +2 分'),
      (1, 2, '中轴船长', '船舱正中横行（第 3 行）每填满 1 格，终局 +1 分'),
      (2, 2, '捕鼠达人', '船上每覆盖 1 只老鼠 🐀，终局额外 +2 分'),
      (3, 3, '巨型猫族', '若船上存在至少 5 格相连的同色猫群，终局 +6 分'),
      (4, 3, '五彩同舟', '若船上集齐全部 5 种颜色猫咪，终局 +7 分'),
      (5, 3, '永恒鱼篓', '立即获得 +1 永久鱼篓与 +1 稀有宝藏 (+3 分)'),
    ];
    final list = <IsleLessonCard>[];
    var id = 1;
    for (var copy = 0; copy < 5; copy++) {
      for (final (kind, cost, title, desc) in templates) {
        list.add(IsleLessonCard(
          id: id++,
          kind: kind,
          cost: cost,
          title: title,
          desc: desc,
        ));
      }
    }
    return shuffled(list, rng);
  }

  @override
  void start() {
    boat = List.generate(
      players,
      (_) => List.generate(rows, (_) => List.filled(cols, 0)),
    );
    isOshax = List.generate(
      players,
      (_) => List.generate(rows, (_) => List.filled(cols, false)),
    );
    fish = List.filled(players, 0);
    permanentBaskets = List.filled(players, 1);
    baskets = List.filled(players, 1);
    rareTreasures = List.filled(players, 0);
    lessons = List.generate(players, (_) => <IsleLessonCard>[]);
    passed = List.filled(players, false);
    score = List.filled(players, 0);

    catDeck
      ..clear()
      ..addAll(_buildCatDeck());
    lessonDeck
      ..clear()
      ..addAll(_buildLessonDeck());

    day = 1;
    _startDay();
  }

  void _startDay() {
    for (var s = 0; s < players; s++) {
      fish[s] += 10;
      baskets[s] = permanentBaskets[s] + 1; // 1 permanent + 1 daily exploration basket
      passed[s] = false;
    }
    islandCats.clear();
    final targetCats = max(6, players * 3);
    for (var i = 0; i < targetCats && catDeck.isNotEmpty; i++) {
      final raw = catDeck.removeLast();
      islandCats.add(IsleCatTile(
        id: raw.id,
        color: raw.color,
        field: i < targetCats ~/ 2 ? 0 : 1,
        shape: raw.shape,
      ));
    }
    lessonMarket.clear();
    while (lessonMarket.length < 4 && lessonDeck.isNotEmpty) {
      lessonMarket.add(lessonDeck.removeLast());
    }
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
  }

  bool boatIsEmpty(int seat) {
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (boat[seat][r][c] != 0) return false;
      }
    }
    return true;
  }

  bool canPlaceCells(int seat, List<(int, int)> cells, List<(int, int)> shape) {
    if (!matchesShape(cells, shape)) return false;
    for (final (r, c) in cells) {
      if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
      if (boat[seat][r][c] != 0) return false;
    }
    if (boatIsEmpty(seat)) return true;

    // Must be orthogonally adjacent to at least one existing tile on the boat
    for (final (r, c) in cells) {
      for (final (nr, nc) in orthoNeighbors(r, c)) {
        if (boat[seat][nr][nc] != 0) return true;
      }
    }
    return false;
  }

  List<List<(int, int)>> validPlacementsForShape(int seat, List<(int, int)> shape) {
    final results = <List<(int, int)>>[];
    final emptyBoat = boatIsEmpty(seat);
    final orients = allOrientations(shape);
    for (final o in orients) {
      var maxDr = 0;
      var maxDc = 0;
      for (final (dr, dc) in o) {
        if (dr > maxDr) maxDr = dr;
        if (dc > maxDc) maxDc = dc;
      }
      for (var r0 = 0; r0 + maxDr < rows; r0++) {
        for (var c0 = 0; c0 + maxDc < cols; c0++) {
          var ok = true;
          var touchesExisting = emptyBoat;
          final placed = <(int, int)>[];
          for (final (dr, dc) in o) {
            final r = r0 + dr;
            final c = c0 + dc;
            if (boat[seat][r][c] != 0) {
              ok = false;
              break;
            }
            placed.add((r, c));
            if (!touchesExisting) {
              for (final (nr, nc) in orthoNeighbors(r, c)) {
                if (boat[seat][nr][nc] != 0) {
                  touchesExisting = true;
                  break;
                }
              }
            }
          }
          if (ok && touchesExisting) {
            results.add(placed);
          }
        }
      }
    }
    return results;
  }

  (int, int)? findBestTreasureCell(int seat) {
    (int, int)? best;
    var bestScore = -999;
    final emptyBoat = boatIsEmpty(seat);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (boat[seat][r][c] != 0) continue;
        var adj = emptyBoat;
        if (!adj) {
          for (final (nr, nc) in orthoNeighbors(r, c)) {
            if (boat[seat][nr][nc] != 0) {
              adj = true;
              break;
            }
          }
        }
        if (!adj) continue;
        var val = rats[r][c] ? 10 : 1;
        if (val > bestScore) {
          bestScore = val;
          best = (r, c);
        }
      }
    }
    return best;
  }

  static int familyScoreForSize(int size) {
    if (size < 3) return 0;
    if (size == 3) return 8;
    if (size == 4) return 11;
    if (size == 5) return 15;
    return 20;
  }

  int calcCatFamilyScore(int seat) {
    final visited = List.generate(rows, (_) => List.filled(cols, false));
    var total = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (visited[r][c]) continue;
        final color = boat[seat][r][c];
        if (color < 1 || color > 5) continue;
        var count = 0;
        final q = <(int, int)>[(r, c)];
        visited[r][c] = true;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          count++;
          for (final (nr, nc) in orthoNeighbors(cr, cc)) {
            if (!visited[nr][nc] && boat[seat][nr][nc] == color) {
              visited[nr][nc] = true;
              q.add((nr, nc));
            }
          }
        }
        total += familyScoreForSize(count);
      }
    }
    return total;
  }

  int calcUncoveredRats(int seat) {
    var count = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (rats[r][c] && boat[seat][r][c] == 0) {
          count++;
        }
      }
    }
    return count;
  }

  int calcUnfilledRooms(int seat) {
    final roomHasEmpty = List.filled(numRooms, false);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (boat[seat][r][c] == 0) {
          roomHasEmpty[roomMap[r][c]] = true;
        }
      }
    }
    return roomHasEmpty.where((e) => e).length;
  }

  int calcLessonScore(int seat) {
    var total = 0;
    final colorsPresent = <int>{};
    var row2Filled = 0;
    var coveredRats = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final v = boat[seat][r][c];
        if (v >= 1 && v <= 5) colorsPresent.add(v);
        if (r == 2 && v != 0) row2Filled++;
        if (rats[r][c] && v != 0) coveredRats++;
      }
    }
    // Check max family size
    var maxFamily = 0;
    final visited = List.generate(rows, (_) => List.filled(cols, false));
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (visited[r][c]) continue;
        final color = boat[seat][r][c];
        if (color < 1 || color > 5) continue;
        var count = 0;
        final q = <(int, int)>[(r, c)];
        visited[r][c] = true;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          count++;
          for (final (nr, nc) in orthoNeighbors(cr, cc)) {
            if (!visited[nr][nc] && boat[seat][nr][nc] == color) {
              visited[nr][nc] = true;
              q.add((nr, nc));
            }
          }
        }
        if (count > maxFamily) maxFamily = count;
      }
    }

    for (final l in lessons[seat]) {
      switch (l.kind) {
        case 0:
          total += colorsPresent.length * 2;
        case 1:
          total += row2Filled;
        case 2:
          total += coveredRats * 2;
        case 3:
          if (maxFamily >= 5) total += 6;
        case 4:
          if (colorsPresent.length == 5) total += 7;
        case 5:
          total += 3;
      }
    }
    return total;
  }

  int calcTreasureScore(int seat) {
    var treasureCells = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (boat[seat][r][c] == 7) treasureCells++;
      }
    }
    return rareTreasures[seat] * 3 + treasureCells * 2;
  }

  int calcScore(int seat) {
    final familyVp = calcCatFamilyScore(seat);
    final treasureVp = calcTreasureScore(seat);
    final lessonVp = calcLessonScore(seat);
    final ratPenalty = calcUncoveredRats(seat);
    final roomPenalty = calcUnfilledRooms(seat) * 5;
    return familyVp + treasureVp + lessonVp - ratPenalty - roomPenalty;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    switch (type) {
      case 'rescue':
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= islandCats.length) {
          throw GameError('无效的猫咪编号');
        }
        if (baskets[seat] <= 0) {
          throw GameError('没有可用鱼篓，无法营救猫咪');
        }
        final cat = islandCats[slot];
        if (fish[seat] < cat.fishCost) {
          throw GameError('鱼干不足，需要 ${cat.fishCost} 条鱼');
        }
        final rawCells = action['cells'];
        if (rawCells is! List || rawCells.length != cat.shape.length) {
          throw GameError('放置格数与猫咪形状不符');
        }
        final cells = <(int, int)>[];
        for (final item in rawCells) {
          if (item is! List || item.length < 2) {
            throw GameError('坐标格式错误');
          }
          cells.add((asInt(item[0], -1), asInt(item[1], -1)));
        }
        if (!canPlaceCells(seat, cells, cat.shape)) {
          throw GameError('不满足猫岛奇缘船舱拼放或相邻规则');
        }

        var placeColor = cat.color;
        if (cat.color == 6) {
          final chosen = asInt(action['oshaxColor'], 1);
          placeColor = (chosen >= 1 && chosen <= 5) ? chosen : 1;
        }

        fish[seat] -= cat.fishCost;
        baskets[seat] -= 1;
        islandCats.removeAt(slot);

        var triggeredMap = false;
        for (final (r, c) in cells) {
          boat[seat][r][c] = placeColor;
          if (cat.color == 6) {
            isOshax[seat][r][c] = true;
          }
          if (mapColor[r][c] == placeColor) {
            triggeredMap = true;
          }
        }

        if (triggeredMap) {
          rareTreasures[seat]++;
          (int, int)? tPos;
          final rawT = action['treasureCell'];
          if (rawT is List && rawT.length >= 2) {
            final tr = asInt(rawT[0], -1);
            final tc = asInt(rawT[1], -1);
            if (tr >= 0 && tr < rows && tc >= 0 && tc < cols && boat[seat][tr][tc] == 0) {
              tPos = (tr, tc);
            }
          }
          tPos ??= findBestTreasureCell(seat);
          if (tPos != null) {
            boat[seat][tPos.$1][tPos.$2] = 7;
          }
        }

        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 营救了 ${isleCatTypeEmojis[placeColor]}${isleCatTypeNames[placeColor]}${triggeredMap ? ' 并触发藏宝图获得🪙宝藏！' : ''}';
        host.log(lastAction);
        _advanceTurn();

      case 'lesson':
        final slot = asInt(action['slot'], -1);
        if (slot < 0 || slot >= lessonMarket.length) {
          throw GameError('无效的研习卡编号');
        }
        final card = lessonMarket[slot];
        if (fish[seat] < card.cost) {
          throw GameError('鱼干不足，需要 ${card.cost} 条鱼');
        }
        fish[seat] -= card.cost;
        lessonMarket.removeAt(slot);
        lessons[seat].add(card);
        if (card.kind == 5) {
          permanentBaskets[seat]++;
          baskets[seat]++;
          rareTreasures[seat]++;
        }
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 研习了《${card.title}》';
        host.log(lastAction);
        _advanceTurn();

      case 'pass':
        passed[seat] = true;
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 结束今日行动';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    if (passed.every((p) => p)) {
      if (day >= maxDays) {
        over = true;
        for (var s = 0; s < players; s++) {
          score[s] = calcScore(s);
        }
        lastAction = '猫岛奇缘航程结束！总分最高者获胜';
        host.log(lastAction);
        return;
      }
      day++;
      _startDay();
      turn = (day - 1) % players;
      return;
    }

    for (var step = 1; step <= players; step++) {
      final cand = (turn + step) % players;
      if (!passed[cand]) {
        turn = cand;
        return;
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // Try rescuing a cat if we have a basket and enough fish
    if (baskets[seat] > 0 && islandCats.isNotEmpty) {
      var bestVal = -999999;
      int? bestSlot;
      List<(int, int)>? bestCells;
      var bestOshaxColor = 1;

      for (var s = 0; s < islandCats.length; s++) {
        final cat = islandCats[s];
        if (fish[seat] < cat.fishCost) continue;
        final placements = validPlacementsForShape(seat, cat.shape);
        if (placements.isEmpty) continue;

        final limit = min(placements.length, botLevel >= 2 ? 16 : 6);
        for (var i = 0; i < limit; i++) {
          final cells = placements[i];
          final placeColor = cat.color == 6 ? ((s % 5) + 1) : cat.color;
          var val = cells.length * 4 - cat.fishCost;
          for (final (r, c) in cells) {
            if (rats[r][c]) val += 5;
            if (mapColor[r][c] == placeColor) val += 12;
            for (final (nr, nc) in orthoNeighbors(r, c)) {
              if (boat[seat][nr][nc] == placeColor) val += 8;
            }
          }
          if (val > bestVal) {
            bestVal = val;
            bestSlot = s;
            bestCells = cells;
            bestOshaxColor = placeColor;
          }
        }
      }

      if (bestSlot != null && bestCells != null) {
        return {
          'type': 'rescue',
          'slot': bestSlot,
          'oshaxColor': bestOshaxColor,
          'cells': [
            for (final (r, c) in bestCells) [r, c],
          ],
        };
      }
    }

    // Consider buying a lesson card if we have spare fish
    for (var l = 0; l < lessonMarket.length; l++) {
      if (fish[seat] >= lessonMarket[l].cost + 2) {
        return {'type': 'lesson', 'slot': l};
      }
    }

    return {'type': 'pass'};
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validBySlot = <List<List<List<int>>>>[];
    if (!over && seat >= 0 && seat < players) {
      for (final cat in islandCats) {
        final pl = validPlacementsForShape(seat, cat.shape);
        validBySlot.add([
          for (final cells in pl.take(12))
            [
              for (final (r, c) in cells) [r, c],
            ],
        ]);
      }
    }

    return {
      'rows': rows,
      'cols': cols,
      'day': day,
      'maxDays': maxDays,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'roomMap': roomMap,
      'rats': rats,
      'mapColor': mapColor,
      'islandCats': [for (final c in islandCats) c.toJson()],
      'lessonMarket': [for (final l in lessonMarket) l.toJson()],
      'validBySlot': validBySlot,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'fish': fish[s],
            'baskets': baskets[s],
            'permanentBaskets': permanentBaskets[s],
            'rareTreasures': rareTreasures[s],
            'passed': passed[s],
            'score': score[s],
            'familyVp': calcCatFamilyScore(s),
            'treasureVp': calcTreasureScore(s),
            'lessonVp': calcLessonScore(s),
            'uncoveredRats': calcUncoveredRats(s),
            'unfilledRooms': calcUnfilledRooms(s),
            'lessons': [for (final l in lessons[s]) l.toJson()],
            'boat': [
              for (var r = 0; r < rows; r++) List<int>.of(boat[s][r]),
            ],
          },
      ],
    };
  }
}
