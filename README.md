# Claude Code Boost Skills

모델별 품질 하네스 스킬 + 효과를 실측하는 A/B 벤치마크.

모델마다 실패하는 방식이 다르다 — Sonnet은 장황한 시행착오, Haiku는 스펙 규칙 누락, Opus는 상대적으로 낭비가 적다. 각 스킬은 해당 모델의 실패 모드만 정확히 막는 최소 규칙 집합이다 (**스킬 = 모델별 처방**, 실측 근거는 아래 벤치마크 참고).

## 스킬

| 스킬 | 대상 | 핵심 아이디어 | 발동 시점 |
|---|---|---|---|
| `opus-boost` | Opus | 이해 → 계획 → 소단위 구현 → 적대적 리뷰 → 검증 규율. 게이트형 멀티에이전트: 계획 토너먼트(넓은 해법 공간), fresh-context 반박 검증(위험한 diff), loop-until-dry(감사형 과제), Explore 위임(광역 탐색) | 태스크 시작 |
| `sonnet-boost` | Sonnet, Haiku | 요구사항 계약서 · 사용 전 검증 · 하나 바꾸고 즉시 확인 · 완료 전 계약 재검사. 위험한 diff에는 스켑틱 1개 fresh-context 검증 | 태스크 시작 |
| `haiku-boost` | Haiku | 검증 우선: 구현 **전에** 스펙의 모든 규칙을 자체 assert로 변환, 가설 기반 수리, 같은 실패 3회면 패치 대신 재작성. 단일 에이전트 유지 | 태스크 시작 (객관 채점 가능한 과제) |
| `fresh-eyes-done-gate` | 전 모델 | done 선언 직전, 작업 컨텍스트가 전혀 없는 서브에이전트에게 요구사항 원문 + diff + 검증 목록**만** 주고 빠진 것/깨진 것을 찾게 하는 최종 게이트 | 태스크 종료 |

공통 설계 원칙:

- 규칙 본문은 압축 영어(토큰 절약), 사용자 응답은 한국어.
- 멀티에이전트 조항은 전부 **조건부 게이트** — 작은 태스크에서는 발동하지 않아 토큰 효율을 해치지 않는다.
- **fresh-context 원칙**: 검증자는 작성자의 추론·결론을 받지 않는다. 버그를 만든 컨텍스트는 그 버그를 보지 못하기 때문에, 자기 리뷰가 아니라 깨끗한 눈이 필요하다.

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
benchmark/             A/B 하네스 — run-benchmark.ps1, tasks.json, hidden/(숨김 테스트), results/
install.ps1            정션 설치 스크립트
```
