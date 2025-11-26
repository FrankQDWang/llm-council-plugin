#!/bin/bash
#
# council_utils.sh - Utility functions for LLM Council orchestration
#
# This script provides shared utility functions for managing the council
# working directory, validating outputs, and checking dependencies.
#
# Source this file in other scripts:
#   source "$(dirname "$0")/council_utils.sh"

set -euo pipefail

# Default working directory (relative to project root)
COUNCIL_DIR="${COUNCIL_DIR:-.council}"

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

# Initialize the council working directory
# Usage: council_init
council_init() {
    if [[ ! -d "$COUNCIL_DIR" ]]; then
        mkdir -p "$COUNCIL_DIR"
        echo -e "${GREEN}Created council working directory: $COUNCIL_DIR${NC}" >&2
    fi
}

# Clean up the council working directory
# Usage: council_cleanup
council_cleanup() {
    if [[ -d "$COUNCIL_DIR" ]]; then
        rm -rf "$COUNCIL_DIR"
        echo -e "${GREEN}Cleaned up council working directory${NC}" >&2
    fi
}

# Validate that an output file exists and is non-empty
# Usage: validate_output <file_path> <member_name>
# Returns: 0 if valid, 1 if invalid
validate_output() {
    local file_path="$1"
    local member_name="$2"

    if [[ ! -f "$file_path" ]]; then
        echo -e "${RED}$member_name: No response file${NC}" >&2
        return 1
    fi

    if [[ ! -s "$file_path" ]]; then
        echo -e "${YELLOW}$member_name: Empty response (marked as absent)${NC}" >&2
        return 1
    fi

    echo -e "${GREEN}$member_name: Response captured${NC}" >&2
    return 0
}

# Check if a CLI tool is available
# Usage: check_cli <cli_name>
# Returns: 0 if available, 1 if not
check_cli() {
    local cli_name="$1"
    command -v "$cli_name" &>/dev/null
}

# Get the status of all council member CLIs
# Usage: get_cli_status
# Output: JSON-like status string
get_cli_status() {
    local claude_status="absent"
    local codex_status="absent"
    local gemini_status="absent"

    check_cli claude && claude_status="available"
    check_cli codex && codex_status="available"
    check_cli gemini && gemini_status="available"

    echo "claude:$claude_status codex:$codex_status gemini:$gemini_status"
}

# Count available council members
# Usage: count_available_members
# Returns: Number of available CLIs (0-3)
count_available_members() {
    local count=0
    check_cli claude && ((count++)) || true
    check_cli codex && ((count++)) || true
    check_cli gemini && ((count++)) || true
    echo "$count"
}

# Display progress message
# Usage: progress_msg <message>
progress_msg() {
    echo -e "${YELLOW}>>> $1${NC}" >&2
}

# Display error message
# Usage: error_msg <message>
error_msg() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

# Display success message
# Usage: success_msg <message>
success_msg() {
    echo -e "${GREEN}$1${NC}" >&2
}

# Check if the final report was generated
# Usage: check_final_report
# Returns: 0 if report exists and is non-empty, 1 otherwise
check_final_report() {
    local report_file="$COUNCIL_DIR/final_report.md"

    if [[ ! -f "$report_file" ]]; then
        error_msg "Final report not found: $report_file"
        return 1
    fi

    if [[ ! -s "$report_file" ]]; then
        error_msg "Final report is empty: $report_file"
        return 1
    fi

    success_msg "Final report generated: $report_file"
    return 0
}

# Get list of available Stage 1 response files
# Usage: get_stage1_files
# Output: Space-separated list of file paths
get_stage1_files() {
    local files=""
    [[ -s "$COUNCIL_DIR/stage1_claude.txt" ]] && files="$files $COUNCIL_DIR/stage1_claude.txt"
    [[ -s "$COUNCIL_DIR/stage1_openai.txt" ]] && files="$files $COUNCIL_DIR/stage1_openai.txt"
    [[ -s "$COUNCIL_DIR/stage1_gemini.txt" ]] && files="$files $COUNCIL_DIR/stage1_gemini.txt"
    echo "$files"
}

# Get list of available Stage 2 review files
# Usage: get_stage2_files
# Output: Space-separated list of file paths
get_stage2_files() {
    local files=""
    [[ -s "$COUNCIL_DIR/stage2_review_claude.txt" ]] && files="$files $COUNCIL_DIR/stage2_review_claude.txt"
    [[ -s "$COUNCIL_DIR/stage2_review_openai.txt" ]] && files="$files $COUNCIL_DIR/stage2_review_openai.txt"
    [[ -s "$COUNCIL_DIR/stage2_review_gemini.txt" ]] && files="$files $COUNCIL_DIR/stage2_review_gemini.txt"
    echo "$files"
}

# Count Stage 1 responses
# Usage: count_stage1_responses
# Returns: Number of Stage 1 files (0-3)
count_stage1_responses() {
    local count=0
    [[ -s "$COUNCIL_DIR/stage1_claude.txt" ]] && ((count++)) || true
    [[ -s "$COUNCIL_DIR/stage1_openai.txt" ]] && ((count++)) || true
    [[ -s "$COUNCIL_DIR/stage1_gemini.txt" ]] && ((count++)) || true
    echo "$count"
}

# Count Stage 2 reviews
# Usage: count_stage2_reviews
# Returns: Number of Stage 2 files (0-3)
count_stage2_reviews() {
    local count=0
    [[ -s "$COUNCIL_DIR/stage2_review_claude.txt" ]] && ((count++)) || true
    [[ -s "$COUNCIL_DIR/stage2_review_openai.txt" ]] && ((count++)) || true
    [[ -s "$COUNCIL_DIR/stage2_review_gemini.txt" ]] && ((count++)) || true
    echo "$count"
}

# Display council session summary
# Usage: council_summary
council_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "                   COUNCIL SESSION SUMMARY                  "
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Stage 1 Responses: $(count_stage1_responses)/3"
    echo "Stage 2 Reviews:   $(count_stage2_reviews)/3"
    echo ""

    if check_final_report 2>/dev/null; then
        echo "Final Report:      ✓ Generated"
        echo ""
        echo "Report Location:   $COUNCIL_DIR/final_report.md"
    else
        echo "Final Report:      ✗ Not generated"
    fi
    echo ""
    echo "═══════════════════════════════════════════════════════════"
}
