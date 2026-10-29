import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TokyoKingBoard extends StatefulWidget {
  final GameContext g;
  const TokyoKingBoard(this.g, {super.key});

  @override
  State<TokyoKingBoard> createState() => _TokyoKingBoardState();
}

class _TokyoKingBoardState extends State<TokyoKingBoard> {
  final Set<int> _keptDice = {0, 1, 2, 3, 4, 5};
  int _lastTurn = -1;
  int _lastRollsLeft = -1;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  @override
  void didUpdateWidget(covariant TokyoKingBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final rollsLeft = (v['rollsLeft'] as num?)?.toInt() ?? 2;
    if (turn != _lastTurn || (rollsLeft == 2 && _lastRollsLeft != 2)) {
      _keptDice
        ..clear()
        ..addAll([0, 1, 2, 3, 4]);
      _lastTurn = turn;
    }
    _lastRollsLeft = rollsLeft;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = '${v['phase'] ?? 'roll'}';
    final rollsLeft = (v['rollsLeft'] as num?)?.toInt() ?? 0;
    final targetVp = (v['targetVp'] as num?)?.toInt() ?? 20;
    final tokyoCity = (v['tokyoCity'] as num?)?.toInt() ?? -1;
    final tokyoBay = (v['tokyoBay'] as num?)?.toInt() ?? -1;
    final bayActive = v['bayActive'] == true;
    final dice = (v['dice'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final yieldQueue = (v['yieldQueue'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final market = (v['market'] as List?)?.cast<Map>() ?? const <Map>[];
    final pList = (v['players'] as List?)?.cast<Map>() ?? const <Map>[];
    final lastAction = '${v['lastAction'] ?? ''}';

    final isMyTurn = !g.over && g.seat == turn;
    final isMyYield = !g.over && phase == 'yield' && yieldQueue.isNotEmpty && yieldQueue.first == g.seat;

    String statusText = lastAction;
    if (!g.over) {
      if (isMyYield) {
        statusText = '⚠️ 你在东京受到攻击！请选择【留守东京】或【撤离东京】';
      } else if (isMyTurn) {
        if (phase == 'roll') {
          statusText = '🎲 轮到你：点击骰子切换保留/重掷（剩余 $rollsLeft 次重掷），或直接结算';
        } else if (phase == 'buy') {
          statusText = '⚡ 购卡阶段：可花费能量购买超能力卡、刷新市场或结束回合';
        }
      }
    }

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      statusText,
                      highlight: isMyTurn || isMyYield,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildPlayersWrap(cs, pList, turn, targetVp),
                  const SizedBox(height: 8),
                  _buildTokyoAndDiceRow(
                    cs,
                    tokyoCity: tokyoCity,
                    tokyoBay: tokyoBay,
                    bayActive: bayActive,
                    pList: pList,
                    dice: dice,
                    phase: phase,
                    rollsLeft: rollsLeft,
                    isMyTurn: isMyTurn,
                    isMyYield: isMyYield,
                  ),
                  const SizedBox(height: 8),
                  _buildMarketSection(cs, market, pList, phase, isMyTurn),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: _buildFinalBanner(cs),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayersWrap(ColorScheme cs, List<Map> pList, int turn, int targetVp) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        for (final p in pList) _buildMonsterCard(cs, p, turn, targetVp),
      ],
    );
  }

  Widget _buildMonsterCard(ColorScheme cs, Map p, int turn, int targetVp) {
    final s = (p['seat'] as num?)?.toInt() ?? 0;
    final monster = '${p['monster'] ?? '怪兽'}';
    final hp = (p['hp'] as num?)?.toInt() ?? 0;
    final maxHp = (p['maxHp'] as num?)?.toInt() ?? 10;
    final vp = (p['vp'] as num?)?.toInt() ?? 0;
    final energy = (p['energy'] as num?)?.toInt() ?? 0;
    final alive = p['alive'] == true;
    final inTokyo = p['inTokyo'] == true;
    final cards = (p['cards'] as List?)?.cast<Map>() ?? const <Map>[];
    final active = s == turn && !g.over;

    return Opacity(
      opacity: alive ? 1.0 : 0.45,
      child: Container(
        width: 178,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: inTokyo
                ? Colors.orangeAccent
                : (active ? cs.primary : cs.outline.withValues(alpha: 0.3)),
            width: inTokyo || active ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Avatar(g.avatar(s), size: 26, bot: g.bot(s), dim: !alive),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${g.name(s)}${s == g.seat ? " (我)" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        monster,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: cs.primary),
                      ),
                    ],
                  ),
                ),
                if (inTokyo)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '东京',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                else if (!alive)
                  const Text('💀淘汰', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('❤️ $hp/$maxHp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('⭐ $vp/$targetVp', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('⚡ $energy', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (cards.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: [
                  for (final c in cards)
                    Tooltip(
                      message: '${c['name']}：${c['desc']}',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${c['name']}',
                          style: TextStyle(fontSize: 9, color: cs.onPrimaryContainer),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTokyoAndDiceRow(
    ColorScheme cs, {
    required int tokyoCity,
    required int tokyoBay,
    required bool bayActive,
    required List<Map> pList,
    required List<String> dice,
    required String phase,
    required int rollsLeft,
    required bool isMyTurn,
    required bool isMyYield,
  }) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Tokyo Arena Card
        Container(
          width: 240,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepOrange.shade900.withValues(alpha: 0.85),
                Colors.indigo.shade900.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.amberAccent, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '🗼 东京霸权区（回合开始 +2⭐，红心禁疗）',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _buildTokyoSlot('🏙️ 东京市', tokyoCity, pList),
                  if (bayActive || tokyoBay != -1)
                    _buildTokyoSlot('🌊 东京湾', tokyoBay, pList),
                ],
              ),
            ],
          ),
        ),

        // Dice & Action Controls
        Container(
          constraints: const BoxConstraints(maxWidth: 460),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < dice.length; i++)
                    _buildTokyoDie(
                      cs,
                      index: i,
                      face: dice[i],
                      canToggle: isMyTurn && phase == 'roll' && rollsLeft > 0,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (isMyYield)
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => g.act({'type': 'stay'}),
                      icon: const Icon(Icons.shield, size: 16),
                      label: const Text('留守东京'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => g.act({'type': 'yield'}),
                      icon: const Icon(Icons.directions_run, size: 16),
                      label: const Text('撤离东京'),
                    ),
                  ],
                )
              else if (isMyTurn && phase == 'roll')
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    if (rollsLeft > 0)
                      FilledButton.tonalIcon(
                        onPressed: _keptDice.length >= dice.length
                            ? null
                            : () => g.act({
                                  'type': 'reroll',
                                  'keep': _keptDice.toList(),
                                }),
                        icon: const Icon(Icons.casino, size: 16),
                        label: Text('重掷未锁骰子 ($rollsLeft)'),
                      ),
                    FilledButton.icon(
                      onPressed: () => g.act({'type': 'resolve'}),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('结算骰子'),
                    ),
                  ],
                )
              else if (isMyTurn && phase == 'buy')
                FilledButton.icon(
                  onPressed: () => g.act({'type': 'end_turn'}),
                  icon: const Icon(Icons.skip_next, size: 16),
                  label: const Text('结束回合'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTokyoSlot(String label, int seat, List<Map> pList) {
    final occupied = seat >= 0 && seat < pList.length;
    final monsterName = occupied ? '${pList[seat]['monster']}' : '空缺';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: occupied ? Colors.orangeAccent : Colors.white24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            occupied ? g.name(seat) : '虚位以待',
            style: TextStyle(
              color: occupied ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Text(
            monsterName,
            style: const TextStyle(color: Colors.amberAccent, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTokyoDie(
    ColorScheme cs, {
    required int index,
    required String face,
    required bool canToggle,
  }) {
    final kept = _keptDice.contains(index);
    final (String symbol, String sub, Color bg) = switch (face) {
      '1' => ('1', '3个=1⭐', Colors.amber.shade700),
      '2' => ('2', '3个=2⭐', Colors.amber.shade800),
      '3' => ('3', '3个=3⭐', Colors.orange.shade800),
      'claw' => ('🐾', '爪击', Colors.red.shade700),
      'heart' => ('❤️', '回血', Colors.pink.shade600),
      'energy' => ('⚡', '能量', Colors.green.shade700),
      _ => (face, '', Colors.grey.shade700),
    };

    return GestureDetector(
      onTap: canToggle
          ? () {
              setState(() {
                if (kept) {
                  _keptDice.remove(index);
                } else {
                  _keptDice.add(index);
                }
              });
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 56,
        height: 62,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: canToggle && kept ? Colors.yellowAccent : Colors.white38,
            width: canToggle && kept ? 2.5 : 1,
          ),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3, offset: Offset(1, 2))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  symbol,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  canToggle ? (kept ? '📌保留' : '🔄重掷') : sub,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketSection(
    ColorScheme cs,
    List<Map> market,
    List<Map> pList,
    String phase,
    bool isMyTurn,
  ) {
    final myEnergy = (g.seat >= 0 && g.seat < pList.length)
        ? ((pList[g.seat]['energy'] as num?)?.toInt() ?? 0)
        : 0;
    final hasAlienTech = (g.seat >= 0 && g.seat < pList.length) &&
        ((pList[g.seat]['cards'] as List?)
                ?.any((c) => (c as Map)['id'] == 'alien_tech') ??
            false);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🃏 超能力卡市场', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const Spacer(),
              if (isMyTurn && phase == 'buy')
                TextButton.icon(
                  onPressed: myEnergy >= 2 ? () => g.act({'type': 'sweep'}) : null,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('刷新市场 (2⚡)', style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < market.length; i++)
                _buildPowerCard(
                  cs,
                  index: i,
                  card: market[i],
                  canBuy: isMyTurn && phase == 'buy',
                  myEnergy: myEnergy,
                  discount: hasAlienTech ? 1 : 0,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPowerCard(
    ColorScheme cs, {
    required int index,
    required Map card,
    required bool canBuy,
    required int myEnergy,
    required int discount,
  }) {
    final name = '${card['name']}';
    final rawCost = (card['cost'] as num?)?.toInt() ?? 0;
    final cost = (rawCost - discount) < 1 ? 1 : (rawCost - discount);
    final kind = '${card['kind']}';
    final desc = '${card['desc']}';
    final affordable = canBuy && myEnergy >= cost;

    return Container(
      width: 195,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: affordable ? Colors.greenAccent : cs.outline.withValues(alpha: 0.3),
          width: affordable ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '⚡$cost',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: kind == 'keep' ? Colors.blue.shade700 : Colors.deepOrange.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  kind == 'keep' ? '永久' : '即刻',
                  style: const TextStyle(color: Colors.white, fontSize: 9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.85)),
          ),
          if (canBuy) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 26,
              child: FilledButton.tonal(
                onPressed: affordable ? () => g.act({'type': 'buy', 'index': index}) : null,
                child: Text(affordable ? '购买 ($cost⚡)' : '能量不足'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinalBanner(ColorScheme cs) {
    final fin = (v['final'] as List?)?.cast<Map>() ?? const <Map>[];
    final winners = fin.where((m) => m['win'] == true).map((m) => '${m['name']}').join('、');
    return ResultBanner(
      winners.isEmpty ? '游戏结束' : '🏆 $winners 赢得东京之王！',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final m in fin)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '${m['win'] == true ? "👑 " : ""}${m['name']}：⭐${m['vp']} 分 | ❤️${m['hp']} HP',
                style: TextStyle(
                  fontWeight: m['win'] == true ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
