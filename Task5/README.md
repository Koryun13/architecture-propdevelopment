# Задание 5. Управление трафиком внутри кластера Kubernetes

Файл с сетевыми политиками: [non-admin-api-allow.yaml](non-admin-api-allow.yaml).

## Сервисы
В namespace `default` развёрнуты четыре сервиса на образе Nginx. Метка `role` задаёт роль сервиса:
```bash
kubectl run front-end-app          --image=nginx --labels role=front-end          --expose --port 80
kubectl run back-end-api-app       --image=nginx --labels role=back-end-api       --expose --port 80
kubectl run admin-front-end-app    --image=nginx --labels role=admin-front-end    --expose --port 80
kubectl run admin-back-end-api-app --image=nginx --labels role=admin-back-end-api --expose --port 80
```

## Сетевые политики
```bash
kubectl apply -f non-admin-api-allow.yaml
```

| Политика | Действие |
|---|---|
| `default-deny-ingress` | Запрещает любой входящий трафик ко всем подам namespace |
| `back-end-api-allow-from-front-end` | `front-end` → `back-end-api` |
| `front-end-allow-from-back-end-api` | `back-end-api` → `front-end` |
| `admin-back-end-api-allow-from-admin-front-end` | `admin-front-end` → `admin-back-end-api` |
| `admin-front-end-allow-from-admin-back-end-api` | `admin-back-end-api` → `admin-front-end` |

Трафик разрешён в обе стороны только внутри пар `front-end` ↔ `back-end-api` и `admin-front-end` ↔ `admin-back-end-api`. Любой другой под, в том числе новый сервис без разрешающей политики, изолирован: другие поды не могут к нему обращаться.

NetworkPolicy работают только с CNI, который их поддерживает, поэтому Minikube запускается с Calico:
```bash
minikube start -p propdevelopment --cni=calico
```

## Проверка (Minikube, Kubernetes v1.37, Calico)
Тестовый под получает метку проверяемой роли:
```bash
kubectl run test-$RANDOM --rm -i -t --image=alpine --labels role=front-end -- sh
/ # wget -qO- --timeout=2 http://back-end-api-app          # ответ Nginx
/ # wget -qO- --timeout=2 http://admin-back-end-api-app    # wget: download timed out
```

Матрица доступности (запросы из подов сервисов, `curl http://<service>`):

| Откуда \ Куда | front-end | back-end-api | admin-front-end | admin-back-end-api |
|---|---|---|---|---|
| **front-end** | — | ✅ 200 | ❌ timeout | ❌ timeout |
| **back-end-api** | ✅ 200 | — | ❌ timeout | ❌ timeout |
| **admin-front-end** | ❌ timeout | ❌ timeout | — | ✅ 200 |
| **admin-back-end-api** | ❌ timeout | ❌ timeout | ✅ 200 | — |

Тестовый под alpine:

| Метка тестового пода | → back-end-api | → admin-back-end-api |
|---|---|---|
| без метки | ❌ | ❌ |
| `role=front-end` | ✅ | ❌ |
| `role=admin-front-end` | ❌ | ✅ |
