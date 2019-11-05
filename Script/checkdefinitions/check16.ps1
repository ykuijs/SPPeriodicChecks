$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '16'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ContentDBSize'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Content Database size'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check16_ContentDBSize()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 16: Content Database Size check"
            $results.Check16 = ""

            $siteThreshold = 100

            $errorCount = 0
            $errorDB = ""

            foreach ($cdb in Get-SPContentDatabase)
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

            if ($errorCount -gt 0)
            {
                WriteLog "  Check Failed"
                $results.Check16 = $results.Check16 + "Database Size Check: $errorCount database(s) failed`r`n"
                $results.Check16 = $results.Check16 + "`tDatabases: $errorDB`r`n"
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check16 = $results.Check16 + "Database Size Check: Passed`r`n"
            }

            WriteLog "Completed Check 16: Content Database Size check"
        })

    return $sb.ToString()
}
