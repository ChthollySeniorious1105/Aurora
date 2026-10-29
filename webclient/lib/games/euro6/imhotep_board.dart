import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<Color> _stoneColors = [
  Color(0xFFD32F2F),
  Color(0xFF1976D2),
  Color(0xFF388E3C),
  Color(0xFFFBC02D),
];

const List<String> _destNames = ['集市', '金字塔', '神庙', '墓室', '方尖碑'];
const List<int> _pyramidPts = [2, 1, 3, 2, 4, 3, 2, 1, 3, 2, 3, 4, 2, 4];

const Map<String, String> _marketCardLabels = {
  'statue': '🗿雕像(+2分)',
  'sled3': '⛏️采石(+3石)',
  'pyramid': '🔺入塔(+1石)',
  'obelisk': '🗼入碑(+1石)',
};

class ImhotepBoard extends StatefulWidget {
  final GameContext g;
  const ImhotepBoard(this.g, {super.key});

  @override
  State<ImhotepBoard> createState() => _ImhotepBoardState();
}

class _ImhotepBoardState extends State<ImhotepBoard> {
  int? _selectedShipForSail;

  Widget _stoneBox(int owner, {double size = 22, String? label, VoidCallback? onTap, bool highlight = false}) {
    final isEmpty = owner < 0;
    final col = isEmpty ? Colors.grey.withValues(alpha: 0.25) : _stoneColors[owner % _stoneColors.length];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: col,
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: highlight ? Colors.amberAccent : (isEmpty ? Colors.white38 : Colors.black54),
            width: highlight ? 2 : 1,
          ),
        ),
        child: label != null
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: size * 0.48,
                    fontWeight: FontWeight.bold,
                    color: isEmpty ? Colors.white70 : Colors.white,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 6;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final lastAction = '${v['lastAction'] ?? ''}';

    final ships = (v['ships'] as List?) ?? const [];
    final destShip = (v['destShip'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(5, -1);
    final marketCards = (v['marketCards'] as List?)?.map((e) => '$e').toList() ?? const [];
    final pyramidStones = (v['pyramidStones'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final templeTop = (v['templeTop'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(5, -1);
    final burialStones = (v['burialStones'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final obelisk = (v['obelisk'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];
    final players = (v['players'] as List?) ?? const [];
    final placings = (v['placings'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [];

    final me = g.seat;
    final myTurn = !over && turn == me && !g.replay;
    final mySled = (me >= 0 && me < players.length) ? ((players[me] as Map)['sled'] as num?)?.toInt() ?? 0 : 0;

    if (_selectedShipForSail != null) {
      if (_selectedShipForSail! >= ships.length || (ships[_selectedShipForSail!] as Map)['canSail'] != true) {
        _selectedShipForSail = null;
      }
    }

    String statusText;
    if (over) {
      statusText = '游戏结束 · $lastAction';
    } else if (myTurn) {
      statusText = _selectedShipForSail != null
          ? '轮到你 (第$round/$maxRounds轮)：已选 ${_selectedShipForSail! + 1}号船，请点击下方任意空目的地起航！'
          : '轮到你 (第$round/$maxRounds轮)：可【采石】、【点击船舱空位装船】，或【选船起航】';
    } else {
      statusText = '第 $round/$maxRounds 轮 · 等待 ${g.name(turn)} · $lastAction';
    }

    Widget buildShipCard(int sIdx) {
      final sm = ships[sIdx] as Map;
      final size = (sm['size'] as num?)?.toInt() ?? 2;
      final minReq = (sm['minRequired'] as num?)?.toInt() ?? 1;
      final slots = (sm['slots'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(size, -1);
      final sailed = sm['sailed'] == true;
      final dest = (sm['dest'] as num?)?.toInt() ?? -1;
      final canSail = sm['canSail'] == true;
      final selectedSail = _selectedShipForSail == sIdx;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: sailed
              ? cs.surface.withValues(alpha: 0.4)
              : (selectedSail ? cs.primaryContainer.withValues(alpha: 0.9) : cs.surface.withValues(alpha: 0.88)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selectedSail ? cs.primary : cs.outline.withValues(alpha: 0.35),
            width: selectedSail ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('⛵', style: TextStyle(fontSize: 15)),
                const SizedBox(width: 4),
                Text(
                  '${sIdx + 1}号船 (起航≥$minReq)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var k = 0; k < size; k++) ...[
                  _stoneBox(
                    slots[k],
                    size: 26,
                    label: slots[k] < 0 ? '${k + 1}' : 'P${slots[k] + 1}',
                    highlight: myTurn && !sailed && slots[k] < 0 && mySled > 0,
                    onTap: myTurn && !sailed && slots[k] < 0 && mySled > 0
                        ? () => g.act({'type': 'load', 'ship': sIdx, 'slot': k})
                        : null,
                  ),
                  if (k < size - 1) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 6),
            if (sailed)
              Text(
                '已驶往: ${dest >= 0 && dest < _destNames.length ? _destNames[dest] : "?"}',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.65)),
              )
            else if (myTurn && canSail)
              InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => _selectedShipForSail = selectedSail ? null : sIdx),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: selectedSail ? cs.primary : cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    selectedSail ? '已选起航(点目的地)' : '选此船起航',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: selectedSail ? cs.onPrimary : cs.onSecondaryContainer,
                    ),
                  ),
                ),
              )
            else
              Text(
                canSail ? '可起航' : '还差 ${minReq - slots.where((x) => x >= 0).length} 石可起航',
                style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.65)),
              ),
          ],
        ),
      );
    }

    Widget buildDestCard(int dIdx, Widget content) {
      final dockedShip = destShip[dIdx];
      final open = dockedShip == -1;
      final canSailHere = myTurn && open && _selectedShipForSail != null;

      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canSailHere
            ? () {
                final sIdx = _selectedShipForSail!;
                setState(() => _selectedShipForSail = null);
                g.act({'type': 'sail', 'ship': sIdx, 'dest': dIdx});
              }
            : null,
        child: Container(
          width: 175,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: canSailHere ? cs.primaryContainer.withValues(alpha: 0.85) : cs.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: canSailHere ? cs.primary : cs.outline.withValues(alpha: 0.35),
              width: canSailHere ? 2.2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${dIdx + 1}. ${_destNames[dIdx]}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: cs.onSurface),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: open ? Colors.green.withValues(alpha: 0.2) : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      open ? (canSailHere ? '点击停靠!' : '空泊位') : '${dockedShip + 1}号船已停',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: open ? Colors.green.shade700 : Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              content,
            ],
          ),
        ),
      );
    }

    // Destination 0: Market
    final marketWidget = buildDestCard(
      0,
      Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          if (marketCards.isEmpty)
            Text('本轮集市卡已领完', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.6)))
          else
            for (final c in marketCards)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_marketCardLabels[c] ?? c, style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer)),
              ),
        ],
      ),
    );

    // Destination 1: Pyramid
    final pyramidWidget = buildDestCard(
      1,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (var i = 0; i < 14; i++)
                _stoneBox(
                  i < pyramidStones.length ? pyramidStones[i] : -1,
                  size: 20,
                  label: '${_pyramidPts[i]}',
                ),
            ],
          ),
          if (pyramidStones.length > 14)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text('额外石料: +${pyramidStones.length - 14}', style: const TextStyle(fontSize: 10)),
            ),
        ],
      ),
    );

    // Destination 2: Temple
    final templeWidget = buildDestCard(
      2,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('轮末俯瞰每格+1分:', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 5; i++) ...[
                _stoneBox(
                  templeTop[i],
                  size: 24,
                  label: templeTop[i] < 0 ? '空' : 'P${templeTop[i] + 1}',
                ),
                if (i < 4) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );

    // Destination 3: Burial Chamber
    final burialCols = ((burialStones.length + 2) ~/ 3).clamp(3, 8);
    final burialWidget = buildDestCard(
      3,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('终局相连群(1/3/6/10/15+):', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < 3; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < burialCols; c++) ...[
                          Builder(builder: (_) {
                            final idx = c * 3 + r;
                            final owner = idx < burialStones.length ? burialStones[idx] : -1;
                            return _stoneBox(owner, size: 18, label: owner < 0 ? null : '${owner + 1}');
                          }),
                          const SizedBox(width: 2),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Destination 4: Obelisk
    final obeliskWidget = buildDestCard(
      4,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('终局高度排名(12/6/3分):', style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7))),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (var s = 0; s < obelisk.length; s++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _stoneColors[s % _stoneColors.length].withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _stoneColors[s % _stoneColors.length]),
                  ),
                  child: Text('P${s + 1}: ${obelisk[s]}层', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
        ],
      ),
    );

    Widget buildPlayerStatus(int s) {
      if (s < 0 || s >= players.length) return const SizedBox();
      final p = players[s] as Map;
      final sled = (p['sled'] as num?)?.toInt() ?? 0;
      final vp = (p['vp'] as num?)?.toInt() ?? 0;
      final statues = (p['statues'] as num?)?.toInt() ?? 0;
      final burScore = (p['burialScore'] as num?)?.toInt() ?? 0;
      final obScore = (p['obeliskScore'] as num?)?.toInt() ?? 0;
      final totalScore = (p['totalScore'] as num?)?.toInt() ?? 0;
      final active = !over && turn == s;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? cs.primary : _stoneColors[s % _stoneColors.length].withValues(alpha: 0.6),
            width: active ? 2 : 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            g.tag(s, active: active, size: 28, sub: '总分: $totalScore 分 · 木撬: $sled/5 石'),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text('⭐即时分: $vp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('⚱️墓室: +$burScore', style: const TextStyle(fontSize: 11)),
                Text('🗼方尖碑: +$obScore', style: const TextStyle(fontSize: 11)),
                if (statues > 0) Text('🗿雕像: $statues', style: const TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      );
    }

    Widget? resultBanner;
    if (over && placings.isNotEmpty) {
      final winners = [
        for (var s = 0; s < placings.length; s++)
          if (placings[s] == 1) g.name(s),
      ];
      resultBanner = ResultBanner('${winners.join("、")} 获胜！');
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: StatusBar(statusText, highlight: myTurn)),
                const SizedBox(height: 6),
                if (myTurn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: mySled < 5 ? () => g.act({'type': 'quarry'}) : null,
                          icon: const Icon(Icons.hardware, size: 16),
                          label: Text('采石 (+3石，当前 $mySled/5)'),
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final s in g.seatsFromMe()) buildPlayerStatus(s),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (var sIdx = 0; sIdx < ships.length; sIdx++) buildShipCard(sIdx),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    marketWidget,
                    pyramidWidget,
                    templeWidget,
                    burialWidget,
                    obeliskWidget,
                  ],
                ),
              ],
            ),
          ),
          if (resultBanner != null) Align(alignment: Alignment.topCenter, child: resultBanner),
        ],
      ),
    );
  }
}
