# Balance Game 防火牆設定腳本

param(
    [int]$Port = 7788,
    [switch]$RemoveRule = $false,
    [switch]$CheckStatus = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host @"
Balance Game 防火牆設定腳本

用法:
    .\setup_firewall.ps1 [-Port <port>] [-RemoveRule] [-CheckStatus] [-Help]

參數:
    -Port        連接埠號碼 (預設: 7788)
    -RemoveRule  移除防火牆規則
    -CheckStatus 檢查目前防火牆狀態
    -Help        顯示此說明

範例:
    .\setup_firewall.ps1                    # 新增防火牆規則
    .\setup_firewall.ps1 -Port 8080         # 指定連接埠
    .\setup_firewall.ps1 -CheckStatus       # 檢查狀態
    .\setup_firewall.ps1 -RemoveRule        # 移除規則
"@
    exit 0
}

# 檢查管理員權限
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "此腳本需要管理員權限。請以管理員身分執行 PowerShell。"
    exit 1
}

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "        Balance Game 防火牆設定工具" -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""

$ruleName = "Balance Game - Port $Port"

# 檢查狀態功能
if ($CheckStatus) {
    Write-Host "檢查防火牆狀態..." -ForegroundColor Green
    Write-Host ""
    
    # 檢查 Windows Defender 防火牆是否啟用
    Write-Host "Windows Defender 防火牆狀態:" -ForegroundColor Yellow
    try {
        $firewallProfiles = Get-NetFirewallProfile
        foreach ($profile in $firewallProfiles) {
            $status = if ($profile.Enabled) { "啟用" } else { "停用" }
            $color = if ($profile.Enabled) { "Green" } else { "Red" }
            Write-Host "  $($profile.Name): $status" -ForegroundColor $color
        }
    }
    catch {
        Write-Warning "無法取得防火牆設定檔狀態"
    }
    
    Write-Host ""
    
    # 檢查特定規則
    Write-Host "Balance Game 防火牆規則:" -ForegroundColor Yellow
    try {
        $existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        if ($existingRule) {
            Write-Host "  ✅ 規則存在: $ruleName" -ForegroundColor Green
            Write-Host "  　 狀態: $($existingRule.Enabled)" -ForegroundColor Gray
            Write-Host "  　 動作: $($existingRule.Action)" -ForegroundColor Gray
            Write-Host "  　 方向: $($existingRule.Direction)" -ForegroundColor Gray
            
            # 取得連接埠資訊
            $portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $existingRule
            if ($portFilter) {
                Write-Host "  　 連接埠: $($portFilter.LocalPort)" -ForegroundColor Gray
                Write-Host "  　 協定: $($portFilter.Protocol)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ❌ 規則不存在: $ruleName" -ForegroundColor Red
        }
    }
    catch {
        Write-Warning "無法檢查防火牆規則"
    }
    
    Write-Host ""
    
    # 檢查連接埠是否被佔用
    Write-Host "連接埠使用狀況:" -ForegroundColor Yellow
    try {
        $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
        if ($portInUse) {
            Write-Host "  ✅ 連接埠 $Port 正在使用中" -ForegroundColor Green
            foreach ($connection in $portInUse) {
                Write-Host "  　 狀態: $($connection.State)" -ForegroundColor Gray
                Write-Host "  　 程序: $(Get-Process -Id $connection.OwningProcess -ErrorAction SilentlyContinue | Select-Object -ExpandProperty ProcessName)" -ForegroundColor Gray
            }
        } else {
            Write-Host "  ⚠️  連接埠 $Port 未在使用中" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Warning "無法檢查連接埠狀況"
    }
    
    exit 0
}

# 移除規則功能
if ($RemoveRule) {
    Write-Host "移除防火牆規則..." -ForegroundColor Yellow
    try {
        # 使用 PowerShell cmdlet
        Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
        
        # 使用 netsh 作為備用方法
        & netsh advfirewall firewall delete rule name="$ruleName" 2>$null
        
        Write-Host "✅ 防火牆規則已移除: $ruleName" -ForegroundColor Green
    }
    catch {
        Write-Warning "移除防火牆規則時發生錯誤: $_"
    }
    exit 0
}

# 新增防火牆規則
Write-Host "設定防火牆規則..." -ForegroundColor Green
Write-Host "連接埠: $Port" -ForegroundColor Yellow
Write-Host "規則名稱: $ruleName" -ForegroundColor Yellow
Write-Host ""

try {
    # 方法 1: 使用 PowerShell cmdlet (推薦)
    Write-Host "1. 嘗試使用 PowerShell 防火牆 cmdlet..." -ForegroundColor Cyan
    
    # 先移除可能存在的舊規則
    Remove-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    
    # 新增入站規則
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Protocol TCP -LocalPort $Port -Action Allow -Profile Domain,Private,Public
    
    Write-Host "✅ PowerShell 方法成功" -ForegroundColor Green
}
catch {
    Write-Warning "PowerShell 方法失敗: $_"
    
    # 方法 2: 使用 netsh (備用方法)
    Write-Host "2. 嘗試使用 netsh 命令..." -ForegroundColor Cyan
    
    try {
        # 先刪除可能存在的規則
        & netsh advfirewall firewall delete rule name="$ruleName" 2>$null
        
        # 新增規則
        $result = & netsh advfirewall firewall add rule name="$ruleName" dir=in action=allow protocol=TCP localport=$Port
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ netsh 方法成功" -ForegroundColor Green
        } else {
            Write-Error "netsh 命令失敗，退出代碼: $LASTEXITCODE"
        }
    }
    catch {
        Write-Error "netsh 方法也失敗: $_"
        Write-Host ""
        Write-Host "手動設定指南:" -ForegroundColor Yellow
        Write-Host "1. 開啟 Windows 設定"
        Write-Host "2. 搜尋「Windows Defender 防火牆」"
        Write-Host "3. 點選「進階設定」"
        Write-Host "4. 左側點選「輸入規則」"
        Write-Host "5. 右側點選「新增規則...」"
        Write-Host "6. 選擇「連接埠」→ 下一步"
        Write-Host "7. 選擇「TCP」，輸入連接埠: $Port → 下一步"
        Write-Host "8. 選擇「允許連線」→ 下一步"
        Write-Host "9. 全選所有設定檔 → 下一步"
        Write-Host "10. 名稱輸入: $ruleName → 完成"
        exit 1
    }
}

Write-Host ""

# 驗證規則是否成功建立
Write-Host "驗證防火牆規則..." -ForegroundColor Green
try {
    Start-Sleep -Seconds 2
    $rule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
    if ($rule) {
        Write-Host "✅ 防火牆規則驗證成功" -ForegroundColor Green
        Write-Host "　 規則名稱: $($rule.DisplayName)" -ForegroundColor Gray
        Write-Host "　 狀態: $($rule.Enabled)" -ForegroundColor Gray
        Write-Host "　 動作: $($rule.Action)" -ForegroundColor Gray
    } else {
        Write-Warning "無法找到剛建立的規則，但可能仍然有效"
    }
}
catch {
    Write-Warning "無法驗證規則: $_"
}

Write-Host ""

# 額外的網路設定建議
Write-Host "額外建議設定:" -ForegroundColor Yellow
Write-Host "1. 確保網路設定檔為「私人」:" -ForegroundColor Cyan
Write-Host "   設定 → 網路和網際網路 → 變更連線內容 → 選擇「私人」"
Write-Host ""
Write-Host "2. 檢查網路探索:" -ForegroundColor Cyan
Write-Host "   控制台 → 網路和共用中心 → 變更進階共用設定"
Write-Host "   啟用「網路探索」和「檔案及印表機共用」"
Write-Host ""
Write-Host "3. 測試連接:" -ForegroundColor Cyan
Write-Host "   curl http://localhost:$Port"
Write-Host "   telnet localhost $Port"
Write-Host ""

Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "防火牆設定完成！" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "下一步:" -ForegroundColor Yellow
Write-Host "1. 測試本機連接: http://localhost:$Port"
Write-Host "2. 測試區網連接: http://[您的IP]:$Port"
Write-Host "3. 如果仍有問題，執行: .\setup_firewall.ps1 -CheckStatus"