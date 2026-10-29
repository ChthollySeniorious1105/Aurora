import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _manilaCargos = [
  '🟢 玉器 (36P)',
  '🟣 丝绸 (30P)',
  '🟠 肉豆蔻 (24P)',
  '🟡 人参 (18P)',
];

const List<List<int>> _manilaSeatCosts = [
  [3, 4, 5, 5],
  [3, 4, 5],
  [2, 3, 4],
  [1, 2, 3],
];

const List<int> _portCosts = [4, 3, 2];
const List<int> _portPayouts = [6, 8, 15];

class ManilaBoard extends StatefulWidget {
  final GameContext g;
  const ManilaBoard(this.g, {super.key});

  @override
  State<ManilaBoard> createState() => _ManilaBoardState();
}

class _ManilaBoardState extends State<ManilaBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'bid';
    final voyage = (v['voyage'] as num?)?.toInt() ?? 1;
    final maxVoyages = (v['maxVoyages'] as num?)?.toInt() ?? 4;
    final harborMaster = (v['harborMaster'] as num?)?.toInt() ?? 0;
    final highBid = (v['highBid'] as num?)?.toInt() ?? 0;
    final pesos = (v['pesos'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 30);
    final stocks = (v['stocks'] as List?) ?? const [];
    final stockPrice = (v['stockPrice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [0, 0, 0, 0];
    final boatPos = (v['boatPos'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const [3, 2, 2, 2];
    final boatSeats = (v['boatSeats'] as List?) ?? const [];
    final portSeats = (v['portSeats'] as List?) ?? const [null, null, null];
    final shipyardSeats = (v['shipyardSeats'] as List?) ?? const [null, null, null];
    final pirates = (v['pirates'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final insuranceSeat = (v['insuranceSeat'] as num?)?.toInt();
    final placeRound = (v['placeRound'] as num?)?.toInt() ?? 1;
    final lastDice = (v['lastDice'] as List?)?.map((e) => (e as num).toInt()).toList() ?? const <int>[];
    final scores = (v['scores'] as List?)?.map((e) => (e as num).toInt()).toList() ??
        List<int>.filled(g.players, 0);
    final lastEvent = v['lastEvent'] as String? ?? '';

    final isMyTurn = g.seat == turn && !g.over;

    return Container(
      color: g.table,
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: StatusBar(
                      g.over
                          ? '马尼拉海运 — 航程结束'
                          : '第 $voyage/$maxVoyages 航次 · ${phase == 'bid' ? '港务长竞拍' : '第 $placeRound/3 轮派遣'} · ${isMyTurn ? '轮到你行动' : '等待 ${g.name(turn)}'}',
                      highlight: isMyTurn,
                    ),
                  ),
                  if (lastEvent.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      lastEvent,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.85)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  // Stock Ticker & Bidding Controls
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _chip(cs, '⚓ 港务长: ${g.name(harborMaster)}'),
                            for (var c = 0; c < 4; c++)
                              _chip(cs, '${_manilaCargos[c].split(' ').take(2).join(' ')} 股价: ${stockPrice[c]}'),
                            if (lastDice.isNotEmpty) _chip(cs, '🎲 上轮骰子: $lastDice'),
                          ],
                        ),
                        if (isMyTurn && phase == 'bid') ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              for (final inc in const [1, 2, 3])
                                if (g.seat >= 0 && pesos[g.seat] >= highBid + inc)
                                  FilledButton.tonal(
                                    onPressed: () => g.act({'type': 'bid', 'amount': highBid + inc}),
                                    child: Text('出价 ${highBid + inc} 比索'),
                                  ),
                              OutlinedButton(
                                onPressed: () => g.act({'type': 'pass'}),
                                child: const Text('放弃竞拍 (Pass)'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // 4 Cargo Boats Track
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⛵ 四大平底货船航道（满 14 格抵达港口，第 13 格海盗埋伏）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        for (var b = 0; b < 4; b++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _buildBoatRow(
                              g,
                              cs,
                              b,
                              b < boatPos.length ? boatPos[b] : 0,
                              b < boatSeats.length ? (boatSeats[b] as List) : const [],
                              isMyTurn && phase == 'place',
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Port, Shipyard, Pirates & Insurance
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.84),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < 3; i++)
                          _spotButton(
                            cs,
                            '🏗️ 港口#${i + 1} (费${_portCosts[i]}→奖${_portPayouts[i]})',
                            portSeats[i] as int?,
                            g,
                            onTap: isMyTurn && phase == 'place' && portSeats[i] == null
                                ? () => g.act({'type': 'place', 'spot': 'port', 'index': i})
                                : null,
                          ),
                        for (var i = 0; i < 3; i++)
                          _spotButton(
                            cs,
                            '🔨 修船厂#${i + 1} (费${_portCosts[i]}→奖${_portPayouts[i]})',
                            shipyardSeats[i] as int?,
                            g,
                            onTap: isMyTurn && phase == 'place' && shipyardSeats[i] == null
                                ? () => g.act({'type': 'place', 'spot': 'shipyard', 'index': i})
                                : null,
                          ),
                        _spotButton(
                          cs,
                          '🏴‍☠️ 海盗湾 (费5·13格劫船) [${pirates.map(g.name).join(",")}]',
                          pirates.length >= 2 ? pirates.first : null,
                          g,
                          onTap: isMyTurn && phase == 'place' && pirates.length < 2
                              ? () => g.act({'type': 'place', 'spot': 'pirate'})
                              : null,
                        ),
                        _spotButton(
                          cs,
                          '🛡️ 保险公司 (+10比索·赔沉船)',
                          insuranceSeat,
                          g,
                          onTap: isMyTurn && phase == 'place' && insuranceSeat == null
                              ? () => g.act({'type': 'place', 'spot': 'insurance'})
                              : null,
                        ),
                        if (isMyTurn && phase == 'place')
                          OutlinedButton(
                            onPressed: () => g.act({'type': 'pass'}),
                            child: const Text('跳过派遣'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Players & Stock Portfolios
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final s in g.seatsFromMe())
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cs.surface.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: turn == s && !g.over ? cs.primary : cs.outline.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              g.tag(
                                s,
                                active: turn == s && !g.over,
                                sub: '💵 ${pesos[s]} 比索 · 总资产 ${scores[s]}',
                              ),
                              if (s < stocks.length) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '持股: ${_stocksText(stocks[s] as List)}',
                                  style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.75)),
                                ),
                              ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(lastEvent.isNotEmpty ? lastEvent : '游戏结束'),
            ),
        ],
      ),
    );
  }

  String _stocksText(List s) {
    const names = ['玉器', '丝绸', '肉豆蔻', '人参'];
    final parts = <String>[];
    for (var i = 0; i < 4 && i < s.length; i++) {
      final n = (s[i] as num).toInt();
      if (n > 0) parts.add('${names[i]}×$n');
    }
    return parts.isEmpty ? '无' : parts.join(' ');
  }

  Widget _chip(ColorScheme cs, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: cs.secondaryContainer.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cs.onSecondaryContainer)),
    );
  }

  Widget _buildBoatRow(
    GameContext g,
    ColorScheme cs,
    int boatIdx,
    int pos,
    List seats,
    bool canPlace,
  ) {
    final costs = _manilaSeatCosts[boatIdx];
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '${_manilaCargos[boatIdx]} [位置: $pos/14]',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          for (var i = 0; i < costs.length; i++)
            _seatChip(
              g,
              cs,
              costs[i],
              i < seats.length ? (seats[i] as num?)?.toInt() : null,
              onTap: canPlace && pos < 14 && (i >= seats.length || seats[i] == null)
                  ? () => g.act({'type': 'place', 'spot': 'boat', 'boat': boatIdx, 'seatIndex': i})
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _seatChip(GameContext g, ColorScheme cs, int cost, int? occupant, {VoidCallback? onTap}) {
    final occupied = occupant != null;
    final w = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: occupied ? cs.primaryContainer : cs.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: onTap != null ? cs.primary : cs.outline.withValues(alpha: 0.35)),
      ),
      child: Text(
        occupied ? '👤 ${g.name(occupant)}' : '空舱 (${cost}P)',
        style: TextStyle(
          fontSize: 11,
          fontWeight: occupied ? FontWeight.bold : FontWeight.normal,
          color: occupied ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
    if (onTap == null) return w;
    return InkWell(onTap: onTap, child: w);
  }

  Widget _spotButton(ColorScheme cs, String label, int? occupant, GameContext g, {VoidCallback? onTap}) {
    final text = occupant != null ? '$label: ${g.name(occupant)}' : label;
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: occupant != null ? cs.primaryContainer : cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: onTap != null ? cs.primary : cs.outline.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: occupant != null ? FontWeight.bold : FontWeight.normal,
          color: occupant != null ? cs.onPrimaryContainer : cs.onSurface,
        ),
      ),
    );
    if (onTap == null) return box;
    return InkWell(onTap: onTap, child: box);
  }
}
