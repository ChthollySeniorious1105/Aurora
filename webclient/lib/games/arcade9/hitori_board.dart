import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a9_common.dart';

class HitoriBoard extends StatefulWidget {
  final GameContext g;
  const HitoriBoard(this.g, {super.key});
  @override
  State<HitoriBoard> createState() => _HitoriBoardState();
}

class _HitoriBoardState extends State<HitoriBoard> {
  GameContext get g => widget.g;
  // 0 = cycle (0->1->2->0), 1 = shade black (toggle 1/0), 2 = circle safe (toggle 2/0)
  int _toolMode = 0;

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  void _onCellTap(int r, int c, int currentMark) {
    if (!_canPlay) return;
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

  void _onCellSecondaryTap(int r, int c, int currentMark) {
    if (!_canPlay) return;
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
    final grid = aInts(v['grid']);
    final marks = aInts(v['marks']);
    final duplicates = aInts(v['duplicates']).toSet();
    final adjBlacks = aInts(v['adjBlacks']).toSet();
    final disconnected = aInts(v['disconnected']).toSet();
    final whiteConnected = v['whiteConnected'] != false;
    final cleanLines = aInt(v['cleanLines'], 0);
    final totalLines = math.max(1, aInt(v['totalLines'], 2 * size));
    final ps = aMaps(v['ps']);

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数独涂黑竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出数独涂黑（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (duplicates.isNotEmpty) '重复数字 ${duplicates.length} 格',
        if (adjBlacks.isNotEmpty) '黑格相邻',
        if (!whiteConnected) '白格被隔断',
      ];
      final warnStr = warnings.isEmpty ? '无冲突' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 无重行列 $cleanLines/$totalLines · $warnStr · ${left}s';
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
        grid: grid,
        marks: marks,
        duplicates: duplicates,
        adjBlacks: adjBlacks,
        disconnected: disconnected,
        whiteConnected: whiteConnected,
        cleanLines: cleanLines,
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
    final cleanLines = aInt(p['cleanLines'], 0);
    final totalLines = math.max(1, aInt(p['totalLines'], 10));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$cleanLines/$totalLines行', null),
    };
    return A9ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (cleanLines / totalLines),
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
    required List<int> grid,
    required List<int> marks,
    required Set<int> duplicates,
    required Set<int> adjBlacks,
    required Set<int> disconnected,
    required bool whiteConnected,
    required int cleanLines,
    required int totalLines,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 52.0 : 45.0;

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141B24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.primary.withValues(alpha: 0.45), width: 1.8),
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
                    grid: grid,
                    marks: marks,
                    duplicates: duplicates,
                    adjBlacks: adjBlacks,
                    disconnected: disconnected,
                  ),
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
              A9Chip('消重行列 $cleanLines/$totalLines', cs.primary, size: 11),
              A9Chip(
                adjBlacks.isEmpty ? '✓ 黑格不邻' : '⚠ 黑格相邻',
                adjBlacks.isEmpty ? Colors.teal : Colors.redAccent,
                size: 11,
              ),
              A9Chip(
                whiteConnected ? '✓ 白格连通' : '⚠ 白格割断',
                whiteConnected ? Colors.green : Colors.deepOrange,
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
                label: const Text('涂黑 ■', style: TextStyle(fontSize: 11)),
                selected: _toolMode == 1,
                onSelected: (_) => setState(() => _toolMode = 1),
                visualDensity: VisualDensity.compact,
              ),
              ChoiceChip(
                label: const Text('画圈 ◯', style: TextStyle(fontSize: 11)),
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

  Widget _buildCell({
    required int r,
    required int c,
    required int size,
    required double cellPx,
    required List<int> grid,
    required List<int> marks,
    required Set<int> duplicates,
    required Set<int> adjBlacks,
    required Set<int> disconnected,
  }) {
    final idx = r * size + c;
    final numVal = idx < grid.length ? grid[idx] : 1;
    final mark = idx < marks.length ? marks[idx] : 0;
    final isDup = duplicates.contains(idx);
    final isAdjBlack = adjBlacks.contains(idx);
    final isDisc = disconnected.contains(idx);

    Color bgColor;
    Color borderColor;
    Color textColor;
    double borderWidth = 1.2;

    if (mark == 1) {
      // Shaded black
      bgColor = isAdjBlack ? const Color(0xFF4A121B) : const Color(0xFF1A222C);
      borderColor = isAdjBlack ? const Color(0xFFFF1744) : const Color(0xFF37474F);
      textColor = isAdjBlack ? const Color(0xFFFF8A80) : const Color(0xFF607D8B);
      if (isAdjBlack) borderWidth = 2.4;
    } else if (mark == 2) {
      // Circled safe
      bgColor = isDup ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9);
      borderColor = isDup
          ? const Color(0xFFD32F2F)
          : (isDisc ? const Color(0xFFFF8F00) : const Color(0xFF2E7D32));
      textColor = isDup ? const Color(0xFFC62828) : const Color(0xFF1B5E20);
      borderWidth = isDup || isDisc ? 2.2 : 1.6;
    } else {
      // Unshaded default
      bgColor = isDup ? const Color(0xFFFFF0F0) : const Color(0xFFFAFAFA);
      borderColor = isDup
          ? const Color(0xFFE53935)
          : (isDisc ? const Color(0xFFFF8F00) : const Color(0xFFB0BEC5));
      textColor = isDup ? const Color(0xFFC62828) : const Color(0xFF1E293B);
      if (isDup || isDisc) borderWidth = 2.0;
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, mark),
      onSecondaryTap: () => _onCellSecondaryTap(r, c, mark),
      child: Container(
        width: cellPx,
        height: cellPx,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        alignment: Alignment.center,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (mark == 2)
              Container(
                width: cellPx * 0.76,
                height: cellPx * 0.76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDup ? const Color(0xFFD32F2F) : const Color(0xFF2E7D32),
                    width: 2.2,
                  ),
                ),
              ),
            Text(
              '$numVal',
              style: TextStyle(
                fontSize: cellPx * 0.46,
                fontWeight: FontWeight.w900,
                color: textColor,
                decoration: mark == 1 ? TextDecoration.lineThrough : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
