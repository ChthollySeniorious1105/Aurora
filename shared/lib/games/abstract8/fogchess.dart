import '../../src/engine.dart';

const String fogChessRules = '''
# 游戏概述
- **雾战国际象棋 (Fog of War Chess)** 是在标准国际象棋规则基础上加入**战争迷雾**的心理博弈战棋。
- 棋盘为 8×8 标准国际象棋布局，白方（座位 0）先行，黑方（座位 1）后行。

# 战争迷雾视野规则
- 对局进行中，每位玩家**只能看到**：
  1. 自己所有在场棋子所在的格子；
  2. 自己的棋子当前可以合法移动到或吃子的格子（包括兵正前方紧邻被阻挡的格子，以及初始兵前进两格路径上的格子）。
- 棋盘上其余所有格子均处于**战争迷雾 (`?`)** 中，无法看到对手在迷雾中的棋子位置与调动。
- 旁观者在对局结束前只能看到迷雾棋盘；对局结束后，全图迷雾散去，揭晓所有棋子。

# 无将军提示与擒王获胜
- 本游戏**没有“将军 (Check)”提示，也没有“不能送王”的限制**：
  - 玩家可以将王走入敌方攻击范围，或留在敌方攻击范围内而不必应将。
  - **唯一胜负核心**：当一方**真正吃掉对方的王 (`K`)** 时，对局立刻结束，吃王方获胜！

# 特殊走法
- **兵的升变**：兵到达对方底线时升变为后 (`Q`)、车 (`R`)、象 (`B`) 或马 (`N`)（默认升变为后 `Q`）。
- **王车易位**：当王与对应侧的车均未移动过，且两者之间无棋子阻挡时，王可以横移两格并跳过车完成易位（迷雾模式下不受经过格是否受攻限制）。
- **吃过路兵**：对方兵从初始行一次前进两格越过己方兵的斜吃格时，己方兵可在紧接着的一回合内斜向吃掉该过路兵。

# 其他规则
- 因包含隐藏信息，本游戏不支持悔棋；支持认输与求和。
''';

class FogPiece {
  final int owner; // 0 = White, 1 = Black
  final String type; // 'K', 'Q', 'R', 'B', 'N', 'P'
  bool moved;

  FogPiece(this.owner, this.type, {this.moved = false});

  String get code => '${owner == 0 ? 'w' : 'b'}$type';
}

class FogMove {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;
  final String? promo;
  final bool isCastle;
  final bool isEnPassant;

  const FogMove({
    required this.fromR,
    required this.fromC,
    required this.toR,
    required this.toC,
    this.promo,
    this.isCastle = false,
    this.isEnPassant = false,
  });

  Map<String, dynamic> toJson() => {
        'from': [fromR, fromC],
        'to': [toR, toC],
        if (promo != null) 'promo': promo,
        if (isCastle) 'castle': true,
        if (isEnPassant) 'enPassant': true,
      };
}

class FogChessGame extends GameEngine {
  FogChessGame(super.setup);

  late List<List<FogPiece?>> board;
  int turn = 0;
  bool _over = false;
  int? winner;
  String? winReason;
  int stepCount = 0;
  int maxTurns = 160;
  int halfMoveClock = 0;

  /// En passant target square `(r, c)` where a capturing pawn lands, and the pawn `(pr, pc)` being captured.
  (int, int)? epTarget;
  (int, int)? epPawn;

  final List<List<String>> capturedBy = [[], []];
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
    if (winner == null) return const [1, 1];
    return rankWinners(2, [winner!]);
  }

  @override
  void resign(int seat) {
    if (_over) return;
    _over = true;
    winner = 1 - seat;
    winReason = '${name(seat)} 认输，${name(winner!)} 获胜';
    host.log(winReason!);
  }

  @override
  void agreeDraw() {
    if (_over) return;
    _over = true;
    winner = null;
    winReason = '双方同意和棋';
    host.log(winReason!);
  }

  @override
  void start() {
    maxTurns = setup.opt<int>('maxTurns', 160);
    board = List.generate(8, (_) => List<FogPiece?>.filled(8, null));

    const backRank = ['R', 'N', 'B', 'Q', 'K', 'B', 'N', 'R'];
    for (var c = 0; c < 8; c++) {
      board[0][c] = FogPiece(1, backRank[c]);
      board[1][c] = FogPiece(1, 'P');
      board[6][c] = FogPiece(0, 'P');
      board[7][c] = FogPiece(0, backRank[c]);
    }

    turn = 0;
    _over = false;
    winner = null;
    winReason = null;
    stepCount = 0;
    halfMoveClock = 0;
    epTarget = null;
    epPawn = null;
    capturedBy[0].clear();
    capturedBy[1].clear();
    lastMove = null;
  }

  bool _inBounds(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  /// Generates all legal moves for [seat].
  /// Because Fog of War Chess has no check restrictions, legal moves are all
  /// pseudo-legal moves of [seat]'s pieces.
  List<FogMove> legalMovesFor(int seat) {
    final moves = <FogMove>[];
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat) continue;
        moves.addAll(_pieceMoves(r, c, p));
      }
    }
    return moves;
  }

  List<FogMove> _pieceMoves(int r, int c, FogPiece p) {
    final res = <FogMove>[];
    final seat = p.owner;
    switch (p.type) {
      case 'P':
        final dir = seat == 0 ? -1 : 1;
        final startRow = seat == 0 ? 6 : 1;
        final promoRow = seat == 0 ? 0 : 7;
        final r1 = r + dir;
        if (_inBounds(r1, c) && board[r1][c] == null) {
          if (r1 == promoRow) {
            for (final pr in const ['Q', 'R', 'B', 'N']) {
              res.add(FogMove(fromR: r, fromC: c, toR: r1, toC: c, promo: pr));
            }
          } else {
            res.add(FogMove(fromR: r, fromC: c, toR: r1, toC: c));
            final r2 = r + 2 * dir;
            if (r == startRow && _inBounds(r2, c) && board[r2][c] == null) {
              res.add(FogMove(fromR: r, fromC: c, toR: r2, toC: c));
            }
          }
        }
        // Diagonal captures & en passant
        for (final dc in const [-1, 1]) {
          final nc = c + dc;
          if (!_inBounds(r1, nc)) continue;
          final target = board[r1][nc];
          if (target != null && target.owner != seat) {
            if (r1 == promoRow) {
              for (final pr in const ['Q', 'R', 'B', 'N']) {
                res.add(FogMove(fromR: r, fromC: c, toR: r1, toC: nc, promo: pr));
              }
            } else {
              res.add(FogMove(fromR: r, fromC: c, toR: r1, toC: nc));
            }
          } else if (epTarget == (r1, nc) && epPawn != null) {
            final epP = board[epPawn!.$1][epPawn!.$2];
            if (epP != null && epP.owner != seat) {
              res.add(FogMove(fromR: r, fromC: c, toR: r1, toC: nc, isEnPassant: true));
            }
          }
        }
      case 'N':
        const jumps = [
          (-2, -1), (-2, 1), (-1, -2), (-1, 2),
          (1, -2), (1, 2), (2, -1), (2, 1),
        ];
        for (final (dr, dc) in jumps) {
          final nr = r + dr, nc = c + dc;
          if (!_inBounds(nr, nc)) continue;
          final t = board[nr][nc];
          if (t == null || t.owner != seat) {
            res.add(FogMove(fromR: r, fromC: c, toR: nr, toC: nc));
          }
        }
      case 'B':
      case 'R':
      case 'Q':
        final dirs = <(int, int)>[
          if (p.type != 'B') ...const [(-1, 0), (1, 0), (0, -1), (0, 1)],
          if (p.type != 'R') ...const [(-1, -1), (-1, 1), (1, -1), (1, 1)],
        ];
        for (final (dr, dc) in dirs) {
          var nr = r + dr, nc = c + dc;
          while (_inBounds(nr, nc)) {
            final t = board[nr][nc];
            if (t == null) {
              res.add(FogMove(fromR: r, fromC: c, toR: nr, toC: nc));
            } else {
              if (t.owner != seat) {
                res.add(FogMove(fromR: r, fromC: c, toR: nr, toC: nc));
              }
              break;
            }
            nr += dr;
            nc += dc;
          }
        }
      case 'K':
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            final nr = r + dr, nc = c + dc;
            if (!_inBounds(nr, nc)) continue;
            final t = board[nr][nc];
            if (t == null || t.owner != seat) {
              res.add(FogMove(fromR: r, fromC: c, toR: nr, toC: nc));
            }
          }
        }
        // Castling
        final homeRow = seat == 0 ? 7 : 0;
        if (!p.moved && r == homeRow && c == 4) {
          // Kingside (col 7)
          final kr = board[homeRow][7];
          if (kr != null &&
              kr.owner == seat &&
              kr.type == 'R' &&
              !kr.moved &&
              board[homeRow][5] == null &&
              board[homeRow][6] == null) {
            res.add(FogMove(fromR: homeRow, fromC: 4, toR: homeRow, toC: 6, isCastle: true));
          }
          // Queenside (col 0)
          final qr = board[homeRow][0];
          if (qr != null &&
              qr.owner == seat &&
              qr.type == 'R' &&
              !qr.moved &&
              board[homeRow][1] == null &&
              board[homeRow][2] == null &&
              board[homeRow][3] == null) {
            res.add(FogMove(fromR: homeRow, fromC: 4, toR: homeRow, toC: 2, isCastle: true));
          }
        }
    }
    return res;
  }

  /// Computes the 8x8 visibility mask for [seat].
  /// A square (r, c) is visible to [seat] iff:
  /// 1. Occupied by [seat]'s own piece, OR
  /// 2. A square that at least one of [seat]'s pieces can legally move to or capture on right now
  ///    (including blocked pawn forward squares that the pawn directly faces).
  List<List<bool>> computeVisibility(int seat) {
    if (_over) {
      return List.generate(8, (_) => List<bool>.filled(8, true));
    }
    if (seat != 0 && seat != 1) {
      return List.generate(8, (_) => List<bool>.filled(8, false));
    }

    final vis = List.generate(8, (_) => List<bool>.filled(8, false));
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat) continue;
        vis[r][c] = true;

        // Add all legal move/capture destinations for this piece
        for (final m in _pieceMoves(r, c, p)) {
          vis[m.toR][m.toC] = true;
          if (m.isEnPassant && epPawn != null) {
            vis[epPawn!.$1][epPawn!.$2] = true;
          }
        }

        // For pawns: also include blocked forward squares directly faced
        if (p.type == 'P') {
          final dir = seat == 0 ? -1 : 1;
          final startRow = seat == 0 ? 6 : 1;
          final r1 = r + dir;
          if (_inBounds(r1, c)) {
            vis[r1][c] = true;
            final r2 = r + 2 * dir;
            if (r == startRow && board[r1][c] == null && _inBounds(r2, c)) {
              vis[r2][c] = true;
            }
          }
        }
      }
    }
    return vis;
  }

  (int, int)? _parseCoord(Object? raw, {Object? rRaw, Object? cRaw}) {
    if (raw is List && raw.length >= 2) {
      return (asInt(raw[0], -1), asInt(raw[1], -1));
    }
    if (raw is Map) {
      return (asInt(raw['r'], -1), asInt(raw['c'], -1));
    }
    if (raw is int && raw >= 0 && raw < 64) {
      return (raw ~/ 8, raw % 8);
    }
    if (rRaw != null && cRaw != null) {
      return (asInt(rRaw, -1), asInt(cRaw, -1));
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你走棋');

    final from = _parseCoord(action['from'], rRaw: action['fromR'], cRaw: action['fromC']);
    final to = _parseCoord(action['to'], rRaw: action['toR'], cRaw: action['toC']);
    if (from == null || to == null) {
      throw GameError('走棋坐标格式无效');
    }
    final (fr, fc) = from;
    final (tr, tc) = to;
    if (!_inBounds(fr, fc) || !_inBounds(tr, tc)) {
      throw GameError('坐标超出棋盘范围');
    }

    final reqPromo = asStr(action['promo'], 'Q').toUpperCase();
    final promo = const ['Q', 'R', 'B', 'N'].contains(reqPromo) ? reqPromo : 'Q';

    final legal = legalMovesFor(seat);
    final matching = legal.where((m) {
      if (m.fromR != fr || m.fromC != fc || m.toR != tr || m.toC != tc) return false;
      if (m.promo != null && m.promo != promo) return false;
      return true;
    }).toList();

    if (matching.isEmpty) {
      throw GameError('非法的走法');
    }

    final move = matching.first;
    final piece = board[fr][fc]!;
    FogPiece? captured;

    if (move.isEnPassant && epPawn != null) {
      captured = board[epPawn!.$1][epPawn!.$2];
      board[epPawn!.$1][epPawn!.$2] = null;
    } else {
      captured = board[tr][tc];
    }

    board[fr][fc] = null;
    if (move.promo != null) {
      board[tr][tc] = FogPiece(seat, move.promo!, moved: true);
    } else {
      piece.moved = true;
      board[tr][tc] = piece;
    }

    if (move.isCastle) {
      if (tc == 6) {
        final rook = board[fr][7];
        board[fr][7] = null;
        if (rook != null) {
          rook.moved = true;
          board[fr][5] = rook;
        }
      } else if (tc == 2) {
        final rook = board[fr][0];
        board[fr][0] = null;
        if (rook != null) {
          rook.moved = true;
          board[fr][3] = rook;
        }
      }
    }

    // Update en passant state
    if (piece.type == 'P' && (tr - fr).abs() == 2) {
      epTarget = ((fr + tr) ~/ 2, fc);
      epPawn = (tr, tc);
    } else {
      epTarget = null;
      epPawn = null;
    }

    stepCount++;
    if (piece.type == 'P' || captured != null) {
      halfMoveClock = 0;
    } else {
      halfMoveClock++;
    }

    if (captured != null) {
      capturedBy[seat].add(captured.code);
    }

    lastMove = {
      'seat': seat,
      'from': [fr, fc],
      'to': [tr, tc],
      'piece': piece.code,
      'captured': captured?.code,
      'promo': move.promo,
      'castle': move.isCastle,
    };

    if (captured != null && captured.type == 'K') {
      _over = true;
      winner = seat;
      winReason = '${name(seat)} 擒获敌方国王，赢得胜利！';
      host.log(winReason!);
      return;
    }

    if (captured != null) {
      host.log('${name(seat)} 吃掉了敌方一枚${_pieceName(captured.type)}');
    }

    turn = 1 - turn;

    // Check if next player has no legal moves or turn limit reached
    final nextMoves = legalMovesFor(turn);
    if (nextMoves.isEmpty) {
      _over = true;
      winner = seat;
      winReason = '${name(turn)} 无子可动，${name(seat)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (stepCount >= maxTurns || halfMoveClock >= 80) {
      _over = true;
      final s0 = _materialScore(0);
      final s1 = _materialScore(1);
      if (s0 == s1) {
        winner = null;
        winReason = '达到回合上限，双方子力相当判和';
      } else {
        winner = s0 > s1 ? 0 : 1;
        winReason = '达到回合上限，${name(winner!)} 子力优势获胜';
      }
      host.log(winReason!);
    }
  }

  int _materialScore(int seat) {
    var total = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat) continue;
        total += _pieceValue(p.type);
      }
    }
    return total;
  }

  static int _pieceValue(String type) => switch (type) {
        'K' => 10000,
        'Q' => 900,
        'R' => 500,
        'B' => 330,
        'N' => 310,
        'P' => 100,
        _ => 0,
      };

  static String _pieceName(String type) => switch (type) {
        'K' => '王',
        'Q' => '后',
        'R' => '车',
        'B' => '象',
        'N' => '马',
        'P' => '兵',
        _ => '棋子',
      };

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    // IMPORTANT: bot(seat) ONLY uses seat's visible view!
    final v = view(seat);
    final visBoard = (v['board'] as List).map((row) => (row as List).cast<String>()).toList();
    final legalRaw = (v['legalMoves'] as List).cast<Map<String, dynamic>>();
    if (legalRaw.isEmpty) return null;

    if (botLevel == 0) {
      // Even level 0 always takes an exposed enemy King if visible
      for (final m in legalRaw) {
        final to = (m['to'] as List).cast<int>();
        final targetCode = visBoard[to[0]][to[1]];
        if (targetCode.endsWith('K')) {
          return {
            'type': 'move',
            'from': m['from'],
            'to': m['to'],
            if (m['promo'] != null) 'promo': m['promo'],
          };
        }
      }
      if (rng.nextDouble() < 0.5) {
        final pick = legalRaw[rng.nextInt(legalRaw.length)];
        return {
          'type': 'move',
          'from': pick['from'],
          'to': pick['to'],
          if (pick['promo'] != null) 'promo': pick['promo'],
        };
      }
    }

    // Build set of squares attacked by VISIBLE enemy pieces so we can protect our King / avoid blunders
    final visEnemyAttacks = <(int, int)>{};
    final oppPrefix = seat == 0 ? 'b' : 'w';
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        final cell = visBoard[r][c];
        if (!cell.startsWith(oppPrefix)) continue;
        final eType = cell.substring(1);
        _addVisibleAttacks(visBoard, r, c, 1 - seat, eType, visEnemyAttacks);
      }
    }

    // Find our King position from visible board
    (int, int)? myKingPos;
    final myKingCode = '${seat == 0 ? 'w' : 'b'}K';
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (visBoard[r][c] == myKingCode) {
          myKingPos = (r, c);
        }
      }
    }
    final kingInVisibleDanger = myKingPos != null && visEnemyAttacks.contains(myKingPos);

    Map<String, dynamic> bestMove = legalRaw.first;
    var bestScore = -1e9;

    for (final m in legalRaw) {
      final from = (m['from'] as List).cast<int>();
      final to = (m['to'] as List).cast<int>();
      final fr = from[0], fc = from[1];
      final tr = to[0], tc = to[1];
      final promo = m['promo'] as String?;

      // Ignore underpromotions in bot search
      if (promo != null && promo != 'Q') continue;

      final moverCode = visBoard[fr][fc];
      final moverType = moverCode.length >= 2 ? moverCode.substring(1) : 'P';
      final targetCode = visBoard[tr][tc];

      var score = 0.0;

      // 1. Capturing a visible enemy piece
      if (targetCode.startsWith(oppPrefix)) {
        final capType = targetCode.substring(1);
        score += _pieceValue(capType) * 12.0 - _pieceValue(moverType) * 0.4;
      } else if (m['enPassant'] == true) {
        score += _pieceValue('P') * 11.0;
      }

      // 2. Promotion bonus
      if (promo == 'Q') {
        score += 800.0;
      }

      // 3. Advancement & center control (encourages scouting into fog & attacking enemy back ranks)
      final forwardProgress = seat == 0 ? (7 - tr) : tr;
      if (moverType == 'P') {
        score += forwardProgress * 18.0;
      } else if (moverType != 'K') {
        score += forwardProgress * 9.0;
        final centerDist = (3.5 - tr).abs() + (3.5 - tc).abs();
        score += (7.0 - centerDist) * 4.0;
      } else {
        // Keep King safe unless escaping danger
        if (m['castle'] == true) score += 60.0;
        if (!kingInVisibleDanger) {
          score -= 25.0;
        }
      }

      // 4. King safety against visible threats
      if (moverType == 'K') {
        if (visEnemyAttacks.contains((tr, tc))) {
          score -= 5000.0;
        } else if (kingInVisibleDanger) {
          score += 2000.0; // Escapes visible attack!
        }
      } else {
        if (visEnemyAttacks.contains((tr, tc))) {
          score -= _pieceValue(moverType) * (botLevel >= 2 ? 6.0 : 3.0);
        }
      }

      score += rng.nextDouble() * 8.0;
      if (score > bestScore) {
        bestScore = score;
        bestMove = m;
      }
    }

    return {
      'type': 'move',
      'from': bestMove['from'],
      'to': bestMove['to'],
      if (bestMove['promo'] != null) 'promo': bestMove['promo'],
    };
  }

  void _addVisibleAttacks(
    List<List<String>> visBoard,
    int r,
    int c,
    int owner,
    String type,
    Set<(int, int)> out,
  ) {
    switch (type) {
      case 'P':
        final dir = owner == 0 ? -1 : 1;
        for (final dc in const [-1, 1]) {
          if (_inBounds(r + dir, c + dc)) out.add((r + dir, c + dc));
        }
      case 'N':
        const jumps = [
          (-2, -1), (-2, 1), (-1, -2), (-1, 2),
          (1, -2), (1, 2), (2, -1), (2, 1),
        ];
        for (final (dr, dc) in jumps) {
          if (_inBounds(r + dr, c + dc)) out.add((r + dr, c + dc));
        }
      case 'K':
        for (var dr = -1; dr <= 1; dr++) {
          for (var dc = -1; dc <= 1; dc++) {
            if (dr == 0 && dc == 0) continue;
            if (_inBounds(r + dr, c + dc)) out.add((r + dr, c + dc));
          }
        }
      case 'B':
      case 'R':
      case 'Q':
        final dirs = <(int, int)>[
          if (type != 'B') ...const [(-1, 0), (1, 0), (0, -1), (0, 1)],
          if (type != 'R') ...const [(-1, -1), (-1, 1), (1, -1), (1, 1)],
        ];
        for (final (dr, dc) in dirs) {
          var nr = r + dr, nc = c + dc;
          while (_inBounds(nr, nc)) {
            out.add((nr, nc));
            final cell = visBoard[nr][nc];
            if (cell != '' && cell != '?') break;
            nr += dr;
            nc += dc;
          }
        }
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final vis = computeVisibility(seat);
    final boardView = List.generate(8, (r) {
      return List.generate(8, (c) {
        if (!vis[r][c]) return '?';
        final p = board[r][c];
        return p == null ? '' : p.code;
      });
    });

    final legal = (!_over && (seat == 0 || seat == 1))
        ? [for (final m in legalMovesFor(seat)) m.toJson()]
        : const <Map<String, dynamic>>[];

    // Sanitize lastMove so hidden enemy squares are never leaked
    Map<String, dynamic>? safeLastMove;
    if (lastMove != null) {
      if (_over || lastMove!['seat'] == seat) {
        safeLastMove = Map<String, dynamic>.of(lastMove!);
      } else if (seat == 0 || seat == 1) {
        final fr = (lastMove!['from'] as List)[0] as int;
        final fc = (lastMove!['from'] as List)[1] as int;
        final tr = (lastMove!['to'] as List)[0] as int;
        final tc = (lastMove!['to'] as List)[1] as int;
        safeLastMove = {
          'seat': lastMove!['seat'],
          if (vis[fr][fc]) 'from': [fr, fc],
          if (vis[tr][tc] || lastMove!['captured'] != null) 'to': [tr, tc],
          if (lastMove!['captured'] != null) 'captured': lastMove!['captured'],
        };
      }
    }

    var visibleCount = 0;
    for (var r = 0; r < 8; r++) {
      for (var c = 0; c < 8; c++) {
        if (vis[r][c]) visibleCount++;
      }
    }

    return {
      'turn': turn,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'stepCount': stepCount,
      'maxTurns': maxTurns,
      'board': boardView,
      'visible': vis,
      'visibleCount': visibleCount,
      'legalMoves': legal,
      'capturedBy': [
        List<String>.of(capturedBy[0]),
        List<String>.of(capturedBy[1]),
      ],
      'lastMove': safeLastMove,
    };
  }
}
