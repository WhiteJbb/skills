#Requires -Version 5.1
<#
Architecture / judgment benchmark (text output, no single right answer).
Same brief -> N candidates (model x skill) each produce a markdown design doc,
then PAIRWISE blind judging by multiple judge models (X/Y anonymized, order
randomized). Answers the question: can a skill-boosted Opus/Sonnet catch Fable
on open-ended design/architecture, even at higher token cost?

Usage:
  .\run-arch-benchmark.ps1
  .\run-arch-benchmark.ps1 -TasksFile .\arch-tasks.json -Judges claude-opus-4-8
#>
param(
  [string]$TasksFile = "",
  [string[]]$Judges = @("claude-opus-4-8", "claude-fable-5"),
  [int]$MaxTurns = 30,
  [string]$OutRoot = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)
if (-not $TasksFile) { $TasksFile = Join-Path $PSScriptRoot "arch-tasks.json" }
if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) { throw "claude CLI not found on PATH." }

# candidates: Fable is the reference; Opus/Sonnet in baseline and skill-boosted forms
$Candidates = @(
  @{ label = "fable-base";   model = "claude-fable-5";  skill = "" },
  @{ label = "opus-base";    model = "claude-opus-4-8"; skill = "" },
  @{ label = "opus-boost";   model = "claude-opus-4-8"; skill = "opus-boost" },
  @{ label = "sonnet-base";  model = "claude-sonnet-5"; skill = "" },
  @{ label = "sonnet-boost"; model = "claude-sonnet-5"; skill = "sonnet-boost" }
)

function Get-SkillBody($skill) {
  if (-not $skill) { return $null }
  $p = Join-Path $env:USERPROFILE ".claude\skills\$skill\SKILL.md"
  if (-not (Test-Path $p)) { throw "skill not found: $p" }
  return (Get-Content $p -Raw) -replace '(?s)^---.*?---\s*', ''
}

function Invoke-Gen($prompt, $model, $work) {
  Push-Location $work
  $raw = $prompt | & claude -p --model $model --max-turns $MaxTurns `
      --permission-mode bypassPermissions --output-format json `
      --disallowedTools "Skill,Bash,WebFetch,WebSearch"
  Pop-Location
  $txt = ($raw | Out-String).Trim()
  [System.IO.File]::WriteAllText((Join-Path $work "claude-output.json"), $txt, (New-Object System.Text.UTF8Encoding($false)))
  $json = $null
  try { $json = $txt | ConvertFrom-Json } catch { Write-Warning "gen parse failed in $work" }
  return $json
}

$tasks = Get-Content $TasksFile -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutRoot) { $OutRoot = Join-Path $PSScriptRoot "results" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutRoot "arch-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null
$runsFile = Join-Path $outDir "runs.jsonl"
[PSCustomObject]@{ candidates = ($Candidates | ForEach-Object { $_.label }); judges = $Judges; max_turns = $MaxTurns } |
  ConvertTo-Json | Set-Content (Join-Path $outDir "config.json") -Encoding UTF8

# ---------- generation ----------
$gen = @{}
$total = $tasks.Count * $Candidates.Count
$done = 0
foreach ($task in $tasks) {
  foreach ($c in $Candidates) {
    $done++
    $work = Join-Path $outDir "$($task.id)_$($c.label)"
    New-Item -ItemType Directory -Force $work | Out-Null
    $body = Get-SkillBody $c.skill
    if ($body) {
      $prompt = "You MUST follow every rule in the work discipline below while doing the task.`n`n<work-discipline>`n$body`n</work-discipline>`n`nTASK:`n$($task.prompt)"
    } else {
      $prompt = $task.prompt
    }
    Write-Host "[$done/$total] $($task.id) | $($c.label) ($($c.model)) ..."
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $json = Invoke-Gen $prompt $c.model $work
    $sw.Stop()
    $answer = if ($json) { [string]$json.result } else { "" }
    [System.IO.File]::WriteAllText((Join-Path $work "answer.md"), $answer, (New-Object System.Text.UTF8Encoding($false)))
    $rec = [PSCustomObject]@{
      task = $task.id; label = $c.label; model = $c.model; skill = $c.skill
      chars = $answer.Length
      wall_s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
      turns = $(if ($json) { $json.num_turns } else { $null })
      out_tokens = $(if ($json -and $json.usage) { $json.usage.output_tokens } else { $null })
      cost_usd = $(if ($json) { $json.total_cost_usd } else { $null })
    }
    $gen["$($task.id)|$($c.label)"] = $rec
    Add-Content -Path $runsFile -Value ($rec | ConvertTo-Json -Compress) -Encoding UTF8
    Write-Host ("    -> {0} chars | {1}s | {2} turns | out {3} tok | `${4}" -f $answer.Length, $rec.wall_s, $rec.turns, $rec.out_tokens, $rec.cost_usd)
  }
}

# ---------- pairwise blind judging ----------
$pairRows = New-Object System.Collections.Generic.List[object]
$pairsFile = Join-Path $outDir "pairwise.jsonl"
$labels = @($Candidates | ForEach-Object { $_.label })

foreach ($task in $tasks) {
  $avail = @($labels | Where-Object { (Test-Path (Join-Path $outDir "$($task.id)_$_\answer.md")) -and ((Get-Item (Join-Path $outDir "$($task.id)_$_\answer.md")).Length -gt 0) })
  if ($avail.Count -lt 2) { Write-Warning "judging skipped for $($task.id)"; continue }

  for ($i = 0; $i -lt $avail.Count - 1; $i++) {
    for ($j = $i + 1; $j -lt $avail.Count; $j++) {
      $armA = $avail[$i]; $armB = $avail[$j]
      $flip = ((Get-Random -Maximum 2) -eq 1)
      $xArm = $(if ($flip) { $armB } else { $armA })
      $yArm = $(if ($flip) { $armA } else { $armB })
      $pdir = Join-Path $outDir "$($task.id)_pair_$($armA)_vs_$($armB)"
      New-Item -ItemType Directory -Force $pdir | Out-Null
      Copy-Item (Join-Path $outDir "$($task.id)_$xArm\answer.md") (Join-Path $pdir "X.md")
      Copy-Item (Join-Path $outDir "$($task.id)_$yArm\answer.md") (Join-Path $pdir "Y.md")
      [PSCustomObject]@{ X = $xArm; Y = $yArm } | ConvertTo-Json | Set-Content (Join-Path $pdir "mapping.json") -Encoding UTF8

      $judgePrompt = @"
You are judging two anonymous design documents, X and Y, answering the same architecture brief. You do not know who wrote either; judge ONLY their content.

BRIEF given to both:
$($task.prompt)

Read X.md and Y.md in the current directory with the Read tool before deciding. Pick the overall better ENGINEERING design, weighing: soundness and realism of the data model; correctness and completeness of the real-time availability logic (including the back-to-back multi-service case); whether concurrent double-booking is genuinely prevented (a real atomic/locking/transactional mechanism, not hand-waving); a realistic no-show policy that honestly states its own risks; and the depth and honesty of the stated trade-offs. Reward specific, correct, failure-aware reasoning. Penalize: vagueness and hand-waving, missing the concurrency race, ignoring a stated requirement, and generic checklists with no real decisions.

Output ONLY this JSON, no fences, no prose:
{"winner":"X","margin":"slight|clear","reason":"one sentence naming the deciding difference"}
"@

      foreach ($judge in $Judges) {
        Write-Host "judging $($task.id): $armA vs $armB [$judge] ..."
        Push-Location $pdir
        $jraw = $judgePrompt | & claude -p --model $judge --max-turns 12 --output-format json --allowedTools "Read,Glob" --disallowedTools "Skill,Bash,WebFetch,WebSearch,Write,Edit"
        Pop-Location
        $winnerArm = $null; $margin = $null; $reason = $null
        try {
          $jres = ($jraw | Out-String) | ConvertFrom-Json
          $text = ([string]$jres.result).Trim() -replace '(?s)^\s*```(json)?\s*', '' -replace '(?s)\s*```\s*$', ''
          $verdict = $text | ConvertFrom-Json
          $w = "$($verdict.winner)".Trim().ToUpper()
          if ($w -eq "X") { $winnerArm = $xArm } elseif ($w -eq "Y") { $winnerArm = $yArm }
          $margin = "$($verdict.margin)"; $reason = "$($verdict.reason)"
        } catch { Write-Warning "judge parse failed: $($task.id) $armA vs $armB [$judge]" }
        $row = [PSCustomObject]@{
          task = $task.id; arm_a = $armA; arm_b = $armB; x_arm = $xArm; y_arm = $yArm
          judge = $judge; winner = $winnerArm; margin = $margin; reason = $reason
        }
        $pairRows.Add($row)
        Add-Content -Path $pairsFile -Value ($row | ConvertTo-Json -Compress) -Encoding UTF8
        if ($winnerArm) { Write-Host "    -> $winnerArm ($margin)" }
      }
    }
  }
}

# ---------- aggregate ----------
$valid = @($pairRows | Where-Object { $_.winner })
$wins = $labels | ForEach-Object {
  $arm = $_
  $armPairs = @($valid | Where-Object { $_.arm_a -eq $arm -or $_.arm_b -eq $arm })
  [PSCustomObject]@{
    candidate = $arm
    wins = @($valid | Where-Object { $_.winner -eq $arm }).Count
    clear_wins = @($valid | Where-Object { $_.winner -eq $arm -and $_.margin -eq "clear" }).Count
    judged = $armPairs.Count
    avg_tokens = ($tasks | ForEach-Object { $gen["$($_.id)|$arm"].out_tokens } | Where-Object { $_ } | Measure-Object -Average).Average
  }
} | Sort-Object wins -Descending

$agreeTotal = 0; $agreeSame = 0
foreach ($task in $tasks) {
  foreach ($pk in @($valid | Where-Object { $_.task -eq $task.id } | Group-Object arm_a, arm_b)) {
    if ($pk.Group.Count -ge 2) { $agreeTotal++; if ((@($pk.Group | Select-Object -ExpandProperty winner -Unique)).Count -eq 1) { $agreeSame++ } }
  }
}

Write-Host ""
Write-Host "=== Pairwise wins (judges: $($Judges -join ', ')) ==="
$wins | Format-Table -AutoSize
if ($agreeTotal -gt 0) { Write-Host ("Judge agreement: {0}/{1} pairs ({2}%)" -f $agreeSame, $agreeTotal, [Math]::Round(100 * $agreeSame / $agreeTotal, 0)) }
$wins | Export-Csv (Join-Path $outDir "arch-summary.csv") -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Raw: $runsFile / $pairsFile"
