param (
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

# The script is located in waspc/tools, so we need to go up one level to get to the waspc directory.
$WaspC_Dir = (Get-Item $PSScriptRoot).Parent.FullName

# Get the path to the built executable.
$WaspC_Bin_Path = (cabal list-bin exe:wasp-cli)

# The data directory.
$Data_Dir = "$WaspC_Dir/data"

# Other files to include.
$Readme_Path = "$WaspC_Dir/README.md"
$License_Path = "$WaspC_Dir/LICENSE"

# Check if the files exist.
if (-not (Test-Path $WaspC_Bin_Path)) {
    Write-Error "wasp-cli.exe not found at $WaspC_Bin_Path"
    exit 1
}
if (-not (Test-Path $Data_Dir)) {
    Write-Error "data directory not found at $Data_Dir"
    exit 1
}

# Create a temporary directory to stage the files.
$Temp_Dir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "wasp-package")

# Copy the files to the temporary directory.
Copy-Item -Path $WaspC_Bin_Path -Destination (Join-Path $Temp_Dir "wasp-bin.exe")
Copy-Item -Path $Data_Dir -Destination (Join-Path $Temp_Dir "data") -Recurse
Copy-Item -Path $Readme_Path -Destination (Join-Path $Temp_Dir "README.md")
Copy-Item -Path $License_Path -Destination (Join-Path $Temp_Dir "LICENSE")

# Create the zip archive.
Compress-Archive -Path $Temp_Dir\* -DestinationPath $OutputPath -Force

# Clean up the temporary directory.
Remove-Item -Path $Temp_Dir -Recurse -Force

Write-Host "Successfully created package at $OutputPath"
