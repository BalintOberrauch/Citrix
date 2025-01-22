<#
.SYNOPSIS
    Configures Citrix XML traffic on a Cloud Connector to use SSL, ensuring secure communication.

.DESCRIPTION
    This script automates the configuration of SSL for Citrix XML services by:
    - Retrieving the Citrix Broker Service GUID from the registry.
    - Displaying installed certificates for user selection.
    - Binding the selected SSL certificate to port 443.
    - Disabling non-SSL communication for XML services by updating the Citrix registry key.

.PARAMETER None
    No parameters are required to execute this script.

.EXAMPLE
    .\secure_xml_cc.ps1
    Prompts for a certificate selection, reconfigures SSL bindings, and enforces secure XML traffic.

.NOTES
    - Created by Björn Müller (v0.1).
    - Updated by Balint Oberrauch (v0.2): Enhanced error handling, added certificate selection by Friendly Name, CN, and Thumbprint, and automated removal of existing bindings.
    - Followed Citrix guidelines as per CTX221671.

    Ensure you run this script with administrative privileges.

.LINK
    https://support.citrix.com/article/CTX221671
#>

# Retrieve the Citrix Broker Service GUID from the registry
# This GUID is required to associate the SSL certificate with the Citrix XML Service.
$keys = Get-Item -Path Registry::"HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"

foreach ($key in $keys) {
    if ((Get-ItemProperty $key[0].PsPath).DisplayName -eq 'Citrix Remote Broker Provider - x64') {
        $CtxBrokerServiceValues = ($key.Name).Substring(71, 38)
    }
}

# Display installed certificates and prompt user to select one
# Certificates are fetched from the Local Machine certificate store.
$certs = Get-ChildItem Cert:\LocalMachine\My\
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "              Installed Certificates" -ForegroundColor Green
Write-Host "=================================================" -ForegroundColor Cyan

$i = 0
foreach ($cert in $certs) {
    $i++
    $cn = $cert.Subject -replace ".*CN=(.*?)(,|$)", '$1'
    Write-Host "[$i]" -ForegroundColor Yellow -NoNewline
    Write-Host " Friendly Name: " -ForegroundColor White -NoNewline
    Write-Host "$($cert.FriendlyName)" -ForegroundColor Magenta
    Write-Host "     Common Name: $cn" -ForegroundColor Cyan
    Write-Host "     Thumbprint: $($cert.Thumbprint)" -ForegroundColor DarkGray
    Write-Host "-------------------------------------------------" -ForegroundColor Cyan
}

# Prompt the user to select a certificate
# If an invalid option is selected, the script exits gracefully.
[int]$selectedCertIndex = Read-Host "Enter the number of the certificate you want to select"
if ($selectedCertIndex -le $i -AND $selectedCertIndex -gt 0) {
    $selectedCert = $certs[$selectedCertIndex - 1]
    $selectedCert
} else {
    Write-Host "Certificate not found." -ForegroundColor Yellow
    $selectedCert = $null
    break # Exit if no certificate is selected
}

# Remove previous SSL binding on port 443
# This ensures no conflicting bindings exist before adding the new certificate binding.
netsh http delete sslcert ipport=0.0.0.0:443

# Add the new SSL binding using the selected certificate thumbprint and Citrix Broker Service GUID
netsh http add sslcert ipport=0.0.0.0:443 certhash=$certhash appid=$CtxBrokerServiceValues

# Update Citrix XML Service registry key to enforce SSL-only traffic
$registryPath = "HKLM:\Software\Citrix\DesktopServer"
$Name = "XmlServicesEnableNonSsl"
$value = "0"

# Create or update the registry key
New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType DWORD -Force | Out-Null
