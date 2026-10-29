import '../../widgets/common.dart';
import 'oriflamme_board.dart';
import 'pickomino_board.dart';
import 'transamerica_board.dart';
import 'winners_circle_board.dart';

export 'oriflamme_board.dart';
export 'pickomino_board.dart';
export 'transamerica_board.dart';
export 'winners_circle_board.dart';

final Map<String, BoardBuilder> party19Boards = {
  'winners_circle': WinnersCircleBoard.new,
  'transamerica': TransAmericaBoard.new,
  'oriflamme': OriflammeBoard.new,
  'pickomino': PickominoBoard.new,
};
