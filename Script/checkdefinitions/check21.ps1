$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '21'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'GathererLogs'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Search Gatherer logs'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check21_GathererLogs() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 21: Search Gatherer Log check"
$results.Check21 = ""
$logMaxRows      = 10000
$contentSourceID = -1 # All content sources
$errorID         = -1 # All errors
$endDate         = Get-Date
$startDate       = $endDate.AddDays(-3)

$ssas = Get-SPEnterpriseSearchServiceApplication

if ($null -eq $ssas)
{
    # No Search Service Applications found
    WriteLog "  Check not possible: No Search Service applications found. Either because none exist or an access issue occurred."
    $results.Check21 = $results.Check21 + "Search Gatherer Check: No Search Service applications found.`r`n"
    $results.Check21 = $results.Check21 + "`tEither because none exist or an access issue occurred.`r`n"
}
else
{
    # One or more Search Service Applications found
    foreach ($ssa in $ssas)
    {
        $logs = New-Object Microsoft.Office.Server.Search.Administration.CrawlLog $ssa

        $warnings = $logs.GetCrawledUrls($true,$logMaxRows,"",$false,$contentSourceID,1,$errorID,$startDate,$endDate)
        $errors = $logs.GetCrawledUrls($true,$logMaxRows,"",$false,$contentSourceID,2,$errorID,$startDate,$endDate)
        $topErrors = $logs.GetCrawledUrls($true,$logMaxRows,"",$false,$contentSourceID,4,$errorID,$startDate,$endDate)

        if (($errors.Rows[0]["DocumentCount"] -gt 0) -or `
            ($topErrors.Rows[0]["DocumentCount"] -gt 0) -or `
            ($warnings.Rows[0]["DocumentCount"]))
        {
            WriteLog "  Check Failed"
            $results.Check21 = $results.Check21 + "Search Gatherer Check: $($ssa.name) - Failed`r`n"
            $results.Check21 = $results.Check21 + "`tWarnings: $($warnings.Rows[0]["DocumentCount"])`r`n"
            $results.Check21 = $results.Check21 + "`tErrors: $($errors.Rows[0]["DocumentCount"])`r`n"
            $results.Check21 = $results.Check21 + "`tTop Level Errors: $($topErrors.Rows[0]["DocumentCount"])`r`n"
        }
        else
        {
            WriteLog "  Check Passed"
            $results.Check21 = $results.Check21 + "Search Gatherer Check: $($ssa.name) - Passed`r`n"
        }
    }
}

WriteLog "Completed Check 21: Search Gatherer Log check"
})

    return $sb.ToString()
}
