#Requires -Version 5.1
<#
Cross-run pairwise blind judging — compare screenshot outputs from DIFFERENT
benchmark result dirs (e.g., a Fable reference run vs a skill run).

PairsFile JSON:
[
  { "task": "tide-app", "brief": "<the brief given to both>",
    "label_a": "fable-baseline",  "dir_a": "results\\design-A\\tide-app_baseline",
    "label_b": "sonnet-design-boost", "dir_b": "results\\design-B\\tide-app_design-boost" }
]
Each dir must contain desktop.png and mobile.png. X/Y assignment is randomized.

Usage:
  .\judge-pairs.ps1 -PairsFile .\fable-ref-pairs.json
  .\judge-pairs.ps1 -PairsFile .\pairs.json -Judges claude-opus-4-8
#>
param(
  [Parameter(Mandatory = $true)][string]$PairsFile,
  [string[]]$Judges = @("claude-opus-4-8", "claude-fable-5"),
  [string]$OutRoot = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) { throw "claude CLI not found on PATH." }

$pairs = Get-Content $PairsFile -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutRoot) { $OutRoot = Join-Path $PSScriptRoot "results" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutRoot "crossjudge-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null
$pairsOut = Join-Path $outDir "pairwise.jsonl"

function Resolve-Dir($base, $p) {
  if (Split-Path $p -IsAbsolute) { return $p }
  return (Join-Path $base $p)
}

$rows = New-Object System.Collections.Generic.List[object]
$idx = 0
foreach ($pair in $pairs) {
  $idx++
  $dirA = Resolve-Dir $PSScriptRoot $pair.dir_a
  $dirB = Resolve-Dir $PSScriptRoot $pair.dir_b
  foreach ($d in @($dirA, $dirB)) {
    if (-not (Test-Path (Join-Path $d "desktop.png"))) { throw "missing desktop.png in $d" }
  }
  $flip = ((Get-Random -Maximum 2) -eq 1)
  $xLabel = $(if ($flip) { $pair.label_b } else { $pair.label_a })
  $xDir = $(if ($flip) { $dirB } else { $dirA })
  $yLabel = $(if ($flip) { $pair.label_a } else { $pair.label_b })
  $yDir = $(if ($flip) { $dirA } else { $dirB })

  $pdir = Join-Path $outDir ("{0:d2}_{1}_{2}_vs_{3}" -f $idx, $pair.task, $pair.label_a, $pair.label_b)
  New-Item -ItemType Directory -Force $pdir | Out-Null
  Copy-Item (Join-Path $xDir "desktop.png") (Join-Path $pdir "X-desktop.png")
  Copy-Item (Join-Path $yDir "desktop.png") (Join-Path $pdir "Y-desktop.png")
  if (Test-Path (Join-Path $xDir "mobile.png")) { Copy-Item (Join-Path $xDir "mobile.png") (Join-Path $pdir "X-mobile.png") }
  if (Test-Path (Join-Path $yDir "mobile.png")) { Copy-Item (Join-Path $yDir "mobile.png") (Join-Path $pdir "Y-mobile.png") }
  [PSCustomObject]@{ X = $xLabel; Y = $yLabel } | ConvertTo-Json | Set-Content (Join-Path $pdir "mapping.json") -Encoding UTF8

  $judgePrompt = @"
You are judging two anonymous implementations, X and Y, of the same design brief. You do not know how either was produced; judge ONLY what you see.

BRIEF given to both:
$($pair.brief)

In the current directory: X-desktop.png, X-mobile.png, Y-desktop.png, Y-mobile.png (desktop 1440px, mobile 390px; may crop below the fold). Read ALL four with the Read tool before deciding.

Pick the overall winner weighing: subject-specific distinctiveness (not mistakable for a generic template), typography, layout & mobile adaptation, color craft, and detail polish. Heavily penalize: known generic-AI looks (cream+serif+terracotta, dark bg+acid green, purple/blue gradient hero, glassmorphism, big-number gradient hero, meaningless 01/02/03 numbering) and responsive failures (content clipped or overflowing at 390px, desktop page merely shrunken).

Output ONLY this JSON, no fences, no prose:
{"winner":"X","margin":"slight|clear","reason":"one sentence"}
"@

  foreach ($judge in $Judges) {
    Write-Host "judging [$idx/$($pairs.Count)] $($pair.task): $($pair.label_a) vs $($pair.label_b) [$judge] ..."
    Push-Location $pdir
    $jraw = $judgePrompt | & claude -p --model $judge --max-turns 15 --output-format json --allowedTools "Read,Glob" --disallowedTools "Skill,Bash,WebFetch,WebSearch,Write,Edit"
    Pop-Location
    $winnerLabel = $null; $margin = $null; $reason = $null
    try {
      $jres = ($jraw | Out-String) | ConvertFrom-Json
      $text = ([string]$jres.result).Trim() -replace '(?s)^\s*```(json)?\s*', '' -replace '(?s)\s*```\s*$', ''
      $verdict = $text | ConvertFrom-Json
      $w = "$($verdict.winner)".Trim().ToUpper()
      if ($w -eq "X") { $winnerLabel = $xLabel } elseif ($w -eq "Y") { $winnerLabel = $yLabel }
      $margin = "$($verdict.margin)"; $reason = "$($verdict.reason)"
    } catch { Write-Warning "judge parse failed: $($pair.task) [$judge]" }

    $row = [PSCustomObject]@{
      task = $pair.task; label_a = $pair.label_a; label_b = $pair.label_b
      x = $xLabel; y = $yLabel
      judge = $judge; winner = $winnerLabel; margin = $margin; reason = $reason
    }
    $rows.Add($row)
    Add-Content -Path $pairsOut -Value ($row | ConvertTo-Json -Compress) -Encoding UTF8
    if ($winnerLabel) { Write-Host "    -> $winnerLabel ($margin)" }
  }
}

$valid = @($rows | Where-Object { $_.winner })
$labels = @($pairs | ForEach-Object { $_.label_a; $_.label_b } | Sort-Object -Unique)
$wins = $labels | ForEach-Object {
  $l = $_
  [PSCustomObject]@{
    label = $l
    wins = @($valid | Where-Object { $_.winner -eq $l }).Count
    clear_wins = @($valid | Where-Object { $_.winner -eq $l -and $_.margin -eq "clear" }).Count
    judged = @($valid | Where-Object { $_.label_a -eq $l -or $_.label_b -eq $l }).Count
  }
} | Sort-Object wins -Descending

$agreeTotal = 0; $agreeSame = 0
foreach ($g in @($valid | Group-Object task, label_a, label_b)) {
  if ($g.Group.Count -ge 2) {
    $agreeTotal++
    if ((@($g.Group | Select-Object -ExpandProperty winner -Unique)).Count -eq 1) { $agreeSame++ }
  }
}

Write-Host ""
Write-Host "=== Cross-run pairwise wins (judges: $($Judges -join ', ')) ==="
$wins | Format-Table -AutoSize
if ($agreeTotal -gt 0) { Write-Host ("Judge agreement: {0}/{1} pairs" -f $agreeSame, $agreeTotal) }
$wins | Export-Csv (Join-Path $outDir "summary.csv") -NoTypeInformation -Encoding UTF8
Write-Host "Raw: $pairsOut"
