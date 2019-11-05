
$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '31'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ServicesCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check Status for Windows Services'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check31_ServicesCheck()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 31: Services check"

            $errorServices = ""

            $configFolder = "c:\Windows\Monitoring"
            $configFilename = "servicesconfig.txt"

            if (-not (Test-Path $configFolder))
            {
                $null = New-Item -Path $configFolder -ItemType Directory
            }

            $configFile = Join-Path -Path $configFolder -ChildPath $configFilename
            if (-not (Test-Path $configFile))
            {
                $services = Get-Service
                $services | Select-Object Name, Status | ConvertTo-Csv | Out-File $configFile
            }

            $configServices = Get-Content $configFile | ConvertFrom-Csv

            $runningServices = Get-Service | Select-Object Name, Status

            foreach ($configService in $configServices)
            {
                if ($configService.Status -eq "Running")
                {
                    $runningService = $runningServices | Where-Object -FilterScript { $_.Name -eq $configService.Name }
                    if ($null -ne $runningService)
                    {
                        if ($configService.Status -ne $runningService.Status)
                        {
                            if ($errorServices -eq "")
                            {
                                $errorServices = "`tFailing services: $($configService.Name)"
                            }
                            else
                            {
                                $errorServices = "$errorServices, $($configService.Name)"
                            }
                        }
                    }
                }
            }

            if ($errorServices -ne "")
            {
                WriteLog "  Check Failed"
                $results.Check31 = $results.Check31 + "Services Check: Failed`r`n"
                $results.Check31 = $results.Check31 + $errorServices
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check31 = $results.Check31 + "Services Check: Passed`r`n"
            }

            WriteLog "Completed Check 31: Services check"
        })

    return $sb.ToString()
}
