import '../../src/engine.dart';

class SimiloCharacter {
  final int id;
  final String name;
  final String realm; // 神话 / 历史 / 童话 / 科幻
  final String role; // 君王 / 智者 / 勇者 / 奇兽
  final String era; // 远古 / 中世 / 近现代 / 未来
  final int power;
  final String emoji;

  const SimiloCharacter({
    required this.id,
    required this.name,
    required this.realm,
    required this.role,
    required this.era,
    required this.power,
    required this.emoji,
  });

  Map<String, dynamic> toJson({bool eliminated = false}) => {
        'id': id,
        'name': name,
        'realm': realm,
        'role': role,
        'era': era,
        'power': power,
        'emoji': emoji,
        'eliminated': eliminated,
      };
}

const List<SimiloCharacter> kSimiloDeck = [
  SimiloCharacter(id: 1, name: '宙斯', realm: '神话', role: '君王', era: '远古', power: 9, emoji: '⚡'),
  SimiloCharacter(id: 2, name: '雅典娜', realm: '神话', role: '智者', era: '远古', power: 8, emoji: '🦉'),
  SimiloCharacter(id: 3, name: '孙悟空', realm: '神话', role: '勇者', era: '远古', power: 9, emoji: '🐒'),
  SimiloCharacter(id: 4, name: '九尾狐', realm: '神话', role: '奇兽', era: '远古', power: 7, emoji: '🦊'),
  SimiloCharacter(id: 5, name: '阿努比斯', realm: '神话', role: '智者', era: '远古', power: 8, emoji: '🐺'),
  SimiloCharacter(id: 6, name: '波塞冬', realm: '神话', role: '君王', era: '远古', power: 9, emoji: '🔱'),
  SimiloCharacter(id: 7, name: '女武神', realm: '神话', role: '勇者', era: '中世', power: 8, emoji: '🛡️'),
  SimiloCharacter(id: 8, name: '不死凤凰', realm: '神话', role: '奇兽', era: '远古', power: 8, emoji: '🔥'),
  SimiloCharacter(id: 9, name: '秦始皇', realm: '历史', role: '君王', era: '远古', power: 9, emoji: '👑'),
  SimiloCharacter(id: 10, name: '诸葛亮', realm: '历史', role: '智者', era: '中世', power: 8, emoji: '🪶'),
  SimiloCharacter(id: 11, name: '圣女贞德', realm: '历史', role: '勇者', era: '中世', power: 7, emoji: '⚔️'),
  SimiloCharacter(id: 12, name: '达芬奇', realm: '历史', role: '智者', era: '中世', power: 6, emoji: '🎨'),
  SimiloCharacter(id: 13, name: '亚历山大', realm: '历史', role: '君王', era: '远古', power: 8, emoji: '🐎'),
  SimiloCharacter(id: 14, name: '花木兰', realm: '历史', role: '勇者', era: '中世', power: 7, emoji: '🏹'),
  SimiloCharacter(id: 15, name: '爱因斯坦', realm: '历史', role: '智者', era: '近现代', power: 6, emoji: '🧪'),
  SimiloCharacter(id: 16, name: '汉尼拔战象', realm: '历史', role: '奇兽', era: '远古', power: 7, emoji: '🐘'),
  SimiloCharacter(id: 17, name: '冰雪女王', realm: '童话', role: '君王', era: '中世', power: 8, emoji: '❄️'),
  SimiloCharacter(id: 18, name: '梅林法师', realm: '童话', role: '智者', era: '中世', power: 8, emoji: '🧙'),
  SimiloCharacter(id: 19, name: '小红帽', realm: '童话', role: '勇者', era: '中世', power: 4, emoji: '🧺'),
  SimiloCharacter(id: 20, name: '柴郡猫', realm: '童话', role: '奇兽', era: '近现代', power: 5, emoji: '😼'),
  SimiloCharacter(id: 21, name: '亚瑟王', realm: '童话', role: '君王', era: '中世', power: 8, emoji: '🗡️'),
  SimiloCharacter(id: 22, name: '穿靴子的猫', realm: '童话', role: '勇者', era: '中世', power: 6, emoji: '👢'),
  SimiloCharacter(id: 23, name: '仙女教母', realm: '童话', role: '智者', era: '中世', power: 7, emoji: '✨'),
  SimiloCharacter(id: 24, name: '巨龙史矛革', realm: '童话', role: '奇兽', era: '远古', power: 9, emoji: '🐉'),
  SimiloCharacter(id: 25, name: '星际女皇', realm: '科幻', role: '君王', era: '未来', power: 9, emoji: '🌌'),
  SimiloCharacter(id: 26, name: '量子智脑', realm: '科幻', role: '智者', era: '未来', power: 8, emoji: '🤖'),
  SimiloCharacter(id: 27, name: '机甲游侠', realm: '科幻', role: '勇者', era: '未来', power: 8, emoji: '🚀'),
  SimiloCharacter(id: 28, name: '虚空利维坦', realm: '科幻', role: '奇兽', era: '未来', power: 9, emoji: '🦑'),
  SimiloCharacter(id: 29, name: '赛博黑客', realm: '科幻', role: '智者', era: '未来', power: 6, emoji: '💻'),
  SimiloCharacter(id: 30, name: '银河铁卫', realm: '科幻', role: '勇者', era: '未来', power: 7, emoji: '🛸'),
];

const List<int> kSimiloEliminateQuota = [1, 2, 3, 4, 1];

class SimiloGame extends GameEngine {
  SimiloGame(super.setup);

  late List<SimiloCharacter> grid;
  late List<bool> eliminated;
  late int _secretTarget;
  late List<SimiloCharacter> _deck;
  late List<SimiloCharacter> clueHand;

  final List<Map<String, dynamic>> clues = [];
  final List<Map<String, dynamic>> eliminationLog = [];

  int round = 0; // 0..4
  String phase = 'clue'; // 'clue' | 'eliminate'
  int quotaLeft = 1;

  bool _over = false;
  bool won = false;
  String resultText = '';
  List<int>? _placings;

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _placings;

  @override
  void start() {
    final pool = shuffled(kSimiloDeck, rng);
    grid = pool.sublist(0, 12);
    eliminated = List<bool>.filled(12, false);
    _secretTarget = rng.nextInt(12);
    clueHand = pool.sublist(12, 17);
    _deck = pool.sublist(17);

    clues.clear();
    eliminationLog.clear();
    round = 0;
    phase = 'clue';
    quotaLeft = kSimiloEliminateQuota[0];
    _over = false;
    won = false;
    resultText = '';
    _placings = null;

    host.log('相似物语 Similo 开始！${name(0)} 担任线索人，其余玩家合作推理 12 位角色中的秘密目标！');
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'clue') return const [0];
    if (phase == 'eliminate') {
      return [for (var s = 1; s < players; s++) s];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    final type = asStr(action['type']);

    if (phase == 'clue') {
      if (seat != 0) throw GameError('等待线索人出牌提示');
      if (type != 'clue') throw GameError('线索人必须执行 clue 操作');
      final idx = asInt(action['cardIdx'], -1);
      if (idx < 0 || idx >= clueHand.length) {
        throw GameError('无效的手牌索引 ($idx)');
      }
      if (action['similar'] is! bool) {
        throw GameError('必须指定 similar (true=竖放相似 / false=横放不同)');
      }
      final similar = asBool(action['similar']);
      final card = clueHand.removeAt(idx);
      if (_deck.isNotEmpty) {
        clueHand.add(_deck.removeLast());
      }

      clues.add({
        'round': round + 1,
        'card': card.toJson(),
        'similar': similar,
      });

      quotaLeft = kSimiloEliminateQuota[round];
      phase = 'eliminate';
      host.log('第 ${round + 1} 轮：线索人打出【${card.name}】（${card.realm}·${card.role}·${card.era}），宣告与秘密目标【${similar ? "相似（竖放）" : "不同（横放）"}】！请猜词人排除 $quotaLeft 张角色。');
      return;
    }

    if (phase == 'eliminate') {
      if (seat <= 0 || seat >= players) {
        throw GameError('只有猜词人可以排除嫌疑角色');
      }
      if (type != 'eliminate') {
        throw GameError('请执行 eliminate 操作');
      }
      final slot = asInt(action['slot'], -1);
      if (slot < 0 || slot >= 12) {
        throw GameError('无效的角色格位 ($slot)');
      }
      if (eliminated[slot]) {
        throw GameError('该角色已被排除');
      }

      eliminated[slot] = true;
      quotaLeft--;
      final ch = grid[slot];
      eliminationLog.add({
        'round': round + 1,
        'seat': seat,
        'slot': slot,
        'character': ch.toJson(eliminated: true),
        'wasTarget': slot == _secretTarget,
      });

      if (slot == _secretTarget) {
        _finish(false, '${name(seat)} 误排除了秘密目标【${ch.name}】，全员合作失败！');
        return;
      }

      host.log('${name(seat)} 安全排除了【${ch.name}】！（本轮还需排除 $quotaLeft 张）');

      if (quotaLeft <= 0) {
        if (round >= 4) {
          final targetChar = grid[_secretTarget];
          _finish(true, '历经5轮成功锁定唯一真身【${targetChar.name}】，全员合作获胜！');
          return;
        }
        round++;
        phase = 'clue';
        quotaLeft = kSimiloEliminateQuota[round];
      }
      return;
    }

    throw GameError('未知阶段或操作');
  }

  void _finish(bool isVictory, String reason) {
    _over = true;
    won = isVictory;
    resultText = reason;
    _placings = List<int>.filled(players, 1);
    host.log('相似物语结束：$reason');
  }

  static int _sharedTraits(SimiloCharacter a, SimiloCharacter b) {
    var count = 0;
    if (a.realm == b.realm) count += 2;
    if (a.role == b.role) count += 2;
    if (a.era == b.era) count += 1;
    if ((a.power - b.power).abs() <= 1) count += 1;
    return count;
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (_over || !waitingFor.contains(seat)) return null;

    if (phase == 'clue' && seat == 0) {
      final target = grid[_secretTarget];
      var bestIdx = 0;
      var bestSimilar = true;
      var bestScore = -999;

      for (var i = 0; i < clueHand.length; i++) {
        final c = clueHand[i];
        final shared = _sharedTraits(c, target);
        final sim = shared >= 2;
        final score = sim ? shared * 3 : (6 - shared) * 2;
        if (score > bestScore) {
          bestScore = score;
          bestIdx = i;
          bestSimilar = sim;
        }
      }
      return {
        'type': 'clue',
        'cardIdx': bestIdx,
        'similar': bestSimilar,
      };
    }

    if (phase == 'eliminate' && seat > 0) {
      // Guesser bot NEVER accesses _secretTarget; it evaluates remaining grid slots using public clues!
      final candidates = <int>[
        for (var i = 0; i < 12; i++)
          if (!eliminated[i]) i,
      ];
      if (candidates.isEmpty) return null;

      if (botLevel == 0) {
        return {'type': 'eliminate', 'slot': candidates[rng.nextInt(candidates.length)]};
      }

      int compatibility(SimiloCharacter cand) {
        var score = 0;
        for (final cl in clues) {
          final m = cl['card'] as Map<String, dynamic>;
          final sim = cl['similar'] == true;
          var shared = 0;
          if (cand.realm == m['realm']) shared += 2;
          if (cand.role == m['role']) shared += 2;
          if (cand.era == m['era']) shared += 1;
          if ((cand.power - asInt(m['power'], 5)).abs() <= 1) shared += 1;
          if (sim) {
            score += shared >= 2 ? shared * 2 : -3;
          } else {
            score += shared == 0 ? 3 : -shared * 2;
          }
        }
        return score;
      }

      candidates.sort((a, b) => compatibility(grid[a]).compareTo(compatibility(grid[b])));
      return {'type': 'eliminate', 'slot': candidates.first};
    }
    return null;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final canSeeTarget = _over || seat == 0;
    return {
      'round': round,
      'totalRounds': 5,
      'phase': phase,
      'eliminateQuota': kSimiloEliminateQuota,
      'quotaLeft': quotaLeft,
      'remainingCount': eliminated.where((e) => !e).length,
      'grid': [
        for (var i = 0; i < 12; i++) grid[i].toJson(eliminated: eliminated[i]),
      ],
      'secretTarget': canSeeTarget ? _secretTarget : null,
      'clueHand': (seat == 0 || _over)
          ? [for (final c in clueHand) c.toJson()]
          : const <Map<String, dynamic>>[],
      'clueHandCount': clueHand.length,
      'clues': clues,
      'eliminationLog': eliminationLog,
      'waitingFor': waitingFor,
      'over': _over,
      'won': won,
      'resultText': resultText,
    };
  }
}
