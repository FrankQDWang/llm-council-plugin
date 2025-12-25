#!/bin/bash
#
# query_gemini.sh - Query Google Gemini CLI in non-interactive mode
#
# Usage: ./query_gemini.sh "Your prompt here"
#
# This script wraps the Gemini CLI to provide non-interactive querying
# for the LLM Council orchestration system.
#
# Gemini CLI reference: https://github.com/google-gemini/gemini-cli

set -euo pipefail

# Configuration
TIMEOUT_SECONDS="${GEMINI_TIMEOUT:-120}"
MAX_RETRIES="${GEMINI_MAX_RETRIES:-1}"

# Find timeout command (macOS uses gtimeout from coreutils, Linux uses timeout)
TIMEOUT_CMD=""
if command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

# Input:
# - If an argument is provided, treat it as the prompt unless it is a prompt-file marker.
# - If no argument is provided, read the prompt from stdin.
PROMPT="${1:-}"
PROMPT_FILE=""
CREATED_TEMP=0

if [[ -n "$PROMPT" ]] && [[ "$PROMPT" == __PROMPT_FILE__:* ]]; then
    PROMPT_FILE="${PROMPT#__PROMPT_FILE__:}"
    PROMPT=""
    if [[ ! -f "$PROMPT_FILE" ]]; then
        echo "Error: Prompt file not found: $PROMPT_FILE" >&2
        exit 1
    fi
fi

if [[ -z "$PROMPT" ]] && [[ -z "$PROMPT_FILE" ]]; then
    PROMPT_FILE="$(mktemp -t council-gemini-prompt.XXXXXX)"
    CREATED_TEMP=1
    cat > "$PROMPT_FILE"
fi

if [[ -z "$PROMPT_FILE" ]]; then
    PROMPT_FILE="$(mktemp -t council-gemini-prompt.XXXXXX)"
    CREATED_TEMP=1
    printf '%s' "$PROMPT" > "$PROMPT_FILE"
fi

# Check if Gemini CLI is available
if ! command -v gemini &> /dev/null; then
    echo "Error: gemini CLI not found" >&2
    echo "Install from: npm install -g @google/gemini-cli" >&2
    exit 1
fi

# Function to parse JSON output and extract text
# Gemini CLI with --output-format json returns structured data
parse_gemini_output() {
    local output="$1"

    # Check if jq is available for JSON parsing
    if command -v jq &>/dev/null; then
        # Try to extract text from JSON response
        # Gemini output format may vary; try common paths
        local text
        text=$(echo "$output" | jq -r '.response // .text // .content // .' 2>/dev/null) || text="$output"
        echo "$text"
    else
        # Fallback: return raw output if jq is not available
        echo "$output"
    fi
}

# Function to execute query with retry logic
query_gemini() {
    local attempt=0
    local exit_code=0
    local output=""

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if [[ $attempt -gt 0 ]]; then
            echo "Retry attempt $attempt..." >&2
            sleep $((5 * attempt))  # Exponential backoff: 5s, 10s
        fi

        # Execute Gemini in non-interactive mode.
        # IMPORTANT: Avoid passing long prompts via argv. Gemini's --prompt is appended
        # to stdin, so we pass an empty prompt and stream the full content via stdin.
        local cmd_result=0
        if [[ -n "$TIMEOUT_CMD" ]]; then
            if output=$($TIMEOUT_CMD "$TIMEOUT_SECONDS" gemini -p "" -o text < "$PROMPT_FILE" 2>/dev/null); then
                echo "$output"
                return 0
            else
                cmd_result=$?
            fi
        else
            # No timeout command available, run without timeout
            if output=$(gemini -p "" -o text < "$PROMPT_FILE" 2>/dev/null); then
                echo "$output"
                return 0
            else
                cmd_result=$?
            fi
        fi

        exit_code=$cmd_result

        # Check for timeout or error
        if [[ $exit_code -eq 124 ]]; then
            echo "Warning: Gemini CLI timed out after ${TIMEOUT_SECONDS}s" >&2
        elif [[ $exit_code -eq 1 ]]; then
            echo "Warning: Gemini CLI returned error" >&2
        fi

        ((attempt++))
    done

    echo "Error: Failed to query Gemini after $((MAX_RETRIES + 1)) attempts" >&2
    return $exit_code
}

# Execute the query
query_gemini

if [[ $CREATED_TEMP -eq 1 ]] && [[ -n "${PROMPT_FILE:-}" ]]; then
    rm -f "$PROMPT_FILE" 2>/dev/null || true
fi
