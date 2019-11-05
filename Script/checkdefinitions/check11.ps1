$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '11'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ContentDBStatus'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Content Database status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check11_ContentDBStatus()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 11: Content Database Status check"
            $results.Check11 = ""

            $errorCount = 0
            $errorDB = ""

            foreach ($webapp in Get-SPWebApplication)
            {
                foreach ($contentDB in $webapp.ContentDatabases)
                {
                    if ($contentDB.Status -ne "Online")
                    {
                        $errorCount++
                        if ($errorDB -ne "")
                        {
                            $errorDB += ", "
                        }
                        $errorDB += $contentDB.Name
                    }
                }
            }

            if ($errorCount -gt 0)
            {
                WriteLog "  Check Failed"
                $results.Check11 = $results.Check11 + "Database Status Check: $errorCount database(s) failed`r`n"
                $results.Check11 = $results.Check11 + "`tDatabases: $errorDB`r`n"
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check11 = $results.Check11 + "Database Status Check: Passed`r`n"
            }

            WriteLog "Completed Check 11: Content Database Status check"
        })

    return $sb.ToString()
}
