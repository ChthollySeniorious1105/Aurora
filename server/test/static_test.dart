import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:aurora_server/server.dart';
import 'package:test/test.dart';

/// Static web-client delivery: precompressed gzip, validators / 304,
/// Cache-Control policy, HEAD and path safety.
void main() {
  late AuroraServer server;
  late Directory tmp;
  late Directory web;
  late int port;
  late Uint8List mainJs;
  late Uint8List wasm;

  Uint8List jsLike(int seed, int size) {
    final r = Random(seed);
    final sb = StringBuffer();
    while (sb.length < size) {
      sb.write('function f${r.nextInt(5000)}(a,b){return a.x${r.nextInt(90)}+b[${r.nextInt(300)}];}\n');
    }
    return Uint8List.fromList(utf8.encode(sb.toString()));
  }

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('aurora_static_');
    web = Directory('${tmp.path}/web')..createSync();
    File('${web.path}/index.html').writeAsStringSync('<html>aurora-web${' ' * 2000}</html>');
    mainJs = jsLike(1, 300000);
    File('${web.path}/main.dart.js').writeAsBytesSync(mainJs);
    File('${web.path}/main.dart.js_1.part.js').writeAsBytesSync(jsLike(2, 5000));
    Directory('${web.path}/canvaskit').createSync();
    final r = Random(3);
    wasm = Uint8List.fromList(List.generate(200000, (i) => i % 7 == 0 ? r.nextInt(256) : (i ~/ 13) & 0xff));
    File('${web.path}/canvaskit/canvaskit.wasm').writeAsBytesSync(wasm);
    Directory('${web.path}/icons').createSync();
    File('${web.path}/icons/Icon-192.png').writeAsBytesSync(List.generate(3000, (i) => r.nextInt(256)));
    Directory('${web.path}/assets/fonts').createSync(recursive: true);
    File('${web.path}/assets/fonts/A.otf').writeAsBytesSync(List.generate(4000, (i) => i & 0x3f));
    File('${tmp.path}/secret.txt').writeAsStringSync('secret');
    server = AuroraServer(0,
        webDir: web, dataDir: Directory('${tmp.path}/data'), replayDir: Directory('${tmp.path}/replays'));
    await server.start();
    port = server.boundPort;
  });

  tearDownAll(() async {
    await server.stop();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Raw request (no automatic decompression).
  Future<(HttpClientResponse, Uint8List)> fetch(String path,
      {String method = 'GET', Map<String, String> headers = const {}}) async {
    final c = HttpClient()..autoUncompress = false;
    try {
      final req = await c.openUrl(method, Uri.parse('http://127.0.0.1:$port$path'));
      req.headers.removeAll(HttpHeaders.acceptEncodingHeader); // HttpClient adds gzip by default
      headers.forEach(req.headers.set);
      final res = await req.close();
      final b = BytesBuilder(copy: false);
      await res.forEach(b.add);
      return (res, b.takeBytes());
    } finally {
      c.close(force: true);
    }
  }

  const gz = {'Accept-Encoding': 'gzip, deflate, br'};

  test('gzip response decodes to the identical bytes', () async {
    for (final (path, raw) in [('/main.dart.js', mainJs), ('/canvaskit/canvaskit.wasm', wasm)]) {
      final (res, body) = await fetch(path, headers: gz);
      expect(res.statusCode, 200, reason: path);
      expect(res.headers.value(HttpHeaders.contentEncodingHeader), 'gzip', reason: path);
      expect(res.headers.value(HttpHeaders.varyHeader), contains('Accept-Encoding'), reason: path);
      expect(res.headers.contentLength, body.length, reason: path);
      expect(body.length, lessThan(raw.length), reason: path);
      expect(res.headers.value('x-raw-length'), '${raw.length}', reason: path);
      expect(gzip.decode(body), raw, reason: path);
    }
  });

  test('without gzip in Accept-Encoding the raw file is served', () async {
    for (final h in [<String, String>{}, {'Accept-Encoding': 'gzip;q=0, br'}, {'Accept-Encoding': 'identity'}]) {
      final (res, body) = await fetch('/main.dart.js', headers: h);
      expect(res.statusCode, 200);
      expect(res.headers.value(HttpHeaders.contentEncodingHeader), isNull, reason: '$h');
      expect(res.headers.contentLength, mainJs.length);
      expect(res.headers.value('x-raw-length'), '${mainJs.length}');
      expect(body, mainJs);
    }
  });

  test('concurrent first requests share one compression and all decode', () async {
    final data = jsLike(9, 120000);
    File('${web.path}/main.dart.js_7.part.js').writeAsBytesSync(data);
    final all = await Future.wait(List.generate(6, (_) => fetch('/main.dart.js_7.part.js', headers: gz)));
    for (final (res, body) in all) {
      expect(res.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
      expect(gzip.decode(body), data);
    }
  });

  test('ETag / Last-Modified revalidation answers 304', () async {
    final (res, _) = await fetch('/main.dart.js', headers: gz);
    final etag = res.headers.value(HttpHeaders.etagHeader)!;
    final lastMod = res.headers.value(HttpHeaders.lastModifiedHeader)!;
    expect(etag, startsWith('W/"'));
    expect(() => HttpDate.parse(lastMod), returnsNormally);

    final (r304, b304) = await fetch('/main.dart.js', headers: {...gz, 'If-None-Match': etag});
    expect(r304.statusCode, 304);
    expect(b304, isEmpty);
    expect(r304.headers.value(HttpHeaders.etagHeader), etag);
    expect(r304.headers.value(HttpHeaders.cacheControlHeader), 'no-cache');

    // strong form of the same tag and lists also match (weak comparison)
    expect((await fetch('/main.dart.js', headers: {'If-None-Match': '"x", ${etag.substring(2)}'})).$1.statusCode, 304);
    expect((await fetch('/main.dart.js', headers: {'If-Modified-Since': lastMod})).$1.statusCode, 304);
    // If-None-Match wins over If-Modified-Since
    final (stale, staleBody) =
        await fetch('/main.dart.js', headers: {'If-None-Match': 'W/"nope"', 'If-Modified-Since': lastMod});
    expect(stale.statusCode, 200);
    expect(staleBody, mainJs);
    final old = HttpDate.format(DateTime.utc(2000));
    expect((await fetch('/main.dart.js', headers: {'If-Modified-Since': old})).$1.statusCode, 200);
  });

  test('changing a file changes the ETag and the gzip copy', () async {
    final f = File('${web.path}/main.dart.js_3.part.js')..writeAsBytesSync(jsLike(4, 50000));
    final (r1, _) = await fetch('/main.dart.js_3.part.js', headers: gz);
    final next = jsLike(5, 60000);
    f.writeAsBytesSync(next);
    final (r2, b2) = await fetch('/main.dart.js_3.part.js', headers: {...gz, 'If-None-Match': r1.headers.value('etag')!});
    expect(r2.statusCode, 200);
    expect(r2.headers.value('etag'), isNot(r1.headers.value('etag')));
    expect(r2.headers.value('x-raw-length'), '${next.length}');
    expect(gzip.decode(b2), next);
  });

  test('Cache-Control policy', () async {
    Future<String?> cc(String p) async => (await fetch(p)).$1.headers.value(HttpHeaders.cacheControlHeader);
    for (final p in ['/', '/index.html', '/room/ABC12', '/main.dart.js', '/main.dart.js_1.part.js', '/canvaskit/canvaskit.wasm']) {
      expect(await cc(p), 'no-cache', reason: p);
    }
    for (final p in ['/icons/Icon-192.png', '/assets/fonts/A.otf']) {
      expect(await cc(p), 'public, max-age=604800', reason: p);
    }
    final (png, _) = await fetch('/icons/Icon-192.png', headers: gz);
    expect(png.headers.value(HttpHeaders.contentEncodingHeader), isNull); // images are not gzipped
    expect(png.headers.value(HttpHeaders.etagHeader), isNotNull);
    final (otf, otfBody) = await fetch('/assets/fonts/A.otf', headers: gz);
    expect(otf.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
    expect(gzip.decode(otfBody), File('${web.path}/assets/fonts/A.otf').readAsBytesSync());
  });

  test('HEAD mirrors GET headers without a body', () async {
    final (raw, rawBody) = await fetch('/main.dart.js', method: 'HEAD');
    expect(raw.statusCode, 200);
    expect(rawBody, isEmpty);
    expect(raw.headers.contentLength, mainJs.length);
    expect(raw.headers.value('x-raw-length'), '${mainJs.length}');
    expect(raw.headers.contentType?.mimeType, 'text/javascript');

    final (get, getBody) = await fetch('/main.dart.js', headers: gz); // cached by now
    final (head, headBody) = await fetch('/main.dart.js', method: 'HEAD', headers: gz);
    expect(head.statusCode, 200);
    expect(headBody, isEmpty);
    expect(head.headers.value(HttpHeaders.contentEncodingHeader), 'gzip');
    expect(head.headers.contentLength, getBody.length);
    expect(head.headers.value('etag'), get.headers.value('etag'));

    final (idx, idxBody) = await fetch('/', method: 'HEAD');
    expect(idx.statusCode, 200);
    expect(idxBody, isEmpty);
  });

  test('security behavior is unchanged', () async {
    for (final p in ['/../secret.txt', '/%2e%2e/secret.txt', '/..%2fsecret.txt', '/..%5csecret.txt', '/missing.js']) {
      final (res, body) = await fetch(p);
      expect(utf8.decode(body, allowMalformed: true), isNot(contains('secret')), reason: p);
      expect(res.statusCode, 404, reason: p);
    }
    // raw request line, bypassing client-side normalization
    final s = await Socket.connect('127.0.0.1', port);
    s.write('GET /../secret.txt HTTP/1.1\r\nHost: x\r\nConnection: close\r\n\r\n');
    final reply = await utf8.decoder.bind(s).join();
    s.destroy();
    expect(reply, isNot(contains('secret')));
    final (res, body) = await fetch('/room/ABC12');
    expect(res.statusCode, 200);
    expect(utf8.decode(body), contains('aurora-web'));
    expect(res.headers.value('x-content-type-options'), 'nosniff');
    expect((await fetch('/main.dart.js', method: 'POST')).$1.statusCode, 405);
  });
}
