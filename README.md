# Aurora 联机小游戏独立网页服务端

从 ChthollyMinecraftLauncher（CML）独立出来的 **纯网页端** Aurora 联机小游戏服务端组件（包含 **425 款游戏**）。

不再适配或依赖 CML 原生客户端、不再开放原生 TCP 端口或局域网 UDP 广播；**仅需开放一个 HTTP 端口（默认 `7790`）**，同时承载网页前端静态资源、`/ws` 加密 WebSocket 游戏连接与 `/health`、`/api/status` 状态接口。玩家打开浏览器网址即可一键进入大厅游玩。

## 目录结构

| 目录 / 文件 | 说明 |
|---|---|
| `server/` | 独立网页服务端（Dart 控制台程序，编译为 `aurora_server.exe`） |
| `webclient/` | 网页端前端工程（Flutter Web，构建产物位于 `web/`，由服务端同端口托管） |
| `shared/` | 共享加密协议与全部 425 款游戏权威规则引擎 |
| `Dockerfile` / `docker-compose.yml` | Linux / NAS 一键容器化构建与部署配置 |
| `GAME_DEV_GUIDE.md` | 新增游戏的开发规范 |
| `build.ps1` | 一键构建脚本（编译 `aurora_server.exe` + 构建 `web/` + 打包发行 ZIP） |

## 快速开始（一键启动与网页访问）

1. 双击 `启动服务器并打开网页.bat`（或运行 `aurora_server.exe --open`），服务端无需任何交互提问即可直接启动，并自动调用系统默认浏览器打开游戏页面。
2. 也可直接运行 `启动服务器.bat` 或命令行：
   ```powershell
   aurora_server.exe                       # 默认监听 7790 端口，自动读写 aurora_server.json
   aurora_server.exe --port 8080           # 指定网页端口（HTTP + WebSocket 共用）
   aurora_server.exe --port 8080 --name "周末麻将局" --open
   ```
3. **玩家一键访问**：
   - 浏览器打开 `http://服务器地址:7790`：
     - 首次访问设置昵称和头像后**自动连接当前网页所属服务器**直达大厅；
     - 再次访问打开网页即**自动登录进入大厅**，无需手动填写 IP 或端口。
   - 房间内点击二维码按钮即可生成形如 `http://服务器地址:7790/?room=A7K2Q` 的纯网页邀请链接或二维码（本机 `localhost` 打开时自动识别局域网 IP 生成手机可扫二维码）：
     - 无密码房间点开链接**免二次确认自动入房入座**；
     - 进入/离开房间时浏览器地址栏自动同步 `?room=房间号`，直接复制浏览器网址即可拉人。

## 功能与配置

- **网页端服主管理面板（Web Admin）**：首次启动在 `aurora_server.json` 自动生成 `adminToken`（也可在 `.env` 设置 `ADMIN_TOKEN`），在大厅右上角或设置中打开「服主管理面板」，即可在浏览器内发送全服广播、强制关闭房间、踢出/封禁玩家、在线编辑并**热重载 `words/*.txt` 自定义词库**。
- **大厅搜索、筛选与快速加入**：支持按房间号/名称/游戏搜索、按状态与分类筛选，以及一键「快速加入」有空位的等待房间。
- **后台标签页回合提醒与对局弹幕**：轮到自己操作或对局开始时自动更新浏览器标签页标题并发送桌面通知；支持对局内聊天浮动弹幕开关。
- **HTTP 状态与健康检查接口**：`GET /health` 与 `GET /api/status` 返回 JSON 格式的在线人数、房间数、游戏数与运行时长。
- **自定义词库**：首次启动在同目录生成 `words/` 文件夹（`drawguess.txt`、`undercover.txt`、`turtlesoup.txt`、`decrypto.txt`、`justone.txt`、`wavelength.txt`）。
- **大模型 AI 电脑玩家**（可选）：复制同目录自动生成的 `.env.example` 为 `.env`，支持 `AI_PROVIDER=anthropic` 或 `AI_PROVIDER=openai`（兼容 DeepSeek / 通义 / Kimi / Ollama 等）。
- **战绩、Elo 与回放**：战绩保存在 `data/stats.json`，每日挑战保存在 `data/daily.json`，对局回放保存在 `replays/`。
- **端到端加密**：WebSocket 内帧采用 X25519 密钥交换 + ChaCha20-Poly1305 认证加密，服务器长期身份保存在 `server_identity.key`。
- **控制台命令**：`rooms`、`users`、`kick <#id>`、`ban <#id>`、`say <文本>`、`reload`（热重载词库）、`ai`、`replays`、`stats`、`open`（打开浏览器）、`quit`。
- **Docker / NAS 部署**：运行 `docker compose up -d --build` 即可在 Linux 云服务器或 NAS 上一键启动并持久化 `data/`、`replays/`、`words/`。

## 构建与测试

```powershell
# 一键运行测试、编译服务端与网页前端并生成发行包 dist\Aurora-WebServer-<ver>-windows-x64.zip
powershell -ExecutionPolicy Bypass -File build.ps1

# 跳过测试快速构建
powershell -ExecutionPolicy Bypass -File build.ps1 -SkipTests
```
