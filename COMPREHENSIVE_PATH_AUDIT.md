# Comprehensive Path Resolution Audit

**Audit Date**: 2025-11-28
**Scope**: Complete codebase scan for relative path issues
**Status**: 🔴 **38 remaining issues found** (after initial 12 fixes)

## Executive Summary

After fixing the critical command and skill files, a comprehensive scan reveals **38 additional instances** of relative path usage across documentation and test files. These don't cause immediate failures but create:
1. **Documentation inconsistency** - Docs show patterns that won't work for users
2. **Test fragility** - Tests may pass locally but fail in CI/CD
3. **User confusion** - Copy-paste examples from docs will fail

## Issue Breakdown by Severity

### 🔴 Critical (User-Facing Documentation)

These files are **copied by users** and will cause failures:

| File | Instances | Impact | Priority |
|------|-----------|--------|----------|
| `README.md` | 5 | High - First file users read | P0 |
| `docs/INSTALL.md` | 5 | High - Installation instructions | P0 |
| `skills/council-orchestrator/REFERENCE.md` | 15 | High - Technical reference | P1 |
| `skills/council-orchestrator/EXAMPLES.md` | 11 | High - Copy-paste examples | P1 |
| `skills/council-orchestrator/SECURITY.md` | 2 | Medium - Security examples | P2 |

**Total**: 38 documentation issues

### 🟡 Medium (Test Files)

| File | Instances | Impact | Priority |
|------|-----------|--------|----------|
| `tests/test_hooks.sh` | 2 | Medium - Test false positives | P2 |

**Total**: 2 test issues

### ✅ Already Correct (No Action Needed)

| Component | Status | Reason |
|-----------|--------|--------|
| `hooks/*.sh` | ✅ Correct | Uses `CLAUDE_PLUGIN_ROOT` with fallback |
| `skills/*/scripts/*.sh` | ✅ Correct | Uses `$(dirname "${BASH_SOURCE[0]}")` |
| `commands/*.md` | ✅ Fixed | Updated in commit 38130e4 |
| `skills/council-orchestrator/SKILL.md` | ✅ Fixed | Updated in commit 38130e4 |

## Detailed Findings

### 1. README.md (5 instances)

**Lines with issues:**
- Line 132: `./skills/council-orchestrator/scripts/run_parallel.sh`
- Line 135: `./skills/council-orchestrator/scripts/run_peer_review.sh`
- Line 138: `./skills/council-orchestrator/scripts/run_chairman.sh`
- Line 166: `./skills/council-orchestrator/scripts/council_utils.sh`
- Line 167: `source ./skills/council-orchestrator/scripts/council_utils.sh`

**Context**: Quick Start examples and manual execution instructions

**Impact**: Users copying these commands will get "No such file or directory" errors

**Fix**: Replace with environment variable pattern

### 2. docs/INSTALL.md (5 instances)

**Lines with issues:**
- Line 66: `source ./skills/council-orchestrator/scripts/council_utils.sh && get_cli_status`
- Line 139: `./skills/council-orchestrator/scripts/query_claude.sh "terminal test"`
- Line 142: `./skills/council-orchestrator/scripts/run_parallel.sh "terminal test"`
- Line 145: `./skills/council-orchestrator/scripts/run_peer_review.sh "terminal test" .council`
- Line 148: `./skills/council-orchestrator/scripts/run_chairman.sh "terminal test" .council`

**Context**: Verification and testing instructions

**Impact**: Post-installation verification fails for marketplace users

**Fix**: Replace with environment variable pattern

### 3. skills/council-orchestrator/REFERENCE.md (15 instances)

**Lines with issues:**
- Line 51, 69: `source ./skills/council-orchestrator/scripts/council_utils.sh`
- Lines 98, 113, 121, 129: Query script calls in manual execution
- Line 175: `./skills/council-orchestrator/scripts/run_parallel.sh`
- Lines 248, 256, 264: Review script calls
- Lines 293, 310, 382: Chairman script calls

**Context**: Detailed manual execution guide

**Impact**: Advanced users following manual procedures will fail

**Fix**: Replace with environment variable pattern + `get_plugin_root()` usage

### 4. skills/council-orchestrator/EXAMPLES.md (11 instances)

**Lines with issues:**
- Lines 24, 288: `source ./skills/council-orchestrator/scripts/council_utils.sh`
- Lines 31, 106, 536, 556: `run_parallel.sh` calls
- Lines 36: `run_peer_review.sh` call
- Lines 41, 541: Chairman prompt generation
- Line 158: Direct query script call
- Line 408: Debug example with bash -x

**Context**: Usage examples and troubleshooting

**Impact**: Users debugging issues will copy broken patterns

**Fix**: Replace with environment variable pattern

### 5. skills/council-orchestrator/SECURITY.md (2 instances)

**Lines identified:**
- Line 32: `source ./skills/council-orchestrator/scripts/council_utils.sh`
- Line 104: `for script in ./skills/council-orchestrator/scripts/*.sh`

**Context**: Security validation examples

**Impact**: Security audit instructions won't work correctly

**Fix**: Replace with environment variable pattern

### 6. tests/test_hooks.sh (2 instances)

**Lines with issues:**
- Line 238: Test input with `source skills/council-orchestrator/scripts/council_utils.sh`
- Line 275: Test input with `source skills/council-orchestrator/scripts/council_utils.sh`

**Context**: PreToolUse hook test cases

**Impact**: Tests may pass locally but fail in CI environments where cwd differs

**Fix**: Update test inputs to use absolute paths or mock CLAUDE_PLUGIN_ROOT

## Why These Weren't Caught Initially

1. **Documentation is not executed** - Markdown files aren't run as code
2. **Local development bias** - All testing done from plugin root directory
3. **No CI/CD verification** - Tests not run in marketplace simulation mode
4. **Copy-paste assumption** - Assumed users would adjust paths themselves

## Recommended Fix Pattern

### For User-Facing Documentation

Replace this pattern:
```bash
# ❌ Old (broken for marketplace users)
source ./skills/council-orchestrator/scripts/council_utils.sh
./skills/council-orchestrator/scripts/run_parallel.sh "$query"
```

With this pattern:
```bash
# ✅ New (works everywhere)
# Resolve plugin root (works for both local dev and marketplace installations)
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    PLUGIN_ROOT="${COUNCIL_PLUGIN_ROOT}"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT}"
else
    PLUGIN_ROOT="${CLAUDE_PROJECT_DIR}"
fi

source "${PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
"${PLUGIN_ROOT}/skills/council-orchestrator/scripts/run_parallel.sh" "$query"
```

Or use the helper function:
```bash
# ✅ Alternative: Use helper function (after sourcing council_utils.sh)
source "$(resolve_council_utils)"  # From source_utils.sh
PLUGIN_ROOT=$(get_plugin_root)
"${PLUGIN_ROOT}/skills/council-orchestrator/scripts/run_parallel.sh" "$query"
```

### For Test Files

Update test inputs to include environment variable setup:
```bash
# ✅ Test with proper environment
export CLAUDE_PLUGIN_ROOT="${PWD}"
local input='{"tool_name":"Bash","tool_input":{"command":"source ${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"}}'
```

## Fix Priority Matrix

### Phase 1: Critical User-Facing Docs (P0)
- [ ] README.md (5 fixes)
- [ ] docs/INSTALL.md (5 fixes)
- **Impact**: Prevents user confusion and support issues
- **Effort**: 2-3 hours
- **Risk**: Low - documentation only

### Phase 2: Technical Documentation (P1)
- [ ] skills/council-orchestrator/REFERENCE.md (15 fixes)
- [ ] skills/council-orchestrator/EXAMPLES.md (11 fixes)
- **Impact**: Enables advanced usage and debugging
- **Effort**: 3-4 hours
- **Risk**: Low - documentation only

### Phase 3: Security & Tests (P2)
- [ ] skills/council-orchestrator/SECURITY.md (2 fixes)
- [ ] tests/test_hooks.sh (2 fixes)
- **Impact**: Improves test reliability and security audit accuracy
- **Effort**: 1 hour
- **Risk**: Medium - tests could reveal other issues

## Verification Plan

After fixes:

### 1. Automated Verification
```bash
# Ensure no relative paths remain in user-facing docs
! grep -r "^\./skills\|source \./skills" \
    README.md docs/ skills/*/EXAMPLES.md skills/*/REFERENCE.md

# Ensure all examples use environment variables
grep -r "CLAUDE_PLUGIN_ROOT\|COUNCIL_PLUGIN_ROOT\|get_plugin_root" \
    README.md docs/ skills/*/EXAMPLES.md | wc -l
# Should be > 0
```

### 2. Manual Verification
- [ ] Copy command from README.md and test in different directory
- [ ] Follow INSTALL.md from scratch in clean environment
- [ ] Execute EXAMPLES.md code snippets in /tmp directory
- [ ] Run test suite with `CLAUDE_PROJECT_DIR=/tmp`

### 3. Marketplace Simulation
```bash
# Simulate marketplace installation
mkdir -p ~/.claude/plugins/cache/test-install
cp -r . ~/.claude/plugins/cache/test-install/
cd /tmp/test-project
export CLAUDE_PLUGIN_ROOT=~/.claude/plugins/cache/test-install
export CLAUDE_PROJECT_DIR=/tmp/test-project

# Test commands from documentation
# All should work without modification
```

## Prevention Measures

### 1. Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
if git diff --cached --name-only | grep -q "\.md$"; then
    if git diff --cached | grep -q "^+.*\./skills/"; then
        echo "ERROR: Relative path ./skills/ detected in markdown"
        echo "Use \${CLAUDE_PLUGIN_ROOT} or \${COUNCIL_PLUGIN_ROOT} instead"
        exit 1
    fi
fi
```

### 2. CI/CD Test
```yaml
# .github/workflows/test.yml
- name: Test marketplace simulation
  run: |
    cd /tmp
    export CLAUDE_PLUGIN_ROOT="${GITHUB_WORKSPACE}"
    export CLAUDE_PROJECT_DIR="/tmp"
    ./tests/test_runner.sh
```

### 3. Documentation Linter
Add to `tests/test_runner.sh`:
```bash
test_documentation_paths() {
    echo "Testing: Documentation uses correct paths"

    # Check for problematic patterns
    if grep -r "source \./skills" README.md docs/ skills/*/EXAMPLES.md; then
        echo "❌ Found relative paths in documentation"
        return 1
    fi

    echo "✅ Documentation paths correct"
}
```

## Estimated Total Effort

| Phase | Files | Instances | Effort | Risk |
|-------|-------|-----------|--------|------|
| P0 - Critical Docs | 2 | 10 | 2-3h | Low |
| P1 - Technical Docs | 2 | 26 | 3-4h | Low |
| P2 - Security/Tests | 2 | 4 | 1h | Medium |
| Testing & Verification | - | - | 2h | Low |
| **Total** | **6** | **40** | **8-10h** | **Low-Medium** |

## Next Steps

1. ✅ Complete this audit (DONE)
2. 🔄 Fix P0 documentation (README.md, INSTALL.md) - **IN PROGRESS**
3. ⏳ Fix P1 documentation (REFERENCE.md, EXAMPLES.md)
4. ⏳ Fix P2 files (SECURITY.md, test_hooks.sh)
5. ⏳ Add prevention measures
6. ⏳ Final verification and commit

## Conclusion

The initial fix (commit 38130e4) resolved the **critical execution failures** in commands and skills. However, **38 additional instances remain in documentation** that could:
- Confuse users who copy-paste examples
- Cause support issues
- Make advanced features appear broken
- Reduce trust in the plugin

**Recommendation**: Fix all documentation in phases, prioritizing user-facing docs (README, INSTALL) first.
