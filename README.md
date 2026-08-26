# Agent Skills

One installer. One health check. Every skill stays installed and available.

The installer also makes **Caveman** and **Unslop** always-on for Codex. They are invoked at the start of each Codex task; every other skill is available when its description matches the work.

## Commands

Clone this repository once:

```bash
git clone https://github.com/aliabedi1/agent-skills.git
cd agent-skills
```

```powershell
git clone https://github.com/aliabedi1/agent-skills.git
Set-Location agent-skills
```

Then there are only two commands.

| What you want | Linux / macOS | Windows PowerShell |
| --- | --- | --- |
| Install or update every skill | `./install.sh` | `.\install.ps1` |
| Check your installation | `./install.sh doctor` | `.\install.ps1 doctor` |

The installer is safe to rerun. It updates only skills it previously installed, makes a backup before replacing one, and never overwrites a manually installed skill.

## What gets installed

```text
collections/
├── matt/       # Matt Pocock's TypeScript and engineering skills
├── cursor/     # Cursor and frontend skills, including Impeccable
├── custom/     # Custom skills, including Unslop
├── caveman/    # Caveman communication skills
├── documents/  # Document and PDF skills
└── lark/       # Lark / Feishu skills and workflows
```

All collections are installed to Codex and Claude Code by default. The installer checks `~/.codex/skills`, `~/.claude/skills`, and `~/.cursor/skills` first. If a skill already exists, it keeps that existing owner and shows a duplicate warning instead of creating another copy.

Impeccable is included from [pbakaus/impeccable](https://github.com/pbakaus/impeccable) under its Apache-2.0 license. Unslop is included from [nattergabriel/unslop](https://github.com/nattergabriel/unslop) under its MIT license.

## Caveman and Unslop are always on

When you run the installer, it adds a short managed block to `~/.codex/AGENTS.md`:

```md
At the start of every task, invoke and follow `$caveman` and `$unslop`.
```

This means you do not need to remember a profile, environment variable, or extra command. Existing instructions in that file are kept; only this repository's marked block is refreshed.

## Doctor

Use doctor whenever Codex warns that skill descriptions were shortened, or when you think two agents/plugins installed the same skill:

```text
Agent Skills doctor

Installed skills: 86 discovered (82 managed by this repository)
Active collections: caveman,cursor,custom,documents,lark,matt

Duplicate skills:
- impeccable
  - /home/me/.codex/skills/impeccable
  - /home/me/.cursor/skills/impeccable

Context size warning risk: high (86 installed skill directories)
Recommendations:
- Keep one owner for each duplicate before reinstalling.
- Run ./install.sh to install or update every skill.
```

The warning is about the amount of routing information Codex loads at startup. It does not delete skills. With this repository's deliberately full installation, doctor may report a medium or high risk; that is useful information, not a failure.

Plugin-provided skills may not appear as folders, so doctor also reminds you to review enabled plugins separately.

## Maintaining the catalog

Every skill remains self-contained:

```text
collections/<collection>/<skill-name>/
├── SKILL.md
├── scripts/
├── references/
└── assets/
```

To import locally installed skills into a collection while maintaining this repository:

```bash
./scripts/sync-from-local.sh claude custom
./scripts/validate.sh
```

```powershell
.\scripts\sync-from-local.ps1 -Source claude -Collection custom
bash .\scripts\validate.sh
```

The installer tracks its own copies in `.installed-skills.json` and `.agent-skills-managed` inside each skills directory. Those files let it update managed skills without touching manually created or externally installed skills.

Do not commit API keys, tokens, credentials, private memories, or machine-specific configuration. Third-party skills retain their original authorship and license terms.
