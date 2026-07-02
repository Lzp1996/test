# GitHub + Claude Bot 自动化配置指南

## 🎯 系统架构

```
PR 提交
    ↓
check-skip-review（检查跳过标签）
    ↓
    ├─ 跳过 → 自动合并部署
    ├─ 低风险 + 通过 → 自动部署
    ├─ 可自动修复 → Claude 修复 → 重新审查
    └─ 高风险/修复失败 → 人工审核
```

## 📋 必需配置

### 1. GitHub Secrets 配置

在仓库的 Settings → Secrets and variables → Actions 中添加：

**认证配置（选择其中一种）：**

```bash
# 方式一：使用 API Key（推荐用于 CI/CD）
ANTHROPIC_API_KEY=sk-ant-api03-xxx...

# 方式二：使用 Auth Token（推荐用于长期使用）
ANTHROPIC_AUTH_TOKEN=sk-xxx...

# 可选：第三方中转地址
ANTHROPIC_BASE_URL=https://your-proxy.com
```

**认证方式说明：**

| 方式 | 格式 | 获取方法 | 适用场景 |
|------|------|----------|----------|
| **API Key** | `sk-ant-api03-xxx...` | [Anthropic Console](https://console.anthropic.com/) | CI/CD、自动化脚本 |
| **Auth Token** | `sk-xxx...` | `claude setup-token` 命令 | 长期使用、本地开发 |

**优先级：** 如果同时配置了两者，系统会优先使用 `ANTHROPIC_AUTH_TOKEN`

### 2. GitHub 权限配置

确保 GitHub Actions 有以下权限（Settings → Actions → General）：

- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests

### 3. 创建所需标签

在仓库中创建以下标签（Issues → Labels）：

- `auto-deploy-approved` - 绿色 - 低风险自动部署（审查通过或跳过后添加）
- `needs-human-approval` - 黄色 - 需要人工确认
- `needs-human-review` - 红色 - 必须人工审核
- `review-failed` - 灰色 - 审查未通过

**可选（跳过审查，见 [SKIP-REVIEW.md](./SKIP-REVIEW.md)）：**

- `skip-claude-review` - 蓝色 - 跳过 Claude 审查
- `skip-review` - 蓝色 - 跳过 Claude 审查
- `auto-merge-approved` - 蓝色 - 触发跳过（与 `auto-deploy-approved` 不同）

## 🔄 工作流程说明

### Job 结构（pr-review.yml）

```
check-skip-review  →  检查是否跳过审查
       ↓
  ┌────┴────┐
  │ 跳过?   │
  └────┬────┘
   是  │  否
       │   ↓
       │  claude-review  →  Claude 审查 + 评论 + 上传 artifact
       │       ↓
       │  auto-fix（条件触发）→  自动修复 + 推送
       ↓       ↓
     decision  →  部署决策 + 自动合并（低风险或跳过）
```

### 跳过审查（check-skip-review job）

PR 满足以下**任一**条件时跳过 Claude 审查，直接进入自动合并：

**PR 标题标签**（需包含方括号）：
- `[skip-review]`
- `[deploy-direct]`
- `[trusted]`

**PR 标签**：
- `skip-claude-review`
- `skip-review`
- `auto-merge-approved`（触发跳过，与决策输出的 `auto-deploy-approved` 不同）

跳过时会：
1. 在 PR 中评论跳过原因
2. `decision` job 添加 `auto-deploy-approved` 标签
3. 触发自动合并和部署

详细用法见 [SKIP-REVIEW.md](./SKIP-REVIEW.md)

### PR 审查流程（claude-review job）

1. **触发条件**：`check-skip-review` 输出 `should-skip == false`
2. **审查步骤**：
   - 生成 PR diff（唯一临时文件路径）
   - Claude Code headless 分析代码（`claude-sonnet-4-6`）
   - 返回结构化 JSON 结果
   - 在 PR 中评论审查报告
   - 上传 artifact（保留 7 天，名称含 PR 编号和 Run ID）

3. **JSON 输出格式**：
```json
{
  "passed": true/false,
  "risk_level": "low/medium/high",
  "can_auto_fix": true/false,
  "needs_human_review": true/false,
  "max_fix_attempts": 0-3,
  "issues": ["问题1", "问题2"],
  "suggestions": ["建议1", "建议2"],
  "files_changed": 5,
  "lines_added": 100,
  "lines_deleted": 20,
  "auto_decision": "自动化决策说明",
  "commit_info": {
    "original_message": "commit message",
    "is_manual_commit": true/false
  }
}
```

### 自动修复流程（auto-fix job）

**触发条件**：
- 未跳过审查 + 审查未通过 + 可自动修复 + 不需要人工审核

**执行步骤**：
1. 下载审查结果 artifact
2. Claude Code 自动修复代码
3. 运行 lint 验证
4. 检测远程分支是否有新提交，如有则 stash + rebase
5. 提交并推送修复（触发重新审查）
6. 评论修复结果（成功 / 失败 / 冲突）

**重试机制**：
- 最多重试 `max_fix_attempts` 次
- 每次修复后运行 lint 检查
- lint 失败则 `git reset --hard HEAD` 回滚并重试
- 全部失败则标记为需要人工介入

**冲突处理**：
- 推送前检测远程分支是否有新提交
- 尝试 stash → rebase → stash pop
- rebase 冲突或推送失败时，在 PR 中评论并标记需要人工介入

### 并发控制

`pr-review.yml` 配置了 concurrency，同一 PR 分支的 workflow 不会并行运行：

```yaml
concurrency:
  group: pr-review-${{ github.event.pull_request.head.ref }}
  cancel-in-progress: false  # 排队等待，不取消正在运行的
```

### 临时文件命名

脚本和 workflow 使用 PR 编号 + Run ID 创建唯一临时文件，避免并发冲突：

```bash
TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${GITHUB_RUN_ID:-$$}"
```

| 文件 | 路径 |
|------|------|
| 审查 prompt | `${TMP_PREFIX}-review-prompt.txt` |
| 审查原始输出 | `${TMP_PREFIX}-claude-review-raw.txt` |
| 审查日志 | `${TMP_PREFIX}-claude-review.log` |
| 审查 JSON 结果 | `${TMP_PREFIX}-claude-review-result.json` → 复制到 `/tmp/claude-review-result.json` |
| 修复 prompt | `${TMP_PREFIX}-fix-prompt.txt` |
| 修复日志 | `${TMP_PREFIX}-claude-fix.log` |
| 修复摘要 | `${TMP_PREFIX}-fix-summary.txt` → 复制到 `/tmp/fix-summary.txt` |

本地测试时 `GITHUB_RUN_ID` 未设置，会使用 shell PID（`$$`）作为后缀。

### 决策流程（decision job）

`decision` job 在 `check-skip-review` 完成后始终运行（`if: always() && !cancelled()`）。

根据审查结果或跳过状态自动决策：

| 条件 | 决策 | 标签 |
|------|------|------|
| 跳过审查 | ✅ 跳过审查 - 自动部署 | `auto-deploy-approved` |
| 通过 + 低风险 + 无需人工 | ✅ 自动部署 | `auto-deploy-approved` |
| 通过 + 中等风险 | ⚠️ 需要确认 | `needs-human-approval` |
| 高风险 或 需要人工 | 🔴 必须审核 | `needs-human-review` |
| 未通过 | ❌ 审查失败 | `review-failed` |

### 部署流程（deploy.yml）

**触发条件**：
- 直接 push 到 master → 自动部署
- PR 合并到 master → 检查标签
  - 有 `auto-deploy-approved` → 自动部署
  - 无标签 → 跳过部署（评论通知）
- 手动触发 → 自动部署

## 🛡️ 风险级别定义

### Low（低风险）- 可自动部署
- ✅ CSS/样式修改
- ✅ 配置文件调整（非敏感）
- ✅ 文档更新
- ✅ 注释修改
- ✅ 格式化调整
- ✅ 拼写错误修正

### Medium（中等风险）- 需要确认
- ⚠️ 非关键路径的逻辑修改
- ⚠️ 有完整测试的新功能
- ⚠️ 代码重构
- ⚠️ 依赖升级（小版本）

### High（高风险）- 必须人工审核
- 🔴 安全相关代码
- 🔴 认证/授权逻辑
- 🔴 数据库迁移
- 🔴 API 破坏性变更
- 🔴 依赖升级（大版本）
- 🔴 外部服务集成
- 🔴 无测试的新功能

## 🔧 本地测试

### 测试审查脚本

```bash
# 生成测试 diff
git diff HEAD~1 > /tmp/test-diff.txt

# 设置环境变量
export ANTHROPIC_API_KEY="sk-ant-xxx..."
export ANTHROPIC_BASE_URL="https://your-proxy.com"  # 可选

# 运行审查
bash .github/scripts/claude-review.sh \
  "123" \
  "Test PR" \
  "username" \
  "/tmp/test-diff.txt"

# 查看结果
cat /tmp/claude-review-result.json | jq '.'
```

### 测试修复脚本

```bash
# 创建测试审查结果
cat > /tmp/test-review.json <<EOF
{
  "passed": false,
  "risk_level": "low",
  "can_auto_fix": true,
  "needs_human_review": false,
  "max_fix_attempts": 2,
  "issues": ["Missing semicolons", "Unused imports"],
  "suggestions": ["Add semicolons", "Remove unused imports"]
}
EOF

# 运行修复
bash .github/scripts/claude-fix.sh \
  "/tmp/test-review.json" \
  "123"
```

## 📊 监控和调试

### 查看 Workflow 运行日志

1. GitHub → Actions 标签页
2. 选择具体的 workflow run
3. 查看每个 job 的详细日志

### 常见问题排查

**问题：Claude API 调用失败**
```bash
# 检查日志文件（替换 PR_NUMBER 和 RUN_ID 为实际值）
TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${RUN_ID}"
cat ${TMP_PREFIX}-claude-review.log

# 验证 API Key
curl -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     $ANTHROPIC_BASE_URL/v1/messages
```

**问题：JSON 解析失败**
```bash
TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${RUN_ID}"
# 查看原始输出
cat ${TMP_PREFIX}-claude-review-raw.txt

# 手动提取 JSON
grep -o '{.*}' ${TMP_PREFIX}-claude-review-raw.txt | jq '.'
```

**问题：自动修复失败**
```bash
TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${RUN_ID}"
# 查看修复日志
cat ${TMP_PREFIX}-claude-fix.log

# 检查 lint 配置
npm run lint -- --debug
```

**问题：自动修复冲突**
- 症状：PR 中出现「自动修复冲突」评论
- 原因：推送修复时远程分支已有新提交，rebase 失败
- 解决：手动解决冲突后重新触发审查，或关闭并重新打开 PR

## 🚀 使用示例

### 场景1：低风险样式修改

1. 提交 PR 修改 CSS
2. Claude 审查：`risk_level: "low"`, `passed: true`
3. 自动添加 `auto-deploy-approved` 标签
4. 合并 PR
5. 自动部署到 GitHub Pages ✅

### 场景2：有 lint 错误的代码

1. 提交 PR，代码有格式问题
2. Claude 审查：`passed: false`, `can_auto_fix: true`
3. 自动修复流程启动
4. Claude 修复代码并提交
5. 重新触发审查
6. 审查通过 → 自动部署 ✅

### 场景3：高风险变更

1. 提交 PR 修改认证逻辑
2. Claude 审查：`risk_level: "high"`
3. 添加 `needs-human-review` 标签
4. 人工审查代码
5. 人工批准并合并
6. 自动部署 ✅

## ⚠️ 重要注意事项

### 安全性

1. **API Key 保护**：永远不要将 API Key 提交到代码仓库
2. **第三方中转**：如果使用代理，确保代理服务可信
3. **权限最小化**：GitHub Token 仅授予必需权限
4. **审计日志**：定期检查 Actions 运行日志

### 成本控制

1. **Token 消耗**：每次审查约消耗 5k-20k tokens
2. **成本估算**：
   - 10 次 PR/天 × 15k tokens × $3/million tokens = $0.45/天
   - 约 $13.5/月
3. **优化建议**：
   - 设置 diff 大小限制（超大 PR 跳过自动审查）
   - 使用 Claude Haiku 进行初步筛选
   - 缓存常见审查结果

### 可靠性

1. **失败回退**：任何自动化失败都应该回退到人工审核
2. **通知机制**：关键决策都应该发送通知
3. **审计追踪**：保留所有审查和修复记录（artifacts，7 天）
4. **测试覆盖**：确保有完整的测试套件作为安全网

## 🎓 最佳实践

### 代码审查

- ✅ 保持 PR 小而专注（<500行变更）
- ✅ 包含清晰的 PR 描述
- ✅ 为新功能添加测试
- ✅ 遵循项目代码规范

### 自动化决策

- ✅ 宁可保守，不要激进
- ✅ 不确定的情况下总是要求人工审核
- ✅ 记录所有自动决策的依据
- ✅ 定期回顾自动化决策的准确性

### 渐进式采用

1. **第一阶段**：仅审查，不自动合并/部署
2. **第二阶段**：低风险变更自动部署，记录并观察
3. **第三阶段**：根据数据调整风险阈值
4. **第四阶段**：启用自动修复功能

## 📈 效果预期

### 可以实现0人工的场景

- ✅ 文档更新
- ✅ CSS/样式调整
- ✅ 配置文件微调
- ✅ 格式化和 lint 修复
- ✅ 依赖版本锁定更新

### 仍需人工介入的场景

- ⚠️ 复杂业务逻辑变更
- ⚠️ 安全敏感代码
- ⚠️ 架构级别重构
- ⚠️ 新的第三方集成
- ⚠️ 数据库模式变更

### 预期效果

- 📊 60-70% 的 PR 可以自动审查
- 📊 30-40% 的低风险 PR 可以自动部署
- 📊 节省 50%+ 的代码审查时间
- 📊 减少 80%+ 的格式/lint 问题

## 🔮 后续优化方向

1. **智能学习**：根据历史审查结果优化风险判断
2. **多级审查**：Haiku 初筛 → Sonnet 详细审查
3. **测试生成**：自动为新功能生成测试用例
4. **性能分析**：自动检测性能回归
5. **安全扫描**：集成 SAST/DAST 工具
6. **A/B 测试**：自动部署到 staging 环境验证

---

**问题反馈**：如有问题请提交 Issue 或联系团队
