import '../../widgets/common.dart';
import 'deception_board.dart';
import 'draftosaurus_board.dart';
import 'modernart_board.dart';
import 'survive_board.dart';

final Map<String, BoardBuilder> party12Boards = {
  'deception': DeceptionBoard.new,
  'modernart': ModernArtBoard.new,
  'survive': SurviveBoard.new,
  'draftosaurus': DraftosaurusBoard.new,
};
