# 재사용 가능한 Phase 1 IaC·CI/CD 기준

## 재사용의 의미

이 저장소에서 “재사용 가능”은 다음 두 경우를 구분한다.

1. 같은 deployment를 반복 실행할 때는 **같은 remote state**를 사용한다. Terraform은 이미
   관리 중인 리소스를 다시 만들지 않고 차이만 반영하므로, 두 번째 정상 plan은 `No changes`
   로 수렴해야 한다.
2. 별도의 환경을 새로 만들 때는 `terraform/environments/phase1`을 복사해 새 deployment
   디렉터리를 만들고 backend key/prefix, 리소스 이름, CIDR을 모두 분리한다.

State를 삭제한 뒤 같은 이름으로 다시 apply하는 것은 재실행이 아니다. 특히 Cloud SQL,
service account, WIF pool/provider 및 전역 bucket 이름은 삭제 후 일정 시간 재사용이 제한될 수
있다. 따라서 state를 인프라보다 먼저 삭제하지 않는다.

## 결정적으로 고정한 항목

- Terraform CLI: `1.14.3` (`.terraform-version`과 Actions 모두 동일)
- Terraform provider: 각 root의 커밋된 `.terraform.lock.hcl`
- Terraform module/Helm chart: 코드의 정확한 버전
- EKS: Kubernetes `1.35`와 CoreDNS, kube-proxy, VPC CNI, Pod Identity add-on 버전
- GitHub Actions: release tag가 아닌 action commit SHA
- Java builder/runtime, Redis, PostgreSQL client: container digest
- 애플리케이션 artifact: `sha-<40자 commit>` immutable tag

GKE는 `REGULAR` release channel과 auto-upgrade를 의도적으로 사용한다. 따라서 클라우드가
보안 patch를 자동 적용할 수는 있지만, 반복 apply 때 Terraform이 별도 클러스터를 만들지는
않는다. GKE 버전을 고정해 관리형 보안 업데이트를 막는 대신, 업그레이드 후 plan을 정기적으로
검토하는 정책이다.

## 같은 환경의 적용 순서

1. `scripts/bootstrap-state.ps1`로 state bucket을 멱등 생성한다. 스크립트는 AWS account와
   GCP project를 먼저 검증한다.
2. `aws-infra`, `gcp-cicd`, `gcp-dr`를 각각 `plan`으로 검토하고 승인된 saved plan만 apply한다.
3. `dr-data`를 apply해 private RDS, private Cloud SQL, HA VPN, DB secret container를 만든다.
4. `aws-addons`, `gcp-addons`를 apply한다. 이 두 root는 각 cluster remote state에 의존한다.
5. `Database DR bootstrap and CDC validation`을 `bootstrap-source` → `create-dms` →
   `validate-cdc` → `readiness` 순서로 실행한다.
6. 앱 CI가 서비스별 test/build/Trivy를 통과한 동일 이미지를 ECR과 GAR에 저장하고 GitOps
   promotion PR을 만든다. 필수 check가 성공하면 auto-merge되어 desired state가 변경된다.
7. Argo CD가 AWS EKS desired state를 동기화한다. 실제 장애 선언 때만 `gcp-dr-approval`
   Environment 승인 뒤 GCP failover workflow를 실행한다.

Terraform workflow의 concurrency key는 deployment 단위다. 따라서 같은 `phase1`의
`aws-infra`와 `aws-addons` apply가 동시에 실행되어 remote-state 의존성이 깨지는 것을 막는다.

## 재실행 동작

| 작업 | 같은 입력으로 다시 실행했을 때 |
|---|---|
| Terraform plan/apply | 같은 state에서 create를 반복하지 않고 차이에 수렴 |
| 이미지 CI | ECR/GAR의 동일 SHA tag를 재사용하고 양쪽 digest 일치 검증 |
| DB bootstrap | 기존 앱/DMS password를 재사용하고 값이 다를 때만 secret version 추가 |
| DMS 생성 | job 상태를 읽고 `DRAFT`, `STOPPED`, `FAILED`, `RUNNING/CDC`별로 재개 |
| DR failover | 이미 승격된 Cloud SQL과 이미 활성화된 overlay를 감지하고 안전하게 재개 |

`terraform apply`는 workflow가 만든 saved plan을 `infrastructure-production` 승인 후 그대로
적용한다. 승인 뒤 새 plan을 다시 만들지 않으므로 리뷰한 내용과 실제 변경이 일치한다.

## 새 환경을 복제할 때 반드시 바꿀 값

- 모든 backend `key`/`prefix`
- AWS account ID와 GCP project ID safety lock
- S3/GCS bucket, ECR/GAR, IAM, service account, WIF, cluster, DB, VPN 리소스 이름
- AWS VPC/subnet, GKE subnet/pod/service/master, Cloud SQL private service CIDR
- dependent stack이 읽는 state bucket/key/prefix
- GitHub Environment variables와 OIDC subject의 repository owner/name/immutable ID

`terraform/environments/README.md`의 체크리스트를 완료하지 않은 deployment는 apply하지 않는다.

## 현재 외부 설정 의존성

코드만으로 만들 수 없거나 의도적으로 bootstrap 외부에 둔 항목은 다음과 같다.

- GitHub repository, Environment reviewer, branch protection, Actions variables/secrets
- 앱 저장소가 GitOps 저장소에 branch/PR을 만들 최소 권한 credential
- Google DMS migration job/connection profile(상태 기반 workflow가 관리)
- DNS failover(현재 범위 제외)

현재 `gcp-cicd`가 기존 GAR/WIF를 Terraform state로 가져오려면 Terraform service account에
`roles/artifactregistry.admin`과 `roles/iam.workloadIdentityPoolAdmin`이 추가로 필요하다.
권한이 적용되기 전에는 import plan이 성공하지 않으므로, 해당 변경은 별도 승인 대상으로 둔다.

앱 CI의 `GITOPS_TOKEN`은 만료되었거나 유효하지 않으면 이미지 publish까지 성공하고 GitOps
promotion만 실패한다. Fine-grained PAT를 쓸 경우 GitOps 저장소 하나에만 `Contents: Read and
write`, `Pull requests: Read and write`를 부여하고 만료일을 관리한다. 장기 운영에서는
GitHub App installation token으로 교체한다.

앱 promotion과 승인된 DR activation/restore도 main에 직접 push하지 않는다. 작업 branch와
PR을 만들고 required check를 통과한 뒤 auto-merge한다. 따라서 main branch rule의 관리자
강제를 켜도 자동화가 동작하며, 저장소 소유자의 실수로 check를 우회하는 경로를 제거할 수 있다.

## 검증 기준

- `terraform fmt -check -recursive`와 여섯 root의 `terraform validate` 성공
- 모든 YAML parse 성공, 모든 Python helper compile/test 성공
- PR에서 여섯 root의 speculative plan 성공
- apply 전 saved plan에 예상하지 않은 replace/destroy가 없음
- apply 직후 동일 commit으로 다시 plan했을 때 `No changes`
- 동일 앱 commit으로 CI를 두 번 실행했을 때 ECR/GAR digest가 동일
- DB가 있을 때 CDC INSERT/UPDATE/DELETE와 DMS `RUNNING/CDC` 증적 확보
- DR 훈련 뒤 Cloud SQL writer, GKE workload, smoke test, restore 결과와 RTO/RPO 기록

현재 로컬 정적 검증과 이미지 CI의 동일 SHA 재실행은 확인했다. 반면 Phase 1 EKS/RDS/Cloud
SQL이 없는 상태에서는 add-on, DB/DMS, 전체 failover의 실제 재검증을 완료할 수 없다. 리소스를
다시 만든 뒤 위 순서로 실행 결과를 추가해야 한다.
