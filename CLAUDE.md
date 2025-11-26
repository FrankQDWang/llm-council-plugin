# LLM Council Plugin Development Context

## Repository Guidelines & Standards

All repository guidelines, project structure, and technical standards are documented in:
- @AGENTS.md – canonical reference for repository structure, naming conventions, testing, and commit guidelines

Follow this file as the single source of truth for:
- Project structure and module organization
- Plugin and marketplace metadata conventions
- Slash command development patterns
- Build, test, and development workflows
- Coding style and naming conventions
- Testing guidelines and requirements
- Commit and PR standards

## Quick References

- **Test suite**: Run `./tests/test_runner.sh` before committing
- **Hooks testing**: Run `./tests/test_hooks.sh` to validate hook behavior
- **Plugin validation**: Run `claude plugin validate .` before publishing manifest changes
- **Script permissions**: Ensure all new scripts have `chmod +x` applied
- **Hooks documentation**: See @hooks/README.md for security model and configuration

## Session Context

When working on this plugin:
1. Start sessions by reading the guidelines in @AGENTS.md
2. Review @hooks/README.md when modifying hook behavior or security logic
3. Keep manifest changes synchronized with installation documentation
4. Maintain test coverage for orchestration logic, hooks, and commands
5. Follow the naming convention: filenames → command names (e.g., `council.md` → `/council`)
