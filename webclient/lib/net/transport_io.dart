import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'transport.dart';

/// VM side (only `flutter test` and tooling): the same `/ws` WebSocket
/// protocol as the browser, via `dart:io`.
const bool isWeb = false;

String defaultWebAddress() => '';

class _IoWsLink implements Link {
  final WebSocket ws;
  late final Stream<Uint8List> _data = ws
      .where((m) => m is List<int>)
      .map((m) => m is Uint8List ? m : Uint8List.fromList(m as List<int>));
  _IoWsLink(this.ws);

  @override
  Stream<Uint8List> get data => _data;

  @override
  void add(List<int> bytes) {
    if (ws.readyState == WebSocket.open) ws.add(bytes);
  }

  @override
  Future<void> close() async {
    try {
      await ws.close();
    } catch (_) {}
  }

  @override
  void destroy() {
    ws.close().catchError((_) {});
  }
}

Future<Link> openLink(String address, Duration timeout) async {
  final String url;
  try {
    url = webSocketUrl(address);
  } on FormatException {
    throw const ConnectException('地址格式错误');
  }
  try {
    final ws = await WebSocket.connect(url).timeout(timeout);
    return _IoWsLink(ws);
  } on TimeoutException {
    throw const ConnectException('连接超时');
  } on SocketException catch (e) {
    final m = '${e.osError?.message ?? ''} ${e.message}';
    if (m.contains('refused') || m.contains('拒绝') || e.osError?.errorCode == 10061 || e.osError?.errorCode == 111) {
      throw const ConnectException('连接被拒绝（服务器未启动或端口错误）');
    }
    if (m.contains('host lookup') || m.contains('No such host')) throw const ConnectException('无法解析地址');
    throw ConnectException(e.message.isEmpty ? '$e' : e.message);
  } on WebSocketException {
    throw const ConnectException('无法建立 WebSocket 连接（不是 Aurora 服务器或地址/端口错误）');
  }
}
