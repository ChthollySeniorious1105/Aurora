import 'dart:math';

import 'package:flutter/material.dart';

import '../../widgets/common.dart';

const Map<String, String> _toolLabel = {
  'pickaxe': '镐',
  'lantern': '灯',
  'cart': '车',
};

class SaboteurBoard extends StatefulWidget {
  final GameContext g;
  const SaboteurBoard(this.g, {super.key});

  @override
  State<SaboteurBoard> createState() => _SaboteurBoardState();
}

class _SaboteurBoardState extends State<SaboteurBoard> {
  int? _selectedCardIdx;

  GameContext get g => widget.g;

  @override
  void didUpdateWidget(covariant SaboteurBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.g.view['turn'] != g.view['turn'] ||
        oldWidget.g.view['phase'] != g.view['phase'] ||
        oldWidget.g.view['round'] != g.view['round']) {
      _selectedCardIdx = null;
    }
  }

  bool _canPlacePathLocally(
    Map<(int, int), Map<String, dynamic>> grid,
    Set<String> reachableSet,
    int r,
    int c,
    Map<String, dynamic> card,
  ) {
    if (r < 0 || r >= 5 || c < 0 || c >= 9) return false;
    if (r == 2 && c == 0) return false;
    if (c == 8 && (r == 0 || r == 2 || r == 4)) return false;
    if (grid.containsKey((r, c))) return false;
    if (card['kind'] != 'path') return false;

    final myEdges = ((card['edges'] as List?) ?? const []).map((e) => '$e').toSet();
    if (myEdges.isEmpty) return false;

    const dirs = {
      'N': (-1, 0, 'S'),
      'S': (1, 0, 'N'),
      'E': (0, 1, 'W'),
      'W': (0, -1, 'E'),
    };

    var connected = false;
    for (final entry in dirs.entries) {
      final d = entry.key;
      final (dr, dc, opp) = entry.value;
      final nr = r + dr;
      final nc = c + dc;
      final neighbor = grid[(nr, nc)];
      if (neighbor == null) continue;
      final nEdges = ((neighbor['edges'] as List?) ?? const []).map((e) => '$e').toSet();
      final myOpen = myEdges.contains(d);
      final nOpen = nEdges.contains(opp);
      if (myOpen != nOpen) return false;
      if (myOpen && nOpen && reachableSet.contains('$nr,$nc')) {
        connected = true;
      }
    }
    return connected;
  }

  @override
  Widget build(BuildContext context) {
    final v = g.view;
    final cs = Theme.of(context).colorScheme;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final round = (v['round'] as num?)?.toInt() ?? 1;
    final totalRounds = (v['totalRounds'] as num?)?.toInt() ?? 3;
    final phase = '${v['phase'] ?? 'play'}';
    final deckCount = (v['deckCount'] as num?)?.toInt() ?? 0;
    final over = v['over'] == true || g.over;
    final myRole = v['myRole'] as String?;
    final roles = (v['roles'] as List?)?.map((e) => '$e').toList();
    final gold = (v['gold'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final handCounts = (v['handCounts'] as List?)?.map((e) => (e as num).toInt()).toList() ?? List.filled(g.players, 0);
    final hand = (v['hand'] as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? const <Map<String, dynamic>>[];
    final brokenList = (v['brokenTools'] as List?)
            ?.map((e) => (e as List).map((x) => '$x').toList())
            .toList() ??
        List.generate(g.players, (_) => <String>[]);
    final reachableSet = ((v['reachableCells'] as List?) ?? const []).map((e) => '$e').toSet();
    final goals = (v['goals'] as List?)?.map((e) => (e as Map).cast<String, dynamic>()).toList() ?? const [];
    final logs = (v['log'] as List?)?.map((e) => '$e').toList() ?? const <String>[];
    final acked = ((v['ackedNextRound'] as List?) ?? const []).map((e) => (e as num).toInt()).toSet();

    final gridRaw = (v['grid'] as Map?) ?? const {};
    final grid = <(int, int), Map<String, dynamic>>{};
    for (final e in gridRaw.entries) {
      final parts = '${e.key}'.split(',');
      if (parts.length == 2) {
        final r = int.tryParse(parts[0]);
        final c = int.tryParse(parts[1]);
        if (r != null && c != null && e.value is Map) {
          grid[(r, c)] = (e.value as Map).cast<String, dynamic>();
        }
      }
    }

    final isMyTurn = !over && phase == 'play' && g.seat == turn;
    final myBroken = g.seat >= 0 && g.seat < brokenList.length ? brokenList[g.seat] : const <String>[];
    final selectedCard = (_selectedCardIdx != null && _selectedCardIdx! < hand.length)
        ? hand[_selectedCardIdx!]
        : null;

    final roleBadge = myRole == 'saboteur'
        ? '【破坏者】'
        : (myRole == 'digger' ? '【淘金矮人】' : '');

    String statusText;
    if (over) {
      final best = gold.isEmpty ? 0 : gold.reduce(max);
      final winners = [for (var s = 0; s < g.players; s++) if (gold[s] == best) g.name(s)].join('、');
      statusText = '全场结束：$winners 以 $best 金块获胜！';
    } else if (phase == 'roundEnd') {
      final summary = v['roundSummary'] as Map?;
      final winTeam = summary?['winnerTeam'] == 'digger' ? '淘金矮人获胜' : '破坏者获胜';
      statusText = '第 $round/$totalRounds 局结算：$winTeam！请点击继续下一局';
    } else if (isMyTurn) {
      statusText = '$roleBadge 轮到你：选一张手牌放置矿道、使用行动或弃牌（牌堆余 $deckCount）';
    } else {
      statusText = '$roleBadge 第$round/$totalRounds局 · 等待 ${g.name(turn)} 行动（牌堆余 $deckCount）';
    }

    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxHeight < 460 || constraints.maxWidth < 460;

      return Stack(
        children: [
          Container(
            color: g.table,
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Column(
              children: [
                // Top bar: Status + Players
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusBar(statusText, highlight: isMyTurn),
                    for (var s = 0; s < g.players; s++)
                      Builder(builder: (context) {
                        final bTools = brokenList[s];
                        final bStr = bTools.isEmpty
                            ? '工具完好'
                            : '损坏:${bTools.map((t) => _toolLabel[t] ?? t).join("/")}';
                        final rLabel = roles != null && s < roles.length
                            ? (roles[s] == 'saboteur' ? '·破坏者' : '·淘金')
                            : '';
                        return g.tag(
                          s,
                          active: !over && phase == 'play' && turn == s,
                          size: compact ? 24 : 30,
                          sub: '💰${gold[s]} · 牌${handCounts[s]} · $bStr$rLabel',
                        );
                      }),
                  ],
                ),
                SizedBox(height: compact ? 3 : 6),

                // Center 9x5 Mine Grid
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1B18).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outline.withValues(alpha: 0.3)),
                    ),
                    padding: EdgeInsets.all(compact ? 4 : 8),
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var r = 0; r < 5; r++)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var c = 0; c < 9; c++)
                                  Padding(
                                    padding: const EdgeInsets.all(2.5),
                                    child: _buildMineCell(
                                      r: r,
                                      c: c,
                                      grid: grid,
                                      reachableSet: reachableSet,
                                      goals: goals,
                                      selectedCard: selectedCard,
                                      isMyTurn: isMyTurn,
                                      myBroken: myBroken,
                                      cs: cs,
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),

                // Bottom hand & action controls
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6 : 10,
                    vertical: compact ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isMyTurn ? cs.primary : cs.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!over && phase == 'roundEnd')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: FilledButton.icon(
                            onPressed: (g.seat >= 0 && !acked.contains(g.seat))
                                ? () => g.act({'type': 'next_round'})
                                : null,
                            icon: const Icon(Icons.play_arrow, size: 16),
                            label: Text(
                              g.seat >= 0 && acked.contains(g.seat)
                                  ? '已准备，等待其他玩家…'
                                  : '继续下一局',
                            ),
                          ),
                        )
                      else
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var i = 0; i < hand.length; i++) ...[
                                if (i > 0) const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: isMyTurn
                                      ? () => setState(() {
                                            _selectedCardIdx = _selectedCardIdx == i ? null : i;
                                          })
                                      : null,
                                  child: _buildHandCard(
                                    hand[i],
                                    selected: _selectedCardIdx == i,
                                    compact: compact,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (isMyTurn && selectedCard != null && _selectedCardIdx != null) ...[
                        const SizedBox(height: 4),
                        _buildSelectedCardActions(
                          selectedIdx: _selectedCardIdx!,
                          card: selectedCard,
                          brokenList: brokenList,
                          compact: compact,
                        ),
                      ],
                      if (logs.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          logs.last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 10 : 12,
                            color: cs.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (over)
            Align(
              alignment: Alignment.center,
              child: ResultBanner(statusText),
            ),
        ],
      );
    });
  }

  Widget _buildSelectedCardActions({
    required int selectedIdx,
    required Map<String, dynamic> card,
    required List<List<String>> brokenList,
    required bool compact,
  }) {
    final kind = '${card['kind']}';
    final actKind = '${card['action'] ?? ''}';
    final buttons = <Widget>[];

    if (kind == 'action' && actKind == 'break') {
      final tool = '${card['tool']}';
      for (var s = 0; s < g.players; s++) {
        if (s == g.seat) continue;
        if (!brokenList[s].contains(tool)) {
          buttons.add(
            FilledButton.tonal(
              style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
              onPressed: () {
                g.act({'type': 'action', 'index': selectedIdx, 'target': s});
                setState(() => _selectedCardIdx = null);
              },
              child: Text('破坏 ${g.name(s)} 的${_toolLabel[tool] ?? tool}', style: const TextStyle(fontSize: 12)),
            ),
          );
        }
      }
    } else if (kind == 'action' && actKind == 'repair') {
      final tools = ((card['tools'] as List?) ?? const []).map((e) => '$e').toList();
      for (var s = 0; s < g.players; s++) {
        for (final t in tools) {
          if (brokenList[s].contains(t)) {
            buttons.add(
              FilledButton.tonal(
                style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                onPressed: () {
                  g.act({'type': 'action', 'index': selectedIdx, 'target': s, 'tool': t});
                  setState(() => _selectedCardIdx = null);
                },
                child: Text('修复 ${g.name(s)} 的${_toolLabel[t] ?? t}', style: const TextStyle(fontSize: 12)),
              ),
            );
          }
        }
      }
    } else if (kind == 'action' && actKind == 'map') {
      for (var gIdx = 0; gIdx < 3; gIdx++) {
        buttons.add(
          FilledButton.tonal(
            style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
            onPressed: () {
              g.act({'type': 'action', 'index': selectedIdx, 'goalIndex': gIdx});
              setState(() => _selectedCardIdx = null);
            },
            child: Text('探查终点 ${gIdx + 1}', style: const TextStyle(fontSize: 12)),
          ),
        );
      }
    }

    buttons.add(
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
        onPressed: () {
          g.act({'type': 'discard', 'index': selectedIdx});
          setState(() => _selectedCardIdx = null);
        },
        icon: const Icon(Icons.delete_outline, size: 14),
        label: const Text('弃牌摸牌', style: TextStyle(fontSize: 12)),
      ),
    );

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: buttons,
    );
  }

  Widget _buildMineCell({
    required int r,
    required int c,
    required Map<(int, int), Map<String, dynamic>> grid,
    required Set<String> reachableSet,
    required List<Map<String, dynamic>> goals,
    required Map<String, dynamic>? selectedCard,
    required bool isMyTurn,
    required List<String> myBroken,
    required ColorScheme cs,
  }) {
    const double cellW = 54;
    const double cellH = 44;

    // Goal cell at c == 8 and r in {0, 2, 4}
    if (c == 8 && (r == 0 || r == 2 || r == 4)) {
      final gIdx = r ~/ 2;
      final goalInfo = gIdx < goals.length ? goals[gIdx] : const <String, dynamic>{};
      final revealed = goalInfo['revealed'] == true;
      final knownType = goalInfo['knownType'] as String?;
      final canPeek = isMyTurn &&
          selectedCard != null &&
          selectedCard['kind'] == 'action' &&
          selectedCard['action'] == 'map';

      return GestureDetector(
        onTap: canPeek
            ? () {
                g.act({'type': 'action', 'index': _selectedCardIdx, 'goalIndex': gIdx});
                setState(() => _selectedCardIdx = null);
              }
            : null,
        child: Container(
          width: cellW,
          height: cellH,
          decoration: BoxDecoration(
            color: knownType == 'gold'
                ? const Color(0xFF5D4037)
                : const Color(0xFF37474F),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: canPeek
                  ? Colors.amberAccent
                  : (knownType == 'gold' ? Colors.amber : Colors.white30),
              width: canPeek ? 2 : 1.2,
            ),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      knownType == 'gold'
                          ? '💰金矿'
                          : (knownType == 'stone' ? '🪨石头' : '❓终点${gIdx + 1}'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: knownType == 'gold' ? Colors.amberAccent : Colors.white,
                      ),
                    ),
                    if (!revealed && knownType != null)
                      const Text(
                        '(已探知)',
                        style: TextStyle(fontSize: 9, color: Colors.amberAccent),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final existing = grid[(r, c)];
    if (existing != null) {
      final isStart = existing['kind'] == 'start';
      final canRockfall = isMyTurn &&
          !isStart &&
          existing['kind'] == 'path' &&
          selectedCard != null &&
          selectedCard['kind'] == 'action' &&
          selectedCard['action'] == 'rockfall';

      return GestureDetector(
        onTap: canRockfall
            ? () {
                g.act({'type': 'action', 'index': _selectedCardIdx, 'r': r, 'c': c});
                setState(() => _selectedCardIdx = null);
              }
            : null,
        child: Container(
          width: cellW,
          height: cellH,
          decoration: BoxDecoration(
            color: const Color(0xFF2D2620),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: canRockfall
                  ? Colors.redAccent
                  : (isStart ? Colors.amber : Colors.white24),
              width: (canRockfall || isStart) ? 2.0 : 1.0,
            ),
          ),
          child: CustomPaint(
            painter: _TunnelCardPainter(
              edges: ((existing['edges'] as List?) ?? const []).map((e) => '$e').toSet(),
              deadEnd: existing['deadEnd'] == true,
              isStart: isStart,
              reachable: reachableSet.contains('$r,$c'),
            ),
          ),
        ),
      );
    }

    // Empty cell
    final canPlace = isMyTurn &&
        myBroken.isEmpty &&
        selectedCard != null &&
        selectedCard['kind'] == 'path' &&
        _canPlacePathLocally(grid, reachableSet, r, c, selectedCard);

    return GestureDetector(
      onTap: canPlace
          ? () {
              g.act({
                'type': 'place_path',
                'index': _selectedCardIdx,
                'r': r,
                'c': c,
              });
              setState(() => _selectedCardIdx = null);
            }
          : null,
      child: Container(
        width: cellW,
        height: cellH,
        decoration: BoxDecoration(
          color: canPlace
              ? Colors.amber.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: canPlace ? Colors.amberAccent : Colors.white12,
            width: canPlace ? 1.8 : 1.0,
          ),
        ),
        child: canPlace
            ? const Center(child: Icon(Icons.add, size: 16, color: Colors.amberAccent))
            : null,
      ),
    );
  }

  Widget _buildHandCard(Map<String, dynamic> card, {required bool selected, required bool compact}) {
    final w = compact ? 46.0 : 56.0;
    final h = compact ? 54.0 : 66.0;
    final kind = '${card['kind']}';

    Widget inner;
    if (kind == 'path') {
      final edges = ((card['edges'] as List?) ?? const []).map((e) => '$e').toSet();
      final deadEnd = card['deadEnd'] == true;
      inner = CustomPaint(
        painter: _TunnelCardPainter(
          edges: edges,
          deadEnd: deadEnd,
          isStart: false,
          reachable: true,
        ),
        size: Size(w, h),
      );
    } else {
      final act = '${card['action']}';
      String title;
      Color badgeColor;
      if (act == 'break') {
        final t = '${card['tool']}';
        title = '破坏\n${_toolLabel[t] ?? t}';
        badgeColor = Colors.redAccent;
      } else if (act == 'repair') {
        final tools = ((card['tools'] as List?) ?? const []).map((t) => _toolLabel['$t'] ?? '$t').join('/');
        title = '修复\n$tools';
        badgeColor = Colors.greenAccent.shade700;
      } else if (act == 'rockfall') {
        title = '落石\n塌方';
        badgeColor = Colors.orangeAccent.shade700;
      } else {
        title = '藏宝图\n探路';
        badgeColor = Colors.lightBlueAccent.shade700;
      }
      inner = Container(
        color: badgeColor.withValues(alpha: 0.22),
        padding: const EdgeInsets.all(3),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: w,
      height: h,
      transform: Matrix4.translationValues(0, selected ? -5 : 0, 0),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2620),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: selected ? Colors.amberAccent : Colors.white30,
          width: selected ? 2.2 : 1.0,
        ),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 3, offset: Offset(1, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: inner,
      ),
    );
  }
}

class _TunnelCardPainter extends CustomPainter {
  final Set<String> edges;
  final bool deadEnd;
  final bool isStart;
  final bool reachable;

  _TunnelCardPainter({
    required this.edges,
    required this.deadEnd,
    required this.isStart,
    required this.reachable,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final pathWidth = min(size.width, size.height) * 0.34;

    final tunnelPaint = Paint()
      ..color = reachable ? const Color(0xFFD7CCC8) : const Color(0xFF8D6E63)
      ..strokeWidth = pathWidth
      ..strokeCap = StrokeCap.butt;

    for (final d in edges) {
      Offset end;
      switch (d) {
        case 'N':
          end = Offset(cx, 0);
          break;
        case 'S':
          end = Offset(cx, size.height);
          break;
        case 'E':
          end = Offset(size.width, cy);
          break;
        case 'W':
          end = Offset(0, cy);
          break;
        default:
          continue;
      }
      final mid = deadEnd
          ? Offset(cx + (end.dx - cx) * 0.45, cy + (end.dy - cy) * 0.45)
          : Offset(cx, cy);
      canvas.drawLine(end, mid, tunnelPaint);
    }

    if (!deadEnd) {
      canvas.drawCircle(Offset(cx, cy), pathWidth * 0.52, tunnelPaint);
    } else {
      final blockPaint = Paint()..color = Colors.redAccent.shade200;
      canvas.drawCircle(Offset(cx, cy), pathWidth * 0.38, blockPaint);
    }

    if (isStart) {
      final startPaint = Paint()..color = Colors.amber.shade700;
      canvas.drawCircle(Offset(cx, cy), pathWidth * 0.48, startPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TunnelCardPainter oldDelegate) => true;
}
