#!/usr/bin/env bash
#
# council_status.sh - Check readiness of LLM Council components.
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/council_utils.sh"

CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

echo "LLM Council Status"
echo "=================="
echo ""

echo "CLI Availability:"

claude_ok="❌"
codex_ok="❌"
gemini_ok="❌"

if command -v claude &>/dev/null; then claude_ok="✅"; fi
if command -v codex &>/dev/null; then codex_ok="✅"; fi
if command -v gemini &>/dev/null; then gemini_ok="✅"; fi

echo "  Claude : $claude_ok $(command -v claude 2>/dev/null || true)"
echo "  Codex  : $codex_ok $(command -v codex 2>/dev/null || true)"
echo "  Gemini : $gemini_ok $(command -v gemini 2>/dev/null || true)"
echo ""

echo "Versions:"
echo "  claude : $(claude --version 2>/dev/null | head -n1 || echo 'unknown')"
echo "  codex  : $(codex --version 2>/dev/null | head -n1 || echo 'unknown')"
echo "  gemini : $(gemini --version 2>/dev/null | head -n1 || echo 'unknown')"
echo ""

echo "Security Status:"
if command -v jq &>/dev/null; then
    echo "  jq      : ✅ ENABLED ($(jq --version 2>/dev/null || true))"
else
    echo "  jq      : ⚠️ DISABLED (install jq to enable validations)"
fi
echo ""

echo "Configuration:"
config_list

enabled_members="$(config_get "enabled_members" "claude,codex,gemini")"
min_quorum="$(config_get "min_quorum" "2")"

available=0
[[ "$enabled_members" == *"claude"* ]] && command -v claude &>/dev/null && ((available++)) || true
[[ "$enabled_members" == *"codex"* ]] && command -v codex &>/dev/null && ((available++)) || true
[[ "$enabled_members" == *"gemini"* ]] && command -v gemini &>/dev/null && ((available++)) || true

echo "Council Readiness:"
echo "  Enabled members : $enabled_members"
echo "  Available now   : $available/3"
echo "  Min quorum      : $min_quorum"
if [[ "$available" -ge "$min_quorum" ]]; then
    echo "  Status          : ✅ Ready"
else
    echo "  Status          : ⚠️ Not Ready (insufficient quorum)"
fi
echo ""

if [[ -d ".council" ]]; then
    stage1_count=$(ls -1 .council/stage1_*.txt 2>/dev/null | wc -l | tr -d '[:space:]')
    stage2_count=$(ls -1 .council/stage2_review_*.txt 2>/dev/null | wc -l | tr -d '[:space:]')
    report_ok="no"
    [[ -s ".council/final_report.md" ]] && report_ok="yes"
    echo "Previous Session (.council/):"
    echo "  Stage 1 files : $stage1_count"
    echo "  Stage 2 files : $stage2_count"
    echo "  Final report  : $report_ok"
    echo ""
fi

