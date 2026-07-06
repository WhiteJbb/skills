#Requires -Version 5.1
# Link this repo's skill folders into ~\.claude\skills via directory junctions,
# so editing the repo is deploying (no copy step). Safe to re-run.
$ErrorActionPreference = "Stop"

$dest = Join-Path $env:USERPROFILE ".claude\skills"
New-Item -ItemType Directory -Force $dest | Out-Null

foreach ($name in @("opus-boost", "sonnet-boost", "haiku-boost")) {
  $link = Join-Path $dest $name
  $target = Join-Path $PSScriptRoot $name
  if (-not (Test-Path $target)) { throw "skill folder not found: $target" }

  if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.LinkType -eq "Junction" -and "$($item.Target)" -eq $target) {
      Write-Host "$name : already linked"
      continue
    }
    Remove-Item $link -Recurse -Force
  }

  New-Item -ItemType Junction -Path $link -Target $target | Out-Null
  Write-Host "$name : linked -> $target"
}
