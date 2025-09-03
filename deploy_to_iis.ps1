# Balance Game IIS 部署 PowerShell 腳本
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
    .\deploy_to_iis.ps1 [-SiteName <name>] [-Port <port>] [-PoolName <pool>] [-SkipPublish] [-Help]

參數:
    -SiteName   IIS 網站名稱 (預設: BalanceGame)
    -Port       HTTP 連接埠 (預設: 8080)
    -PoolName   應用程式集區名稱 (預設: BalanceGamePool)
    -SkipPublish 跳過專案發布步驟
    -Help       顯示此說明

範例:
    .\deploy_to_iis.ps1
    .\deploy_to_iis.ps1 -SiteName "MyBalanceGame" -Port 9000
    .\deploy_to_iis.ps1 -SkipPublish
"@
    exit 0
}

# 檢查管理員權限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "此腳本需要管理員權限。請以管理員身分執行 PowerShell。"
    exit 1
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "        Balance Game IIS 部署腳本" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

# 檢查 .NET Core Hosting Bundle
Write-Host "檢查 .NET Core Hosting Bundle..." -ForegroundColor Yellow
$hostingBundle = Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Updates\.NET*" -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*ASP.NET Core*Hosting Bundle*" }
if (-not $hostingBundle) {
    Write-Warning "未檢測到 ASP.NET Core Hosting Bundle。請先安裝 .NET 8.0 Hosting Bundle。"
    Write-Host "下載位址: https://dotnet.microsoft.com/download/dotnet/8.0" -ForegroundColor Blue
}

$PhysicalPath = Join-Path $PSScriptRoot "publish"

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

# 2. 匯入 WebAdministration 模組
Write-Host "2. 載入 IIS 管理模組..." -ForegroundColor Green
try {
    Import-Module WebAdministration -ErrorAction Stop
    Write-Host "[OK] IIS 模組已載入" -ForegroundColor Green
}
catch {
    Write-Error "無法載入 IIS WebAdministration 模組。請確認 IIS 已安裝。"
    exit 1
}

# 3. 建立應用程式集區
Write-Host "3. 設定應用程式集區..." -ForegroundColor Green
try {
    if (Test-Path "IIS:\AppPools\$PoolName") {
        Write-Host "[警告] 應用程式集區 '$PoolName' 已存在，將更新設定" -ForegroundColor Yellow
        Remove-WebAppPool -Name $PoolName
    }
    
    New-WebAppPool -Name $PoolName
    Set-ItemProperty -Path "IIS:\AppPools\$PoolName" -Name processModel.identityType -Value ApplicationPoolIdentity
    Set-ItemProperty -Path "IIS:\AppPools\$PoolName" -Name managedRuntimeVersion -Value ""
    Set-ItemProperty -Path "IIS:\AppPools\$PoolName" -Name enable32BitAppOnWin64 -Value $false
    
    Write-Host "[OK] 應用程式集區 '$PoolName' 已建立" -ForegroundColor Green
}
catch {
    Write-Error "建立應用程式集區失敗: $_"
    exit 1
}

# 4. 建立網站
Write-Host "4. 設定網站..." -ForegroundColor Green
try {
    if (Get-Website -Name $SiteName -ErrorAction SilentlyContinue) {
        Write-Host "[警告] 網站 '$SiteName' 已存在，將移除並重建" -ForegroundColor Yellow
        Remove-Website -Name $SiteName
    }
    
    New-Website -Name $SiteName -PhysicalPath $PhysicalPath -Port $Port -ApplicationPool $PoolName
    Write-Host "[OK] 網站 '$SiteName' 已建立" -ForegroundColor Green
}
catch {
    Write-Error "建立網站失敗: $_"
    exit 1
}

# 5. 設定權限
Write-Host "5. 設定檔案權限..." -ForegroundColor Green
try {
    $acl = Get-Acl $PhysicalPath
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("IIS AppPool\$PoolName", "ReadAndExecute", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl -Path $PhysicalPath -AclObject $acl
    Write-Host "[OK] 權限設定完成" -ForegroundColor Green
}
catch {
    Write-Warning "權限設定失敗: $_"
}

# 6. 設定防火牆
Write-Host "6. 設定防火牆..." -ForegroundColor Green
try {
    $ruleName = "BalanceGame HTTP Port $Port"
    $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($existingRule) {
        Remove-NetFirewallRule -DisplayName $ruleName
    }
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow | Out-Null
    Write-Host "[OK] 防火牆規則已新增" -ForegroundColor Green
}
catch {
    Write-Warning "防火牆設定失敗: $_"
}

# 7. 啟動服務
Write-Host "7. 啟動應用程式集區和網站..." -ForegroundColor Green
try {
    Start-WebAppPool -Name $PoolName
    Start-Website -Name $SiteName
    Write-Host "[OK] 服務已啟動" -ForegroundColor Green
}
catch {
    Write-Warning "啟動服務時出現問題: $_"
}

# 8. 獲取本機 IP
$localIPs = @()
Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -ne "127.0.0.1" } | ForEach-Object {
    $localIPs += $_.IPAddress
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
Write-Host ""
Write-Host "存取網址:" -ForegroundColor Yellow
Write-Host "  本機: http://localhost:$Port" -ForegroundColor Green
foreach ($ip in $localIPs) {
    Write-Host "  區網: http://$ip`:$Port" -ForegroundColor Green
}
Write-Host ""
Write-Host "管理命令:" -ForegroundColor Yellow
Write-Host "  停止: Stop-Website -Name '$SiteName'"
Write-Host "  啟動: Start-Website -Name '$SiteName'"
Write-Host "  重啟: Restart-WebAppPool -Name '$PoolName'"
Write-Host ""

# 9. 測試連線
Write-Host "測試網站是否可存取..." -ForegroundColor Yellow
try {
    Start-Sleep -Seconds 2
    $response = Invoke-WebRequest -Uri "http://localhost:$Port" -TimeoutSec 10 -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "[OK] 網站運行正常！" -ForegroundColor Green
    } else {
        Write-Warning "網站回應狀態碼: $($response.StatusCode)"
    }
}
catch {
    Write-Warning "無法連接到網站，請檢查設定或查看 Windows 事件記錄"
}

Write-Host ""
Write-Host "提示: 如需疑難排解，請查看 Windows 事件檢視器中的 IIS 相關記錄" -ForegroundColor Cyan
