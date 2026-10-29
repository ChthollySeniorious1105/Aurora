import '../../widgets/common.dart';
import 'cacao_board.dart';
import 'imhotep_board.dart';
import 'pointsalad_board.dart';

/// 点数沙拉 / 可可亚 / 埃及建造师
final Map<String, BoardBuilder> euro6Boards = {
  'pointsalad': (g) => PointSaladBoard(g),
  'cacao': (g) => CacaoBoard(g),
  'imhotep': (g) => ImhotepBoard(g),
};
