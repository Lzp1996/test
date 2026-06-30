# PR 自动合并配置说明

## ✅ 已实现完整的 0 人工流程

当前系统**已完全实现**基于风险判断的 PR 自动合并和 CI/CD 部署。

## 🔄 完整流程

```
PR 创建
    ↓
Claude 审查（返回风险级别）
    ↓
风险判断
    ↓
    ├─ 低风险 + 通过 → 自动合并 PR → 自动部署 ✅
    ├─ 中等风险 → 添加标签，等待人工确认 ⚠️
    └─ 高风险 → 添加标签，必须人工审核 🔴
```

## 📋 自动合并条件

PR 会**自动合并**当且仅当：

1. ✅ **审查通过** - `passed: true`
2. ✅ **低风险** - `risk_level: "low"`
3. ✅ **无需人工** - `needs_human_review: false`
4. ✅ **无冲突** - PR 可以干净合并
5. ✅ **所有检查通过** - 其他 GitHub checks 通过（如果有）

**任何一个条件不满足，都不会自动合并。**

## 🎯 不同风险级别的处理

### 🟢 低风险（Low Risk）
**触发条件：**
- CSS/样式修改
- 文档更新
- 配置文件调整（非敏感）
- 注释修改
- 格式化修改

**自动化操作：**
1. ✅ Claude 审查通过
2. ✅ 添加 `auto-deploy-approved` 标签
3. ✅ **自动合并 PR**（Squash and merge）
4. ✅ 自动触发部署
5. ✅ 部署后通知

**完全 0 人工介入！**

### 🟡 中等风险（Medium Risk）
**触发条件：**
- 非关键路径的逻辑修改
- 有测试的新功能
- 代码重构

**处理流程：**
1. ✅ Claude 审查通过
2. ✅ 添加 `needs-human-approval` 标签
3. ⚠️ 等待人工确认
4. ⚠️ 人工批准后手动合并
5. ✅ 自动部署

**需要人工确认，但部署自动化。**

### 🔴 高风险（High Risk）
**触发条件：**
- 安全相关代码
- 认证/授权逻辑
- 数据库迁移
- API 破坏性变更

**处理流程：**
1. ✅ Claude 审查
2. ✅ 添加 `needs-human-review` 标签
3. 🔴 必须人工详细审核
4. 🔴 人工审核并批准
5. 🔴 人工手动合并
6. ✅ 自动部署

**安全第一，必须人工介入。**

## 🤖 自动合并配置

### 合并方式

当前配置使用 **Squash and merge**：
```javascript
merge_method: 'squash'
```

**可选项：**
- `'squash'` - 压缩所有 commits 为一个（推荐）
- `'merge'` - 保留所有 commits
- `'rebase'` - Rebase 合并

**修改方式：**
在 `.github/workflows/pr-review.yml` 的 `Auto-merge PR` 步骤中修改 `merge_method`。

### 合并消息格式

```
标题: PR标题 (#PR号)
内容: 
  Auto-merged by Claude Code automation
  
  [PR 描述]
  
  Co-Authored-By: Claude Bot <claude-bot@github.actions>
```

## ⚙️ 自定义配置

### 1. 禁用自动合并

如果你不想自动合并，只想自动添加标签：

**方式一：删除自动合并步骤**
```bash
# 编辑 .github/workflows/pr-review.yml
# 删除或注释 "Auto-merge PR" 步骤
```

**方式二：修改条件**
```yaml
# 在 Auto-merge PR 步骤中添加额外条件
if: |
  steps.make-decision.outputs.auto-merge == 'true' &&
  false  # 永远不自动合并
```

### 2. 仅特定类型 PR 自动合并

```yaml
# 仅文档更新自动合并
if: |
  steps.make-decision.outputs.auto-merge == 'true' &&
  contains(github.event.pull_request.title, 'docs:')
```

### 3. 需要特定审批者

```yaml
# 检查是否有特定用户审批
- name: Check approvals
  run: |
    # 获取审批列表
    # 检查是否包含特定用户
```

### 4. 修改风险阈值

编辑 `.github/scripts/claude-review.sh` 中的审查 prompt，调整风险判断标准：

```bash
# 示例：将某些变更从 medium 调整为 low
- MEDIUM: 小范围逻辑修改
+ LOW: 小范围逻辑修改（有测试覆盖）
```

## 🛡️ 安全机制

### 自动合并失败处理

如果自动合并失败（有冲突、检查未通过等）：

1. ❌ 自动合并失败
2. 📝 在 PR 中评论失败原因
3. 🏷️ 移除 `auto-deploy-approved` 标签
4. 🏷️ 添加 `needs-human-approval` 标签
5. ⚠️ 等待人工处理

### 防护措施

- ✅ 检查 PR 是否有冲突
- ✅ 检查 mergeable 状态
- ✅ 捕获所有合并错误
- ✅ 失败时回退到人工审核
- ✅ 详细的日志记录

### 审计追踪

每次自动合并都会：
- 📝 在 PR 中留下评论
- 🏷️ 保留所有标签历史
- 📊 在 commit message 中记录
- 🔍 在 Actions 日志中可追溯

## 📊 自动化比例预估

基于当前配置：

| 类型 | 比例 | 处理方式 |
|------|------|----------|
| **完全自动化** | 30-40% | 低风险 → 自动合并 → 自动部署 |
| **半自动化** | 40-50% | 中等风险 → 人工确认 → 自动部署 |
| **人工处理** | 10-20% | 高风险 → 人工审核 → 人工合并 → 自动部署 |

**实际比例取决于：**
- 团队的开发习惯
- PR 的平均复杂度
- 测试覆盖率
- Claude 审查的准确性

## 🧪 测试自动合并

### 创建测试 PR

```bash
# 1. 创建测试分支
git checkout -b test/auto-merge-low-risk

# 2. 做一个低风险修改（文档更新）
echo "<!-- Test auto-merge -->" >> README.md
git add README.md
git commit -m "docs: test auto-merge feature"

# 3. 推送并创建 PR
git push -u origin test/auto-merge-low-risk

# 4. 在 GitHub 创建 PR
# 观察自动化流程：
# - Claude 审查
# - 添加 auto-deploy-approved 标签
# - 自动合并 PR
# - 自动部署
```

### 验证流程

1. ✅ PR 创建后，等待 1-2 分钟
2. ✅ 查看 PR 评论，确认 Claude 审查结果
3. ✅ 查看 PR 标签，应该有 `auto-deploy-approved`
4. ✅ 观察 PR 是否自动合并（状态变为 Merged）
5. ✅ 查看 Actions，确认部署 workflow 触发
6. ✅ 访问部署 URL，验证更改已上线

### 测试场景

**场景 1：低风险 - 应该自动合并**
```bash
# 修改 CSS
echo ".test { color: red; }" >> src/style.css

# 或更新文档
echo "# Update" >> docs/guide.md
```

**场景 2：中等风险 - 不应该自动合并**
```bash
# 添加新功能
echo "export function newFeature() {}" >> src/feature.js
```

**场景 3：高风险 - 不应该自动合并**
```bash
# 修改认证逻辑
echo "// Update auth" >> src/auth.js
```

## ⚠️ 注意事项

### 1. GitHub 权限

确保 GitHub Actions 有合并 PR 的权限：

```bash
Settings → Actions → General → Workflow permissions
- ✅ Read and write permissions
- ✅ Allow GitHub Actions to create and approve pull requests
```

### 2. 分支保护规则

如果启用了分支保护，可能需要调整：

```bash
Settings → Branches → Branch protection rules → master

可能需要：
- ✅ 允许 GitHub Actions bot 绕过保护规则
- 或 配置特定的检查要求
```

### 3. 自动合并与代码审查

如果你的仓库要求代码审查：
- 选项 A：为 Claude Bot 添加例外
- 选项 B：让 Claude Bot 也算作一个 reviewer
- 选项 C：禁用自动合并，只自动添加标签

### 4. 监控和调优

定期检查：
- 📊 自动合并的成功率
- 📊 Claude 审查的准确性
- 📊 是否有误判（应该人工但自动了，或反之）
- 📊 部署失败率

根据数据调整风险判断标准。

## 🔧 故障排查

### 问题：PR 没有自动合并

**检查清单：**
1. 查看 PR 标签，是否有 `auto-deploy-approved`？
   - 没有 → Claude 判断不是低风险
   - 有 → 继续检查
2. 查看 Actions 日志，`Auto-merge PR` 步骤
   - 是否有冲突？
   - 是否有错误信息？
3. 检查权限配置
4. 检查分支保护规则

### 问题：不应该合并的被自动合并了

这是**风险判断不准确**：

1. 查看审查结果（JSON）
2. 分析为什么被判为低风险
3. 调整 `.github/scripts/claude-review.sh` 中的 prompt
4. 提高该类型变更的风险级别

### 问题：合并后部署失败

这是**部署问题**，与自动合并无关：

1. 查看部署日志
2. 按照 [ROLLBACK.md](./ROLLBACK.md) 回滚
3. 修复问题后重新部署

## 📚 相关文档

- [CONFIG.md](./CONFIG.md) - 完整配置说明
- [ROLLBACK.md](./ROLLBACK.md) - 回滚操作
- [FLOWCHARTS.md](./FLOWCHARTS.md) - 流程图

## 🎯 总结

✅ **是的，当前配置已完全实现基于风险判断的 PR 自动合并和 CI/CD！**

**完整流程：**
```
PR 创建 → Claude 审查 → 低风险 → 自动合并 → 自动部署 → 完成 ✅
```

**无需任何人工操作！**

对于低风险变更（文档、样式、配置等），从提交 PR 到部署上线，完全自动化。
