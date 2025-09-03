# IIS 權限修正腳本
param(
    [string]$SitePath = ".\publish",
    [string]$PoolName = "BalanceGamePool"
)

# 檢查管理員權限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "此腳本需要管理員權限。請以管理員身分執行 PowerShell。"
    exit 1
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "        IIS 權限修正腳本" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$PhysicalPath = Resolve-Path $SitePath

Write-Host "修正路徑: $PhysicalPath" -ForegroundColor Yellow
Write-Host "應用程式集區: $PoolName" -ForegroundColor Yellow
Write-Host ""

Write-Host "1. 重設資料夾權限..." -ForegroundColor Green
try {
    # 重設權限
    & icacls $PhysicalPath /reset /T
    Write-Host "[OK] 權限已重設" -ForegroundColor Green
}
catch {
    Write-Warning "重設權限失敗: $_"
}

Write-Host "2. 設定基本權限..." -ForegroundColor Green
try {
    # 管理員完整權限
    & icacls $PhysicalPath /grant "Administrators":F /T
    
    # 系統帳戶完整權限
    & icacls $PhysicalPath /grant "NT AUTHORITY\SYSTEM":F /T
    
    # 應用程式集區完整權限
    & icacls $PhysicalPath /grant "IIS AppPool\$PoolName":F /T
    
    # IIS 用戶讀取執行權限
    & icacls $PhysicalPath /grant "IIS_IUSRS":RX /T
    
    # 網路服務讀取執行權限
    & icacls $PhysicalPath /grant "NT AUTHORITY\NETWORK SERVICE":RX /T
    
    # IUSR 讀取權限
    & icacls $PhysicalPath /grant "IUSR":R /T
    
    Write-Host "[OK] 基本權限設定完成" -ForegroundColor Green
}
catch {
    Write-Error "設定基本權限失敗: $_"
    exit 1
}

Write-Host "3. 檢查關鍵檔案..." -ForegroundColor Green
$webConfigPath = Join-Path $PhysicalPath "web.config"
$dllPath = Join-Path $PhysicalPath "BalanceGame.dll"

if (Test-Path $webConfigPath) {
    Write-Host "[OK] web.config 檔案存在" -ForegroundColor Green
    & icacls $webConfigPath /grant "IIS AppPool\$PoolName":F
    & icacls $webConfigPath /grant "IIS_IUSRS":R
} else {
    Write-Warning "web.config 檔案不存在"
}

if (Test-Path $dllPath) {
    Write-Host "[OK] BalanceGame.dll 檔案存在" -ForegroundColor Green
} else {
    Write-Warning "BalanceGame.dll 檔案不存在，請確認應用程式已正確發布"
}

Write-Host "4. 建立並設定 logs 資料夾..." -ForegroundColor Green
$logsPath = Join-Path $PhysicalPath "logs"
if (-not (Test-Path $logsPath)) {
    New-Item -ItemType Directory -Path $logsPath -Force | Out-Null
}
& icacls $logsPath /grant "IIS AppPool\$PoolName":F /T
Write-Host "[OK] logs 資料夾權限設定完成" -ForegroundColor Green

Write-Host "5. 顯示最終權限..." -ForegroundColor Green
Write-Host "web.config 權限:"
& icacls $webConfigPath | Select-Object -First 10

Write-Host ""
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "              權限修正完成！" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "請嘗試重新啟動 IIS 網站:" -ForegroundColor Yellow
Write-Host "  iisreset" -ForegroundColor Green
Write-Host "或重啟應用程式集區:" -ForegroundColor Yellow
Write-Host "  $env:SystemRoot\System32\inetsrv\appcmd.exe recycle apppool $PoolName" -ForegroundColor Green
