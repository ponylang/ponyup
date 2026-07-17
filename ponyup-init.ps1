Param(
  [string] $Prefix = "$env:LOCALAPPDATA\ponyup",
  [bool] $SetPath = $true,
  [string] $Repository = "releases"
)
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

# Query the Cloudsmith API for the latest ponyup package in the chosen
# repository. This mirrors ponyup-init.sh: it gives us the package version
# (a semver for releases, a date for nightlies), the checksum, and the download
# URL.
$queryUrl = "https://api.cloudsmith.io/packages/ponylang/$Repository/"
$query = "?query=ponyup-$Arch-pc-windows-msvc&page=1&page_size=1"
Write-Host "Querying $queryUrl$query..."
$response = @(Invoke-RestMethod -Uri "$queryUrl$query")
$package = $response[0]
# Cloudsmith returns `[]` for no match. Invoke-RestMethod unrolls that into an
# empty array, so $response[0] is an empty Object[] (NOT $null) whose fields read
# as empty. Guard on the fields we actually consume being present: this catches
# the no-match case and a package that somehow lacks a checksum.
if ((-not $package.version) -or (-not $package.cdn_url) -or
    (-not $package.checksum_sha256)) {
  Write-Error "Failed to find ponyup in the '$Repository' repository"
  exit 1
}
$pkgVersion = $package.version
$downloadUrl = $package.cdn_url
# Cloudsmith exposes both checksum_sha256 and checksum_sha512. We use sha256 to
# match ponyup-init.sh; this is intentionally different from ponyup's internal
# downloader, which verifies sha512. Don't "align" them.
$checksum = $package.checksum_sha256

$zipName = "ponyup-$Arch-pc-windows-msvc.zip"
$zipPath = "$tempPath\$zipName"

Write-Host "Downloading $downloadUrl..."
Invoke-WebRequest -Uri $downloadUrl -Outfile $zipPath

$dlChecksum = (Get-FileHash -Algorithm SHA256 -Path $zipPath).Hash.ToLower()
if ($dlChecksum -ne $checksum.ToLower()) {
  Remove-Item -Force $zipPath
  Write-Error "checksum mismatch: expected $checksum, calculated $dlChecksum"
  exit 1
}
Write-Host "checksum ok"

$ponyupPath = $Prefix
if (-not (Test-Path $ponyupPath)) {
  New-Item -ItemType Directory -Path $ponyupPath
}

Write-Host "Unzipping to $ponyupPath..."
Expand-Archive -Force -Path $zipPath -DestinationPath $ponyupPath

$platform = "$PlatformStringArch-pc-windows-msvc"
Write-Host "Setting platform to $platform..."
Set-Content -Path "$ponyupPath\.platform" -Value $platform

# Build the lock string from the Cloudsmith package version, not from
# `ponyup version`: a nightly's package version is a date, whereas the binary
# reports its semver, so only the Cloudsmith version produces a correct lock
# string for nightlies.
$channel = if ($Repository -eq 'releases') { 'release' } else { 'nightly' }
$lockStr = "ponyup-$channel-$pkgVersion-$PlatformStringArch-windows"
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

if ($SetPath) {
  $binDir = "$ponyupPath\bin"
  # Change only the User-scope PATH, through the registry. The simpler
  # [Environment]::SetEnvironmentVariable(..., 'User') corrupts it: its value is
  # $env:PATH, which is the System and User PATHs already merged and expanded,
  # and it stores the result as REG_SZ. That copies every System entry into the
  # User PATH and drops its REG_EXPAND_SZ type, so %VAR% entries stop expanding.
  # Reading only the raw User value and writing it back as ExpandString avoids
  # both the copy and the type change.
  $envKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
  try {
    $userPath = [string] $envKey.GetValue(
      'PATH', '',
      [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    # Compare each entry expanded and without a trailing slash, so a copy of the
    # bin directory written as %VAR% or with a trailing "\" is still detected.
    $binDirKey = $binDir.TrimEnd('\')
    $alreadyOnPath = $false
    foreach ($entry in ($userPath -split ';')) {
      if ([Environment]::ExpandEnvironmentVariables($entry).TrimEnd('\') -ieq $binDirKey) {
        $alreadyOnPath = $true
        break
      }
    }
    if (-not $alreadyOnPath) {
      Write-Host "Adding $binDir to PATH; you will need to restart your terminal to use it."
      $newUserPath =
        if (($userPath -eq '') -or $userPath.EndsWith(';')) {
          "$userPath$binDir"
        } else {
          "$userPath;$binDir"
        }
      $envKey.SetValue(
        'PATH', $newUserPath,
        [Microsoft.Win32.RegistryValueKind]::ExpandString)
      $env:PATH =
        if (($env:PATH -eq '') -or $env:PATH.EndsWith(';')) {
          "$env:PATH$binDir"
        } else {
          "$env:PATH;$binDir"
        }
      # A raw registry write does not notify running programs the way
      # SetEnvironmentVariable does. Without this broadcast, Explorer passes new
      # terminals the old PATH from its cached environment block until the next
      # sign-out.
      try {
        $signature = @'
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(
    IntPtr hWnd, uint msg, UIntPtr wParam, string lParam,
    uint flags, uint timeout, out UIntPtr result);
'@
        $user32 = Add-Type -MemberDefinition $signature `
          -Name 'PonyupNativeMethods' -Namespace 'Ponyup' -PassThru
        $HWND_BROADCAST = [IntPtr] 0xFFFF
        $WM_SETTINGCHANGE = 0x1A
        $SMTO_ABORTIFHUNG = 0x2
        $result = [UIntPtr]::Zero
        [void] $user32::SendMessageTimeout(
          $HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, 'Environment',
          $SMTO_ABORTIFHUNG, 5000, [ref] $result)
      }
      catch {
        Write-Host ("Could not notify running programs of the PATH change; " +
          "sign out and back in for it to take effect.")
      }
    }
    else {
      Write-Host "$binDir is already in PATH"
    }
  }
  finally {
    $envKey.Close()
  }
}
