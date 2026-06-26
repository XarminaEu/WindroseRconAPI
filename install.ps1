#Requires -Version 5.1
<#
.SYNOPSIS
    Installs the WindroseRCON UE4SS mod into a Windrose Dedicated Server.
.DESCRIPTION
    Copies the WindroseRCON mod folder, UE4SS settings, and enables the mod
    in the UE4SS mods.json/mods.txt files. Run this from the Windrose server
    folder that contains R5\Binaries\Win64\ue4ss.
#>
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$serverRoot = $PWD.Path
$ue4ssMods = Join-Path $serverRoot "R5\Binaries\Win64\ue4ss\Mods"
$ue4ssDir = Join-Path $serverRoot "R5\Binaries\Win64\ue4ss"
$modSource = Join-Path $PSScriptRoot "WindroseRCON"
$settingsSource = Join-Path $PSScriptRoot "UE4SS-settings.ini"
$dllSource = Join-Path $PSScriptRoot "WindroseRCON\Scripts\windrose_rcon.dll"

if (-not (Test-Path $ue4ssMods)) {
    Write-Error "UE4SS Mods folder not found at $ue4ssMods. Make sure you are running this from the Windrose server root."
}

Write-Host "Installing WindroseRCON into $ue4ssMods ..."

$modDest = Join-Path $ue4ssMods "WindroseRCON"
if (Test-Path $modDest) {
    if (-not $Force) {
        Write-Error "Mod already exists at $modDest. Use -Force to overwrite."
    }
    Remove-Item -Path $modDest -Recurse -Force
}
Copy-Item -Path $modSource -Destination $modDest -Recurse -Force

$dataDir = Join-Path $modDest "Data"
New-Item -ItemType Directory -Path $dataDir -Force | Out-Null

if (Test-Path $dllSource) {
    Copy-Item -Path $dllSource -Destination (Join-Path $modDest "Scripts\windrose_rcon.dll") -Force
    Write-Host "  Copied windrose_rcon.dll"
} else {
    Write-Warning "windrose_rcon.dll not found. Build WindroseRCON_DLL first, then run this script again."
}

Write-Host "Installing Windrose-safe UE4SS-settings.ini ..."
$settingsDest = Join-Path $ue4ssDir "UE4SS-settings.ini"
if (Test-Path $settingsDest) {
    $backup = Join-Path $ue4ssDir "UE4SS-settings.ini.backup"
    Copy-Item -Path $settingsDest -Destination $backup -Force
    Write-Host "  Backed up existing UE4SS-settings.ini to UE4SS-settings.ini.backup"
}
Copy-Item -Path $settingsSource -Destination $settingsDest -Force

Write-Host "Enabling WindroseRCON in mods.json ..."
$modsJson = Join-Path $ue4ssMods "mods.json"
if (Test-Path $modsJson) {
    $mods = Get-Content -Path $modsJson -Raw | ConvertFrom-Json
    $existing = $mods | Where-Object { $_.mod_name -eq "WindroseRCON" }
    if (-not $existing) {
        $mods += [PSCustomObject]@{ mod_name = "WindroseRCON"; mod_enabled = $true }
        $mods | ConvertTo-Json -Depth 10 | Set-Content -Path $modsJson -Encoding UTF8
        Write-Host "  Added WindroseRCON to mods.json"
    } else {
        $existing.mod_enabled = $true
        $mods | ConvertTo-Json -Depth 10 | Set-Content -Path $modsJson -Encoding UTF8
        Write-Host "  WindroseRCON already in mods.json, enabled"
    }
}

$modsTxt = Join-Path $ue4ssMods "mods.txt"
if (Test-Path $modsTxt) {
    $lines = Get-Content -Path $modsTxt
    if ($lines -notmatch "^WindroseRCON\s*:") {
        $lines = @("WindroseRCON : 1") + $lines
        Set-Content -Path $modsTxt -Value ($lines -join "`r`n") -Encoding UTF8
        Write-Host "  Added WindroseRCON to mods.txt"
    }
}

Write-Host "Installation complete."
Write-Host "Important: Edit WindroseRCON/Data/config_user.lua to set your RCON password and admin Steam IDs."
