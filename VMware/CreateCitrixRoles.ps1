<#
.SYNOPSIS
This script connects to a VMware vSphere server and configures a custom role with specific privileges necessary for Citrix Machine Creation Services (MCS), including permissions for machine provisioning, storage management, and deletion of provisioned machines.

.DESCRIPTION
The script performs the following actions:
- Prompts the user to input a VMware vSphere server using the Read-Host cmdlet.
- Connects to the specified VMware vSphere server.
- Creates a new role named "CitrixRole" with specific privileges if it doesn't already exist.
- Prompts the user to select the specific privilege sets they wish to combine and assign to the "CitrixRole" role.
- Offers the user an option to disconnect from the vSphere server at the end of the script.

This script ensures that the "CitrixRole" role has the necessary permissions to perform comprehensive Citrix MCS operations on a VMware vSphere environment.

.NOTES
Author: Balint Oberrauch
Date: 04/11/2024
Version: 1.4
Prerequisites:
- VMware PowerCLI module installed and imported.
- Appropriate permissions to connect to the vSphere server and manage roles.
#>

# Import VMware PowerCLI Module
Import-Module VMware.PowerCLI

# Prompt for the VMware vSphere server address
$vCenterServer = Read-Host -Prompt "Enter the vCenter server address"

# Connect to the VMware vSphere server
Connect-VIServer -Server $vCenterServer

# Check if the role "CitrixRole" already exists
$RoleName = "CitrixRole"
$Role = Get-VIRole -Name $RoleName -ErrorAction SilentlyContinue
if (-not $Role) {
    Write-Verbose "Creating new role '$RoleName' on server '$vCenterServer'."
    try {
        $Role = New-VIRole -Name $RoleName -Verbose
    } catch {
        Write-Error "Failed to create role '$RoleName'. Error: $_"
        return
    }
} else {
    Write-Verbose "Role '$RoleName' already exists."
}

# Define privilege sets
$Privileges = @{
    # Basic Connection and Resource Permissions
    "AddConnectionsAndResources" = @(
        "System.Anonymous",
        "System.Read",
        "System.View"
    )

    # VM Power Management Privileges
    "PowerManagement" = @(
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Interact.PowerOn",
        "VirtualMachine.Interact.Reset",
        "VirtualMachine.Interact.Suspend",
        "Datastore.Browse"
    )

    # Machine Creation Services Privileges
    "MachineCreationServices" = @(
        "Datastore.AllocateSpace",
        "Datastore.Browse",
        "Datastore.FileManagement",
        "Network.Assign",
        "Resource.AssignVMToPool",
        "VirtualMachine.Config.AddExistingDisk",
        "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AddRemoveDevice"
        "VirtualMachine.Config.AdvancedConfig",
        "VirtualMachine.Config.RemoveDisk",
        "VirtualMachine.Config.CPUCount",
        "VirtualMachine.Config.Memory",
        "VirtualMachine.Config.Settings",
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Interact.PowerOn",
        "VirtualMachine.Interact.Reset",
        "VirtualMachine.Interact.Suspend",
        "VirtualMachine.Inventory.CreateFromExisting",
        "VirtualMachine.Inventory.Create",
        "VirtualMachine.Inventory.Delete",
        "VirtualMachine.Provisioning.Clone",
        "VirtualMachine.State.CreateSnapshot"
    )

    # Image Update and Rollback Privileges
    "ImageUpdateAndRollback" = @(
        "Datastore.AllocateSpace",
        "Datastore.Browse",
        "Datastore.FileManagement",
        "Network.Assign",
        "Resource.AssignVMToPool",
        "VirtualMachine.Config.AddExistingDisk",
        "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AdvancedConfig",
        "VirtualMachine.Config.RemoveDisk",
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Interact.PowerOn",
        "VirtualMachine.Interact.Reset",
        "VirtualMachine.Inventory.CreateFromExisting",
        "VirtualMachine.Inventory.Create",
        "VirtualMachine.Inventory.Delete",
        "VirtualMachine.Provisioning.Clone"
    )

    # Privileges for Deleting Provisioned Machines
    "DeleteProvisionedMachines" = @(
        "Datastore.Browse",
        "Datastore.FileManagement",
        "VirtualMachine.Config.RemoveDisk",
        "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Inventory.Delete"
    )

    # Cryptographic operations - vTPM-Related Privileges for Citrix MCS
    "CryptographicOperations" = @(
        "Cryptographer.Access",
        "Cryptographer.AddDisk",
        "Cryptographer.Clone",
        "Cryptographer.Encrypt",
        "Cryptographer.EncryptNew",
        "Cryptographer.Decrypt",
        "Cryptographer.Migrate",
        "Cryptographer.ReadKeyServersInfo"
    )

    # Provisioning Services Privileges
    # The VApp.Export is required for creating MCS machine catalogs using machine profile. This is mandatory for W11.
    "ProvisioningServices" = @(
        "VirtualMachine.Config.AddRemoveDevice",
        "VirtualMachine.Config.CPUCount",
        "VirtualMachine.Config.Memory",
        "VirtualMachine.Config.Settings",
        "VirtualMachine.Provisioning.CloneTemplate",
        "VirtualMachine.Provisioning.DeployTemplate",
        "VApp.Export"
    )

    # Storage Profile Management Privileges
    "StorageProfile" = @(
        "StorageProfile.Update",
        "StorageProfile.View"
    )
}

# Display available privilege sets
Write-Host "Available Privilege Sets:"
$index = 1
$Privileges.Keys | ForEach-Object { Write-Host "$index. $_"; $index++ }

# Prompt user to select privilege sets to combine
$selectedIndices = Read-Host -Prompt "Enter the numbers of the privilege sets you want to assign, separated by commas (e.g., 1,3,5)"
if (-not $selectedIndices) {
    Write-Error "No privilege sets selected. Exiting script."
    return
}

$selectedPrivilegeSets = $selectedIndices -split "," | ForEach-Object { $Privileges.Keys[([int]$_ - 1)] }

# Retrieve selected privilege objects based on user's selection
$AllPrivilegeID = @()
foreach ($privilegeSet in $selectedPrivilegeSets) {
    try {
        $AllPrivilegeID += Get-VIPrivilege -Id $Privileges[$privilegeSet]
    } catch {
        Write-Error "Error retrieving privileges for '$privilegeSet'. Error: $_"
        return
    }
}

# Assign selected privileges to the role
if ($AllPrivilegeID.Count -eq 0) {
    Write-Error "No valid privileges found to assign. Exiting script."
    return
}

try {
    Set-VIRole -Role $Role -AddPrivilege ($AllPrivilegeID) -Verbose
    Write-Verbose "Selected privileges successfully assigned to '$RoleName' role."
} catch {
    Write-Error "Failed to assign privileges to '$RoleName' role. Error: $_"
    return
}

# Display the privileges assigned for verification
try {
    Get-VIPrivilege -Role $Role | Format-Table -Property Name
} catch {
    Write-Error "Failed to retrieve privileges for role '$RoleName'. Error: $_"
}

# Prompt user to disconnect from vCenter
$disconnectResponse = Read-Host -Prompt "Do you want to disconnect from vCenter? (y/n)"
if ($disconnectResponse -match '^(y|Y)$') {
    Disconnect-VIServer -Confirm:$false
    Write-Host "Disconnected from vCenter."
} else {
    Write-Host "Remaining connected to vCenter."
}
