import '../../src/engine.dart';

class SantoriniGod {
  final String id;
  final String name;
  final String title;
  final String desc;
  const SantoriniGod(this.id, this.name, this.title, this.desc);
}

const List<SantoriniGod> santoriniGods = [
  SantoriniGod('apollo', '阿波罗', '音乐之神', '移动时可进入相邻对手工人格并与其互换位置（仍需遵守高度差 ≤ 1）。'),
  SantoriniGod('artemis', '阿尔忒弥斯', '狩猎女神', '移动阶段可移动 1 步或连续 2 步（不能移回起始原格）。'),
  SantoriniGod('athena', '雅典娜', '智慧女神', '若你在本回合向上移动，直到你下回合开始前，其他玩家不能向上移动。'),
  SantoriniGod('atlas', '阿特拉斯', '擎天神', '建造时可在任意高度（0~3 层）的相邻空格直接建造穹顶（4 层）。'),
  SantoriniGod('demeter', '德墨忒尔', '丰收女神', '建造时可额外建造第 2 次，但不能建在同一个格子上。'),
  SantoriniGod('hephaestus', '赫菲斯托斯', '锻造之神', '建造时可在同一格连续加盖 2 层（不能建出穹顶，仅限 0→2 或 1→3）。'),
  SantoriniGod('pan', '潘神', '牧神', '若你的工人从高处向低处移动且下降 2 层或以上，你也立即获胜。'),
  SantoriniGod('prometheus', '普罗米修斯', '先知泰坦', '若本回合不向上移动，可在移动前先用该工人建造 1 次，移动后再建造 1 次。'),
];

SantoriniGod? santoriniGodById(String id) {
  for (final g in santoriniGods) {
    if (g.id == id) return g;
  }
  return null;
}

List<int> santoriniAdj(int cell) {
  final x = cell % 5, y = cell ~/ 5;
  final out = <int>[];
  for (var dy = -1; dy <= 1; dy++) {
    for (var dx = -1; dx <= 1; dx++) {
      if (dx == 0 && dy == 0) continue;
      final nx = x + dx, ny = y + dy;
      if (nx >= 0 && nx < 5 && ny >= 0 && ny < 5) {
        out.add(ny * 5 + nx);
      }
    }
  }
  return out;
}

String santoriniCoord(int cell) {
  if (cell < 0 || cell >= 25) return '?';
  final x = cell % 5, y = cell ~/ 5;
  return '${String.fromCharCode(65 + x)}${y + 1}';
}

class Santorini extends GameEngine {
  final List<int> heights = List.filled(25, 0);
  late List<List<int>> workers;
  late List<String> gods;
  late List<bool> eliminated;
  final List<int> eliminationOrder = [];

  String phase = 'place'; // 'place' | 'play'
  int turn = 0;
  String step = 'place'; // 'place' | 'move' | 'post_prebuild' | 'build' | 'build2'
  int activeCell = -1;
  int firstBuildCell = -1;

  bool athenaLocked = false;
  int athenaSeat = -1;

  int plies = 0;
  bool _over = false;
  int winner = -1; // 0..players-1, or players for draw
  List<int>? _placings;
  String note = '';
  String result = '';
  Map<String, dynamic>? lastAction;

  Santorini(super.setup);

  bool get godMode => setup.opt<bool>('gods', false);

  @override
  void start() {
    workers = [for (var i = 0; i < players; i++) <int>[]];
    eliminated = List.filled(players, false);
    if (godMode) {
      final pool = shuffled(santoriniGods, rng);
      gods = [for (var i = 0; i < players; i++) pool[i].id];
      for (var i = 0; i < players; i++) {
        if (gods[i] == 'athena') athenaSeat = i;
        final g = pool[i];
        host.log('${name(i)} 获得神明【${g.name}·${g.title}】');
      }
    } else {
      gods = List.filled(players, 'none');
    }
    phase = 'place';
    step = 'place';
    turn = 0;
    note = '请按顺序放置各自的 2 名工人';
  }

  int workerOwner(int cell) {
    for (var s = 0; s < players; s++) {
      if (!eliminated[s] && workers[s].contains(cell)) return s;
    }
    return -1;
  }

  bool _canStep(int seat, int from, int to, {required bool noClimb, required bool allowApolloSwap}) {
    if (heights[to] >= 4) return false;
    final maxRise = (noClimb || (athenaLocked && seat != athenaSeat)) ? 0 : 1;
    if (heights[to] - heights[from] > maxRise) return false;
    final occ = workerOwner(to);
    if (occ == -1) return true;
    if (allowApolloSwap && occ != seat) return true;
    return false;
  }

  bool _winsOnStep(int seat, int from, int to) {
    if (heights[to] == 3 && heights[to] > heights[from]) return true;
    if (gods[seat] == 'pan' && heights[from] - heights[to] >= 2) return true;
    return false;
  }

  bool _hasBuildAfterMove(int seat, int from, int to) {
    final occAtTo = workerOwner(to);
    for (final b in santoriniAdj(to)) {
      if (heights[b] >= 4) continue;
      if (b == from) {
        // If Apollo swapped with an opponent at `to`, `from` now has that opponent.
        if (occAtTo == -1) return true;
        continue;
      }
      if (workerOwner(b) == -1) return true;
    }
    return false;
  }

  /// Returns all legal `(from, to)` moves for [seat].
  /// If [onlyWorkerAt] >= 0, restricts to the worker at that cell.
  /// If [noClimb] is true, worker may not move up (Prometheus after pre-build).
  List<(int, int)> legalMovesFor(int seat, {int onlyWorkerAt = -1, bool noClimb = false}) {
    if (eliminated[seat]) return const [];
    final god = gods[seat];
    final out = <(int, int)>[];
    final seen = <(int, int)>{};
    final ws = onlyWorkerAt >= 0 ? [onlyWorkerAt] : workers[seat];

    for (final from in ws) {
      for (final to1 in santoriniAdj(from)) {
        if (!_canStep(seat, from, to1, noClimb: noClimb, allowApolloSwap: god == 'apollo')) continue;
        final wins1 = _winsOnStep(seat, from, to1);
        if (wins1 || _hasBuildAfterMove(seat, from, to1)) {
          if (seen.add((from, to1))) out.add((from, to1));
        }
        // Artemis may take a second step (if step 1 did not already win)
        if (god == 'artemis' && !wins1) {
          for (final to2 in santoriniAdj(to1)) {
            if (to2 == from) continue;
            if (!_canStep(seat, to1, to2, noClimb: noClimb, allowApolloSwap: false)) continue;
            // After moving from -> to1 -> to2, `from` and `to1` are empty, so `to1` is always a valid build spot.
            if (seen.add((from, to2))) out.add((from, to2));
          }
        }
      }
    }
    return out;
  }

  /// Returns all legal `(workerCell, buildCell)` pre-builds for Prometheus.
  List<(int, int)> legalPrebuildsFor(int seat) {
    if (eliminated[seat] || gods[seat] != 'prometheus') return const [];
    final out = <(int, int)>[];
    for (final w in workers[seat]) {
      for (final b in santoriniAdj(w)) {
        if (heights[b] >= 4 || workerOwner(b) != -1) continue;
        heights[b]++;
        final hasMove = legalMovesFor(seat, onlyWorkerAt: w, noClimb: true).isNotEmpty;
        heights[b]--;
        if (hasMove) out.add((w, b));
      }
    }
    return out;
  }

  /// Returns legal build cells for the worker currently at [workerCell].
  List<int> legalBuildCells(int workerCell, {int excludeCell = -1}) {
    if (workerCell < 0) return const [];
    return [
      for (final b in santoriniAdj(workerCell))
        if (b != excludeCell && heights[b] < 4 && workerOwner(b) == -1) b,
    ];
  }

  bool _playerHasAnyAction(int seat) {
    if (eliminated[seat]) return false;
    if (legalMovesFor(seat).isNotEmpty) return true;
    if (legalPrebuildsFor(seat).isNotEmpty) return true;
    return false;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('对局已结束');
    if (seat != turn) throw GameError('还没轮到你');
    final type = asStr(action['type']);

    if (phase == 'place') {
      if (type != 'place') throw GameError('当前请放置工人');
      final cell = asInt(action['cell']);
      if (cell < 0 || cell >= 25) throw GameError('无效格子');
      if (workerOwner(cell) != -1) throw GameError('该格已有工人');
      workers[seat].add(cell);
      plies++;
      lastAction = {'type': 'place', 'seat': seat, 'cell': cell};
      note = '${name(seat)} 在 ${santoriniCoord(cell)} 放置了工人';

      if (workers[seat].length == 2) {
        if (seat + 1 < players) {
          turn = seat + 1;
        } else {
          phase = 'play';
          turn = 0;
          step = 'move';
          _checkStartOfTurn();
        }
      }
      return;
    }

    // Play phase
    final god = gods[seat];

    if (step == 'move') {
      if (type == 'prebuild') {
        if (god != 'prometheus') throw GameError('只有普罗米修斯可以在移动前建造');
        final from = asInt(action['from']);
        final cell = asInt(action['cell']);
        final allowed = legalPrebuildsFor(seat);
        if (!allowed.contains((from, cell))) throw GameError('非法先手建造（需确保建造后该工人能不攀爬移动）');
        heights[cell]++;
        activeCell = from;
        firstBuildCell = cell;
        step = 'post_prebuild';
        plies++;
        lastAction = {'type': 'prebuild', 'seat': seat, 'from': from, 'build': cell};
        note = '${name(seat)}（普罗米修斯）先在 ${santoriniCoord(cell)} 建造至 ${heights[cell] == 4 ? '穹顶' : '${heights[cell]}层'}';
        return;
      }
      if (type != 'move') throw GameError('请选择工人移动');
      _executeMove(seat, asInt(action['from']), asInt(action['to']), noClimb: false);
      return;
    }

    if (step == 'post_prebuild') {
      if (type != 'move') throw GameError('请移动刚才建造的工人');
      final from = asInt(action['from']);
      if (from != activeCell) throw GameError('必须移动刚才建造的那名工人');
      _executeMove(seat, from, asInt(action['to']), noClimb: true);
      return;
    }

    if (step == 'build') {
      if (type != 'build') throw GameError('请选择相邻空格进行建造');
      final cell = asInt(action['cell']);
      final validCells = legalBuildCells(activeCell);
      if (!validCells.contains(cell)) throw GameError('不能在该位置建造');

      final dome = asBool(action['dome']);
      final doubleBuild = asBool(action['double']);
      if (dome && god != 'atlas') throw GameError('只有阿特拉斯可以直接建造穹顶');
      if (doubleBuild && god != 'hephaestus') throw GameError('只有赫菲斯托斯可以连建两层');
      if (doubleBuild && heights[cell] > 1) throw GameError('赫菲斯托斯连建两层不能建出穹顶');

      if (dome) {
        heights[cell] = 4;
      } else if (doubleBuild) {
        heights[cell] += 2;
      } else {
        heights[cell]++;
      }
      plies++;
      final prevFrom = (lastAction?['from'] as int?) ?? activeCell;
      lastAction = {
        'type': 'build',
        'seat': seat,
        'from': prevFrom,
        'to': activeCell,
        'build': cell,
        if (dome) 'dome': true,
        if (doubleBuild) 'double': true,
      };
      final buildDesc = heights[cell] == 4
          ? '穹顶'
          : (doubleBuild ? '连建至 ${heights[cell]}层' : '${heights[cell]}层');
      note = '${name(seat)} 在 ${santoriniCoord(cell)} 建造（$buildDesc）';

      if (god == 'demeter') {
        final secondCells = legalBuildCells(activeCell, excludeCell: cell);
        if (secondCells.isNotEmpty) {
          firstBuildCell = cell;
          step = 'build2';
          return;
        }
      }
      _endTurn();
      return;
    }

    if (step == 'build2') {
      if (type == 'pass') {
        plies++;
        _endTurn();
        return;
      }
      if (type != 'build') throw GameError('请选择第二处建造位置或结束回合');
      final cell = asInt(action['cell']);
      final validCells = legalBuildCells(activeCell, excludeCell: firstBuildCell);
      if (!validCells.contains(cell)) throw GameError('第二次建造不能在同一格或无效格');
      heights[cell]++;
      plies++;
      lastAction = {
        ...?lastAction,
        'build2': cell,
      };
      note = '${name(seat)}（德墨忒尔）又在 ${santoriniCoord(cell)} 建造（${heights[cell] == 4 ? '穹顶' : '${heights[cell]}层'}）';
      _endTurn();
      return;
    }
  }

  void _executeMove(int seat, int from, int to, {required bool noClimb}) {
    final god = gods[seat];
    final moves = legalMovesFor(seat, onlyWorkerAt: noClimb ? activeCell : -1, noClimb: noClimb);
    if (!moves.contains((from, to))) throw GameError('非法移动');

    final fromH = heights[from];
    final toH = heights[to];
    var climbed = toH > fromH;
    var panDrop = god == 'pan' && (fromH - toH >= 2);
    var reached3 = toH == 3 && toH > fromH;

    // For Artemis 2-step move, check intermediate step if not directly adjacent
    final directAdj = santoriniAdj(from).contains(to);
    if (!directAdj && god == 'artemis') {
      for (final mid in santoriniAdj(from)) {
        if (!santoriniAdj(mid).contains(to)) continue;
        if (!_canStep(seat, from, mid, noClimb: noClimb, allowApolloSwap: false)) continue;
        if (!_canStep(seat, mid, to, noClimb: noClimb, allowApolloSwap: false)) continue;
        if (heights[mid] > fromH || toH > heights[mid]) climbed = true;
        if (toH == 3 && toH > heights[mid]) reached3 = true;
        break;
      }
    }

    final occ = workerOwner(to);
    if (occ != -1 && occ != seat) {
      // Apollo swap
      final oppIdx = workers[occ].indexOf(to);
      workers[occ][oppIdx] = from;
    }
    final myIdx = workers[seat].indexOf(from);
    workers[seat][myIdx] = to;

    if (god == 'athena') {
      athenaLocked = climbed;
    }

    plies++;
    activeCell = to;
    lastAction = {
      'type': 'move',
      'seat': seat,
      'from': from,
      'to': to,
      if (firstBuildCell >= 0 && step == 'post_prebuild') 'prebuild': firstBuildCell,
    };
    note = '${name(seat)} 将工人从 ${santoriniCoord(from)} 移至 ${santoriniCoord(to)}';

    if (reached3 || panDrop) {
      _win(seat, panDrop && !reached3 ? '${name(seat)}（潘神）从高处跃下获胜！' : '${name(seat)} 登上第三层高塔获胜！');
      return;
    }

    firstBuildCell = -1;
    step = 'build';
  }

  void _endTurn() {
    activeCell = -1;
    firstBuildCell = -1;
    step = 'move';
    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (!eliminated[next]) {
        turn = next;
        break;
      }
    }
    _checkStartOfTurn();
  }

  void _checkStartOfTurn() {
    while (!_over) {
      // When Athena's turn starts again, her lock resets until she climbs again
      if (turn == athenaSeat) {
        athenaLocked = false;
      }
      if (_playerHasAnyAction(turn)) break;

      // Current player has no legal move+build -> eliminated!
      final outSeat = turn;
      eliminated[outSeat] = true;
      workers[outSeat].clear();
      eliminationOrder.add(outSeat);
      if (outSeat == athenaSeat) athenaLocked = false;
      host.log('${name(outSeat)} 无路可走，被淘汰出局！');

      final alive = [for (var s = 0; s < players; s++) if (!eliminated[s]) s];
      if (alive.length == 1) {
        _win(alive.first, '${name(outSeat)} 无棋可走，${name(alive.first)} 获胜！');
        return;
      }
      for (var i = 1; i <= players; i++) {
        final next = (outSeat + i) % players;
        if (!eliminated[next]) {
          turn = next;
          break;
        }
      }
    }
  }

  void _win(int w, String msg) {
    _over = true;
    winner = w;
    result = msg;
    note = msg;
    host.log(msg);
    if (players == 2) {
      _placings = rankWinners(players, [w]);
    } else {
      // Winner = 1; others ranked by reverse elimination order
      final p = List.filled(players, 2);
      p[w] = 1;
      for (var i = 0; i < eliminationOrder.length; i++) {
        // Earlier eliminated gets worse rank
        p[eliminationOrder[i]] = players - i;
      }
      _placings = p;
    }
  }

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (_over || seat < 0 || seat >= players || eliminated[seat]) {
      throw GameError('无法认输');
    }
    eliminated[seat] = true;
    workers[seat].clear();
    eliminationOrder.add(seat);
    if (seat == athenaSeat) athenaLocked = false;
    host.log('${name(seat)} 认输');

    final alive = [for (var s = 0; s < players; s++) if (!eliminated[s]) s];
    if (alive.length == 1) {
      _win(alive.first, '${name(seat)} 认输，${name(alive.first)} 获胜！');
      return;
    }
    if (turn == seat) {
      activeCell = -1;
      firstBuildCell = -1;
      if (phase == 'place') {
        if (seat + 1 < players) {
          turn = seat + 1;
        } else {
          phase = 'play';
          turn = alive.first;
          step = 'move';
          _checkStartOfTurn();
        }
      } else {
        _endTurn();
      }
    }
  }

  @override
  bool get canDraw => true;

  @override
  void agreeDraw() {
    if (_over) throw GameError('对局已结束');
    _over = true;
    winner = players;
    result = '双方议和';
    note = result;
    _placings = List.filled(players, 1);
    host.log('对局以和棋结束');
  }

  @override
  List<int> get waitingFor => _over ? const [] : [turn];

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  Map<String, dynamic> view(int seat) {
    final moves = !_over && phase == 'play' && (step == 'move' || step == 'post_prebuild')
        ? [
            for (final (f, t) in legalMovesFor(
              turn,
              onlyWorkerAt: step == 'post_prebuild' ? activeCell : -1,
              noClimb: step == 'post_prebuild',
            ))
              [f, t]
          ]
        : const <List<int>>[];
    final prebuilds = !_over && phase == 'play' && step == 'move' && gods[turn] == 'prometheus'
        ? [for (final (f, b) in legalPrebuildsFor(turn)) [f, b]]
        : const <List<int>>[];
    final builds = !_over && phase == 'play' && (step == 'build' || step == 'build2')
        ? legalBuildCells(activeCell, excludeCell: step == 'build2' ? firstBuildCell : -1)
        : const <int>[];

    return {
      'heights': List<int>.of(heights),
      'workers': [for (final w in workers) List<int>.of(w)],
      'gods': List<String>.of(gods),
      'godEnabled': godMode,
      'eliminated': List<bool>.of(eliminated),
      'phase': phase,
      'turn': turn,
      'step': step,
      'activeCell': activeCell,
      'firstBuildCell': firstBuildCell,
      'athenaLocked': athenaLocked,
      'athenaSeat': athenaSeat,
      'legalMoves': moves,
      'legalPrebuilds': prebuilds,
      'legalBuilds': builds,
      'canDome': !_over && step == 'build' && gods[turn] == 'atlas',
      'doubleCells': !_over && step == 'build' && gods[turn] == 'hephaestus'
          ? [for (final b in builds) if (heights[b] <= 1) b]
          : const <int>[],
      'canPass': !_over && step == 'build2',
      'plies': plies,
      'over': _over,
      'winner': winner,
      'result': result,
      'note': note,
      'last': lastAction,
    };
  }

  bool _opponentCanReach3At(int seat, int cell) {
    if (heights[cell] != 3) return false;
    for (var s = 0; s < players; s++) {
      if (s == seat || eliminated[s]) continue;
      if (athenaLocked && s != athenaSeat) continue;
      for (final w in workers[s]) {
        if (heights[w] == 2 && santoriniAdj(w).contains(cell)) return true;
        if (gods[s] == 'artemis' && heights[w] >= 1) {
          for (final mid in santoriniAdj(w)) {
            if (heights[mid] == 2 && workerOwner(mid) == -1 && santoriniAdj(mid).contains(cell)) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || seat != turn) return null;

    if (phase == 'place') {
      final center = [12, 6, 7, 8, 11, 13, 16, 17, 18];
      final candidates = [
        for (final c in center)
          if (workerOwner(c) == -1) c,
      ];
      if (candidates.isEmpty) {
        for (var c = 0; c < 25; c++) {
          if (workerOwner(c) == -1) candidates.add(c);
        }
      }
      final pick = candidates[rng.nextInt(candidates.length)];
      return {'type': 'place', 'cell': pick};
    }

    final god = gods[seat];

    if (step == 'move' || step == 'post_prebuild') {
      final moves = legalMovesFor(
        seat,
        onlyWorkerAt: step == 'post_prebuild' ? activeCell : -1,
        noClimb: step == 'post_prebuild',
      );
      if (moves.isEmpty) {
        // Must use Prometheus prebuild if no direct move
        final pbs = legalPrebuildsFor(seat);
        if (pbs.isNotEmpty) {
          final (f, b) = pbs[rng.nextInt(pbs.length)];
          return {'type': 'prebuild', 'from': f, 'cell': b};
        }
        return null;
      }

      // Check immediate winning move first
      for (final (f, t) in moves) {
        if (_winsOnStep(seat, f, t)) {
          return {'type': 'move', 'from': f, 'to': t};
        }
        if (god == 'artemis' && !santoriniAdj(f).contains(t) && heights[t] == 3) {
          return {'type': 'move', 'from': f, 'to': t};
        }
      }

      if (botLevel == 0 && rng.nextDouble() < 0.5) {
        final (f, t) = moves[rng.nextInt(moves.length)];
        return {'type': 'move', 'from': f, 'to': t};
      }

      // Score moves
      var bestScore = -999999;
      var bestMove = moves.first;
      for (final (f, t) in moves) {
        var score = rng.nextInt(15);
        final fh = heights[f], th = heights[t];
        score += (th - fh) * 320 + th * 180;
        // Center preference
        final tx = t % 5, ty = t ~/ 5;
        score += (4 - ((tx - 2).abs() + (ty - 2).abs())) * 20;
        // Check if moving to `t` lets us dome a threatening level-3 next to an opponent
        for (final b in santoriniAdj(t)) {
          if (b != t && heights[b] == 3 && _opponentCanReach3At(seat, b)) {
            score += 2500;
          }
        }
        if (score > bestScore) {
          bestScore = score;
          bestMove = (f, t);
        }
      }
      return {'type': 'move', 'from': bestMove.$1, 'to': bestMove.$2};
    }

    if (step == 'build') {
      final cells = legalBuildCells(activeCell);
      if (cells.isEmpty) return null;
      var bestScore = -999999;
      Map<String, dynamic> bestAction = {'type': 'build', 'cell': cells.first};

      for (final b in cells) {
        final h = heights[b];
        final options = <(int, bool, bool)>[(h + 1, false, false)];
        if (god == 'atlas' && h < 3) options.add((4, true, false));
        if (god == 'hephaestus' && h <= 1) options.add((h + 2, false, true));

        for (final (newH, dome, dbl) in options) {
          var score = rng.nextInt(10);
          final oldH = heights[b];
          heights[b] = newH;
          final oppWins = _opponentCanReach3At(seat, b);
          heights[b] = oldH;

          if (oldH == 3 && newH == 4) {
            // Doming a level 3 tower: great if opponent threatened it, bad if only we could reach it
            final oppThreat = _opponentCanReach3At(seat, b);
            if (oppThreat) {
              score += 5000;
            } else if (heights[activeCell] == 2) {
              score -= 600;
            }
          } else if (newH == 3) {
            if (oppWins) {
              score -= 4000;
            } else if (heights[activeCell] == 2) {
              score += 1200;
            } else {
              score += 200;
            }
          } else if (newH < 4) {
            if (newH == heights[activeCell] + 1) {
              score += 350 * newH;
            } else {
              score += 120 * newH;
            }
          }

          if (score > bestScore) {
            bestScore = score;
            bestAction = {
              'type': 'build',
              'cell': b,
              if (dome) 'dome': true,
              if (dbl) 'double': true,
            };
          }
        }
      }
      return bestAction;
    }

    if (step == 'build2') {
      final cells = legalBuildCells(activeCell, excludeCell: firstBuildCell);
      if (cells.isEmpty) return {'type': 'pass'};
      for (final b in cells) {
        final h = heights[b];
        if (h == 3 && _opponentCanReach3At(seat, b)) {
          return {'type': 'build', 'cell': b};
        }
        if (h + 1 <= heights[activeCell] + 1 && h + 1 < 4) {
          heights[b] = h + 1;
          final bad = _opponentCanReach3At(seat, b);
          heights[b] = h;
          if (!bad) return {'type': 'build', 'cell': b};
        }
      }
      return {'type': 'pass'};
    }

    return null;
  }
}
