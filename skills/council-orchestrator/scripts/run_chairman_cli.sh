#!/bin/bash
#
# run_chairman_cli.sh - Phase 3: Chairman Synthesis via Claude CLI (Opus).
#
# This matches the plugin behavior of using a dedicated "Chairman" to synthesize
# Stage 1/2 outputs into a final verdict saved as final_report.md.
#
# Usage:
#   ./run_chairman_cli.sh [council_dir]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/council_utils.sh"

COUNCIL_DIR="${1:-.council}"

if [[ ! -d "$COUNCIL_DIR" ]]; then
    error_msg "Council directory not found: $COUNCIL_DIR"
    exit 1
fi

QUERY_FILE="$COUNCIL_DIR/query.txt"
if [[ ! -f "$QUERY_FILE" ]]; then
    error_msg "Query file not found: $QUERY_FILE"
    exit 1
fi

if ! command -v claude &>/dev/null; then
    error_msg "Claude CLI not found (required for chairman synthesis)"
    exit 1
fi

# Require at least one Stage 1 response.
if ! ls "$COUNCIL_DIR"/stage1_*.txt >/dev/null 2>&1; then
    error_msg "No Stage 1 responses found in $COUNCIL_DIR"
    exit 1
fi

ORIGINAL_QUESTION="$(cat "$QUERY_FILE")"

# Enumerate files explicitly (tools generally don't expand globs).
stage1_files=()
for f in "$COUNCIL_DIR"/stage1_*.txt; do
    [[ -f "$f" ]] && stage1_files+=("$(basename "$f")")
done

stage2_files=()
for f in "$COUNCIL_DIR"/stage2_review_*.txt; do
    [[ -f "$f" ]] && stage2_files+=("$(basename "$f")")
done

# Compose the chairman prompt (keep paths relative to COUNCIL_DIR for tool sandboxing).
CHAIRMAN_PROMPT_FILE="$(mktemp "$COUNCIL_DIR/chairman_prompt.XXXXXX.txt")"
{
    echo "You are the Council Chairman synthesizing multi-model deliberation results."
    echo ""
    echo "## Original Question"
    echo "$ORIGINAL_QUESTION"
    echo ""
    echo "## Council Directory"
    echo "You may only Read/Write within this directory."
    echo ""
    echo "## Stage 1 Opinion Files (read each by exact filename)"
    for f in "${stage1_files[@]}"; do
        echo "- $f"
    done
    echo ""
    echo "## Stage 2 Peer Review Files (optional; read each by exact filename if present)"
    if [[ ${#stage2_files[@]} -gt 0 ]]; then
        for f in "${stage2_files[@]}"; do
            echo "- $f"
        done
    else
        echo "- (none)"
    fi
    echo ""
    echo "## Output"
    echo "- Write the final report to: final_report.md"
    echo ""
    echo "## Task"
    echo "1) Read ALL listed Stage 1 files."
    echo "2) Read ALL listed Stage 2 files (if any)."
    echo "3) Identify consensus and key disagreements; arbitrate conflicts."
    echo "4) Produce a professional Markdown verdict that directly answers the question."
    echo "5) Save it to final_report.md, then print the same Markdown in your final response."
    echo ""
    echo "## Required Report Sections"
    echo "- Executive Summary"
    echo "- Council Participation (map members by filenames: stage1_claude.txt=Claude, stage1_openai.txt=OpenAI Codex, stage1_gemini.txt=Google Gemini)"
    echo "- Areas of Consensus"
    echo "- Areas of Disagreement (with arbitration)"
    echo "- Final Synthesized Recommendation"
    echo "- Warnings & Caveats"
} > "$CHAIRMAN_PROMPT_FILE"

# Run Claude as chairman with only Read/Write tools scoped to COUNCIL_DIR.
# Use stdin for the prompt to avoid argv length limits.
TIMEOUT_CFG="$(config_get "timeout" "120")"
MODEL="${COUNCIL_CHAIRMAN_MODEL:-claude-opus-4-5-20251101}"

prompt_base="$(basename "$CHAIRMAN_PROMPT_FILE")"

# Run from inside COUNCIL_DIR so relative filenames in the prompt resolve.
(
    cd "$COUNCIL_DIR"
    if command -v timeout &>/dev/null; then
        timeout "$TIMEOUT_CFG" \
            claude -p --output-format text \
            --model "$MODEL" \
            --tools "Read,Write" \
            --add-dir "." \
            --permission-mode bypassPermissions \
            --no-session-persistence \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$TIMEOUT_CFG" \
            claude -p --output-format text \
            --model "$MODEL" \
            --tools "Read,Write" \
            --add-dir "." \
            --permission-mode bypassPermissions \
            --no-session-persistence \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    else
        claude -p --output-format text \
            --model "$MODEL" \
            --tools "Read,Write" \
            --add-dir "." \
            --permission-mode bypassPermissions \
            --no-session-persistence \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    fi
)

if [[ -s "$COUNCIL_DIR/final_report.md" ]]; then
    success_msg "Final report generated: $COUNCIL_DIR/final_report.md"
    exit 0
fi

# Fallback: if the model printed the report but failed to write, persist stdout.
if [[ -s "$COUNCIL_DIR/chairman_stdout.md" ]]; then
    cp -f "$COUNCIL_DIR/chairman_stdout.md" "$COUNCIL_DIR/final_report.md"
    success_msg "Final report saved from stdout: $COUNCIL_DIR/final_report.md"
    exit 0
fi

error_msg "Chairman synthesis failed (no final_report.md produced)"
exit 1
