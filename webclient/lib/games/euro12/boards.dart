import '../../widgets/common.dart';
import 'barenpark_board.dart';
import 'canvas_board.dart';
import 'nova_luna_board.dart';
import 'tiny_towns_board.dart';

final Map<String, BoardBuilder> euro12Boards = {
  'barenpark': (g) => BarenparkBoard(g),
  'nova_luna': (g) => NovaLunaBoard(g),
  'tiny_towns': (g) => TinyTownsBoard(g),
  'canvas': (g) => CanvasBoard(g),
};
