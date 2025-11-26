#!/bin/bash
#
# post-tool.sh - PostToolUse hook for LLM Council plugin
#
# This hook validates outputs after tool execution to ensure:
# - Output sanity checks
# - Rate limit detection
# - Error pattern detection
# - Quorum verification for council operations
#
# Called by Claude Code after Bash tool execution.
# Receives tool context via stdin as JSON.
#
# Exit codes:
#   0 - Continue (output acceptable)
#   1 - Signal issue (logged but doesn't block)

set -euo pipefail

# Configuration
MAX_OUTPUT_LENGTH="${COUNCIL_MAX_OUTPUT_LENGTH:-100000}"
COUNCIL_DIR="${COUNCIL_DIR:-.council}"
MIN_QUORUM=2

# Read input from stdin (JSON format from Claude Code)
INPUT=$(cat)

# Extract tool info from JSON (requires jq)
if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    TOOL_OUTPUT=$(echo "$INPUT" | jq -r '.tool_output // empty' 2>/dev/null || echo "")
    EXIT_CODE=$(echo "$INPUT" | jq -r '.exit_code // "0"' 2>/dev/null || echo "0")
else
    TOOL_NAME=""
    TOOL_OUTPUT=""
    EXIT_CODE="0"
fi

# Function to check for rate limit errors
check_rate_limit() {
    local output="$1"

    local rate_limit_patterns=(
        'rate limit'
        'Rate limit'
        'RATE_LIMIT'
        '429'
        'Too many requests'
        'too many requests'
        'quota exceeded'
        'Quota exceeded'
    )

    for pattern in "${rate_limit_patterns[@]}"; do
        if [[ "$output" == *"$pattern"* ]]; then
            echo "WARNING: Rate limit detected in output. Consider waiting before retry." >&2
            return 1
        fi
    done

    return 0
}

# Function to check for authentication errors
check_auth_errors() {
    local output="$1"

    local auth_patterns=(
        'unauthorized'
        'Unauthorized'
        'UNAUTHORIZED'
        '401'
        '403'
        'authentication failed'
        'Authentication failed'
        'invalid api key'
        'Invalid API key'
        'access denied'
        'Access denied'
    )

    for pattern in "${auth_patterns[@]}"; do
        if [[ "$output" == *"$pattern"* ]]; then
            echo "ERROR: Authentication issue detected. Check API credentials." >&2
            return 1
        fi
    done

    return 0
}

# Function to check output length
check_output_length() {
    local output="$1"
    local length=${#output}

    if [[ $length -gt $MAX_OUTPUT_LENGTH ]]; then
        echo "WARNING: Output very large ($length chars). May impact context." >&2
    fi

    return 0
}

# Function to check for empty or error outputs
check_output_quality() {
    local output="$1"
    local exit_code="$2"

    # Check for non-zero exit code
    if [[ "$exit_code" != "0" ]]; then
        echo "WARNING: Tool exited with code $exit_code" >&2
    fi

    # Check for empty output (might be okay for some commands)
    if [[ -z "$output" ]]; then
        echo "INFO: Tool produced no output" >&2
    fi

    # Check for common error patterns
    local error_patterns=(
        'Error:'
        'ERROR:'
        'error:'
        'Failed:'
        'FAILED:'
        'failed:'
        'Exception:'
        'Traceback'
    )

    for pattern in "${error_patterns[@]}"; do
        if [[ "$output" == *"$pattern"* ]]; then
            echo "INFO: Error pattern detected in output: $pattern" >&2
            break
        fi
    done

    return 0
}

# Function to verify council quorum after parallel execution
verify_council_quorum() {
    local output="$1"

    # Only check if this looks like a council operation
    if [[ "$output" != *"council"* && "$output" != *".council"* ]]; then
        return 0
    fi

    # Check if we're in a council session
    if [[ ! -d "$COUNCIL_DIR" ]]; then
        return 0
    fi

    # Count Stage 1 responses
    local stage1_count=0
    [[ -s "$COUNCIL_DIR/stage1_claude.txt" ]] && ((stage1_count++)) || true
    [[ -s "$COUNCIL_DIR/stage1_openai.txt" ]] && ((stage1_count++)) || true
    [[ -s "$COUNCIL_DIR/stage1_gemini.txt" ]] && ((stage1_count++)) || true

    if [[ $stage1_count -gt 0 && $stage1_count -lt $MIN_QUORUM ]]; then
        echo "WARNING: Council quorum not met. Only $stage1_count of $MIN_QUORUM required responses." >&2
        echo "Council may proceed with degraded coverage." >&2
    fi

    return 0
}

# Function to sanitize output for sensitive data
check_sensitive_data_leak() {
    local output="$1"

    # Patterns that might indicate sensitive data exposure
    local sensitive_patterns=(
        'sk-[a-zA-Z0-9]{48}'      # OpenAI API key pattern
        'AIza[a-zA-Z0-9_-]{35}'   # Google API key pattern
        'AKIA[A-Z0-9]{16}'        # AWS access key pattern
        'ghp_[a-zA-Z0-9]{36}'     # GitHub personal access token
        'gho_[a-zA-Z0-9]{36}'     # GitHub OAuth token
        'Bearer [a-zA-Z0-9._-]+'  # Bearer token pattern
    )

    for pattern in "${sensitive_patterns[@]}"; do
        if echo "$output" | grep -qE "$pattern" 2>/dev/null; then
            echo "WARNING: Potential sensitive data detected in output. Review before sharing." >&2
            return 1
        fi
    done

    return 0
}

# Main validation logic
main() {
    # Only validate Bash tool outputs
    if [[ "$TOOL_NAME" != "Bash" && "$TOOL_NAME" != "bash" ]]; then
        exit 0
    fi

    # Run all checks (non-blocking - just informational)
    check_rate_limit "$TOOL_OUTPUT" || true
    check_auth_errors "$TOOL_OUTPUT" || true
    check_output_length "$TOOL_OUTPUT" || true
    check_output_quality "$TOOL_OUTPUT" "$EXIT_CODE" || true
    verify_council_quorum "$TOOL_OUTPUT" || true
    check_sensitive_data_leak "$TOOL_OUTPUT" || true

    # Post-tool hooks don't block, just inform
    exit 0
}

main
