# GitHub 配置清单

## 📋 必需配置项

按照以下顺序配置，确保系统正常运行。

---

## 1️⃣ GitHub Secrets 配置

进入仓库：**Settings → Secrets and variables → Actions → New repository secret**

### 认证配置（必需，选择其中一种）

#### 选项 A：使用 API Key（推荐用于 CI/CD）

```yaml
名称: ANTHROPIC_API_KEY
值: sk-ant-api03-xxx...
说明: Claude API Key，从 https://console.anthropic.com/ 获取
```

#### 选项 B：使用 Auth Token（你当前使用的）

```yaml
名称: ANTHROPIC_AUTH_TOKEN
值: sk-xxx...
说明: Claude Auth Token，通过 claude setup-token 获取
```

### 代理配置（可选，如果使用中转服务）

```yaml
名称: ANTHROPIC_BASE_URL
值: https://www.hotaitool.net
说明: 第三方 API 中转地址（你当前使用的）
```

### 配置截图示例

```
┌─────────────────────────────────────────┐
│ Name: ANTHROPIC_AUTH_TOKEN              │
│ Secret: (hidden)│
│ Updated: Just now                        │
└─────────────────────────────────────────┘
```

---

## 2️⃣ GitHub Actions 权限配置

进入：**Settings → Actions → General → Workflow permissions**

### 必需设置

```
◉ Read and write permissions
  └─ 允许 workflows 创建 tags、合并 PR、部署等

☑ Allow GitHub Actions to create and approve pull requests
  └─ 允许自动合并 PR
```

### 配置说明

- **Read and write permissions**: 必需，用于：
  - 创建部署标签 `deploy-*`
  - 自动合并 PR
  - 提交自动修复的代码
  - 部署到 GitHub Pages

- **Allow GitHub Actions to create and approve pull requests**: 必需，用于：
  - 自动合并低风险 PR
  - 在 PR 中添加评论
  - 添加标签

---

## 3️⃣ GitHub Labels 配置

进入：**Issues → Labels → New label**

创建以下 4 个标签：

### 标签 1：auto-deploy-approved

```
名称: auto-deploy-approved
描述: Low risk, automatically approved for deployment
颜色: #0E8A16 (绿色)
```

### 标签 2：needs-human-approval

```
名称: needs-human-approval
描述: Medium risk, requires human confirmation before merge
颜色: #FBCA04 (黄色)
```

### 标签 3：needs-human-review

```
名称: needs-human-review
描述: High risk, requires detailed human review
颜色: #D93F0B (红色)
```

### 标签 4：review-failed

```
名称: review-failed
描述: Code review failed, needs fixes
颜色: #6A737D (灰色)
```

### 可选标签：跳过审查（见 SKIP-REVIEW.md）

如需使用跳过审查功能，额外创建以下标签：

```
skip-claude-review    # 蓝色 #0075CA - 跳过 Claude 审查
skip-review           # 蓝色 #0075CA - 跳过 Claude 审查
auto-merge-approved   # 蓝色 #0075CA - 触发跳过（与 auto-deploy-approved 不同）
```

PR 标题也可使用 `[skip-review]`、`[deploy-direct]`、`[trusted]` 跳过审查。

### 快速创建命令（使用 GitHub CLI）

```bash
gh label create "auto-deploy-approved" \
  --description "Low risk, automatically approved for deployment" \
  --color "0E8A16"

gh label create "needs-human-approval" \
  --description "Medium risk, requires human confirmation before merge" \
  --color "FBCA04"

gh label create "needs-human-review" \
  --description "High risk, requires detailed human review" \
  --color "D93F0B"

gh label create "review-failed" \
  --description "Code review failed, needs fixes" \
  --color "6A737D"

# 可选：跳过审查标签
gh label create "skip-claude-review" --color "0075CA" --description "Skip Claude review" || true
gh label create "skip-review" --color "0075CA" --description "Skip Claude review" || true
gh label create "auto-merge-approved" --color "0075CA" --description "Trigger skip review" || true
```

---

## 4️⃣ GitHub Pages 配置（必须使用分支部署）

进入：**Settings → Pages**

### 设置（与 deploy.yml 的 peaceiris 方式一致）

```
Source: Deploy from a branch
Branch: gh-pages
Folder: / (root)

Enforce HTTPS: ☑ (建议开启)
```

### ⚠️ 不要使用的配置

```
Source: GitHub Actions   ← 会触发 deploy-pages，卡在 deployment_queued
```

### 说明

- `deploy.yml` 用 peaceiris 将构建产物推送到 `gh-pages` 分支
- Pages 源必须是 **gh-pages 分支**，不能选 GitHub Actions
- Actions 里可能出现「pages build and deployment」，卡住可 Cancel，**以 Deploy Vue to GitHub Pages 为准**
- **不要**创建 `github-pages` Environment（Settings → Environments），否则会走 deploy-pages API

---

## 5️⃣ 分支保护规则（可选但推荐）

进入：**Settings → Branches → Add branch protection rule**

### 推荐配置（master 分支）

```yaml
Branch name pattern: master

☑ Require a pull request before merging
  ├─ ☐ Require approvals (可选，自动合并时不需要)
  └─ ☑ Dismiss stale pull request approvals when new commits are pushed

☑ Require status checks to pass before merging
  └─ 如果有其他 CI checks，在这里添加

☐ Require conversation resolution before merging (可选)

☑ Do not allow bypassing the above settings
  └─ ☑ Allow specified actors to bypass required pull requests
      └─ 添加: github-actions[bot]
```

### 说明

如果启用了分支保护：
- 必须允许 `github-actions[bot]` 绕过保护规则
- 否则自动合并会失败

---

## 6️⃣ GitHub Actions 环境配置

**不需要**创建 `github-pages` Environment。

若之前已创建，请到 **Settings → Environments** 删除 `github-pages`，否则可能触发 `deploy-pages` 并卡在 `deployment_queued`。

---

## 🧪 验证配置

### 步骤 1：测试 API 认证

```bash
# 在 GitHub 网页
Actions → Test Claude API Configuration → Run workflow

# 或使用 CLI
gh workflow run test-secrets.yml
gh run watch
```

**预期输出：**
```
✅ ANTHROPIC_AUTH_TOKEN is set
✅ Using custom base URL: https://www.hotaitool.net
✅ Claude Code CLI is installed
✅ API connection successful
```

### 步骤 2：创建测试 PR

```bash
# 创建测试分支
git checkout -b test/auto-deploy
echo "<!-- Test auto-deploy -->" >> README.md
git add README.md
git commit -m "docs: test auto-deploy"
git push -u origin test/auto-deploy

# 在 GitHub 创建 PR
```

**预期行为：**
1. ✅ 2-3分钟后出现 Claude 审查评论
2. ✅ 添加 `auto-deploy-approved` 标签（低风险）
3. ✅ PR 自动合并
4. ✅ 自动触发部署
5. ✅ 5-10分钟后部署完成

---

## 📊 配置检查清单

在提交第一个 PR 前，确认以下所有项：

- [ ] **Secrets 配置**
  - [ ] `ANTHROPIC_AUTH_TOKEN` 或 `ANTHROPIC_API_KEY` 已添加
  - [ ] `ANTHROPIC_BASE_URL` 已添加（如果使用中转）
  
- [ ] **权限配置**
  - [ ] Read and write permissions 已启用
  - [ ] Allow create and approve pull requests 已勾选
  
- [ ] **标签创建**
  - [ ] `auto-deploy-approved` (绿色)
  - [ ] `needs-human-approval` (黄色)
  - [ ] `needs-human-review` (红色)
  - [ ] `review-failed` (灰色)
  - [ ] 跳过审查标签（可选，见 SKIP-REVIEW.md）
  
- [ ] **Pages 配置**（如果使用）
  - [ ] Source 设置为 Deploy from a branch → gh-pages / (root)
  - [ ] 未创建 github-pages Environment
  
- [ ] **分支保护**（如果启用）
  - [ ] github-actions[bot] 已添加到 bypass 列表
  
- [ ] **验证测试**
  - [ ] test-secrets.yml 运行成功
  - [ ] 测试 PR 自动审查成功

---

## 🔧 快速配置脚本

如果你安装了 GitHub CLI (`gh`)，可以使用以下脚本快速配置：

```bash
#!/bin/bash

echo "🚀 开始配置 GitHub 仓库..."

# 1. 添加 Secrets（需要手动输入值）
echo "📝 添加 Secrets..."
gh secret set ANTHROPIC_AUTH_TOKEN --body "sk-your-token-here"
gh secret set ANTHROPIC_BASE_URL --body "https://www.hotaitool.net"

# 2. 创建标签
echo "🏷️  创建标签..."
gh label create "auto-deploy-approved" --color "0E8A16" --description "Low risk, auto-approved" || true
gh label create "needs-human-approval" --color "FBCA04" --description "Medium risk, needs confirmation" || true
gh label create "needs-human-review" --color "D93F0B" --description "High risk, needs review" || true
gh label create "review-failed" --color "6A737D" --description "Review failed" || true

# 3. 启用 Pages（如果适用）
# 注意：这需要通过 GitHub API，建议手动配置

echo "✅ 配置完成！"
echo ""
echo "⚠️  还需手动配置："
echo "1. Settings → Actions → General → Workflow permissions"
echo "   - 启用 Read and write permissions"
echo "   - 勾选 Allow create and approve pull requests"
echo ""
echo "2. Settings → Pages"
echo "   - Source: Deploy from a branch → gh-pages / (root)"
echo "   - 不要选 GitHub Actions"
echo ""
echo "3. 运行测试："
echo "   gh workflow run test-secrets.yml"
```

---

## 🆘 常见配置问题

### 问题 1：Workflow 提示权限不足

**错误信息：**
```
Error: Resource not accessible by integration
```

**解决方案：**
检查 **Settings → Actions → General → Workflow permissions**
- 确保启用了 `Read and write permissions`
- 确保勾选了 `Allow create and approve pull requests`

### 问题 2：API 认证失败

**错误信息：**
```
❌ API connection failed
```

**解决方案：**
1. 检查 Secret 名称拼写是否正确
2. 检查 Secret 值是否正确（没有多余空格）
3. 运行 `test-secrets.yml` 查看详细错误

### 问题 3：PR 没有自动合并

**可能原因：**
- 没有 `auto-deploy-approved` 标签 → Claude 判断不是低风险
- 权限不足 → 检查 Workflow permissions
- 分支保护 → github-actions[bot] 需要 bypass 权限
- 有冲突 → 需要先解决冲突

**排查步骤：**
1. 查看 PR 的标签
2. 查看 Actions 日志中的 `Auto-merge PR` 步骤
3. 检查是否有错误信息

### 问题 4：标签不存在

**错误信息：**
```
Label does not exist
```

**解决方案：**
按照第 3 步创建所需的 4 个标签

---

## 📚 相关文档

- [SETUP.md](./SETUP.md) - 详细设置指南
- [CONFIG.md](./CONFIG.md) - 完整配置说明
- [SKIP-REVIEW.md](./SKIP-REVIEW.md) - 跳过审查指南
- [AUTO-MERGE.md](./AUTO-MERGE.md) - 自动合并配置

---

## ✅ 配置完成后

一旦所有配置完成：

1. ✅ 提交代码到 GitHub
2. ✅ 运行 `test-secrets.yml` 验证
3. ✅ 创建测试 PR 验证完整流程
4. ✅ 开始享受自动化！

**从 PR 创建到部署上线，低风险变更只需 5-10 分钟，完全无需人工干预！** 🎉
