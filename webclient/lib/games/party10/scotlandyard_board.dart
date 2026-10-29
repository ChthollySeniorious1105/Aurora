import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ScotlandYardBoard extends StatefulWidget {
  final GameContext g;
  const ScotlandYardBoard(this.g, {super.key});

  @override
  State<ScotlandYardBoard> createState() => _ScotlandYardBoardState();
}

class _ScotlandYardBoardState extends State<ScotlandYardBoard> {
  String? _selectedTicket;

  static const Map<String, Color> _ticketColors = {
    'taxi': Color(0xFFF59E0B),
    'bus': Color(0xFF10B981),
    'metro': Color(0xFFEF4444),
    'black': Color(0xFF1F2937),
    'double': Color(0xFF8B5CF6),
  };

  static const Map<String, String> _ticketLabels = {
    'taxi': '出租车',
    'bus': '巴士',
    'metro': '地铁',
    'black': '黑票',
    'double': '双倍×2',
  };

  static const List<Color> _seatColors = [
    Color(0xFFDC2626), // Mister X
    Color(0xFF2563EB), // Det 1
    Color(0xFF059669), // Det 2
    Color(0xFFD97706), // Det 3
    Color(0xFF7C3AED), // Det 4
    Color(0xFFDB2777), // Det 5
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 16;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final winner = v['winner'] as String?;
    final winReason = v['winReason'] as String? ?? '';
    final lastKnownPos = (v['lastKnownPos'] as num?)?.toInt();
    final lastKnownRound = (v['lastKnownRound'] as num?)?.toInt();
    final isReveal = v['isReveal'] == true;
    final canUseDouble = v['canUseDouble'] == true;
    final doubleMovesLeft = (v['doubleMovesLeft'] as num?)?.toInt() ?? 0;

    final rawPositions = (v['positions'] as List?) ?? const [];
    final positions = [
      for (final p in rawPositions) (p as num?)?.toInt(),
    ];
    final rawTickets = (v['tickets'] as List?) ?? const [];
    final tickets = [
      for (final t in rawTickets)
        (t as Map?)?.map((k, val) => MapEntry('$k', (val as num).toInt())) ??
            <String, int>{},
    ];
    final travelLog = [
      for (final e in (v['travelLog'] as List?) ?? const [])
        (e as Map).cast<String, dynamic>(),
    ];
    final legalMoves = [
      for (final m in (v['legalMoves'] as List?) ?? const [])
        (m as Map).cast<String, dynamic>(),
    ];
    final stations = [
      for (final s in (v['stations'] as List?) ?? const [])
        (s as Map).cast<String, dynamic>(),
    ];

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final filteredMoves = _selectedTicket == null
        ? legalMoves
        : legalMoves.where((m) => m['ticket'] == _selectedTicket).toList();
    final activeMoves = filteredMoves.isNotEmpty ? filteredMoves : legalMoves;

    final statusText = over
        ? (winner == 'misterX' ? 'X先生 逃脱获胜！' : '苏格兰场刑警 抓捕获胜！')
        : '第 $round/$maxRounds 轮${isReveal ? "【现身轮】" : ""} · 轮到 ${turn == 0 ? "X先生(${g.name(0)})" : "刑警 ${g.name(turn)}"}${doubleMovesLeft > 0 ? " (双倍移动剩余 $doubleMovesLeft 步)" : ""}';

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: status + travel log
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    if (lastKnownPos != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          '上次现身: 第$lastKnownRound轮 @$lastKnownPos号站',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                _buildPlayersStrip(
                    cs, g, turn, positions, tickets, compact: compact),
                const SizedBox(height: 4),
                _buildTravelLogBar(cs, travelLog, maxRounds, compact: compact),
                const SizedBox(height: 4),
                // Main London Map area
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: cs.outline.withValues(alpha: 0.4), width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: LayoutBuilder(builder: (context, mapBox) {
                        return Stack(
                          children: [
                            CustomPaint(
                              size: Size(mapBox.maxWidth, mapBox.maxHeight),
                              painter: _LondonMapPainter(
                                stations: stations,
                                positions: positions,
                                lastKnownPos: lastKnownPos,
                                legalTargets: {
                                  for (final m in activeMoves) m['to'] as int,
                                },
                              ),
                            ),
                            for (final st in stations)
                              _buildStationNode(
                                context,
                                st,
                                mapBox.maxWidth,
                                mapBox.maxHeight,
                                positions: positions,
                                lastKnownPos: lastKnownPos,
                                isMyTurn: isMyTurn,
                                movesToHere: [
                                  for (final m in activeMoves)
                                    if (m['to'] == st['id']) m,
                                ],
                                compact: compact,
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
                if (isMyTurn) ...[
                  const SizedBox(height: 4),
                  _buildActionBar(
                    cs,
                    g,
                    stations: stations,
                    legalMoves: legalMoves,
                    activeMoves: activeMoves,
                    canUseDouble: canUseDouble,
                    compact: compact,
                  ),
                ],
              ],
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  winner == 'misterX' ? 'X先生 逃脱成功！' : '苏格兰场刑警 缉拿成功！',
                  child: Text(
                    winReason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildPlayersStrip(
    ColorScheme cs,
    GameContext g,
    int turn,
    List<int?> positions,
    List<Map<String, int>> tickets, {
    required bool compact,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var s = 0; s < g.players; s++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s == turn
                      ? _seatColors[s % _seatColors.length]
                          .withValues(alpha: 0.28)
                      : cs.surface.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _seatColors[s % _seatColors.length],
                    width: s == turn ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _seatColors[s % _seatColors.length],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        s == 0 ? 'X先生' : '刑警$s',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${g.name(s)} ${positions.length > s && positions[s] != null ? "@${positions[s]}号" : "@隐匿"}',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (tickets.length > s)
                      Text(
                        s == 0
                            ? '出${tickets[s]['taxi'] ?? 0} 巴${tickets[s]['bus'] ?? 0} 铁${tickets[s]['metro'] ?? 0} 黑${tickets[s]['black'] ?? 0} 双${tickets[s]['double'] ?? 0}'
                            : '出${tickets[s]['taxi'] ?? 0} 巴${tickets[s]['bus'] ?? 0} 铁${tickets[s]['metro'] ?? 0}',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurface.withValues(alpha: 0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTravelLogBar(
    ColorScheme cs,
    List<Map<String, dynamic>> travelLog,
    int maxRounds, {
    required bool compact,
  }) {
    final revealSet = {3, 8, 13, 18, maxRounds};
    return SizedBox(
      height: compact ? 24 : 28,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: max(maxRounds, travelLog.length),
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (context, idx) {
          final entry = idx < travelLog.length ? travelLog[idx] : null;
          final r = entry != null ? (entry['round'] as num).toInt() : idx + 1;
          final isRev = revealSet.contains(r);
          final tk = entry?['ticket'] as String?;
          final st = entry?['station'];
          final bg = tk != null
              ? (_ticketColors[tk] ?? Colors.blueGrey)
              : cs.surface.withValues(alpha: 0.45);
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isRev ? Colors.amberAccent : Colors.white24,
                width: isRev ? 1.6 : 0.8,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              entry != null
                  ? '#${idx + 1} ${_ticketLabels[tk] ?? tk}${st != null ? "($st)" : ""}'
                  : 'R$r${isRev ? "★" : ""}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: tk != null ? Colors.white : cs.onSurface,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStationNode(
    BuildContext context,
    Map<String, dynamic> st,
    double width,
    double height, {
    required List<int?> positions,
    required int? lastKnownPos,
    required bool isMyTurn,
    required List<Map<String, dynamic>> movesToHere,
    required bool compact,
  }) {
    final id = (st['id'] as num).toInt();
    final name = st['name'] as String? ?? '$id';
    final x = (st['x'] as num).toDouble();
    final y = (st['y'] as num).toDouble();

    final px = (x * (width - 44)) + 22;
    final py = (y * (height - 36)) + 18;

    final occupants = <int>[];
    for (var s = 0; s < positions.length; s++) {
      if (positions[s] == id) occupants.add(s);
    }
    final canMoveHere = isMyTurn && movesToHere.isNotEmpty;
    final isLastKnown = lastKnownPos == id && !occupants.contains(0);

    final nodeSize = compact ? 22.0 : 28.0;

    return Positioned(
      left: px - nodeSize / 2,
      top: py - nodeSize / 2,
      child: GestureDetector(
        onTap: canMoveHere
            ? () {
                final m = movesToHere.first;
                widget.g.act({
                  'type': 'move',
                  'to': id,
                  'ticket': m['ticket'],
                });
              }
            : null,
        child: Tooltip(
          message: '$id号 · $name',
          child: Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: occupants.isNotEmpty
                  ? _seatColors[occupants.first % _seatColors.length]
                  : (canMoveHere
                      ? Colors.amberAccent
                      : (isLastKnown
                          ? Colors.red.withValues(alpha: 0.45)
                          : const Color(0xFF1E293B))),
              border: Border.all(
                color: canMoveHere
                    ? Colors.white
                    : (occupants.isNotEmpty
                        ? Colors.white
                        : Colors.blueGrey.shade300),
                width: canMoveHere || occupants.isNotEmpty ? 2.2 : 1.2,
              ),
              boxShadow: canMoveHere
                  ? const [BoxShadow(color: Colors.amber, blurRadius: 6)]
                  : null,
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Text(
                  occupants.contains(0)
                      ? 'X:$id'
                      : (occupants.isNotEmpty ? 'D${occupants.first}:$id' : '$id'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: canMoveHere && occupants.isEmpty
                        ? Colors.black
                        : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionBar(
    ColorScheme cs,
    GameContext g, {
    required List<Map<String, dynamic>> stations,
    required List<Map<String, dynamic>> legalMoves,
    required List<Map<String, dynamic>> activeMoves,
    required bool canUseDouble,
    required bool compact,
  }) {
    final stationNames = {
      for (final s in stations) (s['id'] as num).toInt(): s['name'] as String,
    };
    final availableTickets = {
      for (final m in legalMoves) m['ticket'] as String,
    }.toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (canUseDouble)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => g.act({'type': 'double'}),
                  icon: const Icon(Icons.fast_forward, size: 14),
                  label: const Text('使用双倍票', style: TextStyle(fontSize: 11)),
                ),
              ),
            for (final tk in availableTickets)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    _ticketLabels[tk] ?? tk,
                    style: const TextStyle(fontSize: 11),
                  ),
                  selected: _selectedTicket == tk,
                  onSelected: (sel) =>
                      setState(() => _selectedTicket = sel ? tk : null),
                ),
              ),
            const SizedBox(width: 4),
            for (final m in activeMoves)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ActionChip(
                  visualDensity: VisualDensity.compact,
                  backgroundColor:
                      (_ticketColors[m['ticket']] ?? cs.primaryContainer)
                          .withValues(alpha: 0.85),
                  label: Text(
                    '→${m['to']}号(${stationNames[m['to']] ?? ""}) [${_ticketLabels[m['ticket']] ?? m['ticket']}]',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => g.act({
                    'type': 'move',
                    'to': m['to'],
                    'ticket': m['ticket'],
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

int max(int a, int b) => a > b ? a : b;

class _LondonMapPainter extends CustomPainter {
  final List<Map<String, dynamic>> stations;
  final List<int?> positions;
  final int? lastKnownPos;
  final Set<int> legalTargets;

  _LondonMapPainter({
    required this.stations,
    required this.positions,
    required this.lastKnownPos,
    required this.legalTargets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final posMap = <int, Offset>{};
    for (final s in stations) {
      final id = (s['id'] as num).toInt();
      final x = (s['x'] as num).toDouble();
      final y = (s['y'] as num).toDouble();
      posMap[id] = Offset(
        (x * (size.width - 44)) + 22,
        (y * (size.height - 36)) + 18,
      );
    }

    // Draw Thames river band across central/south London
    final riverPaint = Paint()
      ..color = const Color(0xFF0284C7).withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final riverPath = Path()
      ..moveTo(0, size.height * 0.82)
      ..quadraticBezierTo(
        size.width * 0.32,
        size.height * 0.60,
        size.width * 0.55,
        size.height * 0.58,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.52,
        size.width,
        size.height * 0.62,
      );
    canvas.drawPath(riverPath, riverPaint);

    // Draw transport edges
    final drawn = <String>{};
    for (final s in stations) {
      final id = (s['id'] as num).toInt();
      final p1 = posMap[id];
      if (p1 == null) continue;
      final edges = (s['edges'] as Map?) ?? const {};
      for (final entry in edges.entries) {
        final mode = '${entry.key}';
        final list = (entry.value as List?) ?? const [];
        for (final rawTo in list) {
          final to = (rawTo as num).toInt();
          final a = id < to ? id : to;
          final b = id < to ? to : id;
          final key = '$mode:$a-$b';
          if (!drawn.add(key)) continue;
          final p2 = posMap[to];
          if (p2 == null) continue;

          var offset = Offset.zero;
          Color color;
          var width = 1.8;
          switch (mode) {
            case 'taxi':
              color = const Color(0xFFFBBF24).withValues(alpha: 0.55);
              width = 1.6;
              break;
            case 'bus':
              color = const Color(0xFF34D399).withValues(alpha: 0.75);
              offset = const Offset(2.0, -2.0);
              width = 2.2;
              break;
            case 'metro':
              color = const Color(0xFFF87171).withValues(alpha: 0.85);
              offset = const Offset(-2.5, 2.5);
              width = 2.6;
              break;
            case 'ferry':
              color = const Color(0xFF38BDF8);
              offset = const Offset(0, 3.0);
              width = 2.4;
              break;
            default:
              color = Colors.white38;
          }

          final paint = Paint()
            ..color = color
            ..strokeWidth = width
            ..style = PaintingStyle.stroke;
          canvas.drawLine(p1 + offset, p2 + offset, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LondonMapPainter oldDelegate) => true;
}
