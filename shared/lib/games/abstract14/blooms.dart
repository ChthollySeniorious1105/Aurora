import 'dart:math';

import '../../src/engine.dart';

const List<(int, int)> bloomsHexDirs = [
  (1, 0),
  (-1, 0),
  (0, 1),
  (0, -1),
  (1, -1),
  (-1, 1),
];

int bloomsHexDist(int q, int r) {
  return max(q.abs(), max(r.abs(), (q + r).abs()));
}

List<(int, int)> bloomsBoardCellsForRadius(int radius) {
  return [
    for (var q = -radius; q <= radius; q++)
      for (var r = -radius; r <= radius; r++)
        if (bloomsHexDist(q, r) <= radius) (q, r),
  ];
}

class BloomGroup {
  final int color;
  final Set<(int, int)> stones;
  final Set<(int, int)> liberties;

  const BloomGroup({
    required this.color,
    required this.stones,
    required this.liberties,
  });
}

/// 双色花围棋 (Blooms) — Nick Bentley's Dual-Color-per-Player Hexagonal Liberty-Capture game.
class BloomsGame extends GameEngine {
  BloomsGame(super.setup);

  late String mode;
  late int radius;
  late int targetCaptures;
  late int maxTotalTurns;
  late List<(int, int)> boardCells;

  /// Key: (q, r), Value:
  /// 0 = empty
  /// 1 = Player 0 Color 1 (🌸 樱粉)
  /// 2 = Player 0 Color 2 (🌺 赤红)
  /// 3 = Player 1 Color 3 (💠 冰蓝)
  /// 4 = Player 1 Color 4 (🔮 靛紫)
  final Map<(int, int), int> _board = {};

  List<int> captured = [0, 0];
  int turn = 0;
  int turnNumber = 0;
  List<int> placedColorsThisTurn = [];
  List<(int, int)> lastCapturedCells = [];

  bool _over = false;
  int? winner; // 0, 1, or -1 for draw
  String? winReason;
  Map<String, dynamic>? lastMove;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get canResign => true;

  @override
  bool get canDraw => true;

  @override
  List<int>? get placings {
    if (!_over) return null;
    if (winner == null || winner == -1) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  static List<int> colorsOfSeat(int seat) =>
      seat == 0 ? const [1, 2] : const [3, 4];

  static int ownerOfColor(int color) {
    if (color == 1 || color == 2) return 0;
    if (color == 3 || color == 4) return 1;
    return -1;
  }

  static String colorLabel(int color) {
    switch (color) {
      case 1:
        return '🌸 樱粉';
      case 2:
        return '🌺 赤红';
      case 3:
        return '💠 冰蓝';
      case 4:
        return '🔮 靛紫';
      default:
        return '空';
    }
  }

  bool isValidHex(int q, int r) => bloomsHexDist(q, r) <= radius;

  int stoneAt(int q, int r) => _board[(q, r)] ?? 0;

  void setStoneAt(int q, int r, int color) {
    if (isValidHex(q, r)) {
      _board[(q, r)] = color;
    }
  }

  int get maxPlacementsThisTurn => turnNumber == 0 ? 1 : 2;

  List<int> availableColorsForCurrentTurn() {
    final myColors = colorsOfSeat(turn);
    if (placedColorsThisTurn.isEmpty) return myColors;
    if (placedColorsThisTurn.length >= maxPlacementsThisTurn) return const [];
    return [
      for (final c in myColors)
        if (!placedColorsThisTurn.contains(c)) c,
    ];
  }

  @override
  void start() {
    mode = setup.opt<String>('mode', 'standard');
    radius = mode == 'quick' ? 3 : 4;
    targetCaptures = mode == 'quick' ? 10 : 15;
    maxTotalTurns = mode == 'quick' ? 140 : 220;
    boardCells = bloomsBoardCellsForRadius(radius);
    _board.clear();
    for (final cell in boardCells) {
      _board[cell] = 0;
    }
    captured = [0, 0];
    turn = 0;
    turnNumber = 0;
    placedColorsThisTurn = [];
    lastCapturedCells = [];
    _over = false;
    winner = null;
    winReason = null;
    lastMove = null;
  }

  @override
  void resign(int seat) {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜！';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = -1;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  /// Flood-fill the single-color Bloom containing `(startQ, startR)`.
  BloomGroup? inspectBloom(int startQ, int startR) {
    if (!isValidHex(startQ, startR)) return null;
    final color = stoneAt(startQ, startR);
    if (color == 0) return null;

    final stones = <(int, int)>{(startQ, startR)};
    final liberties = <(int, int)>{};
    final queue = <(int, int)>[(startQ, startR)];

    while (queue.isNotEmpty) {
      final (q, r) = queue.removeLast();
      for (final (dq, dr) in bloomsHexDirs) {
        final nq = q + dq;
        final nr = r + dr;
        if (!isValidHex(nq, nr)) continue;
        final nc = stoneAt(nq, nr);
        if (nc == 0) {
          liberties.add((nq, nr));
        } else if (nc == color && stones.add((nq, nr))) {
          queue.add((nq, nr));
        }
      }
    }

    return BloomGroup(color: color, stones: stones, liberties: liberties);
  }

  /// Find and remove all enemy Blooms (owned by `1 - seat`) that have `0` liberties.
  /// Returns the list of captured cell coordinates.
  List<(int, int)> captureDeadEnemyBlooms(int seat) {
    final oppSeat = 1 - seat;
    final visited = <(int, int)>{};
    final toRemove = <(int, int)>[];

    for (final (q, r) in boardCells) {
      if (visited.contains((q, r))) continue;
      final c = stoneAt(q, r);
      if (ownerOfColor(c) != oppSeat) continue;

      final bloom = inspectBloom(q, r);
      if (bloom == null) continue;
      visited.addAll(bloom.stones);
      if (bloom.liberties.isEmpty) {
        toRemove.addAll(bloom.stones);
      }
    }

    for (final cell in toRemove) {
      _board[cell] = 0;
    }
    captured[seat] += toRemove.length;
    return toRemove;
  }

  bool get hasEmptyHex => _board.values.any((v) => v == 0);

  void _finishCurrentTurn(int seat) {
    // Capture any remaining 0-liberty enemy blooms at end of turn
    final extraCaptured = captureDeadEnemyBlooms(seat);
    if (extraCaptured.isNotEmpty) {
      lastCapturedCells.addAll(extraCaptured);
    }

    if (captured[seat] >= targetCaptures) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 累计围杀 ${captured[seat]} 颗敌方花子（达标 $targetCaptures 颗），大获全胜！';
      host.log(winReason!);
      return;
    }

    turnNumber++;
    placedColorsThisTurn = [];

    if (!hasEmptyHex || turnNumber >= maxTotalTurns) {
      _adjudicate();
      return;
    }

    turn = 1 - seat;
  }

  void _adjudicate() {
    _over = true;
    final c0 = captured[0];
    final c1 = captured[1];
    if (c0 != c1) {
      winner = c0 > c1 ? 0 : 1;
      winReason = '对局结束：${name(winner!)} 俘获更多敌方花子（$c0 : $c1）获胜！';
    } else {
      var s0 = 0;
      var s1 = 0;
      for (final v in _board.values) {
        if (ownerOfColor(v) == 0) s0++;
        if (ownerOfColor(v) == 1) s1++;
      }
      if (s0 != s1) {
        winner = s0 > s1 ? 0 : 1;
        winReason = '对局结束：${name(winner!)} 盘面花子更多（$s0 : $s1）获胜！';
      } else {
        winner = -1;
        winReason = '对局结束：双方俘获与盘面子数均相同，平局！';
      }
    }
    host.log(winReason!);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你行动');

    final type = asStr(action['type']);

    if (type == 'end_turn' || type == 'pass') {
      if (placedColorsThisTurn.isEmpty) {
        throw GameError('本回合至少需要放置 1 颗花子才能结束回合');
      }
      lastMove = {
        'type': 'end_turn',
        'seat': seat,
      };
      _finishCurrentTurn(seat);
      return;
    }

    if (type != 'place') {
      throw GameError('未知操作类型：$type');
    }

    final q = asInt(action['q'], 999);
    final r = asInt(action['r'], 999);
    final color = asInt(action['color'], -1);

    if (!isValidHex(q, r)) {
      throw GameError('落子坐标超出棋盘范围');
    }
    if (stoneAt(q, r) != 0) {
      throw GameError('该六角格已有花子');
    }

    final myColors = colorsOfSeat(seat);
    if (!myColors.contains(color)) {
      throw GameError('只能使用属于你的两种花色（${myColors.map(colorLabel).join(' / ')}）');
    }
    if (placedColorsThisTurn.contains(color)) {
      throw GameError('同一回合放置两颗花子时必须使用不同颜色！');
    }
    if (placedColorsThisTurn.length >= maxPlacementsThisTurn) {
      throw GameError('本回合落子次数已满');
    }

    if (placedColorsThisTurn.isEmpty) {
      lastCapturedCells = [];
    }

    _board[(q, r)] = color;
    placedColorsThisTurn.add(color);

    // Immediately capture any enemy Blooms that now have 0 liberties
    final newlyCaptured = captureDeadEnemyBlooms(seat);
    if (newlyCaptured.isNotEmpty) {
      lastCapturedCells.addAll(newlyCaptured);
    }

    lastMove = {
      'type': 'place',
      'seat': seat,
      'q': q,
      'r': r,
      'color': color,
      'capturedCount': newlyCaptured.length,
    };

    if (captured[seat] >= targetCaptures) {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 累计围杀 ${captured[seat]} 颗敌方花子（达标 $targetCaptures 颗），大获全胜！';
      host.log(winReason!);
      return;
    }

    if (placedColorsThisTurn.length >= maxPlacementsThisTurn || !hasEmptyHex) {
      _finishCurrentTurn(seat);
    }
  }

  /// Evaluate placing [color] at `(q, r)` for [seat].
  double _scorePlacement(int seat, int q, int r, int color) {
    final oppSeat = 1 - seat;
    _board[(q, r)] = color;

    // Count how many enemy stones would be immediately captured, and how many
    // enemy blooms are reduced to 1 or 2 liberties.
    var immediateCaps = 0;
    var atariPressure = 0.0;
    final visited = <(int, int)>{};

    for (final (dq, dr) in bloomsHexDirs) {
      final nq = q + dq;
      final nr = r + dr;
      if (!isValidHex(nq, nr) || visited.contains((nq, nr))) continue;
      final nc = stoneAt(nq, nr);
      if (ownerOfColor(nc) == oppSeat) {
        final b = inspectBloom(nq, nr);
        if (b != null) {
          visited.addAll(b.stones);
          if (b.liberties.isEmpty) {
            immediateCaps += b.stones.length;
          } else if (b.liberties.length == 1) {
            atariPressure += b.stones.length * 14.0;
          } else if (b.liberties.length == 2) {
            atariPressure += b.stones.length * 4.5;
          }
        }
      }
    }

    // Check own bloom liberties after placement
    final myBloom = inspectBloom(q, r);
    final myLibs = myBloom?.liberties.length ?? 0;

    _board[(q, r)] = 0;

    // If this placement doesn't capture anything and leaves our own bloom with 0 liberties,
    // it's self-capture on the opponent's turn — heavily penalize!
    if (immediateCaps == 0 && myLibs == 0) {
      return -200.0;
    }

    // Check if placing here saves an adjacent friendly bloom of [color] that only had 1 liberty
    var rescueBonus = 0.0;
    if (myLibs >= 2) {
      for (final (dq, dr) in bloomsHexDirs) {
        final nq = q + dq;
        final nr = r + dr;
        if (isValidHex(nq, nr) && stoneAt(nq, nr) == color) {
          final existing = inspectBloom(nq, nr);
          if (existing != null && existing.liberties.length == 1) {
            rescueBonus += existing.stones.length * 10.0;
          }
        }
      }
    }

    final centerBonus = (radius - bloomsHexDist(q, r)) * 0.9;
    final libBonus = min(myLibs, 4) * 1.6;
    return immediateCaps * 80.0 +
        atariPressure +
        rescueBonus +
        libBonus +
        centerBonus +
        rng.nextDouble() * 1.5;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final availColors = availableColorsForCurrentTurn();
    final emptyCells = <(int, int)>[
      for (final cell in boardCells)
        if (stoneAt(cell.$1, cell.$2) == 0) cell,
    ];

    if (availColors.isEmpty || emptyCells.isEmpty) {
      if (placedColorsThisTurn.isNotEmpty) {
        return {'type': 'end_turn'};
      }
      return null;
    }

    if (botLevel == 0 && rng.nextDouble() < 0.35) {
      final pickCell = emptyCells[rng.nextInt(emptyCells.length)];
      final pickColor = availColors[rng.nextInt(availColors.length)];
      return {
        'type': 'place',
        'q': pickCell.$1,
        'r': pickCell.$2,
        'color': pickColor,
      };
    }

    (int, int, int)? bestMove;
    var bestScore = double.negativeInfinity;

    for (final c in availColors) {
      for (final (q, r) in emptyCells) {
        final s = _scorePlacement(seat, q, r, c);
        if (s > bestScore) {
          bestScore = s;
          bestMove = (q, r, c);
        }
      }
    }

    // If we already placed 1 stone this turn and every possible 2nd placement is self-atari (< -50), end turn!
    if (placedColorsThisTurn.isNotEmpty && bestScore < -50.0) {
      return {'type': 'end_turn'};
    }

    final chosen = bestMove ?? (emptyCells.first.$1, emptyCells.first.$2, availColors.first);
    return {
      'type': 'place',
      'q': chosen.$1,
      'r': chosen.$2,
      'color': chosen.$3,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    // Compute liberties per stone for visual clarity on the board
    final libertiesMap = <(int, int), int>{};
    final visited = <(int, int)>{};
    for (final (q, r) in boardCells) {
      if (visited.contains((q, r))) continue;
      final c = stoneAt(q, r);
      if (c == 0) continue;
      final b = inspectBloom(q, r);
      if (b != null) {
        visited.addAll(b.stones);
        for (final pos in b.stones) {
          libertiesMap[pos] = b.liberties.length;
        }
      }
    }

    final cellViews = <Map<String, dynamic>>[
      for (final (q, r) in boardCells)
        {
          'q': q,
          'r': r,
          'color': stoneAt(q, r),
          'liberties': libertiesMap[(q, r)] ?? 0,
        },
    ];

    return {
      'mode': mode,
      'radius': radius,
      'targetCaptures': targetCaptures,
      'turn': turn,
      'turnNumber': turnNumber,
      'maxPlacementsThisTurn': maxPlacementsThisTurn,
      'placedColorsThisTurn': List<int>.of(placedColorsThisTurn),
      'availableColors': !_over ? availableColorsForCurrentTurn() : const <int>[],
      'canEndTurn': !_over && placedColorsThisTurn.isNotEmpty,
      'captured': List<int>.of(captured),
      'lastCapturedCells': [
        for (final (q, r) in lastCapturedCells) [q, r],
      ],
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'cells': cellViews,
      'lastMove': lastMove,
    };
  }
}
