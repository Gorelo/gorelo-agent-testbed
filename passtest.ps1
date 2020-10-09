function generatepass()
{
    $pass = [System.Web.Security.Membership]::GeneratePassword(16, 4)
    $pass
    $securepass = $pass | ConvertTo-SecureString -AsPlainText -Force
    return $securepass
}

$newpass = generatepass
$newpass