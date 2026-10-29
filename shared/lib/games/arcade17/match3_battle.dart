import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a17_util.dart';

class Match3SwapResult {
  final bool valid;
  final int comboCount;
  final int totalCleared;
  final int specialsCreated;
  final int specialsTriggered;
  final int iceThawed;
  final int iceAttackCount;
  final int pointsGained;
  final bool reshuffled;
  final List<int> initialMatchedCells;

  const Match3SwapResult({
    required this.valid,
    this.comboCount = 0,
    this.totalCleared = 0,
    this.specialsCreated = 0,
    this.specialsTriggered = 0,
    this.iceThawed = 0,
    this.iceAttackCount = 0,
    this.pointsGained = 0,
    this.reshuffled = false,
    this.initialMatchedCells = const [],
  });
}

class Match3Logic {
  static const int boardSize = 7;
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];

  /// Special gem constants:
  /// `0`: Normal gem
  /// `1`: ⚡ Line Blaster (激光炸弹 — formed by 4-in-a-row, clears row & col)
  /// `2`: 🌈 Rainbow Prism (彩虹棱镜 — formed by 5+-in-a-row, clears all gems of target color)
  static const int specialNone = 0;
  static const int specialLineBlaster = 1;
  static const int specialRainbowPrism = 2;

  static bool areOrthogonallyAdjacent(int idx1, int idx2, [int size = boardSize]) {
    if (idx1 < 0 || idx1 >= size * size || idx2 < 0 || idx2 >= size * size) return false;
    final r1 = idx1 ~/ size, c1 = idx1 % size;
    final r2 = idx2 ~/ size, c2 = idx2 % size;
    return (r1 - r2).abs() + (c1 - c2).abs() == 1;
  }

  /// Finds all horizontal and vertical runs of `>= 3` identical non-zero gem colors.
  static List<List<int>> findRuns(List<int> board, [int size = boardSize]) {
    final runs = <List<int>>[];

    // Horizontal runs
    for (var r = 0; r < size; r++) {
      var c = 0;
      while (c < size) {
        final col = board[r * size + c];
        if (col <= 0) {
          c++;
          continue;
        }
        var end = c + 1;
        while (end < size && board[r * size + end] == col) {
          end++;
        }
        if (end - c >= 3) {
          runs.add([for (var k = c; k < end; k++) r * size + k]);
        }
        c = end;
      }
    }

    // Vertical runs
    for (var c = 0; c < size; c++) {
      var r = 0;
      while (r < size) {
        final col = board[r * size + c];
        if (col <= 0) {
          r++;
          continue;
        }
        var end = r + 1;
        while (end < size && board[end * size + c] == col) {
          end++;
        }
        if (end - r >= 3) {
          runs.add([for (var k = r; k < end; k++) k * size + c]);
        }
        r = end;
      }
    }

    return runs;
  }

  static bool hasAutoMatch(List<int> board, [int size = boardSize]) =>
      findRuns(board, size).isNotEmpty;

  /// Checks whether swapping two orthogonally adjacent indices [idx1] and [idx2]
  /// creates at least one `>= 3` match or activates a special power gem.
  static bool isValidSwap(
    List<int> board,
    int idx1,
    int idx2, [
    List<int>? special,
    int size = boardSize,
  ]) {
    if (!areOrthogonallyAdjacent(idx1, idx2, size)) return false;
    if (board[idx1] <= 0 || board[idx2] <= 0) return false;
    if (special != null &&
        idx1 < special.length &&
        idx2 < special.length &&
        (special[idx1] > 0 || special[idx2] > 0)) {
      return true;
    }
    if (board[idx1] == board[idx2]) return false;

    final tmp = List<int>.of(board);
    final t = tmp[idx1];
    tmp[idx1] = tmp[idx2];
    tmp[idx2] = t;
    return hasAutoMatch(tmp, size);
  }

  /// Returns all valid orthogonally adjacent swaps `(idx1, idx2)` (`idx1 < idx2`).
  static List<(int, int)> findValidSwaps(
    List<int> board, [
    List<int>? special,
    int size = boardSize,
  ]) {
    final out = <(int, int)>[];
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idx = r * size + c;
        if (c + 1 < size) {
          final right = r * size + (c + 1);
          if (isValidSwap(board, idx, right, special, size)) {
            out.add((idx, right));
          }
        }
        if (r + 1 < size) {
          final down = (r + 1) * size + c;
          if (isValidSwap(board, idx, down, special, size)) {
            out.add((idx, down));
          }
        }
      }
    }
    return out;
  }

  /// Generates a `size × size` initial board with no pre-existing 3-in-a-row
  /// and guaranteed at least 1 valid swap.
  static List<int> generateInitialBoard(int colors, Random rng, [int size = boardSize]) {
    final n = size * size;
    for (var attempt = 0; attempt < 50; attempt++) {
      final board = List<int>.filled(n, 0);
      for (var r = 0; r < size; r++) {
        for (var c = 0; c < size; c++) {
          final forbidden = <int>{};
          if (c >= 2 && board[r * size + c - 1] == board[r * size + c - 2]) {
            forbidden.add(board[r * size + c - 1]);
          }
          if (r >= 2 && board[(r - 1) * size + c] == board[(r - 2) * size + c]) {
            forbidden.add(board[(r - 1) * size + c]);
          }
          final choices = [
            for (var col = 1; col <= colors; col++)
              if (!forbidden.contains(col)) col,
          ];
          board[r * size + c] = choices[rng.nextInt(choices.length)];
        }
      }
      if (!hasAutoMatch(board, size) && findValidSwaps(board, null, size).isNotEmpty) {
        return board;
      }
    }

    // Deterministic guaranteed fallback with no 3-in-a-row and valid swaps at (0,1)<->(1,1)
    final fallback = List<int>.generate(n, (i) {
      final r = i ~/ size, c = i % size;
      return ((r * 2 + c) % colors) + 1;
    });
    // Ensure a valid swap at (0,0)-(0,1)-(1,2)
    fallback[0] = 1;
    fallback[1] = 1;
    fallback[2] = 2;
    fallback[size + 2] = 1;
    return fallback;
  }

  /// Ensures [board] has no immediate 3-in-a-row and has at least one valid swap.
  static bool ensurePlayableBoard(
    List<int> board,
    List<int> special,
    int colors,
    Random rng, [
    int size = boardSize,
  ]) {
    if (findValidSwaps(board, special, size).isNotEmpty) return false;
    final fresh = generateInitialBoard(colors, rng, size);
    for (var i = 0; i < board.length; i++) {
      board[i] = fresh[i];
    }
    return true;
  }

  /// Applies a swap between [idx1] and [idx2], resolving all special gem creations,
  /// special gem activations, ice shield thawing, gravity drops, and cascade combos.
  static Match3SwapResult executeSwap({
    required List<int> board,
    required List<int> special,
    required List<int> frozen,
    required int idx1,
    required int idx2,
    required int colors,
    required Random rng,
    int size = boardSize,
  }) {
    if (!isValidSwap(board, idx1, idx2, special, size)) {
      return const Match3SwapResult(valid: false);
    }

    // Perform swap
    final tb = board[idx1];
    board[idx1] = board[idx2];
    board[idx2] = tb;

    final ts = special[idx1];
    special[idx1] = special[idx2];
    special[idx2] = ts;

    final tf = frozen[idx1];
    frozen[idx1] = frozen[idx2];
    frozen[idx2] = tf;

    final n = size * size;
    var comboCount = 0;
    var totalCleared = 0;
    var specialsCreated = 0;
    var specialsTriggered = 0;
    var iceThawed = 0;
    final firstWaveMatched = <int>[];

    for (var wave = 1; wave <= 25; wave++) {
      final runs = findRuns(board, size);
      final directSpecialOnSwap = wave == 1 && (special[idx1] > 0 || special[idx2] > 0);
      if (runs.isEmpty && !directSpecialOnSwap) break;

      comboCount++;
      final matchedCells = <int>{};
      final newSpecialAt = <int, int>{};
      final newSpecialColorAt = <int, int>{};

      for (final run in runs) {
        matchedCells.addAll(run);
        if (run.length >= 4) {
          final specType = run.length >= 5 ? specialRainbowPrism : specialLineBlaster;
          var targetCell = run[run.length ~/ 2];
          if (wave == 1) {
            if (run.contains(idx2) && frozen[idx2] == 0) {
              targetCell = idx2;
            } else if (run.contains(idx1) && frozen[idx1] == 0) {
              targetCell = idx1;
            }
          }
          final prevType = newSpecialAt[targetCell] ?? 0;
          if (specType > prevType) {
            newSpecialAt[targetCell] = specType;
            newSpecialColorAt[targetCell] = board[run.first];
          }
        }
      }

      if (directSpecialOnSwap) {
        if (special[idx1] > 0) matchedCells.add(idx1);
        if (special[idx2] > 0) matchedCells.add(idx2);
      }

      // Expand matchedCells via existing special power gems
      final specQueue = Queue<int>();
      final triggeredSpecCells = <int>{};
      for (final u in matchedCells) {
        if (special[u] > 0) specQueue.add(u);
      }

      while (specQueue.isNotEmpty) {
        final u = specQueue.removeFirst();
        if (!triggeredSpecCells.add(u)) continue;
        final spType = special[u];
        if (spType <= 0) continue;
        specialsTriggered++;

        if (spType == specialLineBlaster) {
          final ru = u ~/ size, cu = u % size;
          for (var k = 0; k < size; k++) {
            final rowCell = ru * size + k;
            final colCell = k * size + cu;
            if (matchedCells.add(rowCell) && special[rowCell] > 0) {
              specQueue.add(rowCell);
            }
            if (matchedCells.add(colCell) && special[colCell] > 0) {
              specQueue.add(colCell);
            }
          }
        } else if (spType == specialRainbowPrism) {
          var targetColor = board[u];
          if (wave == 1) {
            if (u == idx1 && board[idx2] > 0) {
              targetColor = board[idx2];
            } else if (u == idx2 && board[idx1] > 0) {
              targetColor = board[idx1];
            }
          }
          for (var i = 0; i < n; i++) {
            if (board[i] == targetColor) {
              if (matchedCells.add(i) && special[i] > 0) {
                specQueue.add(i);
              }
            }
          }
        }
      }

      if (wave == 1) {
        firstWaveMatched.addAll(matchedCells.toList()..sort());
      }

      // Thaw orthogonally adjacent frozen cells
      final adjFrozen = <int>{};
      for (final u in matchedCells) {
        final r = u ~/ size, c = u % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nb = nr * size + nc;
          if (!matchedCells.contains(nb) && frozen[nb] > 0) {
            adjFrozen.add(nb);
          }
        }
      }
      for (final nb in adjFrozen) {
        frozen[nb] = 0;
        iceThawed++;
      }

      // Clear matched gems or thaw included frozen gems / spawn newly created specials
      for (final u in matchedCells) {
        if (newSpecialAt.containsKey(u)) {
          board[u] = newSpecialColorAt[u] ?? max(1, board[u]);
          special[u] = newSpecialAt[u]!;
          frozen[u] = 0;
          specialsCreated++;
          totalCleared++;
        } else if (frozen[u] > 0 && !triggeredSpecCells.contains(u)) {
          // Frozen gem included in match thaws first before it can be cleared on a future match
          frozen[u] = 0;
          iceThawed++;
          totalCleared++;
        } else {
          board[u] = 0;
          special[u] = 0;
          frozen[u] = 0;
          totalCleared++;
        }
      }

      // Gravity drop & deterministic refill per column
      for (var c = 0; c < size; c++) {
        var writeR = size - 1;
        for (var readR = size - 1; readR >= 0; readR--) {
          final idx = readR * size + c;
          if (board[idx] > 0) {
            if (writeR != readR) {
              final dst = writeR * size + c;
              board[dst] = board[idx];
              special[dst] = special[idx];
              frozen[dst] = frozen[idx];
            }
            writeR--;
          }
        }
        while (writeR >= 0) {
          final dst = writeR * size + c;
          board[dst] = rng.nextInt(colors) + 1;
          special[dst] = 0;
          frozen[dst] = 0;
          writeR--;
        }
      }
    }

    final reshuffled = ensurePlayableBoard(board, special, colors, rng, size);
    final iceAttackCount = (comboCount >= 2 || totalCleared >= 5)
        ? min(6, (comboCount >= 2 ? comboCount : 1) + (totalCleared >= 5 ? (totalCleared - 4) : 0))
        : 0;
    final pointsGained = totalCleared * 10 +
        (comboCount > 1 ? (comboCount - 1) * 30 : 0) +
        specialsCreated * 35 +
        specialsTriggered * 45 +
        iceThawed * 15;

    return Match3SwapResult(
      valid: true,
      comboCount: comboCount,
      totalCleared: totalCleared,
      specialsCreated: specialsCreated,
      specialsTriggered: specialsTriggered,
      iceThawed: iceThawed,
      iceAttackCount: iceAttackCount,
      pointsGained: pointsGained,
      reshuffled: reshuffled,
      initialMatchedCells: firstWaveMatched,
    );
  }

  /// Launches [count] Ice Shields onto unfrozen cells of [targetFrozen] using [rng].
  static int applyIceAttack(List<int> targetFrozen, int count, Random rng) {
    if (count <= 0) return 0;
    final unfrozen = <int>[
      for (var i = 0; i < targetFrozen.length; i++)
        if (targetFrozen[i] == 0) i,
    ];
    if (unfrozen.isEmpty) return 0;
    unfrozen.shuffle(rng);
    final actual = min(count, unfrozen.length);
    for (var i = 0; i < actual; i++) {
      targetFrozen[unfrozen[i]] = 1;
    }
    return actual;
  }
}

/// 宝石消消乐对战 (Match-3 Battle, 1-6 人).
class Match3BattleGame extends GameEngine {
  Match3BattleGame(super.setup);

  static const int boardSize = Match3Logic.boardSize;

  late int maxMoves;
  late int colors;
  int totalActions = 0;
  late List<Match3Player> ps;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<List<int>> get specials => [for (final p in ps) p.special];
  List<List<int>> get frozen => [for (final p in ps) p.frozen];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a17Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 720, 2 => 240, _ => 420 };

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    p.resignNo = ++_resigns;
    p.status = 'resigned';
    host.log('${name(seat)} 认输');
    final still = [for (var s = 0; s < players; s++) if (ps[s].resignNo == 0) s];
    if (still.isEmpty || (players > 1 && still.length <= 1)) {
      _finish(still.isEmpty ? '所有人都已认输' : '其他人都已认输');
    } else {
      _checkAllDone();
    }
  }

  @override
  void start() {
    maxMoves = setup.opt<int>('moves', 15) == 10 ? 10 : 15;
    colors = setup.opt<int>('colors', 5) == 6 ? 6 : 5;
    final baseSeed = rng.nextInt(1 << 30);

    ps = [
      for (var s = 0; s < players; s++)
        () {
          final pRng = Random(baseSeed ^ ((s + 1) * 0x9E3779B9));
          final initBoard = Match3Logic.generateInitialBoard(colors, pRng, boardSize);
          return Match3Player(
            board: initBoard,
            rng: pRng,
            movesLeft: maxMoves,
          );
        }(),
    ];

    host.log('宝石消消乐对战开始（7×7 棋盘，$colors 色宝石，每人 $maxMoves 步）！连成 4/5 颗合成激光炸弹与彩虹棱镜，连锁即可发射冰封护盾攻击对手！');
  }

  bool _active(int s) => ps[s].resignNo == 0 && ps[s].status == 'play' && ps[s].movesLeft > 0;

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a17Rotated([for (var s = 0; s < players; s++) if (_active(s)) s], totalActions);
  }

  (int, int) _resolveSwapIndices(Map<String, dynamic> a) {
    if (a.containsKey('i1') && a.containsKey('i2')) {
      final i1 = asInt(a['i1'], -1);
      final i2 = asInt(a['i2'], -1);
      if (i1 < 0 || i1 >= boardSize * boardSize || i2 < 0 || i2 >= boardSize * boardSize) {
        throw GameError('格子索引超出 7×7 棋盘范围');
      }
      return (i1, i2);
    }
    final r1 = asInt(a['r1'], -1);
    final c1 = asInt(a['c1'], -1);
    final r2 = asInt(a['r2'], -1);
    final c2 = asInt(a['c2'], -1);
    if (r1 < 0 ||
        r1 >= boardSize ||
        c1 < 0 ||
        c1 >= boardSize ||
        r2 < 0 ||
        r2 >= boardSize ||
        c2 < 0 ||
        c2 >= boardSize) {
      throw GameError('行列坐标超出 7×7 棋盘范围');
    }
    return (r1 * boardSize + c1, r2 * boardSize + c2);
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (!_active(seat)) throw GameError('你已完成所有步数');

    switch (type) {
      case 'swap':
        final (idx1, idx2) = _resolveSwapIndices(a);
        if (!Match3Logic.areOrthogonallyAdjacent(idx1, idx2, boardSize)) {
          throw GameError('只能交换上下左右正交相邻的两颗宝石');
        }
        final res = Match3Logic.executeSwap(
          board: p.board,
          special: p.special,
          frozen: p.frozen,
          idx1: idx1,
          idx2: idx2,
          colors: colors,
          rng: p.rng,
          size: boardSize,
        );
        if (!res.valid) {
          throw GameError('该交换无法形成三连消除');
        }

        p.movesLeft--;
        p.movesUsed++;
        p.score += res.pointsGained;
        p.totalCleared += res.totalCleared;
        p.lastCombo = res.comboCount;
        p.lastCleared = res.totalCleared;
        p.lastPoints = res.pointsGained;
        p.lastSwap = [idx1, idx2];
        if (res.comboCount > p.maxCombo) {
          p.maxCombo = res.comboCount;
        }
        p.specialsCreated += res.specialsCreated;
        p.specialsTriggered += res.specialsTriggered;
        p.iceThawed += res.iceThawed;

        // Launch multiplayer garbage ice attack onto opponents
        var totalIceSentThisTurn = 0;
        if (res.iceAttackCount > 0 && players > 1) {
          for (var opp = 0; opp < players; opp++) {
            if (opp == seat || ps[opp].resignNo > 0 || ps[opp].status != 'play') continue;
            final frozenAdded = Match3Logic.applyIceAttack(ps[opp].frozen, res.iceAttackCount, p.rng);
            ps[opp].iceReceived += frozenAdded;
            totalIceSentThisTurn += frozenAdded;
          }
          p.iceSent += totalIceSentThisTurn;
        }
        p.lastIceAttack = res.iceAttackCount;

        if (res.comboCount >= 2 || res.specialsCreated > 0 || res.iceAttackCount > 0) {
          final tags = <String>[
            if (res.comboCount >= 2) '${res.comboCount} 连击',
            '消除 ${res.totalCleared} 颗',
            if (res.specialsCreated > 0) '合成特效×${res.specialsCreated}',
            if (res.iceAttackCount > 0 && players > 1) '发射 ❄️×${res.iceAttackCount}',
          ];
          host.log('${name(seat)} 达成 ${tags.join(" · ")}，+${res.pointsGained} 分！');
        }

        totalActions++;
        if (p.movesLeft <= 0) {
          p.status = 'done';
          host.log('${name(seat)} 完成了全部 $maxMoves 步，总分 ${p.score} 分！');
        }
        _checkAllDone();

      case 'reshuffle':
        Match3Logic.ensurePlayableBoard(p.board, p.special, colors, p.rng, boardSize);
        totalActions++;

      default:
        throw GameError('未知操作');
    }
  }

  void _checkAllDone() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_active(s)) s].isEmpty) {
      _finish('全员完成所有步数');
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a17Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.maxCombo != pb.maxCombo) return pb.maxCombo - pa.maxCombo;
      return pb.totalCleared - pa.totalCleared;
    }, (s) => {
          'score': ps[s].score,
          'cleared': ps[s].totalCleared,
          'maxCombo': ps[s].maxCombo,
          'iceSent': ps[s].iceSent,
        });
    host.log('游戏结束（$why）！冠军：${a17Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_active(seat)) return null;
    final p = ps[seat];
    var swaps = Match3Logic.findValidSwaps(p.board, p.special, boardSize);
    if (swaps.isEmpty) {
      Match3Logic.ensurePlayableBoard(p.board, p.special, colors, p.rng, boardSize);
      swaps = Match3Logic.findValidSwaps(p.board, p.special, boardSize);
      if (swaps.isEmpty) return null;
    }

    (int, int) chosen = swaps[rng.nextInt(swaps.length)];
    if (botLevel >= 1 && swaps.length > 1) {
      var bestScore = -1;
      for (final sw in swaps) {
        final bCopy = List<int>.of(p.board);
        final sCopy = List<int>.of(p.special);
        final fCopy = List<int>.of(p.frozen);
        final t = bCopy[sw.$1];
        bCopy[sw.$1] = bCopy[sw.$2];
        bCopy[sw.$2] = t;
        final runs = Match3Logic.findRuns(bCopy, boardSize);
        var sc = 0;
        for (final r in runs) {
          sc += r.length * 10 + (r.length >= 4 ? 30 : 0);
        }
        if (sCopy[sw.$1] > 0 || sCopy[sw.$2] > 0) sc += 50;
        if (fCopy[sw.$1] > 0 || fCopy[sw.$2] > 0) sc += 15;
        if (sc > bestScore) {
          bestScore = sc;
          chosen = sw;
        }
      }
    }

    return {
      'type': 'swap',
      'r1': chosen.$1 ~/ boardSize,
      'c1': chosen.$1 % boardSize,
      'r2': chosen.$2 ~/ boardSize,
      'c2': chosen.$2 % boardSize,
    };
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final myBoard = me?.board ?? List<int>.filled(boardSize * boardSize, 1);
    final mySpecial = me?.special ?? List<int>.filled(boardSize * boardSize, 0);
    final myFrozen = me?.frozen ?? List<int>.filled(boardSize * boardSize, 0);
    final validSwaps = Match3Logic.findValidSwaps(myBoard, mySpecial, boardSize);

    return {
      'phase': over ? 'over' : 'play',
      'size': boardSize,
      'colors': colors,
      'maxMoves': maxMoves,
      'movesLeft': me?.movesLeft ?? 0,
      'movesUsed': me?.movesUsed ?? 0,
      'board': myBoard,
      'special': mySpecial,
      'frozen': myFrozen,
      'frozenCount': myFrozen.where((v) => v > 0).length,
      'specialCount': mySpecial.where((v) => v > 0).length,
      'validSwapCount': validSwaps.length,
      'hintSwap': validSwaps.isNotEmpty ? [validSwaps.first.$1, validSwaps.first.$2] : const <int>[],
      'lastSwap': me?.lastSwap ?? const <int>[],
      'lastCombo': me?.lastCombo ?? 0,
      'lastCleared': me?.lastCleared ?? 0,
      'lastPoints': me?.lastPoints ?? 0,
      'lastIceAttack': me?.lastIceAttack ?? 0,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'score': ps[s].score,
            'status': ps[s].status,
            'movesLeft': ps[s].movesLeft,
            'movesUsed': ps[s].movesUsed,
            'cleared': ps[s].totalCleared,
            'maxCombo': ps[s].maxCombo,
            'lastCombo': ps[s].lastCombo,
            'iceSent': ps[s].iceSent,
            'iceReceived': ps[s].iceReceived,
            'frozenCount': ps[s].frozen.where((v) => v > 0).length,
            'specialCount': ps[s].special.where((v) => v > 0).length,
          },
      ],
      'final': ranking,
    };
  }
}

class Match3Player {
  final List<int> board;
  final List<int> special;
  final List<int> frozen;
  final Random rng;

  int score = 0;
  int movesLeft;
  int movesUsed = 0;
  int totalCleared = 0;
  int maxCombo = 0;
  int lastCombo = 0;
  int lastCleared = 0;
  int lastPoints = 0;
  int lastIceAttack = 0;
  int specialsCreated = 0;
  int specialsTriggered = 0;
  int iceThawed = 0;
  int iceSent = 0;
  int iceReceived = 0;
  int resignNo = 0;
  String status = 'play'; // 'play' | 'done' | 'resigned'
  List<int> lastSwap = const [];

  Match3Player({
    required this.board,
    required this.rng,
    required this.movesLeft,
  })  : special = List<int>.filled(board.length, 0),
        frozen = List<int>.filled(board.length, 0);
}
