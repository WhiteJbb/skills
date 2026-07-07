#Requires -Version 5.1
<#
Skill A/B benchmark for Claude Code headless mode.
Runs each task in tasks.json twice (baseline vs skill-injected) and records
tokens, cost, wall/API time, turns, and test pass/fail.

Usage:
  .\run-benchmark.ps1                                        # sonnet-boost on claude-sonnet-5, 1 run each
  .\run-benchmark.ps1 -Runs 3                                # 3 runs per task/mode (recommended)
  .\run-benchmark.ps1 -Model claude-opus-4-8 -Skill opus-boost
  .\run-benchmark.ps1 -Modes baseline                        # baseline only
  .\run-benchmark.ps1 -TasksFile .\gate-tasks.json           # gate-verification tasks
#>
param(
  [string]$Model = "claude-sonnet-5",
  [string]$Skill = "sonnet-boost",
  [string]$TasksFile = "",
  [int]$Runs = 1,
  [int]$MaxTurns = 40,
  [string[]]$Modes = @("baseline", "skill"),
  [string]$OutRoot = ""
)

$ErrorActionPreference = "Stop"
$OutputEncoding = New-Object System.Text.UTF8Encoding($false)

if (-not $TasksFile) { $TasksFile = Join-Path $PSScriptRoot "tasks.json" }

if ($null -eq (Get-Command claude -ErrorAction SilentlyContinue)) {
  throw "claude CLI not found on PATH."
}
if ($null -eq (Get-Command python -ErrorAction SilentlyContinue)) {
  Write-Warning "python not found on PATH - the sample task checks will all fail."
}

$skillPath = Join-Path $env:USERPROFILE ".claude\skills\$Skill\SKILL.md"
if (-not (Test-Path $skillPath)) { throw "Skill not found: $skillPath" }
$skillBody = (Get-Content $skillPath -Raw) -replace '(?s)^---.*?---\s*', ''

$tasks = Get-Content $TasksFile -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $OutRoot) { $OutRoot = Join-Path $PSScriptRoot "results" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutRoot $stamp
New-Item -ItemType Directory -Force $outDir | Out-Null
$runsFile = Join-Path $outDir "runs.jsonl"

[PSCustomObject]@{ model = $Model; skill = $Skill; runs = $Runs; modes = $Modes; max_turns = $MaxTurns } |
  ConvertTo-Json | Set-Content (Join-Path $outDir "config.json") -Encoding UTF8

function AvgOf($group, $name) {
  $vals = @($group | ForEach-Object { $_.$name } | Where-Object { $null -ne $_ })
  if ($vals.Count -eq 0) { return $null }
  return [Math]::Round(($vals | Measure-Object -Average).Average, 2)
}

$total = $tasks.Count * $Modes.Count * $Runs
$done = 0
$records = New-Object System.Collections.Generic.List[object]

foreach ($task in $tasks) {
  foreach ($mode in $Modes) {
    for ($r = 1; $r -le $Runs; $r++) {
      $done++
      $work = Join-Path $outDir ("{0}_{1}_run{2}" -f $task.id, $mode, $r)
      New-Item -ItemType Directory -Force $work | Out-Null

      if ($task.source) {
        $src = $task.source
        if (-not (Split-Path $src -IsAbsolute)) {
          $src = Join-Path (Split-Path (Resolve-Path $TasksFile) -Parent) $src
        }
        if (-not (Test-Path $src)) { throw "Task '$($task.id)': source not found: $src" }
        $xd = @(".git", "node_modules", ".venv", "venv", "__pycache__", "dist", "build", ".next", "target", "results")
        if ($null -ne $task.exclude) { $xd = @($task.exclude) }
        $rcArgs = @((Resolve-Path $src).Path, $work, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NP")
        if ($xd.Count -gt 0) { $rcArgs += "/XD"; $rcArgs += $xd }
        robocopy @rcArgs | Out-Null
        if ($LASTEXITCODE -ge 8) { throw "Task '$($task.id)': robocopy failed ($LASTEXITCODE) copying $src" }
      }

      if ($task.setup) {
        foreach ($p in $task.setup.PSObject.Properties) {
          $fp = Join-Path $work $p.Name
          $parent = Split-Path $fp -Parent
          if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Force $parent | Out-Null }
          [System.IO.File]::WriteAllText($fp, $p.Value, (New-Object System.Text.UTF8Encoding($false)))
        }
      }

      if ($task.prep) {
        Push-Location $work
        try { Invoke-Expression $task.prep | Out-Null } catch { Write-Warning "Task '$($task.id)': prep failed: $_" }
        Pop-Location
      }

      if ($mode -eq "skill") {
        $prompt = "You MUST follow every rule in the work discipline below while doing the task.`n`n<work-discipline>`n$skillBody`n</work-discipline>`n`nTASK:`n$($task.prompt)"
      } else {
        $prompt = $task.prompt
      }

      # All modes stream events so we can count tool calls (Skill invocations,
      # subagent spawns). Subagent tool is named Task in CLI 2.1.x; "Agent" kept
      # as an alternate for version drift.
      $cliArgs = @("-p", "--model", $Model,
                   "--permission-mode", "bypassPermissions",
                   "--max-turns", "$MaxTurns",
                   "--output-format", "stream-json", "--verbose")
      if ($mode -ne "auto") {
        # keep installed skills from auto-loading; skill mode injects the body itself
        $cliArgs += @("--disallowedTools", "Skill")
      }

      Write-Host ("[{0}/{1}] {2} | {3} | run {4} ..." -f $done, $total, $task.id, $mode, $r)

      Push-Location $work
      $sw = [System.Diagnostics.Stopwatch]::StartNew()
      $raw = $prompt | & claude @cliArgs
      $sw.Stop()
      Pop-Location

      $rawText = ($raw | Out-String).Trim()
      [System.IO.File]::WriteAllText((Join-Path $work "claude-stream.jsonl"), $rawText, (New-Object System.Text.UTF8Encoding($false)))
      $json = $null
      $skillsUsed = @()
      $toolCounts = @{}
      foreach ($line in @($raw)) {
        $obj = $null
        try { $obj = "$line" | ConvertFrom-Json } catch { continue }
        if ($null -eq $obj) { continue }
        # count main-loop tool calls only; events emitted inside a subagent carry parent_tool_use_id
        if ($obj.type -eq "assistant" -and $obj.message.content -and (-not $obj.parent_tool_use_id)) {
          foreach ($c in @($obj.message.content)) {
            if ($c.type -ne "tool_use") { continue }
            $n = "$($c.name)"
            if ($toolCounts.ContainsKey($n)) { $toolCounts[$n]++ } else { $toolCounts[$n] = 1 }
            if ($n -eq "Skill") { $skillsUsed += "$($c.input.skill)" }
          }
        }
        if ($obj.type -eq "result") { $json = $obj }
      }
      if ($null -eq $json) { Write-Warning "no result event: $($task.id)/$mode/run$r" }

      $agentsSpawned = 0
      foreach ($n in @("Task", "Agent")) {
        if ($toolCounts.ContainsKey($n)) { $agentsSpawned += $toolCounts[$n] }
      }
      $toolsUsed = (@($toolCounts.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ",")

      $passed = $null
      if ($task.check) {
        Push-Location $work
        $eap = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        $checkOut = ""
        try {
          $checkOut = (Invoke-Expression $task.check 2>&1 | Out-String)
          $passed = ($LASTEXITCODE -eq 0)
        } catch {
          $passed = $false
          $checkOut = $checkOut + "`n[check exception] $_"
        }
        $ErrorActionPreference = $eap
        Pop-Location
        # keep the grader stdout (e.g. per-bug PASS/FAIL lines) for post-hoc analysis
        [System.IO.File]::WriteAllText((Join-Path $work "check-output.txt"), $checkOut.Trim(), (New-Object System.Text.UTF8Encoding($false)))
      }

      $apiS = $null; $turns = $null; $cost = $null; $isErr = $null
      $inTok = $null; $outTok = $null; $cacheRead = $null; $cacheWrite = $null
      if ($json) {
        $isErr = $json.is_error
        $turns = $json.num_turns
        $cost = $json.total_cost_usd
        if ($json.duration_api_ms) { $apiS = [Math]::Round($json.duration_api_ms / 1000, 1) }
        if ($json.usage) {
          $inTok = $json.usage.input_tokens
          $outTok = $json.usage.output_tokens
          $cacheRead = $json.usage.cache_read_input_tokens
          $cacheWrite = $json.usage.cache_creation_input_tokens
        }
        if ($json.result) {
          [System.IO.File]::WriteAllText((Join-Path $work "ANSWER.md"), [string]$json.result, (New-Object System.Text.UTF8Encoding($false)))
        }
      }

      # honesty metric: skill reports emit `rules proven: N/M | probe: fired|not needed`
      $rulesProven = $null; $rulesTotal = $null; $probeDecision = $null
      if ($json.result) {
        $ans = [string]$json.result
        $m = [regex]::Match($ans, 'rules proven:\s*(\d+)\s*/\s*(\d+)')
        if ($m.Success) { $rulesProven = [int]$m.Groups[1].Value; $rulesTotal = [int]$m.Groups[2].Value }
        $mp = [regex]::Match($ans, 'probe:\s*(fired|not needed|skipped)', 'IgnoreCase')
        if ($mp.Success) { $probeDecision = $mp.Groups[1].Value.ToLower() }
      }

      $fired = $null
      if ($mode -eq "auto") { $fired = ($skillsUsed.Count -gt 0) }

      $rec = [PSCustomObject]@{
        task = $task.id; mode = $mode; run = $r; model = $Model
        passed = $passed
        skill_fired = $fired
        skills_used = ($skillsUsed -join ",")
        agents_spawned = $agentsSpawned
        tools_used = $toolsUsed
        rules_proven = $rulesProven
        rules_total = $rulesTotal
        probe_decision = $probeDecision
        wall_s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
        api_s = $apiS
        turns = $turns
        in_tokens = $inTok
        out_tokens = $outTok
        cache_read = $cacheRead
        cache_write = $cacheWrite
        cost_usd = $cost
        is_error = $isErr
      }
      $records.Add($rec)
      Add-Content -Path $runsFile -Value ($rec | ConvertTo-Json -Compress) -Encoding UTF8

      $passLabel = "n/a"
      if ($passed -eq $true) { $passLabel = "PASS" }
      if ($passed -eq $false) { $passLabel = "FAIL" }
      $fireLabel = ""
      if ($mode -eq "auto") {
        if ($fired) { $fireLabel = " | skill fired: $($skillsUsed -join ',')" } else { $fireLabel = " | skill NOT fired" }
      }
      Write-Host ("    -> {0} | {1}s | {2} turns | out {3} tok | agents {4} | `${5}{6}" -f $passLabel, $rec.wall_s, $turns, $outTok, $agentsSpawned, $cost, $fireLabel)
    }
  }
}

$summary = $records | Group-Object task, mode | ForEach-Object {
  $g = $_.Group
  $checked = @($g | Where-Object { $null -ne $_.passed })
  $passRate = $null
  if ($checked.Count -gt 0) {
    $passRate = [Math]::Round((@($checked | Where-Object { $_.passed }).Count / $checked.Count) * 100, 0)
  }
  $autoRuns = @($g | Where-Object { $null -ne $_.skill_fired })
  $firePct = $null
  if ($autoRuns.Count -gt 0) {
    $firePct = [Math]::Round((@($autoRuns | Where-Object { $_.skill_fired }).Count / $autoRuns.Count) * 100, 0)
  }
  [PSCustomObject]@{
    task = $g[0].task; mode = $g[0].mode; runs = $g.Count
    pass_pct = $passRate
    fire_pct = $firePct
    avg_wall_s = AvgOf $g "wall_s"
    avg_api_s = AvgOf $g "api_s"
    avg_turns = AvgOf $g "turns"
    avg_agents = AvgOf $g "agents_spawned"
    avg_out_tok = AvgOf $g "out_tokens"
    avg_cache_read = AvgOf $g "cache_read"
    avg_cost_usd = AvgOf $g "cost_usd"
  }
} | Sort-Object task, mode

$summary | Format-Table -AutoSize
$summary | Export-Csv (Join-Path $outDir "summary.csv") -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Detail: $runsFile"
Write-Host "Summary: $(Join-Path $outDir 'summary.csv')"
