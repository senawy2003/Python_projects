@echo off
title USB AutoBackup - Uninstall

echo Stopping USB AutoBackup...
taskkill /f /im pythonw.exe >nul 2>&1

echo Removing startup shortcut...
del "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\USBAutoBackup.lnk" >nul 2>&1

echo Done. Config and logs kept at: %APPDATA%\USBAutoBackup\
echo (Delete that folder manually for a full clean uninstall.)
echo.
pause
