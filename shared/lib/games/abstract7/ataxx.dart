import 'dart:math';

import '../../src/engine.dart';

const int ataxxSize = 7;
const int ataxxCells = ataxxSize * ataxxSize; // 49

String ataxxCoord(int cell) {
  if (cell < 0 || cell >= ataxxCells) return '?';
  final r = cell ~/ ataxxSize, c = cell % ataxxSize;
  return '${String.fromCharCode(65 + c)}${ataxxSize - r}';
}

/// 同化棋（Ataxx）— 经典 7×7 分裂跳跃与八邻感染领地争夺棋
class Ataxx extends GameEngine {
  static const int maxPlies = 180;
  static const int maxNoProgressPlies = 32;

  String mapId = 'open';

  /// 49-cell 7×7 board:
  /// -2 = blocked wall / obstacle
  /// -1 = empty cell
  ///  0 = Player 0 piece (Ruby / Red)
  ///  1 = Player 1 piece (Sapphire / Blue)
  late List<int> board;

  int turn = 0;
  int plies = 0;
  int noProgressPlies = 0;

  bool _over = false;
  int winner = -1; // 0, 1, or 2 (draw)
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Ataxx(super.setup);

  static List<int> blockedCellsForMap(String mapId) {
    switch (mapId) {
      case 'cross':
        // Central plus sign: (2,3)=17, (3,2)=23, (3,3)=24, (3,4)=25, (4,3)=31
        return const [17, 23, 24, 25, 31];
      case 'pillars':
        // Four symmetrical inner pillars: (2,2)=16, (2,4)=18, (4,2)=30, (4,4)=32
        return const [16, 18, 30, 32];
      default:
        return const [];
    }
  }

  @override
  void start() {
    final optMap = setup.opt<String>('map', 'open');
    mapId = (optMap == 'cross' || optMap == 'pillars') ? optMap : 'open';

    board = List.filled(ataxxCells, -1);
    for (final w in blockedCellsForMap(mapId)) {
      board[w] = -2;
    }

    // Player 0 starts at (0, 0) = 0 and (6, 6) = 48
    board[0] = 0;
    board[48] = 0;
    // Player 1 starts at (0, 6) = 6 and (6, 0) = 42
    board[6] = 1;
    board[42] = 1;

    turn = 0;
    plies = 0;
    noProgressPlies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    result = '';
    note = '对局开始：邻格移动（距离 1）会分裂出新棋子，跨格移动（距离 2）会跳跃移位，落点周围 8 格敌子全部同化！';
  }

  int countPieces(int seat) {
    var cnt = 0;
    for (final v in board) {
      if (v == seat) cnt++;
    }
    return cnt;
  }

  int countEmpty() {
    var cnt = 0;
    for (final v in board) {
      if (v == -1) cnt++;
    }
    return cnt;
  }

  static int chebyshevDist(int a, int b) {
    final ar = a ~/ ataxxSize, ac = a % ataxxSize;
    final br = b ~/ ataxxSize, bc = b % ataxxSize;
    return max((ar - br).abs(), (ac - bc).abs());
  }

  List<int> legalTargets(int from) {
    if (from < 0 || from >= ataxxCells) return const [];
    final s = board[from];
    if (s != 0 && s != 1) return const [];
    final r0 = from ~/ ataxxSize, c0 = from % ataxxSize;
    final out = <int>[];
    for (var dr = -2; dr <= 2; dr++) {
      final nr = r0 + dr;
      if (nr < 0 || nr >= ataxxSize) continue;
      for (var dc = -2; dc <= 2; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nc = c0 + dc;
        if (nc < 0 || nc >= ataxxSize) continue;
        final idx = nr * ataxxSize + nc;
        if (board[idx] == -1) {
          out.add(idx);
        }
      }
    }
    return out;
  }

  bool hasAnyLegalMove(int seat) {
    for (var i = 0; i < ataxxCells; i++) {
      if (board[i] == seat && legalTargets(i).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Executes move `from -> to` for [seat] and flips all opponent neighbors around [to].
  /// Returns the list of infected cell indices.
  List<int> executeMove(int seat, int from, int to) {
    final dist = chebyshevDist(from, to);
    if (dist == 2) {
      board[from] = -1;
    }
    board[to] = seat;

    final opp = 1 - seat;
    final tr = to ~/ ataxxSize, tc = to % ataxxSize;
    final infected = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      final nr = tr + dr;
      if (nr < 0 || nr >= ataxxSize) continue;
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nc = tc + dc;
        if (nc < 0 || nc >= ataxxSize) continue;
        final nIdx = nr * ataxxSize + nc;
        if (board[nIdx] == opp) {
          board[nIdx] = seat;
          infected.add(nIdx);
        }
      }
    }
    return infected;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');

    final t = asStr(action['type']);
    if (t != 'move') throw GameError('请选择己方棋子并移动到距离 1 或 2 的空格');

    final from = asInt(action['from'], -1);
    final to = asInt(action['to'], -1);
    if (from < 0 || from >= ataxxCells || to < 0 || to >= ataxxCells) {
      throw GameError('请选择有效的起点与终点');
    }
    if (board[from] != seat) {
      throw GameError('起点必须是你自己的棋子');
    }
    if (board[to] != -1) {
      throw GameError(board[to] == -2 ? '目标格为障碍壁垒，无法落子' : '目标格已有棋子，必须落入空格');
    }

    final dist = chebyshevDist(from, to);
    if (dist < 1 || dist > 2) {
      throw GameError('只能分裂（距离 1）或跳跃（距离 2）到周围两圈内的空格');
    }

    final infected = executeMove(seat, from, to);
    plies++;
    if (dist == 1 || infected.isNotEmpty) {
      noProgressPlies = 0;
    } else {
      noProgressPlies++;
    }

    lastAction = {
      'type': 'move',
      'seat': seat,
      'from': from,
      'to': to,
      'dist': dist,
      'kind': dist == 1 ? 'clone' : 'jump',
      'infected': infected,
    };

    final sideName = seat == 0 ? '赤晶方' : '蓝珀方';
    final kindLabel = dist == 1 ? '分裂' : '跳跃';
    final infectText = infected.isEmpty ? '' : '，同化周围 ${infected.length} 枚敌子！';
    final baseNote = '${name(seat)}（$sideName）$kindLabel ${ataxxCoord(from)}→${ataxxCoord(to)}$infectText';

    final c0 = countPieces(0);
    final c1 = countPieces(1);
    final empty = countEmpty();

    if (c0 == 0 || c1 == 0) {
      final w = c0 > 0 ? 0 : 1;
      _finish(w, '$baseNote；${name(1 - w)} 棋子被全部同化清零，${name(w)} 全歼获胜（$c0:$c1）！');
      return;
    }
    if (empty == 0) {
      _finishByScore('$baseNote；棋盘已满');
      return;
    }
    if (noProgressPlies >= maxNoProgressPlies || plies >= maxPlies) {
      _finishByScore('$baseNote；达到回合上限');
      return;
    }

    final nextSeat = 1 - seat;
    if (hasAnyLegalMove(nextSeat)) {
      turn = nextSeat;
      note = baseNote;
    } else if (hasAnyLegalMove(seat)) {
      turn = seat;
      note = '$baseNote；${name(nextSeat)} 无合法移动自动跳过，继续由 ${name(seat)} 行动！';
    } else {
      _finishByScore('$baseNote；双方均无合法移动');
    }
  }

  void _finishByScore(String prefix) {
    final c0 = countPieces(0);
    final c1 = countPieces(1);
    if (c0 != c1) {
      final w = c0 > c1 ? 0 : 1;
      final wSide = w == 0 ? '赤晶方' : '蓝珀方';
      _finish(w, '$prefix，${name(w)}（$wSide）以 $c0:$c1 领地优势获胜！');
    } else {
      _finish(2, '$prefix，双方棋子数 $c0:$c1 完全相等，握手言和！');
    }
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
      'map': mapId,
      'size': ataxxSize,
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'counts': [countPieces(0), countPieces(1)],
      'empty': countEmpty(),
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // Deduplicate clone moves to the same destination `to` (all distance-1 moves to `to`
    // produce the exact same board state!), keeping only one representative `from` per `to` for dist==1.
    final seenCloneTo = <int>{};
    final moves = <(int, int)>[];
    for (var f = 0; f < ataxxCells; f++) {
      if (board[f] != seat) continue;
      for (final t in legalTargets(f)) {
        final d = chebyshevDist(f, t);
        if (d == 1) {
          if (seenCloneTo.add(t)) {
            moves.add((f, t));
          }
        } else {
          moves.add((f, t));
        }
      }
    }
    if (moves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = moves[rng.nextInt(moves.length)];
      return {'type': 'move', 'from': pick.$1, 'to': pick.$2};
    }

    final saved = List<int>.of(board);
    final opp = 1 - seat;
    var bestScore = -1e12;
    var bestMove = moves.first;

    for (final (f, t) in moves) {
      final dist = chebyshevDist(f, t);
      final infected = executeMove(seat, f, t);
      final myCnt = countPieces(seat);
      final oppCnt = countPieces(opp);

      if (oppCnt == 0) {
        board.setAll(0, saved);
        return {'type': 'move', 'from': f, 'to': t};
      }

      // Base score: net piece advantage + bonus for cloning (+1 piece) vs jumping (0 net unless infecting >= 2)
      var sc = (myCnt - oppCnt) * 10.0 + infected.length * 6.0 + (dist == 1 ? 7.0 : -3.0) + rng.nextDouble() * 1.5;

      // In normal/hard mode, penalize leaving `from` empty if jumping exposes own pieces to a huge counter-infection
      if (botLevel >= 2 && dist == 2 && infected.length <= 1) {
        sc -= 8.0;
      }

      if (sc > bestScore) {
        bestScore = sc;
        bestMove = (f, t);
      }

      board.setAll(0, saved);
    }

    return {'type': 'move', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
