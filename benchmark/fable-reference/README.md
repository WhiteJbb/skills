# Fable 참조 산출물 아카이브

Fable(`claude-fable-5`)이 벤치마크에서 실제로 생성한 결과물을 **git으로 추적**해 나중에도 비교할 수 있게 보존한다. `benchmark/results/`의 작업 폴더는 `.gitignore`가 통째로 무시하므로(용량·재현성 이유), 비교 가치가 있는 Fable 산출물과 그 대조군만 여기에 큐레이션해 커밋한다.

각 폴더는 하나의 과제에 대한 **동일 브리프 비교 세트**다 — Fable 것만이 아니라 같은 과제를 푼 다른 모델 결과도 함께 둬야 "나중에 비교"가 성립하기 때문이다.

## 내용

### `arch-salon-scheduler/` — 아키텍처·판단 과제 (실험 11)
정답이 하나가 아닌 설계 과제(200개 미용실 체인 예약 시스템). 블라인드 페어와이즈 심사에서 **Fable이 8전 8승** (비편향 Opus 심사자 4/4). 자세한 분석은 [../README.md](../README.md) 실험 11.

| 파일 | 내용 |
|---|---|
| `fable-base.md` | **Fable의 설계 문서** (심사 전승; `FOR UPDATE`가 미삽입 행을 못 잠금 → GiST exclusion constraint가 진짜 serializer라는 진단 등 실패인지 추론의 깊이) |
| `opus-base.md` / `opus-boost.md` | Opus baseline / opus-boost 적용 (boost가 문서를 절반으로 축약 → 깊이 손실) |
| `sonnet-base.md` / `sonnet-boost.md` | Sonnet baseline / sonnet-boost 적용 (sonnet-boost 0승) |
| `pairwise-verdicts.jsonl` | 10페어 × 2심사자 = 20 판정 (승자·마진·근거 한 줄) |
| `gen-metrics.jsonl` | 후보별 생성 메트릭 (문자수·토큰·시간·비용) |

### `design-tide-app/` · `design-type-foundry/` · `design-seller-dashboard/` — 디자인 과제 (디자인 4라운드)

같은 브리프를 Fable baseline / Sonnet baseline / Sonnet+design-boost가 푼 비교 세트. 블라인드 쌍대 심사(Opus 4.8 + Fable) 합산: **Fable vs Sonnet baseline = 5:1, Fable vs Sonnet+design-boost = 4:2** — 스킬이 격차를 절반쯤 좁혔고, tide-app에서는 심사자 만장일치 clear로 Fable을 꺾었다(Fable이 다크+애시드그린 디폴트를 밟은 브리프). 분석은 [../README.md](../README.md) 디자인 4라운드.

| 파일 | 내용 |
|---|---|
| `fable-{index.html,desktop.png,mobile.png}` | **Fable baseline 산출물** (html은 재렌더 가능한 원본, png는 심사자가 본 실제 화면) |
| `sonnet-base-*` / `sonnet-design-boost-*` | 같은 브리프의 Sonnet 대조군 (3라운드 산출물) |
| `pairwise-verdicts.jsonl` | 이 과제의 교차 심사 판정 4건 (심사자·승자·마진·근거) |
| `gen-metrics.jsonl` | 세 후보의 생성 메트릭 (턴·토큰·비용·오버플로) |

재심사 예 (새 스킬 버전과 붙여보기): `.\judge-pairs.ps1 -PairsFile <새 쌍 명세>` — dir에 desktop.png/mobile.png만 있으면 됨.

### `algo-max-points/` — 알고리즘 추론 과제 (실험 8·10)
delete-and-earn ±2 변형(±1 습관이면 hidden 실패). 전 모델이 정답에 도달하나 **Fable이 최소 토큰(2,678)으로 가장 간결·우아하게** 해결.

| 파일 | 내용 |
|---|---|
| `fable-solution.py` | Fable의 해법 (26줄, O(n) 투포인터, gap≥3 정확 추론) |
| `fable-report.md` | Fable의 최종 보고 |

## 새 Fable 산출물 추가하는 법

새 벤치마크에서 Fable 결과를 보존하려면:

```bash
# 예: 어떤 과제의 Fable 답과 대조군을 아카이브
mkdir -p benchmark/fable-reference/<과제이름>
cp benchmark/results/<stamp>/<task>_fable*/{answer.md,solution.py,ANSWER.md} \
   benchmark/fable-reference/<과제이름>/   # 있는 것만
# 비교하려면 대조군(baseline/skill) 결과물도 같은 폴더에 함께 복사
git add benchmark/fable-reference/<과제이름>
```

이 폴더는 `results/`와 달리 `.gitignore` 대상이 아니므로 그대로 커밋된다.
