Param(
  [Parameter(HelpMessage="Architecture (native, x64).")]
  [string]
  $Binary = ""
)

$bytes = [System.IO.File]::ReadAllBytes($Binary)
$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
$machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
switch ($machine) {
  0x014c { Write-Output "x86" }
  0x8664 { Write-Output "x64" }
  0xAA64 { Write-Output "ARM64" }
  default { Write-Output "Unknown: $machine" }
}
