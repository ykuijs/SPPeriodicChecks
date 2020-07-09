$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '32'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'ScheduledTasks'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Result of completed scheduled tasks'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check32_ScheduledTasks()
{
    $sb = {
        Write-Log "Starting Check 32: Scheduled Tasks check"
        $results.Check32 = ""

        function Get-SchedTask
        {
            [Cmdletbinding(
                DefaultParameterSetName = 'COM'
            )]
            param
            (
                [parameter(
                    ValueFromPipeline = $true,
                    ValueFromPipelineByPropertyName = $true,
                    ValueFromRemainingArguments = $false,
                    Position = 0
                )]
                [Alias("host", "server", "computer")]
                [string[]]
                $ComputerName = "localhost",

                [parameter()]
                [string]
                $folder = "\",

                [parameter(ParameterSetName = 'COM')]
                [switch]
                $recurse,

                [parameter(ParameterSetName = 'COM')]
                [validatescript( {
                        #Test path if provided, otherwise allow $null
                        if ($_)
                        {
                            Test-Path -PathType Container -path $_
                        }
                        else
                        {
                            $true
                        }
                    })]
                [string]
                $Path = $null,

                [parameter()]
                [string]
                $Exclude = $null,

                [parameter(ParameterSetName = 'SchTasks')]
                [switch]
                $CompatibilityMode
            )
            Begin
            {
                if (-not $CompatibilityMode)
                {
                    $sch = New-Object -ComObject Schedule.Service

                    function Get-AllTaskSubFolder
                    {
                        [cmdletbinding()]
                        param (
                            # Set to use $Schedule as default parameter so it automatically list all files
                            # For current schedule object if it exists.
                            $FolderRef = $sch.getfolder("\"),

                            [switch]$recurse
                        )

                        #No recurse?  Return the folder reference
                        if (-not $recurse)
                        {
                            $FolderRef
                        }
                        #Recurse?  Build up an array!
                        else
                        {
                            try
                            {
                                #This will fail on older systems...
                                $folders = $folderRef.getfolders(1)

                                #Extract results into array
                                $ArrFolders = @(
                                    if ($folders)
                                    {
                                        foreach ($fold in $folders)
                                        {
                                            $fold
                                            if ($fold.getfolders(1))
                                            {
                                                Get-AllTaskSubFolder -FolderRef $fold
                                            }
                                        }
                                    }
                                )
                            }
                            catch
                            {
                                #If we failed and the expected error, return folder ref only!
                                if ($_.tostring() -like '*Exception calling "GetFolders" with "1" argument(s): "The request is not supported.*')
                                {
                                    $folders = $null
                                    Write-Warning "GetFolders failed, returning root folder only: $_"
                                    Return $FolderRef
                                }
                                else
                                {
                                    Throw $_
                                }
                            }

                            #Return only unique results
                            $Results = @($ArrFolders) + @($FolderRef)
                            $UniquePaths = $Results | Select-Object -ExpandProperty path -Unique
                            $Results | Where-Object -FilterScript { $UniquePaths -contains $_.path }
                        }
                    } #Get-AllTaskSubFolder
                }

                function Get-SchTask
                {
                    [Cmdletbinding()]
                    param
                    (
                        [string]
                        $computername,

                        [string]
                        $folder,

                        [switch]
                        $CompatibilityMode
                    )

                    #we format the properties to match those returned from com objects
                    $result = @( schtasks.exe /query /v /s $computername /fo csv |
                        convertfrom-csv |
                        Where-Object -FilterScript {
                            $_.taskname -ne "taskname" -and $_.taskname -match $( $folder.replace("\", "\\") )
                        } | Select-Object @{ label = "ComputerName"; expression = { $computername } },
                        @{ label = "Name"; expression = { $_.TaskName } },
                        @{ label = "Action"; expression = { $_."Task To Run" } },
                        @{ label = "LastRunTime"; expression = { $_."Last Run Time" } },
                        @{ label = "NextRunTime"; expression = { $_."Next Run Time" } },
                        "Status",
                        "Author"
                    )

                    if ($CompatibilityMode)
                    {
                        #User requested compat mode, don't add props
                        $result
                    }
                    else
                    {
                        #If this was a failback, we don't want to affect display of props for comps that don't fail... include empty props expected for com object
                        #We also extract task name and path to parent for the Name and Path props, respectively
                        foreach ($item in $result)
                        {
                            $name = @( $item.Name -split "\\" )[-1]
                            $taskPath = $item.name
                            $item | Select-Object ComputerName,
                            @{ label = "Name"; expression = { $name } },
                            @{ label = "Path"; Expression = { $taskPath } },
                            Enabled,
                            Action,
                            Arguments,
                            UserId,
                            LastRunTime,
                            NextRunTime,
                            Status,
                            Author,
                            RunLevel,
                            Description,
                            NumberOfMissedRuns
                        }
                    }
                } #Get-SchTask
            }
            Process
            {
                # Loop through computers
                foreach ($computer in $computername)
                {
                    Write-Verbose "Running against $computer"
                    try
                    {
                        #use com object unless in compatibility mode.  Set compatibility mode if this fails
                        if (-not $compatibilityMode)
                        {
                            try
                            {
                                #Connect to the computer
                                $sch.Connect($computer)

                                if ($recurse)
                                {
                                    $AllFolders = Get-AllTaskSubFolder -FolderRef $sch.GetFolder($folder) -recurse -ErrorAction stop
                                }
                                else
                                {
                                    $AllFolders = Get-AllTaskSubFolder -FolderRef $sch.GetFolder($folder) -ErrorAction stop
                                }

                                foreach ($fold in $AllFolders)
                                {
                                    #Get tasks in this folder
                                    $tasks = $fold.GetTasks(0)

                                    foreach ($task in $tasks)
                                    {
                                        # Extract helpful items from XML
                                        $Author = ([regex]::split($task.xml, '<Author>|</Author>'))[1]
                                        $UserId = ([regex]::split($task.xml, '<UserId>|</UserId>'))[1]
                                        $Description = ([regex]::split($task.xml, '<Description>|</Description>'))[1]
                                        $Action = ([regex]::split($task.xml, '<Command>|</Command>'))[1]
                                        $Arguments = ([regex]::split($task.xml, '<Arguments>|</Arguments>'))[1]
                                        $RunLevel = ([regex]::split($task.xml, '<RunLevel>|</RunLevel>'))[1]
                                        #$LogonType = ([regex]::split($task.xml,'<LogonType>|</LogonType>'))[1]

                                        # Convert state to status
                                        Switch ($task.State)
                                        {
                                            0
                                            {
                                                $Status = "Unknown"
                                            }
                                            1
                                            {
                                                $Status = "Disabled"
                                            }
                                            2
                                            {
                                                $Status = "Queued"
                                            }
                                            3
                                            {
                                                $Status = "Ready"
                                            }
                                            4
                                            {
                                                $Status = "Running"
                                            }
                                        }

                                        # Output the task details
                                        if (-not $exclude -or $task.Path -notmatch $Exclude)
                                        {
                                            $task | Select-Object @{ label = "ComputerName"; expression = { $computer } },
                                            Name,
                                            Path,
                                            Enabled,
                                            @{ label = "Action"; expression = { $Action } },
                                            @{ label = "Arguments"; expression = { $Arguments } },
                                            @{ label = "UserId"; expression = { $UserId } },
                                            LastRunTime,
                                            NextRunTime,
                                            @{ label = "Status"; expression = { $Status } },
                                            @{ label = "Author"; expression = { $Author } },
                                            @{ label = "RunLevel"; expression = { $RunLevel } },
                                            @{ label = "Description"; expression = { $Description } },
                                            NumberOfMissedRuns

                                            #if specified, output the results in importable XML format
                                            if ($path)
                                            {
                                                $xml = $task.Xml
                                                $taskname = $task.Name
                                                $xml | Out-File $( Join-Path $path "$computer-$taskname.xml" )
                                            }
                                        }
                                    }
                                }
                            }
                            catch
                            {
                                try
                                {
                                    Get-SchTask -computername $computer -folder $folder -ErrorAction stop
                                }
                                catch
                                {
                                    Write-Error "Could not pull scheduled tasks from $computer using schtasks.exe:`n$_"
                                    Continue
                                }
                            }
                        }

                        #otherwise, use schtasks
                        else
                        {
                            try
                            {
                                Get-SchTask -computername $computer -folder $folder -CompatibilityMode -ErrorAction stop
                            }
                            catch
                            {
                                Write-Error "Could not pull scheduled tasks from $computer using schtasks.exe:`n$_"
                                Continue
                            }
                        }

                    }
                    catch
                    {
                        Write-Error "Error pulling Scheduled tasks from $computer`: $_"
                        Continue
                    }
                }
            }
        }

        function FindLogs()
        {
            Param(
                [Parameter(Mandatory = $true)]
                [String]$TaskName
            )

            $stopCode = 201
            $errorCode = 202

            $filter = @"
<QueryList>
    <Query Id="0" Path="Microsoft-Windows-TaskScheduler/Operational">
    <Select Path="Microsoft-Windows-TaskScheduler/Operational">*[System[(EventID=$stopCode or EventID=$errorCode)] and EventData[Data[@Name="TaskName"]="\$TaskName"]]</Select>
    </Query>
</QueryList>
"@

            $errorCount = 0
            $erroredTasks = ""
            $returnCodeRegex = [regex]'return code (\d+)'

            try
            {
                $events = get-winevent -Oldest -FilterXML $filter -ErrorAction Stop

                $events = $events | Where-Object -FilterScript { $_.timecreated -gt $startTime }
                if ($events.Count -gt 0)
                {
                    foreach ($event in $events)
                    {
                        if ($event.id -eq $stopCode)
                        {
                            $event.message -match $returnCodeRegex | Out-Null
                            $returnCode = $matches[1]
                            if ($returnCode -ne 0)
                            {
                                $errorCount++
                            }
                        }

                        if ($event.id -eq $errorCode)
                        {
                            $errorCount++
                        }
                    }

                    if ($errorCount -gt 0)
                    {
                        $erroredTasks += "`tTask `"$TaskName`" failed $errorCount times`r`n"
                        return $erroredTasks
                    }
                }
            }
            catch [Exception]
            {
                if ($_.Exception -match "No events were found that match the specified selection criteria")
                {
                    #Write-Output "No events found";
                }
            }
        }

        $errorCount = 0
        $errorTasks = ""

        $tasks = Get-SchedTask | Where-Object -FilterScript { $_.Status -ne "Disabled" }
        $tasks | ForEach-Object -Process { $errorTasks += FindLogs $_.Name }

        if ($errorTasks -ne "")
        {
            Write-Log "  Check Failed"
            $results.Check32 = $results.Check32 + "Scheduled Tasks Check: Failed`r`n"
            $results.Check32 = $results.Check32 + $errorTasks
        }
        else
        {
            Write-Log "  Check Passed"
            $results.Check32 = $results.Check32 + "Scheduled Tasks Check: Passed`r`n"
        }
        Write-Log "Completed Check 32: Scheduled Tasks check"
    }

    return $sb.ToString()
}
