$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'M1'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'PatchCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Missing Patch check'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Remote'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Monthly'

$script:checks += $item

function script:Save-WSUSFile()
{
    WriteLog "        Started downloading WSUSSCN2.CAB file"
    $url = "http://go.microsoft.com/fwlink/?LinkID=74689"
    $destination = Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab"

    $wsusscn2Properties = Get-ItemProperty -Path $destination
    if ($wsusscn2Properties.LastWriteTime -lt (Get-Date).AddDays(-7))
    {
        WriteLog "           Downloading file to $destination"
        if (Test-Path -Path $destination)
        {
            Remove-Item -Path $destination -ErrorAction SilentlyContinue
            Remove-Item -Path "$destination.dat" -ErrorAction SilentlyContinue
        }

        try
        {
            $wc = New-Object System.Net.WebClient
            $wc.DownloadFile($url, $destination)
            WriteLog "        Completed downloading WSUSSCN2.CAB file"
        }
        catch
        {
            WriteLog " [ERROR] Error while downloading WSUSSCN2.CAB file: $($_.Exception)"
            return $false
        }
    }
    else
    {
        WriteLog "          Already downloaded a copy of WSUSSCN2.CAB in the last seven days. Skipping download!"
    }

    return $true
}

function script:Copy-WSUSFileToServer()
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Server
    )
    WriteLog "        Copying WSUSSCN2.CAB file to server $Server"
    $wsusscn2File = Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab"

    $null = Start-Job -ScriptBlock {
        param
        (
            [Parameter(Mandatory = $true)]
            [System.String]
            $Server,

            [Parameter(Mandatory = $true)]
            [System.String]
            $WSusScnPath
        )
        $session = New-PSSession -ComputerName $Server
        #Copy-Item -Path $WSusScnPath -Destination "C:\Windows\Temp" -ToSession $session -Force
        Remove-PSSession -Session $session
    } -ArgumentList $Server, $wsusscn2File -Name WsusscnCopy
}

function script:Start-ScanOnServer()
{
    Param (
        [Parameter(Mandatory = $true)]
        [System.String]
        $Server
    )

    $session = New-PSSession -ComputerName $Server
    $scanJob = Invoke-Command -Session $session -ScriptBlock {
        param ($excludedPatches)

        $wsusscnPath = 'C:\Windows\Temp\wsusscn2.cab'

        $missingPatchesDetails = ""
        $missingPatchesCount = 0
        $errors = ""
        $log = ""

        if (Test-Path -Path $wsusscnPath)
        {
            try
            {
                $updateSession = New-Object -ComObject Microsoft.Update.Session
                $updateServiceManager = New-Object -ComObject Microsoft.Update.ServiceManager
                $UpdateService = $UpdateServiceManager.AddScanPackageService("Offline Sync Service", $wsusscnPath)
                $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
                $UpdateSearcher.ServerSelection = 3
                $UpdateSearcher.ServiceID = $UpdateService.ServiceID
                $SearchResult = $UpdateSearcher.Search('IsHidden = 0 AND IsInstalled =0')

                $allMissingUpdates = $SearchResult.Updates | Where-Object { $_.KBArticleIds -notin @($excludedPatches.Patch) }
                if ($allMissingUpdates.Count -ne 0)
                {
                    $missingPatchesCount = 0
                    $missingPatchesDetails += "`tServer: $($env:COMPUTERNAME)`r`n"

                    $log += "          Server $($env:COMPUTERNAME) is missing the following patches:`r`n"
                    foreach ($category in $SearchResult.RootCategories)
                    {
                        $catUpdates = $category.Updates | Where-Object { $_.KBArticleIds -notin @($excludedPatches.Patch) }
                        if ($catUpdates.Count -gt 0)
                        {
                            $catName = $category.Name
                            $missingPatchesDetails += "`t`t$catName  : $($catUpdates.Count) ($(($catUpdates | ForEach { $_.KBArticleIDs | Select-Object -First 1 }) -join ", "))`r`n"

                            $log += "`r`n          Category: $($category.Name)`r`n"
                            $catUpdates | ForEach { $log += "          - $($_.Title)`r`n" }
                            $missingPatchesCount += $catUpdates.Count
                        }
                    }
                }
                else
                {
                    $log += "          No patches missing!"
                }
            }
            catch
            {
                $errors = "$($env:COMPUTERNAME): Error while performing scan: $($_.Exception)"
            }
        }
        else
        {
            $errors = "$($env:COMPUTERNAME): Cannot find WSUSSCN2.CAB file on the server"
        }

        return $missingPatchesDetails, $missingPatchesCount, $errors, $log
    } -AsJob -HideComputerName -ArgumentList $excludedPatches

    return $scanJob
}

function script:CheckM1_PatchCheck()
{
    Param()

    WriteLog "      Starting Missing Patch check"

    if ($null -eq $results.Remote)
    {
        $results.Remote = @{ }
    }

    $results.Remote.CheckM1 = ""

    # Download or use offline WSUSSCN2.CAB file
    if ($downloadWSUSFile -eq $true)
    {
        # Download WSUSSCN2.CAB file
        $downloadResult = Save-WSUSFile

        if ($downloadResult -eq $false)
        {
            $results.Remote.CheckM1 = $results.Remote.CheckM1 + "Missing Patch Check: Failed, could not download WSUSSCN2.CAB file. Check logfile for more details.`r`n"
            WriteLog "ERROR: Could not download WSUSSCN2.CAB file."
            return
        }
    }
    else
    {
        # Check if offline WSUSSCN2.CAB file exists
        $wsusscn2Path = (Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab")
        if (-not (Test-Path -Path $wsusscn2Path))
        {
            $results.Remote.CheckM1 = $results.Remote.CheckM1 + "Missing Patch Check: Failed, wsusscn2.cab missing.`r`n"
            WriteLog "ERROR: Wsusscn2.cab not found! (Path: $WSUSCabPath)"
            return
        }
        else
        {
            $wsusscn2Properties = Get-ItemProperty -Path $wsusscn2Path
            if ($wsusscn2Properties.LastWriteTime -lt (Get-Date).AddDays(-60))
            {
                $results.Remote.CheckM1 = $results.Remote.CheckM1 + "Missing Patch Check: WARNING - Wsusscn2.cab file is older than 60 days`r`n"
                WriteLog "WARNING: Wsusscn2.cab file is older than 60 days"
            }
        }
    }

    # Copying WSUSSCN2.CAB file to all servers
    foreach ($server in $ServerConfig)
    {
        Copy-WSUSFileToServer -Server $server.servername
    }
    WriteLog "        Waiting for WSUSSCN2.CAB file copy to complete"
    $null = Wait-Job -Name WsusscnCopy
    Remove-Job -Name WsusscnCopy

    WriteLog "        Excluding the following patches from the scan results: $($excludedPatches.Patch -join ", ")"

    # Starting Missing Patch scan on all servers
    $scanJobs = @()
    foreach ($server in $ServerConfig)
    {
        WriteLog "        Starting Missing Patch scan on server $($server.servername)"
        $scanJobs += Start-ScanOnServer $server.servername
    }
    WriteLog "        Waiting for Missing Patch scans to complete"
    $null = Wait-Job -Job $scanJobs
    WriteLog "        Completed all Missing Patch scans"

    # Retrieving scan results from all servers
    $missingPatchesCount = 0
    $missingPatchesOverview = ""
    $failedServers = 0
    foreach ($job in $scanJobs)
    {
        $srvResult = Receive-Job -Job $job

        if ($srvResult[0] -ne "")
        {
            $missingPatchesOverview += $srvResult[0]
        }

        $missingPatchesCount += $srvResult[1]

        if ($srvResult[2] -ne "")
        {
            $failedServers++
            $missingPatchesOverview += $srvResult[2]
        }

        WriteLog $srvResult[3]
    }

    WriteLog "        Cleaning up jobs and sessions"
    Remove-Job -Job $scanJobs

    # Store results in results object
    if ($missingPatchesCount -gt 0 -or $failedServers -gt 0)
    {
        WriteLog "        Check Failed"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "Missing Patch Check: Failed, $missingPatchesCount patches missing, $failedServers server(s) failed`r`n"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "$missingPatchesOverview"
    }
    else
    {
        WriteLog "        Check Passed"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "Missing Patch Check: Passed`r`n"
    }
    WriteLog "      Completed Missing Patch check"
}
