<#
.SYNOPSIS
Retrieves service account information for running services, scheduled tasks, and services from the Service Control Manager (SCM).

.DESCRIPTION
This script fetches and displays service account information from three sources:

1. Running services that are set to start automatically.
2. Scheduled tasks that are in 'Ready' or 'Running' state.
3. Services registered within the Service Control Manager (SCM) in the system registry.

By default, the script will display service account details for all entities in these categories. However, users can specify the optional `-FilterAccount` parameter to filter the results based on a specific service account or a substring of it.

.PARAMETER FilterAccount
Optional parameter. Specifies the service account or a substring of it to filter the results. If not provided, information for all service accounts will be shown.

.EXAMPLE
.\ServiceAccountsInfo.ps1

Displays service account information for all running services, scheduled tasks, and services in the SCM.

.EXAMPLE
.\ServiceAccountsInfo.ps1 -FilterAccount "NT AUTHORITY\LocalService"

Displays service account information filtered by the "NT AUTHORITY\LocalService" account.

.NOTES
File Name      : ServiceAccountsInfo.ps1
Author         : Balint Oberrauch
Prerequisite   : PowerShell V3, Citrix.Broker.Admin.V2 module for Citrix functionality
#>

param (
    [string]$FilterAccount
)

# Always try to load the Citrix module, if available.
if (Get-Module -ListAvailable -Name Citrix.Broker.Admin.V2) {
    Import-Module Citrix.Broker.Admin.V2 -ErrorAction SilentlyContinue
}

$services = Get-CimInstance -Class Win32_Service | 
Select-Object Name, StartMode, State, StartName |
Where-Object { 
    (!$FilterAccount -or $_.StartName -like "*$FilterAccount*")
}

# Fetching Citrix XenDesktop administrators
$citrixAdmins = @()
if (Get-Command -Name Get-BrokerAdministrator -ErrorAction SilentlyContinue) {
    $citrixAdmins = Get-BrokerAdministrator | 
    Where-Object { 
        (!$FilterAccount -or $_.Name -like "*$FilterAccount*")
    }
}

# Fetching and filtering service accounts for scheduled tasks
$scheduledTasksInfo = Get-ScheduledTask | ForEach-Object {
    $principal = if ($_.Principal) { $_.Principal.UserId } else { 'N/A' }
    if (!$FilterAccount -or $principal -like "*$FilterAccount*") {
        [PSCustomObject]@{
            'TaskName'       = $_.TaskName;
            'TaskAccount'    = $principal;
        }
    }
}


# Fetching and filtering service accounts from SCM (Service Control Manager)
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
$servicesFromSCM = Get-ChildItem $regPath | ForEach-Object {
    $obj = Get-ItemProperty $_.PSPath
    if ($obj -and $obj.ObjectName -and (!$FilterAccount -or $obj.ObjectName -like "*$FilterAccount*")) {
        [PSCustomObject]@{
            'ServiceName' = $_.PSChildName;
            'ServiceAccount' = $obj.ObjectName;
        }
    }
}

# Display results

Write-Output "`nCitrix XenDesktop Administrators:"
$citrixAdmins | Format-Table -AutoSize

Write-Output "Service Account Information for Running Services:"
$services | Format-Table -AutoSize

Write-Output "`nService Account Information for Scheduled Tasks:"
$scheduledTasksInfo | Format-Table -AutoSize

Write-Output "`nService Account Information from SCM:"
$servicesFromSCM | Format-Table -AutoSize


