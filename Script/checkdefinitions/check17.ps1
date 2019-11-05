$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '17'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ServiceAppStatus'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Service Application Status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check17_ServiceAppStatus()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check 17: Service Application Status check"
            $results.Check17 = ""

            $errorCount = 0
            $errorSA = ""

            $sp = Get-SPServiceApplicationProxy | Where-Object -FilterScript { $_.Status -ne "Online" }
            if ($null -ne $sp)
            {
                $errorCount += $sp.Count
                foreach ($proxy in $sp)
                {
                    if ($errorSA -ne "")
                    {
                        $errorSA += ", "
                    }
                    $errorSA += "$($proxy.Name) (Status: $($proxy.Status))"
                }
            }

            $sa = Get-SPServiceApplication | Where-Object -FilterScript { $_.Status -ne "Online" }
            if ($null -ne $sa)
            {
                $errorCount += $sp.Count
                foreach ($serviceapp in $sp)
                {
                    if ($errorSA -ne "")
                    {
                        $errorSA += ", "
                    }
                    $errorSA += "$($serviceapp.Name) (Status: $($serviceapp.Status))"
                }
            }

            if ($errorCount -gt 0)
            {
                WriteLog "  Check Failed"
                $results.Check17 = $results.Check17 + "Service Application Status Check: $errorCount service application(s) failed`r`n"
                $results.Check17 = $results.Check17 + "`tService Applications: $errorSA`r`n"
            }
            else
            {
                WriteLog "  Check Passed"
                $results.Check17 = $results.Check17 + "Service Application Status Check: Passed`r`n"
            }

            WriteLog "Completed Check 17: Service Application Status check"
        })

    return $sb.ToString()
}
