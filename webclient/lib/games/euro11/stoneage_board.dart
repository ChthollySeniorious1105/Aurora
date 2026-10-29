import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _greenNames = ['陶艺', '医药', '天文', '文字', '音乐', '纺织', '交通', '日晷'];

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<T> _asList<T>(Object? v) => v is List ? v.cast<T>() : <T>[];
Map<String, dynamic> _asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

class StoneAgeBoard extends StatefulWidget {
  final GameContext g;
  const StoneAgeBoard(this.g, {super.key});

  @override
  State<StoneAgeBoard> createState() => _StoneAgeBoardState();
}

class _StoneAgeBoardState extends State<StoneAgeBoard> {
  int workerCount = 1;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = '${v['phase']}';
    final over = phase == 'over';
    final turn = _asInt(v['turn']);
    final round = _asInt(v['round'], 1);
    final maxRounds = _asInt(v['maxRounds'], 8);
    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final placements = _asMap(v['placements']);
    final buildings = _asList<dynamic>(v['buildings']);
    final civCards = _asList<dynamic>(v['civCards']);
    final ps = _asList<dynamic>(v['players']).map(_asMap).toList();
    final myAvail = me >= 0 && me < ps.length ? _asInt(ps[me]['availableWorkers']) : 0;
    if (workerCount > max(1, myAvail)) workerCount = max(1, myAvail);

    final status = over
        ? '石器时代 · 部落文明终局结算'
        : phase == 'place'
            ? (myTurn
                ? '第 $round/$maxRounds 轮 [派遣族人] · 轮到你（剩余 $myAvail 族人）：选人数后点击地点派遣'
                : '第 $round/$maxRounds 轮 [派遣族人] · 等待 ${g.name(turn)} 派遣族人')
            : (myTurn
                ? '第 $round/$maxRounds 轮 [结算行动] · 轮到你结算族人收益与建筑/文明卡'
                : '第 $round/$maxRounds 轮 [结算行动] · 等待 ${g.name(turn)} 结算');

    String workersBadge(String loc) {
      final m = _asMap(placements[loc]);
      if (m.isEmpty) return '空';
      return m.entries.map((e) => 'P${(int.tryParse(e.key) ?? 0) + 1}×${e.value}').join(' ');
    }

    Widget locCard(String loc, String title, String subtitle, {int? fixedCount}) {
      final cnt = fixedCount ?? workerCount;
      final canTap = myTurn && phase == 'place' && myAvail >= cnt;
      final badge = workersBadge(loc);
      return GestureDetector(
        onTap: canTap ? () => g.act({'type': 'place', 'loc': loc, 'count': cnt}) : null,
        child: Container(
          width: 142,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canTap ? cs.primary.withValues(alpha: 0.7) : cs.outline.withValues(alpha: 0.3),
              width: canTap ? 1.6 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Text(subtitle, style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.75))),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('👥 $badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      );
    }

    Widget controlsBar() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (phase == 'place' && myTurn) ...[
              const Text('每次派遣人数:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              for (var k = 1; k <= min(5, max(1, myAvail)); k++)
                ChoiceChip(
                  label: Text('$k人', style: const TextStyle(fontSize: 11)),
                  selected: workerCount == k,
                  onSelected: (_) => setState(() => workerCount = k),
                ),
            ],
            if (phase == 'resolve' && myTurn)
              FilledButton.icon(
                onPressed: () => g.act({'type': 'resolve'}),
                icon: const Icon(Icons.casino, size: 16),
                label: const Text('一键投骰并结算本轮全部行动'),
              ),
          ],
        ),
      );
    }

    Widget buildingsAndCivPanel() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏠 建筑工坊（限1人 · 支付对应资源获分）与 📜 文明卡牌（限1人 · 按列支付1~4任意资源）：',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < buildings.length; i++)
                  Builder(builder: (_) {
                    final b = buildings[i] is Map ? _asMap(buildings[i]) : null;
                    if (b == null) return const SizedBox.shrink();
                    final cost = _asList<dynamic>(b['cost']).map(_asInt).toList();
                    final costStr = [
                      if ((cost.elementAtOrNull(0) ?? 0) > 0) '🪵${cost[0]}',
                      if ((cost.elementAtOrNull(1) ?? 0) > 0) '🧱${cost[1]}',
                      if ((cost.elementAtOrNull(2) ?? 0) > 0) '🪨${cost[2]}',
                      if ((cost.elementAtOrNull(3) ?? 0) > 0) '🪙${cost[3]}',
                    ].join(' ');
                    return locCard(
                      'building_$i',
                      '🏠 ${b['name']} (+${b['vp']}分)',
                      '消耗: $costStr',
                      fixedCount: 1,
                    );
                  }),
                for (var i = 0; i < civCards.length; i++)
                  Builder(builder: (_) {
                    final c = civCards[i] is Map ? _asMap(civCards[i]) : null;
                    if (c == null) return const SizedBox.shrink();
                    final gs = c['greenSymbol'] is num ? _asInt(c['greenSymbol']) : -1;
                    final bottomTxt = gs >= 0
                        ? '🌿科技: ${_greenNames[gs.clamp(0, 7)]}'
                        : '🏺倍率: ${c['multiplierTrack']}×${c['multiplierValue']}';
                    return locCard(
                      'civ_$i',
                      '📜 ${c['name']} (${i + 1}资源)',
                      '${c['immediateText']} · $bottomTxt',
                      fixedCount: 1,
                    );
                  }),
              ],
            ),
          ],
        ),
      );
    }

    Widget playersPanel() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final p in ps)
              Builder(builder: (_) {
                final s = _asInt(p['seat']);
                final syms = _asList<dynamic>(p['greenSymbols']).map(_asInt).toList();
                return g.tag(
                  s,
                  active: !over && turn == s,
                  size: 30,
                  sub: '${_asInt(p['score'])}分 | 🍖${_asInt(p['food'])} 🪵${_asInt(p['wood'])} 🧱${_asInt(p['brick'])} 🪨${_asInt(p['stone'])} 🪙${_asInt(p['gold'])} | 🌾${_asInt(p['agri'])} 🔨+${_asInt(p['tools'])} 👥${_asInt(p['availableWorkers'])}/${_asInt(p['workers'])} 🌿${syms.length}种',
                );
              }),
          ],
        ),
      );
    }

    Widget? banner;
    if (over) {
      final pl = _asList<dynamic>(v['placings']).map(_asInt).toList();
      final winners = [for (var s = 0; s < pl.length; s++) if (pl[s] == 1) g.name(s)];
      banner = ResultBanner(
        '${winners.join('、')} 统领远古部族！',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DataTable(
            headingRowHeight: 28,
            dataRowMinHeight: 24,
            dataRowMaxHeight: 28,
            columns: const [
              DataColumn(label: Text('玩家')),
              DataColumn(label: Text('建筑/基础')),
              DataColumn(label: Text('科技(K²)')),
              DataColumn(label: Text('人物倍率')),
              DataColumn(label: Text('余粮资源')),
              DataColumn(label: Text('总分')),
            ],
            rows: [
              for (final p in ps)
                DataRow(cells: [
                  DataCell(Text(g.name(_asInt(p['seat'])), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['baseVp'])}')),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['scienceVp'])} (${_asInt(_asMap(p['breakdown'])['scienceCount'])}²)')),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['multiplierVp'])}')),
                  DataCell(Text('${_asInt(_asMap(p['breakdown'])['resourceVp'])}')),
                  DataCell(Text('${_asInt(p['score'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StatusBar(status, highlight: myTurn),
                const SizedBox(height: 6),
                controlsBar(),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    locCard('field', '🌾 农田 (限1人)', '农业轨 +1 (免口粮)', fixedCount: 1),
                    locCard('tool', '🔨 工具坊 (限1人)', '工具值 +1 (采矿加点)', fixedCount: 1),
                    locCard('hut', '🛖 育儿屋 (需2人)', '部族人口上限 +1', fixedCount: 2),
                    locCard('hunt', '🏹 狩猎场 (不限)', '投骰 ÷2 获得 🍖食物'),
                    locCard('forest', '🌲 森林 (限7人)', '投骰 ÷3 获得 🪵木材'),
                    locCard('brick', '🧱 砖坑 (限7人)', '投骰 ÷4 获得 🧱砖块'),
                    locCard('stone', '🪨 采石场 (限7人)', '投骰 ÷5 获得 🪨石料'),
                    locCard('gold', '🪙 淘金河 (限7人)', '投骰 ÷6 获得 🪙黄金'),
                  ],
                ),
                const SizedBox(height: 6),
                buildingsAndCivPanel(),
                const SizedBox(height: 6),
                playersPanel(),
              ],
            ),
          ),
        ),
        if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
      ],
    );
  }
}
