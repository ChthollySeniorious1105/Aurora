import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a16_common.dart';

class LitsBoard extends StatefulWidget {
  final GameContext g;
  const LitsBoard(this.g, {super.key});
  @override
  State<LitsBoard> createState() => _LitsBoardState();
}

class _LitsBoardState extends State<LitsBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  static const List<Color> _regionColors = [
    Color(0xFFFFF8E1), // Soft Amber
    Color(0xFFE3F2FD), // Soft Blue
    Color(0xFFF3E5F5), // Soft Purple
    Color(0xFFE0F2F1), // Soft Teal
    Color(0xFFFFF3E0), // Soft Orange
    Color(0xFFFCE4EC), // Soft Pink
    Color(0xFFF1F8E9), // Soft Lime
    Color(0xFFE8EAF6), // Soft Indigo
  ];

  bool get _canPlay {
    final v = g.view;
    final phase = aStr(v['phase']);
    final ps = aMaps(v['ps']);
    if (g.over || phase != 'play' || g.seat < 0 || g.seat >= ps.length) return false;
    return aStr(ps[g.seat]['status']) == 'play';
  }

  int _regAt(List<int> regionMap, int size, int r, int c) {
    if (r < 0 || r >= size || c < 0 || c >= size) return -1;
    final idx = r * size + c;
    return idx < regionMap.length ? regionMap[idx] : -1;
  }

  void _onCellTap(int r, int c, int size) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay) return;
    g.act({'type': 'toggle', 'r': r, 'c': c});
  }

  void _onSetVal(int val, int size) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    g.act({'type': 'set', 'r': idx ~/ size, 'c': idx % size, 'val': val});
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
    final regionCount = math.max(1, aInt(v['regionCount'], 4));
    final regionMap = aInts(v['regionMap']);
    final regionAnchorCells = aInts(v['regionAnchorCells']);
    final board = aInts(v['board']);
    final regionBlackCounts = aInts(v['regionBlackCounts']);
    final regionShapes = aStrs(v['regionShapes']);
    final satisfiedRegions = aInts(v['satisfiedRegions']).toSet();
    final violatedRegions = aInts(v['violatedRegions']).toSet();
    final sameShapeConflictRegions = aInts(v['sameShapeConflictRegions']).toSet();
    final twoByTwoCells = aInts(v['twoByTwoCells']).toSet();
    final conflictCells = aInts(v['conflictCells']).toSet();
    final satisfiedRegionCount = aInt(v['satisfiedRegionCount'], 0);
    final blackComponentCount = aInt(v['blackComponentCount'], 0);
    final isAllBlackConnected = v['isAllBlackConnected'] == true;
    final blackCount = aInt(v['blackCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '四格骨牌竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出四格骨牌（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (twoByTwoCells.isNotEmpty) '禁 2×2 全黑冲突',
        if (sameShapeConflictRegions.isNotEmpty) '同形骨牌相邻冲突',
        if (violatedRegions.isNotEmpty && sameShapeConflictRegions.isEmpty) '区域骨牌形状或数量有误',
      ];
      final warnStr = warnings.isEmpty ? '点击方格涂黑组成 L/I/T/S 骨牌' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 骨牌 $satisfiedRegionCount/$regionCount · 黑格 $blackCount/${regionCount * 4} · $warnStr · ${left}s';
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
        regionCount: regionCount,
        regionMap: regionMap,
        regionAnchorCells: regionAnchorCells,
        board: board,
        regionBlackCounts: regionBlackCounts,
        regionShapes: regionShapes,
        satisfiedRegions: satisfiedRegions,
        violatedRegions: violatedRegions,
        sameShapeConflictRegions: sameShapeConflictRegions,
        twoByTwoCells: twoByTwoCells,
        conflictCells: conflictCells,
        satisfiedRegionCount: satisfiedRegionCount,
        blackComponentCount: blackComponentCount,
        isAllBlackConnected: isAllBlackConnected,
        blackCount: blackCount,
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
    final sat = aInt(p['satisfiedRegions'], 0);
    final tot = math.max(1, aInt(p['regionCount'], 4));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot宫', null),
    };
    return A16ProgressTile(
      g,
      s,
      width: width,
      pct: st == 'solved' ? 1.0 : (sat / tot),
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
    required int regionCount,
    required List<int> regionMap,
    required List<int> regionAnchorCells,
    required List<int> board,
    required List<int> regionBlackCounts,
    required List<String> regionShapes,
    required Set<int> satisfiedRegions,
    required Set<int> violatedRegions,
    required Set<int> sameShapeConflictRegions,
    required Set<int> twoByTwoCells,
    required Set<int> conflictCells,
    required int satisfiedRegionCount,
    required int blackComponentCount,
    required bool isAllBlackConnected,
    required int blackCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final anchorToReg = <int, int>{
      for (var reg = 0; reg < regionAnchorCells.length; reg++)
        if (regionAnchorCells[reg] >= 0) regionAnchorCells[reg]: reg,
    };

    final gridCard = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF141C26),
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
                    regionMap: regionMap,
                    anchorToReg: anchorToReg,
                    board: board,
                    regionBlackCounts: regionBlackCounts,
                    regionShapes: regionShapes,
                    satisfiedRegions: satisfiedRegions,
                    violatedRegions: violatedRegions,
                    conflictCells: conflictCells,
                  ),
              ],
            ),
        ],
      ),
    );

    final noConflict = twoByTwoCells.isEmpty && sameShapeConflictRegions.isEmpty && violatedRegions.isEmpty;

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 235 : 340),
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
              A16Chip('骨牌 $satisfiedRegionCount/$regionCount', const Color(0xFF00897B), size: 11),
              A16Chip(
                isAllBlackConnected
                    ? '✓ 全黑连通'
                    : (blackCount == 0 ? '黑格 0/${regionCount * 4}' : '连通群 $blackComponentCount'),
                isAllBlackConnected ? Colors.green : cs.primary,
                size: 11,
              ),
              A16Chip(
                noConflict
                    ? '✓ 无 2×2/同形冲突'
                    : (twoByTwoCells.isNotEmpty ? '⚠ 禁 2×2 冲突' : '⚠ 同形/形状冲突'),
                noConflict ? Colors.green : Colors.redAccent,
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
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF263238),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(1, size) : null,
                  child: const Text('■ 涂黑骨牌', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                height: 34,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE0F2F1),
                    foregroundColor: const Color(0xFF00695C),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: _canPlay ? () => _onSetVal(2, size) : null,
                  child: const Text('● 标记留白', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                ),
              ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetVal(0, size) : null,
                  child: const Icon(Icons.backspace_outlined, size: 16),
                ),
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
                label: const Text('重置', style: TextStyle(fontSize: 12)),
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
    required List<int> regionMap,
    required Map<int, int> anchorToReg,
    required List<int> board,
    required List<int> regionBlackCounts,
    required List<String> regionShapes,
    required Set<int> satisfiedRegions,
    required Set<int> violatedRegions,
    required Set<int> conflictCells,
  }) {
    final idx = r * size + c;
    final regId = _regAt(regionMap, size, r, c).clamp(0, 99);
    final val = idx < board.length ? board[idx] : 0;
    final isConflict = conflictCells.contains(idx);
    final isSelected = _selectedIdx == idx;
    final shape = regId < regionShapes.length ? regionShapes[regId] : '';
    final anchorReg = anchorToReg[idx];

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.8);
    const innerBorder = BorderSide(color: Color(0x55475569), width: 0.7);

    Color bgColor;
    if (val == 1) {
      bgColor = isConflict ? const Color(0xFFB71C1C) : const Color(0xFF1E293B);
    } else if (isSelected) {
      bgColor = const Color(0xFFB2EBF2);
    } else {
      bgColor = _regionColors[regId % _regionColors.length];
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 2});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: _regAt(regionMap, size, r - 1, c) != regId ? wallBorder : innerBorder,
            bottom: _regAt(regionMap, size, r + 1, c) != regId ? wallBorder : innerBorder,
            left: _regAt(regionMap, size, r, c - 1) != regId ? wallBorder : innerBorder,
            right: _regAt(regionMap, size, r, c + 1) != regId ? wallBorder : innerBorder,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (val == 1)
              Text(
                shape.isNotEmpty ? shape : '■',
                style: TextStyle(
                  fontSize: cellPx * 0.36,
                  fontWeight: FontWeight.w900,
                  color: isConflict
                      ? const Color(0xFFFFCDD2)
                      : (satisfiedRegions.contains(regId) ? const Color(0xFF80CBC4) : Colors.white),
                ),
              )
            else if (val == 2)
              Container(
                width: cellPx * 0.22,
                height: cellPx * 0.22,
                decoration: const BoxDecoration(
                  color: Color(0xFF00897B),
                  shape: BoxShape.circle,
                ),
              ),
            if (anchorReg != null)
              Positioned(
                left: 2,
                top: 1,
                child: () {
                  final cnt = anchorReg < regionBlackCounts.length ? regionBlackCounts[anchorReg] : 0;
                  final s = anchorReg < regionShapes.length ? regionShapes[anchorReg] : '';
                  final isSat = satisfiedRegions.contains(anchorReg);
                  final isViol = violatedRegions.contains(anchorReg);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                    decoration: BoxDecoration(
                      color: isViol
                          ? const Color(0xFFD32F2F)
                          : (isSat ? const Color(0xFF2E7D32) : const Color(0xAA0F172A)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.isNotEmpty ? '$s·$cnt/4' : '$cnt/4',
                      style: TextStyle(
                        fontSize: cellPx * 0.16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                  );
                }(),
              ),
          ],
        ),
      ),
    );
  }
}
