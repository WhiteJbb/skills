#Requires -Version 5.1
<#
Recreates the pinned OSS checkouts under benchmark\oss\ (gitignored).
Run once per machine before using oss-tasks.json.
#>
$ErrorActionPreference = "Stop"

$oss = Join-Path $PSScriptRoot "oss"
New-Item -ItemType Directory -Force $oss | Out-Null

$src = Join-Path $oss "markdown-git"
if (-not (Test-Path $src)) {
  git clone --quiet https://github.com/Python-Markdown/markdown.git $src
}

# task id -> pinned commit (parent of the upstream fix)
$pins = @{
  # Python-Markdown issue #495; fix = 07dfa4e, pin = its parent
  "md-ref-backtick" = "fb6b27a6ff90980b5bcb0cd51528a7c9dc3a93ca"
}

foreach ($kv in $pins.GetEnumerator()) {
  $dest = Join-Path $oss $kv.Key
  if (Test-Path $dest) { Remove-Item -Recurse -Force -Confirm:$false $dest }
  New-Item -ItemType Directory -Force $dest | Out-Null
  git -C $src archive $kv.Value | tar -x -C $dest
  Write-Host ("{0} -> {1}" -f $kv.Key, $kv.Value)
}
Write-Host "done. run: .\run-benchmark.ps1 -TasksFile .\oss-tasks.json"
