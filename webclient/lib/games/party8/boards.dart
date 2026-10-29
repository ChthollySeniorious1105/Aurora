import '../../widgets/common.dart';
import 'deepsea_board.dart';
import 'karuba_board.dart';
import 'qwixx_board.dart';

export 'deepsea_board.dart';
export 'karuba_board.dart';
export 'qwixx_board.dart';

final Map<String, BoardBuilder> party8Boards = {
  'qwixx': QwixxBoard.new,
  'deepsea': DeepSeaBoard.new,
  'karuba': KarubaBoard.new,
};
