import 'dart:async';
import 'dart:typed_data';

import 'transport_io.dart' if (dart.library.js_interop) 'transport_web.dart' as impl;

/// Connection failure with a user-facing message.
class ConnectException implements Exception {
  final String message;
  const ConnectException(this.message);
  @override
  String toString() => message;
}

/// A byte pipe to the server: a binary WebSocket to `ws(s)://host:port/ws`
/// (the same HTTP port that served the page), carrying length-prefixed
/// encrypted frames.
abstract class Link {
  Stream<Uint8List> get data;
  void add(List<int> bytes);
  Future<void> close();
  void destroy();
}

/// True when running in a browser. False only under `flutter test` / VM
/// tooling, where the `dart:io` WebSocket implementation is used.
const bool kIsWebTransport = impl.isWeb;

/// Opens a [Link]. [address] is an http(s)/ws(s) URL or "host[:port]" of an
/// Aurora server; empty = the server that served this page.
Future<Link> openLink(String address, {Duration timeout = const Duration(seconds: 8)}) =>
    impl.openLink(address, timeout);

/// The page's own origin (`http(s)://host:port`), i.e. the Aurora server that
/// served this web client. '' outside the browser.
String defaultWebAddress() => impl.defaultWebAddress();

/// Turns a server address into its WebSocket URL: http(s) URLs become ws(s),
/// ws(s) URLs are kept, bare "host[:port]" gets `wss://` when [secure] (HTTPS
/// page) else `ws://`; the path defaults to `/ws`. Empty [address] = [origin].
/// Throws [FormatException] on malformed input.
String webSocketUrl(String address, {String origin = '', bool secure = false}) {
  var a = address.trim();
  if (a.isEmpty) a = origin.trim();
  if (a.isEmpty) throw const FormatException('empty address');
  if (a.startsWith('http://')) a = 'ws://${a.substring(7)}';
  if (a.startsWith('https://')) a = 'wss://${a.substring(8)}';
  if (!a.startsWith('ws://') && !a.startsWith('wss://')) {
    if (a.contains('://')) a = a.substring(a.indexOf('://') + 3);
    a = '${secure ? 'wss' : 'ws'}://$a';
  }
  final u = Uri.parse(a);
  if (u.host.isEmpty) throw const FormatException('missing host');
  return Uri(
    scheme: u.scheme,
    host: u.host,
    port: u.hasPort ? u.port : null,
    path: u.path.isEmpty || u.path == '/' ? '/ws' : u.path,
  ).toString();
}
