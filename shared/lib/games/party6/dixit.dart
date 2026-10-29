import '../../src/ai.dart';
import '../../src/engine.dart';

/// Metadata for each of the 72 illustrated dream cards in Dixit (妙语说书人).
class DixitCard {
  final int id;
  final String title;
  final String motif; // procedural painter motif key
  final int colorA;
  final int colorB;
  final List<String> tags;
  final List<String> clues;
  const DixitCard({
    required this.id,
    required this.title,
    required this.motif,
    required this.colorA,
    required this.colorB,
    required this.tags,
    required this.clues,
  });
}

const List<(String, String, int, int, List<String>, List<String>)> _kCardBases = [
  ('星海孤舟', 'moon_boat', 0xFF1A237E, 0xFF7986CB, ['星空', '远航', '孤独', '月亮'], ['银河里的漂流者', '唯有月光伴我远行', '静谧的夜航']),
  ('时光沙漏', 'hourglass', 0xFF4A148C, 0xFFBA68C8, ['时间', '流逝', '记忆', '沙漠'], ['抓不住的流沙', '光阴的故事', '倒转的岁月']),
  ('云端阶梯', 'sky_stairs', 0xFF01579B, 0xFF4FC3F7, ['天空', '梦想', '攀登', '白云'], ['通往梦境的台阶', '一步步走入云霄', '高处的风景']),
  ('迷雾提灯', 'forest_lantern', 0xFF1B5E20, 0xFF81C784, ['森林', '希望', '迷失', '微光'], ['黑暗中的一束微光', '森林深处的引路人', '永不熄灭的温暖']),
  ('深海鲸歌', 'whale_stars', 0xFF0D47A1, 0xFF64B5F6, ['海洋', '星空', '鲸鱼', '孤独'], ['五十二赫兹的呼唤', '深海与星辰相拥', '蔚蓝色的梦']),
  ('假面舞会', 'mask_mirror', 0xFF880E4F, 0xFFF06292, ['伪装', '戏剧', '秘密', '镜子'], ['面具下的真实自我', '华丽的谎言', '谁在镜中凝望']),
  ('荆棘蔷薇', 'rose_key', 0xFFB71C1C, 0xFFE57373, ['爱情', '守护', '秘密', '花朵'], ['带刺的温柔', '锁住心门的钥匙', '盛开在废墟之上']),
  ('逆时钟楼', 'clock_tower', 0xFF3E2723, 0xFFA1887F, ['时间', '怀旧', '黄昏', '钟声'], ['停留在昨日的钟声', '回不去的旧时光', '黄昏的守望']),
  ('孤岛灯塔', 'lighthouse', 0xFF004D40, 0xFF4DB6AC, ['守望', '海洋', '风暴', '希望'], ['暴风雨中的守望者', '远方归途的坐标', '孤独却坚定']),
  ('旋转木马', 'carousel', 0xFFE65100, 0xFFFFB74D, ['童年', '欢乐', '循环', '梦境'], ['追逐不上的童年', '华丽而短暂的欢愉', '原地打转的思念']),
  ('浮空仙岛', 'floating_island', 0xFF311B92, 0xFF9575CD, ['幻想', '天空', '自由', '奇迹'], ['悬浮于尘世之外', '乌托邦的幻影', '云上的花园']),
  ('涅槃之羽', 'phoenix_feather', 0xFFBF360C, 0xFFFF8A65, ['重生', '火焰', '自由', '飞翔'], ['浴火后的新生', '飘落的一片炽热', '灰烬里的光芒']),
];

const List<(String, List<String>, String)> _kVariations = [
  ('·初见', ['黎明', '希望'], '初升的温柔'),
  ('·暮色', ['黄昏', '怀旧'], '夕阳下的余晖'),
  ('·幻影', ['镜子', '梦境'], '半梦半醒之间'),
  ('·霜雪', ['凛冬', '孤独'], '大雪纷飞的寂静'),
  ('·春华', ['生机', '花朵'], '万物复苏的悸动'),
  ('·星语', ['星空', '秘密'], '写给宇宙的情书'),
];

/// All 72 unique illustrated dream cards (`0..71`).
final List<DixitCard> kDixitCards = List.generate(72, (id) {
  final baseIdx = id % _kCardBases.length; // 0..11
  final varIdx = id ~/ _kCardBases.length; // 0..5
  final base = _kCardBases[baseIdx];
  final v = _kVariations[varIdx];
  final shift = varIdx * 0x001109;
  final cA = 0xFF000000 | ((base.$3 + shift) & 0x00FFFFFF);
  final cB = 0xFF000000 | ((base.$4 ^ (shift << 1)) & 0x00FFFFFF);
  return DixitCard(
    id: id,
    title: '${base.$1}${v.$1}',
    motif: base.$2,
    colorA: cA,
    colorB: cB,
    tags: [...base.$5, ...v.$2],
    clues: [...base.$6, v.$3],
  );
});

class DixitGame extends GameEngine {
  final _ai = AiSlot();

  /// Remaining draw pile of card IDs (`0..71`).
  late List<int> deck;

  /// Hand of 6 card IDs per seat.
  late List<List<int>> hands;

  /// Cumulative score per seat.
  late List<int> scores;

  /// Target score to win (default 30).
  late int targetScore;

  /// Current round number (1-based) and current Storyteller seat.
  int round = 1;
  int storyteller = 0;

  /// Current phase: 'story', 'submit', 'vote', 'end'.
  String phase = 'story';

  /// Poetic clue given by the Storyteller this round.
  String currentClue = '';

  /// Card submitted by each seat this round (`seat -> cardId`).
  final Map<int, int> submittedCard = {};

  /// Shuffled list of submitted card IDs revealed on the table during `'vote'`.
  List<int> pool = [];

  /// Votes cast by non-Storyteller seats (`voterSeat -> cardId`).
  final Map<int, int> votes = {};

  /// Summary of the most recently completed round for UI display.
  Map<String, dynamic>? lastRound;

  bool _over = false;

  DixitGame(super.setup);

  @override
  bool get isOver => _over;

  @override
  List<int>? get placings => _over ? rankByScore(scores) : null;

  @override
  void start() {
    targetScore = setup.opt<int>('target', 30);
    deck = shuffled([for (var i = 0; i < 72; i++) i], rng);
    hands = [
      for (var s = 0; s < players; s++)
        [for (var i = 0; i < 6; i++) deck.removeLast()],
    ];
    scores = List.filled(players, 0);
    round = 1;
    storyteller = 0;
    phase = 'story';
    currentClue = '';
    submittedCard.clear();
    pool = [];
    votes.clear();
    lastRound = null;
    _over = false;

    host.log('【妙语说书人】游戏开始！第 1 轮由 ${name(storyteller)} 担任说书人。');
  }

  @override
  List<int> get waitingFor {
    if (_over) return const [];
    if (phase == 'story') return [storyteller];
    if (phase == 'submit') {
      return [
        for (var s = 0; s < players; s++)
          if (s != storyteller && !submittedCard.containsKey(s)) s,
      ];
    }
    if (phase == 'vote') {
      return [
        for (var s = 0; s < players; s++)
          if (s != storyteller && !votes.containsKey(s)) s,
      ];
    }
    return const [];
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (_over) throw GameError('游戏已结束');
    if (seat < 0 || seat >= players) throw GameError('无效座位');

    final type = asStr(action['type']);

    if (phase == 'story') {
      if (seat != storyteller) throw GameError('当前由说书人 ${name(storyteller)} 出牌与给提示');
      if (type != 'story') throw GameError('请选择一张手牌并输入提示语');
      final card = asInt(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手中没有这张画牌');
      final clue = AiText.firstLine(asStr(action['clue'], asStr(action['text'])), maxLen: 40);
      if (clue.isEmpty) throw GameError('请输入一句诗意提示语');

      hands[seat].remove(card);
      submittedCard[seat] = card;
      currentClue = clue;
      phase = 'submit';
      host.log('【第 $round 轮】说书人 ${name(storyteller)} 给出妙语：「$currentClue」，请其余玩家挑选一张手牌交出。');
      return;
    }

    if (phase == 'submit') {
      if (seat == storyteller) throw GameError('说书人已经出过牌了');
      if (submittedCard.containsKey(seat)) throw GameError('你本轮已经交过牌了');
      if (type != 'submit') throw GameError('请从手牌中选择一张最契合提示语的画牌');
      final card = asInt(action['card']);
      if (!hands[seat].contains(card)) throw GameError('你手中没有这张画牌');

      hands[seat].remove(card);
      submittedCard[seat] = card;

      if (submittedCard.length == players) {
        pool = shuffled(submittedCard.values, rng);
        phase = 'vote';
        votes.clear();
        host.log('所有画牌已洗混展示！请非说书人投票找出说书人的画牌。');
      }
      return;
    }

    if (phase == 'vote') {
      if (seat == storyteller) throw GameError('说书人无需投票');
      if (votes.containsKey(seat)) throw GameError('你已经投过票了');
      if (type != 'vote') throw GameError('请投票选择你认为是说书人交出的画牌');

      int chosenCard = -1;
      if (action.containsKey('card')) {
        final c = asInt(action['card']);
        if (pool.contains(c)) {
          chosenCard = c;
        } else if (c >= 0 && c < pool.length) {
          chosenCard = pool[c];
        }
      } else if (action.containsKey('index') || action.containsKey('slot')) {
        final idx = asInt(action['index'], asInt(action['slot']));
        if (idx >= 0 && idx < pool.length) {
          chosenCard = pool[idx];
        }
      }

      if (!pool.contains(chosenCard)) {
        throw GameError('请选择场上一张有效的画牌');
      }
      if (chosenCard == submittedCard[seat]) {
        throw GameError('不能投票给自己交出的画牌');
      }

      votes[seat] = chosenCard;
      if (votes.length == players - 1) {
        _scoreRoundAndAdvance();
      }
      return;
    }
  }

  void _scoreRoundAndAdvance() {
    final stCard = submittedCard[storyteller]!;
    final ownerOf = <int, int>{for (final e in submittedCard.entries) e.value: e.key};
    final correctVoters = <int>[
      for (final e in votes.entries)
        if (e.value == stCard) e.key,
    ];
    final nonStCount = players - 1;
    final allOrNone = correctVoters.isEmpty || correctVoters.length == nonStCount;

    final delta = List.filled(players, 0);
    if (allOrNone) {
      // Everyone or nobody found Storyteller's card: Storyteller gets 0, all other players get +2!
      for (var s = 0; s < players; s++) {
        if (s != storyteller) delta[s] += 2;
      }
    } else {
      // Storyteller and everyone who guessed right get +3!
      delta[storyteller] += 3;
      for (final v in correctVoters) {
        delta[v] += 3;
      }
    }

    // Decoy bonus: every non-Storyteller gets +1 per vote received on their submitted card!
    for (final votedCard in votes.values) {
      final owner = ownerOf[votedCard];
      if (owner != null && owner != storyteller) {
        delta[owner] += 1;
      }
    }

    for (var s = 0; s < players; s++) {
      scores[s] += delta[s];
    }

    final summaryReason = correctVoters.isEmpty
        ? '无人猜中说书人的牌！说书人得 0 分，其余玩家各 +2 分'
        : (correctVoters.length == nonStCount
            ? '全员猜中说书人的牌（过于直白）！说书人得 0 分，其余玩家各 +2 分'
            : '共 ${correctVoters.length} 人猜中说书人的牌！说书人与猜中者各 +3 分');

    lastRound = {
      'round': round,
      'storyteller': storyteller,
      'clue': currentClue,
      'storyCard': stCard,
      'pool': List.of(pool),
      'submittedBy': {for (final e in submittedCard.entries) '${e.key}': e.value},
      'votes': {for (final e in votes.entries) '${e.key}': e.value},
      'delta': List.of(delta),
      'allOrNone': allOrNone,
      'summary': summaryReason,
    };

    host.log('【第 $round 轮结算】说书人画牌是《${kDixitCards[stCard].title}》——$summaryReason。');

    // Check game end condition: any player >= targetScore OR not enough cards in deck to replenish hands
    final reachedTarget = scores.any((sc) => sc >= targetScore);
    if (reachedTarget || deck.length < players) {
      _over = true;
      phase = 'end';
      final maxSc = scores.reduce((a, b) => a > b ? a : b);
      final winners = [for (var s = 0; s < players; s++) if (scores[s] == maxSc) name(s)].join('、');
      host.log('🏆 游戏结束！$winners 以 $maxSc 分赢得《妙语说书人》桂冠！');
      return;
    }

    // Draw 1 card per player to restore 6 cards in hand
    for (var s = 0; s < players; s++) {
      hands[s].add(deck.removeLast());
    }

    round++;
    storyteller = (storyteller + 1) % players;
    phase = 'story';
    currentClue = '';
    submittedCard.clear();
    pool = [];
    votes.clear();
  }

  /// Scores how well a card matches a clue string using card tags and poetic phrases.
  int matchScore(int cardId, String clue) {
    final c = kDixitCards[cardId];
    var score = 0;
    for (final cl in c.clues) {
      if (cl == clue) score += 5;
      for (var i = 0; i < cl.length; i++) {
        if (clue.contains(cl[i])) score += 1;
      }
    }
    for (final tag in c.tags) {
      if (clue.contains(tag)) score += 4;
      for (var i = 0; i < tag.length; i++) {
        if (clue.contains(tag[i])) score += 2;
      }
    }
    if (clue.contains(c.title.substring(0, 2))) score += 3;
    return score;
  }

  @override
  Map<String, dynamic> view(int seat) {
    final myHand = (seat >= 0 && seat < players) ? List.of(hands[seat]) : const <int>[];
    final mySubmitted = (seat >= 0 && seat < players) ? submittedCard[seat] : null;
    final myVote = (seat >= 0 && seat < players) ? votes[seat] : null;

    final maxSc = scores.isEmpty ? 0 : scores.reduce((a, b) => a > b ? a : b);
    final winNames = [for (var s = 0; s < players; s++) if (scores[s] == maxSc) name(s)].join('、');

    return {
      'phase': phase,
      'round': round,
      'storyteller': storyteller,
      'targetScore': targetScore,
      'deckCount': deck.length,
      'scores': List.of(scores),
      'clue': currentClue,
      'hand': myHand,
      'mySubmitted': mySubmitted,
      'myVote': myVote,
      'submittedSeats': submittedCard.keys.toList(),
      'votedSeats': votes.keys.toList(),
      'pool': phase == 'vote' || _over ? List.of(pool) : const <int>[],
      'lastRound': lastRound,
      'result': _over ? '$winNames 获胜（$maxSc 分）！' : null,
    };
  }

  @override
  Map<String, dynamic>? bot(int seat) {
    if (!waitingFor.contains(seat)) return null;

    if (phase == 'story') {
      final hand = hands[seat];
      if (aiOn) {
        // Use a deterministic card index while polling so tick 1 (pending) and
        // tick 2 (resolved) refer to the exact same card in hand.
        final aiCard = hand[(round + seat) % hand.length];
        final meta = kDixitCards[aiCard];
        final r = _ai.poll(
          setup.ai!,
          'dixit_story:$round:$seat',
          () => AiRequest(
            system: '你在玩《妙语说书人》（Dixit）并担任说书人。请根据画牌意象给出一句含蓄、诗意的短提示语（4～15字），不要直接照抄牌名。',
            prompt: '你选中的画牌意象标签：${meta.tags.join("、")}（参考意境：${meta.clues.first}）。请输出提示语：',
          ),
        );
        if (r.pending) return null;
        if (r.text != null) {
          final clue = AiText.firstLine(r.text!, maxLen: 24);
          if (clue.length >= 2) {
            return {'type': 'story', 'card': aiCard, 'clue': clue};
          }
        }
      }

      final chosenCard = hand[rng.nextInt(hand.length)];
      final meta = kDixitCards[chosenCard];
      final clue = meta.clues[rng.nextInt(meta.clues.length)];
      return {'type': 'story', 'card': chosenCard, 'clue': clue};
    }

    if (phase == 'submit') {
      final hand = hands[seat];
      if (aiOn) {
        final desc = [
          for (var i = 0; i < hand.length; i++)
            '$i:${kDixitCards[hand[i]].title}(${kDixitCards[hand[i]].tags.join("/")})',
        ].join('；');
        final r = _ai.poll(
          setup.ai!,
          'dixit_sub:$round:$seat',
          () => AiRequest(
            system: '你在玩《妙语说书人》。请从你的手牌中选出最契合说书人提示语的一张，只输出对应的序号（0到${hand.length - 1}）。',
            prompt: '说书人提示语：「$currentClue」。你的手牌：$desc。',
          ),
        );
        if (r.pending) return null;
        if (r.text != null) {
          final idx = int.tryParse(r.text!.trim().replaceAll(RegExp(r'[^0-9]'), ''));
          if (idx != null && idx >= 0 && idx < hand.length) {
            return {'type': 'submit', 'card': hand[idx]};
          }
        }
      }

      if (botLevel == 0) {
        return {'type': 'submit', 'card': hand[rng.nextInt(hand.length)]};
      }
      var bestCard = hand.first;
      var bestScore = -1;
      for (final c in hand) {
        final sc = matchScore(c, currentClue);
        if (sc > bestScore) {
          bestScore = sc;
          bestCard = c;
        }
      }
      return {'type': 'submit', 'card': bestCard};
    }

    if (phase == 'vote') {
      final myCard = submittedCard[seat];
      final choices = [for (final c in pool) if (c != myCard) c];

      if (aiOn) {
        final desc = [
          for (var i = 0; i < choices.length; i++)
            '$i:${kDixitCards[choices[i]].title}(${kDixitCards[choices[i]].tags.join("/")})',
        ].join('；');
        final r = _ai.poll(
          setup.ai!,
          'dixit_vote:$round:$seat',
          () => AiRequest(
            system: '你在玩《妙语说书人》。请投票选出你认为最可能是说书人根据提示语出的那张画牌，只输出对应序号。',
            prompt: '说书人提示语：「$currentClue」。候选画牌：$desc。',
          ),
        );
        if (r.pending) return null;
        if (r.text != null) {
          final idx = int.tryParse(r.text!.trim().replaceAll(RegExp(r'[^0-9]'), ''));
          if (idx != null && idx >= 0 && idx < choices.length) {
            return {'type': 'vote', 'card': choices[idx]};
          }
        }
      }

      if (botLevel == 0 || rng.nextDouble() < 0.25) {
        return {'type': 'vote', 'card': choices[rng.nextInt(choices.length)]};
      }
      var bestCard = choices.first;
      var bestScore = -1;
      for (final c in choices) {
        final sc = matchScore(c, currentClue);
        if (sc > bestScore) {
          bestScore = sc;
          bestCard = c;
        }
      }
      return {'type': 'vote', 'card': bestCard};
    }

    return null;
  }
}
