$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '33'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'RunningIISComponents'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Running websites and application pools'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersSP'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check33_RunningIISComponents() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 33: Running IIS components check"
Import-Module WebAdministration

$results.Check33 = ""

$errorCountAppPools = 0
$errorAppPools = ""
$errorCountWebApps = 0
$errorWebApps = ""

$exclusionsAppPools = "SharePoint Web Services Root",".NET v2.0", ".NET v2.0 Classic", ".NET v4.0", ".NET v4.0 Classic", ".NET v4.5", ".NET v4.5 Classic", "DefaultAppPool", "Classic .NET AppPool", "ASP.NET v4.0", "ASP.NET v4.0 Classic"
$exclusionsWebApps = "Default Web Site"

foreach ($webapp in get-childitem IIS:\AppPools\)
{
    if ($(Get-WebAppPoolState $webapp.name).Value -eq "Stopped")
    {
        if (-not $exclusionsAppPools.Contains($webapp.name))
        {
            $errorCountAppPools++
            if ($errorAppPools -ne "")
            {
                $errorAppPools += ", "
            }
            $errorAppPools += $webapp.Name
        }
    }
}

foreach ($site in Get-Website)
{
    if ($site.State -eq "Stopped")
    {
        if (-not $exclusionsWebApps.Contains($site.Name))
        {
            $errorCountWebApps++
            if ($errorWebApps -ne "")
            {
                $errorWebApps += ", "
            }
            $errorWebApps += $site.Name
        }
    }
}

if (($errorCountAppPools -gt 0) -or ($errorCountWebApps -gt 0))
{
    WriteLog "  Check Failed"
    $results.Check33 = $results.Check33 + "Application Pool and Websites Check: $errorCountAppPools Application Pool(s) failed and $errorCountWebApps Website(s) failed`r`n"
    $results.Check33 = $results.Check33 + "`tApplication Pools: $errorAppPools`r`n"
    $results.Check33 = $results.Check33 + "`tWebsites: $errorWebApps`r`n"
}
else
{
    WriteLog "  Check Passed"
    $results.Check33 = $results.Check33 + "Application Pool and Websites Check: Passed`r`n"
}

WriteLog "Completed Check 33: Running IIS components check"
})

    return $sb.ToString()
}
