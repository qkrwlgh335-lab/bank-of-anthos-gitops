# Phase 1 CI/CD 구현 및 실구동 검증

## 판정

2026-09-02 KST 기준 AWS Active 경로의 CI/CD는 실제로 정상 동작했다.

`app main 변경 → 선택 서비스 test/build/Trivy → ECR/GAR 동일 이미지 push → GitOps tag
변경 → Argo CD 자동 reconcile → EKS 롤링 배포 → ALB 사용자 요청`을 끝까지 확인했다.

GCP 승인형 DR은 이 완료 판정에 포함하지 않는다. GAR 사전 적재와 승인 workflow는 있지만
GKE, GCP-side Argo CD/External Secrets, DR 권한과 DB bootstrap이 아직 준비되지 않아 실제
failover를 실행하지 않았다.

## 구성과 책임 경계

| 구간 | 실제 담당 | 하는 일 | 하지 않는 일 |
|---|---|---|---|
| CI | GitHub Actions | 변경 감지, test, image build, Trivy, ECR/GAR push | EKS/GKE 직접 변경 |
| Release | app CI + GitOps repo | 성공 서비스의 immutable tag 변경 | 컨테이너 직접 재시작 |
| CD | Argo CD | Git desired state를 EKS에 reconcile | 이미지 build |
| Runtime | EKS | 6 Deployment, Service, Redis, Pod 재시작/스케줄링 | CI 정책 결정 |
| Infra | Terraform | VPC, EKS, IAM, ECR, add-on, GCP CI 기반 | 앱 release tag 변경 |

## 실제 실행 증거

### 1. 전체 빌드와 양쪽 Registry 적재

- [app run 33549580465](https://github.com/qkrwlgh335-lab/bank-of-anthos-app/actions/runs/33549580465): 성공
- 6개 서비스 test/build/Trivy/ECR/GAR: 성공
- GitOps promotion: 성공
- 이미지 태그: `sha-5a4825edf92152fd081f93c89cba5845bde72b9b`
- 각 서비스의 ECR digest와 GAR digest 일치 확인

### 2. 서비스별 독립 배포

- [app run 33551155972](https://github.com/qkrwlgh335-lab/bank-of-anthos-app/actions/runs/33551155972): 성공
- 실행 서비스: `frontend`, `userservice`, `contacts`
- 미실행 서비스: `balancereader`, `ledgerwriter`, `transactionhistory`
- 새 태그: `sha-0c42a52d25a7e2f572f8f6078055fa79fa2e5c98`
- GitOps commit `f607cf2`: 위 Python 3개 태그만 변경
- GitOps commit `aad0f16`: 추적 설정 보정 후 Argo CD 자동 동기화

### 3. EKS와 사용자 경로

- Argo Application `bank-of-anthos-dev`: `Synced / Healthy`
- 적용 revision: `aad0f16ed44d4e4b3875826c711d29a8afcb1b27`
- 6개 앱 Deployment와 Redis: 모두 `1/1 Ready`
- ALB `/ready`: 응답 본문 `ok`, HTTP 200
- ALB `/`: HTTP 200
- 데모 로그인: `testuser`로 로그인 후 `/home`, HTTP 200

ALB 주소는 임시 실습 리소스이므로 고정 문서 주소나 운영 DNS로 간주하지 않는다.

## 검증 중 발견하고 수정한 문제

| 문제 | 원인 | 수정 및 재검증 |
|---|---|---|
| Trivy action을 찾지 못함 | 존재하지 않는 action tag | `aquasecurity/trivy-action@v0.36.0`으로 고정 |
| Java test 실행 실패 | `mvnw` 실행 비트 없음 | Git executable bit 복원, JDK 17에서 test 성공 |
| Python 컨테이너의 `gunicorn` 없음 | CI가 만든 host `.venv`가 Docker builder 결과를 덮어씀 | Python 3개 `.dockerignore`에 `.venv/` 추가, 새 이미지 기동 성공 |
| 앱이 Google ADC를 찾다 종료 | 인증 없이 `ENABLE_TRACING=true` | 현재 PoC base에서 tracing 비활성화, 6개 서비스 기동 성공 |
| GitHub OIDC AssumeRole 실패 | 계정이 immutable repository ID가 든 사용자 정의 subject 사용 | CloudTrail의 실제 subject로 IAM trust를 제한해 ECR/Terraform OIDC 성공 |

`/.gunicorn`의 read-only 경고는 남을 수 있지만 worker와 readiness에는 영향을 주지 않았다.
운영 이미지에서는 gunicorn control 파일 경로를 writable `emptyDir`로 명시하는 편이 좋다.

## 재검증 명령

```powershell
kubectl --kubeconfig .runtime/kubeconfig -n argocd get application bank-of-anthos-dev
kubectl --kubeconfig .runtime/kubeconfig -n bank get deployments,pods,ingress

$AlbHost = kubectl --kubeconfig .runtime/kubeconfig -n bank get ingress bank-of-anthos `
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
curl.exe "http://$AlbHost/ready"
```

## 완료와 미완료를 구분한 목록

완료:

- 서비스별 CI와 전체 6개 CI
- CRITICAL 취약점 gate
- 같은 이미지의 ECR/GAR 이중 적재
- AWS/GCP keyless federation
- 성공 서비스만 GitOps tag 승격
- Argo CD 자동 동기화와 self-heal
- EKS/ALB 로그인 smoke test
- Terraform format/validate와 OIDC plan 실행

미완료:

- GCP GKE Pilot Light 실제 생성 및 GCP Argo CD 배포
- Cloud SQL 승격 후 DB role/grant/secret bootstrap
- DR 승인 workflow의 실제 failover와 RTO/RPO 계측
- DNS 실제 전환
- branch protection, HTTPS, 관측성, NetworkPolicy

## IaC 재검증 결과

[최종 Terraform run 33573683695](https://github.com/qkrwlgh335-lab/bank-of-anthos-gitops/actions/runs/33573683695)에서
세 stack의 format/validate와 GitHub OIDC 인증이 성공했다. `aws-infra` plan은
`0 add, 1 change, 0 destroy`이며, 남은 1개는 실행 주체를 고정하기 위한 KMS key policy
in-place 변경이다. 실제 apply는 수행하지 않았다.
