import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class SimiloBoard extends StatefulWidget {
  final GameContext g;
  const SimiloBoard(this.g, {super.key});

  @override
  State<SimiloBoard> createState() => _SimiloBoardState();
}

class _SimiloBoardState extends State<SimiloBoard> {
  int _selectedClueIdx = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'clue';
    final quotaLeft = (v['quotaLeft'] as num?)?.toInt() ?? 1;
    final remainingCount = (v['remainingCount'] as num?)?.toInt() ?? 12;
    final secretTarget = (v['secretTarget'] as num?)?.toInt();
    final grid = (v['grid'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final clueHand = (v['clueHand'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final clues = (v['clues'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? <int>{};
    final myTurn = waiting.contains(g.seat) && !g.over;

    String statusText;
    if (g.over) {
      statusText = (v['resultText'] as String?) ?? '游戏结束';
    } else if (phase == 'clue') {
      statusText = myTurn
          ? '第 ${round + 1}/5 轮：请从手牌选择1张角色，以【竖放相似】或【横放不同】打出提示！'
          : '第 ${round + 1}/5 轮：等待线索人 ${g.name(0)} 出牌提示…';
    } else {
      statusText = myTurn
          ? '第 ${round + 1}/5 轮：请点击下方12宫格排除非目标角色（本轮还需排除 $quotaLeft 张）！'
          : '第 ${round + 1}/5 轮：等待猜词人排除嫌疑角色（还需排除 $quotaLeft 张）…';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header & Players
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(statusText, highlight: myTurn),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🔍 剩余角色：$remainingCount / 12 · 本轮需排除：$quotaLeft 张',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        g.tag(
                          s,
                          active: waiting.contains(s),
                          sub: s == 0 ? '🔮 线索人' : '🕵️ 猜词人',
                          size: 30,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Clues History Strip
                  if (clues.isNotEmpty) ...[
                    Text(
                      '📜 已给出的线索牌（竖放=与目标相似，横放=与目标不同）：',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final cl in clues) _buildClueBadge(cs, cl),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // 3x4 Grid of 12 Character Portraits
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final cols = constraints.maxWidth >= 560 ? 4 : 3;
                      final spacing = 6.0;
                      final itemW = (constraints.maxWidth - spacing * (cols - 1)) / cols;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (var i = 0; i < grid.length; i++)
                            SizedBox(
                              width: itemW,
                              child: _buildCharacterCard(
                                cs,
                                grid[i],
                                slot: i,
                                isSecretTarget: secretTarget == i,
                                canEliminate: myTurn && phase == 'eliminate' && grid[i]['eliminated'] != true,
                                onEliminate: () => g.act({'type': 'eliminate', 'slot': i}),
                              ),
                            ),
                        ],
                      );
                    },
                  ),

                  // Clue Giver Hand Controls
                  if (g.seat == 0 && clueHand.isNotEmpty && !g.over) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '🃏 线索人手牌 (${clueHand.length} 张) — 点选一张并宣告相似或不同：',
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              if (myTurn && phase == 'clue')
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    FilledButton.icon(
                                      onPressed: () {
                                        final idx = _selectedClueIdx.clamp(0, clueHand.length - 1);
                                        setState(() => _selectedClueIdx = 0);
                                        g.act({'type': 'clue', 'cardIdx': idx, 'similar': true});
                                      },
                                      icon: const Icon(Icons.swap_vert, size: 16),
                                      label: const Text('竖放：与目标相似'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () {
                                        final idx = _selectedClueIdx.clamp(0, clueHand.length - 1);
                                        setState(() => _selectedClueIdx = 0);
                                        g.act({'type': 'clue', 'cardIdx': idx, 'similar': false});
                                      },
                                      icon: const Icon(Icons.swap_horiz, size: 16),
                                      label: const Text('横放：与目标不同'),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < clueHand.length; i++)
                                ChoiceChip(
                                  label: Text(
                                    '${clueHand[i]['emoji']} ${clueHand[i]['name']} '
                                    '(${clueHand[i]['realm']}·${clueHand[i]['role']}·${clueHand[i]['era']}·战${clueHand[i]['power']})',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                  selected: _selectedClueIdx == i,
                                  onSelected: (_) => setState(() => _selectedClueIdx = i),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (g.over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(statusText),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClueBadge(ColorScheme cs, Map<String, dynamic> cl) {
    final c = cl['card'] as Map<String, dynamic>? ?? const {};
    final similar = cl['similar'] == true;
    final color = similar ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            similar ? '⬆️ 竖放·相似' : '↔️ 横放·不同',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'R${cl['round']} ${c['emoji']} ${c['name']} (${c['realm']}·${c['role']}·${c['era']}·战${c['power']})',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(
    ColorScheme cs,
    Map<String, dynamic> ch, {
    required int slot,
    required bool isSecretTarget,
    required bool canEliminate,
    required VoidCallback onEliminate,
  }) {
    final isElim = ch['eliminated'] == true;
    return Opacity(
      opacity: isElim ? 0.42 : 1.0,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: canEliminate ? onEliminate : null,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isSecretTarget
                ? Colors.amber.withValues(alpha: 0.25)
                : cs.surface.withValues(alpha: isElim ? 0.5 : 0.88),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSecretTarget
                  ? Colors.amber
                  : (canEliminate ? cs.primary : cs.outline.withValues(alpha: 0.3)),
              width: isSecretTarget ? 2.4 : (canEliminate ? 1.5 : 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '${ch['emoji']} ${ch['name']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        decoration: isElim ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ),
                  if (isSecretTarget)
                    const Text('⭐目标', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber))
                  else if (isElim)
                    const Text('❌排除', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${ch['realm']} · ${ch['role']}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.primary),
              ),
              Text(
                '${ch['era']} · 战力 ${ch['power']}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.75)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
