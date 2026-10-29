import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<(String, String, int)> _csSystems = [
  ('🚀', '鱼雷', 3),
  ('📡', '声呐', 3),
  ('🤫', '静音', 4),
  ('💣', '水雷', 3),
];

class CaptainSonarBoard extends StatefulWidget {
  final GameContext g;
  const CaptainSonarBoard(this.g, {super.key});

  @override
  State<CaptainSonarBoard> createState() => _CaptainSonarBoardState();
}

class _CaptainSonarBoardState extends State<CaptainSonarBoard> {
  int _selectedCharge = 0;
  String _weaponMode = 'none'; // 'none' | 'torpedo' | 'mine'

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 18;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final islands = (v['islands'] as List?) ?? const [];
    final hp = (v['hp'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 4);
    final sunk = (v['sunk'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(g.players, false);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final headingLog = (v['headingLog'] as List?) ?? const [];
    final charges = (v['charges'] as List?) ?? const [];
    final publicSector = (v['publicSector'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, -1);
    final myPos = (v['myPos'] as List?)?.map((e) => (e as num).toInt()).toList();
    final myTrail = (v['myTrail'] as List?) ?? const [];
    final myIntel = (v['myIntel'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final validDirs = (v['validDirs'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final lastExplosion = (v['lastExplosion'] as List?)?.map((e) => (e as num).toInt()).toList();
    final revealedSubPos = (v['revealedSubPos'] as List?) ?? const [];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    List<int> myCharges = const [0, 0, 0, 0];
    if (g.seat >= 0 && g.seat < charges.length) {
      myCharges = (charges[g.seat] as List).map((e) => (e as num).toInt()).toList();
    }
    final torpedoReady = myCharges.isNotEmpty && myCharges[0] >= 3;
    final sonarReady = myCharges.length > 1 && myCharges[1] >= 3;
    final silenceReady = myCharges.length > 2 && myCharges[2] >= 4;
    final mineReady = myCharges.length > 3 && myCharges[3] >= 3;

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
                          ? '深海潜艇战 — 海战结束'
                          : '第 $round/$maxRounds 轮 · ${canAct ? "轮到你的潜艇行动" : "等待 ${g.name(turn)} 潜行"}',
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
                  // Control Deck (when player is seated)
                  if (canAct)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.45)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('⚡ 充能系统:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (var i = 0; i < 4; i++)
                                ChoiceChip(
                                  label: Text(
                                    '${_csSystems[i].$1}${_csSystems[i].$2} (${myCharges[i]}/${_csSystems[i].$3})',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  selected: _selectedCharge == i,
                                  onSelected: (_) => setState(() => _selectedCharge = i),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('🧭 潜行方向:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (final (dir, label) in const [
                                ('N', '⬆️ 北(N)'),
                                ('S', '⬇️ 南(S)'),
                                ('W', '⬅️ 西(W)'),
                                ('E', '➡️ 东(E)'),
                              ])
                                FilledButton.tonal(
                                  onPressed: validDirs.contains(dir)
                                      ? () => g.act({'type': 'move', 'dir': dir, 'charge': _selectedCharge})
                                      : null,
                                  child: Text(label, style: const TextStyle(fontSize: 12)),
                                ),
                              OutlinedButton(
                                onPressed: () => g.act({'type': 'surface'}),
                                child: const Text('🌊 紧急上浮 (清尾迹/+1HP)', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          if (torpedoReady || sonarReady || silenceReady || mineReady) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                if (torpedoReady)
                                  FilledButton(
                                    onPressed: () => setState(
                                      () => _weaponMode = _weaponMode == 'torpedo' ? 'none' : 'torpedo',
                                    ),
                                    child: Text(
                                      _weaponMode == 'torpedo' ? '🎯 点击海图发射鱼雷 (取消)' : '🚀 准备发射鱼雷 (射程1~4)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (mineReady)
                                  FilledButton.tonal(
                                    onPressed: () => setState(
                                      () => _weaponMode = _weaponMode == 'mine' ? 'none' : 'mine',
                                    ),
                                    child: Text(
                                      _weaponMode == 'mine' ? '🎯 点击海图引爆水雷 (取消)' : '💣 准备引爆水雷 (射程1~2)',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                if (sonarReady)
                                  for (var s = 0; s < g.players; s++)
                                    if (s != g.seat && (s >= sunk.length || !sunk[s]))
                                      FilledButton.tonal(
                                        onPressed: () => g.act({'type': 'sonar', 'target': s}),
                                        child: Text('📡 声呐探测 ${g.name(s)}', style: const TextStyle(fontSize: 12)),
                                      ),
                                if (silenceReady)
                                  for (final dir in validDirs)
                                    FilledButton.tonal(
                                      onPressed: () => g.act({'type': 'silence', 'dir': dir, 'steps': 1}),
                                      child: Text('🤫 静音向$dir冲刺', style: const TextStyle(fontSize: 12)),
                                    ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 8x8 Ocean Grid & Public Direction Logs
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      // 8x8 Ocean Tactical Map
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              myPos != null
                                  ? '🗺️ 8×8 深海战术海图 · 我方坐标 (${myPos[0]},${myPos[1]}) 第${((myPos[0] >= 4 ? 2 : 0) + (myPos[1] >= 4 ? 1 : 0)) + 1}象限'
                                  : '🗺️ 8×8 深海战术海图 (第1~4象限)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                            ),
                            const SizedBox(height: 6),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var r = 0; r < 8; r++)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (var c = 0; c < 8; c++)
                                          _buildOceanCell(
                                            g: g,
                                            cs: cs,
                                            r: r,
                                            c: c,
                                            islands: islands,
                                            myPos: myPos,
                                            myTrail: myTrail,
                                            lastExplosion: lastExplosion,
                                            revealedSubPos: revealedSubPos,
                                            canAct: canAct,
                                            torpedoReady: torpedoReady,
                                            mineReady: mineReady,
                                          ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Public Heading Logs & Sonar Intel
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.86),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '📡 公开航向日志 & 充能状态',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary),
                              ),
                              const SizedBox(height: 6),
                              for (var s = 0; s < g.players; s++) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: cs.secondaryContainer.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${g.name(s)} · ❤️${s < hp.length ? hp[s] : 4}/4 HP · ${s < publicSector.length && publicSector[s] >= 0 ? "📍已知象限:${publicSector[s] + 1}" : "📍象限未知"}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '航向日志: ${s < headingLog.length && (headingLog[s] as List).isNotEmpty ? (headingLog[s] as List).join(" → ") : "(暂无记录)"}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      if (s < charges.length) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '充能: 🚀${(charges[s] as List)[0]}/3 · 📡${(charges[s] as List)[1]}/3 · 🤫${(charges[s] as List)[2]}/4 · 💣${(charges[s] as List)[3]}/3',
                                          style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                              if (myIntel.isNotEmpty) ...[
                                const Divider(height: 12),
                                Text(
                                  '🔐 我方声呐机密情报',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.tertiary),
                                ),
                                for (final line in myIntel.reversed.take(4))
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(line, style: const TextStyle(fontSize: 11)),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '${s < sunk.length && sunk[s] ? "💀已沉没" : "❤️${s < hp.length ? hp[s] : 4}HP"} · ⭐${s < scores.length ? scores[s] : 0}分',
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
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '深海潜艇战结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildOceanCell({
    required GameContext g,
    required ColorScheme cs,
    required int r,
    required int c,
    required List islands,
    required List<int>? myPos,
    required List myTrail,
    required List<int>? lastExplosion,
    required List revealedSubPos,
    required bool canAct,
    required bool torpedoReady,
    required bool mineReady,
  }) {
    final isIsland = r < islands.length &&
        c < (islands[r] as List).length &&
        (islands[r] as List)[c] == true;
    final isMySub = myPos != null && myPos.length >= 2 && myPos[0] == r && myPos[1] == c;
    var inMyTrail = false;
    for (final t in myTrail) {
      final tl = t as List;
      if (tl.length >= 2 && (tl[0] as num).toInt() == r && (tl[1] as num).toInt() == c) {
        inMyTrail = true;
        break;
      }
    }
    final isBoom = lastExplosion != null &&
        lastExplosion.length >= 2 &&
        lastExplosion[0] == r &&
        lastExplosion[1] == c;

    var revealedSeat = -1;
    for (var s = 0; s < revealedSubPos.length; s++) {
      final p = revealedSubPos[s] as List;
      if (p.length >= 2 && (p[0] as num).toInt() == r && (p[1] as num).toInt() == c) {
        revealedSeat = s;
        break;
      }
    }

    var canShootHere = false;
    if (canAct && myPos != null && myPos.length >= 2) {
      final dist = (myPos[0] - r).abs() + (myPos[1] - c).abs();
      if (_weaponMode == 'torpedo' && torpedoReady && dist >= 1 && dist <= 4) {
        canShootHere = true;
      } else if (_weaponMode == 'mine' && mineReady && dist >= 1 && dist <= 2) {
        canShootHere = true;
      }
    }

    final sectorIdx = (r >= 4 ? 2 : 0) + (c >= 4 ? 1 : 0);
    final rightSectorBorder = c == 3;
    final bottomSectorBorder = r == 3;

    String icon = '';
    if (isIsland) {
      icon = '🏝️';
    } else if (isMySub) {
      icon = '🚤';
    } else if (revealedSeat >= 0) {
      icon = '🛥️';
    } else if (isBoom) {
      icon = '💥';
    } else if (inMyTrail) {
      icon = '•';
    }

    return GestureDetector(
      onTap: canShootHere
          ? () {
              final type = _weaponMode == 'mine' ? 'mine' : 'torpedo';
              setState(() => _weaponMode = 'none');
              g.act({'type': type, 'r': r, 'c': c});
            }
          : null,
      child: Container(
        width: 36,
        height: 36,
        margin: EdgeInsets.only(
          right: rightSectorBorder ? 4 : 1,
          bottom: bottomSectorBorder ? 4 : 1,
        ),
        decoration: BoxDecoration(
          color: isIsland
              ? Colors.brown.withValues(alpha: 0.45)
              : isMySub
                  ? cs.primaryContainer
                  : canShootHere
                      ? Colors.redAccent.withValues(alpha: 0.35)
                      : (sectorIdx.isEven
                          ? cs.secondaryContainer.withValues(alpha: 0.45)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: canShootHere
                ? Colors.redAccent
                : isMySub
                    ? cs.primary
                    : cs.outline.withValues(alpha: 0.25),
            width: (canShootHere || isMySub) ? 1.8 : 0.8,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 1,
              left: 2,
              child: Text(
                '$r,$c',
                style: TextStyle(fontSize: 7, color: cs.onSurface.withValues(alpha: 0.45)),
              ),
            ),
            Center(
              child: Text(
                icon,
                style: TextStyle(
                  fontSize: inMyTrail && !isMySub ? 16 : 14,
                  fontWeight: FontWeight.bold,
                  color: cs.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
