#!/bin/bash
#
# query_codex.sh - Query OpenAI Codex CLI in non-interactive mode
#
# Usage: ./query_codex.sh "Your prompt here"
#
# This script wraps the Codex CLI to provide non-interactive querying
# for the LLM Council orchestration system.
#
# Codex CLI reference: https://github.com/openai/codex

set -euo pipefail

# Configuration
TIMEOUT_SECONDS="${CODEX_TIMEOUT:-120}"
MAX_RETRIES="${CODEX_MAX_RETRIES:-1}"

# Find timeout command (macOS uses gtimeout from coreutils, Linux uses timeout)
TIMEOUT_CMD=""
if command -v timeout &>/dev/null; then
    TIMEOUT_CMD="timeout"
elif command -v gtimeout &>/dev/null; then
    TIMEOUT_CMD="gtimeout"
fi

# Validate input
if [[ $# -lt 1 ]]; then
    echo "Error: No prompt provided" >&2
    echo "Usage: $0 \"Your prompt here\"" >&2
    exit 1
fi

PROMPT="$1"

# Check if Codex CLI is available
if ! command -v codex &> /dev/null; then
    echo "Error: codex CLI not found" >&2
    echo "Install from: npm install -g @openai/codex" >&2
    exit 1
fi

# Function to execute query with retry logic
query_codex() {
    local attempt=0
    local exit_code=0

    while [[ $attempt -le $MAX_RETRIES ]]; do
        if [[ $attempt -gt 0 ]]; then
            echo "Retry attempt $attempt..." >&2
            sleep $((5 * attempt))  # Exponential backoff: 5s, 10s
        fi

        # Execute Codex in non-interactive exec mode
        # codex exec: executes a prompt in non-interactive mode
        # Stdin is piped from /dev/null to prevent blocking
        local cmd_result=0
        if [[ -n "$TIMEOUT_CMD" ]]; then
            # Use echo to pipe the prompt via stdin for codex exec
            if echo "$PROMPT" | $TIMEOUT_CMD "$TIMEOUT_SECONDS" codex exec 2>/dev/null; then
                return 0
            else
                cmd_result=$?
            fi
        else
            # No timeout command available, run without timeout
            if echo "$PROMPT" | codex exec 2>/dev/null; then
                return 0
            else
                cmd_result=$?
            fi
        fi

        exit_code=$cmd_result

        # Check for timeout or error
        if [[ $exit_code -eq 124 ]]; then
            echo "Warning: Codex CLI timed out after ${TIMEOUT_SECONDS}s" >&2
        elif [[ $exit_code -eq 1 ]]; then
            echo "Warning: Codex CLI returned error" >&2
        fi

        ((attempt++))
    done

    echo "Error: Failed to query Codex after $((MAX_RETRIES + 1)) attempts" >&2
    return $exit_code
}

# Execute the query
query_codex
