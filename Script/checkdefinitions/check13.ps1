$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '13'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'UpgradeStatusContentDB'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Content database upgrade status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check13_UpgradeStatusContentDB() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 13: Database Upgrade Status check"
$results.Check13 = ""

$errorCount = 0
$errorDB = ""

foreach ($webapp in Get-SPWebApplication)
{
    foreach ($contentDB in $webapp.ContentDatabases)
    {
        if($contentDB.NeedsUpgrade -eq $true)
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

if($errorCount -gt 0)
{
    WriteLog "  Check Failed"
    $results.Check13 = $results.Check13 + "Database Upgrade Status Check: $errorCount database(s) failed`r`n"
    $results.Check13 = $results.Check13 + "`tDatabases: $errorDB`r`n"
}
else
{
    WriteLog "  Check Passed"
    $results.Check13 = $results.Check13 + "Database Upgrade Status Check: Passed`r`n"
}

WriteLog "Completed Check 13: Database Upgrade Status check"
})

    return $sb.ToString()
}
