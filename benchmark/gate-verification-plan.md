# 게이트 발동 검증 실험 계획

> 상태: **완료 — 발동 검증 성공, 이득 검증은 이 난이도 대역에서 불가 판정** (2026-07-06 설계, 2026-07-07 구현·실행·후속까지 종료).
>
> - **발동하는가** → 예. 문언 2회 수정 끝에 skill 셀 4/4 발동 (Opus: "count, don't judge" 객관 조건, Sonnet: 회계 라인 `files changed: N | skeptic: fired|skipped` 의무 신고 + 조건 성립 시 skipped 무효). 판단 재량 어휘는 실행 확률을 낮추고, 셀 수 있는 조건 + 신고 의무가 실행을 강제한다는 교훈.
> - **이득이 있는가** → 미검출. v1(조용한 호출 지점, 버그 5개)과 v2(간접 참조 3종, 미묘한 버그 7개) 모두 두 모델 baseline이 천장(전 셀 PASS) — Sonnet 5/Opus 4.8급에는 수백 줄 자기완결 과제로 격차를 만들 수 없다. 발동 비용은 토큰 1.6~2.1배. 게이트는 비용 유계·오발동 없음(실험 4)이므로 유지, 이득 입증은 약한 모델(Haiku) 또는 실제 대형 코드베이스 과제로 이월.
>
> 전 과정 기록: [README.md](README.md) 실험 5 + 실험 5 후속. 구현 상세: 아래 [구현 노트](#구현-노트-2026-07-07).

## 목적

후속 실험 4는 "게이트가 조용해야 할 때 조용함"(회귀 없음)만 증명했다. 이 실험은 반대쪽을 검증한다:

1. **발동하는가** — 게이트 조건(multi-file diff, 감사형 과제)을 실제로 만족하는 과제에서 fresh-context 서브에이전트가 실제로 뜨는지.
2. **이득이 있는가** — 발동했을 때 pass율 상승이 토큰·시간 비용 증가를 정당화하는지.

가설: baseline(및 게이트 없는 구판)은 놓치는 결함을 게이트가 잡는다. 잡지 못하면 게이트는 비용만 드는 장식이므로 제거 대상.

## 선행 작업: 하네스에 서브에이전트 감지 추가

현재 skill 모드는 `--output-format json`이라 최종 결과만 남아 **게이트 발동 여부를 알 수 없다** (턴 수로는 구분 불가). auto 모드가 Skill 호출을 감지하는 방식을 확장한다:

- 모든 모드를 `--output-format stream-json --verbose`로 통일하고, 이벤트 스트림에서 `tool_use`를 파싱해 이름별 카운트를 기록.
- `runs.jsonl`에 `agents_spawned`(서브에이전트 호출 수), `tools_used`(이름별 요약) 컬럼 추가.
- 주의: 서브에이전트 도구의 실제 이벤트 이름(`Task`/`Agent` 등)은 CLI 버전에 따라 다를 수 있으니 **첫 런의 스트림에서 실제 이름을 확인**하고 파싱 코드를 맞춘다.
- 판정 기준: 게이트 발동 = 해당 런에서 `agents_spawned ≥ 1`.

## 과제 1: `multiref-signature` — 멀티파일 시그니처 리팩터링

검증 대상: opus-boost §4 fresh-context 반박 검증(2-3 스켑틱) / sonnet-boost done gate 4번(스켑틱 1개).

### 설계 원칙 (refactor-callsites의 교훈)

refactor-callsites는 "여러 파일이 얽힌 과제"였지만 **옵션 파라미터(기본값 있음)** 라서 diff가 fmt.py 한 파일로 끝났고, 게이트가 문언대로 침묵했다. 이번에는 **기본값 없는 필수 keyword 파라미터**로 설계해 모든 호출 지점 수정을 강제한다 → diff가 반드시 4개 파일에 걸침 → 게이트 조건 성립.

### 구성

- `storage.py` — `save(data)` 를 `save(data, *, format)` (필수, 기본값 없음)으로 변경하라는 과제. `format`은 `"json" | "csv"`, 그 외 ValueError.
- 호출 지점 4곳: `exporter.py`, `backup.py`, `cli.py`, `legacy/compat.py`.
- **함정**: `legacy/compat.py`는 보이는 테스트가 import하지 않는 "조용한 호출 지점". 성급한 런은 여기를 놓친다. 숨김 테스트만 이 모듈을 import해 실행.
- 보이는 테스트: exporter/backup 경로만 검사. 숨김 테스트: 4개 호출 지점 전부 + ValueError 케이스.
- 프롬프트에 "모든 호출 지점이 계속 동작해야 한다"는 명시 (스펙은 전부 공개, 채점만 숨김 — 기존 숨김 테스트 패턴과 동일).

### 측정

| 지표 | 기대 |
|---|---|
| 게이트 발동 (skill 모드) | fire — diff가 4파일 + 공개 API 변경 |
| pass율 baseline vs skill | baseline이 legacy 호출 지점을 놓칠 때 격차 발생 |
| 비용 델타 | 스켑틱 1-3개 호출분의 토큰 증가 — pass 격차와 비교 |

주의: Grep이 습관화된 모델은 baseline에서도 legacy를 잡을 수 있다. baseline pass율이 100%면 함정 난이도를 올린다 (예: 동적 dispatch 근처에 호출 지점 배치, 파일 수 증가).

## 과제 2: `audit-seeded-bugs` — 버그 심은 감사 과제

검증 대상: opus-boost "Audit tasks" 섹션 (렌즈별 병렬 finder + loop-until-dry + 발견당 스켑틱 반박).

### 구성

소형 모듈 3파일(합계 150~250줄), 예: 로그 분석기 — `parser.py` / `aggregator.py` / `report.py`. 서로 다른 클래스의 버그 5개를 심는다:

| # | 클래스 | 예시 | 노리는 렌즈 |
|---|---|---|---|
| 1 | off-by-one | 슬라이스 경계 `range(len(x)-1)` | boundaries |
| 2 | 비교 연산자 | `>=` 대신 `>` (임계값 판정) | dataflow |
| 3 | 삼킨 예외 | `except: return []` — 에러 은폐 | error paths |
| 4 | 가변 기본 인자 | `def f(acc=[])` 상태 누적 | dataflow/동시성 |
| 5 | 빈 입력 | 빈 리스트에서 ZeroDivisionError | boundaries |

- 프롬프트: "이 모듈의 버그를 **전부** 찾아 고쳐라. 기능 추가·리팩터링 금지. 발견한 버그 목록을 보고하라." (감사형 문언 — audit 섹션 트리거를 명시적으로 밟는다)
- 채점: 숨김 테스트가 버그당 1개 테스트로 5개 전부 검사. **버그별 PASS/FAIL을 stdout에 한 줄씩 출력**하고 전부 통과 시에만 exit 0 — runs.jsonl의 이진 판정과 별개로 작업 폴더 출력에서 발견율(k/5)을 사후 집계할 수 있게.
- 미끼 안전장치: 버그가 아닌 코드를 "수리"해 새 버그를 만들지 않는지도 숨김 테스트의 정상 동작 케이스로 검사.

### 측정

- 핵심 지표: **발견율 k/5** (baseline vs skill). 가설: baseline은 명백한 2~3개를 찾고 멈춤, loop-until-dry는 2라운드 연속 무발견까지 반복하므로 4~5개 도달.
- 보조: `agents_spawned` (finder + 스켑틱 수), 라운드 수(ANSWER.md 보고에서 확인), 오탐(멀쩡한 코드 수정) 여부.

## 실행 매트릭스

| 항목 | 값 |
|---|---|
| 과제 | multiref-signature, audit-seeded-bugs |
| 모델 × 스킬 | Sonnet 5 + sonnet-boost, Opus 4.8 + opus-boost (Haiku 제외 — 단일 에이전트 정책) |
| 모드 | baseline, skill (auto는 발동 확인 후 추가) |
| 런 수 | 1차 스크리닝 1회 → 격차 보이면 3회 반복 |
| 호출 수 | 1차 2×2×2 = 8회 (서브에이전트 호출은 별도 소모 — audit 과제는 회당 한도 소모가 클 수 있음) |

## 판정 기준

| 결과 | 해석 → 행동 |
|---|---|
| 게이트 미발동 | 게이트 문언이 과제와 안 맞음 → 스킬 문언 수정 후 재시도 (과제 재설계 아님 — 과제가 조건을 명확히 만족하도록 설계했으므로) |
| 발동 + pass 격차 없음 + 비용 증가 | 게이트 이득 없음 → 조건을 더 좁히거나 제거 검토 |
| 발동 + pass 격차 있음 | 게이트 유지 확정, README에 실험 5로 기록 |

## 나중으로 미루는 것

- **계획 토너먼트 검증** — "넓은 해법 공간"을 객관 채점 과제로 만들기 어려움 (설계 품질은 pass/fail로 안 드러남). 아이디어가 생기면 별도 설계.
- **fresh-eyes-done-gate 발동률** — auto 모드에서 description만으로 태스크 종료 시점에 자동 발동되는지. 위 두 과제의 auto 런에 얹어서 확인 가능.

## 구현 노트 (2026-07-07)

구현 산출물:

| 항목 | 파일 |
|---|---|
| 하네스 확장 | `run-benchmark.ps1` — 전 모드 `stream-json --verbose` 통일, `runs.jsonl`에 `agents_spawned`/`tools_used` 추가, summary에 `avg_agents`, `check` 출력을 `check-output.txt`로 저장 |
| 과제 1 | `fixtures\multiref-signature\` (5모듈 + 보이는 테스트) + `hidden\test_multiref_hidden.py` |
| 과제 2 | `fixtures\audit-seeded-bugs\` (3파일 149줄, 버그 5개) + `hidden\test_audit_hidden.py` |
| 과제 정의 | `gate-tasks.json` (`-TasksFile .\gate-tasks.json`으로 실행) |

계획 대비 확정·보완 사항:

- **서브에이전트 도구 이름 확인 완료**: CLI 2.1.181 스트림의 init 이벤트 기준 `Task` (`Agent`도 버전 대비로 함께 카운트). 서브에이전트 내부 이벤트는 `parent_tool_use_id`가 채워져 오므로 메인 루프 호출만 센다 — 기존 auto 런 스트림으로 리플레이 검증됨.
- 과제 1 보이는 테스트에 `save([1, 2], format="json")` 기본 케이스 1개 추가 — 리팩터링을 아예 안 해도 보이는 테스트가 통과해버리는 구멍 차단. legacy/cli 경로는 계획대로 숨김 전용.
- 과제 2는 **각 함수의 docstring을 스펙으로 명시** — "버그"의 기준을 객관화. 채점기는 검사마다 모듈 체인을 reload해 가변 기본 인자 버그의 상태 오염이 다른 검사 판정을 오염시키지 않게 격리 (부분 수정 시 k/5가 정확).

오프라인 검증 결과 (모델 호출 없음):

- multiref: 원본 → 보이는/숨김 모두 FAIL, 정답(4곳 전부) → 모두 PASS, **legacy만 놓친 부분해 → 보이는 PASS + 숨김 FAIL** (함정 작동).
- audit: 원본 → `FOUND 0/5, baseline PASS` exit 1, 전부 수정 → `FOUND 5/5` exit 0, 부분 수정(1·2·5) → `FOUND 3/5` (버그별 판정 정확), 멀쩡한 코드 훼손 → `baseline FAIL` exit 1 (미끼 안전장치 작동).
- 하네스: 구문 검증 통과, 기존 스트림 리플레이에서 `Skill:1`·턴 수·비용 추출값이 기록과 일치.
