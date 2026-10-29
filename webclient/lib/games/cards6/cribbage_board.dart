import 'package:flutter/material.dart';

import '../../widgets/common.dart';
import '../../widgets/pieces.dart';

int _asInt(Object? v, [int d = 0]) => v is num ? v.toInt() : d;
List<int> _asInts(Object? v) => [for (final x in (v as List? ?? const [])) (x as num).toInt()];
List<String> _asStrs(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];

int _cribCardVal(String c) {
  if (c.length < 2) return 0;
  final r = c.substring(0, c.length - 1);
  if (r == 'A') return 1;
  if (r == 'T' || r == 'J' || r == 'Q' || r == 'K') return 10;
  return int.tryParse(r) ?? 0;
}

Widget _pill(String text, Color color, {double fontSize = 12}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1))],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: fontSize,
          fontFamilyFallback: kFontFallback,
        ),
      ),
    );

class CribbageBoard extends StatefulWidget {
  final GameContext g;
  const CribbageBoard(this.g, {super.key});

  @override
  State<CribbageBoard> createState() => _CribbageBoardState();
}

class _CribbageBoardState extends State<CribbageBoard> {
  final Set<String> _selectedDiscard = {};
  String _handSig = '';

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  @override
  Widget build(BuildContext context) {
    final hand = _asStrs(v['hand']);
    final phase = '${v['phase'] ?? 'discard'}';
    final sig = '${hand.join(',')}|$phase';
    if (sig != _handSig) {
      _handSig = sig;
      _selectedDiscard.removeWhere((c) => !hand.contains(c));
      if (phase != 'discard') _selectedDiscard.clear();
    }

    final me = g.seat;
    final bottomSeat = me >= 0 ? me : 0;
    final topSeat = 1 - bottomSeat;
    final dealer = _asInt(v['dealer'], 0);
    final turn = _asInt(v['turn'], -1);
    final targetScore = _asInt(v['targetScore'], 61);
    final scores = _asInts(v['scores']);
    final prevScores = _asInts(v['prevScores']);
    final discarded = (v['discarded'] as List?)?.map((e) => e == true).toList() ?? [false, false];
    final handCounts = _asInts(v['handCounts']);
    final count = _asInt(v['count'], 0);
    final canPlay = v['canPlay'] == true;

    final myTurn = me >= 0 &&
        !g.over &&
        ((phase == 'discard' && !discarded[me]) ||
            (phase == 'pegging' && turn == me) ||
            (phase == 'show'));

    String statusText;
    if (phase == 'discard') {
      if (me >= 0 && !discarded[me]) {
        statusText = '请选择 2 张手牌放入 ${g.name(dealer)} 的底牌（Crib）';
      } else {
        statusText = '等待对手选择 2 张底牌放入 Crib…';
      }
    } else if (phase == 'pegging') {
      if (me >= 0 && turn == me) {
        statusText = canPlay ? '轮到你出牌（当前累计 $count / 31 点）' : '无牌可出（超过 31 点），请点击“喊 Go”';
      } else {
        statusText = '等待 ${g.name(turn)} 出牌（当前累计 $count / 31 点）';
      }
    } else if (phase == 'show') {
      statusText = '本手亮牌计分完成，点击“下一手”继续';
    } else {
      statusText = '比赛结束';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final compact = h < 480;
        final cardW = (w / (w > h ? 15 : 8.5)).clamp(28.0, compact ? 42.0 : 58.0);

        return Stack(fit: StackFit.expand, children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Column(children: [
              // Header + Pegging Track
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _pill('克里比奇 · 第 ${_asInt(v['handNo'], 1)} 手', Colors.brown.shade800),
                  const SizedBox(width: 6),
                  _pill('目标 $targetScore 分', Colors.indigo.shade700),
                  const SizedBox(width: 6),
                  _pill('庄家: ${g.name(dealer)} (含Crib)', Colors.amber.shade900),
                ]),
              ),
              const SizedBox(height: 4),
              _buildPeggingBoard(scores, prevScores, targetScore, w - 16, compact),
              const SizedBox(height: 4),
              // Opponent row
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  g.tag(
                    topSeat,
                    active: !g.over &&
                        ((phase == 'discard' && !discarded[topSeat]) || (phase == 'pegging' && turn == topSeat)),
                    size: compact ? 26 : 32,
                    sub: '${scores.length > topSeat ? scores[topSeat] : 0} / $targetScore 分'
                        '${dealer == topSeat ? ' · 庄家' : ' · 闲家'}',
                  ),
                  const SizedBox(width: 10),
                  _buildBacks(handCounts.length > topSeat ? handCounts[topSeat] : 0, cardW * 0.65),
                ]),
              ),
              const SizedBox(height: 4),
              // Center felt area
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(compact ? 6 : 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: phase == 'show' || (phase == 'over' && v['showSummary'] != null)
                            ? _buildShowPanel(cardW)
                            : _buildTableArea(cardW, phase, dealer, count),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Status & controls
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  StatusBar(statusText, highlight: myTurn),
                  if (me >= 0 && !g.over && phase == 'discard' && !discarded[me]) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _selectedDiscard.length == 2
                          ? () {
                              final chosen = _selectedDiscard.toList();
                              setState(() => _selectedDiscard.clear());
                              g.act({'type': 'discard', 'cards': chosen});
                            }
                          : null,
                      icon: const Icon(Icons.archive, size: 16),
                      label: Text('放入 Crib (${_selectedDiscard.length}/2)'),
                    ),
                  ],
                  if (me >= 0 && !g.over && phase == 'pegging' && turn == me && !canPlay) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade800),
                      onPressed: () => g.act({'type': 'go'}),
                      icon: const Icon(Icons.skip_next, size: 16),
                      label: const Text('喊 Go (无牌≤31)'),
                    ),
                  ],
                  if (me >= 0 && !g.over && phase == 'show') ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: ((v['ready'] as List?)?[me] == true) ? null : () => g.act({'type': 'next_hand'}),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: Text(((v['ready'] as List?)?[me] == true) ? '等待对手…' : '下一手'),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 4),
              // Bottom player tag + hand
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  g.tag(
                    bottomSeat,
                    active: myTurn,
                    size: compact ? 26 : 30,
                    sub: '${scores.length > bottomSeat ? scores[bottomSeat] : 0} / $targetScore 分'
                        '${dealer == bottomSeat ? ' · 庄家' : ' · 闲家'}',
                  ),
                ]),
              ),
              if (me >= 0 && hand.isNotEmpty) ...[
                const SizedBox(height: 4),
                SizedBox(
                  height: cardW * 1.4 + (compact ? 6 : 12),
                  width: w - 24,
                  child: Center(
                    child: OverlapRow(
                      itemWidth: cardW,
                      children: [
                        for (final c in hand)
                          _buildMyCard(c, cardW, phase, me, turn, count, discarded[me]),
                      ],
                    ),
                  ),
                ),
              ],
            ]),
          ),
          if (g.over)
            Center(
              child: SingleChildScrollView(
                child: _buildOverBanner(scores, targetScore),
              ),
            ),
        ]);
      }),
    );
  }

  Widget _buildMyCard(String c, double cardW, String phase, int me, int turn, int count, bool hasDiscarded) {
    if (phase == 'discard' && !hasDiscarded) {
      final sel = _selectedDiscard.contains(c);
      return PlayingCard(
        c,
        width: cardW,
        selected: sel,
        onTap: () {
          setState(() {
            if (sel) {
              _selectedDiscard.remove(c);
            } else if (_selectedDiscard.length < 2) {
              _selectedDiscard.add(c);
            }
          });
        },
      );
    }
    if (phase == 'pegging' && turn == me && !g.over) {
      final fits = count + _cribCardVal(c) <= 31;
      return PlayingCard(
        c,
        width: cardW,
        dim: !fits,
        onTap: fits ? () => g.act({'type': 'play', 'card': c}) : null,
      );
    }
    return PlayingCard(c, width: cardW);
  }

  Widget _buildPeggingBoard(List<int> scores, List<int> prevScores, int target, double maxW, bool compact) {
    return Container(
      width: maxW.clamp(200.0, 720.0),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF5D4037), Color(0xFF3E2723)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade700.withValues(alpha: 0.6), width: 1.5),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var s = 0; s < 2; s++) ...[
          if (s == 1) const SizedBox(height: 3),
          Row(children: [
            SizedBox(
              width: 72,
              child: Text(
                g.name(s),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: compact ? 8 : 10,
                  child: Stack(children: [
                    Container(color: Colors.black38),
                    FractionallySizedBox(
                      widthFactor: ((scores.length > s ? scores[s] : 0) / target).clamp(0.0, 1.0),
                      child: Container(
                        color: s == 0 ? Colors.amberAccent.shade700 : Colors.lightBlueAccent.shade400,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 68,
              child: Text(
                '${scores.length > s ? scores[s] : 0}/$target'
                '${prevScores.length > s && prevScores[s] < (scores.length > s ? scores[s] : 0) ? ' (+${scores[s] - prevScores[s]})' : ''}',
                textAlign: TextAlign.right,
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ]),
        ],
      ]),
    );
  }

  Widget _buildBacks(int n, double w) {
    if (n <= 0) return const SizedBox();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < n.clamp(0, 6); i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.5),
          child: PlayingCard('back', width: w, faceDown: true),
        ),
    ]);
  }

  Widget _buildTableArea(double cardW, String phase, int dealer, int count) {
    final starter = '${v['starter'] ?? ''}';
    final cribCount = _asInt(v['cribCount'], 0);
    final seq = _asStrs(v['seq']);
    final lastEvent = '${v['lastEvent'] ?? ''}';
    final log = _asStrs(v['log']);

    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Starter card
        Column(mainAxisSize: MainAxisSize.min, children: [
          PlayingCard(
            starter.isEmpty ? 'back' : starter,
            width: cardW,
            faceDown: starter.isEmpty,
          ),
          const SizedBox(height: 4),
          _pill(starter.isEmpty ? '待切起手牌' : '起手牌 $starter', Colors.deepPurple.shade700, fontSize: 11),
        ]),
        const SizedBox(width: 18),
        // Crib pile
        Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: cardW + 12,
            height: cardW * 1.4,
            child: Stack(alignment: Alignment.center, children: [
              if (cribCount == 0)
                Container(
                  width: cardW,
                  height: cardW * 1.4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white38, width: 1.5),
                  ),
                  child: const Center(child: Text('Crib', style: TextStyle(color: Colors.white54, fontSize: 12))),
                )
              else
                for (var i = 0; i < cribCount.clamp(1, 4); i++)
                  Positioned(
                    left: i * 3.0,
                    child: PlayingCard('back', width: cardW, faceDown: true),
                  ),
            ]),
          ),
          const SizedBox(height: 4),
          _pill('${g.name(dealer)} 的 Crib ($cribCount/4)', Colors.brown.shade700, fontSize: 11),
        ]),
        if (phase == 'pegging') ...[
          const SizedBox(width: 22),
          // Running count display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade900.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.amberAccent, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('当前累计点数', style: TextStyle(color: Colors.white70, fontSize: 11)),
              Text(
                '$count / 31',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
              ),
            ]),
          ),
        ],
      ]),
      if (seq.isNotEmpty) ...[
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('本轮计数牌序：', style: TextStyle(color: Colors.white70, fontSize: 12)),
          for (final c in seq)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: PlayingCard(c, width: cardW * 0.82),
            ),
        ]),
      ],
      if (lastEvent.isNotEmpty) ...[
        const SizedBox(height: 8),
        _pill(lastEvent, Colors.teal.shade800, fontSize: 12),
      ],
      if (log.isNotEmpty) ...[
        const SizedBox(height: 4),
        for (final line in (log.length > 2 ? log.sublist(log.length - 2) : log))
          Text(line, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    ]);
  }

  Widget _buildShowPanel(double cardW) {
    final s = v['showSummary'] as Map?;
    if (s == null) return const SizedBox();
    final starter = '${s['starter'] ?? ''}';
    final nd = _asInt(s['nonDealer'], 0);
    final dl = _asInt(s['dealer'], 1);
    final cw = (cardW * 0.78).clamp(26.0, 44.0);

    Widget row(String label, List<String> cards, int pts, List<String> details) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          for (final c in cards)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: PlayingCard(c, width: cw),
            ),
          const SizedBox(width: 8),
          _pill('+$pts 分', pts > 0 ? Colors.green.shade700 : Colors.blueGrey, fontSize: 12),
          const SizedBox(width: 6),
          Text(details.join(' · '), style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
        ]),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        _pill('亮牌计分 (The Show)', Colors.amber.shade900, fontSize: 13),
        const SizedBox(width: 10),
        const Text('公共起手牌：', style: TextStyle(color: Colors.white70, fontSize: 12)),
        PlayingCard(starter, width: cw * 0.9),
      ]),
      const SizedBox(height: 6),
      row('1. 闲家 ${g.name(nd)}', _asStrs(s['ndCards']), _asInt(s['ndPts']), _asStrs(s['ndDetails'])),
      row('2. 庄家 ${g.name(dl)}', _asStrs(s['dlCards']), _asInt(s['dlPts']), _asStrs(s['dlDetails'])),
      row('3. 庄家 Crib', _asStrs(s['cribCards']), _asInt(s['cribPts']), _asStrs(s['cribDetails'])),
    ]);
  }

  Widget _buildOverBanner(List<int> scores, int targetScore) {
    final winner = _asInt(v['winner'], -1);
    final title = v['resigned'] == true
        ? '${g.name(winner)} 获胜（对手认输）'
        : (winner >= 0 ? '🏆 ${g.name(winner)} 率先达到 $targetScore 分获胜！' : '比赛结束');
    return ResultBanner(
      title,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Wrap(spacing: 10, runSpacing: 6, children: [
          for (var s = 0; s < 2; s++)
            _pill('${g.name(s)}: ${scores.length > s ? scores[s] : 0} / $targetScore 分',
                s == winner ? Colors.green.shade700 : Colors.blueGrey.shade700),
        ]),
      ]),
    );
  }
}
