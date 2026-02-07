Param([string] $Prefix = "$env:LOCALAPPDATA\ponyup", [bool] $SetPath = $true)
$ErrorActionPreference = 'Stop'

# Detect system architecture
$Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if (-not $Arch) {
  $Arch = $env:PROCESSOR_ARCHITECTURE
}
Write-Host "Detected architecture: $Arch"
if ($Arch -ieq 'amd64' -or $Arch -ieq 'x64')
{
  $Arch = 'x86-64'
  $PlatformStringArch = 'x86_64'
}
elseif ($Arch -ieq 'arm64')
{
  $Arch = 'arm64'
  $PlatformStringArch = 'arm64'
}
else
{
  Write-Error "Unsupported architecture: $Arch. Supported architectures are: amd64, x64, arm64"
  exit 1
}

$tempParent = [System.IO.Path]::GetTempPath()
$tempName = [System.Guid]::NewGuid()
$tempPath = (Join-Path $tempParent $tempName)
New-Item -ItemType Directory -Path $tempPath

$downloadUrl = 'https://dl.cloudsmith.io/public/ponylang/releases/raw/versions/latest'

$zipName = "ponyup-$Arch-pc-windows-msvc.zip"
$zipUrl = "$downloadUrl/$zipName"
$zipPath = "$tempPath\$zipName"

Write-Host "Downloading $zipUrl..."
Invoke-WebRequest -Uri $zipUrl -Outfile $zipPath

$ponyupPath = $Prefix
if (-not (Test-Path $ponyupPath)) {
  New-Item -ItemType Directory -Path $ponyupPath
}

Write-Host "Unzipping to $ponyupPath..."
Expand-Archive -Force -Path $zipPath -DestinationPath $ponyupPath

$platform = "$PlatformStringArch-pc-windows-msvc"
Write-Host "Setting platform to $platform..."
Set-Content -Path "$ponyupPath\.platform" -Value $platform

$version = & "$ponyupPath\bin\ponyup" version
if ($version -match 'ponyup (\d+\.\d+\.\d+)') {
  $lockStr = "ponyup-release-$($Matches[1])-$PlatformStringArch-windows"
  Write-Host "Locking ponyup version to $lockStr..."
  $lockPath = "$ponyupPath\.lock"

  $newContent = @()
  if (Test-Path $lockPath) {
    $content = Get-Content -Path $lockPath
    $content | Foreach-Object {
      if ($_ -match '^ponyup') {
        $newContent += $lockStr
      }
      else {
        $newContent += $_
      }
    }
  } else {
    $newContent = @($lockStr)
  }

  Set-Content -Path "$ponyupPath\.lock" -Value $newContent
}

if ($SetPath) {
  $binDir = "$ponyupPath\bin"
  if (-not ($env:PATH -like "*$binDir*")) {
    Write-Host "Adding $binDir to PATH; you will need to restart your terminal to use it."
    $newPath = "$env:PATH;$binDir"
    [Environment]::SetEnvironmentVariable("PATH", $newPath, 'User')
    $env:PATH = $newPath
  }
  else {
    Write-Host "$binDir is already in PATH"
  }
}
