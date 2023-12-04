<#
.SYNOPSIS
This script manages and synchronizes Citrix Provisioning Services (PVS) disk images across multiple servers.

.DESCRIPTION
The script checks for administrative privileges and creates a desktop shortcut for running as an admin if necessary. It retrieves information about PVS servers and disk locators, checks for missing VHD and PVP files, prompts the user to copy missing files from other locations, and provides a summary of the copied files.

.PARAMETER Verbose
Provides detailed information about the script execution.

.PARAMETER WhatIf
Simulates the actions the script would take without making any actual changes.

.AUTHOR
Balint Oberrauch
https://oberrauch.bz.it

.VERSION HISTORY
1.0 - [02.12.2023] - Initial version
1.1 - [02.12.2023] - Added WhatIf and Verbose support
1.2 - [02.12.2023] - Enhanced file copy functionality and verbose output

.NOTES
Additional information about the script.
#>


[CmdletBinding(SupportsShouldProcess = $true)]
param()

function Create-DesktopShortcut {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param()

    $scriptPath = $PSCommandPath
    $desktopPath = [System.Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path -Path $desktopPath -ChildPath "PVSCopyToolGotCool.lnk"

    $WshShell = New-Object -ComObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut($shortcutPath)
    $Shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`""
    $Shortcut.WindowStyle = 1
    $Shortcut.IconLocation = "powershell.exe"

    if ($PSCmdlet.ShouldProcess($desktopPath, "Create desktop shortcut")) {
        $Shortcut.Save()
        Write-Verbose "Shortcut created on desktop to run this script as admin."
    }
    Start-Sleep -Seconds 2
}

function Copy-FileWithProgress {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    $fileSize = (Get-Item $SourcePath).Length
    $totalBytesCopied = 0
    $bufferSize = 81920
    $buffer = New-Object byte[] $bufferSize
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    $sourceStream = [System.IO.File]::OpenRead($SourcePath)
    $destinationStream = [System.IO.File]::Create($DestinationPath)

    while ($true) {
        $read = $sourceStream.Read($buffer, 0, $bufferSize)
        if ($read -le 0) { break }
        $destinationStream.Write($buffer, 0, $read)
        $totalBytesCopied += $read
        $percentage = ($totalBytesCopied / $fileSize) * 100
        Write-Progress -Activity "Copying file ($($SourcePath))" -Status "$percentage% Complete" -PercentComplete $percentage
    }

    if ($PSCmdlet.ShouldProcess($DestinationPath, "Copy file")) {
        $sourceStream.Close()
        $destinationStream.Close()
        $stopwatch.Stop()

        Write-Verbose "File copied: $DestinationPath"

        return @{
            FilePath = $DestinationPath
            FileSize = $fileSize
            Duration = $stopwatch.Elapsed.TotalSeconds
        }
    }
}

$currentPrincipal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Create-DesktopShortcut
    exit
}

Add-PSSnapin -Name Citrix.PVS.SnapIn

$serverDetails = @()
$pvsServers = Get-PvsServer
foreach ($server in $pvsServers) {
    $stores = Get-PvsStore -ServerName $server.Name
    foreach ($store in $stores) {
        $driveLetterWithColon = $store.Path.Substring(0,2)
        $adminShare = $driveLetterWithColon -replace ':', '$'
        $uncPath = "\\$($server.Name)\$adminShare\$($store.Path -replace '^[A-Za-z]:\\', '')"

        $serverDetails += [PSCustomObject]@{
            ServerName = $server.Name
            StorePath = $uncPath
        }
    }
}

$vDiskDetails = @()
$diskLocators = Get-PvsDiskLocator
foreach ($diskLocator in $diskLocators) {
    $vDiskVersions = Get-PvsDiskVersion -DiskLocatorId $diskLocator.DiskLocatorId

    foreach ($vDiskVersion in $vDiskVersions) {
        $mode = switch ($vDiskVersion.Access) {
            0 { "Production" }
            1 { "Maintenance" }
            7 { "Test" }
            2 { "Maintenance (Highest Version)" }
            5 { "Merge Maintenance" }
            6 { "Merge Test" }
            4 { "Merged" }
            3 { "Override" }
            default { "Unknown" }
        }

        $vDiskDetails += [PSCustomObject]@{
            Name = $vDiskVersion.Name
            Version = $vDiskVersion.Version
            Mode = $mode
            DiskFileName = $vDiskVersion.DiskFileName
            IsMaintenance = ($vDiskVersion.Access -eq 1)
        }
        # Check if Verbose is not enabled, then use Write-Host
        if ($VerbosePreference -ne 'Continue') {
        Write-Host "vDisk: $($vDiskVersion.Name), Version: $($vDiskVersion.Version), Mode: $mode"
        }

        # Always show detailed information when -Verbose is used
        Write-Verbose "vDisk: $($vDiskVersion.Name), Version: $($vDiskVersion.Version), Mode: $mode, Disk File Name: $($vDiskVersion.DiskFileName), IsMaintenance: $($vDiskVersion.Access -eq 1)"
    }
}

Write-Host "`nChecking file presence on each server..."

$missingFiles = @()
$missingFileDetails = @()

foreach ($vDisk in $vDiskDetails) {
    if ($vDisk.IsMaintenance) {
        continue
    }

    foreach ($detail in $serverDetails) {
        $vhdFilePath = Join-Path -Path $detail.StorePath -ChildPath $vDisk.DiskFileName
        $pvpFilePath = Join-Path -Path $detail.StorePath -ChildPath ($vDisk.DiskFileName.Replace('.vhdx', '').Replace('.avhdx', '') + '.pvp')

        if (-not (Test-Path -Path $vhdFilePath)) {
            Write-Host "Missing VHD File: $vhdFilePath on server $($detail.ServerName)" -ForegroundColor Red
            $missingFiles += $vhdFilePath
            $missingFileDetails += [PSCustomObject]@{ ServerName = $detail.ServerName; FilePath = $vhdFilePath; Type = "VHD(X)" }
        }

        if (-not (Test-Path -Path $pvpFilePath)) {
            Write-Host "Missing PVP File: $pvpFilePath on server $($detail.ServerName)" -ForegroundColor Red
            $missingFiles += $pvpFilePath
            $missingFileDetails += [PSCustomObject]@{ ServerName = $detail.ServerName; FilePath = $pvpFilePath; Type = "PVP" }
        }
    }
}

if ($missingFiles.Count -gt 0) {
    $response = Read-Host "Would you like to copy the missing files from another location? (yes/no)"
    if ($response -eq "yes") {
        foreach ($fileDetail in $missingFileDetails) {
            $sourceServer = $serverDetails | Where-Object {
                Test-Path (Join-Path -Path $_.StorePath -ChildPath ($fileDetail.FilePath | Split-Path -Leaf))
            }

            if ($sourceServer) {
                if ($PSCmdlet.ShouldProcess($fileDetail.FilePath, "Copy file")) {
                    $sourceFilePath = Join-Path -Path $sourceServer.StorePath -ChildPath ($fileDetail.FilePath | Split-Path -Leaf)
                    $copyInfo = Copy-FileWithProgress -SourcePath $sourceFilePath -DestinationPath $fileDetail.FilePath
                    # Display copy statistics
                    $fileSizeMB = [Math]::Round($copyInfo.FileSize / 1MB, 2)
                    $durationMin = [int]($copyInfo.Duration / 60)
                    $durationSec = [Math]::Round($copyInfo.Duration % 60, 2)
                    Write-Host "File: $($copyInfo.FilePath), Size: ${fileSizeMB} MB, Time: ${durationMin} minutes, ${durationSec} seconds" -ForegroundColor Green
                    Write-Verbose "Detailed copy stats: $($copyInfo | Out-String)"
                }
            } else {
                Write-Verbose "No source server found with the $($fileDetail.Type) file for $($fileDetail.FilePath)"
            }
        }
    }
} else {
    Write-Host "No missing files detected." -ForegroundColor Green
}

Read-Host -Prompt "Press Enter to exit"
