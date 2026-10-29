import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro12/canvas.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CanvasBoard extends StatefulWidget {
  final GameContext g;
  const CanvasBoard(this.g, {super.key});

  @override
  State<CanvasBoard> createState() => _CanvasBoardState();
}

class _CanvasBoardState extends State<CanvasBoard> {
  final List<int> _selectedHandIndices = [0, 1, 2];

  Color _swatchColor(int c) {
    return switch (c) {
      0 => const Color(0xFFE53935), // Red
      1 => const Color(0xFFFBC02D), // Amber
      2 => const Color(0xFF43A047), // Green
      3 => const Color(0xFF1E88E5), // Blue
      4 => const Color(0xFF8E24AA), // Purple
      _ => Colors.grey,
    };
  }

  void _syncSelectedHand(int handLen) {
    _selectedHandIndices.removeWhere((i) => i < 0 || i >= handLen);
    for (var i = 0; i < handLen && _selectedHandIndices.length < 3; i++) {
      if (!_selectedHandIndices.contains(i)) {
        _selectedHandIndices.add(i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final targetPaintings = asInt(v['targetPaintings'], 3);
    final deckCount = asInt(v['deckCount'], 0);
    final market = (v['market'] as List?) ?? const [];
    final tokensOn = asIntList(v['tokensOn']);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final pList = (v['players'] as List?) ?? const [];

    final mySeat = g.seat >= 0 && g.seat < pList.length ? g.seat : turn;
    final isMyTurn = !over && g.seat == turn;

    final myData = (pList.isNotEmpty && mySeat < pList.length)
        ? (pList[mySeat] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final myHand = (myData['hand'] as List?) ?? const [];
    final myTokens = asInt(myData['tokens'], 0);
    _syncSelectedHand(myHand.length);

    return Container(
      color: g.table,
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top bar
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: StatusBar(
                        over
                            ? '画展圆满落幕 · $lastAction'
                            : (isMyTurn
                                ? '轮到你！从市场拿取艺术卡，或叠合 3 张手牌完成画作 · $lastAction'
                                : '等待 ${g.name(turn)} 创作 · $lastAction'),
                        highlight: isMyTurn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🖼️目标$targetPaintings幅 · 牌库$deckCount',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // Player Tags
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: pList.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, s) {
                    final pd = (pList[s] as Map).cast<String, dynamic>();
                    final sc = asInt(pd['score'], 0);
                    final tk = asInt(pd['tokens'], 0);
                    final gal = ((pd['gallery'] as List?) ?? const []).length;
                    return g.tag(
                      s,
                      active: s == turn,
                      sub: '$sc分 · 🎨$tk · 🖼️$gal/$targetPaintings',
                      size: 28,
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              // Central Market Row
              Expanded(
                flex: 4,
                child: _buildMarketSection(
                  market,
                  tokensOn,
                  myTokens,
                  myHand.length,
                  isMyTurn,
                  cs,
                ),
              ),
              const SizedBox(height: 4),
              // Hand & Layering Workbench + Gallery
              Expanded(
                flex: 6,
                child: _buildStudioSection(
                  mySeat,
                  myData,
                  myHand,
                  isMyTurn,
                  cs,
                ),
              ),
            ],
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '画布艺术展终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMarketSection(
    List<dynamic> market,
    List<int> tokensOn,
    int myTokens,
    int myHandLen,
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
                  '🖼️ 中央画廊市场（拿取第 k 张需花费 k 枚🎨灵感，并获得卡上所有🎨灵感）',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text(
                '我的灵感: 🎨$myTokens',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: market.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, slot) {
                final cm = (market[slot] as Map).cast<String, dynamic>();
                final sitting = slot < tokensOn.length ? tokensOn[slot] : 0;
                final canTake =
                    isMyTurn && myHandLen < 5 && myTokens >= slot;

                return GestureDetector(
                  onTap: canTake
                      ? () => widget.g.act({'type': 'take', 'slot': slot})
                      : null,
                  child: Container(
                    width: 148,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: canTake
                          ? cs.primaryContainer.withValues(alpha: 0.55)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: canTake
                            ? cs.primary
                            : cs.outline.withValues(alpha: 0.3),
                        width: canTake ? 1.8 : 0.8,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 136,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '「${cm['titlePart']}」',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  slot == 0 ? '免费' : '花费🎨$slot',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: canTake ? cs.primary : cs.error,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildZonesRow(
                                (cm['zones'] as List?) ?? const [], cs),
                            const SizedBox(height: 4),
                            Text(
                              sitting > 0 ? '卡上附带 +🎨$sitting' : '卡上无额外灵感',
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

  Widget _buildStudioSection(
    int mySeat,
    Map<String, dynamic> myData,
    List<dynamic> myHand,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final gallery = (myData['gallery'] as List?) ?? const [];
    final ribbons = asIntList(myData['ribbons']);

    // Compute live preview of layering _selectedHandIndices
    final previewZones = List<Map<String, dynamic>?>.filled(3, null);
    final previewTitles = <String>[];
    if (_selectedHandIndices.length == 3 && myHand.length >= 3) {
      for (final idx in _selectedHandIndices) {
        if (idx >= 0 && idx < myHand.length) {
          final cm = (myHand[idx] as Map).cast<String, dynamic>();
          previewTitles.add(asStr(cm['titlePart']));
          final zs = (cm['zones'] as List?) ?? const [];
          for (var z = 0; z < 3 && z < zs.length; z++) {
            if (zs[z] is Map) {
              previewZones[z] = (zs[z] as Map).cast<String, dynamic>();
            }
          }
        }
      }
    }

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
          Wrap(
            spacing: 6,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${widget.g.name(mySeat)} 的手牌 (${myHand.length}/5) · 点击切换 [底层→中层→顶层] 叠合顺序',
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              if (ribbons.length >= 5)
                Text(
                  '🎗️绶带: ☀️${ribbons[0]} 🔺${ribbons[1]} 🌀${ribbons[2]} 🌿${ribbons[3]} ⭐${ribbons[4]}',
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: myHand.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final cm = (myHand[idx] as Map).cast<String, dynamic>();
                final orderPos = _selectedHandIndices.indexOf(idx);
                final layerLabel = switch (orderPos) {
                  0 => '1️⃣底层',
                  1 => '2️⃣中层',
                  2 => '3️⃣顶层',
                  _ => '未选',
                };

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedHandIndices.contains(idx)) {
                        _selectedHandIndices.remove(idx);
                        _selectedHandIndices.add(idx);
                      } else {
                        if (_selectedHandIndices.length >= 3) {
                          _selectedHandIndices.removeAt(0);
                        }
                        _selectedHandIndices.add(idx);
                      }
                    });
                  },
                  child: Container(
                    width: 144,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: orderPos >= 0
                          ? cs.secondaryContainer
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: orderPos >= 0 ? cs.primary : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: 132,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '「${cm['titlePart']}」',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: cs.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    layerLabel,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildZonesRow(
                                (cm['zones'] as List?) ?? const [], cs),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          // Live Preview & Paint Button + Completed Paintings
          Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (previewTitles.length == 3)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '预览《${previewTitles.join("·")}》:',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 6),
                    _buildZonesRow(previewZones, cs),
                  ],
                ),
              if (isMyTurn && myHand.length >= 3 && _selectedHandIndices.length == 3)
                InkWell(
                  onTap: () => widget.g.act({
                    'type': 'paint',
                    'cards': List<int>.of(_selectedHandIndices),
                  }),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '🎨 叠合完成此画作',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
                ),
              if (gallery.isNotEmpty)
                Text(
                  '已展画作: ${[
                    for (final mp in gallery)
                      '${(mp as Map)['title']}(${mp['vp']}分)'
                  ].join(' ')}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildZonesRow(List<dynamic> zones, ColorScheme cs) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Builder(
            builder: (context) {
              final z = i < zones.length ? zones[i] : null;
              if (z is! Map) {
                return Container(
                  width: 38,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: cs.outline.withValues(alpha: 0.4),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      '透明',
                      style: TextStyle(fontSize: 9),
                    ),
                  ),
                );
              }
              final zm = z.cast<String, dynamic>();
              final col = asInt(zm['color'], 0);
              final ic = asInt(zm['icon'], 0);
              return Container(
                width: 38,
                height: 28,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _swatchColor(col),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Center(
                  child: Text(
                    canvasIconEmojis[ic.clamp(0, 4)],
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
