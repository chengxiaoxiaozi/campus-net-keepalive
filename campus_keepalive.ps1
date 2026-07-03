$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$ConfigPath = Join-Path $ProjectDir "config.ini"
$CredentialPath = Join-Path $ProjectDir "credentials.xml"
$StatePath = Join-Path $ProjectDir "state.json"
$LogPath = Join-Path $ProjectDir "keepalive.log"
$MutexName = "Local\CampusNetKeepalive"
$Script:MaxLogBytes = 65536
$Script:LogRetentionDays = 3
$Script:MaxLogArchives = 3

function Write-KeepaliveLog([string]$Message) {
    $ArchivePattern = "keepalive.*.log"
    $Cutoff = (Get-Date).AddDays(-1 * $Script:LogRetentionDays)

    Get-ChildItem -LiteralPath $ProjectDir -Filter $ArchivePattern -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $Cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $Archives = Get-ChildItem -LiteralPath $ProjectDir -Filter $ArchivePattern -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($Archives.Count -gt $Script:MaxLogArchives) {
        $Archives | Select-Object -Skip $Script:MaxLogArchives |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $LogPath) {
        $Item = Get-Item -LiteralPath $LogPath
        if ($Item.Length -gt $Script:MaxLogBytes) {
            $Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
            $ArchivePath = Join-Path $ProjectDir "keepalive.$Stamp.log"
            Move-Item -LiteralPath $LogPath -Destination $ArchivePath -Force
        }
    }

    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
}

function Read-IniFile([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing config.ini. Run setup.ps1 first."
    }

    $Data = @{}
    $Section = ""
    foreach ($RawLine in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $Line = $RawLine.Trim()
        if ($Line.Length -eq 0 -or $Line.StartsWith(";") -or $Line.StartsWith("#")) {
            continue
        }
        if ($Line -match '^\[(.+)\]$') {
            $Section = $Matches[1].Trim()
            if (-not $Data.ContainsKey($Section)) {
                $Data[$Section] = @{}
            }
            continue
        }
        if ($Line -match '^([^=]+)=(.*)$') {
            if (-not $Data.ContainsKey($Section)) {
                $Data[$Section] = @{}
            }
            $Data[$Section][$Matches[1].Trim()] = $Matches[2].Trim()
        }
    }
    return $Data
}

function Get-ConfigValue($Config, [string]$Section, [string]$Key, [string]$Default = "") {
    if ($Config.ContainsKey($Section) -and $Config[$Section].ContainsKey($Key)) {
        return [string]$Config[$Section][$Key]
    }
    return $Default
}

function ConvertTo-PlainText([Security.SecureString]$Secure) {
    $Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
    }
}

function Invoke-JsonpGet([string]$Url, [hashtable]$Pairs, [int]$TimeoutSeconds) {
    $OrderedPairs = New-Object System.Collections.ArrayList
    [void]$OrderedPairs.Add([pscustomobject]@{ Key = "callback"; Value = "drkeepalive" })
    foreach ($Key in $Pairs.Keys) {
        if ($Key -ne "callback" -and $Key -ne "v") {
            [void]$OrderedPairs.Add([pscustomobject]@{ Key = $Key; Value = $Pairs[$Key] })
        }
    }
    [void]$OrderedPairs.Add([pscustomobject]@{ Key = "v"; Value = (Get-Random -Minimum 1000 -Maximum 999999) })
    if (-not ($OrderedPairs | Where-Object { $_.Key -eq "lang" })) {
        [void]$OrderedPairs.Add([pscustomobject]@{ Key = "lang"; Value = "zh" })
    }

    $Query = ($OrderedPairs | ForEach-Object {
        "{0}={1}" -f [uri]::EscapeDataString([string]$_.Key), [uri]::EscapeDataString([string]$_.Value)
    }) -join "&"
    $FullUrl = "$Url`?$Query"

    $Response = Invoke-WebRequest -Uri $FullUrl -UseBasicParsing -Proxy $null -TimeoutSec $TimeoutSeconds
    $Content = $Response.Content.Trim()
    if ($Content -match '^[^(]+\((.*)\);?\s*$') {
        return $Matches[1] | ConvertFrom-Json
    }
    return $Content
}

function Get-State {
    $DefaultState = [pscustomobject]@{
        consecutive_offline = 0
        cooldown_until = ""
        last_result = ""
        last_online_log_at = ""
        updated_at = ""
    }

    if (Test-Path -LiteralPath $StatePath) {
        try {
            $State = Get-Content -LiteralPath $StatePath -Encoding UTF8 | ConvertFrom-Json
            foreach ($Property in $DefaultState.PSObject.Properties.Name) {
                if (-not ($State.PSObject.Properties.Name -contains $Property)) {
                    $State | Add-Member -MemberType NoteProperty -Name $Property -Value $DefaultState.$Property
                }
            }
            return $State
        } catch {
            Write-KeepaliveLog "State file is invalid; resetting it."
        }
    }
    return $DefaultState
}

function Save-State($State) {
    $State.updated_at = (Get-Date).ToString("s")
    $State | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $StatePath -Encoding UTF8
}

function Get-WlanUserIp([string]$ConfiguredIp, [string]$InterfaceAlias) {
    if ($ConfiguredIp) {
        return $ConfiguredIp
    }

    $Addresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
        Where-Object {
            $_.IPAddress -notlike "169.254.*" -and
            $_.IPAddress -ne "127.0.0.1" -and
            $_.IPAddress -notlike "198.18.*"
        }

    if ($InterfaceAlias) {
        $Match = $Addresses | Where-Object { $_.InterfaceAlias -eq $InterfaceAlias } | Select-Object -First 1
        if ($Match) {
            return $Match.IPAddress
        }
    }

    $Preferred = $Addresses | Where-Object { $_.IPAddress -like "10.*" } | Select-Object -First 1
    if ($Preferred) {
        return $Preferred.IPAddress
    }

    $First = $Addresses | Select-Object -First 1
    if ($First) {
        return $First.IPAddress
    }

    throw "Cannot determine WLAN IPv4 address."
}

function Get-WlanUserMac([string]$ConfiguredMac, [string]$InterfaceAlias) {
    if ($ConfiguredMac) {
        return ($ConfiguredMac -replace '[:-]', '').ToUpperInvariant()
    }

    $Adapters = Get-NetAdapter -ErrorAction Stop | Where-Object { $_.Status -eq "Up" }
    if ($InterfaceAlias) {
        $Match = $Adapters | Where-Object { $_.Name -eq $InterfaceAlias } | Select-Object -First 1
        if ($Match) {
            return ($Match.MacAddress -replace '[:-]', '').ToUpperInvariant()
        }
    }

    $Preferred = $Adapters | Where-Object { $_.Name -match "WLAN|Wi-Fi|无线|WIFI" } | Select-Object -First 1
    if ($Preferred) {
        return ($Preferred.MacAddress -replace '[:-]', '').ToUpperInvariant()
    }

    $First = $Adapters | Select-Object -First 1
    if ($First) {
        return ($First.MacAddress -replace '[:-]', '').ToUpperInvariant()
    }

    throw "Cannot determine WLAN MAC address."
}

function Test-PortalOnline($OnlineList) {
    if ($OnlineList -is [string]) {
        return $false
    }
    return ($OnlineList.result -eq 1 -and $OnlineList.list -and $OnlineList.list.Count -gt 0)
}

$Mutex = New-Object System.Threading.Mutex($false, $MutexName)
if (-not $Mutex.WaitOne(0)) {
    Write-KeepaliveLog "Another instance is running; exit."
    exit 0
}

try {
    $Config = Read-IniFile $ConfigPath

    $ServerIp = Get-ConfigValue $Config "portal" "server_ip" "10.10.244.11"
    $PortalPort = Get-ConfigValue $Config "portal" "portal_port" "801"
    $AccountSuffix = Get-ConfigValue $Config "portal" "account_suffix" "@cmcc"
    $AccountPrefix = Get-ConfigValue $Config "portal" "account_prefix" ",0,"
    $InterfaceAlias = Get-ConfigValue $Config "network" "interface_alias" ""
    $ConfiguredIp = Get-ConfigValue $Config "network" "wlan_user_ip" ""
    $ConfiguredMac = Get-ConfigValue $Config "network" "wlan_user_mac" ""
    $TimeoutSeconds = [int](Get-ConfigValue $Config "guard" "timeout_seconds" "5")
    $OfflineConfirmations = [int](Get-ConfigValue $Config "guard" "offline_confirmations" "2")
    $CooldownSeconds = [int](Get-ConfigValue $Config "guard" "cooldown_seconds" "300")
    $OnlineHeartbeatMinutes = [int](Get-ConfigValue $Config "logging" "online_heartbeat_minutes" "360")
    $Script:MaxLogBytes = [int](Get-ConfigValue $Config "logging" "max_log_bytes" "65536")
    $Script:LogRetentionDays = [int](Get-ConfigValue $Config "logging" "retention_days" "3")
    $Script:MaxLogArchives = [int](Get-ConfigValue $Config "logging" "max_archives" "3")

    $WlanUserIp = Get-WlanUserIp $ConfiguredIp $InterfaceAlias
    $WlanUserMac = Get-WlanUserMac $ConfiguredMac $InterfaceAlias
    $PortalBase = "http://$ServerIp`:$PortalPort/eportal/portal"
    $OnlineListUrl = "$PortalBase/online_list"
    $LoginUrl = "$PortalBase/login"

    $State = Get-State
    $OnlineList = Invoke-JsonpGet $OnlineListUrl @{
        wlan_user_ip = $WlanUserIp
        user_account = ""
        jsVersion = "4.1.3"
    } $TimeoutSeconds

    if (Test-PortalOnline $OnlineList) {
        $ShouldLogOnline = $State.last_result -ne "online"
        if (-not $ShouldLogOnline -and $State.last_online_log_at) {
            $LastOnlineLogAt = [datetime]$State.last_online_log_at
            $ShouldLogOnline = ((Get-Date) - $LastOnlineLogAt).TotalMinutes -ge $OnlineHeartbeatMinutes
        } elseif (-not $State.last_online_log_at) {
            $ShouldLogOnline = $true
        }

        $State.consecutive_offline = 0
        $State.cooldown_until = ""
        $State.last_result = "online"
        if ($ShouldLogOnline) {
            $State.last_online_log_at = (Get-Date).ToString("s")
        }
        Save-State $State
        if ($ShouldLogOnline) {
            $User = ($OnlineList.list | Select-Object -First 1).user_account
            Write-KeepaliveLog "Online: $User $WlanUserIp $WlanUserMac"
        }
        exit 0
    }

    $State.consecutive_offline = [int]$State.consecutive_offline + 1
    $State.last_result = "offline"
    Save-State $State
    Write-KeepaliveLog "Offline confirmation $($State.consecutive_offline)/$OfflineConfirmations."

    if ([int]$State.consecutive_offline -lt $OfflineConfirmations) {
        exit 0
    }

    if ($State.cooldown_until) {
        $CooldownUntil = [datetime]$State.cooldown_until
        if ((Get-Date) -lt $CooldownUntil) {
            Write-KeepaliveLog "In cooldown until $($CooldownUntil.ToString('s')); skip login."
            exit 0
        }
    }

    if (-not (Test-Path -LiteralPath $CredentialPath)) {
        throw "Missing credentials.xml. Run setup.ps1 first."
    }

    $Credential = Import-Clixml -LiteralPath $CredentialPath
    $RawUser = $Credential.UserName
    $Password = ConvertTo-PlainText $Credential.Password
    if ($RawUser.EndsWith($AccountSuffix)) {
        $AccountWithSuffix = $RawUser
    } else {
        $AccountWithSuffix = "$RawUser$AccountSuffix"
    }
    $PortalAccount = "$AccountPrefix$AccountWithSuffix"

    try {
        Write-KeepaliveLog "Sending one login request for $AccountWithSuffix."
        $LoginResult = Invoke-JsonpGet $LoginUrl @{
            login_method = "1"
            user_account = $PortalAccount
            user_password = $Password
            wlan_user_ip = $WlanUserIp
            wlan_user_ipv6 = ""
            wlan_user_mac = $WlanUserMac
            wlan_ac_ip = $ServerIp
            wlan_ac_name = ""
            jsVersion = "4.1.3"
            terminal_type = "1"
            lang = "zh-cn"
        } $TimeoutSeconds
    } finally {
        $Password = $null
    }

    $Msg = ""
    if ($LoginResult -and $LoginResult.msg) {
        $Msg = [string]$LoginResult.msg
    }
    $PortalReportedSuccess = ($LoginResult -and (
        $LoginResult.result -eq 1 -or
        $LoginResult.result -eq "ok" -or
        $Msg -match "成功"
    ))

    $OnlineAfterLogin = $null
    for ($CheckIndex = 1; $CheckIndex -le 4; $CheckIndex++) {
        Start-Sleep -Seconds 3
        $OnlineAfterLogin = Invoke-JsonpGet $OnlineListUrl @{
            wlan_user_ip = $WlanUserIp
            user_account = $AccountWithSuffix
            jsVersion = "4.1.3"
        } $TimeoutSeconds
        if (Test-PortalOnline $OnlineAfterLogin) {
            break
        }
    }

    if (Test-PortalOnline $OnlineAfterLogin) {
        $State.consecutive_offline = 0
        $State.cooldown_until = ""
        $State.last_result = "login_ok"
        $State.last_online_log_at = (Get-Date).ToString("s")
        Save-State $State
        Write-KeepaliveLog "Login succeeded."
        exit 0
    }

    if ($PortalReportedSuccess) {
        $State.consecutive_offline = 0
        $State.cooldown_until = ""
        $State.last_result = "login_pending_online"
        Save-State $State
        Write-KeepaliveLog "Portal reported login success; online_list has not caught up yet. msg=$Msg"
        exit 0
    }

    $MsgText = ""
    if ($Msg) { $MsgText = " msg=$Msg" }
    $State.cooldown_until = (Get-Date).AddSeconds($CooldownSeconds).ToString("s")
    $State.last_result = "login_failed"
    Save-State $State
    Write-KeepaliveLog "Login did not restore online state.$MsgText Cooldown $CooldownSeconds seconds."
    exit 1
} catch {
    Write-KeepaliveLog "Error: $($_.Exception.Message)"
    exit 1
} finally {
    if ($Mutex) {
        [void]$Mutex.ReleaseMutex()
        $Mutex.Dispose()
    }
}
