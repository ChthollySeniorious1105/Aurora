import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _seatColors = [
  Color(0xFFD32F2F),
  Color(0xFF1976D2),
  Color(0xFF388E3C),
  Color(0xFFFBC02D),
];

const Map<String, (String, String, Color)> _jungleMeta = {
  'plant1': ('🍫×1', '可可园', Color(0xFF5D4037)),
  'plant2': ('🍫×2', '双倍园', Color(0xFF4E342E)),
  'market2': ('💰2', '2金集市', Color(0xFFF57F17)),
  'market3': ('💰3', '3金集市', Color(0xFFE65100)),
  'market4': ('💰4', '4金集市', Color(0xFFBF360C)),
  'mine1': ('⛏️1', '1金矿', Color(0xFF607D8B)),
  'mine2': ('⛏️2', '2金矿', Color(0xFF455A64)),
  'water': ('💧', '水源', Color(0xFF0288D1)),
  'temple': ('🏛️6/3', '神庙', Color(0xFF7B1FA2)),
};

class CacaoBoard extends StatefulWidget {
  final GameContext g;
  const CacaoBoard(this.g, {super.key});

  @override
  State<CacaoBoard> createState() => _CacaoBoardState();
}

class _CacaoBoardState extends State<CacaoBoard> {
  int _selHand = 0;
  int _rot = 0;
  int _selMarket = 0;

  List<int> _rotateEdges(List<int> edges, int rot) {
    final r = rot & 3;
    return [for (var d = 0; d < 4; d++) edges[(d - r) & 3]];
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'place_worker'}';
    final over = v['over'] == true || g.over;
    final lastAction = '${v['lastAction'] ?? ''}';
    final jungleMarket = (v['jungleMarket'] as List?)?.map((e) => '$e').toList() ?? const [];
    final jungleDeckCount = (v['jungleDeckCount'] as num?)?.toInt() ?? 0;
    final hand = (v['hand'] as List?)
            ?.map((t) => (t as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        const [];
    final players = (v['players'] as List?) ?? const [];
    final placings = (v['placings'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;

    if (_selHand >= hand.length) _selHand = 0;
    if (_selMarket >= jungleMarket.length) _selMarket = 0;

    final workers = <(int, int), (int, List<int>)>{};
    for (final w in (v['workerBoard'] as List?) ?? const []) {
      final m = w as Map;
      final r = (m['r'] as num).toInt();
      final c = (m['c'] as num).toInt();
      final seat = (m['seat'] as num).toInt();
      final edges = (m['edges'] as List).map((e) => (e as num).toInt()).toList();
      workers[(r, c)] = (seat, edges);
    }

    final jungles = <(int, int), String>{};
    for (final j in (v['jungleBoard'] as List?) ?? const []) {
      final m = j as Map;
      final r = (m['r'] as num).toInt();
      final c = (m['c'] as num).toInt();
      final type = '${m['type']}';
      jungles[(r, c)] = type;
    }

    final validWorkerCells = <(int, int)>{};
    for (final c in (v['validWorkerCells'] as List?) ?? const []) {
      final l = c as List;
      validWorkerCells.add(((l[0] as num).toInt(), (l[1] as num).toInt()));
    }

    final pendingJungleCells = <(int, int)>{};
    for (final c in (v['pendingJungleCells'] as List?) ?? const []) {
      final l = c as List;
      pendingJungleCells.add(((l[0] as num).toInt(), (l[1] as num).toInt()));
    }

    // Compute bounding box
    var minR = 0, maxR = 1, minC = 0, maxC = 1;
    final allCoords = <(int, int)>[
      ...workers.keys,
      ...jungles.keys,
      if (myTurn && phase == 'place_worker') ...validWorkerCells,
      if (phase == 'place_jungle') ...pendingJungleCells,
    ];
    for (final (r, c) in allCoords) {
      if (r < minR) minR = r;
      if (r > maxR) maxR = r;
      if (c < minC) minC = c;
      if (c > maxC) maxC = c;
    }

    String statusText;
    if (over) {
      statusText = '游戏结束 · $lastAction';
    } else if (myTurn) {
      statusText = phase == 'place_jungle'
          ? '轮到你：先在下方选择丛林板块，再点击棋盘高亮丛林格放入'
          : '轮到你：选择手牌工人板块（可旋转），点击棋盘高亮工人格放置';
    } else {
      statusText = '等待 ${g.name(turn)} (${phase == 'place_jungle' ? '放置丛林板块' : '放置工人板块'}) · $lastAction';
    }

    Widget buildWorkerTilePreview(List<int> edges, int seat, {double size = 56, bool selected = false}) {
      final col = _seatColors[seat % _seatColors.length];
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: col.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.white : Colors.black54, width: selected ? 2.5 : 1.2),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text('${edges[0]}', style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 3),
                child: Text('${edges[1]}', style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text('${edges[2]}', style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Text('${edges[3]}', style: TextStyle(fontSize: size * 0.22, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
            ),
            Center(
              child: Icon(Icons.person, size: size * 0.28, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ],
        ),
      );
    }

    Widget buildJungleTileBox(String jType, {double size = 56, bool selected = false}) {
      final meta = _jungleMeta[jType] ?? ('🌿', jType, const Color(0xFF2E7D32));
      return Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: meta.$3.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? Colors.amberAccent : Colors.white54, width: selected ? 2.5 : 1.2),
          boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black26, offset: Offset(0, 1))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(meta.$1, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              Text(meta.$2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      );
    }

    Widget buildGridCell(int r, int c) {
      const cellSize = 54.0;
      if (workers.containsKey((r, c))) {
        final (owner, edges) = workers[(r, c)]!;
        return Padding(
          padding: const EdgeInsets.all(2),
          child: buildWorkerTilePreview(edges, owner, size: cellSize),
        );
      }
      if (jungles.containsKey((r, c))) {
        return Padding(
          padding: const EdgeInsets.all(2),
          child: buildJungleTileBox(jungles[(r, c)]!, size: cellSize),
        );
      }
      final isPendingJ = pendingJungleCells.contains((r, c));
      if (isPendingJ) {
        return Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: myTurn && phase == 'place_jungle'
                ? () => g.act({
                      'type': 'place_jungle',
                      'marketIdx': _selMarket,
                      'r': r,
                      'c': c,
                    })
                : null,
            child: Container(
              width: cellSize,
              height: cellSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amberAccent, width: 2),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.park, size: 18, color: Colors.amberAccent),
                    Text('填丛林\n($r,$c)', textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final isValidW = myTurn && phase == 'place_worker' && validWorkerCells.contains((r, c));
      if (isValidW) {
        return Padding(
          padding: const EdgeInsets.all(2),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => g.act({
              'type': 'place_worker',
              'handIdx': _selHand,
              'r': r,
              'c': c,
              'rot': _rot,
            }),
            child: Container(
              width: cellSize,
              height: cellSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cs.primary, width: 1.8),
              ),
              child: Text(
                '放工人\n($r,$c)',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.primary),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(2),
        child: Container(
          width: cellSize,
          height: cellSize,
          decoration: BoxDecoration(
            color: (r + c).isEven ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      );
    }

    final rowsCount = max(1, maxR - minR + 1);
    final colsCount = max(1, maxC - minC + 1);

    final boardGrid = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = minR; r < minR + rowsCount; r++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = minC; c < minC + colsCount; c++) buildGridCell(r, c),
                ],
              ),
          ],
        ),
      ),
    );

    final controlsPanel = Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Jungle Market
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('丛林市场', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
                  Text('牌库剩 $jungleDeckCount', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(width: 8),
              for (var m = 0; m < jungleMarket.length; m++) ...[
                GestureDetector(
                  onTap: () => setState(() => _selMarket = m),
                  child: buildJungleTileBox(
                    jungleMarket[m],
                    size: 52,
                    selected: phase == 'place_jungle' && _selMarket == m,
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
          // My Hand of Worker Tiles
          if (me >= 0 && hand.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('手牌:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface)),
                for (var h = 0; h < hand.length; h++)
                  GestureDetector(
                    onTap: () => setState(() => _selHand = h),
                    child: buildWorkerTilePreview(
                      _rotateEdges(hand[h], _selHand == h ? _rot : 0),
                      me,
                      size: 48,
                      selected: _selHand == h,
                    ),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() => _rot = (_rot + 1) & 3),
                  icon: const Icon(Icons.rotate_right, size: 16),
                  label: Text('旋转(${_rot * 90}°)'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
              ],
            ),
        ],
      ),
    );

    Widget buildPlayerStatus(int s) {
      if (s < 0 || s >= players.length) return const SizedBox();
      final p = players[s] as Map;
      final gold = (p['gold'] as num?)?.toInt() ?? 0;
      final cacao = (p['cacao'] as num?)?.toInt() ?? 0;
      final waterScore = (p['waterScore'] as num?)?.toInt() ?? -10;
      final templeBonus = (p['templeBonus'] as num?)?.toInt() ?? 0;
      final totalScore = (p['totalScore'] as num?)?.toInt() ?? 0;
      final handCount = (p['handCount'] as num?)?.toInt() ?? 0;
      final deckCount = (p['deckCount'] as num?)?.toInt() ?? 0;
      final active = !over && turn == s;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? cs.primary : _seatColors[s % _seatColors.length].withValues(alpha: 0.6),
            width: active ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            g.tag(s, active: active, size: 28, sub: '总分: $totalScore · 剩${handCount + deckCount}块'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text('💰金币: $gold', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('🍫可可: $cacao/5', style: const TextStyle(fontSize: 11)),
                Text('💧水源: ${waterScore >= 0 ? '+$waterScore' : '$waterScore'}', style: const TextStyle(fontSize: 11)),
                Text('🏛️神庙: +$templeBonus', style: const TextStyle(fontSize: 11)),
              ],
            ),
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
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe()) buildPlayerStatus(s),
                  ],
                ),
                const SizedBox(height: 8),
                Center(child: controlsPanel),
                const SizedBox(height: 8),
                Center(child: boardGrid),
              ],
            ),
          ),
          if (resultBanner != null) Align(alignment: Alignment.topCenter, child: resultBanner),
        ],
      ),
    );
  }
}
