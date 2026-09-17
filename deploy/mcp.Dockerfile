# syntax=docker/dockerfile:1
#
# 涩涩大富翁 —— 远程 MCP 镜像（mcp-server.js）
#
# 同时兼容较新的 Streamable HTTP 和旧式 HTTP+SSE 客户端，
# 默认把请求转发到同一 compose 网络里的 api 服务。
#
# 构建： docker build -f deploy/mcp.Dockerfile -t spicy-monopoly-mcp .
# 运行： docker run --rm -p 127.0.0.1:3000:3000 \
#          -e SPICY_MONOPOLY_BASE_URL=https://spicy-monopoly.lol \
#          spicy-monopoly-mcp

FROM node:20-slim

# 端口【故意不在这里固定】：mcp-server.js 支持 SPICY_MONOPOLY_MCP_PORT，
# 且会回退到通用的 PORT；托管平台（Render / Heroku / Fly 等）只会把服务
# 暴露在它自己注入的 PORT 上，Dockerfile 里写死一个端口就会对不上。
# compose 那条路由 docker-compose.yml 显式传 SPICY_MONOPOLY_MCP_PORT=3000。
ENV NODE_ENV=production \
    SPICY_MONOPOLY_MCP_TRANSPORT=http \
    SPICY_MONOPOLY_MCP_HOST=0.0.0.0 \
    SPICY_MONOPOLY_BASE_URL=http://api:8069 \
    TZ=Asia/Shanghai

WORKDIR /app

# 依赖单独一层（npm ci 需要 package-lock.json，本仓库有）
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# .dockerignore 已经把 node_modules 挡在上下文外，所以这步不会覆盖上面装好的依赖
COPY . .

# 文档性质：实际监听端口以 SPICY_MONOPOLY_MCP_PORT / PORT 为准，默认 3000
EXPOSE 3000

CMD ["node", "./mcp-server.js", "--http"]
