import 'dart:math';

import '../../src/engine.dart';
import 'isle_of_cats.dart';

const List<String> planetTrackNames = [
  '生态',
  '水源',
  '植被',
  '漫游车',
  '科技',
];

const List<String> planetTrackEmojis = [
  '🌿',
  '💧',
  '🌱',
  '🛞',
  '⚙️',
];

const List<int> planetTrackVpTable = [0, 1, 2, 3, 4, 5, 7, 9, 11, 13, 16];

class PlanetTile {
  final int id;
  final int trackA; // 0..4
  final int trackB; // 0..4
  final bool hasMeteor; // ☄️
  final List<(int, int)> shape;

  const PlanetTile({
    required this.id,
    required this.trackA,
    required this.trackB,
    required this.hasMeteor,
    required this.shape,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'trackA': trackA,
        'trackB': trackB,
        'hasMeteor': hasMeteor,
        'shape': [
          for (final (r, c) in shape) [r, c],
        ],
      };
}

class PlanetUnknownGame extends GameEngine {
  static const int numDepots = 6;
  static const int numTracks = 5;

  late final int gridSize;
  late final int maxRounds;

  /// planet[seat][r][c]: 0 = empty, 1..5 = terrain (trackIndex + 1)
  late List<List<List<int>>> planet;
  late List<List<List<bool>>> lifepods; // 🌟
  late List<List<List<bool>>> meteors; // ☄️
  late List<List<int>> tracks; // 5 tracks (0..10) per player
  late List<int> rescuedLifepods;
  late List<int> civCards;
  late List<int> biomassPatches;
  late List<int> techLevel;
  late List<bool> actedInRound;
  late List<int> score;

  final List<PlanetTile> tileDeck = [];
  late List<List<PlanetTile>> depots; // 6 depots, each with 2 tiles

  int round = 1;
  int commander = 0;
  int susanRot = 0; // 0..5
  String phase = 'rotate'; // 'rotate' or 'place'
  int turn = 0;
  bool over = false;
  String lastAction = '未知行星 S.U.S.A.N. 空间站就绪';

  PlanetUnknownGame(super.setup)
      : gridSize = setup.opt<int>('gridSize', 7),
        maxRounds = setup.opt<int>('gridSize', 7) == 7 ? 10 : 8;

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static const List<List<(int, int)>> _shapes = [
    [(0, 0), (0, 1)], // Domino (2)
    [(0, 0), (0, 1), (0, 2)], // I3
    [(0, 0), (0, 1), (1, 0)], // L3
    [(0, 0), (0, 1), (1, 0), (1, 1)], // O4
    [(0, 0), (0, 1), (0, 2), (1, 1)], // T4
  ];

  List<PlanetTile> _buildTileDeck() {
    final raw = <PlanetTile>[];
    var id = 1;
    for (var copy = 0; copy < 3; copy++) {
      for (var a = 0; a < numTracks; a++) {
        for (var b = a + 1; b < numTracks; b++) {
          final shapeIdx = (a + b + copy) % _shapes.length;
          final shape = _shapes[shapeIdx];
          final hasMeteor = shape.length >= 3 && (copy + a) % 2 == 0;
          raw.add(PlanetTile(
            id: id++,
            trackA: a,
            trackB: b,
            hasMeteor: hasMeteor,
            shape: shape,
          ));
        }
      }
    }
    return shuffled(raw, rng);
  }

  @override
  void start() {
    planet = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, 0)),
    );
    lifepods = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, false)),
    );
    meteors = List.generate(
      players,
      (_) => List.generate(gridSize, (_) => List.filled(gridSize, false)),
    );
    tracks = List.generate(
      players,
      (_) => List.filled(numTracks, 0),
    );
    rescuedLifepods = List.filled(players, 0);
    civCards = List.filled(players, 0);
    biomassPatches = List.filled(players, 0);
    techLevel = List.filled(players, 0);
    actedInRound = List.filled(players, false);
    score = List.filled(players, 0);

    // Place 4 Lifepods (🌟) on each player's planet
    final mid = gridSize ~/ 2;
    final podCoords = [
      (1, 1),
      (1, gridSize - 2),
      (gridSize - 2, 1),
      (mid, mid),
    ];
    for (var s = 0; s < players; s++) {
      for (final (r, c) in podCoords) {
        lifepods[s][r][c] = true;
      }
    }

    tileDeck
      ..clear()
      ..addAll(_buildTileDeck());

    depots = List.generate(
      numDepots,
      (_) => [
        tileDeck.removeLast(),
        tileDeck.removeLast(),
      ],
    );

    round = 1;
    commander = 0;
    susanRot = 0;
    phase = 'rotate';
    turn = commander;
    over = false;
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
  }

  int depotForSeat(int seat, [int? rotOverride]) {
    final r = rotOverride ?? susanRot;
    return ((r + seat) % numDepots + numDepots) % numDepots;
  }

  bool canPlaceCells(int seat, List<(int, int)> cells, List<(int, int)> shape) {
    if (!IsleOfCatsGame.matchesShape(cells, shape)) return false;
    for (final (r, c) in cells) {
      if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) return false;
      if (planet[seat][r][c] != 0) return false;
    }
    return true;
  }

  List<List<(int, int)>> validPlacementsForShape(int seat, List<(int, int)> shape) {
    final results = <List<(int, int)>>[];
    final orients = IsleOfCatsGame.allOrientations(shape);
    for (final o in orients) {
      var maxDr = 0;
      var maxDc = 0;
      for (final (dr, dc) in o) {
        if (dr > maxDr) maxDr = dr;
        if (dc > maxDc) maxDc = dc;
      }
      for (var r0 = 0; r0 + maxDr < gridSize; r0++) {
        for (var c0 = 0; c0 + maxDc < gridSize; c0++) {
          var ok = true;
          final cells = <(int, int)>[];
          for (final (dr, dc) in o) {
            final r = r0 + dr;
            final c = c0 + dc;
            if (planet[seat][r][c] != 0) {
              ok = false;
              break;
            }
            cells.add((r, c));
          }
          if (ok) {
            results.add(cells);
          }
        }
      }
    }
    return results;
  }

  void _clearOneMeteor(int seat) {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (meteors[seat][r][c]) {
          meteors[seat][r][c] = false;
          return;
        }
      }
    }
  }

  void _rescueOneLifepod(int seat) {
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (lifepods[seat][r][c]) {
          lifepods[seat][r][c] = false;
          rescuedLifepods[seat]++;
          return;
        }
      }
    }
  }

  void _placeBiomassPatch(int seat) {
    // Pick an empty cell in the most-filled row/column
    (int, int)? best;
    var bestFill = -1;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        if (planet[seat][r][c] != 0) continue;
        var fill = 0;
        for (var k = 0; k < gridSize; k++) {
          if (planet[seat][r][k] != 0) fill++;
          if (planet[seat][k][c] != 0) fill++;
        }
        if (lifepods[seat][r][c]) fill += 3;
        if (fill > bestFill) {
          bestFill = fill;
          best = (r, c);
        }
      }
    }
    if (best != null) {
      final (r, c) = best;
      planet[seat][r][c] = 3; // Biomass terrain
      if (lifepods[seat][r][c]) {
        lifepods[seat][r][c] = false;
        rescuedLifepods[seat]++;
      }
    }
  }

  void advanceTrack(int seat, int trackIdx, {bool allowCascade = true}) {
    if (trackIdx < 0 || trackIdx >= numTracks) return;
    if (tracks[seat][trackIdx] >= 10) return;
    tracks[seat][trackIdx] += 1;
    final lv = tracks[seat][trackIdx];

    switch (trackIdx) {
      case 0: // 🌿 Civ: milestones at 3, 6, 9
        if (lv == 3 || lv == 6 || lv == 9) {
          civCards[seat]++;
        }
      case 1: // 💧 Water: high VP track
        break;
      case 2: // 🌱 Biomass: 1x1 patch at 3, 6, 9
        if (lv == 3 || lv == 6 || lv == 9) {
          biomassPatches[seat]++;
          _placeBiomassPatch(seat);
        }
      case 3: // 🛞 Rover: clears a Meteor or rescues a Lifepod
        var hadMeteor = false;
        for (var r = 0; r < gridSize && !hadMeteor; r++) {
          for (var c = 0; c < gridSize; c++) {
            if (meteors[seat][r][c]) {
              hadMeteor = true;
              break;
            }
          }
        }
        if (hadMeteor) {
          _clearOneMeteor(seat);
        } else {
          _rescueOneLifepod(seat);
        }
      case 4: // ⚙️ Tech: milestones at 2, 4, 6, 8
        if (lv == 2 || lv == 4 || lv == 6 || lv == 8) {
          techLevel[seat]++;
          _clearOneMeteor(seat);
          if (allowCascade && (lv == 4 || lv == 8)) {
            // Advance lowest other track by +1
            var minT = 0;
            for (var t = 1; t < 4; t++) {
              if (tracks[seat][t] < tracks[seat][minT]) minT = t;
            }
            advanceTrack(seat, minT, allowCascade: false);
          }
        }
    }
  }

  bool isRowComplete(int seat, int r) {
    for (var c = 0; c < gridSize; c++) {
      if (planet[seat][r][c] == 0 || meteors[seat][r][c]) return false;
    }
    return true;
  }

  bool isColComplete(int seat, int c) {
    for (var r = 0; r < gridSize; r++) {
      if (planet[seat][r][c] == 0 || meteors[seat][r][c]) return false;
    }
    return true;
  }

  int calcRowColMedalScore(int seat) {
    var medals = 0;
    for (var r = 0; r < gridSize; r++) {
      if (isRowComplete(seat, r)) medals += 3;
    }
    for (var c = 0; c < gridSize; c++) {
      if (isColComplete(seat, c)) medals += 3;
    }
    return medals;
  }

  int calcTrackScore(int seat) {
    var total = 0;
    for (var t = 0; t < numTracks; t++) {
      final lv = tracks[seat][t].clamp(0, 10);
      total += planetTrackVpTable[lv];
    }
    return total;
  }

  int calcScore(int seat) {
    return calcRowColMedalScore(seat) +
        calcTrackScore(seat) +
        rescuedLifepods[seat] +
        civCards[seat] * 2;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('尚未轮到你行动');

    final type = asStr(action['type']);
    if (phase == 'rotate') {
      if (type != 'rotate') throw GameError('当前需由指挥官旋转 S.U.S.A.N. 空间站');
      final rot = asInt(action['rot'], -1);
      if (rot < 0 || rot >= numDepots) {
        throw GameError('空间站旋转角度必须在 0..5 之间');
      }
      susanRot = rot;
      phase = 'place';
      for (var s = 0; s < players; s++) {
        actedInRound[s] = false;
      }
      turn = commander;
      lastAction = '${name(seat)} 将 S.U.S.A.N. 空间站旋转至象限 #$susanRot';
      host.log(lastAction);
      return;
    }

    if (type != 'place') throw GameError('当前阶段需从对应空间站舱位选板块改造行星');
    final slot = asInt(action['slot'], -1);
    if (slot != 0 && slot != 1) throw GameError('空间站舱位槽必须是 0 或 1');

    final dIdx = depotForSeat(seat);
    final tile = depots[dIdx][slot];

    final rawCells = action['cells'];
    if (rawCells is! List || rawCells.length != tile.shape.length) {
      throw GameError('放置格数与板块形状不符');
    }
    final cells = <(int, int)>[];
    for (final item in rawCells) {
      if (item is! List || item.length < 2) {
        throw GameError('坐标格式错误');
      }
      cells.add((asInt(item[0], -1), asInt(item[1], -1)));
    }

    if (!canPlaceCells(seat, cells, tile.shape)) {
      throw GameError('所选行星格子不满足双地形板块形状或已被占用');
    }

    final splitIdx = cells.length ~/ 2;
    for (var i = 0; i < cells.length; i++) {
      final (r, c) = cells[i];
      planet[seat][r][c] = (i < splitIdx ? tile.trackA : tile.trackB) + 1;
      if (lifepods[seat][r][c]) {
        lifepods[seat][r][c] = false;
        rescuedLifepods[seat]++;
      }
    }

    if (tile.hasMeteor) {
      final (mr, mc) = cells.first;
      meteors[seat][mr][mc] = true;
    }

    // Advance BOTH resource tracks by +1
    advanceTrack(seat, tile.trackA);
    advanceTrack(seat, tile.trackB);

    // Refill depot slot
    if (tileDeck.isNotEmpty) {
      depots[dIdx][slot] = tileDeck.removeLast();
    }

    actedInRound[seat] = true;
    score[seat] = calcScore(seat);
    lastAction =
        '${name(seat)} 从舱位 #${dIdx + 1} 部署 ${planetTrackEmojis[tile.trackA]}+${planetTrackEmojis[tile.trackB]} 板块${tile.hasMeteor ? ' (含☄️陨石)' : ''}';
    host.log(lastAction);

    _advancePlaceTurn();
  }

  void _advancePlaceTurn() {
    for (var step = 1; step <= players; step++) {
      final cand = (turn + step) % players;
      if (!actedInRound[cand]) {
        turn = cand;
        return;
      }
    }

    // Check if any player cannot place in the next round or maxRounds reached
    if (round >= maxRounds || tileDeck.isEmpty) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '未知行星改造完成！总分最高者获胜';
      host.log(lastAction);
      return;
    }

    round++;
    commander = (round - 1) % players;
    turn = commander;
    phase = 'rotate';
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'rotate') {
      // Pick a rotation where the commander has a valid placement
      for (var r = 0; r < numDepots; r++) {
        final rot = (susanRot + r) % numDepots;
        var allCanPlace = true;
        for (var s = 0; s < players; s++) {
          final d = depotForSeat(s, rot);
          final can0 = validPlacementsForShape(s, depots[d][0].shape).isNotEmpty;
          final can1 = validPlacementsForShape(s, depots[d][1].shape).isNotEmpty;
          if (!can0 && !can1) {
            allCanPlace = false;
            break;
          }
        }
        if (allCanPlace) {
          return {'type': 'rotate', 'rot': rot};
        }
      }
      return {'type': 'rotate', 'rot': (round - 1) % numDepots};
    }

    final dIdx = depotForSeat(seat);
    var bestVal = -999999;
    var bestSlot = 0;
    List<(int, int)>? bestCells;

    for (var slot = 0; slot < 2; slot++) {
      final tile = depots[dIdx][slot];
      final placements = validPlacementsForShape(seat, tile.shape);
      if (placements.isEmpty) continue;

      final limit = min(placements.length, botLevel >= 2 ? 16 : 6);
      for (var i = 0; i < limit; i++) {
        final cells = placements[i];
        var val = cells.length * 4;
        if (!tile.hasMeteor || tile.trackA == 3 || tile.trackB == 3) {
          val += 6;
        } else {
          val -= 3;
        }
        for (final (r, c) in cells) {
          if (lifepods[seat][r][c]) val += 8;
        }
        if (val > bestVal) {
          bestVal = val;
          bestSlot = slot;
          bestCells = cells;
        }
      }
    }

    if (bestCells == null) return null;
    return {
      'type': 'place',
      'slot': bestSlot,
      'cells': [
        for (final (r, c) in bestCells) [r, c],
      ],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validBySlot = <List<List<List<int>>>>[];
    if (!over && seat >= 0 && seat < players) {
      final dIdx = depotForSeat(seat);
      for (var slot = 0; slot < 2; slot++) {
        final pl = validPlacementsForShape(seat, depots[dIdx][slot].shape);
        validBySlot.add([
          for (final cells in pl.take(12))
            [
              for (final (r, c) in cells) [r, c],
            ],
        ]);
      }
    }

    return {
      'gridSize': gridSize,
      'round': round,
      'maxRounds': maxRounds,
      'commander': commander,
      'susanRot': susanRot,
      'phase': phase,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'depots': [
        for (var d = 0; d < numDepots; d++)
          [
            depots[d][0].toJson(),
            depots[d][1].toJson(),
          ],
      ],
      'validBySlot': validBySlot,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'depotIdx': depotForSeat(s),
            'actedInRound': actedInRound[s],
            'tracks': List<int>.of(tracks[s]),
            'rescuedLifepods': rescuedLifepods[s],
            'civCards': civCards[s],
            'biomassPatches': biomassPatches[s],
            'techLevel': techLevel[s],
            'medalScore': calcRowColMedalScore(s),
            'trackScore': calcTrackScore(s),
            'planet': [
              for (var r = 0; r < gridSize; r++) List<int>.of(planet[s][r]),
            ],
            'lifepods': [
              for (var r = 0; r < gridSize; r++) List<bool>.of(lifepods[s][r]),
            ],
            'meteors': [
              for (var r = 0; r < gridSize; r++) List<bool>.of(meteors[s][r]),
            ],
          },
      ],
    };
  }
}
