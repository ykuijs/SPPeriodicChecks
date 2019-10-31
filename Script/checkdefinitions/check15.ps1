$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '15'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'SolutionsDeploymentStatus'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Solution deployment status'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check15_SolutionsDeploymentStatus() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check 15: Solution Deployment check"
$results.Check15 = ""

$errorCount = 0
$errorSolutions = ""

foreach ($solution in $((Get-SPFarm).Solutions))
{
    if(($solution.LastOperationResult -ne [Microsoft.SharePoint.Administration.SPSolutionOperationResult]::DeploymentSucceeded) -and `
       ($solution.LastOperationResult -ne [Microsoft.SharePoint.Administration.SPSolutionOperationResult]::RetractionSucceeded) -and `
       ($solution.LastOperationResult -ne [Microsoft.SharePoint.Administration.SPSolutionOperationResult]::NoOperationPerformed))
    {
        $errorCount++
        if ($errorSolutions -ne "")
        {
            $errorSolutions += ", "
        }
        $errorSolutions += $solution.Name
    }
}

if ($errorCount -gt 0)
{
    WriteLog "  Check Failed"
    $results.Check15 = $results.Check15 + "Solution Deployment Status Check: $errorCount solution(s) failed`r`n"
    $results.Check15 = $results.Check15 + "`tSolutions: $errorSolutions`r`n"
}
else
{
    WriteLog "  Check Passed"
    $results.Check15 = $results.Check15 + "Solution Deployment Status Check: Passed`r`n"
}

WriteLog "Completing Check 15: Solution Deployment check"
})

    return $sb.ToString()
}
