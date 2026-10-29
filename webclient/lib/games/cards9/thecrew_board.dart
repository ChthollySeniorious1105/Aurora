import 'package:aurora_shared/games/cards9/thecrew.dart';
import 'package:flutter/material.dart';

import '../../widgets/common.dart';

class TheCrewBoard extends StatefulWidget {
  final GameContext g;
  const TheCrewBoard(this.g, {super.key});

  @override
  State<TheCrewBoard> createState() => _TheCrewBoardState();
}

class _TheCrewBoardState extends State<TheCrewBoard> {
  bool _radioMode = false;

  GameContext get g => widget.g;
  Map<String, dynamic> get v => g.view;

  List<int> _intList(Object? raw) =>
      raw is List ? [for (final x in raw) (x as num).toInt()] : const [];

  List<String> _strList(Object? raw) =>
      raw is List ? [for (final x in raw) '$x'] : const [];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mission = (v['mission'] as num?)?.toInt() ?? 1;
    final maxMissions = (v['maxMissions'] as num?)?.toInt() ?? 3;
    final hull = (v['hull'] as num?)?.toInt() ?? 3;
    final maxHull = (v['maxHull'] as num?)?.toInt() ?? 3;
    final commander = (v['commander'] as num?)?.toInt() ?? 0;
    final turn = (v['turn'] as num?)?.toInt() ?? 0;
    final phase = (v['phase'] as String?) ?? 'draft_tasks';
    final campaignWon = v['campaignWon'] == true;

    final myHand = _strList(v['myHand']);
    final handCounts = _intList(v['handCounts']);
    final tricksWon = _intList(v['tricksWon']);
    final commRaw = v['communicated'];
    final communicated = commRaw is List
        ? [for (final b in commRaw) b == true]
        : List<bool>.filled(g.players, false);

    final radioRaw = v['radio'] as List? ?? const [];
    final radio = [
      for (var i = 0; i < g.players; i++)
        (i < radioRaw.length && radioRaw[i] is Map)
            ? (radioRaw[i] as Map).cast<String, dynamic>()
            : null,
    ];

    final tasksRaw = v['tasks'] as List? ?? const [];
    final tasks = [
      for (final t in tasksRaw)
        if (t is Map) t.cast<String, dynamic>(),
    ];

    final trickRaw = v['currentTrick'] as List? ?? const [];
    final currentTrick = [
      for (final e in trickRaw)
        if (e is Map) e.cast<String, dynamic>(),
    ];

    final isMyTurn = !g.spectator && !g.over && turn == g.seat;
    final canCommunicate = !g.spectator &&
        !g.over &&
        phase == 'play' &&
        currentTrick.isEmpty &&
        g.seat >= 0 &&
        g.seat < communicated.length &&
        !communicated[g.seat];

    if (!canCommunicate && _radioMode) {
      _radioMode = false;
    }

    // Legal cards in hand
    Set<String> legalHandCards = {};
    if (_radioMode && canCommunicate) {
      for (final c in myHand) {
        if (checkCrewCommunication(c, myHand) != null) {
          legalHandCards.add(c);
        }
      }
    } else if (isMyTurn && phase == 'play') {
      if (currentTrick.isEmpty) {
        legalHandCards = myHand.toSet();
      } else {
        final ledSuit = crewSuitIndex('${currentTrick.first['card'] ?? ''}');
        final sameSuit = myHand.where((c) => crewSuitIndex(c) == ledSuit).toSet();
        legalHandCards = sameSuit.isNotEmpty ? sameSuit : myHand.toSet();
      }
    }

    String statusText;
    if (g.over) {
      statusText = campaignWon ? '星际探险队完成全部任务！' : '飞船护盾耗尽，任务失败';
    } else if (phase == 'draft_tasks') {
      statusText = isMyTurn
          ? '轮到你认领任务：请点击中央未分配的任务牌'
          : '等待 ${g.name(turn)} 认领任务…';
    } else if (_radioMode) {
      statusText = '无线电通信模式：请点击手牌中某彩色花色最大、最小或唯一的一张牌';
    } else {
      statusText = isMyTurn ? '轮到你出牌' : '轮到 ${g.name(turn)} 出牌';
    }

    return Container(
      color: g.table,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final compact = h < 460 || w < 440;
          final cardW = compact ? 42.0 : 52.0;

          return Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(compact ? 6 : 10),
                child: Column(
                  children: [
                    // Header: Mission & Hull & StatusBar
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.rocket_launch, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '第 $mission/$maxMissions 关 · 护盾 $hull/$maxHull',
                                style: TextStyle(
                                  fontSize: compact ? 11 : 12,
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: StatusBar(statusText, highlight: isMyTurn),
                        ),
                        if (canCommunicate) ...[
                          const SizedBox(width: 6),
                          FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: const Size(0, 32),
                            ),
                            onPressed: () => setState(() => _radioMode = !_radioMode),
                            icon: Icon(
                              _radioMode ? Icons.close : Icons.sensors,
                              size: 15,
                            ),
                            label: Text(
                              _radioMode ? '取消通信' : '无线电通信',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // Crew Members Row (scrollable horizontal strip)
                    SizedBox(
                      height: compact ? 84 : 104,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final s in g.seatsFromMe())
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: _buildCrewMemberBox(
                                  context,
                                  seat: s,
                                  isCommander: s == commander,
                                  active: !g.over && turn == s,
                                  handCount: s < handCounts.length ? handCounts[s] : 0,
                                  tricks: s < tricksWon.length ? tricksWon[s] : 0,
                                  radioInfo: s < radio.length ? radio[s] : null,
                                  memberTasks: [
                                    for (final t in tasks)
                                      if (t['owner'] == s) t,
                                  ],
                                  compact: compact,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // Center Mission / Trick Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(compact ? 6 : 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.cyanAccent.withValues(alpha: 0.3)),
                        ),
                        child: Center(
                          child: SingleChildScrollView(
                            child: phase == 'draft_tasks'
                                ? _buildTaskDraftPanel(tasks, isMyTurn, cardW, compact)
                                : _buildTrickTablePanel(currentTrick, tasks, cardW, compact),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: compact ? 4 : 8),

                    // My Hand
                    if (!g.spectator && myHand.isNotEmpty)
                      SizedBox(
                        height: cardW * 1.52,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (final c in myHand)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 3),
                                  child: CrewCardWidget(
                                    code: c,
                                    width: cardW,
                                    highlight: legalHandCards.contains(c),
                                    dim: (isMyTurn && phase == 'play' && !legalHandCards.contains(c)) ||
                                        (_radioMode && !legalHandCards.contains(c)),
                                    onTap: legalHandCards.contains(c)
                                        ? () {
                                            if (_radioMode) {
                                              setState(() => _radioMode = false);
                                              g.act({'type': 'communicate', 'card': c});
                                            } else {
                                              g.act({'type': 'play', 'card': c});
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (g.over)
                Center(
                  child: ResultBanner(
                    campaignWon ? '星际探险大获全胜！' : '星际探险任务失败',
                    child: Text(
                      '达成关卡: $mission / $maxMissions · 剩余飞船护盾: $hull',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCrewMemberBox(
    BuildContext context, {
    required int seat,
    required bool isCommander,
    required bool active,
    required int handCount,
    required int tricks,
    required Map<String, dynamic>? radioInfo,
    required List<Map<String, dynamic>> memberTasks,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.all(compact ? 5 : 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? Colors.cyanAccent : Colors.white24,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              g.tag(
                seat,
                active: active,
                size: compact ? 26 : 30,
                sub: '手牌 $handCount · 赢 $tricks 墩',
              ),
              if (isCommander) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade800,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '指挥官',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (radioInfo != null) ...[
                _miniRadioBadge(radioInfo),
                const SizedBox(width: 4),
              ],
              for (final t in memberTasks)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _miniTaskBadge(t),
                ),
              if (memberTasks.isEmpty && radioInfo == null)
                const Text(
                  '暂无任务',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniRadioBadge(Map<String, dynamic> radioInfo) {
    final c = '${radioInfo['card'] ?? ''}';
    final pos = '${radioInfo['position'] ?? ''}';
    final posLabel = pos == 'highest'
        ? '最大'
        : (pos == 'lowest' ? '最小' : '唯一');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.teal.shade800,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '📡$c($posLabel)',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _miniTaskBadge(Map<String, dynamic> t) {
    final c = '${t['card'] ?? ''}';
    final tok = t['token'];
    final done = t['completed'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: done ? Colors.green.shade800 : Colors.indigo.shade800,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: done ? Colors.greenAccent : Colors.amberAccent),
      ),
      child: Text(
        '${done ? '✓' : '🎯'}$c${tok != null ? '[$tok]' : ''}',
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTaskDraftPanel(
    List<Map<String, dynamic>> tasks,
    bool isMyTurn,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '本关星际任务（点击未认领的任务牌进行认领）',
          style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < tasks.length; i++)
              _buildDraftTaskItem(i, tasks[i], isMyTurn, cardW),
          ],
        ),
      ],
    );
  }

  Widget _buildDraftTaskItem(
    int idx,
    Map<String, dynamic> task,
    bool isMyTurn,
    double cardW,
  ) {
    final card = '${task['card'] ?? 'B1'}';
    final tok = task['token'] as String?;
    final owner = task['owner'] as int?;
    final unassigned = owner == null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CrewCardWidget(
          code: card,
          width: cardW,
          tokenBadge: tok,
          highlight: isMyTurn && unassigned,
          dim: !unassigned,
          onTap: isMyTurn && unassigned
              ? () => g.act({'type': 'take_task', 'index': idx})
              : null,
        ),
        const SizedBox(height: 3),
        Text(
          unassigned ? '待认领' : g.name(owner),
          style: TextStyle(
            color: unassigned ? Colors.amberAccent : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTrickTablePanel(
    List<Map<String, dynamic>> currentTrick,
    List<Map<String, dynamic>> tasks,
    double cardW,
    bool compact,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Active Tasks Summary
        Wrap(
          spacing: 6,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            for (final t in tasks)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t['completed'] == true
                      ? Colors.green.shade900.withValues(alpha: 0.8)
                      : Colors.blueGrey.shade900.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: t['completed'] == true ? Colors.greenAccent : Colors.amber,
                  ),
                ),
                child: Text(
                  '${t['completed'] == true ? '✓' : '🎯'} ${t['card']}'
                  '${t['token'] != null ? ' [${t['token']}]' : ''} → ${g.name((t['owner'] as num?)?.toInt() ?? 0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (currentTrick.isEmpty)
          const Text(
            '等待首引出牌…',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final e in currentTrick)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CrewCardWidget(
                      code: '${e['card'] ?? 'B1'}',
                      width: cardW,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      g.name((e['seat'] as num?)?.toInt() ?? 0),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
    );
  }
}

class CrewCardWidget extends StatelessWidget {
  final String code;
  final double width;
  final String? tokenBadge;
  final bool highlight;
  final bool dim;
  final VoidCallback? onTap;

  const CrewCardWidget({
    super.key,
    required this.code,
    this.width = 48,
    this.tokenBadge,
    this.highlight = false,
    this.dim = false,
    this.onTap,
  });

  static const List<Color> _suitColors = [
    Color(0xFF1E88E5), // 0: 蓝 Blue
    Color(0xFF43A047), // 1: 绿 Green
    Color(0xFFD81B60), // 2: 粉 Pink
    Color(0xFFFBC02D), // 3: 黄 Yellow
    Color(0xFF37474F), // 4: 火箭 Rocket (Trump)
  ];

  @override
  Widget build(BuildContext context) {
    final sIdx = crewSuitIndex(code).clamp(0, 4);
    final r = crewRank(code);
    final h = width * 1.42;
    final bg = _suitColors[sIdx];
    final isRocket = sIdx == 4;

    Widget card = Container(
      width: width,
      height: h,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(
          color: highlight ? Colors.cyanAccent : Colors.white70,
          width: highlight ? 2.4 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: highlight
                ? Colors.cyanAccent.withValues(alpha: 0.45)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: highlight ? 6 : 3,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                kCrewSuitNames[sIdx],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                isRocket ? Icons.rocket : Icons.public,
                color: isRocket ? Colors.orangeAccent : Colors.white,
                size: 18,
              ),
              Text(
                '$r',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (tokenBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '顺位 $tokenBadge',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (dim) card = Opacity(opacity: 0.45, child: card);
    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}
