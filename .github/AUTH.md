# Claude 认证配置指南

## 支持的认证方式

Claude Code CLI 在 GitHub Actions 中支持两种认证方式：

### 方式一：ANTHROPIC_API_KEY（推荐用于 CI/CD）

**格式：** `sk-ant-api03-xxx...`

**获取方式：**
1. 访问 [Anthropic Console](https://console.anthropic.com/)
2. 注册账号并登录
3. 进入 API Keys 页面
4. 创建新的 API Key
5. 复制 Key（格式：`sk-ant-api03-xxx...`）

**优点：**
- ✅ 标准 API 认证方式
- ✅ 易于管理和轮换
- ✅ 支持所有 Claude API 功能
- ✅ 适合团队共享使用

**缺点：**
- ⚠️ 需要 Anthropic 账号
- ⚠️ 可能有 API quota 限制

### 方式二：ANTHROPIC_AUTH_TOKEN（推荐用于长期使用）

**格式：** `sk-xxx...`（不同于 API Key 的格式）

**获取方式：**
1. 本地安装 Claude Code CLI：`npm install -g @anthropic-ai/claude-code`
2. 运行认证命令：`claude setup-token`
3. 按提示登录并授权
4. 复制生成的 Token

**优点：**
- ✅ 长期有效（不需要频繁更新）
- ✅ 与 Claude 订阅绑定
- ✅ 更适合个人持续使用

**缺点：**
- ⚠️ 需要 Claude 订阅
- ⚠️ Token 泄露风险更高（长期有效）

## 使用第三方中转服务

如果使用第三方 API 中转服务（如国内代理），需要额外配置：

**ANTHROPIC_BASE_URL**
- 格式：`https://your-proxy-api.com`
- 用途：将 API 请求转发到指定的代理服务器
- 示例：`https://www.hotaitool.net`

**注意事项：**
- ✅ 确保代理服务可信
- ✅ 代理服务必须支持 Claude API 格式
- ✅ 检查代理服务的认证方式（API Key 还是 Token）

## GitHub Secrets 配置

### 配置步骤

1. 进入仓库页面
2. Settings → Secrets and variables → Actions
3. 点击 "New repository secret"
4. 添加以下 secrets

### 配置选项

**选项 A：使用 API Key（推荐）**
```yaml
ANTHROPIC_API_KEY: sk-ant-api03-xxx...
ANTHROPIC_BASE_URL: https://api.anthropic.com  # 可选，默认值
```

**选项 B：使用 Auth Token**
```yaml
ANTHROPIC_AUTH_TOKEN: sk-xxx...
ANTHROPIC_BASE_URL: https://api.anthropic.com  # 可选，默认值
```

**选项 C：使用中转服务**
```yaml
# 使用 API Key + 中转
ANTHROPIC_API_KEY: your-proxy-api-key
ANTHROPIC_BASE_URL: https://your-proxy.com

# 或使用 Auth Token + 中转
ANTHROPIC_AUTH_TOKEN: your-proxy-token
ANTHROPIC_BASE_URL: https://your-proxy.com
```

### 优先级规则

如果同时配置了 `ANTHROPIC_API_KEY` 和 `ANTHROPIC_AUTH_TOKEN`：

```
ANTHROPIC_AUTH_TOKEN 优先级更高
    ↓
系统会优先使用 ANTHROPIC_AUTH_TOKEN
    ↓
ANTHROPIC_API_KEY 会被忽略
```

**建议：** 只配置其中一个，避免混淆。

## 验证配置

### 方法一：运行测试 Workflow

```bash
# 在 GitHub 网页
Actions → Test Claude API Configuration → Run workflow
```

测试会验证：
- ✅ 认证凭据是否存在
- ✅ 认证凭据格式是否正确
- ✅ API 连接是否成功
- ✅ Claude Code CLI 是否正常工作

### 方法二：本地测试

```bash
# 设置环境变量
export ANTHROPIC_API_KEY="sk-ant-api03-xxx..."
# 或
export ANTHROPIC_AUTH_TOKEN="sk-xxx..."

# 可选
export ANTHROPIC_BASE_URL="https://your-proxy.com"

# 测试 API 连接
curl -X POST "${ANTHROPIC_BASE_URL:-https://api.anthropic.com}/v1/messages" \
  -H "x-api-key: ${ANTHROPIC_AUTH_TOKEN:-$ANTHROPIC_API_KEY}" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 10,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

如果返回 200 和有效 JSON，说明配置正确。

## 常见问题

### Q1: 我应该使用哪种认证方式？

| 场景 | 推荐方式 |
|------|----------|
| 团队 CI/CD | `ANTHROPIC_API_KEY` |
| 个人项目 | `ANTHROPIC_AUTH_TOKEN` |
| 使用中转服务 | 取决于中转服务支持的方式 |
| 临时测试 | `ANTHROPIC_API_KEY` |

### Q2: 如何获取 Auth Token？

```bash
# 安装 Claude Code CLI
npm install -g @anthropic-ai/claude-code

# 设置 Token
claude setup-token

# 按提示操作，完成后 Token 会显示在终端
```

### Q3: 中转服务需要什么格式的认证？

不同的中转服务可能有不同的要求：

- 有些支持标准的 `ANTHROPIC_API_KEY`
- 有些使用自己的 Token 格式
- 有些需要额外的认证 header

**建议**：查看中转服务的文档，确认支持的认证方式。

### Q4: 如何切换认证方式？

```bash
# 在 GitHub Secrets 中
1. 删除旧的 Secret（ANTHROPIC_API_KEY 或 ANTHROPIC_AUTH_TOKEN）
2. 添加新的 Secret
3. 重新运行 workflow

# 不需要修改任何代码，workflows 会自动检测
```

### Q5: Token 泄露了怎么办？

**ANTHROPIC_API_KEY 泄露：**
1. 立即访问 [Anthropic Console](https://console.anthropic.com/)
2. 删除泄露的 API Key
3. 创建新的 API Key
4. 更新 GitHub Secrets

**ANTHROPIC_AUTH_TOKEN 泄露：**
1. 运行 `claude auth logout`
2. 运行 `claude setup-token` 重新生成
3. 更新 GitHub Secrets

### Q6: 如何检查当前使用的认证方式？

查看 workflow 日志中的 "Configure Claude environment" 步骤：

```
✅ Using ANTHROPIC_AUTH_TOKEN
# 或
✅ Using ANTHROPIC_API_KEY
```

## 安全最佳实践

### 保护认证凭据

- ✅ 永远不要将 API Key/Token 提交到代码仓库
- ✅ 使用 GitHub Secrets 存储敏感信息
- ✅ 定期轮换 API Key（建议每 90 天）
- ✅ 使用最小权限原则
- ✅ 启用 IP 白名单（如果服务支持）

### 监控使用情况

- ✅ 定期检查 API 使用量
- ✅ 设置预算告警
- ✅ 监控异常调用模式
- ✅ 审计 API Key 访问日志

### 团队管理

- ✅ 为不同环境使用不同的 API Key（dev/staging/prod）
- ✅ 使用团队账号而不是个人账号
- ✅ 记录 API Key 的创建和轮换历史
- ✅ 离职人员及时撤销访问权限

## 成本估算

基于 Claude API 定价（示例，实际以官网为准）：

```
审查频率: 10 PR/天
每次审查: ~15k tokens
Token 价格: ~$3/million tokens

月成本估算:
10 PR/天 × 30天 × 15k tokens = 4.5M tokens/月
4.5M × $3/M = $13.5/月
```

**节省成本建议：**
- 对超大 PR（>1000 行）跳过自动审查
- 使用 Claude Haiku 进行初步筛选
- 缓存常见审查结果
- 限制自动修复重试次数

## 技术支持

遇到认证问题？

1. 查看 [SETUP.md](./SETUP.md) 快速启动指南
2. 查看 [CONFIG.md](./CONFIG.md) 详细配置
3. 运行测试 workflow 诊断问题
4. 查看 workflow 日志中的错误信息
5. 提交 Issue 寻求帮助

---

**提示**：本文档会随着 Claude API 的更新而调整，请定期检查最新版本。
