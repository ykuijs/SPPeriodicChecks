$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '1'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'QuickEnvCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Quick Environment Check'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'URLs'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Remote'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check1_QuickEnvCheck() {
    WriteLog "    Starting Check 1: Quick Environment check"
    if ($results.Remote -eq $null)
    {
        $results.Remote = @{}
    }
    
    $results.Remote.Check1 = ""
    $errorCount = 0
    $errorURL = ""

    $credential = New-Object System.Net.NetworkCredential($cred.UserName, $cred.Password)

    foreach ($url in $urls)
    {
        WriteLog "      Processing url `"$($url.URL)`""
        try
        {
            #Actually making the request using the credentials and other properties
            $request = [System.Net.WebRequest]::Create($url.URL) 
            $request.Credentials = $credential
            $request.UserAgent = "Mozilla/5.0 (compatible; MSIE 11.0; Windows NT; Windows NT 6.1; en-US"
            $request.Headers.Add("X-FORMS_BASED_AUTH_ACCEPTED", "f")    
            $request.Method = "GET" 
            $request.Accept = "text/html, application/xhtml+xml, */*"

            $response = $request.GetResponse()
            $stream = New-Object System.IO.StreamReader($response.GetResponseStream())
            $html = $stream.ReadToEnd()

            #$result = Invoke-WebRequest -Uri $url.URL -UseDefaultCredentials
            if ($response.Headers -contains "SharePointError")
            {
                #SharePointError header found, check NOT OK
                if ($errorURL -ne "")
                {
                    $errorURL += ", "
                }
                $errorURL += "$($url.URL) (Errorpage was returned)"
                $errorCount++
            }
        }
        catch
        {
            [System.Net.HttpWebResponse] $resp = [System.Net.HttpWebResponse] $_.Exception.Response  
            Write-Host $response.StatusCode -ForegroundColor Red 

            #Error occurred during retrieving URL, check NOT OK
            if ($errorURL -ne "")
            {
               $errorURL += ", "
            }
            $errorURL += "$($url.URL) (HTTP Error: $($response.StatusCode))"
            $errorCount++
        }
        finally
        {
            if ($null -ne $stream)
            {
                $stream.Dispose()
            }
            $response.Dispose()
        }
    }

    if ($errorCount -gt 0)
    {
        $results.Remote.Check1 = $results.Remote.Check1 + "URL Check: $errorCount url(s) failed`r`n"
        $results.Remote.Check1 = $results.Remote.Check1 + "`tURL's: $errorURL`r`n"
    }
    else
    {
        $results.Remote.Check1 = $results.Remote.Check1 + "URL Check: Passed`r`n"
    }
    WriteLog "    Completed Check 1: Quick Environment check"
}
