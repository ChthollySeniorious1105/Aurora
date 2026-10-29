import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const _roleNames = {
  'liberal': '自由派',
  'agent': '潜伏派',
  'leader': '幕后首脑',
};

const _roleDesc = {
  'liberal': '自由派阵营。通过 5 张蓝法案或处决幕后首脑获胜。',
  'agent': '潜伏阵营。掩护幕后首脑，通过 6 张红法案或让首脑在 3 红后当选总理。',
  'leader': '幕后首脑。隐藏自己！若颁布 3 张红法案后你当选总理，潜伏阵营直接获胜。',
};

const _powerShort = {
  'none': '无',
  'peek': '检视3张',
  'investigate': '查验阵营',
  'special_election': '特别选举',
  'execute': '处决',
};

List<int> _ints(Object? v) => v is List ? [for (final e in v) (e as num).toInt()] : <int>[];

class SecretPolicyBoard extends StatefulWidget {
  final GameContext g;
  const SecretPolicyBoard(this.g, {super.key});
  @override
  State<SecretPolicyBoard> createState() => _SecretPolicyBoardState();
}

class _SecretPolicyBoardState extends State<SecretPolicyBoard> {
  bool showRole = true;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  String get phase => (v['phase'] as String?) ?? 'nominate';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = g.seat;
    final president = (v['president'] as num?)?.toInt() ?? 0;
    final chancellor = (v['chancellor'] as num?)?.toInt() ?? -1;
    final lastPres = (v['lastPresident'] as num?)?.toInt() ?? -1;
    final lastChan = (v['lastChancellor'] as num?)?.toInt() ?? -1;
    final blue = (v['bluePolicies'] as num?)?.toInt() ?? 0;
    final red = (v['redPolicies'] as num?)?.toInt() ?? 0;
    final tracker = (v['electionTracker'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final discardCount = (v['discardCount'] as num?)?.toInt() ?? 0;
    final alive = (v['alive'] as List?)?.cast<bool>() ?? List.filled(g.players, true);
    final voted = (v['voted'] as List?)?.cast<bool>() ?? List.filled(g.players, false);
    final powers = (v['powers'] as List?)?.cast<String>() ?? const ['none', 'none', 'peek', 'execute', 'execute'];
    final eligibleChancellors = _ints(v['eligibleChancellors']);
    final eligibleTargets = _ints(v['eligibleTargets']);
    final hand = (v['hand'] as List?)?.cast<String>() ?? const <String>[];
    final peekCards = (v['peekCards'] as List?)?.cast<String>() ?? const <String>[];
    final myRole = v['myRole'] as String?;
    final roles = (v['roles'] as List?)?.cast<String>();
    final known = ((v['known'] as Map?) ?? {}).map((k, val) => MapEntry(int.parse('$k'), '$val'));
    final lastVote = (v['lastVote'] as Map?)?.cast<String, dynamic>();
    final lastVoteMap = (lastVote?['votes'] as Map?)?.map((k, val) => MapEntry(int.parse('$k'), val == true));

    String status;
    var hl = false;
    switch (phase) {
      case 'nominate':
        hl = me == president;
        status = hl ? '你是总统候选人：请点击一名玩家提名为总理' : '等待总统候选人 ${g.name(president)} 提名总理';
        break;
      case 'vote':
        hl = me >= 0 && alive[me] && !voted[me];
        status = hl
            ? '请表决是否同意 ${g.name(president)}(总统) + ${g.name(chancellor)}(总理)'
            : '等待全体存活玩家对政府内阁投票';
        break;
      case 'president_discard':
        hl = me == president;
        status = hl ? '你是总统：请秘密选择 1 张法案弃置' : '总统 ${g.name(president)} 正在审阅 3 张法案…';
        break;
      case 'chancellor_discard':
        hl = me == chancellor;
        status = hl ? '你是总理：请选择 1 张法案弃置（将颁布另一张）' : '总理 ${g.name(chancellor)} 正在抉择法案…';
        break;
      case 'veto_confirm':
        hl = me == president;
        status = hl
            ? '总理 ${g.name(chancellor)} 提议否决本轮全部法案，是否同意？'
            : '等待总统 ${g.name(president)} 回应否决提议…';
        break;
      case 'peek':
        hl = me == president;
        status = hl ? '政策检视：请查看牌堆顶 3 张法案后点击确认' : '总统 ${g.name(president)} 正在检视牌顶 3 张法案';
        break;
      case 'investigate':
        hl = me == president;
        status = hl ? '身份调查：请点击一名玩家查验其阵营归属' : '总统 ${g.name(president)} 正在选择调查目标';
        break;
      case 'special_election':
        hl = me == president;
        status = hl ? '特别选举：请指定下一任总统候选人' : '总统 ${g.name(president)} 正在指定下一任总统候选人';
        break;
      case 'execute':
        hl = me == president;
        status = hl ? '总统处决：请选择一名存活玩家执行处决！' : '总统 ${g.name(president)} 正在决定处决目标';
        break;
      default:
        status = '${v['winner'] == 'liberal' ? '自由派' : '潜伏阵营'}获胜：${v['reason'] ?? ''}';
    }

    Widget buildTracks(bool compact) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 8),
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('🕊️蓝法案', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
              for (var i = 0; i < 5; i++)
                Container(
                  width: compact ? 38 : 46,
                  height: compact ? 24 : 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < blue ? Colors.blue.shade600 : Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.blue.shade400, width: i < blue ? 2 : 1),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      i < blue ? '已颁布' : (i == 4 ? '5蓝胜' : '${i + 1}'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: i < blue ? Colors.white : Colors.blue.shade300,
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Text('牌库 $deckCount · 弃牌 $discardCount · 停滞 $tracker/3', style: const TextStyle(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 5,
            runSpacing: 4,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('🔥红法案', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
              for (var i = 0; i < 6; i++)
                Container(
                  width: compact ? 46 : 56,
                  height: compact ? 26 : 34,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < red ? Colors.red.shade700 : Colors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: i >= 3 ? Colors.amber : Colors.red.shade400,
                      width: i < red ? 2 : 1,
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      i < red
                          ? '已颁布'
                          : (i == 5 ? '6红胜' : _powerShort[powers[i]] ?? '${i + 1}'),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: i < red ? Colors.white : Colors.red.shade300,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ]),
      );
    }

    Widget seatTile(int s) {
      final isAlive = alive[s];
      final isPres = s == president;
      final isChan = s == chancellor;
      final canPickChancellor = phase == 'nominate' && me == president && eligibleChancellors.contains(s) && !g.over;
      final canPickTarget =
          (phase == 'investigate' || phase == 'special_election' || phase == 'execute') &&
              me == president &&
              eligibleTargets.contains(s) &&
              !g.over;
      final clickable = canPickChancellor || canPickTarget;

      final roleStr = roles != null ? _roleNames[roles[s]] : known[s];
      final isBad = roles != null
          ? (roles[s] == 'agent' || roles[s] == 'leader')
          : (known[s] == '潜伏派' || known[s] == '幕后首脑' || known[s] == '潜伏阵营');
      final prevVote = lastVoteMap?[s];

      VoidCallback? onTap;
      if (canPickChancellor) {
        onTap = () => g.act({'type': 'nominate', 'target': s});
      } else if (canPickTarget) {
        onTap = () => g.act({'type': phase, 'target': s});
      }

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Opacity(
          opacity: isAlive ? 1.0 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 148,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: clickable
                  ? cs.primaryContainer.withValues(alpha: 0.45)
                  : cs.surface.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: clickable
                    ? cs.primary
                    : (isPres || isChan ? Colors.amber : cs.outline.withValues(alpha: 0.3)),
                width: clickable || isPres || isChan ? 2 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              g.tag(s, active: (isPres || isChan) && !g.over, size: 28),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 2, alignment: WrapAlignment.center, children: [
                if (!isAlive) _badge('💀已出局', Colors.grey),
                if (isPres) _badge('🏛️总统', Colors.amber),
                if (isChan) _badge('📜总理', Colors.orange),
                if (!isPres && s == lastPres) _badge('前总统', Colors.blueGrey),
                if (!isChan && s == lastChan) _badge('前总理', Colors.blueGrey),
                if (roleStr != null) _badge(roleStr, isBad ? Colors.red : Colors.blue),
                if (phase == 'vote' && isAlive)
                  _badge(voted[s] ? '已投票' : '思考中', voted[s] ? Colors.green : Colors.grey),
                if (phase != 'vote' && prevVote != null)
                  _badge(prevVote ? '上轮赞成' : '上轮反对', prevVote ? Colors.green : Colors.deepOrange),
                if (clickable)
                  _badge(canPickChancellor ? '点击提名' : '点击选择', cs.primary),
              ]),
            ]),
          ),
        ),
      );
    }

    final actions = <Widget>[];
    if (!g.over && me >= 0 && alive[me]) {
      if (phase == 'vote' && !voted[me]) {
        actions.addAll([
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            onPressed: () => g.act({'type': 'vote', 'vote': 'ja'}),
            icon: const Icon(Icons.thumb_up, size: 16),
            label: const Text('赞成 (Ja)'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => g.act({'type': 'vote', 'vote': 'nein'}),
            icon: const Icon(Icons.thumb_down, size: 16),
            label: const Text('反对 (Nein)'),
          ),
        ]);
      } else if ((phase == 'president_discard' && me == president) ||
          (phase == 'chancellor_discard' && me == chancellor)) {
        for (var i = 0; i < hand.length; i++) {
          final isBlue = hand[i] == 'blue';
          actions.add(
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isBlue ? Colors.blue.shade700 : Colors.red.shade700,
              ),
              onPressed: () => g.act({'type': 'discard', 'index': i}),
              icon: const Icon(Icons.delete_outline, size: 16),
              label: Text('弃置：${isBlue ? "蓝法案" : "红法案"}'),
            ),
          );
        }
        if (phase == 'chancellor_discard' && v['vetoUnlocked'] == true && v['vetoRejected'] != true) {
          actions.add(
            OutlinedButton.icon(
              onPressed: () => g.act({'type': 'veto'}),
              icon: const Icon(Icons.block, size: 16),
              label: const Text('提议否决 (Veto)'),
            ),
          );
        }
      } else if (phase == 'veto_confirm' && me == president) {
        actions.addAll([
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
            onPressed: () => g.act({'type': 'veto_reply', 'agree': true}),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('同意否决全部法案'),
          ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'veto_reply', 'agree': false}),
            icon: const Icon(Icons.close, size: 16),
            label: const Text('拒绝否决'),
          ),
        ]);
      } else if (phase == 'peek' && me == president) {
        for (final c in peekCards) {
          actions.add(_badge('牌顶：${c == 'blue' ? '蓝法案' : '红法案'}', c == 'blue' ? Colors.blue : Colors.red));
        }
        actions.add(
          FilledButton.icon(
            onPressed: () => g.act({'type': 'ack_peek'}),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('确认已知晓'),
          ),
        );
      }
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 860;
      final short = c.maxHeight < 450;

      final mainColumn = Column(children: [
        const SizedBox(height: 4),
        StatusBar(status, highlight: hl),
        const SizedBox(height: 4),
        buildTracks(short),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [for (final s in g.seatsFromMe()) seatTile(s)],
            ),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ),
        if (!wide && myRole != null && !short) _roleCard(myRole, known, compact: true),
        if (g.over || phase == 'over') ResultBanner(status),
      ]);

      if (!wide) return mainColumn;
      return Row(children: [
        Expanded(child: mainColumn),
        SizedBox(
          width: 280,
          child: ListView(padding: const EdgeInsets.all(8), children: [
            if (myRole != null) _roleCard(myRole, known),
            const SizedBox(height: 8),
            _historyCard(),
          ]),
        ),
      ]);
    });
  }

  Widget _badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.7)),
        ),
        child: Text(t, style: const TextStyle(fontSize: 11)),
      );

  Widget _roleCard(String role, Map<int, String> known, {bool compact = false}) {
    final isShadow = role == 'agent' || role == 'leader';
    final col = isShadow ? Colors.red : Colors.blue;
    final info = known.entries.map((e) => '${g.name(e.key)}(${e.value})').join('、');
    if (compact) {
      return InkWell(
        onTap: () => setState(() => showRole = !showRole),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: col.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: col),
          ),
          child: Text(
            showRole
                ? '我的身份：${_roleNames[role]} ${info.isEmpty ? "" : "｜已知：$info"}'
                : '点击显示我的秘密身份',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11),
          ),
        ),
      );
    }
    return Card(
      color: col.withValues(alpha: 0.16),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(isShadow ? Icons.local_fire_department : Icons.verified_user, color: col),
            const SizedBox(width: 6),
            Text(
              _roleNames[role] ?? role,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: col),
            ),
          ]),
          const SizedBox(height: 4),
          Text(_roleDesc[role] ?? '', style: const TextStyle(fontSize: 12)),
          if (info.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('已知情报：$info', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ]),
      ),
    );
  }

  Widget _historyCard() {
    final hist = (v['history'] as List?)?.cast<Map>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('立法记录', style: TextStyle(fontWeight: FontWeight.bold)),
          if (hist.isEmpty) const Text('暂无法案颁布', style: TextStyle(fontSize: 12)),
          for (final h in hist.reversed.take(8))
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                h['chaos'] == true
                    ? '第${h['round']}轮：⚡混乱颁布【${h['card'] == 'blue' ? '蓝法案' : '红法案'}】'
                    : '第${h['round']}轮：${g.name((h['president'] as num).toInt())} + ${g.name((h['chancellor'] as num).toInt())} 颁布【${h['card'] == 'blue' ? '蓝法案' : '红法案'}】',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ]),
      ),
    );
  }
}
