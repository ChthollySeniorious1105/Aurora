import '../../widgets/common.dart';
import 'norinori_board.dart';
import 'thermometers_board.dart';
import 'yajilin_board.dart';

/// 箭头回路竞速 / 多米诺双格竞速 / 温度计填充竞速
final Map<String, BoardBuilder> arcade13Boards = {
  'yajilin': (g) => YajilinBoard(g),
  'norinori': (g) => NorinoriBoard(g),
  'thermometers': (g) => ThermometersBoard(g),
};
