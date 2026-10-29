import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro15/harmonies.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class HarmoniesBoard extends StatefulWidget {
  final GameContext g;
  const HarmoniesBoard(this.g, {super.key});

  @override
  State<HarmoniesBoard> createState() => _HarmoniesBoardState();
}

class _HarmoniesBoardState extends State<HarmoniesBoard> {
  int _selectedPouch = 0;
  int _selectedAnimalSlot = -1;
  int? _inspectSeat;
  final List<(int, int)> _pickedCells = [];

  Color _tokenColor(int t) {
    return switch (t) {
      0 => const Color(0xFF8D6E63), // Brown Trunk
      1 => const Color(0xFF43A047), // Green Canopy
      2 => const Color(0xFF78909C), // Gray Mountain
      3 => const Color(0xFFE53935), // Red Building
      4 => const Color(0xFFFBC02D), // Yellow Field
      5 => const Color(0xFF1E88E5), // Blue Water
      _ => Colors.blueGrey,
    };
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rows = asInt(v['rows'], 5);
    final cols = asInt(v['cols'], 5);
    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 10);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final pouches = (v['pouches'] as List?) ?? const [];
    final animalMarket = (v['animalMarket'] as List?) ?? const [];
    final suggestedByPouch = (v['suggestedByPouch'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    if (_selectedPouch >= pouches.length) _selectedPouch = 0;
    if (_selectedAnimalSlot >= animalMarket.length) _selectedAnimalSlot = -1;

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
                                ? '游戏结束 · $lastAction'
                                : (isMyTurn
                                    ? '轮到你！选1袋圆盘放入5×5栖息地（可同时领养动物卡） · $lastAction'
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
                          '🌿第 $round/$maxRounds 轮',
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
                        final sc = asInt(pd['score'], 0);
                        final tvp = asInt(pd['treeVp'], 0);
                        final avp = asInt(pd['animalVp'], 0);
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
                              sub: '⭐$sc分 · 🌿$tvp · 🐾$avp',
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
                                child: _buildMarketPanel(
                                  pouches,
                                  animalMarket,
                                  suggestedByPouch,
                                  viewData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildGridPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  pouches,
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
                                child: _buildMarketPanel(
                                  pouches,
                                  animalMarket,
                                  suggestedByPouch,
                                  viewData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildGridPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  pouches,
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
                '森灵合鸣终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketPanel(
    List<dynamic> pouches,
    List<dynamic> animalMarket,
    List<dynamic> suggestedByPouch,
    Map<String, dynamic> viewData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final myAnimals = (viewData['animals'] as List?) ?? const [];
    final canAutoPlace =
        isMyTurn && _selectedPouch < suggestedByPouch.length;

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
                  '🎒 中央圆盘补给袋 & 动物栖息卡',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (canAutoPlace)
                InkWell(
                  onTap: () {
                    final cells = suggestedByPouch[_selectedPouch];
                    widget.g.act({
                      'type': 'draft',
                      'pouch': _selectedPouch,
                      'claimAnimal': _selectedAnimalSlot,
                      'cells': cells,
                    });
                    setState(() {
                      _pickedCells.clear();
                      _selectedAnimalSlot = -1;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '⚡智能放置第${_selectedPouch + 1}袋',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: pouches.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final p = (pouches[idx] as List?) ?? const [];
                final sel = idx == _selectedPouch;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedPouch = idx;
                    _pickedCells.clear();
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? cs.primary : cs.outline.withValues(alpha: 0.3),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '#${idx + 1} ',
                          style: const TextStyle(
                              fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        for (var i = 0; i < p.length; i++) ...[
                          Container(
                            width: 22,
                            height: 22,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: _tokenColor(asInt(p[i], 0)),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.white70, width: 1.2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              harmoniesTokenEmojis[
                                  asInt(p[i], 0).clamp(0, 5)],
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: animalMarket.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, idx) {
                final a =
                    (animalMarket[idx] as Map).cast<String, dynamic>();
                final sel = idx == _selectedAnimalSlot;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedAnimalSlot = sel ? -1 : idx;
                  }),
                  child: Container(
                    width: 115,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.amber.withValues(alpha: 0.25)
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel
                            ? Colors.amber
                            : cs.outline.withValues(alpha: 0.3),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${a['emoji']} ${a['name']}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${a['patternDesc']}',
                            style: const TextStyle(fontSize: 10),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            sel ? '✓ 本回合领养' : '奖励: 4/9/15分',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sel ? Colors.amber[800] : cs.primary,
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
          if (myAnimals.isNotEmpty) ...[
            const SizedBox(height: 3),
            SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: myAnimals.length,
                separatorBuilder: (_, _) => const SizedBox(width: 4),
                itemBuilder: (context, idx) {
                  final a =
                      (myAnimals[idx] as Map).cast<String, dynamic>();
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${a['emoji']}${a['name']} (${a['cubesPlaced']}/3块 · ${a['vp']}分)',
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGridPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int rows,
    int cols,
    List<dynamic> pouches,
    bool canInteract,
    ColorScheme cs,
  ) {
    final stacks = (viewData['stacks'] as List?) ?? const [];
    final animalAt = (viewData['animalAt'] as List?) ?? const [];
    final selTokens = (_selectedPouch < pouches.length)
        ? ((pouches[_selectedPouch] as List?) ?? const [])
        : const [];

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '🗺️ ${widget.g.name(viewSeat)} 的 5×5 生态版图'
                  '${canInteract && selTokens.isNotEmpty ? '（点选第 ${_pickedCells.length + 1}/3 格放 ${harmoniesTokenEmojis[asInt(selTokens[_pickedCells.length.clamp(0, 2)], 0)]}）' : ''}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (_pickedCells.isNotEmpty)
                InkWell(
                  onTap: () => setState(() => _pickedCells.clear()),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('重置选格',
                        style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '🌿树:${viewData['treeVp'] ?? 0}  ⛰️山:${viewData['mountainVp'] ?? 0}  🌾田:${viewData['fieldVp'] ?? 0}  🧱楼:${viewData['buildingVp'] ?? 0}  🌊河:${viewData['riverVp'] ?? 0}  🐾兽:${viewData['animalVp'] ?? 0}',
              style: const TextStyle(fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 4,
                    crossAxisSpacing: 4,
                  ),
                  itemCount: rows * cols,
                  itemBuilder: (context, index) {
                    final r = index ~/ cols;
                    final c = index % cols;
                    final st = (r < stacks.length &&
                            c < (stacks[r] as List).length)
                        ? ((stacks[r] as List)[c] as List)
                        : const [];
                    final animId = (r < animalAt.length &&
                            c < (animalAt[r] as List).length)
                        ? asInt((animalAt[r] as List)[c], 0)
                        : 0;
                    final pickCount =
                        _pickedCells.where((e) => e.$1 == r && e.$2 == c).length;
                    final topTok =
                        st.isNotEmpty ? asInt(st.last, 0) : -1;

                    return GestureDetector(
                      onTap: !canInteract
                          ? null
                          : () {
                              setState(() {
                                _pickedCells.add((r, c));
                                if (_pickedCells.length == 3) {
                                  final cells = [
                                    for (final (pr, pc) in _pickedCells)
                                      [pr, pc],
                                  ];
                                  _pickedCells.clear();
                                  final claim = _selectedAnimalSlot;
                                  _selectedAnimalSlot = -1;
                                  widget.g.act({
                                    'type': 'draft',
                                    'pouch': _selectedPouch,
                                    'claimAnimal': claim,
                                    'cells': cells,
                                  });
                                }
                              });
                            },
                      child: Container(
                        decoration: BoxDecoration(
                          color: topTok >= 0
                              ? _tokenColor(topTok).withValues(alpha: 0.78)
                              : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: pickCount > 0
                                ? Colors.amberAccent
                                : cs.outline.withValues(alpha: 0.35),
                            width: pickCount > 0 ? 2.5 : 1,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (topTok >= 0)
                                  Text(
                                    harmoniesTokenEmojis[topTok.clamp(0, 5)],
                                    style: const TextStyle(fontSize: 16),
                                  )
                                else
                                  Text(
                                    '$r,$c',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: cs.onSurface.withValues(alpha: 0.45),
                                    ),
                                  ),
                                if (st.isNotEmpty)
                                  Text(
                                    'H${st.length}${animId > 0 ? '🐾' : ''}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                if (pickCount > 0)
                                  Text(
                                    '+$pickCount',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amberAccent,
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
            ),
          ),
        ],
      ),
    );
  }
}
