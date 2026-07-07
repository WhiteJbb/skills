# 미용실 체인 예약 시스템 설계 (200개 지점)

## 1. 데이터 모델

```
Salon(id, name, address, timezone)

Stylist(id, salon_id, name, active)

Skill(id, name)               -- cut, color, perm, ...
StylistSkill(stylist_id, skill_id)   -- N:N

Service(id, name, duration_min, skill_id, price)

WeeklyScheduleTemplate(
  stylist_id, weekday, start_time, end_time
)                              -- 반복되는 기본 근무시간

ScheduleException(
  stylist_id, date, type[OFF|EXTRA], start_time, end_time
)                              -- 휴가/특근 등 예외

Appointment(
  id, salon_id, stylist_id, customer_id,
  start_at, end_at,             -- 전체 블록의 시작/끝 (UTC)
  status[PENDING|CONFIRMED|CANCELLED|NO_SHOW|COMPLETED],
  created_at, deposit_charge_id NULL
)

AppointmentItem(
  id, appointment_id, service_id,
  seq,                         -- 시술 순서
  start_at, end_at             -- back-to-back 하위 구간
)

Customer(id, name, phone, email, no_show_count, no_show_rate_90d, deposit_on_file)
```

핵심 결정: **예약의 원자 단위는 Appointment 하나**이고, 내부에 여러 `AppointmentItem`(서비스별 하위 구간)을 갖는다. 가용성/충돌 검사는 항상 Appointment 레벨의 `[start_at, end_at)` 구간으로 하고, 화면 표시나 정산에만 AppointmentItem을 쓴다. 이렇게 하면 "커트+염색" 같은 멀티 서비스도 충돌 검사 로직이 단일 시술과 동일해진다.

## 2. 실시간 가용성 계산 (멀티 서비스 포함)

요청: 스타일리스트(또는 "이 스킬 가능한 아무나") + 서비스 리스트 `[cut(30m), color(90m)]` → 총 소요시간 `total = Σ duration = 120m`.

계산 절차 (지점 타임존 기준, 특정 날짜 범위):
1. `WeeklyScheduleTemplate` + `ScheduleException`으로 그 날의 근무 구간(`work_windows`) 생성.
2. 해당 스타일리스트의 기존 `Appointment`(CONFIRMED/PENDING) 구간을 근무 구간에서 빼서 **빈 슬롯(free intervals)** 목록 생성. 버퍼 타임(시술 후 정리시간, 예: 5분)을 각 예약 끝에 더해서 뺀다.
3. 요청한 `total` 길이가 들어갈 수 있는 free interval만 후보로 남기고, 15분(설정 가능) 그리드로 스냅한 시작 시각들을 후보 슬롯으로 제시.
4. 서비스가 서로 다른 스킬을 요구하면(예: cut은 A만, color는 B만 가능) → 한 명이 전체를 못 하면 이 조합은 "한 명 back-to-back" 불가로 처리하고, 프론트는 "다른 스타일리스트 필요" 또는 "가능한 스타일리스트만" 필터링해서 보여준다. (요구사항이 "한 명이 연속 수행"이므로 스킬 교집합이 없는 스타일리스트는 후보에서 제외)
5. 이 계산은 항상 **읽기 전용 미리보기**이며 최종 확정은 3번의 원자적 커밋에서 재검증한다 (조회 시점과 예약 시점 사이 경쟁 상태 존재하므로).

가용성 조회는 트래픽이 많으므로 최근 N일치 스타일리스트별 free-interval을 캐시(Redis)해두고, Appointment 생성/취소 시 해당 스타일리스트·날짜 캐시만 무효화한다.

## 3. 동시 요청에서 더블부킹 방지

여러 고객이 동일 슬롯을 동시에 예약 시도하는 문제 → **DB 레벨 제약으로 원자적으로 막는다**, 애플리케이션 레벨 락에 의존하지 않는다.

- PostgreSQL 사용 가정, `btree_gist` 확장 활성화.
- `Appointment`에 exclusion constraint:
```sql
ALTER TABLE appointment ADD CONSTRAINT no_overlap
EXCLUDE USING gist (
  stylist_id WITH =,
  tstzrange(start_at, end_at) WITH &&
) WHERE (status IN ('PENDING','CONFIRMED'));
```
- 예약 생성은 `INSERT` 한 번으로 시도하고, 겹치면 DB가 constraint violation을 던진다 → 애플리케이션은 이를 "이미 선점됨"으로 해석해 사용자에게 즉시 재조회를 안내(낙관적 실패, 재시도 루프 없음).
- PENDING 상태는 "결제/확정 대기" 짧은 창(예: 2분) 동안 슬롯을 홀드하는 용도. 이 상태도 exclusion에 포함되므로 두 고객이 동시에 PENDING을 만들 수 없다 — 하나만 성공.
- PENDING이 2분 내 CONFIRMED로 안 넘어가면 백그라운드 잡이 CANCELLED로 만들어 슬롯을 반납 (TTL 만료).

이 방식이 "먼저 SELECT로 빈 슬롯 확인 후 INSERT"보다 안전한 이유: SELECT-then-INSERT는 두 요청이 동시에 SELECT를 통과한 뒤 둘 다 INSERT할 수 있는 TOCTOU 경쟁 상태가 있다. Exclusion constraint는 DB가 트랜잭션 격리 수준과 무관하게 유일하게 하나만 커밋되도록 보장한다.

## 4. No-show 15% 대응 정책

정책 (단계적):
1. **예약 시 카드 등록(수단 저장) 필수** — 결제 자체는 안 하고 토큰만 저장.
2. **노쇼 이력 기반 차등 적용**: `no_show_rate_90d`가 임계치(예: 20%) 미만인 고객은 예약금 없이 그대로 진행. 임계치 이상이거나 신규 고객+고액 서비스(퍼머, 염색 등 90분 이상)인 경우 **소액 예약금(서비스 가격의 10~20%)** 선결제 요구, 노쇼 시 몰수, 방문 시 시술 금액에서 차감.
3. **자동 알림**: 예약 24시간 전 SMS/앱 알림 + 리마인더에 "취소/변경" 원터치 링크 제공 (취소 데드라인, 예: 4시간 전까지는 페널티 없음).
4. **오버부킹(선택적, 신중하게)**: 노쇼율이 높은 시간대(예: 저녁 6-8시, 월요일)에 한해 스타일리스트 전체 가용 시간의 최대 5~10% 초과 예약을 허용하는 별도 정책. 단, 이는 A안(예약금)이 자리잡을 때까지 임시 방편으로만 사용하고 기본은 끈다 — 리스크가 커서 4번에 별도 서술.
5. 노쇼 발생 시 `no_show_count` 증가, 취소/변경 기한 준수 시 카운트 제외.

**오버부킹이 초래하는 리스크** (그래서 기본값 OFF, opt-in):
- 예측(노쇼 확률)이 틀리면 실제로 손님 2명이 동시에 도착하는데 스타일리스트 1명 → 브랜드 신뢰도 손상, 그 손실이 예약금으로 막는 손실보다 클 수 있음.
- 노쇼 예측 모델이 지점/스타일리스트/요일별로 정교하지 않으면 특정 그룹(예: 특정 시간대 단골)에 불이익이 갈 수 있어 형평성 이슈.
- 예약금 몰수 정책은 고객 이탈(불만으로 다시 안 옴) 리스크가 있음 → 그래서 임계치 기반으로 "상습 노쇼 고객"에게만 적용하고 일반 고객에게는 부담을 주지 않도록 설계.

## 5. 핵심 트레이드오프

1. **가용성 계산을 캐시(근사) + 최종 커밋을 DB 제약(정확)으로 이원화**: 실시간 슬롯 조회마다 DB full scan/락을 걸면 200개 지점 트래픽에서 성능이 안 나옴. 대신 조회는 캐시된 근사치로 빠르게 보여주고, 실제 확정 순간에만 강한 일관성(exclusion constraint)을 요구. 트레이드오프: 아주 드물게 "방금 본 슬롯이 이미 사라짐"을 사용자가 겪을 수 있음 — 이는 즉시 재조회 UX로 대응.

2. **PENDING 홀드 + TTL 방식 vs. 완전 결제 후 확정**: 예약 확정에 결제를 강제하면 이탈률이 오르고, 아예 홀드 없이 바로 CONFIRMED로 가면 결제 실패 시 롤백이 복잡해짐. 짧은 TTL(2분) PENDING 상태로 슬롯을 잠깐 선점 후 결제/확인을 마무리하는 절충안을 택함 — TTL이 너무 길면 슬롯 낭비, 너무 짧으면 결제 UX 압박이라는 재조정 여지가 있음.

3. **오버부킹을 기본 비활성화, 예약금을 1차 방어선으로 채택**: 오버부킹은 노쇼 손실을 가장 직접적으로 상쇄하지만 이중 예약 리스크를 고객에게 전가한다. 예약금은 즉각적 매출 회복 효과는 작지만 브랜드 리스크가 없고 노쇼 억제 유인 자체를 만든다. "손실 회복 속도"보다 "신뢰 손상 방지"를 우선한 선택.