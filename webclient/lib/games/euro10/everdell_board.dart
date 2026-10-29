import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _resNames = ['树枝', '树脂', '鹅卵石', '浆果'];
const List<String> _resEmojis = ['🪵', '💧', '🪨', '🍓'];
const List<String> _seasonNames = ['❄️冬季', '🌸春季', '☀️夏季', '🍂秋季'];

const Map<String, Color> _catColors = {
  'green': Color(0xFF2E7D32),
  'tan': Color(0xFF8D6E63),
  'blue': Color(0xFF1565C0),
  'red': Color(0xFFC62828),
  'purple': Color(0xFF6A1B9A),
};

const Map<String, String> _catLabels = {
  'green': '绿·生产',
  'tan': '褐·旅行',
  'blue': '蓝·治理',
  'red': '红·目的地',
  'purple': '紫·繁荣',
};

class EverdellBoard extends StatefulWidget {
  final GameContext g;
  const EverdellBoard(this.g, {super.key});

  @override
  State<EverdellBoard> createState() => _EverdellBoardState();
}

class _EverdellBoardState extends State<EverdellBoard> {
  int _viewingSeat = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final lastAction = v['lastAction'] as String? ?? '';
    final meadow = (v['meadow'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final locations = (v['locations'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final season = (v['season'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final workersAvail =
        (v['workersAvail'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final workersTotal =
        (v['workersTotal'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 2);
    final resources = (v['resources'] as List?)
            ?.map((r) => (r as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        List.generate(g.players, (_) => [0, 0, 0, 0]);
    final city = (v['city'] as List?)
            ?.map((c) => (c as List).cast<Map<String, dynamic>>())
            .toList() ??
        List.generate(g.players, (_) => <Map<String, dynamic>>[]);
    final hand = (v['hand'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final finished = (v['finished'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final viewSeat = (_viewingSeat >= 0 && _viewingSeat < g.players) ? _viewingSeat : mySeat;
    final isMyTurn = !g.over && g.seat == turn;

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
                      g.over ? '仙境幽谷结束' : '轮到 ${g.name(turn)} · $lastAction',
                      highlight: isMyTurn,
                    ),
                    for (final s in g.seatsFromMe())
                      GestureDetector(
                        onTap: () => setState(() => _viewingSeat = s),
                        child: g.tag(
                          s,
                          active: s == turn && !g.over,
                          size: 28,
                          sub:
                              '${_seasonNames[season[s].clamp(0, 3)]} | ${scores[s]}分 | 工人:${workersAvail[s]}/${workersTotal[s]} | 城:${city[s].length}/15${finished[s] ? ' (完)' : ''}',
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
                      // Worker Locations + Prepare for Season
                      _buildLocationsPanel(
                        cs,
                        locations,
                        isMyTurn,
                        g.seat >= 0 ? workersAvail[g.seat] : 0,
                        g.seat >= 0 ? season[g.seat] : 0,
                      ),
                      const SizedBox(height: 6),
                      // Central 8-card Meadow
                      _buildMeadowSection(
                        cs,
                        meadow,
                        isMyTurn,
                        g.seat >= 0 ? city[g.seat] : const [],
                      ),
                      const SizedBox(height: 6),
                      // Viewing seat's City & Resources
                      _buildCitySection(
                        cs,
                        viewSeat,
                        season[viewSeat],
                        resources[viewSeat],
                        city[viewSeat],
                        scores[viewSeat],
                      ),
                      const SizedBox(height: 6),
                      // Seated player's Hand
                      if (g.seat >= 0 && g.seat < g.players)
                        _buildHandSection(cs, hand, isMyTurn, city[g.seat]),
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
                '仙境幽谷 · 永恒之树编年榜',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分 (城市 ${city[s].length} 张卡牌)',
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

  Widget _buildLocationsPanel(
    ColorScheme cs,
    List<Map<String, dynamic>> locations,
    bool isMyTurn,
    int myWorkers,
    int mySeason,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('🐾 幽谷工人行动点 (可用工人: $myWorkers):',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              if (isMyTurn)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => g.act({'type': 'prepare_season'}),
                  icon: const Icon(Icons.wb_sunny_outlined, size: 14),
                  label: Text(
                    mySeason < 3 ? '准备换季 → 进入${_seasonNames[(mySeason + 1).clamp(0, 3)]}' : '结束秋季建设 (完成本局)',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final loc in locations)
                _buildLocationChip(cs, loc, isMyTurn && myWorkers > 0, mySeason),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChip(ColorScheme cs, Map<String, dynamic> loc, bool canPlace, int mySeason) {
    final id = (loc['id'] as num?)?.toInt() ?? 0;
    final shared = loc['shared'] == true;
    final occupants = (loc['occupants'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final available = canPlace && (shared || occupants.isEmpty) && (id != 6 || mySeason >= 3);

    return InkWell(
      onTap: available ? () => g.act({'type': 'place_worker', 'loc': id}) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: available ? cs.primaryContainer : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: available ? cs.primary : cs.outline.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${loc['name']}${shared ? ' (共享)' : ''}${occupants.isNotEmpty ? ' [已驻:${occupants.map((s) => g.name(s)).join(',')}]' : ''}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            ),
            Text('${loc['desc']}', style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }

  bool _hasUnoccupiedPair(List<Map<String, dynamic>> myCity, Map<String, dynamic> card) {
    if (card['isCritter'] != true) return false;
    final paired = card['pairedName'] as String? ?? '';
    return myCity.any((c) => c['occupied'] != true && c['name'] == paired);
  }

  Widget _buildMeadowSection(
    ColorScheme cs,
    List<Map<String, dynamic>> meadow,
    bool isMyTurn,
    List<Map<String, dynamic>> myCity,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🌼 中央草地 (8 张公共卡牌 · 点击可直接建造或招募进城):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < meadow.length; i++)
                InkWell(
                  onTap: isMyTurn ? () => g.act({'type': 'play_card', 'source': 'meadow', 'idx': i}) : null,
                  child: _buildEvCardWidget(
                    cs,
                    meadow[i],
                    freePair: _hasUnoccupiedPair(myCity, meadow[i]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCitySection(
    ColorScheme cs,
    int seat,
    int seatSeason,
    List<int> res,
    List<Map<String, dynamic>> seatCity,
    int score,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              Text(
                '🏰 ${g.name(seat)} 的城市 (${seatCity.length}/15 张 | ${_seasonNames[seatSeason.clamp(0, 3)]} | ⭐$score分)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              for (var r = 0; r < 4; r++)
                Text('${_resEmojis[r]}${_resNames[r]}:${res[r]}', style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          if (seatCity.isEmpty)
            const Text('城市尚未建造卡牌', style: TextStyle(fontSize: 11))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final slot in seatCity)
                  _buildEvCardWidget(cs, slot, inCity: true),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHandSection(
    ColorScheme cs,
    List<Map<String, dynamic>> hand,
    bool isMyTurn,
    List<Map<String, dynamic>> myCity,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🃏 我的手牌 (${hand.length}/8 张 · 点击卡牌打入城市):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          if (hand.isEmpty)
            const Text('手牌为空', style: TextStyle(fontSize: 11))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < hand.length; i++)
                  InkWell(
                    onTap: isMyTurn ? () => g.act({'type': 'play_card', 'source': 'hand', 'idx': i}) : null,
                    child: _buildEvCardWidget(
                      cs,
                      hand[i],
                      freePair: _hasUnoccupiedPair(myCity, hand[i]),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEvCardWidget(
    ColorScheme cs,
    Map<String, dynamic> card, {
    bool inCity = false,
    bool freePair = false,
  }) {
    final cat = card['category'] as String? ?? 'green';
    final catColor = _catColors[cat] ?? Colors.green;
    final isCritter = card['isCritter'] == true;
    final unique = card['unique'] == true;
    final cost = (card['cost'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0];
    final costParts = <String>[];
    for (var r = 0; r < 4; r++) {
      if (cost[r] > 0) costParts.add('${_resEmojis[r]}${cost[r]}');
    }
    final occupied = card['occupied'] == true;

    return Container(
      width: 142,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: freePair ? Colors.amber : catColor, width: freePair ? 2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${isCritter ? '🐾' : '🏛️'}${card['name']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text('⭐${card['vp']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
          Text(
            '${unique ? '独特' : '普通'} · ${_catLabels[cat] ?? cat} | ${freePair ? '✨配对免费!' : costParts.join(' ')}',
            style: TextStyle(fontSize: 9, color: freePair ? Colors.amber.shade800 : catColor, fontWeight: FontWeight.bold),
          ),
          if (inCity && !isCritter)
            Text(
              occupied ? '🔒 已配对【${card['pairedName']}】' : '🔓 可免费招募【${card['pairedName']}】',
              style: const TextStyle(fontSize: 9),
            )
          else
            Text(
              '配对: ${card['pairedName']}',
              style: const TextStyle(fontSize: 9),
            ),
          Text(
            '${card['effectDesc'] ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.78)),
          ),
        ],
      ),
    );
  }
}
