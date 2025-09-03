# IIS 部署指南

## 系統需求

### 1. 安裝 .NET 8.0 Hosting Bundle
- 下載並安裝：[ASP.NET Core Runtime 8.0.x Hosting Bundle](https://dotnet.microsoft.com/download/dotnet/8.0)
- 安裝後重啟 IIS：`iisreset`

### 2. 啟用 IIS 功能
在 Windows 功能中啟用：
- Internet Information Services
- World Wide Web Services
- Application Development Features → ASP.NET 4.8
- Application Development Features → WebSocket Protocol

## 部署步驟

### 1. 準備網站檔案
已發布的檔案位於：`publish` 資料夾

### 2. 在 IIS 中創建網站

#### 方法一：使用 IIS 管理器 (GUI)
1. 開啟 IIS 管理器
2. 右鍵點擊「網站」→「新增網站」
3. 設定：
   - **網站名稱**: BalanceGame
   - **應用程式集區**: 建立新的或使用預設
   - **實體路徑**: `C:\Users\billchen\RiderProjects\balance - the arvage number game\publish`
   - **連線類型**: http
   - **IP 位址**: 全部未指派
   - **連接埠**: 80 (或其他可用埠，如 8080)
   - **主機名稱**: (可留空，或設定域名)

#### 方法二：使用命令列
```cmd
# 以管理員身分執行 PowerShell
cd "C:\Windows\System32\inetsrv"

# 建立應用程式集區
.\appcmd.exe add apppool /name:"BalanceGamePool" /managedRuntimeVersion:""

# 建立網站
.\appcmd.exe add site /name:"BalanceGame" /physicalPath:"C:\Users\billchen\RiderProjects\balance - the arvage number game\publish" /bindings:http/*:8080:

# 設定應用程式集區
.\appcmd.exe set app "BalanceGame/" /applicationPool:"BalanceGamePool"
```

### 3. 設定應用程式集區
1. 在 IIS 管理器中，點擊「應用程式集區」
2. 找到您的應用程式集區，右鍵「進階設定」
3. 設定：
   - **.NET CLR 版本**: 沒有 Managed 程式碼
   - **受管理的管線模式**: 整合式
   - **啟用 32 位元應用程式**: False
   - **處理序模型 → 身分識別**: ApplicationPoolIdentity

### 4. 權限設定
確保應用程式集區身分識別有權限存取：
- 網站資料夾 (讀取和執行)
- 資料庫檔案 `balance_game.db` (讀取、寫入)
- Logs 資料夾 (如果有的話)

```cmd
# 給予應用程式集區存取權限 (以管理員身分執行)
icacls "C:\Users\billchen\RiderProjects\balance - the arvage number game\publish" /grant "IIS AppPool\BalanceGamePool":(OI)(CI)RX
```

## 網路設定

### 1. 防火牆設定
```cmd
# 以管理員身分執行
netsh advfirewall firewall add rule name="BalanceGame HTTP" dir=in action=allow protocol=TCP localport=8080
```

### 2. 局域網存取
如果要讓同網路其他電腦存取：
1. 找到您的 IP 位址：`ipconfig`
2. 其他用戶可以通過 `http://您的IP:8080` 存取

### 3. 繫結多個位址 (可選)
在 IIS 中可以設定多個繫結：
- `http://localhost:8080`
- `http://您的電腦名稱:8080`
- `http://您的IP:8080`

## 故障排除

### 1. 檢查 Windows 事件檢視器
- Windows 記錄 → 應用程式
- 應用程式和服務記錄 → Microsoft → Windows → IIS-AspNetCoreModule

### 2. 啟用詳細錯誤
在 `web.config` 中暫時啟用：
```xml
<aspNetCore processPath="dotnet" 
            arguments=".\BalanceGame.dll" 
            stdoutLogEnabled="true" 
            stdoutLogFile=".\logs\stdout" />
```

### 3. 常見問題
- **500.19 錯誤**: 檢查 .NET Core Hosting Bundle 是否安裝
- **500.30 錯誤**: 檢查應用程式啟動失敗，查看事件記錄
- **403 錯誤**: 檢查檔案權限
- **連線問題**: 檢查防火牆和網路設定

## 測試部署
1. 瀏覽器開啟：`http://localhost:8080`
2. 應該看到登入頁面
3. 註冊新用戶測試功能

## 更新應用程式
1. 停止 IIS 網站或應用程式集區
2. 覆蓋 publish 資料夾中的檔案
3. 重啟網站或應用程式集區

## 生產環境建議
- 設定 HTTPS (SSL 憑證)
- 設定自動備份資料庫
- 監控應用程式效能
- 設定日誌輪替
