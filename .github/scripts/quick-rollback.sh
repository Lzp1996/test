#!/bin/bash

# 快速回滚脚本 - 本地使用
# 用法: bash .github/scripts/quick-rollback.sh [target]
# target: 可以是 "last"（默认）、tag 名称或 commit SHA

set -e

TARGET="${1:-last}"

echo "🔄 快速回滚工具"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

# 检查 git 状态
if [ -n "$(git status --porcelain)" ]; then
  echo "⚠️  工作目录有未提交的修改"
  echo "请先提交或暂存修改，然后重试"
  exit 1
fi

# 确定回滚目标
if [ "$TARGET" == "last" ]; then
  LAST_TAG=$(git tag -l "deploy-*" --sort=-version:refname | head -n 1)

  if [ -z "$LAST_TAG" ]; then
    echo "❌ 未找到之前的部署标签"
    echo "可用的标签："
    git tag -l "deploy-*" --sort=-version:refname | head -n 5
    exit 1
  fi

  TARGET_REF="$LAST_TAG"
  echo "✅ 找到最后的部署: $LAST_TAG"
else
  if ! git rev-parse "$TARGET" >/dev/null 2>&1; then
    echo "❌ 无效的目标: $TARGET"
    exit 1
  fi

  TARGET_REF="$TARGET"
  echo "✅ 使用指定目标: $TARGET"
fi

TARGET_COMMIT=$(git rev-parse "$TARGET_REF")

echo ""
echo "📋 回滚信息："
echo "  目标: $TARGET_REF"
echo "  Commit: ${TARGET_COMMIT:0:7}"
echo ""

# 确认回滚
read -p "是否继续回滚？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ 回滚已取消"
  exit 0
fi

# 创建回滚分支
ROLLBACK_BRANCH="rollback-$(date +%Y%m%d-%H%M%S)"
echo "🔀 创建回滚分支: $ROLLBACK_BRANCH"
git checkout -b "$ROLLBACK_BRANCH" "$TARGET_COMMIT"

# 构建
echo "🔨 构建中..."
npm ci
npm run build

# 验证构建
if [ ! -f "dist/index.html" ]; then
  echo "❌ 构建失败：index.html 未找到"
  git checkout -
  git branch -D "$ROLLBACK_BRANCH"
  exit 1
fi

echo "✅ 构建成功"

# 提供选项
echo ""
echo "回滚分支已创建: $ROLLBACK_BRANCH"
echo ""
echo "下一步选项："
echo "1. 推送分支并创建 PR: git push -u origin $ROLLBACK_BRANCH"
echo "2. 直接部署到 master: git checkout master && git reset --hard $ROLLBACK_BRANCH && git push --force"
echo "3. 使用 GitHub Actions 回滚: 访问 Actions → Rollback Deployment"
echo ""
echo "当前在分支: $ROLLBACK_BRANCH"
echo "要返回之前的分支: git checkout -"
