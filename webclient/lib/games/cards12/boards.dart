import '../../widgets/common.dart';
import 'skullking_board.dart';
import 'tarot_board.dart';
import 'tichu_board.dart';

/// 地主牌 Tichu / 法国塔罗牌 Jeu de Tarot / 骷髅王 Skull King
final Map<String, BoardBuilder> cards12Boards = {
  'tichu': (g) => TichuBoard(g),
  'tarot': (g) => TarotBoard(g),
  'skullking': (g) => SkullKingBoard(g),
};
