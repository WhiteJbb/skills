# Skill A/B Benchmark

`opus-boost` / `sonnet-boost` 스킬 적용 전후의 **품질(테스트 통과율) · 토큰 · 비용 · 속도 · 턴 수**를 비교한다.

## 요구 사항

- `claude` CLI 로그인 상태 (PATH에 있어야 함)
- `python` (샘플 과제의 자동 채점에 사용)
- 주의: **모든 실행은 실제 Claude 호출이다.** 구독(OAuth) 로그인 상태면 달러 청구 없이 **요금제 사용량 한도(5시간 롤링 윈도우 + 주간 한도)에서 차감**되고, `ANTHROPIC_API_KEY`로 인증된 경우에만 API 실비가 청구된다. 현재 한도는 `/usage`로 확인. 기본 설정(과제 4개 × 2모드 × 1회 = 8회 호출)으로 먼저 돌려보고 늘릴 것 — 벤치마크가 소모한 한도만큼 일반 Claude Code 작업 여유가 줄어든다.

## 사용법

```powershell
cd benchmark

# 기본: sonnet-boost를 claude-sonnet-5로, 과제당 1회
.\run-benchmark.ps1

# 통계적으로 의미 있게: 과제당 3회 (권장)
.\run-benchmark.ps1 -Runs 3

# Opus + opus-boost 조합
.\run-benchmark.ps1 -Model claude-opus-4-8 -Skill opus-boost

# baseline만 다시 측정
.\run-benchmark.ps1 -Modes baseline
```

## 작동 방식

- **baseline 모드**: 과제 프롬프트만 전달. `--disallowedTools Skill`로 설치된 스킬의 자동 로드를 차단해 순수 기본 성능을 측정.
- **skill 모드**: `~\.claude\skills\<이름>\SKILL.md`의 규칙 본문을 프롬프트 앞에 주입. 스킬이 로드된 상태와 같은 토큰 부하로 A/B 비교.
- **auto 모드**: 주입도 차단도 없이 Skill 도구를 열어 두고, 이벤트 스트림에서 Skill 호출을 감지해 **모델이 스스로 스킬을 발동하는지**(`fire_pct`)를 측정. 규칙이 좋아도 실전에서 안 불리면 무용지물이므로, 스킬 description의 트리거 품질을 검증하는 모드다. `-Modes auto` 또는 `-Modes baseline,skill,auto`로 실행.
- 과제마다 격리된 작업 폴더가 생성되고, 완료 후 `check` 명령(테스트)의 종료 코드로 PASS/FAIL 판정.

## 결과 해석

`results\<타임스탬프>\` 아래에 저장:

| 파일 | 내용 |
|---|---|
| `summary.csv` | 과제×모드별 평균 — 통과율, 시간, 턴, 토큰, 비용 |
| `runs.jsonl` | 실행 1회당 원시 기록 |
| `<과제>_<모드>_run<N>\` | 작업 폴더 (생성된 코드, `ANSWER.md`, `claude-output.json`) |

주요 지표:

- `pass_pct` — **품질**. 스킬의 존재 이유. 이게 오르면 나머지 비용은 트레이드오프.
- `fire_pct` — auto 모드에서 스킬이 자동 발동된 비율. 낮으면 스킬 description을 손봐야 한다는 신호 (규칙 내용의 문제가 아님). 어떤 스킬이 불렸는지는 `runs.jsonl`의 `skills_used`에 기록.
- `avg_out_tok` / `avg_cost_usd` — 토큰 사용량과 비용. `cost_usd`는 구독 로그인 시 실제 청구액이 아니라 **API 환산 추정치**다.
- `avg_wall_s` / `avg_api_s` — 응답 속도. wall은 체감 시간, api는 순수 모델 시간.
- `avg_turns` — 도구 호출 횟수. 스킬 모드에서 검증 단계만큼 늘어나는 게 정상. baseline보다 크게 줄었다면 삽질(재시도 루프)이 줄었다는 신호.

주의할 점:

- 1회 실행은 편차가 크다. 비교 목적이면 `-Runs 3` 이상.
- 첫 실행은 프롬프트 캐시가 비어 있어 느릴 수 있다. `cache_read`/`cache_write` 값으로 확인 가능.
- 샘플 과제 3개는 쉬운 편이라 baseline도 자주 통과한다. 스킬 효과는 **어려운 과제일수록** 커지므로, 실제 프로젝트의 까다로운 버그를 `tasks.json`에 추가해 보는 게 가장 의미 있다.

## 실측 결과 (2026-07-06)

`csv-parser` 과제(숨김 테스트 채점, 아래 참고) × `claude-sonnet-5` × `sonnet-boost`, 모드당 1회:

| 지표 | baseline | skill | 차이 |
|---|---|---|---|
| 숨김 테스트 | PASS | PASS | 동일 |
| 소요 시간 | 446.6초 | 154.0초 | **2.9배 빠름** |
| 출력 토큰 | 42,234 | 14,264 | **66% 절감** |
| 비용(API 환산) | $1.38 | $0.75 | **46% 절감** |
| 턴 수 | 6 | 7 | 비슷 |

관찰:

- 품질은 동률(둘 다 통과)이었지만 **효율 격차가 극적** — baseline은 턴당 ~7k 토큰을 쏟으며 장황하게 작업한 반면, skill 모드는 계약서 → 하나 바꾸고 즉시 확인 → 간결 출력 규칙대로 움직여 같은 품질을 1/3 토큰으로 냈다. 스킬 주입 오버헤드(~1k 토큰) 대비 출력 28k 토큰을 회수.
- skill 모드의 최종 보고는 규칙대로 한국어 3줄 계약 검증 형식이었고, 확인 불가능한 항목(숨김 테스트 결과)을 "불확실함"으로 정직하게 표시했다. baseline은 영어로 단정형 보고.
- 한계: 모드당 1회라 시간·토큰 수치는 편차 가능(격차가 3배라 방향성은 유의미). 통과율 차이는 이 난이도에서 미검출 — Sonnet 5는 스펙을 전부 명시하면 풀어낸다. 통과율 격차를 보려면 Haiku로 돌리거나 더 어려운 과제 필요.
- 원시 데이터: `results\20260706-155250\`

### 후속 실험: auto 모드 + Haiku 비교 (같은 날)

같은 csv-parser 과제, 모드당 1회. 전체 매트릭스:

| 모델 | 모드 | 통과 | 자동 발동 | 시간(초) | 출력 토큰 | 턴 |
|---|---|---|---|---|---|---|
| Sonnet 5 | baseline | PASS | — | 446.6 | 42,234 | 6 |
| Sonnet 5 | skill | PASS | — | 154.0 | 14,264 | 7 |
| Sonnet 5 | auto | PASS | **발동됨** (sonnet-boost) | 141.1 | 12,257 | 9 |
| Haiku 4.5 | baseline | PASS | — | 103.4 | 13,917 | 8 |
| Haiku 4.5 | skill | PASS | — | 175.1 | 20,972 | **22** |
| Haiku 4.5 | auto | PASS | **미발동** | 42.5 | 5,881 | 6 |

관찰:

- **Sonnet은 스킬을 스스로 부른다 (fire 1/1).** auto 성적(141초/12.3k tok)이 강제 주입(154초/14.3k)과 사실상 같다 — description 트리거가 작동하고, 발동되면 효과도 그대로. 실전 사용 근거 확보.
- **Haiku는 스킬을 부르지 않았고 (fire 0/1), 강제 주입하면 오히려 손해였다.** 주입 시 턴이 8→22로 폭증 — "하나 바꾸고 즉시 확인" 게이트를 Haiku가 우직하게 수행하며 오버헤드만 쌓였다. Haiku baseline은 원래 간결해서(Sonnet baseline처럼 장황하지 않음) 교정할 낭비 자체가 없었다.
- **전 조합 PASS** — csv-parser는 Haiku 4.5에게도 충분히 어렵지 않다. 통과율 변별에는 더 어려운 과제가 필요하다.
- 종합: **스킬의 가치는 "모델이 낭비하거나 실수하는 지점"이 있을 때 발생한다.** Sonnet의 장황한 시행착오 교정에는 큰 이득(3배), 이미 간결·정확하게 푸는 조합에는 순비용. 무조건 켜는 것보다 과제 난이도가 모델 능력을 초과하는 구간에서 쓰는 것이 맞다.
- 원시 데이터: `results\20260706-163210\` (Sonnet auto), `results\20260706-163432\` (Haiku)

### 후속 실험 2: haiku-boost — "Haiku를 Sonnet 급으로" 검증 (같은 날)

Haiku가 baseline으로는 실패하도록 설계한 고난도 과제 `expr-eval`(수식 계산기 — 우선순위 코너, `^` 우결합, 에러 13종을 숨김 테스트로 채점)로 3자 비교. haiku-boost는 sonnet-boost와 철학이 다름: 프로세스 게이트 대신 **"구현 전에 스펙의 모든 규칙을 자체 assert로 변환"**하는 검증 우선 설계.

| 실험 | 통과 | 시간(초) | 턴 | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|
| Haiku baseline | **FAIL** | 271.1 | 10 | 21,644 | $0.21 |
| Haiku + haiku-boost | **PASS** | 242.4 | 24 | 32,559 | $0.36 |
| Sonnet 5 baseline | PASS | 152.0 | 6 | 14,652 | $0.75 |

관찰:

- **Haiku baseline은 예측된 방식 그대로 실패** — 스펙에 명시된 규칙("연산자 없이 인접한 값 `1 2` → ValueError")을 구현에서 누락. 작은 모델의 실패 모드 = 규칙 누락임을 재확인.
- **haiku-boost가 FAIL → PASS로 뒤집음.** "assert 없는 규칙은 틀리게 될 규칙"이라는 spec→test 강제가 정확히 그 누락을 막았다. 토큰 1.5배는 자체 테스트 작성 비용이고, 이번엔 품질을 샀다 (csv-parser에서 sonnet-boost 주입이 순비용이었던 것과 대조).
- **"Sonnet 급" 판정: 결과 품질은 도달, 효율은 미달.** Haiku+boost는 Sonnet baseline과 같은 PASS를 절반 비용($0.36 vs $0.75)에 냈지만, 1.6배 느리고 턴/토큰은 더 씀. 객관적으로 채점 가능한 과제에서는 "Haiku+boost ≈ Sonnet 품질, 절반 가격" 등식이 성립.
- 한계: 셀당 1회, 과제 1개. 일반화하려면 반복과 과제 추가 필요. 판단형(채점 불가) 과제에는 이 방식이 적용되지 않음.
- 원시 데이터: `results\20260706-164917\` (Haiku), `results\20260706-165751\` (Sonnet)

### 후속 실험 3: Opus + opus-boost (같은 날)

같은 csv-parser 과제, 모드당 1회, `claude-opus-4-8`:

| 모드 | 통과 | 자동 발동 | 시간(초) | 출력 토큰 | 턴 | 비용(환산) |
|---|---|---|---|---|---|---|
| baseline | PASS | — | 236.4 | 18,410 | 6 | $0.97 |
| skill | PASS | — | 207.1 | 16,224 | 5 | $0.69 |
| auto | PASS | **발동됨** (opus-boost) | 303.0 | 22,522 | 9 | $0.98 |

관찰:

- **Opus에는 온건한 이득.** 주입 시 12% 빠르고 토큰 12% 절감, 턴도 6→5. Sonnet(3배)만큼 극적이지 않은 이유는 Opus baseline이 원래 정돈되어 있어서다 (출력 18.4k — Sonnet baseline 42k의 절반 이하).
- **3모델 기울기 확인.** 규율 스킬의 효과는 모델의 낭비 성향에 비례한다: Sonnet(낭비 큼) +190% 효율 / Opus(낭비 적음) +12% / Haiku(낭비 없음) 역효과. "스킬은 모델별 처방"이라는 결론이 세 번째 모델로 재확인됐다.
- **자동 발동 1/1** — opus-boost description이 Opus에서 작동. 단 이 auto 실행은 baseline보다 느리고 토큰도 많았는데(발동·검증 오버헤드 또는 1회 편차), n=1이라 판별 불가. 반복 측정 필요.
- 원시 데이터: `results\20260706-170342\`

### 후속 실험 4: 강화판(멀티에이전트 게이트) 회귀 검증 (같은 날)

opus-boost/sonnet-boost에 Fable식 멀티에이전트 패턴을 **조건부 게이트**로 추가한 강화판을 전체 5과제 × skill 모드로 재측정 (baseline은 같은 날 측정치 재사용). 추가된 게이트: 계획 토너먼트(넓은 해법 공간), fresh-context 반박 검증(위험한 diff), loop-until-dry(감사형 과제), Explore 위임(광역 탐색).

전체 결과 (skill 모드, 과제당 1회):

| 모델 | 과제 | 통과 | 시간(초) | 턴 | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|---|
| Sonnet 5 | bugfix-stats | PASS | 25.3 | 6 | 1,600 | $0.25 |
| Sonnet 5 | impl-duration | PASS | 48.2 | 5 | 3,220 | $0.30 |
| Sonnet 5 | refactor-callsites | PASS | 23.0 | 8 | 1,313 | $0.24 |
| Sonnet 5 | csv-parser | PASS | 386.7 | 8 | 15,199 | $1.65 |
| Sonnet 5 | expr-eval | PASS | 256.7 | 10 | 12,401 | $1.21 |
| Opus 4.8 | bugfix-stats | PASS | 38.4 | 7 | 1,545 | $0.19 |
| Opus 4.8 | impl-duration | PASS | 44.1 | 5 | 2,506 | $0.21 |
| Opus 4.8 | refactor-callsites | PASS | 38.1 | 8 | 1,897 | $0.20 |
| Opus 4.8 | csv-parser | PASS | 383.0 | 7 | 18,971 | $1.30 |
| Opus 4.8 | expr-eval | PASS | 196.7 | 6 | 15,057 | $0.67 |

구판 skill 대비 (csv-parser, 같은 날 측정):

| 지표 (csv-parser) | 구판 skill | 강화판 skill |
|---|---|---|
| Sonnet 5: 토큰 / 턴 | 14,264 / 7 | 15,199 / 8 |
| Opus 4.8: 토큰 / 턴 | 16,224 / 5 | 18,971 / 7 |

관찰:

- **10/10 PASS, 게이트 오발동 없음.** 작은 과제 3개는 1.3~3.2k 토큰으로 그대로 저렴했다. refactor-callsites는 여러 파일이 얽힌 과제지만 실제 diff는 단일 파일(fmt.py)이라 게이트가 규칙 문언대로 정확히 침묵 — 강화판이 비용 프로파일을 해치지 않는다.
- 토큰/턴은 구판과 동급(Sonnet +7%, Opus +17% — n=1 편차 범위). 벽시계 시간은 두 모델 모두 이전 대비 ~2배였으나 토큰·턴이 같으므로 스킬 탓이 아니라 시간대 API 부하로 판단.
- **한계: 이 실험은 "게이트가 조용해야 할 때 조용함"만 증명한다.** 발동해야 할 상황(진짜 multi-file diff, 넓은 해법 공간, 감사형 과제)이 과제셋에 없어 게이트의 이득은 미검증. 발동 검증용 과제 추가가 다음 단계 — 설계는 [gate-verification-plan.md](gate-verification-plan.md) 참고.
- 원시 데이터: `results\20260706-172413\` (Sonnet), `results\20260706-173633\` (Opus)

### 숨김 테스트 패턴

쉬운 과제는 모델이 보이는 테스트를 통과할 때까지 고치면 되므로 pass_pct 변별력이 없다. `csv-parser`처럼 **스펙은 프롬프트에 전부 명시하되, 보이는 테스트는 기본 케이스만 주고 채점은 `hidden\`의 숨김 테스트로** 하면 "보이는 테스트만 통과시키는 성급함"과 "스펙 전항목 구현"의 차이가 통과율로 드러난다. 숨김 테스트는 `check`에서 작업 폴더로 복사해 실행한다 (tasks.json의 csv-parser 항목 참고).

## 다른 프로젝트에서 벤치마크하기

실제 프로젝트를 대상으로 하려면 과제에 `source`를 지정한다. 실행(run)마다 프로젝트가 격리된 작업 폴더로 **복사**되므로 원본은 절대 수정되지 않고, baseline/skill 모드가 항상 동일한 초기 상태에서 출발한다.

```json
{
  "id": "myapp-bugfix",
  "source": "C:\\work\\myapp",
  "exclude": [".git", "node_modules", "dist"],
  "prep": "npm install --silent",
  "prompt": "Fix the bug where the date filter returns yesterday's rows. npm test must pass.",
  "check": "npm test"
}
```

- `source` — 복사할 프로젝트 경로. 상대 경로면 tasks.json 위치 기준. 과제 파일을 프로젝트 안에 두고 `"source": "."`로 쓰는 패턴이 편하다.
- `exclude` — 복사에서 제외할 폴더 이름. 생략 시 기본값: `.git, node_modules, .venv, venv, __pycache__, dist, build, .next, target, results`. 지정하면 기본값을 **대체**한다.
- `prep` — claude 실행 **전에** 작업 폴더에서 실행할 준비 명령(의존성 설치 등). 측정 시간에 포함되지 않는다.
- `setup` — source 복사 후에 덮어쓸 파일이 있으면 함께 사용 가능(예: 일부러 버그 주입).

프로젝트별 과제 파일을 그 프로젝트에 두고 이렇게 실행:

```powershell
& c:\Users\admin\Desktop\skills\benchmark\run-benchmark.ps1 `
    -TasksFile C:\work\myapp\bench-tasks.json `
    -OutRoot C:\work\myapp\bench-results `
    -Runs 3
```

`-OutRoot` 생략 시 결과는 benchmark\results\ 아래에 쌓인다.

주의:

- 큰 프로젝트일수록 모델이 읽는 컨텍스트가 늘어 **회당 비용과 시간이 커진다**. 과제와 무관한 대형 폴더는 exclude로 빼는 게 좋다.
- `check`가 의존성을 요구하면(`npm test` 등) `prep`으로 설치하거나, node_modules를 exclude에서 빼서 통째로 복사한다(복사 시간 증가).
- 좋은 과제 소스: 과거에 실제로 겪은 버그의 커밋 직전 상태. `git worktree add` 나 `git archive`로 그 시점 폴더를 만들어 `source`로 지정하면 된다.

## 과제 추가하기

`tasks.json`에 항목 추가:

```json
{
  "id": "my-task",
  "prompt": "모델에게 줄 지시문",
  "check": "python test_my.py",
  "setup": { "파일명.py": "작업 폴더에 미리 만들 파일 내용" }
}
```

- `check`는 작업 폴더에서 실행되며 종료 코드 0이면 PASS. 생략하면 품질 판정 없이 토큰/속도만 측정.
- `setup`은 생략 가능. 파일 내용의 줄바꿈은 `\n`으로 이스케이프.
