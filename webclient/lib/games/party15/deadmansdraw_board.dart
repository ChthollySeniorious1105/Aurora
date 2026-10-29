import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const List<String> _suitLabels = [
  '⚓ 船锚',
  '🪝 铁钩',
  '💣 火炮',
  '🗡️ 弯刀',
  '🔮 预言球',
  '🗺️ 藏宝图',
  '🧜‍♀️ 人鱼',
  '🗝️ 钥匙',
  '📦 宝箱',
  '🦑 海怪',
];

const List<Color> _suitColors = [
  Color(0xFF455A64),
  Color(0xFF6D4C41),
  Color(0xFFC62828),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFEF6C00),
  Color(0xFF00838F),
  Color(0xFFF9A825),
  Color(0xFF5D4037),
  Color(0xFF283593),
];

class DeadMansDrawBoard extends StatefulWidget {
  final GameContext g;
  const DeadMansDrawBoard(this.g, {super.key});

  @override
  State<DeadMansDrawBoard> createState() => _DeadMansDrawBoardState();
}

class _DeadMansDrawBoardState extends State<DeadMansDrawBoard> {
  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = v['phase'] as String? ?? 'turn';
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final discardCount = (v['discardCount'] as num?)?.toInt() ?? 0;
    final turnArea = (v['turnArea'] as List?) ?? const [];
    final bank = (v['bank'] as List?) ?? const [];
    final oraclePeek = v['oraclePeek'] as Map?;
    final mapChoices = (v['mapChoices'] as List?) ?? const [];
    final krakenMustDraw = (v['krakenMustDraw'] as num?)?.toInt() ?? 0;
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
                          ? '亡者宝藏 — 终局结算'
                          : (isMyTurn
                              ? '轮到你行动（${_phaseLabel(phase)}）'
                              : '等待 ${g.name(turn)}（${_phaseLabel(phase)}）'),
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
                  // Deck & Turn Area Panel
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: cs.surface.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _infoChip(cs, '🃏 摸牌堆: $deckCount 张'),
                            _infoChip(cs, '🗑️ 弃牌堆: $discardCount 张'),
                            if (krakenMustDraw > 0)
                              _infoChip(cs, '🦑 海怪强制再抽: $krakenMustDraw 张', warn: true),
                            if (oraclePeek != null)
                              _infoChip(
                                cs,
                                '🔮 预言球窥视下张: ${_suitLabels[(oraclePeek['suit'] as num).toInt()]} (${oraclePeek['val']})',
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '当前回合出牌区（重复花色即爆牌，⚓船锚可保护此前的牌）：',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary),
                        ),
                        const SizedBox(height: 6),
                        if (turnArea.isEmpty)
                          Text('暂无卡牌，点击“抽牌探索”翻开第一张海盗牌！',
                              style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)))
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var i = 0; i < turnArea.length; i++)
                                _cardWidget(
                                  (turnArea[i]['suit'] as num).toInt(),
                                  (turnArea[i]['val'] as num).toInt(),
                                  sub: '#${i + 1}',
                                ),
                            ],
                          ),
                        if (isMyTurn) ...[
                          const SizedBox(height: 10),
                          _buildActionControls(g, cs, phase, turnArea, mapChoices, krakenMustDraw, deckCount),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // All Players' Banks
                  for (final s in g.seatsFromMe())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildPlayerBank(
                        g,
                        cs,
                        s,
                        s < bank.length ? (bank[s] as List) : const [],
                        s < scores.length ? scores[s] : 0,
                        turn == s && !g.over,
                        isMyTurn,
                        phase,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (g.over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(
                lastEvent.isNotEmpty ? lastEvent : '游戏结束',
              ),
            ),
        ],
      ),
    );
  }

  String _phaseLabel(String phase) {
    switch (phase) {
      case 'hook':
        return '🪝 铁钩：选择自己宝库一门花色打出';
      case 'cannon':
        return '💣 火炮：选择对手宝库一门花色摧毁';
      case 'sword':
        return '🗡️ 弯刀：选择对手宝库一门花色掠夺';
      case 'map':
        return '🗺️ 藏宝图：3选1打入回合区';
      default:
        return '抽牌或见好就收';
    }
  }

  Widget _infoChip(ColorScheme cs, String text, {bool warn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: warn ? Colors.red.withValues(alpha: 0.2) : cs.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: warn ? Colors.redAccent : cs.onSecondaryContainer,
        ),
      ),
    );
  }

  Widget _cardWidget(int suit, int val, {String? sub, VoidCallback? onTap}) {
    final color = _suitColors[suit.clamp(0, 9)];
    final label = _suitLabels[suit.clamp(0, 9)];
    final w = Container(
      width: 64,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white54, width: 1.2),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$val',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            if (sub != null)
              Text(
                sub,
                style: const TextStyle(fontSize: 10, color: Colors.white70),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return w;
    return InkWell(onTap: onTap, child: w);
  }

  Widget _buildActionControls(
    GameContext g,
    ColorScheme cs,
    String phase,
    List turnArea,
    List mapChoices,
    int krakenMustDraw,
    int deckCount,
  ) {
    if (phase == 'map') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🗺️ 请从弃牌堆翻出的卡牌中选择 1 张加入当前回合区：',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < mapChoices.length; i++)
                _cardWidget(
                  (mapChoices[i]['suit'] as num).toInt(),
                  (mapChoices[i]['val'] as num).toInt(),
                  sub: '点击选取',
                  onTap: () => g.act({'type': 'map', 'index': i}),
                ),
              OutlinedButton(
                onPressed: () => g.act({'type': 'map', 'index': -1}),
                child: const Text('放弃选取'),
              ),
            ],
          ),
        ],
      );
    }

    if (phase == 'hook') {
      return const Text('🪝 请在下方你自己的宝库中点击一门非空花色，将其最高牌打入当前回合区！',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    }
    if (phase == 'cannon') {
      return const Text('💣 请在下方任意对手的宝库中点击一门非空花色，摧毁其最高牌！',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    }
    if (phase == 'sword') {
      return const Text('🗡️ 请在下方任意对手的宝库中点击一门非空花色，掠夺其最高牌进入回合区！',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold));
    }

    final canBank = turnArea.isNotEmpty && (krakenMustDraw <= 0 || deckCount == 0);
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: () => g.act({'type': 'draw'}),
          icon: const Icon(Icons.style, size: 16),
          label: const Text('抽牌探索 (Draw)'),
        ),
        FilledButton.tonalIcon(
          onPressed: canBank ? () => g.act({'type': 'bank'}) : null,
          icon: const Icon(Icons.savings, size: 16),
          label: Text('见好就收 (Bank ${turnArea.length} 张)'),
        ),
      ],
    );
  }

  Widget _buildPlayerBank(
    GameContext g,
    ColorScheme cs,
    int s,
    List suitPiles,
    int score,
    bool active,
    bool isMyTurn,
    String phase,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? cs.primary : cs.outline.withValues(alpha: 0.25),
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          g.tag(s, active: active, sub: '宝库总分: $score 分'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var suit = 0; suit < 10; suit++)
                _buildSuitPileTile(
                  g,
                  cs,
                  s,
                  suit,
                  suit < suitPiles.length ? (suitPiles[suit] as List) : const [],
                  isMyTurn,
                  phase,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSuitPileTile(
    GameContext g,
    ColorScheme cs,
    int ownerSeat,
    int suit,
    List pile,
    bool isMyTurn,
    String phase,
  ) {
    final hasCard = pile.isNotEmpty;
    final topVal = hasCard ? (pile.last as num).toInt() : 0;
    VoidCallback? onTap;
    if (isMyTurn && hasCard) {
      if (phase == 'hook' && ownerSeat == g.seat) {
        onTap = () => g.act({'type': 'hook', 'suit': suit});
      } else if (phase == 'cannon' && ownerSeat != g.seat) {
        onTap = () => g.act({'type': 'cannon', 'target': ownerSeat, 'suit': suit});
      } else if (phase == 'sword' && ownerSeat != g.seat) {
        onTap = () => g.act({'type': 'sword', 'target': ownerSeat, 'suit': suit});
      }
    }

    final tile = Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: hasCard ? _suitColors[suit].withValues(alpha: 0.88) : cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: onTap != null ? Colors.amberAccent : Colors.white24,
          width: onTap != null ? 2 : 1,
        ),
      ),
      child: Text(
        hasCard ? '${_suitLabels[suit]}: $topVal (×${pile.length})' : '${_suitLabels[suit]}: -',
        style: TextStyle(
          fontSize: 11,
          fontWeight: hasCard ? FontWeight.bold : FontWeight.normal,
          color: hasCard ? Colors.white : cs.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
    if (onTap == null) return tile;
    return InkWell(onTap: onTap, child: tile);
  }
}
