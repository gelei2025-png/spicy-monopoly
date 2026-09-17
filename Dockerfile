# syntax=docker/dockerfile:1
#
# 涩涩大富翁 —— HTTP API 镜像（monopoly_api.py，FastAPI）
#
# 注意：游戏引擎 monopoly_play.py 本身零第三方依赖，只是「用源码甩给 AI 跑」
# 那条玩法的话根本不需要这个镜像；这个镜像只服务「自建 API」那条路。
#
# 构建： docker build -t spicy-monopoly-api .
# 运行： docker run --rm -p 127.0.0.1:8069:8069 spicy-monopoly-api
# compose：见仓库根目录 docker-compose.yml

FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    TZ=Asia/Shanghai

WORKDIR /app

# 依赖单独一层，改代码时不用重装
COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt

COPY . .

# 容器内监听 0.0.0.0，只在容器网络里可见；
# 宿主机怎么映射端口由 docker-compose.yml 决定（默认限成 127.0.0.1）。
EXPOSE 8069

CMD ["uvicorn", "monopoly_api:app", "--host", "0.0.0.0", "--port", "8069"]
