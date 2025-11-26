# LLM Council CLI Plugin - Multi-Phase Implementation Plan

## Overview

This plan outlines the phased implementation of the LLM Council as a Claude Code Plugin, transforming the original web-based multi-model consensus system into a native terminal agent.

---

## Phase 1: Foundation & Minimal Viable Plugin

**Goal**: Establish the plugin skeleton and verify Claude Code recognizes and loads it correctly.

### 1.1 Plugin Manifest Setup
- [x] Create `.claude-plugin/plugin.json` with minimal required fields
- [x] Set `"strict": true` for development-time validation
- [x] Define placeholder paths for commands, agents, skills

### 1.2 Basic Slash Command
- [x] Create `commands/summon-council.md` with basic structure
- [x] Implement simple echo/acknowledgment response
- [ ] Verify `/council` command appears in Claude Code

### 1.3 Directory Structure
- [x] Created complete directory structure:
```
llm-council-plugin/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── council-chairman.md
├── skills/
│   └── council-orchestrator/
│       ├── SKILL.md
│       └── scripts/
├── commands/
│   └── summon-council.md
├── hooks/
│   └── hooks.json
└── .gitignore
```

### 1.4 Validation Criteria
- [ ] Plugin loads without errors in Claude Code
- [ ] `/council` command is visible and executable
- [ ] Skill metadata appears in Claude's available skills

---

## Phase 2: Single CLI Integration (Claude-only)

**Goal**: Implement the orchestration skill with a single CLI (Claude) to validate the core flow.

### 2.1 Claude CLI Wrapper Script
- [ ] Create `skills/council-orchestrator/scripts/query_claude.sh`
- [ ] Implement non-interactive mode using `claude -p` flag
- [ ] Handle `--output-format text` for clean output
- [ ] Test script independently in terminal

### 2.2 Basic Orchestrator Skill
- [ ] Write `skills/council-orchestrator/SKILL.md` with YAML frontmatter
- [ ] Implement dependency check (`command -v claude`)
- [ ] Define single-model query flow (Phase 1 only)
- [ ] Output to `.council/stage1_claude.txt`

### 2.3 Temporary Directory Management
- [ ] Create `.council/` directory handling in skill
- [ ] Implement cleanup logic after execution
- [ ] Add `.council/` to `.gitignore`

### 2.4 Validation Criteria
- `/council "test query"` successfully calls Claude CLI
- Output captured in `.council/stage1_claude.txt`
- No context pollution in main session

---

## Phase 3: Multi-CLI Integration (Parallel Execution)

**Goal**: Add Codex and Gemini CLIs with parallel execution support.

### 3.1 Codex CLI Wrapper
- [ ] Create `skills/council-orchestrator/scripts/query_codex.sh`
- [ ] Implement `codex exec` non-interactive mode
- [ ] Handle stdin piping for prompt delivery
- [ ] Test independently with simple prompts

### 3.2 Gemini CLI Wrapper
- [ ] Create `skills/council-orchestrator/scripts/query_gemini.sh`
- [ ] Implement `-p` flag and `--output-format json` mode
- [ ] Add `jq` parsing for clean text extraction
- [ ] Test independently with simple prompts

### 3.3 Parallel Execution Logic
- [ ] Update SKILL.md with parallel execution instructions
- [ ] Implement background job pattern (`&` and `wait`)
- [ ] Handle output redirection for all three CLIs:
  - `.council/stage1_openai.txt`
  - `.council/stage1_gemini.txt`
  - `.council/stage1_claude.txt`

### 3.4 Dependency Validation
- [ ] Add `command -v` checks for all three CLIs
- [ ] Implement graceful degradation (mark missing CLIs as "absent")
- [ ] Provide installation guidance for missing dependencies

### 3.5 Validation Criteria
- All three CLIs execute in parallel
- Total execution time ≈ max(individual times), not sum
- Missing CLIs handled gracefully without crashes

---

## Phase 4: Peer Review Implementation (Stage 2)

**Goal**: Implement cross-examination flow where each model reviews others' outputs.

### 4.1 Review Prompt Construction
- [ ] Design anonymized review prompt template
- [ ] Read Stage 1 outputs and inject into review prompts
- [ ] Focus review criteria: accuracy, code quality, security

### 4.2 Cross-Review Execution
- [ ] Codex reviews Gemini + Claude outputs
- [ ] Gemini reviews Codex + Claude outputs
- [ ] Claude reviews Codex + Gemini outputs
- [ ] Save to `.council/stage2_review_*.txt`

### 4.3 SKILL.md Updates
- [ ] Add Stage 2 flow documentation
- [ ] Define data transformation between stages
- [ ] Implement error handling for partial failures

### 4.4 Validation Criteria
- Review prompts correctly include anonymized prior outputs
- Stage 2 files contain substantive review content
- Flow continues even if one reviewer fails

---

## Phase 5: Chairman Sub-agent (Stage 3)

**Goal**: Implement the synthesis sub-agent that produces the final verdict.

### 5.1 Chairman Agent Definition
- [ ] Create `agents/council-chairman.md`
- [ ] Define system prompt for neutral arbitration
- [ ] Set model to `claude-opus-4.5` for reasoning depth
- [ ] Restrict tools to `Read, Write` only

### 5.2 Chairman Integration
- [ ] Update SKILL.md to invoke chairman sub-agent
- [ ] Pass `.council/` directory contents as context
- [ ] Define expected output format (Markdown report)

### 5.3 Report Generation
- [ ] Executive Summary section
- [ ] Debate Summary table (divergences + arguments)
- [ ] Final Synthesized Recommendation
- [ ] Save to `.council/final_report.md`

### 5.4 Context Isolation Verification
- [ ] Ensure chairman processes data in isolated context
- [ ] Verify main session only receives final report
- [ ] Clean up `.council/` after report generation

### 5.5 Validation Criteria
- Chairman correctly synthesizes all inputs
- Report follows specified format
- Main session context remains clean

---

## Phase 6: Hooks & Error Handling

**Goal**: Add lifecycle hooks for security and resilience.

### 6.1 Hooks Configuration
- [ ] Create `hooks/hooks.json` with PreToolUse/PostToolUse
- [ ] Create `hooks/pre-tool.sh` for input validation
- [ ] Create `hooks/post-tool.sh` for output verification

### 6.2 Security Measures
- [ ] Validate prompts for shell injection characters
- [ ] Check API quota/rate limit status before execution
- [ ] Sanitize outputs before passing between stages

### 6.3 Retry Logic
- [ ] Implement exponential backoff for rate limits (429)
- [ ] Handle empty outputs with automatic retry
- [ ] Set maximum retry attempts (1-2)

### 6.4 Graceful Degradation
- [ ] Mark failed members as "absent" in report
- [ ] Continue processing with available members
- [ ] Minimum quorum: at least 2 of 3 members

### 6.5 Validation Criteria
- Hooks trigger correctly on tool invocations
- Malformed inputs rejected before execution
- System recovers from transient failures

---

## Phase 7: User Experience Polish

**Goal**: Enhance the developer experience with progress feedback and configuration.

### 7.1 Progress Indicators
- [ ] Add status messages: "Consulting OpenAI...", "Running peer review..."
- [ ] Display estimated progress through stages
- [ ] Show which members responded/failed

### 7.2 Configuration Options
- [ ] Allow model selection override per CLI
- [ ] Support custom review criteria
- [ ] Enable/disable specific council members

### 7.3 Command Enhancements
- [ ] Add `/council help` for usage information
- [ ] Add `/council status` to check CLI availability
- [ ] Add `/council config` for settings management

### 7.4 Output Formatting
- [ ] Render final report with proper Markdown
- [ ] Highlight consensus points vs. divergences
- [ ] Include member attribution where relevant

### 7.5 Validation Criteria
- User receives clear progress feedback
- Configuration changes persist correctly
- Help/status commands provide useful information

---

## Phase 8: Testing & Documentation

**Goal**: Ensure reliability and provide comprehensive documentation.

### 8.1 Test Scenarios
- [ ] Happy path: all three CLIs respond correctly
- [ ] Partial failure: one CLI unavailable
- [ ] Total failure: network issues
- [ ] Edge cases: empty responses, timeout, large outputs

### 8.2 Integration Testing
- [ ] End-to-end test with real API calls
- [ ] Mock testing for CI/CD environments
- [ ] Performance benchmarking (latency, token usage)

### 8.3 Documentation
- [ ] README.md with quick start guide
- [ ] Installation instructions for each CLI
- [ ] Configuration reference
- [ ] Troubleshooting guide

### 8.4 Marketplace Preparation
- [ ] Create `.claude-plugin/marketplace.json`
- [ ] Prepare screenshots/examples
- [ ] Write marketplace description

### 8.5 Validation Criteria
- All test scenarios pass
- Documentation enables self-service installation
- Plugin ready for marketplace submission

---

## Implementation Notes

### Critical Path Dependencies
```
Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5
                                          ↓
                         Phase 6 ← ← ← ← ←
                                          ↓
                                      Phase 7
                                          ↓
                                      Phase 8
```

### Risk Mitigation
1. **CLI API Changes**: Monitor upstream repos for breaking changes
2. **Rate Limits**: Implement robust retry with backoff
3. **Context Overflow**: Leverage sub-agent isolation aggressively
4. **Dependency Hell**: Provide clear installation scripts

### Success Metrics
- Plugin loads and executes without errors
- Average latency < 60 seconds for full council session
- Graceful handling of partial failures
- Clear, actionable synthesis reports

---

## File Checklist

### Phase 1 Files
- [x] `.claude-plugin/plugin.json`
- [x] `commands/summon-council.md`
- [x] `skills/council-orchestrator/SKILL.md`
- [x] `agents/council-chairman.md`
- [x] `hooks/hooks.json`
- [x] `.gitignore`

### Phase 2-3 Files
- [ ] `skills/council-orchestrator/scripts/query_claude.sh`
- [ ] `skills/council-orchestrator/scripts/query_codex.sh`
- [ ] `skills/council-orchestrator/scripts/query_gemini.sh`

### Phase 5 Files
- [x] `agents/council-chairman.md` (created early in Phase 1)

### Phase 6 Files
- [x] `hooks/hooks.json` (minimal structure created in Phase 1)
- [ ] `hooks/pre-tool.sh`
- [ ] `hooks/post-tool.sh`

### Phase 8 Files
- [ ] `README.md`
- [ ] `.claude-plugin/marketplace.json`
- [ ] `tests/` (directory)

---

## Progress Log

### Phase 1 - COMPLETED (2025-11-26)
- Created plugin manifest with strict mode enabled
- Implemented `/council` slash command definition
- Created full SKILL.md with 3-phase orchestration protocol
- Created chairman sub-agent with Opus 4.5 and restricted tools
- Set up hooks.json placeholder for future security hooks
- Added .gitignore for .council/ temp directory

## Next Steps

1. ~~Begin with Phase 1 to establish the plugin foundation~~ DONE
2. Proceed to Phase 2: Single CLI Integration (Claude-only)
3. Validate each phase before proceeding to the next
4. Use incremental commits for easy rollback if needed
5. Test in isolation before integration
