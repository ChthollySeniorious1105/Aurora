import 'dart:math';

import '../../src/engine.dart';

/// The 8 official origami card colors in Sea Salt & Paper.
const List<String> sspColors = [
  'blue',
  'lightBlue',
  'black',
  'yellow',
  'green',
  'white',
  'purple',
  'orange',
];

const Map<String, String> sspColorNames = {
  'blue': '深蓝',
  'lightBlue': '浅蓝',
  'black': '玄黑',
  'yellow': '明黄',
  'green': '翠绿',
  'white': '纯白',
  'purple': '紫罗兰',
  'orange': '珊瑚橙',
};

const Map<String, String> sspKindNames = {
  'crab': '🦀螃蟹',
  'boat': '⛵帆船',
  'fish': '🐟鱼群',
  'shark': '🦈鲨鱼',
  'swimmer': '🏊泳者',
  'octopus': '🐙章鱼',
  'shell': '🐚贝壳',
  'penguin': '🐧企鹅',
  'sailor': '⚓水手',
  'lighthouse': '🗼灯塔',
  'shoal': '🐠鱼群倍增',
  'colony': '🧊企鹅群落',
  'captain': '🧑‍✈️船长',
  'mermaid': '🧜‍♀️美人鱼',
};

class SspCardDef {
  final String id;
  final String kind;
  final String category; // 'duo', 'collector', 'multiplier', 'mermaid'
  final String color;

  const SspCardDef({
    required this.id,
    required this.kind,
    required this.category,
    required this.color,
  });

  String get label => '${sspKindNames[kind] ?? kind}(${sspColorNames[color] ?? color})';

  Map<String, dynamic> toMap() => {
        'id': id,
        'kind': kind,
        'category': category,
        'color': color,
        'label': label,
      };
}

/// Complete 58-card Sea Salt & Paper deck:
/// - Duo cards (34):
///   - `crab` × 9 (2 blue, 2 lightBlue, 1 black, 2 yellow, 1 green, 1 orange)
///   - `boat` × 8 (2 blue, 2 lightBlue, 2 black, 2 yellow)
///   - `fish` × 7 (2 blue, 1 lightBlue, 2 black, 1 yellow, 1 green)
///   - `shark` × 5 (1 blue, 1 lightBlue, 1 black, 1 green, 1 purple)
///   - `swimmer` × 5 (1 blue, 1 lightBlue, 1 yellow, 1 orange, 1 purple)
/// - Collector cards (16):
///   - `octopus` × 5 (1 lightBlue, 1 yellow, 1 green, 1 purple, 1 orange)
///   - `shell` × 6 (1 blue, 1 lightBlue, 1 black, 1 yellow, 1 green, 1 orange)
///   - `penguin` × 3 (1 purple, 1 orange, 1 lightBlue)
///   - `sailor` × 2 (1 orange, 1 purple)
/// - Multiplier cards (4):
///   - `lighthouse` × 1 (purple, +1 per boat)
///   - `shoal` × 1 (lightBlue, +1 per fish)
///   - `colony` × 1 (green, +2 per penguin)
///   - `captain` × 1 (orange, +3 per sailor)
/// - Mermaid cards (4):
///   - `mermaid` × 4 (white)
final List<SspCardDef> kSspDeckDefs = [
  // Crabs (9)
  const SspCardDef(id: 'crab_1', kind: 'crab', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'crab_2', kind: 'crab', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'crab_3', kind: 'crab', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'crab_4', kind: 'crab', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'crab_5', kind: 'crab', category: 'duo', color: 'black'),
  const SspCardDef(id: 'crab_6', kind: 'crab', category: 'duo', color: 'yellow'),
  const SspCardDef(id: 'crab_7', kind: 'crab', category: 'duo', color: 'yellow'),
  const SspCardDef(id: 'crab_8', kind: 'crab', category: 'duo', color: 'green'),
  const SspCardDef(id: 'crab_9', kind: 'crab', category: 'duo', color: 'orange'),
  // Boats (8)
  const SspCardDef(id: 'boat_1', kind: 'boat', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'boat_2', kind: 'boat', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'boat_3', kind: 'boat', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'boat_4', kind: 'boat', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'boat_5', kind: 'boat', category: 'duo', color: 'black'),
  const SspCardDef(id: 'boat_6', kind: 'boat', category: 'duo', color: 'black'),
  const SspCardDef(id: 'boat_7', kind: 'boat', category: 'duo', color: 'yellow'),
  const SspCardDef(id: 'boat_8', kind: 'boat', category: 'duo', color: 'yellow'),
  // Fish (7)
  const SspCardDef(id: 'fish_1', kind: 'fish', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'fish_2', kind: 'fish', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'fish_3', kind: 'fish', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'fish_4', kind: 'fish', category: 'duo', color: 'black'),
  const SspCardDef(id: 'fish_5', kind: 'fish', category: 'duo', color: 'black'),
  const SspCardDef(id: 'fish_6', kind: 'fish', category: 'duo', color: 'yellow'),
  const SspCardDef(id: 'fish_7', kind: 'fish', category: 'duo', color: 'green'),
  // Sharks (5)
  const SspCardDef(id: 'shark_1', kind: 'shark', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'shark_2', kind: 'shark', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'shark_3', kind: 'shark', category: 'duo', color: 'black'),
  const SspCardDef(id: 'shark_4', kind: 'shark', category: 'duo', color: 'green'),
  const SspCardDef(id: 'shark_5', kind: 'shark', category: 'duo', color: 'purple'),
  // Swimmers (5)
  const SspCardDef(id: 'swimmer_1', kind: 'swimmer', category: 'duo', color: 'blue'),
  const SspCardDef(id: 'swimmer_2', kind: 'swimmer', category: 'duo', color: 'lightBlue'),
  const SspCardDef(id: 'swimmer_3', kind: 'swimmer', category: 'duo', color: 'yellow'),
  const SspCardDef(id: 'swimmer_4', kind: 'swimmer', category: 'duo', color: 'orange'),
  const SspCardDef(id: 'swimmer_5', kind: 'swimmer', category: 'duo', color: 'purple'),
  // Octopuses (5)
  const SspCardDef(id: 'octopus_1', kind: 'octopus', category: 'collector', color: 'lightBlue'),
  const SspCardDef(id: 'octopus_2', kind: 'octopus', category: 'collector', color: 'yellow'),
  const SspCardDef(id: 'octopus_3', kind: 'octopus', category: 'collector', color: 'green'),
  const SspCardDef(id: 'octopus_4', kind: 'octopus', category: 'collector', color: 'purple'),
  const SspCardDef(id: 'octopus_5', kind: 'octopus', category: 'collector', color: 'orange'),
  // Shells (6)
  const SspCardDef(id: 'shell_1', kind: 'shell', category: 'collector', color: 'blue'),
  const SspCardDef(id: 'shell_2', kind: 'shell', category: 'collector', color: 'lightBlue'),
  const SspCardDef(id: 'shell_3', kind: 'shell', category: 'collector', color: 'black'),
  const SspCardDef(id: 'shell_4', kind: 'shell', category: 'collector', color: 'yellow'),
  const SspCardDef(id: 'shell_5', kind: 'shell', category: 'collector', color: 'green'),
  const SspCardDef(id: 'shell_6', kind: 'shell', category: 'collector', color: 'orange'),
  // Penguins (3)
  const SspCardDef(id: 'penguin_1', kind: 'penguin', category: 'collector', color: 'purple'),
  const SspCardDef(id: 'penguin_2', kind: 'penguin', category: 'collector', color: 'orange'),
  const SspCardDef(id: 'penguin_3', kind: 'penguin', category: 'collector', color: 'lightBlue'),
  // Sailors (2)
  const SspCardDef(id: 'sailor_1', kind: 'sailor', category: 'collector', color: 'orange'),
  const SspCardDef(id: 'sailor_2', kind: 'sailor', category: 'collector', color: 'purple'),
  // Multipliers (4)
  const SspCardDef(id: 'lighthouse_1', kind: 'lighthouse', category: 'multiplier', color: 'purple'),
  const SspCardDef(id: 'shoal_1', kind: 'shoal', category: 'multiplier', color: 'lightBlue'),
  const SspCardDef(id: 'colony_1', kind: 'colony', category: 'multiplier', color: 'green'),
  const SspCardDef(id: 'captain_1', kind: 'captain', category: 'multiplier', color: 'orange'),
  // Mermaids (4)
  const SspCardDef(id: 'mermaid_1', kind: 'mermaid', category: 'mermaid', color: 'white'),
  const SspCardDef(id: 'mermaid_2', kind: 'mermaid', category: 'mermaid', color: 'white'),
  const SspCardDef(id: 'mermaid_3', kind: 'mermaid', category: 'mermaid', color: 'white'),
  const SspCardDef(id: 'mermaid_4', kind: 'mermaid', category: 'mermaid', color: 'white'),
];

final Map<String, SspCardDef> kSspCardById = {
  for (final c in kSspDeckDefs) c.id: c,
};

List<String> buildSspDeck() => [for (final c in kSspDeckDefs) c.id];

SspCardDef sspCard(String id) =>
    kSspCardById[id] ??
    SspCardDef(
      id: id,
      kind: id.split('_').first,
      category: 'duo',
      color: 'blue',
    );

/// Checks if two cards form a valid Duo pair (`crab+crab`, `boat+boat`, `fish+fish`, or `shark+swimmer`).
bool sspIsValidDuo(String id1, String id2) {
  if (id1 == id2) return false;
  final k1 = sspCard(id1).kind;
  final k2 = sspCard(id2).kind;
  if (k1 == 'crab' && k2 == 'crab') return true;
  if (k1 == 'boat' && k2 == 'boat') return true;
  if (k1 == 'fish' && k2 == 'fish') return true;
  if ((k1 == 'shark' && k2 == 'swimmer') ||
      (k1 == 'swimmer' && k2 == 'shark')) {
    return true;
  }
  return false;
}

/// Returns the duo effect type: `'crab'`, `'boat'`, `'fish'`, or `'shark_swimmer'`.
String? sspDuoType(String id1, String id2) {
  if (!sspIsValidDuo(id1, id2)) return null;
  final k1 = sspCard(id1).kind;
  if (k1 == 'crab') return 'crab';
  if (k1 == 'boat') return 'boat';
  if (k1 == 'fish') return 'fish';
  return 'shark_swimmer';
}

/// Finds all valid Duo pairs `[id1, id2]` present in [hand].
List<List<String>> sspFindHandDuos(List<String> hand) {
  final out = <List<String>>[];
  final seen = <String>{};
  for (var i = 0; i < hand.length; i++) {
    for (var j = i + 1; j < hand.length; j++) {
      final a = hand[i];
      final b = hand[j];
      if (sspIsValidDuo(a, b)) {
        final t = sspDuoType(a, b)!;
        if (!seen.contains(t)) {
          seen.add(t);
          out.add([a, b]);
        }
      }
    }
  }
  return out;
}

/// Computes color counts (sorted descending) across a player's `hand` and `tableau`.
List<int> sspSortedColorCounts(List<String> hand, List<List<String>> tableau) {
  final counts = <String, int>{};
  for (final id in hand) {
    final col = sspCard(id).color;
    counts[col] = (counts[col] ?? 0) + 1;
  }
  for (final pair in tableau) {
    for (final id in pair) {
      final col = sspCard(id).color;
      counts[col] = (counts[col] ?? 0) + 1;
    }
  }
  final vals = counts.values.toList()..sort((a, b) => b.compareTo(a));
  return vals;
}

/// Computes the color bonus (count of the single most frequent color) for `last_chance` resolution.
int sspColorBonus(List<String> hand, List<List<String>> tableau) {
  final counts = sspSortedColorCounts(hand, tableau);
  return counts.isEmpty ? 0 : counts.first;
}

/// Computes full round score breakdown for `(hand, tableau)`:
/// - `duoPoints`: +1 per played Duo pair in `tableau`
/// - `collectorPoints`:
///   - `octopus`: 0 / 2 / 4 / 6 / 9 for 1..5+
///   - `shell`: 0 / 2 / 4 / 6 / 8 / 10 for 1..6+
///   - `penguin`: 1 / 3 / 5 for 1..3+
///   - `sailor`: 0 / 5 for 1..2+
/// - `multiplierPoints`:
///   - `lighthouse`: +1 per `boat`
///   - `shoal`: +1 per `fish`
///   - `colony`: +2 per `penguin`
///   - `captain`: +3 per `sailor`
/// - `mermaidPoints`: for `m` mermaids, sum of top `m` most frequent color counts
Map<String, int> sspScoreBreakdown(
  List<String> hand,
  List<List<String>> tableau,
) {
  final allCards = <String>[
    ...hand,
    for (final pair in tableau) ...pair,
  ];
  final kindCounts = <String, int>{};
  for (final id in allCards) {
    final k = sspCard(id).kind;
    kindCounts[k] = (kindCounts[k] ?? 0) + 1;
  }

  final duoPoints = tableau.length;

  const octTable = [0, 0, 2, 4, 6, 9];
  const shellTable = [0, 0, 2, 4, 6, 8, 10];
  const pengTable = [0, 1, 3, 5];
  const sailorTable = [0, 0, 5];

  final octN = min(kindCounts['octopus'] ?? 0, 5);
  final shellN = min(kindCounts['shell'] ?? 0, 6);
  final pengN = min(kindCounts['penguin'] ?? 0, 3);
  final sailorN = min(kindCounts['sailor'] ?? 0, 2);

  final collectorPoints = octTable[octN] +
      shellTable[shellN] +
      pengTable[pengN] +
      sailorTable[sailorN];

  var multiplierPoints = 0;
  if ((kindCounts['lighthouse'] ?? 0) > 0) {
    multiplierPoints += (kindCounts['lighthouse'] ?? 0) * (kindCounts['boat'] ?? 0);
  }
  if ((kindCounts['shoal'] ?? 0) > 0) {
    multiplierPoints += (kindCounts['shoal'] ?? 0) * (kindCounts['fish'] ?? 0);
  }
  if ((kindCounts['colony'] ?? 0) > 0) {
    multiplierPoints += 2 * (kindCounts['colony'] ?? 0) * (kindCounts['penguin'] ?? 0);
  }
  if ((kindCounts['captain'] ?? 0) > 0) {
    multiplierPoints += 3 * (kindCounts['captain'] ?? 0) * (kindCounts['sailor'] ?? 0);
  }

  final mermaids = kindCounts['mermaid'] ?? 0;
  final colorCounts = sspSortedColorCounts(hand, tableau);
  var mermaidPoints = 0;
  for (var i = 0; i < mermaids && i < colorCounts.length; i++) {
    mermaidPoints += colorCounts[i];
  }

  final total = duoPoints + collectorPoints + multiplierPoints + mermaidPoints;
  return {
    'duoPoints': duoPoints,
    'collectorPoints': collectorPoints,
    'multiplierPoints': multiplierPoints,
    'mermaidPoints': mermaidPoints,
    'mermaids': mermaids,
    'colorBonus': colorCounts.isEmpty ? 0 : colorCounts.first,
    'total': total,
  };
}

int sspScoreSeat(List<String> hand, List<List<String>> tableau) =>
    sspScoreBreakdown(hand, tableau)['total']!;

class SeaSaltPaperGame extends GameEngine {
  late int targetScore;
  int round = 1;
  int startPlayer = 0;
  int turn = 0;

  /// Current phase:
  /// - `'draw'`: Active player draws 2 from deck (`draw_deck`) or takes 1 top discard (`take_discard`)
  /// - `'choose_drawn'`: Active player chooses 1 of 2 drawn cards (`keep_drawn`) and discards the other to pile 0 or 1
  /// - `'crab_pick'`: Active player picks any card from a non-empty discard pile (`crab_take`)
  /// - `'action'`: Active player may play Duo pairs (`play_duo`), declare `stop` / `last_chance` (if >= 7 pts), or `end_turn`
  String phase = 'draw';

  List<String> deck = [];
  List<List<String>> discards = [[], []];
  late List<List<String>> hands;
  late List<List<List<String>>> tableau; // Played Duo pairs per seat
  late List<int> scores;

  List<String> drawnCards = [];
  int extraTurns = 0;

  int? lastChanceCaller;
  List<int> lastChanceRemaining = [];

  List<String> actionLog = [];
  Map<String, dynamic>? lastRoundSummary;

  bool _over = false;
  List<int>? _placings;

  SeaSaltPaperGame(super.setup) {
    final defaultTarget = switch (players) {
      2 => 40,
      3 => 35,
      _ => 30,
    };
    targetScore = setup.opt<int>('targetScore', defaultTarget);
    // If option explicitly passed 30/20/40, use setup.opt
    if (setup.options.containsKey('targetScore')) {
      targetScore = setup.opt<int>('targetScore', 30);
    } else {
      targetScore = 30;
    }
    hands = List.generate(players, (_) => <String>[]);
    tableau = List.generate(players, (_) => <List<String>>[]);
    scores = List.filled(players, 0);
  }

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    _over = true;
    final winners = [
      for (var i = 0; i < players; i++)
        if (i != seat) i,
    ];
    _placings = rankWinners(players, winners);
    host.log('${name(seat)} 认输');
  }

  @override
  void start() {
    _startRound();
  }

  void _startRound() {
    deck = shuffled(buildSspDeck(), rng);
    for (var s = 0; s < players; s++) {
      hands[s] = [];
      tableau[s] = [];
    }
    discards = [
      [deck.removeLast()],
      [deck.removeLast()],
    ];
    drawnCards = [];
    extraTurns = 0;
    lastChanceCaller = null;
    lastChanceRemaining = [];
    actionLog = [];
    phase = 'draw';
    turn = startPlayer;
    host.log('第 $round 局开始：牌库 ${deck.length} 张，两个弃牌堆各翻开 1 张');
  }

  int seatRoundPoints(int seat) => sspScoreSeat(hands[seat], tableau[seat]);

  int seatMermaids(int seat) =>
      sspScoreBreakdown(hands[seat], tableau[seat])['mermaids']!;

  bool _checkFourMermaidsWin(int seat) {
    if (seatMermaids(seat) >= 4) {
      scores[seat] = max(scores[seat], targetScore) + 10;
      _over = true;
      _placings = rankWinners(players, [seat]);
      actionLog.add('🧜‍♀️ ${name(seat)} 集齐全部 4 张美人鱼，立即赢得整场比赛！');
      host.log('🧜‍♀️ ${name(seat)} 集齐 4 张美人鱼直接获胜！');
      return true;
    }
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (phase == 'draw') {
      if (type == 'draw_deck') {
        if (deck.isEmpty) throw GameError('牌库已空，请从弃牌堆拿牌');
        if (deck.length == 1) {
          final c = deck.removeLast();
          hands[seat].add(c);
          actionLog.add('${name(seat)} 摸取牌库最后 1 张牌');
          if (_checkFourMermaidsWin(seat)) return;
          phase = 'action';
          return;
        }
        final c1 = deck.removeLast();
        final c2 = deck.removeLast();
        drawnCards = [c1, c2];
        phase = 'choose_drawn';
        return;
      }

      if (type == 'take_discard') {
        final pile = asInt(action['pile'], 0);
        if (pile < 0 || pile > 1 || discards[pile].isEmpty) {
          throw GameError('该弃牌堆为空，无法拿牌');
        }
        final c = discards[pile].removeLast();
        hands[seat].add(c);
        actionLog.add(
          '${name(seat)} 从弃牌堆 ${pile + 1} 拿取了 ${sspCard(c).label}',
        );
        if (_checkFourMermaidsWin(seat)) return;
        phase = 'action';
        return;
      }

      throw GameError('摸牌阶段请选择摸牌库 (draw_deck) 或拿取弃牌堆顶牌 (take_discard)');
    }

    if (phase == 'choose_drawn') {
      if (type != 'keep_drawn') {
        throw GameError('请选择保留哪张摸到的牌 (keep_drawn)');
      }
      var keepIdx = asInt(action['keepIndex'], -1);
      final keepCard = asStr(action['keepCard']);
      if (keepIdx < 0 && keepCard.isNotEmpty) {
        keepIdx = drawnCards.indexOf(keepCard);
      }
      if (keepIdx < 0 || keepIdx >= drawnCards.length) {
        keepIdx = 0;
      }
      var discardPile = asInt(
        action['discardPile'],
        asInt(action['pile'], -1),
      );
      // Official rule: if one discard pile is empty, must discard to the empty pile unless specified
      if (discardPile != 0 && discardPile != 1) {
        if (discards[0].isEmpty) {
          discardPile = 0;
        } else if (discards[1].isEmpty) {
          discardPile = 1;
        } else {
          discardPile = 0;
        }
      }

      final kept = drawnCards[keepIdx];
      final discarded = drawnCards[1 - keepIdx];
      drawnCards = [];
      hands[seat].add(kept);
      discards[discardPile].add(discarded);
      actionLog.add(
        '${name(seat)} 从牌库摸2留1，将 ${sspCard(discarded).label} 弃入弃牌堆 ${discardPile + 1}',
      );
      if (_checkFourMermaidsWin(seat)) return;
      phase = 'action';
      return;
    }

    if (phase == 'crab_pick') {
      if (type != 'crab_take') {
        throw GameError('请从弃牌堆选择一张牌拿入手牌 (crab_take)');
      }
      final pile = asInt(action['pile'], discards[0].isNotEmpty ? 0 : 1);
      if (pile < 0 || pile > 1 || discards[pile].isEmpty) {
        throw GameError('选择的弃牌堆为空');
      }
      final cardId = asStr(action['card']);
      String picked;
      if (cardId.isNotEmpty && discards[pile].contains(cardId)) {
        discards[pile].remove(cardId);
        picked = cardId;
      } else {
        final idx = asInt(action['index'], discards[pile].length - 1)
            .clamp(0, discards[pile].length - 1);
        picked = discards[pile].removeAt(idx);
      }
      hands[seat].add(picked);
      actionLog.add(
        '🦀 ${name(seat)} 发动螃蟹成对效果，从弃牌堆 ${pile + 1} 检索拿取了 ${sspCard(picked).label}',
      );
      if (_checkFourMermaidsWin(seat)) return;
      phase = 'action';
      return;
    }

    if (phase == 'action') {
      if (type == 'play_duo') {
        String c1 = asStr(action['card1']);
        String c2 = asStr(action['card2']);
        if ((c1.isEmpty || c2.isEmpty) && action['cards'] is List) {
          final list = (action['cards'] as List).map((e) => '$e').toList();
          if (list.length >= 2) {
            c1 = list[0];
            c2 = list[1];
          }
        }
        if (!hands[seat].contains(c1) || !hands[seat].contains(c2) || c1 == c2) {
          throw GameError('手牌中没有这两张成对行动卡');
        }
        if (!sspIsValidDuo(c1, c2)) {
          throw GameError('这两张牌不能组成合法的成对行动卡 (需螃蟹×2、帆船×2、鱼群×2 或 鲨鱼+泳者)');
        }

        hands[seat].remove(c1);
        hands[seat].remove(c2);
        tableau[seat].add([c1, c2]);
        final duoKind = sspDuoType(c1, c2)!;

        if (duoKind == 'crab') {
          if (discards[0].isEmpty && discards[1].isEmpty) {
            actionLog.add('🦀 ${name(seat)} 打出螃蟹×2（弃牌堆为空，仅得 +1 分）');
            return;
          }
          final pickCard = asStr(action['pickCard'], asStr(action['targetCard']));
          final pickPile = asInt(action['pile'], -1);
          if (pickCard.isNotEmpty) {
            for (var p = 0; p < 2; p++) {
              if (discards[p].remove(pickCard)) {
                hands[seat].add(pickCard);
                actionLog.add(
                  '🦀 ${name(seat)} 打出螃蟹×2，从弃牌堆 ${p + 1} 拿取了 ${sspCard(pickCard).label}',
                );
                _checkFourMermaidsWin(seat);
                return;
              }
            }
          }
          if (pickPile == 0 || pickPile == 1) {
            if (discards[pickPile].isNotEmpty) {
              final taken = discards[pickPile].removeLast();
              hands[seat].add(taken);
              actionLog.add(
                '🦀 ${name(seat)} 打出螃蟹×2，从弃牌堆 ${pickPile + 1} 拿取了 ${sspCard(taken).label}',
              );
              _checkFourMermaidsWin(seat);
              return;
            }
          }
          phase = 'crab_pick';
          return;
        }

        if (duoKind == 'boat') {
          extraTurns += 1;
          actionLog.add('⛵ ${name(seat)} 打出帆船×2：本回合结束后立即获得 1 个额外回合！');
          return;
        }

        if (duoKind == 'fish') {
          if (deck.isNotEmpty) {
            final top = deck.removeLast();
            hands[seat].add(top);
            actionLog.add('🐟 ${name(seat)} 打出鱼群×2：从牌库顶摸取 1 张牌');
            _checkFourMermaidsWin(seat);
          } else {
            actionLog.add('🐟 ${name(seat)} 打出鱼群×2（牌库已空，仅得 +1 分）');
          }
          return;
        }

        if (duoKind == 'shark_swimmer') {
          var target = asInt(action['targetSeat'], -1);
          final candidates = <int>[
            for (var s = 0; s < players; s++)
              if (s != seat &&
                  s != lastChanceCaller &&
                  hands[s].isNotEmpty)
                s,
          ];
          if (candidates.isEmpty) {
            actionLog.add('🦈🏊 ${name(seat)} 打出鲨鱼+泳者（无对手手牌可偷，仅得 +1 分）');
            return;
          }
          if (!candidates.contains(target)) {
            candidates.sort((a, b) => hands[b].length.compareTo(hands[a].length));
            target = candidates.first;
          }
          final stolenIdx = rng.nextInt(hands[target].length);
          final stolen = hands[target].removeAt(stolenIdx);
          hands[seat].add(stolen);
          actionLog.add(
            '🦈🏊 ${name(seat)} 打出鲨鱼+泳者，从 ${name(target)} 手中随机偷取了 1 张牌！',
          );
          _checkFourMermaidsWin(seat);
          return;
        }
      }

      if (type == 'stop') {
        if (lastChanceCaller != null) {
          throw GameError('已有玩家喊出「最后机会」，不能再宣告「到此为止」');
        }
        final pts = seatRoundPoints(seat);
        if (pts < 7) {
          throw GameError('当前本局得分 ($pts 分) 未达到 7 分，不能宣告「到此为止」');
        }
        actionLog.add('🛑 ${name(seat)} 宣告「到此为止 (STOP)」！所有人正常结算本局卡牌得分');
        _resolveStopRound(seat);
        return;
      }

      if (type == 'last_chance') {
        if (lastChanceCaller != null) {
          throw GameError('本局已经有人喊过「最后机会」');
        }
        final pts = seatRoundPoints(seat);
        if (pts < 7) {
          throw GameError('当前本局得分 ($pts 分) 未达到 7 分，不能宣告「最后机会」');
        }
        lastChanceCaller = seat;
        extraTurns = 0;
        lastChanceRemaining = [
          for (var off = 1; off < players; off++) (seat + off) % players,
        ];
        actionLog.add(
          '🎲 ${name(seat)} 以 $pts 分宣告「最后机会 (LAST CHANCE)」！其余玩家各进行最后 1 回合',
        );
        host.log('${name(seat)} 喊出「最后机会」！其余玩家各进行最后 1 回合');
        _advanceTurn();
        return;
      }

      if (type == 'end_turn') {
        _advanceTurn();
        return;
      }

      throw GameError('行动阶段可执行 play_duo / stop / last_chance / end_turn');
    }

    throw GameError('未知阶段：$phase');
  }

  void _advanceTurn() {
    if (extraTurns > 0) {
      extraTurns -= 1;
      if (deck.isEmpty && discards[0].isEmpty && discards[1].isEmpty) {
        _resolveDeckExhausted();
        return;
      }
      phase = 'draw';
      actionLog.add('⛵ ${name(turn)} 开始帆船额外回合！');
      return;
    }

    if (lastChanceCaller != null) {
      lastChanceRemaining.remove(turn);
      if (lastChanceRemaining.isEmpty) {
        _resolveLastChanceRound();
        return;
      }
      turn = lastChanceRemaining.first;
      if (deck.isEmpty && discards[0].isEmpty && discards[1].isEmpty) {
        _resolveLastChanceRound();
        return;
      }
      phase = 'draw';
      return;
    }

    if (deck.isEmpty) {
      _resolveDeckExhausted();
      return;
    }

    turn = (turn + 1) % players;
    phase = 'draw';
  }

  void _resolveStopRound(int caller) {
    final roundPts = [for (var s = 0; s < players; s++) seatRoundPoints(s)];
    for (var s = 0; s < players; s++) {
      scores[s] += roundPts[s];
    }
    _finishRoundSummary(
      mode: 'stop',
      caller: caller,
      betSuccess: null,
      roundGains: roundPts,
    );
  }

  void _resolveLastChanceRound() {
    final caller = lastChanceCaller!;
    final cardPts = [for (var s = 0; s < players; s++) seatRoundPoints(s)];
    final colBonuses = [
      for (var s = 0; s < players; s++) sspColorBonus(hands[s], tableau[s]),
    ];

    var maxOpp = -1;
    for (var s = 0; s < players; s++) {
      if (s != caller && cardPts[s] > maxOpp) {
        maxOpp = cardPts[s];
      }
    }
    final success = cardPts[caller] >= maxOpp;
    final roundGains = List<int>.filled(players, 0);

    for (var s = 0; s < players; s++) {
      if (s == caller) {
        roundGains[s] = success
            ? (cardPts[s] + colBonuses[s])
            : colBonuses[s];
      } else {
        roundGains[s] = success
            ? colBonuses[s]
            : cardPts[s];
      }
      scores[s] += roundGains[s];
    }

    _finishRoundSummary(
      mode: 'last_chance',
      caller: caller,
      betSuccess: success,
      roundGains: roundGains,
    );
  }

  void _resolveDeckExhausted() {
    if (lastChanceCaller != null) {
      _resolveLastChanceRound();
      return;
    }
    final roundPts = [for (var s = 0; s < players; s++) seatRoundPoints(s)];
    if (roundPts.every((p) => p == 0)) {
      roundPts[turn] = 1;
    }
    for (var s = 0; s < players; s++) {
      scores[s] += roundPts[s];
    }
    _finishRoundSummary(
      mode: 'deck_empty',
      caller: -1,
      betSuccess: null,
      roundGains: roundPts,
    );
  }

  void _finishRoundSummary({
    required String mode,
    required int caller,
    required bool? betSuccess,
    required List<int> roundGains,
  }) {
    lastRoundSummary = {
      'round': round,
      'mode': mode,
      'caller': caller,
      'betSuccess': betSuccess,
      'roundGains': roundGains,
      'scores': List<int>.of(scores),
    };
    host.log(
      '第 $round 局结算 ($mode)：${[
        for (var s = 0; s < players; s++) '${name(s)} +${roundGains[s]}(总${scores[s]})'
      ].join('，')}',
    );

    final maxScore = scores.reduce(max);
    if (maxScore >= targetScore || round >= 12) {
      _over = true;
      _placings = rankByScore(scores);
      host.log('海盐与纸折比赛结束！');
    } else {
      round += 1;
      startPlayer = (startPlayer + 1) % players;
      _startRound();
    }
  }

  /// Evaluates how much a candidate card increases [seat]'s score + duo potential.
  int _evaluateCardForSeat(int seat, String cardId) {
    final baseScore = seatRoundPoints(seat);
    final testHand = [...hands[seat], cardId];
    final newScore = sspScoreSeat(testHand, tableau[seat]);
    var val = (newScore - baseScore) * 10;
    final def = sspCard(cardId);
    if (def.kind == 'mermaid') val += 35;
    if (def.category == 'multiplier') val += 18;
    // Check if it completes a duo in hand
    for (final h in hands[seat]) {
      if (sspIsValidDuo(h, cardId)) {
        val += 15;
        break;
      }
    }
    return val;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'draw') {
      var bestPile = -1;
      var bestVal = 12; // threshold to prefer discard over blind deck draw
      for (var p = 0; p < 2; p++) {
        if (discards[p].isNotEmpty) {
          final top = discards[p].last;
          final v = _evaluateCardForSeat(seat, top);
          if (v > bestVal || deck.isEmpty) {
            bestVal = v;
            bestPile = p;
          }
        }
      }
      if (bestPile >= 0) {
        return {'type': 'take_discard', 'pile': bestPile};
      }
      if (deck.isNotEmpty) {
        return {'type': 'draw_deck'};
      }
      return {
        'type': 'take_discard',
        'pile': discards[0].isNotEmpty ? 0 : 1,
      };
    }

    if (phase == 'choose_drawn') {
      final v0 = _evaluateCardForSeat(seat, drawnCards[0]);
      final v1 = drawnCards.length > 1
          ? _evaluateCardForSeat(seat, drawnCards[1])
          : -999;
      final keepIdx = v0 >= v1 ? 0 : 1;
      final pile = discards[0].isEmpty
          ? 0
          : (discards[1].isEmpty ? 1 : rng.nextInt(2));
      return {
        'type': 'keep_drawn',
        'keepIndex': keepIdx,
        'discardPile': pile,
      };
    }

    if (phase == 'crab_pick') {
      var bestPile = discards[0].isNotEmpty ? 0 : 1;
      var bestCard = discards[bestPile].last;
      var bestVal = -999;
      for (var p = 0; p < 2; p++) {
        for (final c in discards[p]) {
          final v = _evaluateCardForSeat(seat, c);
          if (v > bestVal) {
            bestVal = v;
            bestPile = p;
            bestCard = c;
          }
        }
      }
      return {
        'type': 'crab_take',
        'pile': bestPile,
        'card': bestCard,
      };
    }

    if (phase == 'action') {
      final duos = sspFindHandDuos(hands[seat]);
      if (duos.isNotEmpty) {
        final pair = duos.first;
        return {
          'type': 'play_duo',
          'card1': pair[0],
          'card2': pair[1],
        };
      }

      final pts = seatRoundPoints(seat);
      if (lastChanceCaller == null && pts >= 7) {
        if (scores[seat] + pts >= targetScore || pts >= 11) {
          return {'type': 'stop'};
        }
        if (pts >= 9 && botLevel >= 1) {
          return {'type': 'last_chance'};
        }
        return {'type': 'stop'};
      }

      return {'type': 'end_turn'};
    }

    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final hasSeat = seat >= 0 && seat < players;
    final myHand = hasSeat ? List<String>.of(hands[seat]) : <String>[];
    final myBreakdown = hasSeat
        ? sspScoreBreakdown(hands[seat], tableau[seat])
        : const <String, int>{
            'duoPoints': 0,
            'collectorPoints': 0,
            'multiplierPoints': 0,
            'mermaidPoints': 0,
            'mermaids': 0,
            'colorBonus': 0,
            'total': 0,
          };

    return {
      'round': round,
      'targetScore': targetScore,
      'phase': phase,
      'turn': turn,
      'deckCount': deck.length,
      'discards': [
        List<String>.of(discards[0]),
        List<String>.of(discards[1]),
      ],
      'scores': List<int>.of(scores),
      'handCounts': [for (final h in hands) h.length],
      'tableau': [
        for (var s = 0; s < players; s++)
          [for (final pair in tableau[s]) List<String>.of(pair)],
      ],
      'hand': myHand,
      'drawnCards': (hasSeat && seat == turn && phase == 'choose_drawn')
          ? List<String>.of(drawnCards)
          : const <String>[],
      'myBreakdown': myBreakdown,
      'availableDuos': (hasSeat && seat == turn && phase == 'action')
          ? sspFindHandDuos(myHand)
          : const <List<String>>[],
      'canCallStop': hasSeat &&
          seat == turn &&
          phase == 'action' &&
          lastChanceCaller == null &&
          (myBreakdown['total'] ?? 0) >= 7,
      'lastChanceCaller': lastChanceCaller,
      'lastChanceRemaining': List<int>.of(lastChanceRemaining),
      'extraTurns': extraTurns,
      'actionLog': List<String>.of(actionLog.reversed.take(6)),
      'lastRoundSummary': lastRoundSummary,
      'over': _over,
      'placings': _placings,
    };
  }
}
