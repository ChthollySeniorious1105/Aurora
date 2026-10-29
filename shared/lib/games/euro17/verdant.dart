import '../../src/engine.dart';

const List<String> verdantLightNames = ['强光', '半阴', '耐阴'];
const List<String> verdantLightEmojis = ['☀️', '⛅', '🌙'];

const List<String> verdantColorNames = ['观叶', '开花', '多肉', '奇珍', '爬藤'];
const List<String> verdantColorEmojis = ['🟩', '🟥', '🟨', '🟦', '🟪'];

class VerdantPlantCard {
  final int id;
  final String name;
  final String emoji;
  final int color; // 0..4
  final int light; // 0: ☀️, 1: ⛅, 2: 🌙
  final int targetVerdancy; // 2..4
  final int currentVerdancy;
  final int vp; // 3..8
  final bool potted;
  final int potBonus; // +3, +2, +1 when potted

  const VerdantPlantCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.light,
    required this.targetVerdancy,
    this.currentVerdancy = 0,
    required this.vp,
    this.potted = false,
    this.potBonus = 0,
  });

  VerdantPlantCard copyWith({
    int? currentVerdancy,
    bool? potted,
    int? potBonus,
  }) =>
      VerdantPlantCard(
        id: id,
        name: name,
        emoji: emoji,
        color: color,
        light: light,
        targetVerdancy: targetVerdancy,
        currentVerdancy: currentVerdancy ?? this.currentVerdancy,
        vp: vp,
        potted: potted ?? this.potted,
        potBonus: potBonus ?? this.potBonus,
      );

  Map<String, dynamic> toJson() => {
        'kind': 'plant',
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'colorName': verdantColorNames[color],
        'colorEmoji': verdantColorEmojis[color],
        'light': light,
        'lightName': verdantLightNames[light],
        'lightEmoji': verdantLightEmojis[light],
        'targetVerdancy': targetVerdancy,
        'currentVerdancy': currentVerdancy,
        'vp': vp,
        'potted': potted,
        'potBonus': potBonus,
      };
}

class VerdantRoomCard {
  final int id;
  final String name;
  final String emoji;
  final int color; // 0..4
  /// Directional Window Light icons [N, E, S, W], each in 0..2 (☀️, ⛅, 🌙).
  final List<int> lights;

  const VerdantRoomCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    required this.lights,
  });

  Map<String, dynamic> toJson() => {
        'kind': 'room',
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        'colorName': verdantColorNames[color],
        'colorEmoji': verdantColorEmojis[color],
        'lights': lights,
        'lightEmojis': [for (final l in lights) verdantLightEmojis[l]],
      };
}

class VerdantToken {
  final int id;
  final String name;
  final String emoji;
  final bool isFertilizer; // true = +2🌿 Fertilizer, false = +2 VP Pet/Furniture
  final int value; // 2 verdancy or 2 VP

  const VerdantToken({
    required this.id,
    required this.name,
    required this.emoji,
    required this.isFertilizer,
    this.value = 2,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'isFertilizer': isFertilizer,
        'value': value,
      };
}

class VerdantCell {
  final VerdantPlantCard? plant;
  final VerdantRoomCard? room;

  const VerdantCell({this.plant, this.room});

  bool get isEmpty => plant == null && room == null;

  Map<String, dynamic>? toJson() {
    if (plant != null) return plant!.toJson();
    if (room != null) return room!.toJson();
    return null;
  }
}

class VerdantGame extends GameEngine {
  static const int rows = 3;
  static const int cols = 5;
  static const int marketCols = 4;

  // Orthogonal directions: 0=N (-1,0), 1=E (0,+1), 2=S (+1,0), 3=W (0,-1)
  static const List<(int, int)> dirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  late final int maxTurns;
  late List<VerdantPlantCard> plantDeck;
  late List<VerdantRoomCard> roomDeck;
  late List<VerdantToken> tokenDeck;

  late List<VerdantPlantCard?> plantRow;
  late List<VerdantToken?> tokenRow;
  late List<VerdantRoomCard?> roomRow;
  late List<int> plantThumbs;
  late List<int> roomThumbs;

  /// Each player's 3x5 Home Grid (`grid[seat][r][c]`).
  /// Even parity `(r + c) % 2 == 0` holds Plant Cards;
  /// Odd parity `(r + c) % 2 == 1` holds Room Cards.
  late List<List<List<VerdantCell>>> grid;
  late List<int> thumbs;
  late List<int> roomBonusVp;
  late List<int> tokenVp;
  late List<int> pottedCount;
  late List<int> turnsTaken;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '绿意盎然室内园艺构筑开启';

  VerdantGame(super.setup) : maxTurns = setup.opt<int>('turns', 13);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static bool isPlantCell(int r, int c) => (r + c) % 2 == 0;
  static bool isRoomCell(int r, int c) => (r + c) % 2 == 1;

  List<VerdantPlantCard> _buildPlantDeck() {
    const templates = [
      ('龟背竹', '🪴', 0, 1, 3, 5),
      ('琴叶榕', '🌿', 0, 0, 4, 7),
      ('虎皮兰', '🌱', 0, 2, 2, 3),
      ('绿萝柱', '🍃', 0, 2, 3, 4),
      ('白鹤芋', '🦢', 1, 1, 3, 5),
      ('红掌花', '🌺', 1, 0, 3, 6),
      ('蝴蝶兰', '🌸', 1, 1, 4, 7),
      ('非洲紫罗兰', '💐', 1, 2, 2, 4),
      ('玉露多肉', '🌵', 2, 0, 2, 4),
      ('芦荟盆栽', '🪴', 2, 0, 3, 5),
      ('生石花', '🌼', 2, 0, 4, 7),
      ('熊童子', '🐾', 2, 1, 3, 5),
      ('猪笼草', '🏺', 3, 1, 4, 8),
      ('捕蝇草', '🪷', 3, 0, 3, 6),
      ('空气凤梨', '🍍', 3, 2, 2, 4),
      ('鹿角蕨', '🦌', 3, 2, 4, 7),
      ('常春藤', '🧗', 4, 2, 2, 3),
      ('爱之蔓', '💜', 4, 1, 3, 5),
      ('球兰花藤', '🏵️', 4, 0, 4, 7),
      ('佛珠吊兰', '📿', 4, 1, 3, 6),
    ];
    var id = 1;
    final out = <VerdantPlantCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, col, lt, tv, vp) in templates) {
        out.add(VerdantPlantCard(
          id: id++,
          name: nm,
          emoji: em,
          color: col,
          light: lt,
          targetVerdancy: tv,
          vp: vp,
        ));
      }
    }
    return shuffled(out, rng);
  }

  List<VerdantRoomCard> _buildRoomDeck() {
    const templates = [
      ('阳光花房', '🏡', 0, [0, 1, 0, 2]),
      ('温馨客厅', '🛋️', 0, [1, 0, 2, 1]),
      ('浪漫露台', '🌺', 1, [0, 0, 1, 2]),
      ('彩绘餐厅', '🍽️', 1, [1, 2, 0, 1]),
      ('南向飘窗', '🪟', 2, [0, 2, 0, 1]),
      ('暖阳午茶室', '☕', 2, [2, 0, 1, 0]),
      ('静谧书房', '📚', 3, [2, 1, 2, 0]),
      ('珍奇画廊', '🖼️', 3, [1, 2, 1, 2]),
      ('复古阁楼', '🪜', 4, [2, 0, 2, 1]),
      ('森林卧室', '🛏️', 4, [1, 1, 2, 0]),
    ];
    var id = 101;
    final out = <VerdantRoomCard>[];
    for (var copy = 0; copy < 7; copy++) {
      for (final (nm, em, col, lts) in templates) {
        out.add(VerdantRoomCard(
          id: id++,
          name: nm,
          emoji: em,
          color: col,
          lights: lts,
        ));
      }
    }
    return shuffled(out, rng);
  }

  List<VerdantToken> _buildTokenDeck() {
    const templates = [
      ('有机液肥', '🧪', true, 2),
      ('缓释花肥', '🌿', true, 2),
      ('阳光营养液', '💧', true, 2),
      ('橘猫伴侣', '🐱', false, 2),
      ('柯基萌犬', '🐶', false, 2),
      ('复古留声机', '📻', false, 2),
      ('藤编摇椅', '🪑', false, 2),
      ('手工陶壶', '🫖', false, 2),
    ];
    var id = 301;
    final out = <VerdantToken>[];
    for (var copy = 0; copy < 10; copy++) {
      for (final (nm, em, fert, val) in templates) {
        out.add(VerdantToken(
          id: id++,
          name: nm,
          emoji: em,
          isFertilizer: fert,
          value: val,
        ));
      }
    }
    return shuffled(out, rng);
  }

  VerdantPlantCard _drawPlant() {
    if (plantDeck.isEmpty) plantDeck = _buildPlantDeck();
    return plantDeck.removeLast();
  }

  VerdantRoomCard _drawRoom() {
    if (roomDeck.isEmpty) roomDeck = _buildRoomDeck();
    return roomDeck.removeLast();
  }

  VerdantToken _drawToken() {
    if (tokenDeck.isEmpty) tokenDeck = _buildTokenDeck();
    return tokenDeck.removeLast();
  }

  @override
  void start() {
    plantDeck = _buildPlantDeck();
    roomDeck = _buildRoomDeck();
    tokenDeck = _buildTokenDeck();

    plantRow = List.generate(marketCols, (_) => _drawPlant());
    tokenRow = List.generate(marketCols, (_) => _drawToken());
    roomRow = List.generate(marketCols, (_) => _drawRoom());
    plantThumbs = List.filled(marketCols, 0);
    roomThumbs = List.filled(marketCols, 0);

    grid = List.generate(
      players,
      (_) => List.generate(
        rows,
        (_) => List.generate(cols, (_) => const VerdantCell()),
      ),
    );
    thumbs = List.filled(players, 1);
    roomBonusVp = List.filled(players, 0);
    tokenVp = List.filled(players, 0);
    pottedCount = List.filled(players, 0);
    turnsTaken = List.filled(players, 0);
    score = List.filled(players, 0);

    // Give each player 1 starting Plant at (1, 1) (even parity) and 1 starting Room at (1, 2) (odd parity)
    for (var s = 0; s < players; s++) {
      final startPlant = _drawPlant();
      final startRoom = _drawRoom();
      grid[s][1][1] = VerdantCell(plant: startPlant);
      grid[s][1][2] = VerdantCell(room: startRoom);
      // Apply initial adjacency between (1,1) and (1,2)
      // (1,2) is East of (1,1), so Room's West window (dir 3) touches Plant at (1,1)
      if (startRoom.lights[3] == startPlant.light) {
        _addVerdancyAt(s, 1, 1, 1);
      }
      if (startRoom.color == startPlant.color) {
        roomBonusVp[s] += 1;
      }
      score[s] = calcScore(s);
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，请从中央市场选择 1 列拿取植物/房间卡与园艺标记';
  }

  int nextPotBonus(int seat) {
    final cnt = pottedCount[seat];
    if (cnt < 2) return 3;
    if (cnt < 4) return 2;
    return 1;
  }

  void _addVerdancyAt(int seat, int r, int c, int amount) {
    if (amount <= 0) return;
    final p = grid[seat][r][c].plant;
    if (p == null || p.potted) return;
    final nextV = p.currentVerdancy + amount;
    if (nextV >= p.targetVerdancy) {
      final pb = nextPotBonus(seat);
      pottedCount[seat]++;
      grid[seat][r][c] = VerdantCell(
        plant: p.copyWith(
          currentVerdancy: p.targetVerdancy,
          potted: true,
          potBonus: pb,
        ),
      );
    } else {
      grid[seat][r][c] = VerdantCell(
        plant: p.copyWith(currentVerdancy: nextV),
      );
    }
  }

  /// Applies Fertilizer (+2🌿) to the specified `(fertR, fertC)` if it holds an unpotted plant,
  /// or automatically chooses the best unpotted plant in `grid[seat]`.
  (int, int)? _applyFertilizer(int seat, int fertR, int fertC, int amount) {
    if (fertR >= 0 &&
        fertR < rows &&
        fertC >= 0 &&
        fertC < cols &&
        grid[seat][fertR][fertC].plant != null &&
        !grid[seat][fertR][fertC].plant!.potted) {
      _addVerdancyAt(seat, fertR, fertC, amount);
      return (fertR, fertC);
    }
    // Auto-select best unpotted plant
    int bestR = -1;
    int bestC = -1;
    int bestScore = -1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = grid[seat][r][c].plant;
        if (p == null || p.potted) continue;
        final willPot = (p.currentVerdancy + amount >= p.targetVerdancy) ? 100 : 0;
        final val = willPot + p.vp * 10 + p.currentVerdancy;
        if (val > bestScore) {
          bestScore = val;
          bestR = r;
          bestC = c;
        }
      }
    }
    if (bestR >= 0) {
      _addVerdancyAt(seat, bestR, bestC, amount);
      return (bestR, bestC);
    }
    return null;
  }

  int calcPlantVp(int seat) {
    var pts = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final p = grid[seat][r][c].plant;
        if (p == null) continue;
        if (p.potted) {
          pts += p.vp + p.potBonus;
        } else {
          pts += p.currentVerdancy ~/ 2;
        }
      }
    }
    return pts;
  }

  int calcScore(int seat) =>
      calcPlantVp(seat) + roomBonusVp[seat] + tokenVp[seat] + (thumbs[seat] ~/ 2);

  List<(int, int)> emptyCellsFor(int seat, {required bool pickPlant}) {
    final res = <(int, int)>[];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (!grid[seat][r][c].isEmpty) continue;
        if (pickPlant && isPlantCell(r, c)) res.add((r, c));
        if (!pickPlant && isRoomCell(r, c)) res.add((r, c));
      }
    }
    return res;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'use_thumb':
        if (thumbs[seat] < 2) {
          throw GameError('需要至少 2 枚绿手指 (👍) 才能催熟植物 (+1🌿)');
        }
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        final target = _applyFertilizer(seat, r, c, 1);
        if (target == null) {
          throw GameError('当前没有未装盆的植物可催熟');
        }
        thumbs[seat] -= 2;
        score[seat] = calcScore(seat);
        final tp = grid[seat][target.$1][target.$2].plant!;
        lastAction =
            '${name(seat)} 消耗 2👍 为 ${tp.emoji}${tp.name} 增加 +1🌿 (${tp.currentVerdancy}/${tp.targetVerdancy})';
        host.log(lastAction);

      case 'draft':
        final col = asInt(action['col'], -1);
        if (col < 0 || col >= marketCols) {
          throw GameError('无效的市场列编号: $col');
        }
        final pickPlant = asBool(action['pickPlant']);
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (r < 0 || r >= rows || c < 0 || c >= cols) {
          throw GameError('无效的网格坐标 ($r, $c)');
        }
        if (!grid[seat][r][c].isEmpty) {
          throw GameError('网格 ($r, $c) 已有卡牌');
        }
        if (pickPlant && !isPlantCell(r, c)) {
          throw GameError('植物卡只能放置在偶校验格 (r + c) % 2 == 0');
        }
        if (!pickPlant && !isRoomCell(r, c)) {
          throw GameError('房间卡只能放置在奇校验格 (r + c) % 2 == 1');
        }

        final token = tokenRow[col];
        var lightMatches = 0;
        var colorMatches = 0;
        String cardDesc = '';

        if (pickPlant) {
          final plant = plantRow[col];
          if (plant == null) throw GameError('该列已无植物卡');
          final gainedThumbs = plantThumbs[col];
          thumbs[seat] += gainedThumbs;
          plantThumbs[col] = 0;
          roomThumbs[col] += 1; // Place 1 👍 on unchosen Room card

          grid[seat][r][c] = VerdantCell(plant: plant);

          // Check all 4 orthogonal neighbors for Rooms
          for (var d = 0; d < 4; d++) {
            final nr = r + dirs[d].$1;
            final nc = c + dirs[d].$2;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final adjRoom = grid[seat][nr][nc].room;
            if (adjRoom == null) continue;
            // Neighbor Room is in direction d from Plant, so Room's window facing Plant is (d + 2) % 4
            final roomWindowDir = (d + 2) % 4;
            if (adjRoom.lights[roomWindowDir] == plant.light) {
              lightMatches++;
            }
            if (adjRoom.color == plant.color) {
              colorMatches++;
            }
          }
          if (lightMatches > 0) {
            _addVerdancyAt(seat, r, c, lightMatches);
          }
          if (colorMatches > 0) {
            roomBonusVp[seat] += colorMatches;
          }
          plantRow[col] = _drawPlant();
          cardDesc = '${plant.emoji}${plant.name}';
        } else {
          final room = roomRow[col];
          if (room == null) throw GameError('该列已无房间卡');
          final gainedThumbs = roomThumbs[col];
          thumbs[seat] += gainedThumbs;
          roomThumbs[col] = 0;
          plantThumbs[col] += 1; // Place 1 👍 on unchosen Plant card

          grid[seat][r][c] = VerdantCell(room: room);

          // Check all 4 orthogonal neighbors for Plants
          for (var d = 0; d < 4; d++) {
            final nr = r + dirs[d].$1;
            final nc = c + dirs[d].$2;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final adjPlant = grid[seat][nr][nc].plant;
            if (adjPlant == null) continue;
            // Room's window in direction d faces the neighbor Plant at (nr, nc)
            if (room.lights[d] == adjPlant.light) {
              lightMatches++;
              _addVerdancyAt(seat, nr, nc, 1);
            }
            if (room.color == adjPlant.color) {
              colorMatches++;
            }
          }
          if (colorMatches > 0) {
            roomBonusVp[seat] += colorMatches;
          }
          roomRow[col] = _drawRoom();
          cardDesc = '${room.emoji}${room.name}';
        }

        // Apply drafted token
        String tokDesc = '';
        if (token != null) {
          if (token.isFertilizer) {
            final fertR = asInt(action['fertR'], r);
            final fertC = asInt(action['fertC'], c);
            final target = _applyFertilizer(seat, fertR, fertC, token.value);
            tokDesc = target != null
                ? ' + ${token.emoji}${token.name}(+${token.value}🌿)'
                : ' + ${token.emoji}${token.name}';
          } else {
            tokenVp[seat] += token.value;
            tokDesc = ' + ${token.emoji}${token.name}(+${token.value}分)';
          }
          tokenRow[col] = _drawToken();
        }

        turnsTaken[seat]++;
        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 拿取第${col + 1}列 $cardDesc 放入($r,$c)$tokDesc (光照+${lightMatches}🌿, 同色+$colorMatches分)';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (turnsTaken[nextSeat] < maxTurns) {
        turn = nextSeat;
        round = turnsTaken[turn] + 1;
        return;
      }
    }
    over = true;
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
    lastAction = '绿意盎然终局结算完成！总分最高者获胜';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (thumbs[seat] >= 2) {
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          final p = grid[seat][r][c].plant;
          if (p != null && !p.potted && p.currentVerdancy + 1 == p.targetVerdancy) {
            return {'type': 'use_thumb', 'r': r, 'c': c};
          }
        }
      }
    }

    final plantCells = emptyCellsFor(seat, pickPlant: true);
    final roomCells = emptyCellsFor(seat, pickPlant: false);

    int bestCol = 0;
    bool bestPickPlant = plantCells.isNotEmpty;
    int bestR = plantCells.isNotEmpty ? plantCells.first.$1 : roomCells.first.$1;
    int bestC = plantCells.isNotEmpty ? plantCells.first.$2 : roomCells.first.$2;
    int bestVal = -999999;

    for (var col = 0; col < marketCols; col++) {
      final tok = tokenRow[col];
      final tokVal = tok == null ? 0 : 4;

      if (plantCells.isNotEmpty && plantRow[col] != null) {
        final p = plantRow[col]!;
        for (final (r, c) in plantCells) {
          var matches = 0;
          var colBonus = 0;
          for (var d = 0; d < 4; d++) {
            final nr = r + dirs[d].$1;
            final nc = c + dirs[d].$2;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final rm = grid[seat][nr][nc].room;
            if (rm == null) continue;
            if (rm.lights[(d + 2) % 4] == p.light) matches++;
            if (rm.color == p.color) colBonus++;
          }
          final v = p.vp * 3 + matches * 8 + colBonus * 5 + plantThumbs[col] * 2 + tokVal;
          if (v > bestVal) {
            bestVal = v;
            bestCol = col;
            bestPickPlant = true;
            bestR = r;
            bestC = c;
          }
        }
      }

      if (roomCells.isNotEmpty && roomRow[col] != null) {
        final rm = roomRow[col]!;
        for (final (r, c) in roomCells) {
          var matches = 0;
          var colBonus = 0;
          for (var d = 0; d < 4; d++) {
            final nr = r + dirs[d].$1;
            final nc = c + dirs[d].$2;
            if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
            final pl = grid[seat][nr][nc].plant;
            if (pl == null) continue;
            if (!pl.potted && rm.lights[d] == pl.light) matches++;
            if (rm.color == pl.color) colBonus++;
          }
          final v = matches * 9 + colBonus * 5 + roomThumbs[col] * 2 + tokVal;
          if (v > bestVal) {
            bestVal = v;
            bestCol = col;
            bestPickPlant = false;
            bestR = r;
            bestC = c;
          }
        }
      }
    }

    return {
      'type': 'draft',
      'col': bestCol,
      'pickPlant': bestPickPlant,
      'r': bestR,
      'c': bestC,
      'fertR': bestR,
      'fertC': bestC,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxTurns': maxTurns,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'plantRow': [for (final p in plantRow) p?.toJson()],
      'tokenRow': [for (final t in tokenRow) t?.toJson()],
      'roomRow': [for (final r in roomRow) r?.toJson()],
      'plantThumbs': List<int>.of(plantThumbs),
      'roomThumbs': List<int>.of(roomThumbs),
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'plantVp': calcPlantVp(s),
            'roomBonusVp': roomBonusVp[s],
            'tokenVp': tokenVp[s],
            'thumbs': thumbs[s],
            'pottedCount': pottedCount[s],
            'turnsTaken': turnsTaken[s],
            'grid': [
              for (var r = 0; r < rows; r++)
                [
                  for (var c = 0; c < cols; c++) grid[s][r][c].toJson(),
                ],
            ],
          },
      ],
    };
  }
}
