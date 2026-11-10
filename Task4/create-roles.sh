#!/usr/bin/env bash
# Создание namespace по доменам PropDevelopment и ролей RBAC (см. roles.md).
#
# Организационная структура отражается через namespace: каждый домен
# (продажи, ЖКУ, финансы, дата, «Умный дом») разворачивает сервисы в своём namespace,
# а продуктовые команды получают права только в нём.
set -euo pipefail

kubectl apply -f - <<'EOF'
# ---------- Namespaces по доменам ----------
apiVersion: v1
kind: Namespace
metadata: { name: sales, labels: { domain: sales } }          # Группа сервисов для продаж
---
apiVersion: v1
kind: Namespace
metadata: { name: housing, labels: { domain: housing } }      # Группа сервисов ЖКУ
---
apiVersion: v1
kind: Namespace
metadata: { name: smart-home, labels: { domain: housing } }   # Сервисы «Умный дом» (Task3)
---
apiVersion: v1
kind: Namespace
metadata: { name: finance, labels: { domain: finance } }      # Финансы
---
apiVersion: v1
kind: Namespace
metadata: { name: data, labels: { domain: data } }            # Дата: DWH, BI
---
# ---------- 1. propdev-viewer: только просмотр ресурсов кластера, без секретов ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-viewer
rules:
  - apiGroups: [""]
    resources: [pods, pods/log, pods/status, services, endpoints, configmaps, events,
                namespaces, nodes, persistentvolumes, persistentvolumeclaims,
                serviceaccounts, resourcequotas, limitranges, replicationcontrollers]
    verbs: [get, list, watch]
  - apiGroups: [apps, batch, autoscaling, policy, networking.k8s.io, storage.k8s.io,
                discovery.k8s.io, metrics.k8s.io]
    resources: ["*"]
    verbs: [get, list, watch]
---
# ---------- 2. propdev-configurator: настройка кластера, без секретов и без изменения RBAC ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-configurator
rules:
  - apiGroups: [""]
    resources: [pods, services, endpoints, configmaps, persistentvolumeclaims,
                persistentvolumes, namespaces, serviceaccounts, resourcequotas,
                limitranges, replicationcontrollers]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [""]
    resources: [pods/log, pods/status, events, nodes]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [nodes]
    verbs: [patch, update]          # cordon/drain, метки и taints узлов
  - apiGroups: [""]
    resources: [pods/eviction]
    verbs: [create]
  - apiGroups: [apps, batch, autoscaling, policy, networking.k8s.io, storage.k8s.io,
                discovery.k8s.io]
    resources: ["*"]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [rbac.authorization.k8s.io]
    resources: [roles, rolebindings, clusterroles, clusterrolebindings]
    verbs: [get, list, watch]       # видит RBAC, но не может выдать себе права
---
# ---------- 3. propdev-security-admin: привилегированная роль ИБ ----------
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-security-admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: [get, list, watch]       # полный просмотр, включая secrets
  - apiGroups: [""]
    resources: [secrets]
    verbs: [get, list, watch, create, update, patch, delete]   # управление и ротация секретов
  - apiGroups: [rbac.authorization.k8s.io]
    resources: [roles, rolebindings, clusterroles, clusterrolebindings]
    verbs: [get, list, watch, create, update, patch, delete, bind, escalate]
  - apiGroups: [certificates.k8s.io]
    resources: [certificatesigningrequests, certificatesigningrequests/approval]
    verbs: [get, list, watch, create, update, delete]  # выпуск и отзыв сертификатов пользователей
  - apiGroups: [certificates.k8s.io]
    resources: [signers]
    resourceNames: [kubernetes.io/kube-apiserver-client]
    verbs: [approve]
  - apiGroups: [networking.k8s.io]
    resources: [networkpolicies]
    verbs: [get, list, watch, create, update, patch, delete]   # сетевые политики (Task5)
---
# ---------- 4. propdev-namespace-developer: разработка в namespace своего домена ----------
# ClusterRole, которая выдаётся через RoleBinding только в namespace домена.
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: propdev-namespace-developer
rules:
  - apiGroups: [""]
    resources: [pods, services, endpoints, configmaps, persistentvolumeclaims, serviceaccounts]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [""]
    resources: [pods/log, pods/status, events, resourcequotas, limitranges]
    verbs: [get, list, watch]
  - apiGroups: [""]
    resources: [pods/portforward]
    verbs: [create]
  - apiGroups: [apps, batch, autoscaling]
    resources: ["*"]
    verbs: [get, list, watch, create, update, patch, delete]
  - apiGroups: [networking.k8s.io]
    resources: [ingresses, networkpolicies]
    verbs: [get, list, watch]
# Нет доступа к secrets и pods/exec (через exec можно прочитать секреты из окружения пода).
---
# ---------- 5. cluster-admin — встроенная роль, используется как break-glass (см. bind-roles.sh) ----------
EOF

echo
kubectl get clusterroles -l '!kubernetes.io/bootstrapping' -o name | grep propdev
kubectl get ns sales housing smart-home finance data
