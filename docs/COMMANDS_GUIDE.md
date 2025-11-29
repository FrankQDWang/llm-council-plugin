# Slash Commands Development Guide

> **Purpose**: Comprehensive guide for developing slash commands in the LLM Council Plugin. Referenced from @CLAUDE.md via `@docs/COMMANDS_GUIDE.md`.

## Overview

Slash command files live in `commands/` and follow the official rule `/<command-name>` where `<command-name>` is derived from the Markdown filename (without `.md`).

Example: `council.md` → `/llm-council-plugin:council`

You can still present a shorter user-facing form like `/council` in the command body, but the namespaced form (`/plugin-name:<command-name>`) always comes from the filename.

---

## Command Execution Model

Our slash commands use the **instructional approach**:
- Commands provide implementation guidance for Claude through clear "Implementation Instructions" sections
- Claude intelligently uses its tools (Bash, Skill, etc.) to execute the instructions
- This allows for flexible error handling, context-aware execution, and intelligent decision-making

**Do NOT use**:
- ❌ Direct bash execution with `!bash` prefix (unless command is trivial and fixed)
- ❌ `allowed-tools` frontmatter (only needed for direct `!bash` execution)

**DO use**:
- ✅ Clear "Implementation Instructions" sections that explicitly state "Use the **Bash tool**" or "Use the **Skill tool**"
- ✅ Appropriate 2025 model selection in frontmatter
- ✅ Structured argument handling with `$ARGUMENTS` or positional parameters (`$1`, `$2`, `$3`)

---

## Model Selection Guidelines (2025)

All commands should specify appropriate models in frontmatter based on complexity:

| Model | Model ID | Use Case | Examples |
|-------|----------|----------|----------|
| **Opus 4.5** | `claude-opus-4-5-20251101` | Maximum reasoning capability, complex multi-step autonomous tasks, critical architectural decisions requiring absolute correctness | Advanced consensus synthesis, complex multi-agent coordination |
| **Sonnet 4.5** | `claude-sonnet-4-5-20250929` | Complex orchestration, multi-step workflows, advanced reasoning | `/council` (multi-model coordination) |
| **Haiku 4.5** | `claude-haiku-4-5-20251001` | Simple commands, configuration, status checks, help docs | `/council-config`, `/council-status`, `/council-help` |
| **Omit** | - | Inherit from user settings (good default for flexibility) | Commands that should adapt to user preference |

**Rationale**:
- **Opus 4.5** delivers maximum reasoning capability for mission-critical tasks requiring absolute correctness, complex multi-step logic chains, and long-horizon autonomous workflows. Use when the quality of reasoning justifies the higher cost (15% improvement on long-horizon tasks vs Sonnet, first model to score 80%+ on SWE-bench Verified).
- **Sonnet 4.5** provides excellent reasoning for complex tasks requiring coordination, synthesis, and multi-step logic. It delivers 90-95% of Opus capability at significantly reduced cost, making it ideal for most complex orchestration tasks.
- **Haiku 4.5** offers fast, economical performance for straightforward operations like displaying config, running status checks, or showing help
- Omitting `model` allows commands to inherit from the user's session settings, providing maximum flexibility

---

## Argument Handling Best Practices

### Use `$ARGUMENTS` for Single Conceptual Input

When the command takes a single conceptual input (e.g., a question, a query string):

```markdown
---
argument-hint: "<question>"
---

# Implementation Instructions

Treat `$ARGUMENTS` as the user's complete question...
```

**Example**: `/council How should I structure my React components?`
- `$ARGUMENTS` = `How should I structure my React components?`

### Use Positional Parameters for Structured Subcommands

When the command has structured subcommands or multiple distinct arguments:

```markdown
---
argument-hint: "[set <key> <value> | reset]"
---

# Implementation Instructions

When `$1` is 'set', use `$2` as key and `$3` as value...
When `$1` is 'reset', clear all configuration...
```

**Example**: `/council-config set max_retries 5`
- `$1` = `set`
- `$2` = `max_retries`
- `$3` = `5`

### Always Include argument-hint

The `argument-hint` frontmatter field guides auto-completion and user expectations:

```markdown
---
argument-hint: "<question>"        # Single input
argument-hint: "[subcommand]"       # Optional subcommand
argument-hint: "<required-arg>"     # Required argument
argument-hint: "[option] <value>"   # Mixed optional/required
---
```

---

## Council Working Directory Semantics (`.council/`)

These invariants are important for both user experience and testability:

### Core Rules

1. **`.council/` represents the most recent run**
   - The `/council` command is responsible for resetting the working directory at the **start** of each session
   - Example: `council_cleanup || true` followed by `council_init`

2. **DO NOT auto-cleanup at the end**
   - Do **not** automatically run `council_cleanup` at the end of a successful `/council` flow
   - Cleanup is an explicit user choice via `/council-cleanup` or manual `council_cleanup` invocation

3. **Accurate user-facing messages**
   - Never claim that `final_report.md` is saved in `.council/` if you have just removed the directory
   - When you delete `.council/`, clearly state that all session files (including `final_report.md`) are gone

4. **Historical reports (future)**
   - If you implement historical report retention, use a separate configurable directory (e.g. `COUNCIL_REPORTS_DIR`)
   - `.council/` remains a scratch space for the latest run only

### When Changing Council Commands

When changing `/council`, `/council-cleanup`, or the `council-orchestrator` skill:
- Keep these invariants intact
- Update tests in `tests/test_runner.sh` if behavior around `.council/` changes

---

## Command File Structure Template

```markdown
---
# Metadata (required)
description: Brief description of what this command does

# Arguments (if applicable)
argument-hint: "<arg-pattern>"

# Model selection (optional - omit to inherit from user settings)
model: claude-haiku-4-5-20251001

# Tool restrictions (only for !bash commands - usually omit)
# allowed-tools: [Bash, Read]
---

# Command Name

Brief user-facing description of the command.

## Usage

```
/command-name <arguments>
```

## Implementation Instructions

**Use the Bash tool** to execute the following steps:

1. Step 1 description
2. Step 2 description
3. Step 3 description

**Path Resolution** (for plugin scripts):
```bash
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
else
    UTILS_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/council_utils.sh"
fi

source "$UTILS_PATH"
```

## Error Handling

Describe how to handle common error scenarios.

## Output

Describe what the user should see when the command succeeds.
```

---

## Path Resolution in Commands

All commands must use **absolute paths** resolved via environment variables:

```bash
# Standard pattern for plugin files
if [[ -n "${COUNCIL_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${COUNCIL_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
elif [[ -n "${CLAUDE_PLUGIN_ROOT:-}" ]]; then
    UTILS_PATH="${CLAUDE_PLUGIN_ROOT}/skills/council-orchestrator/scripts/council_utils.sh"
else
    UTILS_PATH="${CLAUDE_PROJECT_DIR}/skills/council-orchestrator/scripts/council_utils.sh"
fi

source "$UTILS_PATH"
```

**For user project files**, use `CLAUDE_PROJECT_DIR` directly:
```bash
COUNCIL_DIR="${CLAUDE_PROJECT_DIR}/.council"
```

See @docs/PATH_RESOLUTION.md for comprehensive guide.

---

## Testing Commands

Before committing command changes:

```bash
# 1. Run full test suite
./tests/test_runner.sh

# 2. Validate plugin manifest
claude plugin validate .

# 3. Manual testing
# Test your command in a live Claude Code session
/your-command <test-args>
```

---

## Common Patterns

### Pattern 1: Simple Configuration Command
```markdown
---
description: Display or set configuration values
argument-hint: "[set <key> <value> | reset]"
model: claude-haiku-4-5-20251001
---

# Implementation Instructions

**Use the Bash tool**:

- If `$1` is empty, display current configuration
- If `$1` is 'set', update configuration with `$2=$3`
- If `$1` is 'reset', restore defaults
```

### Pattern 2: Complex Orchestration Command
```markdown
---
description: Orchestrate multi-model consensus deliberation
argument-hint: "<question>"
model: claude-sonnet-4-5-20250929
---

# Implementation Instructions

**Use the Skill tool** to activate the `council-orchestrator` skill:

1. Validate user input
2. Initialize working directory
3. Run three-phase deliberation
4. Generate final report
```

### Pattern 3: Status/Info Command
```markdown
---
description: Check system status
model: claude-haiku-4-5-20251001
---

# Implementation Instructions

**Use the Bash tool** to check:

1. CLI availability (claude, openai, gemini)
2. Configuration values
3. Working directory state
```

---

## Official References

- [Slash Commands - Claude Code Docs](https://code.claude.com/docs/en/slash-commands)
- [Command Best Practices - Claude Code Docs](https://code.claude.com/docs/en/common-workflows)
- [Model Configuration - Claude Code Docs](https://code.claude.com/docs/en/model-config)

---

*For comprehensive development guidelines, see @docs/DEVELOPMENT.md*
