#
# This function list all certificates where the CN=<computer name>
# Pick the latest
# Update the winrm HTTPS listener certificate
#

#
# Welcoming PR and comments on how to improve it for production readyness.
# Work in conjunction with the KeyVaultForWindows or KeyVaultForLinux extension that will pull renewed certificates to the VM.
#
function Update-WinRMCertificate {
    param (
        [string]$CommonName,
        [int]$WinRmsPort
    )

    # Get all certificates with the specified common name
    $certificates = Get-ChildItem -Path Cert:\LocalMachine\My | Where-Object {$_.Subject -match $CommonName}

    # Check if any certificates were found
    if ($certificates.Count -gt 0) {
        # Sort certificates by expiration date in descending order
        $latestCertificate = $certificates | Sort-Object -Property NotAfter -Descending | Select-Object -First 1

        # Get the thumbprint of the latest certificate
        $newThumbprint = $latestCertificate.Thumbprint

        # Get the current thumbprint of the WinRM listener
        $listener = Get-WSManInstance -ResourceURI "winrm/config/Listener" -Enumerate
        $httpsListener = $listener | Where-Object { $_.Transport -eq "HTTPS" }

        # Check if the HTTPS listener is found and has a CertificateThumbprint property
        if ($httpsListener -ne $null -and $httpsListener.CertificateThumbprint -ne $null) {
            $currentThumbprint = $httpsListener.CertificateThumbprint

            # Check if the thumbprint has changed
            if ($currentThumbprint -ne $newThumbprint) {
                # Update WinRM listener configuration with the new certificate thumbprint
                Get-ChildItem wsman:\localhost\Listener\ | Where-Object -Property Keys -like 'Transport=HTTP*' | Remove-Item -Recurse
                New-Item -Path WSMan:\localhost\Listener -Transport HTTPS -Address * -Port $WinRmsPort -CertificateThumbprint $newThumbprint -Force
                Restart-Service WinRM -Force
                Write-Host "WinRM listener thumbprint has been updated to $newThumbprint"
            } else {
                Write-Host "WinRM listener thumbprint is already up to date."
            }
        } else {
            Write-Host "No HTTPS listener found or CertificateThumbprint property is not available."
        }
    } else {
        Write-Host "Certificate with common name '$CommonName' not found."
    }
}

WinRM e winrm/config/listener
