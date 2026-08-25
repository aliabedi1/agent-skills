#!/usr/bin/env bash
set -euo pipefail

REPOSITORY="${AGENT_SKILLS_REPOSITORY:-aliabedi1/agent-skills}"
REF="${AGENT_SKILLS_REF:-main}"
TARGETS="${AGENT_SKILLS_TARGETS:-both}"
ARCHIVE_URL="${AGENT_SKILLS_ARCHIVE_URL:-https://codeload.github.com/${REPOSITORY}/tar.gz/refs/heads/${REF}}"
COMMAND="install"
PROFILE=""
UNINSTALL_SKILL=""
UNINSTALL_COLLECTION=""

usage() {
  cat <<'EOF'
Usage:
  ./install.sh [--profile minimal|backend|frontend|matt|cursor|all]
  ./install.sh doctor
  ./install.sh clean
  ./install.sh uninstall <skill-name>
  ./install.sh uninstall --collection <collection-name>

Set AGENT_SKILLS_COLLECTIONS to a comma-separated list of collections or skill
names. With no profile or selection, all collections are installed for backward
compatibility.
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

if [[ $# -gt 0 ]]; then
  case "$1" in
    doctor|clean)
      COMMAND="$1"
      shift
      ;;
    uninstall)
      COMMAND="uninstall"
      shift
      if [[ "${1:-}" == "--collection" ]]; then
        [[ $# -eq 2 ]] || die "Usage: $0 uninstall --collection <collection-name>"
        UNINSTALL_COLLECTION="$2"
      else
        [[ $# -eq 1 ]] || die "Usage: $0 uninstall <skill-name>"
        UNINSTALL_SKILL="${1:-}"
      fi
      shift "$#"
      ;;
  esac
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      [[ $# -ge 2 ]] || die "--profile requires a profile name"
      PROFILE="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *) die "Unknown argument: $1" ;;
  esac
done

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

remove_managed_entry() {
  local root="$1" skill="$2" file temp
  file="$(managed_file "$root")"
  [[ -f "$file" ]] || return 0
  ensure_managed_format "$root"
  temp="${file}.tmp.$$"
  awk -F '\t' -v name="$skill" '$1 != name' "$file" > "$temp"
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

remove_managed_skill() {
  local agent="$1" root="$2" skill="$3" destination
  if ! is_managed "$root" "$skill"; then
    return 0
  fi
  destination="$root/$skill"
  if [[ -e "$destination" || -L "$destination" ]]; then
    rm -rf -- "$destination"
    printf '[%s] removed managed skill %s\n' "$agent" "$skill"
  fi
  remove_managed_entry "$root" "$skill"
}

run_clean() {
  local agent root file copy skill _collection _location _timestamp _source
  while IFS=$'\t' read -r agent root; do
    file="$(managed_file "$root")"
    [[ -f "$file" ]] || continue
    ensure_managed_format "$root"
    copy="${file}.clean.$$"
    cp "$file" "$copy"
    while IFS=$'\t' read -r skill _collection _location _timestamp _source; do
      [[ -z "$skill" ]] && continue
      if ! valid_name "$skill"; then
        printf 'Ignoring invalid managed entry: %s\n' "$skill" >&2
        continue
      fi
      remove_managed_skill "$agent" "$root" "$skill"
    done < "$copy"
    rm -f -- "$copy"
  done < <(target_roots)
  printf 'Clean complete. Only skills listed in this repository\x27s managed manifests were removed.\n'
}

run_uninstall() {
  local agent root file copy skill collection _location _timestamp _source
  if [[ -n "$UNINSTALL_SKILL" ]]; then
    valid_name "$UNINSTALL_SKILL" || die "Invalid skill name: $UNINSTALL_SKILL"
  else
    valid_name "$UNINSTALL_COLLECTION" || die "Invalid collection name: $UNINSTALL_COLLECTION"
  fi
  while IFS=$'\t' read -r agent root; do
    file="$(managed_file "$root")"
    [[ -f "$file" ]] || continue
    ensure_managed_format "$root"
    copy="${file}.uninstall.$$"
    cp "$file" "$copy"
    while IFS=$'\t' read -r skill collection _location _timestamp _source; do
      [[ -z "$skill" ]] && continue
      if ! valid_name "$skill"; then
        printf 'Ignoring invalid managed entry: %s\n' "$skill" >&2
        continue
      fi
      if [[ -n "$UNINSTALL_SKILL" && "$skill" == "$UNINSTALL_SKILL" ]] || \
         [[ -n "$UNINSTALL_COLLECTION" && "$collection" == "$UNINSTALL_COLLECTION" ]]; then
        remove_managed_skill "$agent" "$root" "$skill"
      fi
    done < "$copy"
    rm -f -- "$copy"
  done < <(target_roots)
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
  printf 'Cleanup recommendations:\n'
  printf -- '- Use a focused profile or AGENT_SKILLS_COLLECTIONS for daily work.\n'
  if [[ -s "$duplicates" ]]; then
    printf -- '- Keep one owner for each duplicate and uninstall the managed copies you do not need.\n'
  fi
  printf -- '- Run %s clean to remove only repository-managed skills.\n' "$0"
  printf -- '- Plugin-provided skills cannot be inspected from filesystem roots; review enabled plugins separately.\n'
  rm -f "$inventory" "$duplicates"
}

if [[ "$COMMAND" == "doctor" ]]; then
  run_doctor
  exit 0
elif [[ "$COMMAND" == "clean" ]]; then
  run_clean
  exit 0
elif [[ "$COMMAND" == "uninstall" ]]; then
  run_uninstall
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
REPO_ROOT="$(dirname "$COLLECTIONS_ROOT")"
PROFILES_FILE="$REPO_ROOT/profiles.conf"

selectors="${AGENT_SKILLS_COLLECTIONS:-}"
if [[ -n "$PROFILE" ]]; then
  [[ -z "$selectors" ]] || die "Use either --profile or AGENT_SKILLS_COLLECTIONS, not both."
  [[ -f "$PROFILES_FILE" ]] || die "Profile configuration not found."
  selectors="$(awk -F '=' -v name="$PROFILE" '$1 == name { print $2; found=1 } END { exit !found }' "$PROFILES_FILE")" || die "Unknown profile: $PROFILE"
  printf 'Using profile %s (%s).\n' "$PROFILE" "$selectors"
elif [[ -z "$selectors" ]]; then
  selectors="all"
  printf 'No profile selected; installing all collections for backward compatibility.\n'
  printf 'For a smaller startup context, use --profile minimal or AGENT_SKILLS_COLLECTIONS.\n'
fi

SELECTED="$TEMP_DIR/selected.tsv"
: > "$SELECTED"
IFS=',' read -r -a requested <<< "$selectors"
for selector in "${requested[@]}"; do
  selector="${selector#"${selector%%[![:space:]]*}"}"
  selector="${selector%"${selector##*[![:space:]]}"}"
  [[ -n "$selector" ]] || continue
  if [[ "$selector" == "all" ]]; then
    while IFS= read -r -d '' skill_file; do
      skill_dir="$(dirname "$skill_file")"
      collection="$(basename "$(dirname "$skill_dir")")"
      printf '%s\t%s\t%s\n' "$(basename "$skill_dir")" "$collection" "$skill_dir" >> "$SELECTED"
    done < <(find "$COLLECTIONS_ROOT" -mindepth 3 -maxdepth 3 -type f -name SKILL.md -print0)
  elif [[ -d "$COLLECTIONS_ROOT/$selector" ]]; then
    while IFS= read -r -d '' skill_file; do
      skill_dir="$(dirname "$skill_file")"
      printf '%s\t%s\t%s\n' "$(basename "$skill_dir")" "$selector" "$skill_dir" >> "$SELECTED"
    done < <(find "$COLLECTIONS_ROOT/$selector" -mindepth 2 -maxdepth 2 -type f -name SKILL.md -print0)
  else
    matches=0
    while IFS= read -r -d '' skill_file; do
      skill_dir="$(dirname "$skill_file")"
      collection="$(basename "$(dirname "$skill_dir")")"
      printf '%s\t%s\t%s\n' "$selector" "$collection" "$skill_dir" >> "$SELECTED"
      matches=$((matches + 1))
    done < <(find "$COLLECTIONS_ROOT" -mindepth 3 -maxdepth 3 -type f -path "*/$selector/SKILL.md" -print0)
    [[ "$matches" -gt 0 ]] || die "Unknown collection or skill: $selector"
    [[ "$matches" -eq 1 ]] || die "Skill name is duplicated across repository collections: $selector"
  fi
done
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

if [[ "$CHANGED" -eq 0 ]]; then
  printf 'Selected managed skills are already up to date, or an existing owner was kept.\n'
else
  printf 'Selected skills are up to date. Replaced managed files were backed up under %s.\n' "$BACKUP_ROOT"
fi
printf 'Restart the affected agent so it reloads the skills. Run %s doctor to inspect ownership and context risk.\n' "$0"
