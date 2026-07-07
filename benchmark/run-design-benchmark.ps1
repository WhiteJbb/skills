#Requires -Version 5.1
<#
Design benchmark v2.
Same brief -> N arms generate a page in headless Claude Code:
  baseline        : brief only, Skill tool blocked
  design-boost    : SKILL.md + DESIGN-SYSTEM.md injected
  frontend-design : Anthropic official skill injected
  auto            : brief only, Skill tool ALLOWED -> measures self-invocation (fire)
Then: headless Edge screenshots (desktop 1440 / mobile 390), an OBJECTIVE mobile
overflow check (scrollWidth probe via --dump-dom), and PAIRWISE blind judging of
JudgedArms by MULTIPLE judge models (X/Y anonymized, order randomized). Reliability
= cross-judge agreement rate.

Usage:
  .\run-design-benchmark.ps1                                             # Sonnet 5 gen
  .\run-design-benchmark.ps1 -Model claude-opus-4-8                      # Opus gen
  .\run-design-benchmark.ps1 -Arms baseline,design-boost -JudgedArms baseline,design-boost
  .\run-design-benchmark.ps1 -Judges claude-opus-4-8                     # single judge
#>
param(
  [string]$Model = "claude-sonnet-5",
  [string[]]$Judges = @("claude-opus-4-8", "claude-fable-5"),
  [string]$TasksFile = "",
  [int]$MaxTurns = 25,
  [string[]]$Arms = @("baseline", "design-boost", "frontend-design", "auto"),
  [string[]]$JudgedArms = @("baseline", "design-boost", "frontend-design"),
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
    "auto" { return $null }
    "design-boost" {
      $s = [IO.File]::ReadAllText((Join-Path $repo "design-boost\SKILL.md")) -replace '(?s)^---.*?---\s*', ''
      $ds = [IO.File]::ReadAllText((Join-Path $repo "design-boost\DESIGN-SYSTEM.md"))
      return "$s`n`n<design-system-template>`n$ds`n</design-system-template>"
    }
    "frontend-design" {
      $p = Join-Path $env:USERPROFILE ".claude\plugins\cache\claude-plugins-official\frontend-design\unknown\skills\frontend-design\SKILL.md"
      if (-not (Test-Path $p)) { throw "frontend-design plugin not found: $p" }
      return [IO.File]::ReadAllText($p) -replace '(?s)^---.*?---\s*', ''
    }
    default { throw "unknown arm: $armName" }
  }
}

Add-Type -AssemblyName System.Drawing

function FileUrl($p) { return "file:///" + ($p -replace '\\', '/') }

function Invoke-Shot($url, $pngPath, $w, $h) {
  & $edge --headless=new --disable-gpu --hide-scrollbars --virtual-time-budget=9000 "--window-size=$w,$h" "--screenshot=$pngPath" $url | Out-Null
  for ($i = 0; $i -lt 20 -and -not (Test-Path $pngPath); $i++) { Start-Sleep -Milliseconds 500 }
  return [bool](Test-Path $pngPath)
}

function Take-Shot($htmlPath, $pngPath, $w, $h) {
  return (Invoke-Shot (FileUrl $htmlPath) $pngPath $w $h)
}

# Windows Chromium clamps the minimum window width (~492px viewport), so a direct
# --window-size=390 screenshot renders a 492px layout and silently CROPS the right
# ~100px (this poisoned round 1-2 mobile judging). Render mobile inside a true
# 390px iframe in a wide window, then crop the wide image down to the iframe.
function New-Wrapper($targetPath, $wrapperPath, $w, $h) {
  $leaf = Split-Path $targetPath -Leaf
  $wrapHtml = "<!doctype html><html><head><style>html,body{margin:0;padding:0}iframe{display:block;width:${w}px;height:${h}px;border:0}</style></head><body><iframe src=""$leaf""></iframe></body></html>"
  [IO.File]::WriteAllText($wrapperPath, $wrapHtml, (New-Object System.Text.UTF8Encoding($false)))
}

function Take-MobileShot($htmlPath, $pngPath, $w, $h) {
  $wrapper = "$htmlPath.mwrap.html"
  New-Wrapper $htmlPath $wrapper $w $h
  $full = "$pngPath.full.png"
  if (-not (Invoke-Shot (FileUrl $wrapper) $full 800 $h)) { return $false }
  $src = [System.Drawing.Image]::FromFile($full)
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($src, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), 0, 0, $w, $h, [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $src.Dispose()
  $bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
  return [bool](Test-Path $pngPath)
}

# Objective 390px overflow check: inject a probe that counts text elements whose ink
# overflows their box (scrollWidth > clientWidth) or that extend past the viewport,
# then paints a red/green bar; the bar color is read back from a screenshot pixel.
$script:ProbeJs = @'
<script>window.addEventListener('load',function(){setTimeout(function(){
var W=window.innerWidth,bad=0;
function innerScrollable(el){for(var p=el.parentElement;p;p=p.parentElement){var c=getComputedStyle(p);if((c.overflowX==='auto'||c.overflowX==='scroll')&&p.clientWidth<=W)return true}return false}
if(document.documentElement.scrollWidth>W+2)bad++;
document.querySelectorAll('body *').forEach(function(el){
  var cs=getComputedStyle(el); if(cs.display==='none'||cs.visibility==='hidden')return;
  var hasText=false,ns=el.childNodes; for(var i=0;i<ns.length;i++){if(ns[i].nodeType===3&&ns[i].textContent.trim()){hasText=true;break}}
  if(!hasText)return;
  if(cs.overflowX!=='auto'&&cs.overflowX!=='scroll'&&cs.textOverflow!=='ellipsis'&&el.scrollWidth>el.clientWidth+2){bad++;return}
  var r=el.getBoundingClientRect();
  if(r.width>0&&r.right>W+2&&!innerScrollable(el))bad++;
});
var d=document.createElement('div');
d.style.cssText='position:fixed;top:0;left:0;width:100%;height:24px;z-index:2147483647;background:'+(bad>0?'#FF0000':'#00FF00');
document.body.appendChild(d);},80);});</script>
'@

function Get-MobileOverflow($htmlPath) {
  $content = [IO.File]::ReadAllText($htmlPath)
  if ($content -match '</body>') { $content = $content -replace '</body>', "$($script:ProbeJs)</body>" } else { $content += $script:ProbeJs }
  $probeFile = "$htmlPath.ovfl.html"
  [IO.File]::WriteAllText($probeFile, $content, (New-Object System.Text.UTF8Encoding($false)))
  $wrapper = "$htmlPath.owrap.html"
  New-Wrapper $probeFile $wrapper 390 600
  $png = "$htmlPath.ovfl.png"
  if (-not (Invoke-Shot (FileUrl $wrapper) $png 800 600)) { return $null }
  $bmp = [System.Drawing.Bitmap]::FromFile($png)
  $p = $bmp.GetPixel(5, 5)
  $bmp.Dispose()
  if ($p.R -gt 200 -and $p.G -lt 100) { return [PSCustomObject]@{ overflow = $true } }
  if ($p.G -gt 200 -and $p.R -lt 100) { return [PSCustomObject]@{ overflow = $false } }
  return $null
}

function Invoke-Gen($prompt, $isAuto, $work) {
  $allowed = "Read,Write,Edit,MultiEdit,Glob,Grep"
  $disallowed = "Skill,Bash,WebFetch,WebSearch"
  if ($isAuto) { $allowed = "$allowed,Skill"; $disallowed = "Bash,WebFetch,WebSearch" }
  Push-Location $work
  $raw = $prompt | & claude -p --model $script:Model --max-turns $script:MaxTurns --output-format stream-json --verbose --allowedTools $allowed --disallowedTools $disallowed
  Pop-Location
  [System.IO.File]::WriteAllText((Join-Path $work "claude-stream.jsonl"), (($raw | Out-String).Trim()), (New-Object System.Text.UTF8Encoding($false)))
  $result = $null
  $skillsUsed = @()
  foreach ($line in @($raw)) {
    $obj = $null
    try { $obj = "$line" | ConvertFrom-Json } catch { continue }
    if ($null -eq $obj) { continue }
    if ($obj.type -eq "assistant" -and $obj.message.content -and (-not $obj.parent_tool_use_id)) {
      foreach ($c in @($obj.message.content)) {
        if ($c.type -eq "tool_use" -and "$($c.name)" -eq "Skill") { $skillsUsed += "$($c.input.skill)" }
      }
    }
    if ($obj.type -eq "result") { $result = $obj }
  }
  return [PSCustomObject]@{ result = $result; skills_used = $skillsUsed }
}

$tasks = Get-Content $TasksFile -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $OutRoot) { $OutRoot = Join-Path $PSScriptRoot "results" }
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $OutRoot "design-$stamp"
New-Item -ItemType Directory -Force $outDir | Out-Null
$runsFile = Join-Path $outDir "runs.jsonl"

[PSCustomObject]@{ model = $Model; judges = $Judges; arms = $Arms; judged_arms = $JudgedArms; max_turns = $MaxTurns } |
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
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $gen = Invoke-Gen $prompt ($arm -eq "auto") $work
    $sw.Stop()
    $json = $gen.result

    $html = Join-Path $work "index.html"
    $hasHtml = Test-Path $html
    $shots = $false
    $ovfl = $null
    if ($hasHtml) {
      $sd = Take-Shot $html (Join-Path $work "desktop.png") 1440 2200
      $sm = Take-MobileShot $html (Join-Path $work "mobile.png") 390 1700
      $shots = ($sd -and $sm)
      $ovfl = Get-MobileOverflow $html
    } else {
      Write-Warning "no index.html produced: $($task.id)/$arm"
    }

    $fired = $null
    if ($arm -eq "auto") { $fired = ($gen.skills_used.Count -gt 0) }

    $rec = [PSCustomObject]@{
      task = $task.id; arm = $arm; model = $Model
      html = $hasHtml; screenshots = $shots
      mobile_overflow = $(if ($ovfl) { $ovfl.overflow } else { $null })
      skill_fired = $fired
      skills_used = ($gen.skills_used -join ",")
      wall_s = [Math]::Round($sw.Elapsed.TotalSeconds, 1)
      turns = $(if ($json) { $json.num_turns } else { $null })
      out_tokens = $(if ($json -and $json.usage) { $json.usage.output_tokens } else { $null })
      cost_usd = $(if ($json) { $json.total_cost_usd } else { $null })
      is_error = $(if ($json) { $json.is_error } else { $true })
    }
    $genMetrics["$($task.id)|$arm"] = $rec
    Add-Content -Path $runsFile -Value ($rec | ConvertTo-Json -Compress) -Encoding UTF8

    $ovflLabel = "n/a"
    if ($null -ne $rec.mobile_overflow) { $ovflLabel = $(if ($rec.mobile_overflow) { "OVERFLOW" } else { "ok" }) }
    $fireLabel = ""
    if ($arm -eq "auto") { $fireLabel = $(if ($fired) { " | FIRED: $($gen.skills_used -join ',')" } else { " | not fired" }) }
    Write-Host ("    -> html:{0} shots:{1} mobile:{2} | {3}s | {4} turns | out {5} tok | `${6}{7}" -f $hasHtml, $shots, $ovflLabel, $rec.wall_s, $rec.turns, $rec.out_tokens, $rec.cost_usd, $fireLabel)
  }
}

# ---------- pairwise blind judging ----------
$pairRows = New-Object System.Collections.Generic.List[object]
$pairsFile = Join-Path $outDir "pairwise.jsonl"

foreach ($task in $tasks) {
  $avail = @($JudgedArms | Where-Object { Test-Path (Join-Path $outDir "$($task.id)_$_\desktop.png") })
  if ($avail.Count -lt 2) { Write-Warning "judging skipped for $($task.id): fewer than 2 entries"; continue }

  for ($i = 0; $i -lt $avail.Count - 1; $i++) {
    for ($j = $i + 1; $j -lt $avail.Count; $j++) {
      $armA = $avail[$i]; $armB = $avail[$j]
      $flip = ((Get-Random -Maximum 2) -eq 1)
      $xArm = $(if ($flip) { $armB } else { $armA })
      $yArm = $(if ($flip) { $armA } else { $armB })

      $pdir = Join-Path $outDir "$($task.id)_pair_$($armA)_vs_$($armB)"
      New-Item -ItemType Directory -Force $pdir | Out-Null
      foreach ($side in @(@("X", $xArm), @("Y", $yArm))) {
        Copy-Item (Join-Path $outDir "$($task.id)_$($side[1])\desktop.png") (Join-Path $pdir "$($side[0])-desktop.png")
        $m = Join-Path $outDir "$($task.id)_$($side[1])\mobile.png"
        if (Test-Path $m) { Copy-Item $m (Join-Path $pdir "$($side[0])-mobile.png") }
      }
      [PSCustomObject]@{ X = $xArm; Y = $yArm } | ConvertTo-Json | Set-Content (Join-Path $pdir "mapping.json") -Encoding UTF8

      $judgePrompt = @"
You are judging two anonymous implementations, X and Y, of the same design brief. You do not know how either was produced; judge ONLY what you see.

BRIEF given to both:
$($task.prompt)

In the current directory: X-desktop.png, X-mobile.png, Y-desktop.png, Y-mobile.png (desktop 1440px, mobile 390px; may crop below the fold). Read ALL four with the Read tool before deciding.

Pick the overall winner weighing: subject-specific distinctiveness (not mistakable for a generic template), typography, layout & mobile adaptation, color craft, and detail polish. Heavily penalize: known generic-AI looks (cream+serif+terracotta, dark bg+acid green, purple/blue gradient hero, glassmorphism, big-number gradient hero, meaningless 01/02/03 numbering) and responsive failures (content clipped or overflowing at 390px, desktop page merely shrunken).

Output ONLY this JSON, no fences, no prose:
{"winner":"X","margin":"slight|clear","reason":"one sentence"}
"@

      foreach ($judge in $Judges) {
        Write-Host "judging $($task.id): $armA vs $armB [$judge] ..."
        Push-Location $pdir
        $jraw = $judgePrompt | & claude -p --model $judge --max-turns 15 --output-format json --allowedTools "Read,Glob" --disallowedTools "Skill,Bash,WebFetch,WebSearch,Write,Edit"
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
          task = $task.id; gen_model = $Model
          arm_a = $armA; arm_b = $armB; x_arm = $xArm; y_arm = $yArm
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

$wins = $JudgedArms | ForEach-Object {
  $arm = $_
  $armPairs = @($valid | Where-Object { $_.arm_a -eq $arm -or $_.arm_b -eq $arm })
  [PSCustomObject]@{
    arm = $arm
    wins = @($valid | Where-Object { $_.winner -eq $arm }).Count
    clear_wins = @($valid | Where-Object { $_.winner -eq $arm -and $_.margin -eq "clear" }).Count
    judged = $armPairs.Count
    mobile_overflows = @($tasks | Where-Object { $gm = $genMetrics["$($_.id)|$arm"]; $gm -and $gm.mobile_overflow }).Count
  }
} | Sort-Object wins -Descending

$agreeTotal = 0; $agreeSame = 0
foreach ($task in $tasks) {
  foreach ($pairKey in @($valid | Where-Object { $_.task -eq $task.id } | Group-Object arm_a, arm_b)) {
    if ($pairKey.Group.Count -ge 2) {
      $agreeTotal++
      if ((@($pairKey.Group | Select-Object -ExpandProperty winner -Unique)).Count -eq 1) { $agreeSame++ }
    }
  }
}

Write-Host ""
Write-Host "=== Pairwise wins (gen model: $Model; judges: $($Judges -join ', ')) ==="
$wins | Format-Table -AutoSize
if ($agreeTotal -gt 0) {
  Write-Host ("Judge agreement: {0}/{1} pairs ({2}%)" -f $agreeSame, $agreeTotal, [Math]::Round(100 * $agreeSame / $agreeTotal, 0))
}
$autoRuns = @($genMetrics.Values | Where-Object { $_.arm -eq "auto" })
if ($autoRuns.Count -gt 0) {
  $firedRuns = @($autoRuns | Where-Object { $_.skill_fired })
  Write-Host ("Auto-fire: {0}/{1} tasks fired ({2})" -f $firedRuns.Count, $autoRuns.Count, (($firedRuns | ForEach-Object { $_.skills_used }) -join "; "))
}
$wins | Export-Csv (Join-Path $outDir "design-summary.csv") -NoTypeInformation -Encoding UTF8
Write-Host ""
Write-Host "Raw: $runsFile / $pairsFile"
