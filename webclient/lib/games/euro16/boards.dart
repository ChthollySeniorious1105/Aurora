import '../../widgets/common.dart';
import 'aquatica_board.dart';
import 'furnace_board.dart';
import 'meadow_board.dart';
import 'trekking_history_board.dart';

final Map<String, BoardBuilder> euro16Boards = {
  'meadow': (g) => MeadowBoard(g),
  'furnace': (g) => FurnaceBoard(g),
  'trekking_history': (g) => TrekkingHistoryBoard(g),
  'aquatica': (g) => AquaticaBoard(g),
};
