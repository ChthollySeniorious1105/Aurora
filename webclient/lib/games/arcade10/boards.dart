import '../../widgets/common.dart';
import 'futoshiki_board.dart';
import 'kenken_board.dart';
import 'masyu_board.dart';

/// 不等号数独竞速 / 黑白珍珠回路竞速 / 算术笼数独竞速
final Map<String, BoardBuilder> arcade10Boards = {
  'futoshiki': (g) => FutoshikiBoard(g),
  'masyu': (g) => MasyuBoard(g),
  'kenken': (g) => KenKenBoard(g),
};
