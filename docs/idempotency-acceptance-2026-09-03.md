# Terraform/CI/CD idempotency acceptance audit

검증일: 2026-09-03 (Asia/Seoul)

## 결론

현재 구성은 **정적 합격 후보(candidate)** 이지만 최종 합격 상태는 아니다. 코드 수준의 재실행
안전장치는 보완됐으나, 현재 AWS 실리소스와 remote state가 일치하지 않고 새 코드가 아직 승인형
apply와 destroy/recreate 실험을 통과하지 않았기 때문이다. 이 문서는 검증되지 않은 항목을 성공으로
간주하지 않는다.

검증 중에는 Terraform apply/destroy, AWS/GCP 리소스 변경 또는 삭제를 수행하지 않았다.

## 이번 보완

- 모든 Terraform PR plan이 `terraform/environments/*`를 자동 발견하고 환경별 backend/tfvars를 사용한다.
- 환경 간 동일 remote-state 위치와 account/project 범위의 고유 이름 중복을 CI에서 거부한다.
- apply와 destroy가 모두 `plan -out=tfplan -> review/approval -> apply tfplan` 경로만 사용한다.
- 승인 작업 직후 동일 조건의 `plan -detailed-exitcode`를 실행하고 변경이 남으면 실패시킨다.
- Terraform stack 변경은 deployment 단위 concurrency로 직렬화한다.
- 직접 `terraform destroy -auto-approve`를 호출하던 로컬 스크립트를 차단했다.
- DB ledger DDL을 멱등 SQL로 바꾸고 bootstrap 재실행이 항상 누락된 schema object를 완성한다.
- DR Drill은 이미 적용된 SHA에서 빈 commit으로 실패하지 않으며 SHA 기반 branch를 재사용한다.
- DR Drill 원복은 실패 당시 관측값이 아니라 명시적인 pilot-light node 목표값으로 수렴한다.
- DB/DR 워크플로에 deployment/name prefix와 환경별 resource/secret 이름을 추가했다.
- EKS, RDS PostgreSQL, GKE release channel, Cloud SQL tier 및 일부 quota를 plan 전에 확인한다.

## 8개 합격 기준 판정

| 번호 | 현재 판정 | 근거와 남은 조건 |
|---|---|---|
| 1 | 불합격 | kdn10 실계정에는 EKS가 없지만 `aws-infra` state serial 10에는 EKS cluster/node group이 남아 있다. 최근 plan run 33658283575도 `12 add, 3 change, 3 destroy`였다. 승인 apply 후 새 post-apply convergence step이 `No changes`를 증명해야 한다. |
| 2 | 부분 합격 | immutable image 재사용과 DMS 상태별 resume는 구현되어 있다. ledger 부분 실패 문제와 DR 빈 commit/잘못된 node 원복도 이번에 수정했다. 다만 새 코드로 의도적인 중간 실패 후 재실행 시험은 아직 없다. 실패한 saved plan을 그대로 억지 적용하지 말고 같은 workflow를 전체 재실행하여 새 plan을 다시 승인해야 한다. |
| 3 | 불합격 | saved destroy와 순서는 구현했지만 실제 `destroy -> 동일 환경 재생성`을 수행하지 않았다. Argo workload/Ingress가 만든 LB가 먼저 제거되는지도 실험 증거가 없다. `gcp-cicd` WIF와 state bucket은 재생성 실행 주체이므로 정상 teardown에서 의도적으로 유지한다. |
| 4 | 부분 합격 | deployment 디렉터리, name prefix, backend 중복 차단은 구현됐다. 현재 실제 디렉터리는 `phase1` 하나뿐이고 GitOps workload overlay도 `dev`, `gcp-dr`만 있으므로 dev/stage/prod 3환경 생성 증거는 없다. |
| 5 | 부분 합격 | app workflow는 `sha-<40 hex>` tag, ECR/GAR immutable tag 재사용, 두 registry digest 동일성 검사를 사용한다. run 33658940803에서 6개 build/test/scan/publish와 required gate는 성공했다. 하지만 GitOps 승격은 app repository의 오래된 `GITOPS_TOKEN`으로 checkout에 실패하여 전체 CD는 미합격이다. |
| 6 | 코드 합격/실행 필요 | workflow가 commit SHA를 고정하고 run/attempt/SHA별 plan artifact를 저장한 뒤 승인 job에서 같은 artifact를 `terraform apply tfplan`로 적용한다. 새 코드로 실제 승인 apply 증거는 아직 없다. |
| 7 | 부분 합격 | remote state를 유지하고 Phase 1의 기존 GAR/SA/WIF에는 configuration-driven import block이 있다. 하지만 adoption plan은 현재 Terraform SA의 조회 권한 부족 때문에 완료 증거가 없고, state를 잃은 임의 리소스를 자동 소유권 주장하지는 않는다. |
| 8 | 부분 합격 | Terraform 1.14.3, provider lock files, action SHA, EKS 1.35/add-on, PostgreSQL 16.14/16 및 container digest가 고정되어 있다. AWS 실계정 preflight는 EKS 1.35와 RDS 16.14를 통과했다. GKE는 REGULAR channel 정책이므로 패치 버전은 Google이 관리하며 quota와 CSP 정책은 매 실행 때 다시 검증해야 한다. |

## 현재 실환경 증거

- AWS identity: account `558807819624`, user `kdn10`
- AWS EKS list: empty
- AWS RDS list: unrelated stopped MySQL `mid-db-instance`만 존재
- S3 `aws-infra` state: serial 10, managed resource groups 53, EKS cluster/node group/OIDC 주소 포함
- GitHub Terraform run 33658283575: 정적 검사 성공, aws-infra plan은 외부 drift와
  `12 to add, 3 to change, 3 to destroy`
- GitHub app run 33658940803: 6개 서비스 CI/ECR/GAR와 `CI required gate` 성공,
  cross-repository GitOps checkout 실패
- app repository `GITOPS_TOKEN`: 2026-09-01 생성 이후 갱신되지 않음

## 최종 합격을 위한 승인형 실행 순서

1. 변경을 PR로 올려 `Terraform required gate`와 모든 환경별 speculative plan을 통과시킨다.
2. app repository의 fine-grained `GITOPS_TOKEN`을 GitOps repository Contents/PR write 권한으로 교체한다.
3. 예상 replace/destroy를 검토한 뒤 `aws-infra`부터 stack 의존 순서대로 승인 apply한다.
4. 각 apply job의 `Prove convergence`가 exit code 0임을 보존한다.
5. 모든 stack을 다시 `action=plan`으로 실행하여 전부 `No changes`를 캡처한다.
6. 통제된 한 단계 실패 후 workflow 전체를 재실행하고 새 saved plan을 다시 승인해 수렴을 확인한다.
7. 별도 시험 환경에서 workload/Ingress를 먼저 제거한 뒤 `gcp-addons -> aws-addons -> dr-data -> gcp-dr -> aws-infra` 순서로 승인 destroy한다.
8. 같은 deployment/backend state로 재apply하고 이름/SG/IAM/LB/DB 충돌 없이 생성된 뒤 다시 `No changes`인지 확인한다.

`gcp-cicd`와 remote-state bucket은 7번의 일반 teardown 대상이 아니다. WIF pool/provider를 삭제하면
Google의 soft-delete 기간 동안 같은 ID를 재사용할 수 없으므로, bootstrap identity를 폐기할 때는
별도 변경·승인 절차와 새 ID가 필요하다.
