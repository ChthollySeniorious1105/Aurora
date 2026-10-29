import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'transport.dart';

const bool isWeb = true;

/// The server that served this page (its HTTP port also accepts `/ws`).
String defaultWebAddress() {
  final loc = web.window.location;
  return loc.host.isEmpty ? '' : '${loc.protocol}//${loc.host}';
}

class _WsLink implements Link {
  final web.WebSocket ws;
  final _data = StreamController<Uint8List>();
  _WsLink(this.ws);

  @override
  Stream<Uint8List> get data => _data.stream;

  @override
  void add(List<int> bytes) {
    if (ws.readyState != web.WebSocket.OPEN) return;
    final u = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    ws.send(u.toJS);
  }

  void _done([Object? error]) {
    if (_data.isClosed) return;
    if (error != null) _data.addError(error);
    _data.close();
  }

  @override
  Future<void> close() async {
    try {
      ws.close();
    } catch (_) {}
    _done();
  }

  @override
  void destroy() {
    try {
      ws.close();
    } catch (_) {}
    _done();
  }
}

Future<Link> openLink(String address, Duration timeout) async {
  final secure = web.window.location.protocol == 'https:';
  final String url;
  try {
    url = webSocketUrl(address, origin: defaultWebAddress(), secure: secure);
  } catch (_) {
    throw const ConnectException('地址格式错误');
  }
  if (secure && url.startsWith('ws://')) {
    throw const ConnectException('HTTPS 页面只能连接 wss:// 地址');
  }
  final web.WebSocket ws;
  try {
    ws = web.WebSocket(url);
  } catch (_) {
    throw const ConnectException('地址格式错误');
  }
  ws.binaryType = 'arraybuffer';
  final link = _WsLink(ws);
  final opened = Completer<void>();
  const failed = ConnectException('无法连接游戏服务器（服务器未启动，或反向代理未转发 /ws 的 WebSocket）');
  ws.onopen = ((web.Event _) {
    if (!opened.isCompleted) opened.complete();
  }).toJS;
  ws.onmessage = ((web.MessageEvent e) {
    final d = e.data;
    if (d.isA<JSArrayBuffer>()) {
      link._data.add((d as JSArrayBuffer).toDart.asUint8List());
    }
  }).toJS;
  ws.onerror = ((web.Event _) {
    if (!opened.isCompleted) opened.completeError(failed);
  }).toJS;
  ws.onclose = ((web.CloseEvent _) {
    if (!opened.isCompleted) opened.completeError(failed);
    link._done();
  }).toJS;
  try {
    await opened.future.timeout(timeout);
  } on TimeoutException {
    link.destroy();
    throw const ConnectException('连接超时');
  }
  return link;
}
