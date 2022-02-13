Param(
  [Parameter(Position=0, HelpMessage="The action to take (fetch, build, test, buildtest, install, package, clean).")]
  [string]
  $Command = 'build',

  [Parameter(HelpMessage="The build configuration (Release, Debug).")]
  [string]
  $Config = "Release",

  [Parameter(HelpMessage="The version number to set.")]
  [string]
  $Version = "",

  [Parameter(HelpMessage="Architecture (native, x64).")]
  [string]
  $Arch = "x86-64",

  [Parameter(HelpMessage="Directory to install to.")]
  [string]
  $Destdir = "build/install"
)

$ErrorActionPreference = "Stop"

$target = "ponyup" # The name of the target executable.
$targetPath = "cmd" # The source package directory.
$testPath = "../test" # The path of the tests package relative to $targetPath.
$isLibrary = $false

$rootDir = Split-Path $script:MyInvocation.MyCommand.Path
$srcDir = Join-Path -Path $rootDir -ChildPath $targetPath

if ($Config -ieq "Release")
{
  $configFlag = ""
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/release"
}
elseif ($Config -ieq "Debug")
{
  $configFlag = "--debug"
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/debug"
}
else
{
  throw "Invalid -Config path '$Config'; must be one of (Debug, Release)."
}

switch ($Version)
{
  "release" { $Version = Get-Content "$rootDir\VERSION" }
  "nightly" { $Version = "nightly" + (Get-Date).ToString("yyyyMMdd") }
  default { $Version = (Get-Content "$rootDir\VERSION") + "-" + (& git rev-parse --short --verify HEAD) }
}

$ponyArgs = "--define openssl_0.9.0"

Write-Host "Configuration:    $Config"
Write-Host "Version:          $Version"
Write-Host "Root directory:   $rootDir"
Write-Host "Source directory: $srcDir"
Write-Host "Build directory:  $buildDir"

# generate pony templated files if necessary
if (($Command -ne "clean") -and (Test-Path -Path "$rootDir\VERSION"))
{
  $versionTimestamp = (Get-ChildItem -Path "$rootDir\VERSION").LastWriteTimeUtc
  Get-ChildItem -Path $srcDir -Include "*.pony.in" -Recurse | ForEach-Object {
    $templateFile = $_.FullName
    $ponyFile = $templateFile.Substring(0, $templateFile.Length - 3)
    $ponyFileTimestamp = [DateTime]::MinValue
    if (Test-Path $ponyFile)
    {
      $ponyFileTimestamp = (Get-ChildItem -Path $ponyFile).LastWriteTimeUtc
    }
    if (($ponyFileTimestamp -lt $versionTimestamp) -or ($ponyFileTimestamp -lt $_.LastWriteTimeUtc))
    {
      Write-Host "$templateFile -> $ponyFile"
      ((Get-Content -Path $templateFile) -replace '%%VERSION%%', $Version) | Set-Content -Path $ponyFile
    }
  }
}

function BuildTarget
{
  $binaryFile = Join-Path -Path $buildDir -ChildPath "$target.exe"
  $binaryTimestamp = [DateTime]::MinValue
  if (Test-Path $binaryFile)
  {
    $binaryTimestamp = (Get-ChildItem -Path $binaryFile).LastWriteTimeUtc
  }

  :buildFiles foreach ($file in (Get-ChildItem -Path "$srcDir\.." -Include "*.pony" -Recurse))
  {
    if ($binaryTimestamp -lt $file.LastWriteTimeUtc)
    {
      Write-Host "corral run -- ponyc $configFlag $ponyArgs --cpu `"$Arch`" --output `"$buildDir`" --bin-name `"$target`" `"$srcDir`""
      $output = (corral run -- ponyc $configFlag $ponyArgs --cpu "$Arch" --output "$buildDir" --bin-name "$target" "$srcDir")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }
      break buildFiles
    }
  }
}

function BuildTest
{
  $testTarget = "test.exe"

  $testFile = Join-Path -Path $buildDir -ChildPath $testTarget
  $testTimestamp = [DateTime]::MinValue
  if (Test-Path $testFile)
  {
    $testTimestamp = (Get-ChildItem -Path $testFile).LastWriteTimeUtc
  }

  :testFiles foreach ($file in (Get-ChildItem -Path "$srcDir\.." -Include "*.pony" -Recurse))
  {
    if ($testTimestamp -lt $file.LastWriteTimeUtc)
    {
      $testDir = Join-Path -Path $srcDir -ChildPath $testPath
      Write-Host "corral run -- ponyc $configFlag $ponyArgs --cpu `"$Arch`" --output `"$buildDir`" --bin-name `"test`" `"$testDir`""
      $output = (corral run -- ponyc $configFlag $ponyArgs --cpu "$Arch" --output "$buildDir" --bin-name test "$testDir")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }
      break testFiles
    }
  }

  Write-Output "$testTarget is built" # force function to return a list of outputs
  return $testFile
}

switch ($Command.ToLower())
{
  "fetch"
  {
    Write-Host "corral fetch"
    $output = (corral fetch)
    $output | ForEach-Object { Write-Host $_ }
    if ($LastExitCode -ne 0) { throw "Error" }
    break
  }

  "build"
  {
    if (-not $isLibrary)
    {
      BuildTarget
    }
    else
    {
      Write-Host "$target is a library; nothing to build."
    }
    break
  }

  "buildtest"
  {
    BuildTest
    break
  }

  "test"
  {
    if ([Environment]::Is64BitOperatingSystem) {
      $env:PONYUP_PLATFORM = 'x86_64-pc-windows-msvc'
    }
    else {
      $env:PONYUP_PLATFORM = 'x86-pc-windows-msvc'
    }

    $testFile = (BuildTest)[-1]
    Write-Host "$testFile"
    & "$testFile"
    if ($LastExitCode -ne 0) { throw "Error" }
    break
  }

  "clean"
  {
    if (Test-Path "$buildDir")
    {
      Write-Host "Remove-Item -Path `"$buildDir`" -Recurse -Force"
      Remove-Item -Path "$buildDir" -Recurse -Force
    }
    break
  }

  "install"
  {
    if (-not $isLibrary)
    {
      $binDir = Join-Path -Path $Destdir -ChildPath "bin"

      if (-not (Test-Path $binDir))
      {
        mkdir "$binDir"
      }

      $binFile = Join-Path -Path $buildDir -ChildPath "$target.exe"
      Copy-Item -Path $binFile -Destination $binDir -Force
    }
    else
    {
      Write-Host "$target is a library; nothing to install."
    }
    break
  }

  "package"
  {
    if (-not $isLibrary)
    {
      $binDir = Join-Path -Path $Destdir -ChildPath "bin"
      $package = "$target-x86-64-pc-windows-msvc.zip"
      Write-Host "Creating $package..."

      Compress-Archive -Path $binDir -DestinationPath "$buildDir\..\$package" -Force
    }
    else
    {
      Write-Host "$target is a library; nothing to package."
    }
    break
  }

  default
  {
    throw "Unknown command '$Command'; must be one of (fetch, build, test, buildtest, install, package, clean)."
  }
}
