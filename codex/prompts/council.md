# LLM Council (/council)

## User Question

$ARGUMENTS

## Execution

1) Persist the (possibly very long) question to a temp file:

```bash
QUERY_FILE="$(mktemp -t council-query.XXXXXX)"
cat > "$QUERY_FILE" << 'QUERY_EOF'
$ARGUMENTS
QUERY_EOF
```

2) Run Stage 1 + 2 + 3 via the installed skill scripts (this resets `.council/` for this run):

```bash
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
"$CODEX_HOME/skills/council-orchestrator/scripts/run_council.sh" --query-file "$QUERY_FILE" --output-dir .council
rm -f "$QUERY_FILE"
```

3) Display the final report (also saved at `.council/final_report.md`):

```bash
cat .council/final_report.md
```
