# GitHub + Claude Bot 自动化配置指南

## 🎯 系统架构

```
PR 提交
    ↓
Claude Code Headless 审查
    ↓
返回 JSON 结果
    ↓
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

- `auto-deploy-approved` - 绿色 - 低风险自动部署
- `needs-human-approval` - 黄色 - 需要人工确认
- `needs-human-review` - 红色 - 必须人工审核
- `review-failed` - 灰色 - 审查未通过

## 🔄 工作流程说明

### PR 审查流程（pr-review.yml）

1. **触发条件**：PR 创建、更新或重新打开
2. **审查步骤**：
   - 生成 PR diff
   - Claude Code headless 分析代码
   - 返回结构化 JSON 结果
   - 在 PR 中评论审查报告

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
- 审查未通过 + 可自动修复 + 不需要人工审核

**执行步骤**：
1. 下载审查结果
2. Claude Code 自动修复代码
3. 运行 lint 验证
4. 提交修复（触发重新审查）
5. 评论修复结果

**重试机制**：
- 最多重试 `max_fix_attempts` 次
- 每次修复后运行 lint 检查
- 失败则回滚并重试
- 全部失败则标记为需要人工介入

### 决策流程（decision job）

根据审查结果自动决策：

| 条件 | 决策 | 标签 |
|------|------|------|
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
# 检查日志文件
cat /tmp/claude-review.log

# 验证 API Key
curl -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     $ANTHROPIC_BASE_URL/v1/messages
```

**问题：JSON 解析失败**
```bash
# 查看原始输出
cat /tmp/claude-review-raw.txt

# 手动提取 JSON
grep -o '{.*}' /tmp/claude-review-raw.txt | jq '.'
```

**问题：自动修复失败**
```bash
# 查看修复日志
cat /tmp/claude-fix.log

# 检查 lint 配置
npm run lint -- --debug
```

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
3. **审计追踪**：保留所有审查和修复记录（artifacts）
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
