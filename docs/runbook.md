# Phase 1 실행·검증 Runbook

## 최초 1회

1. AWS/GCP remote-state bucket을 생성합니다: `scripts/bootstrap-state.ps1`.
2. GitHub의 `Terraform plan and apply`에서 `aws-infra`, `gcp-cicd`, `gcp-dr`를 차례로
   plan하고 `infrastructure-production` 승인 뒤 각 saved plan을 apply합니다.
3. `dr-data`를 plan/apply해 private RDS PostgreSQL 16, private Cloud SQL PostgreSQL 16,
   HA VPN과 DB Secret Manager container를 만듭니다.
4. `aws-addons`, `gcp-addons`를 plan/apply합니다.
5. Terraform 출력으로 GitHub variables를 등록하고, 앱 저장소에는 GitOps 저장소 하나만
   선택한 단기 Fine-grained PAT를 `GITOPS_TOKEN` Actions secret으로 등록합니다.
   승인형 DR이 GitOps 저장소에 activation/restore commit을 남기도록 GitOps 저장소의
   `gcp-dr-approval` Environment에도 push 권한이 있는 `GITOPS_TOKEN`을 등록합니다.
6. `Database DR bootstrap and CDC validation`을 `bootstrap-source` → `create-dms` →
   `validate-cdc` → `readiness` 순서로 실행합니다.
7. 앱 저장소의 `Service CI and GitOps promotion`을 실행해 여섯 이미지를 양쪽 Registry에
   넣고 GitOps 태그를 `sha-<commit>`으로 변경합니다.
8. `scripts/bootstrap-argocd.ps1`로 AWS Argo Application을 한 번 등록합니다.
9. GCP Argo Application을 등록하고 업무 replicas 0을 확인합니다.
10. 실제 CDC 검증이 완료되기 전에는 `DR_DB_BOOTSTRAP_READY=false`를 유지합니다.

## GCP 플랫폼 사전 점검

`DR failover to GCP` workflow를 `platform-preflight`로 실행합니다. 이 모드는 DB가 없어도
GKE, Argo CD, External Secrets, GAR 이미지와 0 replicas를 검사하며 Cloud SQL 승격이나
노드 확장을 수행하지 않습니다.

## DB·DNS 제외 승인형 GCP Drill

DB가 없는 상태에서 승인 절차와 GCP 플랫폼만 검증할 때 `platform-drill`을 사용합니다.

1. 검증할 공통 `sha-<40자 commit>` 태그와 Incident ID를 입력합니다.
2. confirmation에 `DRILL-GCP-NO-DB`를 정확히 입력합니다.
3. `gcp-dr-approval` reviewer가 승인합니다.
4. Workflow가 GKE 1→3노드, GitOps Probe activation, 여섯 GAR 이미지 pull/실행,
   업무 replicas 0을 검사합니다.
5. Workflow의 `always()` 복구 단계가 Probe를 0으로 만들고 노드를 원래 수로 되돌립니다.
6. 완료 후 `platform-preflight`와 `terraform gcp-dr plan`으로 원복을 재검증합니다.

이 모드는 Cloud SQL/DMS, 업무 Deployment, Ingress, DNS를 변경하지 않습니다. 따라서 앱 로그인,
조회, 송금 같은 기능 Smoke Test나 RPO/RTO는 증명하지 않습니다.

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
RDS, Cloud SQL과 VPN은 `dr-data` state에 포함되므로 비용 중단 시 함께 검토해야 합니다.
Google DMS migration job/connection profile은 workflow가 만들며 Terraform state 밖에 있으므로,
데이터 보존·승격 여부를 확인한 뒤 별도로 정리해야 합니다. State bucket은 인프라보다 먼저
삭제하지 않습니다. 전체 재실행 규칙은 `docs/reusable-cicd-iac.md`를 따릅니다.
