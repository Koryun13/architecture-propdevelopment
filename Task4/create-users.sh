#!/usr/bin/env bash
# Создание пользователей Kubernetes по сертификатам X.509 (Minikube).
# Группа пользователя задаётся полем O (Organization) сертификата. По группам
# пользователи связываются с ролями (см. bind-roles.sh).
#
# Каждому пользователю: закрытый ключ -> CSR -> CertificateSigningRequest в API ->
# подтверждение -> подписанный сертификат -> user и context в kubeconfig.
#
# Использование: ./create-users.sh  (нужны kubectl и openssl; текущий контекст — администратор кластера)
set -euo pipefail

CERT_DIR="${CERT_DIR:-$(dirname "$0")/certs}"
CLUSTER="$(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
mkdir -p "$CERT_DIR"

# пользователь : группы (через запятую)
USERS=(
  "anna.analyst:propdev:viewers"                 # бизнес-аналитик — только просмотр
  "dmitry.devops:propdev:devops"                 # DevOps-инженер — настройка кластера
  "olga.security:propdev:security"               # специалист по ИБ — привилегированный доступ (секреты, RBAC)
  "petr.developer:propdev:sales-developers"      # разработчик домена «Продажи»
  "irina.engineer:propdev:housing-developers"    # инженер по эксплуатации домена «ЖКУ»
  "sergey.admin:propdev:platform-admins"         # администратор платформы (break-glass)
)

for entry in "${USERS[@]}"; do
  user="${entry%%:*}"
  groups="${entry#*:}"
  key="$CERT_DIR/$user.key" csr="$CERT_DIR/$user.csr" crt="$CERT_DIR/$user.crt"

  # Subject: CN=<пользователь>, O=<группа> (O может повторяться для нескольких групп)
  subj="/CN=$user"
  IFS=',' read -ra grp <<< "$groups"
  for g in "${grp[@]}"; do subj="$subj/O=$g"; done

  echo ">>> $user ($groups)"
  [[ -f "$key" ]] || openssl genrsa -out "$key" 2048 2>/dev/null
  MSYS_NO_PATHCONV=1 openssl req -new -key "$key" -out "$csr" -subj "$subj"

  kubectl delete csr "$user" --ignore-not-found >/dev/null
  cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: $user
spec:
  request: $(base64 < "$csr" | tr -d '\n')
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 7776000   # 90 дней — сертификаты пользователей регулярно перевыпускаются
  usages: ["client auth"]
EOF
  kubectl certificate approve "$user"
  for _ in $(seq 1 20); do
    cert="$(kubectl get csr "$user" -o jsonpath='{.status.certificate}')"
    [[ -n "$cert" ]] && break
    sleep 1
  done
  echo "$cert" | base64 -d > "$crt"

  kubectl config set-credentials "$user" --client-certificate="$crt" --client-key="$key" --embed-certs=true
  kubectl config set-context "$user@$CLUSTER" --cluster="$CLUSTER" --user="$user" --namespace=default
done

echo
echo "Пользователи созданы. Пример проверки: kubectl --context anna.analyst@$CLUSTER auth whoami"
