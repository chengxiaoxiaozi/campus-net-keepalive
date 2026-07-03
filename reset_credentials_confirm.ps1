$ErrorActionPreference = "Stop"

$ProjectDir = $PSScriptRoot
$CredentialPath = Join-Path $ProjectDir "credentials.xml"

function ConvertTo-PlainText([Security.SecureString]$Secure) {
    $Ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try {
        [Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($Ptr)
    }
}

Write-Host "Reset Campus Net Keepalive credentials with confirmation"
Write-Host "Password content is never printed. Only length is shown."
Write-Host ""

$Account = Read-Host "Campus account/student id, without @cmcc"
$Password1 = Read-Host "Campus password" -AsSecureString
$Password2 = Read-Host "Campus password again" -AsSecureString

$Plain1 = ConvertTo-PlainText $Password1
$Plain2 = ConvertTo-PlainText $Password2

try {
    Write-Host ""
    Write-Host "Password length: $($Plain1.Length)"

    if ($Plain1 -ne $Plain2) {
        Write-Host "Passwords do not match. Nothing was saved."
        Read-Host "Press Enter to close"
        exit 1
    }

    if ($Plain1.Length -lt 8) {
        Write-Host "Warning: password length is less than 8. If this is unexpected, close this window and retry."
        $Confirm = Read-Host "Type YES to save anyway"
        if ($Confirm -ne "YES") {
            Write-Host "Nothing was saved."
            Read-Host "Press Enter to close"
            exit 1
        }
    }

    $Credential = New-Object System.Management.Automation.PSCredential($Account, $Password1)
    $Credential | Export-Clixml -LiteralPath $CredentialPath

    Write-Host ""
    Write-Host "Updated: $CredentialPath"
} finally {
    $Plain1 = $null
    $Plain2 = $null
}

Read-Host "Press Enter to close"
