# GitHub 설정

## 애플리케이션 저장소 변수

`qkrwlgh335-lab/bank-of-anthos-app`의 Actions variables에 다음을 둡니다.

| 이름 | 값 |
|---|---|
| `AWS_REGION` | `ap-northeast-2` |
| `AWS_CI_ROLE_ARN` | Terraform의 `github_app_ci_role_arn` 출력 |
| `ECR_PREFIX` | `bank-app` |
| `GCP_PROJECT_ID` | `kdt4-1-506106` |
| `GCP_REGION` | `asia-northeast3` |
| `GAR_REPOSITORY` | `bank-of-anthos` |
| `GCP_WIF_PROVIDER` | GCP Terraform의 `workload_identity_provider` 출력 |
| `GCP_SERVICE_ACCOUNT` | GCP Terraform의 `app_ci_service_account` 출력 |
| `GITOPS_REPOSITORY` | `qkrwlgh335-lab/bank-of-anthos-gitops` |

Secrets에는 `GITOPS_TOKEN` 하나만 둡니다. 실습에서는 만료 기간을 1~7일로 지정하고
`bank-of-anthos-gitops` 저장소 하나의 `Contents: Read and write`만 허용한 Fine-grained
PAT를 사용합니다. 이는 클라우드 자격 증명이 아니며 실습 후 폐기합니다. Public GitOps
저장소를 읽는 Argo CD에는 키가 필요 없습니다.

## 플랫폼 저장소 변수

| 이름 | 값 |
|---|---|
| `AWS_REGION` | `ap-northeast-2` |
| `AWS_TERRAFORM_ROLE_ARN` | Terraform의 `github_terraform_role_arn` 출력 |
`infrastructure-production` Environment를 만들고 apply 전에 reviewer 승인을 요구합니다.
PR은 AWS/GCP Terraform format/validate를 자동 수행합니다. 원격 plan/apply는 AWS 두 스택만
workflow dispatch로 실행합니다. GCP 인프라 관리자 역할은 GitHub에 부여하지 않고 최초
GAR/WIF 생성은 관리자가 수행합니다.

## 키를 저장하지 않는 이유

GitHub가 실행마다 짧은 수명의 OIDC 토큰을 발급하고 AWS STS/GCP WIF가 저장소 조건을
검증해 임시 권한을 발급합니다. 노출·회전해야 할 AWS access key와 GCP JSON key가 없습니다.
앱 역할에는 ECR push만 있고 EKS 권한은 없습니다.
