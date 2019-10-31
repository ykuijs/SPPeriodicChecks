$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'W1'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'PermissionsCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check if all permissions are configured correctly'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Weekly'

$script:checks += $item

function script:CheckW1_PermissionsCheck() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check W1: Permissions check"
$results.CheckW1 = ""

$errorCount = 0
$erroredComponents = ""

#$errorCount++
#$erroredComponents += $component.Name

if ($errorCount -gt 0)
{
    WriteLog "  Check Failed"
    $results.CheckW1 = $results.CheckW1 + "Permissions Check: Failed`r`n"
    $results.CheckW1 = $results.CheckW1 + "`t$errorCount components failed`r`n"
}
else
{
    WriteLog "  Check Passed"
    $results.CheckW1 = $results.CheckW1 + "Permissions Check: Passed`r`n"
}
WriteLog "Completed Check W1: Permissions check"
})

    return $sb.ToString()
}
