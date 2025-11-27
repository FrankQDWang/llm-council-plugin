#!/bin/bash
# check_codex_env.sh - 验证 Codex 运行环境

echo "=== Codex 环境检查 ==="

# 1. CLI 可用性
if command -v codex &>/dev/null; then
    echo "✅ Codex CLI: $(codex --version 2>&1 | head -1)"
else
    echo "❌ Codex CLI: Not found"
    exit 1
fi

# 2. API Key
if [[ -n "${OPENAI_API_KEY:-}" ]]; then
    echo "✅ OPENAI_API_KEY: Set (${#OPENAI_API_KEY} chars)"
else
    echo "⚠️  OPENAI_API_KEY: Not set"
fi

# 3. 网络连接（可选）
if ping -c 1 api.openai.com &>/dev/null; then
    echo "✅ Network: OpenAI API reachable"
else
    echo "⚠️  Network: Cannot reach OpenAI API"
fi

echo "=== 检查完成 ==="
