import 'package:aurora_shared/games/party17/broom_service.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class BroomServiceBoard extends StatefulWidget {
  final GameContext g;
  const BroomServiceBoard(this.g, {super.key});

  @override
  State<BroomServiceBoard> createState() => _BroomServiceBoardState();
}

class _BroomServiceBoardState extends State<BroomServiceBoard> {
  final Set<int> _draftRoles = {0, 1, 4, 7};

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final trick = (v['trick'] as num?)?.toInt() ?? 1;
    final phase = v['phase'] as String? ?? 'select';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final ledRole = (v['ledRole'] as num?)?.toInt() ?? -1;
    final braveSeat = (v['braveSeat'] as num?)?.toInt() ?? -1;
    final myHand = (v['myHand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final potions = (v['potions'] as List?) ?? const [];
    final wands = (v['wands'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 2);
    final clouds = (v['clouds'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final witchRegion = (v['witchRegion'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 3);
    final regionTokens = (v['regionTokens'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const [3, 3, 3, 3, 3, 3, 2, 2];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 10);
    final trickPlays = (v['trickPlays'] as List?) ?? const [];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

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
                          ? '魔女速递 — 配送完成'
                          : '第 $round/$maxRounds 轮 (第 $trick 墩) · ${phase == "select" ? "挑选 4 张角色卡" : (phase == "lead" ? "领出角色卡" : "跟出同名角色")} · ${canAct ? "轮到你行动" : "等待 ${g.name(turn)}"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.88)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // 8 Realm Regions
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
                        Text(
                          '🗺️ 王国八大疆域（高塔魔药订单与雷暴云海）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (var i = 0; i < kBroomRegions.length; i++)
                              _buildRegionTile(
                                g: g,
                                cs: cs,
                                reg: kBroomRegions[i],
                                tokens: i < regionTokens.length ? regionTokens[i] : 2,
                                witchRegion: witchRegion,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Role Selection or Trick Table & Hand
                  if (phase == 'select' && canAct)
                    _buildRoleSelector(g, cs)
                  else
                    _buildTrickAndHandSection(
                      g: g,
                      cs: cs,
                      phase: phase,
                      ledRole: ledRole,
                      braveSeat: braveSeat,
                      myHand: myHand,
                      trickPlays: trickPlays,
                      canAct: canAct,
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
                          active: (phase == 'select' || turn == s) && !g.over,
                          sub: _playerSub(s, potions, wands, clouds, scores),
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

  String _playerSub(int s, List potions, List<int> wands, List<int> clouds, List<int> scores) {
    var p0 = 1, p1 = 1, p2 = 1;
    if (s < potions.length && potions[s] is List) {
      final l = potions[s] as List;
      if (l.length >= 3) {
        p0 = (l[0] as num).toInt();
        p1 = (l[1] as num).toInt();
        p2 = (l[2] as num).toInt();
      }
    }
    final w = s < wands.length ? wands[s] : 0;
    final c = s < clouds.length ? clouds[s] : 0;
    final sc = s < scores.length ? scores[s] : 0;
    return '🟪$p0 🟧$p1 🟩$p2 · 🪄$w · 🌩️$c · ⭐$sc分';
  }

  Widget _buildRegionTile({
    required GameContext g,
    required ColorScheme cs,
    required BroomRegionInfo reg,
    required int tokens,
    required List<int> witchRegion,
  }) {
    final pEmoji = reg.potionType == 0
        ? '🟪'
        : (reg.potionType == 1 ? '🟧' : (reg.potionType == 2 ? '🟩' : '🌩️'));
    final witchesHere = <String>[
      for (var s = 0; s < witchRegion.length; s++)
        if (witchRegion[s] == reg.id) 'P${s + 1}',
    ];
    return Container(
      width: 145,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${reg.emoji}${reg.name} ($pEmoji+${reg.baseVp}分)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          Text(
            '剩余高塔/云层:$tokens${witchesHere.isNotEmpty ? " · 🧙${witchesHere.join(",")}" : ""}',
            style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector(GameContext g, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '🃏 请选择 4 张本轮角色卡（已选 ${_draftRoles.length}/4）：',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                ),
              ),
              FilledButton(
                onPressed: _draftRoles.length == 4
                    ? () => g.act({'type': 'select', 'roles': _draftRoles.toList()..sort()})
                    : null,
                child: const Text('确认选牌'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final role in kBroomRoles)
                InkWell(
                  onTap: () {
                    setState(() {
                      if (_draftRoles.contains(role.id)) {
                        _draftRoles.remove(role.id);
                      } else if (_draftRoles.length < 4) {
                        _draftRoles.add(role.id);
                      }
                    });
                  },
                  child: Container(
                    width: 165,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _draftRoles.contains(role.id)
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _draftRoles.contains(role.id) ? cs.primary : cs.outline.withValues(alpha: 0.3),
                        width: _draftRoles.contains(role.id) ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${role.emoji} ${role.name}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text('⚔️勇敢: ${role.braveDesc}', style: const TextStyle(fontSize: 10)),
                        Text('🛡️稳妥: ${role.cowardDesc}', style: const TextStyle(fontSize: 10)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrickAndHandSection({
    required GameContext g,
    required ColorScheme cs,
    required String phase,
    required int ledRole,
    required int braveSeat,
    required List<int> myHand,
    required List trickPlays,
    required bool canAct,
  }) {
    return Container(
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
            ledRole >= 0 && ledRole < kBroomRoles.length
                ? '🔥 当前领出角色: ${kBroomRoles[ledRole].emoji}${kBroomRoles[ledRole].name} · 勇敢席位: ${braveSeat >= 0 ? g.name(braveSeat) : "暂无"}'
                : '🔥 等待领出本墩角色卡…',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
          ),
          if (trickPlays.isNotEmpty) ...[
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in trickPlays)
                  if (p is Map)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        '${g.name((p["seat"] as num?)?.toInt() ?? 0)}: ${p["mode"] == "brave" ? (p["cancelled"] == true ? "⚔️勇敢(被截胡❌)" : "⚔️勇敢宣告") : "🛡️稳妥执行"}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '🖐️ 我的手牌 (${myHand.length} 张)：',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final rId in myHand)
                if (rId >= 0 && rId < kBroomRoles.length)
                  _buildPlayableRoleCard(
                    g: g,
                    cs: cs,
                    role: kBroomRoles[rId],
                    playable: canAct &&
                        (phase == 'lead' || (phase == 'follow' && rId == ledRole)),
                  ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayableRoleCard({
    required GameContext g,
    required ColorScheme cs,
    required BroomRoleInfo role,
    required bool playable,
  }) {
    return Container(
      width: 185,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: playable ? cs.secondaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: playable ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${role.emoji} ${role.name}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text('⚔️勇敢: ${role.braveDesc}', style: const TextStyle(fontSize: 10)),
          Text('🛡️稳妥: ${role.cowardDesc}', style: const TextStyle(fontSize: 10)),
          if (playable) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: () => g.act({'type': 'play', 'role': role.id, 'mode': 'brave'}),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('⚔️勇敢')),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                    onPressed: () => g.act({'type': 'play', 'role': role.id, 'mode': 'coward'}),
                    child: const FittedBox(fit: BoxFit.scaleDown, child: Text('🛡️稳妥')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
