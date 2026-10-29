import '../../widgets/common.dart';
import 'kakuro_board.dart';
import 'plumber_board.dart';
import 'shikaku_board.dart';

/// 数方分割竞速 / 数和填字竞速 / 水管工接管竞速
final Map<String, BoardBuilder> arcade8Boards = {
  'shikaku': (g) => ShikakuBoard(g),
  'kakuro': (g) => KakuroBoard(g),
  'plumber': (g) => PlumberBoard(g),
};
