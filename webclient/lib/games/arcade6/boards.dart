import '../../widgets/common.dart';
import 'akari_board.dart';
import 'hashi_board.dart';
import 'klotski_board.dart';

/// 华容道竞速 / 数回连桥竞速 / 美术馆照明竞速
final Map<String, BoardBuilder> arcade6Boards = {
  'klotski': (g) => KlotskiBoard(g),
  'hashi': (g) => HashiBoard(g),
  'akari': (g) => AkariBoard(g),
};
