import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CashNGunsBoard extends StatefulWidget {
  final GameContext g;
  const CashNGunsBoard(this.g, {super.key});

  @override
  State<CashNGunsBoard> createState() => _CashNGunsBoardState();
}

class _CashNGunsBoardState extends State<CashNGunsBoard> {
  String _selectedBullet = 'click';
  int _selectedTarget = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 8;
    final phase = (v['phase'] as String?) ?? 'aim';
    final godfather = (v['godfather'] as num?)?.toInt() ?? 0;
    final wounds = ((v['wounds'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final alive = ((v['alive'] as List?) ?? const []).map((e) => e == true).toList();
    final myAmmo = ((v['myAmmo'] as List?) ?? const []).map((e) => e.toString()).toList();
    final myAimTarget = (v['myAimTarget'] as num?)?.toInt() ?? -1;
    final myCourage = v['myCourage'] as String?;
    final aimTargets = ((v['aimTargets'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final ducked = ((v['ducked'] as List?) ?? const []).map((e) => e == true).toList();
    final woundedThisRound = ((v['woundedThisRound'] as List?) ?? const []).map((e) => e == true).toList();
    final revealedBullets = ((v['revealedBullets'] as List?) ?? const []).map((e) => e?.toString()).toList();
    final tableLoot = ((v['tableLoot'] as List?) ?? const []).cast<Map>();
    final lootTurn = (v['lootTurn'] as num?)?.toInt() ?? -1;
    final totalCash = ((v['totalCash'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final diamondCounts = ((v['diamondCounts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final paintingCounts = ((v['paintingCounts'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();
    final lastEvent = (v['lastEvent'] as String?) ?? '';
    final placings = ((v['placings'] as List?) ?? const []).map((e) => (e as num).toInt()).toList();

    final amIAlive = g.seat >= 0 && g.seat < alive.length && alive[g.seat];
    final needMyAim = !g.over && phase == 'aim' && amIAlive && myAimTarget < 0;
    final needMyCourage = !g.over && phase == 'courage' && amIAlive && myCourage == null;
    final needMyLoot = !g.over && phase == 'loot' && lootTurn == g.seat;

    if (!myAmmo.contains(_selectedBullet) && myAmmo.isNotEmpty) {
      _selectedBullet = myAmmo.first;
    }
    if (_selectedTarget < 0 || _selectedTarget == g.seat || (_selectedTarget < alive.length && !alive[_selectedTarget])) {
      for (var s = 0; s < g.players; s++) {
        if (s != g.seat && s < alive.length && alive[s]) {
          _selectedTarget = s;
          break;
        }
      }
    }

    String statusText;
    if (g.over) {
      statusText = '分赃完毕！查看最终财富榜';
    } else if (phase == 'aim') {
      statusText = needMyAim ? '阶段 1 [举枪瞄准]：选择子弹并瞄准一名对手' : '等待其他玩家完成瞄准…';
    } else if (phase == 'courage') {
      statusText = needMyCourage ? '阶段 2 [生死抉择]：选择【坚守】或【卧倒】！' : '等待被瞄准的玩家做出抉择…';
    } else {
      statusText = needMyLoot ? '阶段 3 [分赃]：请点击桌面上的 1 张战利品拿取' : '等待 ${g.name(lootTurn)} 挑选战利品…';
    }

    return Container(
      color: g.table,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        StatusBar(statusText, highlight: needMyAim || needMyCourage || needMyLoot),
                        Text(
                          '第 $round / $maxRounds 轮 · 🎩 教父: ${g.name(godfather)}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
                        ),
                      ],
                    ),
                    if (lastEvent.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        lastEvent,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                      ),
                    ],
                    if (g.over) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: ResultBanner(
                          '分赃结算',
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var s = 0; s < g.players; s++)
                                Text(
                                  '${g.name(s)}：\$${s < totalCash.length ? totalCash[s] : 0} '
                                  '(${s < alive.length && alive[s] ? "幸存" : "💀 中弹出局"}) '
                                  '${s < placings.length && placings[s] == 1 ? "🏆" : ""}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Table Loot Cards
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.78),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '本轮桌面战利品 (${tableLoot.length} 张)${needMyLoot ? " — 点击任意战利品直接拿取！" : ""}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < tableLoot.length; i++)
                                ActionChip(
                                  label: Text('${tableLoot[i]['name']}'),
                                  onPressed: needMyLoot ? () => g.act({'type': 'loot', 'index': i}) : null,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Players Standoff Grid
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final s in g.seatsFromMe())
                          _buildPlayerBox(
                            cs: cs,
                            seat: s,
                            isGodfather: s == godfather,
                            woundCnt: s < wounds.length ? wounds[s] : 0,
                            isAlive: s < alive.length ? alive[s] : true,
                            targetSeat: s < aimTargets.length ? aimTargets[s] : -1,
                            isDucked: s < ducked.length && ducked[s],
                            wasWounded: s < woundedThisRound.length && woundedThisRound[s],
                            bullet: s < revealedBullets.length ? revealedBullets[s] : null,
                            cash: s < totalCash.length ? totalCash[s] : 0,
                            diamonds: s < diamondCounts.length ? diamondCounts[s] : 0,
                            paintings: s < paintingCounts.length ? paintingCounts[s] : 0,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Action Controls for current player
                    if (needMyAim) _buildAimControls(cs, myAmmo, alive),
                    if (needMyCourage) _buildCourageControls(cs, aimTargets),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlayerBox({
    required ColorScheme cs,
    required int seat,
    required bool isGodfather,
    required int woundCnt,
    required bool isAlive,
    required int targetSeat,
    required bool isDucked,
    required bool wasWounded,
    required String? bullet,
    required int cash,
    required int diamonds,
    required int paintings,
  }) {
    final targetStr = targetSeat >= 0 ? '🔫 瞄准 ${g.name(targetSeat)}' : '准备中…';
    final statusBadge = !isAlive
        ? '💀 已淘汰'
        : (isDucked ? '🏳️ 已卧倒' : (wasWounded ? '🩸 中弹负伤' : ''));
    final bulletBadge = bullet == null ? '' : (bullet == 'bang' ? '💥 实弹' : '💬 空包弹');

    return Container(
      width: 230,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: isAlive ? 0.85 : 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          g.tag(
            seat,
            active: false,
            sub: '${isGodfather ? "🎩教父 · " : ""}伤势 $woundCnt/3 · \$$cash',
            size: 30,
          ),
          const SizedBox(height: 4),
          Text(
            '💎×$diamonds  🖼️×$paintings  $targetStr',
            style: const TextStyle(fontSize: 12),
          ),
          if (statusBadge.isNotEmpty || bulletBadge.isNotEmpty)
            Text(
              '$statusBadge $bulletBadge'.trim(),
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildAimControls(ColorScheme cs, List<String> myAmmo, List<bool> alive) {
    final clickCnt = myAmmo.where((b) => b == 'click').length;
    final bangCnt = myAmmo.where((b) => b == 'bang').length;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('选择本轮上膛子弹与瞄准对象：', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (clickCnt > 0)
                ChoiceChip(
                  label: Text('💬 空包弹 Click (剩 $clickCnt)'),
                  selected: _selectedBullet == 'click',
                  onSelected: (_) => setState(() => _selectedBullet = 'click'),
                ),
              if (bangCnt > 0)
                ChoiceChip(
                  label: Text('💥 实弹 Bang (剩 $bangCnt)'),
                  selected: _selectedBullet == 'bang',
                  onSelected: (_) => setState(() => _selectedBullet = 'bang'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var s = 0; s < g.players; s++)
                if (s != g.seat && s < alive.length && alive[s])
                  ChoiceChip(
                    label: Text('瞄准 ${g.name(s)}'),
                    selected: _selectedTarget == s,
                    onSelected: (_) => setState(() => _selectedTarget = s),
                  ),
              FilledButton.icon(
                onPressed: _selectedTarget >= 0
                    ? () => g.act({'type': 'aim', 'target': _selectedTarget, 'bullet': _selectedBullet})
                    : null,
                icon: const Icon(Icons.gps_fixed, size: 16),
                label: const Text('确认举枪'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCourageControls(ColorScheme cs, List<int> aimTargets) {
    final aimingAtMe = <String>[
      for (var s = 0; s < aimTargets.length; s++)
        if (aimTargets[s] == g.seat) g.name(s),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            aimingAtMe.isEmpty ? '无人瞄准你！' : '⚠️ 正将枪口对准你的人：${aimingAtMe.join("、")}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.error),
          ),
          FilledButton.icon(
            onPressed: () => g.act({'type': 'courage', 'choice': 'stay'}),
            icon: const Icon(Icons.shield, size: 16),
            label: const Text('勇敢坚守 (Stay)'),
          ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'courage', 'choice': 'duck'}),
            icon: const Icon(Icons.airline_seat_flat, size: 16),
            label: const Text('保命卧倒 (Duck)'),
          ),
        ],
      ),
    );
  }
}
