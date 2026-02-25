$cycles = @(
    @{ Name = "Machine Policy Retrieval & Evaluation Cycle";    ScheduleID = "{00000000-0000-0000-0000-000000000021}" },
    @{ Name = "User Policy Retrieval & Evaluation Cycle";       ScheduleID = "{00000000-0000-0000-0000-000000000026}" },
    @{ Name = "Application Deployment Evaluation Cycle";        ScheduleID = "{00000000-0000-0000-0000-000000000121}" },
    @{ Name = "Discovery Data Collection Cycle";                ScheduleID = "{00000000-0000-0000-0000-000000000003}" },
    @{ Name = "File Collection Cycle";                          ScheduleID = "{00000000-0000-0000-0000-000000000010}" },
    @{ Name = "Hardware Inventory Cycle";                       ScheduleID = "{00000000-0000-0000-0000-000000000001}" },
    @{ Name = "Machine Policy Evaluation Cycle";                ScheduleID = "{00000000-0000-0000-0000-000000000022}" },
    @{ Name = "Software Inventory Cycle";                       ScheduleID = "{00000000-0000-0000-0000-000000000002}" },
    @{ Name = "Software Metering Usage Report Cycle";           ScheduleID = "{00000000-0000-0000-0000-000000000031}" },
    @{ Name = "Software Updates Deployment Evaluation Cycle";   ScheduleID = "{00000000-0000-0000-0000-000000000108}" },
    @{ Name = "Software Updates Scan Cycle";                    ScheduleID = "{00000000-0000-0000-0000-000000000113}" },
    @{ Name = "State Message Refresh";                          ScheduleID = "{00000000-0000-0000-0000-000000000111}" },
    @{ Name = "User Policy Evaluation Cycle";                   ScheduleID = "{00000000-0000-0000-0000-000000000027}" },
    @{ Name = "Windows Installer Source List Update Cycle";     ScheduleID = "{00000000-0000-0000-0000-000000000032}" }
)

$total     = $cycles.Count
$completed = 0
$results   = @()

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "  SCCM Configuration Manager Cycles   " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

foreach ($cycle in $cycles) {
    $completed++
    $percent = [math]::Round(($completed / $total) * 100)

    Write-Progress `
        -Activity "Running SCCM Cycles" `
        -Status ("[$completed/$total] " + $cycle.Name) `
        -PercentComplete $percent

    Write-Host ("  [{0,2}/{1}] {2}" -f $completed, $total, $cycle.Name) -NoNewline

    try {
        $client = [wmiclass]"\\.\root\ccm:SMS_Client"
        $client.TriggerSchedule($cycle.ScheduleID) | Out-Null

        Start-Sleep -Seconds 5

        Write-Host "  [OK]" -ForegroundColor Green
        $results += [PSCustomObject]@{ Cycle = $cycle.Name; Status = "Success" }
    }
    catch {
        Write-Host "  [FAILED] $($_.Exception.Message)" -ForegroundColor Red
        $results += [PSCustomObject]@{ Cycle = $cycle.Name; Status = "Failed: $($_.Exception.Message)" }
    }
}

Write-Progress -Activity "Running SCCM Cycles" -Completed

Write-Host ""
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "               Summary                 " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

$success = ($results | Where-Object { $_.Status -eq "Success" }).Count
$failed  = ($results | Where-Object { $_.Status -ne "Success" }).Count

Write-Host ""
Write-Host "  Total  : $total"
Write-Host "  Success: $success" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed : $failed" -ForegroundColor Red
    Write-Host ""
    Write-Host "  Failed cycles:" -ForegroundColor Red
    $results | Where-Object { $_.Status -ne "Success" } | ForEach-Object {
        Write-Host "    - $($_.Cycle): $($_.Status)" -ForegroundColor Red
    }
}
Write-Host ""
