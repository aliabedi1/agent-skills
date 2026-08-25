param(
    [ValidateSet("claude", "codex")]
    [string]$Source = "claude",

    [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*$')]
    [string]$Collection = "custom"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Destination = Join-Path (Join-Path $RepoRoot "collections") $Collection
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

New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$ResolvedCollections = [IO.Path]::GetFullPath((Join-Path $RepoRoot "collections")).TrimEnd('\', '/')
$ResolvedDestination = [IO.Path]::GetFullPath($Destination).TrimEnd('\', '/')
if (-not $ResolvedDestination.StartsWith($ResolvedCollections + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace a directory outside the collections root: $ResolvedDestination"
}
Get-ChildItem -LiteralPath $ResolvedDestination -Directory | Remove-Item -Recurse -Force
foreach ($Skill in $Skills) {
    Copy-Item -LiteralPath $Skill.FullName -Destination (Join-Path $ResolvedDestination $Skill.Name) -Recurse -Force
}

Write-Host "Synced $SourceDirectory into collection $Collection. Other collections were not changed. Review git diff, then commit and push."
