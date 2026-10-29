import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _sgColorNames = ['红', '黄', '绿', '蓝', '紫'];
const List<Color> _sgColors = [
  Color(0xFFE53935), // 0 Red
  Color(0xFFFBC02D), // 1 Yellow
  Color(0xFF43A047), // 2 Green
  Color(0xFF1E88E5), // 3 Blue
  Color(0xFF8E24AA), // 4 Purple
];

class SagradaBoard extends StatefulWidget {
  final GameContext g;
  const SagradaBoard(this.g, {super.key});

  @override
  State<SagradaBoard> createState() => _SagradaBoardState();
}

class _SagradaBoardState extends State<SagradaBoard> {
  int _selectedDieIdx = 0;
  int _viewingSeat = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 8;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final draftStep = (v['draftStep'] as num?)?.toInt() ?? 0;
    final draftOrder = (v['draftOrder'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final lastAction = v['lastAction'] as String? ?? '';

    final draftPool = (v['draftPool'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final publicObjs = (v['publicObjectives'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final tools = (v['tools'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final patternNames = (v['patternNames'] as List?)?.cast<String>() ?? List.filled(g.players, '');
    final pattern = (v['pattern'] as List?)
            ?.map((s) => (s as List).map((r) => (r as List).cast<Map<String, dynamic>>()).toList())
            .toList() ??
        const [];
    final window = (v['window'] as List?)
            ?.map((s) => (s as List).map((r) => (r as List).cast<Map<String, dynamic>?>()).toList())
            .toList() ??
        const [];
    final favor = (v['favor'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final privateColor = (v['privateColor'] as num?)?.toInt();

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final viewSeat = (_viewingSeat >= 0 && _viewingSeat < g.players) ? _viewingSeat : mySeat;
    final isMyTurn = !g.over && g.seat == turn;

    if (_selectedDieIdx >= draftPool.length) _selectedDieIdx = 0;

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(
                      g.over
                          ? '圣家族大教堂结束'
                          : '第 $round/$maxRounds 轮 (蛇形轮抽 ${draftStep + 1}/${draftOrder.length}) · 轮到 ${g.name(turn)} · $lastAction',
                      highlight: isMyTurn,
                    ),
                    for (final s in g.seatsFromMe())
                      GestureDetector(
                        onTap: () => setState(() => _viewingSeat = s),
                        child: g.tag(
                          s,
                          active: s == turn && !g.over,
                          size: 28,
                          sub: '${scores[s]}分 | 🔮恩宠:${favor[s]}',
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Draft Pool + Tool Cards
                      _buildDraftAndToolsPanel(cs, draftPool, tools, isMyTurn, g.seat >= 0 ? favor[g.seat] : 0),
                      const SizedBox(height: 6),
                      // Window Grid + Public/Private Objectives side by side or stacked
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (viewSeat < pattern.length && viewSeat < window.length)
                            _buildWindowFrame(
                              cs,
                              viewSeat,
                              patternNames[viewSeat],
                              pattern[viewSeat],
                              window[viewSeat],
                              favor[viewSeat],
                              scores[viewSeat],
                              isMyTurn && viewSeat == g.seat,
                              draftPool,
                            ),
                          _buildObjectivesPanel(cs, publicObjs, privateColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                '圣家族大教堂 · 彩绘玻璃杰作榜',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分 (🔮恩宠剩余 ${favor[s]})',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildDraftAndToolsPanel(
    ColorScheme cs,
    List<Map<String, dynamic>> draftPool,
    List<Map<String, dynamic>> tools,
    bool isMyTurn,
    int myFavor,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('🎲 选秀池彩骰 (点击选中骰子，再点击下方花窗格子镶嵌):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (isMyTurn)
                OutlinedButton(
                  onPressed: () => g.act({'type': 'pass'}),
                  child: const Text('跳过本次镶嵌', style: TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var i = 0; i < draftPool.length; i++)
                GestureDetector(
                  onTap: () => setState(() => _selectedDieIdx = i),
                  child: _buildDieWidget(
                    (draftPool[i]['color'] as num?)?.toInt() ?? 0,
                    (draftPool[i]['val'] as num?)?.toInt() ?? 1,
                    selected: _selectedDieIdx == i,
                    size: 40,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var t = 0; t < tools.length; t++)
                _buildToolChip(cs, t, tools[t], isMyTurn, myFavor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolChip(ColorScheme cs, int toolIdx, Map<String, dynamic> tool, bool isMyTurn, int myFavor) {
    final cost = (tool['cost'] as num?)?.toInt() ?? 1;
    final canUse = isMyTurn && myFavor >= cost;
    return InkWell(
      onTap: canUse ? () => g.act({'type': 'use_tool', 'toolIdx': toolIdx, 'die': _selectedDieIdx, 'delta': 1}) : null,
      child: Opacity(
        opacity: canUse ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: cs.secondaryContainer,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withValues(alpha: 0.4)),
          ),
          child: Text(
            '🛠️ ${tool['name']} (🔮$cost): ${tool['desc']}',
            style: const TextStyle(fontSize: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowFrame(
    ColorScheme cs,
    int seat,
    String patName,
    List<List<Map<String, dynamic>>> seatPat,
    List<List<Map<String, dynamic>?>> seatWin,
    int seatFavor,
    int seatScore,
    bool canPlaceHere,
    List<Map<String, dynamic>> draftPool,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🪟 ${g.name(seat)} 的花窗 · $patName (🔮$seatFavor | ⭐$seatScore分)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 8),
          for (var r = 0; r < 4; r++)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var c = 0; c < 5; c++)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: _buildWindowCell(
                        cs,
                        r,
                        c,
                        seatPat[r][c],
                        seatWin[r][c],
                        canPlaceHere && draftPool.isNotEmpty,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWindowCell(
    ColorScheme cs,
    int r,
    int c,
    Map<String, dynamic> constraint,
    Map<String, dynamic>? placedDie,
    bool canTap,
  ) {
    if (placedDie != null) {
      return _buildDieWidget(
        (placedDie['color'] as num?)?.toInt() ?? 0,
        (placedDie['val'] as num?)?.toInt() ?? 1,
        size: 46,
      );
    }

    final cType = constraint['type'] as String? ?? 'none';
    final cColor = (constraint['color'] as num?)?.toInt();
    final cShade = (constraint['shade'] as num?)?.toInt();

    Color bg = cs.surfaceContainerHighest;
    String label = '';
    if (cType == 'color' && cColor != null) {
      bg = _sgColors[cColor.clamp(0, 4)].withValues(alpha: 0.32);
      label = _sgColorNames[cColor.clamp(0, 4)];
    } else if (cType == 'shade' && cShade != null) {
      bg = cs.secondaryContainer;
      label = '$cShade';
    }

    return InkWell(
      onTap: canTap
          ? () => g.act({
                'type': 'place',
                'die': _selectedDieIdx,
                'r': r,
                'c': c,
              })
          : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: cType == 'color' && cColor != null
                ? _sgColors[cColor.clamp(0, 4)]
                : cs.outline.withValues(alpha: 0.45),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: cType == 'shade' ? 16 : 12,
            color: cs.onSurface.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  Widget _buildDieWidget(int colorIdx, int val, {bool selected = false, double size = 42}) {
    final c = _sgColors[colorIdx.clamp(0, 4)];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.white : Colors.black38,
          width: selected ? 3 : 1.5,
        ),
        boxShadow: selected ? const [BoxShadow(color: Colors.amber, blurRadius: 6)] : null,
      ),
      child: Text(
        '${_sgColorNames[colorIdx.clamp(0, 4)]}$val',
        style: TextStyle(
          color: colorIdx == 1 ? Colors.black87 : Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.3,
        ),
      ),
    );
  }

  Widget _buildObjectivesPanel(
    ColorScheme cs,
    List<Map<String, dynamic>> publicObjs,
    int? privateColor,
  ) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (privateColor != null) ...[
            Row(
              children: [
                const Text('🔒 我的秘密目标颜色: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _sgColors[privateColor.clamp(0, 4)],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${_sgColorNames[privateColor.clamp(0, 4)]}色点数总和',
                    style: TextStyle(
                      color: privateColor == 1 ? Colors.black87 : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Text('🏛️ 公共目标卡 (全员计分):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          for (final obj in publicObjs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '• 【${obj['name']}】(+${obj['vp']}分): ${obj['desc']}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
