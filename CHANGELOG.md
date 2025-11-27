# Changelog

All notable changes to the LLM Council Plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **Codex Integration**: Added `--skip-git-repo-check` flag to `query_codex.sh` to fix "Not inside a trusted directory" error when running Codex CLI in non-Git directories
- Fixed Codex member absence from Stage 1 and Stage 2 council deliberations

### Changed
- Increased default `CODEX_MAX_RETRIES` from 1 to 3 for better reliability during transient failures

### Added
- Added `check_codex_env.sh` script for validating Codex environment setup (CLI availability, API key, network connectivity)
- Added `test_codex_integration.sh` automated test suite for Codex CLI integration

## [Previous Releases]

See git history for earlier changes.
