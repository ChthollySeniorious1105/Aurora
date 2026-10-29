import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const _factionNames = {
  'red': '潜伏战线（红方）',
  'blue': '军情处（蓝方）',
  'green': '神秘酱油（绿方）',
};

const _actionNames = {
  'lock': '锁定',
  'swap': '调包',
  'decrypt': '破译',
  'intercept': '截获',
  'counter': '识破',
  'transfer': '转移',
  'reinforce': '增援',
  'burn': '烧毁',
  'trap': '真伪莫辨',
};

const _colorNames = {
  'red': '红情报',
  'blue': '蓝情报',
  'black': '黑情报',
};

const _deliveryNames = {
  'direct': '直达',
  'text': '密电',
};

const _receiveResponseActions = {'decrypt', 'counter', 'swap', 'transfer', 'intercept'};

List<int> _ints(Object? v) => v is List ? [for (final e in v) (e as num).toInt()] : <int>[];

class TheMessageBoard extends StatefulWidget {
  final GameContext g;
  const TheMessageBoard(this.g, {super.key});
  @override
  State<TheMessageBoard> createState() => _TheMessageBoardState();
}

class _TheMessageBoardState extends State<TheMessageBoard> {
  int _selectedCard = 0;
  int _selectedTarget = -1;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  String get phase => (v['phase'] as String?) ?? 'action';

  Color _cardColor(String c) => switch (c) {
        'red' => Colors.red.shade700,
        'blue' => Colors.blue.shade700,
        _ => Colors.grey.shade800,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = g.seat;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final sender = (v['sender'] as num?)?.toInt() ?? -1;
    final currentTarget = (v['currentTarget'] as num?)?.toInt() ?? -1;
    final alive = (v['alive'] as List?)?.cast<bool>() ?? List.filled(g.players, true);
    final codenames = (v['codenames'] as List?)?.cast<String>() ?? List.filled(g.players, '特工');
    final myFaction = v['myFaction'] as String?;
    final factions = (v['factions'] as List?) ?? List.filled(g.players, null);
    final hand = (v['hand'] as List?)?.cast<Map>() ?? const <Map>[];
    final handCounts = _ints(v['handCounts']);
    final intelLists = (v['intel'] as List?) ?? List.filled(g.players, const []);
    final locked = _ints(v['locked']).toSet();
    final canPass = v['canPass'] == true;
    final transitDelivery = v['transitDelivery'] as String?;
    final transitCard = (v['transitCard'] as Map?)?.cast<String, dynamic>();
    final lastPeek = v['lastPeek'] as String?;
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;

    final otherAlive = [
      for (var s = 0; s < g.players; s++)
        if (alive[s] && s != me) s,
    ];
    if (!otherAlive.contains(_selectedTarget)) {
      _selectedTarget = otherAlive.isNotEmpty ? otherAlive.first : 0;
    }
    if (_selectedCard >= hand.length) {
      _selectedCard = 0;
    }

    String status;
    var hl = false;
    switch (phase) {
      case 'action':
        hl = me == turn;
        status = hl
            ? '你的回合：可打出功能牌，或选择 1 张手牌作为情报传给他人'
            : '等待 ${g.name(turn)}（${codenames[turn]}）出牌并传递情报…';
        break;
      case 'receive':
        hl = me == currentTarget;
        status = hl
            ? '情报到达你面前！请选择【接收情报】、【拒收传递】或使用响应牌'
            : '情报传递中：等待 ${g.name(currentTarget)} 处理来自 ${g.name(sender)} 的情报…';
        break;
      default:
        status = '${v['reason'] ?? '对局结束'}';
    }

    Widget buildHeaderBar() {
      final facColor = switch (myFaction) {
        'red' => Colors.red,
        'blue' => Colors.blue,
        'green' => Colors.green,
        _ => cs.primary,
      };
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: facColor.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: facColor.withValues(alpha: 0.7)),
        ),
        child: Wrap(
          spacing: 10,
          runSpacing: 2,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (me >= 0 && myFaction != null)
              Text(
                '代号：${codenames[me]} ｜ 阵营：${_factionNames[myFaction]}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: facColor),
              ),
            Text('牌库剩余：$deckCount 张', style: const TextStyle(fontSize: 11)),
            if (phase == 'receive' && transitDelivery != null)
              Text(
                '当前传递：【${_deliveryNames[transitDelivery] ?? transitDelivery}】'
                '${transitCard != null ? "（已破译：${_colorNames[transitCard['color']]}·${_actionNames[transitCard['action']]}）" : ""}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
            if (lastPeek != null)
              Text(lastPeek, style: const TextStyle(fontSize: 11, color: Colors.cyan)),
          ],
        ),
      );
    }

    Widget seatTile(int s) {
      final isAlive = alive[s];
      final isTurn = phase == 'action' && s == turn;
      final isTarget = phase == 'receive' && s == currentTarget;
      final isSelTarget = s == _selectedTarget && s != me;
      final sIntel = (intelLists[s] as List).cast<Map>();
      final rCnt = sIntel.where((c) => c['color'] == 'red').length;
      final bCnt = sIntel.where((c) => c['color'] == 'blue').length;
      final kCnt = sIntel.where((c) => c['color'] == 'black').length;
      final fac = factions[s] as String?;
      final hCnt = s < handCounts.length ? handCounts[s] : 0;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isAlive && s != me ? () => setState(() => _selectedTarget = s) : null,
        child: Opacity(
          opacity: isAlive ? 1.0 : 0.5,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 156,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isSelTarget
                  ? cs.primaryContainer.withValues(alpha: 0.42)
                  : cs.surface.withValues(alpha: 0.68),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isTarget
                    ? Colors.amber
                    : (isSelTarget ? cs.primary : cs.outline.withValues(alpha: 0.3)),
                width: isTarget || isSelTarget || isTurn ? 2 : 1,
              ),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              g.tag(
                s,
                active: (isTurn || isTarget) && !g.over,
                sub: '${codenames[s]} · 手牌 $hCnt',
                size: 28,
              ),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _intelPill('红$rCnt', Colors.red),
                const SizedBox(width: 4),
                _intelPill('蓝$bCnt', Colors.blue),
                const SizedBox(width: 4),
                _intelPill('黑$kCnt', Colors.grey.shade800),
              ]),
              const SizedBox(height: 3),
              Wrap(spacing: 4, runSpacing: 2, alignment: WrapAlignment.center, children: [
                if (!isAlive) _badge('💀已阵亡', Colors.grey),
                if (isTurn) _badge('📡行动中', Colors.amber),
                if (isTarget) _badge('📩待接收', Colors.orange),
                if (locked.contains(s)) _badge('🔒已锁定', Colors.deepOrange),
                if (fac != null)
                  _badge(
                    _factionNames[fac] ?? fac,
                    fac == 'red' ? Colors.red : (fac == 'blue' ? Colors.blue : Colors.green),
                  ),
                if (isSelTarget && me >= 0 && !g.over) _badge('当前目标', cs.primary),
              ]),
            ]),
          ),
        ),
      );
    }

    Widget buildHandArea() {
      if (me < 0 || !alive[me] || g.over) return const SizedBox.shrink();
      final selCard = hand.isNotEmpty && _selectedCard < hand.length ? hand[_selectedCard] : null;
      final selAction = selCard?['action'] as String?;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.82),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          border: Border(top: BorderSide(color: cs.outline.withValues(alpha: 0.25))),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (hand.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (var i = 0; i < hand.length; i++)
                  Builder(builder: (context) {
                    final c = hand[i];
                    final col = '${c['color']}';
                    final act = '${c['action']}';
                    final del = '${c['delivery']}';
                    final selected = i == _selectedCard;
                    final bg = _cardColor(col);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _selectedCard = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          width: 82,
                          height: 62,
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: bg.withValues(alpha: selected ? 0.95 : 0.72),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected ? Colors.amberAccent : Colors.white38,
                              width: selected ? 2.5 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _actionNames[act] ?? act,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${_colorNames[col]}·${_deliveryNames[del]}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ]),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              if (phase == 'action' && me == turn && selCard != null) ...[
                OutlinedButton.icon(
                  onPressed: () => g.act({
                    'type': 'play_action',
                    'index': _selectedCard,
                    'target': _selectedTarget,
                  }),
                  icon: const Icon(Icons.auto_fix_high, size: 16),
                  label: Text('打出功能【${_actionNames[selAction]}】'),
                ),
                FilledButton.icon(
                  onPressed: otherAlive.isNotEmpty
                      ? () => g.act({
                            'type': 'transmit',
                            'index': _selectedCard,
                            'target': _selectedTarget,
                          })
                      : null,
                  icon: const Icon(Icons.send, size: 16),
                  label: Text('传情报给 ${g.name(_selectedTarget)}'),
                ),
              ],
              if (phase == 'receive' && me == currentTarget) ...[
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                  onPressed: () => g.act({'type': 'accept'}),
                  icon: const Icon(Icons.download_done, size: 16),
                  label: const Text('接收情报'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.deepOrange),
                  onPressed: canPass ? () => g.act({'type': 'pass'}) : null,
                  icon: const Icon(Icons.forward, size: 16),
                  label: Text(canPass ? '拒收并传递' : '已锁定/必接'),
                ),
                if (selAction != null && _receiveResponseActions.contains(selAction))
                  OutlinedButton.icon(
                    onPressed: () => g.act({
                      'type': 'use_card',
                      'index': _selectedCard,
                      'target': _selectedTarget,
                    }),
                    icon: const Icon(Icons.bolt, size: 16),
                    label: Text('响应【${_actionNames[selAction]}】'),
                  ),
              ],
            ],
          ),
        ]),
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 860;
      final mainCol = Column(children: [
        const SizedBox(height: 4),
        StatusBar(status, highlight: hl),
        buildHeaderBar(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [for (final s in g.seatsFromMe()) seatTile(s)],
            ),
          ),
        ),
        buildHandArea(),
        if (g.over || phase == 'over') ResultBanner(status),
      ]);

      if (!wide) return mainCol;
      return Row(children: [
        Expanded(child: mainCol),
        SizedBox(
          width: 260,
          child: ListView(padding: const EdgeInsets.all(8), children: [
            _historyCard(),
          ]),
        ),
      ]);
    });
  }

  Widget _intelPill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );

  Widget _badge(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.withValues(alpha: 0.7)),
        ),
        child: Text(t, style: const TextStyle(fontSize: 10)),
      );

  Widget _historyCard() {
    final hist = (v['history'] as List?)?.cast<Map>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('电台截获记录', style: TextStyle(fontWeight: FontWeight.bold)),
          if (hist.isEmpty) const Text('暂无情报接收', style: TextStyle(fontSize: 12)),
          for (final h in hist.reversed.take(10))
            Builder(builder: (context) {
              final card = (h['card'] as Map).cast<String, dynamic>();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${g.name((h['receiver'] as num).toInt())} 收到来自 ${g.name((h['sender'] as num).toInt())} 的【${_colorNames[card['color']]}】',
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }),
        ]),
      ),
    );
  }
}
