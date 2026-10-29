import '../../widgets/common.dart';
import 'alhambra_board.dart';
import 'dominion_board.dart';
import 'sheriff_board.dart';

/// 皇舆争霸 / 阿尔罕布拉宫 / 诺丁汉警长
final Map<String, BoardBuilder> euro7Boards = {
  'dominion': (g) => DominionBoard(g),
  'alhambra': (g) => AlhambraBoard(g),
  'sheriff': (g) => SheriffBoard(g),
};
