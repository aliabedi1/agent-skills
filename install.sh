#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${AGENT_SKILLS_REPOSITORY:-aliabedi1/agent-skills}"
REF="${AGENT_SKILLS_REF:-main}"
TARGETS="${AGENT_SKILLS_TARGETS:-both}"
ARCHIVE_URL="${AGENT_SKILLS_ARCHIVE_URL:-https://codeload.github.com/${REPOSITORY}/tar.gz/refs/heads/${REF}}"
COMMAND="install"

usage() {
  cat <<'EOF'
Usage:
  ./install.sh
  ./install.sh doctor

Run without arguments to install every skill. Caveman and Unslop are then
configured as always-on Codex skills; every other skill remains available when
its description matches the task.
EOF
}

die() {
  printf '%s\n' "$*" >&2
  exit 2
}

valid_name() {
  [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]
}

case "$TARGETS" in
  both|codex|claude) ;;
  *) die "AGENT_SKILLS_TARGETS must be both, codex, or claude (received: $TARGETS)" ;;
esac

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 2
fi
if [[ $# -eq 1 ]]; then
  case "$1" in
    doctor) COMMAND="doctor" ;;
    --help|-h) usage; exit 0 ;;
    *) die "Only supported command is: $0 doctor" ;;
  esac
fi

CODEX_SKILLS_DIR="${CODEX_HOME:-$HOME/.codex}/skills"
CLAUDE_SKILLS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills"
CURSOR_SKILLS_DIR="${CURSOR_CONFIG_DIR:-$HOME/.cursor}/skills"

target_roots() {
  case "$TARGETS" in
    codex) printf 'codex\t%s\n' "$CODEX_SKILLS_DIR" ;;
    claude) printf 'claude\t%s\n' "$CLAUDE_SKILLS_DIR" ;;
    both)
      printf 'codex\t%s\n' "$CODEX_SKILLS_DIR"
      printf 'claude\t%s\n' "$CLAUDE_SKILLS_DIR"
      ;;
  esac
}

all_roots() {
  printf 'codex\t%s\n' "$CODEX_SKILLS_DIR"
  printf 'claude\t%s\n' "$CLAUDE_SKILLS_DIR"
  printf 'cursor\t%s\n' "$CURSOR_SKILLS_DIR"
}

managed_file() {
  printf '%s/.agent-skills-managed\n' "$1"
}

manifest_file() {
  printf '%s/.installed-skills.json\n' "$1"
}

is_managed() {
  local root="$1" skill="$2" file
  file="$(managed_file "$root")"
  [[ -f "$file" ]] && awk -F '\t' -v name="$skill" '$1 == name { found=1 } END { exit !found }' "$file"
}

ensure_managed_format() {
  local root="$1" file temp skill timestamp
  file="$(managed_file "$root")"
  [[ -f "$file" ]] || return 0
  if grep -q $'\t' "$file"; then
    return 0
  fi
  temp="${file}.tmp.$$"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  : > "$temp"
  while IFS= read -r skill || [[ -n "$skill" ]]; do
    [[ -z "$skill" ]] && continue
    valid_name "$skill" || continue
    printf '%s\tlegacy\t%s/%s\t%s\tlegacy/%s\n' "$skill" "$root" "$skill" "$timestamp" "$skill" >> "$temp"
  done < "$file"
  mv "$temp" "$file"
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

write_json_manifest() {
  local root="$1" managed json first skill collection location timestamp source
  managed="$(managed_file "$root")"
  json="$(manifest_file "$root")"
  mkdir -p "$root"
  {
    printf '[\n'
    first=1
    if [[ -f "$managed" ]]; then
      while IFS=$'\t' read -r skill collection location timestamp source; do
        [[ -z "$skill" ]] && continue
        [[ "$first" -eq 1 ]] || printf ',\n'
        first=0
        printf '  {"skill":"%s","source_collection":"%s","source":"%s","install_location":"%s","timestamp":"%s"}' \
          "$(json_escape "$skill")" "$(json_escape "$collection")" "$(json_escape "$source")" \
          "$(json_escape "$location")" "$(json_escape "$timestamp")"
      done < "$managed"
    fi
    printf '\n]\n'
  } > "$json"
}

upsert_managed() {
  local root="$1" skill="$2" collection="$3" location="$4" source="$5"
  local file temp timestamp
  file="$(managed_file "$root")"
  temp="${file}.tmp.$$"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$root"
  ensure_managed_format "$root"
  if [[ -f "$file" ]]; then
    awk -F '\t' -v name="$skill" '$1 != name' "$file" > "$temp"
  else
    : > "$temp"
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$skill" "$collection" "$location" "$timestamp" "$source" >> "$temp"
  sort -t $'\t' -k1,1 "$temp" -o "$temp"
  mv "$temp" "$file"
  write_json_manifest "$root"
}

warn_duplicate() {
  local skill="$1" source="$2"
  shift 2
  printf 'Duplicate skill detected:\n%s\n\nSources:\n- %s\n' "$skill" "$source" >&2
  printf -- '- %s\n' "$@" >&2
  printf 'Owner: %s (existing installation is kept)\n\n' "$1" >&2
}

existing_sources() {
  local skill="$1" excluded_root="${2:-}" agent root path
  while IFS=$'\t' read -r agent root; do
    [[ "$root" == "$excluded_root" ]] && continue
    path="$root/$skill"
    if [[ -d "$path" || -L "$path" ]]; then
      printf '%s\n' "$path"
    fi
  done < <(all_roots)
}

configure_codex_always_on() {
  local codex_root="$1" instructions temp
  local marker_start="# >>> agent-skills always-on >>>"
  local marker_end="# <<< agent-skills always-on <<<"

  instructions="$codex_root/AGENTS.md"
  mkdir -p "$codex_root"
  temp="${instructions}.tmp.$$"
  if [[ -f "$instructions" ]]; then
    awk -v start="$marker_start" -v end="$marker_end" '
      $0 == start { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "$instructions" > "$temp"
  else
    : > "$temp"
  fi
  cat >> "$temp" <<EOF

$marker_start
## Always-on skills

At the start of every task, invoke and follow \`\$caveman\` and \`\$unslop\`.
Keep higher-priority instructions and explicit user requests authoritative.
$marker_end
EOF
  mv "$temp" "$instructions"
  printf '[codex] configured always-on caveman and unslop\n'
}

run_doctor() {
  local inventory duplicates managed_count total_count risk agent root path skill collection active_collections
  inventory="$(mktemp)"
  duplicates="$(mktemp)"
  managed_count=0
  while IFS=$'\t' read -r agent root; do
    [[ -d "$root" ]] || continue
    while IFS= read -r -d '' path; do
      skill="$(basename "$path")"
      valid_name "$skill" || continue
      printf '%s\t%s\n' "$skill" "$path" >> "$inventory"
      if is_managed "$root" "$skill"; then
        managed_count=$((managed_count + 1))
      fi
    done < <(find "$root" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/SKILL.md' \; -print0 2>/dev/null)
  done < <(all_roots)
  total_count="$(wc -l < "$inventory" | tr -d ' ')"
  cut -f1 "$inventory" | sort | uniq -d > "$duplicates"
  printf 'Agent Skills doctor\n\n'
  printf 'Installed skills: %s discovered (%s managed by this repository)\n' "$total_count" "$managed_count"
  active_collections="$({
    while IFS=$'\t' read -r agent root; do
      [[ -f "$(managed_file "$root")" ]] || continue
      ensure_managed_format "$root"
      while IFS=$'\t' read -r skill collection _; do
        [[ -n "$collection" ]] && printf '%s\n' "$collection"
      done < "$(managed_file "$root")"
    done < <(all_roots)
  } | sort -u | paste -sd, -)"
  printf 'Active collections: %s\n' "${active_collections:-none}"
  printf '\nSkill sources:\n'
  if [[ -s "$inventory" ]]; then
    sort "$inventory" | awk -F '\t' '{ printf "- %s: %s\n", $1, $2 }'
  else
    printf -- '- none\n'
  fi
  printf '\nDuplicate skills:\n'
  if [[ -s "$duplicates" ]]; then
    while IFS= read -r skill; do
      printf -- '- %s\n' "$skill"
      awk -F '\t' -v name="$skill" '$1 == name { printf "  - %s\n", $2 }' "$inventory"
    done < "$duplicates"
  else
    printf -- '- none\n'
  fi
  if [[ "$total_count" -ge 50 ]]; then risk="high"; elif [[ "$total_count" -ge 25 ]]; then risk="medium"; else risk="low"; fi
  printf '\nContext size warning risk: %s (%s installed skill directories)\n' "$risk" "$total_count"
  printf 'Recommendations:\n'
  if [[ -s "$duplicates" ]]; then
    printf -- '- Keep one owner for each duplicate before reinstalling.\n'
  fi
  printf -- '- Run %s to install or update every skill.\n' "$0"
  printf -- '- Plugin-provided skills cannot be inspected from filesystem roots; review enabled plugins separately.\n'
  rm -f "$inventory" "$duplicates"
}

if [[ "$COMMAND" == "doctor" ]]; then
  run_doctor
  exit 0
fi

for command_name in curl tar find sort; do
  command -v "$command_name" >/dev/null 2>&1 || die "Required command not found: $command_name"
done

TEMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TEMP_DIR"' EXIT

printf 'Downloading %s at %s...\n' "$REPOSITORY" "$REF"
if [[ -f "$ARCHIVE_URL" ]]; then
  cp "$ARCHIVE_URL" "$TEMP_DIR/repository.tar.gz"
else
  curl --fail --silent --show-error --location "$ARCHIVE_URL" --output "$TEMP_DIR/repository.tar.gz"
fi
tar -xzf "$TEMP_DIR/repository.tar.gz" -C "$TEMP_DIR"

COLLECTIONS_ROOT="$(find "$TEMP_DIR" -mindepth 2 -maxdepth 2 -type d -name collections -print -quit)"
[[ -n "$COLLECTIONS_ROOT" ]] || die "The downloaded repository does not contain a top-level collections directory."
printf 'Installing every available skill.\n'

SELECTED="$TEMP_DIR/selected.tsv"
: > "$SELECTED"
while IFS= read -r -d '' skill_file; do
  skill_dir="$(dirname "$skill_file")"
  collection="$(basename "$(dirname "$skill_dir")")"
  printf '%s\t%s\t%s\n' "$(basename "$skill_dir")" "$collection" "$skill_dir" >> "$SELECTED"
done < <(find "$COLLECTIONS_ROOT" -mindepth 3 -maxdepth 3 -type f -name SKILL.md -print0)
sort -t $'\t' -k1,1 -u "$SELECTED" -o "$SELECTED"
[[ -s "$SELECTED" ]] || die "The selection did not contain any skills."

BACKUP_ROOT="${AGENT_SKILLS_BACKUP_DIR:-$HOME/.agent-skills-backups}/$(date -u +%Y%m%dT%H%M%SZ)-$$"
CHANGED=0
while IFS=$'\t' read -r agent root; do
  mkdir -p "$root"
  ensure_managed_format "$root"
  while IFS=$'\t' read -r skill collection source_dir; do
    valid_name "$skill" || die "Invalid skill directory name: $skill"
    destination="$root/$skill"
    source_label="collections/$collection/$skill"
    if is_managed "$root" "$skill"; then
      if [[ -d "$destination" ]] && diff -qr "$source_dir" "$destination" >/dev/null 2>&1; then
        continue
      fi
      if [[ -e "$destination" || -L "$destination" ]]; then
        mkdir -p "$BACKUP_ROOT/$agent"
        cp -a "$destination" "$BACKUP_ROOT/$agent/$skill"
        rm -rf -- "$destination"
      fi
    else
      owners=()
      while IFS= read -r owner; do
        [[ -n "$owner" ]] && owners+=("$owner")
      done < <(existing_sources "$skill" "$root")
      if [[ -e "$destination" || -L "$destination" ]]; then
        owners=("$destination" "${owners[@]}")
      fi
      if [[ "${#owners[@]}" -gt 0 ]]; then
        warn_duplicate "$skill" "$source_label" "${owners[@]}"
        continue
      fi
    fi
    cp -a "$source_dir" "$destination"
    upsert_managed "$root" "$skill" "$collection" "$destination" "$source_label"
    printf '[%s] installed %s (%s)\n' "$agent" "$skill" "$collection"
    CHANGED=1
  done < "$SELECTED"
done < <(target_roots)

if [[ "$TARGETS" == "both" || "$TARGETS" == "codex" ]]; then
  configure_codex_always_on "${CODEX_HOME:-$HOME/.codex}"
fi

if [[ "$CHANGED" -eq 0 ]]; then
  printf 'Selected managed skills are already up to date, or an existing owner was kept.\n'
else
  printf 'Selected skills are up to date. Replaced managed files were backed up under %s.\n' "$BACKUP_ROOT"
fi
printf 'Restart the affected agent so it reloads the skills. Run %s doctor to inspect ownership and context risk.\n' "$0"
