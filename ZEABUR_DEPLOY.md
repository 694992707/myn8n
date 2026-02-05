# Zeabur 部署指南

## 部署方式

### 方式 1: 通过 Git 仓库部署 (推荐)

1. **推送代码到 Git 仓库**
   ```bash
   git add .
   git commit -m "feat: add AI builder support"
   git push origin master
   ```

2. **在 Zeabur 创建项目**
   - 登录 [Zeabur Dashboard](https://dash.zeabur.com)
   - 点击 "New Project"
   - 选择区域 (推荐选择离你最近的)

3. **添加服务**
   - 点击 "Add Service" → "Git"
   - 连接你的 GitHub/GitLab 账号
   - 选择此仓库
   - Zeabur 会读取 `zeabur.json` 并使用 `Dockerfile` (忽略 `Dockerfile.zeabur`)

4. **配置环境变量**
   在服务设置中添加:

   | 变量名 | 值 |
   |--------|-----|
   | `N8N_AI_ENABLED` | `true` |
   | `N8N_AI_ANTHROPIC_KEY` | 你的 API Key |
   | `N8N_AI_ASSISTANT_BASE_URL` | `https://api.anthropic.com` |
   | `N8N_AI_MODEL_NAME` | `claude-sonnet-4-5-20250929` |
   | `N8N_AI_PROVIDER` | `anthropic` |

5. **添加持久化存储**
   - 点击服务 → "Storage"
   - 挂载路径: `/home/node/.n8n`

6. **绑定域名**
   - 点击 "Networking" → "Add Domain"
   - 使用 Zeabur 提供的域名或绑定自定义域名

### 方式 2: 通过 Docker 镜像部署

1. **本地构建并推送镜像**
   ```bash
   # 构建镜像
   docker build -f Dockerfile -t your-registry/n8n-custom:latest .

   # 推送到 Docker Hub 或其他 Registry
   docker push your-registry/n8n-custom:latest
   ```

2. **在 Zeabur 部署**
   - "Add Service" → "Prebuilt Image"
   - 输入镜像地址: `your-registry/n8n-custom:latest`
   - 配置环境变量和存储

---

## 环境变量配置

### 必需变量

```
N8N_AI_ENABLED=true
N8N_AI_ANTHROPIC_KEY=sk-xxx-your-api-key
N8N_AI_ASSISTANT_BASE_URL=https://api.anthropic.com
```

### 可选变量

```
# 自定义模型
N8N_AI_MODEL_NAME=claude-sonnet-4-5-20250929

# 切换协议类型
N8N_AI_PROVIDER=anthropic   # 或 openai

# Webhook URL (Zeabur 会自动设置)
WEBHOOK_URL=https://your-domain.zeabur.app/
```

### 使用第三方 API 示例

**OpenAI:**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.openai.com/v1
N8N_AI_PROVIDER=openai
N8N_AI_MODEL_NAME=gpt-4o
N8N_AI_ANTHROPIC_KEY=sk-xxxx  # OpenAI API Key
```

**Moonshot/Kimi:**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.moonshot.cn/v1
N8N_AI_PROVIDER=openai
N8N_AI_MODEL_NAME=moonshot-v1-128k
N8N_AI_ANTHROPIC_KEY=sk-xxxx
```

**DeepSeek:**
```
N8N_AI_ASSISTANT_BASE_URL=https://api.deepseek.com
N8N_AI_PROVIDER=openai
N8N_AI_MODEL_NAME=deepseek-chat
N8N_AI_ANTHROPIC_KEY=sk-xxxx
```

---

## 资源配置建议

| 资源 | 最小配置 | 推荐配置 |
|------|----------|----------|
| CPU | 0.5 核 | 1 核 |
| 内存 | 512MB | 1GB |
| 存储 | 1GB | 5GB |

在 Zeabur 服务设置中可以调整资源配额。

---

## 验证部署

1. 访问 Zeabur 分配的域名
2. 创建管理员账号完成初始化
3. 进入工作流编辑器
4. 右下角应显示 AI 星星图标
5. 点击测试 AI Builder 功能

---

## 常见问题

### Q: 构建超时?
Zeabur 默认构建超时为 30 分钟，n8n 构建较大。可以:
- 在 Zeabur 设置中增加构建超时时间
- 使用方式 2 预构建镜像部署

### Q: 内存不足?
增加服务的内存配额，建议至少 1GB。

### Q: 数据丢失?
确保已配置持久化存储挂载到 `/home/node/.n8n`。

### Q: AI 功能不工作?
1. 检查环境变量是否正确设置
2. 查看服务日志排查错误
3. 确认 API Key 有效且有额度
