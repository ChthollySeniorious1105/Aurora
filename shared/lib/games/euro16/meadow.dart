import '../../src/engine.dart';

const List<String> meadowSymbolNames = [
  '草地',
  '林木',
  '溪流',
  '昆虫',
  '两栖',
  '飞鸟',
  '走兽',
];

const List<String> meadowSymbolEmojis = [
  '🌱',
  '🌲',
  '🌊',
  '🐛',
  '🐸',
  '🐦',
  '🦊',
];

class MeadowCard {
  final int id;
  final int tier; // 0: Ground, 1: Low Nature, 2: Mid Wildlife, 3: Apex/Landscape
  final String name;
  final String emoji;
  final int provides; // 0..6 symbol provided when in Ecosystem
  final List<int> reqs; // required symbols in Ecosystem to play
  final int vp;

  const MeadowCard({
    required this.id,
    required this.tier,
    required this.name,
    required this.emoji,
    required this.provides,
    required this.reqs,
    required this.vp,
  });

  String get reqsDesc => reqs.isEmpty
      ? '无前置（基础生境）'
      : '需 ${reqs.map((s) => meadowSymbolEmojis[s]).join('+')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'tier': tier,
        'name': name,
        'emoji': emoji,
        'provides': provides,
        'providesEmoji': meadowSymbolEmojis[provides],
        'providesName': meadowSymbolNames[provides],
        'reqs': reqs,
        'reqsDesc': reqsDesc,
        'vp': vp,
      };
}

class MeadowCampfireGoal {
  final int id;
  final int symA;
  final int symB;
  final int claimedBy; // -1 if unclaimed
  final int bonusVp; // 2, 3, or 4 when claimed

  const MeadowCampfireGoal({
    required this.id,
    required this.symA,
    required this.symB,
    this.claimedBy = -1,
    this.bonusVp = 0,
  });

  MeadowCampfireGoal copyWith({int? claimedBy, int? bonusVp}) =>
      MeadowCampfireGoal(
        id: id,
        symA: symA,
        symB: symB,
        claimedBy: claimedBy ?? this.claimedBy,
        bonusVp: bonusVp ?? this.bonusVp,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'symA': symA,
        'symB': symB,
        'symAEmoji': meadowSymbolEmojis[symA],
        'symBEmoji': meadowSymbolEmojis[symB],
        'claimedBy': claimedBy,
        'bonusVp': bonusVp,
      };
}

class MeadowGame extends GameEngine {
  static const int gridSize = 4;
  static const List<int> campfireRewards = [2, 3, 4];

  late final int maxRounds;
  late List<List<MeadowCard?>> market; // 4x4 grid: row = tier 0..3
  late List<List<MeadowCard>> tierDecks; // 4 decks for rows 0..3
  late List<List<MeadowCard>> hand;
  late List<List<MeadowCard>> ecosystem;
  late List<List<int>> tokensLeft; // remaining path token depths [1, 2, 3, 4]
  late List<MeadowCampfireGoal> campfireGoals;
  late List<int> campfireVp;
  late List<int> score;

  int round = 1;
  int turn = 0;
  bool over = false;
  String lastAction = '翠屿芳原自然观察开启';

  MeadowGame(super.setup) : maxRounds = setup.opt<int>('rounds', 6);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<List<MeadowCard>> _buildTierDecks() {
    var nextId = 1;
    // Tier 0: Ground/Base habitat cards (0..1 VP, reqs: [], provides: 0, 1, 2)
    final t0Templates = [
      ('晨露芳草地', '🌱', 0, <int>[], 1),
      ('向阳野花甸', '🌼', 0, <int>[], 1),
      ('苔藓灌木丛', '🌿', 0, <int>[], 1),
      ('针叶松林带', '🌲', 1, <int>[], 1),
      ('白桦林地', '🌳', 1, <int>[], 1),
      ('枯木树桩', '🪵', 1, <int>[], 1),
      ('山涧清溪', '🌊', 2, <int>[], 1),
      ('芦苇浅滩', '🌾', 2, <int>[], 1),
      ('林间水塘', '💧', 2, <int>[], 1),
    ];
    final t0 = <MeadowCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, prov, rq, vp) in t0Templates) {
        t0.add(MeadowCard(
          id: nextId++,
          tier: 0,
          name: nm,
          emoji: em,
          provides: prov,
          reqs: rq,
          vp: vp,
        ));
      }
    }

    // Tier 1: Low-tier Nature cards (1..2 VP, reqs: 1 base symbol, provides: 3, 4, 5)
    final t1Templates = [
      ('七星瓢虫', '🐞', 3, [0], 2),
      ('凤尾彩蝶', '🦋', 3, [0], 2),
      ('林间蜜蜂', '🐝', 3, [1], 2),
      ('独角仙', '🪲', 3, [1], 2),
      ('蓝光豆娘', '🦟', 3, [2], 2),
      ('雨林树蛙', '🐸', 4, [2], 2),
      ('溪流火蝾螈', '🦎', 4, [2], 2),
      ('草地蟾蜍', '🐸', 4, [0], 1),
      ('林间知更鸟', '🐦', 5, [1], 2),
      ('草甸云雀', '🐤', 5, [0], 2),
    ];
    final t1 = <MeadowCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, prov, rq, vp) in t1Templates) {
        t1.add(MeadowCard(
          id: nextId++,
          tier: 1,
          name: nm,
          emoji: em,
          provides: prov,
          reqs: rq,
          vp: vp,
        ));
      }
    }

    // Tier 2: Mid-tier Wildlife cards (2..3 VP, reqs: 1..2 symbols, provides: 4, 5, 6)
    final t2Templates = [
      ('翠鸟捕鱼', '🐦', 5, [2, 3], 3),
      ('斑点啄木鸟', '🪶', 5, [1, 3], 3),
      ('红尾伯劳', '🦅', 5, [0, 3], 3),
      ('池塘白鹳', '🦩', 5, [2, 4], 3),
      ('刺猬寻虫', '🦔', 6, [0, 3], 3),
      ('林间赤松鼠', '🐿️', 6, [1, 0], 2),
      ('欧亚河狸', '🦫', 6, [1, 2], 3),
      ('金线蛙王', '🐸', 4, [2, 3], 3),
      ('田野小鼹鼠', '🐭', 6, [0, 3], 2),
    ];
    final t2 = <MeadowCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, prov, rq, vp) in t2Templates) {
        t2.add(MeadowCard(
          id: nextId++,
          tier: 2,
          name: nm,
          emoji: em,
          provides: prov,
          reqs: rq,
          vp: vp,
        ));
      }
    }

    // Tier 3: Apex/Landscape cards (3..4 VP, reqs: 2 symbols, provides: 5, 6)
    final t3Templates = [
      ('丛林赤狐', '🦊', 6, [0, 5], 4),
      ('山谷苍狼', '🐺', 6, [1, 6], 4),
      ('高空金雕', '🦅', 5, [5, 4], 4),
      ('极夜雪鸮', '🦉', 5, [1, 5], 4),
      ('梅花雄鹿', '🦌', 6, [0, 1], 3),
      ('溪谷水獭', '🦦', 6, [2, 4], 4),
      ('松林棕熊', '🐻', 6, [1, 3], 4),
      ('欧洲獾王', '🦡', 6, [3, 4], 4),
    ];
    final t3 = <MeadowCard>[];
    for (var copy = 0; copy < 4; copy++) {
      for (final (nm, em, prov, rq, vp) in t3Templates) {
        t3.add(MeadowCard(
          id: nextId++,
          tier: 3,
          name: nm,
          emoji: em,
          provides: prov,
          reqs: rq,
          vp: vp,
        ));
      }
    }

    return [
      shuffled(t0, rng),
      shuffled(t1, rng),
      shuffled(t2, rng),
      shuffled(t3, rng),
    ];
  }

  MeadowCard? _drawFromTier(int r) {
    if (tierDecks[r].isNotEmpty) {
      return tierDecks[r].removeLast();
    }
    for (var alt = 0; alt < gridSize; alt++) {
      if (tierDecks[alt].isNotEmpty) {
        return tierDecks[alt].removeLast();
      }
    }
    return null;
  }

  @override
  void start() {
    tierDecks = _buildTierDecks();
    market = List.generate(
      gridSize,
      (r) => List.generate(gridSize, (_) => _drawFromTier(r)),
    );

    hand = List.generate(players, (_) => <MeadowCard>[]);
    ecosystem = List.generate(players, (_) => <MeadowCard>[]);
    tokensLeft = List.generate(players, (_) => [1, 2, 3, 4]);
    campfireVp = List.filled(players, 0);
    score = List.filled(players, 0);

    // Give each player 1 starting Ground habitat in Ecosystem + 2 cards in hand
    for (var s = 0; s < players; s++) {
      final startGround = _drawFromTier(0);
      if (startGround != null) {
        ecosystem[s].add(startGround);
      }
      final h0 = _drawFromTier(0);
      final h1 = _drawFromTier(1);
      if (h0 != null) hand[s].add(h0);
      if (h1 != null) hand[s].add(h1);
      score[s] = calcScore(s);
    }

    campfireGoals = [
      const MeadowCampfireGoal(id: 0, symA: 0, symB: 3), // 🌱 + 🐛
      const MeadowCampfireGoal(id: 1, symA: 1, symB: 5), // 🌲 + 🐦
      const MeadowCampfireGoal(id: 2, symA: 2, symB: 4), // 🌊 + 🐸
      const MeadowCampfireGoal(id: 3, symA: 5, symB: 6), // 🐦 + 🦊
    ];

    round = 1;
    turn = 0;
    over = false;
    lastAction = '第 1 轮开始，请插入路径标指示物拿取卡牌并构筑生态圈';
  }

  /// Counts how many of each symbol 0..6 are currently present in [seat]'s ecosystem.
  List<int> symbolCounts(int seat) {
    final counts = List.filled(7, 0);
    for (final c in ecosystem[seat]) {
      counts[c.provides]++;
    }
    return counts;
  }

  /// Checks if [seat]'s Ecosystem currently displays all prerequisite symbols in [card.reqs].
  bool canPlayCard(int seat, MeadowCard card) {
    final counts = symbolCounts(seat);
    final needed = List.filled(7, 0);
    for (final req in card.reqs) {
      needed[req]++;
      if (counts[req] < needed[req]) return false;
    }
    return true;
  }

  /// Checks if [seat] can draft `market[r][c]` using one of their remaining Path Tokens.
  /// Returns the matching token depth `d in 1..4`, or -1 if none matches.
  int matchingTokenDepth(int seat, int r, int c, [int preferredDepth = -1]) {
    final rem = tokensLeft[seat];
    if (rem.isEmpty) return -1;
    if (preferredDepth > 0) {
      if (!rem.contains(preferredDepth)) return -1;
      if (preferredDepth == r + 1 || preferredDepth == c + 1) {
        return preferredDepth;
      }
      return -1;
    }
    if (rem.contains(r + 1)) return r + 1;
    if (rem.contains(c + 1)) return c + 1;
    return -1;
  }

  /// Checks if [seat] can claim `campfireGoals[goalIdx]`.
  bool canClaimGoal(int seat, int goalIdx) {
    if (goalIdx < 0 || goalIdx >= campfireGoals.length) return false;
    final g = campfireGoals[goalIdx];
    if (g.claimedBy != -1) return false;
    // A player cannot claim more than 3 campfire goals
    final myClaimed =
        campfireGoals.where((goal) => goal.claimedBy == seat).length;
    if (myClaimed >= campfireRewards.length) return false;
    final counts = symbolCounts(seat);
    if (g.symA == g.symB) {
      return counts[g.symA] >= 2;
    }
    return counts[g.symA] >= 1 && counts[g.symB] >= 1;
  }

  int nextCampfireReward(int seat) {
    final myClaimed =
        campfireGoals.where((goal) => goal.claimedBy == seat).length;
    return campfireRewards[myClaimed.clamp(0, campfireRewards.length - 1)];
  }

  int calcEcosystemVp(int seat) {
    var pts = 0;
    for (final c in ecosystem[seat]) {
      pts += c.vp;
    }
    return pts;
  }

  int calcScore(int seat) => calcEcosystemVp(seat) + campfireVp[seat];

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');
    if (tokensLeft[seat].isEmpty) throw GameError('本轮路径标已用完');

    final type = asStr(action['type']);
    switch (type) {
      case 'draft_play':
        final r = asInt(action['row'], -1);
        final c = asInt(action['col'], -1);
        if (r < 0 || r >= gridSize || c < 0 || c >= gridSize) {
          throw GameError('无效的市场行列坐标 ($r, $c)');
        }
        final card = market[r][c];
        if (card == null) {
          throw GameError('该市场格已无卡牌');
        }
        final reqDepth = asInt(action['depth'], -1);
        final usedDepth = matchingTokenDepth(seat, r, c, reqDepth);
        if (usedDepth < 0) {
          throw GameError(
              '没有深度为 ${r + 1} 或 ${c + 1} 的可用路径标来拿取 ($r, $c)');
        }

        // Validate optional playCard before mutating state
        final playIdx = asInt(action['playCard'], -1);
        final tempHand = [...hand[seat], card];
        MeadowCard? playedCard;
        if (playIdx >= 0) {
          if (playIdx >= tempHand.length) {
            throw GameError('无效的打出卡牌编号');
          }
          final candidate = tempHand[playIdx];
          if (!canPlayCard(seat, candidate)) {
            throw GameError(
                '生态圈缺少打出 ${candidate.name} 所需的符号 (${candidate.reqsDesc})');
          }
          playedCard = candidate;
        }

        // Commit token & draft
        tokensLeft[seat].remove(usedDepth);
        hand[seat].add(card);
        market[r][c] = _drawFromTier(r);

        // Commit playCard if chosen
        if (playedCard != null) {
          hand[seat].removeAt(playIdx);
          ecosystem[seat].add(playedCard);
        }

        score[seat] = calcScore(seat);
        final playStr = playedCard != null
            ? '，并打出 ${playedCard.emoji}${playedCard.name} (+${playedCard.vp}分)'
            : '';
        lastAction =
            '${name(seat)} 放置深度$usedDepth路径标拿取 ${card.emoji}${card.name}$playStr';
        host.log(lastAction);
        _advanceTurn();

      case 'campfire':
        final gIdx = asInt(action['goalIdx'], -1);
        if (!canClaimGoal(seat, gIdx)) {
          throw GameError('当前未满足该营火目标的生态符号对或已被达成');
        }
        final reward = nextCampfireReward(seat);
        final usedDepth = tokensLeft[seat].removeLast();
        final g = campfireGoals[gIdx];
        campfireGoals[gIdx] = g.copyWith(claimedBy: seat, bonusVp: reward);
        campfireVp[seat] += reward;

        // Optional card play
        final playIdx = asInt(action['playCard'], -1);
        String playStr = '';
        if (playIdx >= 0 && playIdx < hand[seat].length) {
          final candidate = hand[seat][playIdx];
          if (!canPlayCard(seat, candidate)) {
            throw GameError(
                '生态圈缺少打出 ${candidate.name} 所需的符号 (${candidate.reqsDesc})');
          }
          hand[seat].removeAt(playIdx);
          ecosystem[seat].add(candidate);
          playStr = '，并打出 ${candidate.emoji}${candidate.name}';
        }

        score[seat] = calcScore(seat);
        lastAction =
            '${name(seat)} 放置深度$usedDepth路径标造访营火达成 [${meadowSymbolEmojis[g.symA]}+${meadowSymbolEmojis[g.symB]}] 目标 (+$reward分)$playStr';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (tokensLeft[nextSeat].isNotEmpty) {
        turn = nextSeat;
        return;
      }
    }

    // All players used all 4 path tokens this round
    if (round >= maxRounds) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '翠屿芳原终局结算完成！自然观察总分最高者获胜';
      host.log(lastAction);
      return;
    }

    round++;
    for (var s = 0; s < players; s++) {
      tokensLeft[s] = [1, 2, 3, 4];
    }
    turn = (round - 1) % players;
    lastAction = '第 $round 轮开始，路径标已全部回收';
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    // 1. Check if we can claim a Campfire Goal!
    for (var g = 0; g < campfireGoals.length; g++) {
      if (canClaimGoal(seat, g)) {
        var bestPlay = -1;
        var bestVp = -1;
        for (var i = 0; i < hand[seat].length; i++) {
          final c = hand[seat][i];
          if (canPlayCard(seat, c) && c.vp > bestVp) {
            bestVp = c.vp;
            bestPlay = i;
          }
        }
        return {
          'type': 'campfire',
          'goalIdx': g,
          'playCard': bestPlay,
        };
      }
    }

    // 2. Otherwise pick the best market cell reachable with remaining path tokens
    var bestR = -1;
    var bestC = -1;
    var bestPlayIdx = -1;
    var bestVal = -999999;

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final mCard = market[r][c];
        if (mCard == null) continue;
        final d = matchingTokenDepth(seat, r, c);
        if (d < 0) continue;

        final tempHand = [...hand[seat], mCard];
        var chosenPlay = -1;
        var playVal = 0;
        for (var i = 0; i < tempHand.length; i++) {
          final cand = tempHand[i];
          if (canPlayCard(seat, cand)) {
            final v = cand.vp * 10 + cand.tier * 3;
            if (v > playVal) {
              playVal = v;
              chosenPlay = i;
            }
          }
        }

        final draftVal = canPlayCard(seat, mCard) ? mCard.vp * 4 : mCard.tier;
        final totalVal = playVal + draftVal;
        if (totalVal > bestVal) {
          bestVal = totalVal;
          bestR = r;
          bestC = c;
          bestPlayIdx = chosenPlay;
        }
      }
    }

    if (bestR >= 0 && bestC >= 0) {
      return {
        'type': 'draft_play',
        'row': bestR,
        'col': bestC,
        'playCard': bestPlayIdx,
      };
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'market': [
        for (var r = 0; r < gridSize; r++)
          [
            for (var c = 0; c < gridSize; c++) market[r][c]?.toJson(),
          ],
      ],
      'campfireGoals': [for (final g in campfireGoals) g.toJson()],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'ecosystemVp': calcEcosystemVp(s),
            'campfireVp': campfireVp[s],
            'tokensLeft': List<int>.of(tokensLeft[s]),
            'symbolCounts': symbolCounts(s),
            'handCount': hand[s].length,
            'hand': (s == seat || seat < 0 || over)
                ? [for (final c in hand[s]) c.toJson()]
                : const [],
            'ecosystem': [for (final c in ecosystem[s]) c.toJson()],
          },
      ],
    };
  }
}
