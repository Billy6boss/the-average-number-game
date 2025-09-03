# Balance Game IIS 部署 PowerShell 腳本 (兼容版本)
param(
    [string]$SiteName = "BalanceGame",
    [int]$Port = 7788,
    [string]$PoolName = "BalanceGamePool",
    [switch]$SkipPublish = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host @"
Balance Game IIS 部署腳本

用法:
    .\deploy_to_iis_compatible.ps1 [-SiteName <name>] [-Port <port>] [-PoolName <pool>] [-SkipPublish] [-Help]

參數:
    -SiteName   IIS 網站名稱 (預設: BalanceGame)
    -Port       HTTP 連接埠 (預設: 7788)
    -PoolName   應用程式集區名稱 (預設: BalanceGamePool)
    -SkipPublish 跳過專案發布步驟
    -Help       顯示此說明

範例:
    .\deploy_to_iis_compatible.ps1
    .\deploy_to_iis_compatible.ps1 -SiteName "MyBalanceGame" -Port 9000
    .\deploy_to_iis_compatible.ps1 -SkipPublish
"@
    exit 0
}

# 檢查管理員權限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "此腳本需要管理員權限。請以管理員身分執行 PowerShell。"
    exit 1
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "        Balance Game IIS 部署腳本 (兼容版)" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$PhysicalPath = Join-Path $PSScriptRoot "publish"
$appcmd = "$env:SystemRoot\System32\inetsrv\appcmd.exe"

# 檢查 appcmd 是否存在
if (-not (Test-Path $appcmd)) {
    Write-Error "找不到 appcmd.exe，請確認 IIS 已正確安裝。"
    exit 1
}

# 1. 發布專案
if (-not $SkipPublish) {
    Write-Host "1. 建立發布版本..." -ForegroundColor Green
    try {
        & dotnet publish -c Release -o $PhysicalPath --self-contained false --verbosity quiet
        if ($LASTEXITCODE -ne 0) {
            throw "發布失敗"
        }
        Write-Host "[OK] 發布成功" -ForegroundColor Green
    }
    catch {
        Write-Error "發布失敗: $_"
        exit 1
    }
} else {
    Write-Host "1. 跳過發布步驟" -ForegroundColor Yellow
}

Write-Host ""

# 2. 建立應用程式集區
Write-Host "2. 設定應用程式集區..." -ForegroundColor Green
try {
    # 刪除現有的應用程式集區
    & $appcmd delete apppool $PoolName 2>$null
    
    # 建立新的應用程式集區
    & $appcmd add apppool /name:$PoolName /managedRuntimeVersion:
    if ($LASTEXITCODE -ne 0) {
        throw "建立應用程式集區失敗"
    }
    
    # 設定應用程式集區屬性
    & $appcmd set apppool $PoolName /processModel.identityType:ApplicationPoolIdentity
    & $appcmd set apppool $PoolName /enable32BitAppOnWin64:false
    
    Write-Host "[OK] 應用程式集區 '$PoolName' 已建立" -ForegroundColor Green
}
catch {
    Write-Error "建立應用程式集區失敗: $_"
    exit 1
}

# 3. 建立網站
Write-Host "3. 設定網站..." -ForegroundColor Green
try {
    # 刪除現有網站
    & $appcmd delete site $SiteName 2>$null
    
    # 建立新網站
    & $appcmd add site /name:$SiteName /physicalPath:$PhysicalPath /bindings:http/*:${Port}:
    if ($LASTEXITCODE -ne 0) {
        throw "建立網站失敗"
    }
    
    # 設定應用程式集區
    & $appcmd set app "$SiteName/" /applicationPool:$PoolName
    
    Write-Host "[OK] 網站 '$SiteName' 已建立" -ForegroundColor Green
}
catch {
    Write-Error "建立網站失敗: $_"
    exit 1
}

# 4. 設定權限
Write-Host "4. 設定檔案權限..." -ForegroundColor Green
try {
    # 給予應用程式集區身分識別完整權限
    & icacls $PhysicalPath /grant "IIS AppPool\$PoolName":(OI)(CI)F /T 2>$null
    Write-Host "[OK] 已授予應用程式集區完整權限" -ForegroundColor Green
    
    # 給予 IIS_IUSRS 讀取權限
    & icacls $PhysicalPath /grant "IIS_IUSRS":(OI)(CI)RX /T 2>$null
    Write-Host "[OK] 已授予 IIS_IUSRS 讀取權限" -ForegroundColor Green
    
    # 給予 IUSR 讀取權限
    & icacls $PhysicalPath /grant "IUSR":(OI)(CI)RX /T 2>$null
    Write-Host "[OK] 已授予 IUSR 讀取權限" -ForegroundColor Green
    
    # 特別設定 web.config 權限
    $webConfigPath = Join-Path $PhysicalPath "web.config"
    if (Test-Path $webConfigPath) {
        & icacls $webConfigPath /grant "IIS AppPool\$PoolName":F 2>$null
        & icacls $webConfigPath /grant "IIS_IUSRS":R 2>$null
        & icacls $webConfigPath /grant "IUSR":R 2>$null
        Write-Host "[OK] web.config 權限設定完成" -ForegroundColor Green
    }
    
    Write-Host "[OK] 權限設定完成" -ForegroundColor Green
}
catch {
    Write-Warning "權限設定失敗: $_"
}

# 5. 設定防火牆
Write-Host "5. 設定防火牆..." -ForegroundColor Green
try {
    $ruleName = "BalanceGame HTTP Port $Port"
    # 刪除現有規則
    & netsh advfirewall firewall delete rule name=$ruleName 2>$null
    # 添加新規則
    & netsh advfirewall firewall add rule name=$ruleName dir=in action=allow protocol=TCP localport=$Port
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] 防火牆規則已新增" -ForegroundColor Green
    } else {
        Write-Warning "防火牆設定可能失敗"
    }
}
catch {
    Write-Warning "防火牆設定失敗: $_"
}

# 6. 啟動服務
Write-Host "6. 啟動應用程式集區和網站..." -ForegroundColor Green
try {
    & $appcmd start apppool $PoolName
    & $appcmd start site $SiteName
    Write-Host "[OK] 服務已啟動" -ForegroundColor Green
}
catch {
    Write-Warning "啟動服務時出現問題: $_"
}

# 7. 獲取本機 IP
Write-Host "7. 獲取網路資訊..." -ForegroundColor Green
$localIPs = @()
try {
    $networkAdapters = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    foreach ($adapter in $networkAdapters) {
        if ($adapter.IPAddress) {
            foreach ($ip in $adapter.IPAddress) {
                if ($ip -match '^\d+\.\d+\.\d+\.\d+$' -and $ip -ne '127.0.0.1') {
                    $localIPs += $ip
                }
            }
        }
    }
}
catch {
    Write-Warning "無法獲取 IP 位址資訊"
}

# 8. 額外權限檢查和修正
Write-Host "7. 額外權限檢查和修正..." -ForegroundColor Green
try {
    # 取得系統帳戶並設定權限
    $systemAccount = "NT AUTHORITY\SYSTEM"
    $networkService = "NT AUTHORITY\NETWORK SERVICE"
    
    # 重新設定根資料夾權限
    & icacls $PhysicalPath /reset /T 2>$null
    & icacls $PhysicalPath /grant "Administrators":F /T 2>$null
    & icacls $PhysicalPath /grant $systemAccount:F /T 2>$null
    & icacls $PhysicalPath /grant "IIS AppPool\$PoolName":F /T 2>$null
    & icacls $PhysicalPath /grant "IIS_IUSRS":RX /T 2>$null
    & icacls $PhysicalPath /grant $networkService:RX /T 2>$null
    
    Write-Host "[OK] 已重新設定資料夾權限" -ForegroundColor Green
    
    # 檢查並建立 logs 資料夾
    $logsPath = Join-Path $PhysicalPath "logs"
    if (-not (Test-Path $logsPath)) {
        New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
        & icacls $logsPath /grant "IIS AppPool\$PoolName":F /T 2>$null
        Write-Host "[OK] 已建立 logs 資料夾" -ForegroundColor Green
    }
}
catch {
    Write-Warning "額外權限設定時出現問題: $_"
}

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "              部署完成！" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "網站資訊:" -ForegroundColor Yellow
Write-Host "  名稱: $SiteName"
Write-Host "  應用程式集區: $PoolName"
Write-Host "  實體路徑: $PhysicalPath"
Write-Host "  連接埠: $Port"
Write-Host ""
Write-Host "存取網址:" -ForegroundColor Yellow
Write-Host "  本機: http://localhost:$Port" -ForegroundColor Green
if ($localIPs.Count -gt 0) {
    foreach ($ip in $localIPs) {
        Write-Host "  區網: http://$ip`:$Port" -ForegroundColor Green
    }
} else {
    Write-Host "  區網: http://[您的IP]:$Port" -ForegroundColor Green
}
Write-Host ""
Write-Host "管理命令:" -ForegroundColor Yellow
Write-Host "  停止網站: $appcmd stop site $SiteName"
Write-Host "  啟動網站: $appcmd start site $SiteName"
Write-Host "  重啟應用程式集區: $appcmd recycle apppool $PoolName"
Write-Host ""

# 9. 測試連線
Write-Host "測試網站是否可存取..." -ForegroundColor Yellow
try {
    Start-Sleep -Seconds 3
    $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] 網站運行正常！" -ForegroundColor Green
        Write-Host "可以開始使用天秤遊戲了！" -ForegroundColor Green
    } else {
        Write-Warning "網站回應狀態碼: $($response.StatusCode)"
    }
}
catch {
    Write-Warning "無法立即連接到網站，請稍等片刻後嘗試存取"
    Write-Host "如果仍有問題，請檢查 Windows 事件檢視器中的 IIS 記錄" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "部署完成！請開啟瀏覽器測試遊戲功能。" -ForegroundColor Cyan
