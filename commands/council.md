---
description: Summon the LLM Council for multi-model deliberation on complex technical questions.
argument-hint: "<question>"
---

# Council

Summon the LLM Council for multi-model deliberation on complex technical questions.

## Usage

```
/council "Your technical question here"
```

## Examples

```
/council "How should I optimize React component re-renders?"
/council "What's the best approach for implementing rate limiting in a Node.js API?"
/council "Review this algorithm for potential edge cases"
```

## What Happens

1. **Opinion Collection**: Your query is sent to OpenAI Codex, Google Gemini, and Claude in parallel
2. **Peer Review**: Each model anonymously reviews the others' responses
3. **Synthesis**: The Chairman (Claude Opus) synthesizes all inputs into a final verdict

## Implementation

When this command is invoked:

1. Treat `$ARGUMENTS` as the user's full technical question (everything typed after `/council`).
2. Activate the `council-orchestrator` skill.
3. Pass `$ARGUMENTS` as the `{query}` parameter to the skill.
4. Display progress updates to the user:
   - "Consulting council members..."
   - "Running peer review..."
   - "Chairman is synthesizing the verdict..."
5. Return the final Markdown report to the user
