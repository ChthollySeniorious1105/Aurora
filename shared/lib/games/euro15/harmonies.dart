import '../../src/engine.dart';

const List<String> harmoniesTokenNames = [
  '树干',
  '树叶',
  '山脉',
  '建筑',
  '麦田',
  '河流',
];

const List<String> harmoniesTokenEmojis = [
  '🪵',
  '🌿',
  '⛰️',
  '🧱',
  '🌾',
  '🌊',
];

class HarmoniesAnimalCard {
  final int id;
  final String name;
  final String emoji;
  final int anchorToken; // 0..5 top token where the cube sits
  final int anchorHeight; // 1..3 required stack height at anchor
  final int adjToken; // 0..5 required adjacent top token
  final int adjMinHeight; // 1..3 minimum stack height at adjacent cell
  final int cubesPlaced; // 0..3 cubes placed from this card

  const HarmoniesAnimalCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.anchorToken,
    required this.anchorHeight,
    required this.adjToken,
    required this.adjMinHeight,
    this.cubesPlaced = 0,
  });

  int get cubesLeft => 3 - cubesPlaced;

  static const List<int> cubePoints = [0, 4, 9, 15];

  int get vp => cubePoints[cubesPlaced.clamp(0, 3)];

  String get patternDesc =>
      '${harmoniesTokenEmojis[anchorToken]}×$anchorHeight 邻接 ${harmoniesTokenEmojis[adjToken]}≥$adjMinHeight';

  HarmoniesAnimalCard copyWith({int? cubesPlaced}) => HarmoniesAnimalCard(
        id: id,
        name: name,
        emoji: emoji,
        anchorToken: anchorToken,
        anchorHeight: anchorHeight,
        adjToken: adjToken,
        adjMinHeight: adjMinHeight,
        cubesPlaced: cubesPlaced ?? this.cubesPlaced,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'anchorToken': anchorToken,
        'anchorHeight': anchorHeight,
        'adjToken': adjToken,
        'adjMinHeight': adjMinHeight,
        'cubesPlaced': cubesPlaced,
        'cubesLeft': cubesLeft,
        'vp': vp,
        'patternDesc': patternDesc,
      };
}

class HarmoniesGame extends GameEngine {
  static const int rows = 5;
  static const int cols = 5;
  static const int maxStackHeight = 3;
  static const int numPouches = 5;
  static const int maxPersonalAnimals = 4;

  late final int maxRounds;
  late List<List<List<List<int>>>> stacks; // stacks[seat][r][c] = [t0, ...]
  late List<List<List<int>>> animalAt; // animalAt[seat][r][c] = animal card id (0 = none)
  late List<List<HarmoniesAnimalCard>> playerAnimals;
  late List<int> score;

  final List<List<int>> pouches = []; // 5 pouches of 3 tokens each
  final List<HarmoniesAnimalCard> animalDeck = [];
  final List<HarmoniesAnimalCard> animalMarket = [];

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '森灵合鸣生态构筑开启';

  HarmoniesGame(super.setup) : maxRounds = setup.opt<int>('rounds', 10);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  static List<(int, int)> orthoNeighbors(int r, int c) {
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];
    return [
      for (final (dr, dc) in dirs)
        if (r + dr >= 0 && r + dr < rows && c + dc >= 0 && c + dc < cols)
          (r + dr, c + dc),
    ];
  }

  /// Checks whether [token] (0..5) can be legally stacked onto [stack].
  static bool canStackToken(List<int> stack, int token) {
    if (stack.length >= maxStackHeight) return false;
    return switch (token) {
      // 0: 🪵 Brown Trunk — empty cell (h=0) or on 1 Trunk (h=1)
      0 => stack.isEmpty || (stack.length == 1 && stack[0] == 0),
      // 1: 🌿 Green Canopy — empty cell (h=0), 1 Trunk (h=1), or 2 Trunks (h=2)
      1 => stack.isEmpty ||
          (stack.length == 1 && stack[0] == 0) ||
          (stack.length == 2 && stack[0] == 0 && stack[1] == 0),
      // 2: ⛰️ Gray Mountain — empty cell or stacked up to 3 Mountains
      2 => stack.isEmpty ||
          (stack.length == 1 && stack[0] == 2) ||
          (stack.length == 2 && stack[0] == 2 && stack[1] == 2),
      // 3: 🧱 Red Building — empty cell or stacked 2 high on 🧱(3)/⛰️(2)/🪵(0)
      3 => stack.isEmpty ||
          (stack.length == 1 &&
              (stack[0] == 3 || stack[0] == 2 || stack[0] == 0)),
      // 4: 🌾 Yellow Field — empty cell only
      4 => stack.isEmpty,
      // 5: 🌊 Blue Water — empty cell only
      5 => stack.isEmpty,
      _ => false,
    };
  }

  bool canPlaceAt(int seat, int r, int c, int token) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    if (animalAt[seat][r][c] > 0) return false; // cannot stack on top of an animal cube
    return canStackToken(stacks[seat][r][c], token);
  }

  List<HarmoniesAnimalCard> _buildAnimalDeck() {
    const templates = [
      ('赤狐', '🦊', 1, 2, 4, 1), // 2-tall Tree next to Field
      ('猫头鹰', '🦉', 1, 3, 0, 1), // 3-tall Tree next to Trunk
      ('河狸', '🦫', 0, 2, 5, 1), // 2-tall Trunk next to Water
      ('翠鸟', '🐦', 5, 1, 1, 1), // Water next to Bush/Tree
      ('雪貂', '🦡', 1, 1, 2, 1), // Bush next to Mountain
      ('岩羊', '🐐', 2, 2, 2, 1), // 2-tall Mountain next to Mountain
      ('金雕', '🦅', 2, 3, 5, 1), // 3-tall Mountain next to Water
      ('田鼠', '🐭', 4, 1, 3, 1), // Field next to Building
      ('刺猬', '🦔', 1, 1, 4, 1), // Bush next to Field
      ('白鹳', '🦩', 3, 2, 5, 1), // 2-tall Building next to Water
      ('青蛙', '🐸', 5, 1, 4, 1), // Water next to Field
      ('蜜蜂', '🐝', 4, 1, 1, 2), // Field next to 2+ tall Tree
      ('松鼠', '🐿️', 1, 2, 1, 1), // 2-tall Tree next to Canopy
      ('棕熊', '🐻', 2, 2, 1, 2), // 2-tall Mountain next to 2+ tall Tree
      ('燕子', '🕊️', 3, 2, 4, 1), // 2-tall Building next to Field
      ('水獭', '🦦', 5, 1, 2, 1), // Water next to Mountain
    ];
    final list = <HarmoniesAnimalCard>[];
    var id = 1;
    for (final (nm, em, aTok, aH, adjTok, adjH) in templates) {
      list.add(HarmoniesAnimalCard(
        id: id++,
        name: nm,
        emoji: em,
        anchorToken: aTok,
        anchorHeight: aH,
        adjToken: adjTok,
        adjMinHeight: adjH,
      ));
    }
    return shuffled(list, rng);
  }

  List<int> _drawPouch() => [
        for (var i = 0; i < 3; i++) rng.nextInt(6),
      ];

  @override
  void start() {
    stacks = List.generate(
      players,
      (_) => List.generate(rows, (_) => List.generate(cols, (_) => <int>[])),
    );
    animalAt = List.generate(
      players,
      (_) => List.generate(rows, (_) => List.filled(cols, 0)),
    );
    playerAnimals = List.generate(players, (_) => <HarmoniesAnimalCard>[]);
    score = List.filled(players, 0);

    pouches
      ..clear()
      ..addAll([for (var i = 0; i < numPouches; i++) _drawPouch()]);

    animalDeck
      ..clear()
      ..addAll(_buildAnimalDeck());
    animalMarket.clear();
    while (animalMarket.length < 5 && animalDeck.isNotEmpty) {
      animalMarket.add(animalDeck.removeLast());
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，请选择圆盘指示物袋并构筑栖息地';
  }

  /// Checks if cell (r, c) on [seat]'s board matches [card]'s habitat pattern.
  bool matchesAnimalPattern(int seat, HarmoniesAnimalCard card, int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return false;
    if (animalAt[seat][r][c] > 0) return false;
    final st = stacks[seat][r][c];
    if (st.length != card.anchorHeight || st.last != card.anchorToken) {
      return false;
    }
    for (final (nr, nc) in orthoNeighbors(r, c)) {
      final nst = stacks[seat][nr][nc];
      if (nst.length >= card.adjMinHeight && nst.last == card.adjToken) {
        return true;
      }
    }
    return false;
  }

  /// Automatically places animal cubes on any newly completed habitat patterns.
  int autoPlaceAnimals(int seat) {
    var placed = 0;
    for (var i = 0; i < playerAnimals[seat].length; i++) {
      var card = playerAnimals[seat][i];
      if (card.cubesLeft <= 0) continue;
      for (var r = 0; r < rows && card.cubesLeft > 0; r++) {
        for (var c = 0; c < cols && card.cubesLeft > 0; c++) {
          if (matchesAnimalPattern(seat, card, r, c)) {
            animalAt[seat][r][c] = card.id;
            card = card.copyWith(cubesPlaced: card.cubesPlaced + 1);
            playerAnimals[seat][i] = card;
            placed++;
          }
        }
      }
    }
    return placed;
  }

  /// Trees & Bushes (top == 1): height 1 = 1 VP, height 2 = 3 VP, height 3 = 7 VP.
  int calcTreeScore(int seat) {
    var pts = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final st = stacks[seat][r][c];
        if (st.isNotEmpty && st.last == 1) {
          pts += switch (st.length) {
            1 => 1,
            2 => 3,
            3 => 7,
            _ => 0,
          };
        }
      }
    }
    return pts;
  }

  /// Mountains (top == 2): height 1/2/3 = 1/3/7 VP if adjacent to another Mountain!
  int calcMountainScore(int seat) {
    var pts = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final st = stacks[seat][r][c];
        if (st.isNotEmpty && st.last == 2) {
          final hasAdjMountain = orthoNeighbors(r, c).any((nb) {
            final nst = stacks[seat][nb.$1][nb.$2];
            return nst.isNotEmpty && nst.last == 2;
          });
          if (hasAdjMountain) {
            pts += switch (st.length) {
              1 => 1,
              2 => 3,
              3 => 7,
              _ => 0,
            };
          }
        }
      }
    }
    return pts;
  }

  /// Fields (top == 4): +5 VP for each contiguous group of >= 2 Yellow Fields!
  int calcFieldScore(int seat) {
    final vis = List.generate(rows, (_) => List.filled(cols, false));
    var pts = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (vis[r][c]) continue;
        final st = stacks[seat][r][c];
        if (st.isEmpty || st.last != 4) continue;
        var count = 0;
        final q = <(int, int)>[(r, c)];
        vis[r][c] = true;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          count++;
          for (final (nr, nc) in orthoNeighbors(cr, cc)) {
            if (!vis[nr][nc]) {
              final nst = stacks[seat][nr][nc];
              if (nst.isNotEmpty && nst.last == 4) {
                vis[nr][nc] = true;
                q.add((nr, nc));
              }
            }
          }
        }
        if (count >= 2) pts += 5;
      }
    }
    return pts;
  }

  /// Buildings (top == 3 && height == 2): +5 VP if surrounded by >= 3 distinct top token colors!
  int calcBuildingScore(int seat) {
    var pts = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final st = stacks[seat][r][c];
        if (st.length == 2 && st.last == 3) {
          final neighborColors = <int>{};
          for (var dr = -1; dr <= 1; dr++) {
            for (var dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              final nr = r + dr;
              final nc = c + dc;
              if (nr >= 0 && nr < rows && nc >= 0 && nc < cols) {
                final nst = stacks[seat][nr][nc];
                if (nst.isNotEmpty) {
                  neighborColors.add(nst.last);
                }
              }
            }
          }
          if (neighborColors.length >= 3) {
            pts += 5;
          }
        }
      }
    }
    return pts;
  }

  /// Rivers (top == 5): Longest contiguous River scores 2/5/8/11... VP!
  int calcRiverScore(int seat) {
    final vis = List.generate(rows, (_) => List.filled(cols, false));
    var maxLen = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if (vis[r][c]) continue;
        final st = stacks[seat][r][c];
        if (st.isEmpty || st.last != 5) continue;
        var count = 0;
        final q = <(int, int)>[(r, c)];
        vis[r][c] = true;
        while (q.isNotEmpty) {
          final (cr, cc) = q.removeLast();
          count++;
          for (final (nr, nc) in orthoNeighbors(cr, cc)) {
            if (!vis[nr][nc]) {
              final nst = stacks[seat][nr][nc];
              if (nst.isNotEmpty && nst.last == 5) {
                vis[nr][nc] = true;
                q.add((nr, nc));
              }
            }
          }
        }
        if (count > maxLen) maxLen = count;
      }
    }
    if (maxLen < 2) return 0;
    return 2 + (maxLen - 2) * 3;
  }

  int calcAnimalScore(int seat) {
    var pts = 0;
    for (final a in playerAnimals[seat]) {
      pts += a.vp;
    }
    return pts;
  }

  int calcScore(int seat) =>
      calcTreeScore(seat) +
      calcMountainScore(seat) +
      calcFieldScore(seat) +
      calcBuildingScore(seat) +
      calcRiverScore(seat) +
      calcAnimalScore(seat);

  /// Finds 3 legal cells for the 3 tokens in [pouchTokens] on [seat]'s board.
  List<(int, int)>? findPlacementForPouch(int seat, List<int> pouchTokens) {
    final tempStacks = [
      for (var r = 0; r < rows; r++)
        [
          for (var c = 0; c < cols; c++) List<int>.of(stacks[seat][r][c]),
        ],
    ];
    final chosen = <(int, int)>[];

    for (final tok in pouchTokens) {
      (int, int)? bestCell;
      var bestVal = -999999;
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < cols; c++) {
          if (animalAt[seat][r][c] > 0) continue;
          if (!canStackToken(tempStacks[r][c], tok)) continue;
          final cur = tempStacks[r][c];
          var val = 0;
          if (tok == 1 && cur.isNotEmpty && cur.last == 0) {
            val += cur.length == 2 ? 18 : 12; // complete a 2 or 3-tall tree!
          } else if (tok == 0 && cur.length == 1 && cur[0] == 0) {
            val += 8; // 2nd trunk
          } else if (tok == 2 && cur.isNotEmpty && cur.last == 2) {
            val += 10; // taller mountain
          } else if (tok == 3 && cur.length == 1) {
            val += 11; // 2-tall building
          }
          for (final (nr, nc) in orthoNeighbors(r, c)) {
            final nst = tempStacks[nr][nc];
            if (nst.isNotEmpty && nst.last == tok) {
              if (tok == 4 || tok == 5 || tok == 2) val += 7;
            }
          }
          // Check animal card synergy
          for (final a in playerAnimals[seat]) {
            if (a.cubesLeft <= 0) continue;
            if (a.anchorToken == tok && cur.length + 1 == a.anchorHeight) {
              val += 14;
            }
            if (a.adjToken == tok && cur.length + 1 >= a.adjMinHeight) {
              val += 6;
            }
          }
          if (val > bestVal) {
            bestVal = val;
            bestCell = (r, c);
          }
        }
      }
      if (bestCell == null) {
        chosen.add((-1, -1));
      } else {
        tempStacks[bestCell.$1][bestCell.$2].add(tok);
        chosen.add(bestCell);
      }
    }
    return chosen;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'draft':
        final p = asInt(action['pouch'], -1);
        if (p < 0 || p >= pouches.length) {
          throw GameError('无效的指示物袋编号');
        }
        final tokens = pouches[p];
        final rawCells = action['cells'];
        if (rawCells is! List || rawCells.length != 3) {
          throw GameError('需要指定 3 个放置格子');
        }

        // Validate sequentially on a temporary copy first
        final tempStacks = [
          for (var r = 0; r < rows; r++)
            [
              for (var c = 0; c < cols; c++) List<int>.of(stacks[seat][r][c]),
            ],
        ];
        final coords = <(int, int)>[];
        for (var i = 0; i < 3; i++) {
          final item = rawCells[i];
          if (item is! List || item.length < 2) {
            throw GameError('坐标格式无效');
          }
          final r = asInt(item[0], -1);
          final c = asInt(item[1], -1);
          final tok = tokens[i];
          if (r == -1 && c == -1) {
            // Allowed only if no legal cell exists for tok
            var anyLegal = false;
            for (var rr = 0; rr < rows; rr++) {
              for (var cc = 0; cc < cols; cc++) {
                if (animalAt[seat][rr][cc] == 0 &&
                    canStackToken(tempStacks[rr][cc], tok)) {
                  anyLegal = true;
                  break;
                }
              }
            }
            if (anyLegal) {
              throw GameError('棋盘仍有合法位置可放置${harmoniesTokenNames[tok]}');
            }
            coords.add((-1, -1));
          } else {
            if (r < 0 || r >= rows || c < 0 || c >= cols) {
              throw GameError('坐标越界');
            }
            if (animalAt[seat][r][c] > 0) {
              throw GameError('已有动物方块的格子不能继续叠放指示物');
            }
            if (!canStackToken(tempStacks[r][c], tok)) {
              throw GameError(
                  '无法在 ($r,$c) 叠放 ${harmoniesTokenEmojis[tok]}${harmoniesTokenNames[tok]}');
            }
            tempStacks[r][c].add(tok);
            coords.add((r, c));
          }
        }

        // Optional animal claim
        final claimIdx = asInt(action['claimAnimal'], -1);
        HarmoniesAnimalCard? claimedCard;
        if (claimIdx >= 0) {
          if (claimIdx >= animalMarket.length) {
            throw GameError('无效的动物卡编号');
          }
          final activeAnimals =
              playerAnimals[seat].where((a) => a.cubesLeft > 0).length;
          if (activeAnimals >= maxPersonalAnimals) {
            throw GameError('未完成的个人动物卡已达上限 ($maxPersonalAnimals 张)');
          }
          claimedCard = animalMarket.removeAt(claimIdx);
          playerAnimals[seat].add(claimedCard);
          if (animalDeck.isNotEmpty) {
            animalMarket.add(animalDeck.removeLast());
          }
        }

        // Commit stacks
        for (var i = 0; i < 3; i++) {
          final (r, c) = coords[i];
          if (r >= 0 && c >= 0) {
            stacks[seat][r][c].add(tokens[i]);
          }
        }
        pouches[p] = _drawPouch();

        final placedCubes = autoPlaceAnimals(seat);
        score[seat] = calcScore(seat);
        final tokStr = tokens.map((t) => harmoniesTokenEmojis[t]).join('');
        final claimStr =
            claimedCard != null ? '，领养${claimedCard.emoji}${claimedCard.name}' : '';
        final cubeStr = placedCubes > 0 ? '，栖息+$placedCubes只动物！' : '';
        lastAction = '${name(seat)} 选取指示物[$tokStr]$claimStr$cubeStr';
        host.log(lastAction);
        _advanceTurn();

      case 'place_animal':
        final cardIdx = asInt(action['cardIdx'], -1);
        final r = asInt(action['r'], -1);
        final c = asInt(action['c'], -1);
        if (cardIdx < 0 || cardIdx >= playerAnimals[seat].length) {
          throw GameError('无效的个人动物卡编号');
        }
        final card = playerAnimals[seat][cardIdx];
        if (card.cubesLeft <= 0) {
          throw GameError('该动物卡上的动物方块已全部放置');
        }
        if (!matchesAnimalPattern(seat, card, r, c)) {
          throw GameError('该位置不满足 ${card.name} 的栖息地地形要求');
        }
        animalAt[seat][r][c] = card.id;
        playerAnimals[seat][cardIdx] =
            card.copyWith(cubesPlaced: card.cubesPlaced + 1);
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 在 ($r,$c) 安置了 ${card.emoji}${card.name}';
        host.log(lastAction);

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    if (turn + 1 < players) {
      turn++;
      return;
    }
    turn = 0;
    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '森灵合鸣终局结算完成！总分最高者获胜';
      host.log(lastAction);
      return;
    }
    round++;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    var bestPouch = 0;
    List<(int, int)>? bestCells;
    var bestScore = -999999;

    for (var p = 0; p < pouches.length; p++) {
      final cells = findPlacementForPouch(seat, pouches[p]);
      if (cells == null) continue;
      final nonSkipped = cells.where((e) => e.$1 >= 0).length;
      final sc = nonSkipped * 10 + p;
      if (sc > bestScore) {
        bestScore = sc;
        bestPouch = p;
        bestCells = cells;
      }
    }

    bestCells ??= [(-1, -1), (-1, -1), (-1, -1)];
    var claimIdx = -1;
    final activeAnimals =
        playerAnimals[seat].where((a) => a.cubesLeft > 0).length;
    if (activeAnimals < maxPersonalAnimals && animalMarket.isNotEmpty) {
      claimIdx = 0;
    }

    return {
      'type': 'draft',
      'pouch': bestPouch,
      'claimAnimal': claimIdx,
      'cells': [
        for (final (r, c) in bestCells) [r, c],
      ],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final suggestedByPouch = <List<List<int>>>[];
    if (!over && seat >= 0 && seat < players) {
      for (final pouch in pouches) {
        final pl = findPlacementForPouch(seat, pouch) ??
            const [(-1, -1), (-1, -1), (-1, -1)];
        suggestedByPouch.add([
          for (final (r, c) in pl) [r, c],
        ]);
      }
    }

    return {
      'rows': rows,
      'cols': cols,
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'pouches': [for (final p in pouches) List<int>.of(p)],
      'animalMarket': [for (final a in animalMarket) a.toJson()],
      'suggestedByPouch': suggestedByPouch,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'treeVp': calcTreeScore(s),
            'mountainVp': calcMountainScore(s),
            'fieldVp': calcFieldScore(s),
            'buildingVp': calcBuildingScore(s),
            'riverVp': calcRiverScore(s),
            'animalVp': calcAnimalScore(s),
            'animals': [for (final a in playerAnimals[s]) a.toJson()],
            'stacks': [
              for (var r = 0; r < rows; r++)
                [
                  for (var c = 0; c < cols; c++) List<int>.of(stacks[s][r][c]),
                ],
            ],
            'animalAt': [
              for (var r = 0; r < rows; r++) List<int>.of(animalAt[s][r]),
            ],
          },
      ],
    };
  }
}
