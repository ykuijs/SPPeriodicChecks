﻿$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '20'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'SearchTopologyStatus'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Status of all Search topology components'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check20_SearchTopologyStatus()
{
    $sb = {
        Write-Log "Starting Check 20: Search Topology check"
        $results.Check20 = ""

        try
        {
            $ssas = Get-SPEnterpriseSearchServiceApplication
            $errorMessage = ""
            foreach ($ssa in $ssas)
            {
                $errorCount = 0
                $erroredComponents = ""

                $components = Get-SPEnterpriseSearchStatus -SearchApplication $ssa -ErrorAction Stop
                foreach ($component in $components)
                {
                    if ($component.State -ne "Active")
                    {
                        $errorCount++
                        if ($erroredComponents -ne "")
                        {
                            $erroredComponents += ", "
                        }
                        $erroredComponents += $component.Name
                    }
                }

                if ($errorCount -gt 0)
                {
                    $errorMessage = "`t$($ssa.name): $errorCount components failed`r`n"
                }
            }

            if ($errorMessage -ne "")
            {
                Write-Log "  Check Failed"
                $results.Check20 = $results.Check20 + "Search Topology Check: Failed`r`n"
                $results.Check20 = $results.Check20 + $errorMessage
            }
            else
            {
                Write-Log "  Check Passed"
                $results.Check20 = $results.Check20 + "Search Topology Check: Passed`r`n"
            }
        }
        catch
        {
            Write-Log "  Check Failed"
            $results.Check20 = $results.Check20 + "Search Topology Check: Failed`r`n"
            $results.Check20 = $results.Check20 + $_.Exception.Message
        }

        Write-Log "Completed Check 20: Search Topology check"
    }

    return $sb.ToString()
}
