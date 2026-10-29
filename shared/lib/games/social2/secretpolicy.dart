import '../../src/ai.dart';
import '../../src/engine.dart';

const secretPolicyRoleNames = {
  'liberal': '自由派',
  'agent': '潜伏派',
  'leader': '幕后首脑',
};

bool secretPolicyIsShadow(String role) => role == 'agent' || role == 'leader';

/// Unshuffled role list for [n] players (5..10).
List<String> secretPolicyRoles(int n) {
  final agents = switch (n) {
    5 || 6 => 1,
    7 || 8 => 2,
    _ => 3,
  };
  final liberals = n - agents - 1;
  return [
    for (var i = 0; i < liberals; i++) 'liberal',
    for (var i = 0; i < agents; i++) 'agent',
    'leader',
  ];
}

/// Executive powers on the 1st..5th Red policy slots for [n] players.
List<String> secretPolicyPowers(int n) {
  if (n <= 6) {
    return const ['none', 'none', 'peek', 'execute', 'execute'];
  } else if (n <= 8) {
    return const ['none', 'investigate', 'special_election', 'execute', 'execute'];
  } else {
    return const ['investigate', 'investigate', 'special_election', 'execute', 'execute'];
  }
}

const secretPolicyPowerNames = {
  'none': '无特权',
  'peek': '政策检视',
  'investigate': '身份调查',
  'special_election': '特别选举',
  'execute': '总统处决',
};

class SecretPolicy extends GameEngine {
  SecretPolicy(super.setup);

  final AiSlot _ai = AiSlot();

  late List<String> roles;
  late List<bool> alive;
  List<String> deck = [];
  List<String> discardPile = [];

  int bluePolicies = 0;
  int redPolicies = 0;
  int electionTracker = 0;

  int president = 0;
  int chancellor = -1;
  int lastPresident = -1;
  int lastChancellor = -1;
  int? resumeAfterSpecial;

  /// Phases:
  /// nominate, vote, president_discard, chancellor_discard, veto_confirm,
  /// peek, investigate, special_election, execute, over
  String phase = 'nominate';

  Map<int, bool> votes = {};
  List<String> drawnCards = [];
  List<String> peekCards = [];
  bool vetoProposed = false;
  bool vetoRejected = false;

  final Set<int> investigatedSeats = {};
  late List<Map<String, String>> investigatedBy;
  final List<int> executedSeats = [];
  final List<Map<String, dynamic>> history = [];
  final List<Map<String, dynamic>> claims = [];
  Map<String, dynamic>? lastVote;
  Map<String, dynamic>? lastEnacted;

  String winner = ''; // 'liberal' or 'shadow'
  String reason = '';
  int roundNum = 1;

  // Publicly observable suspicion score per seat (used by bots without reading hidden roles)
  late List<double> publicSuspicion;

  int get aliveCount => alive.where((a) => a).length;
  List<String> get powers => secretPolicyPowers(players);
  int get vetoThreshold => setup.opt<String>('vetoRule', 'standard') == 'early' ? 4 : 5;
  bool get vetoUnlocked => redPolicies >= vetoThreshold;

  @override
  bool get isOver => phase == 'over';

  @override
  int get botDelayMs => 750;

  @override
  List<int>? get placings {
    if (!isOver) return null;
    final shadowWon = winner == 'shadow';
    return [
      for (var s = 0; s < players; s++)
        (secretPolicyIsShadow(roles[s]) == shadowWon) ? 1 : 2,
    ];
  }

  @override
  Set<int>? voiceListeners(int seat) {
    if (isOver || seat < 0 || seat >= players || alive[seat]) return null;
    return {for (var s = 0; s < players; s++) if (!alive[s]) s};
  }

  @override
  void start() {
    roles = shuffled(secretPolicyRoles(players), rng);
    alive = List.filled(players, true);
    investigatedBy = [for (var i = 0; i < players; i++) <String, String>{}];
    publicSuspicion = List.filled(players, 0.0);
    deck = shuffled([
      for (var i = 0; i < 6; i++) 'blue',
      for (var i = 0; i < 11; i++) 'red',
    ], rng);
    discardPile = [];
    president = rng.nextInt(players);
    host.log('秘密法案开始！${players}人局，${name(president)} 担任首任总统候选人');
  }

  void _ensureDeck(int minCards) {
    if (deck.length >= minCards) return;
    deck.addAll(discardPile);
    discardPile.clear();
    deck = shuffled(deck, rng);
    host.log('法案牌库重洗（共 ${deck.length} 张）');
  }

  /// Eligible chancellor nominees for the current [president].
  List<int> eligibleChancellors() {
    final strict = <int>[];
    final aliveNow = aliveCount;
    for (var s = 0; s < players; s++) {
      if (!alive[s] || s == president) continue;
      if (s == lastChancellor) continue;
      if (aliveNow > 5 && s == lastPresident) continue;
      strict.add(s);
    }
    if (strict.isNotEmpty) return strict;
    return [for (var s = 0; s < players; s++) if (alive[s] && s != president) s];
  }

  /// Eligible investigation targets for [president].
  List<int> eligibleInvestigateTargets() {
    final uninvestigated = [
      for (var s = 0; s < players; s++)
        if (alive[s] && s != president && !investigatedSeats.contains(s)) s,
    ];
    if (uninvestigated.isNotEmpty) return uninvestigated;
    return [for (var s = 0; s < players; s++) if (alive[s] && s != president) s];
  }

  /// Eligible targets for special election or execution.
  List<int> eligibleOtherAlive() =>
      [for (var s = 0; s < players; s++) if (alive[s] && s != president) s];

  /// Secret knowledge visible to [seat].
  Map<String, String> knowledge(int seat) {
    if (seat < 0 || seat >= players) return const {};
    final out = <String, String>{...investigatedBy[seat]};
    final myRole = roles[seat];
    if (myRole == 'agent') {
      for (var s = 0; s < players; s++) {
        if (s == seat) continue;
        if (roles[s] == 'agent') out['$s'] = '潜伏派';
        if (roles[s] == 'leader') out['$s'] = '幕后首脑';
      }
    } else if (myRole == 'leader' && players <= 6) {
      for (var s = 0; s < players; s++) {
        if (s != seat && roles[s] == 'agent') out['$s'] = '潜伏派';
      }
    }
    return out;
  }

  @override
  List<int> get waitingFor {
    if (isOver) return const [];
    switch (phase) {
      case 'nominate':
      case 'president_discard':
      case 'veto_confirm':
      case 'peek':
      case 'investigate':
      case 'special_election':
      case 'execute':
        return [president];
      case 'chancellor_discard':
        return [chancellor];
      case 'vote':
        return [
          for (var s = 0; s < players; s++)
            if (alive[s] && !votes.containsKey(s)) s,
        ];
      default:
        return const [];
    }
  }

  void _finish(String winTeam, String why) {
    winner = winTeam;
    reason = why;
    phase = 'over';
    host.log('${winTeam == 'liberal' ? '自由派' : '潜伏阵营'}获胜：$why');
  }

  void _advancePresident() {
    roundNum++;
    chancellor = -1;
    votes.clear();
    drawnCards.clear();
    peekCards.clear();
    vetoProposed = false;
    vetoRejected = false;

    int base = president;
    if (resumeAfterSpecial != null) {
      base = resumeAfterSpecial!;
      resumeAfterSpecial = null;
    }
    for (var i = 1; i <= players; i++) {
      final next = (base + i) % players;
      if (alive[next]) {
        president = next;
        break;
      }
    }
    phase = 'nominate';
  }

  void _enactPolicy(String card, {required bool chaos}) {
    if (card == 'blue') {
      bluePolicies++;
    } else {
      redPolicies++;
    }
    lastEnacted = {
      'card': card,
      'chaos': chaos,
      'president': chaos ? -1 : president,
      'chancellor': chaos ? -1 : chancellor,
      'round': roundNum,
    };
    history.add(lastEnacted!);

    if (!chaos) {
      if (card == 'red') {
        publicSuspicion[president] += 0.45;
        publicSuspicion[chancellor] += 0.65;
      } else {
        publicSuspicion[president] = (publicSuspicion[president] - 0.25).clamp(-2.0, 5.0);
        publicSuspicion[chancellor] = (publicSuspicion[chancellor] - 0.35).clamp(-2.0, 5.0);
      }
    }

    host.log(chaos
        ? '混乱强制颁布：${card == 'blue' ? '蓝法案' : '红法案'}（蓝 $bluePolicies / 红 $redPolicies）'
        : '政府颁布了 ${card == 'blue' ? '蓝法案' : '红法案'}（蓝 $bluePolicies / 红 $redPolicies）');

    if (bluePolicies >= 5) {
      _finish('liberal', '成功颁布 5 项自由派蓝法案！');
      return;
    }
    if (redPolicies >= 6) {
      _finish('shadow', '成功颁布 6 项潜伏派红法案！');
      return;
    }

    if (!chaos && card == 'red') {
      final pwr = powers[redPolicies - 1];
      switch (pwr) {
        case 'peek':
          _ensureDeck(3);
          peekCards = [
            for (var i = 0; i < 3 && i < deck.length; i++) deck[deck.length - 1 - i],
          ];
          phase = 'peek';
          host.log('触发行政特权【政策检视】：总统 ${name(president)} 查看牌堆顶 3 张法案');
          return;
        case 'investigate':
          phase = 'investigate';
          host.log('触发行政特权【身份调查】：总统 ${name(president)} 可调查一名玩家的阵营');
          return;
        case 'special_election':
          phase = 'special_election';
          host.log('触发行政特权【特别选举】：总统 ${name(president)} 可指定下一任总统候选人');
          return;
        case 'execute':
          phase = 'execute';
          host.log('触发行政特权【总统处决】：总统 ${name(president)} 必须处决一名存活玩家');
          return;
      }
    }
    _advancePresident();
  }

  @override
  void handle(int seat, Map<String, dynamic> action) {
    if (isOver) throw GameError('对局已结束');
    if (seat < 0 || seat >= players || !alive[seat]) {
      throw GameError('你已出局或不在座位上');
    }
    final type = asStr(action['type']);

    if (type == 'claim') {
      final text = AiText.firstLine(asStr(action['text']), maxLen: 40);
      if (text.isEmpty) throw GameError('发言内容不能为空');
      claims.add({'seat': seat, 'text': text, 'round': roundNum});
      if (claims.length > 16) claims.removeAt(0);
      host.log('${name(seat)} 发言：$text');
      return;
    }

    switch (phase) {
      case 'nominate':
        if (seat != president) throw GameError('只有当前总统候选人可以提名总理');
        if (type != 'nominate') throw GameError('请提名一名总理候选人');
        final target = asInt(action['target']);
        final eligible = eligibleChancellors();
        if (!eligible.contains(target)) {
          throw GameError('该玩家当前不可被提名为总理');
        }
        chancellor = target;
        votes = {};
        phase = 'vote';
        host.log('总统候选人 ${name(president)} 提名 ${name(chancellor)} 为总理，请全体投票');
        break;

      case 'vote':
        if (type != 'vote') throw GameError('请先进行投票');
        if (votes.containsKey(seat)) throw GameError('你已经投过票了');
        bool approve;
        if (action.containsKey('vote')) {
          final vStr = asStr(action['vote']).toLowerCase();
          if (vStr != 'ja' && vStr != 'nein') throw GameError('投票只能为 ja 或 nein');
          approve = vStr == 'ja';
        } else {
          approve = asBool(action['approve']);
        }
        votes[seat] = approve;
        if (votes.length == aliveCount) {
          _resolveVote();
        }
        break;

      case 'president_discard':
        if (seat != president) throw GameError('等待总统弃置法案');
        if (type != 'discard') throw GameError('请选择要弃置的 1 张法案');
        final idx = asInt(action['index']);
        if (idx < 0 || idx >= drawnCards.length) throw GameError('无效的法案序号');
        final removed = drawnCards.removeAt(idx);
        discardPile.add(removed);
        phase = 'chancellor_discard';
        host.log('总统 ${name(president)} 已弃置 1 张法案，将剩余 2 张交给总理 ${name(chancellor)}');
        break;

      case 'chancellor_discard':
        if (seat != chancellor) throw GameError('等待总理颁布法案');
        if (type == 'veto') {
          if (!vetoUnlocked) throw GameError('尚未解锁否决权');
          if (vetoRejected) throw GameError('本轮总统已拒绝过否决提议');
          vetoProposed = true;
          phase = 'veto_confirm';
          host.log('总理 ${name(chancellor)} 提议否决本轮全部法案！等待总统 ${name(president)} 表决');
          return;
        }
        if (type != 'discard') throw GameError('请选择要弃置的 1 张法案');
        final idx = asInt(action['index']);
        if (idx < 0 || idx >= drawnCards.length) throw GameError('无效的法案序号');
        final removed = drawnCards.removeAt(idx);
        discardPile.add(removed);
        final enacted = drawnCards.removeAt(0);
        drawnCards.clear();
        _enactPolicy(enacted, chaos: false);
        break;

      case 'veto_confirm':
        if (seat != president) throw GameError('等待总统回应否决提议');
        if (type != 'veto_reply') throw GameError('请选择同意或拒绝否决');
        final agree = asBool(action['agree']);
        if (agree) {
          discardPile.addAll(drawnCards);
          drawnCards.clear();
          electionTracker++;
          host.log('总统 ${name(president)} 同意否决！全部法案已弃置（停滞轨 $electionTracker/3）');
          if (electionTracker >= 3) {
            electionTracker = 0;
            lastPresident = -1;
            lastChancellor = -1;
            _ensureDeck(1);
            final top = deck.removeLast();
            _enactPolicy(top, chaos: true);
          } else {
            _advancePresident();
          }
        } else {
          vetoProposed = false;
          vetoRejected = true;
          phase = 'chancellor_discard';
          host.log('总统 ${name(president)} 拒绝否决，总理 ${name(chancellor)} 必须颁布一项法案');
        }
        break;

      case 'peek':
        if (seat != president) throw GameError('等待总统确认检视结果');
        if (type != 'ack_peek') throw GameError('请确认政策检视结果');
        peekCards = [];
        _advancePresident();
        break;

      case 'investigate':
        if (seat != president) throw GameError('等待总统选择调查目标');
        if (type != 'investigate') throw GameError('请选择一名要调查的玩家');
        final target = asInt(action['target']);
        if (!eligibleInvestigateTargets().contains(target)) {
          throw GameError('该玩家无法被调查');
        }
        investigatedSeats.add(target);
        final party = secretPolicyIsShadow(roles[target]) ? '潜伏阵营' : '自由派';
        investigatedBy[president]['$target'] = party;
        host.log('总统 ${name(president)} 调查了 ${name(target)} 的阵营身份');
        _advancePresident();
        break;

      case 'special_election':
        if (seat != president) throw GameError('等待总统指定特别选举候选人');
        if (type != 'special_election') throw GameError('请选择下一任总统候选人');
        final target = asInt(action['target']);
        if (!eligibleOtherAlive().contains(target)) {
          throw GameError('请选择一名其他存活玩家');
        }
        resumeAfterSpecial ??= president;
        roundNum++;
        president = target;
        chancellor = -1;
        votes.clear();
        phase = 'nominate';
        host.log('特别选举：${name(target)} 成为下一任总统候选人');
        break;

      case 'execute':
        if (seat != president) throw GameError('等待总统执行处决');
        if (type != 'execute') throw GameError('请选择要处决的目标玩家');
        final target = asInt(action['target']);
        if (!eligibleOtherAlive().contains(target)) {
          throw GameError('请选择一名其他存活玩家');
        }
        alive[target] = false;
        executedSeats.add(target);
        if (lastPresident == target) lastPresident = -1;
        if (lastChancellor == target) lastChancellor = -1;
        if (roles[target] == 'leader') {
          _finish('liberal', '总统 ${name(president)} 处决了幕后首脑 ${name(target)}！');
          return;
        }
        host.log('总统 ${name(president)} 处决了 ${name(target)}（并非幕后首脑）');
        _advancePresident();
        break;

      default:
        throw GameError('当前阶段无法执行此操作');
    }
  }

  void _resolveVote() {
    final ja = votes.values.where((v) => v).length;
    final nein = aliveCount - ja;
    final passed = ja * 2 > aliveCount;
    lastVote = {
      'president': president,
      'chancellor': chancellor,
      'votes': {for (final e in votes.entries) '${e.key}': e.value},
      'ja': ja,
      'nein': nein,
      'passed': passed,
    };
    host.log('投票结果：$ja 赞成(Ja) / $nein 反对(Nein) —— ${passed ? '通过' : '否决'}');

    if (passed) {
      electionTracker = 0;
      lastPresident = president;
      lastChancellor = chancellor;
      if (redPolicies >= 3 && roles[chancellor] == 'leader') {
        _finish('shadow', '已颁布 $redPolicies 项红法案后，幕后首脑 ${name(chancellor)} 成功当选总理！');
        return;
      }
      _ensureDeck(3);
      drawnCards = [deck.removeLast(), deck.removeLast(), deck.removeLast()];
      vetoProposed = false;
      vetoRejected = false;
      phase = 'president_discard';
    } else {
      electionTracker++;
      if (electionTracker >= 3) {
        electionTracker = 0;
        lastPresident = -1;
        lastChancellor = -1;
        _ensureDeck(1);
        final top = deck.removeLast();
        _enactPolicy(top, chaos: true);
      } else {
        _advancePresident();
      }
    }
  }

  @override
  Map<String, dynamic> view(int seat) {
    final me = seat >= 0 && seat < players;
    final over = isOver;
    final showHand = me &&
        ((phase == 'president_discard' && seat == president) ||
            ((phase == 'chancellor_discard' || phase == 'veto_confirm') && seat == chancellor));
    final showPeek = me && phase == 'peek' && seat == president;

    return {
      'phase': phase,
      'round': roundNum,
      'president': president,
      'chancellor': chancellor,
      'lastPresident': lastPresident,
      'lastChancellor': lastChancellor,
      'alive': alive,
      'bluePolicies': bluePolicies,
      'redPolicies': redPolicies,
      'electionTracker': electionTracker,
      'deckCount': deck.length,
      'discardCount': discardPile.length,
      'powers': powers,
      'vetoUnlocked': vetoUnlocked,
      'vetoProposed': vetoProposed,
      'vetoRejected': vetoRejected,
      'eligibleChancellors': phase == 'nominate' ? eligibleChancellors() : const <int>[],
      'eligibleTargets': switch (phase) {
        'investigate' => eligibleInvestigateTargets(),
        'special_election' || 'execute' => eligibleOtherAlive(),
        _ => const <int>[],
      },
      'voted': [for (var s = 0; s < players; s++) votes.containsKey(s)],
      'myVote': me && votes.containsKey(seat) ? (votes[seat]! ? 'ja' : 'nein') : null,
      'hand': showHand ? drawnCards : const <String>[],
      'peekCards': showPeek ? peekCards : const <String>[],
      'investigatedSeats': investigatedSeats.toList(),
      'executedSeats': executedSeats,
      'lastVote': lastVote,
      'lastEnacted': lastEnacted,
      'history': history,
      'claims': claims,
      'myRole': me ? roles[seat] : null,
      'known': me ? knowledge(seat) : const <String, String>{},
      'roles': over ? roles : null,
      'winner': winner,
      'reason': reason,
    };
  }

  // ---------------------------------------------------------------- Bot & AI
  @override
  Map<String, dynamic>? bot(int seat) {
    if (isOver || !alive[seat] || !waitingFor.contains(seat)) return null;
    final myRole = roles[seat];
    final isShadow = secretPolicyIsShadow(myRole);
    final known = knowledge(seat);

    if (aiOn && (phase == 'nominate' || phase == 'vote' || phase == 'execute')) {
      final key = 'sp:$roundNum:$phase:$seat:$president:$chancellor:$electionTracker';
      final poll = _ai.poll(setup.ai!, key, () {
        final knownDesc = known.isEmpty
            ? '未知'
            : known.entries.map((e) => '座位${e.key}(${e.value})').join('、');
        final contextDesc = switch (phase) {
          'nominate' => '你是总统候选人，请从可选总理候选人 ${eligibleChancellors()} 中提名一人，返回 {"target":座位号}。',
          'vote' => '当前总统候选人:座位$president(${name(president)})，提名总理:座位$chancellor(${name(chancellor)})，请投票返回 {"vote":"ja"} 或 {"vote":"nein"}。',
          _ => '你是总统，请从存活玩家 ${eligibleOtherAlive()} 中选择处决目标，返回 {"target":座位号}。',
        };
        return AiRequest(
          system: '你在玩《秘密法案》(Secret Policy)。只返回一行 JSON，不要任何解释。',
          prompt: '你的座位:$seat，身份:${secretPolicyRoleNames[myRole]}，已知信息:$knownDesc。'
              '当前蓝法案:$bluePolicies/5，红法案:$redPolicies/6，连续否决:$electionTracker/3。$contextDesc',
          maxTokens: 120,
        );
      });
      if (poll.pending) return null;
      if (poll.text != null) {
        final j = AiText.json(poll.text!);
        if (j != null) {
          if (phase == 'nominate') {
            final t = asInt(j['target']);
            if (eligibleChancellors().contains(t)) {
              return {'type': 'nominate', 'target': t};
            }
          } else if (phase == 'vote') {
            final v = asStr(j['vote']).toLowerCase();
            if (v == 'ja' || v == 'nein') {
              return {'type': 'vote', 'vote': v};
            }
          } else if (phase == 'execute') {
            final t = asInt(j['target']);
            if (eligibleOtherAlive().contains(t)) {
              return {'type': 'execute', 'target': t};
            }
          }
        }
      }
    }

    switch (phase) {
      case 'nominate':
        if (seat != president) return null;
        final candidates = List<int>.of(eligibleChancellors());
        if (botLevel == 0) {
          return {'type': 'nominate', 'target': candidates[rng.nextInt(candidates.length)]};
        }
        double scoreCandidate(int c) {
          final k = known['$c'];
          if (isShadow) {
            if (redPolicies >= 3 && k == '幕后首脑') return 100.0;
            if (k == '潜伏派' || k == '幕后首脑' || k == '潜伏阵营') return 5.0 + rng.nextDouble();
            return -publicSuspicion[c] + rng.nextDouble();
          } else {
            if (k == '潜伏阵营') return -50.0;
            if (k == '自由派') return 10.0 + rng.nextDouble();
            return -publicSuspicion[c] + rng.nextDouble() * 0.6;
          }
        }
        candidates.sort((a, b) => scoreCandidate(b).compareTo(scoreCandidate(a)));
        return {'type': 'nominate', 'target': candidates.first};

      case 'vote':
        if (votes.containsKey(seat)) return null;
        if (botLevel == 0 && electionTracker < 2) {
          return {'type': 'vote', 'vote': rng.nextBool() ? 'ja' : 'nein'};
        }
        if (electionTracker >= 2) {
          // Avoid chaos unless we strongly suspect the chancellor is the enemy leader at 3+ red
          if (!isShadow && redPolicies >= 3 && (known['$chancellor'] == '潜伏阵营' || publicSuspicion[chancellor] > 1.2)) {
            return {'type': 'vote', 'vote': 'nein'};
          }
          return {'type': 'vote', 'vote': 'ja'};
        }
        bool approve;
        if (isShadow) {
          if (redPolicies >= 3 && (chancellor == seat && myRole == 'leader' || known['$chancellor'] == '幕后首脑')) {
            approve = true;
          } else {
            final teamOnGov = president == seat ||
                chancellor == seat ||
                known.containsKey('$president') ||
                known.containsKey('$chancellor');
            approve = teamOnGov ? rng.nextDouble() < 0.85 : rng.nextDouble() < 0.35;
          }
        } else {
          if (known['$president'] == '潜伏阵营' || known['$chancellor'] == '潜伏阵营') {
            approve = false;
          } else if (president == seat || chancellor == seat || known['$chancellor'] == '自由派') {
            approve = true;
          } else {
            final susp = publicSuspicion[president] + publicSuspicion[chancellor];
            approve = susp < (redPolicies >= 3 ? 0.6 : 1.2) && rng.nextDouble() < 0.75;
          }
        }
        return {'type': 'vote', 'vote': approve ? 'ja' : 'nein'};

      case 'president_discard':
        if (seat != president) return null;
        // Liberal wants to keep 'blue' (so discard 'red'); Shadow wants to keep 'red' (so discard 'blue')
        final wantDiscard = isShadow ? 'blue' : 'red';
        // Leader sometimes plays blue early to build trust
        if (myRole == 'leader' && redPolicies < 3 && bluePolicies < 3 && botLevel == 2 && rng.nextDouble() < 0.35) {
          final rIdx = drawnCards.indexOf('red');
          if (rIdx >= 0) return {'type': 'discard', 'index': rIdx};
        }
        final idx = drawnCards.indexOf(wantDiscard);
        return {'type': 'discard', 'index': idx >= 0 ? idx : 0};

      case 'chancellor_discard':
        if (seat != chancellor) return null;
        if (vetoUnlocked && !vetoRejected) {
          final allRed = drawnCards.every((c) => c == 'red');
          final allBlue = drawnCards.every((c) => c == 'blue');
          if (!isShadow && allRed) return {'type': 'veto'};
          if (isShadow && allBlue && bluePolicies >= 4) return {'type': 'veto'};
        }
        final wantDiscard = isShadow ? 'blue' : 'red';
        final idx = drawnCards.indexOf(wantDiscard);
        return {'type': 'discard', 'index': idx >= 0 ? idx : 0};

      case 'veto_confirm':
        if (seat != president) return null;
        if (!isShadow) {
          return {'type': 'veto_reply', 'agree': electionTracker < 2};
        } else {
          return {'type': 'veto_reply', 'agree': bluePolicies >= 4 && electionTracker < 2};
        }

      case 'peek':
        if (seat != president) return null;
        return {'type': 'ack_peek'};

      case 'investigate':
        if (seat != president) return null;
        final targets = List<int>.of(eligibleInvestigateTargets());
        targets.sort((a, b) => publicSuspicion[b].compareTo(publicSuspicion[a]));
        return {'type': 'investigate', 'target': targets.first};

      case 'special_election':
        if (seat != president) return null;
        final targets = List<int>.of(eligibleOtherAlive());
        if (isShadow) {
          final mates = targets.where((t) => known.containsKey('$t')).toList();
          if (mates.isNotEmpty) return {'type': 'special_election', 'target': mates.first};
        } else {
          final libs = targets.where((t) => known['$t'] == '自由派').toList();
          if (libs.isNotEmpty) return {'type': 'special_election', 'target': libs.first};
          targets.sort((a, b) => publicSuspicion[a].compareTo(publicSuspicion[b]));
        }
        return {'type': 'special_election', 'target': targets.first};

      case 'execute':
        if (seat != president) return null;
        final targets = List<int>.of(eligibleOtherAlive());
        if (isShadow) {
          final nonMates = targets.where((t) => !known.containsKey('$t')).toList();
          if (nonMates.isNotEmpty) {
            return {'type': 'execute', 'target': nonMates[rng.nextInt(nonMates.length)]};
          }
        } else {
          final bads = targets.where((t) => known['$t'] == '潜伏阵营').toList();
          if (bads.isNotEmpty) return {'type': 'execute', 'target': bads.first};
          targets.sort((a, b) => publicSuspicion[b].compareTo(publicSuspicion[a]));
        }
        return {'type': 'execute', 'target': targets.first};

      default:
        return null;
    }
  }
}
