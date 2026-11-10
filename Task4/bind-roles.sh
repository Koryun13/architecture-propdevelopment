#!/usr/bin/env bash
# Связывание пользователей с ролями (см. roles.md).
# Привязка идёт к группам (поле O сертификата из create-users.sh): права выдаются
# и отзываются сменой группы, без правки RBAC под каждого сотрудника.
set -euo pipefail

kubectl apply -f - <<'EOF'
# ---------- Кластерные роли ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: propdev-viewers }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-viewer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:viewers" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: propdev-devops }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-configurator }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:devops" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: propdev-security }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-security-admin }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:security" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata: { name: propdev-platform-admins }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: cluster-admin }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:platform-admins" }
---
# ---------- Роли в namespace доменов (организационная структура) ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: sales-developers, namespace: sales }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-developer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:sales-developers" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: housing-developers, namespace: housing }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-developer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:housing-developers" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: housing-developers, namespace: smart-home }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-developer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:housing-developers" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: finance-developers, namespace: finance }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-developer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:finance-developers" }
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata: { name: data-engineers, namespace: data }
roleRef: { apiGroup: rbac.authorization.k8s.io, kind: ClusterRole, name: propdev-namespace-developer }
subjects:
  - { apiGroup: rbac.authorization.k8s.io, kind: Group, name: "propdev:data-engineers" }
EOF

echo
kubectl get clusterrolebindings -o wide | grep -E 'NAME|propdev'
kubectl get rolebindings -A -o wide | grep -E 'NAMESPACE|propdev'
