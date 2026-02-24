# ============================================================
# PowerShell 7 Profile — Equivalent of .zshrc for Windows
# Location: $PROFILE (~\Documents\PowerShell\Microsoft.PowerShell_profile.ps1)
# ============================================================

# ============================================================
# Oh My Posh prompt (equivalent of Powerlevel10k)
# ============================================================
if (Get-Command "oh-my-posh" -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\dracula.omp.json" | Invoke-Expression
}

# ============================================================
# Modules
# ============================================================
Import-Module PSReadLine
Import-Module Terminal-Icons

if (Get-Module -ListAvailable -Name PSFzf) {
    Import-Module PSFzf
    Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+p' -PSReadlineChordReverseHistory 'Ctrl+r'
}

# ============================================================
# PSReadLine (autosuggestions + syntax highlighting)
# ============================================================
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -EditMode Emacs
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineOption -BellStyle None
Set-PSReadLineOption -MaximumHistoryCount 200000

# Accept autosuggestion with Ctrl+F, Tab for menu complete
Set-PSReadLineKeyHandler -Key "Ctrl+f" -Function ForwardWord
Set-PSReadLineKeyHandler -Key "Tab" -Function MenuComplete
Set-PSReadLineKeyHandler -Key "UpArrow" -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key "DownArrow" -Function HistorySearchForward

# ============================================================
# Environment
# ============================================================
$env:EDITOR = "vim"
$env:VISUAL = "vim"

# ============================================================
# Safe Remove (move to trash instead of delete)
# ============================================================
$TrashDir = "$env:USERPROFILE\.trash"

function Remove-SafeItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]]$Paths
    )

    if (-not (Test-Path $TrashDir)) { New-Item -ItemType Directory -Path $TrashDir -Force | Out-Null }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"

    foreach ($p in $Paths) {
        if (-not (Test-Path $p)) {
            Write-Error "rm: cannot remove '$p': No such file or directory"
            continue
        }

        $resolved = Resolve-Path $p
        $name = Split-Path $resolved -Leaf
        $dest = Join-Path $TrashDir "${timestamp}_${name}"

        Move-Item -Path $resolved -Destination $dest
    }
}

Set-Alias -Name rm -Value Remove-SafeItem -Option AllScope -Force

function emptytrash {
    $confirm = Read-Host "Empty trash ($TrashDir)? [y/N]"
    if ($confirm -eq 'y' -or $confirm -eq 'Y') {
        Remove-Item -Recurse -Force "$TrashDir\*"
    }
}

function rmtrash {
    Remove-Item -Recurse -Force $TrashDir
    Write-Host "Trash removed: $TrashDir"
}

# Real delete (bypass trash)
function rrm { Remove-Item -Recurse -Force @args }

# ============================================================
# Navigation aliases
# ============================================================
function .. { Set-Location .. }
function ... { Set-Location ..\.. }
function .... { Set-Location ..\..\.. }

# ============================================================
# Quick aliases
# ============================================================
Set-Alias -Name c -Value Clear-Host
function e { exit }
function ff { Clear-Host; fastfetch }

# ============================================================
# Git aliases
# ============================================================
function gs { git status }
function ga { git add @args }
function gaa { git add --all }
function gc { git commit @args }
function gp { git push @args }
function gl { git pull @args }
function gd { git diff @args }
function glog { git log --oneline --graph --decorate -20 }

# ============================================================
# Utility functions
# ============================================================

# Which command (like Linux)
function which { Get-Command @args | Select-Object -ExpandProperty Source }

# Open explorer in current directory
function open { explorer.exe . }

# Quick edit profile
function editprofile { vim $PROFILE }

# Reload profile
function reload { . $PROFILE; Write-Host "Profile reloaded" -ForegroundColor Green }

# System update (winget)
function sysupdate {
    Write-Host "==> Updating packages..." -ForegroundColor Cyan
    winget upgrade --all --accept-source-agreements --accept-package-agreements
}

# ============================================================
# Startup
# ============================================================
# Show fastfetch on new terminal (optional, comment out if too slow)
# fastfetch
