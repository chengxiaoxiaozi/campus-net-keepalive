$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$ScriptPath = Join-Path $ProjectDir "campus_keepalive.ps1"
$HiddenRunnerPath = Join-Path $ProjectDir "run_hidden.vbs"
$ConfigPath = Join-Path $ProjectDir "config.ini"
$TaskName = "CampusNetKeepalive"

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    throw "campus_keepalive.ps1 not found: $ScriptPath"
}

if (-not (Test-Path -LiteralPath $HiddenRunnerPath)) {
    throw "run_hidden.vbs not found: $HiddenRunnerPath"
}

if (-not (Test-Path -LiteralPath $ConfigPath) -or
    -not (Test-Path -LiteralPath (Join-Path $ProjectDir "credentials.xml"))) {
    throw "Run setup.ps1 first, then install the scheduled task."
}

function Read-IniValue([string]$Path, [string]$Section, [string]$Key, [string]$Default) {
    $CurrentSection = ""
    foreach ($RawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $Line = $RawLine.Trim()
        if ($Line.Length -eq 0 -or $Line.StartsWith(";") -or $Line.StartsWith("#")) { continue }
        if ($Line -match '^\[(.+)\]$') {
            $CurrentSection = $Matches[1].Trim()
            continue
        }
        if ($CurrentSection -eq $Section -and $Line -match '^([^=]+)=(.*)$') {
            if ($Matches[1].Trim() -eq $Key) {
                return $Matches[2].Trim()
            }
        }
    }
    return $Default
}

$CheckIntervalMinutes = [int](Read-IniValue $ConfigPath "schedule" "check_interval_minutes" "1")
if ($CheckIntervalMinutes -lt 1) { $CheckIntervalMinutes = 1 }

$WScriptExe = Join-Path $env:SystemRoot "System32\wscript.exe"
$TaskRun = "`"$WScriptExe`" `"$HiddenRunnerPath`""

schtasks.exe /Create /TN $TaskName /TR $TaskRun /SC MINUTE /MO $CheckIntervalMinutes /F | Out-Null

Write-Host "Installed scheduled task: $TaskName"
Write-Host "Schedule: every $CheckIntervalMinutes minute(s)"
Write-Host "Script: $ScriptPath"
Write-Host "Hidden runner: $HiddenRunnerPath"
Write-Host "This task runs as the current Windows user and does not require an always-on background process."
