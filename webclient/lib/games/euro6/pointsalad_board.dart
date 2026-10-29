import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _veggieNames = ['番茄', '生菜', '胡萝卜', '卷心菜', '洋葱', '青椒'];
const List<String> _veggieIcons = ['🍅', '🥬', '🥕', '🥗', '🧅', '🫑'];
const List<Color> _veggieColors = [
  Color(0xFFD94336), // Tomato
  Color(0xFF4CAF50), // Lettuce
  Color(0xFFF57C00), // Carrot
  Color(0xFF7B1FA2), // Cabbage
  Color(0xFFC2185B), // Onion
  Color(0xFFfbc02d), // Pepper
];

class PointSaladBoard extends StatefulWidget {
  final GameContext g;
  const PointSaladBoard(this.g, {super.key});

  @override
  State<PointSaladBoard> createState() => _PointSaladBoardState();
}

class _PointSaladBoardState extends State<PointSaladBoard> {
  final Set<int> _selectedSlots = {};
  String _stateKey = '';

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final flippedThisTurn = v['flippedThisTurn'] == true;
    final lastAction = '${v['lastAction'] ?? ''}';
    final piles = (v['piles'] as List?) ?? const [];
    final market = (v['market'] as List?) ?? const [];
    final players = (v['players'] as List?) ?? const [];
    final placings = (v['placings'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    final curKey = '$turn/$over/$flippedThisTurn/$lastAction';
    if (curKey != _stateKey) {
      _stateKey = curKey;
      _selectedSlots.clear();
    }

    final availMarketCount = market.where((m) => m != null).length;
    final maxPick = availMarketCount >= 2 ? 2 : availMarketCount;

    String statusText;
    if (over) {
      statusText = '游戏结束 · $lastAction';
    } else if (myTurn) {
      statusText = '轮到你：选 1 张计分卡，或选至多 $maxPick 张蔬菜卡${flippedThisTurn ? '' : '（也可先翻转1张已有计分卡）'}';
    } else {
      statusText = '等待 ${g.name(turn)} 行动 · $lastAction';
    }

    Widget buildPointPileCard(int pIdx) {
      final pileMap = pIdx < piles.length ? (piles[pIdx] as Map?) : null;
      final count = (pileMap?['count'] as num?)?.toInt() ?? 0;
      final top = pileMap?['top'] as Map?;
      if (top == null || count <= 0) {
        return Container(
          width: 112,
          height: 82,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          ),
          child: Text('牌堆 ${pIdx + 1} 已空', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5))),
        );
      }
      final veg = (top['veggie'] as num?)?.toInt() ?? 0;
      final label = '${top['label'] ?? ''}';
      final vCol = _veggieColors[veg % 6];

      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: myTurn ? () => g.act({'type': 'take_point', 'pile': pIdx}) : null,
        child: Container(
          width: 112,
          height: 82,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: myTurn ? cs.primary : vCol, width: myTurn ? 2 : 1.5),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 2))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(color: vCol.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                      child: Text(
                        '背:${_veggieIcons[veg % 6]}${_veggieNames[veg % 6]}',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: vCol),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text('剩$count', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.65))),
                  ],
                ),
              ),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
                    ),
                  ),
                ),
              ),
              if (myTurn)
                Text('点击拿计分卡', style: TextStyle(fontSize: 9, color: cs.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }

    Widget buildVeggieSlot(int sIdx) {
      final card = sIdx < market.length ? (market[sIdx] as Map?) : null;
      if (card == null) {
        return Container(
          width: 112,
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
          ),
          child: Text('空槽', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.45))),
        );
      }
      final veg = (card['veggie'] as num?)?.toInt() ?? 0;
      final vCol = _veggieColors[veg % 6];
      final selected = _selectedSlots.contains(sIdx);

      return InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: myTurn
            ? () {
                setState(() {
                  if (selected) {
                    _selectedSlots.remove(sIdx);
                  } else {
                    if (_selectedSlots.length >= maxPick) {
                      _selectedSlots.remove(_selectedSlots.first);
                    }
                    _selectedSlots.add(sIdx);
                  }
                });
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 112,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? vCol.withValues(alpha: 0.32) : cs.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? cs.primary : vCol, width: selected ? 2.5 : 1.5),
            boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_veggieIcons[veg % 6], style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _veggieNames[veg % 6],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: vCol),
                    ),
                    if (selected)
                      Text('已选', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget buildMarketSection() {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('计分牌堆 (3列) & 蔬菜市场 (6格)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface)),
                if (myTurn && _selectedSlots.isNotEmpty)
                  FilledButton.icon(
                    onPressed: () {
                      final slots = _selectedSlots.toList()..sort();
                      g.act({'type': 'take_veggies', 'slots': slots});
                      setState(() => _selectedSlots.clear());
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('拿取所选蔬菜 (${_selectedSlots.length})'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (var p = 0; p < 3; p++)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildPointPileCard(p),
                      const SizedBox(height: 6),
                      buildVeggieSlot(p * 2),
                      const SizedBox(height: 6),
                      buildVeggieSlot(p * 2 + 1),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    }

    Widget buildPlayerCard(int s) {
      if (s < 0 || s >= players.length) return const SizedBox();
      final pMap = players[s] as Map;
      final score = (pMap['score'] as num?)?.toInt() ?? 0;
      final veggies = (pMap['veggies'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(6, 0);
      final pointCards = (pMap['pointCards'] as List?) ?? const [];
      final isMine = s == me;
      final active = !over && turn == s;

      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: isMine ? 0.88 : 0.72),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            g.tag(s, active: active, sub: '总分: $score 分 · 计分卡 ${pointCards.length} 张'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (var vIdx = 0; vIdx < 6; vIdx++)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _veggieColors[vIdx].withValues(alpha: veggies[vIdx] > 0 ? 0.22 : 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _veggieColors[vIdx].withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      '${_veggieIcons[vIdx]}${_veggieNames[vIdx]} ×${veggies[vIdx]}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: veggies[vIdx] > 0 ? FontWeight.bold : FontWeight.normal,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
              ],
            ),
            if (pointCards.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < pointCards.length; i++)
                    Builder(builder: (_) {
                      final pc = pointCards[i] as Map;
                      final veg = (pc['veggie'] as num?)?.toInt() ?? 0;
                      final label = '${pc['label'] ?? ''}';
                      final cScore = (pc['cardScore'] as num?)?.toInt() ?? 0;
                      final canFlip = isMine && myTurn && !flippedThisTurn;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHighest.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _veggieColors[veg % 6].withValues(alpha: 0.7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Text(
                                  '当前 ${cScore >= 0 ? '+$cScore' : '$cScore'} 分 · 背:${_veggieIcons[veg % 6]}${_veggieNames[veg % 6]}',
                                  style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.75)),
                                ),
                              ],
                            ),
                            if (canFlip) ...[
                              const SizedBox(width: 6),
                              InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => g.act({'type': 'flip', 'index': i}),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('翻成蔬菜', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ],
          ],
        ),
      );
    }

    Widget? resultBanner;
    if (over && placings.isNotEmpty) {
      final winners = [
        for (var s = 0; s < placings.length; s++)
          if (placings[s] == 1) g.name(s),
      ];
      resultBanner = ResultBanner('${winners.join("、")} 获胜！');
    }

    final seatOrder = g.seatsFromMe();

    return Container(
      color: g.table,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: StatusBar(statusText, highlight: myTurn)),
                const SizedBox(height: 8),
                Center(child: buildMarketSection()),
                const SizedBox(height: 8),
                for (final s in seatOrder) ...[
                  buildPlayerCard(s),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
          if (resultBanner != null) Align(alignment: Alignment.topCenter, child: resultBanner),
        ],
      ),
    );
  }
}
