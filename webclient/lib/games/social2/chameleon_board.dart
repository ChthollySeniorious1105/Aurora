import 'package:flutter/material.dart';

import '../../widgets/common.dart';

String _coord(int idx) => '${"ABCD"[(idx ~/ 4).clamp(0, 3)]}${(idx % 4) + 1}';

class ChameleonBoard extends StatefulWidget {
  final GameContext g;
  const ChameleonBoard(this.g, {super.key});
  @override
  State<ChameleonBoard> createState() => _ChameleonBoardState();
}

class _ChameleonBoardState extends State<ChameleonBoard> {
  final TextEditingController _ctrl = TextEditingController();

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;
  String get phase => (v['phase'] as String?) ?? 'clue';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submitClue() {
    final txt = _ctrl.text.trim();
    if (txt.isEmpty) return;
    g.act({'type': 'clue', 'text': txt});
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = g.seat;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final maxRounds = (v['maxRounds'] as num?)?.toInt() ?? 3;
    final topic = (v['topic'] as String?) ?? '';
    final words = (v['words'] as List?)?.cast<String>() ?? const <String>[];
    final turn = (v['turn'] as num?)?.toInt() ?? -1;
    final myRole = v['myRole'] as String?;
    final secretIndex = (v['secretIndex'] as num?)?.toInt() ?? -1;
    final secretCoord = v['secretCoord'] as String?;
    final secretWord = v['secretWord'] as String?;
    final chamSeat = (v['chameleonSeat'] as num?)?.toInt() ?? -1;
    final clues = (v['clues'] as List?)?.cast<Map>() ?? const <Map>[];
    final voted = (v['voted'] as List?)?.cast<bool>() ?? List.filled(g.players, false);
    final scores = [for (final e in (v['scores'] as List? ?? const [])) (e as num).toInt()];
    final readyNext = (v['readyNext'] as List?)?.cast<bool>() ?? List.filled(g.players, false);
    final lastRound = (v['lastRoundResult'] as Map?)?.cast<String, dynamic>();

    final clueBySeat = <int, String>{};
    for (final c in clues) {
      clueBySeat[(c['seat'] as num).toInt()] = '${c['text']}';
    }

    String status;
    var hl = false;
    switch (phase) {
      case 'clue':
        hl = me == turn;
        status = hl
            ? '第 $round/$maxRounds 轮【$topic】：轮到你给出一个线索词'
            : '第 $round/$maxRounds 轮【$topic】：等待 ${g.name(turn)} 给出线索';
        break;
      case 'vote':
        hl = me >= 0 && !voted[me];
        status = hl ? '全员发言完毕！请点击你怀疑是变色龙的玩家投票' : '等待其他玩家投票指认变色龙…';
        break;
      case 'guess':
        hl = me == chamSeat;
        status = hl
            ? '你被识破了！请在 4×4 题目卡上点击反猜本轮秘密词'
            : '变色龙 ${g.name(chamSeat)} 被抓获！等待其反猜秘密词…';
        break;
      case 'roundEnd':
        hl = me >= 0 && !readyNext[me];
        status = lastRound != null
            ? '第 ${lastRound['round']} 轮结算：${lastRound['outcome']}（秘密词：${lastRound['secretWord']}）'
            : '本轮结束，请点击继续';
        break;
      default:
        status = '${v['reason'] ?? '对局结束'}';
    }

    Widget buildRoleHeader() {
      if (myRole == null) return const SizedBox.shrink();
      final isCham = myRole == 'chameleon';
      final color = isCham ? Colors.deepOrange : Colors.teal;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Text(
          isCham
              ? '🦎 你的身份：【变色龙】——你不晓得秘密词，请根据他人线索伪装！'
              : '🔎 你的身份：【知情者】——本轮秘密词：$secretCoord「$secretWord」',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
        ),
      );
    }

    Widget buildTopicBoard(bool compact) {
      final canGuess = phase == 'guess' && me == chamSeat && !g.over;
      final guessIdx = (lastRound?['guessIndex'] as num?)?.toInt() ?? -1;

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: EdgeInsets.all(compact ? 6 : 10),
        decoration: BoxDecoration(
          color: cs.surface.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.4)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.grid_view_rounded, size: 16, color: cs.primary),
            const SizedBox(width: 6),
            Text('主题卡：【$topic】', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary, fontSize: 14)),
            const SizedBox(width: 10),
            Text('第 $round / $maxRounds 轮', style: const TextStyle(fontSize: 12)),
          ]),
          const SizedBox(height: 6),
          for (var r = 0; r < 4; r++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                for (var col = 0; col < 4; col++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final idx = r * 4 + col;
                      final w = idx < words.length ? words[idx] : '';
                      final isSecret = idx == secretIndex;
                      final isGuessed = (phase == 'roundEnd' || phase == 'over') && idx == guessIdx;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: canGuess ? () => g.act({'type': 'guess', 'index': idx}) : null,
                          child: Container(
                            height: compact ? 32 : 42,
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isSecret
                                  ? Colors.teal.withValues(alpha: 0.32)
                                  : (canGuess
                                      ? cs.primaryContainer.withValues(alpha: 0.4)
                                      : cs.surfaceContainerHighest.withValues(alpha: 0.55)),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSecret
                                    ? Colors.tealAccent.shade700
                                    : (isGuessed
                                        ? Colors.deepOrange
                                        : (canGuess ? cs.primary : cs.outline.withValues(alpha: 0.25))),
                                width: isSecret || isGuessed ? 2 : 1,
                              ),
                            ),
                            child: Row(children: [
                              Text(
                                _coord(idx),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface.withValues(alpha: 0.55),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    w,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSecret ? FontWeight.bold : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),
              ]),
            ),
        ]),
      );
    }

    Widget seatTile(int s) {
      final isTurn = phase == 'clue' && s == turn;
      final isCham = s == chamSeat;
      final canVote = phase == 'vote' && me >= 0 && !voted[me] && !g.over;
      final myVote = (v['myVote'] as num?)?.toInt();
      final clue = clueBySeat[s];
      final sc = s < scores.length ? scores[s] : 0;

      return InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: canVote ? () => g.act({'type': 'vote', 'target': s}) : null,
        child: Container(
          width: 155,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: canVote
                ? cs.primaryContainer.withValues(alpha: 0.35)
                : cs.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isTurn
                  ? Colors.amber
                  : (myVote == s ? cs.primary : cs.outline.withValues(alpha: 0.3)),
              width: isTurn || myVote == s ? 2 : 1,
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            g.tag(s, active: isTurn && !g.over, sub: '得分 $sc', size: 28),
            const SizedBox(height: 4),
            if (clue != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('线索：「$clue」', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else
              const Text('尚未给线索', style: TextStyle(fontSize: 11, color: Colors.grey)),
            const SizedBox(height: 3),
            Wrap(spacing: 4, runSpacing: 2, alignment: WrapAlignment.center, children: [
              if (isCham) _badge('🦎变色龙', Colors.deepOrange),
              if (phase == 'vote') _badge(voted[s] ? '已投票' : '思考中', voted[s] ? Colors.green : Colors.grey),
              if (canVote) _badge('点击投票', cs.primary),
            ]),
          ]),
        ),
      );
    }

    final actions = <Widget>[];
    if (!g.over && me >= 0) {
      if (phase == 'clue' && me == turn) {
        actions.add(
          SizedBox(
            width: 180,
            height: 36,
            child: TextField(
              controller: _ctrl,
              onSubmitted: (_) => _submitClue(),
              decoration: const InputDecoration(
                hintText: '输入一个线索词…',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(),
              ),
            ),
          ),
        );
        actions.add(
          FilledButton.icon(
            onPressed: _submitClue,
            icon: const Icon(Icons.send, size: 16),
            label: const Text('提交线索'),
          ),
        );
      } else if (phase == 'roundEnd' && !readyNext[me]) {
        actions.add(
          FilledButton.icon(
            onPressed: () => g.act({'type': 'next'}),
            icon: const Icon(Icons.play_arrow, size: 16),
            label: const Text('继续下一轮'),
          ),
        );
      }
    }

    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 860;
      final short = c.maxHeight < 460;

      if (short) {
        // Phone landscape (e.g. 800x390): side-by-side topic grid and seats
        return Column(children: [
          const SizedBox(height: 2),
          StatusBar(status, highlight: hl),
          Expanded(
            child: Row(children: [
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(4),
                  child: Column(children: [
                    buildRoleHeader(),
                    buildTopicBoard(true),
                  ]),
                ),
              ),
              Expanded(
                flex: 5,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(4),
                  child: Column(children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [for (final s in g.seatsFromMe()) seatTile(s)],
                    ),
                    if (actions.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center, children: actions),
                    ],
                    if (g.over || phase == 'over') ResultBanner(status),
                  ]),
                ),
              ),
            ]),
          ),
        ]);
      }

      final mainCol = Column(children: [
        const SizedBox(height: 4),
        StatusBar(status, highlight: hl),
        const SizedBox(height: 4),
        buildRoleHeader(),
        const SizedBox(height: 4),
        buildTopicBoard(false),
        const SizedBox(height: 6),
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
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ),
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
    final hist = (v['roundHistory'] as List?)?.cast<Map>() ?? const [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('历轮战报', style: TextStyle(fontWeight: FontWeight.bold)),
          if (hist.isEmpty) const Text('暂无记录', style: TextStyle(fontSize: 12)),
          for (final h in hist.reversed)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '第${h['round']}轮【${h['topic']}】秘密词：${h['secretWord']}\n'
                '变色龙：${g.name((h['chameleon'] as num).toInt())} —— ${h['outcome']}',
                style: const TextStyle(fontSize: 12),
              ),
            ),
        ]),
      ),
    );
  }
}
