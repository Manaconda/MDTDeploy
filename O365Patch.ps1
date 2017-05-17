$Drive=Read-Host "Installation Drive"
$destination=$Drive + ":\DeploymentShare"
(Get-Content $destination\Applications\Microsoft Office 2016 Pro Plus O365\Install.bat) | ForEach-Object { $_ -replace "WDS01", $env.$env:COMPUTERNAME } | Set-Content $destination\Applications\Microsoft Office 2016 Pro Plus O365\Install.bat
(Get-Content $destination\Applications\Microsoft Office 2016 Pro Plus O365\Install.xml) | ForEach-Object { $_ -replace "WDS01", $env.$env:COMPUTERNAME } | Set-Content $destination\Applications\Microsoft Office 2016 Pro Plus O365\Install.xml
Write-Host "Complete"
Read-Host
