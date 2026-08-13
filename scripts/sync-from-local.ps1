param(
    [ValidateSet("claude", "codex")]
    [string]$Source = "claude"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Destination = Join-Path $RepoRoot "skills"
if ($Source -eq "codex") {
    $AgentHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
}
else {
    $AgentHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
}
$SourceDirectory = Join-Path $AgentHome "skills"

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
    throw "Skills directory not found: $SourceDirectory"
}

$Skills = Get-ChildItem -LiteralPath $SourceDirectory -Directory |
    Where-Object { -not $_.Name.StartsWith(".") -and (Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") -PathType Leaf) }
if (-not $Skills) {
    throw "No valid skills with SKILL.md were found in $SourceDirectory"
}

Get-ChildItem -LiteralPath $Destination -Directory | Remove-Item -Recurse -Force
foreach ($Skill in $Skills) {
    Copy-Item -LiteralPath $Skill.FullName -Destination (Join-Path $Destination $Skill.Name) -Recurse -Force
}

Write-Host "Synced $SourceDirectory into $Destination. Review git diff, then commit and push."
