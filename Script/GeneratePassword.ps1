function Test-Credential
{
    <#
    .SYNOPSIS
        Takes a PSCredential object and validates it against the domain (or local machine, or ADAM instance).

    .PARAMETER cred
        A PScredential object with the username/password you wish to test. Typically this is generated using the Get-Credential cmdlet. Accepts pipeline input.

    .PARAMETER context
        An optional parameter specifying what type of credential this is. Possible values are 'Domain','Machine',and 'ApplicationDirectory.' The default is 'Domain.'

    .OUTPUTS
        A boolean, indicating whether the credentials were successfully validated.

    #>
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Management.Automation.PSCredential]$credential,
        [parameter()][validateset('Domain', 'Machine', 'ApplicationDirectory')]
        [string]$context = 'Domain'
    )
    begin
    {
        Add-Type -assemblyname system.DirectoryServices.accountmanagement
        $DS = New-Object System.DirectoryServices.AccountManagement.PrincipalContext([System.DirectoryServices.AccountManagement.ContextType]::$context)
    }
    process
    {
        $account = Split-Path -Path $credential.UserName -Leaf
        $DS.ValidateCredentials($account, $credential.GetNetworkCredential().password)
    }
}

$cred = Get-Credential

if (Test-Credential $cred)
{
    $cred.Password | ConvertFrom-SecureString | Out-File password.txt
    Write-Output "Password stored!"
}
else
{
    Write-Error "Specified credentials invalid"
}
