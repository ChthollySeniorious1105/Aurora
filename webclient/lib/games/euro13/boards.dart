import '../../widgets/common.dart';
import 'akropolis_board.dart';
import 'flamecraft_board.dart';
import 'kingdom_builder_board.dart';
import 'tokaido_board.dart';

final Map<String, BoardBuilder> euro13Boards = {
  'akropolis': (g) => AkropolisBoard(g),
  'flamecraft': (g) => FlamecraftBoard(g),
  'tokaido': (g) => TokaidoBoard(g),
  'kingdom_builder': (g) => KingdomBuilderBoard(g),
};
