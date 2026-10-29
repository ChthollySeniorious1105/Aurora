import '../../widgets/common.dart';
import 'creek_board.dart';
import 'heyawake_board.dart';
import 'shingoki_board.dart';

/// 分室涂黑竞速 / 信号灯回路竞速 / 溪流交点竞速
final Map<String, BoardBuilder> arcade14Boards = {
  'heyawake': (g) => HeyawakeBoard(g),
  'shingoki': (g) => ShingokiBoard(g),
  'creek': (g) => CreekBoard(g),
};
