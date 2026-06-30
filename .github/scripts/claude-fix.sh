#!/bin/bash

set -e

REVIEW_RESULT_FILE=$1
PR_NUMBER=$2

echo "🔧 Starting Claude Auto-Fix..."

# 读取审查结果
REVIEW_RESULT=$(cat "${REVIEW_RESULT_FILE}")
MAX_ATTEMPTS=$(echo "${REVIEW_RESULT}" | jq -r '.max_fix_attempts')
ISSUES=$(echo "${REVIEW_RESULT}" | jq -r '.issues | join("; ")')

echo "Max fix attempts: ${MAX_ATTEMPTS}"
echo "Issues to fix: ${ISSUES}"

if [ "${MAX_ATTEMPTS}" -eq 0 ]; then
  echo "❌ Auto-fix not allowed for this PR"
  echo "fixed=false" >> $GITHUB_OUTPUT
  exit 0
fi

# 创建修复提示词
cat > /tmp/fix-prompt.txt <<EOF
You are an expert code fixer. Fix the following issues in the codebase:

Issues to fix:
${ISSUES}

Review context:
${REVIEW_RESULT}

Instructions:
1. Fix ONLY the specific issues mentioned
2. Do NOT refactor or change unrelated code
3. Ensure all fixes are safe and don't break existing functionality
4. Run linting and formatting after fixes
5. Provide a summary of changes made

After fixing, respond with a summary of what was changed.
EOF

# 运行 Claude Code 进行自动修复
ATTEMPT=1
FIXED=false

while [ ${ATTEMPT} -le ${MAX_ATTEMPTS} ]; do
  echo "🔄 Fix attempt ${ATTEMPT}/${MAX_ATTEMPTS}..."

  claude --headless --model claude-sonnet-4-6 \
    --input /tmp/fix-prompt.txt \
    --output /tmp/fix-result.txt \
    2>&1 | tee /tmp/claude-fix.log

  # 检查是否有文件被修改
  if git diff --quiet; then
    echo "⚠️ No changes made by Claude"
    ATTEMPT=$((ATTEMPT + 1))
    continue
  fi

  # 运行 lint 检查修复是否成功
  if npm run lint --if-present 2>/dev/null; then
    echo "✅ Lint passed, fix successful"
    FIXED=true
    break
  else
    echo "⚠️ Lint failed, attempting another fix..."
    git checkout .  # 回滚更改
    ATTEMPT=$((ATTEMPT + 1))
  fi
done

if [ "${FIXED}" = true ]; then
  echo "✅ Auto-fix completed successfully"
  cat /tmp/fix-result.txt > /tmp/fix-summary.txt
  echo "fixed=true" >> $GITHUB_OUTPUT
else
  echo "❌ Auto-fix failed after ${MAX_ATTEMPTS} attempts"
  echo "Auto-fix failed - needs manual intervention" > /tmp/fix-summary.txt
  echo "fixed=false" >> $GITHUB_OUTPUT
fi
