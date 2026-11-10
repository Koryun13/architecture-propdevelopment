# Задание 4. Защита доступа к кластеру Kubernetes (RBAC)

| Файл | Содержание |
|---|---|
| [roles.md](roles.md) | Таблица ролей, их полномочий и групп пользователей |
| [create-users.sh](create-users.sh) | Создание пользователей по сертификатам X.509 (CSR API Kubernetes), группа — в поле `O` сертификата |
| [create-roles.sh](create-roles.sh) | Создание namespace доменов и ролей: `propdev-viewer`, `propdev-configurator`, `propdev-security-admin`, `propdev-namespace-developer` |
| [bind-roles.sh](bind-roles.sh) | Связывание групп пользователей с ролями: ClusterRoleBinding и RoleBinding в namespace доменов |

## Запуск
```bash
minikube start -p propdevelopment --cni=calico   # пустой Minikube
./create-users.sh
./create-roles.sh
./bind-roles.sh
```
Скрипт `create-users.sh` сохраняет ключи и сертификаты в `certs/` (каталог исключён из Git) и добавляет в kubeconfig контексты `<user>@<cluster>`.

## Проверка (Minikube, Kubernetes v1.37)
```bash
kubectl --context anna.analyst@propdevelopment auth whoami
kubectl --context <user>@propdevelopment auth can-i <verb> <resource> [-n <namespace>]
kubectl --context <user>@propdevelopment auth can-i create pods --subresource=exec -n sales
```

| Пользователь | Проверка | Результат |
|---|---|---|
| anna.analyst | `list pods -A` | yes |
| anna.analyst | `get secrets -n sales` | no |
| anna.analyst | `create deployment -n sales` | no |
| dmitry.devops | `create deployment -n sales` | yes |
| dmitry.devops | `create networkpolicy -n data` | yes |
| dmitry.devops | `get secrets -n sales` | no |
| dmitry.devops | `create clusterrolebinding` | no |
| olga.security | `get secrets -A` | yes |
| olga.security | `create rolebinding -n finance` | yes |
| olga.security | `delete deployment -n sales` | no |
| petr.developer | `create deployment -n sales` | yes |
| petr.developer | `create deployment -n finance` | no |
| petr.developer | `get secrets -n sales` | no |
| petr.developer | `create pods --subresource=exec -n sales` | no |
| petr.developer | `create pods --subresource=portforward -n sales` | yes |
| irina.engineer | `create deployment -n smart-home` | yes |
| irina.engineer | `list pods -n sales` | no |
| sergey.admin | `* *` | yes |

## Связь с заданиями 1–3
- Секреты (ключи и токены API партнёров, сертификаты mTLS) отнесены к **секретным данным** (Task1), поэтому читать их может только привилегированная роль ИБ и break-glass администратор.
- Разграничение по namespace доменов закрывает пункты Task2 о минимальных привилегиях и замкнутых контурах: команда продаж не видит ресурсы финансов и данных.
- Для сервисов «Умный дом» (Task3) выделен namespace `smart-home`, доступ к нему есть у команды домена ЖКУ.
- В промышленной среде пользователи и группы берутся из Keycloak (OIDC, федерация с Active Directory), а не из клиентских сертификатов. Тогда отзыв доступа идёт через единый реестр учётных записей.
