import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class WelcomeToBoard extends StatefulWidget {
  final GameContext g;
  const WelcomeToBoard(this.g, {super.key});

  @override
  State<WelcomeToBoard> createState() => _WelcomeToBoardState();
}

class _WelcomeToBoardState extends State<WelcomeToBoard> {
  int _selectedCombo = 0;
  int _delta = 0;
  int _estateSize = 2;
  int _fenceIdx = -1;

  static const List<IconData> _effectIcons = [
    Icons.fence,
    Icons.trending_up,
    Icons.park,
    Icons.pool,
    Icons.engineering,
  ];

  static const List<Color> _effectColors = [
    Color(0xFF5D4037),
    Color(0xFF7B1FA2),
    Color(0xFF2E7D32),
    Color(0xFF0288D1),
    Color(0xFFE65100),
  ];

  bool _canWrite(List<int> row, int slot, int finalNum) {
    if (slot < 0 || slot >= row.length) return false;
    if (finalNum < 1 || finalNum > 17) return false;
    if (row[slot] != 0) return false;
    for (var i = 0; i < slot; i++) {
      if (row[i] > 0 && row[i] >= finalNum) return false;
    }
    for (var i = slot + 1; i < row.length; i++) {
      if (row[i] > 0 && row[i] <= finalNum) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 20;
    final combos = (v['combos'] as List?)?.cast<Map>() ?? const <Map>[];
    final poolPlans = (v['poolPlans'] as List?)
            ?.map((r) => (r as List).map((e) => (e as num).toInt()).toSet())
            .toList() ??
        [const <int>{}, const <int>{}, const <int>{}];
    final houses = (v['houses'] as List?)
            ?.map((r) => (r as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        const <List<int>>[];
    final fences = (v['fences'] as List?)
            ?.map((r) => (r as List).map((e) => e == true).toList())
            .toList() ??
        const <List<bool>>[];
    final pools = (v['pools'] as List?)
            ?.map((r) => (r as List).map((e) => e == true).toList())
            .toList() ??
        const <List<bool>>[];
    final parks = (v['parks'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0, 0];
    final estateLevels = (v['estateLevels'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(6, 0);
    final refusals = (v['refusals'] as num?)?.toInt() ?? 0;
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final acted = (v['acted'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final waiting = (v['waitingFor'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final breakdown = (v['breakdown'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final cityPlans = (v['cityPlans'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastEvent = v['lastEvent'] as String? ?? '';

    if (_selectedCombo >= combos.length) _selectedCombo = 0;
    final curCombo = combos.isNotEmpty ? combos[_selectedCombo] : null;
    final baseNum = (curCombo?['number'] as num?)?.toInt() ?? 1;
    final curEffect = (curCombo?['effect'] as num?)?.toInt() ?? 0;
    final finalNum = curEffect == 4 ? (baseNum + _delta).clamp(1, 17) : baseNum;

    final myTurn = g.seat >= 0 && waiting.contains(g.seat) && !g.over;

    final statusText = g.over
        ? '社区建设结束！'
        : myTurn
            ? '第 $round/$maxRounds 轮：请选择上方工程组合，再点击街道空位填入 $finalNum 号房'
            : '第 $round/$maxRounds 轮：等待其他建筑师完成规划…';

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
                  Center(child: StatusBar(statusText, highlight: myTurn)),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Players bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        g.tag(
                          s,
                          active: waiting.contains(s),
                          size: 30,
                          sub: '${scores[s]}分 · ${acted[s] ? "✓已规划" : "规划中"}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 3 Combinations + Effect controls
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.86),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('本轮可选组合：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            for (var i = 0; i < combos.length; i++)
                              _buildComboCard(
                                cs,
                                index: i,
                                number: (combos[i]['number'] as num?)?.toInt() ?? 1,
                                effect: (combos[i]['effect'] as num?)?.toInt() ?? 0,
                                effectName: '${combos[i]['effectName']}',
                                selected: _selectedCombo == i,
                              ),
                            if (myTurn)
                              OutlinedButton.icon(
                                onPressed: () => g.act({'type': 'refuse'}),
                                icon: const Icon(Icons.block, size: 16),
                                label: Text('拒签许可 ($refusals/3)'),
                              ),
                          ],
                        ),
                        if (curEffect == 4) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('临时工门牌微调：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (final d in const [-2, -1, 0, 1, 2])
                                ChoiceChip(
                                  label: Text('${d >= 0 ? "+$d" : "$d"} (${(baseNum + d).clamp(1, 17)})'),
                                  selected: _delta == d,
                                  onSelected: (_) => setState(() => _delta = d),
                                ),
                            ],
                          ),
                        ],
                        if (curEffect == 1) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Text('选择升值地产规模：', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              for (var sz = 1; sz <= 6; sz++)
                                ChoiceChip(
                                  label: Text('$sz栋 (Lv.${estateLevels[sz - 1]})'),
                                  selected: _estateSize == sz,
                                  onSelected: (_) => setState(() => _estateSize = sz),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // 3 Streets Sheet
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: myTurn ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var st = 0; st < houses.length; st++) ...[
                          if (st > 0) const SizedBox(height: 8),
                          _buildStreetRow(
                            cs,
                            g,
                            street: st,
                            rowHouses: houses[st],
                            rowFences: fences[st],
                            rowPools: pools[st],
                            poolPlanSet: poolPlans[st],
                            parkCount: parks[st],
                            maxParks: st + 3,
                            finalNum: finalNum,
                            curEffect: curEffect,
                            myTurn: myTurn,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Score Breakdown & City Plans
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Text('🌳 公园: ${breakdown['parks'] ?? 0}分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('🏊 泳池: ${breakdown['pools'] ?? 0}分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('🏘️ 地产: ${breakdown['estates'] ?? 0}分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('📋 规划: ${breakdown['plans'] ?? 0}分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('👷 临时工: ${breakdown['temps'] ?? 0}分', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('⚠️ 拒签扣分: -${breakdown['penalty'] ?? 0}分', style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
                        Text('🏆 总计: ${breakdown['total'] ?? 0}分', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary)),
                        for (final p in cityPlans)
                          Text(
                            '📌 ${p['name']}: ${p['claimed'] == true ? "${p['later']}分" : "${p['first']}分"}',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Center(
              child: ResultBanner(
                _winnerText(g, scores),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('${g.name(s)}：${scores[s]} 分'),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _winnerText(GameContext g, List<int> scores) {
    var best = -1;
    for (final s in scores) {
      if (s > best) best = s;
    }
    final winners = [
      for (var i = 0; i < g.players; i++)
        if (scores[i] == best) g.name(i),
    ];
    return '${winners.join("、")} 获胜！（$best 分）';
  }

  Widget _buildComboCard(
    ColorScheme cs, {
    required int index,
    required int number,
    required int effect,
    required String effectName,
    required bool selected,
  }) {
    final safeEff = effect.clamp(0, 4);
    final color = _effectColors[safeEff];
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() {
        _selectedCombo = index;
        _delta = 0;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.18) : cs.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? color : cs.outline.withValues(alpha: 0.4), width: selected ? 2.5 : 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(width: 8),
            Icon(_effectIcons[safeEff], size: 18, color: color),
            const SizedBox(width: 4),
            Text(effectName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildStreetRow(
    ColorScheme cs,
    GameContext g, {
    required int street,
    required List<int> rowHouses,
    required List<bool> rowFences,
    required List<bool> rowPools,
    required Set<int> poolPlanSet,
    required int parkCount,
    required int maxParks,
    required int finalNum,
    required int curEffect,
    required bool myTurn,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('第 ${street + 1} 街（${rowHouses.length} 栋）', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text('🌳 公园：$parkCount / $maxParks', style: const TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Left street boundary fence
              Container(width: 4, height: 46, color: cs.primary),
              for (var sl = 0; sl < rowHouses.length; sl++) ...[
                _buildHouseCell(
                  cs,
                  g,
                  street: street,
                  slot: sl,
                  val: rowHouses[sl],
                  hasPoolPlan: poolPlanSet.contains(sl),
                  poolBuilt: rowPools[sl],
                  validWrite: myTurn && _canWrite(rowHouses, sl, finalNum),
                  finalNum: finalNum,
                  curEffect: curEffect,
                  rowFences: rowFences,
                ),
                // Right boundary or interior fence
                GestureDetector(
                  onTap: curEffect == 0 && sl < rowHouses.length - 1
                      ? () => setState(() => _fenceIdx = sl)
                      : null,
                  child: Container(
                    width: 6,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: rowFences[sl]
                          ? cs.primary
                          : (_fenceIdx == sl && curEffect == 0)
                              ? Colors.amber
                              : cs.outline.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHouseCell(
    ColorScheme cs,
    GameContext g, {
    required int street,
    required int slot,
    required int val,
    required bool hasPoolPlan,
    required bool poolBuilt,
    required bool validWrite,
    required int finalNum,
    required int curEffect,
    required List<bool> rowFences,
  }) {
    final filled = val > 0;
    return GestureDetector(
      onTap: validWrite
          ? () {
              var f = _fenceIdx;
              if (curEffect == 0 && (f < 0 || f >= rowFences.length - 1)) {
                f = slot < rowFences.length - 1 ? slot : slot - 1;
              }
              g.act({
                'type': 'build',
                'combo': _selectedCombo,
                'street': street,
                'slot': slot,
                'fence': f,
                'estateSize': _estateSize,
                'delta': curEffect == 4 ? _delta : 0,
              });
            }
          : null,
      child: Container(
        width: 40,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          color: filled
              ? cs.secondaryContainer
              : validWrite
                  ? cs.primaryContainer.withValues(alpha: 0.55)
                  : cs.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: validWrite ? cs.primary : cs.outline.withValues(alpha: 0.4),
            width: validWrite ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (hasPoolPlan)
              Icon(
                Icons.pool,
                size: 12,
                color: poolBuilt ? Colors.blue : Colors.blueGrey.withValues(alpha: 0.45),
              ),
            Text(
              filled ? '$val' : (validWrite ? '+$finalNum' : '·'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: filled ? 15 : 11,
                color: filled
                    ? cs.onSecondaryContainer
                    : validWrite
                        ? cs.primary
                        : cs.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
