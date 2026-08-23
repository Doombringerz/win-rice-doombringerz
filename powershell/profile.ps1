# profile.ps1: Doombringerz Windows shell aliases and helpers
# Sourced from your $PROFILE by install.ps1
# https://github.com/Doombringerz/win-rice-doombringerz

# Resolve the directory this file lives in. Lets doom-theme find sibling
# starship-red.toml / starship-gold.toml regardless of install location.
# Uses $global: scope because $script: is dynamic and unreachable from
# interactively-invoked functions in dot-sourced files.
$global:WinRiceRoot = $PSScriptRoot

# ── Starship prompt ─────────────────────────────────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $env:STARSHIP_CONFIG = Join-Path $env:USERPROFILE ".config\starship.toml"
    Invoke-Expression (&starship init powershell)
}

# ── Git shortcuts ───────────────────────────────────────────────────────────
function gst    { git status @args }
function gd     { git diff @args }
function gds    { git diff --staged @args }
function ga     { git add @args }
function gaa    { git add -A @args }
function gc     { git commit @args }
function gcm    { param([string]$m) git commit -m $m }
function gca    { param([string]$m) git commit -am $m }
function gco    { git checkout @args }
function gcb    { git checkout -b @args }
function gb     { git branch @args }
function gp     { git pull @args }
function gps    { git push @args }
function gpr    { git pull --rebase @args }
function glog   { git log --oneline --decorate --graph -20 @args }
function gloga  { git log --oneline --decorate --graph --all -30 @args }
function gwip   { git add -A; git commit -m "wip" }

# ── Navigation ──────────────────────────────────────────────────────────────
function ll     { Get-ChildItem -Force @args }
function ..     { Set-Location .. }
function ...    { Set-Location ..\.. }
function ....   { Set-Location ..\..\.. }

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location $Path
}

# ── Reload the profile without restarting the shell ─────────────────────────
function Update-Profile {
    if (Test-Path $PROFILE) {
        . $PROFILE
        Write-Host "Profile reloaded." -ForegroundColor Green
    } else {
        Write-Host "No profile at $PROFILE, nothing to reload." -ForegroundColor Yellow
        Write-Host "Run install.ps1 to set one up." -ForegroundColor Yellow
    }
}
Set-Alias -Name reload-profile -Value Update-Profile

# ── Open current directory in Explorer ──────────────────────────────────────
function here { explorer.exe (Get-Location).Path }

# ── Disk usage of current directory, sorted by size ─────────────────────────
function Get-DirectorySize {
    Get-ChildItem -Force | ForEach-Object {
        $size = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse -Force -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
        } else { $_.Length }
        [PSCustomObject]@{
            Name        = $_.Name
            "Size (MB)" = if ($size) { [math]::Round($size / 1MB, 2) } else { 0 }
        }
    } | Sort-Object -Property "Size (MB)" -Descending | Format-Table -AutoSize
}
Set-Alias -Name du-summary -Value Get-DirectorySize

# ── Quick which/where for a command ─────────────────────────────────────────
function which { param([string]$cmd) (Get-Command $cmd -ErrorAction SilentlyContinue).Source }

# ── Doombringerz theme switching (red / gold) ───────────────────────────────
function doom-theme {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [ValidateSet("red", "gold", "auto", "status")]
        [string]$Mode = "status"
    )

    # Resolve themes relative to where profile.ps1 lives (works in test + install).
    # $global: scope because $script: doesn't survive into interactive function calls.
    $themeDir    = $global:WinRiceRoot
    $starshipDst = Join-Path $env:USERPROFILE ".config\starship.toml"
    if (-not $themeDir -or -not (Test-Path $themeDir)) {
        Write-Host "Theme directory not resolved. \$global:WinRiceRoot is empty." -ForegroundColor Red
        Write-Host "Profile may not have been dot-sourced. Try: reload-profile" -ForegroundColor Yellow
        return
    }

    if ($Mode -eq "status") {
        if (Test-Path $starshipDst) {
            $body = Get-Content $starshipDst -Raw -ErrorAction SilentlyContinue
            $current = if     ($body -match "starship-red\.toml")  { "red" }
                       elseif ($body -match "starship-gold\.toml") { "gold" }
                       else                                         { "unknown / custom" }
            Write-Host "Current doom theme: " -NoNewline
            $col = if ($current -eq "red") { "Red" } elseif ($current -eq "gold") { "Yellow" } else { "Gray" }
            Write-Host $current -ForegroundColor $col
        } else {
            Write-Host "No starship config at $starshipDst" -ForegroundColor Yellow
        }
        Write-Host "Usage: doom-theme red | gold | auto | status"
        return
    }

    # Resolve "auto" -> red 18:00-06:00 (doom hours), gold 06:00-18:00 (ascended hours)
    $resolved = $Mode
    if ($Mode -eq "auto") {
        $hour = (Get-Date).Hour
        $resolved = if ($hour -ge 18 -or $hour -lt 6) { "red" } else { "gold" }
    }

    $srcFile = Join-Path $themeDir "starship-$resolved.toml"
    if (-not (Test-Path $srcFile)) {
        Write-Host "Theme source not found: $srcFile" -ForegroundColor Red
        Write-Host "Re-run win-rice install.ps1 to restore theme files." -ForegroundColor Yellow
        return
    }

    $dstDir = Split-Path $starshipDst -Parent
    if (-not (Test-Path $dstDir)) {
        New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
    }
    Copy-Item $srcFile $starshipDst -Force

    Write-Host "Doom theme set: " -NoNewline
    $col = if ($resolved -eq "red") { "Red" } else { "Yellow" }
    Write-Host $resolved -ForegroundColor $col
    Write-Host "Open a fresh terminal to see the change." -ForegroundColor Gray
}

# ── Doombringerz banner (opt-in, not auto on shell start) ───────────────────
function doom-banner {
    $banner = @(
        "██████╗  ██████╗  ██████╗ ███╗   ███╗",
        "██╔══██╗██╔═══██╗██╔═══██╗████╗ ████║",
        "██║  ██║██║   ██║██║   ██║██╔████╔██║",
        "██║  ██║██║   ██║██║   ██║██║╚██╔╝██║",
        "██████╔╝╚██████╔╝╚██████╔╝██║ ╚═╝ ██║",
        "╚═════╝  ╚═════╝  ╚═════╝ ╚═╝     ╚═╝"
    )
    Write-Host ""
    foreach ($line in $banner) { Write-Host $line -ForegroundColor Red }
    Write-Host "         for when shit gets done" -ForegroundColor Yellow
    Write-Host ""
}
