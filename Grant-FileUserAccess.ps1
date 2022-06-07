Elevate-NoAdmin $PSCommandPath

$Paths = @()
while ($true)
{
    $Path = (Read-Host "Enter file/folder path").Trim('"')
    if ($Path -in 'exit','') { break }
    $Paths += $Path
}

$userAccount = [Security.Principal.NTAccount]$Env:USERNAME
$accessRule = [Security.AccessControl.FileSystemAccessRule]::new($userAccount, "FullControl", "Allow")

Write-Host "`n"
foreach ($Path in $Paths)
{
    $acl = Get-Acl $Path
    $acl.SetOwner($userAccount)
    $acl.SetAccessRule($accessRule)
    Set-Acl $Path -AclObject $acl
    
    if ($Error.Count -eq 0)
    {
        Write-Host "$Env:USERNAME was set as owner and granted FullControl for '$((Get-Item $Path -Include "*").Name)'."
    }
}

Pause-Exit "`n"
