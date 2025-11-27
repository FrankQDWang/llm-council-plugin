#!/bin/bash
# test_codex_integration.sh - Codex 集成测试

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
QUERY_SCRIPT="$SCRIPT_DIR/skills/council-orchestrator/scripts/query_codex.sh"

echo "=== Codex 集成测试 ==="
echo "脚本位置: $QUERY_SCRIPT"

# 测试 1: 验证脚本包含修复
echo ""
echo "Test 1: 验证 --skip-git-repo-check 标志存在"
if grep -q "codex exec --skip-git-repo-check" "$QUERY_SCRIPT"; then
    echo "✅ PASS: 找到 --skip-git-repo-check 标志"
else
    echo "❌ FAIL: 缺少 --skip-git-repo-check 标志"
    exit 1
fi

# 测试 2: 验证重试次数已提高
echo ""
echo "Test 2: 验证默认重试次数为 3"
if grep -q 'MAX_RETRIES="${CODEX_MAX_RETRIES:-3}"' "$QUERY_SCRIPT"; then
    echo "✅ PASS: 默认重试次数为 3"
else
    echo "❌ FAIL: 默认重试次数不是 3"
    exit 1
fi

# 测试 3: 非 Git 目录运行测试
echo ""
echo "Test 3: 非 Git 目录运行测试"
TEST_DIR="/tmp/codex-test-$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

if echo "print hello world" | "$QUERY_SCRIPT" "-" > output.txt 2>&1; then
    echo "✅ PASS: Codex 在非 Git 目录中成功运行"
    cat output.txt | head -5
else
    echo "❌ FAIL: Codex 运行失败"
    cat output.txt
    rm -rf "$TEST_DIR"
    exit 1
fi

# 清理
cd /
rm -rf "$TEST_DIR"

echo ""
echo "=== 所有测试通过 ==="
