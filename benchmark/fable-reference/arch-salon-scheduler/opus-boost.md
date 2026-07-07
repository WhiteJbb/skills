# 200개 지점 헤어살롱 예약 시스템 설계

## 전제(명시적 결정)

- **DB: 단일 리전 PostgreSQL(지점 샤딩 아님)** + 읽기 복제본. 예약 정합성이 규모보다 우선하므로 강한 일관성을 주는 단일 primary를 선택. 200지점 · 스타일리스트 수천 명 규모는 단일 Postgres로 충분(피크에도 초당 수백 예약 미만).
- 예약 시간 격자(granularity): **15분**. 모든 서비스 duration은 15분 배수로 정규화.

---

## 1. 데이터 모델

```
salon(id, name, tz, ...)                         -- 지점별 타임존 보관(필수)
stylist(id, salon_id, name, active)
skill(id, code)                                  -- cut, color, perm ...
stylist_skill(stylist_id, skill_id)              -- N:M, 보유 스킬
service(id, salon_id, name, skill_id, duration_min, price, deposit_pct)

-- 주간 반복 근무표
work_shift(id, stylist_id, weekday, start_time, end_time)   -- 요일별 근무 블록
-- 예외(휴가/교육/땜질 오픈): 특정 날짜 override
schedule_exception(id, stylist_id, date, start_time, end_time, type)  -- type: off | extra

-- 예약(한 스타일리스트가 연속 수행하는 1건)
appointment(
  id, salon_id, stylist_id, customer_id,
  time_range tstzrange,          -- [시작, 끝) UTC, 아래 핵심
  status,                        -- held | booked | done | no_show | canceled
  deposit_state,                 -- none | authorized | captured | refunded
  created_at
)
appointment_item(appointment_id, service_id, seq, duration_min)  -- 다중 서비스 순서/구성
```

핵심 결정: 예약의 시간을 **`tstzrange` 단일 컬럼**으로 저장(start+duration 분리 저장 아님). 겹침 방지 제약을 이 컬럼 하나로 걸기 위함(§3). 지점 로컬 타임이 아니라 **UTC로 저장**하고 표시할 때만 `salon.tz`로 변환 — DST 경계 버그 차단.

---

## 2. 실시간 가용성 계산 (다중 서비스 포함)

요청: `(stylist 후보들, 서비스 목록, 날짜, 지점)`.

1. **스킬 필터**: 요청 서비스들의 `skill_id` 집합 ⊆ 스타일리스트 `stylist_skill`. 불충족 스타일리스트 제거.
2. **필요 길이**: `need = Σ appointment_item.duration_min` (연속 수행이므로 단순 합).
3. **근무 가능 구간** 구성: 해당 요일 `work_shift` ∪ `schedule_exception(extra)` − `schedule_exception(off)`.
4. **바쁜 구간**: 그 날의 기존 `appointment.time_range`(status ∈ held/booked).
5. **free = 근무구간 − 바쁜구간**을 병합 정렬해 얻은 각 빈 블록에서, 15분 격자로 시작점을 슬라이딩하며 **길이 ≥ need인 연속 시작점**만 후보 슬롯으로 반환.

다중 서비스는 별도 로직이 아니라 "**need = 합계짜리 단일 블록 탐색**"으로 자연스럽게 처리됨(back-to-back 보장). 서비스 사이 청소/세팅 버퍼가 필요하면 `service.buffer_min`을 합에 포함.

**성능**: 실시간성을 위해 온디맨드 계산 + 스타일리스트·날짜 단위 **캐시(Redis)**. 캐시는 해당 스타일리스트에 예약 write가 커밋될 때만 무효화 — 자주 바뀌지 않으므로 적중률 높음. (사전 물질화 테이블은 근무표/서비스 변경 시 광범위 재계산이 필요해 신선도가 떨어져 배제.)

---

## 3. 동시 예약 이중부킹 방지

**PostgreSQL exclusion constraint**로 DB가 원자적으로 강제:

```sql
CREATE EXTENSION btree_gist;
ALTER TABLE appointment
  ADD CONSTRAINT no_overlap
  EXCLUDE USING gist (
    stylist_id WITH =,
    time_range WITH &&
  ) WHERE (status IN ('held','booked'));
```

같은 스타일리스트의 겹치는 구간 INSERT는 **두 번째가 반드시 실패**. 동일 순간 다중 요청도 트랜잭션 커밋 시점에 DB가 직렬화하여 정확히 하나만 성공 → 애플리케이션 레벨 락 불필요, 분산 락도 불필요.

**흐름**: `INSERT ... status='held'`(단기 TTL, 예: 5분) → 결제/디포짓 승인 → `UPDATE status='booked'`. 제약 위반은 `SQLSTATE 23P01`로 잡아 "방금 마감됨" 재조회로 전환. held 만료분은 백그라운드 잡이 정리.

이것을 선택한 이유: 낙관적 버전 컬럼이나 `SELECT FOR UPDATE`는 "겹침"이라는 **범위 조건**을 앱 코드가 직접 판정해야 해 경계 버그 여지가 큼. 겹침 판정을 DB 제약에 위임하면 경합 정확성이 코드가 아니라 스키마로 보장됨.

---

## 4. 노쇼 15% 정책

**계층형(강제성 낮은 것부터):**

1. **리마인더**: 24h/2h 전 SMS·카카오 — 실측 노쇼를 가장 싸게 낮춤. 여기서 취소되면 슬롯 즉시 회수.
2. **디포짓/카드 온파일**: 고가·장시간 서비스(color/perm 등 `deposit_pct>0`)에 한해 예약 시 부분 선결제 또는 카드 사전승인. 노쇼 시 캡처. 저가 cut은 마찰 회피 위해 면제.
3. **대기자 리스트**: held 만료·취소 슬롯을 대기 고객에게 자동 알림 → 빈자리 실시간 재판매.
4. **취소 창(policy window)**: 예약 24h 전 무료 취소, 이후 디포짓 비환불.

**오버부킹은 채택하지 않음**: 항공권과 달리 1인 스타일리스트는 대체 공급이 불가능 — 둘 다 나타나면 반드시 한 명을 돌려보내 신뢰가 붕괴. 대신 **대기자 재판매**로 좌석을 메움(위험 없는 대안).

**정책이 유발하는 리스크:**
- 디포짓 → **예약 전환율 하락**, 결제 실패/차지백, 환불 분쟁. 완화: 서비스별 선택 적용 + 명확한 취소 고지.
- 카드 사전승인 만료(보통 7일) → 장기 선예약은 캡처 실패. 완화: 방문 임박 시 재승인.
- 대기자 자동배정 → 늦게 응답한 대기자와의 충돌. 완화: 대기 알림에도 §3의 held TTL 동일 적용.

---

## 5. 핵심 트레이드오프 3가지

1. **정합성 > 확장성 (단일 Postgres + exclusion constraint).** 200지점은 분산이 필요할 만큼 크지 않고, 이중부킹은 즉시 고객 신뢰를 깨므로 강한 일관성을 주는 단일 primary를 택함. 향후 확장은 정합성이 지점 내부에서만 필요하다는 점을 이용해 **지점 단위 샤딩**으로 무중단 확장 가능(제약이 지점을 넘지 않음).
2. **온디맨드 계산+캐시 > 사전 물질화.** 근무표·서비스·예약이 수시로 바뀌는 환경에서 물질화는 신선도 관리 비용이 큼. write 시 무효화되는 캐시로 신선도와 성능을 동시 확보.
3. **대기자 재판매 > 오버부킹.** 노쇼 손실을 "좌석을 못 채워서"가 아니라 "빈자리를 못 되판다"로 재정의. 1인 공급 제약 하에서 고객을 돌려보내는 위험 없이 손실을 회수하는 유일한 안전한 방법.

---

작업: 5개 요구항목(데이터모델·가용성·동시성·노쇼·트레이드오프) 설계를 마크다운으로 작성.
검증: exclusion constraint 문법(`btree_gist` + `EXCLUDE ... WITH &&`)은 Postgres 표준 기능으로 확인된 구성이며, 다중서비스=합계길이 단일블록 탐색 로직을 손으로 트레이스함.
불확실: 카드 사전승인 만료일(7일)은 PG사별 상이 — 실제 연동 PG 정책 확인 필요.

rules proven: n/a (설계 산출물) | probe: not needed