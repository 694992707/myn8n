# n8n 本地构建与 Docker 部署指南

本指南说明如何从修改后的源代码构建 n8n 并部署到 Docker。

## 前置要求

- Node.js 18+ (推荐 20.x)
- pnpm 9+
- Docker & Docker Compose
- Git

## 1. 安装依赖并构建

```bash
# 进入项目目录
cd /path/to/n8n

# 安装依赖
pnpm install

# 构建项目 (将输出重定向到文件以便检查)
pnpm build > build.log 2>&1

# 检查构建是否成功
tail -n 30 build.log
```

## 2. 构建 Docker 镜像

### 方法 A: 使用官方 Dockerfile

```bash
# 在项目根目录执行
docker build -t n8n-custom:latest .
```

### 方法 B: 创建自定义 Dockerfile

如果官方 Dockerfile 不适用，创建 `Dockerfile.custom`:

```dockerfile
FROM node:20-alpine

# 安装必要的系统依赖
RUN apk add --no-cache \
    git \
    python3 \
    make \
    g++ \
    su-exec \
    tini

# 设置工作目录
WORKDIR /app

# 复制构建好的文件
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY packages ./packages

# 安装 pnpm
RUN npm install -g pnpm@9

# 安装生产依赖
RUN pnpm install --prod --frozen-lockfile

# 设置环境变量
ENV NODE_ENV=production
ENV N8N_PORT=5678

# 暴露端口
EXPOSE 5678

# 启动命令
ENTRYPOINT ["tini", "--"]
CMD ["node", "packages/cli/bin/n8n"]
```

构建镜像:
```bash
docker build -f Dockerfile.custom -t n8n-custom:latest .
```

## 3. Docker Compose 部署

创建 `docker-compose.yml`:

```yaml
version: '3.8'

services:
  n8n:
    image: n8n-custom:latest
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      # 基础配置
      - N8N_HOST=0.0.0.0
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - WEBHOOK_URL=http://localhost:5678/

      # 数据库配置 (使用 SQLite)
      - DB_TYPE=sqlite
      - DB_SQLITE_DATABASE=/home/node/.n8n/database.sqlite

      # AI 功能配置 (必须)
      - N8N_AI_ENABLED=true
      - N8N_AI_ANTHROPIC_KEY=your-api-key-here
      - N8N_AI_ASSISTANT_BASE_URL=https://api.anthropic.com

      # 可选: 自定义模型配置
      - N8N_AI_MODEL_NAME=claude-sonnet-4-5-20250929
      - N8N_AI_PROVIDER=anthropic

    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
```

启动服务:
```bash
docker-compose up -d
```

## 4. 环境变量说明

| 变量名 | 必需 | 默认值 | 说明 |
|--------|------|--------|------|
| `N8N_AI_ENABLED` | 是 | `false` | 启用 AI 模块 |
| `N8N_AI_ANTHROPIC_KEY` | 是 | - | API 密钥，设置后启用直连模式 |
| `N8N_AI_ASSISTANT_BASE_URL` | 是 | - | AI API 地址 |
| `N8N_AI_MODEL_NAME` | 否 | `claude-sonnet-4-5-20250929` | 自定义模型名称 |
| `N8N_AI_PROVIDER` | 否 | `anthropic` | 协议类型: `anthropic` 或 `openai` |

### API 地址示例

**Anthropic 官方:**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.anthropic.com
```

**OpenAI 兼容接口:**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.openai.com/v1
N8N_AI_PROVIDER=openai
N8N_AI_MODEL_NAME=gpt-4o
```

**第三方代理 (如 Moonshot/Kimi):**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.moonshot.cn
N8N_AI_PROVIDER=openai
N8N_AI_MODEL_NAME=moonshot-v1-8k
```

## 5. 验证部署

1. 访问 `http://localhost:5678`
2. 完成初始设置创建管理员账号
3. 在画布右下角应看到 **星星 (AI)** 图标
4. 点击进入 **Build** 标签页测试 AI 功能

## 6. 查看日志

```bash
# 查看容器日志
docker-compose logs -f n8n

# 确认直连成功的日志
# 应看到: [AI Builder] Initializing model...
```

## 7. 常见问题

### Q: 构建失败怎么办?
```bash
# 清理并重新构建
pnpm clean
pnpm install
pnpm build > build.log 2>&1
```

### Q: AI 图标不显示?
确保环境变量正确设置:
```bash
docker exec n8n env | grep N8N_AI
```

### Q: API 调用失败?
检查 API 密钥和 URL 是否正确:
```bash
# 测试 Anthropic API
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: YOUR_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}'
```

### Q: 如何使用 PostgreSQL?
修改 docker-compose.yml:
```yaml
services:
  postgres:
    image: postgres:15
    environment:
      - POSTGRES_USER=n8n
      - POSTGRES_PASSWORD=n8n
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data

  n8n:
    # ... 其他配置
    environment:
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=n8n
      - DB_POSTGRESDB_PASSWORD=n8n
    depends_on:
      - postgres

volumes:
  postgres_data:
  n8n_data:
```

## 8. 生产环境建议

1. 使用 HTTPS (通过反向代理如 Nginx/Traefik)
2. 配置持久化存储
3. 设置定期备份
4. 使用 PostgreSQL 替代 SQLite
5. 配置日志轮转
