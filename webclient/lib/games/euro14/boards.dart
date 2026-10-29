import '../../widgets/common.dart';
import 'dorfromantik_board.dart';
import 'isle_of_cats_board.dart';
import 'my_city_board.dart';
import 'planet_unknown_board.dart';

final Map<String, BoardBuilder> euro14Boards = {
  'isle_of_cats': (g) => IsleOfCatsBoard(g),
  'dorfromantik': (g) => DorfromantikBoard(g),
  'my_city': (g) => MyCityBoard(g),
  'planet_unknown': (g) => PlanetUnknownBoard(g),
};
