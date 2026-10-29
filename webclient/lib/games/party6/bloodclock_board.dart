import 'package:aurora_shared/games/party6/defs.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BloodClockBoard extends StatefulWidget {
  final GameContext g;
  const BloodClockBoard(this.g, {super.key});

  @override
  State<BloodClockBoard> createState() => _BloodClockBoardState();
}

class _BloodClockBoardState extends State<BloodClockBoard> {
  int _selectedTarget = -1;
  int _selectedTarget2 = -1;
  String _dayActionMode = 'nominate'; // 'nominate' or 'slayer'
  final TextEditingController _chatCtrl = TextEditingController();

  @override
  void dispose() {
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final phase = (v['phase'] as String?) ?? 'night';
    final day = (v['day'] as num?)?.toInt() ?? 1;
    final alive = (v['alive'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, true);
    final ghostVote = (v['ghostVote'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, true);
    final onBlock = (v['onBlock'] as num?)?.toInt() ?? -1;
    final onBlockVotes = (v['onBlockVotes'] as num?)?.toInt() ?? 0;
    final voteThreshold = (v['voteThreshold'] as num?)?.toInt() ?? 1;
    final myRoleName = v['myRoleName'] as String?;
    final myRoleTeam = v['myRoleTeam'] as String?;
    final myRoleDesc = v['myRoleDesc'] as String?;
    final isAwake = v['isAwake'] == true;
    final wakeRole = v['wakeRole'] as String?;
    final myNotes = (v['myNotes'] as List?)?.cast<String>() ?? const <String>[];
    final publicLog = (v['publicLog'] as List?)?.cast<String>() ?? const <String>[];
    final grimoire = (v['grimoire'] as List?)?.cast<Map>() ?? const <Map>[];
    final result = v['result'] as String?;

    final statusText = switch (phase) {
      'night' => isAwake ? '第 $day 夜：请行使你的【${kBotcRoles[wakeRole]?.name ?? myRoleName ?? ""}】夜晚能力' : '第 $day 夜：夜幕降临，请等待说书人唤醒…',
      'vote' => '公投表决：${g.name((v['nominator'] as num?)?.toInt() ?? 0)} 提名处决 ${g.name((v['nominee'] as num?)?.toInt() ?? 0)}（需 $voteThreshold 票）',
      'day' => '第 $day 天白天：自由发言、猎手开枪或发起处决提名',
      _ => result ?? '游戏结束',
    };

    return Container(
      color: phase == 'night' ? const Color(0xFF121324) : g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.all(compact ? 6 : 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Top status + Role badge
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          StatusBar(statusText, highlight: isAwake || phase == 'vote'),
                          if (myRoleName != null)
                            _buildRoleBadge(cs, myRoleName, myRoleTeam, myRoleDesc),
                          if (onBlock >= 0)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              avatar: const Icon(Icons.gavel, size: 16, color: Colors.redAccent),
                              label: Text('处决台：${g.name(onBlock)} ($onBlockVotes票)', style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Town Square Seats
                      _buildTownSquare(g, cs, alive, ghostVote, onBlock, v, grimoire, compact),
                      const SizedBox(height: 8),

                      // Active Phase Controls
                      if (!g.over && !g.spectator) ...[
                        if (phase == 'night' && isAwake)
                          _buildNightControls(g, cs, wakeRole ?? '', alive),
                        if (phase == 'vote')
                          _buildVoteControls(g, cs, v, alive, ghostVote),
                        if (phase == 'day')
                          _buildDayControls(g, cs, v, alive, compact),
                        const SizedBox(height: 8),
                      ],

                      // Private Notes & Public Log
                      _buildLogsSection(cs, myNotes, publicLog, compact),
                    ],
                  ),
                ),
                if (g.over && result != null)
                  Align(
                    alignment: Alignment.topCenter,
                    child: ResultBanner(result),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleBadge(ColorScheme cs, String roleName, String? team, String? desc) {
    final isEvil = team == 'demon' || team == 'minion';
    final badgeColor = isEvil ? Colors.red.shade800 : Colors.indigo.shade700;
    final teamLabel = switch (team) {
      'demon' => '恶魔',
      'minion' => '爪牙',
      'outsider' => '外来者',
      _ => '镇民',
    };
    return Tooltip(
      message: desc ?? roleName,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isEvil ? Icons.whatshot : Icons.shield, size: 15, color: Colors.white),
            const SizedBox(width: 5),
            Text(
              '我的身份：$roleName（$teamLabel）',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTownSquare(
    GameContext g,
    ColorScheme cs,
    List<bool> alive,
    List<bool> ghostVote,
    int onBlock,
    Map<String, dynamic> v,
    List<Map> grimoire,
    bool compact,
  ) {
    final nominee = (v['nominee'] as num?)?.toInt() ?? -1;
    final votes = (v['votes'] as Map?) ?? const {};

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (var s = 0; s < g.players; s++)
          _buildSeatCard(
            g: g,
            cs: cs,
            seat: s,
            isAlive: s < alive.length ? alive[s] : true,
            hasGhostVote: s < ghostVote.length ? ghostVote[s] : false,
            isOnBlock: onBlock == s,
            isNominee: nominee == s,
            voteVal: votes['$s'] as bool?,
            grimoireEntry: s < grimoire.length ? grimoire[s] : null,
            compact: compact,
          ),
      ],
    );
  }

  Widget _buildSeatCard({
    required GameContext g,
    required ColorScheme cs,
    required int seat,
    required bool isAlive,
    required bool hasGhostVote,
    required bool isOnBlock,
    required bool isNominee,
    required bool? voteVal,
    required Map? grimoireEntry,
    required bool compact,
  }) {
    final isMe = seat == g.seat;
    final statusParts = <String>[
      if (isAlive) '存活' else (hasGhostVote ? '阵亡·有死人票👻' : '阵亡·无票'),
      if (isOnBlock) '待处决⚰️',
      if (voteVal != null) (voteVal ? '✋赞成' : '反对'),
      if (grimoireEntry != null) '【${grimoireEntry['trueRoleName']}】',
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        if (_selectedTarget == seat) {
          _selectedTarget = -1;
        } else if (_selectedTarget >= 0 && _selectedTarget2 == -1) {
          _selectedTarget2 = seat;
        } else {
          _selectedTarget = seat;
          _selectedTarget2 = -1;
        }
      }),
      child: Container(
        constraints: BoxConstraints(minWidth: compact ? 115 : 140, maxWidth: compact ? 165 : 195),
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 5 : 7),
        decoration: BoxDecoration(
          color: isAlive ? cs.surface.withValues(alpha: 0.88) : cs.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isOnBlock
                ? Colors.redAccent
                : (isNominee
                    ? Colors.amber
                    : (_selectedTarget == seat || _selectedTarget2 == seat
                        ? cs.primary
                        : (isMe ? cs.secondary : cs.outline.withValues(alpha: 0.3)))),
            width: isOnBlock || isNominee || _selectedTarget == seat || _selectedTarget2 == seat ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Avatar(g.avatar(seat), size: compact ? 28 : 34, bot: g.bot(seat), dim: !isAlive),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${seat + 1}号 ${g.name(seat)}${isMe ? "(我)" : ""}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: compact ? 11 : 12.5,
                      decoration: isAlive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    statusParts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 10 : 11, color: cs.onSurface.withValues(alpha: 0.78)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNightControls(GameContext g, ColorScheme cs, String wakeRole, List<bool> alive) {
    final isFortuneTeller = wakeRole == 'fortune_teller';
    final rName = kBotcRoles[wakeRole]?.name ?? wakeRole;
    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isFortuneTeller ? '🌙 【$rName】请选择 2 名玩家进行占卜查验：' : '🌙 【$rName】请选择 1 名目标玩家：',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var s = 0; s < g.players; s++)
                  if ((wakeRole != 'monk' && wakeRole != 'butler') || s != g.seat)
                    if (wakeRole != 'imp' || (s < alive.length && alive[s]))
                      FilterChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${s + 1}号 ${g.name(s)}', style: const TextStyle(fontSize: 12)),
                        selected: _selectedTarget == s || (isFortuneTeller && _selectedTarget2 == s),
                        onSelected: (sel) {
                          setState(() {
                            if (!isFortuneTeller) {
                              _selectedTarget = sel ? s : -1;
                            } else {
                              if (_selectedTarget == s) {
                                _selectedTarget = _selectedTarget2;
                                _selectedTarget2 = -1;
                              } else if (_selectedTarget2 == s) {
                                _selectedTarget2 = -1;
                              } else if (_selectedTarget == -1) {
                                _selectedTarget = s;
                              } else {
                                _selectedTarget2 = s;
                              }
                            }
                          });
                        },
                      ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: isFortuneTeller
                  ? (_selectedTarget >= 0 && _selectedTarget2 >= 0 && _selectedTarget != _selectedTarget2
                      ? () {
                          g.act({'type': 'night_act', 'targets': [_selectedTarget, _selectedTarget2]});
                          setState(() {
                            _selectedTarget = -1;
                            _selectedTarget2 = -1;
                          });
                        }
                      : null)
                  : (_selectedTarget >= 0
                      ? () {
                          g.act({'type': 'night_act', 'target': _selectedTarget});
                          setState(() => _selectedTarget = -1);
                        }
                      : null),
              icon: const Icon(Icons.nightlight_round, size: 16),
              label: const Text('确认夜晚技能'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoteControls(GameContext g, ColorScheme cs, Map<String, dynamic> v, List<bool> alive, List<bool> ghostVote) {
    final votes = (v['votes'] as Map?) ?? const {};
    if (votes.containsKey('${g.seat}')) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Text('你已投票（${votes['${g.seat}'] == true ? "赞成处决" : "反对"}），等待其余玩家表决…'),
        ),
      );
    }
    final amAlive = g.seat >= 0 && g.seat < alive.length ? alive[g.seat] : true;
    final haveGhost = g.seat >= 0 && g.seat < ghostVote.length ? ghostVote[g.seat] : false;
    if (!amAlive && !haveGhost) {
      return const SizedBox.shrink();
    }
    final nominee = (v['nominee'] as num?)?.toInt() ?? 0;

    return Card(
      color: cs.surface.withValues(alpha: 0.94),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '是否赞成处决 ${g.name(nominee)}？${amAlive ? "" : "（注意：死亡玩家投赞成票将消耗唯一的死人票👻）"}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            FilledButton.icon(
              onPressed: () => g.act({'type': 'vote', 'yes': true}),
              icon: const Icon(Icons.pan_tool, size: 16),
              label: Text(amAlive ? '举手赞成' : '消耗死人票赞成👻'),
            ),
            OutlinedButton.icon(
              onPressed: () => g.act({'type': 'vote', 'yes': false}),
              icon: const Icon(Icons.close, size: 16),
              label: const Text('不举手（反对）'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayControls(GameContext g, ColorScheme cs, Map<String, dynamic> v, List<bool> alive, bool compact) {
    final amAlive = g.seat >= 0 && g.seat < alive.length ? alive[g.seat] : false;
    final nominatedBy = (v['nominatedBy'] as List?)?.cast<int>() ?? const <int>[];
    final nominatedTargets = (v['nominatedTargets'] as List?)?.cast<int>() ?? const <int>[];
    final dayPassed = (v['dayPassed'] as List?)?.cast<int>() ?? const <int>[];
    final slayerUsed = (v['slayerUsed'] as List?)?.cast<int>() ?? const <int>[];

    return Card(
      color: cs.surface.withValues(alpha: 0.92),
      child: Padding(
        padding: EdgeInsets.all(compact ? 8 : 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Speech input row (both living and dead players can speak!)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatCtrl,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '发表你的白天推理、报查验或对跳声明…',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (txt) {
                      if (txt.trim().isNotEmpty) {
                        g.act({'type': 'speak', 'text': txt.trim()});
                        _chatCtrl.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () {
                    final txt = _chatCtrl.text.trim();
                    if (txt.isNotEmpty) {
                      g.act({'type': 'speak', 'text': txt});
                      _chatCtrl.clear();
                    } else {
                      g.act({'type': 'speak', 'text': '我是好人，建议大家公开情报找出恶魔！'});
                    }
                  },
                  child: const Text('发言'),
                ),
              ],
            ),
            if (amAlive) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'nominate', label: Text('提名处决', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'slayer', label: Text('猎手开枪', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_dayActionMode},
                    onSelectionChanged: (s) => setState(() => _dayActionMode = s.first),
                  ),
                  for (var s = 0; s < g.players; s++)
                    if (s < alive.length && alive[s])
                      ChoiceChip(
                        visualDensity: VisualDensity.compact,
                        label: Text('${s + 1}号 ${g.name(s)}', style: const TextStyle(fontSize: 11.5)),
                        selected: _selectedTarget == s,
                        onSelected: (sel) => setState(() => _selectedTarget = sel ? s : -1),
                      ),
                  if (_dayActionMode == 'nominate')
                    FilledButton(
                      onPressed: (!nominatedBy.contains(g.seat) &&
                              _selectedTarget >= 0 &&
                              !nominatedTargets.contains(_selectedTarget))
                          ? () {
                              g.act({'type': 'nominate', 'target': _selectedTarget});
                              setState(() => _selectedTarget = -1);
                            }
                          : null,
                      child: const Text('发起提名'),
                    )
                  else
                    FilledButton(
                      onPressed: (!slayerUsed.contains(g.seat) && _selectedTarget >= 0)
                          ? () {
                              g.act({'type': 'slayer', 'target': _selectedTarget});
                              setState(() => _selectedTarget = -1);
                            }
                          : null,
                      child: const Text('发动猎手射击'),
                    ),
                  if (!dayPassed.contains(g.seat))
                    OutlinedButton(
                      onPressed: () => g.act({'type': 'skip_day'}),
                      child: const Text('结束提名/入夜'),
                    )
                  else
                    const Text('已准备入夜…', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogsSection(ColorScheme cs, List<String> myNotes, List<String> publicLog, bool compact) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (myNotes.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('🔮 我的私密线索簿', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: cs.onPrimaryContainer)),
                  const SizedBox(height: 4),
                  for (final n in myNotes.reversed.take(compact ? 3 : 5))
                    Text('• $n', style: TextStyle(fontSize: 11.5, color: cs.onPrimaryContainer)),
                ],
              ),
            ),
          ),
        if (publicLog.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 640),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🔔 钟楼广场公告', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  for (final line in publicLog.reversed.take(compact ? 3 : 6))
                    Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5)),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
