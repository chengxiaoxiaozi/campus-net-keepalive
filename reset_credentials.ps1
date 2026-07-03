$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$CredentialPath = Join-Path $ProjectDir "credentials.xml"

Write-Host "Reset Campus Net Keepalive credentials"
Write-Host "This only rewrites credentials.xml. It does not change config.ini or scheduled task."
Write-Host ""

$Account = Read-Host "Campus account/student id, without @cmcc"
$Password = Read-Host "Campus password" -AsSecureString

$Credential = New-Object System.Management.Automation.PSCredential($Account, $Password)
$Credential | Export-Clixml -LiteralPath $CredentialPath

Write-Host ""
Write-Host "Updated: $CredentialPath"
Write-Host "You can close this window."
Read-Host "Press Enter to close"
