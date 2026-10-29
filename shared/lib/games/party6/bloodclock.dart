import '../../src/ai.dart';
import '../../src/engine.dart';

/// Role metadata for Blood on the Clocktower: Trouble Brewing (血染钟楼·灾祸滋生).
class BotcRole {
  final String id;
  final String name;
  final String team; // 'townsfolk', 'outsider', 'minion', 'demon'
  final String desc;
  const BotcRole(this.id, this.name, this.team, this.desc);

  bool get isGood => team == 'townsfolk' || team == 'outsider';
  bool get isEvil => team == 'minion' || team == 'demon';
}

const Map<String, BotcRole> kBotcRoles = {
  // Demon
  'imp': BotcRole('imp', '小恶魔', 'demon', '第二夜起每晚杀害一名玩家；若自刀则一名存活爪牙变为新小恶魔。'),
  // Minions
  'poisoner': BotcRole('poisoner', '投毒者', 'minion', '每晚选择一名玩家下毒，使其当晚与次日技能失效且获得假情报。'),
  'scarlet_woman': BotcRole('scarlet_woman', '红唇女郎', 'minion', '若恶魔死亡前场上有至少 5 名存活玩家，你变为新的小恶魔。'),
  'baron': BotcRole('baron', '男爵', 'minion', '开局设置时增加 2 名外来者（减少 2 名镇民）。'),
  'spy': BotcRole('spy', '间谍', 'minion', '每晚查看完整魔典，且可能被善良查验视为镇民或外来者。'),
  // Outsiders
  'butler': BotcRole('butler', '管家', 'outsider', '每晚选择一名主人；次日只有主人投赞成（或未反对）时你才能投赞成票。'),
  'drunk': BotcRole('drunk', '酒鬼', 'outsider', '你以为自己是一个镇民角色，但其实技能无效且获得假情报。'),
  'recluse': BotcRole('recluse', '隐士', 'outsider', '你可能被善良查验视为邪恶的爪牙或恶魔。'),
  'saint': BotcRole('saint', '圣徒', 'outsider', '如果你被处决，邪恶阵营立即获胜！'),
  // Townsfolk
  'washerwoman': BotcRole('washerwoman', '洗衣妇', 'townsfolk', '首夜得知两名玩家中有一人是某个特定镇民。'),
  'librarian': BotcRole('librarian', '图书管理员', 'townsfolk', '首夜得知两名玩家中有一人是某个特定外来者（或无外来者在场）。'),
  'investigator': BotcRole('investigator', '调查员', 'townsfolk', '首夜得知两名玩家中有一人是某个特定爪牙。'),
  'chef': BotcRole('chef', '厨师', 'townsfolk', '首夜得知邻座的邪恶玩家共有多少对。'),
  'empath': BotcRole('empath', '共情者', 'townsfolk', '每晚得知你最近的两名存活邻居中共有几名邪恶玩家。'),
  'fortune_teller': BotcRole('fortune_teller', '占卜师', 'townsfolk', '每晚选择两名玩家，得知其中是否有恶魔（含一名善良宿敌干扰项）。'),
  'undertaker': BotcRole('undertaker', '送葬者', 'townsfolk', '每晚得知今天白天被处决玩家的真实角色。'),
  'monk': BotcRole('monk', '僧侣', 'townsfolk', '第二夜起每晚选择一名其他玩家，保护其免受恶魔杀害。'),
  'ravenkeeper': BotcRole('ravenkeeper', '渡鸦守卫', 'townsfolk', '若在夜晚死于恶魔袭击，当晚选择一名玩家得知其角色。'),
  'virgin': BotcRole('virgin', '处女', 'townsfolk', '首次被提名时，若提名者是镇民，提名者立即被处决。'),
  'slayer': BotcRole('slayer', '猎手', 'townsfolk', '整局一次，白天可公开向一名玩家开枪；若是恶魔则其立即死亡。'),
  'soldier': BotcRole('soldier', '士兵', 'townsfolk', '夜晚不会死于恶魔的袭击。'),
  'mayor': BotcRole('mayor', '镇长', 'townsfolk', '若黄昏时仅有 3 人存活且当天无人被处决，善良阵营直接获胜。'),
};

const List<String> kTownsfolkIds = [
  'washerwoman',
  'librarian',
  'investigator',
  'chef',
  'empath',
  'fortune_teller',
  'undertaker',
  'monk',
  'ravenkeeper',
  'virgin',
  'slayer',
  'soldier',
  'mayor',
];

const List<String> kOutsiderIds = ['butler', 'drunk', 'recluse', 'saint'];
const List<String> kMinionIds = ['poisoner', 'scarlet_woman', 'baron', 'spy'];

/// Base distribution of (Townsfolk, Outsiders, Minions, Demons) for 5..10 players.
(int, int, int, int) botcDistribution(int n, {bool hasBaron = false}) {
  final (int t, int o, int m) = switch (n) {
    5 => (3, 0, 1),
    6 => (3, 1, 1),
    7 => (5, 0, 1),
    8 => (5, 1, 1),
    9 => (5, 2, 1),
    _ => (7, 0, 2),
  };
  if (hasBaron) {
    final add = (4 - o).clamp(0, 2);
    return (t - add, o + add, m, 1);
  }
  return (t, o, m, 1);
}

class BloodClock extends GameEngine {
  final _ai = AiSlot();

  /// Actual role ID per seat (e.g. 'drunk' for the Drunk).
  late List<String> trueRole;

  /// Role ID shown to each seat (for 'drunk', this is a fake Townsfolk role; otherwise == trueRole).
  late List<String> shownRole;

  /// Alive status per seat.
  late List<bool> alive;

  /// Remaining Ghost Vote token per seat (true = still has ghost vote once dead).
  late List<bool> ghostVote;

  /// Current phase: 'night', 'day', 'vote', 'end'.
  String phase = 'night';

  /// Current day/night number (starts at Night 1 -> Day 1 -> Night 2 ...).
  int day = 1;

  /// Seat currently poisoned by Poisoner (until next dusk), or -1.
  int poisonedSeat = -1;

  /// Seat protected by Monk tonight, or -1.
  int monkProtected = -1;

  /// Butler's chosen master seat (per seat, -1 if none).
  late List<int> butlerMaster;

  /// Fortune Teller's Red Herring seat (a good player who registers as Demon to Fortune Teller).
  int redHerring = -1;

  /// Virgin passive ability already triggered?
  bool virginTriggered = false;

  /// Seats that have already used (or bluffed) the Slayer day shot.
  final Set<int> slayerUsed = {};

  /// Seat executed today (or yesterday during night), or -1.
  int executedLastDay = -1;

  /// Seats that died tonight.
  List<int> nightDeaths = [];

  /// Active night queue of `(seat, roleId)` waiting for player choice tonight.
  final List<(int, String)> nightQueue = [];

  /// Private night logs / clues per seat.
  late List<List<String>> privateNotes;

  /// Three not-in-play good roles given to the Demon as bluffs on Night 1.
  List<String> demonBluffs = [];

  /// Public town square log lines.
  final List<String> publicLog = [];

  /// Day chat / statements (`{'seat': s, 'day': d, 'text': t}`).
  final List<Map<String, dynamic>> dayChats = [];
  final Set<int> spokeToday = {};

  /// Nomination tracking for the current day.
  final Set<int> nominatedBy = {};
  final Set<int> nominatedTargets = {};
  final Set<int> dayPassed = {};

  /// Current vote state when `phase == 'vote'`.
  int nominator = -1;
  int nominee = -1;
  final Map<int, bool> votes = {};

  /// Player currently on the block (待处决) and their vote count.
  int onBlock = -1;
  int onBlockVotes = 0;

  /// Winner team ('good' or 'evil') and reason when `isOver`.
  String? winner;
  String winReason = '';
  bool _over = false;

  BloodClock(super.setup);

  @override
  bool get isOver => _over;

  bool isEvilSeat(int seat) {
    final r = kBotcRoles[trueRole[seat]];
    return r != null && r.isEvil;
  }

  bool isHealthy(int seat) => poisonedSeat != seat && trueRole[seat] != 'drunk';

  int get aliveCount => alive.where((a) => a).length;

  int get voteThreshold => (aliveCount + 1) ~/ 2;

  @override
  List<int>? get placings {
    if (!_over || winner == null) return null;
    final goodWon = winner == 'good';
    final winners = <int>[
      for (var s = 0; s < players; s++)
        if (isEvilSeat(s) != goodWon) s,
    ];
    return rankWinners(players, winners);
  }

  @override
  Set<int>? voiceListeners(int seat) {
    if (_over || phase != 'night') {
      // During the Day (and at game over), everyone hears everyone (dead players can speak in BotC!).
      return null;
    }
    if (seat < 0 || seat >= players) return null;
    // During Night, evil players share the evil night channel; good players only hear themselves.
    if (isEvilSeat(seat)) {
      return {for (var s = 0; s < players; s++) if (isEvilSeat(s)) s};
    }
    return {seat};
  }

  @override
  void start() {
    alive = List.filled(players, true);
    ghostVote = List.filled(players, true);
    butlerMaster = List.filled(players, -1);
    privateNotes = List.generate(players, (_) => <String>[]);

    // 1. Pick Minions first to check if Baron is in play.
    final (_, _, mCount, _) = botcDistribution(players);
    final minionsPool = shuffled(kMinionIds, rng);
    final chosenMinions = minionsPool.sublist(0, mCount);
    final hasBaron = chosenMinions.contains('baron');

    final (tCount, oCount, _, _) = botcDistribution(players, hasBaron: hasBaron);
    final outsidersPool = shuffled(kOutsiderIds, rng);
    final chosenOutsiders = outsidersPool.sublist(0, oCount);

    final townsfolkPool = shuffled(kTownsfolkIds, rng);
    final chosenTownsfolk = townsfolkPool.sublist(0, tCount);
    final unusedTownsfolk = townsfolkPool.sublist(tCount);

    final bag = shuffled(<String>[
      'imp',
      ...chosenMinions,
      ...chosenOutsiders,
      ...chosenTownsfolk,
    ], rng);

    trueRole = List.of(bag);
    shownRole = List.of(bag);

    // If Drunk is in play, show them an unused Townsfolk role!
    var unusedIdx = 0;
    for (var s = 0; s < players; s++) {
      if (trueRole[s] == 'drunk') {
        shownRole[s] = unusedTownsfolk[unusedIdx++];
      }
    }

    // Pick 3 unused good roles as Demon bluffs.
    final usedShown = shownRole.toSet();
    final bluffPool = <String>[
      ...kTownsfolkIds.where((id) => !usedShown.contains(id)),
      ...kOutsiderIds.where((id) => !usedShown.contains(id) && id != 'drunk'),
    ];
    demonBluffs = bluffPool.take(3).toList();

    // Choose Fortune Teller's Red Herring (any Good player).
    final goodSeats = [for (var s = 0; s < players; s++) if (!isEvilSeat(s)) s];
    redHerring = goodSeats.isNotEmpty ? goodSeats[rng.nextInt(goodSeats.length)] : 0;

    day = 1;
    _logPublic('【第 1 夜】暴风雨笼罩鸦木布拉夫，所有玩家请闭眼。');
    _beginNight();
  }

  void _logPublic(String msg) {
    publicLog.add(msg);
    if (publicLog.length > 60) publicLog.removeAt(0);
    host.log(msg);
  }

  void _addNote(int seat, String note) {
    privateNotes[seat].add(note);
  }

  /// Starts or restarts the night phase for the current `day` (Night `day`).
  void beginNightForTest() => _beginNight();

  void _beginNight() {
    phase = 'night';
    poisonedSeat = -1;
    monkProtected = -1;
    nightDeaths = [];
    nightQueue.clear();

    // Build active night choices in official Trouble Brewing order:
    // 1. Poisoner (every night)
    for (var s = 0; s < players; s++) {
      if (alive[s] && shownRole[s] == 'poisoner') {
        nightQueue.add((s, 'poisoner'));
      }
    }
    // 2. Monk (Night 2+)
    if (day >= 2) {
      for (var s = 0; s < players; s++) {
        if (alive[s] && shownRole[s] == 'monk') {
          nightQueue.add((s, 'monk'));
        }
      }
    }
    // 3. Imp (Night 2+)
    if (day >= 2) {
      for (var s = 0; s < players; s++) {
        if (alive[s] && shownRole[s] == 'imp') {
          nightQueue.add((s, 'imp'));
        }
      }
    }
    // 4. Butler (every night)
    for (var s = 0; s < players; s++) {
      if (alive[s] && shownRole[s] == 'butler') {
        nightQueue.add((s, 'butler'));
      }
    }
    // 5. Fortune Teller (every night)
    for (var s = 0; s < players; s++) {
      if (alive[s] && shownRole[s] == 'fortune_teller') {
        nightQueue.add((s, 'fortune_teller'));
      }
    }

    _advanceNightIfReady();
  }

  void _advanceNightIfReady() {
    // Remove any queued actor who died before their turn (unless ravenkeeper triggered by death).
    while (nightQueue.isNotEmpty) {
      final (seat, roleId) = nightQueue.first;
      if (!alive[seat] && roleId != 'ravenkeeper') {
        nightQueue.removeAt(0);
        continue;
      }
      return; // Wait for `seat` to act.
    }

    // All active night choices done -> generate passive night info and enter Day!
    _DeliverPassiveNightInfo();
    if (_checkGameOverAfterNight()) return;

    phase = 'day';
    spokeToday.clear();
    nominatedBy.clear();
    nominatedTargets.clear();
    dayPassed.clear();
    onBlock = -1;
    onBlockVotes = 0;
    nominator = -1;
    nominee = -1;
    votes.clear();
    executedLastDay = -1;

    if (day == 1) {
      _logPublic('【第 1 天】天亮了，平安夜无人死亡。请自由发言或发起提名。');
    } else if (nightDeaths.isEmpty) {
      _logPublic('【第 $day 天】天亮了，昨晚是平安夜，无人死亡！');
    } else {
      final names = nightDeaths.map(name).join('、');
      _logPublic('【第 $day 天】天亮了，昨晚 $names 惨遭杀害！');
    }
  }

  // ignore: non_constant_identifier_names
  void _DeliverPassiveNightInfo() {
    if (day == 1) {
      // Evil team recognition + Demon bluffs
      final evilSeats = [for (var s = 0; s < players; s++) if (isEvilSeat(s)) s];
      final impSeat = [for (var s = 0; s < players; s++) if (trueRole[s] == 'imp') s].firstOrNull ?? -1;
      final minionNames = [
        for (final s in evilSeats)
          if (s != impSeat) '${name(s)}(${kBotcRoles[trueRole[s]]?.name ?? trueRole[s]})',
      ];
      for (final s in evilSeats) {
        if (s == impSeat) {
          final bluffs = demonBluffs.map((r) => kBotcRoles[r]?.name ?? r).join('、');
          _addNote(s, '【首夜邪恶阵营】你的爪牙是：${minionNames.isEmpty ? "无" : minionNames.join("、")}。不在场的伪装身份：$bluffs。');
        } else {
          _addNote(s, '【首夜邪恶阵营】你的恶魔是：${impSeat >= 0 ? name(impSeat) : "未知"}。');
        }
      }

      // First-night info roles
      for (var s = 0; s < players; s++) {
        final sr = shownRole[s];
        final healthy = isHealthy(s);
        if (sr == 'washerwoman') {
          _giveWasherwomanInfo(s, healthy);
        } else if (sr == 'librarian') {
          _giveLibrarianInfo(s, healthy);
        } else if (sr == 'investigator') {
          _giveInvestigatorInfo(s, healthy);
        } else if (sr == 'chef') {
          _giveChefInfo(s, healthy);
        }
      }
    } else {
      // Undertaker (Night 2+ if someone was executed yesterday)
      if (executedLastDay >= 0) {
        for (var s = 0; s < players; s++) {
          if (alive[s] && shownRole[s] == 'undertaker') {
            final healthy = isHealthy(s);
            final trueR = trueRole[executedLastDay];
            final rId = healthy ? trueR : _randomOtherRole(trueR);
            final rName = kBotcRoles[rId]?.name ?? rId;
            _addNote(s, '【第 $day 夜·送葬者】昨天被处决的 ${name(executedLastDay)} 的身份是：$rName。');
          }
        }
      }
    }

    // Every night: Empath & Spy
    for (var s = 0; s < players; s++) {
      if (!alive[s]) continue;
      final sr = shownRole[s];
      if (sr == 'empath') {
        final healthy = isHealthy(s);
        final (left, right) = _livingNeighbours(s);
        var count = 0;
        if (left >= 0 && _registersAsEvil(left)) count++;
        if (right >= 0 && right != left && _registersAsEvil(right)) count++;
        if (!healthy) {
          count = (count + 1 + rng.nextInt(2)) % 3;
        }
        _addNote(s, '【第 $day 夜·共情者】你最近的两名存活邻居（${name(left)}、${name(right)}）中有 $count 名邪恶玩家。');
      } else if (trueRole[s] == 'spy' && isHealthy(s)) {
        final summary = [
          for (var i = 0; i < players; i++)
            '${name(i)}:${kBotcRoles[trueRole[i]]?.name ?? trueRole[i]}${alive[i] ? "" : "(亡)"}',
        ].join('，');
        _addNote(s, '【第 $day 夜·间谍魔典】$summary');
      }
    }
  }

  bool _registersAsEvil(int seat) {
    final r = trueRole[seat];
    if (r == 'recluse' && isHealthy(seat)) return true;
    if (r == 'spy' && isHealthy(seat)) return false;
    return isEvilSeat(seat);
  }

  bool _registersAsDemon(int seat) {
    final r = trueRole[seat];
    if (r == 'imp') return true;
    if (seat == redHerring) return true;
    if (r == 'recluse' && isHealthy(seat)) return true;
    return false;
  }

  (int, int) _livingNeighbours(int seat) {
    var l = -1;
    var r = -1;
    for (var d = 1; d < players; d++) {
      final cand = (seat - d + players) % players;
      if (alive[cand]) {
        l = cand;
        break;
      }
    }
    for (var d = 1; d < players; d++) {
      final cand = (seat + d) % players;
      if (alive[cand]) {
        r = cand;
        break;
      }
    }
    return (l, r);
  }

  void _giveWasherwomanInfo(int seat, bool healthy) {
    final others = [for (var i = 0; i < players; i++) if (i != seat) i];
    final tfSeats = [
      for (final i in others)
        if (kBotcRoles[trueRole[i]]?.team == 'townsfolk' || (trueRole[i] == 'spy' && isHealthy(i))) i,
    ];
    if (healthy && tfSeats.isNotEmpty) {
      final target = tfSeats[rng.nextInt(tfSeats.length)];
      final decoyPool = [for (final i in others) if (i != target) i];
      final decoy = decoyPool[rng.nextInt(decoyPool.length)];
      final pair = shuffled([target, decoy], rng);
      final roleId = trueRole[target] == 'spy' ? kTownsfolkIds[rng.nextInt(kTownsfolkIds.length)] : trueRole[target];
      final rName = kBotcRoles[roleId]?.name ?? roleId;
      _addNote(seat, '【首夜·洗衣妇】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
    } else {
      final pair = shuffled(others, rng).take(2).toList();
      final roleId = kTownsfolkIds[rng.nextInt(kTownsfolkIds.length)];
      final rName = kBotcRoles[roleId]?.name ?? roleId;
      _addNote(seat, '【首夜·洗衣妇】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
    }
  }

  void _giveLibrarianInfo(int seat, bool healthy) {
    final others = [for (var i = 0; i < players; i++) if (i != seat) i];
    final outSeats = [
      for (final i in others)
        if (kBotcRoles[trueRole[i]]?.team == 'outsider') i,
    ];
    if (healthy) {
      if (outSeats.isEmpty) {
        _addNote(seat, '【首夜·图书管理员】本局没有外来者在场（0 名外来者）。');
      } else {
        final target = outSeats[rng.nextInt(outSeats.length)];
        final decoyPool = [for (final i in others) if (i != target) i];
        final decoy = decoyPool[rng.nextInt(decoyPool.length)];
        final pair = shuffled([target, decoy], rng);
        final rName = kBotcRoles[trueRole[target]]?.name ?? trueRole[target];
        _addNote(seat, '【首夜·图书管理员】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
      }
    } else {
      final pair = shuffled(others, rng).take(2).toList();
      final roleId = kOutsiderIds[rng.nextInt(kOutsiderIds.length)];
      final rName = kBotcRoles[roleId]?.name ?? roleId;
      _addNote(seat, '【首夜·图书管理员】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
    }
  }

  void _giveInvestigatorInfo(int seat, bool healthy) {
    final others = [for (var i = 0; i < players; i++) if (i != seat) i];
    final minSeats = [
      for (final i in others)
        if (kBotcRoles[trueRole[i]]?.team == 'minion' || (trueRole[i] == 'recluse' && isHealthy(i))) i,
    ];
    if (healthy && minSeats.isNotEmpty) {
      final target = minSeats[rng.nextInt(minSeats.length)];
      final decoyPool = [for (final i in others) if (i != target) i];
      final decoy = decoyPool[rng.nextInt(decoyPool.length)];
      final pair = shuffled([target, decoy], rng);
      final roleId = trueRole[target] == 'recluse' ? kMinionIds[rng.nextInt(kMinionIds.length)] : trueRole[target];
      final rName = kBotcRoles[roleId]?.name ?? roleId;
      _addNote(seat, '【首夜·调查员】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
    } else {
      final pair = shuffled(others, rng).take(2).toList();
      final roleId = kMinionIds[rng.nextInt(kMinionIds.length)];
      final rName = kBotcRoles[roleId]?.name ?? roleId;
      _addNote(seat, '【首夜·调查员】${name(pair[0])} 与 ${name(pair[1])} 之中有一人是【$rName】。');
    }
  }

  void _giveChefInfo(int seat, bool healthy) {
    var pairs = 0;
    for (var i = 0; i < players; i++) {
      final j = (i + 1) % players;
      if (_registersAsEvil(i) && _registersAsEvil(j)) pairs++;
    }
    if (!healthy) {
      pairs = pairs == 0 ? 1 : 0;
    }
    _addNote(seat, '【首夜·厨师】场上共有 $pairs 对邻座的邪恶玩家。');
  }

  String _randomOtherRole(String avoid) {
    final all = kBotcRoles.keys.where((k) => k != avoid).toList();
    return all[rng.nextInt(all.length)];
  }

  bool _checkGameOverAfterNight() {
    final hasAliveImp = [for (var s = 0; s < players; s++) if (alive[s] && trueRole[s] == 'imp') s].isNotEmpty;
    if (!hasAliveImp) {
      _endGame('good', '恶魔已死亡，善良阵营获胜！');
      return true;
    }
    if (aliveCount <= 2) {
      _endGame('evil', '场上仅剩 $aliveCount 名玩家存活且恶魔仍在场，邪恶阵营获胜！');
      return true;
    }
    return false;
  }

  void _endGame(String team, String reason) {
    winner = team;
    winReason = reason;
    _over = true;
    phase = 'end';
    _logPublic('【游戏结束】$reason');
  }

  /// Checks if Scarlet Woman takes over as Imp when Imp dies.
  /// `aliveBeforeDeath` is the number of living players right before Imp died.
  bool _tryScarletWomanTakeover(int aliveBeforeDeath) {
    if (aliveBeforeDeath < 5) return false;
    for (var s = 0; s < players; s++) {
      if (alive[s] && trueRole[s] == 'scarlet_woman' && isHealthy(s)) {
        trueRole[s] = 'imp';
        shownRole[s] = 'imp';
        _addNote(s, '【红唇女郎触发】小恶魔已死亡且场上原本有 $aliveBeforeDeath 人存活，你已继任为新的【小恶魔】！');
        return true;
      }
    }
    return false;
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'night') {
      if (nightQueue.isEmpty) return const [];
      return [nightQueue.first.$1];
    }
    if (phase == 'vote') {
      return [
        for (var s = 0; s < players; s++)
          if (!votes.containsKey(s) && (alive[s] || ghostVote[s])) s,
      ];
    }
    if (phase == 'day') {
      return [
        for (var s = 0; s < players; s++)
          if (alive[s] && !dayPassed.contains(s)) s,
      ];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);

    if (phase == 'night') {
      if (nightQueue.isEmpty || nightQueue.first.$1 != seat) {
        throw GameError('当前未轮到你在夜晚行动');
      }
      if (type != 'night_act' && type != 'choose') {
        throw GameError('请完成夜晚技能选择');
      }
      final roleId = nightQueue.first.$2;
      _handleNightAction(seat, roleId, action);
      return;
    }

    if (phase == 'vote') {
      if (type != 'vote') throw GameError('当前正在进行公投表决');
      if (votes.containsKey(seat)) throw GameError('你已经投过票了');
      final yes = action['yes'] == true || action['vote'] == true || action['support'] == true;
      if (!alive[seat] && yes && !ghostVote[seat]) {
        throw GameError('你的死人票（幽灵票）已经使用过了');
      }
      // Butler check: if alive, true role is butler, healthy, and master already voted false
      if (yes && alive[seat] && trueRole[seat] == 'butler' && isHealthy(seat)) {
        final master = butlerMaster[seat];
        if (master >= 0 && votes[master] == false) {
          throw GameError('管家只能在主人投赞成票时投赞成票');
        }
      }
      votes[seat] = yes;
      // If this seat is someone's Butler master and voted false, flip an already-cast Butler yes vote to false.
      if (!yes) {
        for (var b = 0; b < players; b++) {
          if (alive[b] && trueRole[b] == 'butler' && isHealthy(b) && butlerMaster[b] == seat && votes[b] == true) {
            votes[b] = false;
          }
        }
      }
      if (waitingFor.isEmpty) {
        _resolveVote();
      }
      return;
    }

    if (phase == 'day') {
      switch (type) {
        case 'speak':
        case 'chat':
          final text = AiText.firstLine(asStr(action['text']), maxLen: 60);
          if (text.isEmpty) throw GameError('发言内容不能为空');
          spokeToday.add(seat);
          dayChats.add({'seat': seat, 'day': day, 'text': text});
          _logPublic('${name(seat)}：$text');
          return;

        case 'slayer':
          if (!alive[seat]) throw GameError('死亡玩家不能发动猎手技能');
          if (slayerUsed.contains(seat)) throw GameError('你本局已经使用过猎手技能了');
          final target = asInt(action['target']);
          if (target < 0 || target >= players || !alive[target]) {
            throw GameError('请选择一名存活玩家作为射击目标');
          }
          slayerUsed.add(seat);
          final hitsDemon = trueRole[seat] == 'slayer' &&
              isHealthy(seat) &&
              (trueRole[target] == 'imp' || (trueRole[target] == 'recluse' && isHealthy(target)));
          if (hitsDemon) {
            final aliveBefore = aliveCount;
            alive[target] = false;
            _logPublic('【猎手开枪】${name(seat)} 拔弩射向 ${name(target)}，${name(target)} 应声倒地身亡！');
            if (trueRole[target] == 'imp') {
              final replaced = _tryScarletWomanTakeover(aliveBefore);
              if (!replaced) {
                _endGame('good', '猎手 ${name(seat)} 当场射杀了恶魔 ${name(target)}，善良阵营获胜！');
                return;
              }
            }
            if (aliveCount <= 2) {
              _endGame('evil', '场上仅剩 $aliveCount 名玩家存活，邪恶阵营获胜！');
              return;
            }
          } else {
            _logPublic('【猎手开枪】${name(seat)} 宣称自己是猎手并射向 ${name(target)}，但无事发生。');
          }
          return;

        case 'nominate':
          if (!alive[seat]) throw GameError('死亡玩家不能发起提名');
          if (nominatedBy.contains(seat)) throw GameError('你今天已经发起过一次提名了');
          final target = asInt(action['target']);
          if (target < 0 || target >= players || !alive[target]) {
            throw GameError('只能提名存活的玩家');
          }
          if (nominatedTargets.contains(target)) {
            throw GameError('${name(target)} 今天已经被提名过了');
          }
          nominatedBy.add(seat);
          nominatedTargets.add(target);
          dayPassed.clear();
          _logPublic('【发起提名】${name(seat)} 提名处决 ${name(target)}！');

          // Check Virgin passive ability!
          if (trueRole[target] == 'virgin' && !virginTriggered) {
            virginTriggered = true;
            if (isHealthy(target) && kBotcRoles[trueRole[seat]]?.team == 'townsfolk') {
              _logPublic('【处女神迹】镇民 ${name(seat)} 提名了处女 ${name(target)}，${name(seat)} 被立即处决！');
              _executePlayer(seat);
              if (!_over) {
                day++;
                _logPublic('【第 $day 夜】黄昏降临，所有玩家请闭眼。');
                _beginNight();
              }
              return;
            }
          }

          phase = 'vote';
          nominator = seat;
          nominee = target;
          votes.clear();
          return;

        case 'skip_day':
          if (!alive[seat]) throw GameError('你已死亡，无需跳过白天');
          dayPassed.add(seat);
          if (waitingFor.isEmpty) {
            _endDay();
          }
          return;

        default:
          throw GameError('未知白天操作：$type');
      }
    }
  }

  void _handleNightAction(int seat, String roleId, Map<String, dynamic> action) {
    final healthy = isHealthy(seat);

    if (roleId == 'fortune_teller') {
      final list = asIntList(action['targets']);
      final t1 = list.isNotEmpty ? list[0] : asInt(action['target']);
      final t2 = list.length > 1 ? list[1] : asInt(action['target2']);
      if (t1 < 0 || t1 >= players || t2 < 0 || t2 >= players || t1 == t2) {
        throw GameError('占卜师必须选择两名不同的玩家');
      }
      var hasDemon = _registersAsDemon(t1) || _registersAsDemon(t2);
      if (!healthy) {
        hasDemon = !hasDemon;
      }
      _addNote(seat, '【第 $day 夜·占卜师】你查验了 ${name(t1)} 与 ${name(t2)}：${hasDemon ? "是（其中有恶魔）" : "否（均非恶魔）"}。');
      nightQueue.removeAt(0);
      _advanceNightIfReady();
      return;
    }

    final target = asInt(action['target']);
    if (target < 0 || target >= players) {
      throw GameError('请选择一名有效的目标玩家');
    }

    switch (roleId) {
      case 'poisoner':
        if (trueRole[seat] == 'poisoner' && healthy) {
          poisonedSeat = target;
        }
        _addNote(seat, '【第 $day 夜·投毒者】你对 ${name(target)} 下了毒。');
        break;

      case 'monk':
        if (target == seat) throw GameError('僧侣不能选择保护自己');
        if (trueRole[seat] == 'monk' && healthy) {
          monkProtected = target;
        }
        _addNote(seat, '【第 $day 夜·僧侣】你今晚守护了 ${name(target)}。');
        break;

      case 'imp':
        if (!alive[target]) throw GameError('请选择一名存活玩家');
        _addNote(seat, '【第 $day 夜·小恶魔】你今晚袭击了 ${name(target)}。');
        if (trueRole[seat] == 'imp' && healthy) {
          final protectedByMonk = monkProtected == target;
          final soldierSafe = trueRole[target] == 'soldier' && isHealthy(target);
          if (!protectedByMonk && !soldierSafe) {
            final aliveBefore = aliveCount;
            alive[target] = false;
            nightDeaths.add(target);
            if (target == seat) {
              // Imp starpass (自刀传位)!
              if (!_tryScarletWomanTakeover(aliveBefore)) {
                final livingMinions = [
                  for (var s = 0; s < players; s++)
                    if (alive[s] && kBotcRoles[trueRole[s]]?.team == 'minion') s,
                ];
                if (livingMinions.isNotEmpty) {
                  final newImp = livingMinions.first;
                  trueRole[newImp] = 'imp';
                  shownRole[newImp] = 'imp';
                  _addNote(newImp, '【恶魔传位】小恶魔自杀传位，你现在成为了新的【小恶魔】！');
                }
              }
            } else if (shownRole[target] == 'ravenkeeper') {
              // Ravenkeeper wakes up tonight to learn a player's role!
              nightQueue.insert(1, (target, 'ravenkeeper'));
            }
          }
        }
        break;

      case 'ravenkeeper':
        final rId = healthy ? trueRole[target] : _randomOtherRole(trueRole[target]);
        final rName = kBotcRoles[rId]?.name ?? rId;
        _addNote(seat, '【第 $day 夜·渡鸦守卫】你在临终前查验了 ${name(target)}，其身份是：【$rName】。');
        break;

      case 'butler':
        if (target == seat) throw GameError('管家不能选择自己为主人');
        butlerMaster[seat] = target;
        _addNote(seat, '【第 $day 夜·管家】你选择 ${name(target)} 作为明天的主人。');
        break;
    }

    nightQueue.removeAt(0);
    _advanceNightIfReady();
  }

  void _resolveVote() {
    // Enforce Butler constraint one final time when tallying
    for (var s = 0; s < players; s++) {
      if (alive[s] && trueRole[s] == 'butler' && isHealthy(s) && votes[s] == true) {
        final m = butlerMaster[s];
        if (m >= 0 && votes[m] != true) {
          votes[s] = false;
        }
      }
    }

    var yesCount = 0;
    final voters = <String>[];
    for (var s = 0; s < players; s++) {
      if (votes[s] == true) {
        yesCount++;
        voters.add(name(s));
        if (!alive[s]) {
          ghostVote[s] = false; // Spend Ghost Vote token!
        }
      }
    }

    final need = voteThreshold;
    if (yesCount >= need) {
      if (yesCount > onBlockVotes) {
        onBlock = nominee;
        onBlockVotes = yesCount;
        _logPublic('【投票结果】对 ${name(nominee)} 的提名获得 $yesCount 票（需 $need 票），${name(nominee)} 走上处决台！');
      } else if (yesCount == onBlockVotes && onBlock != -1) {
        onBlock = -1;
        _logPublic('【投票结果】${name(nominee)} 同样获得 $yesCount 票，平票导致处决台清空！');
      } else {
        _logPublic('【投票结果】${name(nominee)} 获得 $yesCount 票，未超过当前最高票（$onBlockVotes 票）。');
      }
    } else {
      _logPublic('【投票结果】对 ${name(nominee)} 的提名仅获 $yesCount 票（不足 $need 票），未通过。');
    }

    phase = 'day';
    nominator = -1;
    nominee = -1;
    votes.clear();
  }

  void _endDay() {
    if (onBlock >= 0 && alive[onBlock]) {
      _logPublic('【黄昏处决】${name(onBlock)} 以 $onBlockVotes 票被公投处决！');
      _executePlayer(onBlock);
      if (_over) return;
    } else {
      executedLastDay = -1;
      _logPublic('【黄昏降临】今天无人被处决。');
      // Check Mayor 3-player win condition!
      if (aliveCount == 3) {
        final hasHealthyMayor = [
          for (var s = 0; s < players; s++)
            if (alive[s] && trueRole[s] == 'mayor' && isHealthy(s)) s,
        ].isNotEmpty;
        if (hasHealthyMayor) {
          _endGame('good', '场上仅剩 3 人存活且无人被处决，镇长带领善良阵营获胜！');
          return;
        }
      }
    }

    if (day >= 12) {
      // Safety cap to prevent infinite stall
      _endGame('evil', '历经漫长黑夜小镇彻底沦陷，邪恶阵营获胜！');
      return;
    }

    day++;
    _logPublic('【第 $day 夜】夜幕降临，所有玩家请闭眼。');
    _beginNight();
  }

  void _executePlayer(int target) {
    final aliveBefore = aliveCount;
    alive[target] = false;
    executedLastDay = target;

    // 1. Check Saint execution!
    if (trueRole[target] == 'saint' && isHealthy(target)) {
      _endGame('evil', '圣徒 ${name(target)} 被公投处决，邪恶阵营立即获胜！');
      return;
    }

    // 2. Check Imp execution & Scarlet Woman takeover!
    if (trueRole[target] == 'imp') {
      final replaced = _tryScarletWomanTakeover(aliveBefore);
      if (!replaced) {
        _endGame('good', '恶魔 ${name(target)} 被成功处决，善良阵营获胜！');
        return;
      }
    }

    // 3. Check if <= 2 players remain alive with Demon still alive
    if (aliveCount <= 2) {
      _endGame('evil', '处决后场上仅剩 $aliveCount 名玩家存活，邪恶阵营获胜！');
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canSeeGrimoire = _over || (seat >= 0 && seat < players && trueRole[seat] == 'spy' && isHealthy(seat));
    final myShownRole = (seat >= 0 && seat < players) ? shownRole[seat] : null;
    final myRoleMeta = myShownRole != null ? kBotcRoles[myShownRole] : null;

    final isMyNightTurn = phase == 'night' && nightQueue.isNotEmpty && nightQueue.first.$1 == seat;
    final myNightRole = isMyNightTurn ? nightQueue.first.$2 : null;

    return {
      'phase': phase,
      'day': day,
      'alive': List.of(alive),
      'ghostVote': List.of(ghostVote),
      'aliveCount': aliveCount,
      'voteThreshold': voteThreshold,
      'onBlock': onBlock,
      'onBlockVotes': onBlockVotes,
      'nominator': nominator,
      'nominee': nominee,
      'votes': {for (final e in votes.entries) '${e.key}': e.value},
      'nominatedBy': nominatedBy.toList(),
      'nominatedTargets': nominatedTargets.toList(),
      'dayPassed': dayPassed.toList(),
      'slayerUsed': slayerUsed.toList(),
      'myRole': myShownRole,
      'myRoleName': myRoleMeta?.name,
      'myRoleTeam': myRoleMeta?.team,
      'myRoleDesc': myRoleMeta?.desc,
      'myNotes': (seat >= 0 && seat < players) ? List.of(privateNotes[seat]) : const <String>[],
      'myMaster': (seat >= 0 && seat < players) ? butlerMaster[seat] : -1,
      'isAwake': isMyNightTurn,
      'wakeRole': myNightRole,
      'grimoire': canSeeGrimoire
          ? [
              for (var s = 0; s < players; s++)
                {
                  'seat': s,
                  'trueRole': trueRole[s],
                  'trueRoleName': kBotcRoles[trueRole[s]]?.name ?? trueRole[s],
                  'shownRole': shownRole[s],
                  'team': kBotcRoles[trueRole[s]]?.team ?? 'townsfolk',
                  'poisoned': poisonedSeat == s,
                },
            ]
          : null,
      'dayChats': List.of(dayChats),
      'publicLog': List.of(publicLog),
      'winner': winner,
      'winReason': winReason,
      'result': _over ? winReason : null,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'night') {
      final roleId = nightQueue.first.$2;
      if (roleId == 'fortune_teller') {
        final cands = shuffled([for (var s = 0; s < players; s++) if (s != seat && alive[s]) s], rng);
        if (cands.length >= 2) {
          return {'type': 'night_act', 'targets': [cands[0], cands[1]]};
        }
        final allOther = [for (var s = 0; s < players; s++) if (s != seat) s];
        return {'type': 'night_act', 'targets': [seat, allOther.first]};
      }
      if (roleId == 'monk' || roleId == 'butler') {
        final others = [for (var s = 0; s < players; s++) if (s != seat && alive[s]) s];
        final pool = others.isNotEmpty ? others : [for (var s = 0; s < players; s++) if (s != seat) s];
        return {'type': 'night_act', 'target': pool[rng.nextInt(pool.length)]};
      }
      if (roleId == 'imp') {
        final goodAlive = [for (var s = 0; s < players; s++) if (alive[s] && !isEvilSeat(s)) s];
        final pool = goodAlive.isNotEmpty ? goodAlive : [for (var s = 0; s < players; s++) if (alive[s]) s];
        return {'type': 'night_act', 'target': pool[rng.nextInt(pool.length)]};
      }
      if (roleId == 'poisoner') {
        final goodAlive = [for (var s = 0; s < players; s++) if (alive[s] && !isEvilSeat(s)) s];
        final pool = goodAlive.isNotEmpty ? goodAlive : [for (var s = 0; s < players; s++) if (alive[s]) s];
        return {'type': 'night_act', 'target': pool[rng.nextInt(pool.length)]};
      }
      // ravenkeeper
      final pool = [for (var s = 0; s < players; s++) if (s != seat && alive[s]) s];
      final target = pool.isNotEmpty ? pool[rng.nextInt(pool.length)] : (seat + 1) % players;
      return {'type': 'night_act', 'target': target};
    }

    if (phase == 'vote') {
      if (!alive[seat]) {
        // Dead bots save their ghost vote until <= 4 players alive
        if (aliveCount <= 4 && ghostVote[seat] && nominee != seat) {
          return {'type': 'vote', 'yes': rng.nextBool()};
        }
        return {'type': 'vote', 'yes': false};
      }
      // Butler check: only vote yes if master hasn't voted false (and is voting yes)
      if (shownRole[seat] == 'butler') {
        final m = butlerMaster[seat];
        if (m >= 0 && votes[m] != true) {
          return {'type': 'vote', 'yes': false};
        }
      }
      if (nominee == seat) {
        return {'type': 'vote', 'yes': false};
      }
      final yes = rng.nextDouble() < 0.65;
      return {'type': 'vote', 'yes': yes};
    }

    if (phase == 'day') {
      // 1. Speak once per day
      if (!spokeToday.contains(seat)) {
        if (aiOn) {
          final myR = kBotcRoles[shownRole[seat]]?.name ?? shownRole[seat];
          final notes = privateNotes[seat].join('；');
          final r = _ai.poll(
            setup.ai!,
            'botc_speak:$day:$seat',
            () => AiRequest(
              system: '你在玩《血染钟楼·灾祸滋生》。请用简短的一句话（不超过35字）发表你的白天推理或身份声明。不要输出多余解释。',
              prompt: '你是${name(seat)}，你看到的身份是【$myR】。你的线索记录：${notes.isEmpty ? "暂无" : notes}。当前是第$day天。',
            ),
          );
          if (r.pending) return null;
          if (r.text != null) {
            final line = AiText.firstLine(r.text!, maxLen: 45);
            if (line.length >= 2) {
              return {'type': 'speak', 'text': line};
            }
          }
        }
        final myR = kBotcRoles[shownRole[seat]]?.name ?? '镇民';
        final notes = privateNotes[seat];
        final text = notes.isNotEmpty && ! shownRole[seat].contains('imp') && shownRole[seat] != 'poisoner'
            ? notes.last
            : '我是好人（跳$myR），建议今天仔细听取线索再投票。';
        return {'type': 'speak', 'text': AiText.firstLine(text, maxLen: 45)};
      }

      // 2. Slayer shot on Day 2+ if shownRole is slayer
      if (shownRole[seat] == 'slayer' && !slayerUsed.contains(seat) && day >= 2) {
        final targets = [for (var s = 0; s < players; s++) if (s != seat && alive[s]) s];
        if (targets.isNotEmpty) {
          return {'type': 'slayer', 'target': targets[rng.nextInt(targets.length)]};
        }
      }

      // 3. Nominate if nobody is on the block yet and fewer than 2 nominations happened today
      if (onBlock == -1 && !nominatedBy.contains(seat) && nominatedTargets.length < 2) {
        final targets = [
          for (var s = 0; s < players; s++)
            if (s != seat && alive[s] && !nominatedTargets.contains(s)) s,
        ];
        if (targets.isNotEmpty) {
          return {'type': 'nominate', 'target': targets[rng.nextInt(targets.length)]};
        }
      }

      return {'type': 'skip_day'};
    }

    return null;
  }
}
