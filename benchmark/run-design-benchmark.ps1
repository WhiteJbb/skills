#Requires -Version 5.1
<#
Design A/B/C benchmark.
Same brief -> N arms (baseline / design-boost / frontend-design) generate a page
in headless Claude Code -> headless Edge screenshots (desktop + mobile) ->
a blind LLM judge scores the anonymized screenshots on 5 design dimensions.

Usage:
  .\run-design-benchmark.ps1                                  # Sonnet 5, all 3 arms
  .\run-design-benchmark.ps1 -Arms baseline,design-boost
  .\run-design-benchmark.ps1 -Model claude-opus-4-8 -JudgeModel claude-fable-5
#>
param(
  [string]$Model = "claude-sonnet-5",
  [string]$JudgeModel = "claude-fable-5",
  [string]$TasksFile = "",
  [int]$MaxTurns = 25,
  [string[]]$Arms = @("baseline", "design-boost", "frontend-design"),
  [string]$OutRoot = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

if (-not $TasksFile) { $TasksFile = Join-Path $PSScriptRoot "design-tasks.json" }
$repo = Split-Path $PSScriptRoot -Parent
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) { throw "Edge not found: $edge" }
if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) { throw "claude CLI not found on PATH." }

function Get-SkillBody($armName) {
  switch ($armName) {
    "baseline" { return $null }
    "design-boost" {
      $s = (Get-Content (Join-Path $repo "design-boost\SKILL.md") -Raw) -replace '(?s)^---.*?---\s*', ''
      $ds = Get-Content (Join-Path $repo "design-boost\DESIGN-SYSTEM.md") -Raw
      return "$s`n`n<design-system-template>`n$ds`n</design-system-template>"
    }
    "frontend-design" {
      $p = Join-Path $env:USERPROFILE ".claude\plugins\cache\claude-plugins-official\frontend-design\unknown\skills\frontend-design\SKILL.md"
      if (-not (Test-Path $p)) { throw "frontend-design plugin not found: $p" }
      return (Get-Content $p -Raw) -replace '(?s)^---.*?---\s*', ''
    }
    default { throw "unknown arm: $armName" }
  }
}

function Take-Shot($htmlPath, $pngPath, $w, $h) {
  $url = "file:///" + ($htmlPath -replace '\\', '/')
  & $edge --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=8000 "--window-size=$w,$h" "--screenshot=$pngPath" $url | Out-Null
  for ($i = 0; $i -lt 20 -and -not (Test-Path $pngPath); $i++) { Start-Sleep -Milliseconds 500 }
  return [bool](Test-Path $pngPath)
}

$tasks = Get-Content $TasksFile -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutRoot) { $OutRoot = Join-Path $PSScriptRoot "results" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutRoot "design-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null
$runsFile = Join-Path $outDir "runs.jsonl"

[PSCustomObject]@{ model = $Model; judge = $JudgeModel; arms = $Arms; max_turns = $MaxTurns } |
  ConvertTo-Json | Set-Content (Join-Path $outDir "config.json") -Encoding UTF8

# ---------- generation ----------
$genMetrics = @{}
$total = $tasks.Count * $Arms.Count
$done = 0

foreach ($task in $tasks) {
  foreach ($arm in $Arms) {
    $done++
    $work = Join-Path $outDir "$($task.id)_$arm"
    New-Item -ItemType Directory -Force $work | Out-Null

    $body = Get-SkillBody $arm
    if ($body) {
      $prompt = "You MUST follow every rule in the design discipline below while doing the task.`n`n<design-discipline>`n$body`n</design-discipline>`n`nTASK:`n$($task.prompt)"
    } else {
      $prompt = $task.prompt
    }

    Write-Host "[$done/$total] $($task.id) | $arm ..."
    Push-Location $work
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    # no bypassPermissions: the task only needs file tools, everything else is denied
    $raw = $prompt | & claude -p --model $Model --max-turns $MaxTurns --output-format json --allowedTools "Read,Write,Edit,MultiEdit,Glob,Grep" --disallowedTools "Skill,Bash,WebFetch,WebSearch"
    $sw.Stop()
    Pop-Location

    $json = $null
    try { $json = ($raw | Out-String) | ConvertFrom-Json } catch { Write-Warning "result parse failed: $($task.id)/$arm" }

    $html = Join-Path $work "index.html"
    $hasHtml = Test-Path $html
    $shots = $false
    if ($hasHtml) {
      $sd = Take-Shot $html (Join-Path $work "desktop.png") 1440 2200
      $sm = Take-Shot $html (Join-Path $work "mobile.png") 390 1700
      $shots = ($sd -and $sm)
    } else {
      Write-Warning "no index.html produced: $($task.id)/$arm"
    }

    $rec = [PSCustomObject]@{
      task = $task.id; arm = $arm; model = $Model
      html = $hasHtml; screenshots = $shots
      wall_s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
      turns = $(if ($json) { $json.num_turns } else { $null })
      out_tokens = $(if ($json -and $json.usage) { $json.usage.output_tokens } else { $null })
      cost_usd = $(if ($json) { $json.total_cost_usd } else { $null })
      is_error = $(if ($json) { $json.is_error } else { $true })
    }
    $genMetrics["$($task.id)|$arm"] = $rec
    Add-Content -Path $runsFile -Value ($rec | ConvertTo-Json -Compress) -Encoding UTF8
    Write-Host ("    -> html:{0} shots:{1} | {2}s | {3} turns | out {4} tok | `${5}" -f $hasHtml, $shots, $rec.wall_s, $rec.turns, $rec.out_tokens, $rec.cost_usd)
  }
}

# ---------- blind judging ----------
$rows = New-Object System.Collections.Generic.List[object]

foreach ($task in $tasks) {
  $avail = @($Arms | Where-Object { Test-Path (Join-Path $outDir "$($task.id)_$_\desktop.png") })
  if ($avail.Count -lt 2) { Write-Warning "judge skipped for $($task.id): fewer than 2 entries have screenshots"; continue }

  $labels = @("A", "B", "C", "D")[0..($avail.Count - 1)]
  $shuffled = @($avail | Get-Random -Count $avail.Count)
  $map = @{}
  for ($i = 0; $i -lt $labels.Count; $i++) { $map[$labels[$i]] = $shuffled[$i] }

  $jdir = Join-Path $outDir "$($task.id)_judge"
  New-Item -ItemType Directory -Force $jdir | Out-Null
  foreach ($l in $labels) {
    Copy-Item (Join-Path $outDir "$($task.id)_$($map[$l])\desktop.png") (Join-Path $jdir "$l-desktop.png")
    $m = Join-Path $outDir "$($task.id)_$($map[$l])\mobile.png"
    if (Test-Path $m) { Copy-Item $m (Join-Path $jdir "$l-mobile.png") }
  }
  ($map.GetEnumerator() | ForEach-Object { [PSCustomObject]@{ label = $_.Key; arm = $_.Value } }) |
    ConvertTo-Json | Set-Content (Join-Path $jdir "mapping.json") -Encoding UTF8

  $labelList = $labels -join ", "
  $judgePrompt = @"
You are a senior design director judging $($labels.Count) anonymous implementations ($labelList) of the same design brief. You do not know how each was produced; judge ONLY what you see in the screenshots.

BRIEF given to all entrants:
$($task.prompt)

In the current directory each entry has <label>-desktop.png (1440px wide) and <label>-mobile.png (390px wide). Read ALL of these image files with the Read tool before scoring anything. Screenshots may crop content below the fold; judge what is visible.

Score each entry 0-10 (decimals allowed) on:
- distinctiveness: could this NOT be mistaken for a generic template? does it feel designed for THIS specific subject?
- typography: face choice and pairing, scale, hierarchy, spacing of type
- layout: composition, rhythm, whitespace, mobile adaptation quality
- color: palette craft, harmony, contrast, restraint
- craft: detail quality - alignment, consistency, spacing discipline, polish

Penalize known generic-AI looks in the relevant dimension scores and name them in ai_tells: cream bg + high-contrast serif + terracotta accent; near-black bg + acid green accent; purple/blue gradient hero; glassmorphism cards; Inter-for-everything; big-number-with-gradient hero; meaningless 01/02/03 numbering.

Output ONLY this JSON, no markdown fences, no prose before or after:
{"entries":[{"label":"A","scores":{"distinctiveness":0,"typography":0,"layout":0,"color":0,"craft":0},"ai_tells":[],"note":"one sentence"}],"ranking":["bestLabel","...","worstLabel"]}
"@

  Write-Host "judging $($task.id) ($($avail.Count) entries, blind) ..."
  Push-Location $jdir
  # judge only ever reads the screenshots
  $jraw = $judgePrompt | & claude -p --model $JudgeModel --max-turns 15 --output-format json --allowedTools "Read,Glob" --disallowedTools "Skill,Bash,WebFetch,WebSearch,Write,Edit"
  Pop-Location

  $verdict = $null
  try {
    $jres = ($jraw | Out-String) | ConvertFrom-Json
    $text = ([string]$jres.result).Trim() -replace '(?s)^\s*```(json)?\s*', '' -replace '(?s)\s*```\s*$', ''
    [System.IO.File]::WriteAllText((Join-Path $jdir "judge-raw.json"), $text, (New-Object System.Text.UTF8Encoding($false)))
    $verdict = $text | ConvertFrom-Json
  } catch {
    Write-Warning "judge output parse failed for $($task.id): $_"
    continue
  }

  foreach ($e in $verdict.entries) {
    $arm = $map[[string]$e.label]
    $s = $e.scores
    $totalScore = [Math]::Round(($s.distinctiveness + $s.typography + $s.layout + $s.color + $s.craft), 1)
    $rank = ([array]::IndexOf(@($verdict.ranking | ForEach-Object { "$_" }), [string]$e.label) + 1)
    $gm = $genMetrics["$($task.id)|$arm"]
    $rows.Add([PSCustomObject]@{
      task = $task.id; arm = $arm; label = $e.label; rank = $rank
      total = $totalScore
      distinct = $s.distinctiveness; typo = $s.typography; layout = $s.layout; color = $s.color; craft = $s.craft
      ai_tells = (@($e.ai_tells) -join "; ")
      note = $e.note
      gen_cost_usd = $(if ($gm) { $gm.cost_usd } else { $null })
      gen_out_tok = $(if ($gm) { $gm.out_tokens } else { $null })
      gen_wall_s = $(if ($gm) { $gm.wall_s } else { $null })
    })
  }
}

$rows | Sort-Object task, rank | Format-Table task, arm, rank, total, distinct, typo, layout, color, craft, gen_cost_usd -AutoSize
$rows | Sort-Object task, rank | Export-Csv (Join-Path $outDir "design-summary.csv") -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Screenshots + mappings per task under: $outDir"
Write-Host "Summary: $(Join-Path $outDir 'design-summary.csv')"
