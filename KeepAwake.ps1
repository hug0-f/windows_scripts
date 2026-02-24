#Requires -Version 5.1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Config = @{
    WallpaperPattern  = 'wp*.png'
    WallpaperFallback = 'wp.png'
    IconFile          = 'icon.ico'
    TempBmpName       = 'kawt_wallpaper.bmp'
    KeepAwakeInterval = 20000
    UiPollInterval    = 200
    AppName           = 'KeepAwake'
}

function Write-Log {
    param([string]$Message, [ValidateSet('INFO','WARN','ERROR')]$Level = 'INFO')
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "[$timestamp][$Level] $Message"
}

function Set-Wallpaper {
    param([string]$Root, [hashtable]$Cfg)

    $candidates = Get-ChildItem -Path $Root -Filter $Cfg.WallpaperPattern -ErrorAction SilentlyContinue |
                  Select-Object -ExpandProperty FullName

    if ($candidates.Count -eq 0) {
        $fallback = Join-Path $Root $Cfg.WallpaperFallback
        if (Test-Path $fallback) { $candidates = @($fallback) }
    }

    if ($candidates.Count -eq 0) {
        Write-Log "No wallpaper found, skipping." 'WARN'
        return
    }

    $chosen = $candidates | Get-Random
    $bmp    = Join-Path $env:TEMP $Cfg.TempBmpName

    Write-Log "Wallpaper selected: $(Split-Path $chosen -Leaf)"

    $img = [System.Drawing.Image]::FromFile($chosen)
    try {
        $img.Save($bmp, [System.Drawing.Imaging.ImageFormat]::Bmp)
    } finally {
        $img.Dispose()
    }

    [Wallpaper]::SystemParametersInfo(20, 0, $bmp, 0x01 -bor 0x02) | Out-Null
}

function Update-Tooltip {
    param($NotifyIcon, [datetime]$StartTime, [string]$AppName)
    $elapsed = (Get-Date) - $StartTime
    $NotifyIcon.Text = "$AppName - running for {0:hh\:mm\:ss}" -f $elapsed
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]'Wallpaper').Type) {
    Add-Type @"
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
}

if (-not ([System.Management.Automation.PSTypeName]'PowerManagement').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PowerManagement {
    [DllImport("kernel32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
    public const uint ES_CONTINUOUS       = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;
}
"@
}

$root      = $PSScriptRoot
$startTime = Get-Date

Write-Log "$($Config.AppName) starting..."

try {
    Set-Wallpaper -Root $root -Cfg $Config
} catch {
    Write-Log "Failed to apply wallpaper: $_" 'ERROR'
}

$ni = New-Object System.Windows.Forms.NotifyIcon

$icoPath = Join-Path $root $Config.IconFile
$ni.Icon  = if (Test-Path $icoPath) {
    New-Object System.Drawing.Icon($icoPath)
} else {
    [System.Drawing.SystemIcons]::Information
}

$ni.Text    = $Config.AppName
$ni.Visible = $true

$menu          = New-Object System.Windows.Forms.ContextMenuStrip
$menuWallpaper = $menu.Items.Add("Change wallpaper")
$menu.Items.Add('-') | Out-Null
$menuStop      = $menu.Items.Add("Stop $($Config.AppName)")

$ni.ContextMenuStrip = $menu

$state = @{ Running = $true }

$menuWallpaper.Add_Click({
    try { Set-Wallpaper -Root $root -Cfg $Config }
    catch { Write-Log "Failed to change wallpaper: $_" 'ERROR' }
})

$menuStop.Add_Click({
    Write-Log "$($Config.AppName) stop requested by user."
    $state.Running = $false
    [PowerManagement]::SetThreadExecutionState([PowerManagement]::ES_CONTINUOUS) | Out-Null
    $ni.Visible = $false
    $ni.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

$ni.Add_DoubleClick({
    $elapsed = (Get-Date) - $startTime
    $ni.ShowBalloonTip(
        3000,
        $Config.AppName,
        "Running for {0:hh\:mm\:ss}" -f $elapsed,
        [System.Windows.Forms.ToolTipIcon]::Info
    )
})

$timerKeepAwake = New-Object System.Windows.Forms.Timer
$timerKeepAwake.Interval = $Config.KeepAwakeInterval
$timerKeepAwake.Add_Tick({
    [PowerManagement]::SetThreadExecutionState(
        [PowerManagement]::ES_CONTINUOUS `
        -bor [PowerManagement]::ES_SYSTEM_REQUIRED `
        -bor [PowerManagement]::ES_DISPLAY_REQUIRED
    ) | Out-Null
})
$timerKeepAwake.Start()

$timerTooltip = New-Object System.Windows.Forms.Timer
$timerTooltip.Interval = 60000
$timerTooltip.Add_Tick({
    try { Update-Tooltip -NotifyIcon $ni -StartTime $startTime -AppName $Config.AppName }
    catch {}
})
$timerTooltip.Start()

Write-Log "$($Config.AppName) running. Right-click the tray icon to stop."

try {
    while ($state.Running) {
        [System.Windows.Forms.Application]::DoEvents()
        Start-Sleep -Milliseconds $Config.UiPollInterval
    }
} finally {
    $timerKeepAwake.Stop(); $timerKeepAwake.Dispose()
    $timerTooltip.Stop();   $timerTooltip.Dispose()
    if ($ni.Visible) { $ni.Visible = $false; $ni.Dispose() }
    [PowerManagement]::SetThreadExecutionState([PowerManagement]::ES_CONTINUOUS) | Out-Null
    Write-Log "$($Config.AppName) stopped cleanly."
}
