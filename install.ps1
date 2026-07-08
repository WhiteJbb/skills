#Requires -Version 5.1
# Link this repo's skill folders into ~\.claude\skills via directory junctions,
# so editing the repo is deploying (no copy step). Safe to re-run.
#   .\install.ps1                  # profile "all" (default): every active skill
#   .\install.ps1 -Profile sonnet  # measured-win subset for a Sonnet-primary setup
# Switching profiles prunes this repo's junctions that fall outside the new profile.
param(
  [ValidateSet("all", "sonnet")]
  [string]$Profile = "all"
)
$ErrorActionPreference = "Stop"

# Skill locations: category/name. Structure: active/ (measured win), neutral/ (tie/slight-loss/conditional),
# experimental/ (unmeasured variants, not installed).
$allSkills = @(
  "active/sonnet-boost", "active/haiku-boost", "active/design-boost", "active/summary-boost",
  "active/code-review-boost", "active/data-boost", "active/research-boost",
  "neutral/opus-boost", "neutral/fresh-eyes-done-gate", "neutral/report-boost",
  "neutral/slides-boost", "neutral/translate-boost", "neutral/persona-boost"
)

# Profiles.
# sonnet = skills with a measured win on Sonnet (README 처방표): sonnet-boost (tokens -66%),
# design-boost (baseline 0/11), summary-boost (unanimous clear), code-review/data/research-boost
# (2:0 each). haiku-boost rides along for Haiku fallback (only skill that flips FAIL->PASS).
# fresh-eyes-done-gate excluded: redundant with sonnet-boost's built-in done-gate probe.
$profiles = @{
  all    = $allSkills
  sonnet = @("active/sonnet-boost", "active/haiku-boost", "active/design-boost", "active/summary-boost",
             "active/code-review-boost", "active/data-boost", "active/research-boost")
}
$names = $profiles[$Profile]

$dest = Join-Path $env:USERPROFILE ".claude\skills"
New-Item -ItemType Directory -Force $dest | Out-Null

# Map location strings (category/name) to actual folder names for link names.
$skillNames = @{}
foreach ($locStr in $names) {
  $parts = $locStr -split "/"
  $skillName = $parts[-1]
  $skillNames[$skillName] = $locStr
}

foreach ($locStr in $names) {
  $parts = $locStr -split "/"
  $skillName = $parts[-1]  # "sonnet-boost"

  $link = Join-Path $dest $skillName
  $target = Join-Path $PSScriptRoot $locStr  # e.g., active/sonnet-boost
  if (-not (Test-Path $target)) { throw "skill folder not found: $target" }

  if (Test-Path $link) {
    $item = Get-Item $link -Force
    if ($item.LinkType -eq "Junction" -and "$($item.Target)" -eq $target) {
      Write-Host "$skillName : already linked"
      continue
    }
    # Junctions must be deleted via .Delete(): Remove-Item -Recurse on a junction
    # follows the reparse point and deletes the TARGET's files on PowerShell 5.1.
    if ($item.LinkType) { $item.Delete() } else { Remove-Item $link -Recurse -Force }
  }

  New-Item -ItemType Junction -Path $link -Target $target | Out-Null
  Write-Host "$skillName : linked -> $target"
}

# Prune junctions that point into this repo but are not in the selected profile,
# so switching profiles never leaves stale skills active. Foreign links/dirs untouched.
$repoPrefix = Join-Path $PSScriptRoot "*"
Get-ChildItem $dest -Force | Where-Object {
  $_.LinkType -eq "Junction" -and "$($_.Target)" -like $repoPrefix -and -not $skillNames.ContainsKey($_.Name)
} | ForEach-Object {
  $_.Delete()
  Write-Host "$($_.Name) : removed (not in profile '$Profile')"
}
