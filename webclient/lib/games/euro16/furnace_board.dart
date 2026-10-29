import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class FurnaceBoard extends StatefulWidget {
  final GameContext g;
  const FurnaceBoard(this.g, {super.key});

  @override
  State<FurnaceBoard> createState() => _FurnaceBoardState();
}

class _FurnaceBoardState extends State<FurnaceBoard> {
  int _selectedDisc = 1;
  int? _inspectSeat;

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 4);
    final turn = asInt(v['turn'], 0);
    final phase = asStr(v['phase'], 'auction');
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final market = (v['market'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final myDiscs = [
      for (final d in ((myData['discsLeft'] as List?) ?? const [])) asInt(d, 1),
    ];
    if (myDiscs.isNotEmpty && !myDiscs.contains(_selectedDisc)) {
      _selectedDisc = myDiscs.first;
    }

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 700;
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: StatusBar(
                            over
                                ? '游戏结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你 (${phase == 'auction' ? '竞标阶段：选圆片放入工厂卡' : '生产阶段：升级并启动工厂'}) · $lastAction'
                                    : '等待 ${g.name(turn)} 行动 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🏭第 $round/$maxRounds 轮 · ${phase == 'auction' ? '竞标' : '生产'}',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final money = asInt(pd['money'], 0);
                        final gears = asInt(pd['gears'], 0);
                        final res = (pd['resources'] as List?) ?? const [0, 0, 0];
                        final selected = s == viewSeat;
                        return GestureDetector(
                          onTap: () => setState(() => _inspectSeat = s),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: selected
                                  ? Border.all(
                                      color: Colors.amberAccent, width: 2)
                                  : null,
                            ),
                            child: g.tag(
                              s,
                              active: s == turn,
                              sub:
                                  '💰$money · 🪨${res[0]} 🔩${res[1]} 🛢️${res[2]} ⚙️$gears',
                              size: 28,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: wide
                        ? Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildAuctionPanel(
                                  market,
                                  myDiscs,
                                  phase,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildProductionPanel(
                                  viewSeat,
                                  viewData,
                                  phase,
                                  isMyTurn && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildAuctionPanel(
                                  market,
                                  myDiscs,
                                  phase,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildProductionPanel(
                                  viewSeat,
                                  viewData,
                                  phase,
                                  isMyTurn && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '工业熔炉终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: 💰${(pList[s] as Map)['money']}'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAuctionPanel(
    List<dynamic> market,
    List<int> myDiscs,
    String phase,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '⚖️ 5张拍卖工厂卡 (落选得 d×补偿，最高点夺卡)',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              for (final d in myDiscs)
                GestureDetector(
                  onTap: () => setState(() => _selectedDisc = d),
                  child: Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: _selectedDisc == d
                          ? Colors.amber
                          : cs.primaryContainer,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.primary, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$d',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            _selectedDisc == d ? Colors.black : cs.onSurface,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: market.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final card = (market[idx] as Map).cast<String, dynamic>();
                final bids = (card['bids'] as List?) ?? const [];
                final canBid =
                    isMyTurn && phase == 'auction' && myDiscs.isNotEmpty;
                return GestureDetector(
                  onTap: !canBid
                      ? null
                      : () => widget.g.act({
                            'type': 'bid',
                            'slot': idx,
                            'disc': _selectedDisc,
                          }),
                  child: Container(
                    width: 126,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canBid
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3),
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${card['emoji']} ${card['name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '补偿: ${card['compDesc']}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber[800],
                            ),
                          ),
                          Text(
                            '开采: ${card['extractDesc']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          Text(
                            '精炼: ${card['convertDesc']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            bids.isEmpty
                                ? '暂无圆片出价'
                                : '出价: ${bids.map((b) => "${widget.g.name(asInt((b as Map)['seat'], 0))}[${b['disc']}]").join(" ")}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductionPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    String phase,
    bool canAct,
    ColorScheme cs,
  ) {
    final factories = (viewData['factories'] as List?) ?? const [];
    final gears = asInt(viewData['gears'], 0);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '⚙️ ${widget.g.name(viewSeat)} 的工业帝国 (${factories.length} 座工厂)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (canAct && phase == 'production')
                InkWell(
                  onTap: () => widget.g.act({'type': 'end_production'}),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '✓ 一键全产并结束生产',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 170,
                mainAxisExtent: 74,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: factories.length,
              itemBuilder: (context, idx) {
                final f = (factories[idx] as Map).cast<String, dynamic>();
                final upgraded = asBool(f['upgraded']);
                final used = asBool(f['usedThisRound']);

                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: used
                        ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                        : cs.secondaryContainer.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: upgraded
                          ? Colors.amber
                          : cs.outline.withValues(alpha: 0.35),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${f['emoji']} ${f['name']} ${upgraded ? "★已升级" : "未升级"}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                        Text(
                          '开采: ${f['extractDesc']} | 精炼: ${f['convertDesc']}',
                          style: const TextStyle(fontSize: 10),
                        ),
                        if (canAct && phase == 'production')
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!upgraded && gears > 0)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () => widget.g.act({
                                      'type': 'upgrade',
                                      'factoryIdx': idx,
                                    }),
                                    child: Text(
                                      '[⚙️升级]',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.amber[800],
                                      ),
                                    ),
                                  ),
                                ),
                              if (!used)
                                InkWell(
                                  onTap: () => widget.g.act({
                                    'type': 'activate',
                                    'factoryIdx': idx,
                                  }),
                                  child: Text(
                                    '[▶启动生产]',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: cs.primary,
                                    ),
                                  ),
                                )
                              else
                                const Text(
                                  '✓本轮已运转',
                                  style: TextStyle(fontSize: 10),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
