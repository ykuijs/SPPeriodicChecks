$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'M1'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'MBSACheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Missing patches check'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Remote'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Monthly'

$script:checks += $item

function script:Download-WSUSFile() {
    Write-Verbose "        Started downloading WSUSSCN2.CAB file"
    $url = "http://go.microsoft.com/fwlink/?LinkID=74689"
    $destination = Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab"

    if (Test-Path -Path $destination)
    {
        Remove-Item -Path $destination -ErrorAction SilentlyContinue
        Remove-Item -Path "$destination.dat" -ErrorAction SilentlyContinue
    }

    Invoke-WebRequest -Uri $url -OutFile $destination
    Write-Verbose "        Completed downloading WSUSSCN2.CAB file"
}

function script:Start-MBSAScanOnServer() {
    Param (
        [System.String] $server
    )
    $scriptpath = Split-Path $invocation.MyCommand.Path

    $job = Start-Job -Scriptblock {
        $scriptpath  = $args[0]
        $server      = $args[1]
        $MBSAPath    = $args[2]
        $WSUSCabPath = $args[3]
        $logfile     = $args[4]

        function WriteLog() {
            param
            (
                [parameter(Mandatory = $true)]
                [System.String]
                $message
            )
            $date = Get-Date -format "yyyy-MM-dd HH:mm:ss"
            Write-Output -InputObject "$date - $message"
            Add-Content -Path $logfile "$date - $message"
        }

        Set-Location $scriptpath

        $reportFolder = Join-Path -Path $env:TEMP -ChildPath "MBSAReports"
        if (-not(Test-Path $reportFolder))
        {
            New-Item -Path $reportFolder -ItemType Directory
        }

        $application  = Join-Path -Path $MBSAPath -ChildPath "mbsacli.exe"
        $WSUSScn2Path = Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab"
        $arguments    = "/target $server /n OS+SQL+IIS+Password /offline /q /catalog $WSUSScn2Path /rd $reportFolder"
        Start-Process -FilePath $application -ArgumentList $arguments -PassThru -Wait
    } -Name MBSA -ArgumentList $scriptpath, $server, $MBSAPath, $WSUSCabPath, $logfile
}

function script:Analyze-Results() {
    Param
    (
        [System.String] $reportFolder
    )
    Write-Verbose "        Starting MBSA scan result analysis"
    # Setup variables
    $missingPatches = ""
    $missingPatchesCount = 0
    $failedServers = 0

    # Retrieve all MBSA report filenames
    $files = get-Childitem $reportFolder | Where-Object -FilterScript { $_.Extension -match "mbsa" }

    # Loop through each MBSA report file
    foreach ($file in $files)
    {
        # Read file into memory and parse the XML format
        [XML]$scanresults = Get-Content $file.FullName
        $missingKBs = ""

        # Reset all patch counters
        $critical = 0
        $criticalkb = ""
        $important = 0
        $importantkb = ""
        $moderate = 0
        $moderatekb = ""
        $low = 0
        $lowkb = ""
        $rollup = 0
        $rollupkb = ""
        $unknown = 0
        $unknownkb = ""

        $scanok = $false

        # Loop through the different patch category sections
        foreach ($check in $scanresults.SecScan.Check)
        {
            if ($check.Advice -ne "Cannot contact Windows Update Agent on target computer, possibly due to firewall settings.")
            {
                $scanok = $true
                # Loop through all patches in the specific category
                foreach($update in $check.Detail.UpdateData)
                {
                    # Check if the patch is on the "Excluded Patches" list, if so skip patch
                    if (($null -ne $excludedPatches) -and ($excludedPatches.Patch.Contains($update.KBID) -eq $false))
                    {
                        # Only process the patches that are not installed
                        if ($update.IsInstalled -eq $false)
                        {
                            # Check what the severity is and process the data that way
                            switch($update.Severity)
                            {
                                0 { # Severity is 0, patch is either Low or Rollup
                                    if ($update.Type -eq "1")
                                    {
                                        # Patch severity is Low
                                        $low++
                                        $missingPatchesCount++
                                        if ($lowkb -eq "") { $lowkb = $update.KBID } else { $lowkb += ", $($update.KBID)"}
                                    }
                                    elseif ($update.Type -eq "3")
                                    {
                                        # Patch type is Rollup
                                        $rollup++
                                        $missingPatchesCount++
                                        if ($rollupkb -eq "") { $rollupkb = $update.KBID } else { $rollupkb += ", $($update.KBID)"}
                                    }
                                    else
                                    {
                                        # Patch type is Unknown
                                        $unknown++
                                        $missingPatchesCount++
                                        if ($unknownkb -eq "") { $unknownkb = $update.KBID } else { $unknownkb += ", $($update.KBID)"}
                                    }
                                  }
                                2 { 
                                    # Patch severity is Moderate
                                    $moderate++
                                    $missingPatchesCount++
                                    if ($moderatekb -eq "")
                                    {
                                        $moderatekb = $update.KBID
                                    }
                                    else
                                    {
                                        $moderatekb += ", $($update.KBID)"
                                    }
                                  }
                                3 { 
                                    # Patch severity is Important
                                    $important++
                                    $missingPatchesCount++
                                    if ($importantkb -eq "")
                                    {
                                        $importantkb = $update.KBID
                                    }
                                    else
                                    {
                                        $importantkb += ", $($update.KBID)"
                                    }
                                  }
                                4 { 
                                    # Patch severity is Critical
                                    $critical++
                                    $missingPatchesCount++
                                    if ($criticalkb -eq "")
                                    {
                                        $criticalkb = $update.KBID
                                    }
                                    else
                                    {
                                        $criticalkb += ", $($update.KBID)"
                                    }
                                  }
                            }
                        }
                    }
                }
            }
        }

        if ($scanok)
        {
            # Output results to screen
            $missingPatches += "`tServer: $($scanresults.SecScan.Machine)`r`n"
            $missingPatches += "`t`tCritical  : $critical ($criticalkb)`r`n"
            $missingPatches += "`t`tImportant : $important ($importantkb)`r`n"
            $missingPatches += "`t`tModerate  : $moderate ($moderatekb)`r`n"
            $missingPatches += "`t`tLow       : $low ($lowkb)`r`n"
            $missingPatches += "`t`tRollup    : $rollup ($rollupkb)`r`n"
            $missingPatches += "`t`tUnknown   : $unknown ($unknownkb)`r`n"
        }
        else
        {
            $missingPatches += "`tServer: $($scanresults.SecScan.Machine)`r`n"
            $missingPatches += "`t`tFailed: Scan could not be performed due to connectivity/firewall issues.`r`n"
            $failedServers++
        }
    }
    Write-Verbose "        Completed MBSA scan result analysis"
    return $missingPatches,$missingPatchesCount, $failedServers
}

function script:CheckM1_MBSACheck() {
    Param
    (
        [parameter(Mandatory = $true)] [PSCustomObject] $check
    )
    WriteLog "      Starting MBSA check"

    if ($null -eq $results.Remote)
    {
        $results.Remote = @{}
    }
    
    $results.Remote.CheckM1 = ""
    $errorCount   = 0
    $errorMessage = ""
    $reportFolder = Join-Path -Path $env:TEMP -ChildPath "MBSAReports"

    if (-not (Test-Path -Path (Join-Path -Path $MBSAPath -ChildPath "mbsacli.exe")))
    {
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "MBSA Check: Failed, mbsacli.exe missing`r`n"
        WriteLog "Error: MBSAcli.exe not found! (Path: $MBSAPath)"
        return
    }

    if ($downloadWSUSFile -eq $true)
    {
        Download-WSUSFile
    }
    else
    {
        if (-not (Test-Path -Path (Join-Path -Path $WSUSCabPath -ChildPath "wsusscn2.cab")))
        {
            $results.Remote.CheckM1 = $results.Remote.CheckM1 + "MBSA Check: Failed, wsusscn2.cab missing`r`n"
            WriteLog "Error: Wsusscn2.cab not found! (Path: $WSUSCabPath)"
            return
        }
    }

    foreach ($server in $config)
    {
        WriteLog "        Starting MBSA scan on server $($server.servername)"
        Start-MBSAScanOnServer $server.servername
    }
    WriteLog "        Waiting for MBSA scans to complete"
    $temp = Wait-Job -Name MBSA
    WriteLog "        Completed all MBSA scans"

    if (-not (Test-Path -Path (Join-Path -Path $reportFolder -ChildPath "*.mbsa")))
    {
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "MBSA Check: Failed, No reports were found in report folder`r`n"
        WriteLog "Error: No reports found in report folder! (Path: $reportFolder)"
        return
    }
    $analysisResults = Analyze-Results $reportFolder

    WriteLog "        Cleaning up reports"
    Remove-Job -Name MBSA
    if ($debug -eq $true)
    {
        WriteLog "          NOTE: Debug is set to True: Leaving MBSA report files in $reportFolder"
    }
    else
    {
        Remove-Item $reportFolder -Force -Recurse
    }

    $missingPatchesOverview = $analysisResults[0]
    $missingPatchesCount    = $analysisResults[1]
    $failedServers          = $analysisResults[2]

    if ($missingPatchesCount -gt 0 -or $failedServers -gt 0)
    {
        WriteLog "        Check Failed"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "MBSA Check: Failed, $missingPatchesCount patches missing, $failedServers server(s) failed`r`n"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "$missingPatchesOverview"
    }
    else
    {
        WriteLog "        Check Passed"
        $results.Remote.CheckM1 = $results.Remote.CheckM1 + "MBSA Check: Passed`r`n"
    }
    WriteLog "      Completed MBSA check"
}
