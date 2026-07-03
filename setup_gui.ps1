$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ProjectDir = $PSScriptRoot
$ConfigPath = Join-Path $ProjectDir "config.ini"
$CredentialPath = Join-Path $ProjectDir "credentials.xml"
$InstallScript = Join-Path $ProjectDir "install_task.ps1"

function Save-Credential([string]$Account, [string]$Password) {
    $Secure = ConvertTo-SecureString $Password -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Account, $Secure)
    $Credential | Export-Clixml -LiteralPath $CredentialPath
}

function Get-OperatorSettings([string]$Operator, [string]$CustomSuffix) {
    switch ($Operator) {
        "China Mobile / cmcc" { return @{ Suffix = "@cmcc"; Prefix = ",0," } }
        "China Unicom / cucc" { return @{ Suffix = "@cucc"; Prefix = ",0," } }
        "China Telecom / ctcc" { return @{ Suffix = "@ctcc"; Prefix = ",0," } }
        "Campus only" { return @{ Suffix = ""; Prefix = ",0," } }
        default { return @{ Suffix = $CustomSuffix; Prefix = ",0," } }
    }
}

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Campus Net Keepalive Setup"
$Form.StartPosition = "CenterScreen"
$Form.Size = New-Object System.Drawing.Size(560, 650)
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false

$Y = 18
function Add-Label([string]$Text, [int]$YPos) {
    $Label = New-Object System.Windows.Forms.Label
    $Label.Text = $Text
    $Label.Location = New-Object System.Drawing.Point(22, $YPos)
    $Label.Size = New-Object System.Drawing.Size(170, 22)
    $Form.Controls.Add($Label)
    return $Label
}
function Add-TextBox([string]$Text, [int]$YPos) {
    $Box = New-Object System.Windows.Forms.TextBox
    $Box.Text = $Text
    $Box.Location = New-Object System.Drawing.Point(205, $YPos)
    $Box.Size = New-Object System.Drawing.Size(300, 24)
    $Form.Controls.Add($Box)
    return $Box
}

Add-Label "Verification website" $Y | Out-Null
$PortalUrlBox = Add-TextBox "https://p.njupt.edu.cn/a79.htm" $Y
$Y += 38

Add-Label "Portal server IP" $Y | Out-Null
$ServerIpBox = Add-TextBox "10.10.244.11" $Y
$Y += 38

Add-Label "Portal HTTP port" $Y | Out-Null
$PortalPortBox = Add-TextBox "801" $Y
$Y += 38

Add-Label "Operator" $Y | Out-Null
$OperatorBox = New-Object System.Windows.Forms.ComboBox
$OperatorBox.DropDownStyle = "DropDownList"
[void]$OperatorBox.Items.Add("China Mobile / cmcc")
[void]$OperatorBox.Items.Add("China Unicom / cucc")
[void]$OperatorBox.Items.Add("China Telecom / ctcc")
[void]$OperatorBox.Items.Add("Campus only")
[void]$OperatorBox.Items.Add("Custom")
$OperatorBox.SelectedIndex = 0
$OperatorBox.Location = New-Object System.Drawing.Point(205, $Y)
$OperatorBox.Size = New-Object System.Drawing.Size(300, 24)
$Form.Controls.Add($OperatorBox)
$Y += 38

Add-Label "Custom suffix" $Y | Out-Null
$CustomSuffixBox = Add-TextBox "" $Y
$CustomSuffixBox.Enabled = $false
$Y += 38

Add-Label "Account" $Y | Out-Null
$AccountBox = Add-TextBox "" $Y
$Y += 38

Add-Label "Password" $Y | Out-Null
$PasswordBox = Add-TextBox "" $Y
$PasswordBox.UseSystemPasswordChar = $true
$PasswordLenLabel = New-Object System.Windows.Forms.Label
$PasswordLenLabel.Text = "Length: 0"
$PasswordLenLabel.Location = New-Object System.Drawing.Point(205, ($Y + 26))
$PasswordLenLabel.Size = New-Object System.Drawing.Size(140, 18)
$Form.Controls.Add($PasswordLenLabel)
$Y += 55

Add-Label "Password again" $Y | Out-Null
$ConfirmBox = Add-TextBox "" $Y
$ConfirmBox.UseSystemPasswordChar = $true
$ConfirmLenLabel = New-Object System.Windows.Forms.Label
$ConfirmLenLabel.Text = "Length: 0"
$ConfirmLenLabel.Location = New-Object System.Drawing.Point(205, ($Y + 26))
$ConfirmLenLabel.Size = New-Object System.Drawing.Size(140, 18)
$Form.Controls.Add($ConfirmLenLabel)
$Y += 55

Add-Label "Check interval min" $Y | Out-Null
$CheckIntervalBox = Add-TextBox "1" $Y
$Y += 38

Add-Label "Offline confirmations" $Y | Out-Null
$OfflineConfirmBox = Add-TextBox "2" $Y
$Y += 38

Add-Label "Failure cooldown sec" $Y | Out-Null
$CooldownBox = Add-TextBox "300" $Y
$Y += 38

Add-Label "Heartbeat log min" $Y | Out-Null
$HeartbeatBox = Add-TextBox "360" $Y
$Y += 38

Add-Label "Log retention days" $Y | Out-Null
$RetentionBox = Add-TextBox "3" $Y
$Y += 38

Add-Label "Max log archives" $Y | Out-Null
$ArchivesBox = Add-TextBox "3" $Y
$Y += 38

Add-Label "Network interface" $Y | Out-Null
$InterfaceBox = Add-TextBox "" $Y
$Y += 38

$InstallTaskCheck = New-Object System.Windows.Forms.CheckBox
$InstallTaskCheck.Text = "Install or update scheduled task after saving"
$InstallTaskCheck.Checked = $true
$InstallTaskCheck.Location = New-Object System.Drawing.Point(205, $Y)
$InstallTaskCheck.Size = New-Object System.Drawing.Size(300, 24)
$Form.Controls.Add($InstallTaskCheck)
$Y += 38

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Fill in the fields, then click Save."
$StatusLabel.Location = New-Object System.Drawing.Point(22, $Y)
$StatusLabel.Size = New-Object System.Drawing.Size(500, 40)
$Form.Controls.Add($StatusLabel)
$Y += 48

$SaveButton = New-Object System.Windows.Forms.Button
$SaveButton.Text = "Save and configure"
$SaveButton.Location = New-Object System.Drawing.Point(290, $Y)
$SaveButton.Size = New-Object System.Drawing.Size(130, 30)
$Form.Controls.Add($SaveButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Text = "Cancel"
$CancelButton.Location = New-Object System.Drawing.Point(430, $Y)
$CancelButton.Size = New-Object System.Drawing.Size(75, 30)
$Form.Controls.Add($CancelButton)

$OperatorBox.Add_SelectedIndexChanged({
    $CustomSuffixBox.Enabled = ($OperatorBox.SelectedItem -eq "Custom")
})

$UpdatePasswordStatus = {
    $PasswordLenLabel.Text = "Length: $($PasswordBox.Text.Length)"
    $ConfirmLenLabel.Text = "Length: $($ConfirmBox.Text.Length)"
}
$PasswordBox.Add_TextChanged($UpdatePasswordStatus)
$ConfirmBox.Add_TextChanged($UpdatePasswordStatus)

$SaveButton.Add_Click({
    try {
        if ([string]::IsNullOrWhiteSpace($ServerIpBox.Text)) { throw "Portal server IP is required." }
        if ([string]::IsNullOrWhiteSpace($PortalPortBox.Text)) { throw "Portal HTTP port is required." }
        if ([string]::IsNullOrWhiteSpace($AccountBox.Text)) { throw "Account is required." }
        if ($PasswordBox.Text.Length -eq 0) { throw "Password is required." }
        if ($PasswordBox.Text -ne $ConfirmBox.Text) { throw "Passwords do not match." }

        $CheckInterval = [int]$CheckIntervalBox.Text
        $OfflineConfirmations = [int]$OfflineConfirmBox.Text
        $CooldownSeconds = [int]$CooldownBox.Text
        $HeartbeatMinutes = [int]$HeartbeatBox.Text
        $RetentionDays = [int]$RetentionBox.Text
        $MaxArchives = [int]$ArchivesBox.Text

        if ($CheckInterval -lt 1) { throw "Check interval must be at least 1 minute." }
        if ($OfflineConfirmations -lt 1) { throw "Offline confirmations must be at least 1." }
        if ($CooldownSeconds -lt 60) { throw "Failure cooldown should be at least 60 seconds." }

        $Operator = Get-OperatorSettings ([string]$OperatorBox.SelectedItem) $CustomSuffixBox.Text.Trim()
        $Account = $AccountBox.Text.Trim()
        if ($Account.EndsWith($Operator.Suffix) -and $Operator.Suffix.Length -gt 0) {
            $Account = $Account.Substring(0, $Account.Length - $Operator.Suffix.Length)
        }

        $Config = @"
[portal]
portal_url=$($PortalUrlBox.Text.Trim())
server_ip=$($ServerIpBox.Text.Trim())
portal_port=$($PortalPortBox.Text.Trim())
account_suffix=$($Operator.Suffix)
account_prefix=$($Operator.Prefix)

[network]
interface_alias=$($InterfaceBox.Text.Trim())
wlan_user_ip=
wlan_user_mac=

[schedule]
check_interval_minutes=$CheckInterval

[guard]
timeout_seconds=5
offline_confirmations=$OfflineConfirmations
cooldown_seconds=$CooldownSeconds

[logging]
online_heartbeat_minutes=$HeartbeatMinutes
max_log_bytes=65536
retention_days=$RetentionDays
max_archives=$MaxArchives
"@
        Set-Content -LiteralPath $ConfigPath -Value $Config -Encoding UTF8
        Save-Credential $Account $PasswordBox.Text

        if ($InstallTaskCheck.Checked) {
            & $InstallScript | Out-Null
        }

        [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully.", "Done") | Out-Null
        $Form.Close()
    } catch {
        $StatusLabel.Text = $_.Exception.Message
        $StatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
        [System.Windows.Forms.MessageBox]::Show($_.Exception.Message, "Setup failed") | Out-Null
    }
})

$CancelButton.Add_Click({ $Form.Close() })

[void]$Form.ShowDialog()
