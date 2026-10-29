import '../../widgets/common.dart';
import 'coltexpress_board.dart';
import 'heimlich_board.dart';
import 'scotlandyard_board.dart';

export 'coltexpress_board.dart';
export 'heimlich_board.dart';
export 'scotlandyard_board.dart';

final Map<String, BoardBuilder> party10Boards = {
  'scotlandyard': ScotlandYardBoard.new,
  'coltexpress': ColtExpressBoard.new,
  'heimlich': HeimlichBoard.new,
};
