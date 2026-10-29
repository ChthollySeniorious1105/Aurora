import 'package:flutter/material.dart';
import '../../widgets/common.dart';

class ShadowHuntersBoard extends StatefulWidget {
  final GameContext g;
  const ShadowHuntersBoard(this.g, {super.key});

  @override
  State<ShadowHuntersBoard> createState() => _ShadowHuntersBoardState();
}

class _ShadowHuntersBoardState extends State<ShadowHuntersBoard> {
  int? _selectedTarget;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rawPlayers = (v['players'] as List?) ?? const [];
    final playerViews = [
      for (final p in rawPlayers)
        if (p is Map) p.cast<String, dynamic>()
    ];
    final rawZones = (v['zones'] as List?) ?? const [];
    final zoneViews = [
      for (final z in rawZones)
        if (z is Map) z.cast<String, dynamic>()
    ];
    final hermitClues = [
      for (final c in (v['hermitClues'] as List? ?? const [])) '$c'
    ];
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'move';
    final attackableTargets = [
      for (final t in (v['attackableTargets'] as List? ?? const []))
        (t as num).toInt()
    ];
    final lastActionText = (v['lastActionText'] as String?) ?? '';
    final over = v['over'] == true || g.over;
    final winSummary = (v['winSummary'] as String?) ?? '';

    final myTurn = !over && g.seat == turn;
    final myData =
        (g.seat >= 0 && g.seat < playerViews.length) ? playerViews[g.seat] : null;
    final myRevealed = myData?['revealed'] == true;
    final myAlive = myData?['alive'] != false;

    final targetSeat = (_selectedTarget != null &&
            _selectedTarget != g.seat &&
            _selectedTarget! < playerViews.length &&
            playerViews[_selectedTarget!]['alive'] == true)
        ? _selectedTarget!
        : (attackableTargets.isNotEmpty ? attackableTargets.first : -1);

    final statusStr = over
        ? '暗影猎人对局结束'
        : myTurn
            ? (phase == 'move'
                ? '轮到你：请选择要前往的区域（0~5）'
                : '轮到你：可发动攻击、揭示身份或结束回合')
            : '等待 ${g.name(turn)} 行动...';

    return Container(
      color: g.table,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                StatusBar(statusStr, highlight: myTurn),
                if (myData != null)
                  _factionChip(
                    cs,
                    '我的身份: ${myData['roleName']} (${_factionName(myData['faction'] as String? ?? '?')})',
                    _factionColor(myData['faction'] as String? ?? '?'),
                  ),
              ],
            ),
            if (lastActionText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                lastActionText,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
              ),
            ],
            if (over) ...[
              const SizedBox(height: 8),
              Center(
                child: ResultBanner(
                  winSummary.isNotEmpty ? winSummary : '对局结束',
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Action bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surface.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
                  width: myTurn ? 2 : 1,
                ),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (myTurn && phase == 'move')
                    FilledButton.icon(
                      icon: const Icon(Icons.casino, size: 16),
                      label: const Text('掷骰随机移动'),
                      onPressed: () => g.act({'type': 'move', 'target': targetSeat}),
                    ),
                  if (myTurn && myAlive && !myRevealed)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bolt, size: 16),
                      label: Text('揭示身份：${myData?['skillName'] ?? "觉醒"}'),
                      onPressed: () =>
                          g.act({'type': 'reveal', 'target': targetSeat}),
                    ),
                  if (myTurn && phase == 'action' && targetSeat >= 0)
                    FilledButton.icon(
                      icon: const Icon(Icons.gavel, size: 16),
                      label: Text('⚔️ 攻击 ${g.name(targetSeat)}'),
                      onPressed: () =>
                          g.act({'type': 'attack', 'target': targetSeat}),
                    ),
                  if (myTurn && phase == 'action')
                    OutlinedButton.icon(
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('结束回合'),
                      onPressed: () => g.act({'type': 'end_turn'}),
                    ),
                  if (!myTurn && !over)
                    Text(
                      '提示：点击任意角色卡片可将其设为技能/攻击目标',
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            // 6 Area Zones
            const Text(
              '🗺️ 六大领地（点击区域可在移动阶段前往）：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final z in zoneViews)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 185, maxWidth: 300),
                    child: _buildZoneCard(
                      g: g,
                      cs: cs,
                      zone: z,
                      playerViews: playerViews,
                      canMoveHere: myTurn && phase == 'move',
                      targetSeat: targetSeat,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Player Character Cards
            const Text(
              '👥 在场角色状态（点击角色可锁定为目标）：',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in playerViews)
                  ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 250, maxWidth: 360),
                    child: _buildPlayerCard(
                      g: g,
                      cs: cs,
                      p: p,
                      isTurn: !over && turn == (p['seat'] as num).toInt(),
                      isSelectedTarget: targetSeat == (p['seat'] as num).toInt(),
                      zoneViews: zoneViews,
                    ),
                  ),
              ],
            ),
            if (hermitClues.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.surface.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔍 隐士木屋推理线索记录：',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    for (final clue in hermitClues.reversed.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          clue,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: cs.onSurface.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _factionName(String f) {
    if (f == 'shadow') return '暗影';
    if (f == 'hunter') return '猎人';
    if (f == 'neutral') return '中立';
    return '未知';
  }

  Color _factionColor(String f) {
    if (f == 'shadow') return Colors.purpleAccent;
    if (f == 'hunter') return Colors.blueAccent;
    if (f == 'neutral') return Colors.amber.shade700;
    return Colors.blueGrey;
  }

  Widget _factionChip(ColorScheme cs, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: cs.onSurface,
        ),
      ),
    );
  }

  Widget _buildZoneCard({
    required GameContext g,
    required ColorScheme cs,
    required Map<String, dynamic> zone,
    required List<Map<String, dynamic>> playerViews,
    required bool canMoveHere,
    required int targetSeat,
  }) {
    final zId = (zone['id'] as num?)?.toInt() ?? 0;
    final zName = (zone['name'] as String?) ?? '';
    final zDesc = (zone['desc'] as String?) ?? '';
    final zIcon = (zone['icon'] as String?) ?? '📍';

    final occupants = [
      for (final p in playerViews)
        if (p['alive'] == true && (p['zone'] as num?)?.toInt() == zId)
          (p['seat'] as num).toInt()
    ];

    return GestureDetector(
      onTap: canMoveHere
          ? () => g.act({'type': 'move', 'zone': zId, 'target': targetSeat})
          : null,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canMoveHere
                ? cs.primary.withValues(alpha: 0.7)
                : cs.outline.withValues(alpha: 0.3),
            width: canMoveHere ? 1.8 : 1.0,
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
                    '$zIcon [$zId] $zName',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (canMoveHere)
                  Icon(Icons.directions_walk, size: 16, color: cs.primary),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              zDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            if (occupants.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final s in occupants)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        g.name(s),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerCard({
    required GameContext g,
    required ColorScheme cs,
    required Map<String, dynamic> p,
    required bool isTurn,
    required bool isSelectedTarget,
    required List<Map<String, dynamic>> zoneViews,
  }) {
    final seat = (p['seat'] as num).toInt();
    final roleName = (p['roleName'] as String?) ?? '神秘角色';
    final faction = (p['faction'] as String?) ?? '?';
    final maxHp = (p['maxHp'] as num?)?.toInt();
    final dmg = (p['damage'] as num?)?.toInt() ?? 0;
    final alive = p['alive'] == true;
    final revealed = p['revealed'] == true;
    final zoneIdx = (p['zone'] as num?)?.toInt() ?? 0;
    final equips = (p['equipments'] as List?) ?? const [];
    final atkBonus = (p['atkBonus'] as num?)?.toInt() ?? 0;
    final defBonus = (p['defBonus'] as num?)?.toInt() ?? 0;
    final skillName = (p['skillName'] as String?) ?? '???';
    final skillDesc = (p['skillDesc'] as String?) ?? '';

    final zoneName =
        zoneIdx >= 0 && zoneIdx < zoneViews.length ? zoneViews[zoneIdx]['name'] : '区域$zoneIdx';
    final fColor = _factionColor(faction);

    return GestureDetector(
      onTap: alive && seat != g.seat
          ? () => setState(() => _selectedTarget = seat)
          : null,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: alive ? 0.9 : 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelectedTarget
                ? Colors.redAccent
                : isTurn
                    ? cs.primary
                    : fColor.withValues(alpha: 0.45),
            width: (isSelectedTarget || isTurn) ? 2.2 : 1.2,
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
                  child: g.tag(
                    seat,
                    active: isTurn,
                    sub: '📍 $zoneName ${alive ? "" : "· 💀已阵亡"}',
                    size: 30,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$roleName (${_factionName(faction)})${revealed ? " · 已揭示" : ""}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  maxHp != null
                      ? '❤️ 伤害: $dmg / $maxHp HP'
                      : '🩸 已受伤害: $dmg 点',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: dmg >= 8 ? Colors.redAccent : cs.onSurface,
                  ),
                ),
                if (atkBonus > 0)
                  Text('🗡️ 攻+$atkBonus', style: const TextStyle(fontSize: 11.5)),
                if (defBonus > 0)
                  Text('🛡️ 防+$defBonus', style: const TextStyle(fontSize: 11.5)),
              ],
            ),
            if (skillDesc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                '技能【$skillName】：$skillDesc',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onSurface.withValues(alpha: 0.78),
                ),
              ),
            ],
            if (equips.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final eq in equips)
                    if (eq is Map)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (eq['type'] == 'white'
                                  ? Colors.amber
                                  : Colors.deepPurple)
                              .withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${eq['type'] == 'white' ? '⚪' : '⚫'}${eq['name']}',
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
