# Vue 项目 - 自动化 CI/CD 系统

这是一个集成了 GitHub Actions + Claude AI 的自动化代码审查和部署系统。

## ✨ 核心功能

- 🤖 **AI 代码审查** - Claude 自动审查每个 PR
- 🔧 **智能修复** - 自动修复格式和 lint 问题
- 🚀 **自动部署** - 低风险变更自动部署
- 🔄 **一键回滚** - 支持回滚到任意历史版本
- 🛡️ **多重保护** - 构建验证、健康检查、备份机制

## 📊 系统架构

```
PR 提交 → Claude 审查 → 风险评估 → 智能决策
                                      ↓
              ┌─────────────────────────┬─────────────┐
              ↓                         ↓             ↓
        低风险 + 通过              中等风险        高风险
              ↓                         ↓             ↓
          自动部署                  人工确认       人工审核
```

## 🚀 快速开始

### 1. 配置 GitHub Secrets

```bash
Settings → Secrets and variables → Actions
```

添加以下 Secrets（选择其中一种认证方式）：

```yaml
# 方式一：使用 API Key
ANTHROPIC_API_KEY: sk-ant-api03-xxx...

# 方式二：使用 Auth Token  
ANTHROPIC_AUTH_TOKEN: sk-xxx...

# 可选：使用中转服务
ANTHROPIC_BASE_URL: https://your-proxy.com
```

### 2. 设置权限

```bash
Settings → Actions → General → Workflow permissions
```

- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

### 3. 创建标签

```bash
Issues → Labels → New label
```

- `auto-deploy-approved` - 绿色
- `needs-human-approval` - 黄色
- `needs-human-review` - 红色
- `review-failed` - 灰色

### 4. 测试配置

```bash
Actions → Test Claude API Configuration → Run workflow
```

**详细设置指南** → [.github/SETUP.md](.github/SETUP.md)

## 📖 文档

| 文档 | 说明 |
|------|------|
| [SETUP.md](.github/SETUP.md) | 快速启动指南 |
| [CONFIG.md](.github/CONFIG.md) | 详细配置文档 |
| [AUTH.md](.github/AUTH.md) | 认证配置指南 |
| [ROLLBACK.md](.github/ROLLBACK.md) | 回滚操作指南 |
| [FLOWCHARTS.md](.github/FLOWCHARTS.md) | 系统流程图 |

## 🔄 工作流程

### PR 审查流程

1. 开发者创建 PR
2. Claude 自动审查代码
3. 在 PR 中评论审查结果
4. 添加相应的标签
5. 根据风险级别决策：
   - 低风险 + 通过 → 自动部署
   - 中等风险 → 需要人工确认
   - 高风险 → 必须人工审核

### 部署流程

1. PR 合并后触发部署
2. 构建并验证应用
3. 备份构建产物
4. 部署到 GitHub Pages
5. 运行健康检查
6. 创建部署标签
7. 失败时提示回滚

### 回滚流程

```bash
# GitHub Actions 手动触发
Actions → Rollback Deployment → Run workflow

# 或使用 GitHub CLI
gh workflow run rollback.yml -f target=last

# 或使用本地脚本
bash .github/scripts/quick-rollback.sh
```

## 🎯 使用示例

### 场景 1：低风险样式修改

```bash
# 1. 修改 CSS
# 2. 提交 PR
# 3. Claude 审查：low risk, passed
# 4. 自动添加 auto-deploy-approved 标签
# 5. 合并 PR
# 6. 自动部署 ✅
```

### 场景 2：代码有格式问题

```bash
# 1. 提交有 lint 错误的代码
# 2. Claude 审查：can_auto_fix: true
# 3. Claude 自动修复并提交
# 4. 重新触发审查
# 5. 审查通过 → 自动部署 ✅
```

### 场景 3：高风险变更

```bash
# 1. 修改认证逻辑
# 2. Claude 审查：high risk
# 3. 添加 needs-human-review 标签
# 4. 人工详细审核代码
# 5. 人工批准并合并
# 6. 自动部署 ✅
```

### 场景 4：部署失败回滚

```bash
# 1. 部署失败（健康检查未通过）
# 2. 系统提示可回滚版本
# 3. Actions → Rollback Deployment
# 4. 选择 target: last
# 5. 自动回滚到上一版本 ✅
```

## 🛡️ 安全特性

- ✅ 多重验证（构建、部署、健康检查）
- ✅ 自动备份（每次部署备份 30 天）
- ✅ 部署标签（可追溯所有历史版本）
- ✅ 失败回滚（一键恢复到上一版本）
- ✅ 人工门槛（高风险必须人工审核）

## 📊 预期效果

| 指标 | 目标 |
|------|------|
| 自动审查覆盖率 | 60-70% |
| 自动部署比例 | 30-40% |
| 审查时间节省 | 50%+ |
| 格式问题减少 | 80%+ |
| 平均 PR 处理时间 | 减少 40% |

## 🔧 本地开发

```bash
# 安装依赖
npm install

# 开发模式
npm run dev

# 构建
npm run build

# 预览
npm run preview

# Lint
npm run lint
```

## 🧪 测试

```bash
# 测试 API 配置
Actions → Test Claude API Configuration → Run workflow

# 本地测试审查脚本
export ANTHROPIC_AUTH_TOKEN="sk-xxx..."
bash .github/scripts/claude-review.sh "1" "Test" "you" "/tmp/test-diff.txt"

# 查看结果
cat /tmp/claude-review-result.json | jq '.'
```

## 📈 监控

### 查看部署历史

```bash
# 列出所有部署标签
git tag -l "deploy-*" --sort=-version:refname | head -n 10

# 查看最近的 workflows
gh run list --workflow=deploy.yml --limit 10

# 查看审查统计
gh run list --workflow=pr-review.yml --limit 20
```

### 成本估算

```
假设：10 PR/天，每次审查 15k tokens
月成本：10 × 30 × 15k × $3/M = ~$13.5/月
```

## ⚠️ 注意事项

### API 配额

- 定期检查 API 使用量
- 设置预算告警
- 对超大 PR 跳过自动审查

### 认证安全

- 永远不要将 API Key 提交到代码
- 定期轮换认证凭据（建议 90 天）
- 使用 GitHub Secrets 存储敏感信息

### 数据库变更

如果 PR 包含数据库迁移，回滚代码不会自动回滚数据库，需要手动处理。

## 🐛 故障排查

### Claude API 调用失败

```bash
# 检查配置
Actions → Test Claude API Configuration → Run workflow

# 查看日志
Actions → 失败的 workflow → 查看日志
```

### 部署失败

```bash
# 查看构建日志
Actions → deploy.yml → 失败的运行 → Build step

# 查看健康检查
Actions → deploy.yml → Health check step
```

### 回滚问题

```bash
# 查看可用版本
git tag -l "deploy-*" --sort=-version:refname

# 手动回滚
gh workflow run rollback.yml -f target=deploy-20260701-123456
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

在提交 PR 时，请注意：
- 保持 PR 小而专注（<500 行变更）
- 包含清晰的描述
- 为新功能添加测试
- 遵循代码规范

## 📄 许可

MIT License

## 🔗 相关链接

- [Claude API 文档](https://docs.anthropic.com/)
- [GitHub Actions 文档](https://docs.github.com/actions)
- [Claude Code CLI](https://github.com/anthropics/claude-code)

---

**Powered by**: Claude Code + GitHub Actions

如有问题，请查看 [详细文档](.github/) 或提交 Issue。
