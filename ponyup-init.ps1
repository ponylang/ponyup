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

try {
  $triple = "$Arch-pc-windows-msvc"
  $zipName = "ponyup-$triple.zip"
  $zipPath = Join-Path $tempPath $zipName
  $algorithm = 'SHA512'

  if ($Repository -eq 'releases') {
    $base = "https://api.github.com/repos/ponylang/ponyup/releases"
    $page = 0
    do {
      if ($page -eq 0) {
        try { $releases = @(Invoke-RestMethod -Uri "$base/latest") }
        catch {
          if ($_.Exception.Response.StatusCode.value__ -ne 404) { throw }
          $releases = @()
        }
      } else {
        $releases = Invoke-RestMethod -Uri "${base}?per_page=20&page=$page"
      }
      foreach ($release in $releases) {
        if ($release.draft -or $release.prerelease) { continue }
        $assets = $release.assets | Where-Object state -eq uploaded
        $archive = $assets | Where-Object name -eq $zipName
        $sibling = $assets | Where-Object name -eq "$zipName.sha512"
        if ($archive -and $sibling) { break }
      }
      if ($archive -and $sibling) { break }
      if ($page -gt 0 -and $releases.Count -lt 20) { throw "No release contains $zipName and its checksum" }
      $page++
    } while ($true)

    $pkgVersion = $release.tag_name
    $assetHeaders = @{ Accept = 'application/octet-stream' }
    $checksumPath = Join-Path $tempPath 'checksum'
    Invoke-WebRequest -UseBasicParsing -Uri $sibling.url -Headers $assetHeaders -OutFile $checksumPath
    $checksum = (Get-Content -Raw $checksumPath).Trim()
    Invoke-WebRequest -UseBasicParsing -Uri $archive.url -Headers $assetHeaders -OutFile $zipPath
  } elseif ($Repository -eq 'nightlies') {
    $repo = "ponylang/nightly/ponyup-$triple"
    $base = "https://ghcr.io/v2/$repo"
    $tokenUrl = "https://ghcr.io/token?service=ghcr.io&scope=repository:${repo}:pull"
    $token = (Invoke-RestMethod -Uri $tokenUrl).token
    $auth = @{ Authorization = "Bearer $token" }
    $url = "$base/tags/list?n=100"
    $pkgVersion = ''
    while ($url) {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $auth
      $tags = ($response.Content | ConvertFrom-Json).tags
      foreach ($tag in $tags) {
        if ($tag -cmatch '^[0-9]{8}$' -and $tag -gt $pkgVersion) { $pkgVersion = $tag }
      }
      $url = $null
      if (($response.Headers['Link'] -join ',') -match '<([^>]+)>;\s*rel="next"') {
        $next = $Matches[1]
        if (-not $next.StartsWith("/v2/$repo/tags/list?")) { throw "Unexpected GHCR pagination URL" }
        $url = "https://ghcr.io$next"
      }
    }
    if (-not $pkgVersion) { throw "No nightly tags for $repo" }

    $manifestHeaders = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.oci.image.manifest.v1+json' }
    $manifest = Invoke-RestMethod -Uri "$base/manifests/$pkgVersion" -Headers $manifestHeaders
    if ($manifest.artifactType -cne 'application/vnd.ponylang.nightly.v1') {
      throw "Unexpected nightly artifact type"
    }
    $layer = $manifest.layers[0]
    if ($manifest.layers.Count -ne 1 -or $layer.annotations.'org.opencontainers.image.title' -cne $zipName) {
      throw "Unexpected archive in nightly manifest"
    }
    $layerDigest = $layer.digest
    if ($layerDigest -cnotmatch '^sha256:([0-9a-f]{64})$') { throw "Invalid archive digest in nightly manifest" }
    $checksum = $Matches[1]
    $algorithm = 'SHA256'
    Invoke-WebRequest -UseBasicParsing -Uri "$base/blobs/$layerDigest" -Headers $auth -OutFile $zipPath
  } else {
    $url = "https://api.cloudsmith.io/packages/ponylang/${Repository}/?query=ponyup-$triple&page=1&page_size=1"
    $packages = Invoke-RestMethod -Uri $url
    $package = $packages | Select-Object -First 1
    if (-not $package.version -or -not $package.cdn_url -or -not $package.checksum_sha256) {
      throw "Failed to find ponyup in the '$Repository' repository"
    }
    $pkgVersion = $package.version
    $checksum = $package.checksum_sha256
    $algorithm = 'SHA256'
    Invoke-WebRequest -UseBasicParsing -Uri $package.cdn_url -OutFile $zipPath
  }

  $dlChecksum = (Get-FileHash -Algorithm $algorithm -Path $zipPath).Hash.ToLower()
  if ($dlChecksum -ne $checksum.ToLower()) {
    throw "checksum mismatch: expected $checksum, calculated $dlChecksum"
  }
  Write-Host "checksum ok"

  if ($pkgVersion -cnotmatch '^[a-zA-Z0-9._-]+$') { throw 'Invalid ponyup version' }
  $channel = if ($Repository -eq 'releases') { 'release' } else { 'nightly' }
  $lockStr = "ponyup-$channel-$pkgVersion-$PlatformStringArch-windows"
  $ponyupPath = $Prefix
  $binDir = Join-Path $ponyupPath 'bin'
  $null = New-Item -ItemType Directory -Path $binDir -Force
  Expand-Archive -Path $zipPath -DestinationPath $tempPath
  $versionBin = Join-Path $ponyupPath "$lockStr\bin"
  $null = New-Item -ItemType Directory -Path $versionBin -Force
  Move-Item -LiteralPath "$tempPath\bin\ponyup.exe" -Destination "$versionBin\ponyup.exe" -Force
  Set-Content -LiteralPath "$binDir\ponyup.bat" -Encoding Ascii -Value '@echo off', "`"%~dp0..\$lockStr\bin\ponyup.exe`" %* & exit /b"
  $oldExe = Join-Path $binDir 'ponyup.exe'
  if (Test-Path -LiteralPath $oldExe) { Remove-Item -LiteralPath $oldExe }
} finally {
  Remove-Item -LiteralPath $tempPath -Recurse -Force
}

$platform = "$PlatformStringArch-pc-windows-msvc"
Write-Host "Setting platform to $platform..."
Set-Content -Path "$ponyupPath\.platform" -Value $platform

Write-Host "Locking ponyup version to $lockStr..."
$lockPath = "$ponyupPath\.lock"

$newContent = @()
if (Test-Path $lockPath) {
  $newContent = @(foreach ($entry in Get-Content $lockPath) {
    if (-not $entry) { continue }
    if ($entry -match '^ponyup-') {
      $pkg = ($entry -split ' ')[0]
      if ($pkg -ne $lockStr -and (Test-Path -LiteralPath (Join-Path $ponyupPath $pkg) -PathType Container)) { $pkg }
    } else { $entry }
  })
}
Set-Content -Path $lockPath -Value ($newContent + "$lockStr *")

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
