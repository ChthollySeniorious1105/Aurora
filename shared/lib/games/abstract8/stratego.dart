import '../../src/engine.dart';

const String strategoRules = '''
# 游戏概述
- **西洋陆战棋 (Stratego)** 是经典的战争迷雾暗棋策略桌游。
- 双方各自统领一支由元帅、将军、工兵、侦察兵、间谍、地雷和军旗组成的军团，在中央隔有两处湖泊的战场上展开正面对决。

# 战场规模与编制
- **8×8 快速军团（每方 16 子）**：
  - 元帅(10)×1、将军(9)×1、上校(8)×1、少校(7)×1、上尉(6)×1、中尉(5)×1、军士(4)×1、工兵(3)×2、侦察兵(2)×3、间谍(1)×1、地雷(11)×2、军旗(0)×1。
  - 中央第 4、5 行设有两处 2×1 湖泊，不可通行。
- **10×10 标准战场（每方 40 子）**：
  - 元帅(10)×1、将军(9)×1、上校(8)×2、少校(7)×3、上尉(6)×4、中尉(5)×4、军士(4)×4、工兵(3)×5、侦察兵(2)×8、间谍(1)×1、地雷(11)×6、军旗(0)×1。
  - 中央设有两处 2×2 湖泊，不可通行。

# 走子与特殊兵种
- **军旗 (0) 与 地雷 (11)**：不可移动。
- **普通可动部队 (1, 3~10)**：每回合沿上下左右正交方向走 1 格（进入空格或向敌军发起攻击）。
- **侦察兵 (2)**：可沿上下左右直线跨越任意数量的连续空格移动或发起攻击（如同国际象棋的车，不可越过湖泊或其他棋子）。

# 战斗结算与暗子暴露
- 当一方棋子移动到敌方棋子所在格时触发战斗，**交战双方的真实军衔将同时向全场公开**：
  1. **夺取军旗 (0)**：任何可移动棋子攻击敌方军旗均可直接夺旗，**立刻赢得胜利**！
  2. **触发地雷 (11)**：唯有 **工兵 (3)** 攻击地雷时可成功排雷并占领该格；任何其他棋子攻击地雷均会被炸毁（地雷保留并暴露位置）。
  3. **间谍刺杀元帅 (1 → 10)**：若 **间谍 (1)** 主动发起攻击且目标为 **元帅 (10)**，间谍成功刺杀元帅！但若元帅主动攻击间谍，或间谍与其他任何部队交战，均按军衔数值比大小（间谍为 1 级最小）。
  4. **常规军衔比大小**：军衔高者获胜并留场，军衔低者阵亡移除；若双方同级则同归于尽。
- 当一方所有可移动棋子全部阵亡或被困无路可走时，对方同样获胜。

# 布阵与调整
- 开局采用智能军阵部署（军旗置于底线并由地雷护卫）。在走第一步棋之前（或手动布阵阶段），玩家可随时点击己方两枚棋子交换位置或重排阵型。
- 包含隐藏信息，不支持悔棋；支持认输与求和。
''';

class StrategoPiece {
  final int id;
  final int owner; // 0 or 1
  final int rank; // 0=Flag, 1=Spy, 2=Scout, 3=Miner, 4..10=Sergeant..Marshal, 11=Bomb
  bool revealed = false;
  bool moved = false;
  (int, int)? lastPos;

  StrategoPiece({
    required this.id,
    required this.owner,
    required this.rank,
  });

  bool get canMove => rank >= 1 && rank <= 10;
}

class StrategoMove {
  final int fromR;
  final int fromC;
  final int toR;
  final int toC;

  const StrategoMove(this.fromR, this.fromC, this.toR, this.toC);

  Map<String, dynamic> toJson() => {
        'from': [fromR, fromC],
        'to': [toR, toC],
      };
}

class StrategoGame extends GameEngine {
  StrategoGame(super.setup);

  static String rankName(int rank) => switch (rank) {
        0 => '军旗',
        1 => '间谍',
        2 => '侦察兵',
        3 => '工兵',
        4 => '军士',
        5 => '中尉',
        6 => '上尉',
        7 => '少校',
        8 => '上校',
        9 => '将军',
        10 => '元帅',
        11 => '地雷',
        _ => '?',
      };

  static String rankShort(int rank) => switch (rank) {
        0 => '旗',
        1 => '谍',
        2 => '侦2',
        3 => '工3',
        4 => '士4',
        5 => '尉5',
        6 => '尉6',
        7 => '校7',
        8 => '校8',
        9 => '将9',
        10 => '帅10',
        11 => '雷',
        _ => '?',
      };

  late String sizeMode; // 'quick' (8x8) | 'standard' (10x10)
  late String setupMode; // 'auto' | 'manual'
  late int gridSize; // 8 or 10
  late List<List<StrategoPiece?>> board;
  late Set<(int, int)> lakes;

  String phase = 'play'; // 'setup' or 'play'
  final List<bool> ready = [false, false];
  final List<bool> hasMoved = [false, false];

  int turn = 0;
  bool _over = false;
  int? winner;
  String? winReason;
  int stepCount = 0;
  int maxSteps = 400;

  final List<List<int>> capturedBy = [[], []];
  Map<String, dynamic>? lastMove;
  Map<String, dynamic>? lastCombat;

  @override
  bool get isOver => _over;

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'setup') {
      return [
        for (var s = 0; s < 2; s++)
          if (!ready[s]) s,
      ];
    }
    return [turn];
  }

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
    sizeMode = setup.opt<String>('size', 'quick');
    setupMode = setup.opt<String>('setup', 'auto');
    gridSize = sizeMode == 'standard' ? 10 : 8;
    maxSteps = sizeMode == 'standard' ? 500 : 280;

    board = List.generate(gridSize, (_) => List<StrategoPiece?>.filled(gridSize, null));
    lakes = <(int, int)>{};

    if (gridSize == 8) {
      // Two 2x1 lakes in rows 3..4 at cols 2 and 5
      lakes.addAll(const [(3, 2), (4, 2), (3, 5), (4, 5)]);
    } else {
      // Two 2x2 lakes in rows 4..5 at cols 2..3 and 6..7
      for (final r in const [4, 5]) {
        for (final c in const [2, 3, 6, 7]) {
          lakes.add((r, c));
        }
      }
    }

    _deploySmartArmy(0);
    _deploySmartArmy(1);

    if (setupMode == 'manual') {
      phase = 'setup';
      ready[0] = false;
      ready[1] = false;
    } else {
      phase = 'play';
      ready[0] = true;
      ready[1] = true;
    }

    hasMoved[0] = false;
    hasMoved[1] = false;
    turn = 0;
    _over = false;
    winner = null;
    winReason = null;
    stepCount = 0;
    capturedBy[0].clear();
    capturedBy[1].clear();
    lastMove = null;
    lastCombat = null;
  }

  List<int> _armyRanks() {
    if (gridSize == 8) {
      // 16 pieces per side
      return [
        0, // Flag x1
        11, 11, // Bomb x2
        10, // Marshal x1
        9, // General x1
        8, // Colonel x1
        7, // Major x1
        6, // Captain x1
        5, // Lieutenant x1
        4, // Sergeant x1
        3, 3, // Miner x2
        2, 2, 2, // Scout x3
        1, // Spy x1
      ];
    } else {
      // 40 pieces per side
      return [
        0, // Flag x1
        for (var i = 0; i < 6; i++) 11, // Bomb x6
        10, // Marshal x1
        9, // General x1
        8, 8, // Colonel x2
        7, 7, 7, // Major x3
        for (var i = 0; i < 4; i++) 6, // Captain x4
        for (var i = 0; i < 4; i++) 5, // Lieutenant x4
        for (var i = 0; i < 4; i++) 4, // Sergeant x4
        for (var i = 0; i < 5; i++) 3, // Miner x5
        for (var i = 0; i < 8; i++) 2, // Scout x8
        1, // Spy x1
      ];
    }
  }

  List<int> _setupRowsFor(int seat) {
    if (gridSize == 8) {
      return seat == 0 ? const [6, 7] : const [0, 1];
    } else {
      return seat == 0 ? const [6, 7, 8, 9] : const [0, 1, 2, 3];
    }
  }

  void _deploySmartArmy(int seat) {
    final rows = _setupRowsFor(seat);
    for (final r in rows) {
      for (var c = 0; c < gridSize; c++) {
        board[r][c] = null;
      }
    }

    final backRow = seat == 0 ? rows.last : rows.first;
    final frontRow = seat == 0 ? rows.first : rows.last;

    // Place Flag on back row (avoid corners if possible, or pick a random column and surround with 1-2 Bombs)
    final flagCol = rng.nextInt(gridSize);
    var nextId = seat * 100 + 1;
    board[backRow][flagCol] = StrategoPiece(id: nextId++, owner: seat, rank: 0);

    final remaining = _armyRanks()..remove(0);

    // Put 1 or 2 Bombs adjacent to the Flag so the Flag is well protected,
    // while leaving movable avenues so the army is never completely walled in!
    final adjFlag = <(int, int)>[];
    if (flagCol > 0) adjFlag.add((backRow, flagCol - 1));
    if (flagCol + 1 < gridSize) adjFlag.add((backRow, flagCol + 1));
    adjFlag.shuffle(rng);

    if (adjFlag.isNotEmpty && remaining.contains(11)) {
      final (br, bc) = adjFlag.first;
      board[br][bc] = StrategoPiece(id: nextId++, owner: seat, rank: 11);
      remaining.remove(11);
    }

    // Separate remaining Bombs so they don't block the entire front row
    final bombsLeft = remaining.where((x) => x == 11).toList();
    final movables = remaining.where((x) => x != 11).toList()..shuffle(rng);

    // Ensure at least 4 front-row squares receive movable pieces first
    final frontCols = [for (var c = 0; c < gridSize; c++) c]..shuffle(rng);
    for (var i = 0; i < 4 && i < frontCols.length && movables.isNotEmpty; i++) {
      final fc = frontCols[i];
      if (board[frontRow][fc] == null) {
        final rk = movables.removeLast();
        board[frontRow][fc] = StrategoPiece(id: nextId++, owner: seat, rank: rk);
      }
    }

    final pool = <int>[...bombsLeft, ...movables]..shuffle(rng);
    var idx = 0;
    for (final r in rows) {
      for (var c = 0; c < gridSize; c++) {
        if (board[r][c] == null && idx < pool.length) {
          board[r][c] = StrategoPiece(id: nextId++, owner: seat, rank: pool[idx++]);
        }
      }
    }
  }

  bool _inBounds(int r, int c) => r >= 0 && r < gridSize && c >= 0 && c < gridSize;

  bool isLake(int r, int c) => lakes.contains((r, c));

  List<StrategoMove> legalMovesFor(int seat) {
    final res = <StrategoMove>[];
    const dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)];

    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat || !p.canMove) continue;

        if (p.rank == 2) {
          // Scout: can move or attack across any number of empty non-lake squares in a straight orthogonal line
          for (final (dr, dc) in dirs) {
            var nr = r + dr, nc = c + dc;
            while (_inBounds(nr, nc) && !isLake(nr, nc)) {
              final t = board[nr][nc];
              if (t == null) {
                res.add(StrategoMove(r, c, nr, nc));
              } else {
                if (t.owner != seat) {
                  res.add(StrategoMove(r, c, nr, nc));
                }
                break;
              }
              nr += dr;
              nc += dc;
            }
          }
        } else {
          // Normal movable piece: 1 step orthogonally
          for (final (dr, dc) in dirs) {
            final nr = r + dr, nc = c + dc;
            if (!_inBounds(nr, nc) || isLake(nr, nc)) continue;
            final t = board[nr][nc];
            if (t == null || t.owner != seat) {
              res.add(StrategoMove(r, c, nr, nc));
            }
          }
        }
      }
    }
    return res;
  }

  (int, int)? _parseCoord(Object? raw, {Object? rRaw, Object? cRaw}) {
    if (raw is List && raw.length >= 2) {
      return (asInt(raw[0], -1), asInt(raw[1], -1));
    }
    if (raw is Map) {
      return (asInt(raw['r'], -1), asInt(raw['c'], -1));
    }
    if (raw is int && raw >= 0 && raw < gridSize * gridSize) {
      return (raw ~/ gridSize, raw % gridSize);
    }
    if (rRaw != null && cRaw != null) {
      return (asInt(rRaw, -1), asInt(cRaw, -1));
    }
    return null;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    final type = asStr(action['type'], 'move');

    // Allow shuffle/swap during setup phase OR before the seat has made their first move
    if (type == 'shuffle') {
      if (phase != 'setup' && hasMoved[seat]) {
        throw GameError('已开始行军，不能重新随机布阵');
      }
      _deploySmartArmy(seat);
      return;
    }

    if (type == 'swap') {
      if (phase != 'setup' && hasMoved[seat]) {
        throw GameError('已开始行军，不能交换布阵');
      }
      final a = _parseCoord(action['from'] ?? action['a'], rRaw: action['fromR'], cRaw: action['fromC']);
      final b = _parseCoord(action['to'] ?? action['b'], rRaw: action['toR'], cRaw: action['toC']);
      if (a == null || b == null) throw GameError('交换位置无效');
      final (r1, c1) = a;
      final (r2, c2) = b;
      final setupRows = _setupRowsFor(seat);
      if (!setupRows.contains(r1) ||
          !setupRows.contains(r2) ||
          !_inBounds(r1, c1) ||
          !_inBounds(r2, c2)) {
        throw GameError('只能在己方布阵区域内交换棋子');
      }
      final p1 = board[r1][c1];
      final p2 = board[r2][c2];
      if (p1 == null || p2 == null || p1.owner != seat || p2.owner != seat) {
        throw GameError('必须选择两枚己方棋子进行交换');
      }
      board[r1][c1] = p2;
      board[r2][c2] = p1;
      return;
    }

    if (phase == 'setup') {
      if (type != 'ready') {
        throw GameError('布阵阶段请先点击完成布阵');
      }
      ready[seat] = true;
      if (ready[0] && ready[1]) {
        phase = 'play';
        host.log('双方布阵完毕，战斗开始！');
      }
      return;
    }

    if (seat != turn) {
      throw GameError('还没轮到你行动');
    }

    final from = _parseCoord(action['from'], rRaw: action['fromR'], cRaw: action['fromC']);
    final to = _parseCoord(action['to'], rRaw: action['toR'], cRaw: action['toC']);
    if (from == null || to == null) {
      throw GameError('走棋坐标无效');
    }
    final (fr, fc) = from;
    final (tr, tc) = to;

    final legal = legalMovesFor(seat);
    final match = legal.where((m) => m.fromR == fr && m.fromC == fc && m.toR == tr && m.toC == tc).toList();
    if (match.isEmpty) {
      throw GameError('非法的移动或攻击目标');
    }

    final attacker = board[fr][fc]!;
    final defender = board[tr][tc];
    final dist = (tr - fr).abs() + (tc - fc).abs();

    hasMoved[seat] = true;
    attacker.moved = true;
    attacker.lastPos = (fr, fc);
    if (dist > 1) {
      // Moving multiple squares reveals a Scout!
      attacker.revealed = true;
    }

    stepCount++;

    if (defender == null) {
      board[fr][fc] = null;
      board[tr][tc] = attacker;
      lastMove = {
        'seat': seat,
        'from': [fr, fc],
        'to': [tr, tc],
        'combat': false,
      };
      lastCombat = null;
    } else {
      // Combat! Both pieces are revealed to everyone!
      attacker.revealed = true;
      defender.revealed = true;
      board[fr][fc] = null;

      String outcome; // 'attacker', 'defender', 'both', 'flag'
      if (defender.rank == 0) {
        outcome = 'flag';
        board[tr][tc] = attacker;
        capturedBy[seat].add(0);
      } else if (defender.rank == 11) {
        if (attacker.rank == 3) {
          // Miner defuses Bomb!
          outcome = 'attacker';
          board[tr][tc] = attacker;
          capturedBy[seat].add(11);
        } else {
          // Bomb destroys attacker; Bomb stays on board revealed
          outcome = 'defender';
          capturedBy[1 - seat].add(attacker.rank);
        }
      } else if (attacker.rank == 1 && defender.rank == 10) {
        // Spy initiates attack on Marshal -> Spy wins!
        outcome = 'attacker';
        board[tr][tc] = attacker;
        capturedBy[seat].add(10);
      } else if (attacker.rank > defender.rank) {
        outcome = 'attacker';
        board[tr][tc] = attacker;
        capturedBy[seat].add(defender.rank);
      } else if (attacker.rank < defender.rank) {
        outcome = 'defender';
        capturedBy[1 - seat].add(attacker.rank);
      } else {
        // Equal rank: both eliminated
        outcome = 'both';
        board[tr][tc] = null;
        capturedBy[seat].add(defender.rank);
        capturedBy[1 - seat].add(attacker.rank);
      }

      lastCombat = {
        'attackerSeat': seat,
        'attackerRank': attacker.rank,
        'attackerName': rankName(attacker.rank),
        'defenderSeat': 1 - seat,
        'defenderRank': defender.rank,
        'defenderName': rankName(defender.rank),
        'outcome': outcome,
        'at': [tr, tc],
      };

      lastMove = {
        'seat': seat,
        'from': [fr, fc],
        'to': [tr, tc],
        'combat': true,
        'outcome': outcome,
        'attackerRank': attacker.rank,
        'defenderRank': defender.rank,
      };

      if (outcome == 'flag') {
        _over = true;
        winner = seat;
        winReason = '${name(seat)} 的${rankName(attacker.rank)}夺取敌方军旗，大获全胜！';
        host.log(winReason!);
        return;
      }

      final desc = switch (outcome) {
        'attacker' => attacker.rank == 1 && defender.rank == 10
            ? '${name(seat)} 间谍成功刺杀敌方元帅！'
            : (defender.rank == 11
                ? '${name(seat)} 工兵成功排除敌方地雷！'
                : '${name(seat)} ${rankName(attacker.rank)}击败敌方${rankName(defender.rank)}'),
        'defender' => defender.rank == 11
            ? '${name(seat)} ${rankName(attacker.rank)}触雷阵亡！'
            : '${name(seat)} ${rankName(attacker.rank)}不敌敌方${rankName(defender.rank)}',
        _ => '双方${rankName(attacker.rank)}同归于尽！',
      };
      host.log(desc);
    }

    turn = 1 - turn;
    _checkGameEnd();
  }

  void _checkGameEnd() {
    if (_over) return;
    final m0 = legalMovesFor(0);
    final m1 = legalMovesFor(1);

    if (m0.isEmpty && m1.isEmpty) {
      _over = true;
      winner = null;
      winReason = '双方均无可移动部队，握手言和';
      host.log(winReason!);
      return;
    }

    if (turn == 0 && m0.isEmpty) {
      _over = true;
      winner = 1;
      winReason = '${name(0)} 无可移动部队，${name(1)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (turn == 1 && m1.isEmpty) {
      _over = true;
      winner = 0;
      winReason = '${name(1)} 无可移动部队，${name(0)} 获胜！';
      host.log(winReason!);
      return;
    }

    if (stepCount >= maxSteps) {
      _over = true;
      final s0 = _movableStrength(0);
      final s1 = _movableStrength(1);
      if (s0 == s1) {
        winner = null;
        winReason = '达到回合上限，双方战力持平判和';
      } else {
        winner = s0 > s1 ? 0 : 1;
        winReason = '达到回合上限，${name(winner!)} 战场优势获胜';
      }
      host.log(winReason!);
    }
  }

  int _movableStrength(int seat) {
    var score = 0;
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final p = board[r][c];
        if (p == null || p.owner != seat || !p.canMove) continue;
        score += p.rank * p.rank + 5;
      }
    }
    return score;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over) return null;
    if (phase == 'setup') {
      if (!ready[seat]) return {'type': 'ready'};
      return null;
    }
    if (seat != turn) return null;

    // IMPORTANT: bot(seat) ONLY inspects view(seat) so it never reads unrevealed enemy ranks!
    final v = view(seat);
    final visBoard = (v['board'] as List)
        .map((row) => (row as List).map((cell) => cell as Map<String, dynamic>?).toList())
        .toList();
    final legalRaw = (v['legalMoves'] as List).cast<Map<String, dynamic>>();
    if (legalRaw.isEmpty) return null;

    // Collect enemy positions from visBoard (only using public/revealed info)
    final enemyTargets = <({int r, int c, int? rank, bool moved})>[];
    for (var r = 0; r < gridSize; r++) {
      for (var c = 0; c < gridSize; c++) {
        final cell = visBoard[r][c];
        if (cell == null || cell['lake'] == true) continue;
        if (cell['owner'] == 1 - seat) {
          enemyTargets.add((
            r: r,
            c: c,
            rank: cell['rank'] as int?,
            moved: cell['moved'] == true,
          ));
        }
      }
    }

    Map<String, dynamic> bestMove = legalRaw.first;
    var bestScore = -1e9;

    for (final m in legalRaw) {
      final from = (m['from'] as List).cast<int>();
      final to = (m['to'] as List).cast<int>();
      final fr = from[0], fc = from[1];
      final tr = to[0], tc = to[1];

      final myCell = visBoard[fr][fc]!;
      final myRank = myCell['rank'] as int;
      final lastPos = myCell['lastPos'] as List?;
      final targetCell = visBoard[tr][tc];

      var score = 0.0;

      // Avoid immediate oscillation back to lastPos
      if (lastPos != null && lastPos[0] == tr && lastPos[1] == tc) {
        score -= 180.0;
      }

      if (targetCell != null && targetCell['owner'] == 1 - seat) {
        final eRank = targetCell['rank'] as int?;
        final eMoved = targetCell['moved'] == true;
        if (eRank != null) {
          // Revealed enemy piece!
          if (eRank == 0) {
            score += 100000.0; // Capture Flag!
          } else if (eRank == 11) {
            // Known Bomb
            if (myRank == 3) {
              score += 2500.0; // Miner defuses Bomb!
            } else {
              score -= 8000.0; // Never attack known Bomb with non-Miner!
            }
          } else if (myRank == 1 && eRank == 10) {
            score += 3500.0; // Spy assassinates Marshal!
          } else if (myRank > eRank) {
            score += 900.0 + eRank * 60.0;
          } else if (myRank == eRank) {
            score += 220.0 + eRank * 15.0;
          } else {
            score -= 1500.0;
          }
        } else {
          // Unrevealed enemy piece!
          if (myRank == 2 || myRank == 3) {
            // Scouts and Miners love probing unknown pieces (especially unmoved back-row pieces!)
            score += eMoved ? 420.0 : 580.0;
          } else if (myRank <= 6) {
            score += 450.0;
          } else {
            // High ranks (7..10) eagerly attack moved unknown pieces, and probe unmoved ones if needed
            score += eMoved ? 500.0 : 280.0;
          }
        }
      } else {
        // Moving to an empty square: advance toward the most attractive enemy target
        var minDist = 999.0;
        for (final e in enemyTargets) {
          if (e.rank == 11 && myRank != 3) continue; // Non-miners ignore known Bombs
          if (e.rank != null && e.rank! > myRank && !(myRank == 1 && e.rank == 10)) {
            continue; // Don't march toward a known stronger enemy
          }
          final d = ((tr - e.r).abs() + (tc - e.c).abs()).toDouble();
          var weight = d;
          if (e.rank == 0) weight -= 20.0;
          if (e.rank == 11 && myRank == 3) weight -= 8.0; // Miner seeks known Bomb!
          if (e.rank == 10 && myRank == 1) weight -= 10.0; // Spy seeks known Marshal!
          if (e.rank == null && !e.moved && (myRank == 3 || myRank == 2)) {
            weight -= 3.0; // Miners & Scouts head toward unmoved back-row pieces (Flag/Bombs)
          }
          if (weight < minDist) minDist = weight;
        }
        final curDist = ((fr - (seat == 0 ? 0 : gridSize - 1)).abs()).toDouble();
        final newDist = ((tr - (seat == 0 ? 0 : gridSize - 1)).abs()).toDouble();
        score += (100.0 - minDist * 14.0) + (curDist - newDist) * 8.0;
      }

      if (botLevel == 0) {
        score += rng.nextDouble() * 180.0;
      } else {
        score += rng.nextDouble() * 15.0;
      }

      if (score > bestScore) {
        bestScore = score;
        bestMove = m;
      }
    }

    return {
      'type': 'move',
      'from': bestMove['from'],
      'to': bestMove['to'],
    };
  }

  @override
  Map<String, dynamic> view(int seat) {
    final boardView = List.generate(gridSize, (r) {
      return List.generate(gridSize, (c) {
        if (isLake(r, c)) {
          return <String, dynamic>{'lake': true};
        }
        final p = board[r][c];
        if (p == null) return null;
        final canSeeRank = _over || seat == p.owner || p.revealed;
        return <String, dynamic>{
          'id': p.id,
          'owner': p.owner,
          'revealed': p.revealed,
          'moved': p.moved,
          'rank': canSeeRank ? p.rank : null,
          'code': canSeeRank ? '${p.rank}' : '?',
          'name': canSeeRank ? rankName(p.rank) : '?',
          'short': canSeeRank ? rankShort(p.rank) : '暗',
          if (seat == p.owner && p.lastPos != null)
            'lastPos': [p.lastPos!.$1, p.lastPos!.$2],
        };
      });
    });

    final legal = (!_over && phase == 'play' && (seat == 0 || seat == 1))
        ? [for (final m in legalMovesFor(seat)) m.toJson()]
        : const <Map<String, dynamic>>[];

    return {
      'size': sizeMode,
      'setup': setupMode,
      'gridSize': gridSize,
      'phase': phase,
      'ready': List<bool>.of(ready),
      'hasMoved': List<bool>.of(hasMoved),
      'canSwap': !_over && (seat == 0 || seat == 1) && (phase == 'setup' || !hasMoved[seat]),
      'setupRows': (seat == 0 || seat == 1) ? _setupRowsFor(seat) : const <int>[],
      'turn': turn,
      'over': _over,
      'winner': winner,
      'winReason': winReason,
      'stepCount': stepCount,
      'maxSteps': maxSteps,
      'board': boardView,
      'legalMoves': legal,
      'capturedBy': [
        List<int>.of(capturedBy[0]),
        List<int>.of(capturedBy[1]),
      ],
      'lastMove': lastMove,
      'lastCombat': lastCombat,
    };
  }
}
