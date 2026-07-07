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
- 모든 모드가 `stream-json`으로 실행되어 메인 루프의 도구 호출이 `runs.jsonl`에 기록된다: `agents_spawned`(서브에이전트 `Task` 호출 수 — 멀티에이전트 게이트 발동 판정), `tools_used`(도구별 호출 수). 서브에이전트 내부 이벤트(`parent_tool_use_id` 있음)는 제외.
- v-next 스킬이 최종 보고에 내보내는 자기검증 메트릭도 파싱된다: `rules_proven`/`rules_total`(모델이 실행 예시로 증명했다고 주장한 규칙 수 — 실제 `passed`와 대조하면 정직성 측정), `probe_decision`(fresh-eyes 프로브 발동 판단: fired/not needed). baseline 모드는 이 라인이 없어 null.
- 과제마다 격리된 작업 폴더가 생성되고, 완료 후 `check` 명령(테스트)의 종료 코드로 PASS/FAIL 판정. `check`의 출력은 `check-output.txt`로 저장된다(버그별 채점 등 사후 집계용).

## 결과 해석

`results\<타임스탬프>\` 아래에 저장:

| 파일 | 내용 |
|---|---|
| `summary.csv` | 과제×모드별 평균 — 통과율, 시간, 턴, 토큰, 비용 |
| `runs.jsonl` | 실행 1회당 원시 기록 |
| `<과제>_<모드>_run<N>\` | 작업 폴더 (생성된 코드, `ANSWER.md`, `claude-stream.jsonl`, `check-output.txt`) |

주요 지표:

- `pass_pct` — **품질**. 스킬의 존재 이유. 이게 오르면 나머지 비용은 트레이드오프.
- `fire_pct` — auto 모드에서 스킬이 자동 발동된 비율. 낮으면 스킬 description을 손봐야 한다는 신호 (규칙 내용의 문제가 아님). 어떤 스킬이 불렸는지는 `runs.jsonl`의 `skills_used`에 기록.
- `avg_agents` / `agents_spawned` — 서브에이전트 호출 수. 멀티에이전트 게이트 발동 판정 기준: 해당 런에서 `agents_spawned ≥ 1`.
- `avg_out_tok` / `avg_cost_usd` — 토큰 사용량과 비용. `cost_usd`는 구독 로그인 시 실제 청구액이 아니라 **API 환산 추정치**다.
- `avg_wall_s` / `avg_api_s` — 응답 속도. wall은 체감 시간, api는 순수 모델 시간.
- `avg_turns` — 도구 호출 횟수. 스킬 모드에서 검증 단계만큼 늘어나는 게 정상. baseline보다 크게 줄었다면 삽질(재시도 루프)이 줄었다는 신호.

주의할 점:

- 1회 실행은 편차가 크다. 비교 목적이면 `-Runs 3` 이상.
- 첫 실행은 프롬프트 캐시가 비어 있어 느릴 수 있다. `cache_read`/`cache_write` 값으로 확인 가능.
- 샘플 과제 3개는 쉬운 편이라 baseline도 자주 통과한다. 스킬 효과는 **어려운 과제일수록** 커지므로, 실제 프로젝트의 까다로운 버그를 `tasks.json`에 추가해 보는 게 가장 의미 있다.

## 스킬 효과 종합 (실측 기반)

> 아래 실험 1~11의 데이터를 압축한 결론. 대부분 셀당 n=1이라 방향성 위주로 읽을 것. 객관 채점(코딩)에서 통과율(품질) 격차가 실제로 측정된 곳은 두 군데뿐(Haiku expr-eval, OSS `&<>`)이며 나머지는 효율(토큰·시간) 지표다. **판단·아키텍처**는 실험 11에서, **디자인**은 별도 디자인 벤치에서 블라인드 심사로 측정. 대형 코드베이스는 여전히 미검증.

**한 줄 결론: 효과는 "모델 × 과제 난이도"에 좌우된다. 스킬은 모델이 낭비하거나 실수하는 지점을 메우고, 그 지점이 없으면 비용만 든다.**

측정된 4개 국면:

| 국면 | 대표 실측 | 효과 |
|---|---|---|
| 약한 모델 + 능력 초과 스펙 | Haiku `expr-eval`: baseline **FAIL** → haiku-boost **PASS** (토큰 21.6k→32.6k, +50%) | **품질 반전** — 통과율을 뒤집은 유일한 국면 |
| 장황한 모델 + 긴 과제 | Sonnet `csv-parser`: 42.2k→14.3k 토큰(**−66%**), 둘 다 PASS, 2.9배 빠름 | **효율** — 같은 품질을 1/3 토큰에 |
| 정돈된 모델 / 능력 내 과제 | Opus `csv-parser` −12%; Haiku 쉬운 과제엔 skill이 턴 8→22 폭증 | 온건한 이득 ~ 순비용 |
| 멀티에이전트 게이트 (객관채점) | gate-v1/v2: baseline 천장(전 셀 PASS) → 점수 불변, 토큰 +89~114% | 이 난이도선 순비용. 단 baseline이 실수하면 게이트가 실재 결함을 잡음(아래) |

**모델별 처방 (3모델 기울기, 효율 기준):** Sonnet(낭비 큼) 토큰 −66% / Opus(정돈됨) −12% / Haiku(낭비 없음) 규율형(sonnet-boost)은 역효과 → 검증형(haiku-boost의 spec→assert)만 유효. **"스킬은 모델별 처방"** 이 세 모델로 확인됐다.

**게이트가 실재 결함을 잡은 유일한 직접 증거 (실험 6, OSS 이슈 #495):** fresh-context 스켑틱이 **저자 컨텍스트·자동채점기 둘 다 놓친** `&<>` 버그를 잡았고(독립·업스트림 확인), Opus는 스트림상 `Edit→Agent→Edit`로 스켑틱-유발 수정까지 갔다. 단 baseline도 그 버그를 안 냈으므로 **최종 점수 격차로는 안 드러난다** — 게이트는 "모델이 실수하는" 조건에서만 값을 한다.

**v-next 재설계로 얻은 것 (실험 6 후속):** 멀티에이전트 패널을 "spec→실행예시 + 셀 수 있는 트리거의 단일 프로브"로 교체 → gate-v2 토큰 **48~76%↓** 하며 점수 유지(Sonnet multiref 8.6k→4.5k, Opus audit 21.7k→5.1k), OSS는 구판 3-패널(Opus 46k)을 단일 프로브(31k)로 대체해 동일 5/5. 재설계가 완전성을 해친 회귀 3셀은 원인 규명 후 복원(양 OSS 5/5, Sonnet audit 7/7). 그 과정에서 나온 **약한 모델용 설계 원칙 3가지**(전부 실측): ① 트리거는 모델 외부에서 셀 수 있어야 한다(판단은 blind spot이 뚫음) ② 강제 신고는 사실을 정직하게 만들지만 행동을 강제하진 못한다(Sonnet은 조건 참을 적고도 서브에이전트 거부) ③ 완전성 메커니즘은 모델이 이미 따르는 것(자기-실행 테스트)이어야 한다.

**Fable 직접 비교 (실험 8·10·11):** 객관 채점 코딩(max-points, ±2 추론 함정)은 Fable·Opus·Sonnet·Haiku **전부 baseline 통과** — outcome 패리티 이미 성립. 단 Fable이 **최소 토큰(2.7k)으로 가장 간결**하고 스킬은 오히려 장황해져(9.5k) Fable에서 *멀어진다*. 정답 없는 **판단·아키텍처 과제(실험 11)**에선 블라인드 심사에서 **Fable이 8전 8승**(비편향 Opus 심사자 4/4), 스킬은 격차를 못 좁히고 **오히려 역효과**(sonnet-boost 0승 — 간결 규율이 추론 깊이를 깎음). **Fable의 진짜 우위(효율·판단 깊이)는 규율로 이식되지 않는다** — 스킬이 값을 하는 건 base가 실패하는 좁은 코딩 구간뿐이다.

**언제 켜고 끌까 (실측 처방):**
- Haiku로 어려운 스펙 구현 → **haiku-boost 켠다** (품질 반전, 유일하게 확실한 ON).
- Sonnet으로 긴 작업 → **sonnet-boost 켠다** (품질이 아니라 토큰·시간을 산다; 쉬운 과제엔 소액 순비용).
- Opus → 이득 온건. 규율·정직 보고가 목적이면 유지.
- 멀티에이전트 게이트 → baseline이 실수할 만한 환경(약한 모델·대형 코드베이스)에서만 값을 한다. v-next는 그 비용을 단일 프로브로 낮췄다.
- **판단·설계·아키텍처 → 끈다** (실험 11: Fable을 못 따라잡고, 간결 규율이 오히려 추론 깊이를 깎아 역효과).

세부 근거는 아래 실험 1~11 로그. 원시 데이터는 각 실험의 `results\<타임스탬프>\`, Fable 산출물은 `fable-reference/`.

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

### 실험 5: 게이트 발동 검증 1차 스크리닝 (2026-07-07)

[gate-verification-plan.md](gate-verification-plan.md)의 실행 — gate-tasks.json 2과제 × 2모델 × baseline/skill, 셀당 1회. 게이트 발동 판정은 `agents_spawned ≥ 1`.

| 모델 | 과제 | 모드 | 통과 | agents | 시간(초) | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|---|---|
| Sonnet 5 | multiref-signature | baseline | PASS | 0 | 41.8 | 2,561 | $0.62 |
| Sonnet 5 | multiref-signature | skill | PASS | **1** | 109.5 | 5,490 | $0.84 |
| Sonnet 5 | audit-seeded-bugs | baseline | PASS (5/5) | 0 | 73.1 | 6,006 | $0.54 |
| Sonnet 5 | audit-seeded-bugs | skill | PASS (5/5) | 0 | 93.8 | 7,401 | $0.78 |
| Opus 4.8 | multiref-signature | baseline | PASS | 0 | 75.8 | 3,402 | $0.51 |
| Opus 4.8 | multiref-signature | skill | PASS | 0 | 81.3 | 4,530 | $0.33 |
| Opus 4.8 | audit-seeded-bugs | baseline | PASS (5/5) | 0 | 81.6 | 6,049 | $0.42 |
| Opus 4.8 | audit-seeded-bugs | skill | PASS (5/5) | **2** | 181.1 | 11,453 | $1.12 |

관찰:

- **게이트는 발동한다 — 단 모델×과제가 엇갈린다.** sonnet-boost done gate 4번은 multiref에서 문언 그대로 발동 — 스트림에 기록된 스켑틱 프롬프트가 규칙 그대로다("NO prior context … REFUTE 'this diff is correct and complete'" + 계약 + diff). opus-boost Audit 섹션은 audit 과제에서 발동 — 렌즈가 다른 병렬 finder 2개(spec-lens / edge-case-lens). 반대편 셀은 침묵: Opus는 5파일·공개 API diff인데도 §4 fresh-context 검증을 건너뛰었고, Sonnet은 3파일 audit diff에서 done gate 4번을 건너뛰었다.
- **pass 격차 미검출 (8/8 PASS).** 두 모델 baseline이 함정 포함 만점 — multiref는 Grep 습관으로 legacy 호출 지점을 잡았고(계획서가 예고한 시나리오), audit 버그 5개는 149줄 모듈에서 전부 발견됐다(check-output.txt 기준 baseline도 5/5). 이득 검증에는 함정 난이도 상향이 필요하다.
- **발동 비용**: Sonnet multiref 스켑틱 1개 = 토큰 2.1배·시간 2.6배·+$0.22. Opus audit finder 2개 = 토큰 1.9배·시간 2.2배·+$0.70. (주의: 두 매트릭스를 동시 실행해서 wall 시간은 상호 간섭 가능성 있음)
- opus-boost audit 발동은 **부분 준수**: finder는 떴지만 loop-until-dry(2라운드 연속 무발견까지)와 발견당 스켑틱 반박은 총 agents 2라 수행되지 않은 것으로 보인다.
- 이 CLI 버전(2.1.181+)에서 서브에이전트 도구 이벤트 이름이 `Agent`로 기록됐다 — 전날 스트림의 init 이벤트는 `Task`였으므로 두 이름을 모두 세는 하네스 설계가 유효했다.
- **판정** (계획서 기준표 적용): 미발동 셀 2개 → 해당 스킬 문언 수정 후 재시도. 발동 셀 2개는 "발동 + 격차 없음 + 비용 증가"지만, baseline이 천장(100%)이라 격차 자체가 검출 불가능한 난이도였으므로 게이트 제거 판단은 함정 난이도 상향 후로 보류.
- 원시 데이터: `results\20260707-105414\` (Sonnet), `results\20260707-105513\` (Opus)

### 실험 5 후속: 게이트 문언 수정 반복 + 난이도 상향 v2 (같은 날)

**1) 문언 수정 반복** — 미발동 셀만 v1 과제로 재실행하며 문언을 고쳐 나감:

| 셀 | 게이트 문언 | agents |
|---|---|---|
| Opus × multiref | 원판 "for multi-file or risky diffs" | 0 |
| Opus × multiref | "MANDATORY whenever ANY of: 2+ files / public signature / … — **count, don't judge**" | **2** |
| Sonnet × audit | 원판 "Multi-file or risky diff" | 0 |
| Sonnet × audit | + "MANDATORY … Green tests do not waive" | 0 |
| Sonnet × audit | + **회계 라인 강제**: 보고 끝에 `files changed: N \| skeptic: fired\|skipped (reason)` 의무 | **1** |

- **Opus는 객관 조건 명시("세라, 판단하지 말라")로 충분**했다. **Sonnet은 MANDATORY·면제불가 문구를 붙여도 확신이 서면 조용히 스킵**했고, 발동/스킵을 최종 보고에 한 줄로 의무 신고하게 하자 발동했다. 이후 v2에서 조건 성립인데도 `skipped (사유)`로 신고하고 우회하는 사례가 1회 나와 "조건 성립 시 skipped는 규칙 위반, 어떤 사유로도 정당화 불가"를 추가한 것이 최종판.
- 게이트 문언 설계 교훈: **판단 재량 어휘(risky, 필요시)는 실행 확률을 낮추고, 셀 수 있는 조건 + 명시적 신고 의무가 실행을 강제한다.**

**2) 난이도 상향 v2** (`gate-tasks-v2.json`) — baseline 천장을 깨기 위한 함정 강화:

- `multiref-signature-v2` — 호출 경로 6곳으로 증가, 그중 3곳은 `save(` grep으로 안 잡히는 간접 참조: 별칭 import(`save as persist`), 동적 해석(`getattr`), 콜백 레지스트리(함수 객체 등록 — wrapping 없이는 수정 불가 구조).
- `audit-seeded-bugs-v2` — 4파일 240줄 이벤트 분석기에 미묘한 버그 7개: 들여쓰기 조기 return, `reverse=True` 타이브레이크 반전, 레코드별 예외 삼킴, 클래스 공유 기본 인자, 빈 리스트 percentile 크래시, 슬라이스 최신 이벤트 누락(`[-n:-1]`), snapshot aliasing.

| 모델 | 과제 | 모드 | 통과 | agents | 시간(초) | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|---|---|
| Sonnet 5 | multiref-v2 | baseline | PASS | 0 | 56.4 | 4,087 | $0.44 |
| Sonnet 5 | multiref-v2 | skill | PASS | **1** | 195.1 | 8,598 | $0.89 |
| Sonnet 5 | audit-v2 | baseline | PASS (7/7) | 0 | 64.5 | 5,541 | $0.53 |
| Sonnet 5 | audit-v2 | skill | PASS (7/7) | **1** | 259.4 | 9,030 | $1.50 |
| Opus 4.8 | multiref-v2 | baseline | PASS | 0 | 111.4 | 7,374 | $0.45 |
| Opus 4.8 | multiref-v2 | skill | PASS | **1** | 180.6 | 9,178 | $0.61 |
| Opus 4.8 | audit-v2 | baseline | PASS (7/7) | 0 | 180.6 | 10,939 | $0.67 |
| Opus 4.8 | audit-v2 | skill | PASS (7/7) | **3** | 383.5 | 21,656 | $1.81 |

관찰:

- **발동 4/4** (최종 문언 기준, skill 셀 전부) — 실험 5의 목표였던 "게이트가 발동하는가"는 검증 완료. 단 opus-boost §4는 "2-3개 병렬"인데 multiref-v2에서 1개만 띄움(개수는 부분 준수).
- **pass 격차는 v2 난이도에서도 미검출** — 유효 런 16/16 PASS. 간접 참조 6경로도, 미묘한 버그 7종도 두 모델 baseline이 전부 처리했다. Sonnet 5/Opus 4.8급에게 수백 줄 규모의 자기완결 과제로는 게이트가 잡을 잔여 결함이 남지 않는다.
- **스펙 버그 사고 (벤치마크 설계 교훈)**: 최초 Sonnet audit-v2 두 런은 버그 7/7을 다 찾고도 FAIL이었다 — docstring이 "nearest-rank"로 **잘못 라벨**된 p95를 교과서 정의로 정직하게 "수리"해 BASELINE(기존 동작 보존) 검사에 걸린 것. 꼼꼼할수록 손해 보는 불공정 과제라 무효 처리하고, docstring에 정확한 인덱스 공식을 못박아 재실행했다(위 표가 재실행 수치). 흥미롭게도 **Opus는 같은 모호 스펙에서도 공식을 건드리지 않고** 통과 — 과잉 수정 성향의 모델 차이.
- **판정**: 결과는 "발동 + 격차 없음 + 비용 1.6~2.1배"로 계획서 기준표상 "조건 축소/제거 검토"에 해당하나, baseline 천장이 두 차례(v1·v2) 이어진 만큼 이 난이도 대역에서는 격차 검출 자체가 불가능하다고 보는 게 정확하다. 게이트 이득 입증은 (a) Haiku 등 약한 모델 조합, (b) 실제 대형 코드베이스 과제로 넘긴다. 현행 게이트는 비용이 유계(스켑틱/finder 1~3개)이고 실험 4 기준 오발동이 없으므로 **유지**.
- 원시 데이터: `results\20260707-110940\`·`110942\`(문언 반복), `111244\`(회계 라인), `111706\`(v2 Sonnet — audit 두 런은 스펙 버그로 무효), `111711\`(v2 Opus), `113016\`(v2 Sonnet audit 재실행)

### 실험 6: 실전 OSS — 게이트가 실제 결함을 잡은 첫 직접 증거 (2026-07-07)

`md-ref-backtick` (Python-Markdown 이슈 #495, git 히스토리 회귀 방식) × 2모델 × baseline/skill, 셀당 1회. **채점기는 실행 후 강화됨** — 아래 참고.

| 모델 | 모드 | 채점(강화 후) | agents | 턴 | 종료 | 시간(초) | 출력 토큰 | 비용 |
|---|---|---|---|---|---|---|---|---|
| Sonnet 5 | baseline | 5/5 | 0 | 41 | **max_turns** | 535 | 42,792 | $3.42 |
| Sonnet 5 | skill | **3/5** | 1 | 41 | **max_turns** | 1008 | 44,619 | $6.01 |
| Opus 4.8 | baseline | 5/5 | 0 | 39 | success | 1198 | 87,493 | $5.22 |
| Opus 4.8 | skill | 5/5 | **3** | 32 | success | 952 | 46,044 | $6.08 |

**핵심 발견 — 게이트가 저자·채점기 둘 다 놓친 진짜 버그를 잡았다.** 실험 4~5 내내 스켑틱은 전부 "no issues found"였는데, 여기서 처음으로 실재 결함을 잡았고 독립 검증됐다:

- 두 모델 모두 업스트림(`07dfa4e`)과 **다른 독창적 수정**을 만들었다. Sonnet은 `blockprocessors.py`에 `_resolve_code_spans`로 참조 정의 측 id를 원문에서 정규화하는 방식.
- **Sonnet skill의 스켑틱**(서브에이전트 55 도구호출·8만 토큰)이 지적: 코드 스팬에 `<`,`>`,`&`가 있으면(`` [`<div>`] ``) 여전히 링크가 안 된다 — 고치려던 바로 그 증상. 원인은 정의 측은 원문에서, 사용 측은 `code_escape`로 HTML 이스케이프된 텍스트에서 id를 뽑아 둘이 어긋나는 것.
- **독립 확인**: 그 지적대로 Sonnet skill 해법은 `<p>[<code>&lt;div&gt;</code>]</p>`(깨짐), **업스트림 픽스와 두 baseline은 정상 링크**. 최초 채점기는 이 케이스가 없어 놓쳤다 — **게이트가 채점기의 사각지대를 가르쳐준 것**. 그래서 `test_oss_md_hidden.py`에 BUG4/5(`<div>`, `a&b`)를 추가했고, 이 강화 채점기로 재채점한 것이 위 표.

**게이트 개입 → 수정의 기계적 증거 (Opus skill):**

- opus-boost §4가 스켑틱 **3개**를 렌즈별(correctness / edge-cases / regression)로 띄웠다(완전 준수). 그중 correctness 스켑틱이 "REFUTED — `<>&` 비대칭 결함"을 지적.
- 스트림상 스켑틱 3개 **이후** `inlinepatterns.py`에 Edit 1건 발생, 내용이 정확히 `content.replace('&lt;','<').replace('&gt;','>').replace('&amp;','&')` — **스켑틱이 지목한 그 결함의 수정**. Opus skill이 `&<>`를 통과하는 이유가 이 스켑틱-유발 수정이다.

**그런데 Sonnet skill은 3/5로 baseline(5/5)보다 낮다 — 스킬이 해로운 게 아니라 하네스 턴 상한 아티팩트다:**

- Sonnet skill의 스켑틱도 **같은 결함을 정확히 잡았고**, 모델은 파일 백업·테스트 셋업(Bash 2회)까지 착수했으나 **`--max-turns 40`에 걸려(41턴, error_max_turns) 수정을 적용하기 전에 잘렸다.** Sonnet baseline도 41턴 max_turns지만 애초에 견고한 수정을 써서 `&<>`를 통과.
- 즉 두 skill 런 모두 게이트는 결함을 **포착**했고, 턴 여유가 있던 Opus는 **수정까지** 갔으나 Sonnet은 상한에 막혔다. 게이트 가치 실현에는 충분한 턴 예산이 필요하다는 것.

**판정 및 다음 단계:**

- **게이트 이득 = 입증됨(방향성).** "버그를 쓴 컨텍스트는 못 보고 신선한 눈은 본다"가 실제 OSS 결함에서, 저자·채점기가 둘 다 놓친 케이스로 확인됐다. 실험 5에서 미검출이던 것은 과제가 baseline 천장이라 잡을 게 없었기 때문 — 잡을 게 있으면 게이트가 잡는다.
- **공정한 재측정 조건**: `--max-turns`를 60~80으로 올려 Sonnet skill이 스켑틱 수정을 완료할 수 있게 해야 한다(그러면 3/5 → 5/5 예상). 비용은 회당 $3~6.
- n=1 주의: 독창적 해법이라 편차 큼. 다만 "스켑틱이 실재·업스트림 확인된 결함을 지목 → (턴 있으면) 수정"이라는 인과 사슬은 스트림에 기계적으로 남아 있어 방향성은 견고.
- 원시 데이터: `results\20260707-115846\` (Sonnet), `results\20260707-115848\` (Opus)

### 실험 6 후속: 스킬 v-next 재설계 (2026-07-07)

실험 1~6의 데이터가 가리키는 결론 — **측정된 이득은 전부 Fable의 "기질"(검증-후-주장, 삽질 금지, 정직한 불확실성)에서 나왔고, "장치"(멀티에이전트 스켑틱 패널)는 토큰만 쓰고 채점 점수를 못 올렸다.** 유일하게 품질을 뒤집은 메커니즘은 haiku-boost의 spec→assert(구현 전 전 규칙을 실행 가능한 테스트로 변환). 이에 맞춰 opus-boost/sonnet-boost를 재설계:

| # | 개선 | 구현 |
|---|---|---|
| 1 | 트리거를 파일 수 → **불확실성·영향범위** | "2+ 파일이면 스켑틱"을 폐기. 발동 조건 = 실행 예시로 증명 못 한 규칙이 남거나 wide-impact(공개 API/데이터 포맷/보안)일 때만 |
| 2 | **단순성·관행 편향** | "유지보수자가 받아들일 가장 작은 diff, 국소 수정, 코드베이스 기존 패턴 우선 — 새 메커니즘 금지" (OSS에서 skill 모드가 독창적 버그를 자초한 것 방지) |
| 3 | **검증 = spec→실행예시를 전 모델 기본** | §4를 "재읽기식 self-review"에서 "규칙마다 적대적 입력 포함 실행 예시로 증명"으로 교체. haiku-boost 철학을 opus/sonnet에 통합 |
| 4 | 스켑틱을 **값싼 단일 프로브로** | "2-3개 병렬 패널 REFUTE"를 "프로브 1개: 이 스펙을 깨는 입력 하나만 찾아라"로. 발동해도 비용 유계 |
| 5 | **정직성 메트릭 계측** | 스킬이 보고 끝에 `rules proven: N/M | probe: fired|not needed`를 내보내고, 하네스가 `rules_proven`/`probe_decision`으로 파싱. 주장 대 실제(`passed`) 대조로 정직성 측정 |

추가 개선: 세 스킬의 검증 철학을 spec→실행예시로 **통일**(이전엔 haiku만), 프로브가 아무것도 못 찾으면 발동 자체를 비용으로 규정("finds nothing = pure cost"), description도 새 축을 반영해 auto 모드 트리거 정합.

설계 가설(미측정): (a) 파일 수 트리거 제거로 gate-v1/v2의 헛발동이 사라져 skill 토큰이 baseline 수준으로 내려간다, (b) spec→실행예시 기본화로 OSS `&<>` 같은 blind-spot을 스켑틱 없이도 self-test가 잡는다, (c) 단순성 편향으로 skill 모드의 자초 버그가 준다. **검증 방법**: gate-tasks-v2 + oss-tasks를 구판/신판 스킬로 재측정해 "점수 유지 + 토큰 감소"를 확인 (git 이전 커밋 `59e9ae7`이 구판). n≥3 권장.

### 실험 6 후속-2: v-next 재측정 — 토큰은 줄었으나 완전성 회귀, 그리고 수정 (2026-07-07)

v-next(2726720) skill을 gate-tasks-v2 + oss-tasks로 재측정(신판 skill만, baseline·구판은 오늘 기록분 재사용):

| 모델 | 과제 | 신판 | 구판 | 토큰 신/구 | agents 신/구 |
|---|---|---|---|---|---|
| Sonnet | multiref-v2 | 5/5 | 5/5 | 4,476 / 8,598 (−48%) | 0 / 1 |
| Sonnet | audit-v2 | **6/7 FAIL** | 7/7 | 3,630 / 9,030 (−60%) | 0 / 1 |
| Sonnet | OSS #495 | **3/5 FAIL** | 3/5 | 14,458 / (구판 max_turns) | 0 / 1 |
| Opus | multiref-v2 | 5/5 | 5/5 | 4,140 / 9,178 (−55%) | 0 / 1 |
| Opus | audit-v2 | 7/7 | 7/7 | 5,096 / 21,656 (**−76%**) | 0 / 3 |
| Opus | OSS #495 | **3/5 FAIL** | 5/5 | 19,930 / 46,044 | 0 / 3 |

- **토큰 감소는 확인(가설 a 성립)** — 전 셀 48~76%↓, 프로브 발동 0. 특히 Opus audit는 21.7k→5.1k에 7/7 유지.
- **그러나 완전성이 필요한 3셀에서 회귀** — Sonnet audit 7→6(7번째 버그 놓침), 양 모델 OSS가 `&<>` 케이스 놓쳐 5/5→3/5.
- **근본 원인: 프로브 트리거를 "파일 수(셀 수 있음)"에서 "wide-impact(모델 판단)"로 바꾼 것.** 검사 대상인 blind spot이 바로 모델 판단이므로 자기부정. 실측 증거: Sonnet은 공개 API 변경을 매번 "local to two small methods"로 재분류해 프로브 스킵(3셀 전부), Opus는 OSS에서 `&<>`를 **self-test로 실제 찾고도**("불확실: 특수문자 참조 여전히 안 됨") "요구사항 외 · 회귀 아님"으로 스코프 아웃. → **실험 5가 "셀 수 있는 조건 + 강제 신고"로 막았던 구멍을 재설계가 다시 열었다.**
- **정직성 메트릭은 성공** — Sonnet audit `rules proven: 6/6`(찾은 6개는 증명, 실제 7개), Opus OSS는 `&<>` 한계를 `불확실`로 자진 신고. 메트릭이 "확신하나 불완전"과 "스코프 판단"을 그대로 드러냄.

**수정 (커밋 예정):** ① 프로브 트리거를 **셀 수 있는 외부 조건**(공개 시그니처/동작 변경 OR 2+ 소스파일 OR find-all-bugs)으로 복원하되 **값싼 단일 프로브 유지**(구판 3-패널 아님 — Opus audit 토큰 이득 대부분 보존). ② **"리포트된 버그 = 입력 클래스 전체(특수문자/빈/경계), 리터럴 예시만 아님; '나머지는 스코프 외'는 규칙 위반"** 을 계약 단계에 명시. ③ sonnet-boost에 **audit 완전성 조항**(완전성은 자기평가 불가 → 다른 렌즈 finder 1개 발동 후 dry까지 루프) 추가. 교훈: **약한 모델에는 판단 재량 트리거가 무조건 뚫린다 — 트리거는 모델 외부에서 셀 수 있어야 한다.** (실험 5의 재확인)

### 실험 6 후속-3: 수정판 검증 + Sonnet audit의 깊은 지시-불이행 (2026-07-07)

회귀 3셀을 수정판(`d8fc42a` + audit 자기실행스윕)으로 재측정. 3자 비교:

| 셀 | 구판 | v-next(회귀) | 수정판 | 복원 |
|---|---|---|---|---|
| Opus OSS #495 | 5/5 (agents 3, 46k) | 3/5 (agents 0) | **5/5 (agents 1, 31k)** | ✓ 더 싸게 |
| Sonnet OSS #495 | 3/5 (max_turns) | 3/5 (agents 0) | **5/5 (agents 2, 47k)** | ✓ |
| Sonnet audit-v2 | 7/7 (agents 1) | 6/7 (agents 0) | **7/7 (agents 0, 6k)** | ✓ 서브에이전트 없이 |

**두 OSS 셀: 셀 수 있는 트리거 + 버그-클래스 규칙 + 값싼 단일 프로브로 복원.** Opus는 스트림이 `Edit→Edit→Agent→Edit` — 프로브(Agent)가 `&<>`를 잡고 그 뒤 Edit으로 수정한 **기계적 증거**. 구판 3-패널(46k)보다 저렴한 단일 프로브(31k)로 동일 5/5. 정직성 메트릭도 `rules 8/8`로 `&<>`를 스코프 내 인정(v-next에선 "불확실"로 스코프 아웃했던 것).

**Sonnet audit-v2 — 실험 5보다 깊은 발견.** 셀 수 있는 트리거로도 3회 연속 실패(6/7, agents 0). 강제-카운트 신고 라인을 넣자 Sonnet은 `files changed: 3 | public: N | find-all-bugs: Y | probe: **not needed** | rules proven: 6/6`이라고 적었다 — **모든 트리거 조건이 참(3파일·audit)이라고 스스로 기입하고도 규칙을 어기고 서브에이전트를 거부.** 즉 Sonnet은 자기모순 신고를 감수하면서까지 subagent를 안 띄운다. 실험 5의 "판단 트리거는 뚫린다"보다 한 층 깊은 층위 — **강제된 사실 기입조차 subagent 발동으로 이어지지 않는다.**

- **해법: 메커니즘 교체.** Sonnet이 거부하는 finder-subagent 대신, 따르는 self-test로. audit 조항을 "**모든 함수를 적대적 입력(빈/경계/0)으로 직접 실행 — 버그로 안 찍은 함수 포함**"으로 교체. 놓친 BUG5가 `p95([])` 크래시라 `f([])` 한 번에 잡힘 → 7/7, agents 0, 6k 토큰. Sonnet이 신고 라인에 "모든 함수를 empty/boundary 입력으로 직접 실행 완료"라 적고 실제로 스윕함.

**종합 교훈 (약한 모델용 스킬 설계 원칙 3가지, 전부 실측):**
1. **트리거는 모델 외부에서 셀 수 있어야 한다** — 판단 재량("wide-impact")은 blind spot이 뚫는다 (실험 5·6후속-2).
2. **강제 신고는 사실을 정직하게 만들지만 행동을 강제하진 못한다** — Sonnet은 조건 참을 기입하고도 subagent를 거부 (6후속-3).
3. **완전성 메커니즘은 모델이 이미 따르는 것이어야 한다** — subagent 오케스트레이션(거부)이 아니라 자기-실행 테스트(준수). Fable의 멀티에이전트를 이식하는 게 아니라, 같은 목적을 약한 모델이 실행하는 형태로 번역하는 것.

토큰: 수정판은 OSS에서 프로브 1개(구판 3-패널의 1/3~1/2 비용)로 완전성 확보, audit은 서브에이전트 0으로 v-next 대비 소폭 증가(3.6k→6k, 스윕 비용)하나 구판 9k보다 여전히 낮음. **"점수 회복 + 구판보다 저렴"** 달성. 원시 데이터: `results\20260707-143929\`(Sonnet OSS), `143937\`(Opus OSS), `145713\`(Sonnet audit).

### 실험 7: 판단→기계 레버의 경계 — 파티션 스윕은 "발견 과제"에서만 값을 한다 (2026-07-07)

가설: "입력 파티션 커버리지"(구현/변경한 모든 함수를 빈·단일·0·경계·타입 입력으로 실행)를 **전 과제 강제**하면 엣지-크래시류 버그를 기계적으로 잡아 성능이 오른다. 검증용 과제 `rangestats`(6함수) 설계 — **CRASH류**(빈/0 입력에서 가드 없으면 예외 → 스윕이 잡음)와 **LOGIC류**(정상 입력에서 미묘한 오류: even median, tie 방향, 백분위 인덱스 → 크래시 없음, 스윕 신호 없음)를 분리 채점. visible 테스트는 happy-path만. 3 arm(baseline / sonnet-boost=A / 파티션판=B) × Sonnet·Haiku 4.5.

| 모델 | arm | CRASH | LOGIC | 토큰 | partitions run |
|---|---|---|---|---|---|
| Sonnet | baseline | 3/3 | 3/3 | 978 | — |
| Sonnet | A (sonnet-boost) | 3/3 | 3/3 | 6,195 | — |
| Sonnet | B (파티션판) | 3/3 | 3/3 | 8,085 | 21 |
| Haiku 4.5 | baseline | 3/3 | 3/3 | 1,847 | — |
| Haiku 4.5 | A | 3/3 | 3/3 | 5,049 | — |
| Haiku 4.5 | B (파티션판) | 3/3 | 3/3 | 9,487 | 42 |

관찰 (레버 미검출 — 하지만 경계를 정밀화한 값진 null):

- **전 6셀 baseline 포함 완전 통과.** 스펙에 엣지("빈 리스트→0.0", "짝수=두 중앙값 평균", "ceil-1 인덱스")를 전부 명시하니 **Haiku 4.5조차 baseline에서 다 처리.** 파티션 스윕이 잡을 결함이 애초에 없었다.
- **파티션판(B)은 스윕을 실제 수행(21·42회 실행, 신고 라인 `partitions run`으로 확인)했으나 점수 변화 0, 토큰만 +30%(Sonnet)·+88%(Haiku).** 명시 스펙 과제에선 순비용.
- **레버의 진짜 경계는 "크래시 vs 로직"이 아니라 "스펙이 엣지를 명시했나 vs 모델이 발견해야 하나".** 실험 6후속-3에서 같은 스윕이 Sonnet audit을 6/7→7/7로 올린 건 그 크래시가 **명시 안 된·의심 못 한 함수**에 있었기 때문(발견 과제). rangestats는 엣지를 다 적어줘 발견 갭이 0이라 스윕이 무의미.
- **설계 함의 (현행 스킬 정당화):** 파티션 스윕을 universal default로 두면 안 되고 **발견/audit 경로에만**. 현행 sonnet-boost가 스윕을 Audit 섹션에만 둔 게 이 실험으로 확인됨 — universal판(B)은 30~88% 더 쓰고 이득 0. 실험용 변형은 `sonnet-boost-partition/`에 보존.
- **"판단→기계 변환으로 성능을 더 올릴 수 있나"의 실측 답:** 헤드룸은 **모델이 스스로 놓칠 엣지가 있을 때만** 존재한다. 현 모델(Haiku 4.5 포함)은 명시 스펙 구현을 baseline으로 잘 하므로 spec-driven 과제엔 갭이 없다. 레버는 audit·리팩터·대형 미지 코드 같은 **발견 과제로 한정**된다 — 거기선 값을 하고(6후속-3), 여기선(7) 안 한다.
- 원시 데이터: `results\20260707-153137\`·`153142\`(Sonnet), `153603\`·`153605\`(Haiku).

### 실험 8: 추론 증폭기(독립 교차검증) — 현 모델은 추론 함정에도 baseline으로 맞힌다 (2026-07-07)

가설: 추론이 병목인 과제에서 **독립 브루트포스 교차검증**(2차 독립 해법을 문제 정의에서 직접 유도 → 랜덤 입력 diff → 불일치 시 수정)이 논리 오류를 잡아 성능을 올린다. 이건 판단→기계 변환이면서 동시에 **추론을 더 쓰는**(2회 독립 유도) 증폭기 — Fable이 암묵적으로 하는 것. 과제 `max-points`: "delete-and-earn"의 **±2 삭제 변형**(v를 뽑으면 v±2까지 삭제 → 선택값끼리 gap≥3). 습관적 ±1(gap≥2) 해법은 **visible 테스트 통과·hidden 실패**. 채점기는 브루트포스 오라클(게임 시뮬레이션과 3000입력 0 불일치로 검증). arm: baseline / 규율판(opus/sonnet-boost) / 교차검증판 × Opus·Sonnet·Haiku 4.5.

| 모델 | arm | 통과 | 토큰 | baseline 논리 |
|---|---|---|---|---|
| Opus 4.8 | baseline | PASS | 6,642 | gap≥3 정확 |
| Opus 4.8 | opus-boost | PASS | 9,432 | — |
| Opus 4.8 | 교차검증 | PASS | 9,312 | 브루트포스 4016입력 diff, 일치 |
| Sonnet 5 | baseline | PASS | 3,991 | gap≥3 정확 |
| Sonnet 5 | sonnet-boost | PASS | 9,515 | — |
| Sonnet 5 | 교차검증 | PASS | 9,672 | 브루트포스 510입력 diff, 일치 |
| Haiku 4.5 | baseline | PASS | 16,159 | gap≥3 정확 |
| Haiku 4.5 | 교차검증 | PASS | 17,339 | — |

관찰:

- **8 arm 전부 PASS. Opus·Sonnet·Haiku 모두 baseline으로 ±2를 정확히 추론** — 함정(±1 습관)에 아무도 안 걸림. 추론 오류를 유도하려 설계한 과제인데도 현 모델은 첫 시도에 맞혔다. Haiku조차(16k 토큰으로 더 힘들게, 그러나 정확히).
- **교차검증 증폭기는 실제로 실행**(브루트포스 scratch 파일 + `cross-check: done (N inputs, agreed)` 신고, Opus 4016·Sonnet 510 입력 diff)**했으나 고칠 오류 0** → 순 토큰비용 +40~140%.
- **증폭기 자체는 작동한다** — 오프라인에서 gap-2 오답 구현을 넣으면 채점기가 실패시키고(visible 통과·hidden 실패), 교차검증이 그 diff를 잡는다. 즉 도구는 유효하나 **현 모델이 그 오류를 안 만들어 헤드룸이 0**.
- **세 실험(5·6 게이트 / 7 파티션 / 8 교차검증)의 일관된 결론:** 현 모델(Haiku 4.5까지)은 **객관 채점 가능한 코딩을 baseline으로 맞힌다.** 스킬의 추가 기계(멀티에이전트·스윕·교차검증)는 그런 과제에선 순비용이다. 값을 하는 곳은 base 모델이 **진짜 실패하는 좁은 구간**뿐 — (a) Haiku가 규칙을 누락하는 난도(실험 2 expr-eval 품질 반전), (b) 실패가 **의심 못 한 엣지/버그**인 발견 과제(6후속-3 audit, 6 OSS `&<>`).
- **"Opus/Sonnet 추론 최대 활용"의 실측 답:** baseline이 이미 천장이라 **증폭할 여지가 없다.** 추론 증폭기의 헤드룸은 base 모델이 실제로 추론 실패하는 곳 — 경쟁/연구급 난제, 또는 채점 불가한 판단형 과제 — 에만 있고, 그건 이 벤치마크(객관 채점 가능·중형)가 닿지 못하는 영역이다. 실험 변형은 `opus-boost-crosscheck/`·`sonnet-boost-crosscheck/`에 보존.
- 원시 데이터: `results\20260707-155436\`·`155439\`(Opus), `160021\`·`160026\`(Sonnet), `160402\`(Haiku).

### 실험 9: 도메인 스킬 1차 실측 — 요약·번역도 "명시 스펙 = baseline 천장", 단 요약에서 밀도-폭 트레이드오프 발견 (2026-07-07)

신규 도메인 스킬(summary-boost, translate-boost)의 첫 A/B. 기계 채점 가능한 과제 2개를 설계 (`domain-tasks-summary.json` / `domain-tasks-translate.json`):

- `summary-brief` (`fixtures\summary-brief\`) — 1,300단어 투자 브리핑을 **220단어 경영진 요약**으로. 채점: `hidden\grade_summary_hidden.py` — 로드베어링 앵커 사실 15개(고유 숫자/고유명사, 그룹별 대안 regex + 숫자는 lookaround 가드) 커버리지 + 길이. 폭-압축 긴장이 난이도 레버: 15사실 ÷ 220단어.
- `translate-notes` (`fixtures\translate-notes\`) — 릴리스 노트 영→한 번역(11헤딩·32불릿·용어집 7종·플레이스홀더 4종). 채점: `hidden\grade_translate_hidden.py` — 구조 카운트 일치·플레이스홀더 바이트 일치·용어 일관성(한국어 렌더링 수 ≥ 원문 수; 소스에서 동적 계산)·숫자 보존. 18체크.
- **채점기 자체 테스트 선행**: known-good 산출물 만점 + 결함 주입 산출물이 심은 항목만 FAIL하는 걸 확인 후 실측 (스펙 버그 사고 예방책).

결과 (n=1/셀, 유효 셀):

| 모델 | 과제 | baseline | skill(최종판) | 토큰 b→s |
|---|---|---|---|---|
| Sonnet 5 | summary | PASS 15/15, 5.2k | PASS 15/15, 29.0k | **×5.6** |
| Sonnet 5 | translate | PASS 18/18, 11.4k | PASS 18/18, 17.3k | +52% |
| Opus 4.8 | summary | PASS 15/15, 10.6k | PASS 15/15, 10.2k | −4% |
| Opus 4.8 | translate | PASS 18/18, 13.3k | PASS 18/18, 11.9k | −11% |

관찰:

- **품질 격차 미검출 — 실험 7·8의 경계가 도메인 과제에서도 재현.** 요구사항을 명시한 중형 요약/번역은 두 모델 baseline이 천장(만점). 스킬 이득의 헤드룸은 여기에도 없다.
- **비용 기울기가 코딩과 반대.** 코딩에선 Sonnet baseline이 장황(42k)해서 스킬이 −66%를 샀지만, 요약/번역에선 Sonnet baseline이 원래 간결(5.2k/11.4k) — 교정할 낭비가 없어 스킬 절차가 순비용(요약 5.6배). Opus는 소폭 절감. **도메인 작업의 Sonnet은 코딩의 Haiku 포지션**이다.
- **스펙 버그 사고 재발(과제 설계 교훈)**: 최초 프롬프트의 "포함 범주" 열거에서 '현재 운영 제약'을 빠뜨림 → skill 런이 계약을 문자 그대로 따라 가동률·초과근무를 잘라 13/15 FAIL, baseline은 우연히 포함해 PASS. skill 런의 상태 라인이 제외 사유("요구된 7개 카테고리 밖")를 자진 신고해 즉시 진단됨. 프롬프트 수정 후 재실험(위 표). → summary-boost에 "materiality는 결정에서 오고, 범주 목록은 floor지 ceiling이 아니다" 조항 추가.
- **밀도-폭 트레이드오프 발견 및 수정 (요약, Sonnet)**: 인벤토리를 섹션 단위로 축소한 개정판이 3연속 "정확히 1앵커 부족"(14/15 ×3, 매번 다른 앵커) — 완화어·조건 보존 규칙이 사실당 프로즈를 두껍게 만들어 220단어 상한에서 커버리지를 밀어냄(baseline은 218단어로 15/15 = 예산은 충분). 규칙 덧대기 2회 실패 후 예산 정책으로 교체: **"길이 상한 아래에선 폭 우선 — 로드베어링 단위 전부를 평서형으로 먼저, 뉘앙스·보조수치는 남는 예산에"** → 15/15 회복. 요약 스킬의 일반 원칙으로 채택.
- **채점기 밖 이득의 단편**: skill 런이 자기 초안의 잘못된 귀속("6.9년이 5년 가이던스 이내" — 실제로는 다른 시나리오의 가이던스)을 쓰기 시점 재조회로 잡아 수정. 앵커 채점으로는 안 보이는 충실성 이득이 존재하나, 점수를 못 움직인다.
- **다음 헤드룸 후보(미검증)**: 수십 페이지 문서(단일 패스 불가 → 인벤토리가 필수가 되는 구간), 요구사항 비명시 발견형 요약, Haiku. 코딩 실험과 같은 경계 가설.
- 원시 데이터: `results\20260707-155722\`(Sonnet 요약, 스펙버그 셀)·`155725\`(Opus 번역)·`160350\`(Sonnet 번역)·`160353\`(Opus 요약)·`160843\`·`161526\`·`161936\`·`162321\`·`163015\`(Sonnet 요약 skill 반복 5런: 15/15→14/15→14/15→14/15→15/15).

### 실험 9 후속: Fable 기준 대조 블라인드 심사 — "Fable 방식 이식"의 판단형 직접 검증 (2026-07-07)

기계 채점은 "규칙 준수"만 보고 "Fable답게 됐는가"는 못 본다는 지적에 따라 기준을 교체: **Fable baseline 산출물을 REFERENCE로** 놓고, 실험 9의 baseline/skill 산출물을 익명 후보 X/Y로 심사자 2명(Opus 4.8, Fable)에게 블라인드 쌍대 심사. 4축 채점(요약: 선택/구조/충실성/간결성, 번역: 충실성/용어/자연성/형식, 각 0-10, REFERENCE=10 기준) + "어느 후보가 REFERENCE의 방식·품질에 가까운가"(closer + margin). 하네스: `judge-vs-reference.py` + `judge-cases.json`, 원장 `judgments.jsonl`. X/Y 배정은 케이스×심사자 해시로 결정(위치 편향 상쇄). Fable 기준 자체가 기계 채점 만점임을 먼저 확인(요약 15/15 @ 36.4k tok, 번역 18/18 @ **8.5k tok — 전 조합 최소**). 요약 skill 산출물은 최종판 스킬로 통일(Opus 셀 재생성, 15/15 @ 9.9k).

| 케이스 | Opus 심사 | Fable 심사 | 합의 |
|---|---|---|---|
| 요약 × Sonnet | **skill (clear)** 37 vs 31/40 | **skill (clear)** 36 vs 30/40 | ✓ 만장일치 |
| 요약 × Opus | baseline (slight) 35 vs 33 | baseline (slight) 36 vs 36 | ✓ |
| 번역 × Sonnet | skill (slight) | baseline (slight) | ✗ 동률 |
| 번역 × Opus | baseline (slight) | skill (slight) | ✗ 동률 |

관찰:

- **이식은 "모델의 원래 방식이 Fable과 먼 곳"에서 확인된다 — 요약 × Sonnet.** 심사자 2명 모두 clear로 skill: 결론 우선 구조 + 밀도 있는 사실 패킹이 REFERENCE와 일치("leads decision-first like the reference … packs the same facts more densely"), baseline은 문서 순서 + 섹션 헤더로 이탈. 스킬이 강제한 규칙(결론 우선, 폭 우선 패킹)이 정확히 그 차이를 만들었다 — **판단형 과제에서 스킬 이식이 심사로 확인된 첫 사례.**
- **요약 × Opus는 baseline이 이미 Fable-adjacent** — 둘 다 근소하게 baseline. skill은 구조 개선("structural improvement")과 맞바꿔 보조 뉘앙스('unreplaced' 조건, 5년 가이던스 민감도, hedge-at-signing)를 절삭 — breadth-before-richness 정책이 예산 여유가 있는 Opus에서 과잉 절삭한 부작용(근소·n=1, 기록만 하고 스킬 수정은 보류).
- **번역은 두 모델 다 이미 Fable급** — 4표 전부 slight, 2:2, 심사자 합의 0/2(진짜 동률 신호). 이식할 갭이 없다.
- **심사가 기계 채점기의 사각지대 2개를 적발**: ① Sonnet baseline 번역의 의미 오역("does not count against the commitment"→"약정 위반으로 간주되지 않습니다" — SLA 계산 제외를 위반 면제로 뒤틈), ② Opus skill 번역의 용어집 외 드리프트(invoice→인보이스; REFERENCE·baseline은 청구서). **판단형 과제 채점은 기계(하한 보장) + 블라인드 심사(상층 품질) 2층이 맞다** — 실험 10이 "블라인드 심사 필요"로 남긴 항목의 실행이기도 하다.
- **종합**: "Fable 방식이 잘 적용됐나"의 판단형 답 = **갭이 있는 조합(Sonnet×요약)에서는 만장일치 clear로 이식 확인, baseline이 이미 Fable-adjacent인 곳(Opus, 번역)에서는 중립~미세 역효과.** 실험 10의 효율축 결론(능력은 이식 불가)과 합치면: 스킬이 이식하는 것은 Fable의 *구조·규율*이고, 그것이 값을 하는 곳은 base 모델이 그 구조를 스스로 못 만드는 조합뿐이다.
- 원시 데이터: `results\20260707-164018\`(Fable 요약)·`164020\`(Fable 번역)·`164023\`(Opus 요약 skill 최종판)·`judgments.jsonl`.

### 실험 10: Fable 직접 비교 — outcome 패리티는 이미 성립, 스킬은 효율에서 오히려 Fable에서 멀어진다 (2026-07-07)

질문: "같은 과제를 Fable과 스킬 적용 Opus/Sonnet이 푼 걸 비교하면 Fable 방식이 잘 적용됐는지 알 수 있지 않나?" 실현 가능성 확인 — 하네스가 `claude-fable-5`를 헤드리스로 호출함. 실험 8의 함정 과제(max-points, ±2 트랩)에 Fable baseline을 추가해 전 모델과 비교.

| 모델·arm | 통과 | 토큰 | 비고 |
|---|---|---|---|
| **Fable baseline** | PASS | **2,678** | 최소. gap≥3 정확 추론, 26줄 O(n) 투포인터 |
| Sonnet baseline | PASS | 3,991 | |
| Opus baseline | PASS | 6,642 | |
| Opus +skill | PASS | 9,432 | |
| Opus +crosscheck | PASS | 9,312 | |
| Sonnet +skill | PASS | 9,515 | |
| Sonnet +crosscheck | PASS | 9,672 | |
| Haiku baseline | PASS | 16,159 | |
| Haiku +crosscheck | PASS | 17,339 | |

관찰 — 이 비교가 "Fable 방식 적용됐나"를 두 축으로 갈라 답한다:

- **Outcome(pass/fail) 패리티: 이미 성립.** Fable·Opus·Sonnet·Haiku, boosted·unboosted **전부 통과.** 객관 채점 과제에선 base 모델이 이미 Fable과 같은 정답에 도달하므로, outcome으로는 스킬이 뭘 했는지 안 드러난다(실험 5~9의 재확인).
- **측정 가능한 유일한 품질축(간결한 정답=효율): Fable이 1위, 그리고 스킬은 약한 모델을 Fable에서 *멀어지게* 한다.** Fable은 2.7k 토큰에 바로 맞히는데, boosted Opus/Sonnet은 ~9.5k — 스킬이 검증 기계를 얹어 **더 장황해졌다.** 즉 스킬은 Opus/Sonnet을 Fable답게 만든 게 아니라, 같은 정답에 더 많은 일을 하게 만들었다.
- **왜냐면 Fable의 "방식"은 여기서 프로세스가 아니라 능력이다** — "한 번에 정확·간결하게 추론". 이건 규칙으로 이식되지 않는다. 스킬은 Fable의 효율적 1패스 추론 대신 장황한 검증 기계를 대입할 뿐이다.
- **스킬이 모델을 Fable에 가깝게 만드는 유일한 경우**: base가 원래 *실패*할 때(Haiku expr-eval FAIL→PASS, 실험 2). 거기선 추가 규율이 Fable이 native로 갖는 정확성을 사준다 — 단 Fable의 효율이 아니라 brute한 규율로. outcome은 Fable에 근접, 효율은 미달.
- **종합 — "Fable 방식이 잘 적용됐는지"의 실측 답:** (a) outcome은 base가 이미 Fable급이라 스킬이 닫을 격차가 없고, (b) 효율/간결성에선 스킬이 오히려 Fable에서 멀어진다. 스킬이 값을 하는 건 base가 실패하는 좁은 구간뿐이고, 거기서도 Fable의 *효율*이 아니라 *정답*에만 근접한다. **Fable의 진짜 우위(효율적 정확 추론)는 프롬프트·규율로 이식되지 않는다.**
- 한계: n=1, 단일 과제, 채점 밖 품질(견고성·가독성·정직성)은 미측정 — 그건 블라인드 심사 필요(주관적). 토큰은 objective 대리 지표.
- 원시 데이터: `results\20260707-164420\`(Fable), 비교군은 실험 8.

### 실험 11: 판단·아키텍처 과제 — 스킬은 Fable을 못 따라잡고 오히려 방해한다 (2026-07-07)

질문: "정답이 하나가 아닌 설계·아키텍처·판단 과제를 같은 걸로 주면, 토큰을 더 쓰더라도 스킬 적용 Opus/Sonnet이 Fable을 따라잡는가?" pass/fail로 못 재므로 **블라인드 페어와이즈 심사**로 측정(`run-arch-benchmark.ps1`, `arch-tasks.json`). 과제: 200개 미용실 체인 예약 시스템 설계(데이터 모델·멀티서비스 실시간 가용성·동시 더블부킹 방지·15% 노쇼 정책과 리스크·트레이드오프). 후보 5개를 심사자 2명(Opus·Fable, 익명 X/Y·순서 랜덤)이 10페어 심사.

| 후보 | 총 승 (2심사자) | Opus 심사자만(비편향) | 문서 길이 |
|---|---|---|---|
| **fable-base** | **8/8 (5 clear)** | **4/4 (전승)** | 10,850자 |
| opus-base | 4 | 3 | 10,380자 |
| sonnet-base | 4 | 2 | 4,985자 |
| opus-boost | 4 | **1** | 4,255자 |
| sonnet-boost | **0** | 0 | 4,467자 |

관찰:

- **Fable이 8전 8승, 전 매치업 석권.** 심사자 간 일치 70%지만 **Fable 매치업은 두 심사자 100% 일치** — 비편향 심사자(Opus, Fable 아님)도 Fable을 4/4로 1위. 자기편향 아님이 확인됨.
- **스킬은 격차를 못 좁혔고 오히려 낮췄다.** 비편향 Opus 심사 기준 opus-boost는 1승으로 opus-base(3승)보다 **아래**, sonnet-boost는 0승으로 sonnet-base(2승)보다 **아래**. 판단 과제에서 스킬이 **역효과**.
- **원인은 간결화 규율.** boosted 문서는 4.3k자로 baseline·Fable(10.4~10.9k자)의 절반 이하. 코딩 효율을 사주던 "간결 출력" 규칙이 판단 과제에선 **깊이를 깎아 품질을 떨어뜨린다.**
- **Fable이 이긴 이유(심사 근거 일관됨) = 실패 인지 추론의 깊이.** 심사자들이 반복 지목: Fable만 동시 더블부킹의 미묘한 레이스를 정확히 진단("`FOR UPDATE`는 아직-삽입-안-된 행을 못 잠근다 → GiST exclusion constraint가 진짜 serializer"), 스타일리스트별 서비스 소요시간이 가용성 계산에 반영, 노쇼 정책을 EV 논리로 계층화하고 리스크/완화 표까지. 나머지는 "sound but thinner". 이건 프로세스가 아니라 **추론 능력**이다.
- **종합 — "토큰 더 써서 Fable을 따라잡나"의 답: 아니오.** 정답 없는 판단 과제에서 Fable의 우위(정확·실패인지 추론의 깊이)는 스킬로 이식되지 않고, 코딩용 간결 규율은 오히려 그 깊이를 억눌러 **역효과**를 낸다. Fable의 진짜 강점은 규율로 복제 불가.
- 한계: n=1 과제·1런, 심사자 일치 70%, Fable이 후보이자 심사자(익명화로 완화 + 비편향 Opus 심사자로 교차확인). 방향성은 견고.
- 원시 데이터: `results\arch-20260707-165549\`.

### 실험 12: 나머지 도메인 스킬 6종의 Fable 기준 대조 — 심사 진단으로 개선까지 한 사이클 (2026-07-07)

실험 9 후속의 방법론(Fable baseline 산출물 = REFERENCE, 익명 쌍대 블라인드 심사 ×2심사자)을 나머지 6종에 적용하고, **심사 사유를 스킬 결함 진단으로 되먹임**해 수정 → 패배 셀 재생성 → 재심사까지 완주. 과제 6개 신설: `domain-tasks-{review,report,slides,research,data,persona}.json` + 픽스처(리뷰는 audit-v2 재사용; data는 **시드된 심슨의 역설 CSV** — 전체 전환율은 상승하지만 세그먼트 내부는 전부 하락 + 중복 8행·널 6행, `fixtures\data-simpson\`). 대상 모델 Sonnet 5 (Opus 미측정). 심사 하네스 `judge-vs-reference.py`를 8종 kind별 4축 지원으로 확장.

| 케이스 (×Sonnet) | 1차 판정 | 진단(심사 사유) | 수정 후 재심사 |
|---|---|---|---|
| review | **skill 2:0** | 둘 다 7버그 전부 발견(baseline도 천장) — skill이 커버리지·실행성 근소 우위 | — |
| data | **skill 2:0** | **둘 다 심슨 함정 통과**(Sonnet baseline도!) — skill이 행수 결산·confounder 신중함으로 우위 | — |
| persona | 1:1 | 동률 — 둘 다 보이스·경계·압박 정직성 우수 | — |
| report | baseline 2:0 | **상태 라인이 메모 파일 안에 누출**("raw metadata footer") + 단계별 계획 약함 | baseline 2:0 slight — 푸터 지적 소멸, 잔여 차이는 실질(staged timeline·명시적 ask) → "ask+타임라인" 조항 추가(미재검증) |
| slides | baseline 2:0 (**1 clear**) | **"완전한 문장 제목" 규칙이 역효과** — 제목=본문 중복, 초점 붕괴. Fable 기준은 짧은 제목+증거 본문 | **1:1 회복** — 제목을 ≤8단어 주장으로 증류하는 규칙으로 교체 |
| research | baseline 2:0 | 평가서 파일 안 메타 푸터 + 미확립 항목 1개 누락 | **skill 2:0 반전** — 푸터 제거만으로 |

종합 (요약·번역 포함 8도메인, 최종 스킬판): **skill 승 4 (summary clear·review·data·research) / 무 3 (translate·persona·slides) / 패 1 (report, slight)** — 심사자 투표 11:5. 반복 전 3승 2무 3패(clear 패 1) → clear 패배 0.

관찰:

- **최대 소득은 판정보다 진단 — 전 도메인 공통 결함 1개 발견.** 코딩 과제에선 상태 라인이 채팅으로 나가지만, 문서 과제에선 Sonnet이 **산출물 파일 안에** 메타 푸터를 넣는다(report·research 패배의 명시적 사유; review의 "lenses 메타 줄"도 동일). → 8종 전부에 "deliverable hygiene: 상태 라인·프로세스 노트는 채팅 응답에, 산출물 파일엔 절대 금지" 조항 추가. research가 이 수정 하나로 패→승 반전한 것이 실증.
- **스킬 규칙이 Fable 방식과 어긋난 지점을 심사가 정확히 짚는다**: slides의 "완전한 문장 제목" 규칙(clear 패배) → Fable 기준처럼 "짧은 주장 제목(≤8단어) + 증거 본문"으로 교체하자 동률 회복. 규칙→행동→심사의 인과가 왕복으로 확인.
- **data-boost 언어 규칙 결함**: "응답은 한국어"가 아티팩트에 적용돼 영어 데이터·브리프에 한국어 findings.md 생성(심사자는 감점 안 했으나 명백한 불일치) → 아티팩트는 요청/소스 언어, 채팅만 한국어로 분리.
- **Sonnet baseline은 심슨 함정도 7버그 발견도 천장** — 발견형이라 기대했던 data·review에서도 baseline이 정답 도달. 실험 5~11의 "현 모델 baseline 천장"이 판단형에서도 유지. 다만 이 두 도메인에서 skill은 천장 위 여분(결산 라인·confounder 신중함·커버리지)으로 심사 우위 — 순수 정답성이 아니라 **Fable식 마감 품질**의 차이다.
- 실험 11(아키텍처: 코딩식 간결 규율이 깊이를 깎아 역효과)과의 대비: 도메인 스킬엔 그 규율이 없어 역효과를 피했고, 도메인별 마감 규칙이 심사 우위를 만든다. **이식되는 것은 규율과 마감이지 추론 깊이가 아니다** — 두 실험의 공통 결론.
- 한계: 셀당 n=1, 심사자 2명 중 1명이 Fable(자기편향 가능 — X/Y 익명·해시 배정으로 완화), report 최종 조항은 미재검증. 원시 데이터: `results\20260707-1703xx\`·`1713xx\`(v2), 심사 원장 `judgments.jsonl`, 케이스 `judge-cases-2~4b.json`.

### 실험 12 후속: report 재검증 + summary 토큰 다이어트 + auto 발동 8종 실측 (2026-07-07)

실험 12가 남긴 3개 미결 항목의 마무리.

**1) report-boost 재검증 — 패→무.** "ask+단계별 타임라인" 조항 반영판(v3, agents 1 — 논지 프로브 발동)을 재심사: Opus 심사자가 skill로 뒤집고(사유: "staged plan with named phases, non-renewal ask ... covers more of the reference's decision structure" — 추가한 조항이 지목됨), Fable 심사자는 baseline slight 유지 → **1:1 동률**. 8도메인 최종 전적: **4승 4무 0패**.

**2) summary-boost 토큰 다이어트 — −86%.** design-boost에서 실측된 레버("반복은 thinking에서, 표면엔 최종본만")를 이식: **29.0k → 4.2k 토큰, 270s → 61s, 기계 채점 15/15 유지** — baseline(5.2k)보다도 싸졌다. 트레이드오프: 심사는 만장일치 clear → 1:1(두 심사자가 같은 2차 뉘앙스 누락 지목 — "Danvers 압박 단독으론 5년 가이던스 이내"; 앵커 15개 밖이라 기계 채점은 못 봄). 점수합은 여전히 skill 우위(35:32, 35:33). −86% 비용에 clear→동률 맞교환으로 채택.

**3) auto 발동 — 4/8, 그리고 문구가 아니라 과제 성격이 가른다.**

| 발동 ○ (1/1) | 발동 × (0/2 — description 강화 후에도) |
|---|---|
| summary · translate · slides · data | report · research · review · persona |

- 미발동 4종에 실전 표현("decision memo", "assess evidence", "review a module for defects", "reply in character")을 description에 추가하고 재측정 → **전부 여전히 미발동**. 문구 레버가 아니다.
- 패턴: 발동 4종은 **기계적 제약이 많은 과제**(단어 예산, 용어집/구조 카운트, 헤드라인 규칙, 데이터셋 계산) — Sonnet이 "절차 도움이 필요하다"고 느끼는 곳. 미발동 4종은 **자신 있는 산문·논증형 과제** — 그냥 쓴다. 실험 5·6의 "확신이 조건을 우회한다"(조건 참을 기입하고도 서브에이전트 거부)와 같은 층위: **발동 판단은 description 매칭이 아니라 모델의 자기확신에서 나온다.**
- 처방: report·research·review·persona는 **명시 호출**(스킬 이름 언급 또는 /skill)이 기본. 자동 발동에 의존할 수 있는 건 기계 제약형 4종뿐. 강화된 description은 무해하므로 유지.
- auto 경로 부가 관찰: 발동 시 산출물 품질은 유지되나(summary auto 15/15 PASS, translate auto 17/18 — 용어 1회 누락) 주입 모드보다 무겁다(summary auto 30턴/13.5k vs 주입 9턴/4.2k) — 스킬을 중간에 로드하며 절차를 재구성하는 오버헤드.
- 원시 데이터: `results\20260707-1732xx\`·`1734xx\`·`1737xx\`(재측정), report v3 `173215\`, summary diet `173220\`, 심사 `judgments.jsonl`(report-sonnet-v3, summary-sonnet-diet).

### 숨김 테스트 패턴

쉬운 과제는 모델이 보이는 테스트를 통과할 때까지 고치면 되므로 pass_pct 변별력이 없다. `csv-parser`처럼 **스펙은 프롬프트에 전부 명시하되, 보이는 테스트는 기본 케이스만 주고 채점은 `hidden\`의 숨김 테스트로** 하면 "보이는 테스트만 통과시키는 성급함"과 "스펙 전항목 구현"의 차이가 통과율로 드러난다. 숨김 테스트는 `check`에서 작업 폴더로 복사해 실행한다 (tasks.json의 csv-parser 항목 참고).

### 게이트 발동 검증 과제 (gate-tasks.json)

강화판 멀티에이전트 게이트의 발동·이득 검증용 과제 2개 — [gate-verification-plan.md](gate-verification-plan.md)의 구현. 기본 tasks.json과 분리되어 있어 `-TasksFile`로 지정할 때만 실행된다.

- `multiref-signature` — `storage.save`를 **기본값 없는 필수 keyword 파라미터**로 변경, 호출 지점 4곳(`fixtures\multiref-signature\`). `legacy\compat.py`는 보이는 테스트가 import하지 않는 조용한 호출 지점이라 성급한 런은 놓친다. 채점: `hidden\test_multiref_hidden.py` (새 시그니처 + csv/에러 규칙 + 호출 지점 4곳 전부).
- `audit-seeded-bugs` — 로그 분석기 3파일(149줄)에 서로 다른 클래스의 버그 5개(off-by-one, 경계 비교, 삼킨 예외, 가변 기본 인자, 빈 입력 나눗셈)를 심은 감사 과제. 각 함수의 docstring이 스펙. 채점: `hidden\test_audit_hidden.py`가 버그별 PASS/FAIL 한 줄씩 + 정상 동작 보존(BASELINE) 검사를 출력하고 5/5 + BASELINE 통과 시에만 exit 0. 발견율(k/5)은 각 런의 `check-output.txt`에서 사후 집계.

난이도 상향판 `gate-tasks-v2.json` (실험 5 후속에서 추가):

- `multiref-signature-v2` (`fixtures\multiref-signature-v2\`) — 호출 경로 6곳, grep 불가 간접 참조 3종(별칭 import / getattr / 콜백 레지스트리). 채점: `hidden\test_multiref2_hidden.py`.
- `audit-seeded-bugs-v2` (`fixtures\audit-seeded-bugs-v2\`) — 4파일 240줄, 미묘한 버그 7개. 채점: `hidden\test_audit2_hidden.py` (발견율 k/7). **주의**: docstring이 곧 스펙이므로 함수 계약을 서술할 때 모호한 용어를 쓰면 안 된다 — p95를 "nearest-rank"로 잘못 라벨했다가 정직한 auditor가 공식을 "수리"해 억울하게 FAIL한 사고가 있었다(실험 5 후속 참고). 계약은 정확한 공식/규칙으로 못박을 것.

실행 (2모델 × 2모드 × 2과제 = 8회 호출; audit 과제는 서브에이전트만큼 한도 소모가 큼):

```powershell
.\run-benchmark.ps1 -TasksFile .\gate-tasks.json -Model claude-sonnet-5 -Skill sonnet-boost
.\run-benchmark.ps1 -TasksFile .\gate-tasks.json -Model claude-opus-4-8 -Skill opus-boost
# 난이도 상향판
.\run-benchmark.ps1 -TasksFile .\gate-tasks-v2.json -Model claude-sonnet-5 -Skill sonnet-boost
.\run-benchmark.ps1 -TasksFile .\gate-tasks-v2.json -Model claude-opus-4-8 -Skill opus-boost
```

게이트 발동 판정 = 해당 런의 `agents_spawned ≥ 1`. 결과 해석과 후속 행동은 계획 문서의 판정 기준 표 참고.

### 실전 OSS 과제 (oss-tasks.json) — 대형 코드베이스 이월분

실험 5의 결론("수백 줄 자기완결 과제로는 baseline 천장을 못 깬다")에 따라 실제 오픈소스에서 가져온 과제. **git 히스토리 회귀 방식**: 실제 버그픽스 커밋의 직전 상태를 고정하고, 픽스가 추가한 테스트를 숨김 채점기로 이식한다.

- `md-ref-backtick` — [Python-Markdown](https://github.com/Python-Markdown/markdown) (src 8.3k LOC, 의존성 0). **이슈 #495 — 2016년부터 열려 있다가 2025-12에야 고쳐진 버그**: 지름길 참조 링크 라벨에 코드 스팬이 있으면(`` [`Text`] ``) 백틱 프로세서(우선순위 190)가 참조 프로세서(170)보다 먼저 소비해 링크가 안 된다. 근본 원인이 두 프로세서의 우선순위 상호작용이고 업스트림 픽스(`07dfa4e`)는 두 클래스에 걸친다. 크래시가 아닌 동작 버그라 traceback 힌트도 없다.
- 고정 커밋: `fb6b27a`(픽스의 부모). 소스는 `oss\md-ref-backtick\`에 두며 **git에는 커밋하지 않는다**(.gitignore) — 다른 머신에서는 `.\setup-oss.ps1`로 재생성.
- 채점: `hidden\test_oss_md_hidden.py` — 버그 케이스 3개(픽스 커밋의 실제 테스트에서 이식) + **회귀 그물 BASELINE 11개**(인라인 링크+코드, 브래킷 든 코드 스팬, 이중 백틱, 2단 참조 등 — 고정 커밋과 픽스 커밋 양쪽에서 실측으로 PASS 확인된 것만). 우선순위만 건드리는 순진한 수정이 회귀 그물에 걸리는 것 검증됨.
- 환경 주의: 이 머신의 python엔 pip/pytest가 없어 **의존성 0 프로젝트만 가능**하다. 과제 프롬프트에도 "pytest 없음, 스니펫으로 직접 검증"을 명시함.

```powershell
.\setup-oss.ps1        # 최초 1회 (oss\ 재생성)
# OSS 과제는 크고 게이트가 발동하므로 턴 상한을 올린다 (기본 40이면 Sonnet skill이 잘림 — 실험 6 참고)
.\run-benchmark.ps1 -TasksFile .\oss-tasks.json -Model claude-sonnet-5 -Skill sonnet-boost -MaxTurns 80
.\run-benchmark.ps1 -TasksFile .\oss-tasks.json -Model claude-opus-4-8 -Skill opus-boost -MaxTurns 80
```

주시할 지표: pass 격차(부분 수정·회귀 유발이 나오는지), `agents_spawned`(멀티파일 픽스이므로 게이트 발동 대상), 그리고 **스켑틱 개입 후 diff가 추가 수정됐는지**(스트림에서 Agent 결과 이후 Edit 발생 여부 — 게이트가 실제 결함을 잡았는지의 가장 예민한 신호).

## 디자인 벤치마크 (run-design-benchmark.ps1)

`design-boost`용 별도 하네스. 디자인은 pass/fail 채점이 불가능하므로 **블라인드 LLM 심사** 방식을 쓴다. (v2: 쌍대 비교 × 복수 심사자)

```powershell
.\run-design-benchmark.ps1                                  # Sonnet 5 생성, 4-arm, 심사 Opus+Fable
.\run-design-benchmark.ps1 -Model claude-opus-4-8           # Opus 생성
.\run-design-benchmark.ps1 -Arms baseline,design-boost -JudgedArms baseline,design-boost
.\run-design-benchmark.ps1 -Judges claude-opus-4-8          # 심사자 1명만
```

작동 방식 (v2):

1. **생성** — design-tasks.json의 브리프마다 4-arm: `baseline`(브리프만, Skill 차단) / `design-boost`(SKILL.md + DESIGN-SYSTEM.md 주입) / `frontend-design`(Anthropic 공식 스킬 주입) / `auto`(주입 없음 + **Skill 도구 개방** → 스트림에서 자가 발동 감지, fire 측정). 파일 도구만 허용된 헤드리스 실행.
2. **스크린샷** — 데스크톱 1440px 직접 캡처. 모바일은 **390px iframe 래퍼**로 렌더 후 크롭 — Windows Chromium이 최소 창폭(~492px)을 강제하기 때문에 `--window-size=390` 직접 캡처는 492px 레이아웃의 왼쪽 390px만 잘라낸 가짜 "잘림"을 만든다 (v1의 버그, 아래 정정 참고).
3. **객관 오버플로 판정** — 페이지에 프로브 JS를 주입해 텍스트 요소의 잉크 오버플로(`scrollWidth > clientWidth`)와 뷰포트 이탈을 세고, 결과를 빨강/초록 띠로 그린 뒤 스크린샷 픽셀로 읽는다 (`mobile_overflow` — 심사자 인상이 아닌 DOM 사실).
4. **쌍대 블라인드 심사** — JudgedArms의 모든 쌍(3-arm이면 3쌍)을 X/Y 무작위 배정으로 익명화하고, **심사자 2모델**(기본 Opus 4.8 + Fable)이 각각 승자·마진(slight/clear)·한줄 사유를 JSON으로 낸다. 절대 점수보다 순위 신뢰도가 높고, **심사자 간 일치율**(agreement)이 심사 신뢰도 지표로 나온다. 매핑은 `<과제>_pair_*\mapping.json`.

결과: `design-summary.csv`(arm별 승수·clear승·오버플로 수), `pairwise.jsonl`(심사 원장), `runs.jsonl`(생성 메트릭 + fire + overflow), 과제별 폴더에 index.html·스크린샷.

주의: 심사자는 스크린샷만 보므로 인터랙션/모션 품질은 평가에서 빠진다. auto arm은 품질 심사에서 제외(fire 측정 전용).

### 실측 결과 (2026-07-07)

> **정정 (같은 날 발견):** 1·2라운드의 모바일 스크린샷은 v1 하네스 버그로 **492px 레이아웃을 390px로 크롭**한 이미지였다 (Windows Chromium 최소 창폭 클램프). 따라서 두 라운드 심사평의 "모바일 우측 잘림" 감점은 전부 무효 — 검증 결과 예: 2라운드 tide-app design-boost는 진짜 390px에서 정상 적응한다. 데스크톱 판정과 개성/타이포/컬러 축은 영향 없음. v2에서 iframe 렌더 + 객관 오버플로 프로브로 교정됨.

브리프 2개(tide-app: 제주 서핑 조석 앱 랜딩 / type-foundry: 서울 한글 활자 주조소 홈) × 3-arm × 1회, 생성 Sonnet 5, 심사 Fable. 점수는 5차원 합계 (50점 만점):

| 과제 | arm | 순위 | 총점 | 개성 | 타이포 | 레이아웃 | 컬러 | 완성도 | 턴 | 비용(환산) |
|---|---|---|---|---|---|---|---|---|---|---|
| tide-app | **design-boost** | **1** | 39.1 | 8.5 | 8.2 | 7.3 | 7.9 | 7.2 | 26 | $3.80 |
| tide-app | frontend-design | 2 | 38.9 | 8.2 | 7.4 | 7.9 | 7.6 | 7.8 | 2 | $1.88 |
| tide-app | baseline | 3 | 20.6 | 2.8 | 4.8 | 4.2 | 3.8 | 5.0 | 2 | $1.17 |
| type-foundry | **frontend-design** | **1** | 36.5 | 8.5 | 8.0 | 6.5 | 7.5 | 6.0 | 26 | $4.54 |
| type-foundry | design-boost | 2 | 33.5 | 7.5 | 7.5 | 6.0 | 7.0 | 5.5 | 25 | $4.78 |
| type-foundry | baseline | 3 | 28.5 | 5.5 | 6.5 | 4.5 | 5.5 | 6.5 | 2 | $1.02 |

관찰:

- **스킬 효과는 압도적, 두 스킬 간 차이는 박빙.** baseline 평균 24.6 vs design-boost 36.3 vs frontend-design 37.7. 1승 1패에 점수 차 0.2/3.0점 — n=2로는 우열 판정 불가. "design-boost ≈ Anthropic 공식 스킬, 둘 다 baseline을 크게 이김"이 현재 결론.
- **baseline은 예측된 방식으로 실패**: tide-app에서 "파란 그라데이션 + 폰 목업 + 스토어 배지 + 빅넘버 통계열"(심사평: "재고 SaaS 템플릿"), type-foundry에서 크림+테라코타 거의-빈-페이지. 개성 점수(2.8/5.5)가 격차의 근원 — 스킬이 정확히 그 축을 고친다.
- **design-boost의 실패 모드 2개 발견** (스킬 개선 소재): (1) 금지 목록의 디폴트를 그대로 씀 — tide-app에서 크림+세리프, type-foundry에서 의미 없는 01/02/03 넘버링. Sonnet이 체크리스트를 읽고도 어긴다. (2) **모바일 오버플로** — 두 과제 모두 390px에서 텍스트/그리드가 오른쪽으로 잘림. 헤드리스 환경에선 렌더 확인이 불가능해 "보고 고쳐라"형 규칙이 작동 안 함 → DESIGN-SYSTEM.md에 정적 코드 규칙(clamp() 타입 스케일, max-width, overflow-wrap, 고정폭 금지)으로 보강 필요. frontend-design도 type-foundry 모바일 잘림이 있었음 — 공통 약점.
- **비용 프로파일**: 스킬 arm은 프로세스대로 25-26턴을 써 baseline의 3-4배 비용. frontend-design은 과제에 따라 2턴 원샷 또는 26턴으로 갈림 — 에세이형은 프로세스 강제가 없어 실행 편차가 크다.
- 한계: 과제 2개 × 1회 × 심사자 1명. 심사자(Fable)는 frontend-design 스킬 스타일의 원저자 격이라 그 미학에 편향됐을 가능성 — 심사 모델 교체 교차검증이 다음 단계.
- 원시 데이터: `results\design-20260707-113120\` (index.html·스크린샷·mapping.json·judge-raw.json)

### 2라운드: 강화판 design-boost (같은 날)

1라운드에서 발견된 실패 모드 2개(모바일 잘림, 금지 디폴트 무시)를 고친 강화판으로 재실행. design-boost에는 treatment 판별, 서면 클리어런스, 모바일 오버플로 정적 규칙(§5), Fable artifact-design/dataviz 증류, OSS 규칙(색 비중 60-70%, 깊이 전략, 모션 마이크로스펙 등)이 추가됐다. frontend-design은 변경 없음(대조군).

| 과제 | arm | 순위 | 총점 | 턴 | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|---|
| tide-app | frontend-design | 1 | 39.8 | 6 | 15.7k | $0.78 |
| tide-app | design-boost | 2 | 36.2 | 7 | 21.1k | $1.25 |
| tide-app | baseline | 3 | 27.6 | 3 | 10.2k | $0.68 |
| type-foundry | **design-boost** | **1** | 39.6 | 7 | 20.1k | $1.05 |
| type-foundry | baseline | 2 | 36.6 | 3 | 10.0k | $0.49 |
| type-foundry | frontend-design | 3 | 36.6 | 3 | 14.5k | $0.68 |

관찰:

- **효율이 구조적으로 좋아졌다**: design-boost 26턴/64-82k tok/$3.8-4.8 → **7턴/20-21k tok/$1.1-1.2** (3-4배 절감), 점수는 동급 유지. "thinking에서 반복하고 최종 플랜만 노출" 조항과 treatment 판별이 다턴 낭비를 제거한 것으로 보인다.
- **금지 디폴트 재발 없음**: 1라운드의 크림+세리프·01/02/03이 사라졌다 (서면 클리어런스 효과). 단 tide-app에서 "borderline acid-green-on-dark" — 목록의 다른 디폴트 근처로 이동. 디폴트 목록은 두더지잡기 성격이 있다.
- **모바일 잘림 1/2 해소**: type-foundry는 "proper mobile adaptation"으로 해결, tide-app은 여전히 우측 잘림. 대조군 frontend-design은 type-foundry 모바일이 "disqualifying responsive failure"(데스크톱 축소판) — 이 문제는 Sonnet의 일반 약점이고 §5 규칙이 부분적으로만 막는다.
- **새 규칙의 트레이드오프 발견**: type-foundry design-boost의 유일한 감점이 "회색 `[사진: ...]` 플레이스홀더 박스" — 가짜 이미지 금지 규칙을 문자 그대로 준수한 결과다. 실서비스(실사진 삽입 예정)에는 올바른 행동이지만 원샷 미인대회에서는 감점. 규칙 유지가 맞다.
- 2라운드 종합(4회 심사 합산): baseline 평균 28.3 vs design-boost 37.1 vs frontend-design 38.0 — 스킬 효과는 재확인, 두 스킬은 2승 2패 동급. baseline 점수의 라운드 간 출렁임(20.6→27.6, 28.5→36.6)이 크므로 절대점수 비교보다 동일 라운드 내 순위가 신뢰할 만하다.
- 원시 데이터: `results\design-20260707-142150\`

### 3라운드 (v2): 쌍대 심사 × 심사자 2명 + auto 발동 + 객관 오버플로 (같은 날)

하네스 v2(모바일 iframe 렌더 교정 포함)로 재실행. 브리프 3개(에디토리얼 2 + **셀러 대시보드** 유틸리티 1) × 4-arm, 생성 Sonnet 5. 심사는 쌍대 비교(브리프당 3쌍) × 심사자 2명(Opus 4.8 + Fable), X/Y 무작위. design-boost에는 이 라운드 직전에 레퍼런스 조항까지 반영됨.

쌍대 승수 (12판; 1판은 심사 JSON 파싱 실패로 11판 집계):

| arm | 승 | clear 승 | 모바일 오버플로(3브리프 중) |
|---|---|---|---|
| frontend-design | 9 | 8 | 1 |
| design-boost | 8 | 7 | **0** |
| baseline | **0** | 0 | 2 |

심사자별 판정 전체 (base=baseline, db=design-boost, fd=frontend-design):

| 과제 | 쌍 | Opus 4.8 판정 | Fable 판정 | 일치 |
|---|---|---|---|---|
| tide-app | base vs db | db (clear) | db (clear) | O |
| tide-app | base vs fd | fd (clear) | fd (clear) | O |
| tide-app | db vs fd | **fd** (clear) | **db** (clear) | **X** |
| type-foundry | base vs db | db (slight) | 파싱 실패 | — |
| type-foundry | base vs fd | fd (clear) | fd (clear) | O |
| type-foundry | db vs fd | fd (clear) | fd (slight) | O |
| seller-dashboard | base vs db | db (clear) | db (clear) | O |
| seller-dashboard | base vs fd | fd (clear) | fd (clear) | O |
| seller-dashboard | db vs fd | db (clear) | db (clear) | O |

생성 메트릭 (task × arm):

| 과제 | arm | 오버플로 | 턴 | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|
| tide-app | baseline | **O** | 3 | 11.5k | $0.53 |
| tide-app | design-boost | — | 26 | 29.5k | $1.98 |
| tide-app | frontend-design | — | 8 | 18.9k | $0.96 |
| tide-app | auto (fired) | — | 9 | 25.5k | $1.72 |
| type-foundry | baseline | — | 4 | 16.4k | $0.76 |
| type-foundry | design-boost | — | 7 | 17.8k | $0.98 |
| type-foundry | frontend-design | — | 4 | 18.2k | $0.86 |
| type-foundry | auto (fired) | — | 10 | 22.5k | $1.20 |
| seller-dashboard | baseline | **O** | 7 | 26.9k | $2.33 |
| seller-dashboard | design-boost | — | 13 | 58.6k | $2.95 |
| seller-dashboard | frontend-design | **O** | 23 | 108.5k | **$8.10** |
| seller-dashboard | auto (fired) | **O** | 26 | 42.8k | $3.05 |

관찰:

- **baseline 전패 (0/11).** 쌍대 방식에서 격차가 절대점수보다 선명하다 — 두 심사자 모두, 세 브리프 전부에서 스킬 arm 승.
- **auto 발동 3/3.** 브리프만 줬는데 Sonnet이 매번 design-boost를 스스로 불렀다. "실전에서 안 불리면 무용지물" 리스크 해소. 단 auto 대시보드 런은 발동했는데도 오버플로 — 주입 arm(SKILL+DESIGN-SYSTEM 전문)과 달리 auto 경로는 DESIGN-SYSTEM.md §5(오버플로 규칙)를 안 읽었을 가능성. **개선 후보: 모바일 임계 규칙을 SKILL.md 본문으로 승격.**
- **직접 대결은 3:3 동률, 갈린 지점이 정보다**: 유틸리티 브리프(대시보드)는 심사자 2명 모두 design-boost clear 승 — 이번에 추가한 treatment 판별·차트 규칙이 실측으로 값을 함. 에디토리얼 중 활자 주조소는 frontend-design 승(2명 일치), 조석 앱은 심사자 불일치(초접전).
- **객관 오버플로: design-boost만 3/3 통과.** §5 정적 규칙의 효과가 주입 경로에서 확인됨. frontend-design은 대시보드에서 오버플로 + 1892초/$8.10 폭주 — 에세이형 가이드는 유틸리티 과제에서 실행 편차가 크다.
- **심사자 일치율 88% (7/8).** 유일한 불일치는 조석 앱의 스킬 간 대결(Opus→fd, Fable→db, 둘 다 clear) — 방향이 정반대인 clear라 이 쌍은 진짜 취향 영역. 쌍대+2심사자 체계가 "확실한 격차"와 "취향 차이"를 분리해 준다.
- 원시 데이터: `results\design-20260707-150338\` (pairwise.jsonl에 심사 사유 전문)

### 4라운드: Fable 기준 대조 (같은 날)

이 스킬의 존재 이유가 "Sonnet을 Fable처럼"이므로, 진짜 성적표는 공식 스킬과의 비교가 아니라 **Fable 산출물과의 거리**다. 실험 9 후속과 같은 패턴: Fable baseline으로 같은 브리프 3개를 생성해 REFERENCE로 놓고, 3라운드 Sonnet 산출물과 교차 쌍대 심사.

- 도구: [judge-pairs.ps1](judge-pairs.ps1) — 임의의 두 결과 폴더를 X/Y 익명 쌍대 심사하는 범용 스크립트 (쌍 명세: [fable-ref-pairs.json](fable-ref-pairs.json)).
- 쌍 구성: 브리프 3개 × { Fable baseline vs Sonnet+design-boost (스킬이 격차를 얼마나 좁혔나), Fable baseline vs Sonnet baseline (원래 격차 크기) } × 심사자 2명(Opus 4.8 + Fable) = 12판.
- 캐비앗: Fable이 생성자이자 심사자 — X/Y 블라인드지만 자기 스타일 인식 가능성이 있어 Opus 심사와의 일치율을 함께 본다. 더 엄격한 상한 비교는 Fable+frontend-design(실전 구성)인데, Fable baseline과 접전이면 그때 추가하는 게 경제적.

Fable baseline 생성 메트릭 (`results\design-20260707-165325\`):

| 브리프 | 턴 | 출력 토큰 | 비용(환산) | 모바일 오버플로 |
|---|---|---|---|---|
| tide-app | 4 | 23.8k | $2.36 | — |
| type-foundry | 2 | 14.1k | $1.15 | **O** |
| seller-dashboard | 2 | 9.9k | $0.86 | — |

**Fable조차 객관 오버플로 프로브에 1/3 걸렸다** — 프로브 기준이 그만큼 깐깐하다는 뜻이자, Sonnet+design-boost의 3/3 통과가 값지다는 뜻.

심사 결과 (12판, `results\crossjudge-*\pairwise.jsonl`):

| 과제 | 쌍 | Opus 4.8 판정 | Fable 판정 | 일치 |
|---|---|---|---|---|
| tide-app | Fable ref vs Sonnet+db | **db (clear)** | **db (clear)** | O |
| tide-app | Fable ref vs Sonnet base | ref (clear) | ref (clear) | O |
| type-foundry | Fable ref vs Sonnet+db | ref (slight) | ref (clear) | O |
| type-foundry | Fable ref vs Sonnet base | **base (slight)** | ref (clear) | **X** |
| seller-dashboard | Fable ref vs Sonnet+db | ref (clear) | ref (clear) | O |
| seller-dashboard | Fable ref vs Sonnet base | ref (clear) | ref (clear) | O |

합산: **Fable ref vs Sonnet baseline = 5:1 / Fable ref vs Sonnet+design-boost = 4:2** (심사자 일치 5/6).

관찰:

- **격차는 좁혀졌지만 Fable 우위는 유지.** 판수 1→2 승에, 승리의 질이 다르다: design-boost의 2승은 조석 앱에서 **심사자 만장일치 clear로 Fable을 꺾은 것**, baseline의 1승은 심사자가 갈린 slight 1개.
- **조석 앱 = 스킬 이식의 증명 사례.** Fable도 여기서 다크+애시드그린 근처 디폴트를 밟았고(심사평: "penalized dark-bg + acid-green-pill glow"), design-boost가 강제한 디폴트 회피 + 주제 그라운딩(웜 샌드 팔레트 + 해저 등고선 지도 + 모노스페이스 좌표)이 Fable 산출물을 이겼다. 규칙이 좋으면 브리프에 따라 Fable도 넘는다.
- **대시보드에서 Fable 완승의 이유가 다음 개선점이다.** Fable은 유틸리티 화면에도 주제 디테일(조석/날씨 출항 정보, 해녀 인사, 셀러 프로필)을 심었는데, design-boost 대시보드는 "competent but generic corporate-blue"(심사평) — treatment 판별이 "조용함"으로 기울며 주제성을 잃었다. → **utilitarian에도 subject grounding 의무를 명시하는 수정 반영됨** (quiet ≠ generic).
- **쌍대 심사의 상대성 확인**: 같은 Fable 조석 앱이 design-boost와 붙을 땐 "제네릭 다크 템플릿"으로 지고, Sonnet baseline과 붙을 땐 "생물발광 심해 미학, 진짜 주제 특정적"으로 이겼다 — 쌍대 판정은 절대 평가가 아니라 상대 평가다.
- **Fable 심사자의 약한 자기선호 신호**: Fable-judge는 자기 산출물을 5/6, Opus-judge는 4/6 선택. n이 작아 단정 불가, 방향만 기록.

### 5라운드: Opus 생성 (같은 날)

브리프 2개(tide-app 에디토리얼 + seller-dashboard 유틸리티, auto 제외 축소 구성) × 3-arm, 생성 `claude-opus-4-8`, 심사 동일(쌍대 × Opus 4.8 + Fable).

| arm | 승 (12판) | clear 승 | 모바일 오버플로 |
|---|---|---|---|
| frontend-design | 7 | 6 | 1 |
| design-boost | 3 | 3 | 0 |
| baseline | 2 | 2 | 0 |

심사자별 판정 (base=baseline, db=design-boost, fd=frontend-design):

| 과제 | 쌍 | Opus 4.8 판정 | Fable 판정 | 일치 |
|---|---|---|---|---|
| tide-app | base vs db | **db** (clear) | **base** (clear) | **X** |
| tide-app | base vs fd | **fd** (clear) | **base** (clear) | **X** |
| tide-app | db vs fd | fd (clear) | fd (clear) | O |
| seller-dashboard | base vs db | db (clear) | db (clear) | O |
| seller-dashboard | base vs fd | fd (clear) | fd (clear) | O |
| seller-dashboard | db vs fd | fd (slight) | fd (clear) | O |

생성 메트릭:

| 과제 | arm | 오버플로 | 턴 | 출력 토큰 | 비용(환산) |
|---|---|---|---|---|---|
| tide-app | baseline | — | 7 | 49.5k | $2.14 |
| tide-app | design-boost | — | 10 | 33.4k | $1.83 |
| tide-app | frontend-design | **O** | 13 | 26.6k | $1.42 |
| seller-dashboard | baseline | — | 2 | 10.0k | $0.41 |
| seller-dashboard | design-boost | — | 6 | 25.1k | $1.23 |
| seller-dashboard | frontend-design | — | 5 | 30.5k | $1.35 |

관찰:

- **Opus에서는 서열이 바뀐다: frontend-design 7 > design-boost 3 > baseline 2.** Sonnet 3라운드(db 8 ≈ fd 9 ≫ base 0)와 대조적. 코딩 벤치의 "스킬 효과는 모델의 낭비에 비례" 법칙의 디자인판 — Opus baseline은 이미 주제 특정적·데이터 풍부·모바일 재구성까지 해낸다 (심사평: "data-rich tide/swell interface … genuinely restructured 390px layout").
- **Opus + design-boost의 실패 모드는 Sonnet과 정반대.** Sonnet은 규칙이 소심함·디폴트를 고쳐줬지만, Opus는 규칙을 과잉 준수해 "분위기에 볼드니스를 몰빵한 콘텐츠 빈약 포스터"(심사평: "atmospheric light-ray poster, content-thin, mobile essentially the desktop shrunken")를 냈다. 시그니처/리스크 강제가 Opus의 자체 판단을 방해 — 실험 11(아키텍처 과제에서 boost가 Opus 문서 깊이를 깎음)과 같은 패턴.
- **유틸리티 경로 이득은 Opus에서도 성립**: 대시보드에서 design-boost가 baseline을 심사자 만장일치 clear로 이겼다. 단 frontend-design에는 패배 — Opus는 에세이형 가이드에서 더 좋은 판단을 스스로 뽑아낸다.
- **baseline의 2승은 전부 Fable 심사자 발** (tide-app 두 쌍 모두 불일치). Fable은 baseline의 데이터 밀도·모바일 재구성을, Opus 심사자는 스킬 arm의 개성을 높이 샀다. 일치율 67%로 하락 — Opus 산출물들은 품질이 붙어 있어 취향 영역이 넓다.
- 오버플로 1건(fd tide-app)은 Fable 심사자가 독립적으로 같은 결함("mobile text clipped at the left edge")을 지적 — 프로브와 심사의 교차 확인.
- 캡처 사고 1건: Opus design-boost tide 페이지의 무한 rAF 앰비언트 캔버스가 virtual-time 캡처를 행시킴 — 페이지가 `prefers-reduced-motion`을 준수한 덕분에(`if(!reduce)`) `--force-prefers-reduced-motion` 플래그로 수동 복구. 하네스 개선 후보: 캡처 실패 시 reduced-motion 폴백 재시도.
- 원시 데이터: `results\design-20260707-164159\`

**디자인 벤치 종합 결론 (1~5라운드)**: design-boost는 **Sonnet용 처방**이다 — Sonnet에서 공식 스킬과 동급(8:9) + 오버플로 0 + auto 발동 3/3 + Fable 격차 절반 축소(1:5→2:4). Opus에서는 baseline이 이미 강하고 에세이형 frontend-design이 더 낫다(7:3) — Opus에게는 규칙 강제보다 원칙 서술이 맞는다. 코딩(실험 1~8)에서 확립된 "스킬 = 모델별 처방"이 판단형 도메인에서도 재확인됐다.

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
