import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class HeimlichBoard extends StatefulWidget {
  final GameContext g;
  const HeimlichBoard(this.g, {super.key});

  @override
  State<HeimlichBoard> createState() => _HeimlichBoardState();
}

class _HeimlichBoardState extends State<HeimlichBoard> {
  final List<int> _draftSteps = List<int>.filled(7, 0);
  int _lastTurnCount = -1;
  int _lastBudget = -1;

  static const List<Color> _agentColors = [
    Color(0xFFEF4444), // 0 红
    Color(0xFF3B82F6), // 1 蓝
    Color(0xFF10B981), // 2 绿
    Color(0xFFEAB308), // 3 黄
    Color(0xFFA855F7), // 4 紫
    Color(0xFFF97316), // 5 橙
    Color(0xFF1F2937), // 6 黑
  ];

  static const List<String> _agentLabels = [
    '红特工',
    '蓝特工',
    '绿特工',
    '黄特工',
    '紫特工',
    '橙特工',
    '黑特工',
  ];

  static const List<String> _buildingShort = [
    '0号废墟(-3)',
    '1号报亭(+1)',
    '2号咖啡(+2)',
    '3号古董(+3)',
    '4号钟表(+4)',
    '5号美术(+5)',
    '6号剧院(+6)',
    '7号银行(+7)',
    '8号市政(+8)',
    '9号使馆(+9)',
    '10号总部(+10)',
  ];

  void _syncDraft(int turnCount, int budget, int? myAgent) {
    if (_lastTurnCount != turnCount || _lastBudget != budget) {
      _lastTurnCount = turnCount;
      _lastBudget = budget;
      for (var i = 0; i < 7; i++) {
        _draftSteps[i] = 0;
      }
      if (myAgent != null && myAgent >= 0 && myAgent < 7) {
        _draftSteps[myAgent] = budget;
      } else {
        _draftSteps[0] = budget;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final turnCount = (v['turnCount'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'move';
    final over = v['over'] == true || g.over;
    final targetScore = (v['targetScore'] as num?)?.toInt() ?? 42;
    final moveBudget = (v['moveBudget'] as num?)?.toInt() ?? 1;
    final safeBuilding = (v['safeBuilding'] as num?)?.toInt() ?? 7;
    final myAgent = (v['myAgent'] as num?)?.toInt();

    final agentPos = [
      for (final x in (v['agentPos'] as List?) ?? const [0, 0, 0, 0, 0, 0, 0])
        (x as num).toInt(),
    ];
    final agentScores = [
      for (final x
          in (v['agentScores'] as List?) ?? const [0, 0, 0, 0, 0, 0, 0])
        (x as num).toInt(),
    ];
    final secretAgents = (v['secretAgents'] as List?)
        ?.map((e) => (e as num).toInt())
        .toList();

    _syncDraft(turnCount, moveBudget, myAgent);

    final isMyTurn = !over && g.seat >= 0 && g.seat == turn;
    final statusText = over
        ? '特工暗棋结束 · 秘密身份全部揭晓！'
        : (phase == 'move_safe'
            ? '轮到 ${g.name(turn)} 转移【保险箱】位置！'
            : '轮到 ${g.name(turn)} · 骰子点数: $moveBudget 步（目标 $targetScore 分）');

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;
      return Container(
        color: g.table,
        padding: EdgeInsets.all(compact ? 4 : 8),
        child: Stack(
          children: [
            Column(
              children: [
                // Top bar: status + my secret identity badge
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    if (myAgent != null && myAgent >= 0 && myAgent < 7)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _agentColors[myAgent],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '🕵️ 我的秘密身份: ${_agentLabels[myAgent]} (${agentScores[myAgent]}分)',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                // Public 7-Agent Score Track
                _buildAgentScoreStrip(
                  cs,
                  agentScores: agentScores,
                  agentPos: agentPos,
                  myAgent: myAgent,
                  targetScore: targetScore,
                  compact: compact,
                ),
                const SizedBox(height: 4),
                // Players bar
                _buildPlayersBar(
                  cs,
                  g,
                  turn,
                  secretAgents: secretAgents,
                  agentScores: agentScores,
                  compact: compact,
                ),
                const SizedBox(height: 4),
                // 11 Buildings Grid / Loop
                Expanded(
                  child: _buildBuildingsGrid(
                    cs,
                    agentPos: agentPos,
                    safeBuilding: safeBuilding,
                    myAgent: myAgent,
                    isMoveSafe: isMyTurn && phase == 'move_safe',
                    compact: compact,
                  ),
                ),
                if (isMyTurn) ...[
                  const SizedBox(height: 4),
                  _buildTurnControls(
                    cs,
                    g,
                    phase: phase,
                    moveBudget: moveBudget,
                    safeBuilding: safeBuilding,
                    agentPos: agentPos,
                    compact: compact,
                  ),
                ],
              ],
            ),
            if (over)
              Align(
                alignment: Alignment.center,
                child: ResultBanner(
                  '特工秘密身份揭晓！',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var s = 0; s < g.players; s++)
                        if (secretAgents != null && secretAgents.length > s)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            backgroundColor:
                                _agentColors[secretAgents[s]]
                                    .withValues(alpha: 0.85),
                            label: Text(
                              '${g.name(s)} [${_agentLabels[secretAgents[s]]}]: ${agentScores[secretAgents[s]]}分',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
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

  Widget _buildAgentScoreStrip(
    ColorScheme cs, {
    required List<int> agentScores,
    required List<int> agentPos,
    required int? myAgent,
    required int targetScore,
    required bool compact,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var a = 0; a < 7; a++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _agentColors[a].withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: myAgent == a ? Colors.amberAccent : Colors.white24,
                    width: myAgent == a ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${_agentLabels[a]}${myAgent == a ? "(我)" : ""}: ${agentScores[a]}/$targetScore分 @${agentPos[a]}号',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 10 : 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersBar(
    ColorScheme cs,
    GameContext g,
    int turn, {
    required List<int>? secretAgents,
    required List<int> agentScores,
    required bool compact,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var s = 0; s < g.players; s++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: g.tag(
                s,
                active: s == turn,
                size: compact ? 24 : 30,
                sub: (secretAgents != null && secretAgents.length > s)
                    ? '${_agentLabels[secretAgents[s]]} · ${agentScores[secretAgents[s]]}分'
                    : '身份保密',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingsGrid(
    ColorScheme cs, {
    required List<int> agentPos,
    required int safeBuilding,
    required int? myAgent,
    required bool isMoveSafe,
    required bool compact,
  }) {
    return LayoutBuilder(builder: (context, box) {
      final cols = box.maxWidth > 700 ? 6 : 4;
      final rows = (11 / cols).ceil();
      final itemW = (box.maxWidth - (cols - 1) * 6) / cols;
      final itemH = ((box.maxHeight - (rows - 1) * 6) / rows).clamp(42.0, 140.0);

      return SingleChildScrollView(
        child: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var b = 0; b < 11; b++)
              SizedBox(
                width: itemW,
                height: itemH,
                child: _buildBuildingCard(
                  cs,
                  b,
                  hasSafe: safeBuilding == b,
                  occupants: [
                    for (var a = 0; a < 7; a++)
                      if (agentPos.length > a && agentPos[a] == b) a,
                  ],
                  myAgent: myAgent,
                  canPlaceSafe: isMoveSafe && b != safeBuilding,
                  compact: compact,
                ),
              ),
          ],
        ),
      );
    });
  }

  Widget _buildBuildingCard(
    ColorScheme cs,
    int b, {
    required bool hasSafe,
    required List<int> occupants,
    required int? myAgent,
    required bool canPlaceSafe,
    required bool compact,
  }) {
    final isRuins = b == 0;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: canPlaceSafe
          ? () => widget.g.act({'type': 'move_safe', 'building': b})
          : null,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isRuins
              ? const Color(0xFF450A0A).withValues(alpha: 0.85)
              : (hasSafe
                  ? const Color(0xFF78350F).withValues(alpha: 0.88)
                  : cs.surface.withValues(alpha: 0.82)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasSafe
                ? Colors.amberAccent
                : (canPlaceSafe
                    ? cs.primary
                    : (isRuins ? Colors.redAccent : cs.outline.withValues(alpha: 0.4))),
            width: hasSafe || canPlaceSafe ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    _buildingShort[b],
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 10 : 11,
                      fontWeight: FontWeight.bold,
                      color: isRuins
                          ? Colors.redAccent.shade100
                          : (hasSafe ? Colors.amberAccent : cs.onSurface),
                    ),
                  ),
                ),
                if (hasSafe)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      '🔒保险箱',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 3,
                  runSpacing: 2,
                  children: [
                    for (final a in occupants)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: _agentColors[a],
                          borderRadius: BorderRadius.circular(8),
                          border: myAgent == a
                              ? Border.all(color: Colors.amberAccent, width: 1.5)
                              : null,
                        ),
                        child: Text(
                          '${_agentLabels[a].substring(0, 1)}${myAgent == a ? "★" : ""}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnControls(
    ColorScheme cs,
    GameContext g, {
    required String phase,
    required int moveBudget,
    required int safeBuilding,
    required List<int> agentPos,
    required bool compact,
  }) {
    if (phase == 'move_safe') {
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
              const Text(
                '将🔒保险箱移至: ',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              for (var b = 0; b < 11; b++)
                if (b != safeBuilding)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ActionChip(
                      visualDensity: VisualDensity.compact,
                      label: Text('$b号', style: const TextStyle(fontSize: 11)),
                      onPressed: () =>
                          g.act({'type': 'move_safe', 'building': b}),
                    ),
                  ),
            ],
          ),
        ),
      );
    }

    final allocated = _draftSteps.fold<int>(0, (a, b) => a + b);
    final rem = moveBudget - allocated;

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
              '🎲 剩余步数: $rem/$moveBudget',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 6),
            for (var a = 0; a < 7; a++)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: _agentColors[a].withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _agentColors[a]),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_agentLabels[a].substring(0, 1)}:${_draftSteps[a]}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: _draftSteps[a] > 0
                            ? () => setState(() => _draftSteps[a]--)
                            : null,
                        child: const Icon(Icons.remove_circle_outline, size: 15),
                      ),
                      InkWell(
                        onTap: rem > 0
                            ? () => setState(() => _draftSteps[a]++)
                            : null,
                        child: const Icon(Icons.add_circle_outline, size: 15),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(width: 4),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: rem == 0
                  ? () => g.act({
                        'type': 'move',
                        'steps': List<int>.of(_draftSteps),
                      })
                  : null,
              icon: const Icon(Icons.check, size: 15),
              label: const Text('确认移动', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }
}
