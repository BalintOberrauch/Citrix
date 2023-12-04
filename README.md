PVSCopyToolGotCool is a developed tool which copies VHDX Versions across different PVS Servers.

This tool is intended to replace the well known Robocopy PVS copy/sync script.

Features:

-Universally applicable, no manual swapping of PVS Store paths required.
  o PVS Store paths are automatically detected via the PS PVS Snap-In.
-Can be initiated from any server.
  o Powershell PVS Snap-In is a prerequisite!
-Automatically recognizes the mode of the PVS version.
  o Everything except the Maintenance version is copied.
-Supports Verbose and WhatIf parameters.
-Shortcut creation on the desktop.
  o Checks if the script was started with administrative rights.
