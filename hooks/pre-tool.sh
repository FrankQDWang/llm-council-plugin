#!/bin/bash
#
# pre-tool.sh - PreToolUse hook for LLM Council plugin
#
# This hook validates inputs before tool execution to ensure security
# and prevent shell injection attacks.
#
# Called by Claude Code before Bash tool execution.
# Receives tool context via stdin as JSON.
#
# Exit codes:
#   0 - Allow tool execution
#   1 - Block tool execution (with error message)

set -euo pipefail

# Configuration
MAX_PROMPT_LENGTH="${COUNCIL_MAX_PROMPT_LENGTH:-10000}"
COUNCIL_DIR="${COUNCIL_DIR:-.council}"

# Read input from stdin (JSON format from Claude Code)
INPUT=$(cat)

# Extract tool name and input from JSON (requires jq)
if command -v jq &>/dev/null; then
    TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty' 2>/dev/null || echo "")
    TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // empty' 2>/dev/null || echo "")
else
    # Fallback: basic pattern matching if jq unavailable
    TOOL_NAME=""
    TOOL_INPUT=""
fi

# Function to check for shell injection patterns
check_shell_injection() {
    local text="$1"

    # Dangerous shell metacharacters and patterns
    local dangerous_patterns=(
        '`'           # Command substitution
        '$(('         # Arithmetic expansion start
        '$()'         # Command substitution
        '$('          # Command substitution
        '|'           # Pipe
        ';'           # Command separator
        '&&'          # Logical AND
        '||'          # Logical OR
        '>'           # Redirect stdout
        '<'           # Redirect stdin
        '>>'          # Append redirect
        '2>'          # Redirect stderr
        '&>'          # Redirect all
        '\n'          # Newline (could inject commands)
        '\r'          # Carriage return
        '\x00'        # Null byte
    )

    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$text" == *"$pattern"* ]]; then
            echo "BLOCKED: Detected potentially dangerous pattern: $pattern" >&2
            return 1
        fi
    done

    return 0
}

# Function to validate prompt length
check_prompt_length() {
    local text="$1"
    local length=${#text}

    if [[ $length -gt $MAX_PROMPT_LENGTH ]]; then
        echo "BLOCKED: Prompt too long ($length chars, max: $MAX_PROMPT_LENGTH)" >&2
        return 1
    fi

    return 0
}

# Function to check for sensitive file paths
check_sensitive_paths() {
    local text="$1"

    # Patterns that should not appear in council prompts
    local sensitive_patterns=(
        '/etc/passwd'
        '/etc/shadow'
        '~/.ssh/'
        '/.ssh/'
        '.env'
        'credentials'
        'secret'
        'password'
        'api_key'
        'API_KEY'
        'private_key'
    )

    for pattern in "${sensitive_patterns[@]}"; do
        if [[ "$text" == *"$pattern"* ]]; then
            echo "WARNING: Detected potentially sensitive pattern: $pattern" >&2
            # Don't block, just warn - the pattern might be legitimate
        fi
    done

    return 0
}

# Function to validate council-specific operations
validate_council_operation() {
    local tool_input="$1"

    # Check if this is a council script execution
    if [[ "$tool_input" == *"council-orchestrator/scripts"* ]]; then
        # Validate the script exists
        local script_path
        script_path=$(echo "$tool_input" | grep -oE 'skills/council-orchestrator/scripts/[a-z_]+\.sh' || echo "")

        if [[ -n "$script_path" && ! -f "$script_path" ]]; then
            echo "BLOCKED: Council script not found: $script_path" >&2
            return 1
        fi
    fi

    return 0
}

# Main validation logic
main() {
    # Only validate Bash tool calls
    if [[ "$TOOL_NAME" != "Bash" && "$TOOL_NAME" != "bash" ]]; then
        exit 0  # Allow non-Bash tools
    fi

    # Skip if no input to validate
    if [[ -z "$TOOL_INPUT" ]]; then
        exit 0
    fi

    # Run validation checks
    local validation_failed=0

    # Check for shell injection
    if ! check_shell_injection "$TOOL_INPUT"; then
        validation_failed=1
    fi

    # Check prompt length
    if ! check_prompt_length "$TOOL_INPUT"; then
        validation_failed=1
    fi

    # Check for sensitive paths (warning only)
    check_sensitive_paths "$TOOL_INPUT"

    # Validate council operations
    if ! validate_council_operation "$TOOL_INPUT"; then
        validation_failed=1
    fi

    if [[ $validation_failed -eq 1 ]]; then
        echo "Pre-tool validation failed. Tool execution blocked." >&2
        exit 1
    fi

    # All checks passed
    exit 0
}

main
