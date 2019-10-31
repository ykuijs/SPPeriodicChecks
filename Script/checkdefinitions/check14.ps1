$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '14'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'FailedTimerJobs'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Failed Timer Jobs overview'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check14_FailedTimerJobs() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 14: Failed Timer Jobs check"
$results.Check14 = ""

$errorCount = 0
$startTime  = (Get-Date).AddDays(-1)

$farm = Get-SPFarm
$timerService = $farm.TimerService
$failedJobs = $timerService.JobHistoryEntries | Where-Object -FilterScript {
                    $_.Status -eq "Failed" -and $_.StartTime -gt $startTime
              }

if ($failedJobs.Count -gt 0)
{
    WriteLog "  Check Failed"
    $results.Check14 = $results.Check14 + "Failed Timer Jobs Check: $($failedJobs.Count) job(s) failed`r`n"
}
else
{
    WriteLog "  Check Passed"
    $results.Check14 = $results.Check14 + "Failed Timer Jobs Check: Passed`r`n"
}

WriteLog "Completed Check 14: Failed Timer Jobs check"
})

    return $sb.ToString()
}
