# LLM Council Plugin Development Context

> **Purpose**: Core project instructions for AI agents. For comprehensive development guidelines, see @docs/DEVELOPMENT.md.

## What is LLM Council Plugin?

A Claude Code plugin that orchestrates **multi-model LLM consensus** through collaborative deliberation. Coordinates Claude, OpenAI Codex, and Google Gemini for:
- Collaborative AI code review
- Multi-perspective problem-solving
- Consensus-based decision making
- Three-phase deliberation protocol (Opinion → Peer Review → Synthesis)

**Use when**: You need multiple AI perspectives on complex decisions, code reviews, or architectural choices.

## Core Architecture

- **Phase 1**: Parallel opinion collection from available LLMs
- **Phase 2**: Anonymous cross-examination peer review
- **Phase 3**: Chairman agent synthesizes consensus
- **Output**: Comprehensive markdown report in `.council/final_report.md`

## Quick Development Workflow

**Before any commit**:
```bash
# 1. Run test suite (REQUIRED)
./tests/test_runner.sh

# 2. Validate manifests (if changed)
claude plugin validate .

# 3. Set execute permissions on NEW scripts (only if you added scripts)
find hooks/ skills/*/scripts/ tests/ -name "*.sh" -type f ! -perm -u+x -exec chmod +x {} \;
```

**Path resolution template** (copy-paste for commands/skills):
```bash
# Standard pattern - works for marketplace + local dev
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

## Project Structure

- `commands/` – Slash command definitions (e.g. `/council`, `/council-status`)
- `agents/` – Sub-agent definitions, especially the council chairman
- `skills/council-orchestrator/` – Core orchestration Skill and Bash scripts
- `hooks/` – Lifecycle hooks (`hooks.json`, `pre-tool.sh`, `post-tool.sh`)
- `tests/` – Minimal smoke tests and integration checks
- `.claude-plugin/` – Plugin manifest (`plugin.json`) and marketplace metadata (`marketplace.json`)
- `docs/` – User-facing docs; `INSTALL.md` is the canonical installation & debugging guide

## User-Facing Commands

- `/council <question>` - Start multi-model consensus deliberation
- `/council-status` - Check CLI availability and quorum status
- `/council-config [set <key> <value> | reset]` - Manage configuration
- `/council-cleanup` - Remove `.council/` working directory
- `/council-help` - Display usage documentation

## Key Development Patterns

### Slash Commands
- Use **instructional approach** (not `!bash` prefix)
- Model selection based on complexity:
  - **Opus 4.5** (`claude-opus-4-5-20251101`): Complex multi-step autonomous tasks
  - **Sonnet 4.5** (`claude-sonnet-4-5-20250929`): Complex orchestration, multi-step workflows
  - **Haiku 4.5** (`claude-haiku-4-5-20251001`): Simple commands, configuration, status checks
- Argument handling: Use `$ARGUMENTS` for single input, `$1 $2 $3` for structured subcommands
- See @docs/COMMANDS_GUIDE.md for detailed patterns

### Skills (2025 Best Practices)
- **Progressive disclosure**: SKILL.md (core workflow ~150 lines) + REFERENCE.md (details)
- **Discovery-optimized descriptions**: Include "Use when you need..." trigger terms
- **Security documentation**: SECURITY.md for external tool execution
- **Template extraction**: Reusable prompts in `templates/` directory
- See @docs/SKILLS_GUIDE.md for comprehensive guide

### Hooks (2025 Best Practices)
- **Structured JSON output** with `hookSpecificOutput` wrapper (required by API)
- **Security model**: Allow by default, fail open, validation over blocking
- **SessionStart**: Environment setup, sets `CLAUDE_BASH_MAINTAIN_PROJECT_WORKING_DIR=1`
- **PreToolUse**: Command validation before execution
- **PostToolUse**: Output analysis and intelligent context provision
- See @hooks/README.md or @docs/HOOKS_GUIDE.md for detailed documentation

### Path Resolution (Critical for Marketplace)
**For plugin files** (commands, skills, scripts, hooks):
- ✅ Use `COUNCIL_PLUGIN_ROOT` → `CLAUDE_PLUGIN_ROOT` → `CLAUDE_PROJECT_DIR` fallback
- ❌ Never use relative paths like `./skills/...`

**For user project files** (`.council/`, session data):
- ✅ Use `CLAUDE_PROJECT_DIR` directly

**Common mistake**: Using `CLAUDE_PROJECT_DIR` for plugin files will fail for marketplace installations.

See @docs/PATH_RESOLUTION.md for comprehensive guide and examples.

### Council Working Directory Semantics
- `.council/` always represents the **most recent** `/council` run
- `/council` command resets directory at **start** (not end) of each session
- Cleanup is explicit user choice via `/council-cleanup`
- User-facing messages must accurately reflect file state

## Plugin & Marketplace Metadata

- `plugin.json` describes the plugin (paths relative, starting with `./`)
- `marketplace.json` follows official marketplace schema
- When changing manifests, also update `docs/INSTALL.md` and `README.md`
- Validate before publishing: `claude plugin validate .`

**Official References**:
- [Plugin Manifest Reference](https://code.claude.com/docs/en/plugins-reference.md)
- [Marketplace Schema](https://code.claude.com/docs/en/marketplace.md)
- [Plugin Development Guide](https://code.claude.com/docs/en/plugins.md)

## Testing & Quality Assurance

```bash
./tests/test_runner.sh     # Full test suite (required before commits)
./tests/test_hooks.sh      # Hooks in isolation
claude plugin validate .   # Manifest validation
```

**Coverage requirements**:
- Happy path council runs
- Failure/degradation paths (missing CLIs, rate limits)
- Hook behavior (SessionStart, PreToolUse, PostToolUse)
- Edge cases (missing jq, timeouts, malformed input)

## Coding Style & Naming Conventions

- **Shell scripts**: `bash`, `set -euo pipefail`, 2-space indentation, `snake_case` functions, `UPPER_SNAKE_CASE` environment variables
- **Markdown**: Single H1, `##`/`###` structure, fenced code blocks with language tags
- **Paths in manifests**: Relative, starting with `./` (e.g. `"./commands/council.md"`)

Prefer small, composable scripts over large monoliths.

## Commit & Pull Request Guidelines

- **Commit format**: `scope: short imperative description`
- **Group related changes** into single commit
- **PR requirements**:
  - Brief summary of motivation and behavior change
  - Testing notes (`./tests/test_runner.sh` results)
  - User-facing changes called out explicitly

## Subagent Configuration

@AGENTS.md

## Comprehensive Development Guide

For detailed documentation on all development topics, see:

@docs/DEVELOPMENT.md

This includes:
- Complete project structure explanation
- Detailed command execution model
- Model selection rationale
- Progressive disclosure pattern for skills
- Hook development guidelines with examples
- Path resolution historical context
- Testing guidelines and requirements
- Common pitfalls and lessons learned
