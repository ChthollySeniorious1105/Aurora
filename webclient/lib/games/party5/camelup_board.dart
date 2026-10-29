import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class CamelUpBoard extends StatefulWidget {
  final GameContext g;
  const CamelUpBoard(this.g, {super.key});

  @override
  State<CamelUpBoard> createState() => _CamelUpBoardState();
}

class _CamelUpBoardState extends State<CamelUpBoard> {
  static const List<String> _camelNames = ['蓝', '绿', '红', '黄', '白'];
  static const List<Color> _camelColors = [
    Color(0xFF1E88E5), // 蓝
    Color(0xFF43A047), // 绿
    Color(0xFFE53935), // 红
    Color(0xFFFDD835), // 黄
    Color(0xFFF5F5F5), // 白
  ];
  static const List<Color> _camelTextColors = [
    Colors.white,
    Colors.white,
    Colors.white,
    Colors.black87,
    Colors.black87,
  ];

  int _selectedDesertDir = 1; // 1 = Oasis (+1), -1 = Mirage (-1)
  int? _selectedRaceCamel;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final trackLen = (v['trackLen'] as num?)?.toInt() ?? 16;
    final leg = (v['leg'] as num?)?.toInt() ?? 1;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final coins = (v['coins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 3);
    final pyramidTickets =
        (v['pyramidTickets'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final stacksRaw = (v['stacks'] as Map?)?.cast<String, dynamic>() ?? const {};
    final desertRaw = (v['desertTiles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final camelRanking = (v['camelRanking'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 1, 2, 3, 4];
    final unrolledCamels =
        (v['unrolledCamels'] as List?)?.map((e) => (e as num).toInt()).toSet() ?? const <int>{};
    final rolledHistory = (v['rolledHistory'] as List?)?.cast<Map>() ?? const [];
    final legBetTiles = (v['legBetTiles'] as List?)
            ?.map((l) => (l as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        List.generate(5, (_) => [5, 3, 2]);
    final playerLegBets = (v['playerLegBets'] as List?)
            ?.map((l) => (l as List).cast<Map>().toList())
            .toList() ??
        List.generate(g.players, (_) => <Map>[]);
    final myRaceHand = (v['myRaceHand'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final winBets = (v['winBets'] as List?)?.cast<Map>() ?? const [];
    final loseBets = (v['loseBets'] as List?)?.cast<Map>() ?? const [];
    final lastEvent = (v['lastEvent'] as String?) ?? '';

    final myTurn = !over && g.seat == turn;
    final leadCamel = camelRanking.isNotEmpty ? camelRanking.first : 0;
    final lastCamel = camelRanking.isNotEmpty ? camelRanking.last : 4;

    if (_selectedRaceCamel != null && !myRaceHand.contains(_selectedRaceCamel)) {
      _selectedRaceCamel = myRaceHand.isNotEmpty ? myRaceHand.first : null;
    } else if (_selectedRaceCamel == null && myRaceHand.isNotEmpty) {
      _selectedRaceCamel = myRaceHand.first;
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header status bar
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StatusBar(
                        over
                            ? '骆驼大赛已结束'
                            : (myTurn ? '第 $leg 分段 · 轮到你行动（4 选 1）' : '第 $leg 分段 · 轮到 ${g.name(turn)}'),
                        highlight: myTurn,
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _badgePill(cs, '金字塔余 ${unrolledCamels.length}/5 骰'),
                          _badgePill(cs, '领跑: ${_camelNames[leadCamel]}驼 · 垫底: ${_camelNames[lastCamel]}驼'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Main scrollable board area
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (lastEvent.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: cs.surface.withValues(alpha: 0.75),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                lastEvent,
                                style: TextStyle(fontSize: 12, color: cs.onSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),

                          // Track section
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.78),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.primary.withValues(alpha: 0.35)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '🏜️ 沙漠赛道（点击空格可放置绿洲/海市蜃楼）',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    if (myTurn)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ChoiceChip(
                                            label: const Text('🌴绿洲(+1)', style: TextStyle(fontSize: 11)),
                                            selected: _selectedDesertDir == 1,
                                            visualDensity: VisualDensity.compact,
                                            onSelected: (_) => setState(() => _selectedDesertDir = 1),
                                          ),
                                          const SizedBox(width: 6),
                                          ChoiceChip(
                                            label: const Text('🏜️海市蜃楼(-1)', style: TextStyle(fontSize: 11)),
                                            selected: _selectedDesertDir == -1,
                                            visualDensity: VisualDensity.compact,
                                            onSelected: (_) => setState(() => _selectedDesertDir = -1),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (var pos = 0; pos <= trackLen; pos++)
                                      _buildTrackCell(
                                        cs,
                                        pos: pos,
                                        trackLen: trackLen,
                                        stacksRaw: stacksRaw,
                                        desertRaw: desertRaw,
                                        myTurn: myTurn,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Pyramid & Leg Betting Panel
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '🎯 分段下注（点击拿取顶层下注牌）',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: cs.onSurface,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: [
                                        for (final r in rolledHistory)
                                          _buildRolledDieBadge(
                                            (r['camel'] as num?)?.toInt() ?? 0,
                                            (r['steps'] as num?)?.toInt() ?? 1,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    for (var c = 0; c < 5; c++)
                                      _buildLegBetButton(
                                        cs,
                                        camel: c,
                                        tiles: legBetTiles[c],
                                        unrolled: unrolledCamels.contains(c),
                                        myTurn: myTurn,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Overall Race Betting Panel
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                            ),
                            child: Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    _buildRacePileSummary(cs, '🏆 全场冠军押注', winBets, over),
                                    _buildRacePileSummary(cs, '🐢 全场垫底押注', loseBets, over),
                                  ],
                                ),
                                if (myTurn && myRaceHand.isNotEmpty)
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      for (final c in myRaceHand)
                                        GestureDetector(
                                          onTap: () => setState(() => _selectedRaceCamel = c),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: _camelColors[c],
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: _selectedRaceCamel == c ? cs.primary : Colors.black38,
                                                width: _selectedRaceCamel == c ? 2.5 : 1,
                                              ),
                                            ),
                                            child: Text(
                                              '${_camelNames[c]}驼',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: _camelTextColors[c],
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (_selectedRaceCamel != null) ...[
                                        OutlinedButton(
                                          onPressed: () => g.act({
                                            'type': 'race_bet',
                                            'camel': _selectedRaceCamel,
                                            'bet': 'win',
                                          }),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          child: const Text('押总冠军', style: TextStyle(fontSize: 11)),
                                        ),
                                        OutlinedButton(
                                          onPressed: () => g.act({
                                            'type': 'race_bet',
                                            'camel': _selectedRaceCamel,
                                            'bet': 'lose',
                                          }),
                                          style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                                          child: const Text('押垫底', style: TextStyle(fontSize: 11)),
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Players row
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final s in g.seatsFromMe())
                                _buildPlayerTag(
                                  cs,
                                  s,
                                  active: !over && turn == s,
                                  coins: coins[s],
                                  tickets: pyramidTickets[s],
                                  legBets: playerLegBets[s],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Bottom roll action bar for current turn player
                  if (myTurn) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.surface.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.primary.withValues(alpha: 0.5)),
                      ),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: () => g.act({'type': 'roll'}),
                            icon: const Icon(Icons.casino, size: 18),
                            label: const Text('摇金字塔骰子 (+1🪙)'),
                          ),
                          Text(
                            '或点击上方：分段下注牌 / 赛道空格放瓦片 / 全场暗投',
                            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: _buildResultBanner(cs, coins, camelRanking),
            ),
        ],
      ),
    );
  }

  Widget _badgePill(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSurface)),
    );
  }

  Widget _buildTrackCell(
    ColorScheme cs, {
    required int pos,
    required int trackLen,
    required Map<String, dynamic> stacksRaw,
    required Map<String, dynamic> desertRaw,
    required bool myTurn,
  }) {
    final isFinish = pos == trackLen;
    // If any camels are at >= trackLen, collect them into the finish cell
    final camels = <int>[];
    if (isFinish) {
      for (final e in stacksRaw.entries) {
        final p = int.tryParse(e.key) ?? -1;
        if (p >= trackLen) {
          camels.addAll((e.value as List).map((x) => (x as num).toInt()));
        }
      }
    } else {
      final list = stacksRaw['$pos'] as List?;
      if (list != null) {
        camels.addAll(list.map((x) => (x as num).toInt()));
      }
    }

    final desert = !isFinish ? (desertRaw['$pos'] as Map?) : null;
    final canTapDesert = myTurn && pos >= 1 && pos < trackLen && camels.isEmpty;

    Widget cell = Container(
      width: 64,
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isFinish
            ? Colors.amber.withValues(alpha: 0.25)
            : (camels.isNotEmpty
                ? cs.primaryContainer.withValues(alpha: 0.45)
                : cs.surface.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isFinish ? Colors.amber.shade700 : cs.outline.withValues(alpha: 0.35),
          width: isFinish ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isFinish ? '🏁终点' : '#${pos + 1}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isFinish ? Colors.amber.shade800 : cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 2),
          // Render camel stack from TOP (last index) to BOTTOM (index 0)
          for (var i = camels.length - 1; i >= 0; i--)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(vertical: 1),
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: _camelColors[camels[i]],
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: Colors.black26, width: 0.8),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '🐪${_camelNames[camels[i]]}${i == camels.length - 1 && camels.length > 1 ? '▲' : ''}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _camelTextColors[camels[i]],
                  ),
                ),
              ),
            ),
          if (desert != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              decoration: BoxDecoration(
                color: (desert['dir'] == 1 ? Colors.green : Colors.deepOrange).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: desert['dir'] == 1 ? Colors.green : Colors.deepOrange,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${desert['dir'] == 1 ? '🌴+1' : '🏜️-1'} ${desert['ownerName'] ?? ''}',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
              ),
            ),
        ],
      ),
    );

    if (!canTapDesert) return cell;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'desert', 'space': pos, 'dir': _selectedDesertDir}),
      child: cell,
    );
  }

  Widget _buildRolledDieBadge(int camel, int steps) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _camelColors[camel],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black38),
      ),
      child: Text(
        '${_camelNames[camel]}+$steps',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _camelTextColors[camel]),
      ),
    );
  }

  Widget _buildLegBetButton(
    ColorScheme cs, {
    required int camel,
    required List<int> tiles,
    required bool unrolled,
    required bool myTurn,
  }) {
    final topVal = tiles.isNotEmpty ? tiles.first : null;
    final enabled = myTurn && topVal != null;

    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _camelColors[camel].withValues(alpha: topVal != null ? 0.9 : 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black38, width: enabled ? 1.5 : 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '🐪${_camelNames[camel]}驼',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _camelTextColors[camel],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              topVal != null ? '头名+$topVal🪙' : '已抢空',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _camelTextColors[camel]),
            ),
          ),
          if (unrolled) ...[
            const SizedBox(width: 4),
            Icon(Icons.casino_outlined, size: 13, color: _camelTextColors[camel]),
          ],
        ],
      ),
    );

    if (!enabled) return card;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => g.act({'type': 'leg_bet', 'camel': camel}),
      child: card,
    );
  }

  Widget _buildRacePileSummary(ColorScheme cs, String label, List<Map> bets, bool over) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label (${bets.length}张)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: cs.onSurface)),
          if (bets.isNotEmpty) ...[
            const SizedBox(width: 6),
            Wrap(
              spacing: 3,
              children: [
                for (final b in bets)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: (b['camel'] as int? ?? -1) >= 0
                          ? _camelColors[b['camel'] as int]
                          : cs.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (b['camel'] as int? ?? -1) >= 0
                          ? '${g.name((b['seat'] as num).toInt())}:${_camelNames[b['camel'] as int]}'
                          : g.name((b['seat'] as num).toInt()),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: (b['camel'] as int? ?? -1) >= 0
                            ? _camelTextColors[b['camel'] as int]
                            : cs.onPrimaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayerTag(
    ColorScheme cs,
    int s, {
    required bool active,
    required int coins,
    required int tickets,
    required List<Map> legBets,
  }) {
    Widget? trailing;
    if (legBets.isNotEmpty) {
      trailing = Wrap(
        spacing: 2,
        children: [
          for (final b in legBets)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: _camelColors[(b['camel'] as num).toInt()],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${_camelNames[(b['camel'] as num).toInt()]}${b['payout']}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _camelTextColors[(b['camel'] as num).toInt()],
                ),
              ),
            ),
        ],
      );
    }

    return g.tag(
      s,
      active: active,
      size: 32,
      sub: '🪙 $coins 金币${tickets > 0 ? ' · 🎫$tickets' : ''}',
      trailing: trailing,
    );
  }

  Widget _buildResultBanner(ColorScheme cs, List<int> coins, List<int> camelRanking) {
    final order = [for (var i = 0; i < g.players; i++) i]..sort((a, b) => coins[b].compareTo(coins[a]));
    final winner = order.first;
    final winCamel = camelRanking.isNotEmpty ? _camelNames[camelRanking.first] : '?';
    final loseCamel = camelRanking.isNotEmpty ? _camelNames[camelRanking.last] : '?';
    return ResultBanner(
      '🏆 ${g.name(winner)} 赢得骆驼大赛！（${coins[winner]} 🪙）',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '冠军骆驼：$winCamel驼 · 垫底骆驼：$loseCamel驼',
            style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.8)),
          ),
          const SizedBox(height: 6),
          for (final s in order)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${g.name(s)}：${coins[s]} 🪙',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: s == winner ? FontWeight.bold : FontWeight.normal,
                  color: cs.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
