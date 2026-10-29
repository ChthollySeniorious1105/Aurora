import 'dart:math';

import '../../src/engine.dart';

const List<(int, int)> hnefataflDirs = [
  (-1, 0),
  (1, 0),
  (0, -1),
  (0, 1),
];

String hnefataflCoord(int size, int cell) {
  if (cell < 0 || cell >= size * size) return '?';
  final r = cell ~/ size, c = cell % size;
  return '${String.fromCharCode(65 + c)}${size - r}';
}

class Hnefatafl extends GameEngine {
  late int size;

  /// Board of length `size * size`:
  /// -1 = empty, 0 = Attacker (Seat 0, Black), 1 = Defender (Seat 1, White), 2 = King (Seat 1, White/Gold).
  late List<int> board;

  int turn = 0; // Seat 0 (Attackers) moves first
  int plies = 0;
  static const int maxPlies = 160;
  bool _over = false;
  int winner = -1; // 0 = Attackers, 1 = Defenders, 2 = Draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Hnefatafl(super.setup);

  int get mid => size ~/ 2;
  int get throne => mid * size + mid;

  bool isCorner(int cell) {
    if (cell < 0 || cell >= size * size) return false;
    final r = cell ~/ size, c = cell % size;
    return (r == 0 || r == size - 1) && (c == 0 || c == size - 1);
  }

  bool isRestricted(int cell) => cell == throne || isCorner(cell);

  bool belongsTo(int piece, int seat) {
    if (seat == 0) return piece == 0;
    if (seat == 1) return piece == 1 || piece == 2;
    return false;
  }

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
    final optSize = setup.opt<int>('size', 9);
    size = (optSize == 7) ? 7 : 9;
    board = List.filled(size * size, -1);

    final m = mid;
    // Place King on Center Throne
    board[m * size + m] = 2;

    if (size == 9) {
      // 9x9 Tablut: 8 Defenders in a cross of arm length 2 around Throne
      for (final d in [1, 2]) {
        board[(m - d) * size + m] = 1;
        board[(m + d) * size + m] = 1;
        board[m * size + (m - d)] = 1;
        board[m * size + (m + d)] = 1;
      }
      // 16 Attackers in 4 edge camps
      for (final c in [m - 1, m, m + 1]) {
        board[0 * size + c] = 0;
        board[(size - 1) * size + c] = 0;
        board[c * size + 0] = 0;
        board[c * size + (size - 1)] = 0;
      }
      board[1 * size + m] = 0;
      board[(size - 2) * size + m] = 0;
      board[m * size + 1] = 0;
      board[m * size + (size - 2)] = 0;
    } else {
      // 7x7 Brandubh: 4 Defenders orthogonally adjacent to Throne
      board[(m - 1) * size + m] = 1;
      board[(m + 1) * size + m] = 1;
      board[m * size + (m - 1)] = 1;
      board[m * size + (m + 1)] = 1;
      // 8 Attackers: 2 on each orthogonal arm outside the Defenders
      for (final d in [2, 3]) {
        board[(m - d) * size + m] = 0;
        board[(m + d) * size + m] = 0;
        board[m * size + (m - d)] = 0;
        board[m * size + (m + d)] = 0;
      }
    }

    turn = 0;
    plies = 0;
    _over = false;
    winner = -1;
    _placings = null;
    lastAction = null;
    note = '黑方（劫掠者）先行：四方围猎中央国王，白方（近卫军）护送国王逃往四角圣殿！';
    result = '';
  }

  int get kingCell {
    for (var i = 0; i < board.length; i++) {
      if (board[i] == 2) return i;
    }
    return -1;
  }

  int countPieces(int seat) {
    var count = 0;
    for (final p in board) {
      if (belongsTo(p, seat)) count++;
    }
    return count;
  }

  /// Returns all squares reachable from [from] via orthogonal Rook movement.
  /// Regular pieces (0 and 1) may pass through the empty Center Throne,
  /// but only the King (2) may land on the Center Throne or the 4 Corners.
  List<int> legalTargets(int from) {
    final out = <int>[];
    if (from < 0 || from >= size * size) return out;
    final piece = board[from];
    if (piece == -1) return out;
    final isKing = piece == 2;
    final r0 = from ~/ size, c0 = from % size;
    for (final (dr, dc) in hnefataflDirs) {
      var r = r0 + dr, c = c0 + dc;
      while (r >= 0 && r < size && c >= 0 && c < size) {
        final idx = r * size + c;
        if (board[idx] != -1) break;
        if (isKing || !isRestricted(idx)) {
          out.add(idx);
        }
        r += dr;
        c += dc;
      }
    }
    return out;
  }

  bool isMoveLegal(int seat, int from, int to) {
    if (from < 0 || from >= size * size || to < 0 || to >= size * size || from == to) {
      return false;
    }
    if (!belongsTo(board[from], seat)) return false;
    return legalTargets(from).contains(to);
  }

  bool hasAnyLegalMove(int seat) {
    for (var i = 0; i < board.length; i++) {
      if (belongsTo(board[i], seat) && legalTargets(i).isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  bool _isHostileForRegular(int cell, int movingSeat) {
    if (cell < 0 || cell >= size * size) return false;
    if (belongsTo(board[cell], movingSeat)) return true;
    if (isCorner(cell) && board[cell] == -1) return true;
    if (cell == throne && board[cell] == -1) return true;
    return false;
  }

  bool _checkKingCaptured(int kCell, int dr, int dc) {
    final kr = kCell ~/ size, kc = kCell % size;
    final nearOrOnThrone = (kr - mid).abs() + (kc - mid).abs() <= 1;
    if (nearOrOnThrone) {
      // Must be surrounded on all 4 orthogonal sides by Attackers (or the Throne)
      for (final (nr, nc) in hnefataflDirs) {
        final r = kr + nr, c = kc + nc;
        if (r < 0 || r >= size || c < 0 || c >= size) return false;
        final nIdx = r * size + c;
        if (board[nIdx] != 0 && nIdx != throne) return false;
      }
      return true;
    } else {
      // Away from Throne: sandwiched orthogonally between 2 Attackers (or Attacker + Corner/Throne/Edge)
      final r2 = kr + dr, c2 = kc + dc;
      if (r2 < 0 || r2 >= size || c2 < 0 || c2 >= size) return true;
      final beyond = r2 * size + c2;
      return board[beyond] == 0 || isCorner(beyond) || beyond == throne;
    }
  }

  /// Applies move `from -> to` for `seat` on `board` and returns captured squares.
  (List<int> captured, bool kingCaptured) _applyMoveAndCaptures(int seat, int from, int to) {
    final piece = board[from];
    board[from] = -1;
    board[to] = piece;

    final captured = <int>[];
    var kingCap = false;
    final r0 = to ~/ size, c0 = to % size;

    for (final (dr, dc) in hnefataflDirs) {
      final r1 = r0 + dr, c1 = c0 + dc;
      if (r1 < 0 || r1 >= size || c1 < 0 || c1 >= size) continue;
      final adj = r1 * size + c1;
      final adjPiece = board[adj];
      if (adjPiece == -1 || belongsTo(adjPiece, seat)) continue;

      if (adjPiece == 2) {
        // Seat 0 moved next to the King
        if (seat == 0 && _checkKingCaptured(adj, dr, dc)) {
          board[adj] = -1;
          captured.add(adj);
          kingCap = true;
        }
      } else {
        // Regular soldier (Attacker 0 or Defender 1)
        final r2 = r1 + dr, c2 = c1 + dc;
        if (r2 >= 0 && r2 < size && c2 >= 0 && c2 < size) {
          final beyond = r2 * size + c2;
          if (_isHostileForRegular(beyond, seat)) {
            board[adj] = -1;
            captured.add(adj);
          }
        }
      }
    }
    return (captured, kingCap);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final t = asStr(action['type'], 'move');
    if (t != 'move') throw GameError('未知操作');

    final from = _parseCell(action['from']);
    final to = _parseCell(action['to']);
    if (from < 0 || to < 0) {
      throw GameError('请选择要移动的己方棋子与目标格');
    }
    if (!belongsTo(board[from], seat)) {
      throw GameError('必须选择你自己的棋子');
    }
    final isKing = board[from] == 2;
    if (!isKing && isRestricted(to)) {
      throw GameError('只有国王可以停留在中央王座或四角圣殿格上');
    }
    if (!isMoveLegal(seat, from, to)) {
      throw GameError('只能沿横竖直线移动至无阻挡的空格');
    }

    final (captured, kingCap) = _applyMoveAndCaptures(seat, from, to);
    plies++;

    lastAction = {
      'seat': seat,
      'from': from,
      'to': to,
      'captured': captured,
    };

    final sideName = seat == 0 ? '黑方劫掠者' : '白方近卫军';
    final pieceName = isKing ? '国王' : (seat == 0 ? '战士' : '近卫');
    final capText = captured.isEmpty
        ? ''
        : '，夹吃 ${captured.map((c) => hnefataflCoord(size, c)).join('、')}';
    note = '${name(seat)}（$sideName）移动$pieceName ${hnefataflCoord(size, from)}→${hnefataflCoord(size, to)}$capText';

    // 1. Check if King escaped to a Corner -> Defenders (Seat 1) win!
    if (isKing && isCorner(to)) {
      _finish(1, '${name(1)}（白方）护送国王成功抵达四角圣殿 ${hnefataflCoord(size, to)}，白方获胜！');
      return;
    }

    // 2. Check if King was captured -> Attackers (Seat 0) win!
    if (kingCap || kingCell == -1) {
      _finish(0, '${name(0)}（黑方）成功合围擒获白方国王，黑方获胜！');
      return;
    }

    // 3. Check if next player has no legal moves
    final nextSeat = 1 - seat;
    if (!hasAnyLegalMove(nextSeat)) {
      _finish(seat, '${name(nextSeat)} 所有棋子均无路可走，${name(seat)} 获胜！');
      return;
    }

    // 4. Move limit check
    if (plies >= maxPlies) {
      final kCell = kingCell;
      final kr = kCell ~/ size, kc = kCell % size;
      final kOnEdge = kr == 0 || kr == size - 1 || kc == 0 || kc == size - 1;
      final att = countPieces(0);
      final def = countPieces(1);
      // Compare material ratio or King edge proximity
      if (kOnEdge || def * 2 > att) {
        _finish(1, '达到 $maxPlies 手回合上限，白方护卫阵线稳固，${name(1)} 获胜！');
      } else if (att > def * 2) {
        _finish(0, '达到 $maxPlies 手回合上限，黑方兵力占据优势，${name(0)} 获胜！');
      } else {
        _finish(2, '达到 $maxPlies 手回合上限，双方势均力敌握手言和！');
      }
      return;
    }

    turn = nextSeat;
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
      'board': List<int>.of(board),
      'turn': turn,
      'plies': plies,
      'maxPlies': maxPlies,
      'attackerCount': countPieces(0),
      'defenderCount': countPieces(1),
      'kingCell': kingCell,
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  int _cornerMinDist(int cell) {
    if (cell < 0) return 99;
    final r = cell ~/ size, c = cell % size;
    final d1 = r + c;
    final d2 = r + (size - 1 - c);
    final d3 = (size - 1 - r) + c;
    final d4 = (size - 1 - r) + (size - 1 - c);
    return min(min(d1, d2), min(d3, d4));
  }

  int _kingCornerRays(int kCell) {
    if (kCell < 0) return 0;
    final t = legalTargets(kCell);
    var count = 0;
    for (final c in t) {
      if (isCorner(c)) count++;
    }
    return count;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    final allMoves = <(int, int)>[];
    for (var i = 0; i < board.length; i++) {
      if (!belongsTo(board[i], seat)) continue;
      for (final t in legalTargets(i)) {
        allMoves.add((i, t));
      }
    }
    if (allMoves.isEmpty) return null;

    if (botLevel == 0 && rng.nextDouble() < 0.45) {
      final pick = allMoves[rng.nextInt(allMoves.length)];
      return {'type': 'move', 'from': pick.$1, 'to': pick.$2};
    }

    final saved = List<int>.of(board);
    var bestScore = -1e12;
    var bestMove = allMoves.first;

    for (final (f, t) in allMoves) {
      final isKing = board[f] == 2;
      if (seat == 1 && isKing && isCorner(t)) {
        return {'type': 'move', 'from': f, 'to': t};
      }
      final (caps, kingCap) = _applyMoveAndCaptures(seat, f, t);
      if (seat == 0 && kingCap) {
        board.setAll(0, saved);
        return {'type': 'move', 'from': f, 'to': t};
      }

      double score = caps.length * 28.0 + rng.nextDouble() * 1.5;
      final kCell = kingCell;
      if (kCell >= 0) {
        final cornerDist = _cornerMinDist(kCell);
        final cornerRays = _kingCornerRays(kCell);
        // Count attackers adjacent to King
        final kr = kCell ~/ size, kc = kCell % size;
        var adjAttackers = 0;
        for (final (dr, dc) in hnefataflDirs) {
          final r = kr + dr, c = kc + dc;
          if (r >= 0 && r < size && c >= 0 && c < size && board[r * size + c] == 0) {
            adjAttackers++;
          }
        }
        if (seat == 1) {
          score += (size * 2 - cornerDist) * 4.5 + cornerRays * 40.0 - adjAttackers * 16.0;
          if (isKing) score += 3.0;
        } else {
          score += adjAttackers * 18.0 - cornerRays * 50.0 + cornerDist * 2.5;
          // Bonus for blocking corners or moving closer to King
          final tr = t ~/ size, tc = t % size;
          final distToKing = (tr - kr).abs() + (tc - kc).abs();
          score -= distToKing * 1.4;
        }
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = (f, t);
      }
      board.setAll(0, saved);
    }

    return {'type': 'move', 'from': bestMove.$1, 'to': bestMove.$2};
  }
}
