import 'dart:math';

import '../../src/engine.dart';

/// 6 colors: 0 红, 1 橙, 2 黄, 3 绿, 4 蓝, 5 紫
const List<String> qwirkleColorNames = ['红', '橙', '黄', '绿', '蓝', '紫'];

/// 6 shapes: 0 圆形, 1 四角星, 2 菱形, 3 方形, 4 八角星, 5 四叶草
const List<String> qwirkleShapeNames = ['圆形', '四角星', '菱形', '方形', '八角星', '四叶草'];

int qwirkleTile(int color, int shape) => color * 6 + shape;
int qwirkleColor(int tile) => tile ~/ 6;
int qwirkleShape(int tile) => tile % 6;

String qwirkleTileLabel(int tile) =>
    '${qwirkleColorNames[qwirkleColor(tile)]}${qwirkleShapeNames[qwirkleShape(tile)]}';

int parseQwirkleTile(Object? raw) {
  if (raw is int) return raw;
  if (raw is num && raw.isFinite) return raw.toInt();
  if (raw is Map) {
    final c = asInt(raw['color'], -1);
    final s = asInt(raw['shape'], -1);
    if (c >= 0 && c < 6 && s >= 0 && s < 6) return qwirkleTile(c, s);
  }
  if (raw is String) {
    final p = int.tryParse(raw);
    if (p != null) return p;
    final parts = raw.split(':');
    if (parts.length == 2) {
      final c = int.tryParse(parts[0]) ?? -1;
      final s = int.tryParse(parts[1]) ?? -1;
      if (c >= 0 && c < 6 && s >= 0 && s < 6) return qwirkleTile(c, s);
    }
  }
  return -1;
}

const qwirkleRules = '''
# 概述
《形色牌》（Qwirkle）是一款斩获德国年度游戏大奖（Spiel des Jahres）的经典抽象拼接桌游，支持 2~4 人游玩。牌袋中包含 6 种颜色（红、橙、黄、绿、蓝、紫）× 6 种形状（圆形、四角星、菱形、方形、八角星、四叶草）共 36 种不同的牌，每种牌有 3 张（标准 108 张）或 2 张（快速 72 张）。每位玩家手牌上限为 6 张。

# 回合行动
轮到你时，必须从以下行动中二选一：
- 放置拼接（place）：从手中打出 1~6 张牌到棋盘上。同一次打出的所有牌必须位于【同一行或同一列】，与棋盘上已有的牌正交相连，且新牌之间不能有空格断开（中间允许夹有棋盘原本已有的牌）。
- 换牌（swap）：若不想或无法出牌且牌袋非空，可选择手中 1~6 张牌放回牌袋并抽取相同数量的新牌（本回合得 0 分）。若牌袋已空且无法出牌，可选择跳过（pass）。

# 拼接合法性规则
- 棋盘上每一条长度 ≥ 2 的正交连续直线（横向或纵向），必须满足以下二者之一：
  1. 【同色异形】：整条线所有牌颜色完全相同，且形状各不相同（无重复形状）；
  2. 【同形异色】：整条线所有牌形状完全相同，且颜色各不相同（无重复颜色）。
- 因此，任何一条连续直线的最大长度不会超过 6 张。

# 计分与终局
- 每次出牌后，统计所有被本次出牌新建或延长的正交连续线（长度 ≥ 2）：每条线中有几张牌就得几分（已有的牌也会再次计入该线长度得分）。
- 【Qwirkle 奖励】：任何一条连续线达到完整的 6 张牌时，除了基础 6 分外额外获得 +6 分奖励，单线共得 12 分！
- 摸牌补充至 6 张。当牌袋摸空后，第一位出完所有手牌的玩家额外获得 +6 分收官奖励，游戏立即结束，总分最高者获胜！
''';

/// Checks whether a contiguous line of tiles satisfies Qwirkle's rule.
bool qwirkleIsValidLine(List<int> tiles) {
  if (tiles.isEmpty || tiles.length > 6) return false;
  if (tiles.any((t) => t < 0 || t >= 36)) return false;
  if (tiles.length == 1) return true;
  final colors = <int>{};
  final shapes = <int>{};
  for (final t in tiles) {
    colors.add(qwirkleColor(t));
    shapes.add(qwirkleShape(t));
  }
  final sameColorDistinctShape = colors.length == 1 && shapes.length == tiles.length;
  final sameShapeDistinctColor = shapes.length == 1 && colors.length == tiles.length;
  return sameColorDistinctShape || sameShapeDistinctColor;
}

class QwirkleEval {
  final bool valid;
  final String? error;
  final int score;
  final int qwirkles;
  const QwirkleEval({
    required this.valid,
    this.error,
    this.score = 0,
    this.qwirkles = 0,
  });
}

/// Validates a placement on [board] and computes its exact Qwirkle score.
QwirkleEval qwirkleValidateAndScore(
  Map<(int, int), int> board,
  List<({int r, int c, int tile})> placements,
) {
  if (placements.isEmpty || placements.length > 6) {
    return const QwirkleEval(valid: false, error: '每次必须放置 1~6 张牌');
  }
  final seenPos = <(int, int)>{};
  for (final p in placements) {
    if (p.tile < 0 || p.tile >= 36) {
      return const QwirkleEval(valid: false, error: '无效的牌面编码');
    }
    if (!seenPos.add((p.r, p.c))) {
      return const QwirkleEval(valid: false, error: '不能在同一个格子放置多张牌');
    }
    if (board.containsKey((p.r, p.c))) {
      return const QwirkleEval(valid: false, error: '目标格子已有牌');
    }
  }

  final sameRow = placements.every((p) => p.r == placements.first.r);
  final sameCol = placements.every((p) => p.c == placements.first.c);
  if (!sameRow && !sameCol) {
    return const QwirkleEval(valid: false, error: '同一回合放置的所有牌必须在同一行或同一列');
  }

  if (board.isNotEmpty) {
    var touchesExisting = false;
    for (final p in placements) {
      if (board.containsKey((p.r - 1, p.c)) ||
          board.containsKey((p.r + 1, p.c)) ||
          board.containsKey((p.r, p.c - 1)) ||
          board.containsKey((p.r, p.c + 1))) {
        touchesExisting = true;
        break;
      }
    }
    if (!touchesExisting) {
      return const QwirkleEval(valid: false, error: '放置的牌必须与棋盘已有牌正交相邻');
    }
  }

  final temp = <(int, int), int>{
    ...board,
    for (final p in placements) (p.r, p.c): p.tile,
  };

  if (placements.length >= 2) {
    if (sameRow) {
      final r = placements.first.r;
      final minC = placements.map((p) => p.c).reduce(min);
      final maxC = placements.map((p) => p.c).reduce(max);
      for (var c = minC; c <= maxC; c++) {
        if (!temp.containsKey((r, c))) {
          return const QwirkleEval(valid: false, error: '同行放置的牌必须连续，中间不能有空格');
        }
      }
    } else {
      final c = placements.first.c;
      final minR = placements.map((p) => p.r).reduce(min);
      final maxR = placements.map((p) => p.r).reduce(max);
      for (var r = minR; r <= maxR; r++) {
        if (!temp.containsKey((r, c))) {
          return const QwirkleEval(valid: false, error: '同列放置的牌必须连续，中间不能有空格');
        }
      }
    }
  }

  // Gather all maximal orthogonal lines of length >= 2 containing any placed tile
  final scoredLines = <String, List<int>>{};
  for (final p in placements) {
    // Horizontal
    var c0 = p.c;
    while (temp.containsKey((p.r, c0 - 1))) {
      c0--;
    }
    var c1 = p.c;
    while (temp.containsKey((p.r, c1 + 1))) {
      c1++;
    }
    if (c1 > c0) {
      final key = 'H:${p.r}:$c0:$c1';
      scoredLines.putIfAbsent(key, () => [for (var x = c0; x <= c1; x++) temp[(p.r, x)]!]);
    }

    // Vertical
    var r0 = p.r;
    while (temp.containsKey((r0 - 1, p.c))) {
      r0--;
    }
    var r1 = p.r;
    while (temp.containsKey((r1 + 1, p.c))) {
      r1++;
    }
    if (r1 > r0) {
      final key = 'V:${p.c}:$r0:$r1';
      scoredLines.putIfAbsent(key, () => [for (var y = r0; y <= r1; y++) temp[(y, p.c)]!]);
    }
  }

  for (final line in scoredLines.values) {
    if (!qwirkleIsValidLine(line)) {
      return const QwirkleEval(
        valid: false,
        error: '每条正交线上的牌必须同色异形或同形异色，且不能出现重复牌',
      );
    }
  }

  if (scoredLines.isEmpty) {
    // First turn single tile on empty board
    return const QwirkleEval(valid: true, score: 1, qwirkles: 0);
  }

  var score = 0;
  var qwirkles = 0;
  for (final line in scoredLines.values) {
    score += line.length;
    if (line.length == 6) {
      score += 6;
      qwirkles++;
    }
  }
  return QwirkleEval(valid: true, score: score, qwirkles: qwirkles);
}

class QwirkleGame extends GameEngine {
  QwirkleGame(super.setup);

  late int copies = setup.opt<int>('copies', 3);
  List<int> bag = [];
  late List<List<int>> hands = [for (var s = 0; s < players; s++) <int>[]];
  late List<int> scores = List.filled(players, 0);
  Map<(int, int), int> board = {};
  int turn = 0;
  bool over = false;
  int consecutiveNoPlace = 0;
  Map<String, dynamic>? lastMove;
  final List<String> logs = [];

  void _say(String text) {
    logs.add(text);
    if (logs.length > 40) logs.removeAt(0);
    host.log(text);
  }

  void _refillHand(int seat) {
    while (hands[seat].length < 6 && bag.isNotEmpty) {
      hands[seat].add(bag.removeLast());
    }
  }

  @override
  void start() {
    bag = shuffled([
      for (var copy = 0; copy < copies; copy++)
        for (var t = 0; t < 36; t++) t
    ], rng);
    for (var s = 0; s < players; s++) {
      _refillHand(s);
    }
    turn = rng.nextInt(players);
    _say('形色牌 Qwirkle 开始！牌袋共 ${bag.length} 张余牌，${name(turn)} 先手。');
  }

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(scores) : null;

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你操作');

    final type = asStr(action['type']);
    if (type == 'place') {
      final rawList = action['placements'];
      if (rawList is! List || rawList.isEmpty || rawList.length > 6) {
        throw GameError('请选择 1~6 张手牌放置在棋盘上');
      }
      final placements = <({int r, int c, int tile})>[];
      final tempHand = List.of(hands[seat]);
      for (final item in rawList) {
        if (item is! Map) throw GameError('放置格式错误');
        final r = asInt(item['r'], 999999);
        final c = asInt(item['c'], 999999);
        final tile = parseQwirkleTile(item['tile']);
        if (r == 999999 || c == 999999 || tile < 0 || tile >= 36) {
          throw GameError('放置坐标或牌面无效');
        }
        final handIdx = tempHand.indexOf(tile);
        if (handIdx < 0) {
          throw GameError('你手中没有要放置的牌：${qwirkleTileLabel(tile)}');
        }
        tempHand.removeAt(handIdx);
        placements.add((r: r, c: c, tile: tile));
      }

      final eval = qwirkleValidateAndScore(board, placements);
      if (!eval.valid) {
        throw GameError(eval.error ?? '放置不符合形色牌规则');
      }

      for (final p in placements) {
        board[(p.r, p.c)] = p.tile;
      }
      hands[seat] = tempHand;
      scores[seat] += eval.score;
      _refillHand(seat);
      consecutiveNoPlace = 0;

      final qText = eval.qwirkles > 0 ? '（达成 Qwirkle +${eval.qwirkles * 6} 分！）' : '';
      lastMove = {
        'type': 'place',
        'seat': seat,
        'score': eval.score,
        'qwirkles': eval.qwirkles,
        'placements': [
          for (final p in placements) {'r': p.r, 'c': p.c, 'tile': p.tile}
        ],
      };
      _say('${name(seat)} 放置了 ${placements.length} 张牌，获得 ${eval.score} 分$qText');

      if (hands[seat].isEmpty && bag.isEmpty) {
        scores[seat] += 6;
        over = true;
        final best = scores.reduce(max);
        final winners = [for (var s = 0; s < players; s++) if (scores[s] == best) name(s)].join('、');
        _say('${name(seat)} 率先出完手牌获得 +6 分奖励！游戏结束，$winners 以 $best 分获胜！');
        return;
      }

      _advanceTurn();
      return;
    }

    if (type == 'swap') {
      if (bag.isEmpty) {
        throw GameError('牌袋已空，无法换牌，请出牌或选择跳过（pass）');
      }
      final indices = asIntList(action['indices']);
      if (indices.isEmpty || indices.length > hands[seat].length) {
        throw GameError('请选择要交换的手牌');
      }
      final uniqueIndices = indices.toSet().toList()..sort((a, b) => b.compareTo(a));
      if (uniqueIndices.length != indices.length ||
          uniqueIndices.any((i) => i < 0 || i >= hands[seat].length)) {
        throw GameError('换牌索引无效');
      }

      final removed = <int>[];
      for (final idx in uniqueIndices) {
        removed.add(hands[seat].removeAt(idx));
      }
      final drawCount = min(removed.length, bag.length);
      for (var i = 0; i < drawCount; i++) {
        hands[seat].add(bag.removeLast());
      }
      bag.addAll(removed);
      bag.shuffle(rng);
      while (hands[seat].length < 6 && bag.isNotEmpty) {
        hands[seat].add(bag.removeLast());
      }

      consecutiveNoPlace++;
      lastMove = {
        'type': 'swap',
        'seat': seat,
        'count': removed.length,
      };
      _say('${name(seat)} 交换了 ${removed.length} 张手牌');
      if (consecutiveNoPlace >= players * 3) {
        _finishByStalemate();
        return;
      }
      _advanceTurn();
      return;
    }

    if (type == 'pass') {
      if (bag.isNotEmpty) {
        throw GameError('牌袋尚有余牌时不能直接跳过，请出牌或换牌');
      }
      consecutiveNoPlace++;
      lastMove = {'type': 'pass', 'seat': seat};
      _say('${name(seat)} 跳过回合');
      if (consecutiveNoPlace >= players) {
        _finishByStalemate();
        return;
      }
      _advanceTurn();
      return;
    }

    throw GameError('未知操作类型');
  }

  void _advanceTurn() {
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (hands[next].isNotEmpty) {
        turn = next;
        return;
      }
    }
    _finishByStalemate();
  }

  void _finishByStalemate() {
    over = true;
    final best = scores.reduce(max);
    final winners = [for (var s = 0; s < players; s++) if (scores[s] == best) name(s)].join('、');
    _say('无人可继续出牌，游戏结束！$winners 以 $best 分获胜！');
  }

  @override
  Map<String, dynamic> view(int seat) {
    var minR = 0, maxR = 0, minC = 0, maxC = 0;
    if (board.isNotEmpty) {
      minR = board.keys.map((k) => k.$1).reduce(min);
      maxR = board.keys.map((k) => k.$1).reduce(max);
      minC = board.keys.map((k) => k.$2).reduce(min);
      maxC = board.keys.map((k) => k.$2).reduce(max);
    }
    return {
      'players': players,
      'turn': turn,
      'bagCount': bag.length,
      'scores': scores,
      'handCounts': [for (var s = 0; s < players; s++) hands[s].length],
      'hand': seat >= 0 && seat < players ? List.of(hands[seat]) : const <int>[],
      'board': {for (final e in board.entries) '${e.key.$1},${e.key.$2}': e.value},
      'boardCells': [
        for (final e in board.entries) {'r': e.key.$1, 'c': e.key.$2, 'tile': e.value}
      ],
      'bounds': {'minR': minR, 'maxR': maxR, 'minC': minC, 'maxC': maxC},
      'lastMove': lastMove,
      'over': over,
      'log': logs.length > 12 ? logs.sublist(logs.length - 12) : List.of(logs),
    };
  }

  // ------------------------------------------------------------------ Bot
  List<({List<({int r, int c, int tile})> placements, int score})> findCandidateMoves(int seat) {
    final hand = hands[seat];
    if (hand.isEmpty) return const [];

    if (board.isEmpty) {
      // Find best initial line from hand placed at (0, 0), (0, 1)...
      final candidates = <({List<({int r, int c, int tile})> placements, int score})>[];
      // Group by color (distinct shapes)
      for (var c = 0; c < 6; c++) {
        final byShape = <int, int>{};
        for (final t in hand) {
          if (qwirkleColor(t) == c) byShape[qwirkleShape(t)] = t;
        }
        if (byShape.isNotEmpty) {
          final tiles = byShape.values.toList();
          final p = [for (var i = 0; i < tiles.length; i++) (r: 0, c: i, tile: tiles[i])];
          final ev = qwirkleValidateAndScore(board, p);
          if (ev.valid) candidates.add((placements: p, score: ev.score));
        }
      }
      // Group by shape (distinct colors)
      for (var s = 0; s < 6; s++) {
        final byColor = <int, int>{};
        for (final t in hand) {
          if (qwirkleShape(t) == s) byColor[qwirkleColor(t)] = t;
        }
        if (byColor.isNotEmpty) {
          final tiles = byColor.values.toList();
          final p = [for (var i = 0; i < tiles.length; i++) (r: 0, c: i, tile: tiles[i])];
          final ev = qwirkleValidateAndScore(board, p);
          if (ev.valid) candidates.add((placements: p, score: ev.score));
        }
      }
      return candidates;
    }

    // Collect empty cells orthogonally adjacent to existing tiles
    final anchors = <(int, int)>{};
    for (final (r, c) in board.keys) {
      for (final (dr, dc) in const [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
        final nr = r + dr;
        final nc = c + dc;
        if (!board.containsKey((nr, nc))) {
          anchors.add((nr, nc));
        }
      }
    }

    final candidates = <({List<({int r, int c, int tile})> placements, int score})>[];
    final uniqueHandTiles = hand.toSet().toList();

    for (final (ar, ac) in anchors) {
      for (final firstTile in uniqueHandTiles) {
        final single = [(r: ar, c: ac, tile: firstTile)];
        final ev1 = qwirkleValidateAndScore(board, single);
        if (!ev1.valid) continue;
        candidates.add((placements: single, score: ev1.score));

        if (botLevel == 0) continue; // Simple bot mostly plays 1 tile

        // Try extending horizontally (+c) and vertically (+r) with remaining hand tiles
        final remHand = List.of(hand)..remove(firstTile);
        for (final (dr, dc) in const [(0, 1), (1, 0), (0, -1), (-1, 0)]) {
          var curPlacements = List.of(single);
          var pool = List.of(remHand);
          var step = 1;
          while (pool.isNotEmpty && step <= 5) {
            final nr = ar + dr * step;
            final nc = ac + dc * step;
            step++;
            if (board.containsKey((nr, nc))) continue; // skip existing tile in contiguous line
            int? matchedTile;
            QwirkleEval? matchedEval;
            for (final t in pool.toSet()) {
              if (qwirkleColor(t) != qwirkleColor(firstTile) &&
                  qwirkleShape(t) != qwirkleShape(firstTile)) {
                continue;
              }
              final nextP = [...curPlacements, (r: nr, c: nc, tile: t)];
              final ev = qwirkleValidateAndScore(board, nextP);
              if (ev.valid) {
                matchedTile = t;
                matchedEval = ev;
                break;
              }
            }
            if (matchedTile != null && matchedEval != null) {
              curPlacements = [...curPlacements, (r: nr, c: nc, tile: matchedTile)];
              pool.remove(matchedTile);
              candidates.add((placements: curPlacements, score: matchedEval.score));
            } else {
              break;
            }
          }
        }
      }
    }
    return candidates;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;
    final moves = findCandidateMoves(seat);
    if (moves.isNotEmpty) {
      moves.sort((a, b) => b.score.compareTo(a.score));
      final chosen = botLevel == 0
          ? moves[rng.nextInt(moves.length)]
          : (botLevel == 1 && moves.length > 2
              ? moves[rng.nextInt(min(3, moves.length))]
              : moves.first);
      return {
        'type': 'place',
        'placements': [
          for (final p in chosen.placements) {'r': p.r, 'c': p.c, 'tile': p.tile}
        ],
      };
    }

    if (bag.isNotEmpty) {
      final count = min(hands[seat].length, max(1, min(3, bag.length)));
      return {
        'type': 'swap',
        'indices': [for (var i = 0; i < count; i++) i],
      };
    }
    return {'type': 'pass'};
  }
}
