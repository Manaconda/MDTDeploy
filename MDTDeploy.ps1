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


## Inspect
$ProgressPreference='SilentlyContinue'
Write-Host "Inspecting current configuration..."




#######
$PSScriptRoot=Split-Path $script:MyInvocation.MyCommand.Path

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
if (Test-Path e:\RemoteInstall){
Write-Host "WDS already initialised." -ForegroundColor Green}
else{
Write-Host "Creating directories and initialising WDS server."
wdsutil /initialize-server /reminst:e:\remoteinstall /authorize |Out-Null
}
if (Test-Path e:\RemoteInstall){
Write-Host "WDS Initialisation OK" -ForegroundColor Green}
else{
Write-Host "Initialisation failed.  Please configure WDS." -ForegroundColor Red
exit
}

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
Start-Process "$PSScriptRoot\content\adksetup.exe" "/features OptionId.DeploymentTools OptionId.WindowsPreinstallationEnvironment OptionId.UserStateMigrationTool /norestart /quiet /ceip off" -Wait
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
Start-Process "msiexec.exe" "/i $PSScriptRoot\content\MicrosoftDeploymentToolkit_x64.msi /quiet" -Wait
}
####check install
if (Test-Path "C:\Program Files\Microsoft Deployment Toolkit\Bin\DeploymentWorkbench.msc"){
Write-Host "MDT Installed OK" -ForegroundColor Green
}
else{
Write-Host "MDT Installation failed. Please install manually." -ForegroundColor Red
}
