import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class GoodCopBadCopBoard extends StatefulWidget {
  final GameContext g;
  const GoodCopBadCopBoard(this.g, {super.key});

  @override
  State<GoodCopBadCopBoard> createState() => _GoodCopBadCopBoardState();
}

class _GoodCopBadCopBoardState extends State<GoodCopBadCopBoard> {
  int? _selectedTarget;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final cards = (v['cards'] as List?) ?? const [];
    final revealed = (v['revealed'] as List?) ?? const [];
    final myFaction = v['myFaction'] as String?;
    final hp = (v['hp'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 1);
    final maxHp = (v['maxHp'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 1);
    final alive = (v['alive'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, true);
    final hasGun = (v['hasGun'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, false);
    final aimTarget = (v['aimTarget'] as List?)?.map((e) => (e as num?)?.toInt()).toList() ??
        List<int?>.filled(g.players, null);
    final equipDeckCount = (v['equipDeckCount'] as num?)?.toInt() ?? 0;
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = g.seat == turn && !g.over;
    final myArmed = g.seat >= 0 && g.seat < hasGun.length && hasGun[g.seat];
    final defaultTarget = _pickValidTarget(g, alive);

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
                          ? '无间警局 — 尘埃落定'
                          : (isMyTurn ? '轮到你行动（调查 / 装备 / 拔枪 / 开火）' : '等待 ${g.name(turn)} 行动'),
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
                  // Top Info & Action Panel
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
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (myFaction != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: myFaction == 'good'
                                      ? Colors.blue.withValues(alpha: 0.22)
                                      : Colors.red.withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  myFaction == 'good'
                                      ? '🛡️ 我的真实阵营：正义警探 (GOOD) — 寻找并击毙黑帮教父 KINGPIN'
                                      : '🕶️ 我的真实阵营：黑帮卧底 (BAD) — 寻找并击毙正义首领 AGENT',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: myFaction == 'good' ? Colors.lightBlueAccent : Colors.redAccent,
                                  ),
                                ),
                              ),
                            Text(
                              '🧰 装备牌库: $equipDeckCount 张',
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                        if (isMyTurn && defaultTarget != null) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('🎯 行动目标：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (var s = 0; s < g.players; s++)
                                if (s != g.seat && alive[s])
                                  ChoiceChip(
                                    label: Text(g.name(s), style: const TextStyle(fontSize: 11)),
                                    selected: defaultTarget == s,
                                    onSelected: (_) => setState(() => _selectedTarget = s),
                                  ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              FilledButton.tonalIcon(
                                onPressed: () => g.act({'type': 'investigate', 'target': defaultTarget}),
                                icon: const Icon(Icons.search, size: 16),
                                label: Text('调查 ${g.name(defaultTarget)}'),
                              ),
                              FilledButton.tonalIcon(
                                onPressed: () => g.act({'type': 'equip', 'target': defaultTarget}),
                                icon: const Icon(Icons.medical_services_outlined, size: 16),
                                label: const Text('翻牌抽装备'),
                              ),
                              if (!myArmed)
                                FilledButton.icon(
                                  onPressed: () => g.act({'type': 'arm', 'target': defaultTarget}),
                                  icon: const Icon(Icons.gps_fixed, size: 16),
                                  label: Text('🔫 拔枪瞄准 ${g.name(defaultTarget)}'),
                                )
                              else ...[
                                OutlinedButton.icon(
                                  onPressed: () => g.act({'type': 'aim', 'target': defaultTarget}),
                                  icon: const Icon(Icons.my_location, size: 16),
                                  label: Text('转瞄 ${g.name(defaultTarget)}'),
                                ),
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                  onPressed: () => g.act({
                                    'type': 'shoot',
                                    'target': aimTarget[g.seat] ?? defaultTarget,
                                  }),
                                  icon: const Icon(Icons.local_fire_department, size: 16),
                                  label: Text('💥 开枪射击 ${g.name(aimTarget[g.seat] ?? defaultTarget)}'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // All Players Grid
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        _buildPlayerPanel(
                          g,
                          cs,
                          s,
                          s < cards.length ? (cards[s] as List) : const [null, null, null],
                          s < revealed.length ? (revealed[s] as List) : const [false, false, false],
                          hp[s],
                          maxHp[s],
                          alive[s],
                          hasGun[s],
                          aimTarget[s],
                          turn == s && !g.over,
                          isMyTurn,
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

  int? _pickValidTarget(GameContext g, List<bool> alive) {
    if (_selectedTarget != null &&
        _selectedTarget! >= 0 &&
        _selectedTarget! < g.players &&
        _selectedTarget != g.seat &&
        alive[_selectedTarget!]) {
      return _selectedTarget;
    }
    for (var s = 0; s < g.players; s++) {
      if (s != g.seat && alive[s]) return s;
    }
    return null;
  }

  Widget _buildPlayerPanel(
    GameContext g,
    ColorScheme cs,
    int s,
    List seatCards,
    List seatRevealed,
    int hp,
    int maxHp,
    bool alive,
    bool armed,
    int? aim,
    bool active,
    bool isMyTurn,
  ) {
    final subParts = <String>[
      alive ? '❤️ $hp/$maxHp HP' : '💀 已出局',
      if (armed && aim != null) '🔫 瞄准 ${g.name(aim)}',
    ];
    return Container(
      width: 245,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: alive ? 0.82 : 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.25),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(s, active: active, sub: subParts.join(' · ')),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < 3; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    child: _integrityCardTile(
                      g,
                      cs,
                      s,
                      i,
                      i < seatCards.length ? seatCards[i] as String? : null,
                      i < seatRevealed.length && seatRevealed[i] == true,
                      isMyTurn && s != g.seat && alive,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _integrityCardTile(
    GameContext g,
    ColorScheme cs,
    int owner,
    int slot,
    String? card,
    bool isPublic,
    bool canInvestigate,
  ) {
    Color bg;
    String label;
    switch (card) {
      case 'AGENT':
        bg = const Color(0xFF0D47A1);
        label = '⭐ AGENT';
      case 'KINGPIN':
        bg = const Color(0xFFB71C1C);
        label = '👑 KINGPIN';
      case 'GOOD':
        bg = const Color(0xFF1976D2);
        label = '🛡️ GOOD';
      case 'BAD':
        bg = const Color(0xFFD32F2F);
        label = '🕶️ BAD';
      default:
        bg = cs.surfaceContainerHighest;
        label = '❓ 暗牌';
    }

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPublic ? Colors.amberAccent : Colors.white24,
          width: isPublic ? 1.8 : 1,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: card != null ? Colors.white : cs.onSurface,
              ),
            ),
            Text(
              isPublic ? '已公开' : (card != null ? '已知' : '点击调查'),
              style: TextStyle(
                fontSize: 8,
                color: card != null ? Colors.white70 : cs.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
    if (!canInvestigate) return tile;
    return InkWell(
      onTap: () => g.act({'type': 'investigate', 'target': owner, 'slot': slot}),
      child: tile,
    );
  }
}
