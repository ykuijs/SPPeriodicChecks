$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '10'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'HealthAnalyzerIssues'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Health Analyzer issues'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check10_HealthAnalyzerIssues()
{
    $sb = {
        Write-Log "Starting Check 10: Health Analyzer Issues check"
        $results.Check10 = ""

        $caWebapp = Get-SPwebapplication -IncludeCentralAdministration | Where-Object -FilterScript { $_.IsAdministrationWebApplication }
        $listName = "Review Problems and Solutions"
        $spSourceWeb = Get-SPWeb $caWebapp.url
        $spSourceList = $spSourceWeb.Lists[$listName]
        $spSourceItems = $spSourceList.GetItems() | Where-Object -FilterScript { $_['Severity'] -ne "4 - Success" }

        if ($spSourceItems.Count -gt 0)
        {
            Write-Log "  Check Failed"
            $results.Check10 = $results.Check10 + "Health Analyzer Issues Check: $($spSourceItems.Count) rule(s) failed`r`n"
        }
        else
        {
            Write-Log "  Check Passed"
            $results.Check10 = $results.Check10 + "Health Analyzer Issues Check: Passed`r`n"
        }

        Write-Log "Completed Check 10: Health Analyzer Issues check"
    }

    return $sb.ToString()
}
