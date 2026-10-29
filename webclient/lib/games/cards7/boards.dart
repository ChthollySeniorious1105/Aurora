import '../../widgets/common.dart';
import 'arboretum_board.dart';
import 'briscola_board.dart';
import 'euchre_board.dart';

/// 尤克牌 / 布里斯科拉 / 植物园
final Map<String, BoardBuilder> cards7Boards = {
  'euchre': (g) => EuchreBoard(g),
  'briscola': (g) => BriscolaBoard(g),
  'arboretum': (g) => ArboretumBoard(g),
};
