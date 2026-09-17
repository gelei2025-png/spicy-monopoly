# 自建部署速查（API + 远程 MCP）

> 只想玩一局？**不用看这个文档**。把 `monopoly-API使用手册.md`（或 `monopoly-给AI的操作手册.md`）
> 甩给你的 AI，把接入地址填成公开实例 `https://spicy-monopoly.lol` 就行，零安装。
> 这份文档只服务「想自己架一台」的情况。

---

## 零、最省事：一键部署到 Render（连服务器都不用买）

1. 在 Render 用 GitHub 登录，New → Blueprint，选**你这个 fork 仓库**（`render.yaml` 已在根目录）；
2. Render 按 `render.yaml` 建两个免费 Web Service，并自动签发 HTTPS 域名；
3. 等两个服务都 Live，把 MCP 服务的域名后面加 `/mcp` 就是接入地址：

```json
{
  "mcpServers": {
    "spicy-monopoly": {
      "type": "http",
      "url": "https://spicy-monopoly-mcp-xxxx.onrender.com/mcp"
    }
  }
}
```

**免费档要知道的两件事：**

- **会休眠**：15 分钟没有入站流量就睡，下次连上要等约 1 分钟唤醒（开局前先连一次热热身）。
- **不存盘**：免费档没有持久磁盘，**重新部署 / 重启会丢掉进行中的对局**。想留住存档就把 `render.yaml` 里两个 `plan: free` 改成 `starter`，并取消 `monopoly-api` 那段 `disk:` 的注释。

---

## 一、Docker Compose（自备机器）

```bash
git clone https://github.com/RennAkira/spicy-monopoly.git
cd spicy-monopoly

cp .env.example .env      # 按需改端口；公开部署请设 MCP_BEARER_TOKEN
docker compose up -d --build

docker compose ps         # 两个服务都该是 healthy
docker compose logs -f api
```

起完之后的地址：

| 服务 | 地址 | 用途 |
|---|---|---|
| HTTP API | `http://127.0.0.1:8069` | 把 `monopoly-API使用手册.md` 甩给 AI，接入地址填这个 |
| 远程 MCP | `http://127.0.0.1:3000/mcp` | MCP 客户端直接填这个 URL |

客户端配置（远程 MCP）：

```json
{
  "mcpServers": {
    "spicy-monopoly": {
      "type": "http",
      "url": "https://mcp.example.com/mcp"
    }
  }
}
```

设了 `MCP_BEARER_TOKEN` 的话加请求头：

```json
{
  "mcpServers": {
    "spicy-monopoly": {
      "type": "http",
      "url": "https://mcp.example.com/mcp",
      "headers": { "Authorization": "Bearer <你的token>" }
    }
  }
}
```

### 对局数据在哪

运行时产物都写在**宿主机仓库根目录**（compose 把仓库目录 bind 进了容器），
所以在宿主机上直接就能看到，容器重建也不丢：

```
monopoly-state.json          # CLI 那条玩法的当前存档
monopoly-games/              # API/MCP 各局存档
monopoly-seen/               # 跨局去重记录
monopoly-swap-log.jsonl      # 换卡日志
monopoly-feedback.jsonl      # 众包反馈
```

备份就是把这几个文件拷走。它们都在 `.gitignore` 里，`git status` 不会被弄脏。

---

## 二、宿主机直跑（不想用 Docker）

### API

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
.venv/bin/uvicorn monopoly_api:app --host 127.0.0.1 --port 8069
```

systemd：`deploy/systemd/spicy-monopoly-api.service`（安装步骤写在文件头注释里）。

### 远程 MCP

```bash
npm ci --omit=dev
SPICY_MONOPOLY_BASE_URL=http://127.0.0.1:8069 \
SPICY_MONOPOLY_MCP_HOST=127.0.0.1 PORT=3000 \
npm run mcp:http
```

systemd：`deploy/systemd/spicy-monopoly-mcp.service`。

### 只当荷官、不架服务

引擎 `monopoly_play.py` **零第三方依赖**，纯标准库。把这三个文件放进同一个目录就能跑，
连 `pip install` 都不用：

```
monopoly_play.py
monopoly-library.v2.json
monopoly-给AI的操作手册.md
```

```bash
python monopoly_play.py new "Alice:男:攻" "Bob:女:受" heavy 0.5 18
python monopoly_play.py roll
```

---

## 三、公开到外网 —— 三个必须做的

1. **HTTPS**。多数 MCP 客户端直接拒收 `http://` 的远程 URL。用 `deploy/Caddyfile`
   或 Nginx + Let's Encrypt，Caddy 会自动签证书。
2. **鉴权**。MCP 侧设 `SPICY_MONOPOLY_MCP_BEARER_TOKEN`；API 侧本身没有鉴权，
   用反代的 `basic_auth` 挡一层。**别裸奔。**
3. **SSE 不许缓冲**。反代要 `flush_interval -1`（Caddy）或：

   ```nginx
   proxy_buffering off;
   proxy_cache off;
   proxy_read_timeout 300s;
   proxy_http_version 1.1;
   proxy_set_header Connection "";
   ```

   且**不要对 MCP 的域名开 gzip**。原因见下。

### 为什么 SSE 这块值得单独说

这个服务的远程 MCP 要长时间挂着连接。作者 2026-08-02 的提交里记录过：
Cloudflare 把「静默」的连接当成死连接、约 100s 就切断，那天公开服务器
`GET /mcp` 打了 121936 次、其中有效调用只有 1549 次，平均每个完成的请求
重连 79 次。修法是每 25s 发一个 SSE 注释帧把字节续上（客户端会忽略注释帧，
协议不变）。

**自己架的时候别把这层命脉堵回去**：任何会缓冲（gzip、`proxy_buffering on`、
默认的 `flush_interval`）或提前超时（read timeout 太短）的中间层，都会让心跳
失效、回到重连地狱。

托管平台上的替代做法：把 `SPICY_MONOPOLY_MCP_JSON_RESPONSE` 设成 `true`
（`render.yaml` 里已经这么设了），走普通 JSON 响应而不是长连接的 SSE，
在 PaaS 的代理后面最稳。

---

## 四、授权提醒

本项目是 **CC BY-NC 4.0**（署名 · 非商业）。自己架来和伴侣玩没问题，
**别拿去变现**。
