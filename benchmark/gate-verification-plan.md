# 게이트 발동 검증 실험 계획

> 상태: 설계 단계 (2026-07-06 작성, 미착수)

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
