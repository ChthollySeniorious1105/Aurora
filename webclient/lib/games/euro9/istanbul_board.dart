import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const _goodIcons = ['🧣', '🌿', '🧵', '🍋'];

class IstanbulBoard extends StatelessWidget {
  final GameContext g;
  const IstanbulBoard(this.g, {super.key});

  String _goodsText(List<dynamic> gList, int cap) {
    final parts = <String>[];
    for (var i = 0; i < gList.length && i < 4; i++) {
      parts.add('${_goodIcons[i]}${gList[i]}/$cap');
    }
    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final targetRubies = (v['targetRubies'] as num?)?.toInt() ?? 5;
    final endTriggered = v['endTriggered'] == true;
    final lastAction = '${v['lastAction'] ?? ''}';
    final board = (v['board'] as List?) ?? const [];
    final merchantPos = (v['merchantPos'] as List?) ?? const [];
    final assistants = (v['assistants'] as List?) ?? const [];
    final droppedAssistants = (v['droppedAssistants'] as List?) ?? const [];
    final goods = (v['goods'] as List?) ?? const [];
    final capacity = (v['capacity'] as List?) ?? const [];
    final lira = (v['lira'] as List?) ?? const [];
    final rubies = (v['rubies'] as List?) ?? const [];
    final legalMoves = ((v['legalMoves'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();

    final isMyTurn = !g.over && g.seat == turn;

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '游戏已结束 — $lastAction'
                          : '第 $round 轮${endTriggered ? '（终局轮！）' : ''} · 目标💎$targetRubies · 轮到 ${g.name(turn)} · $lastAction',
                      highlight: isMyTurn,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Player tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.center,
                    children: [
                      for (final s in g.seatsFromMe())
                        if (s < rubies.length)
                          g.tag(
                            s,
                            active: s == turn && !g.over,
                            sub:
                                '💎${rubies[s]}/$targetRubies | 💰${lira[s]}里拉 | 👳随行${assistants[s]} | ${_goodsText(goods[s] as List, (capacity[s] as num).toInt())}',
                          ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 4x4 Bazaar Grid
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tileW = ((constraints.maxWidth - 24) / 4).clamp(82.0, 225.0);
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: [
                              for (var loc = 0; loc < board.length; loc++)
                                _buildBazaarTile(
                                  cs,
                                  loc: loc,
                                  width: tileW,
                                  site: board[loc] as Map<String, dynamic>,
                                  merchantPos: merchantPos,
                                  assistants: assistants,
                                  droppedAssistants: droppedAssistants,
                                  clickable: isMyTurn && legalMoves.contains(loc),
                                  isMyHere: g.seat >= 0 &&
                                      g.seat < merchantPos.length &&
                                      (merchantPos[g.seat] as num).toInt() == loc,
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (g.over && v['result'] is Map)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '🏆 获胜者：${((v['result'] as Map)['winners'] as List?)?.join('、') ?? ''}',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players && s < rubies.length; s++)
                      Text('${g.name(s)}：💎${rubies[s]} 红宝石 | 💰${lira[s]} 里拉'),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBazaarTile(
    ColorScheme cs, {
    required int loc,
    required double width,
    required Map<String, dynamic> site,
    required List<dynamic> merchantPos,
    required List<dynamic> assistants,
    required List<dynamic> droppedAssistants,
    required bool clickable,
    required bool isMyHere,
  }) {
    final name = '${site['name']}';
    final desc = '${site['desc']}';
    final row = loc ~/ 4 + 1;
    final col = loc % 4 + 1;

    final merchantsHere = <String>[];
    for (var s = 0; s < merchantPos.length; s++) {
      if ((merchantPos[s] as num).toInt() == loc) {
        merchantsHere.add('🐪${g.name(s)}(+${assistants[s]}助)');
      }
    }

    final droppedHere = <String>[];
    for (var s = 0; s < droppedAssistants.length; s++) {
      final list = droppedAssistants[s] as List;
      if (list.any((e) => (e as num).toInt() == loc)) {
        droppedHere.add('👳${g.name(s)}');
      }
    }

    return Material(
      color: clickable
          ? cs.primaryContainer.withValues(alpha: 0.92)
          : isMyHere
              ? cs.secondaryContainer.withValues(alpha: 0.88)
              : cs.surface.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: clickable ? () => g.act({'type': 'move', 'to': loc}) : null,
        child: Container(
          width: width,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: clickable
                  ? cs.primary
                  : isMyHere
                      ? cs.secondary
                      : cs.outline.withValues(alpha: 0.35),
              width: clickable || isMyHere ? 2 : 1,
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
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Text('($row,$col)', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6))),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: cs.onSurface.withValues(alpha: 0.8)),
              ),
              if (merchantsHere.isNotEmpty || droppedHere.isNotEmpty) ...[
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    for (final m in merchantsHere)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(m, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    for (final d in droppedHere)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.tertiary.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(d, style: const TextStyle(fontSize: 10)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
