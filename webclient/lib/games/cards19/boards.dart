import '../../widgets/common.dart';
import 'linko_board.dart';
import 'mus_board.dart';
import 'tressette_board.dart';

final Map<String, BoardBuilder> cards19Boards = {
  'mus': MusBoard.new,
  'tressette': TressetteBoard.new,
  'linko': LinkoBoard.new,
};
