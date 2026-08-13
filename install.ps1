$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repository = if ($env:AGENT_SKILLS_REPOSITORY) { $env:AGENT_SKILLS_REPOSITORY } else { "aliabedi1/agent-skills" }
$Ref = if ($env:AGENT_SKILLS_REF) { $env:AGENT_SKILLS_REF } else { "main" }
$Targets = if ($env:AGENT_SKILLS_TARGETS) { $env:AGENT_SKILLS_TARGETS.ToLowerInvariant() } else { "both" }
$ArchiveUrl = if ($env:AGENT_SKILLS_ARCHIVE_URL) { $env:AGENT_SKILLS_ARCHIVE_URL } else { "https://codeload.github.com/$Repository/zip/refs/heads/$Ref" }

if ($Targets -notin @("both", "codex", "claude")) {
    throw "AGENT_SKILLS_TARGETS must be both, codex, or claude (received: $Targets)"
}

$TempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("agent-skills-" + [guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempDirectory "repository.zip"
$Timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
$BackupBase = if ($env:AGENT_SKILLS_BACKUP_DIR) { $env:AGENT_SKILLS_BACKUP_DIR } else { Join-Path $HOME ".agent-skills-backups" }
$BackupRoot = Join-Path $BackupBase $Timestamp
$script:Changed = $false

function Get-TreeFingerprint {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        return $null
    }

    $Lines = Get-ChildItem -LiteralPath $Path -File -Recurse |
        ForEach-Object {
            $RelativePath = $_.FullName.Substring($Path.TrimEnd('\', '/').Length).TrimStart('\', '/').Replace('\', '/')
            "$RelativePath`:$((Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash)"
        } |
        Sort-Object
    $Payload = [Text.Encoding]::UTF8.GetBytes(($Lines -join "`n"))
    $Hasher = [Security.Cryptography.SHA256]::Create()
    try {
        return ([BitConverter]::ToString($Hasher.ComputeHash($Payload))).Replace("-", "")
    }
    finally {
        $Hasher.Dispose()
    }
}

function Backup-ExistingSkill {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$AgentName,
        [Parameter(Mandatory = $true)][string]$SkillName
    )

    if (Test-Path -LiteralPath $Path) {
        $AgentBackup = Join-Path $BackupRoot $AgentName
        New-Item -ItemType Directory -Path $AgentBackup -Force | Out-Null
        Copy-Item -LiteralPath $Path -Destination (Join-Path $AgentBackup $SkillName) -Recurse -Force
    }
}

function Sync-SkillTarget {
    param(
        [Parameter(Mandatory = $true)][string]$AgentName,
        [Parameter(Mandatory = $true)][string]$DestinationRoot,
        [Parameter(Mandatory = $true)][string]$SourceRoot
    )

    New-Item -ItemType Directory -Path $DestinationRoot -Force | Out-Null
    $ManifestPath = Join-Path $DestinationRoot ".agent-skills-managed"
    $Skills = Get-ChildItem -LiteralPath $SourceRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "SKILL.md") -PathType Leaf } |
        Sort-Object Name
    $SkillNames = @($Skills | ForEach-Object { $_.Name })

    if (Test-Path -LiteralPath $ManifestPath -PathType Leaf) {
        foreach ($SkillName in @(Get-Content -LiteralPath $ManifestPath)) {
            if ([string]::IsNullOrWhiteSpace($SkillName)) { continue }
            if ($SkillName -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
                Write-Warning "Ignoring invalid entry in $ManifestPath`: $SkillName"
                continue
            }
            if ($SkillName -notin $SkillNames) {
                $DestinationSkill = Join-Path $DestinationRoot $SkillName
                if (Test-Path -LiteralPath $DestinationSkill) {
                    Backup-ExistingSkill -Path $DestinationSkill -AgentName $AgentName -SkillName $SkillName
                    Remove-Item -LiteralPath $DestinationSkill -Recurse -Force
                    Write-Host "[$AgentName] removed $SkillName"
                    $script:Changed = $true
                }
            }
        }
    }

    foreach ($Skill in $Skills) {
        if ($Skill.Name -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
            Write-Warning "Skipping invalid skill directory name: $($Skill.Name)"
            continue
        }

        $DestinationSkill = Join-Path $DestinationRoot $Skill.Name
        if ((Get-TreeFingerprint -Path $Skill.FullName) -eq (Get-TreeFingerprint -Path $DestinationSkill)) {
            continue
        }

        Backup-ExistingSkill -Path $DestinationSkill -AgentName $AgentName -SkillName $Skill.Name
        if (Test-Path -LiteralPath $DestinationSkill) {
            Remove-Item -LiteralPath $DestinationSkill -Recurse -Force
        }
        Copy-Item -LiteralPath $Skill.FullName -Destination $DestinationSkill -Recurse -Force
        Write-Host "[$AgentName] installed $($Skill.Name)"
        $script:Changed = $true
    }

    [IO.File]::WriteAllLines($ManifestPath, $SkillNames, [Text.UTF8Encoding]::new($false))
}

try {
    New-Item -ItemType Directory -Path $TempDirectory -Force | Out-Null
    Write-Host "Downloading $Repository at $Ref..."
    if (Test-Path -LiteralPath $ArchiveUrl -PathType Leaf) {
        Copy-Item -LiteralPath $ArchiveUrl -Destination $ArchivePath
    }
    else {
        Invoke-WebRequest -Uri $ArchiveUrl -OutFile $ArchivePath -UseBasicParsing
    }
    Expand-Archive -LiteralPath $ArchivePath -DestinationPath $TempDirectory -Force

    $SourceRoot = Get-ChildItem -LiteralPath $TempDirectory -Directory |
        ForEach-Object { Join-Path $_.FullName "skills" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Container } |
        Select-Object -First 1
    if (-not $SourceRoot) {
        throw "The downloaded repository does not contain a top-level skills directory."
    }

    $CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
    $ClaudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }

    if ($Targets -in @("both", "codex")) {
        Sync-SkillTarget -AgentName "codex" -DestinationRoot (Join-Path $CodexHome "skills") -SourceRoot $SourceRoot
    }
    if ($Targets -in @("both", "claude")) {
        Sync-SkillTarget -AgentName "claude" -DestinationRoot (Join-Path $ClaudeHome "skills") -SourceRoot $SourceRoot
    }

    if ($script:Changed) {
        Write-Host "Skills are up to date. Replaced files were backed up under $BackupRoot when needed."
    }
    else {
        Write-Host "All managed skills are already up to date."
    }
    Write-Host "Restart Codex and Claude Code to ensure they reload the skills."
}
finally {
    if (Test-Path -LiteralPath $TempDirectory) {
        Remove-Item -LiteralPath $TempDirectory -Recurse -Force
    }
}
