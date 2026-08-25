$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$Repository = if ($env:AGENT_SKILLS_REPOSITORY) { $env:AGENT_SKILLS_REPOSITORY } else { "aliabedi1/agent-skills" }
$Ref = if ($env:AGENT_SKILLS_REF) { $env:AGENT_SKILLS_REF } else { "main" }
$Targets = if ($env:AGENT_SKILLS_TARGETS) { $env:AGENT_SKILLS_TARGETS.ToLowerInvariant() } else { "both" }
$ArchiveUrl = if ($env:AGENT_SKILLS_ARCHIVE_URL) { $env:AGENT_SKILLS_ARCHIVE_URL } else { "https://codeload.github.com/$Repository/zip/refs/heads/$Ref" }
$Command = "install"
$Profile = ""
$UninstallSkill = ""
$UninstallCollection = ""

function Show-Usage {
    @"
Usage:
  .\install.ps1 [-Profile minimal|backend|frontend|matt|cursor|all]
  .\install.ps1 doctor
  .\install.ps1 clean
  .\install.ps1 uninstall <skill-name>
  .\install.ps1 uninstall -Collection <collection-name>

Set AGENT_SKILLS_COLLECTIONS to a comma-separated list of collections or skill
names. With no profile or selection, all collections are installed for backward
compatibility.
"@ | Write-Host
}

if ($Targets -notin @("both", "codex", "claude")) {
    throw "AGENT_SKILLS_TARGETS must be both, codex, or claude (received: $Targets)"
}

$Arguments = @($args)
if ($Arguments.Count -gt 0 -and $Arguments[0] -in @("doctor", "clean")) {
    $Command = $Arguments[0]
    $Arguments = @($Arguments | Select-Object -Skip 1)
}
elseif ($Arguments.Count -gt 0 -and $Arguments[0] -eq "uninstall") {
    $Command = "uninstall"
    $Arguments = @($Arguments | Select-Object -Skip 1)
    if ($Arguments.Count -eq 2 -and $Arguments[0] -in @("-Collection", "--collection")) {
        $UninstallCollection = $Arguments[1]
    }
    elseif ($Arguments.Count -eq 1) {
        $UninstallSkill = $Arguments[0]
    }
    else {
        throw "Usage: .\install.ps1 uninstall <skill-name> or uninstall -Collection <collection-name>"
    }
    $Arguments = @()
}

for ($Index = 0; $Index -lt $Arguments.Count; $Index++) {
    switch ($Arguments[$Index]) {
        { $_ -in @("-Profile", "--profile") } {
            if ($Index + 1 -ge $Arguments.Count) { throw "-Profile requires a profile name" }
            $Profile = $Arguments[++$Index]
        }
        { $_ -in @("-Help", "--help", "-h") } {
            Show-Usage
            exit 0
        }
        default { throw "Unknown argument: $($Arguments[$Index])" }
    }
}

$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $HOME ".codex" }
$ClaudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME ".claude" }
$CursorHome = if ($env:CURSOR_CONFIG_DIR) { $env:CURSOR_CONFIG_DIR } else { Join-Path $HOME ".cursor" }
$AllRoots = [ordered]@{
    codex = Join-Path $CodexHome "skills"
    claude = Join-Path $ClaudeHome "skills"
    cursor = Join-Path $CursorHome "skills"
}
$TargetRoots = [ordered]@{}
if ($Targets -in @("both", "codex")) { $TargetRoots.codex = $AllRoots.codex }
if ($Targets -in @("both", "claude")) { $TargetRoots.claude = $AllRoots.claude }

function Test-ValidName {
    param([Parameter(Mandatory = $true)][string]$Name)
    return $Name -match '^[A-Za-z0-9][A-Za-z0-9._-]*$'
}

function Get-ManagedPath {
    param([Parameter(Mandatory = $true)][string]$Root)
    return Join-Path $Root ".agent-skills-managed"
}

function Get-ManifestPath {
    param([Parameter(Mandatory = $true)][string]$Root)
    return Join-Path $Root ".installed-skills.json"
}

function Get-ManagedEntries {
    param([Parameter(Mandatory = $true)][string]$Root)

    $ManagedPath = Get-ManagedPath -Root $Root
    if (-not (Test-Path -LiteralPath $ManagedPath -PathType Leaf)) { return @() }
    $Lines = @(Get-Content -LiteralPath $ManagedPath)
    $Now = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Entries = foreach ($Line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($Line)) { continue }
        $Parts = @($Line -split "`t", 5)
        if ($Parts.Count -eq 1) {
            if (Test-ValidName -Name $Parts[0]) {
                [pscustomobject]@{
                    skill = $Parts[0]
                    source_collection = "legacy"
                    install_location = Join-Path $Root $Parts[0]
                    timestamp = $Now
                    source = "legacy/$($Parts[0])"
                }
            }
        }
        elseif ($Parts.Count -eq 5) {
            [pscustomobject]@{
                skill = $Parts[0]
                source_collection = $Parts[1]
                install_location = $Parts[2]
                timestamp = $Parts[3]
                source = $Parts[4]
            }
        }
    }
    return @($Entries)
}

function Write-ManagedEntries {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Entries
    )

    New-Item -ItemType Directory -Path $Root -Force | Out-Null
    $Sorted = @($Entries | Sort-Object skill -Unique)
    $Lines = @($Sorted | ForEach-Object {
        "$($_.skill)`t$($_.source_collection)`t$($_.install_location)`t$($_.timestamp)`t$($_.source)"
    })
    [IO.File]::WriteAllLines((Get-ManagedPath -Root $Root), $Lines, [Text.UTF8Encoding]::new($false))
    $Json = if ($Sorted.Count -eq 0) { "[]`n" } else { (ConvertTo-Json -InputObject @($Sorted) -Depth 4) + "`n" }
    [IO.File]::WriteAllText((Get-ManifestPath -Root $Root), $Json, [Text.UTF8Encoding]::new($false))
}

function Test-ManagedSkill {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Skill
    )
    return [bool](Get-ManagedEntries -Root $Root | Where-Object skill -eq $Skill)
}

function Set-ManagedSkill {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Skill,
        [Parameter(Mandatory = $true)][string]$Collection,
        [Parameter(Mandatory = $true)][string]$Location,
        [Parameter(Mandatory = $true)][string]$Source
    )
    $Entries = @(Get-ManagedEntries -Root $Root | Where-Object skill -ne $Skill)
    $Entries += [pscustomobject]@{
        skill = $Skill
        source_collection = $Collection
        install_location = $Location
        timestamp = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ssZ")
        source = $Source
    }
    Write-ManagedEntries -Root $Root -Entries $Entries
}

function Remove-ManagedEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Skill
    )
    $Entries = @(Get-ManagedEntries -Root $Root | Where-Object skill -ne $Skill)
    Write-ManagedEntries -Root $Root -Entries $Entries
}

function Assert-ManagedDestination {
    param(
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Destination
    )
    $ResolvedRoot = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $ResolvedDestination = [IO.Path]::GetFullPath($Destination)
    if ([IO.Path]::GetDirectoryName($ResolvedDestination).TrimEnd('\', '/') -ne $ResolvedRoot) {
        throw "Refusing to remove a path outside the managed skills root: $ResolvedDestination"
    }
}

function Remove-ManagedSkill {
    param(
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$Root,
        [Parameter(Mandatory = $true)][string]$Skill
    )
    if (-not (Test-ManagedSkill -Root $Root -Skill $Skill)) { return }
    $Destination = Join-Path $Root $Skill
    Assert-ManagedDestination -Root $Root -Destination $Destination
    if (Test-Path -LiteralPath $Destination) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
        Write-Host "[$Agent] removed managed skill $Skill"
    }
    Remove-ManagedEntry -Root $Root -Skill $Skill
}

function Get-ExistingSources {
    param(
        [Parameter(Mandatory = $true)][string]$Skill,
        [string]$ExcludedRoot = ""
    )
    foreach ($Entry in $AllRoots.GetEnumerator()) {
        if ($Entry.Value -eq $ExcludedRoot) { continue }
        $Path = Join-Path $Entry.Value $Skill
        if (Test-Path -LiteralPath $Path) { $Path }
    }
}

function Write-DuplicateWarning {
    param(
        [Parameter(Mandatory = $true)][string]$Skill,
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string[]]$Owners
    )
    Write-Warning (@("Duplicate skill detected:", $Skill, "", "Sources:", "- $Source") + @($Owners | ForEach-Object { "- $_" }) + @("Owner: $($Owners[0]) (existing installation is kept)", "") -join "`n")
}

function Invoke-Clean {
    foreach ($Target in $TargetRoots.GetEnumerator()) {
        foreach ($Entry in @(Get-ManagedEntries -Root $Target.Value)) {
            Remove-ManagedSkill -Agent $Target.Key -Root $Target.Value -Skill $Entry.skill
        }
    }
    Write-Host "Clean complete. Only skills listed in this repository's managed manifests were removed."
}

function Invoke-Uninstall {
    if ($UninstallSkill -and -not (Test-ValidName -Name $UninstallSkill)) { throw "Invalid skill name: $UninstallSkill" }
    if ($UninstallCollection -and -not (Test-ValidName -Name $UninstallCollection)) { throw "Invalid collection name: $UninstallCollection" }
    foreach ($Target in $TargetRoots.GetEnumerator()) {
        foreach ($Entry in @(Get-ManagedEntries -Root $Target.Value)) {
            if (($UninstallSkill -and $Entry.skill -eq $UninstallSkill) -or
                ($UninstallCollection -and $Entry.source_collection -eq $UninstallCollection)) {
                Remove-ManagedSkill -Agent $Target.Key -Root $Target.Value -Skill $Entry.skill
            }
        }
    }
}

function Invoke-Doctor {
    $Inventory = @()
    $ManagedCount = 0
    foreach ($RootEntry in $AllRoots.GetEnumerator()) {
        if (-not (Test-Path -LiteralPath $RootEntry.Value -PathType Container)) { continue }
        foreach ($Directory in @(Get-ChildItem -LiteralPath $RootEntry.Value -Directory)) {
            if (-not (Test-Path -LiteralPath (Join-Path $Directory.FullName "SKILL.md") -PathType Leaf)) { continue }
            $Managed = Test-ManagedSkill -Root $RootEntry.Value -Skill $Directory.Name
            if ($Managed) { $ManagedCount++ }
            $Inventory += [pscustomobject]@{ skill = $Directory.Name; path = $Directory.FullName; managed = $Managed }
        }
    }
    $Duplicates = @($Inventory | Group-Object skill | Where-Object Count -gt 1)
    $Collections = @($AllRoots.Values | ForEach-Object { Get-ManagedEntries -Root $_ } | ForEach-Object source_collection | Sort-Object -Unique)
    $Risk = if ($Inventory.Count -ge 50) { "high" } elseif ($Inventory.Count -ge 25) { "medium" } else { "low" }
    Write-Host "Agent Skills doctor`n"
    Write-Host "Installed skills: $($Inventory.Count) discovered ($ManagedCount managed by this repository)"
    Write-Host "Active collections: $(if ($Collections) { $Collections -join ',' } else { 'none' })"
    Write-Host "`nSkill sources:"
    if ($Inventory) { $Inventory | Sort-Object skill, path | ForEach-Object { Write-Host "- $($_.skill): $($_.path)" } } else { Write-Host "- none" }
    Write-Host "`nDuplicate skills:"
    if ($Duplicates) {
        foreach ($Duplicate in $Duplicates) {
            Write-Host "- $($Duplicate.Name)"
            $Duplicate.Group | ForEach-Object { Write-Host "  - $($_.path)" }
        }
    }
    else { Write-Host "- none" }
    Write-Host "`nContext size warning risk: $Risk ($($Inventory.Count) installed skill directories)"
    Write-Host "Cleanup recommendations:"
    Write-Host "- Use a focused profile or AGENT_SKILLS_COLLECTIONS for daily work."
    if ($Duplicates) { Write-Host "- Keep one owner for each duplicate and uninstall managed copies you do not need." }
    Write-Host "- Run .\install.ps1 clean to remove only repository-managed skills."
    Write-Host "- Plugin-provided skills cannot be inspected from filesystem roots; review enabled plugins separately."
}

switch ($Command) {
    "doctor" { Invoke-Doctor; exit 0 }
    "clean" { Invoke-Clean; exit 0 }
    "uninstall" { Invoke-Uninstall; exit 0 }
}

$TempDirectory = Join-Path ([IO.Path]::GetTempPath()) ("agent-skills-" + [guid]::NewGuid().ToString("N"))
$ArchivePath = Join-Path $TempDirectory "repository.zip"
$BackupBase = if ($env:AGENT_SKILLS_BACKUP_DIR) { $env:AGENT_SKILLS_BACKUP_DIR } else { Join-Path $HOME ".agent-skills-backups" }
$BackupRoot = Join-Path $BackupBase ([DateTime]::UtcNow.ToString("yyyyMMddTHHmmssZ") + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$Changed = $false

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

    $RepositoryRoot = Get-ChildItem -LiteralPath $TempDirectory -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "collections") -PathType Container } |
        Select-Object -First 1
    if (-not $RepositoryRoot) { throw "The downloaded repository does not contain a top-level collections directory." }
    $CollectionsRoot = Join-Path $RepositoryRoot.FullName "collections"
    $ProfilesPath = Join-Path $RepositoryRoot.FullName "profiles.conf"

    $Selectors = if ($env:AGENT_SKILLS_COLLECTIONS) { $env:AGENT_SKILLS_COLLECTIONS } else { "" }
    if ($Profile) {
        if ($Selectors) { throw "Use either -Profile or AGENT_SKILLS_COLLECTIONS, not both." }
        if (-not (Test-Path -LiteralPath $ProfilesPath -PathType Leaf)) { throw "Profile configuration not found." }
        $ProfileLine = Get-Content -LiteralPath $ProfilesPath | Where-Object { $_ -match "^$([regex]::Escape($Profile))=" } | Select-Object -First 1
        if (-not $ProfileLine) { throw "Unknown profile: $Profile" }
        $Selectors = ($ProfileLine -split "=", 2)[1]
        Write-Host "Using profile $Profile ($Selectors)."
    }
    elseif (-not $Selectors) {
        $Selectors = "all"
        Write-Host "No profile selected; installing all collections for backward compatibility."
        Write-Host "For a smaller startup context, use -Profile minimal or AGENT_SKILLS_COLLECTIONS."
    }

    $AllSkills = foreach ($CollectionDirectory in @(Get-ChildItem -LiteralPath $CollectionsRoot -Directory)) {
        foreach ($SkillDirectory in @(Get-ChildItem -LiteralPath $CollectionDirectory.FullName -Directory)) {
            if (Test-Path -LiteralPath (Join-Path $SkillDirectory.FullName "SKILL.md") -PathType Leaf) {
                [pscustomobject]@{ skill = $SkillDirectory.Name; collection = $CollectionDirectory.Name; path = $SkillDirectory.FullName }
            }
        }
    }
    $Selected = @()
    foreach ($SelectorValue in @($Selectors -split ',' | ForEach-Object Trim | Where-Object { $_ })) {
        if ($SelectorValue -eq "all") {
            $Selected += $AllSkills
        }
        else {
            $Matches = @($AllSkills | Where-Object { $_.collection -eq $SelectorValue -or $_.skill -eq $SelectorValue })
            if (-not $Matches) { throw "Unknown collection or skill: $SelectorValue" }
            if (-not ($AllSkills.collection -contains $SelectorValue) -and $Matches.Count -gt 1) {
                throw "Skill name is duplicated across repository collections: $SelectorValue"
            }
            $Selected += $Matches
        }
    }
    $Selected = @($Selected | Sort-Object skill -Unique)
    if (-not $Selected) { throw "The selection did not contain any skills." }

    foreach ($Target in $TargetRoots.GetEnumerator()) {
        New-Item -ItemType Directory -Path $Target.Value -Force | Out-Null
        foreach ($Skill in $Selected) {
            if (-not (Test-ValidName -Name $Skill.skill)) { throw "Invalid skill directory name: $($Skill.skill)" }
            $Destination = Join-Path $Target.Value $Skill.skill
            $SourceLabel = "collections/$($Skill.collection)/$($Skill.skill)"
            if (Test-ManagedSkill -Root $Target.Value -Skill $Skill.skill) {
                $SourceHash = @(Get-ChildItem -LiteralPath $Skill.path -File -Recurse | Get-FileHash -Algorithm SHA256 | Select-Object -ExpandProperty Hash)
                $DestinationHash = @(if (Test-Path -LiteralPath $Destination -PathType Container) { Get-ChildItem -LiteralPath $Destination -File -Recurse | Get-FileHash -Algorithm SHA256 | Select-Object -ExpandProperty Hash })
                if ((@(Compare-Object $SourceHash $DestinationHash)).Count -eq 0 -and $SourceHash.Count -eq $DestinationHash.Count) { continue }
                if (Test-Path -LiteralPath $Destination) {
                    New-Item -ItemType Directory -Path (Join-Path $BackupRoot $Target.Key) -Force | Out-Null
                    Copy-Item -LiteralPath $Destination -Destination (Join-Path (Join-Path $BackupRoot $Target.Key) $Skill.skill) -Recurse -Force
                    Assert-ManagedDestination -Root $Target.Value -Destination $Destination
                    Remove-Item -LiteralPath $Destination -Recurse -Force
                }
            }
            else {
                $Owners = @(Get-ExistingSources -Skill $Skill.skill -ExcludedRoot $Target.Value)
                if (Test-Path -LiteralPath $Destination) { $Owners = @($Destination) + $Owners }
                if ($Owners.Count -gt 0) {
                    Write-DuplicateWarning -Skill $Skill.skill -Source $SourceLabel -Owners $Owners
                    continue
                }
            }
            Copy-Item -LiteralPath $Skill.path -Destination $Destination -Recurse -Force
            Set-ManagedSkill -Root $Target.Value -Skill $Skill.skill -Collection $Skill.collection -Location $Destination -Source $SourceLabel
            Write-Host "[$($Target.Key)] installed $($Skill.skill) ($($Skill.collection))"
            $Changed = $true
        }
    }

    if ($Changed) {
        Write-Host "Selected skills are up to date. Replaced managed files were backed up under $BackupRoot."
    }
    else {
        Write-Host "Selected managed skills are already up to date, or an existing owner was kept."
    }
    Write-Host "Restart the affected agent so it reloads the skills. Run .\install.ps1 doctor to inspect ownership and context risk."
}
finally {
    if (Test-Path -LiteralPath $TempDirectory) {
        $ResolvedTemp = [IO.Path]::GetFullPath($TempDirectory)
        $ResolvedSystemTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
        if (-not $ResolvedTemp.StartsWith($ResolvedSystemTemp, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to remove a temporary directory outside the system temp root: $ResolvedTemp"
        }
        Remove-Item -LiteralPath $ResolvedTemp -Recurse -Force
    }
}
