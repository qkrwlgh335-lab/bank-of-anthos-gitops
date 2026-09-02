# Phase 1 CI/CD·DR 보완 상태

기준 시각: 2026-09-03 KST

## 판정 요약

| 항목 | 상태 | 검증 또는 잠금 기준 |
|---|---|---|
| GKE Pilot Light | 완료 | `phase1-bank-gke`, regional, pilot node 1대 Ready |
| GCP Argo CD / External Secrets | 완료 | Application `Synced / Healthy`, 두 ExternalSecret `Ready` |
| 업무 workload 대기 | 완료 | 6개 서비스, Redis, Drill Probe 모두 `replicas=0` |
| 승인형 DR workflow | 플랫폼 실구동 완료 | 승인 후 1→3노드, 6이미지 Probe, 3→1노드 원복 검증 |
| DB 전환 | 안전 잠금 | DB 삭제 상태이므로 `DR_DB_BOOTSTRAP_READY=false` 유지 |
| HIGH 취약점 차단 | 구현 완료 | Trivy `HIGH,CRITICAL`, `ignore-unfixed=true`, exit code 1 |
| Branch protection | 완료 | 두 저장소 main에 고정 required check 적용 |
| DNS 장애조치 | 미구현 | 설계 승인, 도메인, Cloudflare 권한을 받은 뒤 구현 |

## 최종 실행 증거

- [공급망 고정 후 전체 6개 CI run 33658940803](https://github.com/qkrwlgh335-lab/bank-of-anthos-app/actions/runs/33658940803):
  여섯 서비스 test/build, HIGH/CRITICAL gate, ECR/GAR publish, `CI required gate`는 성공했다.
  기존 앱 저장소 `GITOPS_TOKEN` 인증 실패로 promotion checkout만 실패했으며 새 최소 권한
  credential 등록 전까지 CD 완료로 판정하지 않는다.
- [고정 Terraform 1.14.3 plan run 33658283575](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33658283575):
  여섯 root fmt/validate와 aws-infra plan 성공. EKS가 외부 삭제되어 복구 plan이 발생했으므로
  apply하지 않았다.
- [보호 PR required-gate run 33659560225](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33659560225):
  비-Terraform GitOps 변경에서도 `Terraform required gate`가 성공했고 PR #1만 main에 merge됐다.

- [최종 전체 6개 CI run 33596476481](https://github.com/qkrwlgh335-lab/bank-of-anthos-app/actions/runs/33596476481):
  최신 main에서 6개 test/build, HIGH/CRITICAL gate, ECR/GAR push, `CI required gate`,
  GitOps promotion 모두 성공
- 최신 CI 이미지 태그: `sha-074b9db2e20624f159595ce4308fcf285c4ea3a9`
- [승인형 DB-independent DR drill run 33595881758](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33595881758):
  `gcp-dr-approval` 승인, GKE 1→3노드 확장, 공통 SHA의 GAR 이미지 6개를 GKE에서 실제
  pull/실행, Argo CD reconcile, 업무 replicas 0 유지, Probe 0 및 GKE 3→1 자동 원복 성공
- Drill 검증 이미지 태그: `sha-a5a94e243a17b51161229d7be85787d6e8f472c5`
- [원복 후 platform-preflight run 33596478999](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33596478999):
  Argo CD `Synced / Healthy`, 업무·Probe replicas 0 재확인
- [최종 gcp-dr plan run 33596481364](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33596481364):
  다섯 Terraform root fmt/validate와 required gate 성공, `gcp-dr`는 `No changes`
- [전체 6개 CI run 33582768076](https://github.com/qkrwlgh335-lab/bank-of-anthos-app/actions/runs/33582768076):
  6개 test/build, HIGH/CRITICAL gate, ECR/GAR push, 고정 CI gate, GitOps promotion 성공
- 공통 이미지 태그: `sha-a5a94e243a17b51161229d7be85787d6e8f472c5`
- [GCP platform-preflight run 33583014975](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33583014975):
  DB 없이 GKE/Argo/External Secrets/0 replicas 성공
- [공통 SHA platform-preflight run 33583119645](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33583119645):
  위 상태와 GAR의 공통 태그 6개 존재를 함께 검증
- [gcp-dr OIDC plan run 33583017408](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33583017408):
  다섯 root 정적 검사, 고정 Terraform gate, gcp-dr plan 성공
- [gcp-addons OIDC plan run 33582013842](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33582013842): 성공

## GCP Pilot Light 실제 구성

- 리전: `asia-northeast3`
- GKE: `phase1-bank-gke`
- 노드 풀: `pilot-light`, `e2-standard-2` 1대
- 노드: private, 제어 plane endpoint: public
- 네트워크: 전용 VPC/subnet, Pod/Service secondary range, Cloud NAT
- 상주 구성요소: Argo CD, External Secrets Operator
- Secret 원본: GCP Secret Manager의 `phase1-bank-app-runtime`, `phase1-bank-app-jwt`
- 업무 Deployment: 6개와 Redis 모두 0 replicas
- DB-independent `dr-platform-probe`: 평시 0 replicas
- Ingress/NEG: 평시에는 만들지 않음. 승인형 failover가 replicas와 함께 활성화

DB가 삭제된 현재 Secret version은 연결 구조 검증용 placeholder다. External Secrets가 이를
읽는 것까지는 검증했지만 앱이 잘못된 DB로 기동하지 않도록 replicas 0과
`DR_DB_BOOTSTRAP_READY=false`를 함께 유지한다.

## DR workflow의 네 모드

1. `platform-preflight`: DB 없이 GKE, Argo CD, External Secrets, immutable GAR 이미지,
   업무 replicas 0을 검사한다.
2. `platform-drill`: `DRILL-GCP-NO-DB` 확인 문자열과 `gcp-dr-approval` 승인을 받은 뒤
   GKE를 1→3노드로 확장한다. 전용 Probe의 init container가 여섯 GAR 이미지를 실제 GKE에서
   실행하고, 업무 Deployment는 계속 0으로 유지한다. 성공·실패와 무관하게 Probe 0과 원래
   노드 수로 복구한다. Cloud SQL/DMS와 Ingress/DNS는 접근하지 않는다.
3. `data-preflight`: 새 DB PoC 이후 `GCP_MIGRATION_JOB`, `GCP_CLOUD_SQL_INSTANCE`를 등록하고
   DMS `RUNNING / CDC`와 Cloud SQL read replica를 검사한다.
4. `failover`: immutable tag, `PROMOTE-GCP`, `ACCEPT-LAST-REPLICATED-DATA`,
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

플랫폼 저장소의 고정 필수 체크는 `Terraform required gate`다. 여섯 root
(`aws-infra`, `aws-addons`, `gcp-cicd`, `gcp-dr`, `gcp-addons`, `dr-data`)의 fmt/validate를 하나로
집계한다.

두 저장소 main branch protection의 현재 값:

- strict required status check: 활성
- PR 경로: 활성, 승인자 수 0(자동 promotion/DR PR은 required check로 통제)
- force push / branch deletion: 금지
- 대화 해결 / linear history: 필수
- 관리자 강제: 활성

앱 promotion과 승인된 DR activation/restore도 main 직접 push 대신 branch/PR/auto-merge를
사용한다. 따라서 저장소 소유자도 required check를 우회할 수 없다. 인프라 PR의 사람 승인자
수를 1명으로 올리는 것은 실제 reviewer가 정해진 뒤 적용한다.

PoC의 승인 Job용 `GITOPS_TOKEN`은 저장소 전체가 아니라 `gcp-dr-approval` Environment
secret으로 제한했다. 장기 운영에서는 개인 OAuth/PAT 대신 GitHub App 또는 전용 bot의
Fine-grained PAT로 교체한다.

## OIDC 최소권한 보완

DR 계정에 프로젝트 전체 `container.developer`를 추가하지 않는다. GKE 내부 Role/RoleBinding으로
`argocd`, `external-secrets`, `bank-dr` 네임스페이스의 필요한 조회와 Argo Application 갱신만
허용한다. 클러스터 resize는 기존 `container.clusterAdmin`, Kubernetes object는 namespace
RBAC라는 두 경계로 분리한다.

Terraform 계정에는 state object 접근용 기존 bucket `storage.objectAdmin`만 유지한다. 자기 IAM
binding을 refresh하려면 bucket IAM 관리자까지 필요해지는 순환 구조를 피하기 위해 해당 binding은
`gcp-dr` state 관리 대상에서 제거하되 실제 권한은 삭제하지 않는다.

## 비차단 유지보수 항목

GitHub-hosted runner가 `actions/checkout@v4`, `setup-uv@v6`,
`configure-aws-credentials@v5`의 Node.js 20 런타임을 Node.js 24로 강제 실행한다는 deprecation
경고를 출력했다. 모든 Job은 성공했으므로 현재 장애는 아니지만, 각 Action의 Node.js 24 기반
새 major가 안정화되면 버전을 갱신한다.

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
