import '../../widgets/common.dart';
import 'harmonies_board.dart';
import 'living_forest_board.dart';
import 'next_station_london_board.dart';
import 'project_l_board.dart';

final Map<String, BoardBuilder> euro15Boards = {
  'harmonies': (g) => HarmoniesBoard(g),
  'next_station_london': (g) => NextStationLondonBoard(g),
  'living_forest': (g) => LivingForestBoard(g),
  'project_l': (g) => ProjectLBoard(g),
};
