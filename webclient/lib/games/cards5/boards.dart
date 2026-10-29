import '../../widgets/common.dart';
import 'gwent_board.dart';
import 'hongshi_board.dart';
import 'sanguosha_board.dart';

/// 红十 / 三国杀 / 昆特牌
final Map<String, BoardBuilder> cards5Boards = {
  'hongshi': (g) => HongshiBoard(g),
  'sanguosha': (g) => SanguoshaBoard(g),
  'gwent': (g) => GwentBoard(g),
};
