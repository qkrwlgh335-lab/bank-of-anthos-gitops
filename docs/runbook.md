# Phase 1 실행·검증 Runbook

## 최초 1회

1. AWS/GCP remote-state bucket을 생성합니다: `scripts/bootstrap-state.ps1`.
2. `terraform/aws-infra`를 init/plan/apply합니다.
3. 기존 RDS의 두 DB에 애플리케이션 계정을 만들고 Secrets Manager의
   `phase1/bank-app/runtime`, `phase1/bank-app/jwt`에 값을 등록합니다.
4. `terraform/gcp-cicd`를 기준으로 관리자가 GAR와 GitHub WIF를 한 번 부트스트랩합니다.
5. Terraform 출력으로 GitHub variables를 등록하고, 앱 저장소에는 GitOps 저장소 하나만
   선택한 단기 Fine-grained PAT를 `GITOPS_TOKEN` Actions secret으로 등록합니다.
6. 앱 저장소의 `Service CI and GitOps promotion`을 실행해 여섯 이미지를 양쪽 Registry에
   넣고 GitOps 태그를 `sha-<commit>`으로 변경합니다.
7. `terraform/aws-addons`를 apply합니다.
8. `scripts/bootstrap-argocd.ps1`로 Argo Application을 한 번 등록합니다.
9. `terraform/gcp-dr`과 `terraform/gcp-addons`를 적용하고 GCP Argo Application을 등록합니다.
10. DB가 없는 동안 GCP 업무 replicas 0과 `DR_DB_BOOTSTRAP_READY=false`를 유지합니다.

## GCP 플랫폼 사전 점검

`DR failover to GCP` workflow를 `platform-preflight`로 실행합니다. 이 모드는 DB가 없어도
GKE, Argo CD, External Secrets, GAR 이미지와 0 replicas를 검사하며 Cloud SQL 승격이나
노드 확장을 수행하지 않습니다.

DB를 다시 만든 뒤 `data-preflight`를 실행하고, 실제 장애 훈련에서만 두 Environment 승인과
확인 문자열을 갖춰 `failover`를 사용합니다.

## 정상 흐름 검증

```powershell
kubectl -n bank get pods,svc,ingress
kubectl -n argocd get application bank-of-anthos-dev
kubectl -n bank get externalsecret
aws ecr describe-images --repository-name bank-app/frontend --region ap-northeast-2
```

Ingress의 `ADDRESS`를 브라우저에서 열어 로그인 화면과 `/ready` 200 응답을 확인합니다.
기본 데모 로그인은 `testuser / bankofanthos`입니다.

## 독립 배포 검증

예를 들어 `src/frontend`만 수정하면 변경 감지 결과의 matrix에는 `frontend`만 들어갑니다.
CI는 그 이미지 하나만 새 SHA 태그로 ECR/GAR에 푸시하고 GitOps에서도 frontend 태그만
갱신합니다. Argo CD는 frontend Deployment만 롤링 업데이트합니다.

## 비용/삭제

이 실습에서 새로 비용이 큰 항목은 EKS control plane, EC2 노드 2대, NAT Gateway, ALB입니다.
완료 후 `scripts/destroy-lab.ps1`로 add-ons → AWS infra 순으로 삭제합니다. GAR/WIF는
GCP 관리자 부트스트랩 리소스이므로 별도 확인 후 삭제합니다.
기존 DMS PoC의 RDS, Cloud SQL, DMS는 이 Terraform state에 포함하지 않아 자동 삭제되지
않습니다.
