import '../../widgets/common.dart';
import 'math24_board.dart';
import 'mjconnect_board.dart';
import 'tankbattle_board.dart';

/// 算术24点 / 坦克大战 / 连连看竞速
final Map<String, BoardBuilder> arcade3Boards = {
  'math24': (g) => Math24Board(g),
  'tankbattle': (g) => TankBattleBoard(g),
  'mjconnect': (g) => MjConnectBoard(g),
};
