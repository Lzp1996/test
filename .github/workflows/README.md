# Workflows 说明

这个目录包含所有的 GitHub Actions workflows。

## 工作流列表

### 1. pr-review.yml - PR 自动审查
**触发条件：** PR 创建、更新或重新打开

**Job 结构：**

| Job | 条件 | 说明 |
|-----|------|------|
| `check-skip-review` | 始终运行 | 检查标题/标签是否跳过审查 |
| `claude-review` | 未跳过 | Claude 审查 + 评论 + artifact |
| `auto-fix` | 未跳过 + 可修复 | 自动修复并推送 |
| `decision` | 始终运行 | 部署决策 + 自动合并 |

**跳过审查：** PR 标题含 `[skip-review]` 等标签，或 PR 标签为 `skip-claude-review` / `skip-review` / `auto-merge-approved` 时，跳过 Claude 审查直接进入自动合并。详见 [SKIP-REVIEW.md](../SKIP-REVIEW.md)

**并发控制：**
- 同一 PR 分支的 workflow 排队执行，不会并行运行
- `cancel-in-progress: false`（等待而非取消正在运行的实例）

**功能：**
- 使用 Claude Code 审查代码（`claude-sonnet-4-6`）
- 返回结构化的 JSON 审查结果
- 自动评论审查报告到 PR
- 添加相应的标签
- 触发自动修复（如果需要）
- 低风险 PR 自动合并

**Artifact：**
- 名称：`claude-review-result-pr-{number}-{run_id}`
- 保留：7 天

**使用的 Secrets：**
- `ANTHROPIC_API_KEY` 或 `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_BASE_URL`（可选）

### 2. deploy.yml - 自动部署
**触发条件：**
- Push 到 master 分支
- PR 合并到 master（需要 `auto-deploy-approved` 标签）
- 手动触发

**功能：**
- 构建 Vue 应用
- 验证构建完整性
- 备份构建产物（artifact 保留 7 天）
- 部署到 GitHub Pages
- 健康检查
- 创建部署标签
- 失败时提示回滚

### 3. rollback.yml - 手动回滚
**触发条件：** 手动触发

**输入参数：**
- `target`: 回滚目标（`last`、tag 名称或 commit SHA）
- `skip-health-check`: 是否跳过健康检查

**功能：**
- 回滚到指定版本
- 重新构建和部署
- 健康检查
- 创建回滚标签
- 创建 Issue 记录回滚操作

### 4. test-secrets.yml - API 配置测试
**触发条件：** 手动触发

**功能：**
- 检查认证 Secrets 是否配置
- 测试 Claude API 连接
- 验证 Claude Code CLI 安装
- 显示配置状态

## 使用说明

### 本地测试 workflow

```bash
# 使用 act 工具在本地测试
npm install -g @nektos/act

# 测试 PR 审查
act pull_request -W .github/workflows/pr-review.yml

# 测试部署
act push -W .github/workflows/deploy.yml
```

### 手动触发 workflow

```bash
# 使用 GitHub CLI
gh workflow run test-secrets.yml
gh workflow run rollback.yml -f target=last

# 或在 GitHub 网页
Actions → 选择 workflow → Run workflow
```

### 查看 workflow 运行状态

```bash
# 列出最近的运行
gh run list --workflow=pr-review.yml --limit 10

# 查看特定运行的日志
gh run view <run-id> --log

# 下载 artifacts
gh run download <run-id>
```

## Workflow 依赖

所有 workflows 都需要：
- Node.js 22
- npm
- Claude Code CLI

PR 审查和自动修复还需要：
- 有效的 Claude API 认证
- 足够的 API quota

### 临时文件

脚本使用 PR 编号 + Run ID 创建唯一临时文件前缀：

```bash
TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${GITHUB_RUN_ID:-$$}"
```

Workflow 通过标准路径读取结果：
- `/tmp/claude-review-result.json` — 审查 JSON 结果
- `/tmp/fix-summary.txt` — 修复摘要

### 自动修复冲突

auto-fix job 推送前会检测远程分支：
- 有新提交 → stash + rebase + stash pop
- rebase 冲突 → 在 PR 评论并转人工处理

## 故障排查

### Workflow 失败

1. 查看运行日志
2. 检查 Secrets 配置
3. 验证权限设置
4. 查看具体 step 的错误信息

### 认证问题

运行 `test-secrets.yml` 来诊断认证配置问题。

### 部署问题

查看 `deploy.yml` 的：
- Build step - 构建错误
- Validate build step - 验证失败
- Deploy step - 部署错误
- Health check step - 健康检查失败

### 回滚问题

查看 `rollback.yml` 的：
- Determine rollback target - 目标无效
- Build from target version - 构建失败
- Health check - 健康检查失败

## 性能优化

- 使用 `npm ci` 而不是 `npm install`（更快、更可靠）
- 启用 npm cache（已配置）
- 并行运行独立的 jobs
- 合理设置超时时间

## 安全注意事项

- 永远不要在日志中打印 Secrets
- 使用 `${{ secrets.XXX }}` 访问敏感信息
- 定期轮换 API Keys
- 审计 workflow 权限

## 更多信息

查看详细文档：
- [CONFIG.md](../CONFIG.md) - 配置说明
- [SETUP.md](../SETUP.md) - 设置指南
- [SKIP-REVIEW.md](../SKIP-REVIEW.md) - 跳过审查指南
- [FLOWCHARTS.md](../FLOWCHARTS.md) - 流程图
