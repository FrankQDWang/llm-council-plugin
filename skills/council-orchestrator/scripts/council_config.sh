#!/usr/bin/env bash
#
# council_config.sh - View/manage LLM Council config (~/.council/config).
#
# Usage:
#   council_config.sh
#   council_config.sh set <key> <value>
#   council_config.sh reset
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/council_utils.sh"

cmd="${1:-}"

case "$cmd" in
    "" )
        config_list
        ;;
    set )
        key="${2:-}"
        value="${3:-}"
        if [[ -z "$key" ]] || [[ -z "$value" ]]; then
            echo "Usage: $0 set <key> <value>" >&2
            exit 1
        fi
        config_set "$key" "$value"
        ;;
    reset )
        rm -f "$COUNCIL_CONFIG_FILE"
        echo "Configuration reset: $COUNCIL_CONFIG_FILE"
        ;;
    * )
        echo "Usage: $0 [set <key> <value> | reset]" >&2
        exit 1
        ;;
esac

