import '../../widgets/common.dart';
import 'golf_cards_board.dart';
import 'hanamikoji_board.dart';
import 'jass_board.dart';

final Map<String, BoardBuilder> cards14Boards = {
  'jass': JassBoard.new,
  'golf_cards': GolfCardsBoard.new,
  'hanamikoji': HanamikojiBoard.new,
};
