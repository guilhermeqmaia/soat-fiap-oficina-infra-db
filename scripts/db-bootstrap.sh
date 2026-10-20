#!/usr/bin/env bash
# US-F4-03 — cria bancos/usuarios por servico no RDS via Job no EKS.
#   scripts/db-bootstrap.sh [--profile oficina] [--env prod] [--cluster oficina-mecanica-eks]
# Pre-requisitos: RDS aplicado (secrets no Secrets Manager), cluster no ar,
# Secret k8s `oficina-db` ja sincronizado (CD do OS Service) ou criado aqui.
set -euo pipefail
PROFILE="oficina"; ENV="prod"; CLUSTER="oficina-mecanica-eks"; PROJECT="oficina-mecanica"
while [ $# -gt 0 ]; do case "$1" in --profile) PROFILE="$2"; shift;; --env) ENV="$2"; shift;; --cluster) CLUSTER="$2"; shift;; *) echo "flag desconhecida: $1" >&2; exit 1;; esac; shift; done
export AWS_PROFILE="$PROFILE" AWS_DEFAULT_REGION="${AWS_REGION:-us-east-1}"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
aws eks update-kubeconfig --name "$CLUSTER" >/dev/null
kubectl get namespace oficina >/dev/null 2>&1 || kubectl create namespace oficina

secret_json() { aws secretsmanager get-secret-value --secret-id "$1" --query SecretString --output text; }
# master (mesmo contrato do CD do OS Service)
MASTER=$(secret_json "$PROJECT-$ENV/database")
kubectl -n oficina create secret generic oficina-db \
  --from-literal=DATABASE_URL="$(printf '%s' "$MASTER" | jq -r .DATABASE_URL)" \
  --from-literal=DB_HOST="$(printf '%s' "$MASTER" | jq -r .DB_HOST)" --from-literal=DB_PORT="$(printf '%s' "$MASTER" | jq -r .DB_PORT)" \
  --dry-run=client -o yaml | kubectl apply -f - >/dev/null

# servicos: um secret agregado para o Job (DB_NAME_<svc>, DB_USER_<svc>, DB_PASSWORD_<svc>)
SERVICES=$(aws secretsmanager list-secrets --filters Key=name,Values="$PROJECT-$ENV/" --query 'SecretList[].Name' --output text | tr '\t' '\n' | sed -nE "s|^$PROJECT-$ENV/([a-z0-9-]+)/database$|\1|p" | tr '\n' ' ')
[ -n "$SERVICES" ] || { echo "nenhum secret de servico ($PROJECT-$ENV/<svc>/database) — aplique o Terraform com service_databases"; exit 1; }
args=()
for svc in $SERVICES; do
  J=$(secret_json "$PROJECT-$ENV/$svc/database")
  args+=(--from-literal="DB_NAME_$svc=$(printf '%s' "$J" | jq -r .DB_NAME)" --from-literal="DB_USER_$svc=$(printf '%s' "$J" | jq -r .DB_USER)" --from-literal="DB_PASSWORD_$svc=$(printf '%s' "$J" | jq -r .DB_PASSWORD)")
done
kubectl -n oficina create secret generic oficina-services-db-bootstrap "${args[@]}" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

kubectl -n oficina delete job oficina-db-bootstrap --ignore-not-found >/dev/null
sed "s|__SERVICES__|${SERVICES% }|" "$HERE/k8s/db-bootstrap-job.yaml" | kubectl apply -f - >/dev/null
kubectl -n oficina wait --for=condition=complete job/oficina-db-bootstrap --timeout=180s
kubectl -n oficina logs job/oficina-db-bootstrap
kubectl -n oficina delete secret oficina-services-db-bootstrap >/dev/null
echo "ok — bancos: $SERVICES"
