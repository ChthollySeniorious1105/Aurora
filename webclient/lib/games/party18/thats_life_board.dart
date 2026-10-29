import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ThatsLifeBoard extends StatelessWidget {
  final GameContext g;
  const ThatsLifeBoard(this.g, {super.key});

  String _tileLabel(int pos, int val, bool active) {
    if (pos == 0) return '🏁起点';
    if (pos == 19) return '🏆终点';
    if (!active) return '已收走';
    if (val == 99) return '🍀守护草';
    if (val > 0) return '🟩+$val';
    return '🟥$val';
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final roll = (v['roll'] as num?)?.toInt() ?? 1;
    final tiles = (v['tiles'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(20, 0);
    final activeTiles = (v['activeTiles'] as List?)?.map((e) => e == true).toList() ??
        List<bool>.filled(20, true);
    final pawns = (v['pawns'] as List?) ?? const [];
    final guards = (v['guards'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final collected = (v['collected'] as List?) ?? const [];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final movableGuards = (v['movableGuards'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        const <int>[];
    final lastEvent = v['lastEvent'] as String? ?? '';
    final canAct = v['canAct'] == true && !g.over;

    final myPawns = (g.seat >= 0 && g.seat < pawns.length)
        ? (pawns[g.seat] as List).map((e) => (e as num).toInt()).toList()
        : const <int>[];

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '百变人生 — 旅途终点结算'
                          : '第 $round 轮 · 🎲当前点数: $roll · ${canAct ? "轮到你移动棋子或同格守卫" : "等待 ${g.name(turn)} 行动"}',
                      highlight: canAct,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.9)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Action Bar
                  if (canAct)
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
                      ),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '🎲 前进 $roll 步:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.primary),
                          ),
                          for (var i = 0; i < myPawns.length; i++)
                            if (myPawns[i] < 19)
                              FilledButton(
                                onPressed: () => g.act({'type': 'move_pawn', 'idx': i}),
                                child: Text(
                                  '🏃 移动 ${i + 1}号棋子 (第${myPawns[i]}格)',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                          for (final gPos in movableGuards)
                            FilledButton.tonal(
                              onPressed: () => g.act({'type': 'move_guard', 'pos': gPos}),
                              child: Text(
                                '🛡️ 移动第 $gPos 格中立守卫',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  // 20-Tile Linear Path
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🛤️ 20 格百变人生旅途（最后离开板块的棋子/守卫将使你收走该板块；🍀守护草可将所有红砖负分反转为正分！）',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            for (var pos = 0; pos < 20; pos++)
                              _buildPathTile(
                                cs: cs,
                                pos: pos,
                                val: pos < tiles.length ? tiles[pos] : 0,
                                active: pos < activeTiles.length ? activeTiles[pos] : true,
                                pawns: pawns,
                                guards: guards,
                                canAct: canAct,
                                myPawns: myPawns,
                                movableGuards: movableGuards,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Collections & Guardian Reversal Summary
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🎒 玩家已收集板块与🍀守护草反转状态',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        for (final s in g.seatsFromMe())
                          Builder(builder: (context) {
                            final items = s < collected.length
                                ? (collected[s] as List).map((e) => (e as num).toInt()).toList()
                                : const <int>[];
                            final hasClover = items.contains(99);
                            final itemText = items.isEmpty
                                ? '暂无板块'
                                : items
                                    .map((v) => v == 99
                                        ? '🍀守护草'
                                        : (v > 0
                                            ? '+$v'
                                            : (hasClover ? '(-$v→+${-v})' : '$v')))
                                    .join(' ');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '${g.name(s)}: ⭐${s < scores.length ? scores[s] : 0}分 ${hasClover ? "【🍀负分全转正！】" : ""} · $itemText',
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Player Tags
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        g.tag(
                          s,
                          active: turn == s && !g.over,
                          sub: '⭐${s < scores.length ? scores[s] : 0}分 · 🍀×${s < collected.length ? (collected[s] as List).where((e) => e == 99).length : 0}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '百变人生结束'),
            ),
        ],
      ),
    );
  }

  Widget _buildPathTile({
    required ColorScheme cs,
    required int pos,
    required int val,
    required bool active,
    required List pawns,
    required List<int> guards,
    required bool canAct,
    required List<int> myPawns,
    required List<int> movableGuards,
  }) {
    final guardCount = guards.where((gp) => gp == pos).length;
    final pawnBadges = <String>[];
    for (var s = 0; s < pawns.length; s++) {
      final pList = pawns[s] as List;
      var cnt = 0;
      for (final p in pList) {
        if ((p as num).toInt() == pos) cnt++;
      }
      if (cnt > 0) {
        pawnBadges.add('P${s + 1}${cnt > 1 ? "×$cnt" : ""}');
      }
    }
    if (guardCount > 0) {
      pawnBadges.add('🛡️${guardCount > 1 ? "×$guardCount" : ""}');
    }

    int? myPawnIdxHere;
    if (canAct && pos < 19) {
      for (var i = 0; i < myPawns.length; i++) {
        if (myPawns[i] == pos) {
          myPawnIdxHere = i;
          break;
        }
      }
    }

    Color bgColor;
    if (pos == 0 || pos == 19) {
      bgColor = cs.primaryContainer.withValues(alpha: 0.7);
    } else if (!active) {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.35);
    } else if (val == 99) {
      bgColor = Colors.amber.withValues(alpha: 0.3);
    } else if (val > 0) {
      bgColor = Colors.green.withValues(alpha: 0.25);
    } else {
      bgColor = Colors.redAccent.withValues(alpha: 0.25);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: myPawnIdxHere != null
          ? () => g.act({'type': 'move_pawn', 'idx': myPawnIdxHere})
          : null,
      child: Container(
        width: 82,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: myPawnIdxHere != null ? cs.primary : cs.outline.withValues(alpha: 0.3),
            width: myPawnIdxHere != null ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '#$pos ${_tileLabel(pos, val, active)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: active || pos == 0 || pos == 19
                    ? cs.onSurface
                    : cs.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              pawnBadges.isEmpty ? '—' : pawnBadges.join(' '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10, color: cs.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
