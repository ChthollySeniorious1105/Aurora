import '../../widgets/common.dart';
import 'galaxies_board.dart';
import 'hidato_board.dart';
import 'kuromasu_board.dart';

/// 数链寻路竞速 / 黑格视线竞速 / 对称星系分割竞速
final Map<String, BoardBuilder> arcade12Boards = {
  'hidato': (g) => HidatoBoard(g),
  'kuromasu': (g) => KuromasuBoard(g),
  'galaxies': (g) => GalaxiesBoard(g),
};
