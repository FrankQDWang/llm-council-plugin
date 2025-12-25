# /council-help

LLM Council commands:

- `/council "question"`: run Stage 1 + 2 + 3 and write `.council/final_report.md`
- `/council-cleanup`: delete `.council/`
- `/council-status`: show CLI/config readiness
- `/council-config`: view/set/reset `~/.council/config`
- `/council-verify-deps`: verify required/optional dependencies

Tips:
- If Gemini is installed but not configured, disable it: `/council-config set enabled_members claude,codex`
- Increase long-question limit: `/council-config set max_prompt_length 200000`
- Switch Stage 3 chairman: `/council-config set chairman_provider codex|claude|auto`
