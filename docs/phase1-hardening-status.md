# Phase 1 CI/CD·DR 보완 상태

기준 시각: 2026-09-02 KST

## 판정 요약

| 항목 | 상태 | 검증 또는 잠금 기준 |
|---|---|---|
| GKE Pilot Light | 완료 | `phase1-bank-gke`, regional, pilot node 1대 Ready |
| GCP Argo CD / External Secrets | 완료 | Application `Synced / Healthy`, 두 ExternalSecret `Ready` |
| 업무 workload 대기 | 완료 | 6개 서비스와 Redis 모두 `replicas=0` |
| 승인형 DR workflow | 플랫폼 구현 완료 | platform/data/failover 3단계로 분리 |
| DB 전환 | 안전 잠금 | DB 삭제 상태이므로 `DR_DB_BOOTSTRAP_READY=false` 유지 |
| HIGH 취약점 차단 | 구현 완료 | Trivy `HIGH,CRITICAL`, `ignore-unfixed=true`, exit code 1 |
| Branch protection | 완료 | 두 저장소 main에 고정 required check 적용 |
| DNS 장애조치 | 미구현 | 설계 승인, 도메인, Cloudflare 권한을 받은 뒤 구현 |

## GCP Pilot Light 실제 구성

- 리전: `asia-northeast3`
- GKE: `phase1-bank-gke`
- 노드 풀: `pilot-light`, `e2-standard-2` 1대
- 노드: private, 제어 plane endpoint: public
- 네트워크: 전용 VPC/subnet, Pod/Service secondary range, Cloud NAT
- 상주 구성요소: Argo CD, External Secrets Operator
- Secret 원본: GCP Secret Manager의 `phase1-bank-app-runtime`, `phase1-bank-app-jwt`
- 업무 Deployment: 6개와 Redis 모두 0 replicas
- Ingress/NEG: 평시에는 만들지 않음. 승인형 failover가 replicas와 함께 활성화

DB가 삭제된 현재 Secret version은 연결 구조 검증용 placeholder다. External Secrets가 이를
읽는 것까지는 검증했지만 앱이 잘못된 DB로 기동하지 않도록 replicas 0과
`DR_DB_BOOTSTRAP_READY=false`를 함께 유지한다.

## DR workflow의 세 모드

1. `platform-preflight`: DB 없이 GKE, Argo CD, External Secrets, immutable GAR 이미지,
   업무 replicas 0을 검사한다.
2. `data-preflight`: 새 DB PoC 이후 `GCP_MIGRATION_JOB`, `GCP_CLOUD_SQL_INSTANCE`를 등록하고
   DMS `RUNNING / CDC`와 Cloud SQL read replica를 검사한다.
3. `failover`: immutable tag, `PROMOTE-GCP`, `ACCEPT-LAST-REPLICATED-DATA`,
   `DR_DB_BOOTSTRAP_READY=true`가 모두 있어야 `gcp-dr-approval` 승인 대기로 진입한다.
   승인 뒤 Cloud SQL 승격, GKE 3노드 확장, replicas/Ingress 활성화, Smoke Test 순으로 수행한다.
   그 뒤 `gcp-traffic-cutover` 두 번째 승인을 받는다.

DB를 다시 만들 때까지 다음 변수는 등록하지 않는다.

- `GCP_MIGRATION_JOB`
- `GCP_CLOUD_SQL_INSTANCE`

다음 검증을 모두 마친 뒤에만 `DR_DB_BOOTSTRAP_READY=true`로 바꾼다.

- DMS full dump와 CDC 정상
- accounts/ledger 스키마와 row count 확인
- 승격 후 필요한 PostgreSQL role/grant 확인
- Secret Manager에 실제 Cloud SQL URI, username, password, JWT 등록
- GKE에서 읽기 전용 접속 점검
- RPO 측정값 기록

## GitHub 보안 게이트

앱 저장소의 고정 필수 체크는 `CI required gate`다. 동적 서비스 matrix 중 하나라도 test,
build 또는 수정 가능한 HIGH/CRITICAL 스캔에 실패하면 이 체크가 실패해 승격이 중단된다.
OS 패키지는 보안 업데이트하고, Python builder의 `uv`는 최종 이미지에서 제거했으며,
Java는 distroless 런타임과 수정된 Netty/PostgreSQL JDBC 버전을 사용한다.

플랫폼 저장소의 고정 필수 체크는 `Terraform required gate`다. 다섯 root
(`aws-infra`, `aws-addons`, `gcp-cicd`, `gcp-dr`, `gcp-addons`)의 fmt/validate를 하나로
집계한다.

두 저장소 main branch protection의 현재 값:

- strict required status check: 활성
- PR 경로: 활성, 승인자 수 0
- force push / branch deletion: 금지
- 대화 해결 / linear history: 필수
- 관리자 강제: 비활성

관리자 강제를 끈 이유는 현재 collaborator가 저장소 소유자 한 명이고 app CI의 GitOps
자동 커밋도 그 단기 PAT를 사용하기 때문이다. 팀원을 추가하면 승인자 1명, 관리자 강제로
올리고 GitOps 승격은 GitHub App 또는 전용 bypass actor로 바꾼다.

## OIDC 최소권한 보완

DR 계정에 프로젝트 전체 `container.developer`를 추가하지 않는다. GKE 내부 Role/RoleBinding으로
`argocd`, `external-secrets`, `bank-dr` 네임스페이스의 필요한 조회와 Argo Application 갱신만
허용한다. 클러스터 resize는 기존 `container.clusterAdmin`, Kubernetes object는 namespace
RBAC라는 두 경계로 분리한다.

Terraform 계정에는 state object 접근용 기존 bucket `storage.objectAdmin`만 유지한다. 자기 IAM
binding을 refresh하려면 bucket IAM 관리자까지 필요해지는 순환 구조를 피하기 위해 해당 binding은
`gcp-dr` state 관리 대상에서 제거하되 실제 권한은 삭제하지 않는다.

## DNS 제안안 — 아직 구현하지 않음

가비아의 네임서버 네 개를 AWS 2개/GCP 2개로 섞지 않는다. 서로 독립적인 authoritative
DNS에 같은 zone을 임의로 나누면 응답이 일관되지 않고 failover 정책도 공유되지 않는다.

권장 흐름은 다음과 같다.

1. 가비아 registrar에서 Cloudflare가 할당한 authoritative nameserver만 등록한다.
2. 서비스 hostname을 Cloudflare proxy/load balancer가 받는다.
3. Primary origin은 AWS ALB이고 `/ready`를 health check한다.
4. AWS 장애 감지 시 자동 목적지는 GCP의 정적 장애 안내 페이지다.
5. DR workflow가 DB 승격, GKE 확장, 앱 Smoke Test를 끝낸다.
6. `gcp-traffic-cutover` 승인 뒤에만 실제 GCP Ingress/LB origin으로 전환한다.
7. 복구 때도 DB write 방향과 데이터 정합성 검토 뒤 수동 승인으로 AWS에 되돌린다.

구현 전에 필요한 사용자 승인/정보:

- 실제 도메인과 서비스 hostname
- Cloudflare 사용 및 zone 위임 승인
- Cloudflare 계정/API token 또는 연결 권한
- AWS ALB와 GCP 안내 페이지의 실제 endpoint
- health check 경로/간격과 장애 판정 횟수
- 자동 안내 페이지 전환 및 수동 서비스 전환 정책 승인

이 문서 작성 시점에는 가비아, Route 53, Cloud DNS, Cloudflare 레코드를 변경하지 않았다.
