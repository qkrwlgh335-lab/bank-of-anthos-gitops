# Phase 1 IaC 코드 정리

## 디렉터리와 적용 순서

```text
terraform/
├─ aws-infra/    AWS 기반 인프라와 CI IAM
├─ aws-addons/   EKS 내부 플랫폼 add-on
└─ gcp-cicd/     GAR와 GitHub WIF
```

최초 적용 순서는 `state bootstrap → aws-infra → runtime secret 값 준비 → gcp-cicd → 앱 CI
전체 빌드 → aws-addons → Argo Application bootstrap`이다. `aws-addons`는
`terraform_remote_state`로 `aws-infra` 출력과 EKS 인증정보를 읽으므로 순서를 바꾸면 안 된다.

## State

| Stack | Backend | Key/Prefix |
|---|---|---|
| `aws-infra` | S3 `phase1-cicd-tfstate-558807819624` | `aws-infra/terraform.tfstate` |
| `aws-addons` | 같은 S3 | `aws-addons/terraform.tfstate` |
| `gcp-cicd` | GCS `phase1-cicd-tfstate-kdt4-1-506106` | `gcp-cicd` |

S3 backend는 versioning, encryption, public access block과 native lockfile을 사용한다. GCS도
versioning을 켠다. state, plan, `.terraform/`, private key는 Git에서 제외하고 provider lock
file은 각 stack에 커밋한다.

## `aws-infra`

실제로 관리하는 범위:

- `ap-northeast-2a`, `2c`의 public/private subnet을 가진 신규 VPC
- Internet Gateway, 단일 NAT Gateway와 고정 EIP
- EKS `phase1-bank-eks`, managed node group 2대(`min=2`, `desired=2`, `max=4`)
- EKS core add-on과 Pod Identity agent
- 6개 immutable ECR repository와 최근 10개 보존 lifecycle
- GitHub app CI용 ECR push-only OIDC role
- GitHub Terraform용 OIDC role과 EKS access entry
- ALB Controller와 External Secrets용 IRSA role
- runtime/JWT Secrets Manager secret 컨테이너
- 기존 RDS security group에 NAT EIP `/32` PostgreSQL ingress

관리자 principal은 `cluster_admin_principal_arn`으로 고정한다. 이를 명시하지 않고
`enable_cluster_creator_admin_permissions=true`를 사용하면 로컬 사용자와 GitHub OIDC 중
누가 plan하느냐에 따라 EKS access entry와 KMS key policy가 달라진다. 현재 코드는 EKS
관리자 state 주소를 유지하면서 `kdn10`을 명시하고, KMS 관리자는 `kdn10`과 Terraform OIDC
role로 고정한다.

## `aws-addons`

- AWS Load Balancer Controller Helm release
- External Secrets Operator Helm release와 CRD
- Argo CD Helm release

세 add-on은 `aws-infra`의 cluster, VPC, IRSA 출력에 의존한다. Argo CD server는
`ClusterIP`이며 별도 외부 관리자 UI를 만들지 않았다. 앱은 bootstrap Application 이후
GitOps 저장소를 pull해 배포한다.

## `gcp-cicd`

- Artifact Registry Docker repository `bank-of-anthos`
- GitHub Actions Workload Identity Pool/Provider
- 앱 CI service account와 GAR writer 권한
- Artifact Registry/IAM/STS 관련 API 활성화

이 stack은 이미지의 DR 사전 적재만 담당한다. Cloud SQL/DMS/GKE/Cloud DNS는 포함하지 않는다.

## Terraform 밖에서 관리되는 현재 리소스

아래는 이 저장소에서 삭제하거나 재생성하지 않는다.

- DMS PoC에서 만든 RDS PostgreSQL
- GCP Cloud SQL PostgreSQL read replica와 Google DMS migration job
- DB schema, DB role/password, 초기 데모 데이터
- GitHub repository, Environment reviewer, Actions variables/secrets
- 아직 만들지 않은 GKE와 GCP-side Argo CD/External Secrets

따라서 `scripts/destroy-lab.ps1`은 DMS PoC DB를 함께 지우지 않는다.

## GitHub Actions의 IaC 제어

- PR: 세 stack 모두 `fmt -check`, `init -backend=false`, `validate`
- 수동 `plan`: `aws-infra` 또는 `aws-addons`, GitHub OIDC로 read/plan
- 수동 `apply`: `infrastructure-production` Environment 승인 뒤 새 plan 파일을 만들고 그
  파일만 apply
- 앱 CI와 Terraform workflow는 서로 다른 IAM role 사용

검증 실행:

- [최종 aws-infra plan run 33573683695](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33573683695):
  `0 add, 1 change, 0 destroy`
- [aws-addons plan run 33551933469](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33551933469): `No changes`

첫 aws-infra 실행에서 실행 주체 의존 access/KMS drift를 발견했고 코드에서 제거했다. 최종
plan에는 EKS access entry 교체와 destroy가 없다. 남은 1개 in-place 변경은 KMS 관리자
목록에 Terraform OIDC role을 명시적으로 추가하는 정책 변경이다. 이 변경은
`infrastructure-production` 승인 후에만 apply하며, 이 문서 작성 중에는 apply하지 않았다.

## 현재 PoC에서 의도적으로 단순화한 부분

- 단일 NAT Gateway: 비용은 낮지만 AZ 장애 내성은 없고 다른 AZ에서 cross-AZ 경로가 생긴다.
- EKS public endpoint: 실습 접근을 위한 값이며 운영에서는 허용 CIDR 또는 private endpoint를
  결정해야 한다.
- node group `max=4`: Karpenter/Cluster Autoscaler가 없어 Pod 부족만으로 자동 증설되지 않는다.
- Terraform OIDC role의 `AdministratorAccess`: 부트스트랩용이며 서비스별 최소 권한으로
  축소해야 한다.
- Secrets Manager 즉시 삭제와 ECR `force_delete`: 반복 실습용이며 운영 보존정책과 다르다.
- RDS는 기존 PoC 자산 연결: 최종 인프라팀 RDS module/state로 소유권을 옮겨야 한다.

## 다음 구현 우선순위

1. KMS 관리자 정책 1건의 in-place plan을 검토하고 승인 apply 여부 결정
2. branch protection과 CI required check 적용
3. Terraform role 최소 권한화
4. GKE Pilot Light stack을 별도 state로 추가
5. GCP DB bootstrap과 승인형 DR을 비운영 훈련으로 검증
6. RTO/RPO, DNS TTL, DMS lag, 승인 시간을 한 타임라인으로 계측
