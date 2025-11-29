# Path Resolution Best Practices

> **Purpose**: Comprehensive guide for path resolution in the LLM Council Plugin. Critical for marketplace compatibility. Referenced from @CLAUDE.md via `@docs/PATH_RESOLUTION.md`.

## Overview

All plugin code (commands, skills, hooks, documentation examples) must use **absolute paths** resolved via environment variables to work correctly in both local development and marketplace installations.

---

## The Problem

**Relative paths like `./skills/council-orchestrator/scripts/council_utils.sh` only work when the current working directory equals the plugin root.**

For marketplace-installed plugins:
- Plugin files are in `~/.claude/plugins/cache/llm-council-plugin/`
- User's current working directory is their project directory
- Relative paths fail with "No such file or directory" errors

---

## The Solution

Use Claude Code's official environment variables with a fallback chain for maximum compatibility.

---

## Standard Pattern for Commands and Skills

All slash commands, skill documentation, and user-facing examples should use this pattern:

```bash
# Resolve plugin root with fallback chain
# Works for marketplace installations, local development, and all edge cases
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
else
    UTILS_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/council_utils.sh"
fi

source "$UTILS_PATH"
```

**Compact form for documentation examples**:
```bash
PLUGIN_ROOT="${COUNCIL_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR}}}"
source "${PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
```

---

## Environment Variable Hierarchy

### 1. COUNCIL_PLUGIN_ROOT (First Priority)

**Source**: Set by SessionStart hook (line 24 of `hooks/session-start.sh`)

**Persistence**: Persisted via `CLAUDE_ENV_FILE` for entire session

**Advantages**:
- Most convenient - avoids repeated fallback checks
- Explicitly set for this plugin
- Available after session initialization

**Availability**: Only available after session initialization

**Example value**: `/home/user/.claude/plugins/cache/llm-council-plugin`

### 2. CLAUDE_PLUGIN_ROOT (Second Priority)

**Source**: Provided by Claude Code for marketplace installations

**When set**: For plugins installed via marketplace

**When empty**: During local development (plugin directory = project directory)

**Advantages**:
- Always correct for installed plugins
- Official Claude Code environment variable

**Example value**: `/home/user/.claude/plugins/cache/llm-council-plugin`

### 3. CLAUDE_PROJECT_DIR (Fallback)

**Source**: Provided by Claude Code for user's project root

**When to use**: Last resort for plugin files during local development

**Primary use**: User project files (`.council/`, session data, user code)

**Warning**: Should only be used as fallback for plugin files

**Example value**: `/home/user/my-project`

---

## When to Use Each Pattern

### For Plugin Files (commands, skills, scripts, hooks)

✅ **DO**: Use the standard pattern above
```bash
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    SCRIPT_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/scripts/run.sh"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    SCRIPT_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/run.sh"
else
    SCRIPT_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/run.sh"
fi
```

✅ **DO**: Always check `COUNCIL_PLUGIN_ROOT` first, then `CLAUDE_PLUGIN_ROOT`

❌ **DON'T**: Use relative paths like `./skills/...`

❌ **DON'T**: Use `CLAUDE_PROJECT_DIR` alone (fails for marketplace installations)

### For User Project Files (`.council/`, session data, user code)

✅ **DO**: Use `CLAUDE_PROJECT_DIR` directly
```bash
COUNCIL_DIR="${CLAUDE_PROJECT_DIR}/.council"
OUTPUT_FILE="${CLAUDE_PROJECT_DIR}/.council/final_report.md"
```

---

## Examples by Context

### Slash Commands (`commands/*.md`)

```markdown
---
description: Run council deliberation
argument-hint: "<question>"
---

# Implementation Instructions

**Use the Bash tool**:

```bash
# Resolve plugin root
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
else
    UTILS_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/council_utils.sh"
fi

source "$UTILS_PATH"
council_init
```
```

### Skill Documentation (`skills/*/SKILL.md`, `REFERENCE.md`, `EXAMPLES.md`)

```markdown
## Usage Example

```bash
# In code examples
PLUGIN_ROOT="${COUNCIL_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR}}}"
"${PLUGIN_ROOT}/skills/council-orchestrator/scripts/run_parallel.sh" "$query" .council
```
```

### Helper Scripts (`skills/*/scripts/*.sh`)

```bash
#!/usr/bin/env bash
set -euo pipefail

# Internal scripts can use $(dirname "$0") for relative resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_PATH="${SCRIPT_DIR}/council_utils.sh"
source "$UTILS_PATH"

# For plugin-to-plugin references, still use environment variables
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    TEMPLATE_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/templates/prompt.txt"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    TEMPLATE_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/templates/prompt.txt"
else
    TEMPLATE_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/templates/prompt.txt"
fi
```

### Hooks (`hooks/*.sh`)

See dedicated section below.

---

## Path Resolution in Hooks

Hooks require special handling due to their execution context. Use the correct environment variable for the file type:

### 1. Plugin Infrastructure (hooks, skills, scripts bundled with plugin)

**Use**: `CLAUDE_PLUGIN_ROOT`

**Example**:
```bash
abs_path="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
```

**Why**: Plugin files are installed in `~/.claude/plugins/cache/plugin-name/` when installed via marketplace

### 2. User Project Files (session data, user code, project-specific config)

**Use**: `CLAUDE_PROJECT_DIR`

**Example**:
```bash
session_file="${CLAUDE_PROJECT_DIR}/.council/stage1_openai.txt"
```

**Why**: User project files are in the directory where Claude Code was started

### 3. Local Development Fallback

**When testing plugin in-place** (not installed), `CLAUDE_PLUGIN_ROOT` may be unset

**Fallback to `CLAUDE_PROJECT_DIR`** for development convenience

**Example pattern**:
```bash
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    abs_path="${CLAUDE_PLUGIN_ROOT}/${script_path}"
else
    abs_path="${PROJECT_DIR}/${script_path}"  # Local dev fallback
fi
```

### Common Mistake

❌ **DON'T**: Use `CLAUDE_PROJECT_DIR` for plugin files

**Why it fails**: Plugin files don't exist in the user's project directory for marketplace-installed plugins

```bash
# This WILL FAIL for marketplace installations
SCRIPT_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/run.sh"
# Error: No such file or directory
```

---

## Historical Context

In November 2025, we discovered systematic use of relative paths (`./skills/...`) across **52 instances in 14 files**, causing complete plugin failure for marketplace installations.

**The fix**:
- Implemented the standard pattern above across all commands, skills, and documentation
- Added `COUNCIL_PLUGIN_ROOT` persistence via SessionStart hook
- Updated all 52 instances to use absolute path resolution

**Lesson learned**: Always use environment variables for plugin file paths, even during local development.

---

## Testing Path Resolution

### Test in Local Development

```bash
# Verify COUNCIL_PLUGIN_ROOT is set (after session start)
echo "$COUNCIL_PLUGIN_ROOT"

# Verify fallback works when COUNCIL_PLUGIN_ROOT is unset
unset COUNCIL_PLUGIN_ROOT
# Your code should fall back to CLAUDE_PLUGIN_ROOT or CLAUDE_PROJECT_DIR
```

### Test in Marketplace Installation

```bash
# Install plugin via marketplace
claude plugin install llm-council

# Start Claude Code in a different directory
cd ~/my-project

# Verify plugin commands work
/council "test question"

# Check environment variables
echo "COUNCIL_PLUGIN_ROOT=$COUNCIL_PLUGIN_ROOT"
echo "CLAUDE_PLUGIN_ROOT=$CLAUDE_PLUGIN_ROOT"
echo "CLAUDE_PROJECT_DIR=$CLAUDE_PROJECT_DIR"
```

### Expected Values

**Local development**:
```bash
COUNCIL_PLUGIN_ROOT=/home/user/llm-council-plugin
CLAUDE_PLUGIN_ROOT=                              # Empty
CLAUDE_PROJECT_DIR=/home/user/llm-council-plugin
```

**Marketplace installation**:
```bash
COUNCIL_PLUGIN_ROOT=/home/user/.claude/plugins/cache/llm-council-plugin
CLAUDE_PLUGIN_ROOT=/home/user/.claude/plugins/cache/llm-council-plugin
CLAUDE_PROJECT_DIR=/home/user/my-project
```

---

## Quick Reference

### Plugin Files Pattern (Copy-Paste)

```bash
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    SCRIPT_PATH="${COUNCIL_PLUGIN_ROOT}/path/to/file"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    SCRIPT_PATH="${CLAUDE_PLUGIN_ROOT}/path/to/file"
else
    SCRIPT_PATH="${CLAUDE_PROJECT_DIR}/path/to/file"
fi
```

### User Files Pattern (Copy-Paste)

```bash
USER_FILE="${CLAUDE_PROJECT_DIR}/.council/file.txt"
```

### Internal Script Relative Paths (Copy-Paste)

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RELATIVE_FILE="${SCRIPT_DIR}/sibling_file.sh"
```

---

## Common Errors and Solutions

### Error: "No such file or directory: ./skills/..."

**Cause**: Using relative paths

**Solution**: Use environment variable pattern

```bash
# ❌ Wrong
source ./skills/council-orchestrator/scripts/utils.sh

# ✅ Correct
PLUGIN_ROOT="${COUNCIL_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR}}}"
source "${PLUGIN_ROOT}/skills/council-orchestrator/scripts/utils.sh"
```

### Error: "File not found" for plugin files in hooks

**Cause**: Using `CLAUDE_PROJECT_DIR` for plugin files

**Solution**: Use `CLAUDE_PLUGIN_ROOT` with fallback

```bash
# ❌ Wrong (in hooks)
SCRIPT_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/run.sh"

# ✅ Correct (in hooks)
if [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    SCRIPT_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/run.sh"
else
    SCRIPT_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/run.sh"
fi
```

### Error: "COUNCIL_PLUGIN_ROOT not set"

**Cause**: Accessing before SessionStart hook runs

**Solution**: Use full fallback chain

```bash
# ✅ Always works
PLUGIN_ROOT="${COUNCIL_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PROJECT_DIR}}}"
```

---

## Official References

- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md) - Official best practices
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks.md) - API reference
- [Local hooks documentation](../hooks/README.md) - Plugin-specific implementation details

---

*For comprehensive development guidelines, see @docs/DEVELOPMENT.md*
