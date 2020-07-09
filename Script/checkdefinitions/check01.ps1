$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value '1'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'QuickEnvCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Quick Environment Check'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'URLs'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Remote'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Daily'

$script:checks += $item

function script:Check1_QuickEnvCheck()
{
    Write-Log "    Starting Check 1: Quick Environment check"

    $urls = Read-Configuration (Join-Path -Path $configPath -ChildPath 'urls.txt')

    if ($null -eq $results.Remote)
    {
        $results.Remote = @{ }
    }

    $results.Remote.Check1 = ""
    $errorCount = 0
    $errorURL = ""

    $credential = New-Object System.Net.NetworkCredential($cred.UserName, $cred.Password)

    foreach ($url in $urls)
    {
        Write-Log "      Processing url `"$($url.URL)`""
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
            $null = $stream.ReadToEnd()

            if ($response.Headers -contains "SharePointError")
            {
                #SharePointError header found, check NOT OK
                $errorURL += "$($url.URL) (Errorpage was returned)"
                $errorCount++
            }
        }
        catch
        {
            #Error occurred during retrieving URL, check NOT OK
            $errorURL += "$($url.URL) (HTTP Error: $($response.StatusCode))`r`n"
            $errorCount++
        }
        finally
        {
            if ($null -ne $stream)
            {
                $stream.Dispose()
            }

            if ($null -ne $response)
            {
                $response.Dispose()
            }
        }
    }

    if ($errorCount -gt 0)
    {
        $results.Remote.Check1 = $results.Remote.Check1 + "URL Check: $errorCount url(s) failed`r`n"
        $results.Remote.Check1 = $results.Remote.Check1 + "`t$errorURL"
    }
    else
    {
        $results.Remote.Check1 = $results.Remote.Check1 + "URL Check: Passed`r`n"
    }
    Write-Log "    Completed Check 1: Quick Environment check"
}
