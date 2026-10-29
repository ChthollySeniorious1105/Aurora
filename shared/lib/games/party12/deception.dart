import '../../src/engine.dart';

class SceneTileDef {
  final String title;
  final String type; // 'cause' | 'location' | 'scene'
  final List<String> options;
  const SceneTileDef(this.title, this.type, this.options);
}

class EvidenceCardDef {
  final String name;
  final List<int> tags; // semantic tags 0..5 for smart forensic/investigator bots
  const EvidenceCardDef(this.name, this.tags);
}

const List<EvidenceCardDef> kDeceptionMeansPool = [
  EvidenceCardDef('匕首', [1, 0]),
  EvidenceCardDef('毒药', [2, 1]),
  EvidenceCardDef('手枪', [1, 3]),
  EvidenceCardDef('绳索', [0, 0]),
  EvidenceCardDef('烛台', [3, 0]),
  EvidenceCardDef('扳手', [3, 2]),
  EvidenceCardDef('冰锥', [1, 1]),
  EvidenceCardDef('高尔夫球杆', [3, 3]),
  EvidenceCardDef('注射器', [2, 2]),
  EvidenceCardDef('枕头', [0, 0]),
  EvidenceCardDef('电击器', [5, 2]),
  EvidenceCardDef('剃刀', [1, 0]),
  EvidenceCardDef('花瓶', [3, 0]),
  EvidenceCardDef('哑铃', [3, 0]),
  EvidenceCardDef('斧头', [1, 3]),
  EvidenceCardDef('弩箭', [1, 3]),
  EvidenceCardDef('安眠药', [2, 0]),
  EvidenceCardDef('砒霜', [2, 1]),
  EvidenceCardDef('铁锤', [3, 2]),
  EvidenceCardDef('丝巾', [0, 0]),
  EvidenceCardDef('棒球棒', [3, 3]),
  EvidenceCardDef('美工刀', [1, 2]),
  EvidenceCardDef('碎酒瓶', [1, 4]),
  EvidenceCardDef('塑料袋', [0, 1]),
  EvidenceCardDef('吹箭', [2, 3]),
  EvidenceCardDef('链条', [0, 3]),
  EvidenceCardDef('剪刀', [1, 2]),
  EvidenceCardDef('毒蛇', [2, 3]),
  EvidenceCardDef('河豚毒素', [2, 1]),
  EvidenceCardDef('煤气', [0, 1]),
  EvidenceCardDef('高跟鞋', [3, 4]),
  EvidenceCardDef('消防斧', [1, 5]),
  EvidenceCardDef('手术刀', [1, 2]),
  EvidenceCardDef('钢丝', [0, 2]),
  EvidenceCardDef('砖块', [3, 3]),
  EvidenceCardDef('奖杯', [3, 2]),
];

const List<EvidenceCardDef> kDeceptionCluePool = [
  EvidenceCardDef('血迹', [1, 0]),
  EvidenceCardDef('指纹', [0, 2]),
  EvidenceCardDef('脚印', [3, 3]),
  EvidenceCardDef('情书', [0, 0]),
  EvidenceCardDef('遗嘱', [2, 2]),
  EvidenceCardDef('怀表', [3, 2]),
  EvidenceCardDef('戒指', [0, 4]),
  EvidenceCardDef('烟蒂', [4, 4]),
  EvidenceCardDef('纽扣', [1, 0]),
  EvidenceCardDef('头发', [0, 0]),
  EvidenceCardDef('借据', [2, 2]),
  EvidenceCardDef('车票', [5, 5]),
  EvidenceCardDef('钥匙', [0, 2]),
  EvidenceCardDef('日记', [0, 2]),
  EvidenceCardDef('照片', [0, 4]),
  EvidenceCardDef('手机', [5, 2]),
  EvidenceCardDef('口红', [4, 4]),
  EvidenceCardDef('打火机', [4, 1]),
  EvidenceCardDef('眼镜', [3, 2]),
  EvidenceCardDef('手套', [1, 3]),
  EvidenceCardDef('账本', [2, 2]),
  EvidenceCardDef('录音笔', [5, 2]),
  EvidenceCardDef('项链', [0, 4]),
  EvidenceCardDef('收据', [1, 5]),
  EvidenceCardDef('地图', [3, 3]),
  EvidenceCardDef('机票', [5, 5]),
  EvidenceCardDef('名片', [2, 4]),
  EvidenceCardDef('药瓶', [2, 1]),
  EvidenceCardDef('U盘', [5, 2]),
  EvidenceCardDef('碎布片', [1, 3]),
  EvidenceCardDef('泥土', [3, 3]),
  EvidenceCardDef('水杯', [2, 1]),
  EvidenceCardDef('耳环', [0, 4]),
  EvidenceCardDef('雨伞', [3, 5]),
  EvidenceCardDef('门票', [4, 5]),
  EvidenceCardDef('扑克牌', [4, 4]),
];

const SceneTileDef kCauseOfDeathTile = SceneTileDef(
  '死因',
  'cause',
  ['窒息', '失血过多', '中毒', '钝器重击', '病发/内伤', '机械伤害'],
);

const List<SceneTileDef> kLocationTiles = [
  SceneTileDef('案发地点 A', 'location', ['起居室', '卧室', '储藏室', '浴室', '厨房', '阳台']),
  SceneTileDef('案发地点 B', 'location', ['餐厅', '书房', '办公室', '实验室', '酒吧', '仓库']),
  SceneTileDef('案发地点 C', 'location', ['公园', '巷道', '停车场', '树林', '海滩', '建筑工地']),
];

const List<SceneTileDef> kSceneTileDeck = [
  SceneTileDef('作案动机', 'scene', ['仇恨报复', '谋财害命', '情杀纠葛', '灭口掩盖', '嫉妒竞争', '意外失手']),
  SceneTileDef('天气状况', 'scene', ['晴朗', '雷雨', '大雾', '寒冬', '闷热', '狂风']),
  SceneTileDef('尸体状态', 'scene', ['尚有余温', '已经僵硬', '衣冠不整', '面容扭曲', '平静安详', '残缺不全']),
  SceneTileDef('现场痕迹', 'scene', ['剧烈打斗', '精心伪装', '翻找财物', '匆忙逃离', '毫无痕迹', '血迹斑斑']),
  SceneTileDef('凶手特征', 'scene', ['身强力壮', '心思缜密', '左撇子', '熟人作案', '冷静果断', '惊慌失措']),
  SceneTileDef('作案时间', 'scene', ['黎明', '正午', '黄昏', '深夜', '节假日', '工作日']),
  SceneTileDef('持续时间', 'scene', ['瞬间毙命', '数分钟', '半小时', '数小时', '蓄谋数日', '长期折磨']),
  SceneTileDef('案发声响', 'scene', ['悄无声息', '尖叫呼救', '重物坠地', '玻璃破碎', '争吵打骂', '巨响爆炸']),
  SceneTileDef('死者身份', 'scene', ['富商名流', '普通职员', '科研学者', '江湖人士', '演艺明星', '公职人员']),
  SceneTileDef('社交关系', 'scene', ['亲属家人', '伴侣恋人', '同事上下级', '债权债务', '陌生路人', '昔日好友']),
];

class ActiveSceneTile {
  SceneTileDef def;
  int selected; // -1 if not yet placed, 0..5 when bullet placed
  ActiveSceneTile(this.def, [this.selected = -1]);

  Map<String, dynamic> toJson() => {
        'title': def.title,
        'type': def.type,
        'options': def.options,
        'selected': selected,
      };
}

class DeceptionGame extends GameEngine {
  late int forensicSeat;
  late int murdererSeat;
  int? accompliceSeat;
  int? witnessSeat;

  /// Role per seat: 'forensic' | 'murderer' | 'accomplice' | 'witness' | 'investigator'
  late List<String> roles;

  /// 4 Means cards and 4 Clue cards per seat (empty for forensicSeat).
  late List<List<String>> means;
  late List<List<String>> clues;

  String? keyMeans;
  String? keyClue;

  /// Active 6 tiles: [0] = Cause of Death, [1] = Location, [2..5] = 4 Scene Tiles.
  final List<ActiveSceneTile> tiles = [];
  final List<SceneTileDef> remainingSceneDeck = [];
  SceneTileDef? pendingNewTile;

  /// Police badge per seat (false for forensicSeat, true initially for all other seats).
  late List<bool> badge;

  /// Phase: 'night' | 'forensic' | 'investigate' | 'assassinate_witness' | 'end'
  String phase = 'night';
  int round = 1; // 1..3

  List<int> investigateOrder = [];
  int investigateIndex = 0;

  final List<Map<String, dynamic>> solveHistory = [];
  String? winnerTeam; // 'investigators' | 'murderer'
  int? solverSeat;
  int? assassinatedSeat;
  bool witnessKilled = false;

  DeceptionGame(super.setup);

  List<int> get suspects => [
        for (var s = 0; s < players; s++)
          if (s != forensicSeat) s
      ];

  int get currentInvestigator =>
      phase == 'investigate' && investigateIndex < investigateOrder.length
          ? investigateOrder[investigateIndex]
          : -1;

  @override
  void start() {
    final seats = shuffled([for (var i = 0; i < players; i++) i], rng);
    forensicSeat = seats[0];
    murdererSeat = seats[1];
    final useSpecial = players >= 6 && setup.opt<bool>('specialRoles', true);
    accompliceSeat = useSpecial ? seats[2] : null;
    witnessSeat = useSpecial ? seats[3] : null;

    roles = List.filled(players, 'investigator');
    roles[forensicSeat] = 'forensic';
    roles[murdererSeat] = 'murderer';
    if (accompliceSeat != null) roles[accompliceSeat!] = 'accomplice';
    if (witnessSeat != null) roles[witnessSeat!] = 'witness';

    final shuffledMeans = shuffled(kDeceptionMeansPool, rng);
    final shuffledClues = shuffled(kDeceptionCluePool, rng);
    means = List.generate(players, (_) => <String>[]);
    clues = List.generate(players, (_) => <String>[]);

    var mIdx = 0;
    var cIdx = 0;
    for (var s = 0; s < players; s++) {
      if (s == forensicSeat) continue;
      means[s] = [for (var i = 0; i < 4; i++) shuffledMeans[mIdx++].name];
      clues[s] = [for (var i = 0; i < 4; i++) shuffledClues[cIdx++].name];
    }

    tiles.clear();
    tiles.add(ActiveSceneTile(kCauseOfDeathTile));
    final locs = shuffled(kLocationTiles, rng);
    tiles.add(ActiveSceneTile(locs.first));
    remainingSceneDeck
      ..clear()
      ..addAll(shuffled(kSceneTileDeck, rng));
    for (var i = 0; i < 4; i++) {
      tiles.add(ActiveSceneTile(remainingSceneDeck.removeLast()));
    }
    pendingNewTile = null;

    badge = [for (var s = 0; s < players; s++) s != forensicSeat];
    phase = 'night';
    round = 1;
    investigateOrder = [
      for (var i = 1; i < players; i++) (forensicSeat + i) % players
    ];
    investigateIndex = 0;
    solveHistory.clear();
    winnerTeam = null;
    solverSeat = null;
    assassinatedSeat = null;
    witnessKilled = false;

    host.log('犯罪现场开始！${name(forensicSeat)} 担任法医，请凶手在夜晚秘密选择凶器与核心物证。');
  }

  @override
  bool get isOver => phase == 'end';

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    switch (phase) {
      case 'night':
        return [murdererSeat];
      case 'forensic':
        return [forensicSeat];
      case 'investigate':
        return currentInvestigator >= 0 ? [currentInvestigator] : const [];
      case 'assassinate_witness':
        return [murdererSeat];
      default:
        return const [];
    }
  }

  @override
  Set<int>? voiceListeners(int seat) {
    if (isOver) return null;
    if (phase == 'night') return {seat};
    if (seat == forensicSeat) return {forensicSeat}; // Forensic Scientist cannot speak
    return null;
  }

  String _resolveCard(List<String> pool, Object? raw, String label) {
    if (raw is String && pool.contains(raw)) return raw;
    final idx = asInt(raw, -1);
    if (idx >= 0 && idx < pool.length) return pool[idx];
    throw GameError('无效的$label选择');
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('游戏已结束');
    if (!waitingFor.contains(seat)) throw GameError('当前不是你的行动阶段');

    final type = asStr(action['type']);

    if (phase == 'night') {
      if (type != 'commit' && type != 'select' && type != 'choose') {
        throw GameError('夜晚阶段请选择作案凶器与物证');
      }
      final m = _resolveCard(means[murdererSeat], action['means'], '凶器');
      final c = _resolveCard(clues[murdererSeat], action['clue'], '核心物证');
      keyMeans = m;
      keyClue = c;
      phase = 'forensic';
      round = 1;
      host.log('凶手已完成作案布置，进入第 1 轮法医取证阶段。');
      return;
    }

    if (phase == 'forensic') {
      if (round == 1) {
        if (type == 'bullet') {
          final tIdx = asInt(action['tile'], -1);
          final oIdx = asInt(action['option'], -1);
          if (tIdx < 0 || tIdx >= tiles.length) throw GameError('无效的场景板块');
          if (oIdx < 0 || oIdx >= tiles[tIdx].def.options.length) {
            throw GameError('无效的标记选项');
          }
          tiles[tIdx].selected = oIdx;
          if (tiles.every((t) => t.selected >= 0) && asBool(action['autoConfirm'])) {
            _startInvestigatePhase();
          }
          return;
        }
        if (type == 'confirm_forensic') {
          if (tiles.any((t) => t.selected < 0)) {
            throw GameError('请先在所有 6 个现场板块上放置子弹标记');
          }
          _startInvestigatePhase();
          return;
        }
        if (type == 'forensic' || type == 'place_bullets' || type == 'clues') {
          final bullets = asIntList(action['bullets']);
          if (bullets.length != tiles.length) {
            throw GameError('需要为全部 ${tiles.length} 个板块指定子弹位置');
          }
          for (var i = 0; i < tiles.length; i++) {
            final b = bullets[i];
            if (b < 0 || b >= tiles[i].def.options.length) {
              throw GameError('板块 $i 的选项越界');
            }
            tiles[i].selected = b;
          }
          _startInvestigatePhase();
          return;
        }
        throw GameError('法医请放置子弹标记');
      } else {
        // Round 2 or 3: replace one of scene tiles 2..5 with pendingNewTile and set bullet
        if (type == 'forensic' || type == 'replace_tile' || type == 'clues') {
          final replaceIdx = asInt(action['replace'] ?? action['tile'], -1);
          final optIdx = asInt(action['option'], -1);
          if (replaceIdx < 2 || replaceIdx >= tiles.length) {
            throw GameError('只能替换 2..5 号现场板块');
          }
          if (optIdx < 0 || optIdx >= 6) {
            throw GameError('无效的子弹标记选项');
          }
          if (pendingNewTile != null) {
            tiles[replaceIdx] = ActiveSceneTile(pendingNewTile!, optIdx);
            pendingNewTile = null;
          } else {
            tiles[replaceIdx].selected = optIdx;
          }
          _startInvestigatePhase();
          return;
        }
        throw GameError('法医请替换一块现场板块并放置子弹标记');
      }
    }

    if (phase == 'investigate') {
      if (type == 'pass') {
        host.log('${name(seat)} 结束发言（保留警徽）。');
        _advanceInvestigation();
        return;
      }
      if (type == 'solve') {
        if (!badge[seat]) throw GameError('你的警徽已消耗，无法再次破案');
        final suspect = asInt(action['suspect'], -1);
        if (suspect < 0 || suspect >= players || suspect == forensicSeat) {
          throw GameError('只能指认非医检官的嫌疑人');
        }
        final m = _resolveCard(means[suspect], action['means'], '凶器');
        final c = _resolveCard(clues[suspect], action['clue'], '核心物证');

        badge[seat] = false;
        final correct = suspect == murdererSeat && m == keyMeans && c == keyClue;
        solveHistory.add({
          'round': round,
          'seat': seat,
          'suspect': suspect,
          'means': m,
          'clue': c,
          'correct': correct,
        });

        if (correct) {
          solverSeat = seat;
          host.log('${name(seat)} 破案成功！指认 ${name(suspect)} 使用【$m】留下【$c】完全正确！');
          if (witnessSeat != null) {
            phase = 'assassinate_witness';
            host.log('凶手获得最后反扑机会：请找出并暗杀目击者！');
          } else {
            winnerTeam = 'investigators';
            phase = 'end';
            host.log('刑警阵营与法医获胜！');
          }
          return;
        } else {
          host.log('${name(seat)} 指认 ${name(suspect)}（【$m】+【$c】）—— 法医摇头：指认错误！');
          if (suspects.every((s) => !badge[s])) {
            winnerTeam = 'murderer';
            phase = 'end';
            host.log('所有警徽均已耗尽，凶手成功逃脱！凶手阵营获胜！');
            return;
          }
          _advanceInvestigation();
          return;
        }
      }
      throw GameError('调查阶段请选择发言跳过(pass)或消耗警徽破案(solve)');
    }

    if (phase == 'assassinate_witness') {
      if (type != 'assassinate' && type != 'assassinate_witness') {
        throw GameError('请选择要暗杀的目击者目标');
      }
      final target = asInt(action['target'], -1);
      if (target < 0 ||
          target >= players ||
          target == forensicSeat ||
          target == murdererSeat ||
          target == accompliceSeat) {
        throw GameError('请选择一名好人阵营的调查员作为暗杀目标');
      }
      assassinatedSeat = target;
      if (target == witnessSeat) {
        witnessKilled = true;
        winnerTeam = 'murderer';
        phase = 'end';
        host.log('凶手 ${name(murdererSeat)} 成功识破并暗杀了目击者 ${name(target)}！凶手与帮凶反败为胜！');
      } else {
        witnessKilled = false;
        winnerTeam = 'investigators';
        phase = 'end';
        host.log('凶手 ${name(murdererSeat)} 暗杀了 ${name(target)}，但真正的目击者是 ${name(witnessSeat!)}！刑警阵营获胜！');
      }
      return;
    }
  }

  void _startInvestigatePhase() {
    phase = 'investigate';
    investigateIndex = 0;
    host.log('第 $round 轮法医线索已公布，进入刑警发言与破案阶段。');
  }

  void _advanceInvestigation() {
    investigateIndex++;
    if (investigateIndex < investigateOrder.length) return;
    if (round < 3) {
      round++;
      phase = 'forensic';
      pendingNewTile = remainingSceneDeck.isNotEmpty ? remainingSceneDeck.removeLast() : null;
      host.log('进入第 $round 轮法医换板与取证阶段。');
    } else {
      winnerTeam = 'murderer';
      phase = 'end';
      host.log('3 轮调查结束仍未破案，凶手成功逍遥法外！凶手阵营获胜！');
    }
  }

  /// Semantic affinity between a card name and a scene tile option index (0..5).
  int _cardTileMatchScore(String cardName, int tileIdx, int optIdx) {
    for (final d in kDeceptionMeansPool) {
      if (d.name == cardName) {
        final target = d.tags[tileIdx % d.tags.length];
        return target == optIdx ? 3 : ((target - optIdx).abs() == 1 ? 1 : 0);
      }
    }
    for (final d in kDeceptionCluePool) {
      if (d.name == cardName) {
        final target = d.tags[tileIdx % d.tags.length];
        return target == optIdx ? 3 : ((target - optIdx).abs() == 1 ? 1 : 0);
      }
    }
    return (cardName.hashCode.abs() + tileIdx * 7) % 6 == optIdx ? 2 : 0;
  }

  int _bestOptionForSolution(SceneTileDef tileDef, int tileIdx) {
    final m = keyMeans ?? '';
    final c = keyClue ?? '';
    var bestOpt = 0;
    var bestScore = -1;
    for (var o = 0; o < tileDef.options.length; o++) {
      final score = _cardTileMatchScore(m, tileIdx, o) + _cardTileMatchScore(c, tileIdx, o);
      if (score > bestScore) {
        bestScore = score;
        bestOpt = o;
      }
    }
    return bestOpt;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'night') {
      final mIdx = rng.nextInt(means[seat].length);
      final cIdx = rng.nextInt(clues[seat].length);
      return {'type': 'commit', 'means': means[seat][mIdx], 'clue': clues[seat][cIdx]};
    }

    if (phase == 'forensic') {
      if (round == 1) {
        final bullets = <int>[];
        for (var i = 0; i < tiles.length; i++) {
          if (botLevel == 0 && rng.nextBool()) {
            bullets.add(rng.nextInt(6));
          } else {
            bullets.add(_bestOptionForSolution(tiles[i].def, i));
          }
        }
        return {'type': 'forensic', 'bullets': bullets};
      } else {
        final replaceIdx = 2 + (round % 4);
        final def = pendingNewTile ?? tiles[replaceIdx].def;
        final opt = _bestOptionForSolution(def, replaceIdx);
        return {'type': 'forensic', 'replace': replaceIdx, 'option': opt};
      }
    }

    if (phase == 'investigate') {
      if (!badge[seat]) return {'type': 'pass'};
      // Murderer or Accomplice rarely wastes badge unless round 3 bluff
      if (seat == murdererSeat || seat == accompliceSeat) {
        if (round == 3 && botLevel >= 1 && rng.nextDouble() < 0.25) {
          final others = suspects.where((s) => s != murdererSeat && s != seat).toList();
          if (others.isNotEmpty) {
            final target = others[rng.nextInt(others.length)];
            return {
              'type': 'solve',
              'suspect': target,
              'means': means[target][rng.nextInt(means[target].length)],
              'clue': clues[target][rng.nextInt(clues[target].length)],
            };
          }
        }
        return {'type': 'pass'};
      }

      // Good team investigator / witness:
      // Attempt to solve in Round 3, or in Round 2 with some probability
      final shouldAttempt = round == 3 || (round == 2 && rng.nextDouble() < 0.45);
      if (!shouldAttempt) return {'type': 'pass'};

      final triedTriples = <String>{
        for (final h in solveHistory) '${h['suspect']}|${h['means']}|${h['clue']}'
      };

      // Candidate suspects (Witness knows murderer is in [murdererSeat, accompliceSeat])
      List<int> candSuspects;
      if (seat == witnessSeat) {
        candSuspects = [
          murdererSeat,
          if (accompliceSeat != null) accompliceSeat!,
        ];
      } else {
        candSuspects = suspects.where((s) => s != seat).toList();
        if (candSuspects.isEmpty) candSuspects = suspects;
      }

      int bestSuspect = candSuspects.first;
      String bestMeans = means[bestSuspect].first;
      String bestClue = clues[bestSuspect].first;
      int bestTotal = -999;

      for (final s in candSuspects) {
        for (final m in means[s]) {
          for (final c in clues[s]) {
            if (triedTriples.contains('$s|$m|$c')) continue;
            var score = 0;
            for (var t = 0; t < tiles.length; t++) {
              final sel = tiles[t].selected;
              if (sel >= 0) {
                score += _cardTileMatchScore(m, t, sel) + _cardTileMatchScore(c, t, sel);
              }
            }
            if (botLevel == 0) {
              score = rng.nextInt(20);
            } else if (botLevel == 1) {
              score += rng.nextInt(4);
            }
            if (score > bestTotal) {
              bestTotal = score;
              bestSuspect = s;
              bestMeans = m;
              bestClue = c;
            }
          }
        }
      }
      return {
        'type': 'solve',
        'suspect': bestSuspect,
        'means': bestMeans,
        'clue': bestClue,
      };
    }

    if (phase == 'assassinate_witness') {
      final candidates = suspects
          .where((s) => s != murdererSeat && s != accompliceSeat)
          .toList();
      if (botLevel >= 2 && solverSeat != null && candidates.contains(solverSeat)) {
        return {'type': 'assassinate', 'target': solverSeat};
      }
      final target = candidates[rng.nextInt(candidates.length)];
      return {'type': 'assassinate', 'target': target};
    }

    return null;
  }

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final evilTeam = <int>{
      murdererSeat,
      if (accompliceSeat != null) accompliceSeat!,
    };
    if (winnerTeam == 'murderer') {
      return rankWinners(players, evilTeam);
    } else {
      final goodTeam = [
        for (var s = 0; s < players; s++)
          if (!evilTeam.contains(s)) s
      ];
      return rankWinners(players, goodTeam);
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canSeeSolution = isOver ||
        seat == forensicSeat ||
        seat == murdererSeat ||
        (accompliceSeat != null && seat == accompliceSeat);
    final canSeeEvilSeats = canSeeSolution || (witnessSeat != null && seat == witnessSeat);

    final witnessSuspects = <int>[
      murdererSeat,
      if (accompliceSeat != null) accompliceSeat!,
    ]..sort();

    return {
      'phase': phase,
      'round': round,
      'forensicSeat': forensicSeat,
      'myRole': seat >= 0 && seat < players ? roles[seat] : 'spectator',
      'roles': isOver ? roles : null,
      'murdererSeat': canSeeSolution ? murdererSeat : null,
      'accompliceSeat': canSeeSolution ? accompliceSeat : null,
      'witnessSeat': (isOver || seat == witnessSeat) ? witnessSeat : null,
      'witnessSuspects': canSeeEvilSeats ? witnessSuspects : null,
      'keyMeans': canSeeSolution ? keyMeans : null,
      'keyClue': canSeeSolution ? keyClue : null,
      'means': means,
      'clues': clues,
      'tiles': [for (final t in tiles) t.toJson()],
      'pendingNewTile': (seat == forensicSeat && pendingNewTile != null)
          ? {
              'title': pendingNewTile!.title,
              'type': pendingNewTile!.type,
              'options': pendingNewTile!.options,
            }
          : null,
      'badge': badge,
      'currentInvestigator': currentInvestigator,
      'solveHistory': solveHistory,
      'winnerTeam': winnerTeam,
      'solverSeat': solverSeat,
      'assassinatedSeat': assassinatedSeat,
      'witnessKilled': witnessKilled,
      'waitingFor': waitingFor,
    };
  }
}
