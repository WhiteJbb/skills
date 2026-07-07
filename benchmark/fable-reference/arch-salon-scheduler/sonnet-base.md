# 헤어살롱 체인 스케줄링 시스템 설계 (200개 지점)

## 1. 데이터 모델

```
Salon(id, name, address, timezone)

Stylist(id, salon_id, name)

Skill(id, name)                          -- cut, color, perm ...
StylistSkill(stylist_id, skill_id)       -- N:M

ServiceType(id, name, duration_min, skill_id, buffer_after_min)
  -- duration은 서비스 타입 고정값. buffer_after는 파마 방치시간 등 위생/세팅 텀

StylistSchedule(stylist_id, weekday, start_time, end_time, effective_from, effective_to)
  -- 주간 반복 근무표. 임시 변경은 별도 ScheduleException 테이블로 오버라이드

ScheduleException(stylist_id, date, type[OFF|CUSTOM], start_time, end_time)

Appointment(
  id, salon_id, stylist_id, customer_id,
  status[HOLD|CONFIRMED|CANCELLED|NO_SHOW|COMPLETED],
  start_at, end_at,               -- 계산된 전체 구간 (timestamptz)
  hold_expires_at,                -- HOLD 상태 TTL
  deposit_id NULL,
  created_at, version              -- 낙관적 잠금용
)

AppointmentItem(id, appointment_id, service_type_id, seq, start_at, end_at)
  -- 여러 시술을 순서/구간별로 분해해 저장 (연속 시술의 각 조각)

Deposit(id, customer_id, appointment_id, amount, status[HELD|CAPTURED|RELEASED|FORFEITED])

CustomerReliability(customer_id, no_show_count, completed_count, score, updated_at)
```

핵심 결정: **Appointment는 하나의 예약 단위**, **AppointmentItem은 시술 조각**으로 분리한다. 이렇게 하면 "커트+염색" 같은 결합 예약도 스타일리스트 캘린더에는 하나의 연속 블록으로 보이면서, 매출/시술별 통계는 item 단위로 낼 수 있다.

---

## 2. 실시간 가용성 계산 (멀티 서비스 포함)

**가용성 조회 알고리즘 (스타일리스트 × 날짜 단위):**

1. `StylistSchedule` + `ScheduleException`으로 근무 구간(work windows)을 구한다.
2. 해당 날짜의 `Appointment`(HOLD 포함, CANCELLED 제외)를 시간순으로 가져와 근무 구간에서 차감 → **빈 구간(free slots) 리스트**.
3. 예약 요청은 `[service_type_id, ...]` 배열로 들어온다. 각 서비스의 `duration + buffer`를 합산해 **필요 총 길이 L**을 계산한다. (단, 순서 최적화는 하지 않고 고객이 선택한 순서를 그대로 back-to-back 배치 — 순서 변경은 UX 복잡도 대비 이득이 작다고 판단)
4. **스타일리스트가 요청된 모든 서비스의 skill을 보유**하는지 먼저 필터링(스킬 없으면 후보 제외).
5. 각 free slot에 대해 `slot.length >= L`인 슬롯만 후보로 남기고, 시작 가능 시각을 15분 그리드로 스냅해 프론트에 노출한다 (그리드 단위는 살롱 설정값, 기본 15분).
6. 여러 스타일리스트 중 하나만 지정해도 되는 "누구나 가능" 예약의 경우, 각 스타일리스트에 대해 1~5를 병렬로 수행해 합집합을 반환.

멀티 서비스의 핵심 포인트: **개별 서비스 단위가 아니라 "합산된 연속 블록"으로 슬롯을 찾는다.** 커트(30분)+염색(90분)을 각각 빈 슬롯에 흩어 넣지 않고, 120분 연속 가용 구간에서만 예약을 허용한다. 이는 스타일리스트가 다른 손님과 동시에 여러 시술을 병행하지 않는다는 현실 제약을 반영한다.

가용성 조회는 **읽기 전용 캐시(Redis)** 에 스타일리스트별 "당일~2주" 슬롯 비트맵을 두고, 예약/취소 시 무효화(invalidate)한다. DB는 항상 최종 검증(source of truth)으로 사용하고, 캐시는 조회 성능용일 뿐 신뢰하지 않는다.

---

## 3. 동시 예약 방지 (더블부킹 방지)

같은 슬롯에 여러 고객이 동시에 클릭하는 상황을 3단계로 방어한다.

1. **DB 제약이 최종 방어선**: PostgreSQL 기준, 스타일리스트별 시간 구간에 **EXCLUDE 제약 (btree_gist, tsrange && 연산자)** 을 건다.

```sql
ALTER TABLE appointment ADD CONSTRAINT no_overlap
EXCLUDE USING gist (
  stylist_id WITH =,
  tsrange(start_at, end_at) WITH &&
) WHERE (status IN ('HOLD','CONFIRMED'));
```

  이 제약이 있으면 애플리케이션 로직이 실수해도 DB 레벨에서 물리적으로 겹치는 행 삽입이 불가능하다.

2. **예약 흐름은 2단계(HOLD → CONFIRM)**:
   - 고객이 슬롯을 선택하면 짧은 트랜잭션으로 `Appointment(status=HOLD, hold_expires_at=now+5min)` insert 시도.
   - EXCLUDE 제약 위반(unique_violation/exclusion_violation) 시 즉시 409 반환 → 프론트는 "방금 마감되었습니다"로 안내하고 슬롯 재조회.
   - HOLD 성공 시 고객은 5분 내 결제/확정 정보 입력 → `CONFIRMED`로 전환.
   - 만료된 HOLD는 백그라운드 잡이 주기적으로 CANCELLED 처리(또는 다음 조회 시 lazy 필터링으로 즉시 무시).
3. **동일 트랜잭션 내 insert만으로 충분**하며 별도 분산 락(Redis lock)은 불필요하다고 판단 — DB 제약이 원자성을 보장하므로 애플리케이션 레벨 락은 이중 방어이자 불필요한 지연 요인. 다만 인기 슬롯에 대한 요청 폭주(핫스팟) 시 DB 커넥션 낭비를 줄이기 위해, insert 전에 Redis에 `SETNX stylist:{id}:{start_at}` 로 짧은(1~2초) 선점 락을 걸어 "명백히 늦은" 요청을 사전에 걸러내는 최적화만 추가한다. 이 락은 최적화용이지 정합성의 근거가 아니다 — 정합성은 항상 DB 제약이 담당한다.

---

## 4. 노쇼(15%) 정책

노쇼는 완전히 없앨 수 없으므로, **예측 → 예방 → 손실 회수**의 3단계로 접근한다.

- **예방 (사전)**
  - 예약 확정 24h/2h 전 SMS/알림톡 자동 리마인더 + 원탭 취소 링크 (취소는 노쇼보다 훨씬 싸다 — 취소하면 슬롯을 즉시 재오픈해 다른 고객에게 판다).
  - `CustomerReliability.score`가 낮은 고객(과거 노쇼 이력) 또는 첫 예약 고객에게는 **예약 시 소액 보증금(Deposit)** 을 요구. 노쇼 시 몰수(FORFEITED), 노쇼 아니면 시술비에서 차감하거나 환불.
  - 보증금 비율/대상은 salon_id별 설정 가능(리스크 있는 시술군, 예: 장시간 시술일수록 보증금 비중 ↑).
- **손실 회수 (사후)**
  - 노쇼 발생 시 `status=NO_SHOW` 처리, `CustomerReliability` 갱신, 보증금 몰수.
  - 노쇼로 비게 된 시간은 **대기자 명단(waitlist)** 에 즉시 알림을 보내 재판매 시도 (당일 취소/노쇼 슬롯 전용 낮은 지연 알림 채널).
- **도입 리스크**
  - 보증금 요구는 **예약 이탈률(전환율 저하)** 을 유발할 수 있다 — 특히 신규 고객에게 결제 마찰이 부담. 따라서 첫 예약자 전원이 아니라 "노쇼 이력 있거나 고액 시술(예: 90분 이상)"에 한정해 점진 적용하고, 전환율을 A/B로 모니터링해 임계값을 조정한다.
  - 리마인더 SMS 남발은 스팸으로 인식되어 옵트아웃 증가 우려 — 채널/빈도는 고객이 설정 가능하게 한다.
  - 노쇼 이력 기반 페널티는 "단골인데 어쩌다 한 번 노쇼"와 "상습 노쇼"를 구분 못 하면 불공정 클레임 소지 — score는 최근 N개월 가중 이동평균으로 계산해 오래된 이력은 자연 감쇠시킨다.

---

## 5. 핵심 트레이드오프

1. **정합성을 DB 제약(EXCLUDE constraint)에 위임 vs. 애플리케이션 락 직접 구현**
   분산 락을 자체 구현하면 유연하지만 버그 표면이 커지고 다중 인스턴스/리전 환경에서 정합성 보장이 어렵다. RDBMS의 검증된 제약 기능에 최종 책임을 맡기고, 애플리케이션은 UX(빠른 실패 응답, 핫스팟 완화)에만 집중하는 쪽을 택했다 — 정합성 버그는 매출/신뢰 손실이 크므로 "지루하지만 검증된" 선택을 우선했다.

2. **가용성 캐시(Redis) 도입 vs. 매 조회마다 DB 직접 계산**
   200개 지점 × 다수 스타일리스트의 2주치 슬롯을 매번 계산하면 조회 지연이 커진다. 캐시를 두되 "쓰기 시 무효화 + 최종 확정은 항상 DB 재검증"을 원칙으로 해 **캐시 불일치가 실제 더블부킹으로 이어지지 않도록** 설계했다. 캐시는 속도 최적화일 뿐 신뢰 대상이 아니라는 경계를 명확히 한 것이 핵심.

3. **보증금을 전체 고객 대상 vs. 리스크 기반 선별 적용**
   전체 적용이 노쇼 억제 효과는 더 크지만 예약 전환율을 해친다. 신규/이력 나쁜 고객·고액 시술에만 선별 적용해 "노쇼 손실 감소"와 "예약 마찰 최소화" 사이에서 절충했다. 이는 매출 데이터로 검증 가능한 가설이므로 초기엔 보수적으로 좁게 시작해 데이터 기반으로 확대하는 전략을 택했다.