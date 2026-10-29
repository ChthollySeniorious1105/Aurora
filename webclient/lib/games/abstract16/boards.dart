import '../../widgets/common.dart';
import 'catchup_board.dart';
import 'cephalopod_board.dart';
import 'tumbleweed_board.dart';

/// 风滚草视线棋 Tumbleweed / 追赶大集群棋 Catchup / 章鱼骰子吞并棋 Cephalopod
final Map<String, BoardBuilder> abstract16Boards = {
  'tumbleweed': (g) => TumbleweedBoard(g),
  'catchup': (g) => CatchupBoard(g),
  'cephalopod': (g) => CephalopodBoard(g),
};
