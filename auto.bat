@echo off
setlocal enabledelayedexpansion

set SOURCE_DIR=C:\ps1_sample
set TOOL_DIR=C:\SandboxTools
set WSB_PATH=C:\config.wsb
set PAYLOAD_FLAG=%TOOL_DIR%\active_payload.txt

set /a index=0

for %%f in (%SOURCE_DIR%\*.ps1) do (
    set /a index+=1
    set "PAYLOAD_NAME=malware_!index!.ps1"
    echo Processing %%~nxf as !PAYLOAD_NAME!

    copy "%%f" "%TOOL_DIR%\!PAYLOAD_NAME!" /Y > nul
    echo !PAYLOAD_NAME! > "%PAYLOAD_FLAG%"

    echo Launching Windows Sandbox for !PAYLOAD_NAME!...
    "C:\Windows\System32\WindowsSandbox.exe" "%WSB_PATH%"

    echo Waiting for Sandbox to close...
    :waitloop
    timeout /t 5 > nul
    tasklist | find /i "WindowsSandboxContainer.exe" > nul
    if %errorlevel%==0 goto waitloop

    echo Completed analysis for !PAYLOAD_NAME!
    echo.
)

echo Finished analyzing %index% sample.
pause


