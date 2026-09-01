$ErrorActionPreference = "Stop"

aws eks update-kubeconfig --region ap-northeast-2 --name phase1-bank-eks
kubectl apply -f "$PSScriptRoot/../gitops/bootstrap/bank-of-anthos.yaml"
kubectl -n argocd wait --for=condition=Available deployment/argocd-server --timeout=300s
kubectl -n argocd get applications bank-of-anthos-dev
kubectl -n bank get ingress,pods

Write-Host "Argo CD UI: kubectl -n argocd port-forward svc/argocd-server 8080:80"
