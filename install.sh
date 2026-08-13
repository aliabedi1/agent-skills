#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${AGENT_SKILLS_REPOSITORY:-aliabedi1/agent-skills}"
REF="${AGENT_SKILLS_REF:-main}"
TARGETS="${AGENT_SKILLS_TARGETS:-both}"
ARCHIVE_URL="${AGENT_SKILLS_ARCHIVE_URL:-https://codeload.github.com/${REPOSITORY}/tar.gz/refs/heads/${REF}}"

case "$TARGETS" in
  both|codex|claude) ;;
  *)
    printf 'AGENT_SKILLS_TARGETS must be both, codex, or claude (received: %s)\n' "$TARGETS" >&2
    exit 2
    ;;
esac

for command_name in curl tar; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command_name" >&2
    exit 1
  fi
done

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

printf 'Downloading %s at %s...\n' "$REPOSITORY" "$REF"
curl --fail --silent --show-error --location "$ARCHIVE_URL" --output "$TEMP_DIR/repository.tar.gz"
tar -xzf "$TEMP_DIR/repository.tar.gz" -C "$TEMP_DIR"

SOURCE_DIR="$(find "$TEMP_DIR" -mindepth 2 -maxdepth 2 -type d -name skills -print -quit)"
if [[ -z "$SOURCE_DIR" ]]; then
  printf 'The downloaded repository does not contain a top-level skills directory.\n' >&2
  exit 1
fi

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
BACKUP_ROOT="${AGENT_SKILLS_BACKUP_DIR:-$HOME/.agent-skills-backups}/$TIMESTAMP"
CHANGED=0

valid_skill_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

backup_existing() {
  local destination="$1"
  local agent_name="$2"
  local skill_name="$3"

  if [[ -e "$destination" || -L "$destination" ]]; then
    mkdir -p "$BACKUP_ROOT/$agent_name"
    cp -a "$destination" "$BACKUP_ROOT/$agent_name/$skill_name"
  fi
}

sync_target() {
  local agent_name="$1"
  local destination_root="$2"
  local manifest="$destination_root/.agent-skills-managed"
  local new_manifest="$TEMP_DIR/manifest-$agent_name"
  local source_skill skill_name destination_skill

  mkdir -p "$destination_root"
  : > "$new_manifest"

  while IFS= read -r -d '' source_skill; do
    skill_name="$(basename "$source_skill")"
    if ! valid_skill_name "$skill_name"; then
      printf 'Skipping invalid skill directory name: %s\n' "$skill_name" >&2
      continue
    fi
    printf '%s\n' "$skill_name" >> "$new_manifest"
  done < <(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' \; -print0 | sort -z)

  if [[ -f "$manifest" ]]; then
    while IFS= read -r skill_name || [[ -n "$skill_name" ]]; do
      [[ -z "$skill_name" ]] && continue
      if ! valid_skill_name "$skill_name"; then
        printf 'Ignoring invalid entry in %s: %s\n' "$manifest" "$skill_name" >&2
        continue
      fi
      if ! grep -Fqx "$skill_name" "$new_manifest"; then
        destination_skill="$destination_root/$skill_name"
        if [[ -e "$destination_skill" || -L "$destination_skill" ]]; then
          backup_existing "$destination_skill" "$agent_name" "$skill_name"
          rm -rf "$destination_skill"
          printf '[%s] removed %s\n' "$agent_name" "$skill_name"
          CHANGED=1
        fi
      fi
    done < "$manifest"
  fi

  while IFS= read -r skill_name; do
    source_skill="$SOURCE_DIR/$skill_name"
    destination_skill="$destination_root/$skill_name"

    if [[ -d "$destination_skill" ]] && diff -qr "$source_skill" "$destination_skill" >/dev/null 2>&1; then
      continue
    fi

    backup_existing "$destination_skill" "$agent_name" "$skill_name"
    rm -rf "$destination_skill"
    cp -a "$source_skill" "$destination_skill"
    printf '[%s] installed %s\n' "$agent_name" "$skill_name"
    CHANGED=1
  done < "$new_manifest"

  mv "$new_manifest" "$manifest"
}

CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
CLAUDE_SKILLS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"

if [[ "$TARGETS" == "both" || "$TARGETS" == "codex" ]]; then
  sync_target codex "$CODEX_SKILLS_DIR"
fi

if [[ "$TARGETS" == "both" || "$TARGETS" == "claude" ]]; then
  sync_target claude "$CLAUDE_SKILLS_DIR"
fi

if [[ "$CHANGED" -eq 0 ]]; then
  printf 'All managed skills are already up to date.\n'
else
  printf 'Skills are up to date. Replaced files were backed up under %s when needed.\n' "$BACKUP_ROOT"
fi
printf 'Restart Codex and Claude Code to ensure they reload the skills.\n'
