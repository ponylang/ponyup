Param([string] $Prefix = "$env:LOCALAPPDATA\ponyup", [bool] $SetPath = $true)
$ErrorActionPreference = 'Stop'

$Arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
if ($Arch -ieq 'x64')
{
  $Arch = 'x86_64'
  $ZipArch = 'x86-64'
}
elseif ($Arch -ieq 'arm64')
{
  $Arch = 'arm64'
  $ZipArch = 'arm64'
}

$tempParent = [System.IO.Path]::GetTempPath()
$tempName = [System.Guid]::NewGuid()
$tempPath = (Join-Path $tempParent $tempName)
New-Item -ItemType Directory -Path $tempPath

$downloadUrl = 'https://dl.cloudsmith.io/public/ponylang/releases/raw/versions/latest'

$zipName = "ponyup-$ZipArch-pc-windows-msvc.zip"
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

$platform = "$Arch-pc-windows-msvc"
Write-Host "Setting platform to $platform..."
Set-Content -Path "$ponyupPath\.platform" -Value $platform

$version = & "$ponyupPath\bin\ponyup" version
if ($version -match 'ponyup (\d+\.\d+\.\d+)') {
  $lockStr = "ponyup-release-$($Matches[1])-$Arch-windows"
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
