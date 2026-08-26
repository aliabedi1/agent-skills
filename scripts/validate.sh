#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAILED=0
COUNT=0
SEEN_NAMES="$(mktemp)"
trap 'rm -f "$SEEN_NAMES"' EXIT

bash -n "$REPO_ROOT/install.sh" "$REPO_ROOT/scripts/sync-from-local.sh" "$REPO_ROOT/scripts/validate.sh"

while IFS= read -r -d '' skill_dir; do
  COUNT=$((COUNT + 1))
  if [[ ! -s "$skill_dir/SKILL.md" ]]; then
    printf 'Missing or empty SKILL.md: %s\n' "$skill_dir" >&2
    FAILED=1
  fi
  skill_name="$(basename "$skill_dir")"
  if grep -Fqx "$skill_name" "$SEEN_NAMES"; then
    printf 'Duplicate skill name across collections: %s\n' "$skill_name" >&2
    FAILED=1
  else
    printf '%s\n' "$skill_name" >> "$SEEN_NAMES"
  fi
done < <(find "$REPO_ROOT/collections" -mindepth 2 -maxdepth 2 -type d -print0)

if [[ "$COUNT" -eq 0 ]]; then
  printf 'No skills found.\n' >&2
  exit 1
fi

if find "$REPO_ROOT/collections" -type l -print -quit | grep -q .; then
  printf 'Symlinks are not allowed because they are not portable across machines.\n' >&2
  FAILED=1
fi

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi

printf 'Validated %d skills.\n' "$COUNT"
