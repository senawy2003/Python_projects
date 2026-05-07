@echo off
:: USB AutoBackup - Installer & Launcher

title USB AutoBackup Setup

echo.
echo  +--------------------------------------+
echo  ^|        USB AutoBackup Setup          ^|
echo  +--------------------------------------+
echo.

:: Check Python
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python not found. Please install Python 3.10+ from https://python.org
    pause
    exit /b 1
)

echo Python found:
python --version
echo.

echo [1/3] Installing dependencies...
pip install -r "%~dp0requirements.txt" --quiet
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install dependencies.
    pause
    exit /b 1
)
echo Dependencies installed OK.
echo.

echo [2/3] Creating startup shortcut...
set SCRIPT_DIR=%~dp0
set VBS_TEMP=%TEMP%\make_shortcut.vbs

echo Set oWS = WScript.CreateObject("WScript.Shell") > "%VBS_TEMP%"
echo sLinkFile = "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\USBAutoBackup.lnk" >> "%VBS_TEMP%"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%VBS_TEMP%"
echo oLink.TargetPath = "pythonw.exe" >> "%VBS_TEMP%"
echo oLink.Arguments = """%SCRIPT_DIR%usb_backup_app.py""" >> "%VBS_TEMP%"
echo oLink.WorkingDirectory = "%SCRIPT_DIR%" >> "%VBS_TEMP%"
echo oLink.Description = "USB AutoBackup" >> "%VBS_TEMP%"
echo oLink.Save >> "%VBS_TEMP%"
cscript //nologo "%VBS_TEMP%"
del "%VBS_TEMP%"
echo Startup shortcut created OK.
echo.

echo [3/3] Launching USB AutoBackup...
start "" pythonw.exe "%SCRIPT_DIR%usb_backup_app.py"

echo.
echo  USB AutoBackup is now running in your system tray.
echo  It will start automatically on next login too.
echo.
echo  Look for the teal USB icon in the bottom-right system tray.
echo.
pause
