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

ENV NODE_ENV=production \
    SPICY_MONOPOLY_MCP_TRANSPORT=http \
    SPICY_MONOPOLY_MCP_HOST=0.0.0.0 \
    SPICY_MONOPOLY_MCP_PORT=3000 \
    SPICY_MONOPOLY_BASE_URL=http://api:8069 \
    TZ=Asia/Shanghai

WORKDIR /app

# 依赖单独一层（npm ci 需要 package-lock.json，本仓库有）
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# .dockerignore 已经把 node_modules 挡在上下文外，所以这步不会覆盖上面装好的依赖
COPY . .

EXPOSE 3000

CMD ["node", "./mcp-server.js", "--http"]
