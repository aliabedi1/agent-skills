# Agent Skills

Portable, versioned skills for Codex and Claude Code. This repository is the source of truth for the skills in [`skills/`](skills/).

The installer works on Linux, macOS, and Windows, installs every skill into both agents, and can be rerun at any time to update to the latest version on `main`.

## Included collections

The repository vendors all 35 skills from [Matt Pocock's `mattpocock/skills`](https://github.com/mattpocock/skills) at commit [`8b78b531`](https://github.com/mattpocock/skills/commit/8b78b531ab965735c5dc74f6f7a219e1e37326df), including the engineering, productivity, misc, and in-progress collections. The upstream bucket layout is flattened into one directory per skill under [`skills/`](skills/) so the installers below always discover and install the complete collection.

Each vendored skill includes Matt Pocock's MIT license as `LICENSE.txt`.

## Install or update

Linux/macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.sh | bash
```

Windows PowerShell:

```powershell
irm https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.ps1 | iex
```

Run the same command again whenever you want the latest versions. Restart Codex and Claude Code afterward so they reload the skills.

By default, skills are installed to:

| Agent | Linux/macOS | Windows |
| --- | --- | --- |
| Codex | `~/.codex/skills` | `$HOME\.codex\skills` |
| Claude Code | `~/.claude/skills` | `$HOME\.claude\skills` |

The scripts respect `CODEX_HOME` and `CLAUDE_CONFIG_DIR` when those variables are set.

### Install for only one agent

Linux/macOS, Codex only:

```bash
curl -fsSL https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.sh | AGENT_SKILLS_TARGETS=codex bash
```

Windows PowerShell, Claude only:

```powershell
$env:AGENT_SKILLS_TARGETS = "claude"; irm https://raw.githubusercontent.com/aliabedi1/agent-skills/main/install.ps1 | iex
```

Use `both`, `codex`, or `claude`. Unset the variable afterward if you set it persistently.

## What updates do

The installer owns only the skills recorded in `.agent-skills-managed` inside each agent's skills directory.

- New and changed repository skills are copied into place.
- Skills previously installed by this repository but later removed from it are removed locally.
- Unrelated skills are left alone.
- Any replaced or removed directory is copied first to `~/.agent-skills-backups/<timestamp>/`.
- Built-in Codex skills under `.system` are not included or modified.

## Add or update a skill

You can edit a skill directly under `skills/<skill-name>/`, or sync the current skills from one machine into a clone of this repository.

Linux/macOS:

```bash
git clone https://github.com/aliabedi1/agent-skills.git
cd agent-skills
./scripts/sync-from-local.sh claude
./scripts/validate.sh
git diff
git add skills
git commit -m "Update skills"
git push
```

Windows PowerShell:

```powershell
git clone https://github.com/aliabedi1/agent-skills.git
Set-Location agent-skills
.\scripts\sync-from-local.ps1 -Source claude
bash .\scripts\validate.sh
git diff
git add skills
git commit -m "Update skills"
git push
```

Change `claude` to `codex` when that agent has the authoritative copy. The sync scripts intentionally replace the repository's `skills/` contents with the selected local skill set, so inspect `git diff` before committing.

After pushing, run the install/update command on each PC. The scripts always download the newest commit on `main`; no local clone is needed just to install or update.

## Add a skill manually

Every direct child of `skills/` must be a self-contained directory with a non-empty `SKILL.md`:

```text
skills/
└── my-skill/
    ├── SKILL.md
    ├── scripts/
    ├── references/
    └── assets/
```

Run `./scripts/validate.sh` before pushing. GitHub Actions runs the same validation on every push and pull request.

## Safety and ownership

Do not commit API keys, tokens, credentials, private memories, or machine-specific configuration. This is a public repository. The included skills retain their original authorship and license terms; check each skill directory before redistributing or modifying third-party material.

Rules, workflows, and memories can be added later as separate top-level directories. The current installers deliberately manage only `skills/`.
