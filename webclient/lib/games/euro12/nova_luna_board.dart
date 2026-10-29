import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro12/nova_luna.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class NovaLunaBoard extends StatefulWidget {
  final GameContext g;
  const NovaLunaBoard(this.g, {super.key});

  @override
  State<NovaLunaBoard> createState() => _NovaLunaBoardState();
}

class _NovaLunaBoardState extends State<NovaLunaBoard> {
  int? _selectedWheelSlot;
  int? _inspectSeat;

  Color _tileColor(int col) {
    return switch (col) {
      0 => const Color(0xFF00ACC1), // Cyan
      1 => const Color(0xFFFBC02D), // Yellow
      2 => const Color(0xFFE53935), // Red
      3 => const Color(0xFF1E88E5), // Blue
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final gridSize = asInt(v['gridSize'], 7);
    final moonPos = asInt(v['moonPos'], 0);
    final deckCount = asInt(v['deckCount'], 0);
    final canRefill = asBool(v['canRefill']);
    final availSlots = asIntList(v['availableSlots']);
    final wheel = (v['wheel'] as List?) ?? const [];
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedWheelSlot == null || !availSlots.contains(_selectedWheelSlot)) {
      _selectedWheelSlot = availSlots.isNotEmpty ? availSlots.first : null;
    }

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat =
        (_inspectSeat != null && _inspectSeat! < pList.length)
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
                                ? '游戏结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！先选月轮板块，再点个人星盘空位放置 · $lastAction'
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
                          color: cs.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🌙牌库余 $deckCount',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pList.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (context, s) {
                        final pd = (pList[s] as Map).cast<String, dynamic>();
                        final tp = asInt(pd['timePos'], 0);
                        final dl = asInt(pd['disksLeft'], 0);
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
                              sub: '⚪余$dl · ⏳$tp',
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
                                child: _buildMoonWheelPanel(
                                  wheel,
                                  moonPos,
                                  availSlots,
                                  canRefill,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildTableauPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
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
                                child: _buildMoonWheelPanel(
                                  wheel,
                                  moonPos,
                                  availSlots,
                                  canRefill,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildTableauPanel(
                                  viewSeat,
                                  viewData,
                                  gridSize,
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
                '新月任务终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: 余${(pList[s] as Map)['disksLeft']}圆盘'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoonWheelPanel(
    List<dynamic> wheel,
    int moonPos,
    List<int> availSlots,
    bool canRefill,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(
                child: Text(
                  '🌙 12 格新月轮盘（可选顺时针前 3 枚高亮板块）',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (isMyTurn && canRefill)
                InkWell(
                  onTap: () => widget.g.act({'type': 'refill'}),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '🔄补满轮盘',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.25,
              ),
              itemCount: 12,
              itemBuilder: (context, idx) {
                final isMoon = idx == moonPos;
                final rawTile = idx < wheel.length ? wheel[idx] : null;
                final isAvail = availSlots.contains(idx);
                final isSelected = _selectedWheelSlot == idx;

                if (isMoon) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade900,
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: Colors.amberAccent, width: 1.5),
                    ),
                    child: const Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Text(
                            '🌙\n新月位',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (rawTile == null) {
                  return Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '#${idx + 1} 空',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  );
                }

                final tm = (rawTile as Map).cast<String, dynamic>();
                final col = asInt(tm['color'], 0);
                final cost = asInt(tm['cost'], 1);
                final tasks = (tm['tasks'] as List?) ?? const [];

                return GestureDetector(
                  onTap: isAvail
                      ? () => setState(() => _selectedWheelSlot = idx)
                      : null,
                  child: Opacity(
                    opacity: isAvail ? 1.0 : 0.55,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _tileColor(col),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : (isAvail
                                  ? Colors.amberAccent
                                  : Colors.black26),
                          width: isSelected ? 2.5 : (isAvail ? 1.5 : 0.8),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '⏳$cost · ${novaColorNames[col]}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (tasks.isEmpty)
                              const Text(
                                '无任务',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 9),
                              )
                            else
                              for (final t in tasks)
                                Text(
                                  [
                                    for (final c in (t as List))
                                      novaColorEmojis[asInt(c, 0)]
                                  ].join(),
                                  style: const TextStyle(fontSize: 10),
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

  Widget _buildTableauPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int gridSize,
    bool canActOnTableau,
    ColorScheme cs,
  ) {
    final tab = (viewData['tableau'] as List?) ?? const [];
    final validList = (viewData['validPlacements'] as List?) ?? const [];
    final validSet = <(int, int)>{
      for (final p in validList)
        if (p is List && p.length >= 2) (asInt(p[0]), asInt(p[1])),
    };

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${widget.g.name(viewSeat)} 的星盘 ($gridSize×$gridSize)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Text(
                '剩余圆盘: ${viewData['disksLeft'] ?? 0} · 时间轨: ${viewData['timePos'] ?? 0}',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: Column(
                  children: [
                    for (var r = 0; r < gridSize; r++)
                      Expanded(
                        child: Row(
                          children: [
                            for (var c = 0; c < gridSize; c++)
                              Expanded(
                                child: _buildTableauCell(
                                  r,
                                  c,
                                  (r < tab.length &&
                                          c < (tab[r] as List).length)
                                      ? (tab[r] as List)[c]
                                      : null,
                                  validSet.contains((r, c)),
                                  canActOnTableau,
                                  cs,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableauCell(
    int r,
    int c,
    Object? rawPlaced,
    bool isValidSpot,
    bool canActOnTableau,
    ColorScheme cs,
  ) {
    if (rawPlaced is Map) {
      final pm = rawPlaced.cast<String, dynamic>();
      final tm = (pm['tile'] as Map).cast<String, dynamic>();
      final col = asInt(tm['color'], 0);
      final cost = asInt(tm['cost'], 1);
      final tasks = (tm['tasks'] as List?) ?? const [];
      final doneTasks = (pm['doneTasks'] as List?) ?? const [];

      return Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: _tileColor(col),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: Colors.white54, width: 0.8),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '⏳$cost',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                  for (var i = 0; i < tasks.length; i++)
                    Text(
                      (i < doneTasks.length && doneTasks[i] == true)
                          ? '✅完成'
                          : [
                              for (final reqCol in (tasks[i] as List))
                                novaColorEmojis[asInt(reqCol, 0)]
                            ].join(),
                      style: const TextStyle(
                          fontSize: 9, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final clickable =
        canActOnTableau && isValidSpot && _selectedWheelSlot != null;
    return GestureDetector(
      onTap: clickable
          ? () {
              widget.g.act({
                'type': 'pick',
                'wheelSlot': _selectedWheelSlot,
                'r': r,
                'c': c,
              });
            }
          : null,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: clickable
              ? cs.primary.withValues(alpha: 0.22)
              : cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: clickable
                ? cs.primary
                : cs.outline.withValues(alpha: 0.2),
            width: clickable ? 1.2 : 0.6,
          ),
        ),
        child: clickable && r == 3 && c == 3
            ? const Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('★', style: TextStyle(fontSize: 11)),
                ),
              )
            : null,
      ),
    );
  }
}
