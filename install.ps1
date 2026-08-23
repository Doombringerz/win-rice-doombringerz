# install.ps1 - Doombringerz win-rice installer
# Run: irm https://raw.githubusercontent.com/Doombringerz/win-rice-doombringerz/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

$installDir  = Join-Path $env:USERPROFILE ".win-rice-doombringerz"
$profileSrc  = Join-Path $installDir "powershell\profile.ps1"
$starshipSrc = Join-Path $installDir "powershell\starship-red.toml"  # default theme; switch with doom-theme
$starshipDst = Join-Path $env:USERPROFILE ".config\starship.toml"
$terminalRef = Join-Path $installDir "terminal\settings.json"

# Source repo. Override with $env:WIN_RICE_SOURCE (fork, local checkout, mirror) before running.
$cloneSource = if ($env:WIN_RICE_SOURCE) { $env:WIN_RICE_SOURCE } else { "https://github.com/Doombringerz/win-rice-doombringerz.git" }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# ── Clone or update ─────────────────────────────────────────────────────────
if (Test-Path $installDir) {
    Write-Host "Updating existing install at $installDir" -ForegroundColor Yellow
    Push-Location $installDir
    try { git pull --quiet } finally { Pop-Location }
} else {
    Write-Host "Cloning to $installDir from $cloneSource" -ForegroundColor Green
    git clone --quiet $cloneSource $installDir
}

# ── Starship (scoop preferred, winget fallback) ─────────────────────────────
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Host "Starship already installed: $((Get-Command starship).Source)" -ForegroundColor Cyan
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Installing Starship via scoop..." -ForegroundColor Yellow
    scoop install starship
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Installing Starship via winget..." -ForegroundColor Yellow
    winget install --id Starship.Starship --source winget --accept-source-agreements --accept-package-agreements
} else {
    Write-Host "Neither scoop nor winget found. Install Starship manually: https://starship.rs/install" -ForegroundColor Red
}

# Refresh PATH for the current session in case the installer just added it.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

if (Get-Command starship -ErrorAction SilentlyContinue) {
    Write-Host "Starship ready at: $((Get-Command starship).Source)" -ForegroundColor Green
} else {
    Write-Host "starship is not on PATH yet. Open a new terminal, or see https://starship.rs/install" -ForegroundColor Yellow
}

# ── JetBrainsMono Nerd Font ─────────────────────────────────────────────────
# Starship uses Nerd Font glyphs; without the font they render as [?]. A
# per-user font install is not loaded by elevated processes, so admin terminals
# show [?] unless the font is machine-wide. Run this installer elevated for a
# machine-wide install; otherwise it installs per-user and prints how to cover
# admin terminals. The font is fetched from the official Nerd Fonts release,
# never vendored here. JetBrains Mono is OFL-1.1; the patched Nerd Fonts builds
# are OFL-1.1-no-RFN.

function Test-NerdFont {
    param([switch]$MachineOnly)
    $dirs = if ($MachineOnly) { @("$env:WINDIR\Fonts") }
            else { @("$env:LOCALAPPDATA\Microsoft\Windows\Fonts", "$env:WINDIR\Fonts") }
    @(Get-ChildItem $dirs -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "(?i)JetBrainsMono.*Nerd.*\.ttf$" }).Count -gt 0
}

if (Test-NerdFont) {
    Write-Host "JetBrainsMono Nerd Font already installed." -ForegroundColor Cyan
} elseif ($isAdmin -and (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Host "Installing JetBrainsMono Nerd Font via winget (machine-wide)..." -ForegroundColor Yellow
    winget install --id DEVCOM.JetBrainsMonoNerdFont --scope machine --source winget --accept-source-agreements --accept-package-agreements
} elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Installing JetBrainsMono Nerd Font via scoop (per-user)..." -ForegroundColor Yellow
    scoop bucket add nerd-fonts 2>$null
    scoop install nerd-fonts/JetBrainsMono-NF
} elseif (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Installing JetBrainsMono Nerd Font via winget (per-user)..." -ForegroundColor Yellow
    winget install --id DEVCOM.JetBrainsMonoNerdFont --scope user --source winget --accept-source-agreements --accept-package-agreements
} else {
    $scopeLabel = if ($isAdmin) { "machine-wide" } else { "per-user" }
    Write-Host "No scoop/winget. Downloading JetBrainsMono Nerd Font ($scopeLabel)..." -ForegroundColor Yellow
    try {
        $tmp = Join-Path ([IO.Path]::GetTempPath()) "win-rice-jbm"
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        $zip = Join-Path $tmp "JetBrainsMono.zip"
        Invoke-WebRequest -UseBasicParsing -OutFile $zip `
            -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
        Expand-Archive -Path $zip -DestinationPath $tmp -Force

        if ($isAdmin) {
            $fontDir = "$env:WINDIR\Fonts"
            $fontReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        } else {
            $fontDir = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
            $fontReg = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
        }
        New-Item -ItemType Directory -Force -Path $fontDir | Out-Null

        # Match the main monospaced faces across Nerd Fonts naming schemes (the
        # zip layout and file names have changed between releases). Recurse in
        # case the archive nests files; skip Propo and NoLigatures variants.
        Get-ChildItem $tmp -Recurse -Filter "*.ttf" |
            Where-Object { $_.Name -match "(?i)JetBrainsMono.*Nerd" -and $_.Name -notmatch "(?i)(Propo|NoLig)" } |
            ForEach-Object {
                $target = Join-Path $fontDir $_.Name
                Copy-Item $_.FullName $target -Force
                $regName = ($_.BaseName -replace "(?i)NerdFontMono", " Nerd Font Mono " `
                                        -replace "(?i)NerdFont", " Nerd Font " `
                                        -replace "-", " " -replace "\s+", " ").Trim()
                New-ItemProperty -Path $fontReg -Name "$regName (TrueType)" -Value $target -PropertyType String -Force | Out-Null
            }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
    } catch {
        Write-Host "Font install failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Install it manually: https://github.com/ryanoasis/nerd-fonts/releases" -ForegroundColor Red
    }
}

if (Test-NerdFont) {
    Write-Host "JetBrainsMono Nerd Font ready." -ForegroundColor Green
    if (-not (Test-NerdFont -MachineOnly)) {
        Write-Host "Installed per-user. Admin terminals will show [?] until the font is machine-wide." -ForegroundColor Yellow
        Write-Host "To cover admin terminals, re-run this installer from an elevated terminal (Run as administrator)." -ForegroundColor Yellow
    }
} else {
    Write-Host "No Nerd Font detected. Starship icons will show as [?] until you install one." -ForegroundColor Yellow
}

# ── Copy starship.toml to ~/.config/ (back up existing) ─────────────────────
$starshipDstDir = Split-Path $starshipDst -Parent
if (-not (Test-Path $starshipDstDir)) { New-Item -ItemType Directory -Path $starshipDstDir -Force | Out-Null }
if (Test-Path $starshipDst) {
    $backup = "$starshipDst.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $starshipDst $backup
    Write-Host "Existing starship.toml backed up to $backup" -ForegroundColor Yellow
}
Copy-Item $starshipSrc $starshipDst -Force
Write-Host "starship.toml installed at $starshipDst" -ForegroundColor Green

# ── Add source line to $PROFILE (back up existing first) ────────────────────
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType File -Path $PROFILE -Force | Out-Null
} else {
    $profileBackup = "$PROFILE.backup.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $PROFILE $profileBackup
    Write-Host "Existing profile backed up to $profileBackup" -ForegroundColor Yellow
}
$sourceLine  = ". `"$profileSrc`""
$profileBody = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
if (-not $profileBody -or $profileBody -notmatch [regex]::Escape($sourceLine)) {
    Add-Content -Path $PROFILE -Value "`n# Doombringerz win-rice`n$sourceLine`n"
    Write-Host "Added source line to your PowerShell profile." -ForegroundColor Green
}

# ── Source profile for the current session ──────────────────────────────────
. $profileSrc

# ── Windows Terminal: reference only, not auto-applied ──────────────────────
Write-Host ""
Write-Host "Windows Terminal settings are not auto-applied (no overwrite of your config)." -ForegroundColor Cyan
Write-Host "Reference: $terminalRef" -ForegroundColor Cyan
Write-Host "Open Windows Terminal > Settings > Open JSON file, then merge the" -ForegroundColor Cyan
Write-Host "'profiles.defaults' block and 'Doombringerz Dark' scheme." -ForegroundColor Cyan
Write-Host ""
Write-Host "Set the font, or the prompt icons show as [?]:" -ForegroundColor Cyan
Write-Host '  "profiles": { "defaults": { "font": { "face": "JetBrainsMono Nerd Font" } } }' -ForegroundColor Cyan
Write-Host ""
Write-Host "win-rice installed. Open a fresh terminal to see the new prompt." -ForegroundColor Green
Write-Host ""
