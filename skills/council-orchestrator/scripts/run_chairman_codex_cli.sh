#!/bin/bash
#
# run_chairman_codex_cli.sh - Phase 3: Chairman Synthesis via Codex CLI (default model).
#
# This script synthesizes Stage 1/2 outputs into a final verdict saved as final_report.md.
# Unlike the Claude-based chairman, this writes final_report.md from Codex stdout.
#
# Usage:
#   ./run_chairman_codex_cli.sh [council_dir]
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

if ! command -v codex &>/dev/null; then
    error_msg "Codex CLI not found (required for codex chairman synthesis)"
    echo "Install from: npm install -g @openai/codex" >&2
    exit 1
fi

# Require at least one Stage 1 response.
stage1_files=()
for f in "$COUNCIL_DIR"/stage1_*.txt; do
    [[ -f "$f" ]] && stage1_files+=("$(basename "$f")")
done
if [[ ${#stage1_files[@]} -eq 0 ]]; then
    error_msg "No Stage 1 responses found in $COUNCIL_DIR"
    exit 1
fi

stage2_files=()
for f in "$COUNCIL_DIR"/stage2_review_*.txt; do
    [[ -f "$f" ]] && stage2_files+=("$(basename "$f")")
done

ORIGINAL_QUESTION="$(cat "$QUERY_FILE")"

MAX_LEN="$(config_get "max_prompt_length" "100000")"

write_prompt_with_embedded_files() {
    local prompt_path="$1"
    local per_file_limit="${2:-}"

    {
        echo "You are the Council Chairman synthesizing multi-model deliberation results."
        echo ""
        echo "## Original Question"
        echo "$ORIGINAL_QUESTION"
        echo ""
        echo "## Inputs (embedded below)"
        echo "- Stage 1 files: ${stage1_files[*]}"
        if [[ ${#stage2_files[@]} -gt 0 ]]; then
            echo "- Stage 2 files: ${stage2_files[*]}"
        else
            echo "- Stage 2 files: (none)"
        fi
        echo ""
        echo "## Task"
        echo "1) Read ALL embedded Stage 1/2 files."
        echo "2) Identify consensus and key disagreements; arbitrate conflicts."
        echo "3) Produce a professional Markdown verdict that directly answers the question."
        echo ""
        echo "## Output Requirements"
        echo "- Output ONLY the final Markdown report (no preamble)."
        echo "- Include these sections: Executive Summary, Council Participation, Areas of Consensus, Areas of Disagreement (with arbitration), Final Synthesized Recommendation, Warnings & Caveats."
        echo "- Do NOT run tools or commands; use only the embedded text."
        echo ""
        echo "# Embedded Evidence Files"
        echo ""
    } > "$prompt_path"

    local all_files=("${stage1_files[@]}" "${stage2_files[@]}")
    local rel
    for rel in "${all_files[@]}"; do
        local abs="$COUNCIL_DIR/$rel"
        echo "--- BEGIN FILE: $rel ---" >> "$prompt_path"
        if [[ -n "$per_file_limit" ]]; then
            local total
            total="$(wc -c < "$abs" | tr -d '[:space:]')"
            if [[ "$total" -gt "$per_file_limit" ]]; then
                head -c "$per_file_limit" "$abs" >> "$prompt_path"
                echo "" >> "$prompt_path"
                echo "[TRUNCATED: included first $per_file_limit bytes of $total bytes]" >> "$prompt_path"
            else
                cat "$abs" >> "$prompt_path"
            fi
        else
            cat "$abs" >> "$prompt_path"
        fi
        echo "" >> "$prompt_path"
        echo "--- END FILE: $rel ---" >> "$prompt_path"
        echo "" >> "$prompt_path"
    done
}

# Compose the chairman prompt with embedded file contents to avoid tool/permission prompts.
CHAIRMAN_PROMPT_FILE="$(mktemp "$COUNCIL_DIR/chairman_prompt_codex.XXXXXX.txt")"
write_prompt_with_embedded_files "$CHAIRMAN_PROMPT_FILE"

PROMPT_LEN="$(wc -c < "$CHAIRMAN_PROMPT_FILE" | tr -d '[:space:]')"
if [[ "$PROMPT_LEN" -gt "$MAX_LEN" ]]; then
    # Rebuild with truncation to stay within max_prompt_length.
    # Allocate remaining budget evenly across evidence files.
    all_count=$((${#stage1_files[@]} + ${#stage2_files[@]}))
    reserve=$((4000 + all_count * 200))
    if [[ "$MAX_LEN" -le "$reserve" ]]; then
        per_file_limit=2000
    else
        per_file_limit=$(((MAX_LEN - reserve) / all_count))
        [[ "$per_file_limit" -lt 2000 ]] && per_file_limit=2000
    fi

    write_prompt_with_embedded_files "$CHAIRMAN_PROMPT_FILE" "$per_file_limit"
    PROMPT_LEN="$(wc -c < "$CHAIRMAN_PROMPT_FILE" | tr -d '[:space:]')"
    progress_msg "Codex chairman prompt was truncated to fit max_prompt_length (limit=$MAX_LEN, actual=$PROMPT_LEN, per_file_limit=$per_file_limit)"
fi

TIMEOUT_CFG="$(config_get "timeout" "120")"
prompt_base="$(basename "$CHAIRMAN_PROMPT_FILE")"

# Run Codex as chairman and capture stdout for persistence.
(
    cd "$COUNCIL_DIR"
    if command -v timeout &>/dev/null; then
        timeout "$TIMEOUT_CFG" \
            codex exec -s read-only --skip-git-repo-check \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    elif command -v gtimeout &>/dev/null; then
        gtimeout "$TIMEOUT_CFG" \
            codex exec -s read-only --skip-git-repo-check \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    else
        codex exec -s read-only --skip-git-repo-check \
            < "$prompt_base" \
            > "chairman_stdout.md" 2> "chairman_stderr.log" || true
    fi
)

if [[ -s "$COUNCIL_DIR/chairman_stdout.md" ]]; then
    cp -f "$COUNCIL_DIR/chairman_stdout.md" "$COUNCIL_DIR/final_report.md"
    success_msg "Final report generated (codex): $COUNCIL_DIR/final_report.md"
    exit 0
fi

error_msg "Codex chairman synthesis failed (no output produced). See: $COUNCIL_DIR/chairman_stderr.log"
exit 1

