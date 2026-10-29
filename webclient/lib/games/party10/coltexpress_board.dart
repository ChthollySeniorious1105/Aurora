import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class ColtExpressBoard extends StatefulWidget {
  final GameContext g;
  const ColtExpressBoard(this.g, {super.key});

  @override
  State<ColtExpressBoard> createState() => _ColtExpressBoardState();
}

class _ColtExpressBoardState extends State<ColtExpressBoard> {
  static const Map<String, String> _cardLabels = {
    'move': '移动',
    'climb': '攀爬',
    'punch': '出拳',
    'shoot': '开枪',
    'rob': '抢劫',
    'marshal': '警长',
    'bullet': '中弹',
    'hidden': '暗置',
  };

  static const Map<String, IconData> _cardIcons = {
    'move': Icons.directions_run,
    'climb': Icons.stairs,
    'punch': Icons.sports_mma,
    'shoot': Icons.gps_fixed,
    'rob': Icons.savings,
    'marshal': Icons.local_police,
    'bullet': Icons.broken_image,
    'hidden': Icons.visibility_off,
  };

  static const List<Color> _banditColors = [
    Color(0xFFDC2626),
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 4;
    final phase = v['phase'] as String? ?? 'scheming';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final isTunnelTurn = v['isTunnelTurn'] == true;
    final schemeTurnIdx = (v['schemeTurnIndex'] as num?)?.toInt() ?? 0;
    final totalSchemeTurns = (v['totalSchemeTurns'] as num?)?.toInt() ?? 4;
    final marshalCar = (v['marshalCar'] as num?)?.toInt() ?? 0;

    final carPos = [
      for (final x in (v['carPos'] as List?) ?? const []) (x as num).toInt(),
    ];
    final onRoof = [
      for (final x in (v['onRoof'] as List?) ?? const []) x == true,
    ];
    final insideLoot = [
      for (final carList in (v['insideLoot'] as List?) ?? const [])
        [
          for (final it in (carList as List?) ?? const [])
            (it as Map).cast<String, dynamic>(),
        ],
    ];
    final roofLoot = [
      for (final carList in (v['roofLoot'] as List?) ?? const [])
        [
          for (final it in (carList as List?) ?? const [])
            (it as Map).cast<String, dynamic>(),
        ],
    ];
    final scores = [
      for (final x in (v['scores'] as List?) ?? const []) (x as num).toInt(),
    ];
    final bulletsLeft = [
      for (final x in (v['bulletsLeft'] as List?) ?? const [])
        (x as num).toInt(),
    ];
    final wounds = [
      for (final x in (v['wounds'] as List?) ?? const []) (x as num).toInt(),
    ];
    final hand = [
      for (final c in (v['hand'] as List?) ?? const []) '$c',
    ];
    final programStack = [
      for (final e in (v['programStack'] as List?) ?? const [])
        (e as Map).cast<String, dynamic>(),
    ];
    final execIndex = (v['execIndex'] as num?)?.toInt() ?? 0;
    final pendingAction =
        (v['pendingAction'] as Map?)?.cast<String, dynamic>();
    final actionFeed = [
      for (final s in (v['actionFeed'] as List?) ?? const []) '$s',
    ];

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final statusText = over
        ? '疯狂快车劫案结束！'
        : (phase == 'scheming'
            ? '第 $round/$maxRounds 轮 · 编程阶段(${schemeTurnIdx + 1}/$totalSchemeTurns${isTunnelTurn ? "·山洞暗置" : "·明置"}) · 轮到 ${g.name(turn)}'
            : '第 $round/$maxRounds 轮 · 执行阶段(${execIndex + 1}/${programStack.length}) · 轮到 ${g.name(turn)}');

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Stack(
          children: [
            Column(
              children: [
                StatusBar(statusText, highlight: isMyTurn),
                const SizedBox(height: 4),
                _buildBanditsBar(
                  cs,
                  g,
                  turn,
                  scores: scores,
                  bulletsLeft: bulletsLeft,
                  wounds: wounds,
                  compact: compact,
                ),
                const SizedBox(height: 4),
                _buildProgramStackBar(
                  cs,
                  g,
                  programStack,
                  phase: phase,
                  execIndex: execIndex,
                  compact: compact,
                ),
                const SizedBox(height: 4),
                // 3D Train Cars area
                Expanded(
                  child: _buildTrainView(
                    cs,
                    g,
                    marshalCar: marshalCar,
                    carPos: carPos,
                    onRoof: onRoof,
                    insideLoot: insideLoot,
                    roofLoot: roofLoot,
                    compact: compact,
                  ),
                ),
                if (actionFeed.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    actionFeed.last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ],
                if (isMyTurn) ...[
                  const SizedBox(height: 4),
                  _buildControlPanel(
                    cs,
                    g,
                    phase: phase,
                    hand: hand,
                    isTunnelTurn: isTunnelTurn,
                    pendingAction: pendingAction,
                    compact: compact,
                  ),
                ],
              ],
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  '西部列车大劫案落幕！',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            '${g.name(s)}: \$${scores.length > s ? scores[s] : 0}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBanditsBar(
    ColorScheme cs,
    GameContext g,
    int turn, {
    required List<int> scores,
    required List<int> bulletsLeft,
    required List<int> wounds,
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
                      ? _banditColors[s % _banditColors.length]
                          .withValues(alpha: 0.25)
                      : cs.surface.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _banditColors[s % _banditColors.length],
                    width: s == turn ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor:
                          _banditColors[s % _banditColors.length],
                      child: Text(
                        '${s + 1}',
                        style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${g.name(s)} \$${scores.length > s ? scores[s] : 0}',
                      style: TextStyle(
                        fontSize: compact ? 11 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '弹${bulletsLeft.length > s ? bulletsLeft[s] : 6} 伤${wounds.length > s ? wounds[s] : 0}',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onSurface.withValues(alpha: 0.75),
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

  Widget _buildProgramStackBar(
    ColorScheme cs,
    GameContext g,
    List<Map<String, dynamic>> stack, {
    required String phase,
    required int execIndex,
    required bool compact,
  }) {
    return Container(
      height: compact ? 28 : 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.layers, size: 15),
          const SizedBox(width: 4),
          Text(
            '行动栈(${stack.length}):',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: stack.isEmpty
                ? const Text(
                    '等待各强盗编入行动卡…',
                    style: TextStyle(fontSize: 11),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: stack.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 4),
                    itemBuilder: (context, idx) {
                      final item = stack[idx];
                      final seat = (item['seat'] as num).toInt();
                      final card = item['card'] as String? ?? 'hidden';
                      final isCurrent =
                          phase == 'stealin' && idx == execIndex;
                      final resolved = item['resolved'] == true;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? Colors.amber
                              : _banditColors[seat % _banditColors.length]
                                  .withValues(alpha: resolved ? 0.35 : 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: isCurrent
                              ? Border.all(color: Colors.white, width: 1.5)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${g.name(seat)}:${_cardLabels[card] ?? card}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCurrent ? Colors.black : Colors.white,
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

  Widget _buildTrainView(
    ColorScheme cs,
    GameContext g, {
    required int marshalCar,
    required List<int> carPos,
    required List<bool> onRoof,
    required List<List<Map<String, dynamic>>> insideLoot,
    required List<List<Map<String, dynamic>>> roofLoot,
    required bool compact,
  }) {
    return LayoutBuilder(builder: (context, box) {
      final carWidth =
          ((box.maxWidth - (g.players - 1) * 8) / g.players).clamp(115.0, 220.0);
      return Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var c = 0; c < g.players; c++) ...[
                if (c > 0)
                  Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      color: Colors.brown.shade700,
                    ),
                  ),
                SizedBox(
                  width: carWidth,
                  child: _buildTrainCar(
                    cs,
                    g,
                    c,
                    isLocomotive: c == 0,
                    hasMarshal: marshalCar == c,
                    roofBandits: [
                      for (var s = 0; s < g.players; s++)
                        if (carPos.length > s &&
                            onRoof.length > s &&
                            carPos[s] == c &&
                            onRoof[s])
                          s,
                    ],
                    insideBandits: [
                      for (var s = 0; s < g.players; s++)
                        if (carPos.length > s &&
                            onRoof.length > s &&
                            carPos[s] == c &&
                            !onRoof[s])
                          s,
                    ],
                    insideItems:
                        insideLoot.length > c ? insideLoot[c] : const [],
                    roofItems: roofLoot.length > c ? roofLoot[c] : const [],
                    compact: compact,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTrainCar(
    ColorScheme cs,
    GameContext g,
    int carIdx, {
    required bool isLocomotive,
    required bool hasMarshal,
    required List<int> roofBandits,
    required List<int> insideBandits,
    required List<Map<String, dynamic>> insideItems,
    required List<Map<String, dynamic>> roofItems,
    required bool compact,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isLocomotive
            ? const Color(0xFF451A03)
            : const Color(0xFF78350F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isLocomotive ? Colors.amber : Colors.orange.shade300,
          width: isLocomotive ? 2 : 1.2,
        ),
      ),
      padding: EdgeInsets.all(compact ? 4 : 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Car header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  isLocomotive ? '🚂 0号·火车头' : '🚃 $carIdx号·车厢',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.amberAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (hasMarshal)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '★警长',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 3),
          // Roof level
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.lightBlue.shade900.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '【车顶】',
                      style: TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                    Wrap(
                      spacing: 3,
                      runSpacing: 2,
                      children: [
                        for (final s in roofBandits) _banditBadge(g, s),
                        for (final it in roofItems) _lootBadge(it),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Inside level
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '【车厢内】',
                      style: TextStyle(fontSize: 10, color: Colors.orangeAccent),
                    ),
                    Wrap(
                      spacing: 3,
                      runSpacing: 2,
                      children: [
                        if (hasMarshal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '👮警长',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        for (final s in insideBandits) _banditBadge(g, s),
                        for (final it in insideItems) _lootBadge(it),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _banditBadge(GameContext g, int seat) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: _banditColors[seat % _banditColors.length],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        g.name(seat),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _lootBadge(Map<String, dynamic> it) {
    final type = it['type'] as String? ?? 'bag';
    final val = (it['value'] as num?)?.toInt() ?? 250;
    final icon = type == 'strongbox'
        ? '💼'
        : (type == 'gem' ? '💎' : '💰');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.amber.shade700.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$icon\$$val',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildControlPanel(
    ColorScheme cs,
    GameContext g, {
    required String phase,
    required List<String> hand,
    required bool isTunnelTurn,
    required Map<String, dynamic>? pendingAction,
    required bool compact,
  }) {
    if (phase == 'scheming') {
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
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => g.act({'type': 'draw'}),
                icon: const Icon(Icons.style, size: 15),
                label: const Text('抽3张牌', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(width: 8),
              for (var i = 0; i < hand.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      _cardIcons[hand[i]] ?? Icons.sim_card_alert,
                      size: 14,
                    ),
                    label: Text(
                      '${_cardLabels[hand[i]] ?? hand[i]}${isTunnelTurn && hand[i] != "bullet" ? "(暗)" : ""}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: hand[i] == 'bullet'
                        ? null
                        : () => g.act({'type': 'play', 'index': i}),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // phase == 'stealin'
    final card = pendingAction?['card'] as String? ?? '';
    final validMoveCars = [
      for (final x in (pendingAction?['validMoveCars'] as List?) ?? const [])
        (x as num).toInt(),
    ];
    final validTargets = [
      for (final x in (pendingAction?['validTargets'] as List?) ?? const [])
        (x as num).toInt(),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Text(
              '执行【${_cardLabels[card] ?? card}】：',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            for (final c in validMoveCars)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      g.act({'type': 'resolve', 'targetCar': c}),
                  child: Text('前往 $c 号车', style: const TextStyle(fontSize: 11)),
                ),
              ),
            for (final targetSeat in validTargets)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () =>
                      g.act({'type': 'resolve', 'targetSeat': targetSeat}),
                  child: Text(
                    '目标: ${g.name(targetSeat)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => g.act({'type': 'resolve'}),
              icon: const Icon(Icons.play_arrow, size: 16),
              label: const Text('确认执行', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
