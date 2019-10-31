#requires -version 4.0

<#  
.SYNOPSIS  
    Running various SharePoint environment checks to validate the environment doesn't have any issues.
.DESCRIPTION  
    This script performs various SharePoint checks to validate that the SharePoint servers and environment
    doesn't have any issues. The script usually runs once a day and sends an e-mail report to a configured
    e-mail address.
    When started, the script reads its config from a few XML files and then loads all scripts from the
    checkdefinitions folder. A check can run in two modes:
    - Local  : On the SharePoint server
    - Remote : From the check server
    For troubleshooting purposes, a log file is created. Both on the source server and on each checked target
    servers.
.PARAMETER Full
    Switch parameter to force the execution of all checks
.PARAMETER Config
    Specify a custom configuration XML file instead of the default config.xml one.
.EXAMPLE
    .\RunPeriodicChecks.ps1
    Run the script
.REQUIRED_FILE
    .\config.xml
    Configuration file for the script
.REQUIRED_FILE
    .\checkdefinitions\*.ps1
    Individual check files, which are used to determine which checks need to be run and how to run them
.REQUIRED_FILE
    .\config\servers.txt
    Configuration file with all servers, farms and roles
.REQUIRED_FILE
    .\config\urls.txt
    Configuration file with all urls which need to be checked
.REQUIRED_FILE
    .\config\excludedpatches.txt
    Configuration file with all patches that have to be excluded from the MBSA reporting
.NOTES  
    File Name     : RunPeriodicChecks.ps1
    Author        : Yorick Kuijs
    Version       : 1.0.15
	Last Modified : 15-7-2019
.EXITCODES
    0 : No errors encountered
    10: Cannot find config.xml file
    20: Config.xml does not match schema
    30: Incorrect server configuration
    40: Error during creating report folder
    50: Invalid email addresses specified in config.xml file
    60: No password configured in config.xml file
    70: Configuration folder not found
    80: Specific configuration file not found
.CHANGES
    v1.0 - Initial release
    v1.1 - Added ServersSQL parameter
    v1.2 - Added timeout to Wait-Job, so it won't wait indefinitely. Corrected some code styling issues (config.xml changes)
    v1.3 - Added errored server logging
    v1.4 - Updated error logging and fixed issue in check W4
    v1.5 - Added Group membership test, updated checks 1 and W4
    v1.6 - Improved job logging (added job duration)
    v1.7 - Added Policy Compliance check (Large Lists and Versioning limits)
         - Added option to store report on disk (config.xml changes)
         - Added XML validation
    v1.8 - Added NULL check to check 21
    v1.9 - Added new check (17, ServiceApp status)
    v1.10 - Updated documentation (MBSA check and CredSSP prereqs), fixed naming issue in check 17
    v1.11 - Added possibility to use multiple email addresses, separated with comma
          - Added check for valid email address
          - Improved script relative path support. The script now ensures all files and folders are found in the script folder
          - Added validation of server configuration
          - Added exitcodes
          - Added information about debug the script to the documentation
          - Added Distributed Cache check
    v1.12 - Improved MBSA check logging to show reason of a failed scan
          - Fixed script duration per server calculation issue
          - Updated wait procedure to display how many servers have completed
          - Updated MBSA check to leave the reports when Debug is set to True
          - Added ".NET v4.0" and ".NET v4.0 Classic" application pools to default ignored application pools
          - Added check to validate if the user has sufficient permissions to use PowerShell with SharePoint (Only for servers where Role=SP)
          - Added check if SharePoint plugin exists (Only for servers where Role=SP)
          - Added check if Distributed Cache module can be found
    v1.13 - Added possibility to configure CC and BCC addresses as report recipients
    v1.14 - Added Full parameter to enable the possiblity to force run all checks
          - Updated Distributed Cache check (check 18) to first validate if the DC is actually running on the specified server
          - Updated URLCheck (check 1) to allow authentication against an ADFS/Windows Claims environment
    v1.15 - Removed obsolete parameter Search String in url.txt file
          - Added folder and file checks to make sure required configuration files really exist
          - Added Config parameter to enable the possibility to specify custom configuration file
          - Improved "Failed Timer Jobs" check to make it more efficient
          - Minor bugfixes
    v1.16 - Fixed bug with reading config file, introduces in v1.15

.LINK
	N/A
#>

[CmdletBinding()]
param(
    [Parameter()]
    [Switch]
    $Full = $false,

    [Parameter()]
    [System.String]
    $Config = "config.xml"
)

function WriteLog()
{
# Logging function - Write logging to screen and log file
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $message
    )
    $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host -Object "$date - $message"
    Add-Content -Path $logfile -Value "$date - $message"
}

function Validate-XML()
{
# Validate XML Schema based on inline schema
    param (
        [System.String]
        $xmlFileName
    )

    # Get the file
    $XmlFile = Get-Item -Path $xmlFileName

    # Keep count of how many errors there are in the XML file
    $script:errorCount = 0

    # Perform the XSD Validation
    $readerSettings = New-Object -TypeName System.Xml.XmlReaderSettings
    $readerSettings.ValidationType = [System.Xml.ValidationType]::Schema
    $readerSettings.ValidationFlags = [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessInlineSchema -bor `
                                      [System.Xml.Schema.XmlSchemaValidationFlags]::ProcessSchemaLocation
    $readerSettings.add_ValidationEventHandler(
    {
        # Triggered each time an error is found in the XML file
        $Host.UI.WriteErrorLine("ERROR: Error found in XML: $($_.Message)`n")
        $script:errorCount++
    });
    $reader = [System.Xml.XmlReader]::Create($XmlFile.FullName, $readerSettings)
    while ($reader.Read()) { }
    $reader.Close()

    # Verify the results of the XSD validation
    if($script:errorCount -gt 0)
    {
        # XML is NOT valid
        return $false
    }
    else
    {
        # XML is valid
        return $true
    }
}

function Test-ValidConfiguration
{
    param (
        [Parameter(Mandatory=$true)]
        $ServerConfig
    )

    WriteLog "  Validating server configuration"

    $grouped = $ServerConfig | Sort-Object -Property Farm | Group-Object -Property Farm

    # Loop through each farm
    foreach ($group in $grouped)
    {
        # Check if a Central Admin is specified for the farm
        $caservers = $group.Group | Where-Object -FilterScript { $_.centraladmin -eq "yes" }
        if ($null -eq $caservers)
        {
            WriteLog "**** [ERROR] No central admin specified for farm $($group.Name)"
            exit 30
        }

        # Check if each Central Admin server is has the SharePoint role configured
        $incorrectcaservers = $caservers | Where-Object -FilterScript { $_.role -ne "SP" }
        if ($null -ne $incorrectcaservers)
        {
            WriteLog "**** [ERROR] Central admin role was specified on a non-SharePoint server for farm $($group.Name)"
            exit 30
        }

        # Check if at least one SharePoint server is specified for the farm
        $spservers = $group.Group | Where-Object -FilterScript { $_.role -eq "SP" }
        if ($null -eq $spservers)
        {
            WriteLog "**** [ERROR] No SharePoint servers specified for farm $($group.Name)"
            exit 30
        }
        WriteLog "    Correct server configuration for farm $($group.Name)"
    }
    WriteLog "  Completed validating server configuration"
}

function Validate-EmailAddress
{
# Returns if a string is a valid email address. Will also check all the elements of an array of email addresses.
    param
    (
        [Parameter(Mandatory=$true)]
        [System.String]
        $EmailAddress
    )

    WriteLog "    Validating email address $EmailAddress"

    try
    {
        New-Object -TypeName System.Net.Mail.MailAddress($EmailAddress)
        return $true
    }
    catch
    {
        WriteLog "      [ERROR] Email address $EmailAddress is invalid. Skipping address."
        return $false
    }
}

function ReadConfiguration()
{
# Read configuration function - Read the configuration from a CSV input file and store it in the specified variable
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $ConfigFile
    )

    WriteLog "  Reading $ConfigFile"
    if (Test-Path -Path $ConfigFile)
    {
        $content = Import-Csv -Path $ConfigFile
        #Set-Variable -Name $VarName -Value $content -Scope Script
        WriteLog "  Completed reading $ConfigFile"
        return $content
    }
    else
    {
        $Host.UI.WriteErrorLine("[ERROR]: Configuration file $ConfigFile not found! Please make sure the file exists")
        exit 80
    }
}

function ReadCheckFiles()
{
# Read Check file function - Read and import all Check Definition files from the checkdefinitions folder.
    param ()

    WriteLog "  Reading check definitions"
    $checkdefinitionsFolder = Join-Path -Path $scriptpath -ChildPath "checkdefinitions\*.ps1"
    foreach ($definition in Get-Item -Path $checkdefinitionsFolder)
    {
        WriteLog "    Reading check definition: $($definition.Name)"
        . $definition
    }
    WriteLog "  Completed reading check definitions"
}

function InitializeScriptVariable()
{
# Variable initialization function - Initialize the scripts variables with the loading of the required SharePoint plugin
    param
    (
        [parameter(Mandatory = $true)]
        [System.Array]
        $servers
    )

    WriteLog "  Initialize Scripts"
    foreach ($server in $servers)
    {
        $scripts.($server.servername) = "`$logpath = `"$remoteLogPath`"`r`nif (-not(Test-Path `$logpath)) { `$null = New-Item `$logpath -type directory }`r`n`r`n`$date = Get-Date -Format `"yyyyMMdd`"`r`n`$logfile = Join-Path `$logpath `"PeriodicChecks-`$(`$env:COMPUTERNAME)-`$date.log`"`r`n`r`nfunction WriteLog() {`r`n`tparam`r`n`t(`r`n`t`t[parameter(Mandatory = `$true)] [System.String] `$message`r`n`t)`r`n`t`$date = Get-Date -format `"yyyy-MM-dd HH:mm:ss`"`r`n`tAdd-Content -Path `$logfile `"`$date - `$message`"`r`n}`r`n`r`n`$results=@{}`r`n`$starttime = (Get-Date)`r`n`r`n"
        if ($server.role -eq "SP")
        {
            $scripts.($server.servername) = $scripts.($server.servername) + `
                                            "if (`$null -eq (Get-PSSnapin -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue)) {`r`n`tif (`$null -ne (Get-PSSnapin -Registered -Name Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue))`r`n`t{`r`n`t`tAdd-PSSnapin Microsoft.SharePoint.PowerShell -ErrorAction SilentlyContinue`r`n`t}`r`n`telse`r`n`t{`r`n`t`treturn `"[ERROR] ERROR LOADING POWERSHELL PLUGIN`"`r`n`t}`r`n}`r`n`r`n" + `
                                            "`$farm = Get-SPFarm -ErrorAction SilentlyContinue`r`nif (`$null -eq `$farm) {`r`n`tWriteLog `"[ERROR] Error connecting to farm. Check if you have the correct permissions`"`r`n`treturn `"[ERROR] ERROR CONNECTING TO FARM`"`r`n}`r`n`r`n"
        }
        $checkServer.($server.servername) = $false
    }
    WriteLog "  Completed Initialize Scripts"
}

function FinalizeScriptVariable()
{
# Finalize the script variables function - Finalize the scripts variable to make sure it returns the gathered information
    param
    (
        [parameter(Mandatory = $true)]
        [System.Array]
        $servers
    )

    WriteLog "  Finalize Scripts"
    foreach ($server in $servers)
    {
        $scripts.($server.servername) = $scripts.($server.servername) + "`r`nreturn `$results`r`n"
    }
    WriteLog "  Completed Finalize Scripts"
}

function GenerateFunctionName()
{
# Check function name generation function - Generate the check function names, to they can be executed by the AddCheckscriptForServer function
    param
    (
        [parameter(Mandatory = $true)]
        [PSCustomObject]
        $check
    )

    return "Check$($check.ID)_$($check.Check)"
}

function AddCheckscriptForServer()
{
# Add check script for a specific server function - Add the check script to the scripts variable for the specified server
    param
    (
        [parameter(Mandatory = $true)]
        [PSCustomObject]
        $check,
        
        [parameter(Mandatory = $true)]
        [string]
        $server
    )

    WriteLog "        Start AddCheckscriptForServer"
    
    WriteLog "          Check is $($check.Check)"
    $functionName = GenerateFunctionName $check
    $checkscript  = & $functionName

    $scripts.$server     = $scripts.$server + $checkscript.ToString()
    $checkServer.$server = $true

    WriteLog "        Completed AddCheckscriptForServer"
}

function GenerateScripts()
{
# Generate check scripts function - Generate the check scripts for a specific check
    param (
        [System.Array]
        $localChecks
    )
    WriteLog "  Start generating check scripts for all local checks"

    foreach($check in $localChecks)
    {
        WriteLog "    Generating check scripts for $($check.ID) - $($check.Description)"
        switch ($check.Target.ToLower())
        {
            "farm" {
                # Get all available farms
                $farms = $ServerConfig.farm | Sort-Object | Get-Unique

                # Loop through each farm
                foreach($farm in $farms)
                {
                    WriteLog "    Processing farm `"$farm`""
                    # Find the Central Admin server in the specific farm
                    $servers = $ServerConfig | Where-Object -FilterScript { $_.farm -eq $farm } `
                                             | Where-Object -FilterScript { $_.centraladmin -eq "yes" } `
                                             | Select-Object -First 1
                    $caserver = $servers.servername

                    AddCheckscriptForServer $check $caserver
                }
            }
        
            "serverssp" {
                # Get all SharePoint servers
                $servers = $ServerConfig | Where-Object -FilterScript { $_.role -eq "SP" }
            
                # Loop through each server
                foreach($server in $servers)
                {
                    WriteLog "      Processing server `"$($server.servername)`""
                    AddCheckscriptForServer $check $server.servername
                }
            }
        
            "serverssql" {
                # Get all SQL servers
                $servers = $ServerConfig | Where-Object -FilterScript { $_.role -eq "SQL" }
            
                # Loop through each server
                foreach($server in $servers)
                {
                    WriteLog "      Processing server `"$($server.servername)`""
                    AddCheckscriptForServer $check $server.servername
                }
            }
            
            "serversall" {
                # Loop through each server
                foreach($server in $ServerConfig)
                {
                    WriteLog "      Processing server `"$($server.servername)`""
                    AddCheckscriptForServer $check $server.servername
                }            
            }
        
            "urls" { 
                # Loop through each URL
                foreach($url in $urls)
                {
                    WriteLog "      Processing url `"$($url.URL)`""
                    #Remote Check, so do nothing
                }            
            }
        }
        WriteLog "    Completed generating scripts"
        WriteLog " "
    }
    WriteLog "  Completed generating check scripts for all local checks"
}

function RunScripts()
{
# Run check scripts function - Run all check scripts on all servers as a job
    param (
        [System.Management.Automation.PSCredential]
        $credential
    )

    WriteLog "  Start running the scripts on the servers"
    $jobs = @()
    foreach($server in $scripts.Keys)
    {
        WriteLog "    Running script on server $server"

        $scriptblock = [ScriptBlock]::Create($scripts.$server)
        if($checkServer.$server)
        {
            try
            {
                $session = New-PSSession -ComputerName $server -Credential $credential -Authentication CredSSP -Name "SharePoint.PeriodicChecks" -ErrorAction Stop
                $job = Invoke-Command -Session $session -ScriptBlock $scriptblock -Verbose -AsJob
                $jobs += $job
            }
            catch
            {
                WriteLog "[ERROR] An error occurred while creating the remote session: $($_.Exception.Message)"

                $script:erroredServersCount++
                if ($script:erroredServers -eq "")
                {
                    $script:erroredServers = $server
                }
                else
                {
                    $script:erroredServers += ", " + $server
                }
            }
        }

        if ($debug -eq $true)
        {
            $debugpath = Join-Path -Path $scriptpath -ChildPath "Debug"
            if (-not(Test-Path -Path $debugpath))
            {
                $null = New-Item -Path $debugpath -Type directory
            }
            
            $debugfile = Join-Path -Path $debugpath -ChildPath "$server.txt"
            if (Test-Path $debugfile)
            {
            `	Remove-Item -Path $debugfile
            }
            Add-Content -Path $debugfile -Value $scripts.$server
        }
    }

    WriteLog "    Waiting for scripts to finish"
    if ($jobs.Length -gt 0)
    {
        $sleep = 30
        $maxcount = $remoteTimeOut / $sleep

        $count = 0
        do
        {
            $date = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            Write-Output -InputObject "$date - Completed $(($jobs | Where-Object -FilterScript { $_.State -ne "Running" }).Count) of $($jobs.Count) servers"
            $count++
            Start-Sleep -Seconds $sleep
        }
        until (($jobs | Where-Object -FilterScript { $_.State -eq "Running" }).Count -eq 0 -or $count -ge $maxcount)
    }

    foreach ($job in $jobs)
    {
        $server = $job.Location
        $jobState = $job.State

        switch ($jobState)
        {
            "Completed" {
                $results.$server = Receive-Job -Job $job
                if ($results.$server -is [System.String] -and $results.$server -like "*[ERROR]*")
                {
                    WriteLog "      [ERROR] Error while executing script. Error message: $($results.$server)"
                    $script:erroredServersCount++
                    if ($script:erroredServers -eq "")
                    {
                        $script:erroredServers = $server
                    }
                    else
                    {
                        $script:erroredServers += ", " + $server
                    }
                }
            }
            "Running" {
                WriteLog "      [ERROR] Time-out occurred during check of server $server - Job state is Running"

                $script:erroredServersCount++
                if ($script:erroredServers -eq "")
                {
                    $script:erroredServers = $server
                }
                else
                {
                    $script:erroredServers += ", " + $server
                }
            }
            "Failed" {
                WriteLog "      [ERROR] Error occurred during check of server $server - Job state is Failed"
                $jobresult = $job.ChildJobs[0].JobStateInfo.Reason.ErrorRecord
                WriteLog "        Error message: $jobresult"

                $script:erroredServersCount++
                if ($script:erroredServers -eq "")
                {
                    $script:erroredServers = $server
                }
                else
                {
                    $script:erroredServers += ", " + $server
                }
            }
            Default {
                WriteLog "      [ERROR] Error occurred during check of server $server - Job state is $jobState"

                $script:erroredServersCount++
                if ($script:erroredServers -eq "")
                {
                    $script:erroredServers = $server
                }
                else
                {
                    $script:erroredServers += ", " + $server
                }
            }
        }

        if ($null -eq $job.PSEndTime)
        {
            WriteLog "    Completed running script on server $server (Duration: Still running...)"
        }
        else
        {
            $jobDuration = "{0:N0}" -f ($job.PSEndTime - $job.PSBeginTime).TotalSeconds
            WriteLog "    Completed running script on server $server (Duration: $jobDuration seconds)"
        }

        $null = Remove-Job -Job $job
    }

    # Clean up all open sessions
    try
    {
        Get-PSSession -Name "SharePoint.PeriodicChecks" | Remove-PSSession
    }
    catch
    {
        WriteLog "    [ERROR] Error while cleaning up remote sessions"
    }

    WriteLog "  Completed running the scripts on the servers"
    WriteLog " "
}

function RunRemoteChecks()
{
# Run all remote checks function - Run all remote checks on all servers / environments
    param (
        [System.Array]
        $remoteChecks
    )
    WriteLog "  Start executing remote checks"

    foreach($check in $remoteChecks)
    {
        WriteLog "    Executing remote check $($check.ID) - $($check.Description)"

        $functionName = GenerateFunctionName $check

        switch ($check.Target.ToLower())
        {
            "farm" {
                # Get all available farms
                $farms = $ServerConfig.farm | Sort-Object | Get-Unique

                # Loop through each farm
                foreach($farm in $farms)
                {
                    WriteLog "    Processing farm `"$farm`""
                    # Find the Central Admin server in the specific farm
                    $servers = $ServerConfig | Where-Object -FilterScript { $_.farm -eq $farm } `
                                             | Where-Object -FilterScript { $_.centraladmin -eq "yes" }
                    $caserver = $servers.servername

                    & $functionName $servers
                }
            }
        
            "serverssp" {
                # Get all SharePoint servers
                $servers = $ServerConfig | Where-Object -FilterScript { $_.role -eq "SP" }

                & $functionName $servers
            
                # Loop through each server
                foreach($server in $servers)
                {
                    WriteLog "      Processing server `"$($server.servername)`""
                }
            }
        
            "serverssql" {
                # Get all SQL servers
                $servers = $ServerConfig | Where-Object -FilterScript { $_.role -eq "SQL" }

                & $functionName $servers
            
                # Loop through each server
                foreach($server in $servers)
                {
                    WriteLog "      Processing server `"$($server.servername)`""
                }
            }

            "serversall" {
                # Loop through each server
                & $functionName $ServerConfig
            }
        
            "urls" { 
                # Loop through each URL
                & $functionName
            }
        }
        WriteLog "    Completed remote check"
        WriteLog " "
    }
    WriteLog "  Completed executing remote checks"
}

function AnalyzeResults()
{
# Analyze results function - Analyze the results from all checks and generate the report.
    param (
        [System.Array]
        $runChecks
    )

    WriteLog "  Start data analysis"
    $analysis = "<html>`r`n<head>`r`n  <title></title>`r`n"
    $analysis += "<style>table, th, td { border: 1px solid black; border-collapse: collapse; } th, td { padding: 10px; } th { background-color: #f1f1c1; } .failed {background-color: red;}</style>"
    $analysis += "</head>`r`n<body>`r`n"

    $analysis += "<h3>Summary</h3>`r`n"
    $analysis += "<table>`r`n<tr><td>Start time</td><td>$start</td></tr>`r`n"
    $analysis += "<tr><td>End time</td><td>$(Get-Date)</td></tr>`r`n</table>`r`n"
    $analysis += "</ br>`r`n"

    if ($script:erroredServersCount -gt 0)
    {
        $analysis += "<h3>Scan errors</h3>`r`n"
        $analysis += "<table>`r`n<tr><td>Error count</td><td>$script:erroredServersCount</td></tr>`r`n"
        $analysis += "<tr><td>Server names</td><td>$script:erroredServers</td></tr>`r`n</table>`r`n"
        $analysis += "</ br>`r`n"
    }
    else
    {
        $analysis += "<h3>Scan errors</h3>`r`n"
        $analysis += "No errors detected while running the script</ br>`r`n"
        $analysis += "</ br>`r`n"
    }

    foreach ($id in $runChecks.Id)
    {
        #Write-Output "ID: $id"
        $check = $checks | Where-Object -FilterScript { $_.Id -eq $id }
        $analysis += "<h2>Check $id - $($check.Description) - $($check.Schedule)</h2>`r`n"
        $analysis += "<table>`r`n<tr><th>Server</th><th>Result</th></tr>`r`n"

        foreach($server in $results.Keys)
        {
            if ($check.Target -eq "Farm")
            {
                $source = ($ServerConfig | Where-Object -FilterScript { $_.servername -eq $server }).farm
            }
            else
            {
                $source = $server
            }
            
            if ($null -ne $results.$server."Check$id")
            {
                $result = $results.$server."Check$id"
                $result = $result -replace "`r`n", "<br>"
                $result = $result -replace "`t", "&nbsp;&nbsp;"

                if ($result.ToLower() -like "* failed*")
                {
                    $analysis += "<tr><td>$($source)</td><td class=failed>$result</td></tr>`r`n"
                }
                else
                {
                    $analysis += "<tr><td>$($source)</td><td>$result</td></tr>`r`n"
                }
            }
        }
        $analysis += "</table>`r`n`r`n"
    }
    $analysis += "</body>`r`n</html>`r`n"

    Set-Variable -Name "report" -Value $analysis -Scope Script
    WriteLog "  Completed data analysis"
}

function ProcessReport()
{
# Process report information function
# - Send the generated report via e-mail to a specified e-mail address
# - Store the generated report to disk
    param (
        [System.String]
        $report
    )
    WriteLog "  Processing report"

    $date = Get-Date -Format "yyyy-MM-dd"
    if ($reportsViaEmail -eq $true)
    {
        WriteLog "    Sending report via e-mail. Debug = $debug"
        try
        {
            if ($debug -eq $true)
            {
                $debugreportfile = Join-Path -Path $scriptpath -ChildPath "report.htm"
                if (Test-Path -Path $debugreportfile)
                {
                `	Remove-Item -Path $debugreportfile
                }
            
                Add-Content -Path $debugreportfile -Value $report 
                WriteLog "      Report stored to $debugreportfile"
            }
            else
            {
                $params = @{
                    To         = $mailto
                    From       = $mailfrom
                    Subject    = "Periodic Checks Report $date"
                    SmtpServer = $smtpserver
                    Body       = $report 
                }

                if ($mailcc.Count -gt 0)
                {
                    $params.Add("CC",$mailcc)
                }

                if ($mailbcc.Count -gt 0)
                {
                    $params.Add("BCC",$mailbcc)
                }
                Send-MailMessage @params -BodyAsHtml -ErrorAction Stop
                
                $recipients = $mailto
                if ($mailcc.Count -gt 0)
                {
                    $recipients += $mailcc
                }

                if ($mailbcc.Count -gt 0)
                {
                    $recipients += $mailbcc
                }
                WriteLog "      Report send to $($recipients -join ", ")"
            }
            WriteLog "    Completed sending report via e-mail."
        }
        catch
        {
            WriteLog "[ERROR] Error while sending report e-mail: $($_.Exception.Message)"
        }
    }
    else
    {
        WriteLog "    Sending report via e-mail not required"
    }

    if ($reportsToDisk -eq $true)
    {
        WriteLog "    Storing report to disk"
        if (Test-Path -Path $reportfile)
        {
            WriteLog "      Report file already exists. Removing"
        `	Remove-Item -Path $reportfile
        }
            
        Add-Content -Path $reportfile -Value $report 
        WriteLog "      Report stored to $reportfile"
        WriteLog "    Completed storing report to disk"
    }
    else
    {
        WriteLog "    Storing report to disk not required"
    }

    WriteLog "  Completed processing report"
}


# -------------------- START SCRIPT --------------------

# Log variables
$invocation = (Get-Variable MyInvocation).Value
$scriptpath = Split-Path -Path $invocation.MyCommand.Path

# Read App Configuration
$configName = $Config.TrimEnd(".xml")
$configFile = Join-Path -Path $scriptpath -ChildPath $Config
if (Test-Path -Path $configFile)
{
    $appConfig  = [xml](Get-Content -Path $configFile)
    if (-not (Validate-XML -xmlFileName $configFile))
    {
        $Host.UI.WriteErrorLine("[ERROR]: Config file $configFile not valid! Please make sure it matches the schema!")
        exit 20
    }
}
else
{
    $Host.UI.WriteErrorLine("[ERROR]: Config file $configFile not found! Please make sure the file exists")
    exit 10
}

# Initialize logging
$date = Get-Date -Format "yyyyMMdd"
$logpath = Join-Path -Path $scriptpath -Child $appConfig.AppSettings.Logging.LogFolder
if (-not(Test-Path -Path $logpath))
{
    $null = New-Item -Path $logpath -ItemType directory
}

$logfile = Join-Path -Path $logpath -ChildPath "$($appConfig.AppSettings.Logging.LogPrefix)-$date.log"

WriteLog "****************************************************"
WriteLog "Starting periodic checks"
WriteLog "Start time: $start"
WriteLog "****************************************************"

WriteLog "Starting script preparations"


# Initialize script variables
$start               = Get-Date
$today               = $start
$scripts             = @{}
$results             = @{}
$checkServer         = @{}
$erroredServers      = ""
$erroredServersCount = 0

# Read config variables
$remoteLogPath = $appConfig.AppSettings.Logging.RemoteLogFolder

## MBSA variables
$MBSAPath         = $appConfig.AppSettings.MBSA.MBSAPath
$WSUSCabPath      = $appConfig.AppSettings.MBSA.WSUSCabPath # http://go.microsoft.com/fwlink/?LinkID=74689
$downloadWSUSFile = [System.Convert]::ToBoolean($appConfig.AppSettings.MBSA.DownloadWSUSFile)

## General variables
$debug = [System.Convert]::ToBoolean($appConfig.AppSettings.General.Debug)
$remoteTimeOut = $appConfig.AppSettings.General.RemoteTimeOut

## Reporting variables
$reportsToDisk = [System.Convert]::ToBoolean($appConfig.AppSettings.Reporting.ReportsToDisk)
if ($reportsToDisk -eq $true)
{
    $reportsFolder = $appConfig.AppSettings.Reporting.ReportsFolder
    if (Test-Path -Path $reportsFolder)
    {
        $reportsFolder = (Resolve-Path -Path $reportsFolder).Path
    }
    else
    {
        try
        {
            $reportsFolder = (New-Item -Path $reportsFolder -ItemType Directory).FullName
        }
        catch
        {
            WriteLog "**** [ERROR]: Error occurred during creating reports folder ($reportsFolder). Error message: $($_.Exception.Message)"
            exit 40
        }
    }
    $reportFile = Join-Path -Path $reportsFolder -ChildPath "CheckReport_$date.htm"
}

## Email variables
$reportsViaEmail = [System.Convert]::ToBoolean($appConfig.AppSettings.Email.SendReportsViaEmail)
if ($reportsViaEmail -eq $true)
{
    $mailto = @()
    foreach ($emailAddress in ($appConfig.AppSettings.Email.MailTo -split ","))
    {
        if (Validate-EmailAddress $emailAddress)
        {
            $mailto += $emailAddress
        }
    }

    $mailcc = @()
    if ($appConfig.AppSettings.Email.MailCC -ne "")
    {
        foreach ($emailAddress in ($appConfig.AppSettings.Email.MailCC -split ","))
        {
            if (Validate-EmailAddress $emailAddress)
            {
                $mailcc += $emailAddress
            }
        }
    }

    $mailbcc = @()
    if ($appConfig.AppSettings.Email.MailBCC -ne "")
    {
        foreach ($emailAddress in ($appConfig.AppSettings.Email.MailBCC -split ","))
        {
            if (Validate-EmailAddress $emailAddress)
            {
                $mailbcc += $emailAddress
            }
        }
    }
    if ($mailto.Count -eq 0)
    {
        WriteLog "**** [ERROR]: No valid To email addresses specified!"
        exit 50
    }
    $mailfrom   = $appConfig.AppSettings.Email.MailFrom
    $smtpserver = $appConfig.AppSettings.Email.SMTPServer
}

WriteLog "Starting checks"

# Read required input files
$configPath = Join-Path -Path $scriptpath -ChildPath $configName
if (Test-Path -Path $configPath)
{
    $urls            = ReadConfiguration (Join-Path -Path $configPath -ChildPath "urls.txt")
    $excludedpatches = ReadConfiguration (Join-Path -Path $configPath -ChildPath "patchexclusions.txt")
    $ServerConfig    = ReadConfiguration (Join-Path -Path $configPath -ChildPath "servers.txt")
    Test-ValidConfiguration -ServerConfig $ServerConfig
}
else
{
    $Host.UI.WriteErrorLine("[ERROR]: Configuration folder $configPath not found! Please make sure the folder exists")
    exit 70
}

$checks = @()

# Read the check definition files
ReadCheckFiles

InitializeScriptVariable $ServerConfig

WriteLog " "
$runChecks = $checks

if ($Full)
{
    WriteLog "Parameter Full specified, running all checks"
}
else
{
    WriteLog "Parameter Full NOT specified, only running applicable checks"
    # Check if weekly check and first Monday of the month
    if ($today.DayOfWeek -ne "Monday")
    {
        # Not Monday, filter Weekly checks
        $runChecks = $runChecks | Where-Object { $_.Schedule -ne "Weekly" }
    }
    else
    {
        WriteLog "Executing weekly checks"
    }

    if ($today.Day -gt 8 -or $today.DayOfWeek -ne "Monday")
    {
        # First Monday of each month
        $runChecks = $runChecks | Where-Object -FilterScript { $_.Schedule -ne "Monthly" }
    }
    else
    {
        WriteLog "Executing monthly checks"
    }

    if (($today.Month % 3 -ne 1) -or $today.Day -gt 8 -or $today.DayOfWeek -ne "Monday")
    {
        # First Monday of Januari, April, July or October
        $runChecks = $runChecks | Where-Object -FilterScript { $_.Schedule -ne "Quarterly" }
    }
    else
    {
        WriteLog "Executing quarterly checks"
    }
}

$localChecks = $runChecks | Where-Object -FilterScript { $_.Type -eq "Local" }
$remoteChecks = $runChecks | Where-Object -FilterScript { $_.Type -eq "Remote" }

GenerateScripts $localChecks

FinalizeScriptVariable $ServerConfig

if (-not ([String]::IsNullOrWhiteSpace($appConfig.AppSettings.Credentials.Password)))
{
    $pw = $appConfig.AppSettings.Credentials.Password | ConvertTo-SecureString
    $cred = New-Object -TypeName System.Management.Automation.PSCredential `
                       -ArgumentList $appConfig.AppSettings.Credentials.UserName, $pw
}
else
{
    WriteLog "**** [ERROR]: Error reading password from config file: No password specified! Please make sure a password is configured."
    exit 60
}

RunScripts $cred

RunRemoteChecks $remoteChecks

$report = ""
AnalyzeResults $runChecks

ProcessReport $report

WriteLog "Completed periodic checks"

$end = Get-Date
$diff = $end - $start
WriteLog "****************************************************"
WriteLog "End time: $end"
WriteLog "Duration: $([System.Math]::Round($diff.TotalSeconds)) seconds"
WriteLog "****************************************************"
WriteLog " "
