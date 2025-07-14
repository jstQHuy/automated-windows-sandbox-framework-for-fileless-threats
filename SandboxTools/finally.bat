@echo off
setlocal enableextensions

:: Setup Path
set LOG=%USERPROFILE%\Desktop\debug_log.txt
set SYSMON_DIR=%USERPROFILE%\Desktop\SandboxTools\Sysmon
set SYSMON_BIN=%SYSMON_DIR%\Sysmon64.exe
set SYSMON_CONFIG=%SYSMON_DIR%\sysmon_config.xml
set SYSMON_EVTX=%USERPROFILE%\Desktop\sysmon_log.evtx
set SYSMON_CSV=%USERPROFILE%\Desktop\sysmon_log.csv

echo [%DATE% %TIME%] --- START--- > "%LOG%"

:: #1. Export 1st registry 
reg export "HKEY_LOCAL_MACHINE" %USERPROFILE%\Desktop\HKLM_before.reg /y >> "%LOG%" 2>&1
reg export "HKEY_CURRENT_USER" %USERPROFILE%\Desktop\HKCU_before.reg /y >> "%LOG%" 2>&1
reg export "HKEY_USERS"        %USERPROFILE%\Desktop\HKU_before.reg  /y >> "%LOG%" 2>&1
reg export "HKEY_CLASSES_ROOT" %USERPROFILE%\Desktop\HKCR_before.reg /y >> "%LOG%" 2>&1

:: #2. Setup Sysmon
"%SYSMON_BIN%" -accepteula -i "%SYSMON_CONFIG%" >> "%LOG%" 2>&1

:: #3. Run monitor.ps1 
powershell -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "%USERPROFILE%\Desktop\SandboxTools\monitor.ps1" >> "%LOG%" 2>&1

:: #4. Export Sysmon log
wevtutil epl "Microsoft-Windows-Sysmon/Operational" "%SYSMON_EVTX%" >> "%LOG%" 2>&1
powershell.exe -NoProfile -Command "Get-WinEvent -Path '%SYSMON_EVTX%' | Select-Object TimeCreated, Id, ProviderName, Message | Export-Csv -Path '%SYSMON_CSV%' -NoTypeInformation -Encoding UTF8" >> "%LOG%" 2>&1

:: #5. Wait 5s log
timeout /t 5 > nul

:: #6. Export 2nd registry
reg export "HKEY_LOCAL_MACHINE" %USERPROFILE%\Desktop\HKLM_after.reg /y >> "%LOG%" 2>&1
reg export "HKEY_CURRENT_USER" %USERPROFILE%\Desktop\HKCU_after.reg /y >> "%LOG%" 2>&1
reg export "HKEY_USERS"        %USERPROFILE%\Desktop\HKU_after.reg  /y >> "%LOG%" 2>&1
reg export "HKEY_CLASSES_ROOT" %USERPROFILE%\Desktop\HKCR_after.reg /y >> "%LOG%" 2>&1

:: #7. Compare registry
start /wait "" cmd /c ""%USERPROFILE%\Desktop\SandboxTools\regdiff-4.3\regdiff.exe" "%USERPROFILE%\Desktop\HKLM_before.reg" "%USERPROFILE%\Desktop\HKLM_after.reg" > "%USERPROFILE%\Desktop\HKLM_diff.txt""
start /wait "" cmd /c ""%USERPROFILE%\Desktop\SandboxTools\regdiff-4.3\regdiff.exe" "%USERPROFILE%\Desktop\HKCU_before.reg" "%USERPROFILE%\Desktop\HKCU_after.reg" > "%USERPROFILE%\Desktop\HKCU_diff.txt""
start /wait "" cmd /c ""%USERPROFILE%\Desktop\SandboxTools\regdiff-4.3\regdiff.exe" "%USERPROFILE%\Desktop\HKU_before.reg"  "%USERPROFILE%\Desktop\HKU_after.reg"  > "%USERPROFILE%\Desktop\HKU_diff.txt""
start /wait "" cmd /c ""%USERPROFILE%\Desktop\SandboxTools\regdiff-4.3\regdiff.exe" "%USERPROFILE%\Desktop\HKCR_before.reg" "%USERPROFILE%\Desktop\HKCR_after.reg" > "%USERPROFILE%\Desktop\HKCR_diff.txt""

:: #8. Merge registry diff
type %USERPROFILE%\Desktop\HKLM_diff.txt %USERPROFILE%\Desktop\HKCU_diff.txt %USERPROFILE%\Desktop\HKU_diff.txt %USERPROFILE%\Desktop\HKCR_diff.txt > %USERPROFILE%\Desktop\ALL_registry_differences.txt

:: #9. END
echo DONE. >> "%LOG%"
pause
endlocal
