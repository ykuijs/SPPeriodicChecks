$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '12'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'UpgradeStatusServer'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Server upgrade status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check12_UpgradeStatusServer()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 12: Server Upgrade Status check"
            $results.Check12 = ""

            $errorCount = 0
            $errorServers = ""

            $farm = Get-SPFarm
            $productVersions = [Microsoft.SharePoint.Administration.SPProductVersions]::GetProductVersions($farm)

            foreach ($server in $(Get-SPServer | Where-Object -FilterScript { $_.Role -ne "Invalid" }))
            {
                $serverProductInfo = $productVersions.GetServerProductInfo($server.Id)
                $statusType = ""
                if ($null -ne $serverProductInfo)
                {
                    $statusType = $serverProductInfo.InstallStatus
                    if ($statusType -ne "NoActionRequired")
                    {
                        $errorCount++
                        if ($errorServers -ne "")
                        {
                            $errorServers += ", "
                        }
                        $errorServers += "$($server.Name) (Status: $statusType)"
                    }
                }
            }

            if ($errorCount -gt 0)
            {
                WriteLog "  Check Failed"
                $results.Check12 = $results.Check12 + "Server Upgrade Status Check: $errorCount servers(s) failed`r`n"
                $results.Check12 = $results.Check12 + "`tServers: $errorServers`r`n"
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check12 = $results.Check12 + "Server Upgrade Status Check: Passed`r`n"
            }

            WriteLog "Completed Check 12: Server Upgrade Status check"
        })

    return $sb.ToString()
}
