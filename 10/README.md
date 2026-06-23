
# Домашнее задание: Развертывание приложения в кластере Kubernetes

## Цель работы
Развернуть приложение в кластере Kubernetes с хранением манифестов в репозитории.

## Описание/Пошаговая инструкция выполнения домашнего задания:
1) Развернуть кластер DeckHouse по примеру с занятия.
2) Запустить своё приложение в кластере Kubernetes.
3) Все конфигурации для деплоя приложения, в формате yaml должны быть в репозитории.
4) Предоставить доступ к кластеру через IAM в Yandex.Cloud для менторов.


# 1. Развертывание кластера DeckHouse
Кластер DeckHouse успешно развернут и готов к работе. Все компоненты DeckHouse установлены и функционируют корректно.

#### Состав кластера
| Компонент | Статус |
|-----------|--------|
| Control Plane (master) | ✅ Running |
| Worker Node | ✅ Running |
| DeckHouse modules | ✅ Installed |


## Результаты работы

### Консоль управления DeckHouse
![Консоль управления DeckHouse](./img/d8/console.png)
*Рисунок 1 — Веб-интерфейс консоли управления DeckHouse доступен по адресу https://console.ddgames.ru/system/management*

### Система мониторинга Grafana
![Grafana Dashboard](./img/d8/grafana.png)
*Рисунок 2 — Панель мониторинга Grafana доступна по адресу https://grafana.ddgames.ru/?orgId=1*

### Модуль Stronghold
![Stronghold модуль](./img/d8/stronghold.png)
*Рисунок 3 — Установленный модуль Stronghold доступен по адресу https://stronghold.ddgames.ru/*

### Настройка kubectl и проверка доступа

```bash
$ kubectl config set-context admin-api.ddgames.ru --cluster=api.ddgames.ru --user=admin-api.ddgames.ru
Context "admin-api.ddgames.ru" modified.

$ kubectl config use-context admin-api.ddgames.ru
Switched to context "admin-api.ddgames.ru".

$ kubectl get nodes
NAME     STATUS   ROLES               AGE    VERSION
master   Ready    control-plane,master  154m   v1.33.10
worker   Ready    worker                129m   v1.33.10
```

![kubectl настроен](./img/d8/kubectl.png)
*Рисунок 4 — Подключение kubectl к кластеру*


# 2. Запуск приложения в кластере Kubernetes

### Подготовка доступа к приватному репозиторию

Для доступа к образам в приватном GitLab Container Registry был создан Personal Access Token:

![Создание токена](./img/deploy/token.png)
*Рисунок 5 — Создание Personal Access Token в GitLab с правами read_registry*

На основе токена создан Secret в Kubernetes для авторизации при скачивании образов:

```bash
$ kubectl create secret docker-registry regcred \
    --docker-server=otusteam.gitlab.yandexcloud.net:5050 \
    --docker-username=Ваш_Логин_В_Gitlab \
    --docker-password=glpat-KPbnXcc-jSt4bnLn1FSAtm86MQp10mhwCA*******

secret/regcred created

$ kubectl get secret regcred
NAME      TYPE                             DATA   AGE
regcred   kubernetes.io/dockerconfigjson   1      71s

$ kubectl describe secret regcred
Name:         regcred
Namespace:    default
Labels:       <none>
Annotations:  <none>

Type:  kubernetes.io/dockerconfigjson

Data
====
.dockerconfigjson:  278 bytes
```

![Создание Secret](./img/deploy/add-secrets.png)

*Рисунок 6 — Создание и проверка Secret для доступа к приватному репозиторию*

### Манифесты приложения

Все манифесты для деплоя приложения находятся в директории `d8/`:

| Файл | Назначение |
|------|------------|
| `db-deployment.yaml` | Деплой PostgreSQL |
| `db-service.yaml` | Сервис для PostgreSQL |
| `redis-deployment.yaml` | Деплой Redis |
| `redis-service.yaml` | Сервис для Redis |
| `vote-deployment.yaml` | Деплой приложения голосования |
| `vote-service.yaml` | Сервис для голосования (NodePort 31000) |
| `result-deployment.yaml` | Деплой приложения результатов |
| `result-service.yaml` | Сервис для результатов (NodePort 31001) |
| `worker-deployment.yaml` | Деплой воркера |

Пример манифеста для vote-deployment.yaml:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: vote
  name: vote
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vote
  template:
    metadata:
      labels:
        app: vote
    spec:
      containers:
      - image: otusteam.gitlab.yandexcloud.net:5050/devops/devops-2026-03/example-voting-app/voting-app:latest
        name: vote
        ports:
        - containerPort: 80
          name: vote
      imagePullSecrets:
      - name: regcred
```

### Деплой приложения

```bash
$ kubectl apply -f .
deployment.apps/db created
service/db created
deployment.apps/redis created
service/redis created
deployment.apps/result created
service/result created
deployment.apps/vote created
service/vote created
deployment.apps/worker created
```

### Проверка статуса

```bash
$ kubectl get pods -o wide
NAME                      READY   STATUS    RESTARTS   AGE   IP             NODE     NOMINATED NODE   READINESS GATES
db-74574d66dd-tj7sb       1/1     Running   0          58s   10.111.1.47    worker   <none>           <none>
redis-6c5fb9c4b7-vs7kr    1/1     Running   0          57s   10.111.1.69    worker   <none>           <none>
result-5dbff99c54-wqrjx   1/1     Running   0          57s   10.111.1.54    worker   <none>           <none>
vote-656fbb47b9-fdb27     1/1     Running   0          57s   10.111.1.76    worker   <none>           <none>
worker-7b7f97b9f5-gr8pw   1/1     Running   0          57s   10.111.1.171   worker   <none>           <none>
```

```bash
$ kubectl get svc
NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
db           ClusterIP   10.222.67.229    <none>        5432/TCP         45s
kubernetes   ClusterIP   10.222.0.1       <none>        443/TCP          4h15m
redis        ClusterIP   10.222.29.152    <none>        6379/TCP         44s
result       NodePort    10.222.94.43     <none>        8081:31001/TCP   44s
vote         NodePort    10.222.169.233   <none>        8080:31000/TCP   44s
```

![Деплой приложения](./img/deploy/deploy-kubectl.png)
*Рисунок 7 — Результат деплоя: все поды в статусе Running, сервисы созданы*

### Доступ к приложению

Приложение доступно по внешнему IP адресу worker ноды (`111.88.147.86`):

- **Голосование**: `http://111.88.147.86:31000`
- **Результаты**: `http://111.88.147.86:31001`

![Работа приложения](./img/deploy/deploy-result.png)
*Рисунок 8 — Приложение для голосования Cats vs Dogs успешно работает*



### 2.5 Настройка Ingress и TLS сертификатов

Для доступа к приложению по HTTPS создан ClusterIssuer для Let's Encrypt:

**`cluster-issuer.yaml`:**
```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: yc-clusterissuer
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: dendrino22@yandex.ru
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
```

**Применение:**
```bash
$ kubectl apply -f cluster-issuer.yaml
clusterissuer.cert-manager.io/yc-clusterissuer created

$ kubectl get clusterissuer
NAME                  READY   AGE
yc-clusterissuer      True    30s
```

**Создание Ingress правил:**

**`vote-ingress.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: vote-ingress
  annotations:
    cert-manager.io/cluster-issuer: "yc-clusterissuer"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - vote.ddgames.ru
    secretName: vote-tls
  rules:
  - host: vote.ddgames.ru
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: vote
            port:
              number: 8080
```

**`result-ingress.yaml`:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: result-ingress
  annotations:
    cert-manager.io/cluster-issuer: "yc-clusterissuer"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - result.ddgames.ru
    secretName: result-tls
  rules:
  - host: result.ddgames.ru
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: result
            port:
              number: 8081
```

**Применение Ingress:**
```bash
$ kubectl apply -f vote-ingress.yaml
ingress.networking.k8s.io/vote-ingress created

$ kubectl apply -f result-ingress.yaml
ingress.networking.k8s.io/result-ingress created
```

**Проверка сертификатов:**
```bash
$ kubectl get certificate
NAME         READY   SECRET       AGE
result-tls   True    result-tls   4m45s
vote-tls     True    vote-tls     4m54s

$ kubectl get ingress
NAME             CLASS   HOSTS               ADDRESS           PORTS     AGE
result-ingress   nginx   result.ddgames.ru   158.160.223.224   80, 443   11s
vote-ingress     nginx   vote.ddgames.ru     158.160.223.224   80, 443   20s
```

**Доступ к приложению:**
| Сервис | URL | Статус |
|--------|-----|--------|
| Голосование | https://vote.ddgames.ru | ✅ Working |
| Результаты | https://result.ddgames.ru | ✅ Working |

![Vote App HTTPS](./img/deploy/deploy-result-ingress.png)
*Рисунок 9 — Приложение голосования доступно по HTTPS*



### Известные проблемы

При загрузке приложения голосования по HTTPS в консоли браузера появляется ошибка Mixed Content:

```
Mixed Content: The page at 'https://vote.ddgames.ru/' was loaded over HTTPS, 
but requested an insecure script 'http://code.jquery.com/jquery-latest.min.js'. 
This request has been blocked; the content must be served over HTTPS.

Uncaught ReferenceError: jQuery is not defined
Uncaught ReferenceError: $ is not defined
```

**Причина:** В коде приложения jQuery загружается по протоколу HTTP, тогда как сама страница открыта по HTTPS. Браузер блокирует загрузку небезопасных скриптов на защищённых страницах.

**Влияние на работу:** Из-за ошибки загрузки jQuery не отображается галочка, показывающая сделанный выбор. В остальном приложение функционирует корректно — голоса принимаются и отображаются в результатах.

**Решение:** Исправить в коде приложения загрузку jQuery с HTTP на HTTPS:
```html
<!-- Было -->
<script src="http://code.jquery.com/jquery-latest.min.js"></script>

<!-- Стало -->
<script src="https://code.jquery.com/jquery-latest.min.js"></script>
```
Либо использовать протокол-независимую ссылку:
```html
<script src="//code.jquery.com/jquery-latest.min.js"></script>
```

![Ошибка в консоли](./img/deploy/deploy-to-fix.png)
*Рисунок 10 — Ошибка Mixed Content в консоли браузера при загрузке jQuery по HTTP*
