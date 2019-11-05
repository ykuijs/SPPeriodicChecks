$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'W4'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'AccessCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check who has had access to the servers in the last week'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Weekly'

$script:checks += $item

function script:CheckW4_AccessCheck()
{
    $sb = [Scriptblock]::Create( {
            WriteLog "Starting Check W4: Access check"
            $results.CheckW4 = ""

            Function Get-DisplayName ($strUserName)
            {
                $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]'')
                $searcher.Filter = "(&(objectClass=User)(samAccountName=$strUserName))"
                $result = $searcher.FindOne()

                if ($null -eq $result)
                {
                    return $null
                }
                else
                {
                    return $result.GetDirectoryEntry().displayName
                }
            }

            # Filter:
            #   Event ID's: 4624 and 4625
            #   Time frame: One week back
            #   LogonTypes: 2, 7, 9, 10 and 11
            #     http://www.windowsecurity.com/articles-tutorials/misc_network_security/Logon-Types.html

            [xml]$FilterXML = @"
<QueryList>
  <Query Id="0" Path="Security">
    <Select Path="Security">*[System[(EventID=4624 or EventID=4625) and TimeCreated[timediff(@SystemTime) &lt;= 604800000]]] and *[EventData[(Data[@Name='LogonType'] = '2') or (Data[@Name='LogonType'] = '7') or (Data[@Name='LogonType'] = '9') or (Data[@Name='LogonType'] = '10') or (Data[@Name='LogonType'] = '11')]]</Select>
  </Query>
</QueryList>
"@

            $log = Get-WinEvent -FilterXml $FilterXML -ErrorAction SilentlyContinue

            $loggedOnUsers = @()
            foreach ($logItem in $log)
            {
                switch ($logItem.Id)
                {
                    4624
                    {
                        #$logonType = $logItem.Properties[8].Value
                        $user = $logItem.Properties[5].Value
                    }
                    4625
                    {
                        #$logonType = $logItem.Properties[10].Value
                        $user = $logItem.Properties[5].Value
                    }
                }

                if (-not $loggedOnUsers.Contains($user))
                {
                    $loggedOnUsers += $user
                }
            }

            # Sort array alphabetically
            [Array]::Sort([array]$loggedOnUsers)

            # Process array and generate output
            $users = ""
            foreach ($loggedOnUser in $loggedOnUsers)
            {
                $displayName = Get-DisplayName $loggedOnUser
                if ($null -eq $displayName)
                {
                    $displayName = $loggedOnUser
                }

                if ($users -eq "")
                {
                    $users += "$displayName ($loggedOnUser)"
                }
                else
                {
                    $users += ", $displayName ($loggedOnUser)"
                }
            }

            $results.CheckW4 = "Logged on users:`r`n" + $users
            WriteLog "Completed Check W4: Access check"
        })

    return $sb.ToString()
}
