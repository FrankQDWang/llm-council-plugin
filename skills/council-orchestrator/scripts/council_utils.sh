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
