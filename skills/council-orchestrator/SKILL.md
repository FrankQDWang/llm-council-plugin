---
name: council-orchestrator
description: Orchestrates multi-model deliberation by coordinating OpenAI Codex, Google Gemini, and Claude CLIs. Manages the three-phase consensus protocol including opinion collection, peer review, and chairman synthesis.
license: MIT
version: 1.0.0
---

# Council Orchestration Protocol

## Overview

This skill defines the Standard Operating Procedure (SOP) for the LLM Council. You act as the Coordinator - you do not generate answers directly, but orchestrate external CLI tools to gather and synthesize responses.

## Prerequisites Check

Before executing any operation, verify the following CLI tools are available:

1. `claude` (Claude Code CLI) - **Required**
2. `codex` (OpenAI Codex CLI) - Optional
3. `gemini` (Google Gemini CLI) - Optional

Run these checks using:
```bash
command -v claude && echo "claude: available" || echo "claude: MISSING - see https://claude.ai/code"
command -v codex && echo "codex: available" || echo "codex: MISSING - install with: npm install -g @openai/codex"
command -v gemini && echo "gemini: available" || echo "gemini: MISSING - install with: npm install -g @google/gemini-cli"
```

If Claude CLI is missing, the council cannot proceed. For Codex and Gemini, if missing, proceed with available members (minimum 1 required for single-model mode, 2 of 3 for full council).

## Execution Flow

### Phase 1: Opinion Collection (Parallel Execution)

1. **Parse Input**: Extract the core technical question from the user's prompt.

2. **Create Working Directory**:
   ```bash
   mkdir -p .council
   ```

3. **Check Available CLIs**: Determine which council members are available:
   ```bash
   CLAUDE_AVAILABLE=$(command -v claude &>/dev/null && echo "yes" || echo "no")
   CODEX_AVAILABLE=$(command -v codex &>/dev/null && echo "yes" || echo "no")
   GEMINI_AVAILABLE=$(command -v gemini &>/dev/null && echo "yes" || echo "no")
   ```

4. **Invoke Available Members**: Execute available CLI wrappers in parallel:

   **Single-Model Mode (Claude only)**:
   If only Claude is available, run in single-model mode for testing:
   ```bash
   ./skills/council-orchestrator/scripts/query_claude.sh "{query}" > .council/stage1_claude.txt 2>&1
   ```

   **Full Council Mode (2+ members)**:
   Execute all available CLI wrappers in parallel using background jobs:
   ```bash
   # Only run if CLI is available
   [[ "$CODEX_AVAILABLE" == "yes" ]] && ./skills/council-orchestrator/scripts/query_codex.sh "{query}" > .council/stage1_openai.txt 2>&1 &
   [[ "$GEMINI_AVAILABLE" == "yes" ]] && ./skills/council-orchestrator/scripts/query_gemini.sh "{query}" > .council/stage1_gemini.txt 2>&1 &
   [[ "$CLAUDE_AVAILABLE" == "yes" ]] && ./skills/council-orchestrator/scripts/query_claude.sh "{query}" > .council/stage1_claude.txt 2>&1 &
   wait
   ```

5. **Validate Outputs**: Check that output files are non-empty. Mark empty responses as "member absent".

### Phase 2: Peer Review (Cross-Examination)

1. **Read Stage 1 Outputs**: Load all three response files.

2. **Construct Review Prompts**: For each model, create a prompt containing:
   - The original user question
   - Anonymized responses from the other two models (labeled "Response A" and "Response B")
   - Review criteria: accuracy, code quality, security, completeness

3. **Execute Reviews**: Run each CLI again with the review prompts:
   ```bash
   ./skills/council-orchestrator/scripts/query_codex.sh "{review_prompt}" > .council/stage2_review_openai.txt 2>&1 &
   ./skills/council-orchestrator/scripts/query_gemini.sh "{review_prompt}" > .council/stage2_review_gemini.txt 2>&1 &
   ./skills/council-orchestrator/scripts/query_claude.sh "{review_prompt}" > .council/stage2_review_claude.txt 2>&1 &
   wait
   ```

### Phase 3: Chairman Synthesis

1. **Invoke Sub-agent**: Activate the `council-chairman` sub-agent.

2. **Provide Context**: Pass all files from `.council/` directory as initial context:
   - `stage1_*.txt` - Original responses
   - `stage2_review_*.txt` - Peer reviews

3. **Request Verdict**: Ask the chairman to generate a final Markdown report.

4. **Cleanup**: After receiving the report, remove the temporary directory:
   ```bash
   rm -rf .council
   ```

## Error Handling

- **Rate Limit (429)**: Implement exponential backoff, retry once after 5 seconds.
- **CLI Execution Error (non-zero exit)**: Mark the member as "absent" in the final report.
- **Empty Output**: Treat as execution failure, mark member absent.
- **Timeout**: If a CLI doesn't respond within 60 seconds, terminate and mark absent.

## Output Format

The final output should be the Chairman's Markdown report, containing:
- Executive Summary
- Council Debate Summary (table of divergences)
- Final Synthesized Recommendation
