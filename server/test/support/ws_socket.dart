import 'dart:async';
import 'dart:io';

/// Test stand-in for the raw byte pipe a browser opens: a binary WebSocket to
/// `/ws`, exposing the small `Socket`-like surface the tests use.
class WsSocket extends Stream<List<int>> {
  final WebSocket ws;
  WsSocket(this.ws);

  static Future<WsSocket> connect(String host, int port) async =>
      WsSocket(await WebSocket.connect('ws://$host:$port/ws'));

  /// Sends [bytes] as one binary message.
  void add(List<int> bytes) {
    if (ws.readyState == WebSocket.open) ws.add(bytes);
  }

  Future<void> get done => ws.done;

  void destroy() {
    ws.close().catchError((_) {});
  }

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      ws
          .where((m) => m is List<int>)
          .cast<List<int>>()
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
}
