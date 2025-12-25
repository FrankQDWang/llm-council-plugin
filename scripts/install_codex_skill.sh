#!/usr/bin/env bash
#
# Install this repo's Codex assets (skills + /council prompts) into $CODEX_HOME.
#
# Default CODEX_HOME: $HOME/.codex
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"

timestamp() {
    date +"%Y%m%d%H%M%S"
}

backup_if_exists() {
    local target="$1"
    if [[ -e "$target" ]]; then
        local bak="${target}.bak-$(timestamp)"
        echo "Backing up existing: $target -> $bak" >&2
        mv "$target" "$bak"
    fi
}

copy_dir() {
    local src="$1"
    local dst_parent="$2"

    if command -v rsync >/dev/null 2>&1; then
        rsync -a "$src" "$dst_parent/"
    else
        cp -a "$src" "$dst_parent/"
    fi
}

mkdir -p "$CODEX_HOME/skills" "$CODEX_HOME/prompts"

# Skills
backup_if_exists "$CODEX_HOME/skills/council-orchestrator"
backup_if_exists "$CODEX_HOME/skills/council-chairman"
copy_dir "$REPO_ROOT/skills/council-orchestrator" "$CODEX_HOME/skills"
copy_dir "$REPO_ROOT/skills/council-chairman" "$CODEX_HOME/skills"

# Prompts (/council, /council-cleanup, etc.)
for p in \
    council.md \
    council-cleanup.md \
    council-help.md \
    council-status.md \
    council-config.md \
    council-verify-deps.md; do
    backup_if_exists "$CODEX_HOME/prompts/$p"
    cp -f "$REPO_ROOT/codex/prompts/$p" "$CODEX_HOME/prompts/$p"
done

# Ensure scripts are executable (in case of ZIP/Windows transfers)
chmod +x "$CODEX_HOME/skills/council-orchestrator/scripts/"*.sh 2>/dev/null || true

echo "Installed to: $CODEX_HOME" >&2
echo "Try in Codex CLI: /council \"your question\"" >&2
