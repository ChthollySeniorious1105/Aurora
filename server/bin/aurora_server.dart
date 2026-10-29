import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:aurora_shared/aurora_shared.dart';
import 'package:aurora_server/server.dart';

const _usage = '''用法: aurora_server [选项]

  -p, --port <端口>     网页端口（HTTP + WebSocket，默认 $kDefaultPort）
      --name <名称>     服务器名称（显示在大厅）
      --web-dir <目录>  网页客户端目录（默认 exe 同目录的 web）
      --data-dir <目录> 配置与数据目录（默认 exe 所在目录）
      --open            启动后用默认浏览器打开游戏页面
  -h, --help            显示本帮助

玩家用浏览器打开 http://服务器地址:端口 即可游玩，无需安装客户端。''';

/// Aurora standalone web server entry point.
///
/// One HTTP port serves the browser client (static files from the `web`
/// folder) and the encrypted game connection on `/ws`. Settings are kept in
/// `aurora_server.json` next to the executable; no interactive setup is needed,
/// so double-clicking the start script is enough.
Future<void> main(List<String> args) async {
  int? port;
  String? name, webDirArg, dataDirArg;
  var open = false;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    // "--flag value" or "--flag=value"
    final eq = a.indexOf('=');
    final flag = a.startsWith('-') && eq > 0 ? a.substring(0, eq) : a;
    String value() {
      if (eq > 0 && a.startsWith('-')) return a.substring(eq + 1);
      if (i + 1 < args.length) return args[++i];
      _fail('参数 $flag 缺少取值\n\n$_usage');
    }

    switch (flag) {
      case '--port' || '-p' || '--web-port':
        final v = value();
        port = int.tryParse(v);
        if (port == null) _fail('端口无效：$v');
      case '--name':
        name = value();
      case '--web-dir':
        webDirArg = value();
      case '--data-dir':
        dataDirArg = value();
      case '--open':
        open = true;
      case '--help' || '-h':
        stdout.writeln(_usage);
        return;
      default:
        _fail('未知参数：$a\n\n$_usage');
    }
  }

  final sep = Platform.pathSeparator;
  final baseDir = dataDirArg ?? _defaultBaseDir();
  Directory(baseDir).createSync(recursive: true);
  final cfgFile = File('$baseDir${sep}aurora_server.json');
  Map<String, dynamic> cfg = {};
  if (cfgFile.existsSync()) {
    try {
      cfg = jsonDecode(cfgFile.readAsStringSync()) as Map<String, dynamic>;
    } catch (_) {}
  }
  // Configs from the CML-bundled server kept the native TCP port in `port`
  // and the browser port in `webPort`; only the browser port survives.
  var cfgPort = cfg['port'] is int ? cfg['port'] as int : null;
  final legacyWebPort = cfg.remove('webPort');
  if (legacyWebPort is int && legacyWebPort > 0) cfgPort = legacyWebPort;
  port ??= cfgPort ?? kDefaultPort;
  if (port < 1 || port > 65535) _fail('端口无效：$port（1～65535）');
  name ??= cfg['name'] is String && (cfg['name'] as String).trim().isNotEmpty
      ? cfg['name'] as String
      : 'Aurora 服务器';
  // pid salt: generated once; changing it resets everyone's 战绩 identity
  final oldSalt = cfg['salt'];
  final salt = oldSalt is String && oldSalt.length >= 16 ? oldSalt : _randomHex(16);
  final oldAdmin = cfg['adminToken'];
  final cfgAdmin = oldAdmin is String && oldAdmin.trim().isNotEmpty ? oldAdmin.trim() : _randomHex(8);
  try {
    // keep any extra keys the admin added; only update the ones we own
    cfg
      ..['port'] = port
      ..['name'] = name
      ..['salt'] = salt
      ..['adminToken'] = cfgAdmin;
    cfgFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(cfg));
  } catch (_) {}

  ensureEnvExample(baseDir);
  final (env, envPath) = loadEnv([baseDir, Directory.current.path]);
  final envAdmin = env['ADMIN_TOKEN']?.trim() ?? '';
  final adminToken = envAdmin.isNotEmpty ? envAdmin : cfgAdmin;
  final ai = HttpAiService.fromEnv(env);
  final identity = _loadIdentity('$baseDir${sep}server_identity.key');
  final webDir = _resolveWebDir(webDirArg, baseDir);
  final publicWebUrl = env['PUBLIC_WEB_URL']?.trim() ?? '';
  final server = AuroraServer(port,
      serverName: name,
      resourceDir: Directory('$baseDir${sep}words'),
      identity: identity,
      ai: ai.configured ? ai : null,
      salt: salt,
      dataDir: Directory('$baseDir${sep}data'),
      replayDir: Directory('$baseDir${sep}replays'),
      replayKeep: int.tryParse(env['REPLAY_KEEP']?.trim() ?? '') ?? 2000,
      webDir: webDir,
      publicWebUrl: publicWebUrl,
      adminToken: adminToken,
      trustProxy: env['TRUST_PROXY']?.trim().toLowerCase() == 'true');
  server.resources.ensureTemplates();
  try {
    await server.start();
  } on SocketException catch (e) {
    _fail('无法监听端口 $port：${e.message}（端口被占用？可用 --port 换一个端口）');
  }
  final p = server.boundPort;
  logLine('服务器名称：$name');
  logLine('服务器指纹：${identity.fingerprint}（玩家首次连接时会看到，可用于核对服务器身份）');
  logLine('已加载 ${gameRegistry.length} 款游戏');
  logLine('网页客户端：${server.hasWebClient ? webDir.path : '未找到（${webDir.path}）'}');
  logLine(envPath == null ? '未找到 .env（可参考 ${baseDir}${sep}.env.example 创建）' : '已读取配置 $envPath');
  logLine(ai.configured ? 'AI 已启用：${ai.label}' : 'AI 未启用（电脑玩家使用普通算法）');
  logLine('回放 ${server.replays.count} 局，战绩 ${server.stats.players.length} 人');
  logLine('网页管理面板密钥（adminToken）：$adminToken');
  logLine('浏览器打开以下任一地址即可游玩：');
  logLine('  http://localhost:$p    （本机）');
  for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final a in iface.addresses) {
      if (a.isLoopback) continue;
      logLine('  http://${a.address}:$p    (${iface.name})');
    }
  }
  if (publicWebUrl.isNotEmpty) logLine('  $publicWebUrl    （公网入口 PUBLIC_WEB_URL）');
  logLine('内网穿透 / 云服务器：只需开放或映射 TCP $p 这一个端口');
  logLine('输入 help 查看控制台命令');
  if (open) _openBrowser('http://localhost:$p');

  if (stdin.hasTerminal) {
    stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) async {
      final cmd = line.trim();
      final sp = cmd.indexOf(' ');
      final verb = sp < 0 ? cmd : cmd.substring(0, sp);
      final arg = sp < 0 ? '' : cmd.substring(sp + 1).trim();
      switch (verb) {
        case 'help':
          stdout.writeln('rooms          列出房间\n'
              'users          列出在线玩家\n'
              'kick <#id>     断开玩家\n'
              'ban <#id>      断开玩家并封禁其 IP（到重启为止）\n'
              'say <文本>     全服系统公告\n'
              'reload         热重载 words/ 自定义词库\n'
              'ai             AI 状态、今日用量、最近错误\n'
              'replays        回放数量与占用空间\n'
              'stats          战绩人数\n'
              'open           用浏览器打开游戏页面\n'
              'quit           关闭服务器');
        case 'rooms':
          final lines = server.describeRooms();
          stdout.writeln(lines.isEmpty ? '（没有房间）' : lines.join('\n'));
        case 'users':
          for (final c in server.onlineClients) {
            stdout.writeln('#${c.id} ${c.name} ${c.address} ${c.room == null ? "大厅" : "房间${c.room!.id}"}');
          }
        case 'kick' || 'ban':
          final id = int.tryParse(arg.replaceFirst('#', ''));
          if (id == null) {
            stdout.writeln('用法：$verb <玩家#id>（用 users 查看 id）');
          } else if (server.kickClient(id, ban: verb == 'ban')) {
            stdout.writeln(verb == 'ban' ? '已断开并封禁 #$id 的 IP' : '已断开 #$id');
          } else {
            stdout.writeln('没有找到玩家 #$id');
          }
        case 'say':
          if (arg.isEmpty) {
            stdout.writeln('用法：say <文本>');
          } else {
            server.announce(arg);
            stdout.writeln('已发送公告');
          }
        case 'reload':
          final counts = server.resources.reload();
          stdout.writeln('已重载自定义词库：$counts');
        case 'ai':
          stdout.writeln(ai.status());
          if (arg == 'test') {
            if (!ai.available) {
              stdout.writeln('AI 未启用或不可用，无法发起测试请求');
            } else {
              stdout.writeln('正在发起 AI 连通性测试 (${ai.label})…');
              final r = await ai.complete(const AiRequest(system: '只回复 OK', prompt: 'ping', maxTokens: 16));
              stdout.writeln(r != null ? 'AI 测试成功，模型回复：${r.trim()}' : 'AI 测试失败：${ai.lastError}');
            }
          }
        case 'replays':
          final mb = (server.replays.totalBytes / 1024 / 1024).toStringAsFixed(1);
          stdout.writeln('回放 ${server.replays.count} 局，占用约 $mb MB（最多保留 ${server.replays.keep} 局）');
        case 'stats':
          stdout.writeln('战绩记录 ${server.stats.players.length} 人');
        case 'open':
          _openBrowser('http://localhost:$p');
        case 'quit' || 'exit' || 'stop':
          await server.stop();
          exit(0);
        case '':
          break;
        default:
          stdout.writeln('未知命令，输入 help 查看帮助');
      }
    });
  }
  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}

Never _fail(String msg) {
  stderr.writeln(msg);
  exit(1);
}

/// Where config, keys and data live: next to the compiled executable, or the
/// current directory when started from source (`dart run`).
String _defaultBaseDir() {
  final fromSource = Platform.script.path.endsWith('.dart');
  return fromSource ? Directory.current.path : File(Platform.resolvedExecutable).parent.path;
}

/// `--web-dir`, else `<base>/web`, else (running from source) the client's
/// `flutter build web` output in the repository.
Directory _resolveWebDir(String? arg, String baseDir) {
  final sep = Platform.pathSeparator;
  if (arg != null) return Directory(arg);
  final beside = Directory('$baseDir${sep}web');
  if (beside.existsSync() || !Platform.script.path.endsWith('.dart')) return beside;
  final repo = File(Platform.script.toFilePath()).parent.parent.parent.path;
  final built = Directory('$repo${sep}webclient${sep}build${sep}web');
  return built.existsSync() ? built : beside;
}

void _openBrowser(String url) {
  try {
    if (Platform.isWindows) {
      Process.start('cmd', ['/c', 'start', '', url], mode: ProcessStartMode.detached);
    } else if (Platform.isMacOS) {
      Process.start('open', [url], mode: ProcessStartMode.detached);
    } else {
      Process.start('xdg-open', [url], mode: ProcessStartMode.detached);
    }
  } catch (e) {
    logLine('无法自动打开浏览器（$e），请手动访问 $url');
  }
}

String _randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
}

/// Long-term server key (X25519 seed). Clients pin its fingerprint; keep this
/// file private and back it up — deleting it makes every client warn that the
/// server identity changed.
ServerIdentity _loadIdentity(String path) {
  final f = File(path);
  try {
    if (f.existsSync()) {
      final seed = base64.decode(f.readAsStringSync().trim());
      if (seed.length == 32) return ServerIdentity.fromSeed(seed);
      stderr.writeln('server_identity.key 格式错误，将重新生成');
    }
  } catch (e) {
    stderr.writeln('读取 server_identity.key 失败：$e');
  }
  final seed = ServerIdentity.newSeed();
  try {
    f.writeAsStringSync(base64.encode(seed));
  } catch (e) {
    stderr.writeln('无法保存 server_identity.key（重启后指纹会变化）：$e');
  }
  return ServerIdentity.fromSeed(seed);
}
