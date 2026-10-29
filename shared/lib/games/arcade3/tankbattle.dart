import 'dart:math';

import '../../src/engine.dart';
import 'a3_util.dart';

/// 坦克大战 (2-4 人). Real-time / rapid-tick 15×15 grid arena.
///
/// Terrain codes in [grid]:
///  * `#` steel wall (border is permanently indestructible; interior `#` can be
///    broken by 2-star upgraded shells)
///  * `+` destructible brick wall
///  * `~` grass (concealment — tanks and bullets pass through)
///  * `w` water (impassable to tanks, bullets fly over)
///  * `.` floor
///
/// Power-ups in [items]:
///  * `S` shield (temporary invulnerability)
///  * `F` rapid fire (faster reload + extra active bullet)
///  * `U` star upgrade (level 1: faster move/reload; level 2: heavy shells break steel)
///  * `H` heal (+1 life)
class TankBattle extends GameEngine {
  TankBattle(super.setup);

  static const w = 15, h = 15;
  static const tickMs = 100;
  static const countdownTicks = 15;
  static const defaultMaxTicks = 800;
  static const shieldDuration = 30;
  static const spawnShieldDuration = 12;
  static const explosionTicks = 5;

  /// Directions: 0 = up, 1 = right, 2 = down, 3 = left.
  static const dxs = [0, 1, 0, -1];
  static const dys = [-1, 0, 1, 0];
  static const dirNames = ['up', 'right', 'down', 'left'];

  /// Spawn corners (x, y, initialDir) for up to 4 players.
  static const spawns = [
    (1, 1, 2),
    (13, 13, 0),
    (13, 1, 2),
    (1, 13, 0),
  ];

  late int startLives;
  late String mapType;
  int maxTicks = defaultMaxTicks;

  /// Base terrain grid of length `w * h`.
  late List<String> grid;

  /// Power-ups lying on the floor: cell -> 'S' | 'F' | 'U' | 'H'.
  final Map<int, String> items = {};

  /// Active bullets on the arena.
  final List<TankBullet> bullets = [];

  /// Short-lived hit/explosion visual markers: cell -> ticks left.
  final Map<int, int> blasts = {};

  late List<TankPlayer> ps;
  int tick = 0;
  int countdown = countdownTicks;
  bool over = false;
  int _deaths = 0;
  int _resigns = 0;
  int _nextBulletId = 1;
  List<Map<String, dynamic>>? ranking;
  Map<String, dynamic>? last;

  @override
  bool get isOver => over;

  @override
  List<int>? get placings => over ? a3Placings(ranking, players) : null;

  @override
  int get botDelayMs => 250;

  @override
  bool get canResign => !over;

  static int cell(int x, int y) => y * w + x;
  static int cellX(int c) => c % w;
  static int cellY(int c) => c ~/ w;
  static bool isBorder(int c) {
    final x = c % w, y = c ~/ w;
    return x == 0 || y == 0 || x == w - 1 || y == h - 1;
  }

  static int stepCell(int c, int dir) {
    final nx = c % w + dxs[dir];
    final ny = c ~/ w + dys[dir];
    if (nx < 0 || ny < 0 || nx >= w || ny >= h) return -1;
    return ny * w + nx;
  }

  static int? parseDir(Object? raw) {
    if (raw is int && raw >= 0 && raw <= 3) return raw;
    if (raw is num && raw.isFinite) {
      final v = raw.toInt();
      if (v >= 0 && v <= 3) return v;
    }
    if (raw is String) {
      switch (raw.toLowerCase()) {
        case '0':
        case 'up':
        case 'u':
        case 'n':
          return 0;
        case '1':
        case 'right':
        case 'r':
        case 'e':
          return 1;
        case '2':
        case 'down':
        case 'd':
        case 's':
          return 2;
        case '3':
        case 'left':
        case 'l':
        case 'w':
          return 3;
      }
    }
    return null;
  }

  @override
  void resign(int seat) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能认输');
    final p = ps[seat];
    if (!p.alive) throw GameError('你已出局');
    p
      ..alive = false
      ..lives = 0
      ..deathTick = tick
      ..deathNo = ++_deaths
      ..resignNo = ++_resigns;
    host.log('${name(seat)} 认输');
    _checkEnd();
  }

  @override
  void start() {
    startLives = setup.opt<int>('lives', 3) == 5 ? 5 : 3;
    final m = setup.opt<String>('map', 'standard');
    mapType = (m == 'steel' || m == 'jungle') ? m : 'standard';
    grid = _buildMap(mapType);
    ps = [
      for (var s = 0; s < players; s++)
        TankPlayer(
          cell(spawns[s].$1, spawns[s].$2),
          spawns[s].$3,
          startLives,
        ),
    ];
    host.log('坦克大战开始！方向键/WASD 移动，空格开火。摧毁砖墙拾取护盾/速射/星级/维修道具，击败所有对手！');
    host.schedule(tickMs, _tick);
  }

  List<String> _buildMap(String type) {
    final g = List<String>.filled(w * h, '.');
    for (var i = 0; i < w * h; i++) {
      if (isBorder(i)) g[i] = '#';
    }
    // Keep spawn corners and their immediate orthogonal neighbors clear
    final clear = <int>{};
    for (final (sx, sy, _) in spawns) {
      final dx = sx == 1 ? 1 : -1;
      final dy = sy == 1 ? 1 : -1;
      clear.addAll([
        cell(sx, sy),
        cell(sx + dx, sy),
        cell(sx, sy + dy),
        cell(sx + dx, sy + dy),
      ]);
    }

    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final c = cell(x, y);
        if (clear.contains(c)) continue;
        if (type == 'steel') {
          if (x % 2 == 0 && y % 2 == 0) {
            g[c] = (x == 4 || x == 10 || y == 4 || y == 10) ? '+' : '#';
          } else if ((x == 7 && (y == 3 || y == 11)) || (y == 7 && (x == 3 || x == 11))) {
            g[c] = '~';
          } else if (x == 7 && y == 7) {
            g[c] = 'w';
          } else if (rng.nextDouble() < 0.42) {
            g[c] = '+';
          }
        } else if (type == 'jungle') {
          if ((y == 5 || y == 9) && (x >= 3 && x <= 5 || x >= 9 && x <= 11)) {
            g[c] = 'w';
          } else if ((x >= 2 && x <= 4 && y >= 6 && y <= 8) ||
              (x >= 10 && x <= 12 && y >= 6 && y <= 8) ||
              (x >= 6 && x <= 8 && (y == 3 || y == 11))) {
            g[c] = '~';
          } else if (x % 4 == 0 && y % 4 == 0) {
            g[c] = '#';
          } else if (rng.nextDouble() < 0.38) {
            g[c] = '+';
          }
        } else {
          // standard
          if (x % 3 == 0 && y % 3 == 0 && (x != 6 || y != 6)) {
            g[c] = '#';
          } else if ((x == 4 || x == 10) && y == 7) {
            g[c] = 'w';
          } else if (x == 7 && (y == 4 || y == 10)) {
            g[c] = '~';
          } else if (rng.nextDouble() < 0.45) {
            g[c] = '+';
          }
        }
      }
    }
    return g;
  }

  /// Whether a tank can drive onto cell [c] (ignoring other tanks if [ignoreTanks] is true).
  bool canTankEnter(int c, {int? ignoreSeat, bool ignoreTanks = false}) {
    if (c < 0 || c >= w * h) return false;
    final t = grid[c];
    if (t == '#' || t == '+' || t == 'w') return false;
    if (!ignoreTanks) {
      for (var s = 0; s < players; s++) {
        if (s != ignoreSeat && ps[s].alive && ps[s].cell == c) return false;
      }
    }
    return true;
  }

  static int moveCooldownFor(int stars) => stars >= 1 ? 1 : 2;
  static int fireCooldownFor(TankPlayer p) => (p.rapidFire || p.stars >= 1) ? 3 : 5;
  static int maxBulletsFor(TankPlayer p) => 1 + (p.rapidFire ? 1 : 0) + (p.stars >= 1 ? 1 : 0);

  int _activeBulletsOf(int seat) => bullets.where((b) => b.owner == seat).length;

  void _spawnPowerUp(int c) {
    const types = ['S', 'F', 'U', 'H'];
    items[c] = types[rng.nextInt(types.length)];
  }

  void _applyItem(int seat, String it) {
    final p = ps[seat];
    p.score += 30;
    switch (it) {
      case 'S':
        p.shield = max(p.shield, shieldDuration);
      case 'F':
        p.rapidFire = true;
      case 'U':
        p.stars = (p.stars + 1).clamp(0, 2);
      case 'H':
        p.lives = min(startLives + 2, p.lives + 1);
    }
  }

  // ---------------------------------------------------------------- tick

  void _tick() {
    if (over) return;
    tick++;
    if (countdown > 0) {
      countdown--;
      host.schedule(tickMs, _tick);
      return;
    }

    // Decay visual blast markers
    for (final c in blasts.keys.toList()) {
      final left = blasts[c]! - 1;
      if (left <= 0) {
        blasts.remove(c);
      } else {
        blasts[c] = left;
      }
    }

    final alive = [for (var s = 0; s < players; s++) if (ps[s].alive) s];

    // Decay cooldowns & shields
    for (final s in alive) {
      final p = ps[s];
      if (p.moveCool > 0) p.moveCool--;
      if (p.fireCool > 0) p.fireCool--;
      if (p.shield > 0) p.shield--;
    }

    // Bot steering inside tick
    for (final s in alive) {
      if (isBot(s) || ps[s].auto) {
        _botThink(s, isBot(s) ? botLevel : 1);
      }
    }

    // 1. Tank movement
    for (final s in alive) {
      final p = ps[s];
      final d = p.pending ?? p.hold;
      if (d == null) continue;
      p.pending = null;
      p.dir = d;
      if (p.moveCool > 0) continue;
      final nc = stepCell(p.cell, d);
      if (!canTankEnter(nc, ignoreSeat: s)) continue;
      p.cell = nc;
      p.moveCool = moveCooldownFor(p.stars);
      p.moves++;
      final it = items.remove(nc);
      if (it != null) _applyItem(s, it);
    }

    // 2. Tank firing
    for (final s in alive) {
      final p = ps[s];
      if (!p.wantFire) continue;
      p.wantFire = false;
      if (p.fireCool > 0 || _activeBulletsOf(s) >= maxBulletsFor(p)) continue;
      p.fireCool = fireCooldownFor(p);
      bullets.add(TankBullet(
        id: _nextBulletId++,
        owner: s,
        cell: p.cell,
        dir: p.dir,
        power: p.stars >= 2 ? 2 : 1,
      ));
    }

    // 3. Advance bullets 2 sub-steps per tick so fast shells never skip cells
    for (var sub = 0; sub < 2 && !over; sub++) {
      _stepBullets();
      _checkEnd();
    }

    // 4. Periodic supply drop if arena has few items
    if (!over && tick % 60 == 0 && items.length < 3) {
      final floors = [
        for (var i = 0; i < w * h; i++)
          if (grid[i] == '.' && !items.containsKey(i) && !ps.any((p) => p.alive && p.cell == i)) i,
      ];
      if (floors.isNotEmpty) {
        _spawnPowerUp(floors[rng.nextInt(floors.length)]);
      }
    }

    if (!over && tick >= maxTicks + countdownTicks) {
      _finish('时间到');
    }
    if (!over) host.schedule(tickMs, _tick);
  }

  void _stepBullets() {
    if (bullets.isEmpty) return;
    final prevCells = <int, int>{for (final b in bullets) b.id: b.cell};
    final deadBullets = <int>{};

    for (final b in bullets) {
      final nc = stepCell(b.cell, b.dir);
      if (nc < 0) {
        deadBullets.add(b.id);
        continue;
      }
      b.cell = nc;
    }

    // Bullet-vs-bullet cancellation (same cell or head-on swap)
    for (var i = 0; i < bullets.length; i++) {
      final a = bullets[i];
      if (deadBullets.contains(a.id)) continue;
      for (var j = i + 1; j < bullets.length; j++) {
        final b = bullets[j];
        if (deadBullets.contains(b.id) || a.owner == b.owner) continue;
        final sameCell = a.cell == b.cell;
        final swapped = a.cell == prevCells[b.id] && b.cell == prevCells[a.id];
        if (sameCell || swapped) {
          deadBullets.add(a.id);
          deadBullets.add(b.id);
          blasts[a.cell] = explosionTicks;
        }
      }
    }

    // Terrain & Tank hits
    for (final b in bullets) {
      if (deadBullets.contains(b.id)) continue;
      final c = b.cell;
      final g = grid[c];
      if (g == '#') {
        deadBullets.add(b.id);
        blasts[c] = explosionTicks;
        if (b.power >= 2 && !isBorder(c)) {
          grid[c] = '.';
          ps[b.owner].score += 15;
        }
        continue;
      }
      if (g == '+') {
        deadBullets.add(b.id);
        blasts[c] = explosionTicks;
        grid[c] = '.';
        ps[b.owner].score += 10;
        if (rng.nextInt(100) < 36) {
          _spawnPowerUp(c);
        }
        continue;
      }
      // Check tank hit (water 'w' and grass '~' let bullets fly right through!)
      for (var s = 0; s < players; s++) {
        if (s == b.owner || !ps[s].alive || ps[s].cell != c) continue;
        deadBullets.add(b.id);
        blasts[c] = explosionTicks;
        _hitTank(s, b.owner);
        break;
      }
    }

    bullets.removeWhere((b) => deadBullets.contains(b.id));
  }

  void _hitTank(int targetSeat, int shooterSeat) {
    final target = ps[targetSeat];
    final shooter = ps[shooterSeat];
    if (target.shield > 0) {
      target.shield = 0;
      shooter.score += 20;
      last = {'k': 'shield', 'target': targetSeat, 'by': shooterSeat, 't': tick};
      return;
    }
    target.lives--;
    shooter.hits++;
    shooter.score += 100;
    if (target.lives > 0) {
      // Respawn at safest corner
      final respawnCell = _pickRespawnCell(targetSeat);
      target
        ..cell = respawnCell
        ..shield = spawnShieldDuration
        ..stars = max(0, target.stars - 1)
        ..rapidFire = false
        ..hold = null
        ..pending = null;
      last = {'k': 'hit', 'target': targetSeat, 'by': shooterSeat, 't': tick};
      host.log('${name(targetSeat)} 被 ${name(shooterSeat)} 击中！（剩余 ${target.lives} 命）');
    } else {
      target
        ..alive = false
        ..deathTick = tick
        ..deathNo = ++_deaths;
      shooter.kills++;
      shooter.score += 150;
      last = {'k': 'kill', 'target': targetSeat, 'by': shooterSeat, 't': tick};
      host.log('${name(targetSeat)} 被 ${name(shooterSeat)} 击毁淘汰！');
    }
  }

  int _pickRespawnCell(int seat) {
    var bestCell = cell(spawns[seat % 4].$1, spawns[seat % 4].$2);
    var bestDist = -1;
    for (final (sx, sy, _) in spawns) {
      final c = cell(sx, sy);
      if (!canTankEnter(c, ignoreSeat: seat)) continue;
      var minEnemyDist = 999;
      for (var o = 0; o < players; o++) {
        if (o != seat && ps[o].alive) {
          final d = (cellX(ps[o].cell) - sx).abs() + (cellY(ps[o].cell) - sy).abs();
          if (d < minEnemyDist) minEnemyDist = d;
        }
      }
      if (minEnemyDist > bestDist) {
        bestDist = minEnemyDist;
        bestCell = c;
      }
    }
    return bestCell;
  }

  void _checkEnd() {
    if (over) return;
    final still = [for (var s = 0; s < players; s++) if (ps[s].alive) s];
    if (still.length <= 1) {
      _finish(still.isEmpty ? '同归于尽' : '${name(still.first)} 存活到最后');
    }
  }

  void _finish(String why) {
    if (over) return;
    over = true;
    ranking = a3Ranking(players, (a, b) {
      final pa = ps[a], pb = ps[b];
      if (pa.resignNo != pb.resignNo) {
        return pa.resignNo == 0 ? -1 : (pb.resignNo == 0 ? 1 : pb.resignNo - pa.resignNo);
      }
      if (pa.alive != pb.alive) return pa.alive ? -1 : 1;
      if (pa.lives != pb.lives) return pb.lives - pa.lives;
      if (!pa.alive && pa.deathNo != pb.deathNo) return pb.deathNo - pa.deathNo;
      if (pa.kills != pb.kills) return pb.kills - pa.kills;
      return pb.score - pa.score;
    }, (s) => {
          'lives': ps[s].lives,
          'kills': ps[s].kills,
          'hits': ps[s].hits,
          'score': ps[s].score,
          'alive': ps[s].alive,
        });
    host.log('游戏结束（$why）！冠军：${a3Winners(ranking!, name)}');
  }

  @override
  List<int> get waitingFor =>
      over ? const [] : a3Rotated([for (var s = 0; s < players; s++) if (ps[s].alive) s], tick);

  @override
  void handle(int seat, Map<String, dynamic> a) {
    if (over) throw GameError('对局已结束');
    if (seat < 0 || seat >= players) throw GameError('观众不能操作');
    final type = asStr(a['type']);
    if (type == 'idle' || type == 'step' || type == 'wait') return;
    final p = ps[seat];
    if (type == 'auto') {
      p.auto = true;
      return;
    }
    if (!p.alive) throw GameError('你已出局');

    switch (type) {
      case 'move':
      case 'dir':
        p.auto = false;
        final rawDir = a['dir'];
        if (rawDir == 'none' || rawDir == -1) {
          p.hold = null;
          return;
        }
        final d = parseDir(rawDir);
        if (d == null) throw GameError('方向无效');
        p.dir = d;
        p.hold = d;
        p.pending = d;

      case 'fire':
      case 'shoot':
        p.auto = false;
        if (countdown > 0) return;
        p.wantFire = true;

      default:
        throw GameError('未知操作');
    }
  }

  // ---------------------------------------------------------------- bot

  int _noise(int m) => setup.botRng.nextInt(m);

  /// Checks if an enemy tank is in line of sight from [fromCell] in direction [dir].
  /// Returns `(enemySeat, bricksInWay)` or null if blocked by steel.
  (int, int)? _scanLine(int seat, int fromCell, int dir) {
    var c = fromCell;
    var bricks = 0;
    final canBreakSteel = ps[seat].stars >= 2;
    for (var dist = 1; dist < w; dist++) {
      c = stepCell(c, dir);
      if (c < 0 || isBorder(c)) return null;
      final g = grid[c];
      if (g == '#') {
        if (!canBreakSteel) return null;
        bricks++;
      } else if (g == '+') {
        bricks++;
      }
      for (var o = 0; o < players; o++) {
        if (o != seat && ps[o].alive && ps[o].cell == c) {
          return (o, bricks);
        }
      }
    }
    return null;
  }

  /// Checks if an enemy bullet is heading directly toward [cell].
  TankBullet? _incomingBullet(int seat, int c) {
    final cx = cellX(c), cy = cellY(c);
    for (final b in bullets) {
      if (b.owner == seat) continue;
      final bx = cellX(b.cell), by = cellY(b.cell);
      if (bx == cx && ((b.dir == 2 && by < cy) || (b.dir == 0 && by > cy))) return b;
      if (by == cy && ((b.dir == 1 && bx < cx) || (b.dir == 3 && bx > cx))) return b;
    }
    return null;
  }

  void _botThink(int seat, int level) {
    final p = ps[seat];
    p.pending = null;

    // 1. Dodge incoming bullets if possible
    final inc = level > 0 ? _incomingBullet(seat, p.cell) : null;
    if (inc != null && p.shield == 0) {
      final perpDirs = (inc.dir == 0 || inc.dir == 2) ? [1, 3] : [0, 2];
      for (final d in perpDirs) {
        final nc = stepCell(p.cell, d);
        if (canTankEnter(nc, ignoreSeat: seat)) {
          p.dir = d;
          p.hold = d;
          p.pending = d;
          return;
        }
      }
      // Or shoot back to cancel the bullet
      final oppDir = (inc.dir + 2) % 4;
      p.dir = oppDir;
      p.hold = null;
      p.wantFire = true;
      return;
    }

    if (level <= 0 && _noise(4) == 0) {
      p.hold = null;
      return;
    }

    // 2. Check if any direction has a clear (or 1-brick) shot at an enemy tank
    for (var d = 0; d < 4; d++) {
      final hit = _scanLine(seat, p.cell, d);
      if (hit != null && hit.$2 <= (level >= 2 ? 2 : 1)) {
        p.dir = d;
        p.wantFire = true;
        // Keep advancing toward enemy if path is open and far
        final nc = stepCell(p.cell, d);
        p.hold = (hit.$2 == 0 && canTankEnter(nc, ignoreSeat: seat) && _noise(2) == 0) ? d : null;
        return;
      }
    }

    // 3. BFS toward nearest item or into firing alignment with an enemy tank
    final start = p.cell;
    final firstDir = <int, int>{};
    final q = <int>[start];
    int? chosenDir;

    bool isGoal(int c) {
      if (items.containsKey(c)) return true;
      for (var d = 0; d < 4; d++) {
        final hit = _scanLine(seat, c, d);
        if (hit != null && hit.$2 <= 1) return true;
      }
      return false;
    }

    for (var i = 0; i < q.length && chosenDir == null; i++) {
      final cur = q[i];
      for (var d = 0; d < 4; d++) {
        final nc = stepCell(cur, d);
        if (nc < 0 || isBorder(nc) || firstDir.containsKey(nc) || nc == start) continue;
        final g = grid[nc];
        // Allow pathing through floor, grass, and destructible bricks
        if (g == '#' || g == 'w') continue;
        var tankBlocked = false;
        for (var o = 0; o < players; o++) {
          if (o != seat && ps[o].alive && ps[o].cell == nc) {
            tankBlocked = true;
            break;
          }
        }
        if (tankBlocked) continue;
        final stepD = cur == start ? d : firstDir[cur]!;
        firstDir[nc] = stepD;
        if (isGoal(nc)) {
          chosenDir = stepD;
          break;
        }
        q.add(nc);
      }
    }

    if (chosenDir != null) {
      final nc = stepCell(start, chosenDir);
      p.dir = chosenDir;
      if (nc >= 0 && grid[nc] == '+') {
        // Shoot brick blocking the path
        p.hold = null;
        p.wantFire = true;
      } else {
        p.hold = chosenDir;
        p.pending = chosenDir;
        if (_noise(4) == 0) p.wantFire = true;
      }
      return;
    }

    // Fallback: random walkable direction or shoot adjacent brick
    final walkDirs = [for (var d = 0; d < 4; d++) if (canTankEnter(stepCell(start, d), ignoreSeat: seat)) d];
    if (walkDirs.isNotEmpty) {
      final d = walkDirs[_noise(walkDirs.length)];
      p.dir = d;
      p.hold = d;
      if (_noise(5) == 0) p.wantFire = true;
    } else {
      for (var d = 0; d < 4; d++) {
        final nc = stepCell(start, d);
        if (nc >= 0 && grid[nc] == '+') {
          p.dir = d;
          p.hold = null;
          p.wantFire = true;
          return;
        }
      }
    }
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat < 0 || seat >= players) return null;
    final p = ps[seat];
    if (!p.alive || countdown > 0 || isBot(seat) || p.auto) return {'type': 'idle'};
    return {'type': 'auto'};
  }

  // ---------------------------------------------------------------- view

  @override
  Map<String, dynamic> view(int seat) {
    return {
      'phase': over ? 'over' : (countdown > 0 ? 'countdown' : 'play'),
      'tick': tick,
      'tickMs': tickMs,
      'w': w,
      'h': h,
      'cd': countdown,
      'map': mapType,
      'startLives': startLives,
      'left': over ? 0 : (maxTicks + countdownTicks - tick).clamp(0, maxTicks) * tickMs ~/ 1000,
      'g': grid.join(),
      'items': [
        for (final e in items.entries) {'c': e.key, 't': e.value},
      ],
      'bullets': [
        for (final b in bullets) {'id': b.id, 'c': b.cell, 'd': b.dir, 'o': b.owner, 'p': b.power},
      ],
      'blasts': [
        for (final e in blasts.entries) [e.key, e.value],
      ],
      'ps': [
        for (var s = 0; s < players; s++)
          {
            'c': ps[s].cell,
            'al': ps[s].alive,
            'd': ps[s].dir,
            'lv': ps[s].lives,
            'k': ps[s].kills,
            'h': ps[s].hits,
            'sc': ps[s].score,
            'sh': ps[s].shield,
            'rf': ps[s].rapidFire,
            'st': ps[s].stars,
            'bush': grid[ps[s].cell] == '~',
          },
      ],
      'last': last,
      'final': ranking,
    };
  }
}

class TankBullet {
  final int id;
  final int owner;
  int cell;
  final int dir;
  final int power;
  TankBullet({
    required this.id,
    required this.owner,
    required this.cell,
    required this.dir,
    this.power = 1,
  });
}

class TankPlayer {
  int cell;
  int dir;
  int lives;
  TankPlayer(this.cell, this.dir, this.lives);

  int? hold;
  int? pending;
  bool wantFire = false;
  int moveCool = 0;
  int fireCool = 0;
  int shield = 0;
  bool rapidFire = false;
  int stars = 0;

  int kills = 0;
  int hits = 0;
  int score = 0;
  int moves = 0;
  bool alive = true;
  bool auto = false;
  int deathTick = 0;
  int deathNo = 0;
  int resignNo = 0;
}
