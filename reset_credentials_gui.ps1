$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ProjectDir = $PSScriptRoot
$CredentialPath = Join-Path $ProjectDir "credentials.xml"

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Campus Net Keepalive - Reset Credentials"
$Form.StartPosition = "CenterScreen"
$Form.Size = New-Object System.Drawing.Size(430, 270)
$Form.FormBorderStyle = "FixedDialog"
$Form.MaximizeBox = $false
$Form.MinimizeBox = $false

$AccountLabel = New-Object System.Windows.Forms.Label
$AccountLabel.Text = "Account, without @cmcc"
$AccountLabel.Location = New-Object System.Drawing.Point(20, 20)
$AccountLabel.Size = New-Object System.Drawing.Size(160, 24)
$Form.Controls.Add($AccountLabel)

$AccountBox = New-Object System.Windows.Forms.TextBox
$AccountBox.Location = New-Object System.Drawing.Point(190, 18)
$AccountBox.Size = New-Object System.Drawing.Size(200, 24)
$AccountBox.Text = "1025071709"
$Form.Controls.Add($AccountBox)

$PasswordLabel = New-Object System.Windows.Forms.Label
$PasswordLabel.Text = "Password"
$PasswordLabel.Location = New-Object System.Drawing.Point(20, 60)
$PasswordLabel.Size = New-Object System.Drawing.Size(160, 24)
$Form.Controls.Add($PasswordLabel)

$PasswordBox = New-Object System.Windows.Forms.TextBox
$PasswordBox.Location = New-Object System.Drawing.Point(190, 58)
$PasswordBox.Size = New-Object System.Drawing.Size(200, 24)
$PasswordBox.UseSystemPasswordChar = $true
$Form.Controls.Add($PasswordBox)

$PasswordLenLabel = New-Object System.Windows.Forms.Label
$PasswordLenLabel.Text = "Length: 0"
$PasswordLenLabel.Location = New-Object System.Drawing.Point(190, 84)
$PasswordLenLabel.Size = New-Object System.Drawing.Size(200, 20)
$Form.Controls.Add($PasswordLenLabel)

$ConfirmLabel = New-Object System.Windows.Forms.Label
$ConfirmLabel.Text = "Password again"
$ConfirmLabel.Location = New-Object System.Drawing.Point(20, 112)
$ConfirmLabel.Size = New-Object System.Drawing.Size(160, 24)
$Form.Controls.Add($ConfirmLabel)

$ConfirmBox = New-Object System.Windows.Forms.TextBox
$ConfirmBox.Location = New-Object System.Drawing.Point(190, 110)
$ConfirmBox.Size = New-Object System.Drawing.Size(200, 24)
$ConfirmBox.UseSystemPasswordChar = $true
$Form.Controls.Add($ConfirmBox)

$ConfirmLenLabel = New-Object System.Windows.Forms.Label
$ConfirmLenLabel.Text = "Length: 0"
$ConfirmLenLabel.Location = New-Object System.Drawing.Point(190, 136)
$ConfirmLenLabel.Size = New-Object System.Drawing.Size(200, 20)
$Form.Controls.Add($ConfirmLenLabel)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Enter the 8-character campus password twice."
$StatusLabel.Location = New-Object System.Drawing.Point(20, 165)
$StatusLabel.Size = New-Object System.Drawing.Size(370, 24)
$Form.Controls.Add($StatusLabel)

$SaveButton = New-Object System.Windows.Forms.Button
$SaveButton.Text = "Save"
$SaveButton.Location = New-Object System.Drawing.Point(220, 198)
$SaveButton.Size = New-Object System.Drawing.Size(80, 28)
$Form.Controls.Add($SaveButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Text = "Cancel"
$CancelButton.Location = New-Object System.Drawing.Point(310, 198)
$CancelButton.Size = New-Object System.Drawing.Size(80, 28)
$Form.Controls.Add($CancelButton)

$UpdateStatus = {
    $PasswordLenLabel.Text = "Length: $($PasswordBox.Text.Length)"
    $ConfirmLenLabel.Text = "Length: $($ConfirmBox.Text.Length)"
    if ($PasswordBox.Text.Length -eq 8 -and $ConfirmBox.Text.Length -eq 8 -and $PasswordBox.Text -eq $ConfirmBox.Text) {
        $StatusLabel.Text = "Ready to save."
        $StatusLabel.ForeColor = [System.Drawing.Color]::DarkGreen
    } else {
        $StatusLabel.Text = "Need two matching 8-character passwords."
        $StatusLabel.ForeColor = [System.Drawing.Color]::DarkRed
    }
}

$PasswordBox.Add_TextChanged($UpdateStatus)
$ConfirmBox.Add_TextChanged($UpdateStatus)

$SaveButton.Add_Click({
    if ([string]::IsNullOrWhiteSpace($AccountBox.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Account cannot be empty.", "Error") | Out-Null
        return
    }
    if ($PasswordBox.Text.Length -ne 8 -or $ConfirmBox.Text.Length -ne 8) {
        [System.Windows.Forms.MessageBox]::Show("Password length must be 8.", "Error") | Out-Null
        return
    }
    if ($PasswordBox.Text -ne $ConfirmBox.Text) {
        [System.Windows.Forms.MessageBox]::Show("Passwords do not match.", "Error") | Out-Null
        return
    }

    $Secure = ConvertTo-SecureString $PasswordBox.Text -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($AccountBox.Text.Trim(), $Secure)
    $Credential | Export-Clixml -LiteralPath $CredentialPath
    [System.Windows.Forms.MessageBox]::Show("Credentials saved.", "Done") | Out-Null
    $Form.Close()
})

$CancelButton.Add_Click({ $Form.Close() })

[void]$Form.ShowDialog()
