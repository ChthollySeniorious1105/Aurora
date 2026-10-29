import 'dart:collection';
import 'dart:math';

import '../../src/engine.dart';
import 'a16_util.dart';

class LitsPuzzle {
  final int size;
  final int regionCount;
  /// `size × size` grid of polyomino Region IDs `0..regionCount-1`.
  final List<List<int>> regions;
  /// Number of cells in each Region `0..regionCount-1` (always `>= 4`).
  final List<int> regionSizes;
  /// Top-left-most flat cell index `r * size + c` for each Region `0..regionCount-1`.
  final List<int> regionAnchorCells;
  /// Flat `size * size` solution (`0` = White, `1` = Black `■`).
  final List<int> solutionBoard;
  /// Tetromino letter (`'L'`, `'I'`, `'T'`, `'S'`) for each Region `0..regionCount-1` in [solutionBoard].
  final List<String> solutionShapes;

  const LitsPuzzle({
    required this.size,
    required this.regionCount,
    required this.regions,
    required this.regionSizes,
    required this.regionAnchorCells,
    required this.solutionBoard,
    required this.solutionShapes,
  });

  List<int> get regionMap => [
        for (var r = 0; r < size; r++)
          for (var c = 0; c < size; c++) regions[r][c],
      ];

  List<int> get initialBoard => List<int>.filled(size * size, 0);
}

class LitsAnalysis {
  final Set<int> satisfiedRegions;
  final Set<int> violatedRegions;
  final Set<int> pendingRegions;
  final Set<int> sameShapeConflictRegions;
  final List<int> regionBlackCounts;
  /// Detected tetromino letter per region (`'L'`, `'I'`, `'T'`, `'S'`, `'O'`, or `''`).
  final List<String> regionShapes;
  final Set<int> twoByTwoCells;
  final Set<int> conflictCells;
  final int blackComponentCount;
  final bool isAllBlackConnected;
  final int blackCount;
  final int dotCount;
  final int regionCount;

  const LitsAnalysis({
    required this.satisfiedRegions,
    required this.violatedRegions,
    required this.pendingRegions,
    required this.sameShapeConflictRegions,
    required this.regionBlackCounts,
    required this.regionShapes,
    required this.twoByTwoCells,
    required this.conflictCells,
    required this.blackComponentCount,
    required this.isAllBlackConnected,
    required this.blackCount,
    required this.dotCount,
    required this.regionCount,
  });

  bool get isSolved =>
      regionCount > 0 &&
      satisfiedRegions.length == regionCount &&
      violatedRegions.isEmpty &&
      pendingRegions.isEmpty &&
      sameShapeConflictRegions.isEmpty &&
      twoByTwoCells.isEmpty &&
      isAllBlackConnected &&
      blackCount == regionCount * 4;
}

class _CandidateTetromino {
  final List<int> cells;
  final String letter;
  const _CandidateTetromino(this.cells, this.letter);
}

class LitsSolver {
  static const List<int> orthoDr = [-1, 0, 1, 0];
  static const List<int> orthoDc = [0, 1, 0, -1];
  static const Set<String> validLetters = {'L', 'I', 'T', 'S'};

  static bool isValidLetter(String s) => validLetters.contains(s);

  /// Classifies a set of flat cell indices on a `size × size` grid into one of:
  /// `'L'`, `'I'`, `'T'`, `'S'` (valid LITS tetrominoes), `'O'` (`2×2` forbidden square),
  /// or `''` (not 4 orthogonally connected cells).
  static String classifyTetromino(int size, List<int> cells) {
    if (cells.length != 4) return '';
    final cellSet = cells.toSet();
    if (cellSet.length != 4) return '';

    // 1. Check orthogonal connectivity via BFS
    final visited = <int>{cells.first};
    final q = Queue<int>()..add(cells.first);
    while (q.isNotEmpty) {
      final cur = q.removeFirst();
      final r = cur ~/ size, c = cur % size;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
        final nxt = nr * size + nc;
        if (cellSet.contains(nxt) && visited.add(nxt)) {
          q.add(nxt);
        }
      }
    }
    if (visited.length != 4) return '';

    // 2. Bounding box & neighbor degrees
    var minR = size, maxR = -1, minC = size, maxC = -1;
    var maxDeg = 0;
    final rowFreq = <int, int>{};
    final colFreq = <int, int>{};

    for (final idx in cells) {
      final r = idx ~/ size, c = idx % size;
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
      rowFreq[r] = (rowFreq[r] ?? 0) + 1;
      colFreq[c] = (colFreq[c] ?? 0) + 1;

      var deg = 0;
      for (var d = 0; d < 4; d++) {
        final nr = r + orthoDr[d], nc = c + orthoDc[d];
        if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
          if (cellSet.contains(nr * size + nc)) deg++;
        }
      }
      if (deg > maxDeg) maxDeg = deg;
    }

    final h = maxR - minR + 1;
    final w = maxC - minC + 1;
    if ((h == 1 && w == 4) || (h == 4 && w == 1)) return 'I';
    if (h == 2 && w == 2) return 'O';
    if (maxDeg == 3) return 'T';
    if (rowFreq.values.any((cnt) => cnt == 3) || colFreq.values.any((cnt) => cnt == 3)) {
      return 'L';
    }
    return 'S';
  }

  /// Counts the number of orthogonal connected components of Black (`1`) cells.
  static int countBlackComponents(int size, List<int> board) {
    final n = size * size;
    final visited = List<bool>.filled(n, false);
    var comps = 0;
    for (var start = 0; start < n; start++) {
      if (start >= board.length || board[start] != 1 || visited[start]) continue;
      comps++;
      final q = Queue<int>()..add(start);
      visited[start] = true;
      while (q.isNotEmpty) {
        final cur = q.removeFirst();
        final r = cur ~/ size, c = cur % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          if (!visited[nxt] && nxt < board.length && board[nxt] == 1) {
            visited[nxt] = true;
            q.add(nxt);
          }
        }
      }
    }
    return comps;
  }

  /// Returns all flat cell indices belonging to any `2×2` all-Black square.
  static Set<int> findTwoByTwoBlackCells(int size, List<int> board) {
    final out = <int>{};
    for (var r = 0; r < size - 1; r++) {
      for (var c = 0; c < size - 1; c++) {
        final i00 = r * size + c;
        final i01 = r * size + (c + 1);
        final i10 = (r + 1) * size + c;
        final i11 = (r + 1) * size + (c + 1);
        if (i11 < board.length &&
            board[i00] == 1 &&
            board[i01] == 1 &&
            board[i10] == 1 &&
            board[i11] == 1) {
          out
            ..add(i00)
            ..add(i01)
            ..add(i10)
            ..add(i11);
        }
      }
    }
    return out;
  }

  static LitsAnalysis analyze(LitsPuzzle puz, List<int> board) {
    final size = puz.size;
    final n = size * size;
    final regionCount = puz.regionCount;

    final regionBlackCells = List<List<int>>.generate(regionCount, (_) => <int>[]);
    var blackCount = 0;
    var dotCount = 0;

    for (var i = 0; i < n; i++) {
      final v = i < board.length ? board[i] : 0;
      if (v == 1) {
        blackCount++;
        final reg = puz.regions[i ~/ size][i % size];
        if (reg >= 0 && reg < regionCount) {
          regionBlackCells[reg].add(i);
        }
      } else if (v == 2) {
        dotCount++;
      }
    }

    final regionBlackCounts = [for (var reg = 0; reg < regionCount; reg++) regionBlackCells[reg].length];
    final regionShapes = <String>[
      for (var reg = 0; reg < regionCount; reg++)
        regionBlackCells[reg].length == 4 ? classifyTetromino(size, regionBlackCells[reg]) : '',
    ];

    final twoByTwoCells = findTwoByTwoBlackCells(size, board);
    final conflictCells = <int>{...twoByTwoCells};
    final sameShapeConflictRegions = <int>{};

    // Check touching tetrominoes of the same valid letter across different regions
    for (var r = 0; r < size; r++) {
      for (var c = 0; c < size; c++) {
        final idxA = r * size + c;
        if (idxA >= board.length || board[idxA] != 1) continue;
        final regA = puz.regions[r][c];
        final shapeA = regionShapes[regA];
        if (!isValidLetter(shapeA)) continue;

        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final idxB = nr * size + nc;
          if (idxB >= board.length || board[idxB] != 1) continue;
          final regB = puz.regions[nr][nc];
          if (regA == regB) continue;
          final shapeB = regionShapes[regB];
          if (shapeA == shapeB) {
            sameShapeConflictRegions.add(regA);
            sameShapeConflictRegions.add(regB);
            conflictCells.addAll(regionBlackCells[regA]);
            conflictCells.addAll(regionBlackCells[regB]);
          }
        }
      }
    }

    final satisfiedRegions = <int>{};
    final violatedRegions = <int>{};
    final pendingRegions = <int>{};

    for (var reg = 0; reg < regionCount; reg++) {
      final cnt = regionBlackCounts[reg];
      final shape = regionShapes[reg];
      if (cnt < 4) {
        pendingRegions.add(reg);
      } else if (cnt > 4 || !isValidLetter(shape)) {
        violatedRegions.add(reg);
        conflictCells.addAll(regionBlackCells[reg]);
      } else if (sameShapeConflictRegions.contains(reg)) {
        violatedRegions.add(reg);
      } else {
        satisfiedRegions.add(reg);
      }
    }

    final blackComponentCount = countBlackComponents(size, board);
    final isAllBlackConnected = blackCount > 0 && blackComponentCount == 1;

    return LitsAnalysis(
      satisfiedRegions: satisfiedRegions,
      violatedRegions: violatedRegions,
      pendingRegions: pendingRegions,
      sameShapeConflictRegions: sameShapeConflictRegions,
      regionBlackCounts: regionBlackCounts,
      regionShapes: regionShapes,
      twoByTwoCells: twoByTwoCells,
      conflictCells: conflictCells,
      blackComponentCount: blackComponentCount,
      isAllBlackConnected: isAllBlackConnected,
      blackCount: blackCount,
      dotCount: dotCount,
      regionCount: regionCount,
    );
  }

  static bool isSolved(LitsPuzzle puz, List<int> board) {
    if (board.length != puz.size * puz.size) return false;
    return analyze(puz, board).isSolved;
  }

  /// Enumerates all valid L, I, T, S 4-cell polyominoes on a `size × size` grid.
  static List<_CandidateTetromino> _allValidTetrominoes(int size) {
    final n = size * size;
    final seen = <String>{};
    final out = <_CandidateTetromino>[];

    void dfs(List<int> cur) {
      if (cur.length == 4) {
        final sorted = List<int>.of(cur)..sort();
        final key = sorted.join(',');
        if (!seen.add(key)) return;
        final letter = classifyTetromino(size, sorted);
        if (isValidLetter(letter)) {
          out.add(_CandidateTetromino(sorted, letter));
        }
        return;
      }
      final frontier = <int>{};
      for (final idx in cur) {
        final r = idx ~/ size, c = idx % size;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          final nxt = nr * size + nc;
          if (!cur.contains(nxt)) frontier.add(nxt);
        }
      }
      for (final nxt in frontier) {
        dfs([...cur, nxt]);
      }
    }

    for (var i = 0; i < n; i++) {
      dfs([i]);
    }
    return out;
  }

  /// Generates a guaranteed-valid LITS puzzle for [size] (`5` or `6`).
  static LitsPuzzle generatePuzzle(int size, Random rng) {
    final n = size * size;
    final targetRegions = size <= 5 ? 4 : 5;
    final candidates = _allValidTetrominoes(size);

    for (var attempt = 0; attempt < 40; attempt++) {
      final shuffledCands = List<_CandidateTetromino>.of(candidates)..shuffle(rng);
      final board = List<int>.filled(n, 0);
      final ownerReg = List<int>.filled(n, -1);
      final chosen = <_CandidateTetromino>[];
      var steps = 0;

      bool placeNext(int k) {
        if (++steps > 2500) return false;
        if (k == targetRegions) return true;

        for (final cand in shuffledCands) {
          // 1. Must be disjoint from already placed tetrominoes
          var overlaps = false;
          for (final idx in cand.cells) {
            if (board[idx] != 0) {
              overlaps = true;
              break;
            }
          }
          if (overlaps) continue;

          // 2. If k > 0, must touch at least one already placed tetromino, and no touching tetromino can share its letter
          var touchesExisting = k == 0;
          var sameLetterTouch = false;
          for (final idx in cand.cells) {
            final r = idx ~/ size, c = idx % size;
            for (var d = 0; d < 4; d++) {
              final nr = r + orthoDr[d], nc = c + orthoDc[d];
              if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
              final nbReg = ownerReg[nr * size + nc];
              if (nbReg >= 0) {
                touchesExisting = true;
                if (chosen[nbReg].letter == cand.letter) {
                  sameLetterTouch = true;
                  break;
                }
              }
            }
            if (sameLetterTouch) break;
          }
          if (!touchesExisting || sameLetterTouch) continue;

          // 3. Tentatively place and verify no 2x2 Black square is formed
          for (final idx in cand.cells) {
            board[idx] = 1;
            ownerReg[idx] = k;
          }
          if (findTwoByTwoBlackCells(size, board).isEmpty) {
            chosen.add(cand);
            if (placeNext(k + 1)) return true;
            chosen.removeLast();
          }
          for (final idx in cand.cells) {
            board[idx] = 0;
            ownerReg[idx] = -1;
          }
        }
        return false;
      }

      if (!placeNext(0)) continue;

      // Grow orthogonally connected polyomino regions starting from each placed tetromino
      final regFlat = List<int>.of(ownerReg);
      final regSizes = List<int>.filled(targetRegions, 4);
      var unassigned = n - targetRegions * 4;
      var guard = 0;

      while (unassigned > 0 && guard++ < 300) {
        final frontier = <(int, int)>[];
        for (var i = 0; i < n; i++) {
          if (regFlat[i] != -1) continue;
          final r = i ~/ size, c = i % size;
          for (var d = 0; d < 4; d++) {
            final nr = r + orthoDr[d], nc = c + orthoDc[d];
            if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
              final nbReg = regFlat[nr * size + nc];
              if (nbReg >= 0) {
                frontier.add((i, nbReg));
              }
            }
          }
        }
        if (frontier.isEmpty) break;
        frontier.sort((a, b) => regSizes[a.$2].compareTo(regSizes[b.$2]));
        final topCount = min(frontier.length, 4);
        final (cellIdx, targetReg) = frontier[rng.nextInt(topCount)];
        if (regFlat[cellIdx] == -1) {
          regFlat[cellIdx] = targetReg;
          regSizes[targetReg]++;
          unassigned--;
        }
      }
      if (unassigned > 0) continue;

      final regions = [
        for (var r = 0; r < size; r++)
          [for (var c = 0; c < size; c++) regFlat[r * size + c]],
      ];
      final regionAnchors = List<int>.filled(targetRegions, -1);
      for (var i = 0; i < n; i++) {
        final reg = regFlat[i];
        if (regionAnchors[reg] == -1) regionAnchors[reg] = i;
      }

      final puz = LitsPuzzle(
        size: size,
        regionCount: targetRegions,
        regions: regions,
        regionSizes: regSizes,
        regionAnchorCells: regionAnchors,
        solutionBoard: board,
        solutionShapes: [for (final t in chosen) t.letter],
      );
      if (isSolved(puz, board) && !isSolved(puz, puz.initialBoard)) {
        return puz;
      }
    }

    // Deterministic fallback for 5x5 (4 regions) and 6x6 (5 regions)
    final fallbackTetros = <_CandidateTetromino>[
      // T0 (L): (0,0), (1,0), (2,0), (2,1)
      _CandidateTetromino([0, size, 2 * size, 2 * size + 1], 'L'),
      // T1 (I): (0,1), (0,2), (0,3), (0,4)
      const _CandidateTetromino([1, 2, 3, 4], 'I'),
      // T2 (T): (1,4), (2,3), (2,4), (3,4)
      _CandidateTetromino([size + 4, 2 * size + 3, 2 * size + 4, 3 * size + 4], 'T'),
      // T3 (S): (3,1), (3,2), (4,2), (4,3)
      _CandidateTetromino([3 * size + 1, 3 * size + 2, 4 * size + 2, 4 * size + 3], 'S'),
      if (size >= 6)
        // T4 (L): (4,0), (5,0), (5,1), (5,2)
        _CandidateTetromino([4 * size, 5 * size, 5 * size + 1, 5 * size + 2], 'L'),
    ];
    final regCount = fallbackTetros.length;
    final sol = List<int>.filled(n, 0);
    final regFlat = List<int>.filled(n, -1);
    final regSizes = List<int>.filled(regCount, 4);
    for (var k = 0; k < regCount; k++) {
      for (final idx in fallbackTetros[k].cells) {
        sol[idx] = 1;
        regFlat[idx] = k;
      }
    }
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < n; i++) {
        if (regFlat[i] != -1) continue;
        final r = i ~/ size, c = i % size;
        var bestReg = -1;
        for (var d = 0; d < 4; d++) {
          final nr = r + orthoDr[d], nc = c + orthoDc[d];
          if (nr >= 0 && nr < size && nc >= 0 && nc < size) {
            final nb = regFlat[nr * size + nc];
            if (nb >= 0 && (bestReg == -1 || regSizes[nb] < regSizes[bestReg])) {
              bestReg = nb;
            }
          }
        }
        if (bestReg >= 0) {
          regFlat[i] = bestReg;
          regSizes[bestReg]++;
          changed = true;
        }
      }
    }
    final regions = [
      for (var r = 0; r < size; r++)
        [for (var c = 0; c < size; c++) regFlat[r * size + c]],
    ];
    final regionAnchors = List<int>.filled(regCount, -1);
    for (var i = 0; i < n; i++) {
      final reg = regFlat[i];
      if (regionAnchors[reg] == -1) regionAnchors[reg] = i;
    }
    return LitsPuzzle(
      size: size,
      regionCount: regCount,
      regions: regions,
      regionSizes: regSizes,
      regionAnchorCells: regionAnchors,
      solutionBoard: sol,
      solutionShapes: [for (final t in fallbackTetros) t.letter],
    );
  }
}

/// 四格骨牌竞速 (LITS Race, 1-6 人).
class LitsGame extends GameEngine {
  LitsGame(super.setup);

  static const int roundMaxSec = 480;

  late int size;
  late int totalRounds;
  int round = 0;
  int roundSec = 0;
  int moves = 0;
  int roundSolvers = 0;

  late LitsPuzzle currentPuzzle;
  late List<LitsPlayer> ps;
  Map<String, dynamic>? lastRoundSummary;
  List<Map<String, dynamic>>? ranking;
  bool over = false;
  int _resigns = 0;

  List<List<int>> get boards => [for (final p in ps) p.board];
  List<int> get scores => [for (final p in ps) p.score];

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a16Placings(ranking, players) : null;

  @override
  bool get canResign => !over;

  @override
  int get botDelayMs => switch (botLevel) { 0 => 760, 2 => 240, _ => 440 };

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
      _checkRoundComplete();
    }
  }

  @override
  void start() {
    final rawSize = setup.opt<int>('size', 5);
    size = rawSize == 6 ? 6 : 5;
    totalRounds = setup.opt<int>('rounds', 3) == 1 ? 1 : 3;

    currentPuzzle = LitsSolver.generatePuzzle(size, rng);
    ps = [for (var s = 0; s < players; s++) LitsPlayer(size * size)];

    host.log('四格骨牌竞速开始（$size×$size 网格，共 $totalRounds 题）！每宫涂黑 1 个 L/I/T/S 骨牌，全黑连通、禁 2×2 且同形不相邻！');
    _startRound(1);
    host.schedule(1000, _clock);
  }

  void _startRound(int r) {
    round = r;
    roundSec = 0;
    roundSolvers = 0;
    if (r > 1) {
      currentPuzzle = LitsSolver.generatePuzzle(size, rng);
    }
    for (var s = 0; s < players; s++) {
      ps[s].resetForRound(size * size);
    }
  }

  void _clock() {
    if (over) return;
    roundSec++;
    if (roundSec >= roundMaxSec) {
      _endRound('本题时间到');
    }
    if (!over) host.schedule(1000, _clock);
  }

  bool _activeInRound(int s) => ps[s].resignNo == 0 && ps[s].status == 'play';

  @override
  List<int> get waitingFor {
    if (over) return const [];
    return a16Rotated([for (var s = 0; s < players; s++) if (_activeInRound(s)) s], moves);
  }

  (int, int) _resolveCell(Map<String, dynamic> a) {
    if (a.containsKey('r') && a.containsKey('c')) {
      final r = asInt(a['r']);
      final c = asInt(a['c']);
      if (r < 0 || r >= size || c < 0 || c >= size) {
        throw GameError('行列坐标超出棋盘范围');
      }
      return (r, c);
    }
    final idx = asInt(a['i']);
    if (idx < 0 || idx >= size * size) {
      throw GameError('格子索引超出棋盘范围');
    }
    return (idx ~/ size, idx % size);
  }

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'next') return;
    final p = ps[seat];
    if (p.resignNo > 0) throw GameError('你已认输');
    if (p.status != 'play') throw GameError('你已完成本题');

    switch (type) {
      case 'toggle':
      case 'set':
      case 'shade':
        final (r, c) = _resolveCell(a);
        final idx = r * size + c;
        if (a.containsKey('val')) {
          final v = asInt(a['val'], -1);
          if (v < 0 || v > 2) {
            throw GameError('格子状态必须在 0～2 之间');
          }
          p.board[idx] = v;
        } else if (type == 'shade') {
          p.board[idx] = p.board[idx] == 1 ? 0 : 1;
        } else {
          p.board[idx] = (p.board[idx] + 1) % 3;
        }
        moves++;
        if (LitsSolver.isSolved(currentPuzzle, p.board)) {
          _markSolved(seat);
        }

      case 'clear':
      case 'reset':
        p.board.fillRange(0, p.board.length, 0);
        moves++;

      case 'pass':
      case 'give_up':
      case 'skip':
        p.status = 'pass';
        p.lastRoundPts = 0;
        moves++;
        host.log('${name(seat)} 放弃了第 $round 题');
        _checkRoundComplete();

      default:
        throw GameError('未知操作');
    }
  }

  void _markSolved(int seat) {
    final p = ps[seat];
    roundSolvers++;
    final pts = switch (roundSolvers) {
      1 => 10,
      2 => 8,
      3 => 6,
      _ => 4,
    };
    p.status = 'solved';
    p.solveRank = roundSolvers;
    p.lastRoundPts = pts;
    p.score += pts;
    p.solvedCount++;
    p.totalSolveSec += roundSec;
    host.log('${name(seat)} 第 $roundSolvers 个解出四格骨牌谜题，+$pts 分！');
    _checkRoundComplete();
  }

  void _checkRoundComplete() {
    if (over) return;
    if ([for (var s = 0; s < players; s++) if (_activeInRound(s)) s].isEmpty) {
      _endRound('全员完成第 $round 题');
    }
  }

  void _endRound(String reason) {
    lastRoundSummary = {
      'round': round,
      'reason': reason,
      'ps': [
        for (var s = 0; s < players; s++)
          {
            's': s,
            'status': ps[s].status,
            'pts': ps[s].lastRoundPts,
            'rank': ps[s].solveRank,
          },
      ],
    };

    if (round >= totalRounds) {
      _finish('全部 $totalRounds 题已完成');
    } else {
      _startRound(round + 1);
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a16Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.score != pb.score) return pb.score - pa.score;
      if (pa.solvedCount != pb.solvedCount) return pb.solvedCount - pa.solvedCount;
      return pa.totalSolveSec - pb.totalSolveSec;
    }, (s) => {
          'score': ps[s].score,
          'solved': ps[s].solvedCount,
          'sec': ps[s].totalSolveSec,
        });
    host.log('游戏结束（$why）！冠军：${a16Winners(ranking!, name)}');
  }

  // ---------------------------------------------------------------- bot

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players || !_activeInRound(seat)) return null;
    final p = ps[seat];
    final puz = currentPuzzle;
    final sol = puz.solutionBoard;

    if (botLevel <= 0 && rng.nextInt(15) == 0) {
      return {'type': 'pass'};
    }

    final diff = <int>[
      for (var i = 0; i < sol.length; i++)
        if ((p.board[i] == 1) != (sol[i] == 1)) i,
    ];
    if (diff.isNotEmpty) {
      final pick = diff[rng.nextInt(diff.length)];
      return {
        'type': 'toggle',
        'r': pick ~/ size,
        'c': pick % size,
      };
    }

    return {'type': 'pass'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players ? ps[seat] : (ps.isNotEmpty ? ps[0] : null);
    final puz = currentPuzzle;
    final myBoard = me?.board ?? puz.initialBoard;
    final an = LitsSolver.analyze(puz, myBoard);

    return {
      'phase': over ? 'over' : 'play',
      'round': round,
      'totalRounds': totalRounds,
      'size': size,
      'sec': roundSec,
      'maxSec': roundMaxSec,
      'left': (roundMaxSec - roundSec).clamp(0, roundMaxSec),
      'regionCount': puz.regionCount,
      'regions': puz.regions,
      'regionMap': puz.regionMap,
      'regionSizes': puz.regionSizes,
      'regionAnchorCells': puz.regionAnchorCells,
      'board': myBoard,
      'regionBlackCounts': an.regionBlackCounts,
      'regionShapes': an.regionShapes,
      'satisfiedRegions': an.satisfiedRegions.toList()..sort(),
      'violatedRegions': an.violatedRegions.toList()..sort(),
      'pendingRegions': an.pendingRegions.toList()..sort(),
      'sameShapeConflictRegions': an.sameShapeConflictRegions.toList()..sort(),
      'twoByTwoCells': an.twoByTwoCells.toList()..sort(),
      'conflictCells': an.conflictCells.toList()..sort(),
      'satisfiedRegionCount': an.satisfiedRegions.length,
      'blackComponentCount': an.blackComponentCount,
      'isAllBlackConnected': an.isAllBlackConnected,
      'blackCount': an.blackCount,
      'dotCount': an.dotCount,
      'ps': [
        for (var s = 0; s < players; s++)
          () {
            final pAn = LitsSolver.analyze(puz, ps[s].board);
            return {
              'score': ps[s].score,
              'solved': ps[s].solvedCount,
              'status': ps[s].status,
              'pts': ps[s].lastRoundPts,
              'rank': ps[s].solveRank,
              'satisfiedRegions': pAn.satisfiedRegions.length,
              'regionCount': puz.regionCount,
              'blackCount': pAn.blackCount,
            };
          }(),
      ],
      'lastResult': lastRoundSummary,
      'final': ranking,
    };
  }
}

class LitsPlayer {
  int score = 0;
  int solvedCount = 0;
  int totalSolveSec = 0;
  int resignNo = 0;

  String status = 'play'; // 'play' | 'solved' | 'pass' | 'resigned'
  int solveRank = 0;
  int lastRoundPts = 0;
  List<int> board;

  LitsPlayer(int cellCount) : board = List<int>.filled(cellCount, 0);

  void resetForRound(int cellCount) {
    if (resignNo == 0) status = 'play';
    solveRank = 0;
    lastRoundPts = 0;
    board = List<int>.filled(cellCount, 0);
  }
}
