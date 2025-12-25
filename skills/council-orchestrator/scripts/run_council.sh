#!/bin/bash
#
# run_council.sh - Run Stage 1 (opinions) + Stage 2 (peer review) + Stage 3 (chairman) end-to-end.
#
# Designed for Codex CLI `/council` prompt integration where the user query can be
# very long: the prompt can be written to a file and this script will read it.
#
# Usage:
#   ./run_council.sh "<query>" [output_dir]
#   ./run_council.sh "__READ_QUERY_FILE__" [output_dir]   # reads <output_dir>/query.txt
#   ./run_council.sh --query-file <path> [--output-dir <dir>] [--no-chairman]
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/council_utils.sh"

usage() {
    cat >&2 <<'USAGE'
Usage:
  run_council.sh "<query>" [output_dir]
  run_council.sh "__READ_QUERY_FILE__" [output_dir]
  run_council.sh --query-file <path> [--output-dir <dir>] [--no-chairman]
USAGE
}

QUERY_ARG=""
QUERY_FILE=""
OUTPUT_DIR=".council"
RUN_CHAIRMAN=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --query-file)
            QUERY_FILE="${2:-}"
            shift 2
            ;;
        --output-dir)
            OUTPUT_DIR="${2:-}"
            shift 2
            ;;
        --no-chairman)
            RUN_CHAIRMAN=0
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -z "$QUERY_ARG" ]]; then
                QUERY_ARG="$1"
                shift
            else
                # Back-compat: 2nd positional arg is output dir
                OUTPUT_DIR="$1"
                shift
            fi
            ;;
    esac
done

if [[ -z "$OUTPUT_DIR" ]]; then
    error_msg "Output directory is empty"
    usage
    exit 1
fi

# Reset working directory for this run (match plugin behavior)
rm -rf "$OUTPUT_DIR" 2>/dev/null || true
mkdir -p "$OUTPUT_DIR"

# Persist query for this run
local_query_file="$OUTPUT_DIR/query.txt"
if [[ -n "$QUERY_FILE" ]]; then
    if [[ ! -f "$QUERY_FILE" ]]; then
        error_msg "Query file not found: $QUERY_FILE"
        exit 1
    fi
    cp -f "$QUERY_FILE" "$local_query_file"
else
    if [[ -z "$QUERY_ARG" ]]; then
        error_msg "No query provided"
        usage
        exit 1
    fi

    if [[ "$QUERY_ARG" == "__READ_QUERY_FILE__" ]]; then
        if [[ ! -f "$local_query_file" ]]; then
            error_msg "Expected query file not found: $local_query_file"
            exit 1
        fi
    elif [[ "$QUERY_ARG" == @* ]] && [[ -f "${QUERY_ARG#@}" ]]; then
        cp -f "${QUERY_ARG#@}" "$local_query_file"
    else
        printf '%s' "$QUERY_ARG" > "$local_query_file"
    fi
fi

COUNCIL_DIR="$OUTPUT_DIR"
council_init

progress_msg "Stage 1: collecting opinions..."
"$SCRIPT_DIR/run_parallel.sh" "__READ_QUERY_FILE__" "$OUTPUT_DIR"

progress_msg "Stage 2: running peer review..."
if "$SCRIPT_DIR/run_peer_review.sh" "__READ_QUERY_FILE__" "$OUTPUT_DIR"; then
    success_msg "Stage 2 complete"
else
    # Peer review can legitimately fail when only one member responded.
    progress_msg "Stage 2 skipped/failed; continuing to chairman synthesis"
fi

if [[ $RUN_CHAIRMAN -eq 1 ]]; then
    CHAIRMAN_PROVIDER_DEFAULT="${COUNCIL_CHAIRMAN_PROVIDER:-codex}"
    CHAIRMAN_PROVIDER="$(config_get "chairman_provider" "$CHAIRMAN_PROVIDER_DEFAULT")"
    progress_msg "Stage 3: chairman synthesis (provider=$CHAIRMAN_PROVIDER)..."

    case "$CHAIRMAN_PROVIDER" in
        codex)
            "$SCRIPT_DIR/run_chairman_codex_cli.sh" "$OUTPUT_DIR"
            ;;
        claude)
            "$SCRIPT_DIR/run_chairman_cli.sh" "$OUTPUT_DIR"
            ;;
        auto)
            if command -v codex &>/dev/null; then
                "$SCRIPT_DIR/run_chairman_codex_cli.sh" "$OUTPUT_DIR"
            else
                "$SCRIPT_DIR/run_chairman_cli.sh" "$OUTPUT_DIR"
            fi
            ;;
        *)
            error_msg "Unknown chairman_provider: $CHAIRMAN_PROVIDER (expected: codex|claude|auto)"
            exit 1
            ;;
    esac
    success_msg "Council run complete (Stage 1 + Stage 2 + Stage 3)"
else
    success_msg "Council orchestration complete (Stage 1 + Stage 2)"
fi
