import 'dart:math';

import '../../src/engine.dart';

class CaptainSonarSystemInfo {
  final int id;
  final String key;
  final String name;
  final String emoji;
  final int maxCharge;
  final String desc;
  const CaptainSonarSystemInfo(
    this.id,
    this.key,
    this.name,
    this.emoji,
    this.maxCharge,
    this.desc,
  );
}

const List<CaptainSonarSystemInfo> kCaptainSonarSystems = [
  CaptainSonarSystemInfo(0, 'torpedo', '鱼雷', '🚀', 3, '满3格发射（曼哈顿距离1~4：直击2伤，九宫格溅射1伤）'),
  CaptainSonarSystemInfo(1, 'sonar', '声呐', '📡', 3, '满3格探测目标潜艇的精确行号与所在象限'),
  CaptainSonarSystemInfo(2, 'silence', '静音推进', '🤫', 4, '满4格直线潜行1~3格且不记录航向日志'),
  CaptainSonarSystemInfo(3, 'mine', '水雷', '💣', 3, '满3格在距离1~2格处引爆深水雷（九宫格1伤）'),
];

class CaptainSonarGame extends GameEngine {
  CaptainSonarGame(super.setup);

  static const List<int> maxCharges = [3, 3, 4, 3];

  late int maxRounds;
  int round = 1;
  int turn = 0;
  String phase = 'act'; // 'act' | 'over'

  /// 8x8 Ocean grid: true = impassable island.
  late List<List<bool>> islands;

  /// Secret position [r, c] per submarine seat (hidden from opponents in view(seat)!).
  late List<List<int>> subPos;

  /// Secret trail of visited [r, c] cells per seat since last surface.
  late List<List<List<int>>> trail;

  /// Hull HP per submarine seat (starts at 4).
  late List<int> hp;

  /// Sunk status per seat.
  late List<bool> sunk;

  /// Public direction log per seat ('N', 'S', 'E', 'W').
  late List<List<String>> headingLog;

  /// 4 System charge bars per seat: [torpedo(0..3), sonar(0..3), silence(0..4), mine(0..3)].
  late List<List<int>> charges;

  /// Publicly known sector (0..3) when a submarine surfaces (-1 if unknown).
  late List<int> publicSector;

  /// Private sonar intelligence log per seat.
  late List<List<String>> intelLog;

  /// Structured latest sonar ping per seat: targetSeat -> {'r': row, 'sector': sector, 'round': round}.
  late List<Map<String, Map<String, int>>> sonarIntel;

  /// Damage / tactical score per seat.
  late List<int> scores;

  /// Last explosion coordinates [r, c] for visual feedback.
  List<int>? lastExplosion;

  String lastEvent = '各潜艇已就位，深海潜行侦察开始！';

  @override
  bool get isOver => phase == 'over';

  @override
  bool get canResign => true;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    if (players == 4) {
      // 2v2 team alliance (0 & 2 vs 1 & 3), ranked by team survival + score
      final team0Alive = (!sunk[0] ? hp[0] : 0) + (!sunk[2] ? hp[2] : 0);
      final team1Alive = (!sunk[1] ? hp[1] : 0) + (!sunk[3] ? hp[3] : 0);
      final team0Score = team0Alive * 100 + scores[0] + scores[2];
      final team1Score = team1Alive * 100 + scores[1] + scores[3];
      if (team0Score != team1Score) {
        final winners = team0Score > team1Score ? const [0, 2] : const [1, 3];
        return rankWinners(players, winners);
      }
    }
    final adjusted = <num>[
      for (var s = 0; s < players; s++)
        (sunk[s] ? -500 : hp[s] * 50) + scores[s],
    ];
    return rankByScore(adjusted);
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    if (turn < 0 || turn >= players || sunk[turn]) return const [];
    return [turn];
  }

  static int sectorOf(int r, int c) => (r >= 4 ? 2 : 0) + (c >= 4 ? 1 : 0);

  static (int, int) dirDelta(String dir) {
    switch (dir) {
      case 'N':
        return (-1, 0);
      case 'S':
        return (1, 0);
      case 'W':
        return (0, -1);
      case 'E':
        return (0, 1);
      default:
        return (0, 0);
    }
  }

  bool isAllied(int s1, int s2) {
    if (s1 == s2) return true;
    if (players == 4) return (s1 % 2) == (s2 % 2);
    return false;
  }

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    maxRounds = mode == 'fast' ? 12 : 18;
    round = 1;
    turn = 0;
    phase = 'act';

    islands = List.generate(8, (_) => List<bool>.filled(8, false));
    // Place 6 strategic islands across the 4 sectors without blocking navigation
    const fixedIslands = [
      (1, 2),
      (2, 5),
      (3, 1),
      (4, 6),
      (5, 2),
      (6, 5),
    ];
    for (final (r, c) in fixedIslands) {
      islands[r][c] = true;
    }

    // Spawn each submarine in its own sector on an open cell
    const spawnSectors = [
      [(0, 0), (0, 1), (1, 0), (2, 2)],
      [(0, 7), (0, 6), (1, 7), (2, 6)],
      [(7, 0), (7, 1), (6, 0), (5, 1)],
      [(7, 7), (7, 6), (6, 7), (5, 6)],
    ];

    subPos = List.generate(players, (s) {
      final candidates = spawnSectors[s % 4]
          .where((rc) => !islands[rc.$1][rc.$2])
          .toList();
      final pick = candidates[rng.nextInt(candidates.length)];
      return [pick.$1, pick.$2];
    });

    trail = [
      for (var s = 0; s < players; s++)
        [
          [subPos[s][0], subPos[s][1]],
        ],
    ];
    hp = List<int>.filled(players, 4);
    sunk = List<bool>.filled(players, false);
    headingLog = [for (var s = 0; s < players; s++) <String>[]];
    charges = [for (var s = 0; s < players; s++) <int>[0, 0, 0, 0]];
    publicSector = List<int>.filled(players, -1);
    intelLog = [for (var s = 0; s < players; s++) <String>[]];
    sonarIntel = [for (var s = 0; s < players; s++) <String, Map<String, int>>{}];
    scores = List<int>.filled(players, 0);
    lastExplosion = null;
    lastEvent = '深海潜艇战开始！8×8 海域分为 4 个象限，追踪敌艇航向并充能发射鱼雷！';
    host.log('【深海潜艇战】全员潜入深海！航向日志公开，坐标与轨迹严格保密。');
  }

  bool isInTrail(int seat, int r, int c) {
    for (final cell in trail[seat]) {
      if (cell[0] == r && cell[1] == c) return true;
    }
    return false;
  }

  bool canStep(int seat, int r, int c) {
    if (r < 0 || r >= 8 || c < 0 || c >= 8) return false;
    if (islands[r][c]) return false;
    if (isInTrail(seat, r, c)) return false;
    return true;
  }

  List<String> validDirs(int seat) {
    final r = subPos[seat][0];
    final c = subPos[seat][1];
    final out = <String>[];
    for (final dir in const ['N', 'S', 'E', 'W']) {
      final (dr, dc) = dirDelta(dir);
      if (canStep(seat, r + dr, c + dc)) {
        out.add(dir);
      }
    }
    return out;
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('还没轮到你行动');
    if (sunk[seat]) throw GameError('你的潜艇已沉没');

    final type = asStr(action['type']);
    switch (type) {
      case 'move':
        _handleMove(seat, action);
        break;
      case 'surface':
        _handleSurface(seat);
        break;
      case 'torpedo':
        _handleTorpedo(seat, action);
        break;
      case 'sonar':
        _handleSonar(seat, action);
        break;
      case 'silence':
        _handleSilence(seat, action);
        break;
      case 'mine':
        _handleMine(seat, action);
        break;
      default:
        throw GameError('未知指令：$type');
    }
  }

  void _handleMove(int seat, Map<String, dynamic> action) {
    final dir = asStr(action['dir']).toUpperCase();
    if (!const ['N', 'S', 'E', 'W'].contains(dir)) {
      throw GameError('航向必须是 N / S / E / W');
    }
    final (dr, dc) = dirDelta(dir);
    final nr = subPos[seat][0] + dr;
    final nc = subPos[seat][1] + dc;
    if (nr < 0 || nr >= 8 || nc < 0 || nc >= 8) {
      throw GameError('目标超出 8×8 海域边界');
    }
    if (islands[nr][nc]) {
      throw GameError('目标海域存在岛屿阻挡');
    }
    if (isInTrail(seat, nr, nc)) {
      throw GameError('不能穿过自己的潜艇尾迹（需上浮清零尾迹）');
    }

    var chargeIdx = asInt(action['charge'], 0);
    if (chargeIdx < 0 || chargeIdx >= 4) chargeIdx = 0;

    subPos[seat] = [nr, nc];
    trail[seat].add([nr, nc]);
    headingLog[seat].add(dir);

    if (charges[seat][chargeIdx] < maxCharges[chargeIdx]) {
      charges[seat][chargeIdx]++;
    } else {
      for (var i = 0; i < 4; i++) {
        if (charges[seat][i] < maxCharges[i]) {
          chargeIdx = i;
          charges[seat][i]++;
          break;
        }
      }
    }

    final sys = kCaptainSonarSystems[chargeIdx];
    lastEvent = '${name(seat)} 向 $dir 潜行 1 格，为【${sys.emoji}${sys.name}】充能 (${charges[seat][chargeIdx]}/${sys.maxCharge})';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _handleSurface(int seat) {
    final r = subPos[seat][0];
    final c = subPos[seat][1];
    final sec = sectorOf(r, c);
    publicSector[seat] = sec;
    trail[seat] = [
      [r, c],
    ];
    headingLog[seat].clear();
    if (hp[seat] < 4) {
      hp[seat] = min(4, hp[seat] + 1);
    }
    lastEvent = '🌊 ${name(seat)} 在第 ${sec + 1} 象限紧急上浮！清空尾迹与航向日志，舰体修复至 ${hp[seat]} HP！';
    host.log(lastEvent);
    _advanceTurn();
  }

  void _handleTorpedo(int seat, Map<String, dynamic> action) {
    if (charges[seat][0] < maxCharges[0]) {
      throw GameError('鱼雷系统尚未充满（需 3 格能量）');
    }
    final tr = asInt(action['r'], -1);
    final tc = asInt(action['c'], -1);
    if (tr < 0 || tr >= 8 || tc < 0 || tc >= 8) {
      throw GameError('鱼雷目标坐标无效');
    }
    final dist = (subPos[seat][0] - tr).abs() + (subPos[seat][1] - tc).abs();
    if (dist < 1 || dist > 4) {
      throw GameError('鱼雷射程必须在曼哈顿距离 1~4 格以内');
    }

    charges[seat][0] = 0;
    lastExplosion = [tr, tc];
    _applyExplosion(seat, tr, tc, directDmg: 2, splashDmg: 1, weaponName: '🚀鱼雷');
  }

  void _handleMine(int seat, Map<String, dynamic> action) {
    if (charges[seat][3] < maxCharges[3]) {
      throw GameError('水雷系统尚未充满（需 3 格能量）');
    }
    final tr = asInt(action['r'], -1);
    final tc = asInt(action['c'], -1);
    if (tr < 0 || tr >= 8 || tc < 0 || tc >= 8) {
      throw GameError('水雷目标坐标无效');
    }
    final dist = (subPos[seat][0] - tr).abs() + (subPos[seat][1] - tc).abs();
    if (dist < 1 || dist > 2) {
      throw GameError('水雷引爆距离必须在 1~2 格以内');
    }

    charges[seat][3] = 0;
    lastExplosion = [tr, tc];
    _applyExplosion(seat, tr, tc, directDmg: 1, splashDmg: 1, weaponName: '💣深水雷');
  }

  void _applyExplosion(
    int attacker,
    int tr,
    int tc, {
    required int directDmg,
    required int splashDmg,
    required String weaponName,
  }) {
    final hits = <String>[];
    for (var s = 0; s < players; s++) {
      if (sunk[s]) continue;
      final sr = subPos[s][0];
      final sc = subPos[s][1];
      final dr = (sr - tr).abs();
      final dc = (sc - tc).abs();
      int dmg = 0;
      String hitType = '';
      if (dr == 0 && dc == 0) {
        dmg = directDmg;
        hitType = '直击';
      } else if (dr <= 1 && dc <= 1) {
        dmg = splashDmg;
        hitType = '溅射';
      }
      if (dmg > 0) {
        hp[s] = max(0, hp[s] - dmg);
        if (s != attacker && !isAllied(attacker, s)) {
          scores[attacker] += dmg * 10;
        }
        if (hp[s] <= 0) {
          sunk[s] = true;
          if (s != attacker && !isAllied(attacker, s)) {
            scores[attacker] += 25;
          }
          hits.add('${name(s)} 遭受$hitType(-$dmg HP) 被击沉！');
        } else {
          hits.add('${name(s)} 遭受$hitType(-$dmg HP，剩余 ${hp[s]} HP)');
        }
      }
    }

    final hitSummary = hits.isEmpty ? '未命中任何潜艇（落空）' : hits.join('；');
    lastEvent = '${name(attacker)} 向 ($tr,$tc) 发射$weaponName：$hitSummary';
    host.log(lastEvent);
    _checkGameOver();
  }

  void _handleSonar(int seat, Map<String, dynamic> action) {
    if (charges[seat][1] < maxCharges[1]) {
      throw GameError('声呐系统尚未充满（需 3 格能量）');
    }
    var target = asInt(action['target'], -1);
    if (target < 0 || target >= players || target == seat || sunk[target]) {
      target = -1;
      for (var s = 0; s < players; s++) {
        if (s != seat && !sunk[s] && !isAllied(seat, s)) {
          target = s;
          break;
        }
      }
      if (target < 0) {
        for (var s = 0; s < players; s++) {
          if (s != seat && !sunk[s]) {
            target = s;
            break;
          }
        }
      }
    }
    if (target < 0) throw GameError('没有可探测的目标潜艇');

    charges[seat][1] = 0;
    final tr = subPos[target][0];
    final tc = subPos[target][1];
    final sec = sectorOf(tr, tc);
    publicSector[target] = sec;
    sonarIntel[seat]['$target'] = {
      'r': tr,
      'sector': sec,
      'round': round,
    };
    final msg = '第$round轮 📡声呐锁定 ${name(target)}：位于第 ${tr + 1} 行 (r=$tr)、第 ${sec + 1} 象限 (Sector $sec)';
    intelLog[seat].add(msg);
    scores[seat] += 3;
    lastEvent = '📡 ${name(seat)} 启动声呐探测了 ${name(target)} 的坐标情报！';
    host.log(lastEvent);
  }

  void _handleSilence(int seat, Map<String, dynamic> action) {
    if (charges[seat][2] < maxCharges[2]) {
      throw GameError('静音推进尚未充满（需 4 格能量）');
    }
    final dir = asStr(action['dir']).toUpperCase();
    if (!const ['N', 'S', 'E', 'W'].contains(dir)) {
      throw GameError('静音推进方向必须是 N / S / E / W');
    }
    final steps = asInt(action['steps'], 1);
    if (steps < 1 || steps > 3) {
      throw GameError('静音推进步数必须在 1~3 步之间');
    }
    final (dr, dc) = dirDelta(dir);
    var curR = subPos[seat][0];
    var curC = subPos[seat][1];
    final stepped = <List<int>>[];
    for (var i = 1; i <= steps; i++) {
      final nr = curR + dr;
      final nc = curC + dc;
      if (!canStep(seat, nr, nc)) {
        throw GameError('静音推进第 $i 步受阻（越界、岛屿或自身尾迹）');
      }
      curR = nr;
      curC = nc;
      stepped.add([curR, curC]);
    }

    charges[seat][2] = 0;
    subPos[seat] = [curR, curC];
    for (final cell in stepped) {
      trail[seat].add(cell);
    }
    scores[seat] += 2;
    lastEvent = '🤫 ${name(seat)} 启动静音推进，向秘密方向潜行且不记录航向日志！';
    host.log(lastEvent);
  }

  void _checkGameOver() {
    if (sunk.every((s) => s)) {
      phase = 'over';
      lastEvent = '所有潜艇同归于尽，深海决战结束！';
      host.log(lastEvent);
      return;
    }

    if (players == 4) {
      final team0Alive = !sunk[0] || !sunk[2];
      final team1Alive = !sunk[1] || !sunk[3];
      if (!team0Alive || !team1Alive) {
        phase = 'over';
        final winTeam = team0Alive ? '蓝方舰队 (座位1&3)' : '红方舰队 (座位2&4)';
        lastEvent = '🏆 $winTeam 歼灭敌方潜艇编队，赢得深海决战胜利！';
        host.log(lastEvent);
        return;
      }
    } else {
      final aliveSeats = [
        for (var s = 0; s < players; s++)
          if (!sunk[s]) s,
      ];
      if (aliveSeats.length <= 1) {
        phase = 'over';
        final winner = aliveSeats.isNotEmpty ? name(aliveSeats.first) : '无人';
        lastEvent = '🏆 $winner 主宰深海，赢得潜艇战胜利！';
        host.log(lastEvent);
        return;
      }
    }

    if (sunk[turn]) {
      _advanceTurn();
    }
  }

  void _advanceTurn() {
    _checkGameOver();
    if (isOver) return;

    for (var i = 1; i <= players; i++) {
      final next = (turn + i) % players;
      if (next <= turn) {
        round++;
      }
      if (!sunk[next]) {
        turn = next;
        break;
      }
    }

    if (round > maxRounds) {
      phase = 'over';
      lastEvent = '达到最大巡航轮数 ($maxRounds 轮)，按潜艇耐久与战功结算胜负！';
      host.log(lastEvent);
    }
  }

  /// Deduce plausible target coordinates for an opponent using ONLY public headingLog,
  /// publicSector, islands, and seat's own sonarIntel (never reads hidden subPos!).
  List<(int, int)> deduceCandidatePositions(int viewerSeat, int targetSeat) {
    final log = headingLog[targetSeat];
    final knownPing = viewerSeat >= 0 && viewerSeat < players
        ? sonarIntel[viewerSeat]['$targetSeat']
        : null;
    final knownRow = knownPing?['r'];
    final knownSec = knownPing?['sector'] ??
        (publicSector[targetSeat] >= 0 ? publicSector[targetSeat] : null);

    final out = <(int, int)>[];
    for (var sr = 0; sr < 8; sr++) {
      for (var sc = 0; sc < 8; sc++) {
        if (islands[sr][sc]) continue;
        var r = sr;
        var c = sc;
        var ok = true;
        final visited = <(int, int)>{(r, c)};
        for (final dir in log) {
          final (dr, dc) = dirDelta(dir);
          r += dr;
          c += dc;
          if (r < 0 || r >= 8 || c < 0 || c >= 8 || islands[r][c] || !visited.add((r, c))) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        if (knownRow != null && r != knownRow) continue;
        if (knownSec != null && sectorOf(r, c) != knownSec) continue;
        out.add((r, c));
      }
    }
    return out;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final validPlayer = seat >= 0 && seat < players;
    return {
      'round': round,
      'maxRounds': maxRounds,
      'turn': turn,
      'phase': phase,
      'islands': [
        for (final row in islands) [for (final cell in row) cell],
      ],
      'hp': List<int>.of(hp),
      'sunk': List<bool>.of(sunk),
      'scores': List<int>.of(scores),
      'headingLog': [
        for (final log in headingLog) List<String>.of(log),
      ],
      'charges': [
        for (final ch in charges) List<int>.of(ch),
      ],
      'publicSector': List<int>.of(publicSector),
      'lastExplosion': lastExplosion != null ? List<int>.of(lastExplosion!) : null,
      'lastEvent': lastEvent,
      'canAct': !isOver && seat == turn,
      // Strictly hide opponent positions & trails while game is ongoing!
      'myPos': validPlayer ? List<int>.of(subPos[seat]) : null,
      'myTrail': validPlayer
          ? [for (final cell in trail[seat]) List<int>.of(cell)]
          : const [],
      'myIntel': validPlayer ? List<String>.of(intelLog[seat]) : const [],
      'mySonarIntel': validPlayer
          ? {
              for (final e in sonarIntel[seat].entries)
                e.key: Map<String, int>.of(e.value),
            }
          : const <String, dynamic>{},
      'validDirs': validPlayer ? validDirs(seat) : const <String>[],
      if (isOver)
        'revealedSubPos': [
          for (final p in subPos) List<int>.of(p),
        ],
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || seat != turn || sunk[seat]) return null;

    // 1. If Sonar is charged (3), ping an alive enemy first
    if (charges[seat][1] >= maxCharges[1]) {
      for (var s = 0; s < players; s++) {
        if (s != seat && !sunk[s] && !isAllied(seat, s)) {
          return {'type': 'sonar', 'target': s};
        }
      }
    }

    // 2. If Torpedo is charged (3), deduce enemy position from public logs & sonar intel and fire if within range 1..4 (avoiding self-damage)
    if (charges[seat][0] >= maxCharges[0]) {
      final myR = subPos[seat][0];
      final myC = subPos[seat][1];
      (int, int)? bestShot;
      for (var s = 0; s < players; s++) {
        if (s == seat || sunk[s] || isAllied(seat, s)) continue;
        final candidates = deduceCandidatePositions(seat, s);
        for (final (cr, cc) in candidates) {
          final dist = (myR - cr).abs() + (myC - cc).abs();
          final selfSplash = (myR - cr).abs() <= 1 && (myC - cc).abs() <= 1;
          if (dist >= 1 && dist <= 4 && !selfSplash) {
            bestShot = (cr, cc);
            break;
          }
        }
        if (bestShot != null) break;
      }
      if (bestShot == null) {
        // Fallback: fire at a valid cell at distance 2..4 away from self
        for (var r = 0; r < 8; r++) {
          for (var c = 0; c < 8; c++) {
            final dist = (myR - r).abs() + (myC - c).abs();
            final selfSplash = (myR - r).abs() <= 1 && (myC - c).abs() <= 1;
            if (dist >= 2 && dist <= 4 && !selfSplash) {
              bestShot = (r, c);
              break;
            }
          }
          if (bestShot != null) break;
        }
      }
      if (bestShot != null) {
        return {'type': 'torpedo', 'r': bestShot.$1, 'c': bestShot.$2};
      }
    }

    // 3. If Silence is charged (4), dash 1..2 steps in a valid direction
    final dirs = validDirs(seat);
    if (charges[seat][2] >= maxCharges[2] && dirs.isNotEmpty) {
      final dir = dirs[rng.nextInt(dirs.length)];
      final (dr, dc) = dirDelta(dir);
      var maxSteps = 1;
      if (canStep(seat, subPos[seat][0] + dr * 2, subPos[seat][1] + dc * 2)) {
        maxSteps = 2;
      }
      return {'type': 'silence', 'dir': dir, 'steps': maxSteps};
    }

    // 4. Primary action: Move if possible, otherwise Surface
    if (dirs.isEmpty || (hp[seat] == 1 && trail[seat].length >= 5)) {
      return {'type': 'surface'};
    }

    final chosenDir = dirs[rng.nextInt(dirs.length)];
    // Prefer charging torpedo (0) or sonar (1) or silence (2)
    var chargeChoice = 0;
    for (final pref in const [0, 1, 2, 3]) {
      if (charges[seat][pref] < maxCharges[pref]) {
        chargeChoice = pref;
        break;
      }
    }
    return {'type': 'move', 'dir': chosenDir, 'charge': chargeChoice};
  }

  @override
  void resign(int seat) {
    if (isOver || seat < 0 || seat >= players) return;
    sunk[seat] = true;
    hp[seat] = 0;
    lastEvent = '${name(seat)} 宣布弃舰投降！';
    host.log(lastEvent);
    _checkGameOver();
  }
}
