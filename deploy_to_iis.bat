@echo off
echo ===============================================
echo        Balance Game IIS 快速部署腳本
echo ===============================================
echo.

REM 檢查是否以管理員身分執行
net session >nul 2>&1
if %errorLevel% == 0 (
    echo [OK] 已以管理員身分執行
) else (
    echo [錯誤] 請以管理員身分執行此腳本
    pause
    exit /b 1
)

echo.
echo 1. 建立發布版本...
dotnet publish -c Release -o ./publish --self-contained false

if %errorLevel% neq 0 (
    echo [錯誤] 發布失敗
    pause
    exit /b 1
)

echo [OK] 發布成功
echo.

set /p SITE_NAME="請輸入網站名稱 (預設: BalanceGame): "
if "%SITE_NAME%"=="" set SITE_NAME=BalanceGame

set /p PORT="請輸入連接埠 (預設: 8080): "
if "%PORT%"=="" set PORT=8080

set /p POOL_NAME="請輸入應用程式集區名稱 (預設: BalanceGamePool): "
if "%POOL_NAME%"=="" set POOL_NAME=BalanceGamePool

set PHYSICAL_PATH=%~dp0publish

echo.
echo 2. 設定 IIS...
echo 網站名稱: %SITE_NAME%
echo 連接埠: %PORT%
echo 應用程式集區: %POOL_NAME%
echo 實體路徑: %PHYSICAL_PATH%
echo.

REM 建立應用程式集區
echo 建立應用程式集區...
%systemroot%\system32\inetsrv\appcmd.exe add apppool /name:"%POOL_NAME%" /managedRuntimeVersion:"" 2>nul
if %errorLevel% == 0 (
    echo [OK] 應用程式集區已建立
) else (
    echo [警告] 應用程式集區可能已存在
)

REM 設定應用程式集區屬性
%systemroot%\system32\inetsrv\appcmd.exe set apppool "%POOL_NAME%" /processModel.identityType:ApplicationPoolIdentity
%systemroot%\system32\inetsrv\appcmd.exe set apppool "%POOL_NAME%" /enable32BitAppOnWin64:false

REM 建立網站
echo 建立網站...
%systemroot%\system32\inetsrv\appcmd.exe add site /name:"%SITE_NAME%" /physicalPath:"%PHYSICAL_PATH%" /bindings:http/*:%PORT%: 2>nul
if %errorLevel% == 0 (
    echo [OK] 網站已建立
) else (
    echo [警告] 網站可能已存在，嘗試更新設定...
    %systemroot%\system32\inetsrv\appcmd.exe set site "%SITE_NAME%" /physicalPath:"%PHYSICAL_PATH%"
    %systemroot%\system32\inetsrv\appcmd.exe set site "%SITE_NAME%" /bindings:http/*:%PORT%:
)

REM 設定應用程式集區
%systemroot%\system32\inetsrv\appcmd.exe set app "%SITE_NAME%/" /applicationPool:"%POOL_NAME%"

echo.
echo 3. 設定權限...
icacls "%PHYSICAL_PATH%" /grant "IIS AppPool\%POOL_NAME%":(OI)(CI)RX /T

echo.
echo 4. 設定防火牆...
netsh advfirewall firewall add rule name="BalanceGame HTTP Port %PORT%" dir=in action=allow protocol=TCP localport=%PORT% 2>nul
if %errorLevel% == 0 (
    echo [OK] 防火牆規則已新增
) else (
    echo [警告] 防火牆規則可能已存在
)

echo.
echo 5. 啟動網站和應用程式集區...
%systemroot%\system32\inetsrv\appcmd.exe start apppool "%POOL_NAME%"
%systemroot%\system32\inetsrv\appcmd.exe start site "%SITE_NAME%"

echo.
echo ===============================================
echo              部署完成！
echo ===============================================
echo.
echo 網站位址: http://localhost:%PORT%
echo 或: http://您的IP位址:%PORT%
echo.
echo 如需測試，請開啟瀏覽器造訪上述網址。
echo.

REM 取得本機 IP
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
    for /f "tokens=1" %%b in ("%%a") do (
        echo 本機 IP: http://%%b:%PORT%
    )
)

echo.
pause
