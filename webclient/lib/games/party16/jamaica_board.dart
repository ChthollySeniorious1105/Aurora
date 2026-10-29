import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _trackSpaces = [
  '0 ⚓皇家港',
  '1 🍞朗姆湾(-2粮)',
  '2 🪙浅滩(-2金)',
  '3 🏴‍☠️海盗穴(+宝箱)',
  '4 🍞暗礁(-2粮)',
  '5 🪙沉船湾(-3金)',
  '6 🏴‍☠️岩洞(+宝箱)',
  '7 🍞渔港(-3粮)',
  '8 🪙税关(-3金)',
  '9 🏴‍☠️幽灵坞(+宝箱)',
  '10 🍞香蕉湾(-2粮)',
  '11 🪙珊瑚矿(-4金)',
  '12 🏴‍☠️三角洲(+宝箱)',
  '13 🍞甘蔗码(-3粮)',
  '14 🪙走私港(-4金)',
  '15 🏴‍☠️要塞(+宝箱)',
  '16 🍞风暴峡(-3粮)',
  '17 🪙外海(-3金)',
  '18 🏁冲线皇家港',
];

const List<String> _cardLabels = [
  '☀️装金币 · 🌙扬帆前进',
  '☀️装干粮 · 🌙扬帆前进',
  '☀️装火药 · 🌙扬帆前进',
  '☀️全速前进 · 🌙乘风破浪',
  '☀️扬帆前进 · 🌙装金币',
  '☀️扬帆前进 · 🌙装干粮',
  '☀️扬帆前进 · 🌙装火药',
  '☀️装金币 · 🌙装干粮',
  '☀️战术倒船 · 🌙装金币',
];

class JamaicaBoard extends StatefulWidget {
  final GameContext g;
  const JamaicaBoard(this.g, {super.key});

  @override
  State<JamaicaBoard> createState() => _JamaicaBoardState();
}

class _JamaicaBoardState extends State<JamaicaBoard> {
  int _selectedHold = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 10;
    final captain = (v['captain'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'roll';
    final rolledDice = (v['rolledDice'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [3, 4];
    final morningVal = (v['morningVal'] as num?)?.toInt() ?? 3;
    final eveningVal = (v['eveningVal'] as num?)?.toInt() ?? 4;
    final pos = (v['pos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final treasures = (v['treasures'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final holds = (v['holds'] as List?) ?? const [];
    final hand = (v['hand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final combatAttacker = (v['combatAttacker'] as num?)?.toInt();
    final combatDefender = (v['combatDefender'] as num?)?.toInt();
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final waitingFor = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = waitingFor.contains(g.seat) && !g.over;

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
                          ? '牙买加海盗赛船 — 航程结束'
                          : '第 $round/$maxRounds 轮 · 船长 ${g.name(captain)} · ☀️晨=$morningVal 🌙暮=$eveningVal · ${isMyTurn ? "请执行你的行动" : "等待其他船长"}',
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
                  // Captain Dice Assignment or Naval Combat Panel
                  if (phase == 'roll' && isMyTurn)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🎲 船长掷出双骰 $rolledDice，请指定晨昏点数：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          FilledButton.tonal(
                            onPressed: () => g.act({
                              'type': 'assign_dice',
                              'morning': rolledDice[0],
                              'evening': rolledDice[1],
                            }),
                            child: Text('☀️晨=${rolledDice[0]} / 🌙暮=${rolledDice[1]}'),
                          ),
                          if (rolledDice[0] != rolledDice[1])
                            FilledButton.tonal(
                              onPressed: () => g.act({
                                'type': 'assign_dice',
                                'morning': rolledDice[1],
                                'evening': rolledDice[0],
                              }),
                              child: Text('☀️晨=${rolledDice[1]} / 🌙暮=${rolledDice[0]}'),
                            ),
                        ],
                      ),
                    ),
                  if (phase == 'combat' && isMyTurn)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.errorContainer.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.error),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚔️ 海上火炮交战：${combatAttacker != null ? g.name(combatAttacker) : "?"} VS ${combatDefender != null ? g.name(combatDefender) : "?"}！请选择投入的 💣 火药数量：',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: cs.onErrorContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (var p = 0; p <= _myPowder(g.seat, holds); p++)
                                FilledButton(
                                  onPressed: () => g.act({'type': 'combat', 'powder': p}),
                                  child: Text('投入 $p 💣 火药'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  if (phase == 'choose' && isMyTurn && hand.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.86),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🃏 选择装载目标货舱并打出 1 张行动卡（☀️晨=$morningVal，🌙暮=$eveningVal）：',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var h = 0; h < 3; h++)
                                ChoiceChip(
                                  label: Text('货舱 #${h + 1}'),
                                  selected: _selectedHold == h,
                                  onSelected: (_) => setState(() => _selectedHold = h),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final cId in hand)
                                FilledButton.tonal(
                                  onPressed: () => g.act({
                                    'type': 'play',
                                    'card': cId,
                                    'hold': _selectedHold,
                                  }),
                                  child: Text(_cardLabels[cId % _cardLabels.length]),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  // 18-Space Circular Island Track
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🗺️ 牙买加环形海岛航道（共 18 格，率先绕岛一圈返回皇家港）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var sp = 0; sp < _trackSpaces.length; sp++)
                              _buildSpaceChip(g, cs, sp, pos),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players & 3 Cargo Holds
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
                                sub: '⛵ 航位 ${pos[s]}/18 · 🏴‍☠️宝箱×${treasures[s]} · ${scores[s]}分',
                              ),
                              const SizedBox(height: 4),
                              if (s < holds.length)
                                Text(
                                  '三舱: ${_holdsText(holds[s] as List)}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                                ),
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

  int _myPowder(int seat, List holds) {
    if (seat < 0 || seat >= holds.length) return 0;
    final myHolds = holds[seat] as List;
    var sum = 0;
    for (final h in myHolds) {
      if (h is Map && h['type'] == 'powder') {
        sum += (h['amount'] as num).toInt();
      }
    }
    return sum;
  }

  String _holdsText(List myHolds) {
    final parts = <String>[];
    for (var i = 0; i < myHolds.length; i++) {
      final h = myHolds[i] as Map;
      final t = h['type'] as String? ?? 'empty';
      final amt = (h['amount'] as num?)?.toInt() ?? 0;
      if (t == 'empty' || amt <= 0) {
        parts.add('[舱${i + 1}:空]');
      } else {
        final icon = t == 'gold'
            ? '🪙金'
            : t == 'food'
                ? '🍞粮'
                : '💣药';
        parts.add('[舱${i + 1}:$icon×$amt]');
      }
    }
    return parts.join(' ');
  }

  Widget _buildSpaceChip(GameContext g, ColorScheme cs, int sp, List<int> pos) {
    final shipsHere = [
      for (var s = 0; s < g.players; s++)
        if (s < pos.length && pos[s] == sp) g.name(s),
    ];
    final hasShips = shipsHere.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: hasShips
            ? cs.primaryContainer
            : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasShips ? cs.primary : cs.outline.withValues(alpha: 0.25),
        ),
      ),
      child: Text(
        hasShips ? '${_trackSpaces[sp]} [⛵${shipsHere.join(",")}]' : _trackSpaces[sp],
        style: TextStyle(
          fontSize: 11,
          fontWeight: hasShips ? FontWeight.bold : FontWeight.normal,
          color: hasShips ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
  }
}
