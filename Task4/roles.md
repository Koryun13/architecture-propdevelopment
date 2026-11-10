# Роли RBAC в Kubernetes

Доступ к кластеру разграничен по организационной структуре PropDevelopment:
- **по функции** — кластерные роли просмотра, настройки и привилегированных действий;
- **по домену** — каждый домен разворачивает сервисы в своём namespace (`sales`, `housing`, `smart-home`, `finance`, `data`), продуктовые команды работают только в нём.

Права выдаются группам (поле `O` сертификата пользователя или группа из IdP), а не отдельным пользователям.

| Роль | Права роли | Группы пользователей |
| --- | --- | --- |
| `propdev-viewer` (ClusterRole + ClusterRoleBinding) | Только просмотр (`get`, `list`, `watch`) ресурсов всего кластера: поды и логи, сервисы, configmaps, namespaces, узлы, PV и PVC, события, workloads (`apps`, `batch`), `autoscaling`, `policy`, `networking`, `storage`. **Нет доступа к `secrets`**, создание и изменение ресурсов запрещено | `propdev:viewers` — бизнес-аналитики, владельцы продуктов, менеджеры операционных команд, внешние аудиторы на время аудита |
| `propdev-configurator` (ClusterRole + ClusterRoleBinding) | Настройка кластера: создание, изменение и удаление namespaces, workloads, сервисов, configmaps, PV и PVC, ingress, NetworkPolicy, HPA, PDB, StorageClass, квот и лимитов; `cordon` и `drain` узлов (patch nodes, eviction). RBAC — только просмотр. **Нет доступа к `secrets`**, нет `pods/exec`, нельзя выдавать права | `propdev:devops` — DevOps-инженеры продуктовых команд |
| `propdev-security-admin` (ClusterRole + ClusterRoleBinding), **привилегированная** | Просмотр всех ресурсов кластера, **включая `secrets`**; управление секретами (создание и ротация); управление RBAC (Roles, ClusterRoles и привязки, `bind`, `escalate`); подтверждение и отзыв сертификатов пользователей (CSR); управление NetworkPolicy. Изменять бизнес-нагрузку (deployments и т. п.) не может | `propdev:security` — специалист по ИБ (и его заместитель) |
| `cluster-admin` (встроенная ClusterRole + ClusterRoleBinding), **привилегированная, break-glass** | Полный доступ ко всем ресурсам кластера, включая `secrets`, `pods/exec` и RBAC. Используется только для аварийных работ и обновления кластера, каждое использование журналируется и согласуется с ИБ | `propdev:platform-admins` — администраторы платформы Kubernetes (инженеры эксплуатации, 1–2 человека) |
| `propdev-namespace-developer` (ClusterRole, выдаётся через **RoleBinding в namespace домена**) | В namespace своего домена: создание, изменение и удаление pods, deployments, statefulsets, jobs и cronjobs, services, configmaps, PVC, serviceaccounts, HPA; просмотр логов, событий, квот, ingress и NetworkPolicy; `port-forward` для отладки. **Нет доступа к `secrets`** и `pods/exec` (через exec можно прочитать секреты из переменных окружения). В чужих namespace прав нет | `propdev:sales-developers` → `sales`; `propdev:housing-developers` → `housing`, `smart-home`; `propdev:finance-developers` → `finance`; `propdev:data-engineers` → `data`. Разработчики и инженеры по эксплуатации функциональных команд домена |

## Пользователи, созданные скриптом `create-users.sh`

| Пользователь | Группа | Роль |
| --- | --- | --- |
| `anna.analyst` | `propdev:viewers` | `propdev-viewer` |
| `dmitry.devops` | `propdev:devops` | `propdev-configurator` |
| `olga.security` | `propdev:security` | `propdev-security-admin` |
| `petr.developer` | `propdev:sales-developers` | `propdev-namespace-developer` в `sales` |
| `irina.engineer` | `propdev:housing-developers` | `propdev-namespace-developer` в `housing`, `smart-home` |
| `sergey.admin` | `propdev:platform-admins` | `cluster-admin` |
