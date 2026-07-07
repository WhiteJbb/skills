# Claude Code Boost Skills

모델별 품질 하네스 스킬 + 효과를 실측하는 A/B 벤치마크.

모델마다 실패하는 방식이 다르다 — Sonnet은 장황한 시행착오, Haiku는 스펙 규칙 누락, Opus는 상대적으로 낭비가 적다. 각 스킬은 해당 모델의 실패 모드만 정확히 막는 최소 규칙 집합이다 (**스킬 = 모델별 처방**, 실측 근거는 아래 벤치마크 참고).

## 스킬

| 스킬 | 대상 | 핵심 아이디어 | 언제 쓰나 (건너뛸 때) |
|---|---|---|---|
| `opus-boost` | Opus | 이해 → 계획 → 소단위 구현 → 적대적 리뷰 → 검증 규율. 게이트형 멀티에이전트: 계획 토너먼트(넓은 해법 공간), fresh-context 반박 검증(위험한 diff), loop-until-dry(감사형 과제), Explore 위임(광역 탐색) | Opus로 **손이 여러 단계 가는 코딩**(구현·디버깅·리팩터·멀티파일) 시작 시. 한 줄짜리 수정·순수 Q&A는 건너뜀. Sonnet/Haiku면 `sonnet-boost` |
| `sonnet-boost` | Sonnet, Haiku | 요구사항 계약서 · 사용 전 검증 · 하나 바꾸고 즉시 확인 · 완료 전 계약 재검사. 위험한 diff에는 스켑틱 1개 fresh-context 검증 | Sonnet/Haiku로 **손이 여러 단계 가는 코딩** 시작 시. 한 줄짜리 수정·순수 Q&A는 건너뜀 |
| `haiku-boost` | Haiku | 검증 우선: 구현 **전에** 스펙의 모든 규칙을 자체 assert로 변환, 가설 기반 수리, 같은 실패 3회면 패치 대신 재작성. 단일 에이전트 유지 | Haiku로 **객관 채점 가능한(테스트로 확인되는) 어려운** 구현/버그픽스 시작 시. 간단한 과제·열린 설계는 건너뜀. **실측상 Haiku FAIL→PASS로 뒤집는 유일 조합** |
| `fresh-eyes-done-gate` | 전 모델 | done 선언 직전, 작업 컨텍스트가 전혀 없는 서브에이전트에게 요구사항 원문 + diff + 검증 목록**만** 주고 빠진 것/깨진 것을 찾게 하는 최종 게이트 | 손이 여러 단계 가는 코딩(구현·버그픽스·리팩터) **완료 선언 직전**, 전 모델. 한 줄짜리 수정·순수 Q&A는 건너뜀 |
| `design-boost` | 전 모델 (Fable 미만에서 가장 효과적) | 코드 작성 **전에** treatment 판별(유틸리티/에디토리얼)과 주제 기반 디자인 플랜(토큰·타이포·시그니처)을 강제하고, "AI 디폴트 룩" 체크리스트로 제네릭 디자인을 차단, 완료 전 비평 패스(스퀸트 테스트·결함 스캔). 수치 플로어(스케일 비율·행길이·대비·색 비중 60-70%·모션 마이크로스펙)와 차트 규칙이 담긴 DESIGN-SYSTEM.md 템플릿 동봉. 출처: Anthropic frontend-design/artifact-design/dataviz/pptx 스킬 증류 + OSS(MIT: Dammyjay93/interface-design, rohitg00/awesome-claude-design 등) 아이디어 재구성 | **비주얼 표면이 있는** 작업(웹페이지·랜딩·대시보드·아티팩트·컴포넌트·리디자인·슬라이드) 시작 시, 전 모델. 비주얼 없는 순수 로직 작업은 건너뜀 |

## 도메인 스킬 (Opus/Sonnet 튜닝)

Fable의 작업 방식 — **선(先)계약 → 근거 기반 검증(기억 금지) → 판단이 아닌 셀 수 있는 게이트 → fresh-eyes/누락 스윕 → 상태 라인으로 실측치 강제** — 를 8개 비코딩 도메인에 이식한 스킬군. Sonnet의 "게이트 합리화 우회"를 막기 위해 모든 게이트를 카운트 가능한 조건(K/N)으로 만들고, Opus의 "한 번 읽고 기억으로 쓰기"를 막기 위해 쓰는 시점 재조회(re-lookup at write time)를 강제한다.

모두 **태스크 시작 시** 발동하며 **Opus·Sonnet** 대상이다 (Haiku는 규율 오버헤드가 커 제외). description 트리거로 auto 모드에서 스스로 발동한다.

| 스킬 | 언제 쓰나 (건너뛸 때) | 핵심 게이트 (Fable 방식의 이식) |
|---|---|---|
| `summary-boost` | 문서·스레드·회의록·논문 **요약** 시작 시 (한 문단 입력은 건너뜀) | 클레임 인벤토리(분모 N) → 커버리지 K/N · 숫자/인용 쓰는 시점 재조회 · 누락 스윕(중간부·각주·반론·부정어) |
| `code-review-boost` | **코드 리뷰·감사·버그 찾기** 시작 시 (한 줄 diff는 건너뜀) | 콜사이트 선독 · 6개 결함 렌즈 각각 별도 패스 · 발견마다 트리거 입력으로 CONFIRMED/PLAUSIBLE 판정 · 2라운드 무발견까지 반복 |
| `report-boost` | **보고서·메모·제안서·장문** 작성 시작 시 (단답·순수 Q&A는 건너뜀) | 목차 전 한 문장 논지 계약 · 클레임 태깅(DATA/SOURCE/ASSUMPTION) · 논지에 기여 없는 섹션 컷 · 결론 우선 · fresh-context 논지 검증 |
| `slides-boost` | **PPT·덱·프레젠테이션** 시작 시 (1슬라이드 요청은 건너뜀; 비주얼은 `design-boost`와 병행) | 슬라이드 전 주장형 헤드라인 스토리라인 · 헤드라인만 읽어도 논증 성립(headline test) · 1슬라이드 1아이디어 · 고아 슬라이드 컷 |
| `research-boost` | **연구·분석·조사·비교** 시작 시 (단순 사실 조회는 건너뜀; 웹 수집은 `deep-research`로, 분석 규율은 이 스킬로) | 하위질문 분해(증거 우선) · 클레임 등급(O/S/I/A) · 반증 탐색 의무(steelman) · 인과 주장 전 경쟁 설명 2+ 배제 |
| `data-boost` | **데이터 분석·EDA·지표·데이터셋** 작업 시작 시 (손에 데이터 없는 질문은 건너뜀) | 분석 전 프로파일링 실행 · 모든 보고 숫자는 실행한 코드가 출력 · 조인/필터마다 행수 검증 · 패턴 주장은 계산으로 입증 · 전체 재실행 |
| `translate-boost` | **번역·현지화** 시작 시 (단어 하나 조회는 건너뜀) | 번역 전 문체+용어집 고정 · 자연성 패스(원문 없이)와 충실성 패스(원문 대조) 분리 · 세그먼트 N/N · 용어 일관성 K/K |
| `persona-boost` | **롤플레이·페르소나·캐릭터·전문가 시뮬** 시작 시 (일반 어시스턴트 Q&A는 건너뜀) | 첫 응답 전 역할 헌장(전문성 한계·구체적 보이스 스펙·지식 경계) · 자기사실 원장으로 모순 차단 · 응답마다 generic-voice 체크 |

> 주의: 도메인 스킬은 코딩 스킬(실험 1~8)만큼 A/B 실측을 거치지 않았다. 설계는 같은 Fable 방식(선계약·근거 검증·셀 수 있는 게이트·정직 신고)이지만, 효과 수치는 아직 미측정 — 벤치마크 하네스로 검증 가능(판단형 과제는 LLM 심사 필요).

공통 설계 원칙:

- 규칙 본문은 압축 영어(토큰 절약), 사용자 응답은 한국어.
- 멀티에이전트 조항은 전부 **조건부 게이트** — 작은 태스크에서는 발동하지 않아 토큰 효율을 해치지 않는다.
- **fresh-context 원칙**: 검증자는 작성자의 추론·결론을 받지 않는다. 버그를 만든 컨텍스트는 그 버그를 보지 못하기 때문에, 자기 리뷰가 아니라 깨끗한 눈이 필요하다.

## 실험 변형 (리포 보존, 미설치)

아래 3개는 벤치마크 실험용 변형으로 **`install.ps1`이 설치하지 않는다**(활성 `~\.claude\skills\`에 없음). 실측 결과 **순비용·무이득**으로 판명돼 비활성 상태로 리포에만 보존한다 — 재현·기록 목적. 자세한 근거는 [benchmark/README.md](benchmark/README.md)의 실험 6후속·7·8.

| 변형 | 실험 | 실측 판정 |
|---|---|---|
| `sonnet-boost-partition` | 실험 7 | 파티션 커버리지를 전 과제 강제 → 명시 스펙 과제에선 점수 불변·토큰 +30~88%. 스윕은 발견/audit 경로에만 값을 함(현행 sonnet-boost가 이미 그렇게 함) |
| `opus-boost-crosscheck` | 실험 8 | 독립 브루트포스 교차검증 강제 → Opus baseline이 이미 정확해 고칠 오류 0, 순 토큰비용 |
| `sonnet-boost-crosscheck` | 실험 8 | 동일 — Sonnet·Haiku baseline도 함정 과제를 맞혀 헤드룸 0 |

**핵심 교훈**: 현 모델(Haiku 4.5까지)은 객관 채점 가능한 코딩을 baseline으로 맞히므로, 스킬의 추가 기계는 그런 과제에선 순비용이다. 값을 하는 곳은 base 모델이 진짜 실패하는 좁은 구간뿐 — 약한 모델의 규칙 누락(실험 2), 실패가 의심 못 한 엣지/버그인 발견 과제(실험 6). 활성 스킬은 그 구간만 노린다.

## 설치

```powershell
.\install.ps1
```

`~\.claude\skills\` 아래에 이 저장소의 스킬 폴더를 가리키는 디렉토리 정션을 만든다 — **저장소 수정 = 즉시 배포**, 복사 단계 없음. 재실행해도 안전하다.

## 벤치마크

스킬 적용 전후의 **통과율 · 토큰 · 비용 · 속도 · 턴 수**를 실제 Claude 호출로 측정한다. 사용법, 모드 설명(baseline/skill/auto), 결과 해석, 실측 데이터 전체는 [benchmark/README.md](benchmark/README.md) 참고.

```powershell
cd benchmark
.\run-benchmark.ps1                                            # sonnet-boost @ Sonnet 5
.\run-benchmark.ps1 -Model claude-opus-4-8 -Skill opus-boost   # opus-boost @ Opus 4.8
```

지금까지의 핵심 실측 (2026-07-06):

- **규율 스킬의 효과는 모델의 낭비에 비례**: Sonnet +190% 효율 / Opus +12% / Haiku 역효과 (원래 간결해서 교정할 낭비가 없음).
- **haiku-boost는 Haiku의 FAIL을 PASS로 뒤집음** — 고난도 과제에서 Sonnet 품질을 절반 비용에 (객관 채점 가능한 과제 한정).
- **auto 발동**: Sonnet·Opus는 description만 보고 스스로 스킬을 부른다. Haiku는 부르지 않는다.

## 저장소 구조

```
opus-boost/            SKILL.md — Opus용 하네스
sonnet-boost/          SKILL.md — Sonnet/Haiku용 하네스
haiku-boost/           SKILL.md — Haiku용 검증 우선 하네스
fresh-eyes-done-gate/  SKILL.md — 모델 공통 최종 게이트
design-boost/          SKILL.md + DESIGN-SYSTEM.md — Fable급 디자인 하네스 + 토큰/수치 템플릿
summary-boost/ code-review-boost/ report-boost/ slides-boost/
research-boost/ data-boost/ translate-boost/ persona-boost/
                       SKILL.md — Opus/Sonnet용 도메인 하네스 8종 (위 표 참고)
sonnet-boost-partition/ opus-boost-crosscheck/ sonnet-boost-crosscheck/
                       SKILL.md — 실험 변형 (미설치, 순비용 판정 — 위 "실험 변형" 절 참고)
benchmark/             A/B 하네스 — run-benchmark.ps1, tasks.json, gate-tasks*.json,
                       oss-tasks.json, algo-reasoning-task.json, hidden/(숨김 테스트), results/
install.ps1            정션 설치 스크립트 (활성 스킬만; 실험 변형 제외)
```
