import '../../widgets/common.dart';
import 'all_creatures_board.dart';
import 'forest_shuffle_board.dart';
import 'marrakech_board.dart';
import 'railroad_ink_board.dart';

final Map<String, BoardBuilder> euro18Boards = {
  'marrakech': (g) => MarrakechBoard(g),
  'forest_shuffle': (g) => ForestShuffleBoard(g),
  'railroad_ink': (g) => RailroadInkBoard(g),
  'all_creatures': (g) => AllCreaturesBoard(g),
};
