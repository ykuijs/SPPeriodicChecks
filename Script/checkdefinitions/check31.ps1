
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
    $excludedservices = Read-Configuration (Join-Path -Path $configPath -ChildPath 'servicesexclusions.txt')

    $sbTemplate = {
        Write-Log "Starting Check 31: Services check"

        $errorServices = ""

        $excludedServices = @("<REPLACE_EXCL_SVC>")
        $configFolder = "<REPLACE_CONFIG_PATH>"
        $configFilename = "<REPLACE_CONFIG_FILE>"

        if (-not (Test-Path -Path $configFolder))
        {
            $null = New-Item -Path $configFolder -ItemType Directory
        }

        $configFile = Join-Path -Path $configFolder -ChildPath $configFilename
        if (-not (Test-Path $configFile))
        {
            $services = Get-Service
            $services | Select-Object -Property Name, Status | ConvertTo-Csv | Out-File -FilePath $configFile
        }

        $configServices = Get-Content -Path $configFile | ConvertFrom-Csv

        $runningServices = Get-Service | Select-Object -Property Name, Status

        foreach ($configService in $configServices)
        {
            if ($configService.Name -notin $excludedServices)
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
        }

        if ($errorServices -ne "")
        {
            Write-Log "  Check Failed"
            $results.Check31 = $results.Check31 + "Services Check: Failed`r`n"
            $results.Check31 = $results.Check31 + $errorServices
        }
        else
        {
            Write-Log "  Check Passed"
            $results.Check31 = $results.Check31 + "Services Check: Passed`r`n"
        }

        Write-Log "Completed Check 31: Services check"
    }

    $sb = $sbTemplate -replace "<REPLACE_EXCL_SVC>", ($excludedservices.Service -join '", "')

    $checkConfig = $appConfig.AppSettings.Checks.Check | Where-Object -FilterScript { $_.Id -eq 31 }

    if ($null -eq $checkConfig)
    {
        Write-Log "  [ERROR] Cannot find settings for Check 31 in Config.xml."
        exit 90
    }

    $sb = $sb -replace "<REPLACE_CONFIG_PATH>", $checkConfig.Path
    $sb = $sb -replace "<REPLACE_CONFIG_File>", $checkConfig.Filename

    return $sb.ToString()
}
