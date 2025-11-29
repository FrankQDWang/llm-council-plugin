# Changelog

All notable changes to the LLM Council Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to semantic versioning principles.

## [Unreleased]

### Fixed
- Documented hook blocking issue for users with outdated cached versions (Issue #26)
- Added prominent troubleshooting reference in INSTALL.md

### Added
- Created CHANGELOG.md to track version history and breaking changes

## [2025-11-27] - Hook Validation Fix

### Fixed
- **[BREAKING FIX]** PreToolUse hook no longer blocks legitimate shell operators (`&&`, `||`, `|`, `;`) - Issue #26, Commit `78ac404`
- Hook validation now uses official Claude Code JSON schema with `hookSpecificOutput` wrapper
- Path resolution in hooks now correctly uses `CLAUDE_PLUGIN_ROOT` for marketplace installations

### Changed
- Updated hook validation to focus on actual security threats (obfuscation, injection) instead of blocking standard shell syntax
- Hooks now follow "allow by default" and "fail open" security principles per Claude Code best practices

### Added
- `scripts/verify-plugin-version.sh` - Diagnostic tool to detect and fix outdated cached plugin versions
- Comprehensive troubleshooting documentation in `docs/TROUBLESHOOTING.md`
- SessionStart hook to solve "Shell cwd was reset" issue via `CLAUDE_ENV_FILE`

### Migration Guide
If you installed the plugin before 2025-11-27 and see `"BLOCKED: Detected potentially dangerous pattern: &&"` errors:

1. Run the diagnostic script:
   ```bash
   ./scripts/verify-plugin-version.sh
   ```

2. Or manually update your cache:
   ```bash
   rm -rf ~/.claude/plugins/cache/llm-council-plugin
   claude plugin install llm-council-plugin@llm-council
   ```

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for comprehensive guidance.

## [2025-11-26] - Path Resolution Fix

### Fixed
- Fixed 52 instances of relative path usage (`./skills/...`) that caused plugin failure for marketplace installations - Issue #21, Commit `35c4eb2`
- Commands, skills, and documentation now use environment variable-based path resolution
- Hooks now correctly use `CLAUDE_PLUGIN_ROOT` for plugin files and `CLAUDE_PROJECT_DIR` for user files

### Added
- Comprehensive path resolution best practices in AGENTS.md
- Standard pattern for path resolution across all plugin components

### Changed
- All slash commands now use `COUNCIL_PLUGIN_ROOT → CLAUDE_PLUGIN_ROOT → CLAUDE_PROJECT_DIR` fallback chain
- SessionStart hook now persists `COUNCIL_PLUGIN_ROOT` via `CLAUDE_ENV_FILE` for session-wide availability

## [2025-11-Initial] - Initial Release

### Added
- Multi-model LLM consensus orchestration via council pattern
- Three-phase deliberation protocol (Opinion → Peer Review → Synthesis)
- Support for Claude, OpenAI Codex, and Google Gemini
- Slash commands: `/council`, `/council-status`, `/council-config`, `/council-cleanup`, `/council-help`
- `council-orchestrator` skill with parallel execution and retry logic
- PreToolUse and PostToolUse hooks for validation and intelligent context
- Comprehensive test suite (18 orchestrator tests, 17 hook tests)

### Features
- **Multi-model coordination**: Orchestrates Claude, OpenAI, and Gemini for collaborative problem-solving
- **Consensus-based output**: Chairman agent synthesizes final report from all perspectives
- **Rate limit handling**: Automatic retry with exponential backoff
- **Security validation**: Command validation, obfuscation detection, and sensitive data leak detection
- **Configurable**: Environment variables for timeouts, retry behavior, and validation thresholds

---

## References

- [Official Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide.md)
- [Plugin Development Best Practices](https://code.claude.com/docs/en/plugins.md)
- [Marketplace Schema](https://code.claude.com/docs/en/marketplace.md)

## Getting Help

- **Documentation**: See README.md, docs/INSTALL.md, docs/TROUBLESHOOTING.md
- **Issues**: https://github.com/xrf9268-hue/llm-council-plugin/issues
- **Testing**: Run `./tests/test_runner.sh` before reporting issues
