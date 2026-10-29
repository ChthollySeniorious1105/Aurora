import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _foodNames = ['昆虫', '种子', '鱼类', '浆果', '啮齿鼠'];
const List<String> _foodEmojis = ['🐛', '🌾', '🐟', '🍒', '🐁'];
const List<String> _habNames = ['森林 (觅食)', '草原 (产蛋)', '湿地 (抽牌)'];
const List<IconData> _habIcons = [Icons.park, Icons.grass, Icons.water];
const List<Color> _habColors = [Color(0xFF2E7D32), Color(0xFFF9A825), Color(0xFF0277BD)];
const List<int> _eggCosts = [0, 1, 1, 2, 2];

class WingspanBoard extends StatefulWidget {
  final GameContext g;
  const WingspanBoard(this.g, {super.key});

  @override
  State<WingspanBoard> createState() => _WingspanBoardState();
}

class _WingspanBoardState extends State<WingspanBoard> {
  int _selectedHandIdx = -1;
  int _viewingSeat = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 4;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final lastAction = v['lastAction'] as String? ?? '';
    final birdfeeder = (v['birdfeeder'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final tray = (v['tray'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final roundGoals = (v['roundGoals'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final cubesLeft = (v['cubesLeft'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final food = (v['food'] as List?)
            ?.map((r) => (r as List).map((e) => (e as num).toInt()).toList())
            .toList() ??
        List.generate(g.players, (_) => [0, 0, 0, 0, 0]);
    final preserve = (v['preserve'] as List?)
            ?.map((s) => (s as List).map((h) => (h as List).cast<Map<String, dynamic>>()).toList())
            .toList() ??
        List.generate(g.players, (_) => [<Map<String, dynamic>>[], <Map<String, dynamic>>[], <Map<String, dynamic>>[]]);
    final hand = (v['hand'] as List?)?.cast<Map<String, dynamic>>() ?? const <Map<String, dynamic>>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final viewSeat = (_viewingSeat >= 0 && _viewingSeat < g.players) ? _viewingSeat : mySeat;
    final isMyTurn = !g.over && g.seat == turn;

    if (_selectedHandIdx >= hand.length) _selectedHandIdx = -1;

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Column(
            children: [
              // Top status & players bar
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
                          ? '展翅翱翔结束'
                          : '第 $round/$maxRounds 轮 · 轮到 ${g.name(turn)} (${cubesLeft[turn]} 行动块) · $lastAction',
                      highlight: isMyTurn,
                    ),
                    for (final s in g.seatsFromMe())
                      GestureDetector(
                        onTap: () => setState(() => _viewingSeat = s),
                        child: g.tag(
                          s,
                          active: s == turn && !g.over,
                          size: 28,
                          sub: '${scores[s]}分 | 块:${cubesLeft[s]} | 食:${food[s].fold(0, (a, b) => a + b)}',
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
                      // Birdfeeder + Bird Tray + Round Goals row
                      _buildSharedSupply(cs, birdfeeder, tray, roundGoals, round, isMyTurn),
                      const SizedBox(height: 6),
                      // Viewing seat's Food supply & Action hint
                      _buildPlayerHeader(cs, viewSeat, food[viewSeat], scores[viewSeat], isMyTurn),
                      const SizedBox(height: 6),
                      // 3 Habitat rows
                      for (var h = 0; h < 3; h++) ...[
                        _buildHabitatRow(
                          cs,
                          h,
                          preserve[viewSeat][h],
                          isMyTurn && viewSeat == g.seat,
                          hand,
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Hand cards (for seated player)
                      if (g.seat >= 0 && g.seat < g.players)
                        _buildHandSection(cs, hand, isMyTurn),
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
                '展翅翱翔 · 最终保育榜',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${scores[s]} 分',
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

  Widget _buildSharedSupply(
    ColorScheme cs,
    List<int> birdfeeder,
    List<Map<String, dynamic>> tray,
    List<Map<String, dynamic>> roundGoals,
    int currentRound,
    bool isMyTurn,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Birdfeeder
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🎲 喂鸟器: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  if (isMyTurn)
                    InkWell(
                      onTap: () => g.act({'type': 'gain_food'}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _habColors[0],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('觅食', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  for (final f in birdfeeder)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('${_foodEmojis[f.clamp(0, 4)]}${_foodNames[f.clamp(0, 4)]}',
                          style: const TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ],
          ),
          // Bird Tray
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🦅 公开鸟牌托盘 (点击湿地抽牌):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < tray.length; i++)
                    InkWell(
                      onTap: isMyTurn ? () => g.act({'type': 'draw_cards', 'trayIdx': i}) : null,
                      child: _buildMiniBirdCard(cs, tray[i]),
                    ),
                ],
              ),
            ],
          ),
          // Round Goals
          if (roundGoals.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏆 轮次目标:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < roundGoals.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: (i + 1 == currentRound) ? Colors.amber.withValues(alpha: 0.3) : cs.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: (i + 1 == currentRound) ? Colors.amber : Colors.transparent,
                          ),
                        ),
                        child: Text(
                          'R${i + 1}: ${roundGoals[i]['name']}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerHeader(ColorScheme cs, int seat, List<int> seatFood, int score, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('🌿 ${g.name(seat)} 的自然保护区 ($score分)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          for (var f = 0; f < 5; f++)
            Text('${_foodEmojis[f]}${_foodNames[f]}:${seatFood[f]}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHabitatRow(
    ColorScheme cs,
    int hab,
    List<Map<String, dynamic>> birds,
    bool canAct,
    List<Map<String, dynamic>> hand,
  ) {
    final actionTypes = ['gain_food', 'lay_eggs', 'draw_cards'];
    final actionLabels = ['觅食 (+${1 + birds.length ~/ 2})', '产蛋 (+${2 + birds.length ~/ 2})', '抽牌 (+${1 + birds.length ~/ 2})'];
    final selectedCard = (_selectedHandIdx >= 0 && _selectedHandIdx < hand.length) ? hand[_selectedHandIdx] : null;
    final canPlaySelectedHere = canAct &&
        selectedCard != null &&
        birds.length < 5 &&
        ((selectedCard['habitats'] as List?)?.contains(hab) ?? false);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _habColors[hab].withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _habColors[hab].withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(_habIcons[hab], size: 16, color: _habColors[hab]),
              Text(_habNames[hab], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              if (canAct)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _habColors[hab],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => g.act({'type': actionTypes[hab]}),
                  icon: const Icon(Icons.play_arrow, size: 14),
                  label: Text(actionLabels[hab], style: const TextStyle(fontSize: 11)),
                ),
              if (canPlaySelectedHere)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade800,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(60, 28),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    g.act({'type': 'play_bird', 'cardIdx': _selectedHandIdx, 'hab': hab});
                    setState(() => _selectedHandIdx = -1);
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 14),
                  label: Text('在此打出【${selectedCard['name']}】(需${_eggCosts[birds.length]}蛋)',
                      style: const TextStyle(fontSize: 11)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var slot = 0; slot < 5; slot++)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: slot < birds.length
                        ? _buildPlacedBirdSlot(cs, birds[slot])
                        : Container(
                            width: 112,
                            height: 68,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: cs.surface.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cs.outline.withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              '空栖位 #${slot + 1}\n费用: ${_eggCosts[slot]}🥚',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.6)),
                            ),
                          ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlacedBirdSlot(ColorScheme cs, Map<String, dynamic> b) {
    final vp = (b['vp'] as num?)?.toInt() ?? 0;
    final eggs = (b['eggs'] as num?)?.toInt() ?? 0;
    final eggCap = (b['eggCap'] as num?)?.toInt() ?? 0;
    final cached = (b['cachedFood'] as num?)?.toInt() ?? 0;
    final tucked = (b['tuckedCards'] as num?)?.toInt() ?? 0;
    final pType = b['powerType'] as String? ?? 'none';

    return Container(
      width: 132,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: pType == 'brown' ? Colors.brown : cs.primary, width: 1.5),
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
                  '${b['name']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text('🪶$vp', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.amber)),
            ],
          ),
          Text('🥚$eggs/$eggCap  📦$cached  🃏$tucked', style: const TextStyle(fontSize: 10)),
          Text(
            '${b['powerDesc'] ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.75)),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBirdCard(ColorScheme cs, Map<String, dynamic> card, {bool selected = false}) {
    final cost = (card['foodCost'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [0, 0, 0, 0, 0];
    final habs = (card['habitats'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final costStr = <String>[];
    for (var f = 0; f < 5; f++) {
      if (cost[f] > 0) costStr.add('${_foodEmojis[f]}×${cost[f]}');
    }
    final habStr = habs.map((h) => ['🌲', '🌾', '💧'][h.clamp(0, 2)]).join();

    return Container(
      width: 140,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: selected ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? Colors.amber : cs.outline.withValues(alpha: 0.4), width: selected ? 2 : 1),
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
                  '${card['name']}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Text('$habStr 🪶${card['vp']}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          Text('费用: ${costStr.isEmpty ? '免费' : costStr.join(' ')} | 蛋上限:${card['eggCap']}',
              style: const TextStyle(fontSize: 10)),
          Text(
            '${card['powerDesc'] ?? ''}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 9, color: cs.onSurface.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildHandSection(ColorScheme cs, List<Map<String, dynamic>> hand, bool isMyTurn) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🃏 我的手牌 (${hand.length} 张) — ${isMyTurn ? '点击选中鸟牌，再点击对应栖息地行打出' : '等待其他玩家行动'}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          if (hand.isEmpty)
            const Text('手牌为空，可在湿地执行【抽牌】行动', style: TextStyle(fontSize: 11))
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < hand.length; i++)
                  GestureDetector(
                    onTap: () => setState(() => _selectedHandIdx = _selectedHandIdx == i ? -1 : i),
                    child: _buildMiniBirdCard(cs, hand[i], selected: _selectedHandIdx == i),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
