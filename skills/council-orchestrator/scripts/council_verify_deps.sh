#!/usr/bin/env bash
#
# council_verify_deps.sh - Verify required/optional dependencies.
#
set -euo pipefail

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  LLM Council - Dependency Verification"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

required_ok=true

echo "Required:"
if command -v jq &>/dev/null; then
    echo "  ✅ jq      : $(jq --version 2>/dev/null || true)"
else
    echo "  ❌ jq      : missing (security validations disabled)"
    required_ok=false
fi

if command -v claude &>/dev/null; then
    echo "  ✅ claude   : $(claude --version 2>/dev/null | head -n1 || true)"
else
    echo "  ❌ claude   : missing (council requires Claude)"
    required_ok=false
fi

echo ""
echo "Optional:"
if command -v codex &>/dev/null; then
    echo "  ✅ codex   : $(codex --version 2>/dev/null | head -n1 || true)"
else
    echo "  ℹ️  codex   : missing (optional)"
fi

if command -v gemini &>/dev/null; then
    echo "  ✅ gemini  : $(gemini --version 2>/dev/null | head -n1 || true)"
else
    echo "  ℹ️  gemini  : missing (optional)"
fi

echo ""
if [[ "$required_ok" == true ]]; then
    echo "✅ System is ready for LLM Council."
    exit 0
fi

echo "❌ Missing required dependencies."
exit 1

