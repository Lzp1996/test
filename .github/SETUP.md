# 🚀 快速启动指南

## 一、前置准备

### 1. 获取 Claude 认证凭据

Claude Code CLI 支持两种认证方式：

#### 方式一：API Key（推荐用于 CI/CD）

访问 [Anthropic Console](https://console.anthropic.com/) 注册并创建 API Key。

API Key 格式：`sk-ant-api03-xxx...`

#### 方式二：Auth Token（推荐用于长期使用）

运行 `claude setup-token` 获取长期认证 Token。

Auth Token 格式：`sk-xxx...`（与 API Key 不同）

**如果使用第三方中转服务**，获取中转地址和对应的 API Key/Token。

### 2. 配置 GitHub Secrets

进入仓库 Settings → Secrets and variables → Actions → New repository secret

**选择其中一种认证方式添加：**

**方式一：使用 API Key**
```
名称: ANTHROPIC_API_KEY
值: sk-ant-api03-xxx...
```

**方式二：使用 Auth Token**
```
名称: ANTHROPIC_AUTH_TOKEN
值: sk-xxx...
```

**如果使用中转服务，额外添加：**
```
名称: ANTHROPIC_BASE_URL
值: https://your-proxy-api.com
```

**注意**：
- 只需要配置 `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN` 其中一个
- 系统会自动检测并使用已配置的认证方式
- 如果两个都配置了，优先使用 `ANTHROPIC_AUTH_TOKEN`

### 3. 设置 GitHub Actions 权限

进入 Settings → Actions → General → Workflow permissions

选择：
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

保存更改。

### 4. 创建标签

进入 Issues → Labels → New label，创建以下标签：

| 名称 | 颜色 | 描述 |
|------|------|------|
| auto-deploy-approved | #0E8A16 (绿色) | 低风险自动部署 |
| needs-human-approval | #FBCA04 (黄色) | 需要人工确认 |
| needs-human-review | #D93F0B (红色) | 必须人工审核 |
| review-failed | #6A737D (灰色) | 审查未通过 |

## 二、验证安装

### 1. 测试 Secrets 配置

创建测试 workflow 文件 `.github/workflows/test-secrets.yml`：

```yaml
name: Test Secrets
on: workflow_dispatch

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - name: Test API Key
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
          ANTHROPIC_BASE_URL: ${{ secrets.ANTHROPIC_BASE_URL }}
        run: |
          if [ -z "$ANTHROPIC_API_KEY" ]; then
            echo "❌ ANTHROPIC_API_KEY not set"
            exit 1
          fi
          echo "✅ ANTHROPIC_API_KEY is set"
          echo "Base URL: ${ANTHROPIC_BASE_URL:-https://api.anthropic.com}"

      - name: Test Claude API
        run: |
          npm install -g @anthropic-ai/claude-code
          claude --version
```

运行：Actions → Test Secrets → Run workflow

如果显示 ✅，说明配置正确。

### 2. 测试本地脚本

```bash
# 克隆仓库
git clone <your-repo>
cd <your-repo>

# 设置环境变量（选择其中一种）

# 方式一：使用 API Key
export ANTHROPIC_API_KEY="sk-ant-api03-xxx..."

# 方式二：使用 Auth Token
export ANTHROPIC_AUTH_TOKEN="sk-xxx..."

# 可选：使用中转服务
export ANTHROPIC_BASE_URL="https://your-proxy.com"

# 创建测试 diff
echo "console.log('test')" > test.js
git add test.js
git diff --cached > /tmp/test-diff.txt

# 运行审查脚本
bash .github/scripts/claude-review.sh "1" "Test" "you" "/tmp/test-diff.txt"

# 查看结果
cat /tmp/claude-review-result.json | jq '.'
```

如果返回有效 JSON，说明脚本工作正常。

## 三、创建测试 PR

### 1. 创建测试分支

```bash
git checkout -b test-claude-review
```

### 2. 做一个低风险修改

编辑 README.md，添加一行注释：

```bash
echo "# Test Claude Review" >> README.md
git add README.md
git commit -m "test: add comment to README"
git push -u origin test-claude-review
```

### 3. 创建 PR

在 GitHub 上创建 PR：test-claude-review → master

### 4. 观察自动化流程

等待几分钟，观察：

1. ✅ PR 下方出现 Claude 审查评论
2. ✅ PR 被添加标签（应该是 `auto-deploy-approved`）
3. ✅ 出现"部署决策"评论

### 5. 合并 PR

点击 Merge pull request

等待部署完成（Actions 标签页）

访问 GitHub Pages 验证部署成功。

## 四、测试自动修复

### 1. 创建有问题的代码

```bash
git checkout -b test-auto-fix

# 创建有 lint 错误的代码（如果项目有 ESLint）
cat > src/test.js <<EOF
function test() {
    console.log("missing semicolon")
    const unused = 123
}
EOF

git add src/test.js
git commit -m "test: code with lint errors"
git push -u origin test-auto-fix
```

### 2. 创建 PR 并观察

创建 PR 后，应该看到：

1. ✅ Claude 审查评论（`passed: false`, `can_auto_fix: true`）
2. ✅ 自动修复流程启动
3. ✅ 新的 commit 被自动添加
4. ✅ 重新触发审查

## 五、测试高风险变更

### 1. 模拟高风险修改

```bash
git checkout -b test-high-risk

# 修改看起来是认证相关的文件（示例）
cat > src/auth.js <<EOF
// 修改认证逻辑
export function login(username, password) {
  // TODO: 实现登录
  return true;
}
EOF

git add src/auth.js
git commit -m "feat: update auth logic"
git push -u origin test-high-risk
```

### 2. 验证人工审核流程

创建 PR 后，应该看到：

1. ✅ Claude 审查评论（`risk_level: "high"`）
2. ✅ 添加 `needs-human-review` 标签
3. ✅ 建议人工审核

合并后，应该：
- ❌ 不会自动部署
- ✅ 出现"需要人工批准"的评论

## 六、常见问题

### Q1: Claude API 调用失败

**症状**：workflow 失败，日志显示 API 错误

**解决**：
1. 检查是否配置了 `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN`
2. 检查 `ANTHROPIC_BASE_URL` 是否可访问（如果使用中转服务）
3. 验证 API quota 是否耗尽
4. 确认认证凭据格式正确：
   - API Key: `sk-ant-api03-xxx...`
   - Auth Token: `sk-xxx...`

```bash
# 测试 API 连接（使用 API Key）
curl -X POST "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 或使用 Auth Token
curl -X POST "$ANTHROPIC_BASE_URL/v1/messages" \
  -H "x-api-key: $ANTHROPIC_AUTH_TOKEN" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{
    "model": "claude-sonnet-4-6",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

### Q2: JSON 解析失败

**症状**：`Failed to parse Claude review response`

**原因**：Claude 返回的不是纯 JSON

**解决**：
1. 检查 `/tmp/claude-review-raw.txt` 查看原始输出
2. 调整 prompt 更明确要求 JSON 输出
3. 改进 JSON 提取逻辑（使用更强大的解析器）

### Q3: 自动修复没有生效

**症状**：显示修复成功但没有新 commit

**解决**：
1. 检查 git config 是否正确
2. 确认 GitHub Token 有 write 权限
3. 查看 `/tmp/claude-fix.log` 日志

### Q4: 部署没有触发

**症状**：PR 合并后没有部署

**解决**：
1. 检查 PR 是否有 `auto-deploy-approved` 标签
2. 查看 deploy workflow 的 `check-approval` job 日志
3. 确认 workflow 权限配置正确

## 七、调优建议

### 1. 调整风险阈值

编辑 `.github/scripts/claude-review.sh` 中的 prompt，调整风险判断标准。

### 2. 限制自动部署范围

如果不想自动部署，注释掉 `deploy.yml` 中的自动触发逻辑：

```yaml
# on:
#   pull_request:
#     types: [closed]
```

仅保留手动触发：

```yaml
on:
  workflow_dispatch:
```

### 3. 添加通知

在 workflow 中添加 Slack/Discord/Email 通知：

```yaml
- name: Notify on Slack
  if: success()
  uses: slackapi/slack-github-action@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    payload: |
      {
        "text": "Claude reviewed PR #${{ github.event.pull_request.number }}"
      }
```

### 4. 性能优化

对于超大 PR，添加 diff 大小检查：

```bash
DIFF_SIZE=$(wc -l < "${DIFF_FILE}")
if [ ${DIFF_SIZE} -gt 1000 ]; then
  echo "⚠️ PR too large, skipping auto-review"
  exit 0
fi
```

## 八、监控和维护

### 1. 定期检查

- 📊 每周查看 Actions 运行情况
- 📊 统计自动部署成功率
- 📊 分析 Claude 审查准确性
- 📊 监控 API 使用量和成本

### 2. 日志保留

所有审查结果会作为 artifact 保存 30 天，可以下载分析：

Actions → Workflow run → Artifacts → claude-review-result

### 3. 持续改进

根据实际使用情况调整：
- 风险判断标准
- 自动修复策略
- 部署决策逻辑

---

**完成！** 现在你的仓库已经配置好 GitHub + Claude 自动化审查和部署系统。

有问题查看 [CONFIG.md](./CONFIG.md) 了解更多配置细节。
