# LLM Council Plugin - Subagent Definitions

> **Purpose**: Defines subagents used by the LLM Council Plugin. This file is referenced from CLAUDE.md via `@AGENTS.md` to maintain a single source of truth.

## Overview

The LLM Council Plugin uses specialized subagents to orchestrate multi-model consensus deliberation. Subagents operate in **separate context windows** from the main conversation, preventing context pollution and enabling longer sessions.

---

## Council Chairman Agent

**Location**: `agents/council-chairman.md`

**Purpose**: Chief arbiter of the LLM Council that synthesizes multi-model responses into a unified decision.

**Activation**: Automatically invoked during Phase 3 of council orchestration (after council members complete their responses).

**Model**: `claude-opus-4-5-20251101` (Opus 4.5)
- Rationale: Maximum reasoning capability for complex synthesis and arbitration
- Use case: Analyzing multiple perspectives, arbitrating disagreements, identifying consensus

**Tools**: Read, Write

**Input**:
- Original user question
- Path to `.council/` working directory containing:
  - `stage1_*.txt` - Initial responses from Claude, OpenAI, and Gemini
  - `stage2_review_*.txt` - Peer reviews from each model

**Output**: Comprehensive markdown report at `.council/final_report.md` with:
- Executive summary
- Council participation table
- Debate summary with verdicts
- Areas of consensus and disagreement
- Final synthesized recommendation
- Warnings and attribution

**Key Responsibilities**:
1. **Deep Reading**: Analyze each member's response for logic, quality, security, and completeness
2. **Find Consensus**: Identify points where all models agree
3. **Arbitrate Disagreements**: Determine correct position when models disagree
4. **Identify Hallucinations**: Call out and refute obviously incorrect or dangerous advice

**Constraints**:
- MUST remain neutral (no vendor favoritism)
- Does NOT call `codex`, `gemini`, or `claude` CLI tools
- Bases judgments on technical merit only
- Handles missing members gracefully (marks as "Absent")

**See**: `agents/council-chairman.md` for complete agent definition and prompt template.

---

## Adding New Subagents

To add a new subagent to the LLM Council Plugin:

1. **Create agent definition file**:
   ```bash
   # Create file in agents/ directory
   touch agents/agent-name.md
   ```

2. **Define agent using frontmatter schema**:
   ```markdown
   ---
   name: agent-name
   description: Brief description. Use when you need [specific use case].
   model: claude-sonnet-4-5-20250929  # or appropriate model
   tools: Read, Write, Bash  # Allowed tools
   ---

   # System Prompt

   [Agent instructions here...]
   ```

3. **Register in plugin manifest**:
   ```json
   // In .claude-plugin/plugin.json
   {
     "agents": [
       "./agents/council-chairman.md",
       "./agents/agent-name.md"  // Add your agent
     ]
   }
   ```

4. **Update this file**:
   - Add section documenting the new agent
   - Include purpose, activation, model, tools, and key responsibilities

5. **Validate and test**:
   ```bash
   claude plugin validate .
   ./tests/test_runner.sh
   ```

---

## Subagent Best Practices

**Model Selection**:
- **Opus 4.5**: Complex reasoning, synthesis, arbitration (like council-chairman)
- **Sonnet 4.5**: Balanced performance for most tasks
- **Haiku 4.5**: Fast, simple tasks

**Tool Restrictions**:
- Limit tools to minimum required for agent's purpose
- Use `tools: Read, Write` for analysis-only agents
- Add `Bash` only if agent needs to execute commands

**Description Guidelines**:
- Include "Use when you need..." trigger phrase
- Be specific about activation conditions
- Keep under 1024 characters

**Context Management**:
- Subagents run in separate context windows
- They don't pollute main conversation
- Enable longer overall sessions with focused threads

---

## Official References

- [Subagents - Claude Code Docs](https://code.claude.com/docs/en/sub-agents)
- [Agent Skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Memory Management - Claude Code Docs](https://code.claude.com/docs/en/memory)

---

*This file follows the official Claude Code AGENTS.md specification for subagent definitions.*
