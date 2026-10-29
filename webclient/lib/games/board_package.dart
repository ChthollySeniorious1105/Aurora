import '../widgets/common.dart';

/// One deferred game-board package (see board_index.g.dart).
class BoardPackage {
  /// Directory name under lib/games.
  final String name;

  /// Downloads the package's code (a no-op outside the web build).
  final Future<void> Function() load;

  /// The package's `game id -> board` map. Only valid after [load] completed.
  final Map<String, BoardBuilder> Function() boards;

  const BoardPackage(this.name, this.load, this.boards);
}
