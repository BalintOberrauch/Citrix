<#
.SYNOPSIS
This script connects to a VMware vSphere server and configures a custom role with specific privileges necessary for Citrix Machine Creation Services (MCS), including permissions for machine provisioning, storage management, and deletion of provisioned machines.

.DESCRIPTION
The script performs the following actions:
- Prompts the user to input a VMware vSphere server using the Read-Host cmdlet.
- Connects to the specified VMware vSphere server.
- Creates a new role named "CitrixMCS" with specific privileges if it doesn't already exist.
- Prompts the user to select the specific privilege sets they wish to combine and assign to the "CitrixMCS" role.

This script ensures that the "CitrixMCS" role has the necessary permissions to perform comprehensive Citrix MCS operations on a VMware vSphere environment.

.NOTES
Author: Balint Oberrauch
Date: 29/01/2024
Version: 1.3
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

# Check if the role "CitrixMCS" already exists
$Role = Get-VIRole -Name "CitrixMCS" -ErrorAction SilentlyContinue
if (-not $Role) {
    # Create a new role named "CitrixMCS" if it doesn't exist
    Write-Verbose "Creating role 'CitrixMCS'"
    $Role = New-VIRole -Name "CitrixMCS" -Verbose
} else {
    Write-Verbose "Role 'CitrixMCS' already exists."
}

# Define privilege sets
$Privileges = @{
    "AddConnectionsAndResources" = @("System.Anonymous", "System.Read", "System.View")
    "PowerManagement" = @("VirtualMachine.Interact.PowerOff", "VirtualMachine.Interact.PowerOn", "VirtualMachine.Interact.Reset", "VirtualMachine.Interact.Suspend")
    "MachineCreationServices" = @(
        "Datastore.AllocateSpace", "Datastore.Browse", "Datastore.FileManagement", "Network.Assign",
        "Resource.AssignVMToPool", "VirtualMachine.Config.AddExistingDisk", "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AdvancedConfig", "VirtualMachine.Config.RemoveDisk", "VirtualMachine.Config.CPUCount",
        "VirtualMachine.Config.Memory", "VirtualMachine.Config.Settings", "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Interact.PowerOn", "VirtualMachine.Interact.Reset", "VirtualMachine.Interact.Suspend",
        "VirtualMachine.Inventory.CreateFromExisting", "VirtualMachine.Inventory.Create",
        "VirtualMachine.Inventory.Delete", "VirtualMachine.Provisioning.Clone", "VirtualMachine.State.CreateSnapshot"
    )
    "MCSvTPM" = @(
        "Cryptographer.Access", "Cryptographer.AddDisk", "Cryptographer.Clone",
        "Cryptographer.Encrypt", "Cryptographer.EncryptNew", "Cryptographer.Migrate",
        "Cryptographer.ReadKeyServersInfo"
    )
    "ImageUpdateAndRollback" = @(
        "Datastore.AllocateSpace", "Datastore.Browse", "Datastore.FileManagement", "Network.Assign",
        "Resource.AssignVMToPool", "VirtualMachine.Config.AddExistingDisk", "VirtualMachine.Config.AddNewDisk",
        "VirtualMachine.Config.AdvancedConfig", "VirtualMachine.Config.RemoveDisk", "VirtualMachine.Interact.PowerOff",
        "VirtualMachine.Interact.PowerOn", "VirtualMachine.Interact.Reset", "VirtualMachine.Inventory.CreateFromExisting",
        "VirtualMachine.Inventory.Create", "VirtualMachine.Inventory.Delete", "VirtualMachine.Provisioning.Clone"
    )
    "DeleteProvisionedMachines" = @(
        "Datastore.Browse", "Datastore.FileManagement", "VirtualMachine.Config.RemoveDisk",
        "VirtualMachine.Interact.PowerOff", "VirtualMachine.Inventory.Delete"
    )
    "ProvisioningServices" = @(
        "VirtualMachine.Config.AddRemoveDevice", "VirtualMachine.Config.CPUCount", "VirtualMachine.Config.Memory",
        "VirtualMachine.Config.Settings", "VirtualMachine.Provisioning.CloneTemplate", "VirtualMachine.Provisioning.DeployTemplate"
    )
    "StorageProfile" = @("StorageProfile.Update", "StorageProfile.View")
}

# Display available privilege sets
Write-Host "Available Privilege Sets:"
$index = 1
$Privileges.Keys | ForEach-Object { Write-Host "$index. $_"; $index++ }

# Prompt user to select privilege sets to combine
$selectedIndices = Read-Host -Prompt "Enter the numbers of the privilege sets you want to assign, separated by commas (e.g., 1,3,5)"
$selectedPrivilegeSets = $selectedIndices -split "," | ForEach-Object { $Privileges.Keys[([int]$_ - 1)] }

# Retrieve selected privilege objects based on user's selection
$AllPrivilegeID = @()
foreach ($privilegeSet in $selectedPrivilegeSets) {
    $AllPrivilegeID += Get-VIPrivilege -Id $Privileges[$privilegeSet]
}

# Assign selected privileges to the role
try {
    Set-VIRole -Role $Role -AddPrivilege ($AllPrivilegeID) -Verbose
    Write-Verbose "Selected privileges successfully assigned to 'CitrixMCS' role."
} catch {
    Write-Error "Failed to assign privileges to 'CitrixMCS' role: $_"
}

# Display the privileges assigned for verification
Get-VIPrivilege -Role $Role | Format-Table -Property Name

# Disconnect from vCenter
Disconnect-VIServer -Confirm:$false
