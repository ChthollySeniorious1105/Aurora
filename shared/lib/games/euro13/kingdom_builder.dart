import 'dart:math';

import '../../src/engine.dart';

const List<String> kbTerrainNames = [
  '草原',
  '峡谷',
  '沙漠',
  '花田',
  '森林',
  '城堡',
];

const List<String> kbTerrainEmojis = [
  '🌿',
  '🪨',
  '🏜️',
  '🌸',
  '🌲',
  '🏰',
];

const List<String> kbCardNames = [
  '市民',
  '矿工',
  '渔夫',
  '领主',
  '探险家',
];

const List<String> kbCardDescs = [
  '最大相连聚落群每座聚落 +2 分',
  '与峡谷(🪨)相邻的每座聚落 +2 分',
  '与沙漠(🏜️)相邻的每座聚落 +2 分',
  '四个 4×4 象限聚落最多者得 6 分(次名 3 分)',
  '拥有至少 1 座聚落的每条横行 +2 分',
];

class KingdomBuilderGame extends GameEngine {
  static const int mapSize = 8;

  late final int initialSettlements;
  late List<List<int>> map; // 8x8 terrain 0..5
  late List<List<int>> owner; // 8x8 seat or -1
  late List<int> handTerrain; // 0..4 per seat
  late List<int> settlementsLeft;
  late List<int> activeCards; // 3 card ids in 0..4
  late List<int> score;

  bool finalRoundTriggered = false;
  int turn = 0;
  bool over = false;
  String lastAction = '王国建造者开局！请遵循相邻强制法则建造聚落';

  KingdomBuilderGame(super.setup)
      : initialSettlements = setup.opt<int>('settlements', 24);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static List<(int, int)> hexNeighbors(int r, int c) {
    const dirs = [
      (-1, 0),
      (1, 0),
      (0, -1),
      (0, 1),
      (-1, 1),
      (1, -1),
    ];
    return [
      for (final (dr, dc) in dirs)
        if (r + dr >= 0 &&
            r + dr < mapSize &&
            c + dc >= 0 &&
            c + dc < mapSize)
          (r + dr, c + dc),
    ];
  }

  static bool areHexAdjacent((int, int) a, (int, int) b) {
    final dr = b.$1 - a.$1;
    final dc = b.$2 - a.$2;
    return (dr == -1 && dc == 0) ||
        (dr == 1 && dc == 0) ||
        (dr == 0 && dc == -1) ||
        (dr == 0 && dc == 1) ||
        (dr == -1 && dc == 1) ||
        (dr == 1 && dc == -1);
  }

  List<List<int>> _buildMap() {
    // Balanced 8x8 map with 4 Castles (terrain 5) at (1,2), (2,5), (5,2), (6,5)
    // and 12 hexes of each of the 5 playable terrains (0..4) = 60 playable hexes + 4 Castles = 64 hexes!
    return [
      [0, 0, 1, 1, 2, 2, 3, 3],
      [0, 4, 5, 1, 2, 3, 4, 3],
      [4, 4, 0, 1, 2, 5, 4, 3],
      [4, 0, 0, 3, 3, 2, 4, 1],
      [1, 1, 3, 2, 2, 0, 0, 4],
      [1, 3, 5, 2, 1, 0, 4, 4],
      [3, 4, 3, 2, 1, 5, 0, 4],
      [3, 3, 2, 2, 1, 1, 0, 0],
    ];
  }

  @override
  void start() {
    map = _buildMap();
    owner = List.generate(mapSize, (_) => List.filled(mapSize, -1));
    settlementsLeft = List.filled(players, initialSettlements);
    activeCards = shuffled([0, 1, 2, 3, 4], rng).sublist(0, 3)..sort();
    handTerrain = [for (var s = 0; s < players; s++) _drawTerrainCard()];
    score = List.filled(players, 0);
    finalRoundTriggered = false;
    turn = 0;
    over = false;
  }

  int _drawTerrainCard() {
    final availTerrains = <int>[];
    for (var t = 0; t < 5; t++) {
      if (emptyHexesOfTerrain(t).isNotEmpty) {
        availTerrains.add(t);
      }
    }
    if (availTerrains.isEmpty) return 0;
    return availTerrains[rng.nextInt(availTerrains.length)];
  }

  List<(int, int)> emptyHexesOfTerrain(int terrain) {
    final out = <(int, int)>[];
    for (var r = 0; r < mapSize; r++) {
      for (var c = 0; c < mapSize; c++) {
        if (map[r][c] == terrain && owner[r][c] == -1) {
          out.add((r, c));
        }
      }
    }
    return out;
  }

  bool isAdjacentToOwnSettlement(int seat, int r, int c) {
    for (final (nr, nc) in hexNeighbors(r, c)) {
      if (owner[nr][nc] == seat) return true;
    }
    return false;
  }

  /// Returns all legally valid next single-settlement placements for [seat] on [terrain]
  /// according to the Kingdom Builder Mandatory Adjacency Rule.
  List<(int, int)> validNextPlacements(int seat, [int? terrainOverride]) {
    final terrain = terrainOverride ?? handTerrain[seat];
    final empty = emptyHexesOfTerrain(terrain);
    if (empty.isEmpty) return const [];
    final adj = [
      for (final (r, c) in empty)
        if (isAdjacentToOwnSettlement(seat, r, c)) (r, c),
    ];
    return adj.isNotEmpty ? adj : empty;
  }

  /// Evaluates Castles (+3 VP per Castle hex adjacent to at least 1 of [seat]'s settlements).
  int calcCastleScore(int seat) {
    var vp = 0;
    for (var r = 0; r < mapSize; r++) {
      for (var c = 0; c < mapSize; c++) {
        if (map[r][c] == 5) {
          if (isAdjacentToOwnSettlement(seat, r, c)) {
            vp += 3;
          }
        }
      }
    }
    return vp;
  }

  /// Evaluates one Kingdom Builder Scoring Card (`0..4`) for [seat].
  int calcCardScore(int seat, int cardId) {
    switch (cardId) {
      case 0: // 市民 Citizens: largest connected group of your settlements (2 VP per settlement in group)
        final visited = List.generate(mapSize, (_) => List.filled(mapSize, false));
        var bestSize = 0;
        for (var r = 0; r < mapSize; r++) {
          for (var c = 0; c < mapSize; c++) {
            if (visited[r][c] || owner[r][c] != seat) continue;
            var size = 0;
            final q = <(int, int)>[(r, c)];
            visited[r][c] = true;
            while (q.isNotEmpty) {
              final (cr, cc) = q.removeLast();
              size++;
              for (final (nr, nc) in hexNeighbors(cr, cc)) {
                if (!visited[nr][nc] && owner[nr][nc] == seat) {
                  visited[nr][nc] = true;
                  q.add((nr, nc));
                }
              }
            }
            if (size > bestSize) bestSize = size;
          }
        }
        return bestSize * 2;

      case 1: // 矿工 Miners: +2 VP per settlement adjacent to at least 1 Canyon (1)
        var vp = 0;
        for (var r = 0; r < mapSize; r++) {
          for (var c = 0; c < mapSize; c++) {
            if (owner[r][c] != seat) continue;
            if (hexNeighbors(r, c).any((nb) => map[nb.$1][nb.$2] == 1)) {
              vp += 2;
            }
          }
        }
        return vp;

      case 2: // 渔夫 Fishermen: +2 VP per settlement adjacent to at least 1 Desert (2)
        var vp = 0;
        for (var r = 0; r < mapSize; r++) {
          for (var c = 0; c < mapSize; c++) {
            if (owner[r][c] != seat) continue;
            if (hexNeighbors(r, c).any((nb) => map[nb.$1][nb.$2] == 2)) {
              vp += 2;
            }
          }
        }
        return vp;

      case 3: // 领主 Lords: Quadrant majorities (+6 VP for 1st, +3 VP for 2nd in each 4x4 quadrant)
        var vp = 0;
        const quads = [
          (0, 4, 0, 4),
          (0, 4, 4, 8),
          (4, 8, 0, 4),
          (4, 8, 4, 8),
        ];
        for (final (r0, r1, c0, c1) in quads) {
          final counts = List.filled(players, 0);
          for (var r = r0; r < r1; r++) {
            for (var c = c0; c < c1; c++) {
              final ow = owner[r][c];
              if (ow >= 0 && ow < players) counts[ow]++;
            }
          }
          final myCount = counts[seat];
          if (myCount <= 0) continue;
          final distinctHigher = <int>{
            for (final cnt in counts)
              if (cnt > myCount) cnt,
          };
          if (distinctHigher.isEmpty) {
            vp += 6;
          } else if (distinctHigher.length == 1) {
            vp += 3;
          }
        }
        return vp;

      case 4: // 探险家 Discoverers: +2 VP per horizontal row with at least 1 settlement
      default:
        var vp = 0;
        for (var r = 0; r < mapSize; r++) {
          var hasAny = false;
          for (var c = 0; c < mapSize; c++) {
            if (owner[r][c] == seat) {
              hasAny = true;
              break;
            }
          }
          if (hasAny) vp += 2;
        }
        return vp;
    }
  }

  int recalcScore(int seat) {
    var total = calcCastleScore(seat);
    for (final cid in activeCards) {
      total += calcCardScore(seat, cid);
    }
    score[seat] = total;
    return total;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    if (type != 'build') throw GameError('未知操作: $type');

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.isEmpty || rawCells.length > 3) {
      throw GameError('每回合需放置 1～3 座聚落');
    }
    if (rawCells.length > settlementsLeft[seat]) {
      throw GameError('剩余聚落数量不足');
    }

    final cells = <(int, int)>[];
    for (final item in rawCells) {
      if (item is! List || item.length < 2) {
        throw GameError('聚落坐标格式错误');
      }
      cells.add((asInt(item[0], -1), asInt(item[1], -1)));
    }

    final terrain = handTerrain[seat];
    // Validate and apply each settlement sequentially using a rollback snapshot on error
    final placed = <(int, int)>[];
    for (final (r, c) in cells) {
      if (r < 0 || r >= mapSize || c < 0 || c >= mapSize) {
        for (final (pr, pc) in placed) {
          owner[pr][pc] = -1;
          settlementsLeft[seat]++;
        }
        throw GameError('坐标超出地图范围');
      }
      if (owner[r][c] != -1 || map[r][c] != terrain) {
        for (final (pr, pc) in placed) {
          owner[pr][pc] = -1;
          settlementsLeft[seat]++;
        }
        throw GameError('只能放置在与手牌地形匹配的空白六角格上');
      }
      final validNow = validNextPlacements(seat, terrain);
      if (!validNow.contains((r, c))) {
        for (final (pr, pc) in placed) {
          owner[pr][pc] = -1;
          settlementsLeft[seat]++;
        }
        throw GameError('违反相邻强制规则：存在与已有聚落相邻的对应地形空位时必须优先相邻放置');
      }
      owner[r][c] = seat;
      settlementsLeft[seat]--;
      placed.add((r, c));
    }

    if (settlementsLeft[seat] <= 0) {
      finalRoundTriggered = true;
    }

    // Draw a new Terrain Card
    handTerrain[seat] = _drawTerrainCard();

    for (var s = 0; s < players; s++) {
      recalcScore(s);
    }

    lastAction =
        '${name(seat)} 在【${kbTerrainNames[terrain]}】建造了 ${placed.length} 座聚落';
    host.log(lastAction);

    _advanceTurn();
  }

  void _advanceTurn() {
    final nextSeat = (turn + 1) % players;
    final noEmptyLeft = [for (var t = 0; t < 5; t++) emptyHexesOfTerrain(t)]
        .every((l) => l.isEmpty);
    if ((finalRoundTriggered && nextSeat == 0) || noEmptyLeft) {
      over = true;
      for (var s = 0; s < players; s++) {
        recalcScore(s);
      }
      lastAction = '王国建造完毕！结算城堡与三张王国计分卡总分';
      host.log(lastAction);
      return;
    }
    turn = nextSeat;
    if (emptyHexesOfTerrain(handTerrain[turn]).isEmpty) {
      handTerrain[turn] = _drawTerrainCard();
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final terrain = handTerrain[seat];
    final targetCount =
        min(3, min(settlementsLeft[seat], emptyHexesOfTerrain(terrain).length));
    if (targetCount <= 0) return null;

    final chosen = <(int, int)>[];
    for (var step = 0; step < targetCount; step++) {
      final valid = validNextPlacements(seat, terrain);
      if (valid.isEmpty) break;
      var bestCell = valid.first;
      if (botLevel >= 1) {
        var bestVal = -999999;
        for (final (r, c) in valid) {
          owner[r][c] = seat;
          var val = recalcScore(seat) * 10;
          // Bonus for being adjacent to a Castle (5)
          if (hexNeighbors(r, c).any((nb) => map[nb.$1][nb.$2] == 5)) {
            val += 25;
          }
          owner[r][c] = -1;
          if (val > bestVal) {
            bestVal = val;
            bestCell = (r, c);
          }
        }
      }
      owner[bestCell.$1][bestCell.$2] = seat;
      chosen.add(bestCell);
    }
    // Restore temporary placements before returning action
    for (final (r, c) in chosen) {
      owner[r][c] = -1;
    }
    recalcScore(seat);

    return {
      'type': 'build',
      'cells': [
        for (final (r, c) in chosen) [r, c],
      ],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validNow = (!over && seat >= 0 && seat < players && seat == turn)
        ? validNextPlacements(seat)
        : const <(int, int)>[];
    return {
      'mapSize': mapSize,
      'map': [for (final row in map) List<int>.of(row)],
      'owner': [for (final row in owner) List<int>.of(row)],
      'activeCards': List<int>.of(activeCards),
      'turn': turn,
      'over': over,
      'finalRound': finalRoundTriggered,
      'lastAction': lastAction,
      'validCells': [
        for (final (r, c) in validNow) [r, c],
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'handTerrain': handTerrain[s],
            'settlementsLeft': settlementsLeft[s],
            'castleVp': calcCastleScore(s),
            'cardVp': [
              for (final cid in activeCards) calcCardScore(s, cid),
            ],
            'score': score[s],
          },
      ],
    };
  }
}
