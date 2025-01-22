<# restore customizations by restoring the settings from the original host#>

#Variables
$SourceSF           = Read-Host "Please provide the DNS Name of the source Host: "
$Source_Base_Folder = '\\' + $SourceSF + '\C$\' + "inetpub\wwwroot\Citrix\"
$TargetSF           = Read-Host "Please provide the DNS Name of the destination Host: "
$Target_Base_Folder = '\\' + $TargetSF + '\C$\' + "inetpub\wwwroot\Citrix\"
$Stores             = (Get-ChildItem $Source_Base_Folder -Exclude "*Web","*Auth","Configuration","Roaming").Name

foreach ($Store in $Stores){
    if (Test-Path $($Target_Base_Folder + $Store)){
        "`r`n"
        "--------------------"
        $Store
        "--------------------"
        # default.ica on Source SF
        $Source_ICA       = $Source_Base_Folder + $Store + '\App_Data\default.ica'
        # default.ica on destination SF
        $Target_ICA       = $Target_Base_Folder + $Store + '\App_Data\'
        # custom Folder on Source SF
        $Source_custom    = $Source_Base_Folder + $Store + 'Web\custom\'
        # custom Folder on this SF
        $Target_custom    = $Target_Base_Folder + $Store + 'Web\'

        if (-not(Test-Path $Target_ICA)){md $Target_ICA}
        Copy-Item -Path $Source_ICA -Destination $Target_ICA -WhatIf
        Copy-Item -Path $Source_ICA -Destination $Target_ICA -Force
        if (-not(Test-Path $Target_custom)){md $Target_custom}
        Copy-Item -Path $Source_custom -Destination $Target_custom -Recurse -WhatIf
        Copy-Item -Path $Source_custom -Destination $Target_custom -Recurse -Force
        "--------------------"
    }
    Else {Write-Host "ERROR - Store $Store doesn't exist on this Server" -ForegroundColor Red}
}
