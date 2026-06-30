#!/bin/bash

set -e

PR_NUMBER=$1
PR_TITLE=$2
PR_AUTHOR=$3
DIFF_FILE=$4

echo "🤖 Starting Claude Code Review..."
echo "PR #${PR_NUMBER}: ${PR_TITLE}"
echo "Author: ${PR_AUTHOR}"

# 创建审查提示词
cat > /tmp/review-prompt.txt <<EOF
You are a senior code reviewer. Analyze the following pull request and provide a structured JSON review.

PR #${PR_NUMBER}: ${PR_TITLE}
Author: ${PR_AUTHOR}

IMPORTANT: You must respond with ONLY a valid JSON object, no other text. The JSON must follow this exact schema:

{
  "passed": boolean,
  "risk_level": "low" | "medium" | "high",
  "can_auto_fix": boolean,
  "needs_human_review": boolean,
  "max_fix_attempts": number,
  "issues": string[],
  "suggestions": string[],
  "files_changed": number,
  "lines_added": number,
  "lines_deleted": number,
  "auto_decision": string,
  "commit_info": {
    "original_message": string,
    "is_manual_commit": boolean
  }
}

Review criteria:
1. **Risk Level Assessment**:
   - LOW: Style changes, config tweaks, documentation, typo fixes, comment updates
   - MEDIUM: Logic changes in non-critical paths, refactoring, new features with tests
   - HIGH: Security changes, authentication/authorization, database migrations, API breaking changes, dependency updates

2. **Auto-fix capability**:
   - Can fix: formatting issues, missing semicolons, simple linting errors, import sorting
   - Cannot fix: logic errors, security issues, architectural problems, breaking changes

3. **Human review required when**:
   - Risk level is HIGH
   - Security-sensitive code changes
   - No tests provided for new features
   - Complex business logic changes
   - External API integration changes

4. **Pass/Fail criteria**:
   - PASS: Code follows standards, no critical issues, adequate tests (if needed)
   - FAIL: Security vulnerabilities, broken tests, missing required tests, code quality issues

5. **Max fix attempts**:
   - 0: Cannot auto-fix or needs human review
   - 1-3: Simple issues that can be fixed automatically

Code changes to review:
EOF

cat "${DIFF_FILE}" >> /tmp/review-prompt.txt

# 使用 Claude Code headless 模式进行审查
# 注意：这里使用 --output-json 标志（如果支持）或通过 prompt 引导输出 JSON
claude --headless --model claude-sonnet-4-6 \
  --input /tmp/review-prompt.txt \
  --output /tmp/claude-review-raw.txt \
  2>&1 | tee /tmp/claude-review.log

# 从输出中提取 JSON（Claude 可能会输出额外的文本）
echo "📝 Extracting JSON from Claude response..."

# 尝试提取 JSON 对象
grep -o '{.*}' /tmp/claude-review-raw.txt | jq '.' > /tmp/claude-review-result.json || {
  echo "❌ Failed to extract valid JSON from Claude response"
  echo "Raw response:"
  cat /tmp/claude-review-raw.txt

  # 创建一个默认的失败响应
  cat > /tmp/claude-review-result.json <<FALLBACK
{
  "passed": false,
  "risk_level": "high",
  "can_auto_fix": false,
  "needs_human_review": true,
  "max_fix_attempts": 0,
  "issues": ["Failed to parse Claude review response"],
  "suggestions": ["Manual review required"],
  "files_changed": 0,
  "lines_added": 0,
  "lines_deleted": 0,
  "auto_decision": "Review failed - needs human intervention",
  "commit_info": {
    "original_message": "${PR_TITLE}",
    "is_manual_commit": true
  }
}
FALLBACK
}

# 验证 JSON 格式
if jq empty /tmp/claude-review-result.json 2>/dev/null; then
  echo "✅ Valid JSON generated"
  echo "Review result:"
  cat /tmp/claude-review-result.json | jq '.'
else
  echo "❌ Invalid JSON format"
  exit 1
fi

echo "✅ Claude Code Review completed"
