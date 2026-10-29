import '../../src/engine.dart';

class StationNode {
  final int id;
  final String name;
  final double x;
  final double y;
  final Map<String, List<int>> edges; // 'taxi', 'bus', 'metro', 'ferry'

  const StationNode({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.edges,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'x': x,
        'y': y,
        'edges': edges,
      };
}

/// 28 numbered London stations connected by taxi, bus, metro, and Thames ferry.
const List<StationNode> kLondonStations = [
  StationNode(
    id: 1,
    name: '贝克街',
    x: 0.20,
    y: 0.16,
    edges: {
      'taxi': [2, 5, 7],
      'bus': [2, 5, 7],
      'metro': [3, 7, 9],
    },
  ),
  StationNode(
    id: 2,
    name: '摄政公园',
    x: 0.36,
    y: 0.14,
    edges: {
      'taxi': [1, 3, 4, 5],
      'bus': [1, 3, 4],
    },
  ),
  StationNode(
    id: 3,
    name: '国王十字',
    x: 0.54,
    y: 0.14,
    edges: {
      'taxi': [2, 4, 11, 12],
      'bus': [2, 4, 11, 12],
      'metro': [1, 9, 11, 12],
    },
  ),
  StationNode(
    id: 4,
    name: '大英博物馆',
    x: 0.48,
    y: 0.28,
    edges: {
      'taxi': [2, 3, 5, 10, 11, 26],
      'bus': [2, 3, 10, 11],
    },
  ),
  StationNode(
    id: 5,
    name: '牛津广场',
    x: 0.30,
    y: 0.28,
    edges: {
      'taxi': [1, 2, 4, 6, 9, 26],
      'bus': [1, 6, 9, 10],
      'metro': [7, 9, 11],
    },
  ),
  StationNode(
    id: 6,
    name: '海德公园',
    x: 0.18,
    y: 0.36,
    edges: {
      'taxi': [5, 7, 8, 9, 25],
      'bus': [5, 7, 8, 16],
    },
  ),
  StationNode(
    id: 7,
    name: '帕丁顿',
    x: 0.08,
    y: 0.24,
    edges: {
      'taxi': [1, 6, 8],
      'bus': [1, 6, 8],
      'metro': [1, 5, 8],
    },
  ),
  StationNode(
    id: 8,
    name: '肯辛顿',
    x: 0.09,
    y: 0.48,
    edges: {
      'taxi': [6, 7, 15, 17, 25],
      'bus': [6, 7, 17],
      'metro': [7, 16],
    },
  ),
  StationNode(
    id: 9,
    name: '皮卡迪利',
    x: 0.34,
    y: 0.40,
    edges: {
      'taxi': [5, 6, 10, 14, 25, 26, 28],
      'bus': [5, 10, 14, 16],
      'metro': [1, 3, 5, 14, 16],
    },
  ),
  StationNode(
    id: 10,
    name: '考文特花园',
    x: 0.48,
    y: 0.40,
    edges: {
      'taxi': [4, 9, 11, 14, 18, 26, 28],
      'bus': [4, 5, 9, 11, 18],
    },
  ),
  StationNode(
    id: 11,
    name: '圣保罗座堂',
    x: 0.64,
    y: 0.34,
    edges: {
      'taxi': [3, 4, 10, 12, 19, 27],
      'bus': [3, 4, 10, 12, 19],
      'metro': [3, 5, 13, 19],
    },
  ),
  StationNode(
    id: 12,
    name: '利物浦街',
    x: 0.78,
    y: 0.22,
    edges: {
      'taxi': [3, 11, 13, 27],
      'bus': [3, 11, 13],
      'metro': [3, 13],
    },
  ),
  StationNode(
    id: 13,
    name: '伦敦塔',
    x: 0.84,
    y: 0.46,
    edges: {
      'taxi': [12, 19, 20, 27],
      'bus': [12, 19, 20],
      'metro': [11, 12, 19],
      'ferry': [19, 20],
    },
  ),
  StationNode(
    id: 14,
    name: '威斯敏斯特',
    x: 0.38,
    y: 0.56,
    edges: {
      'taxi': [9, 10, 15, 16, 18, 21, 28],
      'bus': [9, 16, 18, 21],
      'metro': [9, 16, 18, 28],
      'ferry': [18, 22],
    },
  ),
  StationNode(
    id: 15,
    name: '白金汉宫',
    x: 0.25,
    y: 0.54,
    edges: {
      'taxi': [8, 14, 16, 17, 25],
      'bus': [16, 25],
    },
  ),
  StationNode(
    id: 16,
    name: '维多利亚',
    x: 0.28,
    y: 0.68,
    edges: {
      'taxi': [14, 15, 17, 21, 22],
      'bus': [6, 9, 14, 15, 17, 22],
      'metro': [8, 9, 14, 18],
    },
  ),
  StationNode(
    id: 17,
    name: '切尔西',
    x: 0.14,
    y: 0.68,
    edges: {
      'taxi': [8, 15, 16, 22, 23],
      'bus': [8, 16, 23],
    },
  ),
  StationNode(
    id: 18,
    name: '滑铁卢',
    x: 0.52,
    y: 0.62,
    edges: {
      'taxi': [10, 14, 19, 21, 24, 28],
      'bus': [10, 14, 19, 21, 24],
      'metro': [14, 16, 19, 28],
      'ferry': [14, 19],
    },
  ),
  StationNode(
    id: 19,
    name: '伦敦桥',
    x: 0.68,
    y: 0.58,
    edges: {
      'taxi': [11, 13, 18, 20, 24, 27],
      'bus': [11, 13, 18, 20, 24],
      'metro': [11, 13, 18],
      'ferry': [13, 18],
    },
  ),
  StationNode(
    id: 20,
    name: '格林威治',
    x: 0.88,
    y: 0.72,
    edges: {
      'taxi': [13, 19, 24],
      'bus': [13, 19, 24],
      'ferry': [13],
    },
  ),
  StationNode(
    id: 21,
    name: '兰贝斯',
    x: 0.44,
    y: 0.78,
    edges: {
      'taxi': [14, 16, 18, 22, 24],
      'bus': [14, 18, 22, 24],
    },
  ),
  StationNode(
    id: 22,
    name: '沃克斯豪尔',
    x: 0.30,
    y: 0.84,
    edges: {
      'taxi': [16, 17, 21, 23],
      'bus': [16, 21, 23],
      'ferry': [14, 23],
    },
  ),
  StationNode(
    id: 23,
    name: '巴特西',
    x: 0.14,
    y: 0.86,
    edges: {
      'taxi': [17, 22],
      'bus': [17, 22],
      'ferry': [22],
    },
  ),
  StationNode(
    id: 24,
    name: '南华克',
    x: 0.62,
    y: 0.78,
    edges: {
      'taxi': [18, 19, 20, 21],
      'bus': [18, 19, 20, 21],
    },
  ),
  StationNode(
    id: 25,
    name: '格林公园',
    x: 0.24,
    y: 0.44,
    edges: {
      'taxi': [6, 8, 9, 15],
      'bus': [15],
    },
  ),
  StationNode(
    id: 26,
    name: '苏豪区',
    x: 0.40,
    y: 0.32,
    edges: {
      'taxi': [4, 5, 9, 10],
    },
  ),
  StationNode(
    id: 27,
    name: '金融城',
    x: 0.74,
    y: 0.38,
    edges: {
      'taxi': [11, 12, 13, 19],
    },
  ),
  StationNode(
    id: 28,
    name: '苏格兰场',
    x: 0.44,
    y: 0.49,
    edges: {
      'taxi': [9, 10, 14, 18],
      'metro': [14, 18],
    },
  ),
];

final Map<int, StationNode> kStationById = {
  for (final s in kLondonStations) s.id: s,
};

class ScotlandYardGame extends GameEngine {
  ScotlandYardGame(super.setup);

  late int maxRounds;
  int round = 1;
  int turn = 0; // 0 = Mister X, 1..players-1 = Detectives
  bool over = false;
  String? winner; // 'misterX' | 'detectives'
  String? winReason;

  /// Current station (1..28) for each seat 0..players-1.
  /// Seat 0 is Mister X; seats 1..players-1 are Detectives.
  late List<int> positions;

  /// Ticket inventory per seat: 'taxi', 'bus', 'metro', 'black', 'double'.
  late List<Map<String, int>> tickets;

  /// Public travel log of Mister X's moves:
  /// {'step': int, 'round': int, 'ticket': String, 'station': int (internal)}
  final List<Map<String, dynamic>> travelLog = [];

  /// Last station where Mister X was publicly revealed (or null if not yet revealed).
  int? lastKnownPos;
  int? lastKnownRound;

  /// Remaining moves for Mister X when using a 'double' ticket (0, 1, or 2).
  int doubleMovesLeft = 0;

  Set<int> get revealRounds => {3, 8, 13, 18, maxRounds};

  bool isRevealRound(int r) => revealRounds.contains(r);

  /// True when [seat] is allowed to see Mister X's live station.
  bool canSeeMisterX(int seat) =>
      over || seat == 0 || isRevealRound(round);

  @override
  void start() {
    maxRounds = setup.opt<int>('maxRounds', setup.opt<int>('rounds', 16));
    round = 1;
    turn = 0;
    over = false;
    winner = null;
    winReason = null;
    travelLog.clear();
    lastKnownPos = null;
    lastKnownRound = null;
    doubleMovesLeft = 0;

    // Pick distinct starting stations: Detectives first, then Mister X at distance >= 2 if possible.
    final pool = shuffled([for (var i = 1; i <= 28; i++) i], rng);
    positions = List.filled(players, 1);
    for (var s = 1; s < players; s++) {
      positions[s] = pool[s];
    }
    final detectiveSet = positions.sublist(1).toSet();
    final safeForX = pool.where((st) {
      if (detectiveSet.contains(st)) return false;
      final node = kStationById[st]!;
      for (final list in node.edges.values) {
        if (list.any(detectiveSet.contains)) return false;
      }
      return true;
    }).toList();
    positions[0] = safeForX.isNotEmpty
        ? safeForX.first
        : pool.firstWhere((st) => !detectiveSet.contains(st));

    final extraTickets = players <= 3;
    tickets = List.generate(players, (s) {
      if (s == 0) {
        return {
          'taxi': 6 + players,
          'bus': 4 + players,
          'metro': 4,
          'black': players,
          'double': 2,
        };
      }
      return {
        'taxi': extraTickets ? 14 : 11,
        'bus': extraTickets ? 10 : 8,
        'metro': extraTickets ? 6 : 4,
        'black': 0,
        'double': 0,
      };
    });

    host.log('苏格兰场追捕开始！X先生潜伏在伦敦某处，刑警共有 $maxRounds 轮时间将其缉拿归案！');
  }

  /// Legal single-step moves for [seat] from [fromStation].
  List<Map<String, dynamic>> legalMovesFor(int seat, {int? fromStation}) {
    if (over) return const [];
    final cur = fromStation ?? positions[seat];
    final node = kStationById[cur];
    if (node == null) return const [];
    final tk = tickets[seat];
    final occupiedByDetectives = <int>{
      for (var s = 1; s < players; s++)
        if (s != seat) positions[s],
    };

    final moves = <Map<String, dynamic>>[];
    final added = <String>{};

    void addMove(int to, String ticket) {
      final key = '$to:$ticket';
      if (added.add(key)) {
        moves.add({'to': to, 'ticket': ticket});
      }
    }

    for (final mode in const ['taxi', 'bus', 'metro']) {
      if ((tk[mode] ?? 0) > 0) {
        for (final nxt in node.edges[mode] ?? const <int>[]) {
          if (occupiedByDetectives.contains(nxt)) continue;
          addMove(nxt, mode);
        }
      }
    }

    if (seat == 0 && (tk['black'] ?? 0) > 0) {
      final allNeighbors = <int>{};
      for (final list in node.edges.values) {
        allNeighbors.addAll(list);
      }
      for (final nxt in allNeighbors) {
        if (occupiedByDetectives.contains(nxt)) continue;
        addMove(nxt, 'black');
      }
    }

    return moves;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前还没轮到你行动');

    final type = asStr(action['type']);
    if (type == 'double' || type == 'use_double') {
      if (seat != 0) throw GameError('只有 X先生 可以使用双倍移动票');
      if (doubleMovesLeft > 0) throw GameError('已经处于双倍移动状态中');
      if ((tickets[0]['double'] ?? 0) <= 0) throw GameError('没有剩余的双倍移动票');
      tickets[0]['double'] = tickets[0]['double']! - 1;
      doubleMovesLeft = 2;
      host.log('X先生 使用了一张【双倍移动票】！本回合将连续移动两次！');
      return;
    }

    if (type != 'move') {
      throw GameError('未知操作类型: $type');
    }

    final to = asInt(action['to']);
    final ticket = asStr(action['ticket']);
    final useDouble = asBool(action['double']);

    if (seat == 0 && useDouble && doubleMovesLeft == 0) {
      if ((tickets[0]['double'] ?? 0) <= 0) throw GameError('没有剩余的双倍移动票');
      tickets[0]['double'] = tickets[0]['double']! - 1;
      doubleMovesLeft = 2;
      host.log('X先生 使用了一张【双倍移动票】！');
    }

    final legal = legalMovesFor(seat);
    final match = legal.any((m) => m['to'] == to && m['ticket'] == ticket);
    if (!match) {
      throw GameError('非法移动：无法使用 $ticket 前往 $to 号站点');
    }

    if (seat == 0) {
      tickets[0][ticket] = tickets[0][ticket]! - 1;
      positions[0] = to;
      travelLog.add({
        'step': travelLog.length + 1,
        'round': round,
        'ticket': ticket,
        'station': to,
      });

      if (isRevealRound(round)) {
        lastKnownPos = to;
        lastKnownRound = round;
        host.log('第 $round 轮【现身轮】：X先生 使用【${_ticketName(ticket)}】现身于 $to 号站（${kStationById[to]?.name}）！');
      } else {
        host.log('第 $round 轮：X先生 使用了【${_ticketName(ticket)}】潜行移动。');
      }

      if (doubleMovesLeft > 1) {
        doubleMovesLeft = 1;
        if (legalMovesFor(0).isNotEmpty) {
          return; // Stay on seat 0 for the second move of double ticket.
        }
        doubleMovesLeft = 0;
      } else {
        doubleMovesLeft = 0;
      }

      _advanceTurn();
    } else {
      tickets[seat][ticket] = tickets[seat][ticket]! - 1;
      tickets[0][ticket] = (tickets[0][ticket] ?? 0) + 1;
      positions[seat] = to;
      host.log('${name(seat)} 乘坐【${_ticketName(ticket)}】前往 $to 号站（${kStationById[to]?.name}）');

      if (positions[seat] == positions[0]) {
        over = true;
        winner = 'detectives';
        lastKnownPos = positions[0];
        lastKnownRound = round;
        winReason = '${name(seat)} 在 $to 号站（${kStationById[to]?.name}）成功抓获了 X先生！苏格兰场刑警获胜！';
        host.log(winReason!);
        return;
      }

      _advanceTurn();
    }
  }

  void _advanceTurn() {
    if (over) return;

    // Try next detective in the current round.
    for (var nextSeat = turn + 1; nextSeat < players; nextSeat++) {
      if (legalMovesFor(nextSeat).isNotEmpty) {
        turn = nextSeat;
        return;
      } else {
        host.log('${name(nextSeat)} 无可用车票或路线，跳过本回合');
      }
    }

    // Check if ALL detectives are completely stuck.
    final anyDetectiveCanMove = [
      for (var s = 1; s < players; s++) legalMovesFor(s).isNotEmpty
    ].any((x) => x);
    if (!anyDetectiveCanMove) {
      over = true;
      winner = 'misterX';
      winReason = '所有刑警均已耗尽可行车票，X先生 逍遥法外获胜！';
      host.log(winReason!);
      return;
    }

    // End of round: check if Mister X survived maxRounds.
    if (round >= maxRounds) {
      over = true;
      winner = 'misterX';
      winReason = '成功坚持完 $maxRounds 轮未被抓获，X先生 逃脱成功获胜！';
      host.log(winReason!);
      return;
    }

    round++;
    turn = 0;
    doubleMovesLeft = 0;
    if (isRevealRound(round)) {
      lastKnownPos = positions[0];
      lastKnownRound = round;
    }

    if (legalMovesFor(0).isEmpty) {
      over = true;
      winner = 'detectives';
      lastKnownPos = positions[0];
      lastKnownRound = round;
      winReason = 'X先生 在 ${positions[0]} 号站被彻底包围無路可逃，苏格兰场刑警获胜！';
      host.log(winReason!);
    }
  }

  String _ticketName(String t) {
    switch (t) {
      case 'taxi':
        return '出租车';
      case 'bus':
        return '巴士';
      case 'metro':
        return '地铁';
      case 'black':
        return '黑票(秘密路线)';
      case 'double':
        return '双倍移动票';
      default:
        return t;
    }
  }

  /// Shortest graph distance (number of hops along any detective-usable edge).
  int graphDist(int a, int b) {
    if (a == b) return 0;
    final visited = <int>{a};
    final queue = <(int, int)>[(a, 0)];
    var head = 0;
    while (head < queue.length) {
      final (cur, d) = queue[head++];
      final node = kStationById[cur]!;
      for (final e in node.edges.entries) {
        if (e.key == 'ferry') continue;
        for (final nxt in e.value) {
          if (nxt == b) return d + 1;
          if (visited.add(nxt)) {
            queue.add((nxt, d + 1));
          }
        }
      }
    }
    return 99;
  }

  /// Computes the set of possible stations Mister X could currently be on
  /// using ONLY public information (`lastKnownPos`, `travelLog`, detective positions).
  Set<int> possibleMisterXStations() {
    if (canSeeMisterX(-1)) return {positions[0]};
    var candidates = <int>{
      if (lastKnownPos != null)
        lastKnownPos!
      else
        for (var i = 1; i <= 28; i++) i,
    };

    // Replay logged moves after the last revealed move.
    var startIdx = 0;
    for (var i = 0; i < travelLog.length; i++) {
      final r = travelLog[i]['round'] as int;
      if (isRevealRound(r)) {
        candidates = {travelLog[i]['station'] as int};
        startIdx = i + 1;
      }
    }

    for (var i = startIdx; i < travelLog.length; i++) {
      final tk = travelLog[i]['ticket'] as String;
      final nextSet = <int>{};
      for (final st in candidates) {
        final node = kStationById[st]!;
        if (tk == 'black') {
          for (final list in node.edges.values) {
            nextSet.addAll(list);
          }
        } else {
          nextSet.addAll(node.edges[tk] ?? const <int>[]);
        }
      }
      if (nextSet.isNotEmpty) candidates = nextSet;
    }

    for (var s = 1; s < players; s++) {
      candidates.remove(positions[s]);
    }
    if (candidates.isEmpty) {
      return {for (var i = 1; i <= 28; i++) i};
    }
    return candidates;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final showX = canSeeMisterX(seat);
    final publicPositions = <int?>[
      showX ? positions[0] : null,
      for (var s = 1; s < players; s++) positions[s],
    ];
    final publicLog = [
      for (final entry in travelLog)
        {
          'step': entry['step'],
          'round': entry['round'],
          'ticket': entry['ticket'],
          'station': (over || seat == 0 || isRevealRound(entry['round'] as int))
              ? entry['station']
              : null,
        },
    ];

    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'over': over,
      'winner': winner,
      'winReason': winReason,
      'misterXPos': showX ? positions[0] : null,
      'lastKnownPos': lastKnownPos,
      'lastKnownRound': lastKnownRound,
      'isReveal': isRevealRound(round),
      'revealRounds': [3, 8, 13, 18, maxRounds],
      'positions': publicPositions,
      'tickets': [
        for (var s = 0; s < players; s++) Map<String, int>.of(tickets[s]),
      ],
      'travelLog': publicLog,
      'doubleMovesLeft': doubleMovesLeft,
      'canUseDouble': seat == 0 &&
          turn == 0 &&
          !over &&
          doubleMovesLeft == 0 &&
          (tickets[0]['double'] ?? 0) > 0,
      'legalMoves': (seat >= 0 && seat == turn && !over)
          ? legalMovesFor(seat)
          : const <Map<String, dynamic>>[],
      'stations': [for (final s in kLondonStations) s.toJson()],
    };
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings {
    if (!over) return null;
    if (winner == 'misterX') {
      return rankWinners(players, const [0]);
    }
    return rankWinners(players, [for (var s = 1; s < players; s++) s]);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = legalMovesFor(seat);
    if (moves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      final pick = moves[rng.nextInt(moves.length)];
      return {'type': 'move', 'to': pick['to'], 'ticket': pick['ticket']};
    }

    if (seat == 0) {
      // Mister X strategy: maximize minimum distance to any Detective.
      int minDetDist(int st) {
        var best = 99;
        for (var s = 1; s < players; s++) {
          final d = graphDist(st, positions[s]);
          if (d < best) best = d;
        }
        return best;
      }

      final curMinDist = minDetDist(positions[0]);
      if (doubleMovesLeft == 0 &&
          (tickets[0]['double'] ?? 0) > 0 &&
          curMinDist <= 1 &&
          botLevel >= 1) {
        return {'type': 'double'};
      }

      Map<String, dynamic> bestMove = moves.first;
      var bestScore = -9999.0;
      for (final m in moves) {
        final to = m['to'] as int;
        final tk = m['ticket'] as String;
        final d = minDetDist(to);
        final degree = kStationById[to]!.edges['taxi']?.length ?? 1;
        var score = d * 10.0 + degree * 0.8 + rng.nextDouble() * 0.3;
        if (tk == 'black') {
          // Save black tickets unless escaping after reveal or using ferry.
          final isFerry =
              (kStationById[positions[0]]!.edges['ferry'] ?? const [])
                  .contains(to);
          if (!isFerry && !isRevealRound(round - 1) && d <= 2) {
            score -= 2.5;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestMove = m;
        }
      }
      return {
        'type': 'move',
        'to': bestMove['to'],
        'ticket': bestMove['ticket'],
      };
    } else {
      // Detective strategy: use ONLY public knowledge (`possibleMisterXStations`).
      final targets = possibleMisterXStations();
      Map<String, dynamic> bestMove = moves.first;
      var bestScore = -9999.0;
      for (final m in moves) {
        final to = m['to'] as int;
        final tk = m['ticket'] as String;
        // Average/min distance to candidate Mister X stations.
        var minD = 99;
        var sumD = 0;
        for (final t in targets) {
          final d = graphDist(to, t);
          if (d < minD) minD = d;
          sumD += d;
        }
        final avgD = sumD / targets.length;
        var score = -minD * 12.0 - avgD * 3.0 + rng.nextDouble() * 0.3;
        if (targets.contains(to)) score += 50.0;
        // Slightly prefer conserving rare metro tickets if distance is same.
        if (tk == 'metro') score -= 0.15;
        if (score > bestScore) {
          bestScore = score;
          bestMove = m;
        }
      }
      return {
        'type': 'move',
        'to': bestMove['to'],
        'ticket': bestMove['ticket'],
      };
    }
  }
}
