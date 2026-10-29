import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

const List<String> marrakechDirNames = ['北', '东', '南', '西'];
const List<String> marrakechDirArrows = ['⬆️', '➡️', '⬇️', '⬅️'];

const List<String> marrakechPlayerColorNames = ['红毯商', '蓝毯商', '绿毯商', '紫毯商'];
const List<String> marrakechPlayerEmojis = ['🟥', '🟦', '🟩', '🟪'];

class MarrakechRugCell {
  final int owner; // 0..players-1
  final int rugId; // 1..N

  const MarrakechRugCell({
    required this.owner,
    required this.rugId,
  });

  Map<String, dynamic> toJson() => {
        'owner': owner,
        'rugId': rugId,
        'emoji': marrakechPlayerEmojis[owner % marrakechPlayerEmojis.length],
      };
}

class MarrakechGame extends GameEngine {
  static const int size = 7;
  static const List<int> slipperFaces = [1, 2, 2, 3, 3, 4];

  // Directions: 0 = North (-1, 0), 1 = East (0, +1), 2 = South (+1, 0), 3 = West (0, -1)
  static const List<(int, int)> dirs = [
    (-1, 0),
    (0, 1),
    (1, 0),
    (0, -1),
  ];

  late final int rugsPerPlayer;

  /// 7x7 bazaar grid (`grid[r][c]`). Null if no rug covers `(r, c)`.
  late List<List<MarrakechRugCell?>> grid;

  int assamR = 3;
  int assamC = 3;
  int assamDir = 0; // 0=N, 1=E, 2=S, 3=W

  late List<int> coins;
  late List<int> rugsLeft;
  late List<int> score;

  int nextRugId = 0;
  int round = 1;
  int turn = 0;
  String phase = 'orient'; // 'orient' -> 'place'
  int lastRoll = 0;
  int lastTribute = 0;
  int lastTributeTo = -1;
  List<(int, int)> lastAssamPath = const [];
  bool over = false;
  String lastAction = '摩洛哥集市开市，阿萨姆立于中央 (3,3)';

  MarrakechGame(super.setup) : rugsPerPlayer = setup.opt<int>('rugsPerPlayer', 12);

  @override
  bool get isOver => over;

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  List<int>? get placings => over ? rankByScore(score) : null;

  @override
  void start() {
    grid = List.generate(
      size,
      (_) => List.filled(size, null),
    );
    assamR = 3;
    assamC = 3;
    assamDir = 0;

    coins = List.filled(players, 30);
    rugsLeft = List.filled(players, rugsPerPlayer);
    score = List.filled(players, 30);

    nextRugId = 0;
    round = 1;
    turn = 0;
    phase = 'orient';
    lastRoll = 0;
    lastTribute = 0;
    lastTributeTo = -1;
    lastAssamPath = [(3, 3)];
    over = false;
    lastAction = '第 1 轮开始，请为阿萨姆选择前进方向（直行/左转/右转，不可掉头）';
  }

  /// Advances Assam by 1 step from `(r, c)` facing `dir`, following Marrakech's
  /// border U-turn tracks when stepping off the 7x7 grid.
  static (int, int, int) stepAssamOnce(int r, int c, int dir) {
    final nr = r + dirs[dir].$1;
    final nc = c + dirs[dir].$2;
    if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
      return (nr, nc, dir);
    }
    // Border U-turn wrap tracks:
    switch (dir) {
      case 0: // Stepping North off row 0
        if (c == 0) return (0, 0, 1); // Top-left corner turns East
        final wrapC = (c % 2 == 1) ? c + 1 : c - 1; // (1<->2), (3<->4), (5<->6)
        return (0, wrapC, 2); // U-turn South
      case 2: // Stepping South off row 6
        if (c == 6) return (6, 6, 3); // Bottom-right corner turns West
        final wrapC = (c % 2 == 0) ? c + 1 : c - 1; // (0<->1), (2<->3), (4<->5)
        return (6, wrapC, 0); // U-turn North
      case 3: // Stepping West off col 0
        if (r == 0) return (0, 0, 2); // Top-left corner turns South
        final wrapR = (r % 2 == 1) ? r + 1 : r - 1; // (1<->2), (3<->4), (5<->6)
        return (wrapR, 0, 1); // U-turn East
      case 1: // Stepping East off col 6
      default:
        if (r == 6) return (6, 6, 0); // Bottom-right corner turns North
        final wrapR = (r % 2 == 0) ? r + 1 : r - 1; // (0<->1), (2<->3), (4<->5)
        return (wrapR, 6, 3); // U-turn West
    }
  }

  /// BFS to count the orthogonally connected component size of visible rug cells
  /// belonging to the owner of `(startR, startC)`.
  int connectedVisibleRugSize(int startR, int startC) {
    final startCell = grid[startR][startC];
    if (startCell == null) return 0;
    final targetOwner = startCell.owner;
    final visited = List.generate(size, (_) => List.filled(size, false));
    final q = Queue<(int, int)>();
    visited[startR][startC] = true;
    q.add((startR, startC));
    var count = 0;

    while (q.isNotEmpty) {
      final (cr, cc) = q.removeFirst();
      count++;
      for (final (dr, dc) in dirs) {
        final nr = cr + dr;
        final nc = cc + dc;
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        if (visited[nr][nc]) continue;
        if (grid[nr][nc]?.owner == targetOwner) {
          visited[nr][nc] = true;
          q.add((nr, nc));
        }
      }
    }
    return count;
  }

  int visibleCellsOfColor(int seat) {
    var cnt = 0;
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        if (grid[r][c]?.owner == seat) cnt++;
      }
    }
    return cnt;
  }

  int calcScore(int seat) => coins[seat] + visibleCellsOfColor(seat);

  void _updateScores() {
    for (var s = 0; s < players; s++) {
      score[s] = calcScore(s);
    }
  }

  bool canPlaceRug(int r1, int c1, int r2, int c2) {
    if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size) return false;
    if (r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) return false;
    // Must be orthogonally adjacent (1x2 domino)
    if ((r1 - r2).abs() + (c1 - c2).abs() != 1) return false;
    // Neither cell can contain Assam
    if (r1 == assamR && c1 == assamC) return false;
    if (r2 == assamR && c2 == assamC) return false;
    // At least one cell must be orthogonally adjacent to Assam
    final adj1 = (r1 - assamR).abs() + (c1 - assamC).abs() == 1;
    final adj2 = (r2 - assamR).abs() + (c2 - assamC).abs() == 1;
    if (!adj1 && !adj2) return false;
    // Cannot completely cover both halves of a single previously placed rug
    final cell1 = grid[r1][c1];
    final cell2 = grid[r2][c2];
    if (cell1 != null && cell2 != null && cell1.rugId == cell2.rugId) {
      return false;
    }
    return true;
  }

  List<(int, int, int, int)> legalRugPlacements() {
    final res = <(int, int, int, int)>[];
    final seen = <String>{};
    for (final (dr1, dc1) in dirs) {
      final r1 = assamR + dr1;
      final c1 = assamC + dc1;
      if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size) continue;
      for (final (dr2, dc2) in dirs) {
        final r2 = r1 + dr2;
        final c2 = c1 + dc2;
        if (!canPlaceRug(r1, c1, r2, c2)) continue;
        final key = (r1 < r2 || (r1 == r2 && c1 < c2))
            ? '$r1,$c1-$r2,$c2'
            : '$r2,$c2-$r1,$c1';
        if (seen.add(key)) {
          res.add((r1, c1, r2, c2));
        }
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
      case 'orient_assam':
        if (phase != 'orient') {
          throw GameError('当前处于铺设地毯阶段，请先铺设地毯');
        }
        int newDir;
        if (action.containsKey('turnDelta')) {
          final delta = asInt(action['turnDelta'], 99);
          if (delta < -1 || delta > 1) {
            throw GameError('阿萨姆不能掉头 180°！只能选择直行(0)、左转(-1)或右转(+1)');
          }
          newDir = (assamDir + delta + 4) % 4;
        } else if (action.containsKey('dir')) {
          final d = asInt(action['dir'], -1);
          if (d < 0 || d > 3) {
            throw GameError('无效的方向: $d');
          }
          if (d == (assamDir + 2) % 4) {
            throw GameError('阿萨姆严禁 180° 掉头！');
          }
          newDir = d;
        } else {
          newDir = assamDir;
        }

        assamDir = newDir;
        final steps = slipperFaces[rng.nextInt(slipperFaces.length)];
        lastRoll = steps;

        final path = <(int, int)>[(assamR, assamC)];
        for (var i = 0; i < steps; i++) {
          final next = stepAssamOnce(assamR, assamC, assamDir);
          assamR = next.$1;
          assamC = next.$2;
          assamDir = next.$3;
          path.add((assamR, assamC));
        }
        lastAssamPath = path;

        // Check tribute payment
        final landed = grid[assamR][assamC];
        var tributeMsg = '落于空地/己方地毯，无需支付过路费';
        if (landed != null && landed.owner != seat && coins[seat] > 0) {
          final compSize = connectedVisibleRugSize(assamR, assamC);
          final paid = min(coins[seat], compSize);
          coins[seat] -= paid;
          coins[landed.owner] += paid;
          lastTribute = paid;
          lastTributeTo = landed.owner;
          tributeMsg =
              '踩中 ${name(landed.owner)} 的连片地毯($compSize格)，支付 $paid🪙 迪拉姆';
        } else {
          lastTribute = 0;
          lastTributeTo = -1;
        }

        _updateScores();
        phase = 'place';
        lastAction =
            '${name(seat)} 令阿萨姆朝${marrakechDirNames[newDir]}掷出 拖鞋骰[$steps步] 移至($assamR,$assamC)，$tributeMsg';
        host.log(lastAction);

      case 'place_rug':
        if (phase != 'place') {
          throw GameError('请先转动并移动阿萨姆 (orient_assam)');
        }
        final r1 = asInt(action['r1'], -1);
        final c1 = asInt(action['c1'], -1);
        final r2 = asInt(action['r2'], -1);
        final c2 = asInt(action['c2'], -1);

        if (r1 < 0 ||
            r1 >= size ||
            c1 < 0 ||
            c1 >= size ||
            r2 < 0 ||
            r2 >= size ||
            c2 < 0 ||
            c2 >= size) {
          throw GameError('地毯坐标超出 7×7 集市范围');
        }
        if ((r1 - r2).abs() + (c1 - c2).abs() != 1) {
          throw GameError('地毯必须铺在两个正交相邻的格子上');
        }
        if ((r1 == assamR && c1 == assamC) || (r2 == assamR && c2 == assamC)) {
          throw GameError('地毯不能铺在阿萨姆脚下所在的格子');
        }
        final adj1 = (r1 - assamR).abs() + (c1 - assamC).abs() == 1;
        final adj2 = (r2 - assamR).abs() + (c2 - assamC).abs() == 1;
        if (!adj1 && !adj2) {
          throw GameError('地毯至少有一半必须与阿萨姆当前位置 ($assamR,$assamC) 正交相邻');
        }
        final cell1 = grid[r1][c1];
        final cell2 = grid[r2][c2];
        if (cell1 != null && cell2 != null && cell1.rugId == cell2.rugId) {
          throw GameError('违规铺设：不能用一块新地毯完整覆盖同一块旧地毯的两格！');
        }

        final id = ++nextRugId;
        grid[r1][c1] = MarrakechRugCell(owner: seat, rugId: id);
        grid[r2][c2] = MarrakechRugCell(owner: seat, rugId: id);
        rugsLeft[seat]--;
        _updateScores();

        lastAction =
            '${name(seat)} 在 ($r1,$c1)-($r2,$c2) 铺设了 ${marrakechPlayerEmojis[seat % marrakechPlayerEmojis.length]} 地毯 #$id';
        host.log(lastAction);
        _advanceTurn();

      default:
        throw GameError('未知操作: $type');
    }
  }

  void _advanceTurn() {
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (rugsLeft[nextSeat] > 0 && coins[nextSeat] > 0) {
        if (nextSeat <= turn) round++;
        turn = nextSeat;
        phase = 'orient';
        return;
      }
    }
    // Check if any player still has rugs left (even with 0 coins)
    for (var offset = 1; offset <= players; offset++) {
      final nextSeat = (turn + offset) % players;
      if (rugsLeft[nextSeat] > 0) {
        if (nextSeat <= turn) round++;
        turn = nextSeat;
        phase = 'orient';
        return;
      }
    }
    over = true;
    _updateScores();
    lastAction = '所有地毯铺设完毕，摩洛哥集市终局结算完成！';
    host.log(lastAction);
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (phase == 'orient') {
      // Evaluate deltas -1 (left), 0 (straight), +1 (right) by expected tribute loss
      int bestDelta = 0;
      double bestScore = -1e9;
      for (final delta in const [-1, 0, 1]) {
        final candDir = (assamDir + delta + 4) % 4;
        var expectedPenalty = 0.0;
        for (final steps in slipperFaces) {
          var r = assamR;
          var c = assamC;
          var d = candDir;
          for (var i = 0; i < steps; i++) {
            final nxt = stepAssamOnce(r, c, d);
            r = nxt.$1;
            c = nxt.$2;
            d = nxt.$3;
          }
          final cell = grid[r][c];
          if (cell != null && cell.owner != seat) {
            expectedPenalty += connectedVisibleRugSize(r, c);
          } else if (cell != null && cell.owner == seat) {
            expectedPenalty -= 0.5;
          }
        }
        final val = -expectedPenalty + (botLevel == 0 ? rng.nextDouble() * 4 : 0);
        if (val > bestScore) {
          bestScore = val;
          bestDelta = delta;
        }
      }
      return {
        'type': 'orient_assam',
        'turnDelta': bestDelta,
      };
    }

    // phase == 'place'
    final moves = legalRugPlacements();
    if (moves.isEmpty) return null;
    if (botLevel == 0) {
      final m = moves[rng.nextInt(moves.length)];
      return {
        'type': 'place_rug',
        'r1': m.$1,
        'c1': m.$2,
        'r2': m.$3,
        'c2': m.$4,
      };
    }

    var bestMove = moves.first;
    var bestVal = -999999;
    for (final m in moves) {
      final (r1, c1, r2, c2) = m;
      var val = 0;
      for (final (r, c) in [(r1, c1), (r2, c2)]) {
        final cur = grid[r][c];
        if (cur == null) {
          val += 4; // New coverage
        } else if (cur.owner != seat) {
          val += 8; // Cover opponent's rug!
        } else {
          val -= 3; // Avoid covering own rug
        }
        // Bonus for connecting to own orthogonal rugs
        for (final (dr, dc) in dirs) {
          final nr = r + dr;
          final nc = c + dc;
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            if (grid[nr][nc]?.owner == seat) val += 3;
          }
        }
      }
      if (val > bestVal) {
        bestVal = val;
        bestMove = m;
      }
    }

    return {
      'type': 'place_rug',
      'r1': bestMove.$1,
      'c1': bestMove.$2,
      'r2': bestMove.$3,
      'c2': bestMove.$4,
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final legalPlacements = phase == 'place'
        ? [
            for (final m in legalRugPlacements())
              {'r1': m.$1, 'c1': m.$2, 'r2': m.$3, 'c2': m.$4},
          ]
        : const <Map<String, dynamic>>[];

    return {
      'round': round,
      'rugsPerPlayer': rugsPerPlayer,
      'turn': turn,
      'phase': phase,
      'over': over,
      'lastAction': lastAction,
      'assamR': assamR,
      'assamC': assamC,
      'assamDir': assamDir,
      'assamDirName': marrakechDirNames[assamDir],
      'assamDirArrow': marrakechDirArrows[assamDir],
      'lastRoll': lastRoll,
      'lastTribute': lastTribute,
      'lastTributeTo': lastTributeTo,
      'lastAssamPath': [
        for (final (r, c) in lastAssamPath) [r, c],
      ],
      'legalPlacements': legalPlacements,
      'grid': [
        for (var r = 0; r < size; r++)
          [
            for (var c = 0; c < size; c++) grid[r][c]?.toJson(),
          ],
      ],
      'players': [
        for (var s = 0; s < players; s++)
          {
            'score': score[s],
            'coins': coins[s],
            'visibleRugs': visibleCellsOfColor(s),
            'rugsLeft': rugsLeft[s],
            'emoji': marrakechPlayerEmojis[s % marrakechPlayerEmojis.length],
            'colorName':
                marrakechPlayerColorNames[s % marrakechPlayerColorNames.length],
          },
      ],
    };
  }
}
