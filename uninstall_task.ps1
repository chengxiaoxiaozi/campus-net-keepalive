$ErrorActionPreference = "Stop"

$TaskName = "CampusNetKeepalive"

$Result = & schtasks.exe /Delete /TN $TaskName /F 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Removed scheduled task: $TaskName"
} else {
    Write-Host "Scheduled task was not removed. It may not exist, or Windows denied access."
    Write-Host $Result
}

Write-Host "Local files are kept in this folder."
Write-Host "To fully remove local state, delete config.ini, credentials.xml, keepalive.log, keepalive.*.log, and state.json."
