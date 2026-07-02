#!/bin/bash

set -euo pipefail

REVIEW_RESULT_FILE=$1
PR_NUMBER=$2

echo "🔧 Starting Claude Auto-Fix..."

TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${GITHUB_RUN_ID:-$$}"
PROMPT_FILE="${TMP_PREFIX}-fix-prompt.txt"
RESULT_FILE="${TMP_PREFIX}-fix-result.txt"
LOG_FILE="${TMP_PREFIX}-claude-fix.log"

echo "📁 Using temp file prefix: ${TMP_PREFIX}"

if [ ! -s "${REVIEW_RESULT_FILE}" ]; then
  echo "❌ Review result file is missing or empty: ${REVIEW_RESULT_FILE}"
  echo "fixed=false" >> "${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

REVIEW_RESULT=$(cat "${REVIEW_RESULT_FILE}")
MAX_ATTEMPTS=$(echo "${REVIEW_RESULT}" | jq -r '.max_fix_attempts // 0')
ISSUES=$(echo "${REVIEW_RESULT}" | jq -r '.issues | join("; ")')

echo "Max fix attempts: ${MAX_ATTEMPTS}"
echo "Issues to fix: ${ISSUES}"

if [ "${MAX_ATTEMPTS}" -eq 0 ]; then
  echo "❌ Auto-fix not allowed for this PR"
  echo "fixed=false" >> "${GITHUB_OUTPUT}"
  exit 0
fi

cat > "${PROMPT_FILE}" <<EOF
You are an expert code fixer. Fix the following issues in the codebase:

Issues to fix:
${ISSUES}

Review context:
${REVIEW_RESULT}

Instructions:
1. Fix ONLY the specific issues mentioned
2. Do NOT refactor or change unrelated code
3. Ensure all fixes are safe and don't break existing functionality
4. Run linting and formatting after fixes if available
5. Provide a summary of changes made

After fixing, respond with a summary of what was changed.
EOF

ATTEMPT=1
FIXED=false

while [ "${ATTEMPT}" -le "${MAX_ATTEMPTS}" ]; do
  echo "🔄 Fix attempt ${ATTEMPT}/${MAX_ATTEMPTS}..."

  set +e
  claude -p "Fix the issues described below in this repository." \
    --model claude-sonnet-4-6 \
    --output-format text \
    --permission-mode acceptEdits \
    < "${PROMPT_FILE}" \
    > "${RESULT_FILE}" 2> "${LOG_FILE}"
  CLAUDE_EXIT=$?
  set -e

  echo "Claude CLI exit code: ${CLAUDE_EXIT}"
  if [ -s "${LOG_FILE}" ]; then
    cat "${LOG_FILE}"
  fi

  if ! git diff --quiet; then
    if npm run lint --if-present 2>/dev/null; then
      echo "✅ Lint passed, fix successful"
      FIXED=true
      break
    fi

    if npm run build --if-present 2>/dev/null; then
      echo "✅ Build passed, fix successful"
      FIXED=true
      break
    fi

    echo "⚠️ Validation failed, attempting another fix..."
    git reset --hard HEAD
  else
    echo "⚠️ No changes made by Claude"
  fi

  ATTEMPT=$((ATTEMPT + 1))
done

if [ "${FIXED}" = true ]; then
  echo "✅ Auto-fix completed successfully"
  cp "${RESULT_FILE}" /tmp/fix-summary.txt
  echo "fixed=true" >> "${GITHUB_OUTPUT}"
else
  echo "❌ Auto-fix failed after ${MAX_ATTEMPTS} attempts"
  echo "Auto-fix failed - needs manual intervention" > /tmp/fix-summary.txt
  echo "fixed=false" >> "${GITHUB_OUTPUT}"
fi
