import '../../widgets/common.dart';
import 'binairo_board.dart';
import 'skyscrapers_board.dart';
import 'suguru_board.dart';

/// 摩天楼可见数竞速 / 黑白平衡二进制竞速 / 数块邻格互斥竞速
final Map<String, BoardBuilder> arcade11Boards = {
  'skyscrapers': (g) => SkyscrapersBoard(g),
  'binairo': (g) => BinairoBoard(g),
  'suguru': (g) => SuguruBoard(g),
};
