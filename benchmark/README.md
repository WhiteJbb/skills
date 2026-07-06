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
