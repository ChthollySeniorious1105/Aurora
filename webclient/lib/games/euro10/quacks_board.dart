import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const Map<String, Color> _chipColors = {
  'white': Color(0xFFECEFF1),
  'orange': Color(0xFFFB8C00),
  'green': Color(0xFF43A047),
  'blue': Color(0xFF1E88E5),
  'red': Color(0xFFE53935),
  'yellow': Color(0xFFFDD835),
  'purple': Color(0xFF8E24AA),
};

const Map<String, String> _chipLabels = {
  'white': '白炸弹',
  'orange': '橙南瓜',
  'green': '绿蜘蛛',
  'blue': '蓝骷髅',
  'red': '红毒伞',
  'yellow': '黄曼德拉',
  'purple': '紫幽灵',
};

int _chipPrice(String color, int val) {
  switch (color) {
    case 'orange':
      return val == 1 ? 3 : (val == 2 ? 6 : 10);
    case 'green':
      return val == 1 ? 4 : (val == 2 ? 8 : 14);
    case 'blue':
      return val == 1 ? 5 : (val == 2 ? 10 : 19);
    case 'red':
      return val == 1 ? 4 : (val == 2 ? 8 : 14);
    case 'yellow':
      return val == 1 ? 6 : (val == 2 ? 11 : 18);
    case 'purple':
      return val == 1 ? 7 : (val == 2 ? 12 : 18);
    default:
      return 99;
  }
}

class QuacksBoard extends StatefulWidget {
  final GameContext g;
  const QuacksBoard(this.g, {super.key});

  @override
  State<QuacksBoard> createState() => _QuacksBoardState();
}

class _QuacksBoardState extends State<QuacksBoard> {
  int _viewingSeat = -1;

  GameContext get g => widget.g;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final v = g.view;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 7;
    final phase = v['phase'] as String? ?? 'brew';
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final lastAction = v['lastAction'] as String? ?? '';

    final droplet = (v['droplet'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final pos = (v['pos'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final whiteSum = (v['whiteSum'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final exploded = (v['exploded'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final stopped = (v['stopped'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final flaskFull = (v['flaskFull'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, true);
    final rubies = (v['rubies'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 1);
    final vp = (v['vp'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final coins = (v['coins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final explosionResolved =
        (v['explosionResolved'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final shopDone = (v['shopDone'] as List?)?.map((e) => e == true).toList() ?? List.filled(g.players, false);
    final bagCounts = (v['bagCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final cauldron = (v['cauldron'] as List?)
            ?.map((r) => (r as List).cast<Map<String, dynamic>>())
            .toList() ??
        List.generate(g.players, (_) => <Map<String, dynamic>>[]);
    final trackCoins = (v['trackCoins'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final trackVp = (v['trackVp'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final trackRubies = ((v['trackRubySpots'] as List?)?.map((e) => (e as num).toInt()).toSet()) ?? const <int>{};

    final mySeat = g.seat >= 0 && g.seat < g.players ? g.seat : 0;
    final viewSeat = (_viewingSeat >= 0 && _viewingSeat < g.players) ? _viewingSeat : mySeat;
    final canActBrew = !g.over && phase == 'brew' && g.seat >= 0 && !stopped[g.seat] && !exploded[g.seat];
    final canActShop = !g.over && phase == 'shop' && g.seat >= 0 && !shopDone[g.seat];

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
                          ? '奎德林堡的庸医结束'
                          : '第 $round/$maxRounds 轮 [${phase == 'brew' ? '熬药阶段' : '结算与采购'}] · $lastAction',
                      highlight: canActBrew || canActShop,
                    ),
                    for (final s in g.seatsFromMe())
                      GestureDetector(
                        onTap: () => setState(() => _viewingSeat = s),
                        child: g.tag(
                          s,
                          active: s == turn && !g.over,
                          size: 28,
                          sub:
                              '${vp[s]}分 💎${rubies[s]} ${flaskFull[s] ? '🧪满' : '🧪空'} | 格:${pos[s]} 白:${whiteSum[s]}/7 ${exploded[s] ? '💥炸锅' : (stopped[s] ? '⏹停' : '')}',
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
                      // Action panel for active player
                      if (canActBrew) _buildBrewControls(cs, g.seat, cauldron[g.seat], flaskFull[g.seat], whiteSum[g.seat]),
                      if (canActShop)
                        _buildShopControls(
                          cs,
                          g.seat,
                          exploded[g.seat],
                          explosionResolved[g.seat],
                          coins[g.seat],
                          rubies[g.seat],
                          flaskFull[g.seat],
                          pos[g.seat],
                          trackVp,
                          trackCoins,
                        ),
                      const SizedBox(height: 6),
                      // Viewing seat's Cauldron Track & Pot
                      _buildCauldronPanel(
                        cs,
                        viewSeat,
                        droplet[viewSeat],
                        pos[viewSeat],
                        whiteSum[viewSeat],
                        exploded[viewSeat],
                        bagCounts[viewSeat],
                        cauldron[viewSeat],
                        trackCoins,
                        trackVp,
                        trackRubies,
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
                '奎德林堡的庸医 · 炼金大师榜',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '${g.name(s)}: ${vp[s]} 分 (💎${rubies[s]} 剩余)',
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

  Widget _buildBrewControls(
    ColorScheme cs,
    int seat,
    List<Map<String, dynamic>> pot,
    bool hasFlask,
    int wSum,
  ) {
    final canUseFlask = hasFlask && pot.isNotEmpty && pot.last['color'] == 'white';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.primary),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('⚗️ 熬药操作 (当前白片总和: $wSum / 7):',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ElevatedButton.icon(
            onPressed: () => g.act({'type': 'draw'}),
            icon: const Icon(Icons.auto_fix_high, size: 16),
            label: const Text('从袋中抽 1 枚药片', style: TextStyle(fontSize: 12)),
          ),
          if (canUseFlask)
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () => g.act({'type': 'use_flask'}),
              icon: const Icon(Icons.science, size: 16),
              label: const Text('使用药瓶退回白片', style: TextStyle(fontSize: 12)),
            ),
          OutlinedButton.icon(
            onPressed: () => g.act({'type': 'stop'}),
            icon: const Icon(Icons.stop_circle_outlined, size: 16),
            label: const Text('见好就收 (停止熬药)', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildShopControls(
    ColorScheme cs,
    int seat,
    bool isExploded,
    bool resolved,
    int myCoins,
    int myRubies,
    bool hasFlask,
    int myPos,
    List<int> trackVp,
    List<int> trackCoins,
  ) {
    final spot = myPos.clamp(0, 33);
    final spotVp = spot < trackVp.length ? trackVp[spot] : 0;
    final spotCoins = spot < trackCoins.length ? trackCoins[spot] : 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isExploded && !resolved) ...[
            Text('💥 你的大锅爆炸了！请在分数与采购金币之间二选一：',
                style: TextStyle(fontWeight: FontWeight.bold, color: cs.error, fontSize: 13)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ElevatedButton(
                  onPressed: () => g.act({'type': 'choose_explosion', 'choice': 'vp'}),
                  child: Text('选择获得 +$spotVp 胜利分'),
                ),
                ElevatedButton(
                  onPressed: () => g.act({'type': 'choose_explosion', 'choice': 'coins'}),
                  child: Text('选择获得 $spotCoins 采购金币'),
                ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('🛒 药材市集 (可用金币: 🪙$myCoins | 红宝石: 💎$myRubies)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                if (myRubies >= 2)
                  OutlinedButton(
                    onPressed: () => g.act({'type': 'spend_rubies', 'target': 'droplet'}),
                    child: const Text('💎×2 推进水滴起点 +1', style: TextStyle(fontSize: 11)),
                  ),
                if (myRubies >= 2 && !hasFlask)
                  OutlinedButton(
                    onPressed: () => g.act({'type': 'spend_rubies', 'target': 'flask'}),
                    child: const Text('💎×2 灌满药瓶 🧪', style: TextStyle(fontSize: 11)),
                  ),
                ElevatedButton(
                  onPressed: () => g.act({'type': 'end_shop'}),
                  child: const Text('完成采购 → 下一轮', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final color in const ['orange', 'green', 'blue', 'red', 'yellow', 'purple'])
                  for (final val in const [1, 2, 4])
                    _buildShopChipButton(cs, color, val, myCoins),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShopChipButton(ColorScheme cs, String color, int val, int myCoins) {
    final price = _chipPrice(color, val);
    final affordable = myCoins >= price;
    final bg = _chipColors[color] ?? Colors.grey;
    return InkWell(
      onTap: affordable ? () => g.act({'type': 'buy', 'color': color, 'val': val}) : null,
      child: Opacity(
        opacity: affordable ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bg, width: 1.5),
          ),
          child: Text(
            '${_chipLabels[color]} $val (🪙$price)',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCauldronPanel(
    ColorScheme cs,
    int seat,
    int drop,
    int curPos,
    int wSum,
    bool isExploded,
    int bagCount,
    List<Map<String, dynamic>> pot,
    List<int> trackCoins,
    List<int> trackVp,
    Set<int> trackRubies,
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
              Text('🍲 ${g.name(seat)} 的炼金大锅', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('💧水滴起点: $drop | 📍当前位置: $curPos / 33 | 💣白片和: $wSum / 7 | 🎒袋中余片: $bagCount',
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          // Cauldron Track 0..33
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var idx = 0; idx <= 33; idx++)
                  Container(
                    width: 44,
                    margin: const EdgeInsets.only(right: 3),
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                    decoration: BoxDecoration(
                      color: idx == curPos
                          ? (isExploded ? Colors.red.withValues(alpha: 0.4) : Colors.amber.withValues(alpha: 0.45))
                          : (idx == drop ? Colors.blue.withValues(alpha: 0.25) : cs.surfaceContainerHighest),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: idx == curPos ? Colors.amber : (idx == drop ? Colors.blue : Colors.transparent),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('#$idx${trackRubies.contains(idx) ? '💎' : ''}',
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        Text('🪙${idx < trackCoins.length ? trackCoins[idx] : 0}',
                            style: const TextStyle(fontSize: 9)),
                        Text('⭐${idx < trackVp.length ? trackVp[idx] : 0}',
                            style: const TextStyle(fontSize: 9)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text('本轮已入锅药片:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 4),
          if (pot.isEmpty)
            const Text('锅中暂无药片', style: TextStyle(fontSize: 11))
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final c in pot)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: (_chipColors[c['color']] ?? Colors.grey).withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _chipColors[c['color']] ?? Colors.grey, width: 1.5),
                    ),
                    child: Text(
                      '${_chipLabels[c['color']] ?? c['color']} +${c['val']}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
