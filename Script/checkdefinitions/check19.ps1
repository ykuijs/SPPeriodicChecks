$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '19'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ContentDBSizeInGB'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Content Database File Size'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'Farm'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check19_ContentDBSizeInGB()
{
    $excludedcontentdbs = Read-Configuration (Join-Path -Path $configPath -ChildPath 'contentdbexclusions.txt')

    $sbTemplate = {
        Write-Log "Starting Check 19: Content Database Size Check"
        $results.Check19 = ""

        $maxSize = 175
        $excludedCDBs = @("<REPLACE_EXCL_CDB>")

        $errorCount = 0
        $errorDB = ""

        function Invoke-SQL
        {
            param
            (
                [Parameter(Mandatory = $true)]
                [System.String]
                $SQLInstance,

                [Parameter(Mandatory = $true)]
                [System.String]
                $Database,

                [Parameter(Mandatory = $true)]
                [System.String]
                $Query
            )

            $connectionString = "Data Source=$SQLInstance; " + `
                "Integrated Security=SSPI; " + `
                "Initial Catalog=$Database"

            $connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
            $command = New-Object System.Data.SqlClient.SqlCommand($Query, $connection)
            $connection.Open()

            $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
            $dataset = New-Object System.Data.DataSet

            $adapter.Fill($dataSet) | Out-Null

            $connection.Close()
            return $dataSet.Tables
        }

        foreach ($cdb in Get-SPContentDatabase)
        {
            if ($cdb.Name -notmatch ($excludedCDBs -join "|"))
            {
                $query = "SELECT SUM(CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0) AS SpaceUsedMB FROM sys.database_files WHERE type=0"
                $spaceUsed = (Invoke-SQL -SQLInstance $cdb.Server -Database $cdb.Name -Query $query).SpaceUsedMB
                if ($spaceUsed -gt ($maxSize * 1024))
                {
                    $errorCount++
                    if ($errorDB -ne "")
                    {
                        $errorDB += ", "
                    }
                    $errorDB += "$($cdb.Name) ($([Math]::Round($spaceUsed/1024,1))GB)"
                }
            }
        }

        if ($errorCount -gt 0)
        {
            Write-Log "  Check Failed"
            $results.Check19 = $results.Check19 + "Content Database Size Check: Check failed. $errorCount errors found.`r`n"
            $results.Check19 = $results.Check19 + "`tFailed databases: $errorDB`r`n"
        }
        else
        {
            Write-Log "  Check Passed"
            $results.Check19 = $results.Check19 + "Content Database Size Check: Passed`r`n"
        }

        Write-Log "Completed Check 19: Content Database Size check"
    }

    $sb = $sbTemplate -replace "<REPLACE_EXCL_CDB>", ($excludedcontentdbs.ContentDB -join '", "')

    return $sb.ToString()
}
