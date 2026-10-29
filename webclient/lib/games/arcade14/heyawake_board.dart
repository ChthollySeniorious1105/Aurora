import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import 'a14_common.dart';

class HeyawakeBoard extends StatefulWidget {
  final GameContext g;
  const HeyawakeBoard(this.g, {super.key});
  @override
  State<HeyawakeBoard> createState() => _HeyawakeBoardState();
}

class _HeyawakeBoardState extends State<HeyawakeBoard> {
  GameContext get g => widget.g;
  int _selectedIdx = 0;

  static const List<Color> _roomColors = [
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
    final roomMap = aInts(v['roomMap']);
    final rooms = aMaps(v['rooms']);
    final board = aInts(v['board']);
    final roomBlackCounts = aInts(v['roomBlackCounts']);
    final satisfiedRooms = aInts(v['satisfiedRooms']).toSet();
    final violatedRooms = aInts(v['violatedRooms']).toSet();
    final adjacentBlackCells = aInts(v['adjacentBlackCells']).toSet();
    final spanViolationCells = aInts(v['spanViolationCells']).toSet();
    final isolatedWhiteCells = aInts(v['isolatedWhiteCells']).toSet();
    final whiteConnected = v['whiteConnected'] == true;
    final satisfiedRoomCount = aInt(v['satisfiedRoomCount'], 0);
    final totalRooms = math.max(1, aInt(v['totalRooms'], rooms.length));
    final blackCount = aInt(v['blackCount'], 0);
    final ps = aMaps(v['ps']);

    if (_selectedIdx >= size * size) {
      _selectedIdx = 0;
    }

    final me = g.seat >= 0 && g.seat < ps.length ? ps[g.seat] : null;
    final myStatus = me != null ? aStr(me['status']) : '';

    String status;
    if (phase == 'over') {
      status = '分室涂黑竞速 · 对局结束';
    } else if (me == null) {
      status = '第 $round/$totalRounds 题（$size×$size）· 观战中 · 剩余 ${left}s';
    } else if (myStatus == 'solved') {
      status = '第 $round/$totalRounds 题 · 已解出分室涂黑（+${me['pts']} 分）！等待其他玩家 · ${left}s';
    } else if (myStatus == 'pass') {
      status = '第 $round/$totalRounds 题 · 已放弃本题，等待其他玩家 · ${left}s';
    } else {
      final warnings = <String>[
        if (violatedRooms.isNotEmpty) '房间黑格超额',
        if (adjacentBlackCells.isNotEmpty) '黑格相邻冲突',
        if (spanViolationCells.isNotEmpty) '白格直线跨三室',
        if (!whiteConnected && blackCount > 0) '白格被隔断',
      ];
      final warnStr = warnings.isEmpty ? '规则状态良好' : warnings.join(' · ');
      status =
          '第 $round/$totalRounds 题（$size×$size）· 达标房间 $satisfiedRoomCount/$totalRooms · 黑格 $blackCount · $warnStr · ${left}s';
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
        roomMap: roomMap,
        rooms: rooms,
        board: board,
        roomBlackCounts: roomBlackCounts,
        satisfiedRooms: satisfiedRooms,
        violatedRooms: violatedRooms,
        adjacentBlackCells: adjacentBlackCells,
        spanViolationCells: spanViolationCells,
        isolatedWhiteCells: isolatedWhiteCells,
        whiteConnected: whiteConnected,
        satisfiedRoomCount: satisfiedRoomCount,
        totalRooms: totalRooms,
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
    final sat = aInt(p['satisfiedRooms'], 0);
    final tot = math.max(1, aInt(p['totalRooms'], 5));
    final pts = aInt(p['pts'], 0);
    final (badge, col) = switch (st) {
      'solved' => ('+$pts分', Colors.green),
      'pass' => ('放弃', Colors.orange),
      'resigned' => ('认输', Colors.redAccent),
      _ => ('$sat/$tot室', null),
    };
    return A14ProgressTile(
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
    required List<int> roomMap,
    required List<Map<String, dynamic>> rooms,
    required List<int> board,
    required List<int> roomBlackCounts,
    required Set<int> satisfiedRooms,
    required Set<int> violatedRooms,
    required Set<int> adjacentBlackCells,
    required Set<int> spanViolationCells,
    required Set<int> isolatedWhiteCells,
    required bool whiteConnected,
    required int satisfiedRoomCount,
    required int totalRooms,
    required int blackCount,
    required bool wide,
  }) {
    final cellPx = size <= 5 ? 50.0 : 44.0;
    final anchorRoom = <int, Map<String, dynamic>>{};
    for (final rm in rooms) {
      final r1 = aInt(rm['r1'], 0);
      final c1 = aInt(rm['c1'], 0);
      anchorRoom[r1 * size + c1] = rm;
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
                    roomMap: roomMap,
                    anchorRoom: anchorRoom,
                    board: board,
                    roomBlackCounts: roomBlackCounts,
                    satisfiedRooms: satisfiedRooms,
                    violatedRooms: violatedRooms,
                    adjacentBlackCells: adjacentBlackCells,
                    spanViolationCells: spanViolationCells,
                    isolatedWhiteCells: isolatedWhiteCells,
                  ),
              ],
            ),
        ],
      ),
    );

    final noRuleConflict = violatedRooms.isEmpty &&
        adjacentBlackCells.isEmpty &&
        spanViolationCells.isEmpty &&
        whiteConnected;

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
              A14Chip('房间 $satisfiedRoomCount/$totalRooms', const Color(0xFF00897B), size: 11),
              A14Chip('黑格 $blackCount', cs.primary, size: 11),
              A14Chip(
                noRuleConflict
                    ? '✓ 无跨三室/禁邻'
                    : (spanViolationCells.isNotEmpty ? '⚠ 白格跨三室' : '⚠ 禁邻或断连'),
                noRuleConflict ? Colors.green : Colors.redAccent,
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
                  child: const Text('■ 涂黑方格', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
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
    required List<int> roomMap,
    required Map<int, Map<String, dynamic>> anchorRoom,
    required List<int> board,
    required List<int> roomBlackCounts,
    required Set<int> satisfiedRooms,
    required Set<int> violatedRooms,
    required Set<int> adjacentBlackCells,
    required Set<int> spanViolationCells,
    required Set<int> isolatedWhiteCells,
  }) {
    final idx = r * size + c;
    final roomId = idx < roomMap.length ? roomMap[idx].clamp(0, 99) : 0;
    final val = idx < board.length ? board[idx] : 0;
    final headerRm = anchorRoom[idx];
    final roomCnt = roomId < roomBlackCounts.length ? roomBlackCounts[roomId] : 0;
    final clue = headerRm != null ? aInt(headerRm['clue'], -1) : -1;

    final isRoomSat = satisfiedRooms.contains(roomId);
    final isRoomViol = violatedRooms.contains(roomId);
    final isAdjBlack = adjacentBlackCells.contains(idx);
    final isSpanViol = spanViolationCells.contains(idx);
    final isIsoWhite = isolatedWhiteCells.contains(idx);
    final isSelected = _selectedIdx == idx;

    int roomAt(int rr, int cc) {
      if (rr < 0 || rr >= size || cc < 0 || cc >= size) return -1;
      final i = rr * size + cc;
      return i < roomMap.length ? roomMap[i] : -1;
    }

    const wallBorder = BorderSide(color: Color(0xFF0F172A), width: 2.8);
    const innerBorder = BorderSide(color: Color(0x55475569), width: 0.7);

    final baseBg = _roomColors[roomId % _roomColors.length];
    Color bgColor;
    if (val == 1) {
      bgColor = isAdjBlack ? const Color(0xFFB71C1C) : const Color(0xFF1E293B);
    } else if (isIsoWhite) {
      bgColor = Color.alphaBlend(const Color(0x55D32F2F), baseBg);
    } else if (isSpanViol) {
      bgColor = Color.alphaBlend(const Color(0x44FB8C00), baseBg);
    } else if (isSelected) {
      bgColor = Color.alphaBlend(const Color(0x4400ACC1), baseBg);
    } else if (isRoomSat) {
      bgColor = Color.alphaBlend(const Color(0x222E7D32), baseBg);
    } else if (isRoomViol) {
      bgColor = Color.alphaBlend(const Color(0x33D32F2F), baseBg);
    } else {
      bgColor = baseBg;
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
            top: roomAt(r - 1, c) != roomId ? wallBorder : innerBorder,
            bottom: roomAt(r + 1, c) != roomId ? wallBorder : innerBorder,
            left: roomAt(r, c - 1) != roomId ? wallBorder : innerBorder,
            right: roomAt(r, c + 1) != roomId ? wallBorder : innerBorder,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (headerRm != null && clue >= 0)
              Positioned(
                left: 3,
                top: 2,
                child: Text(
                  '$roomCnt/$clue■',
                  style: TextStyle(
                    fontSize: cellPx * 0.20,
                    fontWeight: FontWeight.w900,
                    color: val == 1
                        ? Colors.white70
                        : (isRoomViol
                            ? const Color(0xFFC62828)
                            : (isRoomSat ? const Color(0xFF1B5E20) : const Color(0xFF0F172A))),
                  ),
                ),
              ),
            if (val == 1)
              Icon(
                Icons.square_rounded,
                size: cellPx * 0.44,
                color: isAdjBlack ? const Color(0xFFFFCDD2) : const Color(0xFF64748B),
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
          ],
        ),
      ),
    );
  }
}
