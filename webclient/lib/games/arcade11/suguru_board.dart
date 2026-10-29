import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a11_common.dart';

class SuguruBoard extends StatefulWidget {
  final GameContext g;
  const SuguruBoard(this.g, {super.key});
  @override
  State<SuguruBoard> createState() => _SuguruBoardState();
}

class _SuguruBoardState extends State<SuguruBoard> {
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

  void _onCellTap(int r, int c, int size, bool isClue) {
    final idx = r * size + c;
    setState(() => _selectedIdx = idx);
    if (!_canPlay || isClue) return;
    g.act({'type': 'toggle', 'r': r, 'c': c});
  }

  void _onSetDigit(int val, int size, List<int> cluesFlat) {
    if (!_canPlay) return;
    final idx = _selectedIdx.clamp(0, size * size - 1);
    if (idx < cluesFlat.length && cluesFlat[idx] > 0) return;
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
    final regionMap = aInts(v['regionMap']);
    final regionList = aMaps(v['regionList']);
    final cluesFlat = aInts(v['cluesFlat']);
    final board = aInts(v['board']);
    final regionDuplicates = aInts(v['regionDuplicates']).toSet();
    final adjacentTouches = aInts(v['adjacentTouches']).toSet();
    final satisfiedRegions = aInts(v['satisfiedRegions']).toSet();
    final violatedRegions = aInts(v['violatedRegions']).toSet();
    final satisfiedRegionCount = aInt(v['satisfiedRegionCount'], 0);
    final totalRegions = math.max(1, aInt(v['totalRegions'], regionList.length));
    final filledCount = aInt(v['filledCount'], 0);
    final totalCells = math.max(1, aInt(v['totalCells'], size * size));
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '数块邻格互斥竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出数块谜题（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (regionDuplicates.isNotEmpty) '数块内重复/超界',
        if (adjacentTouches.isNotEmpty) '八方向邻格同数',
      ];
      final warnStr = warnings.isEmpty ? '无冲突' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 数块 $satisfiedRegionCount/$totalRegions · 已填 $filledCount/$totalCells · $warnStr · ${left}s';
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
        regionMap: regionMap,
        regionList: regionList,
        cluesFlat: cluesFlat,
        board: board,
        regionDuplicates: regionDuplicates,
        adjacentTouches: adjacentTouches,
        satisfiedRegions: satisfiedRegions,
        violatedRegions: violatedRegions,
        satisfiedRegionCount: satisfiedRegionCount,
        totalRegions: totalRegions,
        filledCount: filledCount,
        totalCells: totalCells,
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
    final tot = math.max(1, aInt(p['totalRegions'], 5));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot块', null),
    };
    return A11ProgressTile(
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
    required List<int> regionMap,
    required List<Map<String, dynamic>> regionList,
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> regionDuplicates,
    required Set<int> adjacentTouches,
    required Set<int> satisfiedRegions,
    required Set<int> violatedRegions,
    required int satisfiedRegionCount,
    required int totalRegions,
    required int filledCount,
    required int totalCells,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final anchorLabels = <int, String>{};
    for (final reg in regionList) {
      final regSize = aInt(reg['size'], 1);
      anchorLabels[aInt(reg['anchor'])] = '1..$regSize';
    }

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
                    anchorLabels: anchorLabels,
                    cluesFlat: cluesFlat,
                    board: board,
                    regionDuplicates: regionDuplicates,
                    adjacentTouches: adjacentTouches,
                    satisfiedRegions: satisfiedRegions,
                    violatedRegions: violatedRegions,
                  ),
              ],
            ),
        ],
      ),
    );

    final toolbar = Container(
      constraints: BoxConstraints(maxWidth: wide ? 230 : 340),
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
              A11Chip('数块 $satisfiedRegionCount/$totalRegions', const Color(0xFF00897B), size: 11),
              A11Chip('已填 $filledCount/$totalCells', cs.primary, size: 11),
              A11Chip(
                regionDuplicates.isEmpty && adjacentTouches.isEmpty ? '✓ 邻格无同数' : '⚠ 存在冲突',
                regionDuplicates.isEmpty && adjacentTouches.isEmpty ? Colors.green : Colors.redAccent,
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
              for (var d = 1; d <= 5; d++)
                SizedBox(
                  width: 38,
                  height: 34,
                  child: FilledButton.tonal(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                    onPressed: _canPlay ? () => _onSetDigit(d, size, cluesFlat) : null,
                    child: Text('$d', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              SizedBox(
                width: 44,
                height: 34,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: _canPlay ? () => _onSetDigit(0, size, cluesFlat) : null,
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
    required Map<int, String> anchorLabels,
    required List<int> cluesFlat,
    required List<int> board,
    required Set<int> regionDuplicates,
    required Set<int> adjacentTouches,
    required Set<int> satisfiedRegions,
    required Set<int> violatedRegions,
  }) {
    final idx = r * size + c;
    final regId = idx < regionMap.length ? regionMap[idx].clamp(0, 99) : 0;
    final isClue = idx < cluesFlat.length && cluesFlat[idx] > 0;
    final val = idx < board.length ? board[idx] : 0;
    final label = anchorLabels[idx];
    final isConflict = regionDuplicates.contains(idx) || adjacentTouches.contains(idx);
    final isRegSat = satisfiedRegions.contains(regId);
    final isRegViol = violatedRegions.contains(regId);
    final isSelected = _selectedIdx == idx;

    int regAt(int rr, int cc) {
      if (rr < 0 || rr >= size || cc < 0 || cc >= size) return -1;
      final i = rr * size + cc;
      return i < regionMap.length ? regionMap[i] : -1;
    }

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.8);
    const innerBorder = BorderSide(color: Color(0x55475569), width: 0.7);

    final baseBg = _regionColors[regId % _regionColors.length];
    final bgColor = isConflict
        ? const Color(0xFFFFCDD2)
        : (isSelected
            ? Color.alphaBlend(const Color(0x4400ACC1), baseBg)
            : (isRegSat
                ? Color.alphaBlend(const Color(0x222E7D32), baseBg)
                : baseBg));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onCellTap(r, c, size, isClue),
      onSecondaryTap: () {
        setState(() => _selectedIdx = idx);
        if (_canPlay && !isClue) {
          g.act({'type': 'set', 'r': r, 'c': c, 'val': 0});
        }
      },
      child: Container(
        width: cellPx,
        height: cellPx,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border(
            top: regAt(r - 1, c) != regId ? wallBorder : innerBorder,
            bottom: regAt(r + 1, c) != regId ? wallBorder : innerBorder,
            left: regAt(r, c - 1) != regId ? wallBorder : innerBorder,
            right: regAt(r, c + 1) != regId ? wallBorder : innerBorder,
          ),
        ),
        child: Stack(
          children: [
            if (label != null && label.isNotEmpty)
              Positioned(
                left: 3,
                top: 2,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: cellPx * 0.19,
                    fontWeight: FontWeight.w800,
                    color: isRegViol
                        ? const Color(0xFFC62828)
                        : (isRegSat ? const Color(0xFF1B5E20) : const Color(0xFF475569)),
                  ),
                ),
              ),
            if (isClue)
              Positioned(
                right: 3,
                top: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF334155),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (val > 0)
              Align(
                alignment: const Alignment(0, 0.25),
                child: Text(
                  '$val',
                  style: TextStyle(
                    fontSize: cellPx * 0.44,
                    fontWeight: FontWeight.w900,
                    color: isConflict
                        ? const Color(0xFFB71C1C)
                        : (isClue ? const Color(0xFF0F172A) : const Color(0xFF0277BD)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
