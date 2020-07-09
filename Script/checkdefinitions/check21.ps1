$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '21'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'GathererLogs'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Search Gatherer logs'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check21_GathererLogs()
{
    $sb = {
        Write-Log "Starting Check 21: Search Gatherer Log check"
        $results.Check21 = ""
        $logMaxRows = 10000
        $contentSourceID = -1 # All content sources
        $errorID = -1 # All errors
        $endDate = Get-Date
        $startDate = $endDate.AddDays(-3)

        $warningsThresholdPercentage = 15
        $errorsThresholdPercentage = 8
        $topErrorsThreshold = 0

        $ssas = Get-SPEnterpriseSearchServiceApplication

        if ($null -eq $ssas)
        {
            # No Search Service Applications found
            Write-Log "  Check not possible: No Search Service applications found. Either because none exist or an access issue occurred."
            $results.Check21 = $results.Check21 + "Search Gatherer Check: No Search Service applications found.`r`n"
            $results.Check21 = $results.Check21 + "`tEither because none exist or an access issue occurred.`r`n"
        }
        else
        {
            # One or more Search Service Applications found
            foreach ($ssa in $ssas)
            {
                $logs = New-Object Microsoft.Office.Server.Search.Administration.CrawlLog $ssa

                # Allowed statuses: https://docs.microsoft.com/en-us/previous-versions/office/sharepoint-server/jj264492(v%3Doffice.15)
                $successes = ($logs.GetCrawledUrls($true, $logMaxRows, "", $false, $contentSourceID, 0, $errorID, $startDate, $endDate)).DocumentCount
                $warnings = ($logs.GetCrawledUrls($true, $logMaxRows, "", $false, $contentSourceID, 1, $errorID, $startDate, $endDate)).DocumentCount
                $errors = ($logs.GetCrawledUrls($true, $logMaxRows, "", $false, $contentSourceID, 2, $errorID, $startDate, $endDate)).DocumentCount
                $topErrors = ($logs.GetCrawledUrls($true, $logMaxRows, "", $false, $contentSourceID, 4, $errorID, $startDate, $endDate)).DocumentCount

                $warningsThreshold = [math]::Round(($successes * $warningsThresholdPercentage) / 100)
                $errorsThreshold = [math]::Round(($successes * $errorsThresholdPercentage) / 100)

                if (($warnings -gt $warningsThreshold) -or `
                    ($errors -gt $errorsThreshold) -or `
                    ($topErrors -gt $topErrorsThreshold))
                {
                    Write-Log "  Check Failed"
                    $results.Check21 = $results.Check21 + "Search Gatherer Check: $($ssa.name) - Failed`r`n"
                    $results.Check21 = $results.Check21 + "`tSuccesses: $($successes)`r`n"
                    $results.Check21 = $results.Check21 + "`tWarnings: $($warnings)`r`n"
                    $results.Check21 = $results.Check21 + "`tErrors: $($errors)`r`n"
                    $results.Check21 = $results.Check21 + "`tTop Level Errors: $($topErrors)`r`n"
                }
                else
                {
                    Write-Log "  Check Passed"
                    $results.Check21 = $results.Check21 + "Search Gatherer Check: $($ssa.name) - Passed`r`n"
                }
            }
        }

        Write-Log "Completed Check 21: Search Gatherer Log check"
    }

    return $sb.ToString()
}
