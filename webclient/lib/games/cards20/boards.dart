import '../../widgets/common.dart';
import 'diamonds_board.dart';
import 'fantasy_realms_board.dart';
import 'phase10_board.dart';
import 'sea_salt_paper_board.dart';
import 'zhaopengyou_board.dart';

final Map<String, BoardBuilder> cards20Boards = {
  'sea_salt_paper': SeaSaltPaperBoard.new,
  'fantasy_realms': FantasyRealmsBoard.new,
  'zhaopengyou': ZhaopengyouBoard.new,
  'diamonds': DiamondsBoard.new,
  'phase10': Phase10Board.new,
};
