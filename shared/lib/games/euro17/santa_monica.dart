import '../../src/engine.dart';

const List<String> santaMonicaRowNames = ['海滩排', '街区排'];
const List<String> santaMonicaRowEmojis = ['🏖️', '🛣️'];

const List<String> santaMonicaTagNames = ['冲浪湾', '游乐栈桥', '棕榈步道', '商业街'];
const List<String> santaMonicaTagEmojis = ['🏄', '🎡', '🌴', '🛍️'];

class SantaMonicaCard {
  final int id;
  final String name;
  final String emoji;
  final int rowType; // 0: 🏖️ Beach, 1: 🛣️ Street
  final int featureTag; // 0..3
  final int gainShells; // 🐚 gained when drafted
  final int spawnVip; // 🕶️ VIP spawned when drafted
  final int spawnTourists; // 📸 Tourists spawned when drafted
  final int ringCap; // 1..2 capacity of Activity Ring ⭕
  final int ringFilled; // current meeples in Activity Ring
  final int ringVp; // 2..5 VP when Activity Ring is filled
  final int adjTag; // -1 or 0..3 matching featureTag for adjacency bonus
  final int adjVp; // +1..2 VP per adjacent card with featureTag == adjTag

  const SantaMonicaCard({
    required this.id,
    required this.name,
    required this.emoji,
    required this.rowType,
    required this.featureTag,
    this.gainShells = 0,
    this.spawnVip = 0,
    this.spawnTourists = 0,
    required this.ringCap,
    this.ringFilled = 0,
    required this.ringVp,
    this.adjTag = -1,
    this.adjVp = 0,
  });

  bool get ringDone => ringCap > 0 && ringFilled >= ringCap;

  SantaMonicaCard copyWith({int? ringFilled}) => SantaMonicaCard(
        id: id,
        name: name,
        emoji: emoji,
        rowType: rowType,
        featureTag: featureTag,
        gainShells: gainShells,
        spawnVip: spawnVip,
        spawnTourists: spawnTourists,
        ringCap: ringCap,
        ringFilled: ringFilled ?? this.ringFilled,
        ringVp: ringVp,
        adjTag: adjTag,
        adjVp: adjVp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'rowType': rowType,
        'rowName': santaMonicaRowNames[rowType],
        'rowEmoji': santaMonicaRowEmojis[rowType],
        'featureTag': featureTag,
        'tagName': santaMonicaTagNames[featureTag],
        'tagEmoji': santaMonicaTagEmojis[featureTag],
        'gainShells': gainShells,
        'spawnVip': spawnVip,
        'spawnTourists': spawnTourists,
        'ringCap': ringCap,
        'ringFilled': ringFilled,
        'ringDone': ringDone,
        'ringVp': ringVp,
        'adjTag': adjTag,
        'adjTagEmoji': adjTag >= 0 ? santaMonicaTagEmojis[adjTag] : '',
        'adjVp': adjVp,
      };
}

class SantaMonicaGame extends GameEngine {
  static const int tableauRows = 2;
  static const int tableauCols = 6;
  static const int displayRows = 2;
  static const int displayCols = 4;

  static const List<(int, int)> dirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  late final int maxDrafts;
  late List<SantaMonicaCard> deck;

  /// Central Display: `display[0][0..3]` (Top Row), `display[1][0..3]` (Bottom Row).
  late List<List<SantaMonicaCard?>> display;

  /// Each player's 2x6 Coastal Tableau (`tableau[seat][row][col]`).
  /// Row 0: 🏖️ Beach, Row 1: 🛣️ Street.
  late List<List<List<SantaMonicaCard?>>> tableau;
  late List<int> shells; // 🐚 Sand Dollars
  late List<int> vipPool; // 🕶️ Available VIPs to move into rings
  late List<int> touristPool; // 📸 Available Tourists to move into rings
  late List<int> draftedCount;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '圣莫尼卡海滩度假规划开启';

  SantaMonicaGame(super.setup) : maxDrafts = setup.opt<int>('drafts', 8);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<SantaMonicaCard> _buildDeck() {
    const templates = [
      // Row 0: 🏖️ Beach cards
      ('太平洋摩天轮', '🎡', 0, 1, 1, 1, 0, 1, 4, 1, 2),
      ('黄金冲浪滩', '🏄', 0, 0, 2, 0, 1, 1, 3, 0, 1),
      ('阳光排球场', '🏐', 0, 0, 1, 0, 2, 2, 5, 2, 1),
      ('海滨救生塔', '🛟', 0, 0, 2, 1, 0, 1, 3, 0, 2),
      ('栈桥过山车', '🎢', 0, 1, 0, 1, 1, 2, 5, 1, 2),
      ('落日遮阳伞', '⛱️', 0, 2, 2, 0, 1, 1, 3, 3, 1),
      ('潮汐贝壳湾', '🐚', 0, 0, 3, 0, 0, 1, 2, 0, 1),
      ('海鸥观景台', '🕊️', 0, 1, 1, 1, 0, 1, 4, 2, 2),
      ('滑板冲浪区', '🛹', 0, 2, 1, 0, 2, 2, 4, 2, 1),
      ('海滩瑜伽垫', '🧘', 0, 2, 2, 1, 0, 1, 3, 3, 1),
      // Row 1: 🛣️ Street cards
      ('第三街步行廊', '🛍️', 1, 3, 2, 1, 0, 1, 4, 3, 2),
      ('复古街机厅', '🕹️', 1, 1, 1, 0, 2, 2, 5, 1, 2),
      ('棕榈冰沙车', '🥤', 1, 2, 2, 0, 1, 1, 3, 0, 1),
      ('海风精品店', '👗', 1, 3, 1, 1, 1, 2, 5, 3, 1),
      ('街头艺舞台', '🎸', 1, 2, 2, 1, 0, 1, 3, 2, 2),
      ('威尼斯轮滑道', '🛼', 1, 2, 1, 0, 2, 2, 4, 0, 1),
      ('海岸タコ餐车', '🌮', 1, 3, 2, 0, 1, 1, 3, 1, 1),
      ('日落棕榈大道', '🌴', 1, 2, 3, 0, 0, 1, 2, 2, 2),
      ('星光纪念品店', '🕶️', 1, 3, 1, 1, 1, 1, 4, 3, 1),
      ('冲浪板租借屋', '🏪', 1, 0, 2, 0, 1, 1, 3, 0, 2),
    ];
    var id = 1;
    final out = <SantaMonicaCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, rt, tag, sh, vip, tour, rCap, rVp, aTag, aVp)
          in templates) {
        out.add(SantaMonicaCard(
          id: id++,
          name: nm,
          emoji: em,
          rowType: rt,
          featureTag: tag,
          gainShells: sh,
          spawnVip: vip,
          spawnTourists: tour,
          ringCap: rCap,
          ringVp: rVp,
          adjTag: aTag,
          adjVp: aVp,
        ));
      }
    }
    return shuffled(out, rng);
  }

  SantaMonicaCard _drawCard() {
    if (deck.isEmpty) deck = _buildDeck();
    return deck.removeLast();
  }

  @override
  void start() {
    deck = _buildDeck();
    display = List.generate(
      displayRows,
      (_) => List.generate(displayCols, (_) => _drawCard()),
    );

    tableau = List.generate(
      players,
      (_) => List.generate(
        tableauRows,
        (_) => List.filled(tableauCols, null),
      ),
    );
    shells = List.filled(players, 2);
    vipPool = List.filled(players, 1);
    touristPool = List.filled(players, 1);
    draftedCount = List.filled(players, 0);
    score = List.filled(players, 0);

    // Give each player 1 starting Beach card at (0, 0) and 1 starting Street card at (1, 0)
    for (var s = 0; s < players; s++) {
      tableau[s][0][0] = SantaMonicaCard(
        id: 900 + s * 2,
        name: '初始海滩入口',
        emoji: '🏖️',
        rowType: 0,
        featureTag: 0,
        gainShells: 1,
        spawnVip: 1,
        ringCap: 1,
        ringVp: 3,
        adjTag: 1,
        adjVp: 1,
      );
      tableau[s][1][0] = SantaMonicaCard(
        id: 901 + s * 2,
        name: '初始街区广场',
        emoji: '🛣️',
        rowType: 1,
        featureTag: 2,
        gainShells: 1,
        spawnTourists: 1,
        ringCap: 1,
        ringVp: 3,
        adjTag: 3,
        adjVp: 1,
      );
      score[s] = calcScore(s);
    }

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，请从底层展示排拿取海滩/街区卡，或消耗沙币移动游客完成活动环';
  }

  int calcRingVp(int seat) {
    var pts = 0;
    for (var r = 0; r < tableauRows; r++) {
      for (var c = 0; c < tableauCols; c++) {
        final card = tableau[seat][r][c];
        if (card != null && card.ringDone) {
          pts += card.ringVp;
        }
      }
    }
    return pts;
  }

  int calcChainVp(int seat) {
    // +2 VP for each column where both Row 0 (Beach) and Row 1 (Street) are built!
    var pts = 0;
    for (var c = 0; c < tableauCols; c++) {
      if (tableau[seat][0][c] != null && tableau[seat][1][c] != null) {
        pts += 2;
      }
    }
    return pts;
  }

  int calcAdjBonusVp(int seat) {
    var pts = 0;
    for (var r = 0; r < tableauRows; r++) {
      for (var c = 0; c < tableauCols; c++) {
        final card = tableau[seat][r][c];
        if (card == null || card.adjTag < 0 || card.adjVp <= 0) continue;
        for (final (dr, dc) in dirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr < 0 || nr >= tableauRows || nc < 0 || nc >= tableauCols) {
            continue;
          }
          final adj = tableau[seat][nr][nc];
          if (adj != null && adj.featureTag == card.adjTag) {
            pts += card.adjVp;
          }
        }
      }
    }
    return pts;
  }

  int calcScore(int seat) =>
      calcRingVp(seat) +
      calcChainVp(seat) +
      calcAdjBonusVp(seat) +
      (shells[seat] ~/ 2);

  /// Finds the target row (`0` or `1`) and empty column `slotC` for placing `card`.
  (int, int)? resolvePlacement(int seat, SantaMonicaCard card, int reqSlotC) {
    final prefRow = card.rowType;
    final altRow = 1 - prefRow;

    if (reqSlotC >= 0 && reqSlotC < tableauCols) {
      if (tableau[seat][prefRow][reqSlotC] == null) {
        return (prefRow, reqSlotC);
      }
      // If preferred row is completely full, allow placing in altRow at reqSlotC
      final prefHasEmpty =
          tableau[seat][prefRow].any((cell) => cell == null);
      if (!prefHasEmpty && tableau[seat][altRow][reqSlotC] == null) {
        return (altRow, reqSlotC);
      }
      return null;
    }

    for (var c = 0; c < tableauCols; c++) {
      if (tableau[seat][prefRow][c] == null) return (prefRow, c);
    }
    for (var c = 0; c < tableauCols; c++) {
      if (tableau[seat][altRow][c] == null) return (altRow, c);
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'spend_shell':
        final mode = asStr(action['mode'], 'move');
        if (mode == 'top_draft') {
          if (shells[seat] < 2) {
            throw GameError('从顶层展示排破例拿牌需要消耗 2 枚沙币 (🐚)');
          }
          final col = asInt(action['col'], -1);
          final slotC = asInt(action['slotC'], -1);
          _executeDraft(seat, row: 0, col: col, slotC: slotC, shellCost: 2);
          return;
        }

        // Default mode: spend 1 🐚 Sand Dollar to move VIP / Tourist into an Activity Ring (⭕)
        if (shells[seat] < 1) {
          throw GameError('沙币 (🐚) 不足，需要至少 1 枚沙币');
        }
        if (vipPool[seat] + touristPool[seat] <= 0) {
          throw GameError('当前没有可移动的 VIP (🕶️) 或游客 (📸)');
        }
        final reqR = asInt(action['r'], asInt(action['toR'], -1));
        final reqC = asInt(action['c'], asInt(action['toC'], -1));

        int targetR = -1;
        int targetC = -1;
        if (reqR >= 0 &&
            reqR < tableauRows &&
            reqC >= 0 &&
            reqC < tableauCols) {
          final cand = tableau[seat][reqR][reqC];
          if (cand == null) {
            throw GameError('位置 ($reqR, $reqC) 没有卡牌');
          }
          if (cand.ringDone) {
            throw GameError('该卡牌的活动环 (⭕) 已满');
          }
          targetR = reqR;
          targetC = reqC;
        } else {
          // Auto-select highest-VP unfilled Activity Ring
          var bestVp = -1;
          for (var r = 0; r < tableauRows; r++) {
            for (var c = 0; c < tableauCols; c++) {
              final cand = tableau[seat][r][c];
              if (cand != null && !cand.ringDone && cand.ringVp > bestVp) {
                bestVp = cand.ringVp;
                targetR = r;
                targetC = c;
              }
            }
          }
          if (targetR < 0) {
            throw GameError('当前版图没有未完成的活动环 (⭕)');
          }
        }

        shells[seat] -= 1;
        String meepleStr;
        if (vipPool[seat] > 0) {
          vipPool[seat]--;
          meepleStr = '🕶️VIP';
        } else {
          touristPool[seat]--;
          meepleStr = '📸游客';
        }

        final oldCard = tableau[seat][targetR][targetC]!;
        final updated = oldCard.copyWith(ringFilled: oldCard.ringFilled + 1);
        tableau[seat][targetR][targetC] = updated;
        score[seat] = calcScore(seat);

        final doneStr =
            updated.ringDone ? '，完成⭕活动环获得 +${updated.ringVp}分！' : '';
        lastAction =
            '${name(seat)} 消耗 1🐚 将 $meepleStr 移入 ${updated.emoji}${updated.name} (${updated.ringFilled}/${updated.ringCap})$doneStr';
        host.log(lastAction);

      case 'draft':
        final row = asInt(action['row'], 1);
        final col = asInt(action['col'], -1);
        final slotC = asInt(action['slotC'], -1);
        if (row == 0) {
          if (shells[seat] < 2) {
            throw GameError('从顶层展示排拿牌需要消耗 2 枚沙币 (🐚)');
          }
          _executeDraft(seat, row: 0, col: col, slotC: slotC, shellCost: 2);
        } else {
          _executeDraft(seat, row: 1, col: col, slotC: slotC, shellCost: 0);
        }

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _executeDraft(
    int seat, {
    required int row,
    required int col,
    required int slotC,
    required int shellCost,
  }) {
    if (col < 0 || col >= displayCols) {
      throw GameError('无效的展示列编号: $col');
    }
    final card = display[row][col];
    if (card == null) {
      throw GameError('该展示位已无卡牌');
    }
    final pos = resolvePlacement(seat, card, slotC);
    if (pos == null) {
      throw GameError('无法将该卡牌放置到版图列 $slotC（该位置已有卡牌）');
    }

    shells[seat] -= shellCost;
    final (placedR, placedC) = pos;
    tableau[seat][placedR][placedC] = card;

    // Apply immediate card effects
    shells[seat] += card.gainShells;
    vipPool[seat] += card.spawnVip;
    touristPool[seat] += card.spawnTourists;

    // Refill display: if drafted from bottom row (1), top row (0) slides down to bottom row (1)
    if (row == 1) {
      display[1][col] = display[0][col];
      display[0][col] = _drawCard();
    } else {
      display[0][col] = _drawCard();
    }

    draftedCount[seat]++;
    score[seat] = calcScore(seat);
    lastAction =
        '${name(seat)} 拿取 ${card.emoji}${card.name} 放入${santaMonicaRowNames[placedR]}第${placedC + 1}列 (+${card.gainShells}🐚)';
    host.log(lastAction);
    _advanceTurn();
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (draftedCount[nextSeat] < maxDrafts) {
        turn = nextSeat;
        round = draftedCount[turn] + 1;
        return;
      }
    }
    over = true;
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
    lastAction = '圣莫尼卡海滩终局结算完成！总分最高者获胜';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Spend Sand Dollars to fill Activity Rings if possible!
    if (shells[seat] >= 1 && (vipPool[seat] + touristPool[seat]) > 0) {
      for (var r = 0; r < tableauRows; r++) {
        for (var c = 0; c < tableauCols; c++) {
          final card = tableau[seat][r][c];
          if (card != null && !card.ringDone) {
            return {'type': 'spend_shell', 'r': r, 'c': c};
          }
        }
      }
    }

    // 2. Draft the best card from Bottom Row (display[1][col])
    int bestCol = 0;
    int bestSlotC = 0;
    int bestVal = -999999;

    for (var col = 0; col < displayCols; col++) {
      final card = display[1][col];
      if (card == null) continue;
      for (var sc = 0; sc < tableauCols; sc++) {
        final pos = resolvePlacement(seat, card, sc);
        if (pos == null) continue;
        final (pr, pc) = pos;
        var adjBonus = 0;
        for (final (dr, dc) in dirs) {
          final nr = pr + dr;
          final nc = pc + dc;
          if (nr < 0 || nr >= tableauRows || nc < 0 || nc >= tableauCols) {
            continue;
          }
          final neighbor = tableau[seat][nr][nc];
          if (neighbor == null) continue;
          if (card.adjTag == neighbor.featureTag) adjBonus += card.adjVp;
          if (neighbor.adjTag == card.featureTag) adjBonus += neighbor.adjVp;
        }
        final chainBonus = (tableau[seat][1 - pr][pc] != null) ? 2 : 0;
        final val = card.ringVp * 2 +
            card.gainShells * 3 +
            (card.spawnVip + card.spawnTourists) * 4 +
            adjBonus * 5 +
            chainBonus * 4;
        if (val > bestVal) {
          bestVal = val;
          bestCol = col;
          bestSlotC = pc;
        }
      }
    }

    return {
      'type': 'draft',
      'col': bestCol,
      'slotC': bestSlotC,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxDrafts': maxDrafts,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'display': [
        for (var r = 0; r < displayRows; r++)
          [
            for (var c = 0; c < displayCols; c++) display[r][c]?.toJson(),
          ],
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'ringVp': calcRingVp(s),
            'chainVp': calcChainVp(s),
            'adjVp': calcAdjBonusVp(s),
            'shells': shells[s],
            'vipPool': vipPool[s],
            'touristPool': touristPool[s],
            'draftedCount': draftedCount[s],
            'tableau': [
              for (var r = 0; r < tableauRows; r++)
                [
                  for (var c = 0; c < tableauCols; c++)
                    tableau[s][r][c]?.toJson(),
                ],
            ],
          },
      ],
    };
  }
}
