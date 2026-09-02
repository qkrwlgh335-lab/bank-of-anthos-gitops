# 승인형 GCP DR 배포 설계

## 현재 시나리오와의 적합성

평시 `main` 파이프라인은 AWS EKS만 자동 배포합니다. 동일한 `sha-<commit>` 이미지를 GAR에도
항상 저장하지만 GCP workload replica는 0이므로 트래픽과 쓰기가 발생하지 않습니다. 이는
AWS Active, GCP Pilot Light, Cloud SQL CDC read-only 구조에 맞습니다.

AWS 전체 장애가 선언되면 `DR failover to GCP` workflow를 실행합니다.

1. `platform-preflight`는 DB 없이 GKE, Argo CD, External Secrets, GAR 이미지와 0 replicas를
   읽기 전용으로 검사합니다.
2. `platform-drill`은 `gcp-dr-approval` 승인을 실제 검증하되 DB/DNS를 제외합니다. GKE를
   1→3노드로 확장하고 전용 Probe가 여섯 GAR 이미지를 GKE에서 실행한 뒤 Probe 0과 1노드로
   자동 복구합니다. 업무 Deployment는 계속 0입니다.
3. `data-preflight`는 DB를 다시 만든 뒤 DMS `RUNNING / CDC`와 Cloud SQL read replica를
   별도로 검사합니다.
4. 내부 회의 결과에 따라 `gcp-dr-approval` GitHub Environment reviewer가 승인합니다.
5. 승인된 job만 DMS destination을 writer로 승격합니다. 이 단계는 되돌릴 수 없는 전환으로
   취급하며 입력값 `PROMOTE-GCP`와 `ACCEPT-LAST-REPLICATED-DATA`가 모두 일치해야 합니다.
6. GKE node pool을 1대에서 3대로 확장하고 GCP overlay의 태그·replica·Ingress를 갱신합니다.
7. GCP에 상주하는 Argo CD가 GAR 이미지로 여섯 Deployment를 reconcile합니다.
8. frontend rollout과 smoke test 후 두 번째 `gcp-traffic-cutover` 승인을 받습니다.
9. 권한 DNS 사업자가 정해지기 전까지 DNS 변경은 자동화하지 않습니다.

## 아직 인프라팀과 확정해야 할 계약

- 새 DMS migration job과 Cloud SQL instance 이름.
- 새 DB의 PostgreSQL role/grant와 실제 Secret Manager 값.
- `GCP_DR_SERVICE_ACCOUNT`에는 DMS promote, 대상 Cloud SQL 확인, 지정 GKE node pool resize,
  cluster credential 취득만 허용하는 custom role 적용.
- DMS는 PostgreSQL role/password를 복제하지 않으므로, 승격 직후 `accounts_app`와
  `ledger_app` role/grant 및 `phase1-bank-app-runtime` 값을 준비하는 자동화가 별도로 필요.
- DNS provider와 TTL, health check, 두 번째 traffic cutover 승인 주체.

AWS 전체 장애에서는 소스 RDS 연결이 끊겨 DMS 상태가 `RUNNING`이 아닐 수 있습니다. 정기
readiness 점검(`preflight`)은 반드시 `RUNNING / CDC`여야 하지만 실제 `failover`는 이미 CDC에
도달한 복제본이면 진행할 수 있습니다. 이때 마지막으로 GCP에 반영되지 못한 트랜잭션은
복구할 수 없으므로 회의에서 관측된 복제 지연과 데이터 유실 가능성을 승인 기록에 남겨야 합니다.

현재 값은 `DR_DB_BOOTSTRAP_READY=false`입니다. `true`가 설정되지 않으면 workflow는 승인
job보다 먼저 멈춥니다. 이는 DMS가
PostgreSQL 사용자와 비밀번호를 복제하지 않아 DB만 승격한 뒤 앱 Pod가 접속하지 못하는
반쪽짜리 전환을 방지하는 안전장치입니다. 평시 CI 실패와 DR 전환 실패를 섞지 않기 위해
일반 release workflow와 failover workflow를 완전히 분리했습니다.
