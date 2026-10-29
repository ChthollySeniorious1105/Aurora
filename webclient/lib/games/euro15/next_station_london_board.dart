import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_shared/games/euro15/next_station_london.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class NextStationLondonBoard extends StatefulWidget {
  final GameContext g;
  const NextStationLondonBoard(this.g, {super.key});

  @override
  State<NextStationLondonBoard> createState() => _NextStationLondonBoardState();
}

class _NextStationLondonBoardState extends State<NextStationLondonBoard> {
  int? _selectedFrom;
  int? _inspectSeat;

  static const List<Color> _lineColors = [
    Color(0xFF8E24AA), // 0: Purple
    Color(0xFF1E88E5), // 1: Blue
    Color(0xFFD81B60), // 2: Pink
    Color(0xFF43A047), // 3: Green
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final rows = asInt(v['rows'], 7);
    final cols = asInt(v['cols'], 7);
    final round = asInt(v['round'], 1);
    final activeLine = asInt(v['activeLine'], 0);
    final cardStep = asInt(v['cardStep'], 1);
    final cardsPerRound = asInt(v['cardsPerRound'], 5);
    final turn = asInt(v['turn'], 0);
    final over = asBool(v['over']);
    final lastAction = asStr(v['lastAction']);
    final currentCard =
        (v['currentCard'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stations = (v['stations'] as List?) ?? const [];
    final legalConnections = (v['legalConnections'] as List?) ?? const [];
    final pList = (v['players'] as List?) ?? const [];

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
                                    ? '轮到你！延伸${londonLineEmojis[activeLine]}${londonLineNames[activeLine]}连往 ${currentCard['label'] ?? ''} · $lastAction'
                                    : '等待 ${g.name(turn)} 规划地铁 · $lastAction'),
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
                          '${londonLineEmojis[activeLine.clamp(0, 3)]}第$round/4线 · 卡$cardStep/$cardsPerRound',
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
                        final tvp = asInt(pd['touristVp'], 0);
                        final ivp = asInt(pd['interchangeVp'], 0);
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
                              sub: '⭐$sc分 · 景点$tvp · 换乘$ivp',
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
                                flex: 4,
                                child: _buildControlPanel(
                                  activeLine,
                                  currentCard,
                                  stations,
                                  legalConnections,
                                  viewData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  activeLine,
                                  stations,
                                  legalConnections,
                                  isMyTurn && viewSeat == g.seat,
                                  cs,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildControlPanel(
                                  activeLine,
                                  currentCard,
                                  stations,
                                  legalConnections,
                                  viewData,
                                  isMyTurn,
                                  cs,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Expanded(
                                flex: 6,
                                child: _buildMapPanel(
                                  viewSeat,
                                  viewData,
                                  rows,
                                  cols,
                                  activeLine,
                                  stations,
                                  legalConnections,
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
                '下一站：伦敦终局 · ${[
                  for (var s = 0; s < pList.length; s++)
                    '${g.name(s)}: ${(pList[s] as Map)['score']}分'
                ].join('  ')}',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlPanel(
    int activeLine,
    Map<String, dynamic> currentCard,
    List<dynamic> stations,
    List<dynamic> legalConnections,
    Map<String, dynamic> viewData,
    bool isMyTurn,
    ColorScheme cs,
  ) {
    final lineScores = (viewData['lineScores'] as List?) ?? const [0, 0, 0, 0];
    final sw = asBool(currentCard['switchTrack']);

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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _lineColors[activeLine.clamp(0, 3)],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '当前牌: ${currentCard['label'] ?? ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sw ? '🔀 可从本线任意车站分叉' : '仅可从本线两端终点延伸',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: cs.onSurface.withValues(alpha: 0.75),
                  ),
                ),
              ),
              if (isMyTurn)
                InkWell(
                  onTap: () {
                    widget.g.act({'type': 'pass'});
                    setState(() => _selectedFrom = null);
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '跳过本张',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.onSecondaryContainer,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                for (var l = 0; l < 4; l++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${londonLineEmojis[l]}${londonLineNames[l]}:${l < lineScores.length ? lineScores[l] : 0}分',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            l == activeLine ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                Text(
                  '⭐景点:${viewData['touristVp'] ?? 0}  🔄换乘:${viewData['interchangeVp'] ?? 0}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: legalConnections.isEmpty
                ? Center(
                    child: Text(
                      isMyTurn ? '当前无可连接路线，请点击“跳过本张”' : '点击右侧伦敦地铁图查看网络布局',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: legalConnections.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 6),
                    itemBuilder: (context, idx) {
                      final pair = legalConnections[idx] as List;
                      final u = asInt(pair[0], 0);
                      final v = asInt(pair[1], 0);
                      final stU = (u < stations.length)
                          ? (stations[u] as Map).cast<String, dynamic>()
                          : const <String, dynamic>{};
                      final stV = (v < stations.length)
                          ? (stations[v] as Map).cast<String, dynamic>()
                          : const <String, dynamic>{};
                      return InkWell(
                        onTap: !isMyTurn
                            ? null
                            : () {
                                widget.g.act({
                                  'type': 'connect',
                                  'from': u,
                                  'to': v,
                                });
                                setState(() => _selectedFrom = null);
                              },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: _lineColors[activeLine.clamp(0, 3)]),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '🚇 ${stU['name']} → ${stV['name']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: cs.onPrimaryContainer,
                                  ),
                                ),
                                Text(
                                  '${londonSymbolEmojis[asInt(stV['symbol'], 0).clamp(0, 4)]} 区#${stV['district']}${asBool(stV['isTourist']) ? ' ⭐景点' : ''}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: cs.onPrimaryContainer
                                        .withValues(alpha: 0.8),
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
        ],
      ),
    );
  }

  Widget _buildMapPanel(
    int viewSeat,
    Map<String, dynamic> viewData,
    int rows,
    int cols,
    int activeLine,
    List<dynamic> stations,
    List<dynamic> legalConnections,
    bool canInteract,
    ColorScheme cs,
  ) {
    final lineSegments = (viewData['lineSegments'] as List?) ?? const [];

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
                  '🗺️ ${widget.g.name(viewSeat)} 的伦敦地下铁网络（蓝色水道为泰晤士河🌊）',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              if (_selectedFrom != null)
                InkWell(
                  onTap: () => setState(() => _selectedFrom = null),
                  child: const Text(
                    '取消选站',
                    style: TextStyle(fontSize: 10, color: Colors.redAccent),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth;
                    final h = box.maxHeight;
                    final cellW = w / cols;
                    final cellH = h / rows;

                    return Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _LondonMapPainter(
                              rows: rows,
                              cols: cols,
                              stations: stations,
                              lineSegments: lineSegments,
                              lineColors: _lineColors,
                            ),
                          ),
                        ),
                        for (final rawSt in stations)
                          Builder(
                            builder: (context) {
                              final st =
                                  (rawSt as Map).cast<String, dynamic>();
                              final id = asInt(st['id'], 0);
                              final r = asInt(st['r'], 0);
                              final c = asInt(st['c'], 0);
                              final sym = asInt(st['symbol'], 0);
                              final isTourist = asBool(st['isTourist']);
                              final startLine = asInt(st['startLine'], -1);

                              final isSelectedFrom = _selectedFrom == id;
                              final isLegalDest = canInteract &&
                                  legalConnections.any((pair) {
                                    final p = pair as List;
                                    final pu = asInt(p[0], -1);
                                    final pv = asInt(p[1], -1);
                                    return pv == id &&
                                        (_selectedFrom == null ||
                                            _selectedFrom == pu);
                                  });

                              final nodeSize =
                                  (cellW < cellH ? cellW : cellH) * 0.76;

                              return Positioned(
                                left: (c + 0.5) * cellW - nodeSize / 2,
                                top: (r + 0.5) * cellH - nodeSize / 2,
                                width: nodeSize,
                                height: nodeSize,
                                child: GestureDetector(
                                  onTap: !canInteract
                                      ? null
                                      : () {
                                          // Check if tapping a valid destination directly
                                          for (final pair in legalConnections) {
                                            final p = pair as List;
                                            final pu = asInt(p[0], -1);
                                            final pv = asInt(p[1], -1);
                                            if (pv == id &&
                                                (_selectedFrom == null ||
                                                    _selectedFrom == pu)) {
                                              widget.g.act({
                                                'type': 'connect',
                                                'from': pu,
                                                'to': pv,
                                              });
                                              setState(
                                                  () => _selectedFrom = null);
                                              return;
                                            }
                                          }
                                          setState(() => _selectedFrom = id);
                                        },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: startLine >= 0
                                          ? _lineColors[
                                              startLine.clamp(0, 3)]
                                          : cs.surface,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelectedFrom
                                            ? Colors.amberAccent
                                            : (isLegalDest
                                                ? Colors.greenAccent
                                                : (isTourist
                                                    ? Colors.orangeAccent
                                                    : cs.onSurface)),
                                        width: (isSelectedFrom || isLegalDest)
                                            ? 2.6
                                            : 1.5,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                            blurRadius: 3,
                                            color: Colors.black26),
                                      ],
                                    ),
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding: const EdgeInsets.all(2),
                                        child: Text(
                                          '${londonSymbolEmojis[sym.clamp(0, 3)]}${isTourist ? '⭐' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: startLine >= 0
                                                ? Colors.white
                                                : cs.onSurface,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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

class _LondonMapPainter extends CustomPainter {
  final int rows;
  final int cols;
  final List<dynamic> stations;
  final List<dynamic> lineSegments;
  final List<Color> lineColors;

  _LondonMapPainter({
    required this.rows,
    required this.cols,
    required this.stations,
    required this.lineSegments,
    required this.lineColors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    // Subtle grid lines
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.22)
      ..strokeWidth = 1;
    for (var r = 0; r <= rows; r++) {
      canvas.drawLine(
          Offset(0, r * cellH), Offset(size.width, r * cellH), gridPaint);
    }
    for (var c = 0; c <= cols; c++) {
      canvas.drawLine(
          Offset(c * cellW, 0), Offset(c * cellW, size.height), gridPaint);
    }

    // Thames River across row 3.5 (between r=3 and r=4)
    final riverY = 4.0 * cellH;
    final riverPaint = Paint()
      ..color = const Color(0xFF29B6F6).withValues(alpha: 0.45)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final path = Path()
      ..moveTo(0, riverY - 3)
      ..quadraticBezierTo(
          size.width * 0.25, riverY + 5, size.width * 0.5, riverY)
      ..quadraticBezierTo(
          size.width * 0.75, riverY - 5, size.width, riverY + 3);
    canvas.drawPath(path, riverPaint);

    // Build station center lookup
    final centers = <int, Offset>{};
    for (final raw in stations) {
      final st = (raw as Map).cast<String, dynamic>();
      final id = asInt(st['id'], 0);
      final r = asInt(st['r'], 0);
      final c = asInt(st['c'], 0);
      centers[id] = Offset((c + 0.5) * cellW, (r + 0.5) * cellH);
    }

    // Draw each Metro Line's segments
    for (var l = 0; l < lineSegments.length && l < lineColors.length; l++) {
      final segs = lineSegments[l] as List;
      final paint = Paint()
        ..color = lineColors[l]
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round;
      for (final rawSeg in segs) {
        final pair = rawSeg as List;
        final u = asInt(pair[0], -1);
        final v = asInt(pair[1], -1);
        final p1 = centers[u];
        final p2 = centers[v];
        if (p1 != null && p2 != null) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LondonMapPainter oldDelegate) => true;
}
