# Agent Skills

Portable, versioned skills for Codex, Claude Code, and Cursor-oriented workflows. The repository keeps every skill available, but the installers let each machine activate only the collections needed for the current kind of work.

## Why selective installation matters

An installed skill is copied into an agent's scanned skills directory and may consume startup context. An available skill remains in this repository but consumes no agent context until installed. Installing the whole catalog can make Codex report:

> Skill descriptions were shortened to fit the skills context budget

That warning does not delete skills, but it means Codex had to truncate the descriptions used to decide when skills apply. Focused collections and profiles keep that routing context useful. Plugins can also expose a skill that already exists in `~/.codex/skills`, `~/.claude/skills`, or `~/.cursor/skills`; the installers detect filesystem duplicates and keep the existing source as the owner.

## Collections

```text
collections/
├── matt/       # 35 skills from mattpocock/skills
├── cursor/     # frontend and Cursor-oriented skills
├── custom/     # focused repository utilities
├── caveman/    # caveman communication tools
├── documents/  # DOCX and PDF skills
└── lark/       # Lark/Feishu skills and workflows
```

The Matt collection vendors all 35 skills from [Matt Pocock's `mattpocock/skills`](https://github.com/mattpocock/skills) at commit [`8b78b531`](https://github.com/mattpocock/skills/commit/8b78b531ab965735c5dc74f6f7a219e1e37326df). Their contents and MIT license files are preserved.

Collection names and individual skill names are both valid selectors. For example, `matt,caveman` installs two collections, while `matt,caveman-review` installs Matt plus one skill.

## Install or update

Clone the repository when using profiles or management commands:

```bash
git clone https://github.com/aliabedi1/agent-skills.git
cd agent-skills
```

Windows PowerShell:

```powershell
git clone https://github.com/aliabedi1/agent-skills.git
Set-Location agent-skills
```

### Daily usage

Linux/macOS:

```bash
AGENT_SKILLS_COLLECTIONS=matt,caveman ./install.sh
```

Windows:

```powershell
$env:AGENT_SKILLS_COLLECTIONS = "matt,caveman"
.\install.ps1
```

### Frontend work

```bash
AGENT_SKILLS_COLLECTIONS=matt,cursor ./install.sh
```

```powershell
$env:AGENT_SKILLS_COLLECTIONS = "matt,cursor"
.\install.ps1
```

### Matt skills only

```bash
./install.sh --profile matt
```

```powershell
.\install.ps1 -Profile matt
```

### Cursor collection only

```bash
./install.sh --profile cursor
```

```powershell
.\install.ps1 -Profile cursor
```

### Everything temporarily

```bash
AGENT_SKILLS_COLLECTIONS=all ./install.sh
# work with the full catalog, then:
./install.sh clean
```

```powershell
$env:AGENT_SKILLS_COLLECTIONS = "all"
.\install.ps1
# work with the full catalog, then:
.\install.ps1 clean
```

The existing no-argument command remains compatible and installs `all`, while printing a recommendation to choose a smaller profile. The remote one-line installers also continue to work:

```bash
curl -fsSL https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.sh | bash
```

```powershell
irm https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.ps1 | iex
```

## Profiles

Profiles are maintained in [`profiles.conf`](profiles.conf) and map to collections without requiring a JSON or YAML parser.

| Profile | Collections | Intended use |
| --- | --- | --- |
| `minimal` | `custom` | Small everyday utility set |
| `backend` | `matt,custom` | Backend engineering and repository workflows |
| `frontend` | `cursor,custom` | Frontend implementation and review |
| `matt` | `matt` | Matt Pocock's complete collection |
| `cursor` | `cursor` | Cursor/frontend collection |
| `all` | every collection | Temporary access to the entire catalog |

```bash
./install.sh --profile frontend
```

```powershell
.\install.ps1 -Profile frontend
```

Do not combine a profile with `AGENT_SKILLS_COLLECTIONS`; the installer rejects the ambiguous selection.

## Installation targets and duplicate ownership

By default the installer considers Codex and Claude Code targets. Use `AGENT_SKILLS_TARGETS=codex` or `AGENT_SKILLS_TARGETS=claude` to choose one. It respects `CODEX_HOME`, `CLAUDE_CONFIG_DIR`, and `CURSOR_CONFIG_DIR`.

Before copying a skill, the installer checks:

- `~/.codex/skills`
- `~/.claude/skills`
- `~/.cursor/skills`

If an unmanaged copy already exists, it is not overwritten or deleted. The installer prints the repository source, every discovered installation, and the path that remains the owner. Use a single explicit target when you want predictable ownership for a fresh setup:

```bash
AGENT_SKILLS_TARGETS=codex ./install.sh --profile minimal
```

On Windows:

```powershell
$env:AGENT_SKILLS_TARGETS = "codex"
.\install.ps1 -Profile minimal
```

Plugin-provided skills may not have a directory in these roots, so `doctor` reminds you to review enabled plugins separately.

## Doctor

Run this before installing a large profile or when Codex shows duplicate/context warnings:

```bash
./install.sh doctor
```

```powershell
.\install.ps1 doctor
```

Example output (paths and counts depend on the machine):

```text
Agent Skills doctor

Installed skills: 12 discovered (8 managed by this repository)
Active collections: caveman,custom

Skill sources:
- caveman: /home/me/.codex/skills/caveman
- graphify: /home/me/.cursor/skills/graphify

Duplicate skills:
- graphify
  - /home/me/.codex/skills/graphify
  - /home/me/.cursor/skills/graphify

Context size warning risk: low (12 installed skill directories)
Cleanup recommendations:
- Use a focused profile or AGENT_SKILLS_COLLECTIONS for daily work.
- Keep one owner for each duplicate and uninstall managed copies you do not need.
- Run ./install.sh clean to remove only repository-managed skills.
```

The context risk is a simple inventory heuristic: fewer than 25 skill directories is low, 25–49 is medium, and 50 or more is high. Codex's actual budget can vary.

## Managed cleanup and uninstall

Each target has two management files:

- `.installed-skills.json` records skill name, source collection, repository source, install location, and UTC timestamp.
- `.agent-skills-managed` is the dependency-free installer index used by both shell implementations.

`clean` removes only entries owned by this repository. Manually created and externally installed directories are never included and are never deleted:

```bash
./install.sh clean
```

```powershell
.\install.ps1 clean
```

Remove one managed skill or collection:

```bash
./install.sh uninstall caveman-review
./install.sh uninstall --collection cursor
```

```powershell
.\install.ps1 uninstall caveman-review
.\install.ps1 uninstall -Collection cursor
```

The installer backs up a managed directory before replacing it during an update under `~/.agent-skills-backups/<timestamp>/`. Cleanup and uninstall do not touch unmanaged skills.

For installations made by an older version of this repository, rerun the new installer once to migrate `.agent-skills-managed` into the richer manifest format, inspect with `doctor`, and then use `clean` if desired.

## Maintaining the catalog

Every skill remains a self-contained directory with a non-empty `SKILL.md`:

```text
collections/<collection>/<skill-name>/
├── SKILL.md
├── scripts/
├── references/
└── assets/
```

To sync one agent's locally installed skills into the `custom` collection:

```bash
./scripts/sync-from-local.sh claude custom
./scripts/validate.sh
```

```powershell
.\scripts\sync-from-local.ps1 -Source claude -Collection custom
bash .\scripts\validate.sh
```

Choose another collection name explicitly when importing a distinct source. Sync replaces only that collection, leaving all other collections intact. Validation checks shell syntax, skill metadata, duplicate names across collections, symlinks, and profile references.

## Safety and ownership

Do not commit API keys, tokens, credentials, private memories, or machine-specific configuration. This is a public repository. Included skills retain their original authorship and license terms; check each skill directory before redistributing third-party material.
