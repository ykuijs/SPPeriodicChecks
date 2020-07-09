$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '16'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ContentDBSizeInSiteCol'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Content Database size'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check16_ContentDBSizeInSiteCol()
{
    $excludedcontentdbs = Read-Configuration (Join-Path -Path $configPath -ChildPath 'contentdbexclusions.txt')

    $sbTemplate = {
        Write-Log "Starting Check 16: Content Database Size check"
        $results.Check16 = ""

        $siteThreshold = 100
        $excludedCDBs = @("<REPLACE_EXCL_CDB>")

        $errorCount = 0
        $errorDB = ""

        foreach ($cdb in Get-SPContentDatabase)
        {
            if ($cdb.Name -notmatch ($excludedCDBs -join "|"))
            {
                $cdbSize = $cdb.MaximumSiteCount - $cdb.CurrentSiteCount
                if (($cdbSize -lt $siteThreshold) -and ($cdbSize -ne 0))
                {
                    $errorCount++
                    if ($errorDB -ne "")
                    {
                        $errorDB += ", "
                    }
                    $errorDB += "$($cdb.Name) (Free: $cdbSize)"
                }
            }
        }

        if ($errorCount -gt 0)
        {
            Write-Log "  Check Failed"
            $results.Check16 = $results.Check16 + "Database Size Check: $errorCount database(s) failed`r`n"
            $results.Check16 = $results.Check16 + "`tDatabases: $errorDB`r`n"
        }
        else
        {
            Write-Log "  Check Passed"
            $results.Check16 = $results.Check16 + "Database Size Check: Passed`r`n"
        }

        Write-Log "Completed Check 16: Content Database Size check"
    }

    $sb = $sbTemplate -replace "<REPLACE_EXCL_CDB>", ($excludedcontentdbs.ContentDB -join '", "')

    return $sb.ToString()
}
