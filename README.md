# Claude Code Boost Skills

모델별 품질 하네스 스킬 + 효과를 실측하는 A/B 벤치마크.

모델마다 실패하는 방식이 다르다 — Sonnet은 장황한 시행착오, Haiku는 스펙 규칙 누락, Opus는 상대적으로 낭비가 적다. 각 스킬은 해당 모델의 실패 모드만 정확히 막는 최소 규칙 집합이다 (**스킬 = 모델별 처방**, 실측 근거는 아래 벤치마크 참고).

## 언제 뭘 켜나 — 실측 기반 빠른 처방

전 실험(1~12·후속)의 결론을 상황별로 압축한 표. 원칙: **스킬은 base 모델이 실제로 실패하거나 마감이 무너지는 구간에서만 값을 하고, 이미 잘하는 구간에선 순비용**이다. 도메인 스킬 판정은 Sonnet 기준 Fable 대조 블라인드 심사(실험 9·12), Opus는 요약·번역 외 미측정.

| 상황 | 처방 | 실측 근거 |
|---|---|---|
| Haiku로 어려운 스펙 구현 | **haiku-boost 켠다** | FAIL→PASS 품질 반전 — 유일하게 확실한 ON (실험 2) |
| Sonnet으로 긴 코딩 작업 | **sonnet-boost 켠다** | 같은 품질을 토큰 −66%, 2.9배 빠르게 (실험 1) |
| Opus 코딩 | 취향 — 이득 온건 | 토큰 −12%; 정직 보고·규율 목적이면 유지 (실험 3) |
| 비주얼 표면이 있는 작업 (전 모델) | **design-boost 켠다** | 블라인드 심사에서 baseline 전패(0/11) 유발, 모바일 오버플로 3/3 통과 유일 (디자인 1~3라운드) |
| 손이 많이 간 코딩의 완료 선언 직전 | **fresh-eyes-done-gate** | 저자·채점기가 둘 다 놓친 실버그를 fresh-context가 적발 (실험 6) |
| Sonnet 문서 요약 | **summary-boost 켠다** | 심사자 만장일치 clear 승 + 다이어트판은 baseline보다 싸다(29k→4.2k, −86%, 15/15 유지) (실험 9 후속·12 후속) |
| Opus 문서 요약 | 끈다 | Opus baseline이 이미 Fable-adjacent, 근소 역전 (실험 9 후속) |
| 코드 리뷰·감사 (Sonnet) | **code-review-boost 켠다** | 심사 2:0 승 — 커버리지·실행성 마감 우위 (실험 12) |
| 데이터 분석 (Sonnet) | **data-boost 켠다** | 심사 2:0 승 — 행수 결산·confounder 신중함 (실험 12) |
| 연구·분석 (Sonnet) | **research-boost 켠다** | 심사 2:0 승 (수정판; 실험 12) |
| 보고서·메모 | 동률 — 규율 목적일 때 | v3(ask+타임라인 조항) 기준 1:1 — 클레임 태깅·논지 계약을 강제하고 싶으면 켠다 (실험 12 후속) |
| 슬라이드·PPT | 동률 — 규율 목적일 때 | 수정판 기준 1:1; 스토리라인/헤드라인 테스트가 필요하면 켠다 (실험 12) |
| 일상 번역 | 끈다 | 동률 + 토큰 +52% (실험 9) |
| 오역 비용이 큰 번역 (계약·정책·법률) | **translate-boost 켠다** | baseline이 실제 의미 오역 1건 — 2패스 충실성 검증이 보험 (실험 9 후속) |
| 롤플레이·페르소나 | 단발은 무차이, 장기 세션이면 켠다 | 단발 심사 1:1; 자기사실 원장은 장기 일관성용 (실험 12) |
| 아키텍처·설계 판단 과제 | **전부 끈다** | 코딩식 규율이 깊이를 깎아 baseline보다 역효과 — Fable의 추론 깊이는 이식 불가 (실험 11) |
| 명시 스펙의 중형 코딩·문서 과제 전반 | 스킬 없이도 됨 | 현 모델 baseline이 천장 — 스킬은 마감·정직 보고를 살 뿐 (실험 5~9·12) |

자동 발동 주의 (실측 4/8, 실험 12 후속): **summary·translate·slides·data는 Sonnet이 스스로 부르지만, report·research·review·persona는 description을 강화해도 안 부른다** — 발동 판단은 문구 매칭이 아니라 모델의 자기확신에서 나오며, 자신 있는 산문·논증형 과제에선 도구를 집지 않는다. 이 4종은 요청에 스킬 이름을 명시하거나 /skill로 직접 호출할 것.

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

모두 **태스크 시작 시** 발동하며 **Opus·Sonnet** 대상이다 (Haiku는 규율 오버헤드가 커 제외). 자동 발동은 실측상 4/8만 신뢰 가능 — summary·translate·slides·data는 스스로 불리지만, report·research·review·persona는 명시 호출이 필요하다 (위 처방 표의 "자동 발동 주의" 참고).

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

> 1차 실측 (실험 9 — summary/translate × Sonnet 5/Opus 4.8): 요구사항 명시형 중형 과제에선 **두 모델 baseline이 천장**(전 셀 만점) — 기계 채점 격차 미검출, Sonnet엔 순비용(요약 5.6배·번역 +52%), Opus엔 소폭 절감(−4~−11%). 반복 측정으로 요약 스킬의 **밀도-폭 트레이드오프**를 발견해 "폭 우선" 예산 정책으로 수정(3연속 14/15 → 15/15 회복). 정직 상태 라인은 전 런에서 작동.
>
> **Fable 기준 대조 블라인드 심사 (실험 9 후속)**: Fable baseline 산출물을 REFERENCE로 놓고 심사자 2명(Opus·Fable)이 익명 쌍대 심사 — **요약 × Sonnet에서 심사자 만장일치 clear로 skill 승**(결론 우선 + 밀도 패킹이 Fable 방식과 일치; 판단형 과제에서 스킬 이식이 확인된 첫 사례). 요약 × Opus는 baseline이 이미 Fable-adjacent라 근소 역전, 번역은 두 모델 다 동률(갭 없음). 심사가 기계 채점의 사각지대(의미 오역 1건, 용어 드리프트 1건)도 적발 — 판단형 채점은 기계+심사 2층이 표준.
>
> **8도메인 전수 대조 + 개선 사이클 (실험 12, Sonnet 기준)**: 같은 방법론을 나머지 6종에 적용, 심사 사유를 진단으로 되먹임해 스킬 수정 → 재심사까지 완주. 이 라운드 전적: **skill 승 4 (summary clear·review·data·research) / 무 3 (translate·persona·slides) / 패 1 (report, slight)**, 심사 투표 11:5, clear 패배 0. 이 과정에서 전 도메인 공통 결함(상태 라인이 산출물 파일 안으로 누출 — research는 이 수정만으로 패→승 반전), slides의 문장형 제목 규칙 역효과(clear 패→무), data-boost 언어 규칙 결함을 발견·수정. Sonnet baseline은 심슨 함정·7버그 발견까지 천장이었고, skill의 우위는 정답성이 아니라 **Fable식 마감 품질**(결산·confounder 신중함·커버리지)에서 나온다.
>
> **후속 (실험 12 후속)**: report v3(ask+타임라인 조항)로 패→무 회복 — **최종 4승 4무 0패**. summary-boost는 "반복은 thinking에서" 조항으로 **29k→4.2k 토큰(−86%), 15/15 유지** (심사는 clear→1:1로 후퇴 — 2차 뉘앙스 1개와 맞교환, 채택). auto 발동은 4/8: 기계 제약형(summary·translate·slides·data)만 자동, 산문·논증형(report·research·review·persona)은 description 강화로도 안 불려 **명시 호출 필요**. 헤드룸 후보는 초장문·발견형·Haiku(미검증) — [benchmark/README.md](benchmark/README.md) 실험 9·9후속·12·12후속.

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
.\install.ps1                  # 전체 활성 스킬 13종 (기본)
.\install.ps1 -Profile sonnet  # Sonnet 주력 서브셋 — 실측 승 스킬만
```

`~\.claude\skills\` 아래에 이 저장소의 스킬 폴더를 가리키는 디렉토리 정션을 만든다 — **저장소 수정 = 즉시 배포**, 복사 단계 없음. 재실행해도 안전하고, 프로필을 바꿔 재실행하면 이 저장소 출신 정션 중 새 프로필에 없는 것은 자동 제거된다 (다른 스킬/폴더는 건드리지 않음).

`sonnet` 프로필은 위 처방표에서 Sonnet 실측 승이 있는 것만 담는다: `sonnet-boost` · `design-boost` · `summary-boost` · `code-review-boost` · `data-boost` · `research-boost`, 그리고 Haiku로 내릴 때를 위한 `haiku-boost`. 동률·규율 목적 스킬(report/slides/translate/persona)과 opus-boost, fresh-eyes-done-gate(sonnet-boost done-gate 프로브와 중복)는 제외 — 설치된 스킬의 description은 매 세션 컨텍스트에 상시 로드되므로, 안 부를 스킬을 깔아두는 것 자체가 토큰 비용이다.

## 벤치마크

스킬 적용 전후의 **통과율 · 토큰 · 비용 · 속도 · 턴 수**를 실제 Claude 호출로 측정한다. 사용법, 모드 설명(baseline/skill/auto), 결과 해석, 실측 데이터 전체는 [benchmark/README.md](benchmark/README.md) 참고.

```powershell
cd benchmark
.\run-benchmark.ps1                                            # sonnet-boost @ Sonnet 5
.\run-benchmark.ps1 -Model claude-opus-4-8 -Skill opus-boost   # opus-boost @ Opus 4.8
```

지금까지의 핵심 실측 (실험 1~12, 상세는 [benchmark/README.md](benchmark/README.md)):

- **규율 스킬의 효과는 모델의 낭비에 비례**: Sonnet 토큰 −66% / Opus −12% / Haiku 역효과 (원래 간결해서 교정할 낭비가 없음).
- **haiku-boost는 Haiku의 FAIL을 PASS로 뒤집음** — 고난도 과제에서 Sonnet 품질을 절반 비용에 (객관 채점 가능한 과제 한정). 통과율을 뒤집은 유일한 국면.
- **auto 발동**: Sonnet·Opus는 description만 보고 스스로 스킬을 부른다. Haiku는 부르지 않는다.
- **코딩 게이트 검증·재설계(실험 5~9)**: 멀티에이전트 게이트를 발동시키고(문언을 셀 수 있는 조건으로), spec→실행예시·단일 프로브로 재설계해 토큰 48~76%↓·점수 유지. 단 **현 모델은 Haiku 4.5까지도 객관 채점 코딩을 baseline으로 맞혀**, 스킬은 base가 실패하는 좁은 구간(약한 모델 규칙 누락·발견형 버그)에서만 값을 한다. 게이트가 실재 결함(OSS `&<>`)을 잡은 직접 증거는 확보했으나 baseline도 안 틀려 점수엔 안 드러남.
- **Fable 직접 비교(실험 8·10·11) — 프로젝트의 결론**: 객관 채점 코딩은 base가 이미 Fable급(전부 통과), 단 Fable이 최소 토큰으로 가장 간결하고 스킬은 오히려 장황해 *멀어진다*. **정답 없는 판단·아키텍처 과제(블라인드 심사)에선 Fable이 8전 8승, 스킬은 격차를 못 좁히고 오히려 역효과**(sonnet-boost 0승 — 간결 규율이 추론 깊이를 깎음). **Fable의 진짜 우위(효율·판단 깊이)는 규율로 이식되지 않는다.**
- **단, 규율·마감은 이식된다(실험 9·12) — 도메인 스킬의 존재 이유**: 8개 비코딩 도메인의 Fable 기준 블라인드 심사에서 도메인 스킬은 **4승 4무 0패**(Sonnet). 우위는 정답성이 아니라 Fable식 마감(결론 우선 구조·결산 라인·confounder 신중함·커버리지 완결)에서 나오고, 심사 사유를 되먹여 스킬 결함 3개(산출물 파일 안 메타 누출, 문장형 슬라이드 제목, 아티팩트 언어 규칙)를 수정·재검증했다. summary-boost는 다이어트로 baseline보다 싸졌다(−86%).
- **design-boost는 블라인드 쌍대 심사(심사자: Opus 4.8 + Fable, 일치율 88%)에서 baseline 전패(0/11)를 만들었고, Anthropic 공식 frontend-design 스킬과 동급** (직접 대결 3:3; 유틸리티 대시보드에서는 두 심사자 모두 design-boost 승). 객관 모바일 오버플로 판정 3/3 통과는 design-boost 유일, auto 발동 3/3 (2026-07-07, benchmark/README.md 디자인 3라운드).
- **Fable 기준 대조**: Sonnet baseline은 Fable에 1:5로 완패, design-boost 적용 시 2:4로 축소 — 그 2승은 조석 앱에서 **심사자 만장일치 clear로 Fable 산출물을 꺾은 것** (Fable도 디폴트를 밟은 브리프에서 스킬의 디폴트 차단이 통함). 남은 격차의 원인(유틸리티에서도 주제 디테일)은 스킬에 역반영 (디자인 4라운드).
- **Opus 생성에서는 디자인 서열 역전**: frontend-design 7 > design-boost 3 > baseline 2 (일치율 67%). Opus baseline은 이미 주제·데이터·모바일을 해내고, design-boost의 시그니처/리스크 강제가 오히려 "콘텐츠 빈약 분위기 포스터"를 유도 — 유틸리티(대시보드)에서만 baseline 대비 만장일치 승. **design-boost = Sonnet용 처방** 확정; Opus에는 에세이형(frontend-design)이 맞다 (디자인 5라운드).

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
                       디자인: run-design-benchmark.ps1(쌍대 심사·auto·오버플로 프로브),
                       judge-pairs.ps1(교차 심사), design-tasks*.json, fable-ref-pairs.json
                       판단/아키텍처: run-arch-benchmark.ps1(텍스트 블라인드 심사), arch-tasks.json
                       도메인: domain-tasks-*.json(8과제) + fixtures/(심슨 CSV 등),
                       judge-vs-reference.py(Fable 기준 쌍대 심사) + judge-cases-*.json + judgments.jsonl
                       fable-reference/ — Fable 참조 산출물 아카이브 (git 추적, results/와 달리 미무시)
install.ps1            정션 설치 스크립트 (-Profile all|sonnet; 실험 변형 제외)
```
