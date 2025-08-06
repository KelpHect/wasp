[CmdletBinding()]
param (
    [string]$Version,
    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$HomeLocalBin = "$env:LOCALAPPDATA\bin"
$HomeLocalShare = "$env:LOCALAPPDATA"

$Red = "`e[31m"
$Green = "`e[32m"
$Bold = "`e[1m"
$Reset = "`e[0m"

function Main {
    # Send telemetry in the background.
    Start-Job -ScriptBlock {
        param($PostHogApiKey, $OsInfo)

        $Data = @{
            api_key = $PostHogApiKey
            type = "capture"
            event = "install-script:run"
            distinct_id = (Get-Random).ToString() + $([DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString())
            properties = @{
                os = $OsInfo
                context = if ($env:CI) { "CI" } else { "" }
            }
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "https://app.posthog.com/capture" -Method Post -Body $Data -ContentType "application/json"
    } -ArgumentList "CdDd2A0jKTI2vFAsrI9JWm3MqpOcgHz1bMyogAcwsE4", "windows" | Out-Null

    Install-Based-On-Arch
}

function Install-Based-On-Arch {
    # For now, we only support x86_64.
    if ($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
        Install-From-Bin-Package "wasp-windows-x86_64.zip"
    } else {
        Write-Error "Sorry, this installer does not support your architecture: $env:PROCESSOR_ARCHITECTURE"
        exit 1
    }
}

function Get-Latest-Wasp-Version {
    $Uri = "https://github.com/wasp-lang/wasp/releases/latest"
    $Response = Invoke-WebRequest -Uri $Uri -MaximumRedirection 0 -ErrorAction SilentlyContinue
    if ($Response.StatusCode -eq 302) {
        return $Response.Headers.Location.Split('/')[-1].TrimStart('v')
    } else {
        Write-Error "Failed to get the latest Wasp version."
        exit 1
    }
}

function Install-From-Bin-Package {
    param (
        [string]$BinPackageName
    )

    $LatestVersion = Get-Latest-Wasp-Version

    if ([string]::IsNullOrEmpty($Version)) {
        $VersionToInstall = $LatestVersion
    } else {
        $VersionToInstall = $Version
    }

    if ($VersionToInstall -eq $LatestVersion) {
        $LatestVersionMessage = "latest"
    } else {
        $LatestVersionMessage = "latest is $LatestVersion"
    }

    Write-Host "Installing wasp version $VersionToInstall ($LatestVersionMessage)."

    $DataDstDir = "$HomeLocalShare\wasp-lang\$VersionToInstall"
    New-Item -ItemType Directory -Force -Path $DataDstDir | Out-Null

    if (-not (Get-ChildItem -Path $DataDstDir)) {
        $PackageUrl = "https://github.com/wasp-lang/wasp/releases/download/v$VersionToInstall/$BinPackageName"
        $TempDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "wasp-installer")
        $PackagePath = Join-Path $TempDir $BinPackageName

        Write-Host "Downloading binary package to temporary dir and unpacking it there..."
        if ($DryRun) {
            Write-Host "Dry run: Would download from $PackageUrl to $PackagePath"
            Write-Host "Dry run: Would extract from $PackagePath to $DataDstDir"
        } else {
            try {
                Invoke-WebRequest -Uri $PackageUrl -OutFile $PackagePath
            } catch {
                Write-Error "Installation failed: There is no wasp version $VersionToInstall"
                exit 1
            }

            Write-Host "Installing wasp data to $DataDstDir."
            Expand-Archive -Path $PackagePath -DestinationPath $DataDstDir -Force
            Remove-Item -Path $TempDir -Recurse -Force
        }
    } else {
        Write-Host "Found an existing installation on the disk, at $DataDstDir. Using it instead."
    }

    $BinDstDir = $HomeLocalBin
    New-Item -ItemType Directory -Force -Path $BinDstDir | Out-Null

    if (Test-Path "$BinDstDir\wasp.cmd") {
        Write-Host "Configuring wasp executable at $BinDstDir\wasp.cmd to use wasp version $VersionToInstall."
    } else {
        Write-Host "Installing wasp executable to $BinDstDir\wasp.cmd."
    }

    $WaspCmdContent = @"
@echo off
set "waspc_datadir=$DataDstDir\data"
"$DataDstDir\wasp-bin.exe" %*
"@
    Set-Content -Path "$BinDstDir\wasp.cmd" -Value $WaspCmdContent

    Write-Host "`n=============================================="

    $UserPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
    if (-not ($UserPath -split ';' -contains $BinDstDir)) {
        Write-Host "$Red`nWARNING$Reset: It looks like '$BinDstDir' is not on your PATH! You will not be able to invoke wasp from the terminal by its name."
        Write-Host "  You can add it to your PATH by running the following command in PowerShell and then restarting your terminal:"
        Write-Host "      $Bold`[System.Environment]::SetEnvironmentVariable('Path', [System.Environment]::GetEnvironmentVariable('Path', 'User') + ';$BinDstDir', 'User')`$Reset"
    }

    Write-Host "$Green`nwasp has been successfully installed! To create your first app, do:$Reset"
    if (-not ($UserPath -split ';' -contains $BinDstDir)) {
        Write-Host " - Add wasp to your PATH as described above."
    }
    Write-Host " - $Bold`wasp new MyApp`$Reset"
}

Main
