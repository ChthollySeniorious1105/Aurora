import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a9_common.dart';

class TentsBoard extends StatefulWidget {
  final GameContext g;
  const TentsBoard(this.g, {super.key});
  @override
  State<TentsBoard> createState() => _TentsBoardState();
}

class _TentsBoardState extends State<TentsBoard> {
  GameContext get g => widget.g;
  // 0 = cycle (0->1->2->0), 1 = Tent ⛺ (toggle 1/0), 2 = Grass 🌿 (toggle 2/0)
  int _toolMode = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int currentMark, bool tree) {
    if (!_canPlay || tree) return;
    if (_toolMode == 0) {
      g.act({'type': 'toggle', 'r': r, 'c': c});
    } else if (_toolMode == 1) {
      final next = currentMark == 1 ? 0 : 1;
      g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
    } else {
      final next = currentMark == 2 ? 0 : 2;
      g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
    }
  }

  void _onCellSecondaryTap(int r, int c, int currentMark, bool tree) {
    if (!_canPlay || tree) return;
    final next = currentMark == 2 ? 0 : 2;
    g.act({'type': 'toggle', 'r': r, 'c': c, 'val': next});
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final phase = aStr(v['phase']);
    final round = aInt(v['round'], 1);
    final totalRounds = math.max(1, aInt(v['totalRounds'], 3));
    final size = math.max(5, aInt(v['size'], 5));
    final left = aInt(v['left'], 0);
    final isTree = aBools(v['isTree']);
    final rowClues = aInts(v['rowClues']);
    final colClues = aInts(v['colClues']);
    final marks = aInts(v['marks']);
    final rowCounts = aInts(v['rowCounts']);
    final colCounts = aInts(v['colCounts']);
    final conflicts = aInts(v['conflicts']).toSet();
    final matchedPairs = aInt(v['matchedPairs'], 0);
    final totalTrees = math.max(1, aInt(v['totalTrees'], 5));
    final satisfiedLines = aInt(v['satisfiedLines'], 0);
    final totalLines = math.max(1, aInt(v['totalLines'], 2 * size));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '帐篷露营竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已完成树帐配对（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warn = conflicts.isNotEmpty ? ' · ⚠ 存在帐篷冲突' : '';
      status =
          '第 $round/$totalRounds 题（$size×$size）· 配对 $matchedPairs/$totalTrees · 行列达标 $satisfiedLines/$totalLines$warn · ${left}s';
    }

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth > box.maxHeight * 1.12;
      final sideW = wide ? math.min(200.0, box.maxWidth * 0.24) : 0.0;
      final topStripH = wide ? 0.0 : 58.0;

      final playerTiles = Wrap(
        direction: wide ? Axis.vertical : Axis.horizontal,
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: [
          for (final s in g.seatsFromMe())
            if (s < ps.length) _buildPlayerTile(s, ps[s], totalRounds, wide ? sideW - 12 : 140),
        ],
      );

      final workspace = _buildWorkspace(
        context,
        cs: cs,
        size: size,
        isTree: isTree,
        rowClues: rowClues,
        colClues: colClues,
        marks: marks,
        rowCounts: rowCounts,
        colCounts: colCounts,
        conflicts: conflicts,
        matchedPairs: matchedPairs,
        totalTrees: totalTrees,
        satisfiedLines: satisfiedLines,
        totalLines: totalLines,
        wide: wide,
      );

      Widget body;
      if (wide) {
        body = Row(children: [
          SizedBox(
            width: sideW,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(6),
                child: FittedBox(fit: BoxFit.scaleDown, child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      } else {
        body = Column(children: [
          SizedBox(
            height: topStripH,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: playerTiles),
              ),
            ),
          ),
          Expanded(child: Center(child: workspace)),
        ]);
      }

      return Column(children: [
        SizedBox(height: 38, child: aStatus(status, highlight: _canPlay)),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: body),
            if (phase == 'over')
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  child: aRanking(
                    g,
                    aMaps(v['final']),
                    (r) => '${r['score']} 分 · 解出 ${r['solved']}/$totalRounds 题',
                  ),
                ),
              ),
          ]),
        ),
      ]);
    });
  }

  Widget _buildPlayerTile(int s, Map<String, dynamic> p, int totalRounds, double width) {
    final st = aStr(p['status']);
    final score = aInt(p['score'], 0);
    final solved = aInt(p['solved'], 0);
    final matched = aInt(p['matched'], 0);
    final totalTrees = math.max(1, aInt(p['totalTrees'], 5));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$matched/$totalTrees配对', null),
    };
    return A9ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (matched / totalTrees),
      badge: badge,
      badgeColor: col,
      dim: st == 'resigned',
      sub: '积分 $score · 解出 $solved/$totalRounds',
    );
  }

  Widget _buildWorkspace(
    BuildContext context, {
    required ColorScheme cs,
    required int size,
    required List<bool> isTree,
    required List<int> rowClues,
    required List<int> colClues,
    required List<int> marks,
    required List<int> rowCounts,
    required List<int> colCounts,
    required Set<int> conflicts,
    required int matchedPairs,
    required int totalTrees,
    required int satisfiedLines,
    required int totalLines,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF17261C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.45), width: 1.8),
        boxShadow: const [BoxShadow(blurRadius: 12, color: Colors.black38, offset: Offset(0, 4))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < size; r++)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var c = 0; c < size; c++)
                  _buildCell(
                    r: r,
                    c: c,
                    size: size,
                    cellPx: cellPx,
                    isTree: isTree,
                    marks: marks,
                    conflicts: conflicts,
                  ),
                const SizedBox(width: 6),
                _buildClueBadge(
                  clue: r < rowClues.length ? rowClues[r] : 0,
                  cur: r < rowCounts.length ? rowCounts[r] : 0,
                ),
              ],
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < size; c++)
                SizedBox(
                  width: cellPx + 2.4,
                  child: Center(
                    child: _buildClueBadge(
                      clue: c < colClues.length ? colClues[c] : 0,
                      cur: c < colCounts.length ? colCounts[c] : 0,
                    ),
                  ),
                ),
              const SizedBox(width: 32),
            ],
          ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 220 : 340),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              A9Chip('树帐配对 $matchedPairs/$totalTrees', const Color(0xFF2E7D32), size: 11),
              A9Chip('行列线索 $satisfiedLines/$totalLines', cs.primary, size: 11),
              A9Chip(
                conflicts.isEmpty ? '✓ 扎营合规' : '⚠ 帐篷冲突',
                conflicts.isEmpty ? Colors.teal : Colors.redAccent,
                size: 11,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('循环切换', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 0,
                onSelected: (_) => setState(() => _toolMode = 0),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('搭帐篷 ⛺', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 1,
                onSelected: (_) => setState(() => _toolMode = 1),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('标草地 🌿', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 2,
                onSelected: (_) => setState(() => _toolMode = 2),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _canPlay ? () => g.act({'type': 'clear'}) : null,
                icon: const Icon(Icons.layers_clear, size: 15),
                label: const Text('清空', style: TextStyle(fontSize: 12)),
              ),
              FilledButton.tonalIcon(
                onPressed: _canPlay ? () => g.act({'type': 'pass'}) : null,
                icon: const Icon(Icons.flag_outlined, size: 15),
                label: const Text('放弃', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: wide
            ? Row(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(width: 12),
                toolbar,
              ])
            : Column(mainAxisSize: MainAxisSize.min, children: [
                gridCard,
                const SizedBox(height: 8),
                toolbar,
              ]),
      ),
    );
  }

  Widget _buildClueBadge({required int clue, required int cur}) {
    final exact = cur == clue;
    final over = cur > clue;
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: over
            ? const Color(0xFFD32F2F)
            : (exact ? const Color(0xFF2E7D32) : const Color(0xFF263238)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: over
              ? const Color(0xFFFF8A80)
              : (exact ? const Color(0xFFA5D6A7) : const Color(0xFF546E7A)),
          width: 1.4,
        ),
      ),
      child: Text(
        '$clue',
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<bool> isTree,
    required List<int> marks,
    required Set<int> conflicts,
  }) {
    final idx = r * size + c;
    final tree = idx < isTree.length && isTree[idx];
    final mark = idx < marks.length ? marks[idx] : 0;
    final isConflict = conflicts.contains(idx);

    if (tree) {
      return Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: const Color(0xFFC8E6C9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E7D32), width: 1.6),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.park_rounded,
          size: cellPx * 0.62,
          color: const Color(0xFF1B5E20),
        ),
      );
    }

    Color bgColor;
    Color borderColor;
    Widget? content;

    if (mark == 1) {
      bgColor = isConflict ? const Color(0xFFFFEBEE) : const Color(0xFFFFF3E0);
      borderColor = isConflict ? const Color(0xFFD32F2F) : const Color(0xFFEF6C00);
      content = Icon(
        Icons.change_history_rounded,
        size: cellPx * 0.64,
        color: isConflict ? const Color(0xFFC62828) : const Color(0xFFE65100),
      );
    } else if (mark == 2) {
      bgColor = const Color(0xFFE8F5E9);
      borderColor = const Color(0xFF81C784);
      content = Icon(
        Icons.grass_rounded,
        size: cellPx * 0.46,
        color: const Color(0xFF43A047),
      );
    } else {
      bgColor = const Color(0xFFF5F5DC);
      borderColor = const Color(0xFFA1887F);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, mark, tree),
      onSecondaryTap: () => _onCellSecondaryTap(r, c, mark, tree),
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.2),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: mark == 1 ? 2.2 : 1.2),
        ),
        alignment: Alignment.center,
        child: content,
      ),
    );
  }
}
