param (
  [CmdletBinding()]

  [Parameter(Mandatory = $false)]
  # key vault name holding cert
  [string]$mode = "install"
)

if ($mode.ToLower() -eq "uninstall") {
    Start-Process -Wait -FilePath "C:\Users\azureuser\AppData\Local\Programs\Microsoft VS Code\unins000.exe" -ArgumentList /SILENT
}
else {
    $downloadUrl = "https://code.visualstudio.com/sha/download?build=stable&os=win32-x64"
    $destination = "$env:TEMP\vscode_installer.exe"
    Invoke-WebRequest -Uri $downloadUrl -OutFile $destination
    Start-Process -Wait -FilePath $destination -ArgumentList /verysilent, /mergetasks=!runcode
}



