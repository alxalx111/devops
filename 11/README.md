# Домашнее задание: Настройка RBAC в Kubernetes

## Цель работы
Настроить роли и права доступа в кластере Kubernetes через RBAC для безопасного разграничения полномочий пользователей.

## Описание/Пошаговая инструкция выполнения домашнего задания:
1) Настроить права доступа через RBAC модель.
2) Сделать несколько kubeconfig с разными ролями (read/write/admin) для доступа в кластер.

---

## 1. Создание пользователей и ролей

### 1.1 Создание Service Accounts и ролей

**Admin-user (полный доступ):**

Файл `admin-user.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: default
```

**Write-user (доступ на создание/удаление в default):**

Файл `write-user.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: write-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: write-role
  namespace: default
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["pods", "deployments", "services", "configmaps", "secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: write-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: write-user
  namespace: default
roleRef:
  kind: Role
  name: write-role
  apiGroup: rbac.authorization.k8s.io
```

**Read-user (только чтение в default):**

Файл `read-user.yaml`:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: read-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: read-role
  namespace: default
rules:
- apiGroups: ["", "apps", "extensions"]
  resources: ["pods", "deployments", "services", "configmaps"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-binding
  namespace: default
subjects:
- kind: ServiceAccount
  name: read-user
  namespace: default
roleRef:
  kind: Role
  name: read-role
  apiGroup: rbac.authorization.k8s.io
```

### 1.2 Применение манифестов

```bash
$ kubectl apply -f admin-user.yaml
serviceaccount/admin-user created
clusterrolebinding.rbac.authorization.k8s.io/admin-binding created

$ kubectl apply -f write-user.yaml
serviceaccount/write-user created
role.rbac.authorization.k8s.io/write-role created
rolebinding.rbac.authorization.k8s.io/write-binding created

$ kubectl apply -f read-user.yaml
serviceaccount/read-user created
role.rbac.authorization.k8s.io/read-role created
rolebinding.rbac.authorization.k8s.io/read-binding created
```

### 1.3 Проверка созданных ресурсов

```bash
$ kubectl get sa
NAME         SECRETS   AGE
admin-user   0         116s
default      0         24h
read-user    0         14s
write-user   0         86s

$ kubectl get roles -n default
NAME                              CREATED AT
d8:node-manager:bashible-events   2026-06-23T18:10:44Z
read-role                         2026-06-24T18:36:06Z
write-role                        2026-06-24T18:34:55Z

$ kubectl get rolebindings -n default
NAME                              ROLE                                   AGE
d8:node-manager:bashible-events   Role/d8:node-manager:bashible-events   24h
read-binding                      Role/read-role                         35s
write-binding                     Role/write-role                        106s
```

---

## 2. Получение токенов

```bash
$ kubectl create token admin-user -n default
eyJhbGciOiJSUz********gvD3ok58BRjA

$ kubectl create token write-user -n default
eyJhbGciOi***********s84ZthikcA

$ kubectl create token read-user -n default
eyJhbGc***************ggqBwqZ35w0gscg
```

---

## 3. Создание kubeconfig файлов

API сервер кластера: `https://api.ddgames.ru`

### 3.1 kubeconfig-admin.yaml

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://api.ddgames.ru
  name: deckhouse-cluster
contexts:
- context:
    cluster: deckhouse-cluster
    user: admin-user
  name: admin-context
current-context: admin-context
users:
- name: admin-user
  user:
    token: eyJhbGciOiJSU***********gvD3ok58BRjA
```

### 3.2 kubeconfig-write.yaml

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://api.ddgames.ru
  name: deckhouse-cluster
contexts:
- context:
    cluster: deckhouse-cluster
    user: write-user
  name: write-context
current-context: write-context
users:
- name: write-user
  user:
    token: eyJhbGciOiJ***********7rr7myK3b3Qs84ZthikcA
```

### 3.3 kubeconfig-read.yaml

```yaml
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://api.ddgames.ru
  name: deckhouse-cluster
contexts:
- context:
    cluster: deckhouse-cluster
    user: read-user
  name: read-context
current-context: read-context
users:
- name: read-user
  user:
    token: eyJhbGciOiJS**************1luxggqBwqZ35w0gscg
```

---

## 4. Проверка доступа

### 4.1 Проверка Admin (полный доступ)

```bash
$ kubectl --kubeconfig kubeconfig-admin.yaml get nodes
NAME     STATUS   ROLES                  AGE   VERSION
master   Ready    control-plane,master   24h   v1.33.10
worker   Ready    worker                 24h   v1.33.10

$ kubectl --kubeconfig kubeconfig-admin.yaml get pods -A
NAMESPACE                    NAME                                                              READY   STATUS
d8-admission-policy-engine   gatekeeper-audit-59cb498dd-p9dj6                                  3/3     Running
d8-admission-policy-engine   gatekeeper-controller-manager-5cf79fddc8-lpvzf                    2/2     Running
d8-cert-manager              cert-manager-7bbcd4cdb5-pb9d6                                     2/2     Running
...
```

**Результат:** Admin имеет полный доступ ко всем ресурсам кластера ✅

---

### 4.2 Проверка Write (доступ на создание/удаление в default)

```bash
$ kubectl --kubeconfig kubeconfig-write.yaml create deployment test --image=nginx -n default
deployment.apps/test created

$ kubectl --kubeconfig kubeconfig-write.yaml delete deployment test -n default
deployment.apps "test" deleted from default namespace

$ kubectl --kubeconfig kubeconfig-write.yaml get pods -n kube-system
Error from server (Forbidden): pods is forbidden: User "system:serviceaccount:default:write-user" cannot list resource "pods" in API group "" in the namespace "kube-system"
```

**Результат:** Write может создавать/удалять в `default`, но НЕ может читать в `kube-system` ✅

---

### 4.3 Проверка Read (только чтение в default)

```bash
$ kubectl --kubeconfig kubeconfig-read.yaml get pods -n default
NAME                      READY   STATUS      RESTARTS   AGE
db-74574d66dd-tj7sb       0/1     Completed   0          20h
db-74574d66dd-wbvtz       1/1     Running     0          19h
redis-6c5fb9c4b7-8gslc    1/1     Running     0          19h
vote-656fbb47b9-t9tkd     1/1     Running     0          19h
worker-7b7f97b9f5-ld5vq   1/1     Running     0          19h

$ kubectl --kubeconfig kubeconfig-read.yaml create deployment test --image=nginx -n default
error: failed to create deployment: deployments.apps is forbidden: User "system:serviceaccount:default:read-user" cannot create resource "deployments" in API group "apps" in the namespace "default"
```

**Результат:** Read может читать ресурсы в `default`, но НЕ может создавать/удалять ✅

---

## 5. Сводная таблица прав доступа

| Действие | Admin | Write | Read |
|----------|-------|-------|------|
| Чтение всех ресурсов во всех namespace | ✅ | ❌ | ❌ |
| Чтение ресурсов в default | ✅ | ✅ | ✅ |
| Создание/удаление в default | ✅ | ✅ | ❌ |
| Создание/удаление в других namespace | ✅ | ❌ | ❌ |
| Доступ к узлам кластера | ✅ | ❌ | ❌ |

