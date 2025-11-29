# Skills Development Guide (2025 Best Practices)

> **Purpose**: Comprehensive guide for developing skills in the LLM Council Plugin following 2025 Claude Code best practices. Referenced from @CLAUDE.md via `@docs/SKILLS_GUIDE.md`.

## Overview

Following the official Claude Code skills documentation, our skills adhere to these best practices:
- Schema-compliant frontmatter (no unofficial fields)
- Discovery-optimized descriptions with trigger terms
- Progressive disclosure pattern for complex skills
- Security documentation for external tool execution
- Template extraction for reusable prompts

---

## Frontmatter Schema Compliance

**Only use official fields** in SKILL.md frontmatter:

```markdown
---
name: skill-name                    # lowercase-with-hyphens (max 64 characters)
description: Brief description...   # What it does + when to use it (max 1024 characters)
allowed-tools: [Bash, Read, Write]  # Optional tool restrictions
---
```

**Do NOT add** unofficial fields like `license`, `version`, `author` in skill frontmatter. Store metadata in a separate `METADATA.md` file within the skill directory.

---

## Discovery-Optimized Descriptions

Descriptions should include **trigger terms** to help Claude recognize when to activate the skill.

### Good Example

```yaml
description: Orchestrates multi-model LLM consensus through a three-phase deliberation protocol. Use when you need collaborative AI review, multi-model problem-solving, code review from multiple perspectives, or consensus-based decision making.
```

### Key Elements

1. **Technical summary**: "Orchestrates multi-model LLM consensus through a three-phase deliberation protocol"
2. **Explicit activation phrase**: "Use when you need..."
3. **Trigger terms**: "collaborative AI review", "multi-model problem-solving", "consensus-based decision making"
4. **Workflow mention**: "three-phase deliberation protocol"

### Bad Example

```yaml
description: Runs the council orchestrator.
```

**Why it's bad**: Vague, no trigger terms, no activation guidance, no workflow details.

---

## Progressive Disclosure Pattern

For complex skills, split documentation into multiple files to reduce context consumption:

```
skills/skill-name/
├── SKILL.md           # Core workflow (~150 lines, Level 2 - always loaded)
├── REFERENCE.md       # Detailed implementation (Level 3 - on-demand)
├── EXAMPLES.md        # Usage scenarios (Level 3 - on-demand)
├── SECURITY.md        # Security guidelines (Level 3 - on-demand)
├── METADATA.md        # Version/license info (Level 3 - on-demand)
├── scripts/           # Executable utilities (Level 3 - executed, not loaded)
└── templates/         # Reusable templates (Level 3 - loaded when referenced)
```

### Loading Levels

- **Level 1**: Metadata from frontmatter (~100 tokens) - always in system prompt
- **Level 2**: SKILL.md content - loaded when skill is activated
- **Level 3**: Additional files - loaded only when explicitly referenced

### Benefits

- Reduces Level 2 context by 60-70%
- Faster skill activation
- Better maintainability
- On-demand detailed docs

### SKILL.md Structure (Level 2)

Keep SKILL.md focused on the **core workflow**:

```markdown
---
name: skill-name
description: [Discovery-optimized description with trigger terms]
allowed-tools: [Bash, Read]
---

# Skill Name

Brief overview (2-3 sentences).

## When to Use This Skill

- Use case 1
- Use case 2
- Use case 3

## Prerequisites

- Requirement 1
- Requirement 2

## Workflow

### Phase 1: [Phase Name]

1. Step description
2. Step description

### Phase 2: [Phase Name]

1. Step description
2. Step description

## Input Validation

```bash
# Basic validation pattern
validate_user_input "$query" || exit 1
```

For detailed validation, see @SECURITY.md

## Output

Describe expected output format and location.

## Common Issues

- Issue 1: Solution
- Issue 2: Solution

## See Also

- @REFERENCE.md - Detailed implementation guide
- @EXAMPLES.md - Usage examples
- @SECURITY.md - Security considerations
```

---

## Security for External Tool Execution

When skills execute external tools (CLIs, APIs), document security considerations:

### 1. Input Validation

Add `validate_user_input()` functions:

```bash
# In skills/skill-name/scripts/utils.sh
validate_user_input() {
  local query="$1"

  # Check for empty input
  if [[ -z "$query" ]]; then
    echo "Error: Query cannot be empty" >&2
    return 1
  fi

  # Check for command injection patterns
  if [[ "$query" =~ [\$\`\;] ]]; then
    echo "Error: Query contains potentially dangerous characters" >&2
    return 1
  fi

  # Check length limits
  if [[ ${#query} -gt 10000 ]]; then
    echo "Error: Query exceeds maximum length (10000 chars)" >&2
    return 1
  fi

  return 0
}
```

### 2. SECURITY.md

Create dedicated security documentation:

```markdown
# Security Guidelines

## Input Validation

This skill validates user input to prevent:
- Command injection attacks
- Excessive resource consumption
- Path traversal vulnerabilities

## Validation Rules

- Maximum query length: 10,000 characters
- Prohibited characters: `$`, `` ` ``, `;`
- Required: Non-empty input

## Safe Execution Patterns

### Pattern 1: Quoted Variables

```bash
# Safe
api_call --query "$user_input"

# Unsafe
api_call --query $user_input
```

### Pattern 2: Validation Before Execution

```bash
validate_user_input "$query" || exit 1
api_call --query "$query"
```

## External Dependencies

- `openai` CLI: Version 1.0.0+
- `gemini` CLI: Version 2.0.0+
- `jq`: Version 1.6+

## Credential Management

Never hardcode credentials. Use environment variables:
- `OPENAI_API_KEY`
- `GOOGLE_API_KEY`
```

### 3. Reference in SKILL.md

Link to security docs from main skill file:

```markdown
## Input Validation

```bash
# In SKILL.md
validate_user_input "$query" || exit 1
```

For comprehensive security guidelines, see @SECURITY.md
```

### 4. Sanitization Patterns

Document safe quoting and escaping:

```bash
# Always quote variables
echo "$user_input"

# Use printf for controlled output
printf '%s\n' "$user_input"

# Escape for JSON
jq -n --arg query "$user_input" '{query: $query}'
```

---

## Template Extraction

Extract reusable prompts to `templates/` directory:

```
templates/
├── review_prompt.txt      # Peer review template
└── synthesis_prompt.txt   # Output formatting template
```

### Variable Substitution Pattern

```bash
# Load template
PROMPT=$(cat templates/review_prompt.txt)

# Substitute variables
PROMPT="${PROMPT//\{\{QUESTION\}\}/$user_question}"
PROMPT="${PROMPT//\{\{MODEL\}\}/$model_name}"

# Use in API call
api_call --prompt "$PROMPT"
```

### Template Example

```
# templates/review_prompt.txt

You are reviewing responses to the following question:

{{QUESTION}}

Your task is to analyze the {{MODEL}} model's response and provide:
1. Strengths of the approach
2. Potential weaknesses or gaps
3. Suggestions for improvement

Be specific and constructive in your feedback.
```

---

## Validation Before Publishing

Before committing skill changes:

```bash
# 1. Validate plugin manifest
claude plugin validate .

# 2. Run test suite
./tests/test_runner.sh

# 3. Verify file structure
ls skills/skill-name/
# Expected: SKILL.md, REFERENCE.md, EXAMPLES.md, SECURITY.md, scripts/, templates/

# 4. Check frontmatter schema
head -n 10 skills/skill-name/SKILL.md
# Verify only official fields (name, description, allowed-tools)

# 5. Test skill activation
# Manually test in Claude Code session with trigger terms from description
```

---

## council-orchestrator Example

Our `council-orchestrator` skill demonstrates all these best practices:

✅ **Schema-compliant frontmatter** (no extra fields)
```yaml
---
name: council-orchestrator
description: Orchestrates multi-model LLM consensus through a three-phase deliberation protocol. Use when you need collaborative AI review, multi-model problem-solving, code review from multiple perspectives, or consensus-based decision making.
allowed-tools: [Bash, Read, Write]
---
```

✅ **Discovery-optimized description** with trigger terms
- "Use when you need..."
- "collaborative AI review"
- "multi-model problem-solving"
- "consensus-based decision making"

✅ **Progressive disclosure** (SKILL.md + REFERENCE.md + EXAMPLES.md)
- SKILL.md: ~150 lines, core workflow only
- REFERENCE.md: Detailed implementation
- EXAMPLES.md: Usage scenarios

✅ **Security documentation** (SECURITY.md)
- Input validation rules
- Safe execution patterns
- Credential management

✅ **Template extraction** (templates/)
- `review_prompt.txt`
- `synthesis_prompt.txt`

✅ **Input validation** (validate_user_input function)
```bash
validate_user_input "$query" || exit 1
```

---

## Common Patterns

### Pattern 1: Analysis-Only Skill

```markdown
---
name: code-analyzer
description: Analyzes code quality and suggests improvements. Use when you need code review, quality assessment, or refactoring suggestions.
allowed-tools: [Read]
---

# Code Analyzer Skill

Analyzes source code files for quality, maintainability, and best practices.

## Workflow

1. Read target files
2. Analyze code patterns
3. Generate report

See @REFERENCE.md for detailed analysis criteria.
```

### Pattern 2: Execution Skill with External Tools

```markdown
---
name: test-runner
description: Executes test suites and analyzes results. Use when you need to run tests, validate functionality, or check code coverage.
allowed-tools: [Bash, Read, Write]
---

# Test Runner Skill

Executes project tests and generates analysis reports.

## Security Considerations

See @SECURITY.md for input validation and safe execution patterns.

## Workflow

1. Validate test configuration
2. Execute test suite
3. Parse results
4. Generate report

See @REFERENCE.md for supported test frameworks.
```

---

## Official References

- [Agent Skills - Claude Code Docs](https://code.claude.com/docs/en/skills)
- [Skill Format - Claude Code Docs](https://code.claude.com/docs/en/skills#skill-format)
- [Memory Management - Claude Code Docs](https://code.claude.com/docs/en/memory)

---

*For comprehensive development guidelines, see @docs/DEVELOPMENT.md*
