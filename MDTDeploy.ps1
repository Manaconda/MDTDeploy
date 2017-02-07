#### AUTO ELEVATE
$myWindowsID=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal=new-object System.Security.Principal.WindowsPrincipal($myWindowsID)
 $adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
 if ($myWindowsPrincipal.IsInRole($adminRole))
   {
   $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)"
   $Host.UI.RawUI.BackgroundColor = "DarkBlue"
   clear-host
   }
else
   {
      $newProcess = new-object System.Diagnostics.ProcessStartInfo "PowerShell";
      $newProcess.Arguments = $myInvocation.MyCommand.Definition;
      $newProcess.Verb = "runas";
      [System.Diagnostics.Process]::Start($newProcess);
      exit
   }


$ProgressPreference='SilentlyContinue'



############ Settings
$ProgressPreference='SilentlyContinue'
$PSScriptRoot=Split-Path $script:MyInvocation.MyCommand.Path

clear
Write-Host "MDT Deployment Script." -ForegroundColor Yellow
Write-Host ""
$InstallDrive=Read-Host "Installation Drive"
$Task=Read-Host "[I]nstall or [U]pdate"
Write-Host ""
Write-Host "" 
Write-Host "Inspecting current configuration..."

#######
$RemInst=$InstallDrive + ":\RemoteInstall"


#### WDS ROLE
write-Host ""
Get-WindowsFeature -Name "WDS"
Get-WindowsFeature -Name "WDS-Deployment" 
Get-WindowsFeature -Name "WDS-Transport"
$WDSInstalled=Get-WindowsFeature -Name "WDS"
write-Host ""
write-Host ""

if ($WDSInstalled.InstallState -eq "Installed"){
Write-Host "WDS already installed." -ForegroundColor Green
}
else{
Write-Host "WDS not found.  Attempting install."
Add-WindowsFeature -Name "WDS" -IncludeAllSubFeature |Out-Null
}

#### WDS Config
$WDSInstalled=Get-WindowsFeature -Name "WDS"
if ($WDSInstalled.InstallState -ne "Installed"){
Write-Host "INSTALLATION FAILED.  PLEASE INSTALL MANUALLY." -ForegroundColor Red
exit
}
else{
Write-Host "WDS Installation OK" -ForegroundColor Green
}

Write-Host ""
Write-Host ""
if (Test-Path $RemInst){
Write-Host "WDS already initialised." -ForegroundColor Green}
else{
Write-Host "Creating directories and initialising WDS server."
sleep 2
wdsutil /initialize-server /reminst:$RemInst /authorize |Out-Null
}
if (Test-Path $RemInst){
Write-Host "WDS Initialisation OK" -ForegroundColor Green}
else{
Write-Host "Initialisation failed.  Please configure WDS." -ForegroundColor Red
exit
}

Write-Host "Setting WDS to respond to all client requests..."
sleep 2
WDSUTIL /Set-Server /AnswerClients:All >$null
Write-Host "Complete" -ForegroundColor Green

#### ADK
$needinstall=$false
Write-Host ""
Write-Host "Searching for Windows 10 ADK"
sleep 2
if (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool"){
Write-Host "User State Migration Tool found." -ForegroundColor Green}
else{
Write-Host "User State Migration Tool not found." -ForegroundColor Red
$needinstall=$true
}
sleep 1
if (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment"){
Write-Host "Windows Preinstallation Environment found." -ForegroundColor Green}
else{
Write-Host "Windows Preinstallation Environment not found." -ForegroundColor Red
$needinstall=$true
}
sleep 1
if (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools"){
Write-Host "Deployment Tools found." -ForegroundColor Green}
else{
Write-Host "Deployment Tools not found." -ForegroundColor Red
$needinstall=$true
}
sleep 2
if ($needinstall){
Write-Host ""
Write-Host "Attempting to install ADK features."
Start-Process "$PSScriptRoot\content\MDT\adksetup.exe" "/features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.UserStateMigrationTool /norestart /quiet /ceip off" -Wait
}

###did install complete?

if ((Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\User State Migration Tool") -and (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment") -and (Test-Path "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools")){
Write-Host "Windows ADK Installed" -ForegroundColor Green}
else{
Write-Host "ADK Installation failed.  Please install manually." -ForegroundColor Red
exit
}


#### MDT
if (Test-Path "C:\Program Files\Microsoft Deployment Toolkit\Bin\DeploymentWorkbench.msc"){
Write-Host "MDT installation detected."}
else{
Write-Host "Prerequisites OK" -ForegroundColor Green
Write-Host "Attempting to install MDT"
Start-Process "msiexec.exe" "/i $PSScriptRoot\content\MDT\MicrosoftDeploymentToolkit_x64.msi /quiet" -Wait
}
####check install
if (Test-Path "C:\Program Files\Microsoft Deployment Toolkit\Bin\DeploymentWorkbench.msc"){
Write-Host "MDT Installed OK" -ForegroundColor Green
}
else{
Write-Host "MDT Installation failed. Please install manually." -ForegroundColor Red
}


#### Setting up MDT
Write-Host ""
Write-Host ""
Write-Host "Creating Deployment share and adding to the Workbench."
$Path=$InstallDrive + ":\DeploymentShare"
$PSDriveName="DS001"
$Description="MDT Deployment Share"
$ShareName="DeploymentShare$"
 
Import-Module "C:\Program Files\Microsoft Deployment Toolkit\bin\MicrosoftDeploymentToolkit.psd1"
Remove-PSDrive $PSDriveName -ErrorAction SilentlyContinue
 
If (!(Test-Path $Path)) {
 New-Item -Path $Path -Type directory
 New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $Path -Description $Description -NetworkPath \\$env:COMPUTERNAME\$ShareName | add-MDTPersistentDrive >$null
 Write-host ""
 Write-host "New deployment directory created." -ForegroundColor Green
 Net Share $ShareName=$Path "/Grant:Everyone,Full" "/Remark:$Description" |out-null
 Write-host "Deplyment directory shared and permissions set." -ForegroundColor Green
 sleep 3
 }
else{
 Write-Host "Deployment Share already exists" -ForegroundColor Magenta
 Net Share $ShareName=$Path "/Grant:Everyone,Full" "/Remark:$Description" |out-null
 New-PSDrive -Name $PSDriveName -PSProvider "MDTProvider" -Root $Path -Description $Description -NetworkPath \\$env:COMPUTERNAME\$ShareName
}


write-host ""
write-host ""
Write-Host ""

Write-Host "MDT Install Complete." -ForegroundColor Green

$Import=Read-Host "Import DeploymentShare (y/n)"
if ($Import -eq "n"){
exit
}

Write-Host ""
$colItems = (Get-ChildItem $PSScriptRoot\Content\DeploymentShare -recurse | Measure-Object -property length -sum)
Write-Host "Local DeploymentShare size: " ("{0:N2}" -f ($colItems.sum / 1MB) + " MB")
Write-Host "This could take some time.  Please wait..."
$source=$PSScriptRoot + "\Content\DeploymentShare"
$destination=$InstallDrive + ":\DeploymentShare"
Remove-Item -Recurse -Force "$destination\*"
robocopy $source $destination /e /r:1 /w:1 /mt >$null
Write-host ""
Write-Host "Import complete."
Write-Host
Write-Host "Updating MDT configuration to match local environment."
Write-Host ""
sleep 4

$unc="\\$env:computername\DeploymentShare$"
$local=$InstallDrive + ":\DeploymentShare"
$domain=$env:USERDNSDOMAIN

Write-Host "Setting UNC Path to: $unc"
sleep 2
Write-Host "Setting local path to: $local"
sleep 2
Write-Host "Settting SLShare to: $unc\SLSLogs"
sleep 2
Write-Host "Setting DeployRoot to: $unc"
sleep 2
Write-Host "Setting local domain to: $domain"
sleep 2

(Get-Content $destination\control\settings.xml) | ForEach-Object { $_ -replace "WDS01", $env:computername } | Set-Content $destination\control\settings.xml
(Get-Content $destination\control\settings.xml) | ForEach-Object { $_ -replace "c:", ($InstallDrive + ":") } | Set-Content $destination\control\settings.xml
(Get-Content $destination\control\CustomSettings.ini) | ForEach-Object { $_ -replace "WDS01", $env:computername } | Set-Content $destination\control\CustomSettings.Ini
(Get-Content $destination\control\BootStrap.ini) | ForEach-Object { $_ -replace "WDS01", $env:computername } | Set-Content $destination\control\BootStrap.Ini
(Get-Content $destination\control\BootStrap.ini) | ForEach-Object { $_ -replace "Cuss.local", $domain } | Set-Content $destination\control\BootStrap.Ini

$RSATInstalled = Get-WindowsFeature RSAT

if ($RSATInstalled.InstallState -eq "Installed"){
Write-Host "RSAT detected.  Attempting to create deployment user." -ForegroundColor Green
New-ADUser WDS -ErrorAction SilentlyContinue
sleep 2
Set-ADAccountPassword WDS -NewPassword (ConvertTo-SecureString -AsPlainText "ABC123!!" -Force)
Set-ADUser WDS -PasswordNeverExpires $TRUE -Enabled $TRUE
}
else{
write-host "RSAT not available.  Please create user WDS with password ABC123!!" -ForegroundColor Magenta
}
sleep 3
if (dsquery user -samid "WDS"){
Write-Host "WDS User detected." -ForegroundColor Green
}

Write-Host ""
Write-Host ""
Write-Host "MDT Configuration complete." -ForegroundColor Green
Write-Host ""
Write-Host "Would you like to create a temporary DNS record?"
$DNSRecord=Read-Host "This will allow you to use MDT before the boot images are prepared (y/n)"
if ($DNSRecord="y"){
Write-Host "Creating an A record for WDS01.  Please remove once boot images have been regenerated."
$IPAddress=Get-NetIPAddress –AddressFamily IPv4 |where {$_.IPAddress -notlike "127*"}
Add-DnsServerResourceRecordA -Name "WDS01" -ZoneName $domain -AllowUpdateAny -IPv4Address $IPAddress.IPAddress -TimeToLive 01:00:00
sleep 2
Write-Host "DNS record created. Importing boot image to WDS." -ForegroundColor Green
wdsutil /Add-Image /ImageFile:$local\Boot\LiteTouchPE_x64.wim /ImageType:Boot >$null

}

Write-Host "Please check installation has succeded before proceeding"
Write-Host "Regenerating boot images will take quite some time."
Write-Host ""

Read-Host "Ready to regenerate boot images. Press enter to continue"
update-MDTDeploymentShare -path "DS001:" -Verbose
sleep 5
Write-Host "Boot images generated. Importing to WDS." -ForegroundColor Green
if ($DNSRecord="y"){
Write-Host "Replacing boot image."
wdsutil /replace-image /image:"Lite Touch Windows PE (x64)" /imagetype:boot /architecture:x64 /replacementimage /imagefile:$local\Boot\LiteTouchPE_x64.wim /ImageType:Boot >$null
}
else{
wdsutil /Add-Image /ImageFile:$local\Boot\LiteTouchPE_x64.wim /ImageType:Boot >$null
Write-host "Boot image imported to WDS"
}
sleep 2
Write-host ""
Write-Host "Applying branding."
sleep 2
Copy-Item "$PSScriptRoot\Content\Files\Background.bmp" "c:\Program Files\Microsoft Deployment Toolkit\Samples\background.bmp" -Force
Write-Host ""
Write-Host ""
Write-host "Script Complete." -ForegroundColor Green
Read-Host
