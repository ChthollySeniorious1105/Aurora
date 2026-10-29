import '../../widgets/common.dart';
import 'punct_board.dart';
import 'surakarta_board.dart';
import 'yavalath_board.dart';

/// 彭克特桥接棋 PÜNCT / 苏拉卡尔塔环轨棋 Surakarta / 亚瓦拉特棋 Yavalath
final Map<String, BoardBuilder> abstract13Boards = {
  'punct': (g) => PunctBoard(g),
  'surakarta': (g) => SurakartaBoard(g),
  'yavalath': (g) => YavalathBoard(g),
};
