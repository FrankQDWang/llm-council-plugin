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

### Dependency Check Script

Run the comprehensive check using the council utilities:
```bash
source ./skills/council-orchestrator/scripts/council_utils.sh
get_cli_status
```

Or individually:
```bash
command -v claude && echo "claude: available" || echo "claude: MISSING - see https://claude.ai/code"
command -v codex && echo "codex: available" || echo "codex: MISSING - install with: npm install -g @openai/codex"
command -v gemini && echo "gemini: available" || echo "gemini: MISSING - install with: npm install -g @google/gemini-cli"
```

### Quorum Requirements

- **Minimum**: At least 1 CLI (Claude) required
- **Single-model mode**: Only Claude available - useful for testing
- **Reduced council**: 2 of 3 CLIs available - council can proceed with degraded coverage
- **Full council**: All 3 CLIs available - optimal consensus mechanism

If Claude CLI is missing, the council cannot proceed. For Codex and Gemini, if missing, proceed with available members and mark absent members in the final report.

## Execution Flow

### Phase 1: Opinion Collection (Parallel Execution)

1. **Parse Input**: Extract the core technical question from the user's prompt.

2. **Initialize Working Directory**:
   ```bash
   source ./skills/council-orchestrator/scripts/council_utils.sh
   council_init
   ```

3. **Check Available CLIs**: Determine which council members are available:
   ```bash
   CLAUDE_AVAILABLE=$(command -v claude &>/dev/null && echo "yes" || echo "no")
   CODEX_AVAILABLE=$(command -v codex &>/dev/null && echo "yes" || echo "no")
   GEMINI_AVAILABLE=$(command -v gemini &>/dev/null && echo "yes" || echo "no")
   MEMBER_COUNT=$(count_available_members)

   progress_msg "Available council members: $MEMBER_COUNT"
   ```

4. **Invoke Available Members**: Execute available CLI wrappers in parallel:

   **Single-Model Mode (Claude only)**:
   If only Claude is available, run in single-model mode for testing:
   ```bash
   progress_msg "Single-model mode: Consulting Claude..."
   ./skills/council-orchestrator/scripts/query_claude.sh "{query}" > .council/stage1_claude.txt 2>&1
   ```

   **Full Council Mode (2+ members)**:
   Execute all available CLI wrappers in parallel using background jobs:
   ```bash
   progress_msg "Full council mode: Consulting all available members in parallel..."

   # Track PIDs for wait
   PIDS=()

   # Launch Claude (required)
   if [[ "$CLAUDE_AVAILABLE" == "yes" ]]; then
       progress_msg "Consulting Claude..."
       ./skills/council-orchestrator/scripts/query_claude.sh "{query}" > .council/stage1_claude.txt 2>&1 &
       PIDS+=($!)
   fi

   # Launch Codex (optional)
   if [[ "$CODEX_AVAILABLE" == "yes" ]]; then
       progress_msg "Consulting OpenAI Codex..."
       ./skills/council-orchestrator/scripts/query_codex.sh "{query}" > .council/stage1_openai.txt 2>&1 &
       PIDS+=($!)
   fi

   # Launch Gemini (optional)
   if [[ "$GEMINI_AVAILABLE" == "yes" ]]; then
       progress_msg "Consulting Google Gemini..."
       ./skills/council-orchestrator/scripts/query_gemini.sh "{query}" > .council/stage1_gemini.txt 2>&1 &
       PIDS+=($!)
   fi

   # Wait for all background jobs to complete
   for pid in "${PIDS[@]}"; do
       wait "$pid" || true  # Continue even if one fails
   done

   progress_msg "All council members have responded."
   ```

5. **Validate Outputs**: Check that output files are non-empty using utility functions:
   ```bash
   ABSENT_MEMBERS=()

   validate_output ".council/stage1_claude.txt" "Claude" || ABSENT_MEMBERS+=("Claude")
   [[ "$CODEX_AVAILABLE" == "yes" ]] && validate_output ".council/stage1_openai.txt" "Codex" || ABSENT_MEMBERS+=("Codex")
   [[ "$GEMINI_AVAILABLE" == "yes" ]] && validate_output ".council/stage1_gemini.txt" "Gemini" || ABSENT_MEMBERS+=("Gemini")

   if [[ ${#ABSENT_MEMBERS[@]} -gt 0 ]]; then
       echo "Absent members: ${ABSENT_MEMBERS[*]}" >&2
   fi
   ```

### Phase 2: Peer Review (Cross-Examination)

1. **Read Stage 1 Outputs**: Load all available response files:
   ```bash
   CLAUDE_RESPONSE=""
   CODEX_RESPONSE=""
   GEMINI_RESPONSE=""

   [[ -s ".council/stage1_claude.txt" ]] && CLAUDE_RESPONSE=$(cat .council/stage1_claude.txt)
   [[ -s ".council/stage1_openai.txt" ]] && CODEX_RESPONSE=$(cat .council/stage1_openai.txt)
   [[ -s ".council/stage1_gemini.txt" ]] && GEMINI_RESPONSE=$(cat .council/stage1_gemini.txt)
   ```

2. **Construct Review Prompts**: For each model, create a prompt containing:
   - The original user question
   - Anonymized responses from the other available models (labeled "Response A", "Response B")
   - Review criteria: accuracy, code quality, security, completeness

   Example review prompt template:
   ```
   You are reviewing responses to this question: "{original_question}"

   Please evaluate the following responses:

   --- Response A ---
   {response_a}

   --- Response B ---
   {response_b}

   Review each response for:
   1. Technical accuracy
   2. Code quality (if applicable)
   3. Security considerations
   4. Completeness

   Provide a brief critique of each response, noting strengths and weaknesses.
   ```

3. **Execute Reviews in Parallel**: Run each available CLI with their review prompts:
   ```bash
   progress_msg "Starting peer review phase..."
   PIDS=()

   # Claude reviews Codex + Gemini responses
   if [[ "$CLAUDE_AVAILABLE" == "yes" && ( -n "$CODEX_RESPONSE" || -n "$GEMINI_RESPONSE" ) ]]; then
       progress_msg "Claude reviewing peer responses..."
       ./skills/council-orchestrator/scripts/query_claude.sh "{review_prompt_for_claude}" > .council/stage2_review_claude.txt 2>&1 &
       PIDS+=($!)
   fi

   # Codex reviews Claude + Gemini responses
   if [[ "$CODEX_AVAILABLE" == "yes" && ( -n "$CLAUDE_RESPONSE" || -n "$GEMINI_RESPONSE" ) ]]; then
       progress_msg "Codex reviewing peer responses..."
       ./skills/council-orchestrator/scripts/query_codex.sh "{review_prompt_for_codex}" > .council/stage2_review_openai.txt 2>&1 &
       PIDS+=($!)
   fi

   # Gemini reviews Claude + Codex responses
   if [[ "$GEMINI_AVAILABLE" == "yes" && ( -n "$CLAUDE_RESPONSE" || -n "$CODEX_RESPONSE" ) ]]; then
       progress_msg "Gemini reviewing peer responses..."
       ./skills/council-orchestrator/scripts/query_gemini.sh "{review_prompt_for_gemini}" > .council/stage2_review_gemini.txt 2>&1 &
       PIDS+=($!)
   fi

   # Wait for all reviews to complete
   for pid in "${PIDS[@]}"; do
       wait "$pid" || true
   done

   progress_msg "Peer review phase complete."
   ```

4. **Validate Review Outputs**: Ensure reviews were captured:
   ```bash
   validate_output ".council/stage2_review_claude.txt" "Claude Review" || true
   validate_output ".council/stage2_review_openai.txt" "Codex Review" || true
   validate_output ".council/stage2_review_gemini.txt" "Gemini Review" || true
   ```

### Phase 3: Chairman Synthesis

1. **Invoke Sub-agent**: Activate the `council-chairman` sub-agent.

2. **Provide Context**: Pass all files from `.council/` directory as initial context:
   - `stage1_*.txt` - Original responses
   - `stage2_review_*.txt` - Peer reviews

3. **Request Verdict**: Ask the chairman to generate a final Markdown report.

4. **Cleanup**: After receiving the report, clean up the working directory:
   ```bash
   source ./skills/council-orchestrator/scripts/council_utils.sh
   council_cleanup
   ```

   Or manually:
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
