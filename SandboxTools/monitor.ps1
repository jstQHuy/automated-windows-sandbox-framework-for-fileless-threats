# 0. Setup paths
$desktop     = [Environment]::GetFolderPath("Desktop")
$debugLog    = Join-Path $desktop "debug_log.txt"
# Procmon & config path
$pml         = Join-Path $desktop "procmon_capture.pml"
$csvOut      = Join-Path $desktop "procmon_capture.csv"
$procmonLog  = Join-Path $desktop "procmon_run.log"
$procmon     = "$env:USERPROFILE\Desktop\SandboxTools\ProcMon\Procmon64.exe"
$pmc         = "$env:USERPROFILE\Desktop\SandboxTools\ProcMon\config.pmc"
# Dump Process log path
$txtLog      = Join-Path $desktop "new_processes_after_test.txt"
$csvProcLog  = Join-Path $desktop "new_processes_after_test.csv"
$pwshLog     = Join-Path $desktop "powershell_process.csv"
#Payload path
$payloadPath = "$PSScriptRoot\malware_test.ps1"


# 1. Bypass Procmon EULA
New-Item -Path "HKCU:\Software\Sysinternals\Procmon" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\Sysinternals\Procmon" -Name 'EulaAccepted' -Value 1

"[$(Get-Date)] === START ===" | Out-File $debugLog -Encoding UTF8

# 2. Take process snapshot before test
$before = Get-CimInstance Win32_Process | Select-Object ProcessId
$beforeIds = $before.ProcessId

# 3. Start Procmon in background (20s) — NON-blocking
Start-Process -FilePath $procmon `
    -ArgumentList "/AcceptEula", "/Quiet", "/LoadConfig", "`"$pmc`"", "/Backingfile", "`"$pml`"", "/Runtime", "20", "/Minimized"
    -Wait

# 4. Launch malware sample
Start-Process powershell.exe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -File `"$payloadPath`""

# 5. Monitor and log new processes
$seen = @{}
$collected = @()
$ignoreList = @("svchost.exe", "ctfmon.exe", "dllhost.exe", "smartscreen.exe", "SearchApp.exe", "RuntimeBroker.exe")

for ($i = 1; $i -le 20; $i++) {
    Start-Sleep -Seconds 1
    $snapshot = Get-CimInstance Win32_Process |
        Select-Object ProcessId, ParentProcessId, Name, CommandLine, CreationDate

    $newProcs = $snapshot | Where-Object {
        ($beforeIds -notcontains $_.ProcessId) -and (-not $seen.ContainsKey($_.ProcessId))
    }

    foreach ($proc in $newProcs) {
        $seen[$proc.ProcessId] = $true
        $collected += $proc
        $line = "[{0}] PID={1} PPID={2} NAME={3}" -f (Get-Date), $proc.ProcessId, $proc.ParentProcessId, $proc.Name
        Add-Content -Path $debugLog -Value $line
    }
}

# 6. Write filtered process list to CSV and TXT
$filteredProcs = $collected | Where-Object { $ignoreList -notcontains $_.Name }

$filteredProcs | Sort-Object ProcessId | ForEach-Object {
    "{0,-6} {1,-6} {2,-20} {3}" -f $_.ProcessId, $_.ParentProcessId, $_.Name, $_.CommandLine
} | Set-Content $txtLog

$filteredProcs | Sort-Object ProcessId | Export-Csv $csvProcLog -NoTypeInformation -Encoding UTF8

# 7. Save PowerShell-related processes separately
Get-CimInstance Win32_Process |
    Where-Object { $_.Name -like "powershell*" } |
    Sort-Object ProcessId |
    Export-Csv $pwshLog -NoTypeInformation -Encoding UTF8

# 8. Wait a bit longer to allow Procmon to flush its log
Start-Sleep -Seconds 5

# 9. Convert PML log to CSV
Start-Process -FilePath $procmon `
    -ArgumentList "/OpenLog", "`"$pml`"", "/SaveAs", "`"$csvOut`"" `
    -Wait

# DONE
Add-Content $procmonLog " CSV exported at $csvOut"
"[$(Get-Date)] DONE" | Out-File $debugLog -Append
