# HTTP 后台认证模板。
# 这是无弹窗、无打断的推荐模式，但需要你先用浏览器开发者工具抓到登录请求。

$ErrorActionPreference = "Stop"

$ProbeUrls = @(
    "https://www.baidu.com/",
    "https://www.msftconnecttest.com/connecttest.txt",
    "https://www.gstatic.com/generate_204"
)

$TimeoutSeconds = 3
$LogPath = Join-Path $PSScriptRoot "http-login.log"

function Write-Log($Message) {
    $Line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $Message"
    Add-Content -LiteralPath $LogPath -Value $Line -Encoding UTF8
}

function Test-Online {
    foreach ($Url in $ProbeUrls) {
        try {
            $Response = Invoke-WebRequest -Uri $Url -Method Get -TimeoutSec $TimeoutSeconds -UseBasicParsing
            if ($Response.StatusCode -ge 200 -and $Response.StatusCode -lt 400) {
                return $true
            }
        } catch {
            continue
        }
    }
    return $false
}

if (Test-Online) {
    Write-Log "Online. Nothing to do."
    exit 0
}

Write-Log "Offline detected. Sending login request."

# TODO: 把下面这些字段替换成你从浏览器 Network 面板抓到的真实请求。
$LoginUrl = "https://example.edu/login"
$Method = "POST"

$Headers = @{
    "User-Agent" = "Mozilla/5.0"
    "Content-Type" = "application/x-www-form-urlencoded"
}

# 常见形式示例：
# username=你的账号&password=你的密码&submit=Sign+in
# 注意：如果要开源，不要把真实账号密码提交到 GitHub。
$Body = "username=YOUR_USERNAME&password=YOUR_PASSWORD&submit=Sign+in"

try {
    $Response = Invoke-WebRequest `
        -Uri $LoginUrl `
        -Method $Method `
        -Headers $Headers `
        -Body $Body `
        -TimeoutSec 10 `
        -UseBasicParsing

    Write-Log "Login request sent. HTTP $($Response.StatusCode)"
} catch {
    Write-Log "Login failed: $($_.Exception.Message)"
    exit 1
}

