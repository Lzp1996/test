# 🔄 部署回滚指南

## 概述

完整的部署回滚机制，包括自动回滚、手动回滚和本地快速回滚工具。

## 📋 回滚机制

### 1. 自动回滚（推荐）

部署流程已集成自动检测和提示：

**触发条件：**
- ✅ 构建失败 → 不会部署
- ✅ 部署失败 → 提示可回滚版本
- ✅ 健康检查失败 → 标记为警告状态

**自动保护：**
- 每次成功部署自动创建 `deploy-YYYYMMDD-HHMMSS` 标签
- 构建产物备份保存 30 天
- 部署前验证构建完整性
- 部署后运行健康检查

### 2. 手动回滚（GitHub Actions）

#### 方式一：通过 GitHub 网页

1. 访问仓库 **Actions** 标签页
2. 选择左侧 **Rollback Deployment** workflow
3. 点击右侧 **Run workflow** 按钮
4. 配置回滚参数：
   - **target**: 
     - `last` - 回滚到上一个成功部署（默认）
     - `deploy-20260701-123456` - 回滚到指定标签
     - `abc1234` - 回滚到指定 commit
   - **skip-health-check**: 是否跳过健康检查（默认否）
5. 点击绿色 **Run workflow** 按钮
6. 等待回滚完成（通常 2-5 分钟）

#### 方式二：通过 GitHub CLI

```bash
# 安装 GitHub CLI（如果未安装）
brew install gh

# 认证
gh auth login

# 回滚到上一个版本
gh workflow run rollback.yml

# 回滚到指定标签
gh workflow run rollback.yml -f target=deploy-20260701-123456

# 回滚到指定 commit
gh workflow run rollback.yml -f target=abc1234

# 跳过健康检查
gh workflow run rollback.yml -f skip-health-check=true
```

### 3. 本地快速回滚

使用提供的快速回滚脚本：

```bash
# 回滚到上一个成功部署
bash .github/scripts/quick-rollback.sh

# 回滚到指定标签
bash .github/scripts/quick-rollback.sh deploy-20260701-123456

# 回滚到指定 commit
bash .github/scripts/quick-rollback.sh abc1234
```

脚本会：
1. ✅ 检查 git 状态
2. ✅ 创建回滚分支
3. ✅ 构建并验证
4. ✅ 提供后续操作选项

## 🔍 查找回滚目标

### 查看所有成功部署

```bash
# 查看最近 10 个成功部署
git tag -l "deploy-*" --sort=-version:refname | head -n 10

# 查看部署标签的详细信息
git show deploy-20260701-123456

# 查看特定部署的差异
git diff deploy-20260701-123456 deploy-20260701-140000
```

### 通过 GitHub 网页查看

1. 访问仓库主页
2. 点击右侧 **Tags** 或 **Releases**
3. 查看以 `deploy-` 开头的标签
4. 点击标签查看对应的 commit 信息

### 查看部署历史

```bash
# 查看部署历史
gh run list --workflow=deploy.yml --limit 10

# 查看特定运行的详情
gh run view <run-id>

# 下载部署备份
gh run download <run-id> -n deployment-backup-*
```

## 📊 回滚场景和策略

### 场景 1：部署后发现 Bug

**症状：** 部署成功但发现功能问题

**解决方案：**
```bash
# 立即回滚到上一个版本
gh workflow run rollback.yml

# 或使用本地脚本
bash .github/scripts/quick-rollback.sh
```

**后续操作：**
1. 验证回滚成功
2. 在本地修复 bug
3. 创建新的 PR
4. 重新部署

### 场景 2：健康检查失败

**症状：** 部署流程显示 ⚠️ 健康检查失败

**解决方案：**
1. 检查部署日志：Actions → 失败的部署 → 查看 "Health check" 步骤
2. 判断是否需要回滚：
   - 如果页面完全无法访问 → 立即回滚
   - 如果只是响应慢 → 观察并考虑回滚
3. 执行回滚（如果需要）

### 场景 3：部署完全失败

**症状：** 部署 workflow 显示 ❌ 失败

**解决方案：**
1. 检查失败原因（通常不需要回滚，因为未成功部署）
2. 修复问题后重新部署
3. 如果上一次成功部署已经有问题，再考虑回滚

### 场景 4：回滚到特定版本

**症状：** 需要回滚到更早的版本（不是上一个）

**解决方案：**
```bash
# 查找目标版本
git tag -l "deploy-*" --sort=-version:refname

# 回滚到指定版本
gh workflow run rollback.yml -f target=deploy-20260701-120000

# 或查找特定 commit
git log --oneline --all | grep "某个关键词"
gh workflow run rollback.yml -f target=abc1234
```

## 🛡️ 回滚验证清单

回滚完成后，请验证：

- [ ] 页面可以正常访问
- [ ] 关键功能正常工作
- [ ] 控制台无错误
- [ ] API 调用成功
- [ ] 数据显示正确
- [ ] 用户可以正常登录（如果有认证）

## ⚠️ 注意事项

### 数据库变更

如果部署包含数据库迁移，回滚代码不会自动回滚数据库：

```bash
# 需要手动回滚数据库迁移
# 具体命令取决于你的数据库和迁移工具

# 示例（Django）
python manage.py migrate app_name <previous_migration>

# 示例（Prisma）
npx prisma migrate resolve --rolled-back <migration_name>
```

### 配置文件变更

回滚会恢复代码，但外部配置（如环境变量）需要手动检查：

1. 检查 GitHub Secrets 是否需要调整
2. 检查第三方服务配置
3. 检查 API 密钥和 tokens

### 依赖版本

回滚到旧版本可能遇到依赖问题：

```bash
# 清理依赖缓存
rm -rf node_modules package-lock.json

# 重新安装
npm install
```

### 多个环境

如果有 staging/production 多个环境：

1. 先在 staging 测试回滚
2. 确认无误后再回滚 production
3. 保持环境版本一致性

## 📈 回滚监控

### 创建回滚仪表板

回滚会自动创建 Issue 记录，可以通过以下方式监控：

```bash
# 查看所有回滚记录
gh issue list --label rollback

# 查看最近的回滚
gh issue list --label rollback --limit 5
```

### 回滚统计

```bash
# 统计回滚次数
git tag -l "rollback-*" | wc -l

# 查看回滚频率
git log --all --grep="Rollback" --oneline --since="1 month ago"
```

## 🔧 故障排查

### 问题：找不到回滚目标

**症状：** `No previous deployment tag found`

**解决方案：**
```bash
# 检查是否有部署标签
git tag -l "deploy-*"

# 如果没有，这是第一次部署，无法回滚
# 需要手动创建一个基线标签
git tag deploy-baseline
git push origin deploy-baseline
```

### 问题：回滚构建失败

**症状：** 回滚过程中构建失败

**原因：** 旧版本的依赖可能不兼容当前环境

**解决方案：**
```bash
# 选项 1: 使用备份的构建产物
gh run download <old-run-id> -n deployment-backup-*
tar -xzf build-backup.tar.gz

# 选项 2: 修复构建问题后重试
# 编辑旧版本的代码，修复构建问题
# 然后重新运行回滚
```

### 问题：健康检查一直失败

**症状：** 回滚后健康检查失败

**解决方案：**
```bash
# 跳过健康检查强制回滚
gh workflow run rollback.yml -f skip-health-check=true

# 然后手动验证和修复
```

### 问题：Git 权限错误

**症状：** `Permission denied` 创建标签时

**解决方案：**
1. 检查 workflow 权限：Settings → Actions → General
2. 确保启用了 "Read and write permissions"
3. 检查 `permissions: contents: write` 在 workflow 中

## 📚 最佳实践

### 1. 定期测试回滚

每月至少测试一次回滚流程：

```bash
# 在非生产环境测试
gh workflow run rollback.yml -f target=last
```

### 2. 保持清晰的版本标记

```bash
# 为重要版本添加额外标签
git tag -a v1.0.0 -m "Release 1.0.0"
git push origin v1.0.0
```

### 3. 文档化重要部署

在 PR 中说明：
- 是否包含数据库变更
- 是否需要额外的配置
- 回滚注意事项

### 4. 监控回滚指标

跟踪：
- 回滚频率
- 回滚原因
- 平均恢复时间（MTTR）

### 5. 建立回滚决策标准

| 情况 | 决策 |
|------|------|
| 页面完全无法访问 | 立即回滚 |
| 关键功能不可用 | 立即回滚 |
| 次要功能有 bug | 评估后决定 |
| 性能轻微下降 | 监控并修复，不回滚 |
| 视觉问题 | 修复后部署，不回滚 |

## 🚀 回滚自动化增强

未来可以考虑的增强：

1. **自动健康检查**：集成 Lighthouse、性能监控
2. **金丝雀部署**：先部署到部分用户，验证后全量
3. **自动回滚**：健康检查失败自动触发回滚
4. **回滚审批**：生产环境回滚需要多人审批
5. **蓝绿部署**：零停机时间切换版本

## 📞 紧急联系

如果遇到无法解决的回滚问题：

1. 立即通知团队
2. 查看 `.github/CONFIG.md` 中的详细文档
3. 检查 GitHub Actions 日志
4. 必要时联系 DevOps 团队

---

**记住：** 回滚是保障，不是失败。快速回滚、修复问题、重新部署才是正确的流程。
