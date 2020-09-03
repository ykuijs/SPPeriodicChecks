$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '50'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'LunPathCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Checks the amount of paths to the SAN for each LUN'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersSQL'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check50_LunPathCheck()
{
    $sb = {
        Write-Log "Starting Check 50: LUN Path check"
        $results.Check50 = ""

        [int]$numberOfPathsRequired = <REPLACE_MIN_LUNPATHS>

        $errorLUNs = ""

        try
        {
            $luns = Get-WMIObject -Class REPLACE_WMI_CLASS -Namespace "root\WMI" -ErrorAction Stop

            foreach ($lun in $luns)
            {
                if ($lun.NumberPaths -ne $numberOfPathsRequired)
                {
                    $errorLUNs += "`tFailed LUN: $($lun.DeviceSlNo) - $($lun.NumberPaths) paths exist`r`n"
                }
            }

            if ($errorLUNs -ne "")
            {
                Write-Log "  Check Failed"
                $results.Check50 = $results.Check50 + "LUN Path Check: Failed`r`n"
                $results.Check50 = $results.Check50 + $errorLUNs
            }
            else
            {
                Write-Log "  Check Passed"
                $results.Check50 = $results.Check50 + "LUN Path Check: Passed`r`n"
            }
        }
        catch
        {
            Write-Log "  Check Failed"
            $results.Check50 = $results.Check50 + "LUN Path Check: Failed. Cannot find WMI Class REPLACE_WMI_CLASS. `r`n"
        }

        Write-Log "Completed Check 50: LUN Path check"
    }

    $checkConfig = $appConfig.AppSettings.Checks.Check | Where-Object -FilterScript { $_.Id -eq 50 }

    if ($null -eq $checkConfig)
    {
        Write-Log "  [ERROR] Cannot find settings for Check 31 in Config.xml."
        exit 90
    }

    $sb = $sb -replace "REPLACE_WMI_CLASS", $checkConfig.WMIClass
    $sb = $sb -replace "<REPLACE_MIN_LUNPATHS>", $checkConfig.MinLUNPaths

    return $sb.ToString()
}
