import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _suspects = [
  '🎩 魔术师·红礼帽',
  '🤡 小丑·彩球',
  '🦁 驯兽师·金鞭',
  '🎪 空中飞人·蓝羽',
  '🔮 占卜师·紫水晶',
  '🗡️ 飞刀手·银刃',
  '🔥 吞火者·烈焰',
  '🎭 哑剧演员·白面',
  '🥁 乐队指挥·绿礼服',
];

const List<String> _locations = [
  '⛺ 主帐篷·红顶',
  '🎡 摩天轮·彩灯',
  '🦁 猛兽笼·金锁',
  '🎠 旋转木马·蓝顶',
  '🔮 占卜篷车·紫帘',
  '🎯 飞镖摊·银靶',
  '🍿 爆米花车·火炉',
  '🪞 哈哈镜迷宫·白镜',
  '🎟️ 售票亭·绿窗',
];

const List<String> _visions = [
  '🌹 猩红玫瑰与高帽',
  '🎈 彩绘气球与笑脸',
  '👑 黄金狮爪与锁链',
  '🕊️ 蔚蓝飞鸟与秋千',
  '🌙 紫夜星辰与水晶',
  '⚡ 寒光利刃与标靶',
  '🔥 炽热火炬与浓烟',
  '🪞 苍白假面与镜影',
  '🎺 翠绿号角与节拍',
  '🩸 暗红丝绒与魔杖',
  '🌟 金黄彩带与滚球',
  '🐯 咆哮猛虎与铁笼',
  '☁️ 高空云梯与蓝羽',
  '🕯️ 神秘紫烛与塔罗',
  '🗡️ 旋转银刀与木牌',
  '💥 爆裂火星与铜炉',
  '🎭 双面石膏与迷廊',
  '🥁 盛装乐鼓与绿帐',
];

class MysteriumParkBoard extends StatefulWidget {
  final GameContext g;
  const MysteriumParkBoard(this.g, {super.key});

  @override
  State<MysteriumParkBoard> createState() => _MysteriumParkBoardState();
}

class _MysteriumParkBoardState extends State<MysteriumParkBoard> {
  int _selectedPsychic = 1;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final guideSeat = (v['guideSeat'] as num?)?.toInt() ?? 0;
    final stage = (v['stage'] as num?)?.toInt() ?? 1;
    final phase = v['phase'] as String? ?? 'clue';
    final turnUsed = (v['turnUsed'] as num?)?.toInt() ?? 1;
    final maxTurns = (v['maxTurns'] as num?)?.toInt() ?? 6;
    final suspects = (v['suspects'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.generate(9, (i) => i);
    final locations = (v['locations'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.generate(9, (i) => i);
    final gridCleared = (v['gridCleared'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(9, false);
    final stageSolved = (v['stageSolved'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, false);
    final currentClue = (v['currentClue'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List<int?>.filled(g.players, null);
    final currentGuess = (v['currentGuess'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List<int?>.filled(g.players, null);
    final witnessSlot = (v['witnessSlot'] as num?)?.toInt();
    final targetSlot = (v['targetSlot'] as List?)?.map((e) => (e as num).toInt()).toList();
    final guideHand = (v['guideHand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final finaleCandidates = (v['finaleCandidates'] as List?) ?? const [];
    final finaleClues = (v['finaleClues'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final waitingFor = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = waitingFor.contains(g.seat) && !g.over;
    final stageTitle = stage == 1
        ? '第 1 轮：调查嫌疑人'
        : stage == 2
            ? '第 2 轮：调查马戏团地点'
            : '第 3 轮：终局真凶指认';

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '诡秘马戏团 — 调查结束'
                          : '$stageTitle · 回合 $turnUsed/$maxTurns · ${isMyTurn ? "请执行你的行动" : "等待行动中"}',
                      highlight: isMyTurn,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (stage <= 2) ...[
                    // 3x3 Investigation Matrix
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stage == 1
                                ? '🎪 3×3 嫌疑人矩阵（猜中 👁️ 目击者可立即重猜）：'
                                : '🎠 3×3 案发地点矩阵（猜中 👁️ 目击者可立即重猜）：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var slot = 0; slot < 9; slot++)
                                _buildGridCard(
                                  g: g,
                                  cs: cs,
                                  slot: slot,
                                  label: stage == 1
                                      ? _suspects[suspects[slot] % _suspects.length]
                                      : _locations[locations[slot] % _locations.length],
                                  cleared: slot < gridCleared.length && gridCleared[slot],
                                  isWitness: witnessSlot == slot,
                                  assignedTo: targetSlot != null
                                      ? [
                                          for (var p = 0; p < g.players; p++)
                                            if (p != guideSeat && p < targetSlot.length && targetSlot[p] == slot)
                                              g.name(p),
                                        ]
                                      : const [],
                                  guessedBy: [
                                    for (var p = 0; p < g.players; p++)
                                      if (p < currentGuess.length && currentGuess[p] == slot) g.name(p),
                                  ],
                                  canGuess: isMyTurn &&
                                      phase == 'guess' &&
                                      !(slot < gridCleared.length && gridCleared[slot]) &&
                                      !currentGuess.contains(slot),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Guide Hand Panel (if Guide)
                    if (g.seat == guideSeat && phase == 'clue' && !g.over)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '👻 幽灵馆长手牌（选择一名未破案通灵师并点击幻景卡发放线索）：',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var s = 0; s < g.players; s++)
                                  if (s != guideSeat && !stageSolved[s] && currentClue[s] == null)
                                    ChoiceChip(
                                      label: Text('通灵师: ${g.name(s)}'),
                                      selected: _selectedPsychic == s,
                                      onSelected: (_) => setState(() => _selectedPsychic = s),
                                    ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (final vId in guideHand)
                                  FilledButton.tonal(
                                    onPressed: () {
                                      final targetP = (
                                              _selectedPsychic != guideSeat &&
                                              _selectedPsychic < g.players &&
                                              !stageSolved[_selectedPsychic] &&
                                              currentClue[_selectedPsychic] == null)
                                          ? _selectedPsychic
                                          : [
                                              for (var s = 0; s < g.players; s++)
                                                if (s != guideSeat && !stageSolved[s] && currentClue[s] == null) s,
                                            ].firstOrNull ??
                                              1;
                                      g.act({'type': 'clue', 'seat': targetP, 'vision': vId});
                                    },
                                    child: Text(_visions[vId % _visions.length]),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ] else ...[
                    // Round 3 Finale Panel
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🔮 终局 3 张幻景线索：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final vId in finaleClues)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _visions[vId % _visions.length],
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onSecondaryContainer,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '🕵️ 3 组最终候选（点击投票指认幕后真凶）：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var i = 0; i < finaleCandidates.length; i++)
                                _buildFinaleCandidate(
                                  g,
                                  cs,
                                  i,
                                  finaleCandidates[i] as Map,
                                  isMyTurn && phase == 'finale',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Players & Vision Clues
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: waitingFor.contains(s) && !g.over
                                  ? cs.primary
                                  : cs.outline.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              g.tag(
                                s,
                                active: waitingFor.contains(s) && !g.over,
                                sub: '${s == guideSeat ? "👻 幽灵馆长" : "🔮 通灵师"} · ${scores[s]} 分',
                              ),
                              if (s != guideSeat && s < currentClue.length && currentClue[s] != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '当前线索: ${_visions[currentClue[s]! % _visions.length]}',
                                  style: TextStyle(fontSize: 11, color: cs.primary, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '游戏结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildGridCard({
    required GameContext g,
    required ColorScheme cs,
    required int slot,
    required String label,
    required bool cleared,
    required bool isWitness,
    required List<String> assignedTo,
    required List<String> guessedBy,
    required bool canGuess,
  }) {
    final box = Container(
      width: 145,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cleared
            ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
            : cs.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: canGuess ? cs.primary : cs.outline.withValues(alpha: 0.3),
          width: canGuess ? 1.8 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#${slot + 1} $label',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              decoration: cleared ? TextDecoration.lineThrough : null,
              color: cleared ? cs.onSurface.withValues(alpha: 0.45) : cs.onPrimaryContainer,
            ),
          ),
          if (isWitness)
            const Text('👁️ 无辜目击者', style: TextStyle(fontSize: 11, color: Colors.amber)),
          if (assignedTo.isNotEmpty)
            Text('🎯 目标: ${assignedTo.join(",")}', style: const TextStyle(fontSize: 11)),
          if (guessedBy.isNotEmpty)
            Text('🔮 猜测: ${guessedBy.join(",")}', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
    if (!canGuess) return box;
    return InkWell(
      onTap: () => g.act({'type': 'guess', 'slot': slot}),
      borderRadius: BorderRadius.circular(10),
      child: box,
    );
  }

  Widget _buildFinaleCandidate(
    GameContext g,
    ColorScheme cs,
    int idx,
    Map cand,
    bool canVote,
  ) {
    final sId = (cand['suspect'] as num?)?.toInt() ?? 0;
    final lId = (cand['location'] as num?)?.toInt() ?? 0;
    final box = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canVote ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '候选 #${idx + 1}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
          ),
          Text(_suspects[sId % _suspects.length], style: const TextStyle(fontSize: 12)),
          Text(_locations[lId % _locations.length], style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
    if (!canVote) return box;
    return InkWell(
      onTap: () => g.act({'type': 'vote', 'candidate': idx}),
      borderRadius: BorderRadius.circular(10),
      child: box,
    );
  }
}
