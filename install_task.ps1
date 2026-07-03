$ErrorActionPreference = "Stop"

$ProjectDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$AhkScript = Join-Path $ProjectDir "campus_keepalive.ahk"
$TaskName = "CampusNetKeepalive"

$AhkCandidates = @(
    "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
    "$env:ProgramFiles\AutoHotkey\AutoHotkey64.exe",
    "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
)

$AhkExe = $AhkCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $AhkExe) {
    throw "AutoHotkey v2 not found. Please install AutoHotkey v2 first."
}

if (-not (Test-Path $AhkScript)) {
    throw "campus_keepalive.ahk not found: $AhkScript"
}

$TaskRun = "`"$AhkExe`" `"$AhkScript`""

schtasks.exe /Create `
    /TN $TaskName `
    /TR $TaskRun `
    /SC MINUTE `
    /MO 1 `
    /F | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Schedule: every 1 minute"
Write-Host "Script: $AhkScript"
Write-Host "AutoHotkey: $AhkExe"
