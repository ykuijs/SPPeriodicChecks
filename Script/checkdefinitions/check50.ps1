$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '50'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'LunPathCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Checks the amount of paths to the SAN for each LUN'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersSQL'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check50_LunPathCheck() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 50: LUN Path check"
$results.Check50 = ""

$numberOfPathsRequired = 4

$errorLUNs = ""

try
{
    $luns = Get-WMIObject -Class HPDSM_PERFINFO -Namespace "root\WMI" -ErrorAction Stop

    foreach ($lun in $luns)
    {
	    if ($lun.NumberPaths -ne $numberOfPathsRequired)
        {
		    $errorLUNs += "`tFailed LUN: $($lun.DeviceSlNo) - $($lun.NumberPaths) paths exist`r`n"
	    }
    }

    if ($errorLUNs -ne "")
    {
        WriteLog "  Check Failed"
        $results.Check50 = $results.Check50 + "LUN Path Check: Failed`r`n"
        $results.Check50 = $results.Check50 + $errorLUNs
    }
    else
    {
        WriteLog "  Check Passed"
        $results.Check50 = $results.Check50 + "LUN Path Check: Passed`r`n"
    }
}
catch
{
    WriteLog "  Check Failed"
    $results.Check50 = $results.Check50 + "LUN Path Check: Failed. Cannot find WMI Class HPDSM_PERFINFO. `r`n"
}

WriteLog "Completed Check 50: LUN Path check"
})

    return $sb.ToString()
}
