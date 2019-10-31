$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '30'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'LastBootTime'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Displays the last boot time of the server'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check30_LastBootTime() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 30: Last Boot Time check"
$lastBootTime = [Management.ManagementDateTimeConverter]::ToDateTime((Get-WMIObject -Class win32_operatingsystem).LastBootUpTime)
$results.Check30 = "Last Boot Time: $lastBootTime"

WriteLog "Completed Check 30: Last Boot Time check"
})

    return $sb.ToString()
}
