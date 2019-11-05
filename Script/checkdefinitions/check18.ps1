$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '18'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'DistributedCacheStatus'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Distributed Cache Status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check18_DistributedCacheStatus()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 18: Distributed Cache Status check"
            $results.Check18 = ""

            $errorCount = 0
            $errorDC = ""

            $dcInstanceStatus = Get-SPServiceInstance -Server $env:COMPUTERNAME | Where-Object { $_.GetType().Name -eq "SPDistributedCacheServiceInstance" }
            if ($null -eq $dcInstanceStatus -and $dcInstanceStatus.Status -eq "Online")
            {
                if ($null -eq (Get-Module DistributedCacheAdministration))
                {
                    $errorCount++
                    if ($errorDC -ne "")
                    {
                        $errorDC += ", "
                    }
                    $errorDC += "Cannot load the Distributed Cache cmdlets"
                }
                else
                {
                    try
                    {
                        Use-CacheCluster
                        $afservers = Get-CacheHost -ErrorAction Stop

                        $spservers = Get-SPServiceInstance | Where-Object -FilterScript {
                            ($_.service.tostring()) -eq "SPDistributedCacheService Name=AppFabricCachingService"
                        }

                        foreach ($server in $afservers)
                        {
                            $hostname = ($server.HostName -split "\.")[0]

                            if ($server.Status -ne "Up")
                            {
                                $serverstatus = "Offline"
                                $errorCount++
                                if ($errorDC -ne "")
                                {
                                    $errorDC += ", "
                                }
                                $errorDC += "AppFabric service down on $hostname (Status: $serverstatus)"
                            }
                            else
                            {
                                $serverstatus = "Online"
                            }

                            $matchSP = $spservers | Where-Object { $_.Server.Name -eq $hostname -and $_.Status -eq $serverstatus }
                            if ($null -eq $matchSP)
                            {
                                $errorCount++
                                if ($errorDC -ne "")
                                {
                                    $errorDC += ", "
                                }
                                $errorDC += "AppFabric config not equal to SharePoint config for server $hostname"
                            }
                        }

                        foreach ($server in $spservers)
                        {
                            if ($server.Status -ne "Online")
                            {
                                $serverstatus = "Down"
                                $errorCount++
                                if ($errorDC -ne "")
                                {
                                    $errorDC += ", "
                                }
                                $errorDC += "SharePoint service down on $($server.Server.Name) (Status: $serverstatus)"
                            }
                            else
                            {
                                $serverstatus = "Up"
                            }

                            $matchAF = $afservers | Where-Object { ($_.HostName -split "\.")[0] -eq $server.Server.Name -and $_.Status -eq $serverstatus }
                            if ($null -eq $matchAF)
                            {
                                $errorCount++
                                if ($errorDC -ne "")
                                {
                                    $errorDC += ", "
                                }
                                $errorDC += "SharePoint config not equal to AppFabric config for server $($server.Server.Name)"
                            }
                        }

                        $clusterHealth = Get-CacheClusterHealth
                        if ($clusterHealth.UnallocatedNamedCaches.NamedCaches.Count -ne 0)
                        {
                            $errorCount++
                            if ($errorDC -ne "")
                            {
                                $errorDC += ", "
                            }
                            $errorDC += "Unallocated named cache fractions exist"
                        }
                    }
                    catch
                    {
                        $errorCount++
                        if ($errorDC -ne "")
                        {
                            $errorDC += ", "
                        }
                        $errorDC += "Cannot connect to the Distributed Cache service"
                    }
                }
            }
            else
            {
                WriteLog "Skipping check. Distributed Cache service not running on this server."
            }

            if ($errorCount -gt 0)
            {
                WriteLog "  Check Failed"
                $results.Check18 = $results.Check18 + "Distributed Cache Status Check: Check failed. $errorCount errors found.`r`n"
                $results.Check18 = $results.Check18 + "`tFailed checks: $errorDC`r`n"
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check18 = $results.Check18 + "Distributed Cache Status Check: Passed`r`n"
            }

            WriteLog "Completed Check 18: Distributed Cache Status check"
        })

    return $sb.ToString()
}
