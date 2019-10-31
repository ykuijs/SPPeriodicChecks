$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'M2'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'PolicyCompliance'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'PolicyCompliancecheck'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Monthly'

$script:checks += $item

function script:CheckM2_PolicyCompliance() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check M2: Policy Compliance check"
$results.CheckM2 = ""

$errorLLCount = 0
$errorLLLists = ""

$errorLVCount = 0
$errorLVLists = ""

$filterLists = @("Apps for Office", "Apps for SharePoint", "Master Page Gallery", "Style Library", "wfpub")
$itemLimit   = 10000

$sites = Get-SPSite -Limit All
foreach ($site in $sites)
{
    foreach ($web in $site.AllWebs)
    {
        $weburl = $web.url
        foreach ($list in $web.Lists)
        {
            if ($filterLists -notcontains $list.Title)
            {
                if ($list.ItemCount -gt $itemLimit)
                {
                    $errorLLCount++
                    $errorLLLists += "`t`t$weburl - $($list.Title) (Items: $($list.ItemCount))`r`n"
                }

                if ((($list.EnableVersioning -eq $true) -and ($list.MajorVersionLimit -eq 0)) -or `
                    (($list.EnableMinorVersions -eq $true) -and ($list.MajorWithMinorVersionsLimit -eq 0)))
                {
                    $errorLVCount++
                    $errorLVLists += "`t`t$weburl - $($list.Title)`r`n"
                }
            }
        }
        $web.Dispose()
    }
    $site.Dispose()
}

if (($errorLLCount -ne 0) -or ($errorLVCount -ne 0))
{
    $results.CheckM2 = $results.CheckM2 + "Policy Compliance Check: Failed`r`n"
}
else
{
    $results.CheckM2 = $results.CheckM2 + "Policy Compliance Passed`r`n"
}

if ($errorLLCount -ne 0) {
    WriteLog "  Check Failed"
    $results.CheckM2 = $results.CheckM2 + "`tLarge List Check: Failed`r`n"
    $results.CheckM2 = $results.CheckM2 + $errorLLLists
}

if ($errorLVCount -ne 0) {
    WriteLog "  Check Failed"
    $results.CheckM2 = $results.CheckM2 + "`tList Versions Check: Failed`r`n"
    $results.CheckM2 = $results.CheckM2 + $errorLVLists
}

WriteLog "Completed Check M2: Policy Compliance check"
})

    return $sb.ToString()
}
