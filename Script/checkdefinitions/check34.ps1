$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '34'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'GroupCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check if (admin) groups have certain members'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'urls'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Remote'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check34_GroupCheck()
{
    WriteLog "    Starting Check 34: Group check"
    if ($null -eq $results.Remote)
    {
        $results.Remote = @{ }
    }

    $results.Remote.Check34 = ""

    $errorCount = 0
    $errorGroup = ""

    # Get the users Distinguished Name
    function Get-DistinguishedName($strUserName)
    {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]'')
        $searcher.Filter = "(&(samAccountName=$strUserName))"
        $result = $searcher.FindOne()

        if ($null -eq $result)
        {
            return $null
        }
        else
        {
            return $result.GetDirectoryEntry().DistinguishedName
        }
    }

    function Get-ADGroup($strGroupName)
    {
        $searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]'')
        $searcher.Filter = "(&(objectClass=Group)(samAccountName=$strGroupName))"
        $result = $searcher.FindOne()

        return $result
    }

    WriteLog "      Reading groups configuration file"
    $ConfigFile = Join-Path -Path $scriptpath -ChildPath "config\groups.txt"
    $config = Import-Csv -Path $ConfigFile
    $uniquegroups = $config.groupname | Sort-Object | Get-Unique
    $uniqueusers = $config.useraccount | Sort-Object | Get-Unique

    $userDNs = @{ }
    foreach ($user in $uniqueusers)
    {
        $dn = Get-DistinguishedName $user
        if ($null -ne $dn)
        {
            $userDNs.$user = $dn
        }
    }

    foreach ($groupname in $uniquegroups)
    {
        WriteLog "      Processing group: $groupname"
        $group = Get-ADGroup $groupname
        $actualMembers = @()
        $desiredMembers = @()

        if ($null -eq $group)
        {
            $errorCount++
            if ($errorGroup -ne "")
            {
                $errorGroup += ", "
            }
            $errorGroup += $groupname
            break
        }
        else
        {
            foreach ($member in $group.Properties.Item("member"))
            {
                $actualMembers += $member
            }
        }

        $groupconfig = $config | Where-Object -FilterScript { $_.groupname -eq $groupname }
        foreach ($item in $groupconfig)
        {
            if ($userDNs.ContainsKey($item.useraccount))
            {
                $desiredMembers += $userDNs.$($item.useraccount)
            }
            else
            {
                $dn = Get-DistinguishedName $item.useraccount
                if ($null -ne $dn)
                {
                    $desiredMembers += $dn
                }
                else
                {
                    $desiredMembers += "CN=$($item.useraccount),DC=UNKNOWN,DC=ACCOUNT"
                }
            }
        }

        if (($null -ne $desiredMembers) -and ($null -ne $actualMembers))
        {
            $result = Compare-Object -ReferenceObject $desiredMembers -DifferenceObject $actualMembers
            if ($null -ne $result)
            {
                $errorCount++
                if ($errorGroup -ne "")
                { $errorGroup += ", "
                }
                $errorGroup += $groupname
            }
        }
    }

    if ($errorCount -gt 0)
    {
        WriteLog "      Check Failed"
        $results.Remote.Check34 = $results.Remote.Check34 + "Group Check: $errorCount group(s) failed`r`n"
        $results.Remote.Check34 = $results.Remote.Check34 + "`tGroups: $errorGroup`r`n"
    }
    else
    {
        WriteLog "      Check Passed"
        $results.Remote.Check34 = $results.Remote.Check34 + "Group Check: Passed`r`n"
    }
    WriteLog "    Completed Check 34: Group check"
}
