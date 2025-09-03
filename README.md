# 金繼之國的闖關者 - 天秤遊戲

一個基於 ASP.NET Core 的多人即時數字猜測遊戲。

## 功能特色

- 🎮 **多人即時遊戲** - 支援 2-20 人同時遊玩
- 🏠 **房間系統** - 簡單的 5 位數房間號碼
- 💬 **即時聊天** - 房間內聊天功能
- 📊 **遊戲記錄** - 個人遊戲歷史記錄
- ⚙️ **房間設定** - 房主可調整遊戲參數
- 📱 **響應式設計** - 支援電腦和手機

## 遊戲規則

### 基本規則
1. 每位玩家在時間限制內選擇 0-100 的數字
2. 計算所有數字的平均值，再乘以 0.8 得到目標數字
3. 最接近目標數字的玩家獲勝
4. 失敗者扣 1 分，分數達到 -10 分則淘汰
5. 最後存活的玩家獲得最終勝利

### 特殊規則（根據人數調整）
- **4人以下**：相同數字的玩家答案無效，直接扣 1 分
- **3人以下**：數字與目標值完全相同的失敗者扣 2 分
- **2人以下**：若有人選擇 100，則距離平均值最遠的玩家獲勝

## 技術架構

- **後端**: ASP.NET Core 8.0 + SignalR
- **前端**: MVC + Bootstrap + JavaScript
- **資料庫**: SQLite + Entity Framework Core
- **即時通訊**: SignalR Hub

## 安裝與運行

### 系統需求
- .NET 8.0 SDK
- Windows/Linux/macOS

### 運行步驟

1. **還原 NuGet 套件**
   ```bash
   dotnet restore
   ```

2. **建立資料庫**
   ```bash
   dotnet ef database update
   ```
   （如果沒有 EF Tools，請先安裝：`dotnet tool install --global dotnet-ef`）

3. **運行應用程式**
   ```bash
   dotnet run
   ```

4. **開啟瀏覽器**
   - 本機地址：`http://localhost:5000`
   - HTTPS 地址：`https://localhost:5001`

### 其他用戶加入

同一網路內的其他用戶可以通過您的 IP 地址加入：
- 找到您的本機 IP 地址（例如：192.168.1.100）
- 其他用戶在瀏覽器中輸入：`http://192.168.1.100:5000`

## IIS 部署指南

如果您希望將應用程式部署到 IIS 以獲得更穩定的服務，請按照以下步驟操作：

### 1. 系統需求

- Windows 10/11 或 Windows Server
- IIS 10.0 或更高版本
- .NET 8.0 Hosting Bundle

### 2. 啟用 IIS 功能

#### 透過 PowerShell（推薦）
以**系統管理員身分**執行 PowerShell：

```powershell
# 啟用 IIS 和相關功能
Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole, IIS-WebServer, IIS-CommonHttpFeatures, IIS-HttpErrors, IIS-HttpRedirect, IIS-ApplicationDevelopment, IIS-NetFxExtensibility45, IIS-HealthAndDiagnostics, IIS-HttpLogging, IIS-Security, IIS-RequestFiltering, IIS-Performance, IIS-WebServerManagementTools, IIS-ManagementConsole, IIS-IIS6ManagementCompatibility, IIS-Metabase, IIS-ASPNET45

# 重新啟動（可選）
Restart-Computer
```

#### 透過控制台
1. 開啟「控制台」→「程式和功能」→「開啟或關閉 Windows 功能」
2. 勾選「Internet Information Services」
3. 展開並勾選以下項目：
   - Web Management Tools → IIS Management Console
   - World Wide Web Services → Application Development Features → ASP.NET 4.8
   - World Wide Web Services → Common HTTP Features（全部勾選）
   - World Wide Web Services → Security → Request Filtering

### 3. 安裝 .NET Hosting Bundle

1. 下載 .NET 8.0 Hosting Bundle：
   ```
   https://dotnet.microsoft.com/download/dotnet/8.0
   ```
2. 執行安裝程式並重新啟動 IIS：
   ```cmd
   iisreset
   ```

### 4. 建置應用程式

在專案資料夾中執行：

```bash
# 發行應用程式
dotnet publish -c Release -o ./publish

# 或使用指定的執行環境
dotnet publish -c Release -r win-x64 --self-contained false -o ./publish
```

### 5. 配置 IIS 站台

#### 手動配置
1. 開啟「IIS 管理員」
2. 右鍵點擊「Default Web Site」→「新增應用程式」
3. 設定應用程式：
   - **別名**：`balance-game`
   - **實體路徑**：指向 `publish` 資料夾
4. 設定應用程式集區：
   - **名稱**：`BalanceGamePool`
   - **.NET CLR 版本**：`沒有 Managed 程式碼`
   - **Managed 管線模式**：`整合式`

#### 自動化部署腳本
使用專案中的 PowerShell 腳本：

```powershell
# 執行自動部署腳本
.\deploy_to_iis.ps1
```

或者兼容版本：
```powershell
.\deploy_to_iis_compatible.ps1
```

### 6. 設定權限

執行權限修正腳本：
```powershell
# 以系統管理員身分執行
.\fix_iis_permissions.ps1
```

或手動設定：
1. 右鍵點擊發布資料夾 → 內容 → 安全性
2. 新增 `IIS_IUSRS` 和 `IUSR` 使用者
3. 授予「讀取和執行」、「列出資料夾內容」、「讀取」權限

### 7. 配置防火牆

執行防火牆設定腳本：
```powershell
# 以系統管理員身分執行
.\setup_firewall.ps1
```

或手動設定：
1. 開啟「Windows Defender 防火牆」
2. 點擊「允許應用程式或功能通過防火牆」
3. 勾選「World Wide Web 服務 (HTTP)」和「World Wide Web 服務 (HTTPS)」

### 8. 測試部署

1. **本機測試**：
   ```
   http://localhost/balance-game
   ```

2. **區網測試**：
   ```
   http://[您的IP地址]/balance-game
   ```

3. **檢查應用程式狀態**：
   - 開啟 IIS 管理員
   - 檢查應用程式集區是否正在執行
   - 查看事件檢視器中的錯誤訊息

### 9. 區網和外網存取設定

#### 區網存取
1. 確認網路設定檔為「私人」
2. 開啟網路探索：
   ```powershell
   # 開啟網路探索
   netsh advfirewall firewall set rule group="Network Discovery" new enable=Yes
   netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=Yes
   ```

#### 外網存取（可選）
1. 在路由器中設定連接埠轉發：
   - 外部連接埠：80 → 內部連接埠：80
   - 內部 IP：您的電腦 IP
2. 確認 ISP 沒有封鍋 80 連接埠

### 10. 常見問題排除

#### 500.19 錯誤（web.config 無法讀取）
```powershell
# 重新設定權限
icacls "C:\path\to\your\app" /grant "IIS_IUSRS:(OI)(CI)RX" /T
icacls "C:\path\to\your\app\web.config" /grant "IIS_IUSRS:RX"
```

#### 502.5 錯誤（進程失敗）
1. 檢查 .NET Hosting Bundle 是否正確安裝
2. 確認應用程式集區設定正確
3. 查看 Windows 事件檢視器的詳細錯誤

#### SignalR 連接問題
確認 web.config 包含 WebSocket 支援：
```xml
<system.webServer>
  <webSocket enabled="false" />
</system.webServer>
```

### 11. 效能優化

1. **啟用壓縮**：
   - 在 IIS 中啟用動態和靜態內容壓縮
2. **設定快取**：
   - 為靜態資源設定適當的快取標頭
3. **監控效能**：
   - 使用 IIS 日誌分析工具
   - 監控應用程式集區的記憶體使用量

完成以上步驟後，您的遊戲就可以透過 IIS 穩定運行，並支援多使用者同時存取！

## 使用說明

1. **註冊/登入** - 創建簡單的用戶帳戶
2. **創建房間** - 房主創建遊戲房間，獲得 5 位數房間號碼
3. **加入房間** - 其他玩家輸入房間號碼加入
4. **準備遊戲** - 所有玩家點擊"準備"按鈕
5. **開始遊戲** - 房主點擊"開始遊戲"
6. **提交數字** - 在時間限制內選擇並提交數字
7. **查看結果** - 系統自動計算並顯示結果
8. **下一輪** - 繼續進行直到決出最終勝利者

## 房間設定

房主可以調整以下設定：
- **回合時間**：30-600 秒
- **聊天功能**：開啟/關閉聊天室

## 資料夾結構

```
├── Controllers/              # MVC 控制器
├── Data/                    # Entity Framework 資料庫上下文
├── Hubs/                    # SignalR Hub
├── Models/                  # 資料模型
├── Services/                # 遊戲邏輯服務
├── Views/                   # MVC 視圖
├── wwwroot/                 # 靜態資源
├── Properties/              # 專案屬性和啟動設定
├── appsettings.json         # 應用程式配置
├── web.config               # IIS 配置檔案
├── deploy_to_iis.ps1        # IIS 自動部署腳本
├── deploy_to_iis_compatible.ps1  # IIS 兼容部署腳本
├── fix_iis_permissions.ps1  # IIS 權限修正腳本
├── setup_firewall.ps1       # 防火牆設定腳本
└── IIS_Deployment_Guide.md  # 詳細 IIS 部署指南
```

## 問題排除

### 開發環境問題

#### 連接問題
- 確認防火牆設定允許 5000/5001 端口
- 檢查網路連接是否正常

#### 資料庫問題
- 刪除 `balance_game.db` 檔案並重新運行應用程式
- 確認 SQLite 套件已正確安裝

#### SignalR 連接失敗
- 檢查瀏覽器是否支援 WebSocket
- 嘗試重新整理頁面

### IIS 部署問題

#### 500.19 內部伺服器錯誤
**原因**：web.config 權限不足或格式錯誤
**解決方法**：
```powershell
# 重新設定 web.config 權限
icacls "C:\path\to\your\app\web.config" /grant "IIS_IUSRS:RX"
```

#### 502.5 進程失敗
**原因**：.NET Hosting Bundle 未安裝或應用程式集區設定錯誤
**解決方法**：
1. 重新安裝 .NET 8.0 Hosting Bundle
2. 設定應用程式集區為「沒有 Managed 程式碼」

#### 404 找不到頁面
**原因**：應用程式路徑設定錯誤
**解決方法**：確認 IIS 中的實體路徑指向正確的 publish 資料夾

#### SignalR 無法連接（IIS）
**原因**：WebSocket 設定問題
**解決方法**：檢查 web.config 中的 WebSocket 設定

#### 其他用戶無法存取
**原因**：防火牆或網路設定問題
**解決方法**：
1. 執行 `setup_firewall.ps1` 腳本
2. 確認網路設定檔為「私人」
3. 檢查路由器設定（如需外網存取）

## 開發資訊

此專案使用輕量級架構，適合本機部署和小規模多人遊戲。所有遊戲狀態都儲存在記憶體中，重啟服務會清除所有進行中的遊戲房間。

## 授權

此專案僅供學習和個人使用。
