<#
.SYNOPSIS
This script connects to a VMware vSphere server and configures a custom role with specific privileges necessary for Citrix Machine Creation Services (MCS).

.DESCRIPTION
The script performs the following actions:
- Connects to a VMware vSphere server using the Connect-VIServer cmdlet.
- Creates a new role named "CitrixMCS" with specific privileges if it doesn't already exist.
- Assigns various privileges to the "CitrixMCS" role, which are required for Citrix MCS operations such as VM power management, machine creation services, vTPM operations, image updates and rollbacks, deletion of provisioned machines, and provisioning services.


.NOTES
Author: Balint Oberrauch
Date: 29/01/2024
Version: 1.0
Prerequisites:
- VMware PowerCLI module installed and imported.
- Appropriate permissions to connect to the vSphere server and manage roles.

#>

# Import VMware PowerCLI Module

Import-Module VMware.PowerCLI

# Connect to the VMware vSphere server
Connect-VIServer -Server vcsa.vdi.lab

# Create a new role named "CitrixMCS" if it doesn't exist, with verbose output
New-VIRole -Name "CitrixMCS" -Verbose

# Retrieve the "CitrixMCS" role
$Role = Get-VIRole -Name "CitrixMCS"

# Define privileges


$PermissionsAddConnectionsAndResources = @(
    "System.Anonymous", 
    "System.Read",
    "System.View"
)

$PermissionsPowerManagement = @(
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Interact.PowerOn",
    "VirtualMachine.Interact.Reset",
    "VirtualMachine.Interact.Suspend"
)

$PermissionsMachineCreationServices = @(
    "Datastore.AllocateSpace",
    "Datastore.Browse",
    "Datastore.FileManagement",
    "Network.Assign",
    "Resource.AssignVMToPool",
    "VirtualMachine.Config.AddExistingDisk",
    "VirtualMachine.Config.AddNewDisk",
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

$PermissionsMCSvTPM = @(
    "Cryptographer.Access",
    "Cryptographer.AddDisk",
    "Cryptographer.Clone",
    "Cryptographer.Encrypt",
    "Cryptographer.EncryptNew",
    "Cryptographer.Migrate",
    "Cryptographer.ReadKeyServersInfo"
)

$PermissionsImageUpdateAndRollback = @(
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

$PermissionsDeleteProvisionedMachines = @(
    "Datastore.Browse",
    "Datastore.FileManagement",
    "VirtualMachine.Config.RemoveDisk",
    "VirtualMachine.Interact.PowerOff",
    "VirtualMachine.Inventory.Delete"
)

$PermissionsProvisioningServices = @(
    "VirtualMachine.Config.AddRemoveDevice",
    "VirtualMachine.Config.CPUCount",
    "VirtualMachine.Config.Memory",
    "VirtualMachine.Config.Settings",
    "VirtualMachine.Provisioning.CloneTemplate",
    "VirtualMachine.Provisioning.DeployTemplate"
)

# Retrieve privilege objects based on the defined permission sets

$IDAddConnectionsAndResources = Get-VIPrivilege -Id $PermissionsAddConnectionsAndResources
$IDPowerManagement = Get-VIPrivilege -Id $PermissionsPowerManagement 
$IDMachineCreationServices= Get-VIPrivilege -Id $PermissionsMachineCreationServices
$IDMCSvTPM = Get-VIPrivilege -Id $PermissionsMCSvTPM
$IDImageUpdateAndRollback = Get-VIPrivilege -Id $PermissionsImageUpdateAndRollback
$IDDeleteProvisionedMachines = Get-VIPrivilege -Id $PermissionsDeleteProvisionedMachines
$IDProvisioningServices = Get-VIPrivilege -Id $PermissionsProvisioningServices

# Combine all privilege IDs into a single array
$AllPrivilegeID = $IDAddConnectionsAndResources + $IDMachineCreationServices + $IDMCSvTP # Add others as needed

# Assign all collected privileges to your role
Set-VIRole -Role $Role -AddPrivilege ($AllPrivilegeID) -Verbose

# Display the privileges assigned for verification
Get-VIPrivilege -Role $Role

#Disconnect from vCenter

Disconnect-VIServer -Confirm
