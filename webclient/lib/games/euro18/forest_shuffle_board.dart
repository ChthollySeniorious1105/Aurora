import 'package:aurora_shared/aurora_shared.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ForestShuffleBoard extends StatefulWidget {
  final GameContext g;
  const ForestShuffleBoard(this.g, {super.key});

  @override
  State<ForestShuffleBoard> createState() => _ForestShuffleBoardState();
}

class _ForestShuffleBoardState extends State<ForestShuffleBoard> {
  int _selectedCardId = -1;
  final Set<int> _selectedClearingIds = {};
  int? _inspectSeat;

  static const List<Color> _speciesColors = [
    Color(0xFF2E7D32), // 0: 🌳 橡树
    Color(0xFF00695C), // 1: 🌲 冷杉
    Color(0xFFEF6C00), // 2: 🍂 山毛榉
    Color(0xFFC62828), // 3: 🍁 槭树
    Color(0xFF558B2F), // 4: 🌿 桦树
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = asInt(v['round'], 1);
    final maxRounds = asInt(v['maxRounds'], 10);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final deckCount = asInt(v['deckCount'], 0);
    final clearing = (v['clearing'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final viewSeat = (_inspectSeat != null && _inspectSeat! < pList.length)
        ? _inspectSeat!
        : mySeat;
    final isMyTurn = !over && g.seat == turn;

    final viewData = (pList.isNotEmpty && viewSeat < pList.length)
        ? (pList[viewSeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final myHand = (myData['hand'] as List?) ?? const [];

    Map<String, dynamic>? selectedCard;
    for (final raw in myHand) {
      final m = (raw as Map).cast<String, dynamic>();
      if (asInt(m['id'], -1) == _selectedCardId) {
        selectedCard = m;
        break;
      }
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
                                    ? '轮到你！可抓2张牌、打出树木基座或将生灵塞入树木四向槽位 · $lastAction'
                                    : '等待 ${g.name(turn)} 行动 · $lastAction'),
                            highlight: isMyTurn,
                          ),
                        ),
                      ),
                      if (isMyTurn && myHand.length < 10) ...[
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            final ids = _selectedClearingIds.take(2).toList();
                            setState(() => _selectedClearingIds.clear());
                            g.act({
                              'type': 'take_cards',
                              'clearingIds': ids,
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.teal.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedClearingIds.isEmpty
                                  ? '🃏 摸 2 张牌'
                                  : '🃏 拿所选(${_selectedClearingIds.length})并补满2张',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🌲第 $round/$maxRounds 轮 · 牌库$deckCount',
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
                        final hc = asInt(pd['handCount'], 0);
                        final spVp = asInt(pd['speciesBonusVp'], 0);
                        final fList = (pd['forest'] as List?) ?? const [];
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
                                  '⭐$sc分 (契合+$spVp) · 🌳${fList.length}棵 · ✋$hc张',
                              size: 26,
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
                                child: _buildClearingAndHandPanel(
                                  clearing,
                                  myHand,
                                  selectedCard,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildForestPanel(
                                  viewSeat,
                                  viewData,
                                  selectedCard,
                                  isMyTurn && viewSeat == mySeat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: _buildClearingAndHandPanel(
                                  clearing,
                                  myHand,
                                  selectedCard,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildForestPanel(
                                  viewSeat,
                                  viewData,
                                  selectedCard,
                                  isMyTurn && viewSeat == mySeat,
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
                '森林洗牌终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClearingAndHandPanel(
    List<dynamic> clearing,
    List<dynamic> myHand,
    Map<String, dynamic>? selectedCard,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🌼 林间空地 (${clearing.length} 张 · 点选最多 2 张后点击右上角拿牌)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 4,
            child: clearing.isEmpty
                ? const Center(
                    child: Text('林间空地暂无卡牌', style: TextStyle(fontSize: 10)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: clearing.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, idx) {
                      final c = (clearing[idx] as Map).cast<String, dynamic>();
                      final cid = asInt(c['id'], -1);
                      final sel = _selectedClearingIds.contains(cid);
                      return _buildCardTile(
                        c,
                        selected: sel,
                        onTap: () => setState(() {
                          if (sel) {
                            _selectedClearingIds.remove(cid);
                          } else if (_selectedClearingIds.length < 2) {
                            _selectedClearingIds.add(cid);
                          }
                        }),
                        cs: cs,
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '✋ 我的手牌 (${myHand.length}/10 张 · 点选树木种植，或点选生灵后点击右侧树木塞入)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ),
              if (isMyTurn && selectedCard != null) ...[
                const SizedBox(width: 4),
                if (selectedCard['kind'] == 'tree' &&
                    myHand.length - 1 >= asInt(selectedCard['cost'], 0))
                  InkWell(
                    onTap: () {
                      final cid = asInt(selectedCard['id'], -1);
                      setState(() => _selectedCardId = -1);
                      widget.g.act({
                        'type': 'play_tree',
                        'cardId': cid,
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.shade700,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '🌳 种植 ${selectedCard['name']}(费${selectedCard['cost']})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else
                  InkWell(
                    onTap: () {
                      final cid = asInt(selectedCard['id'], -1);
                      setState(() => _selectedCardId = -1);
                      widget.g.act({
                        'type': 'play_tree',
                        'cardId': cid,
                        'asSapling': true,
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.brown.shade600,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '🌱 作免费树苗种下(0费)',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
          const SizedBox(height: 3),
          Expanded(
            flex: 5,
            child: myHand.isEmpty
                ? const Center(
                    child: Text('当前没有手牌', style: TextStyle(fontSize: 10)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: myHand.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, idx) {
                      final c = (myHand[idx] as Map).cast<String, dynamic>();
                      final cid = asInt(c['id'], -1);
                      final sel = _selectedCardId == cid;
                      return _buildCardTile(
                        c,
                        selected: sel,
                        onTap: () => setState(() {
                          _selectedCardId = sel ? -1 : cid;
                        }),
                        cs: cs,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardTile(
    Map<String, dynamic> c, {
    required bool selected,
    required VoidCallback onTap,
    required ColorScheme cs,
  }) {
    final sp = asInt(c['species'], 0).clamp(0, 4);
    final isTree = c['kind'] == 'tree';
    final sCol = _speciesColors[sp];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 108,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected
              ? sCol.withValues(alpha: 0.28)
              : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? Colors.amber : sCol,
            width: selected ? 2.2 : 1.2,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${c['speciesEmoji']}${c['emoji']} ${c['name']}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
              Text(
                isTree
                    ? '🌳树木基座 · 费:${c['cost']} · ⭐${c['baseVp']}'
                    : '槽:${c['slotName']} · 费:${c['cost']}',
                style: const TextStyle(fontSize: 9.5),
              ),
              Text(
                '${c['synergyDesc']}',
                style: TextStyle(
                  fontSize: 8.5,
                  color: cs.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForestPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    Map<String, dynamic>? selectedCard,
    bool canActHere,
    ColorScheme cs,
  ) {
    final forest = (viewData['forest'] as List?) ?? const [];
    final bd =
        (viewData['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '🌲 ${widget.g.name(viewSeat)} 的个人森林 (${forest.length} 棵树 · 树木${bd['treeVp'] ?? 0} 🦋${bd['butterflyVp'] ?? 0} 🦉${bd['owlVp'] ?? 0} 🍄🐸${asInt(bd['mushroomVp'], 0) + asInt(bd['frogVp'], 0)} 🦌🐺${asInt(bd['deerVp'], 0) + asInt(bd['wolfVp'], 0)} 🌿🐰${asInt(bd['plantVp'], 0) + asInt(bd['hareVp'], 0)})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 230,
                mainAxisExtent: 108,
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
              ),
              itemCount: forest.length,
              itemBuilder: (context, tIdx) {
                final slot = (forest[tIdx] as Map).cast<String, dynamic>();
                return _buildTreeSlotCard(
                  tIdx,
                  slot,
                  selectedCard,
                  canActHere,
                  cs,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeSlotCard(
    int tIdx,
    Map<String, dynamic> slot,
    Map<String, dynamic>? selectedCard,
    bool canActHere,
    ColorScheme cs,
  ) {
    final tree = (slot['tree'] as Map).cast<String, dynamic>();
    final top = slot['top'] as Map<String, dynamic>?;
    final bottom = slot['bottom'] as Map<String, dynamic>?;
    final left = slot['left'] as Map<String, dynamic>?;
    final right = slot['right'] as Map<String, dynamic>?;

    final sp = asInt(tree['species'], 0).clamp(0, 4);
    final sCol = _speciesColors[sp];

    var canTuckSelected = false;
    if (canActHere &&
        selectedCard != null &&
        selectedCard['kind'] == 'dweller') {
      final dir = asInt(selectedCard['slotDir'], -1);
      if (dir == 0 && top == null) canTuckSelected = true;
      if (dir == 1 && bottom == null) canTuckSelected = true;
      if (dir == 2 && left == null) canTuckSelected = true;
      if (dir == 3 && right == null) canTuckSelected = true;
    }

    return GestureDetector(
      onTap: !canTuckSelected
          ? null
          : () {
              final cid = asInt(selectedCard!['id'], -1);
              setState(() => _selectedCardId = -1);
              widget.g.act({
                'type': 'tuck_dweller',
                'cardId': cid,
                'treeIdx': tIdx,
              });
            },
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: canTuckSelected
              ? Colors.amber.withValues(alpha: 0.22)
              : sCol.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: canTuckSelected ? Colors.amber : sCol,
            width: canTuckSelected ? 2.2 : 1.4,
          ),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top slot (dir 0)
              _buildSlotBadge('⬆️冠', top, cs),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildSlotBadge('⬅️左', left, cs),
                  const SizedBox(width: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: sCol.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: sCol),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${tree['speciesEmoji']}${tree['name']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                        Text(
                          '⭐${tree['baseVp']}分',
                          style: const TextStyle(fontSize: 8.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildSlotBadge('➡️右', right, cs),
                ],
              ),
              const SizedBox(height: 2),
              // Bottom slot (dir 1)
              _buildSlotBadge('⬇️根', bottom, cs),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotBadge(
      String dirLabel, Map<String, dynamic>? dweller, ColorScheme cs) {
    if (dweller == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '$dirLabel:空',
          style: TextStyle(
            fontSize: 8.5,
            color: cs.onSurface.withValues(alpha: 0.55),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '${dweller['emoji']}${dweller['name']}',
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }
}
