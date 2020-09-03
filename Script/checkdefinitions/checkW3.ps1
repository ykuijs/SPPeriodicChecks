$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'W3'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'BaselineComplianceCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check server is compliant with baseline settings (if DSC is used)'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Weekly'

$script:checks += $item

function script:CheckW3_BaselineComplianceCheck()
{
    $sb = {
        Write-Log 'Starting Check W3: Baseline Compliance check'
        $results.CheckW3 = ''

        $errorCount = 0
        $erroredResources = ''

        if (Test-Path -Path 'C:\Windows\System32\Configuration\Current.mof')
        {
            try
            {
                $result = Test-DscConfiguration -Detailed -ErrorAction Stop

                if ($result.InDesiredState -eq $false)
                {
                    $errorCount = $result.ResourcesNotInDesiredState.Count
                    $erroredResources = $result.ResourcesNotInDesiredState.ResourceId -join ", "
                }
            }
            catch
            {
                $errorCount = 1
                $erroredResources = $_.Exception.Message
            }

            if ($errorCount -gt 0)
            {
                Write-Log '  Check Failed'
                $results.CheckW3 = $results.CheckW3 + "Baseline Compliancy Check: $errorCount resource(s) failed`r`n"
                $results.CheckW3 = $results.CheckW3 + "`tFailed resources: $erroredResources`r`n"
            }
            else
            {
                Write-Log '  Check Passed'
                $results.CheckW3 = $results.CheckW3 + "Baseline Compliancy Check: Passed`r`n"
            }
        }
        else
        {
            Write-Log '  Check Skipped (DSC not used)'
            $results.CheckW3 = $results.CheckW3 + "Baseline Compliancy Check: Skipped (DSC not used)`r`n"
        }

        Write-Log 'Completed Check W3: Baseline Compliance check'
    }

    return $sb.ToString()
}
