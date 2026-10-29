import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro13/tokaido.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TokaidoBoard extends StatefulWidget {
  final GameContext g;
  const TokaidoBoard(this.g, {super.key});

  @override
  State<TokaidoBoard> createState() => _TokaidoBoardState();
}

class _TokaidoBoardState extends State<TokaidoBoard> {
  int? _inspectSeat;

  Color _stopColor(int st) {
    return switch (st) {
      0 => const Color(0xFF6D4C41), // Village
      1 => const Color(0xFF66BB6A), // Paddy
      2 => const Color(0xFF78909C), // Mountain
      3 => const Color(0xFF1E88E5), // Sea
      4 => const Color(0xFF26A69A), // Hot Spring
      5 => const Color(0xFFE53935), // Temple
      6 => const Color(0xFFAB47BC), // Encounter
      7 => const Color(0xFFFBC02D), // Farm
      8 => const Color(0xFFFF7043), // Inn
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final road = asIntList(v['road']);
    final currentInnPos = asInt(v['currentInnPos'], 5);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final availStops = asIntList(v['availableStops']).toSet();
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

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
                                ? '江户旅途圆满结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到最落后的你行动！请点击前方高亮站点前进 · $lastAction'
                                    : '等待最落后的旅人 ${g.name(turn)} 前进 · $lastAction'),
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
                          '🍜前方必停宿场: #$currentInnPos',
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
                        final pPos = asInt(pd['pos'], 0);
                        final pCoins = asInt(pd['coins'], 0);
                        final pScore = asInt(pd['score'], 0);
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
                              sub: '📍#$pPos · 🪙$pCoins · ⭐$pScore分',
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
                                flex: 7,
                                child: _buildRoadPanel(
                                  road,
                                  availStops,
                                  currentInnPos,
                                  pList,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: _buildTraveloguePanel(
                                  viewSeat,
                                  viewData,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 7,
                                child: _buildRoadPanel(
                                  road,
                                  availStops,
                                  currentInnPos,
                                  pList,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 4,
                                child: _buildTraveloguePanel(
                                  viewSeat,
                                  viewData,
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
                '东海道之旅终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRoadPanel(
    List<int> road,
    Set<int> availStops,
    int currentInnPos,
    List<dynamic> pList,
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
          const Text(
            '🗾 东海道五十三次驿道（京都 #0 ➔ 江户终点，🍜宿场为全员必停站）',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.05,
              ),
              itemCount: road.length,
              itemBuilder: (context, idx) {
                final st = road[idx];
                final isAvail = isMyTurn && availStops.contains(idx);
                final isTargetInn = idx == currentInnPos;

                final hereSeats = <int>[];
                for (var s = 0; s < pList.length; s++) {
                  if (asInt((pList[s] as Map)['pos'], -1) == idx) {
                    hereSeats.add(s);
                  }
                }

                return GestureDetector(
                  onTap: isAvail
                      ? () => widget.g.act({'type': 'move', 'stop': idx})
                      : null,
                  child: Opacity(
                    opacity: (isAvail || hereSeats.isNotEmpty || st == 8)
                        ? 1.0
                        : 0.65,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _stopColor(st),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAvail
                              ? Colors.yellowAccent
                              : (isTargetInn
                                  ? Colors.white
                                  : Colors.black26),
                          width: isAvail ? 2.2 : (isTargetInn ? 1.8 : 0.8),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '#$idx ${tokaidoStopEmojis[st]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              tokaidoStopNames[st],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                              ),
                            ),
                            if (hereSeats.isNotEmpty)
                              Text(
                                [
                                  for (final s in hereSeats)
                                    'P${s + 1}'
                                ].join(','),
                                style: const TextStyle(
                                  color: Colors.yellowAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                ),
                              ),
                          ],
                        ),
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

  Widget _buildTraveloguePanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    ColorScheme cs,
  ) {
    final souv = asIntList(viewData['souvenirs']);
    final souvVp = asInt(viewData['souvenirVp'], 0);
    final paddy = asInt(viewData['paddy'], 0);
    final mountain = asInt(viewData['mountain'], 0);
    final sea = asInt(viewData['sea'], 0);
    final hotSpringVp = asInt(viewData['hotSpringVp'], 0);
    final templeDonated = asInt(viewData['templeDonated'], 0);
    final templeBonus = asInt(viewData['templeBonus'], 0);
    final meals = asInt(viewData['meals'], 0);
    final achVp = asInt(viewData['achievementVp'], 0);

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '📜 ${widget.g.name(viewSeat)} 的江户纪行手账',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🎨三景画卷: 🌾稻田 $paddy/3 · ⛰️山景 $mountain/4 · 🌊海景 $sea/5',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🏘️纪念品(套分$souvVp): ${[
                for (var i = 0; i < 4; i++)
                  '${tokaidoSouvenirEmojis[i]}${i < souv.length ? souv[i] : 0}'
              ].join('  ')}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '⛩️神社供奉: $templeDonated🪙 (终局排行 +$templeBonus分)',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '♨️温泉: +$hotSpringVp分 · 🍜料理: $meals份(+${meals * 6}分) · 🏆成就: +$achVp分',
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}
