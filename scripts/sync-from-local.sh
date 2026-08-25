#!/usr/bin/env bash
set -euo pipefail

SOURCE_AGENT="${1:-claude}"
COLLECTION="${2:-custom}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! [[ "$COLLECTION" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
  printf 'Invalid collection name: %s\n' "$COLLECTION" >&2
  exit 2
fi

case "$SOURCE_AGENT" in
  claude) SOURCE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills" ;;
  codex) SOURCE_DIR="${CODEX_HOME:-$HOME/.codex}/skills" ;;
  *)
    printf 'Usage: %s [claude|codex] [collection]\n' "$0" >&2
    exit 2
    ;;
esac

if [[ ! -d "$SOURCE_DIR" ]]; then
  printf 'Skills directory not found: %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

while IFS= read -r -d '' skill_file; do
  skill_dir="$(dirname "$skill_file")"
  skill_name="$(basename "$skill_dir")"
  [[ "$skill_name" == .* ]] && continue
  cp -a "$skill_dir" "$STAGING_DIR/$skill_name"
done < <(find "$SOURCE_DIR" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print0)

if [[ -z "$(find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -type d -print -quit)" ]]; then
  printf 'No valid skills with SKILL.md were found in %s\n' "$SOURCE_DIR" >&2
  exit 1
fi

DESTINATION="$REPO_ROOT/collections/$COLLECTION"
mkdir -p "$DESTINATION"
find "$DESTINATION" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +
cp -a "$STAGING_DIR/." "$DESTINATION/"
printf 'Synced %s into collection %s. Other collections were not changed. Review git diff, then commit and push.\n' "$SOURCE_DIR" "$COLLECTION"
