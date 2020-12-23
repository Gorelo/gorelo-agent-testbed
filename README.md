**Requirements:**
Download AWS CLI and configure a profile.

Download AWS powershell sdk. This is what the script uses. You will need to install powershell modules referenced once. 
https://docs.aws.amazon.com/powershell/latest/userguide/pstools-getting-set-up-windows.html

*Install-Module -Name AWS.Tools.EC2
*Install-Module -Name AWS.Tools.S3


**Launching instance:**
 .\launch-gorelo-agents.ps1 -action start -os win10 -MsiFileName gorelo-agent-shipondemand.msi -upload -AwsProfile gorelo-rmm-test

**Action:** start
**OS:** can be win10, win7, win2012 (more configs to come).
**MsiFileName:** This is the agent file you download form site.
**Upload (optional):** Only pass this parameter if you want to upload the agent file. Otherwise the launcher assumes the file is already in S3.
**Profile (optional):** Set this if you create a named profile when configuring aws cli. Otherwise it will just use the default.

This will launch the instance and provide you with a dns name you can connect over rdp. It will also install the agent you provided. If all goes well, you will see the system in the devices section!

**Stopping instance:**
.\launch-gorelo-agents.ps1 -action stop -Profile gorelo-rmm-test

**Action:** stop
**Profile (optional):** Set this if you create a named profile when configuring aws cli. Otherwise it will just use the default.


It will show you a list of instanceids and ask you to provide the instanceid you want to stop. Once you copy/paste one of the ids, it will terminate the instance. The code uses a local csv file to manage this list. You can always review that file to see a list of running instances.
