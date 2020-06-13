#params
param (
    [Parameter(Mandatory=$true, HelpMessage="Please provide an action")][string] $action,
    [string] $Profile = "default",
    [Parameter(HelpMessage="The OS must be win7, win10 or win2012")] [ValidateSet("win7", "win10", "win2012", "win2019")] [string]  $OS,
    [string] $MsiFileName,
    [switch] $Upload = $false
)

Import-Module -Name AWS.Tools.EC2
Import-Module -Name AWS.Tools.S3



#userdata script
$userdatascript = "<powershell>
(new-object net.webclient).DownloadFile('https://gorelo-public.s3-us-west-2.amazonaws.com/{agent}','c:\{agent}')
msiexec.exe /i 'C:\{agent}' /qn
</powershell>"

$agentfilepath = "$PSScriptRoot\$MsiFileName"
$instancelog = "$PSScriptRoot\instance.csv"

#template table
$launchTemplates = @{
    win10 = "lt-07c3e2842f9b3420e"
    win2012 = "lt-0d43678de0acf83c5"
    win2019 = "lt-03a39a8acbebfd81f"
    win7 = "lt-0f574698849eca2f1"
}

#starts instances with the template.
function start-instance {
    param ($template)
    $encodeduserscript = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdatascript))
    
    try {
        #upload file
        if($upload)
        {
            Write-Host "Uploading agent file $MsiFileName"
            Write-S3Object -BucketName gorelo-public -File $agentfilepath -Key $MsiFileName -CannedACLName public-read -ProfileName $Profile
        }

        #launch instance
        $launchspecs = New-Object -TypeName Amazon.EC2.Model.LaunchTemplateSpecification
        $launchspecs.LaunchTemplateId = $template
        $reservation = New-Ec2Instance -LaunchTemplate $launchspecs -UserData $encodeduserscript -ProfileName $Profile  
        Write-Host "Started instance with reservation: " $reservation.ReservationId
        
        #Get Instance details
        $live = $false
        while(!$live)
        {
            $instances = (Get-EC2Instance -Filter @{Name = "reservation-id"; Values = $reservation.ReservationId} -ProfileName $Profile).Instances
            if($instances.Count -gt 0 -and $instances[0].State.Name -eq "running")
            {
                Write-Host $instances[0].PublicDnsName $instances[0].InstanceId
                $instances[0] | Select-Object -Property LaunchTime,InstanceId,PublicDnsName | Export-Csv -Path $instancelog -NoTypeInformation -Append
                $live = $true
            }
            else
            {
                Start-Sleep -Seconds 5
            }    
        }    
    }
    catch {
        if($null -ne $_)
        {
            Write-Host $_
            return
        }
    }
}

#stops instances running in AWS.
function stop-instance(){
    
    #check for log file
    if(!(Test-Path $instancelog))
    {
        Write-Host "The filename $instancelog does not exist."
        return
    }

    #show list of instances to help select instance
    $runningInstances = Import-Csv $instancelog
    $runningInstances | Format-Table
    $instanceid = Read-Host -Prompt "Please provide Instanceid from the list above or type all"
    if($instanceid -eq "")
    {
        Write-Host "Need an instanceid to stop."
        return       
    }

    #stop instance
    try {
        if($instanceid -eq "all")
        {
            foreach($instance in $runningInstances)
            {
                Write-Host "Stopping $instance"
                Remove-EC2Instance -InstanceId $instance -ProfileName $Profile
                $remaininginstances = import-csv $instancelog | Where-Object InstanceId -ne $instance
                $remaininginstances | export-csv $instancelog -NoTypeInformation
            }
        }
        else {
            Write-Host "Stopping $instanceid"
            Remove-EC2Instance -InstanceId $instanceid -ProfileName $Profile
            $remaininginstances = import-csv $instancelog | Where-Object InstanceId -ne $instanceid
            $remaininginstances | export-csv $instancelog -NoTypeInformation
        }
    }
    catch {
        if($null -ne $_)
        {
            Write-Host $_
            return
        }

    }
}

if($action -eq "stop")
{
    stop-instance
    break
    
}

#Make sure that if the action is start, that a msi package is provided.
if($action -eq "start" -and $MsiFileName -eq "")
{
    Write-Host "Please provide a file name for the msi package. This will be used to bootstrap the agent."
    break
}
else
{
    if($upload -and !(Test-Path $agentfilepath))
    {
        Write-Host "The filename $agentfilepath does not exist."
        return
    }
    $userdatascript = $userdatascript.Replace("{agent}", $MsiFileName)
    
}

if($null -eq $launchTemplates[$os] )
{
    Write-Host "Please provide OS Name or all"
    return
}
else {
    start-instance($launchTemplates[$os])
    return
}



 
