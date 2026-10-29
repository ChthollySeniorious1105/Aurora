import '../../widgets/common.dart';
import 'hitori_board.dart';
import 'starbattle_board.dart';
import 'tents_board.dart';

/// 数独涂黑竞速 / 星战放星竞速 / 帐篷露营竞速
final Map<String, BoardBuilder> arcade9Boards = {
  'hitori': (g) => HitoriBoard(g),
  'starbattle': (g) => StarBattleBoard(g),
  'tents': (g) => TentsBoard(g),
};
