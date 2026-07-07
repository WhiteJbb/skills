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

> 아래 실험 1~6 + 후속의 데이터를 압축한 결론. **객관 채점(테스트 통과)이 가능한 소~중형 코딩 과제**에 한함 — 판단형·디자인·대형 코드베이스는 미검증. 대부분 셀당 n=1이라 방향성 위주로 읽을 것. 통과율(품질) 격차가 실제로 측정된 곳은 두 군데뿐(Haiku expr-eval, OSS `&<>`)이며 나머지는 효율(토큰·시간) 지표다.

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

**언제 켜고 끌까 (실측 처방):**
- Haiku로 어려운 스펙 구현 → **haiku-boost 켠다** (품질 반전, 유일하게 확실한 ON).
- Sonnet으로 긴 작업 → **sonnet-boost 켠다** (품질이 아니라 토큰·시간을 산다; 쉬운 과제엔 소액 순비용).
- Opus → 이득 온건. 규율·정직 보고가 목적이면 유지.
- 멀티에이전트 게이트 → baseline이 실수할 만한 환경(약한 모델·대형 코드베이스)에서만 값을 한다. v-next는 그 비용을 단일 프로브로 낮췄다.

세부 근거는 아래 실험 1~6 로그. 원시 데이터는 각 실험의 `results\<타임스탬프>\`.

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
