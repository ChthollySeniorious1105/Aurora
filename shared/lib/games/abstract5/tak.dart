import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';

/// Directions: 0 = North (-1, 0), 1 = East (0, 1), 2 = South (1, 0), 3 = West (0, -1).
const List<(int, int)> takDirs = [
  (-1, 0),
  (0, 1),
  (1, 0),
  (0, -1),
];

const List<String> takDirNames = ['北', '东', '南', '西'];

String takCoord(int size, int cell) {
  if (cell < 0 || cell >= size * size) return '?';
  final r = cell ~/ size, c = cell % size;
  return '${String.fromCharCode(65 + c)}${size - r}';
}

class TakPiece {
  final int owner; // 0 or 1
  final String kind; // 'flat', 'wall', 'cap'
  const TakPiece(this.owner, this.kind);

  Map<String, dynamic> toJson() => {'owner': owner, 'kind': kind};

  static TakPiece fromJson(Map m) => TakPiece(m['owner'] as int, m['kind'] as String);
}

class Tak extends GameEngine {
  late int size;

  /// Each cell `0 .. size*size - 1` holds a stack of [TakPiece] from bottom (index 0) to top (last).
  late List<List<TakPiece>> board;

  /// Remaining regular stones (used as 'flat' or 'wall') per player.
  late List<int> stones;

  /// Remaining capstones ('cap') per player.
  late List<int> caps;

  int turn = 0;
  int plies = 0;
  static const int maxPlies = 160;
  bool _over = false;
  int winner = -1; // 0, 1, or 2 for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;
  List<int> winningRoad = const [];

  Tak(super.setup);

  int _parseCell(Object? v) {
    if (v is List && v.length >= 2) {
      final r = asInt(v[0], -1), c = asInt(v[1], -1);
      if (r < 0 || r >= size || c < 0 || c >= size) return -1;
      return r * size + c;
    }
    final idx = asInt(v, -1);
    return (idx >= 0 && idx < size * size) ? idx : -1;
  }

  @override
  void start() {
    final optSize = setup.opt<int>('size', 5);
    size = (optSize == 4) ? 4 : 5;
    board = List.generate(size * size, (_) => <TakPiece>[]);
    final initStones = size == 5 ? 21 : 15;
    stones = [initStones, initStones];
    caps = [1, 1];

    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    winningRoad = const [];
    note = '开局阶段（前2手）：白方先行，请将 1 枚【对手颜色】的平石放置在任意空格上';
    result = '';
  }

  /// Counts squares whose top piece belongs to [seat] and is a 'flat'.
  int flatCount(int seat) {
    var count = 0;
    for (final s in board) {
      if (s.isNotEmpty && s.last.owner == seat && s.last.kind == 'flat') {
        count++;
      }
    }
    return count;
  }

  /// Counts squares whose top piece belongs to [seat] and counts toward a road ('flat' or 'cap').
  int roadControlCount(int seat) {
    var count = 0;
    for (final s in board) {
      if (s.isNotEmpty && s.last.owner == seat && (s.last.kind == 'flat' || s.last.kind == 'cap')) {
        count++;
      }
    }
    return count;
  }

  bool _isRoadCellFor(int cell, int seat) {
    final s = board[cell];
    if (s.isEmpty || s.last.owner != seat) return false;
    return s.last.kind == 'flat' || s.last.kind == 'cap';
  }

  /// Returns a list of cell indices forming a winning orthogonal road for [seat]
  /// (connecting North-South or West-East), or an empty list if none exists.
  List<int> findRoad(int seat) {
    // 1. Check North (row 0) to South (row size - 1)
    final ns = _bfsRoad(
      seat,
      [for (var c = 0; c < size; c++) if (_isRoadCellFor(c, seat)) c],
      (cell) => cell ~/ size == size - 1,
    );
    if (ns.isNotEmpty) return ns;

    // 2. Check West (col 0) to East (col size - 1)
    final we = _bfsRoad(
      seat,
      [for (var r = 0; r < size; r++) if (_isRoadCellFor(r * size, seat)) r * size],
      (cell) => cell % size == size - 1,
    );
    return we;
  }

  List<int> _bfsRoad(int seat, List<int> starts, bool Function(int) isGoal) {
    if (starts.isEmpty) return const [];
    final parent = <int, int>{};
    final q = Queue<int>();
    for (final s in starts) {
      parent[s] = -1;
      if (isGoal(s)) return [s];
      q.add(s);
    }
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final r0 = cur ~/ size, c0 = cur % size;
      for (final (dr, dc) in takDirs) {
        final r = r0 + dr, c = c0 + dc;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        final nxt = r * size + c;
        if (parent.containsKey(nxt) || !_isRoadCellFor(nxt, seat)) continue;
        parent[nxt] = cur;
        if (isGoal(nxt)) {
          final path = <int>[];
          var p = nxt;
          while (p != -1) {
            path.add(p);
            p = parent[p] ?? -1;
          }
          return path.reversed.toList();
        }
        q.add(nxt);
      }
    }
    return const [];
  }

  bool hasRoad(int seat) => findRoad(seat).isNotEmpty;

  /// Validates whether a spread action `(from, dir, drops)` is legal for [seat].
  String? validateSpread(int seat, int from, int dir, List<int> drops) {
    if (plies < 2) return '开局首回合只能放置对手平石，不能移动叠堆';
    if (from < 0 || from >= size * size) return '起点格无效';
    final stack = board[from];
    if (stack.isEmpty || stack.last.owner != seat) {
      return '只能操作栈顶为你本人棋子的叠堆';
    }
    if (dir < 0 || dir >= 4) return '移动方向无效';
    if (drops.isEmpty) return '必须指定沿途每格落下的棋子数';

    var picked = 0;
    for (final d in drops) {
      if (d < 1) return '每格至少需落下 1 枚棋子';
      picked += d;
    }
    final maxCarry = min(size, stack.length);
    if (picked < 1 || picked > maxCarry) {
      return '最多可拿起栈顶 $maxCarry 枚棋子（棋盘边长上限为 $size）';
    }

    final (dr, dc) = takDirs[dir];
    final r0 = from ~/ size, c0 = from % size;
    final k = drops.length;
    final topIsCap = stack.last.kind == 'cap';

    for (var step = 1; step <= k; step++) {
      final r = r0 + dr * step, c = c0 + dc * step;
      if (r < 0 || r >= size || c < 0 || c >= size) {
        return '分堆移动路径超出棋盘边界';
      }
      final sq = r * size + c;
      final dest = board[sq];
      if (dest.isNotEmpty) {
        final topKind = dest.last.kind;
        if (topKind == 'cap') {
          return '不能将任何棋子移动到顶石（Capstone）之上';
        }
        if (topKind == 'wall') {
          final canFlatten = (step == k && drops[k - 1] == 1 && topIsCap);
          if (!canFlatten) {
            return '立石（墙）阻挡分堆！只有顶石在最后一步单独落于立石上才能将其压平';
          }
        }
      }
    }
    return null;
  }

  /// Generates all legal spread actions from [from] for [seat].
  List<Map<String, dynamic>> legalSpreadsFrom(int seat, int from) {
    final out = <Map<String, dynamic>>[];
    if (plies < 2 || from < 0 || from >= size * size) return out;
    final stack = board[from];
    if (stack.isEmpty || stack.last.owner != seat) return out;

    final maxPick = min(size, stack.length);
    final topIsCap = stack.last.kind == 'cap';
    final r0 = from ~/ size, c0 = from % size;

    for (var dir = 0; dir < 4; dir++) {
      final (dr, dc) = takDirs[dir];

      void dfs(int step, int rem, List<int> acc) {
        final r = r0 + dr * step, c = c0 + dc * step;
        if (r < 0 || r >= size || c < 0 || c >= size) return;
        final sq = r * size + c;
        final dest = board[sq];
        if (dest.isNotEmpty) {
          final tk = dest.last.kind;
          if (tk == 'cap') return;
          if (tk == 'wall') {
            // Only legal if this is the final step, dropping exactly 1 piece, and top is 'cap'
            if (rem == 1 && topIsCap) {
              out.add({
                'type': 'spread',
                'from': from,
                'dir': dir,
                'drops': [...acc, 1],
              });
            }
            return;
          }
        }
        for (var drop = 1; drop <= rem; drop++) {
          final nextAcc = [...acc, drop];
          if (drop == rem) {
            out.add({
              'type': 'spread',
              'from': from,
              'dir': dir,
              'drops': nextAcc,
            });
          } else {
            dfs(step + 1, rem - drop, nextAcc);
          }
        }
      }

      for (var pick = 1; pick <= maxPick; pick++) {
        dfs(1, pick, const []);
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'place');

    if (t == 'place') {
      final cell = _parseCell(action['cell']);
      if (cell < 0) throw GameError('请选择要放置棋子的空格');
      if (board[cell].isNotEmpty) throw GameError('放置新棋子只能选择空格');

      final kind = asStr(action['kind'], 'flat');
      if (kind != 'flat' && kind != 'wall' && kind != 'cap') {
        throw GameError('未知棋子类型');
      }

      if (plies < 2) {
        if (kind != 'flat') {
          throw GameError('开局首回合必须放置 1 枚对手颜色的平石（flat）');
        }
        final opp = 1 - seat;
        stones[opp]--;
        board[cell].add(TakPiece(opp, 'flat'));
        plies++;
        lastAction = {
          'type': 'place',
          'seat': seat,
          'owner': opp,
          'cell': cell,
          'kind': 'flat',
          'path': [cell],
        };
        final sideName = seat == 0 ? '白方' : '黑方';
        final oppSide = opp == 0 ? '白子' : '黑子';
        note = '${name(seat)}（$sideName）开局在 ${takCoord(size, cell)} 放置对手$oppSide平石';
        turn = 1 - seat;
        return;
      }

      if (kind == 'cap') {
        if (caps[seat] <= 0) throw GameError('你的顶石（Capstone）已用完');
        caps[seat]--;
      } else {
        if (stones[seat] <= 0) throw GameError('你的常规石子储备已用完');
        stones[seat]--;
      }

      board[cell].add(TakPiece(seat, kind));
      plies++;
      lastAction = {
        'type': 'place',
        'seat': seat,
        'owner': seat,
        'cell': cell,
        'kind': kind,
        'path': [cell],
      };

      final sideName = seat == 0 ? '白方' : '黑方';
      final kindName = kind == 'flat' ? '平石' : (kind == 'wall' ? '立石（墙）' : '顶石');
      note = '${name(seat)}（$sideName）在 ${takCoord(size, cell)} 放置$kindName';
    } else if (t == 'spread') {
      final from = _parseCell(action['from']);
      final dir = asInt(action['dir'], -1);
      final drops = asIntList(action['drops']);
      final err = validateSpread(seat, from, dir, drops);
      if (err != null) throw GameError(err);

      final picked = drops.fold<int>(0, (a, b) => a + b);
      final stack = board[from];
      final startIdx = stack.length - picked;
      final carried = stack.sublist(startIdx);
      stack.removeRange(startIdx, stack.length);

      final (dr, dc) = takDirs[dir];
      final r0 = from ~/ size, c0 = from % size;
      var offset = 0;
      var flattened = -1;
      final path = <int>[from];

      for (var i = 0; i < drops.length; i++) {
        final r = r0 + dr * (i + 1), c = c0 + dc * (i + 1);
        final sq = r * size + c;
        path.add(sq);
        final d = drops[i];
        final slice = carried.sublist(offset, offset + d);
        offset += d;
        if (board[sq].isNotEmpty && board[sq].last.kind == 'wall') {
          board[sq][board[sq].length - 1] = TakPiece(board[sq].last.owner, 'flat');
          flattened = sq;
        }
        board[sq].addAll(slice);
      }

      plies++;
      lastAction = {
        'type': 'spread',
        'seat': seat,
        'from': from,
        'dir': dir,
        'drops': drops,
        'flattened': flattened,
        'path': path,
      };

      final sideName = seat == 0 ? '白方' : '黑方';
      final flatNote = flattened >= 0 ? '（顶石压平 ${takCoord(size, flattened)} 立石！）' : '';
      note = '${name(seat)}（$sideName）从 ${takCoord(size, from)} 向${takDirNames[dir]}分堆移动 [${drops.join(',')}] 枚棋子$flatNote';
    } else {
      throw GameError('未知操作');
    }

    _checkPostMoveEnd(seat);
  }

  void _checkPostMoveEnd(int activeSeat) {
    final opp = 1 - activeSeat;

    // 1. Road Win check (active player takes priority if double road occurs!)
    final activeRoad = findRoad(activeSeat);
    if (activeRoad.isNotEmpty) {
      winningRoad = activeRoad;
      final sideName = activeSeat == 0 ? '白方' : '黑方';
      _finish(activeSeat, '${name(activeSeat)}（$sideName）成功贯通大道（Road Win），获胜！');
      return;
    }
    final oppRoad = findRoad(opp);
    if (oppRoad.isNotEmpty) {
      winningRoad = oppRoad;
      final sideName = opp == 0 ? '白方' : '黑方';
      _finish(opp, '${name(opp)}（$sideName）成功贯通大道（Road Win），获胜！');
      return;
    }

    // 2. Flat Win check (reserve exhausted, board full, or move limit)
    final p0Empty = stones[0] + caps[0] <= 0;
    final p1Empty = stones[1] + caps[1] <= 0;
    final boardFull = board.every((s) => s.isNotEmpty);

    if (p0Empty || p1Empty || boardFull || plies >= maxPlies) {
      final f0 = flatCount(0);
      final f1 = flatCount(1);
      final reason = boardFull
          ? '棋盘已满'
          : (p0Empty || p1Empty ? '一方储备棋子耗尽' : '达到 $maxPlies 手回合上限');
      if (f0 > f1) {
        _finish(0, '$reason，结算平石控制数：白方 $f0 : $f1 黑方，${name(0)} 获胜！');
      } else if (f1 > f0) {
        _finish(1, '$reason，结算平石控制数：黑方 $f1 : $f0 白方，${name(1)} 获胜！');
      } else {
        _finish(2, '$reason，双方平石控制数均为 $f0 处，握手言和！');
      }
      return;
    }

    turn = opp;
  }

  void _finish(int w, String msg) {
    _over = true;
    winner = w;
    result = msg;
    note = msg;
    if (w == 2) {
      _placings = [1, 1];
    } else {
      _placings = rankWinners(players, [w]);
    }
    host.log(msg);
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players) throw GameError('无法认输');
    final w = 1 - seat;
    _finish(w, '${name(seat)} 认输，${name(w)} 获胜！');
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _finish(2, '双方议和');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'size': size,
      'board': [
        for (final stack in board) [for (final p in stack) p.toJson()],
      ],
      'stones': List<int>.of(stones),
      'caps': List<int>.of(caps),
      'flats': [flatCount(0), flatCount(1)],
      'turn': turn,
      'plies': plies,
      'maxPlies': maxPlies,
      'openingSwap': plies < 2,
      'winningRoad': winningRoad,
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  List<List<TakPiece>> _cloneBoard() => [
        for (final s in board) List<TakPiece>.of(s),
      ];

  void _restoreBoard(List<List<TakPiece>> saved) {
    for (var i = 0; i < board.length; i++) {
      board[i] = List<TakPiece>.of(saved[i]);
    }
  }

  double _evalBoard(int seat) {
    final opp = 1 - seat;
    if (hasRoad(seat)) return 10000.0;
    if (hasRoad(opp)) return -10000.0;

    final myFlats = flatCount(seat);
    final oppFlats = flatCount(opp);
    final myRoad = roadControlCount(seat);
    final oppRoad = roadControlCount(opp);

    // Reward central control and orthogonal road adjacency
    var adjScore = 0.0;
    for (var i = 0; i < size * size; i++) {
      if (board[i].isEmpty) continue;
      final top = board[i].last;
      final r = i ~/ size, c = i % size;
      final centerBonus = (size - (r - size ~/ 2).abs() - (c - size ~/ 2).abs()) * 0.6;
      final sign = top.owner == seat ? 1.0 : -1.0;
      adjScore += sign * centerBonus;
      if (top.kind == 'flat' || top.kind == 'cap') {
        for (final (dr, dc) in const [(0, 1), (1, 0)]) {
          final nr = r + dr, nc = c + dc;
          if (nr < size && nc < size) {
            final nIdx = nr * size + nc;
            if (_isRoadCellFor(nIdx, top.owner)) {
              adjScore += sign * 2.8;
            }
          }
        }
      }
    }

    return (myFlats - oppFlats) * 5.0 + (myRoad - oppRoad) * 3.5 + adjScore;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // Opening turns (plies < 2): place opponent's flat stone on an empty corner/edge cell
    if (plies < 2) {
      final empty = [
        for (var i = 0; i < board.length; i++)
          if (board[i].isEmpty) i,
      ];
      if (empty.isEmpty) return null;
      final corners = empty.where((c) {
        final r = c ~/ size, col = c % size;
        return (r == 0 || r == size - 1) && (col == 0 || col == size - 1);
      }).toList();
      final pool = corners.isNotEmpty ? corners : empty;
      final pick = pool[rng.nextInt(pool.length)];
      return {'type': 'place', 'cell': pick, 'kind': 'flat'};
    }

    // Generate candidate moves
    final candidates = <Map<String, dynamic>>[];
    for (var i = 0; i < board.length; i++) {
      if (board[i].isEmpty) {
        if (stones[seat] > 0) {
          candidates.add({'type': 'place', 'cell': i, 'kind': 'flat'});
          if (plies >= 4) {
            candidates.add({'type': 'place', 'cell': i, 'kind': 'wall'});
          }
        }
        if (caps[seat] > 0 && plies >= 4) {
          candidates.add({'type': 'place', 'cell': i, 'kind': 'cap'});
        }
      } else if (board[i].last.owner == seat) {
        candidates.addAll(legalSpreadsFrom(seat, i));
      }
    }

    if (candidates.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      return candidates[rng.nextInt(candidates.length)];
    }

    final saved = _cloneBoard();
    var bestScore = -1e12;
    var bestAction = candidates.first;

    for (final a in candidates) {
      final t = a['type'] as String;
      if (t == 'place') {
        final c = a['cell'] as int;
        final kind = a['kind'] as String;
        board[c].add(TakPiece(seat, kind));
      } else {
        final from = a['from'] as int;
        final dir = a['dir'] as int;
        final drops = (a['drops'] as List<int>);
        final picked = drops.fold<int>(0, (x, y) => x + y);
        final stack = board[from];
        final startIdx = stack.length - picked;
        final carried = stack.sublist(startIdx);
        stack.removeRange(startIdx, stack.length);
        final (dr, dc) = takDirs[dir];
        final r0 = from ~/ size, c0 = from % size;
        var offset = 0;
        for (var i = 0; i < drops.length; i++) {
          final sq = (r0 + dr * (i + 1)) * size + (c0 + dc * (i + 1));
          final d = drops[i];
          final slice = carried.sublist(offset, offset + d);
          offset += d;
          if (board[sq].isNotEmpty && board[sq].last.kind == 'wall') {
            board[sq][board[sq].length - 1] = TakPiece(board[sq].last.owner, 'flat');
          }
          board[sq].addAll(slice);
        }
      }

      if (hasRoad(seat)) {
        _restoreBoard(saved);
        return a;
      }

      var score = _evalBoard(seat) + rng.nextDouble() * 1.5;
      if (t == 'place' && a['kind'] == 'wall') {
        score -= 3.5; // Prefer flat stones unless wall blocks opponent road
      }
      if (score > bestScore) {
        bestScore = score;
        bestAction = a;
      }

      _restoreBoard(saved);
    }

    return bestAction;
  }
}
