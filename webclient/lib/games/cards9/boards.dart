import '../../widgets/common.dart';
import 'koikoi_board.dart';
import 'piquet_board.dart';
import 'thecrew_board.dart';

/// 花札·来来 / 星际探险队 / 皮克牌
final Map<String, BoardBuilder> cards9Boards = {
  'koikoi': (g) => KoiKoiBoard(g),
  'thecrew': (g) => TheCrewBoard(g),
  'piquet': (g) => PiquetBoard(g),
};
