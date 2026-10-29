import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<(String, String, Color)> _lootColors = [
  ('🟦', '蓝海盗', Color(0xFF1E88E5)),
  ('🟩', '绿海盗', Color(0xFF43A047)),
  ('🟨', '黄海盗', Color(0xFFFDD835)),
  ('🟥', '红海盗', Color(0xFFE53935)),
];

class LootBoard extends StatefulWidget {
  final GameContext g;
  const LootBoard(this.g, {super.key});

  @override
  State<LootBoard> createState() => _LootBoardState();
}

class _LootBoardState extends State<LootBoard> {
  int _selectedCardIdx = -1;

  String _cardTitle(Map c) {
    final kind = '${c['kind'] ?? 'pirate'}';
    final col = (c['color'] as num?)?.toInt() ?? -1;
    final val = (c['value'] as num?)?.toInt() ?? 0;
    final str = (c['strength'] as num?)?.toInt() ?? 1;
    if (kind == 'merchant') {
      return '⛵ 商船 $val💰';
    }
    if (kind == 'admiral') {
      return '⚓ 海军上将 (+5)';
    }
    final colInfo = (col >= 0 && col < 4) ? _lootColors[col] : _lootColors[0];
    if (kind == 'captain') {
      return '🏴‍☠️ ${colInfo.$1}${colInfo.$2}船长 (+5)';
    }
    return '${colInfo.$1}${colInfo.$2} (+$str)';
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final gold = (v['gold'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final capturedShips = (v['capturedShips'] as List?) ?? const [];
    final myHand = (v['myHand'] as List?) ?? const [];
    final ships = (v['ships'] as List?) ?? const [];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    if (_selectedCardIdx >= myHand.length) {
      _selectedCardIdx = -1;
    }

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
                          ? '海盗劫掠船 — 远航结束'
                          : '第 $round 轮 · 🃏牌库:$deckCount · ${canAct ? "轮到你行动 (摸牌/放商船/派海盗)" : "等待 ${g.name(turn)} 行动"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Active Merchant Ships on the Sea
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '🌊 海面争夺中的黄金商船 (${ships.length} 艘)',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                            ),
                            if (canAct)
                              FilledButton.tonal(
                                onPressed: () => g.act({'type': 'draw'}),
                                child: Text(
                                  deckCount > 0 ? '🃏 摸 1 张牌 ($deckCount)' : '⏭️ 整理过牌',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (ships.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Center(
                              child: Text(
                                '当前海面风平浪静，快从手牌放出黄金商船 (⛵ 2~8💰) 吧！',
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.7)),
                              ),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (var sIdx = 0; sIdx < ships.length; sIdx++)
                                _buildShipCard(
                                  g: g,
                                  cs: cs,
                                  sIdx: sIdx,
                                  ship: ships[sIdx] as Map,
                                  canAct: canAct,
                                  myHand: myHand,
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // My Hand Panel
                  if (g.seat >= 0)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🃏 我的手牌 (${myHand.length} 张 · 点击商船直接驶入海面，点击海盗卡选择后进攻目标商船)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          const SizedBox(height: 8),
                          if (myHand.isEmpty)
                            const Text('手牌已打空！', style: TextStyle(fontSize: 12))
                          else
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                for (var cIdx = 0; cIdx < myHand.length; cIdx++)
                                  _buildHandCardButton(
                                    g: g,
                                    cs: cs,
                                    cIdx: cIdx,
                                    card: myHand[cIdx] as Map,
                                    canAct: canAct,
                                    ships: ships,
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '💰${s < gold.length ? gold[s] : 0}金 · ⛵${s < capturedShips.length ? (capturedShips[s] as List).length : 0}艘 · 🃏${s < handCounts.length ? handCounts[s] : 0}张',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '海盗劫掠船结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildShipCard({
    required GameContext g,
    required ColorScheme cs,
    required int sIdx,
    required Map ship,
    required bool canAct,
    required List myHand,
  }) {
    final val = (ship['value'] as num?)?.toInt() ?? 4;
    final owner = (ship['owner'] as num?)?.toInt() ?? 0;
    final leader = (ship['leader'] as num?)?.toInt() ?? -1;
    final attacks = (ship['attacks'] as Map?) ?? const {};
    final colors = (ship['colors'] as Map?) ?? const {};

    final canAttackWithSelected = canAct &&
        _selectedCardIdx >= 0 &&
        _selectedCardIdx < myHand.length &&
        (myHand[_selectedCardIdx] as Map)['kind'] != 'merchant';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canAttackWithSelected
            ? () {
                final cIdx = _selectedCardIdx;
                setState(() => _selectedCardIdx = -1);
                g.act({'type': 'attack', 'shipIdx': sIdx, 'cardIdx': cIdx});
              }
            : null,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.secondaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canAttackWithSelected ? cs.primary : cs.outline.withValues(alpha: 0.35),
              width: canAttackWithSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '⛵ 黄金商船 $val💰',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    leader >= 0 ? '👑领先:${g.name(leader)}' : '⚖️平局僵持',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '放出者: ${g.name(owner)}',
                style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
              ),
              const SizedBox(height: 4),
              if (attacks.isEmpty)
                const Text('尚无海盗进攻（放出者回合开始将直接入库）', style: TextStyle(fontSize: 11))
              else
                for (final entry in attacks.entries)
                   Builder(builder: (context) {
                    final s = int.tryParse('${entry.key}') ?? 0;
                    final str = entry.value;
                    final col = (colors['${entry.key}'] as num?)?.toInt() ?? -1;
                    final colLabel = (col >= 0 && col < 4)
                        ? '${_lootColors[col].$1}${_lootColors[col].$2}'
                        : '⚓上将';
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '• ${g.name(s)}: $colLabel 战力 $str',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    );
                  }),
              if (canAttackWithSelected) ...[
                const SizedBox(height: 6),
                Text(
                  '⚔️ 点击派遣所选海盗进攻此船',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHandCardButton({
    required GameContext g,
    required ColorScheme cs,
    required int cIdx,
    required Map card,
    required bool canAct,
    required List ships,
  }) {
    final kind = '${card['kind'] ?? 'pirate'}';
    final isSelected = _selectedCardIdx == cIdx;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: !canAct
          ? null
          : () {
              if (kind == 'merchant') {
                g.act({'type': 'launch', 'cardIdx': cIdx});
              } else if (ships.length == 1) {
                g.act({'type': 'attack', 'shipIdx': 0, 'cardIdx': cIdx});
              } else {
                setState(() {
                  _selectedCardIdx = isSelected ? -1 : cIdx;
                });
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? cs.primaryContainer
              : (kind == 'merchant'
                  ? Colors.amber.withValues(alpha: 0.25)
                  : cs.surfaceContainerHighest.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Text(
          _cardTitle(card),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? cs.onPrimaryContainer : cs.onSurface,
          ),
        ),
      ),
    );
  }
}
