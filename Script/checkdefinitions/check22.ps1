$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '22'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'QuotaCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Site collection quota check'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check22_QuotaCheck()
{
    $sb = {
        Write-Log "Starting Check 22: Site collection quota check"
        $results.Check22 = ""

        $errorCount = 0
        $erroredSites = ""

        $templates = [Microsoft.SharePoint.Administration.SPWebService]::ContentService.QuotaTemplates
        $siteFillPercentageCheck = 90

        $webapplications = Get-SPWebApplication -ErrorAction SilentlyContinue

        if ($null -eq $webapplications)
        {
            # No Web Applications found
            Write-Log "  Check not possible: No web applications found. Either because none exist or an access issue occurred."
            $results.Check22 = "Quota Check: Skipped. No web applications found.`r`n"
        }
        else
        {
            # One or more Web Applications found
            foreach ($webapplication in $webapplications)
            {
                $sites = Get-SPSite -Limit All -WebApplication $webapplication

                foreach ($site in $sites)
                {
                    $url = $site.URL
                    $site.RecalculateStorageMetrics()

                    $quotaTemplate = $templates | Where-Object -FilterScript { $_.QuotaId -eq $site.Quota.QuotaID }

                    if ($null -ne $quotaTemplate)
                    {
                        $siteFillPercentage = [math]::Round(($site.Usage.Storage / 1MB) * 100 / ($site.Quota.StorageMaximumLevel / 1MB))

                        if ($siteFillPercentage -ge $siteFillPercentageCheck)
                        {
                            $errorCount++
                            $erroredSites += "`tSite filled for $siteFillPercentageCheck%: $url)`r`n"
                        }
                    }
                    else
                    {
                        $errorCount++
                        $erroredSites += "`tNo Quota template for: $url`r`n"
                    }

                    $site.Dispose()
                }
            }

            if ($errorCount -ne 0)
            {
                Write-Log "  Check Failed"
                $results.Check22 = "Quota Check: Failed`r`n"
                $results.Check22 += $erroredSites
            }
            else
            {
                Write-Log "  Check Passed"
                $results.Check22 = "Quota Check: Passed`r`n"
            }
        }
        Write-Log "Completed Check 22: Site collection quota check"
    }

    return $sb.ToString()
}
