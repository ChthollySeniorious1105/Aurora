import 'dart:math';

import '../../src/engine.dart';

const List<String> londonLineNames = [
  '紫线',
  '蓝线',
  '粉线',
  '绿线',
];

const List<String> londonLineEmojis = [
  '🟪',
  '🟦',
  '🩷',
  '🟩',
];

const List<String> londonSymbolEmojis = [
  '●',
  '▲',
  '■',
  '✚',
  '🃏',
];

const List<String> londonSymbolNames = [
  '圆站',
  '三角站',
  '方块站',
  '十字站',
  '百搭站',
];

class LondonStation {
  final int id;
  final int r;
  final int c;
  final int district; // 0..8
  final int symbol; // 0: ●, 1: ▲, 2: ■, 3: ✚
  final bool isTourist; // ⭐ Tourist site (+2 VP when visited)
  final int startLine; // -1 or 0..3 starting terminal for a Metro line
  final String name;

  const LondonStation({
    required this.id,
    required this.r,
    required this.c,
    required this.district,
    required this.symbol,
    this.isTourist = false,
    this.startLine = -1,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'r': r,
        'c': c,
        'district': district,
        'symbol': symbol,
        'isTourist': isTourist,
        'startLine': startLine,
        'name': name,
      };
}

class LondonStationCard {
  final int id;
  final int symbol; // 0..3 or 4 for Wild (🃏)
  final bool switchTrack; // 🔀 Can branch from ANY station on the active line

  const LondonStationCard({
    required this.id,
    required this.symbol,
    this.switchTrack = false,
  });

  bool get isWild => symbol == 4;

  String get label =>
      '${londonSymbolEmojis[symbol]}${londonSymbolNames[symbol]}${switchTrack ? ' 🔀道岔' : ''}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'symbol': symbol,
        'isWild': isWild,
        'switchTrack': switchTrack,
        'label': label,
      };
}

class NextStationLondonGame extends GameEngine {
  static const int rows = 7;
  static const int cols = 7;
  static const int numLines = 4;
  static const double riverRow = 3.5; // Separates North (r <= 3) and South (r >= 4)

  static const List<LondonStation> stations = [
    LondonStation(id: 0, r: 0, c: 1, district: 0, symbol: 0, name: 'Camden'),
    LondonStation(
        id: 1, r: 0, c: 3, district: 1, symbol: 1, isTourist: true, name: 'King\'s Cross'),
    LondonStation(id: 2, r: 0, c: 5, district: 2, symbol: 2, name: 'Hackney'),
    LondonStation(id: 3, r: 1, c: 0, district: 0, symbol: 3, name: 'Paddington'),
    LondonStation(
        id: 4, r: 1, c: 2, district: 1, symbol: 2, startLine: 0, name: 'Baker St'),
    LondonStation(
        id: 5, r: 1, c: 4, district: 1, symbol: 0, startLine: 1, name: 'Old St'),
    LondonStation(id: 6, r: 1, c: 6, district: 2, symbol: 1, name: 'Stratford'),
    LondonStation(
        id: 7, r: 2, c: 1, district: 3, symbol: 1, isTourist: true, name: 'Hyde Park'),
    LondonStation(
        id: 8, r: 2, c: 3, district: 4, symbol: 3, isTourist: true, name: 'Oxford Circus'),
    LondonStation(id: 9, r: 2, c: 5, district: 5, symbol: 0, name: 'Liverpool St'),
    LondonStation(id: 10, r: 3, c: 2, district: 4, symbol: 0, name: 'Piccadilly'),
    LondonStation(
        id: 11, r: 3, c: 4, district: 4, symbol: 1, isTourist: true, name: 'St Paul\'s'),
    // --- South of the Thames (r >= 4) ---
    LondonStation(
        id: 12, r: 4, c: 1, district: 3, symbol: 2, startLine: 2, name: 'Victoria'),
    LondonStation(
        id: 13, r: 4, c: 3, district: 4, symbol: 2, isTourist: true, name: 'Waterloo'),
    LondonStation(
        id: 14, r: 4, c: 5, district: 5, symbol: 3, startLine: 3, name: 'London Bridge'),
    LondonStation(id: 15, r: 5, c: 2, district: 6, symbol: 1, name: 'Vauxhall'),
    LondonStation(id: 16, r: 5, c: 4, district: 7, symbol: 0, name: 'Elephant'),
    LondonStation(id: 17, r: 6, c: 3, district: 8, symbol: 3, name: 'Brixton'),
  ];

  static int startStationForLine(int lineIdx) {
    for (final st in stations) {
      if (st.startLine == lineIdx) return st.id;
    }
    return 0;
  }

  static LondonStation? stationAtCell(int r, int c) {
    for (final st in stations) {
      if (st.r == r && st.c == c) return st;
    }
    return null;
  }

  late final int cardsPerRound;
  // lineSegments[seat][line] = list of (u, v) station ID pairs
  late List<List<List<(int, int)>>> lineSegments;
  // lineEndpoints[seat][line] = [endA, endB]
  late List<List<List<int>>> lineEndpoints;
  // visitedByLine[seat][line] = set of visited station IDs
  late List<List<Set<int>>> visitedByLine;
  late List<int> score;

  final List<LondonStationCard> roundDeck = [];
  LondonStationCard currentCard = const LondonStationCard(id: 1, symbol: 4);

  int round = 1; // 1..4 corresponding to activeLine = round - 1
  int cardStep = 1; // 1..cardsPerRound within the round
  int turn = 0;
  bool over = false;
  String lastAction = '伦敦地铁规划开启';

  NextStationLondonGame(super.setup)
      : cardsPerRound = setup.opt<int>('cardsPerRound', 5);

  int get activeLine => (round - 1).clamp(0, numLines - 1);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  List<LondonStationCard> _buildRoundDeck() {
    final base = <LondonStationCard>[
      const LondonStationCard(id: 1, symbol: 0, switchTrack: false),
      const LondonStationCard(id: 2, symbol: 1, switchTrack: false),
      const LondonStationCard(id: 3, symbol: 2, switchTrack: false),
      const LondonStationCard(id: 4, symbol: 3, switchTrack: false),
      const LondonStationCard(id: 5, symbol: 4, switchTrack: true),
      const LondonStationCard(id: 6, symbol: 0, switchTrack: true),
      const LondonStationCard(id: 7, symbol: 1, switchTrack: true),
      const LondonStationCard(id: 8, symbol: 2, switchTrack: true),
      const LondonStationCard(id: 9, symbol: 3, switchTrack: true),
      const LondonStationCard(id: 10, symbol: 4, switchTrack: false),
    ];
    return shuffled(base, rng);
  }

  @override
  void start() {
    lineSegments = List.generate(
      players,
      (_) => List.generate(numLines, (_) => <(int, int)>[]),
    );
    lineEndpoints = List.generate(
      players,
      (_) => [
        for (var l = 0; l < numLines; l++)
          [startStationForLine(l), startStationForLine(l)],
      ],
    );
    visitedByLine = List.generate(
      players,
      (_) => [
        for (var l = 0; l < numLines; l++) {startStationForLine(l)},
      ],
    );
    score = List.filled(players, 0);

    round = 1;
    cardStep = 1;
    turn = 0;
    over = false;
    _startRound();
  }

  void _startRound() {
    roundDeck
      ..clear()
      ..addAll(_buildRoundDeck());
    cardStep = 1;
    currentCard = roundDeck.removeLast();
    lastAction =
        '第 $round 轮（${londonLineEmojis[activeLine]}${londonLineNames[activeLine]}）开始，翻开站点卡：${currentCard.label}';
  }

  /// Checks if segment (u1, v1) properly intersects (u2, v2) in the 2D grid plane.
  static bool segmentsCross(int u1, int v1, int u2, int v2) {
    final e1a = min(u1, v1);
    final e1b = max(u1, v1);
    final e2a = min(u2, v2);
    final e2b = max(u2, v2);
    if (e1a == e2a && e1b == e2b) return true; // Exact same edge

    // Sharing an endpoint is allowed (as long as not colinear overlapping)
    if (u1 == u2 || u1 == v2 || v1 == u2 || v1 == v2) return false;

    final ax = stations[u1].c.toDouble();
    final ay = stations[u1].r.toDouble();
    final bx = stations[v1].c.toDouble();
    final by = stations[v1].r.toDouble();
    final cx = stations[u2].c.toDouble();
    final cy = stations[u2].r.toDouble();
    final dx = stations[v2].c.toDouble();
    final dy = stations[v2].r.toDouble();

    double cross(double x1, double y1, double x2, double y2, double x3, double y3) =>
        (x2 - x1) * (y3 - y1) - (y2 - y1) * (x3 - x1);

    final d1 = cross(ax, ay, bx, by, cx, cy);
    final d2 = cross(ax, ay, bx, by, dx, dy);
    final d3 = cross(cx, cy, dx, dy, ax, ay);
    final d4 = cross(cx, cy, dx, dy, bx, by);

    if (((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0))) {
      return true;
    }
    return false;
  }

  /// Checks whether segment (u -> v) crosses the Thames River (row 3.5).
  static bool crossesThames(int u, int v) =>
      (stations[u].r <= 3) != (stations[v].r <= 3);

  /// Validates whether [seat] can connect [u] -> [v] on [lineIdx] for [card].
  String? validateConnect(
    int seat,
    int lineIdx,
    int u,
    int v, [
    LondonStationCard? card,
  ]) {
    final c = card ?? currentCard;
    if (u < 0 || u >= stations.length || v < 0 || v >= stations.length || u == v) {
      return '无效的站点编号';
    }
    final visited = visitedByLine[seat][lineIdx];
    if (!visited.contains(u)) {
      return '起点必须是当前线路已连接的站点';
    }
    if (!c.switchTrack) {
      final ends = lineEndpoints[seat][lineIdx];
      if (!ends.contains(u)) {
        return '无道岔(🔀)时，只能从当前地铁线的两端终点延伸';
      }
    }
    if (visited.contains(v)) {
      return '同一条地铁线不能重复经过同一站点';
    }
    final stV = stations[v];
    if (!c.isWild && stV.symbol != c.symbol) {
      return '目标站点的符号(${londonSymbolEmojis[stV.symbol]})与当前卡牌(${londonSymbolEmojis[c.symbol]})不匹配';
    }

    final stU = stations[u];
    final dr = stV.r - stU.r;
    final dc = stV.c - stU.c;
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) {
      return '隧道必须沿水平、垂直或 45° 对角线直连';
    }

    // Check no intermediate station lies strictly between u and v
    final steps = max(dr.abs(), dc.abs());
    final sr = dr.sign;
    final sc = dc.sign;
    for (var k = 1; k < steps; k++) {
      final mr = stU.r + sr * k;
      final mc = stU.c + sc * k;
      if (stationAtCell(mr, mc) != null) {
        return '隧道不能直接穿过中间站点';
      }
    }

    // Check no crossing or reusing existing segments across all 4 lines of [seat]
    for (var l = 0; l < numLines; l++) {
      for (final (eu, ev) in lineSegments[seat][l]) {
        if (segmentsCross(u, v, eu, ev)) {
          return '隧道不能与已有地铁线路交叉或重合';
        }
      }
    }
    return null;
  }

  List<(int, int)> legalConnections(int seat, [int? lineIdx, LondonStationCard? card]) {
    final l = lineIdx ?? activeLine;
    final c = card ?? currentCard;
    final res = <(int, int)>[];
    for (final u in visitedByLine[seat][l]) {
      for (var v = 0; v < stations.length; v++) {
        if (validateConnect(seat, l, u, v, c) == null) {
          res.add((u, v));
        }
      }
    }
    return res;
  }

  /// Scores a single Metro Line: (Distinct Districts) * (Max in 1 District) + 2 * (Thames Crossings).
  int calcLineScore(int seat, int lineIdx) {
    final visited = visitedByLine[seat][lineIdx];
    final segs = lineSegments[seat][lineIdx];
    if (segs.isEmpty) return 0;

    final districtCounts = <int, int>{};
    for (final stId in visited) {
      final d = stations[stId].district;
      districtCounts[d] = (districtCounts[d] ?? 0) + 1;
    }
    final distinctDistricts = districtCounts.length;
    var maxInOneDistrict = 0;
    for (final cnt in districtCounts.values) {
      if (cnt > maxInOneDistrict) maxInOneDistrict = cnt;
    }
    var thames = 0;
    for (final (u, v) in segs) {
      if (crossesThames(u, v)) thames++;
    }
    return distinctDistricts * maxInOneDistrict + 2 * thames;
  }

  /// Tourist Sites (⭐): +2 VP for each unique Tourist Site visited by at least 1 line.
  int calcTouristScore(int seat) {
    final visitedAll = <int>{};
    for (var l = 0; l < numLines; l++) {
      if (lineSegments[seat][l].isNotEmpty) {
        visitedAll.addAll(visitedByLine[seat][l]);
      } else {
        visitedAll.add(startStationForLine(l));
      }
    }
    var pts = 0;
    for (final stId in visitedAll) {
      if (stations[stId].isTourist &&
          visitedByLine[seat].any((s) => s.length > 1 && s.contains(stId))) {
        pts += 2;
      }
    }
    return pts;
  }

  /// Interchange Stations served by 2 / 3 / 4 different lines score +2 / +5 / +9 VP!
  int calcInterchangeScore(int seat) {
    var pts = 0;
    for (final st in stations) {
      var linesHere = 0;
      for (var l = 0; l < numLines; l++) {
        if (visitedByLine[seat][l].contains(st.id)) {
          linesHere++;
        }
      }
      pts += switch (linesHere) {
        2 => 2,
        3 => 5,
        4 => 9,
        _ => 0,
      };
    }
    return pts;
  }

  int calcScore(int seat) {
    var total = 0;
    for (var l = 0; l < numLines; l++) {
      total += calcLineScore(seat, l);
    }
    total += calcTouristScore(seat);
    total += calcInterchangeScore(seat);
    return total;
  }

  void applyConnect(int seat, int lineIdx, int u, int v) {
    lineSegments[seat][lineIdx].add((u, v));
    visitedByLine[seat][lineIdx].add(v);
    final ends = lineEndpoints[seat][lineIdx];
    if (ends[0] == ends[1] && ends[0] == u) {
      ends[1] = v;
    } else if (ends[0] == u) {
      ends[0] = v;
    } else if (ends[1] == u) {
      ends[1] = v;
    }
    score[seat] = calcScore(seat);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    switch (type) {
      case 'connect':
        final u = asInt(action['from'], -1);
        final v = asInt(action['to'], -1);
        final err = validateConnect(seat, activeLine, u, v);
        if (err != null) throw GameError(err);

        applyConnect(seat, activeLine, u, v);
        final thamesStr = crossesThames(u, v) ? '（跨越泰晤士河🌊+2分）' : '';
        final tourStr = stations[v].isTourist ? '（途经景点⭐）' : '';
        lastAction =
            '${name(seat)} 延伸${londonLineEmojis[activeLine]}${londonLineNames[activeLine]}: ${stations[u].name} → ${stations[v].name}$thamesStr$tourStr';
        host.log(lastAction);
        _advanceTurn();

      case 'pass':
        score[seat] = calcScore(seat);
        lastAction = '${name(seat)} 本张卡牌跳过连线';
        host.log(lastAction);
        _advanceTurn();

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
    if (cardStep < cardsPerRound && roundDeck.isNotEmpty) {
      cardStep++;
      currentCard = roundDeck.removeLast();
      return;
    }
    if (round >= numLines) {
      over = true;
      for (var s = 0; s < players; s++) {
        score[s] = calcScore(s);
      }
      lastAction = '下一站：伦敦 4 条地铁线建设完毕！总分最高者获胜';
      host.log(lastAction);
      return;
    }
    round++;
    _startRound();
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    final legal = legalConnections(seat);
    if (legal.isEmpty) {
      return {'type': 'pass'};
    }

    (int, int)? bestPair;
    var bestVal = -999999;
    for (final (u, v) in legal) {
      var val = 10;
      if (crossesThames(u, v)) val += 8;
      if (stations[v].isTourist) val += 6;
      // Interchange bonus if another line already visits v
      var otherLines = 0;
      for (var l = 0; l < numLines; l++) {
        if (l != activeLine && visitedByLine[seat][l].contains(v)) {
          otherLines++;
        }
      }
      val += otherLines * 7;
      if (val > bestVal) {
        bestVal = val;
        bestPair = (u, v);
      }
    }

    final chosen = bestPair ?? legal.first;
    return {
      'type': 'connect',
      'from': chosen.$1,
      'to': chosen.$2,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myLegal = (!over && seat >= 0 && seat < players)
        ? [
            for (final (u, v) in legalConnections(seat)) [u, v],
          ]
        : const <List<int>>[];

    return {
      'rows': rows,
      'cols': cols,
      'riverRow': riverRow,
      'round': round,
      'numLines': numLines,
      'activeLine': activeLine,
      'cardStep': cardStep,
      'cardsPerRound': cardsPerRound,
      'turn': turn,
      'over': over,
      'lastAction': lastAction,
      'currentCard': currentCard.toJson(),
      'stations': [for (final st in stations) st.toJson()],
      'legalConnections': myLegal,
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'lineScores': [
              for (var l = 0; l < numLines; l++) calcLineScore(s, l),
            ],
            'touristVp': calcTouristScore(s),
            'interchangeVp': calcInterchangeScore(s),
            'lineEndpoints': [
              for (var l = 0; l < numLines; l++)
                List<int>.of(lineEndpoints[s][l]),
            ],
            'lineSegments': [
              for (var l = 0; l < numLines; l++)
                [
                  for (final (u, v) in lineSegments[s][l]) [u, v],
                ],
            ],
          },
      ],
    };
  }
}
