$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '99'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'TestCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'TestCheck'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersCAM'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check99_TestCheck()
{
    $sb = {
        Write-Log "Starting Check 99: Test Check"
        $results.Check99 = ""

        $numberOfPathsRequired = 4

        $errorLUNs = ""

        try
        {
            Write-Log "  Check Passed"
            $results.Check99 = $results.Check99 + "Test Check: Passed.`r`n"
        }
        catch
        {
            Write-Log "  Check Failed"
            $results.Check99 = $results.Check99 + "Test Check: Failed.`r`n"
        }

        Write-Log "Completed Check 99: Test Check"
    }

    return $sb.ToString()
}
