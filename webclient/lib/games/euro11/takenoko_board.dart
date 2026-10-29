import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _bambooColors = [
  Color(0xFF3E9E52), // 0 绿竹
  Color(0xFFE5B82A), // 1 黄竹
  Color(0xFFE06B9B), // 2 粉竹
];
const List<String> _bambooNames = ['绿竹', '黄竹', '粉竹'];

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<T> _asList<T>(Object? v) => v is List ? v.cast<T>() : <T>[];
Map<String, dynamic> _asMap(Object? v) => v is Map ? v.cast<String, dynamic>() : <String, dynamic>{};

class TakenokoBoard extends StatefulWidget {
  final GameContext g;
  const TakenokoBoard(this.g, {super.key});

  @override
  State<TakenokoBoard> createState() => _TakenokoBoardState();
}

class _TakenokoBoardState extends State<TakenokoBoard> {
  String mode = 'gardener'; // 'plot' | 'irrigate' | 'gardener' | 'panda'
  int selPlotColor = 0;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final over = v['phase'] == 'over';
    final turn = _asInt(v['turn']);
    final round = _asInt(v['round'], 1);
    final actionsLeft = _asInt(v['actionsLeft'], 2);
    final weatherName = '${v['weatherName'] ?? '☀️ 阳光'}';
    final targetGoals = _asInt(v['targetGoals'], 6);
    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final plots = _asList<dynamic>(v['plots']).map(_asMap).toList();
    final validPlacements = _asList<dynamic>(v['validPlacements']).map(_asMap).toList();
    final gardenerPos = _asMap(v['gardenerPos']);
    final pandaPos = _asMap(v['pandaPos']);
    final gq = _asInt(gardenerPos['q']), gr = _asInt(gardenerPos['r']);
    final pq = _asInt(pandaPos['q']), pr = _asInt(pandaPos['r']);
    final myGoals = _asList<dynamic>(v['myGoals']).map(_asMap).toList();
    final ps = _asList<dynamic>(v['players']).map(_asMap).toList();

    final status = over
        ? '熊猫园丁 · 终局结算'
        : myTurn
            ? '第 $round 轮 ($weatherName) · 轮到你（剩余 $actionsLeft 行动点）'
            : '第 $round 轮 ($weatherName) · 等待 ${g.name(turn)} 行动（剩余 $actionsLeft 行动点）';

    Widget actionToolbar() {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ChoiceChip(
              label: const Text('👨‍🌾 移动园丁', style: TextStyle(fontSize: 12)),
              selected: mode == 'gardener',
              onSelected: myTurn ? (_) => setState(() => mode = 'gardener') : null,
            ),
            ChoiceChip(
              label: const Text('🐼 移动熊猫', style: TextStyle(fontSize: 12)),
              selected: mode == 'panda',
              onSelected: myTurn ? (_) => setState(() => mode = 'panda') : null,
            ),
            ChoiceChip(
              label: const Text('🌱 铺设地块', style: TextStyle(fontSize: 12)),
              selected: mode == 'plot',
              onSelected: myTurn ? (_) => setState(() => mode = 'plot') : null,
            ),
            ChoiceChip(
              label: const Text('💧 引水灌溉', style: TextStyle(fontSize: 12)),
              selected: mode == 'irrigate',
              onSelected: myTurn ? (_) => setState(() => mode = 'irrigate') : null,
            ),
            if (mode == 'plot')
              for (var c = 0; c < 3; c++)
                ChoiceChip(
                  label: Text(_bambooNames[c], style: const TextStyle(fontSize: 11)),
                  selected: selPlotColor == c,
                  selectedColor: _bambooColors[c].withValues(alpha: 0.55),
                  onSelected: myTurn ? (_) => setState(() => selPlotColor = c) : null,
                ),
            FilledButton.tonalIcon(
              onPressed: myTurn && myGoals.length < 5 ? () => g.act({'type': 'draw_goal'}) : null,
              icon: const Icon(Icons.style, size: 15),
              label: Text('抽目标 (${_asInt(v['goalDeckCount'])})', style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    Widget hexGardenPanel(double maxW, double maxH) {
      return Container(
        width: maxW,
        height: maxH,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1D3A2A).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.35)),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 500,
            height: 360,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (myTurn && mode == 'plot')
                  for (final vp in validPlacements)
                    Builder(builder: (_) {
                      final q = _asInt(vp['q']);
                      final r = _asInt(vp['r']);
                      final cx = 250.0 + (q + r * 0.5) * 66.0;
                      final cy = 180.0 + r * 58.0;
                      if (cx < 20 || cx > 480 || cy < 20 || cy > 340) return const SizedBox.shrink();
                      return Positioned(
                        left: cx - 28,
                        top: cy - 28,
                        child: GestureDetector(
                          onTap: () => g.act({'type': 'place_plot', 'q': q, 'r': r, 'color': selPlotColor}),
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bambooColors[selPlotColor].withValues(alpha: 0.25),
                              border: Border.all(color: Colors.amberAccent, width: 1.8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '+${_bambooNames[selPlotColor]}\n($q,$r)',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      );
                    }),
                for (final p in plots)
                  Builder(builder: (_) {
                    final q = _asInt(p['q']);
                    final r = _asInt(p['r']);
                    final color = _asInt(p['color'], -1);
                    final irrigated = p['irrigated'] == true;
                    final height = _asInt(p['bambooHeight']);
                    final hasGardener = q == gq && r == gr;
                    final hasPanda = q == pq && r == pr;
                    final cx = 250.0 + (q + r * 0.5) * 66.0;
                    final cy = 180.0 + r * 58.0;

                    final bgColor = color < 0 ? const Color(0xFF2B85C7) : _bambooColors[color.clamp(0, 2)];
                    return Positioned(
                      left: cx - 30,
                      top: cy - 30,
                      child: GestureDetector(
                        onTap: !myTurn
                            ? null
                            : () {
                                if (mode == 'gardener') {
                                  g.act({'type': 'move_gardener', 'to': [q, r]});
                                } else if (mode == 'panda') {
                                  g.act({'type': 'move_panda', 'to': [q, r]});
                                } else if (mode == 'irrigate' && color >= 0 && !irrigated) {
                                  g.act({'type': 'irrigate', 'q': q, 'r': r});
                                }
                              },
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bgColor,
                            border: Border.all(
                              color: irrigated ? Colors.lightBlueAccent : Colors.white54,
                              width: irrigated ? 2.5 : 1.2,
                            ),
                            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black45)],
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.all(3),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    color < 0 ? '💧池塘' : '${_bambooNames[color]} ${'🎍' * height}',
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    '${hasGardener ? '👨‍🌾' : ''}${hasPanda ? '🐼' : ''}${color >= 0 ? ' H:$height' : ''}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      );
    }

    Widget goalsAndPlayersPanel() {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in ps)
                  Builder(builder: (_) {
                    final s = _asInt(p['seat']);
                    final eaten = _asList<dynamic>(p['eaten']).map(_asInt).toList();
                    final comp = _asInt(p['completedCount']);
                    final emp = p['emperor'] == true;
                    return g.tag(
                      s,
                      active: !over && turn == s,
                      size: 28,
                      sub: '${_asInt(p['score'])}分 · 目标$comp/$targetGoals${emp ? '👑' : ''} · 笋[绿${eaten.elementAtOrNull(0) ?? 0}/黄${eaten.elementAtOrNull(1) ?? 0}/粉${eaten.elementAtOrNull(2) ?? 0}]',
                    );
                  }),
              ],
            ),
            if (myGoals.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text('我的手牌目标卡（达成后点击领奖，不消耗行动点）：', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < myGoals.length; i++)
                    Builder(builder: (_) {
                      final mg = myGoals[i];
                      final claimable = mg['claimable'] == true;
                      return ActionChip(
                        avatar: Icon(
                          claimable ? Icons.check_circle : Icons.flag_outlined,
                          size: 16,
                          color: claimable ? Colors.green : cs.primary,
                        ),
                        label: Text(
                          '${mg['title']} (+${mg['vp']}分)${claimable ? ' [可达成!]' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: claimable ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onPressed: myTurn && claimable ? () => g.act({'type': 'claim_goal', 'index': i}) : null,
                      );
                    }),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget? banner;
    if (over) {
      final pl = _asList<dynamic>(v['placings']).map(_asInt).toList();
      final winners = [for (var s = 0; s < pl.length; s++) if (pl[s] == 1) g.name(s)];
      banner = ResultBanner(
        '${winners.join('、')} 荣获御用园丁！',
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DataTable(
            headingRowHeight: 28,
            dataRowMinHeight: 24,
            dataRowMaxHeight: 28,
            columns: const [
              DataColumn(label: Text('玩家')),
              DataColumn(label: Text('完成目标')),
              DataColumn(label: Text('天皇奖')),
              DataColumn(label: Text('总分')),
            ],
            rows: [
              for (final p in ps)
                DataRow(cells: [
                  DataCell(Text(g.name(_asInt(p['seat'])), style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text('${_asInt(p['completedCount'])} 张')),
                  DataCell(Text(p['emperor'] == true ? '+2 👑' : '-')),
                  DataCell(Text('${_asInt(p['score'])}', style: const TextStyle(fontWeight: FontWeight.bold))),
                ]),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final gardenH = max(200.0, min(340.0, c.maxHeight * 0.52));
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
                  actionToolbar(),
                  const SizedBox(height: 6),
                  hexGardenPanel(c.maxWidth - 12, gardenH),
                  const SizedBox(height: 6),
                  goalsAndPlayersPanel(),
                ],
              ),
            ),
          ),
          if (banner != null) Align(alignment: Alignment.topCenter, child: banner),
        ],
      );
    });
  }
}
