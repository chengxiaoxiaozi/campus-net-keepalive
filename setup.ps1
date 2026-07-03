$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$ConfigPath = Join-Path $ProjectDir "config.ini"
$CredentialPath = Join-Path $ProjectDir "credentials.xml"

function Read-Default([string]$Prompt, [string]$Default) {
    $Value = Read-Host "$Prompt [$Default]"
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $Default
    }
    return $Value.Trim()
}

Write-Host "Campus Net Keepalive setup"
Write-Host "This writes only config.ini and credentials.xml in this folder."
Write-Host "credentials.xml is encrypted by Windows DPAPI for the current Windows user."
Write-Host ""

$Account = Read-Host "Campus account/student id, without @cmcc"
$Password = Read-Host "Campus password" -AsSecureString

$PortalUrl = Read-Default "Verification website" "https://p.njupt.edu.cn/a79.htm"
$ServerIp = Read-Default "Portal server IP" "10.10.244.11"
$PortalPort = Read-Default "Portal HTTP port" "801"
$AccountSuffix = Read-Default "Account suffix" "@cmcc"
$AccountPrefix = Read-Default "Portal account prefix" ",0,"
$InterfaceAlias = Read-Default "Network interface alias, leave empty for auto" ""
$WlanUserIp = Read-Default "WLAN IPv4, leave empty for auto" ""
$WlanUserMac = Read-Default "WLAN MAC, leave empty for auto" ""
$CheckIntervalMinutes = Read-Default "Check interval minutes" "1"
$OfflineConfirmations = Read-Default "Offline confirmations before login" "2"
$CooldownSeconds = Read-Default "Cooldown seconds after failed login" "300"
$OnlineHeartbeatMinutes = Read-Default "Online heartbeat log minutes" "360"
$MaxLogBytes = Read-Default "Max current log bytes" "65536"
$LogRetentionDays = Read-Default "Rotated log retention days" "3"
$MaxLogArchives = Read-Default "Max rotated log files" "3"

$Config = @"
[portal]
portal_url=$PortalUrl
server_ip=$ServerIp
portal_port=$PortalPort
account_suffix=$AccountSuffix
account_prefix=$AccountPrefix

[network]
interface_alias=$InterfaceAlias
wlan_user_ip=$WlanUserIp
wlan_user_mac=$WlanUserMac

[schedule]
check_interval_minutes=$CheckIntervalMinutes

[guard]
timeout_seconds=5
offline_confirmations=$OfflineConfirmations
cooldown_seconds=$CooldownSeconds

[logging]
online_heartbeat_minutes=$OnlineHeartbeatMinutes
max_log_bytes=$MaxLogBytes
retention_days=$LogRetentionDays
max_archives=$MaxLogArchives
"@

Set-Content -LiteralPath $ConfigPath -Value $Config -Encoding UTF8

$Credential = New-Object System.Management.Automation.PSCredential($Account, $Password)
$Credential | Export-Clixml -LiteralPath $CredentialPath

Write-Host ""
Write-Host "Wrote: $ConfigPath"
Write-Host "Wrote: $CredentialPath"
Write-Host "Next test:"
Write-Host "powershell -ExecutionPolicy Bypass -File `"$ProjectDir\campus_keepalive.ps1`""
