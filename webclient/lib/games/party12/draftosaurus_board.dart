import 'package:aurora_shared/games/party12/draftosaurus.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class DraftosaurusBoard extends StatefulWidget {
  final GameContext g;
  const DraftosaurusBoard(this.g, {super.key});

  @override
  State<DraftosaurusBoard> createState() => _DraftosaurusBoardState();
}

class _DraftosaurusBoardState extends State<DraftosaurusBoard> {
  int? _selectedDino;
  int? _viewedSeat;

  static const List<(String, String, Color)> _dinoMeta = [
    ('霸王龙', '🦖', Color(0xFFD32F2F)),
    ('三角龙', '🦕', Color(0xFF1976D2)),
    ('剑龙', '🐊', Color(0xFF388E3C)),
    ('腕龙', '🦒', Color(0xFFFBC02D)),
    ('棘龙', '🦎', Color(0xFF8E24AA)),
    ('副栉龙', '🐉', Color(0xFFE64A19)),
  ];

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final v = g.view;
    final cs = Theme.of(context).colorScheme;

    final round = (v['round'] as int?) ?? 1;
    final turn = (v['turn'] as int?) ?? 1;
    final rollerSeat = (v['rollerSeat'] as int?) ?? 0;
    final constraint = (v['constraint'] as int?) ?? 0;
    final constraintName = (v['constraintName'] as String?) ?? '';
    final waiting = (v['waitingFor'] as List?)?.cast<int>() ?? const <int>[];
    final isMyTurn = g.seat >= 0 && waiting.contains(g.seat);

    final hand = (v['hand'] as List? ?? const []).cast<int>();
    final myPick = v['myPick'] as Map<String, dynamic>?;
    final picked = (v['picked'] as List? ?? const []).cast<bool>();
    final scores = (v['scores'] as List? ?? const []).cast<int>();
    final breakdowns = (v['breakdowns'] as List? ?? const []).cast<Map<String, dynamic>>();

    final pensAll = [
      for (final pSeat in (v['pens'] as List? ?? const []))
        [
          for (final pen in (pSeat as List)) (pen as List).cast<int>(),
        ],
    ];
    final riverAll = [
      for (final rSeat in (v['river'] as List? ?? const []))
        (rSeat as List).cast<int>(),
    ];

    final activeDino = (_selectedDino != null && hand.contains(_selectedDino))
        ? _selectedDino
        : (hand.isNotEmpty ? hand.first : null);

    final inspectSeat = (_viewedSeat != null && _viewedSeat! >= 0 && _viewedSeat! < g.players)
        ? _viewedSeat!
        : (g.seat >= 0 ? g.seat : 0);

    String statusText;
    if (g.over) {
      statusText = '恐龙岛选秀结束！2 轮共 12 只恐龙全部入园！';
    } else if (isMyTurn) {
      statusText = g.seat == rollerSeat
          ? '第$round/2轮 · 第$turn/6回合：你是投骰人（无视【$constraintName】限制），请选恐龙入园'
          : '第$round/2轮 · 第$turn/6回合：放置骰【$constraintName】——请选恐龙放入合规围栏或河流';
    } else {
      statusText = '第$round/2轮 · 第$turn/6回合：放置骰【$constraintName】，等待其他园长选秀…';
    }

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
                    StatusBar(statusText, highlight: isMyTurn),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade800,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '🎲 投骰人:${g.name(rollerSeat)} · $constraintName',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
                      _buildPlayerTabs(cs, scores, picked, rollerSeat, inspectSeat),
                      const SizedBox(height: 6),
                      if (g.seat >= 0 && !g.over) ...[
                        _buildHandBar(cs, hand, activeDino, myPick, isMyTurn),
                        const SizedBox(height: 6),
                      ],
                      _buildParkMap(
                        cs: cs,
                        seat: inspectSeat,
                        pens: inspectSeat < pensAll.length ? pensAll[inspectSeat] : List.generate(6, (_) => <int>[]),
                        river: inspectSeat < riverAll.length ? riverAll[inspectSeat] : const <int>[],
                        breakdown: inspectSeat < breakdowns.length ? breakdowns[inspectSeat] : const {},
                        activeDino: activeDino,
                        canPlaceHere: isMyTurn && inspectSeat == g.seat && activeDino != null,
                        rollerSeat: rollerSeat,
                        constraint: constraint,
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
                '恐龙岛选秀结束！',
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    for (var s = 0; s < g.players; s++)
                      Text(
                        '${g.name(s)}: ${s < scores.length ? scores[s] : 0} 分',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlayerTabs(
    ColorScheme cs,
    List<int> scores,
    List<bool> picked,
    int rollerSeat,
    int inspectSeat,
  ) {
    final g = widget.g;
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (var s = 0; s < g.players; s++)
          InkWell(
            onTap: () => setState(() => _viewedSeat = s),
            borderRadius: BorderRadius.circular(24),
            child: g.tag(
              s,
              active: s == inspectSeat,
              size: 28,
              sub: '⭐ ${s < scores.length ? scores[s] : 0}分 ${s == rollerSeat ? '🎲' : ''} ${s < picked.length && picked[s] ? '✅已选' : ''}',
            ),
          ),
      ],
    );
  }

  Widget _buildHandBar(
    ColorScheme cs,
    List<int> hand,
    int? activeDino,
    Map<String, dynamic>? myPick,
    bool isMyTurn,
  ) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMyTurn
                ? '第一步：点选 1 只手牌恐龙，再点击下方园区围栏或河流放置'
                : (myPick != null ? '本回合已选定恐龙，等待其他玩家…' : '当前手牌'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < hand.length; i++)
                _buildDinoChip(
                  dino: hand[i],
                  selected: activeDino == hand[i],
                  onTap: isMyTurn
                      ? () => setState(() {
                            _selectedDino = hand[i];
                            _viewedSeat = widget.g.seat;
                          })
                      : null,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDinoChip({
    required int dino,
    required bool selected,
    VoidCallback? onTap,
  }) {
    final d = dino.clamp(0, 5);
    final meta = _dinoMeta[d];
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? meta.$3 : meta.$3.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: meta.$3, width: selected ? 2.5 : 1.5),
        ),
        child: Text(
          '${meta.$2} ${meta.$1}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: selected ? Colors.white : meta.$3,
          ),
        ),
      ),
    );
  }

  bool _isPenLegalForMe({
    required List<int> currentPen,
    required int penIdx,
    required int dino,
    required int seat,
    required int rollerSeat,
    required int constraint,
  }) {
    if (!DraftosaurusGame.canPenAccept(currentPen, penIdx, dino)) return false;
    if (seat != rollerSeat && !DraftosaurusGame.satisfiesConstraint(currentPen, penIdx, constraint)) {
      return false;
    }
    return true;
  }

  Widget _buildParkMap({
    required ColorScheme cs,
    required int seat,
    required List<List<int>> pens,
    required List<int> river,
    required Map<String, dynamic> breakdown,
    required int? activeDino,
    required bool canPlaceHere,
    required int rollerSeat,
    required int constraint,
  }) {
    final g = widget.g;
    final penScores = (breakdown['penScores'] as List? ?? const []).cast<int>();
    final trexBonus = (breakdown['trexBonus'] as int?) ?? 0;
    final riverScore = (breakdown['riverScore'] as int?) ?? 0;
    final total = (breakdown['total'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${g.name(seat)} 的恐龙公园（总分: $total 分 · 霸王龙奖励: +$trexBonus · 河流: +$riverScore）',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var p = 0; p < kDraftosaurusPens.length; p++)
                _buildPenCard(
                  cs: cs,
                  penDef: kDraftosaurusPens[p],
                  dinos: p < pens.length ? pens[p] : const <int>[],
                  score: p < penScores.length ? penScores[p] : 0,
                  legal: canPlaceHere &&
                      _isPenLegalForMe(
                        currentPen: p < pens.length ? pens[p] : const <int>[],
                        penIdx: p,
                        dino: activeDino!,
                        seat: seat,
                        rollerSeat: rollerSeat,
                        constraint: constraint,
                      ),
                  onTap: canPlaceHere
                      ? () => g.act({'type': 'place', 'dino': activeDino, 'pen': p})
                      : null,
                ),
              _buildRiverCard(
                cs: cs,
                dinos: river,
                score: riverScore,
                legal: canPlaceHere,
                onTap: canPlaceHere
                    ? () => g.act({'type': 'place', 'dino': activeDino, 'pen': 6})
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPenCard({
    required ColorScheme cs,
    required PenDef penDef,
    required List<int> dinos,
    required int score,
    required bool legal,
    VoidCallback? onTap,
  }) {
    final isForest = penDef.zone == 0;
    final isLeft = penDef.side == 2;
    final zoneColor = isForest ? const Color(0xFF2E7D32) : const Color(0xFFF57F17);
    final hasTrex = dinos.contains(0);

    return InkWell(
      onTap: legal ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 215,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: legal ? zoneColor.withValues(alpha: 0.16) : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: legal ? zoneColor : cs.outline.withValues(alpha: 0.3),
            width: legal ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${penDef.name} ${hasTrex ? '🦖+1' : ''}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: zoneColor),
                  ),
                ),
                Text(
                  '$score分',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            Text(
              '${isForest ? '🌲森林区' : '🌾平原区'} · ${isLeft ? '🚻洗手间侧(左)' : '🍔餐厅侧(右)'}',
              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.7)),
            ),
            Text(
              penDef.ruleText,
              style: TextStyle(fontSize: 10, color: cs.onSurface.withValues(alpha: 0.8)),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (dinos.isEmpty)
                  Text(
                    legal ? '👉 点击放入此围栏' : '空围栏',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: legal ? FontWeight.bold : FontWeight.normal,
                      color: legal ? zoneColor : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                else
                  for (final d in dinos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _dinoMeta[d.clamp(0, 5)].$3,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_dinoMeta[d.clamp(0, 5)].$2}${_dinoMeta[d.clamp(0, 5)].$1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRiverCard({
    required ColorScheme cs,
    required List<int> dinos,
    required int score,
    required bool legal,
    VoidCallback? onTap,
  }) {
    const riverColor = Color(0xFF0277BD);
    return InkWell(
      onTap: legal ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 215,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: legal ? riverColor.withValues(alpha: 0.16) : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: legal ? riverColor : cs.outline.withValues(alpha: 0.3),
            width: legal ? 2.2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🌊 河流 (无视骰子限制)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: riverColor),
                ),
                Text(
                  '$score分',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
            const Text('每只恐龙固定 1 分（始终允许放入）', style: TextStyle(fontSize: 10)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                if (dinos.isEmpty)
                  Text(
                    legal ? '👉 点击放入河流 (+1分)' : '暂无恐龙',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: legal ? FontWeight.bold : FontWeight.normal,
                      color: legal ? riverColor : cs.onSurface.withValues(alpha: 0.5),
                    ),
                  )
                else
                  for (final d in dinos)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: _dinoMeta[d.clamp(0, 5)].$3,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${_dinoMeta[d.clamp(0, 5)].$2}${_dinoMeta[d.clamp(0, 5)].$1}',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
