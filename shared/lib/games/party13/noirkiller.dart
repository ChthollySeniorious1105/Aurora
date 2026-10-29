import '../../src/engine.dart';

class NoirSuspectInfo {
  final int id;
  final String name;
  final String role;
  final String icon;
  const NoirSuspectInfo(this.id, this.name, this.role, this.icon);
}

const List<NoirSuspectInfo> kNoirSuspects = [
  NoirSuspectInfo(0, '艾琳', '爵士歌女', '🎤'),
  NoirSuspectInfo(1, '维克多', '私家侦探', '🕵️'),
  NoirSuspectInfo(2, '霍华德', '银行大亨', '💼'),
  NoirSuspectInfo(3, '克莱尔', '夜总会老板', '🍸'),
  NoirSuspectInfo(4, '马库斯', '前线记者', '📸'),
  NoirSuspectInfo(5, '伊芙琳', '神秘贵妇', '💎'),
  NoirSuspectInfo(6, '雷蒙德', '黑帮保镖', '🕶️'),
  NoirSuspectInfo(7, '苏菲', '剧场名伶', '🎭'),
  NoirSuspectInfo(8, '亚瑟', '古董商人', '🏺'),
  NoirSuspectInfo(9, '洛伦佐', '赌场荷官', '🎲'),
  NoirSuspectInfo(10, '海伦', '外科医生', '🩺'),
  NoirSuspectInfo(11, '文森特', '午夜琴师', '🎹'),
  NoirSuspectInfo(12, '格蕾丝', '机要秘书', '📁'),
  NoirSuspectInfo(13, '费利克斯', '化学教授', '🧪'),
  NoirSuspectInfo(14, '诺拉', '占卜女巫', '🔮'),
  NoirSuspectInfo(15, '斯坦利', '退休警长', '🚓'),
  NoirSuspectInfo(16, '碧翠丝', '豪门千金', '👒'),
  NoirSuspectInfo(17, '奥斯卡', '钟表匠人', '⌚'),
  NoirSuspectInfo(18, '薇薇安', '时装模特', '👗'),
  NoirSuspectInfo(19, '哈罗德', '法官大人', '⚖️'),
  NoirSuspectInfo(20, '赛琳娜', '芭蕾舞者', '🩰'),
  NoirSuspectInfo(21, '西蒙', '调酒大师', '🥃'),
  NoirSuspectInfo(22, '戴安娜', '拍卖行主', '🔨'),
  NoirSuspectInfo(23, '埃德加', '推理小说家', '🖋️'),
  NoirSuspectInfo(24, '朱莉娅', '庄园管家', '🗝️'),
];

class NoirKillerGame extends GameEngine {
  NoirKillerGame(super.setup);

  /// 5x5 grid of suspect IDs (0..24)
  late List<List<int>> grid;

  /// Status for each suspect ID (0..24): 0 = Alive, 1 = Exonerated, 2 = Dead
  late List<int> status;

  /// Remaining evidence deck (suspect IDs)
  late List<int> evidenceDeck;

  /// Secret identity of Killer (Seat 0)
  int killerSuspect = 0;

  /// Secret identity of Inspector (Seats 1..P-1)
  int inspectorSuspect = 1;

  /// Current active seat: 0 for Killer, 1..P-1 for Inspector
  int turn = 0;

  /// Tracks which Inspector seat acts next
  int inspectorTurnIndex = 1;

  int deadCount = 0;
  late int targetKills;
  int turnCount = 0;

  /// Last shift action: {'axis': 'row'|'col', 'index': 0..4, 'dir': 1|-1}
  Map<String, dynamic>? lastShift;

  /// Public clue from last exonerate/kill/shift
  bool? lastRadarHit;
  int? lastExonerated;
  int? lastKilled;
  int? lastAccused;
  String lastActionText = '游戏开始，杀手先行动';

  bool over = false;
  String? winner; // 'killer' or 'inspector'
  String winReason = '';

  @override
  bool get isOver => over;

  @override
  bool get canResign => true;

  @override
  void resign(int seat) {
    if (over) throw GameError('游戏已结束');
    over = true;
    if (seat == 0) {
      winner = 'inspector';
      winReason = '${name(seat)} (杀手) 认输，探长获胜！';
    } else {
      winner = 'killer';
      winReason = '${name(seat)} (探长) 认输，杀手获胜！';
    }
    host.log(winReason);
  }

  @override
  List<int>? get placings {
    if (!over) return null;
    if (winner == 'killer') {
      return rankWinners(players, const [0]);
    } else {
      return rankWinners(players, [for (var s = 1; s < players; s++) s]);
    }
  }

  @override
  List<int> get waitingFor => over ? const [] : [turn];

  @override
  void start() {
    final mode = setup.opt<String>('mode', 'standard');
    targetKills = mode == 'fast' ? 8 : 11;

    final ids = shuffled([for (var i = 0; i < 25; i++) i], rng);
    grid = [
      for (var r = 0; r < 5; r++) [for (var c = 0; c < 5; c++) ids[r * 5 + c]]
    ];
    status = List<int>.filled(25, 0);

    final deckIds = shuffled([for (var i = 0; i < 25; i++) i], rng);
    killerSuspect = deckIds.removeLast();
    inspectorSuspect = deckIds.removeLast();
    evidenceDeck = deckIds;

    turn = 0;
    inspectorTurnIndex = 1;
    deadCount = 0;
    turnCount = 0;
    lastShift = null;
    lastRadarHit = null;
    lastExonerated = null;
    lastKilled = null;
    lastAccused = null;
    over = false;
    winner = null;
    winReason = '';
    lastActionText = '黑色追缉令开始！杀手暗中潜伏，目标作案 $targetKills 起。';
    host.log(lastActionText);
  }

  /// Find (row, col) of a suspect ID on the 5x5 grid.
  (int, int) posOf(int suspectId) {
    for (var r = 0; r < 5; r++) {
      for (var c = 0; c < 5; c++) {
        if (grid[r][c] == suspectId) return (r, c);
      }
    }
    return (-1, -1);
  }

  /// Check if two suspects are 8-way adjacent on the 5x5 grid.
  bool areAdjacent(int s1, int s2) {
    final (r1, c1) = posOf(s1);
    final (r2, c2) = posOf(s2);
    if (r1 < 0 || r2 < 0) return false;
    final dr = (r1 - r2).abs();
    final dc = (c1 - c2).abs();
    return dr <= 1 && dc <= 1 && !(dr == 0 && dc == 0);
  }

  /// Return all suspect IDs 8-way adjacent to [suspectId].
  List<int> neighborsOf(int suspectId) {
    final (r, c) = posOf(suspectId);
    if (r < 0) return const [];
    final out = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < 5 && nc >= 0 && nc < 5) {
          out.add(grid[nr][nc]);
        }
      }
    }
    return out;
  }

  /// Check if a shift reverses [lastShift].
  bool isReverseShift(String axis, int index, int dir) {
    if (lastShift == null) return false;
    return lastShift!['axis'] == axis &&
        lastShift!['index'] == index &&
        lastShift!['dir'] == -dir;
  }

  void _applyShift(String axis, int index, int dir) {
    if (axis == 'row') {
      final row = List<int>.of(grid[index]);
      for (var c = 0; c < 5; c++) {
        grid[index][(c + dir + 5) % 5] = row[c];
      }
    } else {
      final col = [for (var r = 0; r < 5; r++) grid[r][index]];
      for (var r = 0; r < 5; r++) {
        grid[(r + dir + 5) % 5][index] = col[r];
      }
    }
  }

  void _advanceTurn() {
    turnCount++;
    if (over) return;
    if (turn == 0) {
      turn = inspectorTurnIndex;
      inspectorTurnIndex++;
      if (inspectorTurnIndex >= players) inspectorTurnIndex = 1;
    } else {
      turn = 0;
    }
  }

  int _resolveTargetSuspect(Map<String, dynamic> action) {
    if (action.containsKey('target')) {
      return asInt(action['target'], -1);
    }
    final r = asInt(action['r'] ?? action['row'], -1);
    final c = asInt(action['c'] ?? action['col'], -1);
    if (r >= 0 && r < 5 && c >= 0 && c < 5) {
      return grid[r][c];
    }
    return -1;
  }

  (String, int, int) _parseShift(Map<String, dynamic> action) {
    var axis = asStr(action['axis'], '');
    var index = asInt(action['index'], -1);
    if (axis.isEmpty) {
      if (action.containsKey('row')) {
        axis = 'row';
        index = asInt(action['row'], -1);
      } else if (action.containsKey('col')) {
        axis = 'col';
        index = asInt(action['col'], -1);
      }
    }
    if (axis != 'row' && axis != 'col') {
      throw GameError('移动方向轴必须是 row 或 col');
    }
    if (index < 0 || index >= 5) {
      throw GameError('行列索引必须在 0..4 之间');
    }
    final rawDir = action['dir'];
    int dir;
    if (rawDir is String) {
      if (rawDir == 'right' || rawDir == 'down' || rawDir == '+1' || rawDir == '1') {
        dir = 1;
      } else if (rawDir == 'left' || rawDir == 'up' || rawDir == '-1') {
        dir = -1;
      } else {
        throw GameError('无效的移动方向');
      }
    } else {
      dir = asInt(rawDir, 0);
    }
    if (dir != 1 && dir != -1) {
      throw GameError('移动方向必须是 1 或 -1');
    }
    return (axis, index, dir);
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (over) throw GameError('游戏已结束');
    if (seat != turn) throw GameError('当前不是你的回合');

    final type = asStr(action['type']);
    final isKiller = seat == 0;

    if (type == 'shift') {
      final (axis, index, dir) = _parseShift(action);
      if (isReverseShift(axis, index, dir)) {
        throw GameError('不能立即反向推回对手上一步移动的行列');
      }
      _applyShift(axis, index, dir);
      lastShift = {'axis': axis, 'index': index, 'dir': dir};
      final axisName = axis == 'row' ? '第 ${index + 1} 行' : '第 ${index + 1} 列';
      final dirName = axis == 'row'
          ? (dir == 1 ? '向右' : '向左')
          : (dir == 1 ? '向下' : '向上');
      lastActionText = '${isKiller ? "杀手" : "探长"} 将 $axisName $dirName 平移了 1 格';
      host.log(lastActionText);
      _advanceTurn();
      return;
    }

    if (isKiller) {
      if (type == 'kill') {
        final target = _resolveTargetSuspect(action);
        if (target < 0 || target >= 25) throw GameError('无效的目标嫌疑人');
        if (target == killerSuspect) throw GameError('杀手不能暗杀自己');
        if (status[target] == 2) throw GameError('该嫌疑人已经被害');
        if (!areAdjacent(killerSuspect, target)) {
          throw GameError('只能暗杀杀手周围 8 格相邻的嫌疑人');
        }
        status[target] = 2;
        deadCount++;
        lastKilled = target;
        lastShift = null;
        final suspectName = kNoirSuspects[target].name;

        if (target == inspectorSuspect) {
          over = true;
          winner = 'killer';
          winReason = '杀手暗杀了探长本人（$suspectName），杀手大获全胜！';
          lastActionText = winReason;
          host.log(winReason);
          return;
        }
        if (deadCount >= targetKills) {
          over = true;
          winner = 'killer';
          winReason = '被害人数达到 $deadCount/$targetKills 人，杀手成功制造恐慌并逃脱！';
          lastActionText = winReason;
          host.log(winReason);
          return;
        }
        lastActionText = '凶案发生！【$suspectName】遇害（已被害 $deadCount/$targetKills 人）';
        host.log(lastActionText);
        _advanceTurn();
        return;
      }

      if (type == 'disguise') {
        if (evidenceDeck.isEmpty) throw GameError('证据牌堆已空，无法伪装');
        final drawn = evidenceDeck.removeLast();
        lastShift = null;
        if (status[drawn] == 0) {
          final oldKiller = killerSuspect;
          status[oldKiller] = 1;
          killerSuspect = drawn;
          lastExonerated = oldKiller;
          lastActionText =
              '杀手发动【伪装】！【${kNoirSuspects[oldKiller].name}】洗清嫌疑，杀手已更换为新身份';
        } else {
          lastActionText =
              '杀手尝试【伪装】抽到【${kNoirSuspects[drawn].name}】（已非存活清白待定），伪装未能更换身份';
        }
        host.log(lastActionText);
        _advanceTurn();
        return;
      }

      throw GameError('杀手只能执行 shift / kill / disguise');
    } else {
      // Inspector turn
      if (type == 'accuse') {
        final target = _resolveTargetSuspect(action);
        if (target < 0 || target >= 25) throw GameError('无效的指控目标');
        if (status[target] == 2) throw GameError('不能指控已经遇害的人');
        if (target == inspectorSuspect) throw GameError('探长不能逮捕自己');
        if (!areAdjacent(inspectorSuspect, target)) {
          throw GameError('只能逮捕探长周围 8 格相邻的嫌疑人');
        }
        lastAccused = target;
        lastShift = null;
        final suspectName = kNoirSuspects[target].name;

        if (target == killerSuspect) {
          over = true;
          winner = 'inspector';
          winReason = '探长成功锁定并逮捕真凶【$suspectName】，正义获胜！';
          lastActionText = winReason;
          host.log(winReason);
          return;
        } else {
          status[target] = 1;
          lastExonerated = target;
          lastActionText = '探长审讯了【$suspectName】，证实其清白并非真凶';
          host.log(lastActionText);
          _advanceTurn();
          return;
        }
      }

      if (type == 'exonerate') {
        if (evidenceDeck.isEmpty) throw GameError('证据牌堆已空，无法继续排查');
        int drawn = evidenceDeck.removeLast();
        while (status[drawn] == 2 && evidenceDeck.isNotEmpty) {
          drawn = evidenceDeck.removeLast();
        }
        if (status[drawn] == 0) {
          status[drawn] = 1;
        }
        lastExonerated = drawn;
        lastShift = null;
        lastRadarHit = areAdjacent(inspectorSuspect, killerSuspect);
        final radarStr = lastRadarHit! ? '⚠️ 警报：杀手就在探长周围8格内！' : '安全：杀手不在探长周围8格内';
        lastActionText = '探长排查确认【${kNoirSuspects[drawn].name}】清白（$radarStr）';
        host.log(lastActionText);
        _advanceTurn();
        return;
      }

      throw GameError('探长只能执行 shift / accuse / exonerate');
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canSeeKiller = seat == 0 || over;
    final canSeeInspector = seat >= 1 || over;

    final killerNeighbors = canSeeKiller ? neighborsOf(killerSuspect) : <int>[];
    final inspectorNeighbors =
        canSeeInspector ? neighborsOf(inspectorSuspect) : <int>[];

    return {
      'grid': [
        for (final row in grid) [...row]
      ],
      'status': [...status],
      'suspects': [
        for (final s in kNoirSuspects)
          {
            'id': s.id,
            'name': s.name,
            'role': s.role,
            'icon': s.icon,
          }
      ],
      'killerSuspect': canSeeKiller ? killerSuspect : -1,
      'inspectorSuspect': canSeeInspector ? inspectorSuspect : -1,
      'killerNeighbors': killerNeighbors,
      'inspectorNeighbors': inspectorNeighbors,
      'turn': turn,
      'turnCount': turnCount,
      'deadCount': deadCount,
      'targetKills': targetKills,
      'evidenceCount': evidenceDeck.length,
      'lastShift': lastShift,
      'lastRadarHit': lastRadarHit,
      'lastExonerated': lastExonerated,
      'lastKilled': lastKilled,
      'lastAccused': lastAccused,
      'lastActionText': lastActionText,
      'over': over,
      'winner': winner,
      'winReason': winReason,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (over || seat != turn) return null;

    if (seat == 0) {
      // Killer bot: only uses Killer's own knowledge (knows killerSuspect, does NOT know inspectorSuspect)
      final adj = neighborsOf(killerSuspect)
          .where((id) => status[id] != 2 && id != killerSuspect)
          .toList();

      // If radar just pinged and deck has cards, consider disguise on higher difficulty
      if (botLevel >= 1 &&
          lastRadarHit == true &&
          evidenceDeck.isNotEmpty &&
          rng.nextDouble() < 0.45) {
        return {'type': 'disguise'};
      }

      if (adj.isNotEmpty) {
        // Prefer killing unexonerated suspects (status == 0) as Inspector is status 0
        final primeTargets = adj.where((id) => status[id] == 0).toList();
        final pool = primeTargets.isNotEmpty ? primeTargets : adj;
        final target = pool[rng.nextInt(pool.length)];
        return {'type': 'kill', 'target': target};
      }

      if (evidenceDeck.isNotEmpty && rng.nextDouble() < 0.5) {
        return {'type': 'disguise'};
      }

      return _pickValidShift();
    } else {
      // Inspector bot: only uses Inspector's own knowledge (knows inspectorSuspect, does NOT know killerSuspect)
      final adjSuspects = neighborsOf(inspectorSuspect)
          .where((id) => status[id] == 0 && id != inspectorSuspect)
          .toList();

      if (adjSuspects.isNotEmpty) {
        final target = adjSuspects[rng.nextInt(adjSuspects.length)];
        return {'type': 'accuse', 'target': target};
      }

      if (evidenceDeck.isNotEmpty && rng.nextDouble() < 0.35) {
        return {'type': 'exonerate'};
      }

      // Try to find a shift that brings a status==0 suspect adjacent to inspectorSuspect
      final (ir, ic) = posOf(inspectorSuspect);
      for (final axis in const ['row', 'col']) {
        for (var idx = 0; idx < 5; idx++) {
          for (final dir in const [1, -1]) {
            if (isReverseShift(axis, idx, dir)) continue;
            if ((axis == 'row' && (idx - ir).abs() <= 1) ||
                (axis == 'col' && (idx - ic).abs() <= 1)) {
              return {'type': 'shift', 'axis': axis, 'index': idx, 'dir': dir};
            }
          }
        }
      }

      return _pickValidShift();
    }
  }

  Map<String, dynamic> _pickValidShift() {
    final options = <Map<String, dynamic>>[];
    for (final axis in const ['row', 'col']) {
      for (var i = 0; i < 5; i++) {
        for (final dir in const [1, -1]) {
          if (!isReverseShift(axis, i, dir)) {
            options.add({'type': 'shift', 'axis': axis, 'index': i, 'dir': dir});
          }
        }
      }
    }
    return options[rng.nextInt(options.length)];
  }
}
