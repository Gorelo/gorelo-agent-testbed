Import-Module -Name AWS.Tools.EC2
Import-Module -Name AWS.Tools.S3

#userdata script
$userdatascript = "<powershell>
(new-object net.webclient).DownloadFile('https://gorelo-public.s3-us-west-2.amazonaws.com/{agent}','c:\{agent}')
msiexec.exe /i 'C:\{agent}' /qn
</powershell>"
$agentfile = ""
$agentfilepath = ""
$upload = $false
$instancelog = "$PSScriptRoot\instance.csv"

#list templates
$win10_template = "lt-07c3e2842f9b3420e"
$win2012_template = ""
$win7_template = "lt-0f574698849eca2f1"

#starts instances with the template.
function start-instance {
    param ($template)
    $encodeduserscript = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userdatascript))
    
    try {
        #upload file
        if($upload)
        {
            Write-Host "Uploading agent file $agentfile"
            Write-S3Object -BucketName gorelo-public -File $agentfilepath -Key $agentfile -CannedACLName public-read -ProfileName gorelo
        }

        #launch instance
        $launchspecs = New-Object -TypeName Amazon.EC2.Model.LaunchTemplateSpecification
        $launchspecs.LaunchTemplateId = $template
        $reservation = New-Ec2Instance -LaunchTemplate $launchspecs -UserData $encodeduserscript -ProfileName gorelo  
        Write-Host "Started instance with reservation: " $reservation.ReservationId
        
        #Get Instance details
        $live = $false
        while(!$live)
        {
            $instances = (Get-EC2Instance -Filter @{Name = "reservation-id"; Values = $reservation.ReservationId} -ProfileName gorelo).Instances
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

    #stop instance
    try {
        if($instanceid -eq "all")
        {
            foreach($instance in $runningInstances)
            {
                Write-Host "Stopping $instance"
                Remove-EC2Instance -InstanceId $instance -ProfileName gorelo
                $remaininginstances = import-csv $instancelog | Where-Object InstanceId -ne $instance
                $remaininginstances | export-csv $instancelog -NoTypeInformation
            }
        }
        else {
            Write-Host "Stopping $instanceid"
            Remove-EC2Instance -InstanceId $instanceid -ProfileName gorelo
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

#Usage
if($args.Count -eq 0)
    {
        Write-Host "Please provide an OS name (win10, win7, win2012) and an action (start, stop)."
        Write-Host "If the action is start, please also provide the url for the MSI package."
        Write-Host "Example> start win7 https://mybucket.s3-us-west-2.amazonaws.com/my-location.msi"
        break
    }


#Actions (start or stop)
$action = $args[0]
switch($action)
{
    "start" {}
    "stop" { stop-instance 
            return        
            }
    default {Write-Host "Please provide an action to perform. (start or stop)"}
}

#Make sure that if the action is start, that a msi package is provided.
if($action -eq "start" -and $null -eq $args[2])
{
    Write-Host "Please provide a url for the msi package for this action and os"
    break
}
else
{
    $agentfile = $args[2]
    $agentfilepath = "$PSScriptRoot\$agentfile" 
    if(!(Test-Path $agentfilepath))
    {
        Write-Host "The filename $agentfilepath does not exist."
        return
    }
    $userdatascript = $userdatascript.Replace("{agent}", $agentfile)
    
    if($null -ne $args[3] -and $args[3] -eq "upload")
    {
        $upload = $true
    }
}


#OS Selection
$osSelection = $args[1]
switch($osSelection)
{
    "win7" { start-instance($win7_template, $win7_template_version) }
    "win10" { start-instance($win10_template, $win10_template_version) }
    "win2012" { start-instance($win2012_template, $win2012_template_version) }
    "all" {}
    default {Write-Host "Please provide OS name or all"}
}



 
