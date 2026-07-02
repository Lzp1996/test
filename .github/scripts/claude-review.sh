#!/bin/bash

set -euo pipefail

PR_NUMBER=$1
PR_TITLE=$2
PR_AUTHOR=$3
DIFF_FILE=$4

echo "🤖 Starting Claude Code Review..."
echo "PR #${PR_NUMBER}: ${PR_TITLE}"
echo "Author: ${PR_AUTHOR}"

TMP_PREFIX="/tmp/pr-${PR_NUMBER}-${GITHUB_RUN_ID:-$$}"
RESULT_FILE="${TMP_PREFIX}-claude-review-result.json"
RAW_FILE="${TMP_PREFIX}-claude-review-raw.txt"
LOG_FILE="${TMP_PREFIX}-claude-review.log"
PROMPT_FILE="${TMP_PREFIX}-review-prompt.txt"

echo "📁 Using temp file prefix: ${TMP_PREFIX}"

write_fallback_json() {
  local reason="${1:-Failed to parse Claude review response}"
  cat > "${RESULT_FILE}" <<FALLBACK
{
  "passed": false,
  "risk_level": "high",
  "can_auto_fix": false,
  "needs_human_review": true,
  "max_fix_attempts": 0,
  "issues": ["${reason}"],
  "suggestions": ["Manual review required"],
  "files_changed": 0,
  "lines_added": 0,
  "lines_deleted": 0,
  "auto_decision": "Review failed - needs human intervention",
  "commit_info": {
    "original_message": $(jq -Rn --arg t "${PR_TITLE}" '$t'),
    "is_manual_commit": true
  }
}
FALLBACK
}

extract_json_from_text() {
  local input_file=$1
  local output_file=$2

  python3 - "${input_file}" "${output_file}" <<'PY'
import json
import re
import sys

input_path, output_path = sys.argv[1], sys.argv[2]
text = open(input_path, encoding="utf-8", errors="replace").read().strip()

if not text:
    sys.exit(1)

# Strip markdown code fences if present
text = re.sub(r"^```(?:json)?\s*", "", text, flags=re.IGNORECASE)
text = re.sub(r"\s*```$", "", text)

candidates = [text]

# If Claude returned wrapper JSON, unwrap common fields first
try:
    wrapper = json.loads(text)
    if isinstance(wrapper, dict):
        for key in ("result", "content", "text", "message"):
            value = wrapper.get(key)
            if isinstance(value, str) and value.strip():
                candidates.insert(0, value.strip())
except json.JSONDecodeError:
    pass

for candidate in candidates:
    try:
        obj = json.loads(candidate)
        if isinstance(obj, dict):
            with open(output_path, "w", encoding="utf-8") as f:
                json.dump(obj, f)
            sys.exit(0)
    except json.JSONDecodeError:
        pass

    start = candidate.find("{")
    if start < 0:
        continue

    depth = 0
    for idx in range(start, len(candidate)):
        ch = candidate[idx]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                snippet = candidate[start : idx + 1]
                try:
                    obj = json.loads(snippet)
                    if isinstance(obj, dict):
                        with open(output_path, "w", encoding="utf-8") as f:
                            json.dump(obj, f)
                        sys.exit(0)
                except json.JSONDecodeError:
                    break

sys.exit(1)
PY
}

cat > "${PROMPT_FILE}" <<EOF
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

cat "${DIFF_FILE}" >> "${PROMPT_FILE}"

echo "📝 Running Claude Code review..."
set +e
claude -p "Review the pull request below and respond with ONLY valid JSON matching the required schema." \
  --model claude-sonnet-4-6 \
  --output-format text \
  --permission-mode plan \
  < "${PROMPT_FILE}" \
  > "${RAW_FILE}" 2> "${LOG_FILE}"
CLAUDE_EXIT=$?
set -e

echo "Claude CLI exit code: ${CLAUDE_EXIT}"
if [ -s "${LOG_FILE}" ]; then
  echo "Claude log:"
  cat "${LOG_FILE}"
fi

if [ ! -s "${RAW_FILE}" ]; then
  echo "❌ Claude returned empty output"
  if [ -s "${LOG_FILE}" ]; then
    write_fallback_json "Claude CLI returned empty output (exit ${CLAUDE_EXIT})"
  else
    write_fallback_json "Claude CLI failed with exit code ${CLAUDE_EXIT}"
  fi
elif extract_json_from_text "${RAW_FILE}" "${RESULT_FILE}"; then
  echo "✅ Extracted JSON from Claude response"
else
  echo "❌ Failed to extract valid JSON from Claude response"
  echo "Raw response:"
  cat "${RAW_FILE}"
  write_fallback_json "Failed to parse Claude review response"
fi

if ! jq empty "${RESULT_FILE}" 2>/dev/null; then
  echo "❌ Invalid JSON format after extraction"
  write_fallback_json "Invalid JSON format in Claude review response"
fi

echo "Review result:"
jq '.' "${RESULT_FILE}"

cp "${RESULT_FILE}" /tmp/claude-review-result.json
echo "✅ Claude Code Review completed"
