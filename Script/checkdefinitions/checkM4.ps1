$item = New-Object PSObject
$item | Add-Member -type NoteProperty -Name 'ID' -Value 'M4'
$item | Add-Member -type NoteProperty -Name 'Check' -Value 'SSLCheck'
$item | Add-Member -type NoteProperty -Name 'Description' -Value 'Check for expired or soon to be expired certificates'
$item | Add-Member -type NoteProperty -Name 'Target' -Value 'ServersAll'
$item | Add-Member -type NoteProperty -Name 'Type' -Value 'Local'
$item | Add-Member -type NoteProperty -Name 'Schedule' -Value 'Monthly'

$script:checks += $item

function script:CheckM4_SSLCheck() {
    $sb = [Scriptblock]::Create({
WriteLog "Starting Check M4: SSL check"
$results.CheckM4 = ""

$expiryperiod = 90

$errorCount = 0
$errorCertificates = ""

$certs = Get-ChildItem -Path Cert:\LocalMachine\My -Recurse
foreach ($cert in $certs)
{
    if ($cert.NotAfter -lt (Get-Date).AddDays($expiryperiod))
    {
        $name = $cert.Subject.Replace("CN=","")
        if ($cert.NotAfter -lt (Get-Date))
        {
            $expiry = "Certificate has expired."
        }
        else
        {
            $expiry = $cert.NotAfter.ToString()
        }
        $errorCertificates += "`tWindows - $($name): $expiry`r`n"
        $errorCount++
    }
}

if (Get-PSSnapin Microsoft.SharePoint.Powershell -EA 0)
{
    $SPcerts = Get-SPTrustedRootAuthority
    foreach ($cert in $SPcerts)
    {
        if ($cert.Certificate.NotAfter -lt (Get-Date).AddDays($expiryperiod))
        {
            $name = $cert.Certificate.Subject.Replace("CN=","")
            if ($cert.Certificate.NotAfter -lt (Get-Date))
            {
                $expiry = "Certificate has expired."
            }
            else
            {
                $expiry = $cert.Certificate.NotAfter.ToString()
            }
            $errorCertificates += "`tSharePoint - $($name): $expiry`r`n"
            $errorCount++
        }
    }
}

if (Get-PSSnapin Microsoft.SharePoint.Powershell -EA 0)
{
    $SPTIcerts = Get-SPTrustedIdentityTokenIssuer
    foreach ($cert in $SPTIcerts)
    {
        if ($cert.SigningCertificate.NotAfter -lt (Get-Date).AddDays($expiryperiod))
        {
            $name = $cert.Name
            if ($cert.SigningCertificate.NotAfter -lt (Get-Date))
            {
                $expiry = "Certificate has expired."
            }
            else
            {
                $expiry = $cert.SigningCertificate.NotAfter.ToString()
            }
            $errorCertificates += "`tSP Token Issuer - $($name): $expiry`r`n"
            $errorCount++
        }
    }
}

if ($errorCertificates -ne "")
{
    WriteLog "  Check Failed"
    $results.CheckM4 = $results.CheckM4 + "SSL Check: Failed`r`n"
    $results.CheckM4 = $results.CheckM4 + $errorCertificates
}
else
{
    WriteLog "  Check Passed"
    $results.CheckM4 = $results.CheckM4 + "SSL Check: Passed`r`n"
}
WriteLog "Completed Check M4: SSL check"
})

    return $sb.ToString()
}
