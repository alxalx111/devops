# Домашнее задание: GitLab CI/CD

## Цель
Произвести настройку GitLab CI/CD; реализовать GitLab pipeline для деплоя приложения в Yandex.Cloud.

---

## Используемое приложение

Исходное [example-voting-app](https://github.com/dockersamples/example-voting-app) - распределенное приложение для голосования, состоящее из 5 микросервисов:
- **vote** (Python) - веб-интерфейс для голосования
- **result** (Node.js) - веб-интерфейс для просмотра результатов
- **worker** (.NET) - обработчик голосов
- **redis** - брокер сообщений для сбора голосов
- **postgres** - база данных для хранения результатов

На OTUS GitLab [OTUS GitLab example-voting-app](https://otusteam.gitlab.yandexcloud.net/devops/devops-2026-03/example-voting-app)

---

## 1. Структура pipeline

Pipeline состоит из следующих этапов:

| Stage | Описание |
|-------|----------|
| `build` | Сборка Docker-образов |
| `push` | Публикация образов в GitLab Registry |
| `deploy` | Деплой приложения на ВМ в Yandex Cloud |

---

## 2. Переменные GitLab CI/CD

В GitLab: **Settings → CI/CD → Variables**

| Variable | Value | Protected | Masked |
|----------|-------|-----------|--------|
| `CI_REGISTRY` | `otusteam.gitlab.yandexcloud.net:5050` | ❌ No | ❌ No |
| `CI_REGISTRY_USER` | `elm.g2016@yandex.ru` | ❌ No | ❌ No |
| `CI_REGISTRY_PASSWORD` | `glpat-токен` | ❌ No | ✅ Yes |
| `VM_IP` | `81.26.191.124` | ❌ No | ❌ No |
| `VM_USER` | `elv` | ❌ No | ❌ No |
| `VM_SSH_KEY` | `-----BEGIN OPENSSH PRIVATE KEY-----...` | ❌ No | ✅ Yes |

---

**Скриншот: Виртуальные машины в Yandex Cloud**

![vms](yandex-vms.png)

| ВМ | Назначение |
|----|-----------|
| `docker-vm` | GitLab Runner для сборки и деплоя |
| `deploy-server` | Целевая ВМ для развертывания приложения |

---

## 3. Исправление worker/Dockerfile

В процессе настройки pipeline возникла проблема со сборкой worker-сервиса. Оригинальный Dockerfile содержал строку:

```dockerfile
FROM --platform=${BUILDPLATFORM} mcr.microsoft.com/dotnet/sdk:7.0 AS build
```

При сборке в GitLab CI/CD переменная `${BUILDPLATFORM}` не подставлялась, что вызывало ошибку:

```
failed to parse platform : "" is an invalid OS component
```

### Исправление:

Было принято решение **убрать `--platform=${BUILDPLATFORM}`** и использовать стандартный образ без указания платформы, так как сборка происходит на amd64-хосте и не требует кроссплатформенности.

**Исправленный worker/Dockerfile:**

```dockerfile
# because of dotnet, we always build on amd64, and target platforms in cli
# dotnet doesn't support QEMU for building or running.
# (errors common in arm/v7 32bit) https://github.com/dotnet/dotnet-docker/issues/1537

# build compiles the program for the builder's local platform
FROM mcr.microsoft.com/dotnet/sdk:7.0 AS build
ARG TARGETPLATFORM
ARG TARGETARCH
ARG BUILDPLATFORM
RUN echo "I am running on $BUILDPLATFORM, building for $TARGETPLATFORM"

WORKDIR /source
COPY *.csproj .
RUN dotnet restore -a $TARGETARCH

COPY . .
RUN dotnet publish -c release -o /app -a $TARGETARCH --self-contained false --no-restore

# app image
FROM mcr.microsoft.com/dotnet/runtime:7.0
WORKDIR /app
COPY --from=build /app .
ENTRYPOINT ["dotnet", "Worker.dll"]
```

### Передача аргументов сборки:

В `.gitlab-ci.yml` для job `build_worker` передаются необходимые аргументы:

```yaml
build_worker:
  stage: build
  script:
    - |
      docker build \
        --build-arg BUILDPLATFORM=linux/amd64 \
        --build-arg TARGETPLATFORM=linux/amd64 \
        --build-arg TARGETARCH=amd64 \
        -t $IMAGE_NAME_WORKER:$IMAGE_TAG ./worker
```

---

## 4. Проблема с подключением к базе данных и её решение

### Обнаруженная проблема:

При запуске приложения worker не мог подключиться к PostgreSQL и зависал в состоянии `Waiting for db`:

```bash
docker logs worker --tail 10
Waiting for db
Waiting for db
Waiting for db
...
```

### Причина:

В коде worker (`worker/Program.cs`) строка подключения к БД была жестко зашита:

```csharp
OpenDbConnection("Server=db;Username=postgres;Password=postgres;");
```

Worker искал сервис с именем **`db`**, но в `docker-compose.yml` сервис назывался **`postgres-db`**. Имена не совпадали, поэтому worker не мог найти базу данных.

### Решение:

Было принято **переименовать сервис в `docker-compose.yml` с `postgres-db` на `db`**:

```yaml
# Было
services:
  postgres-db:
    image: postgres:15-alpine
    ...

# Стало
services:
  db:
    image: postgres:15-alpine
    container_name: postgres-db  # имя контейнера оставлено прежним
    ...
```

Worker также зависит от сервиса `db`:

```yaml
worker:
  depends_on:
    db:
      condition: service_healthy
```

### Результат:

После исправления worker успешно подключился к базе данных:

```bash
elv@deploy-server:~$ docker logs worker --tail 50
Connected to db
Connecting to redis
Found redis at 172.18.0.2
```

---

## 5. .gitlab-ci.yml

```yaml
stages:
  - build
  - push
  - deploy

variables:
  IMAGE_TAG: $CI_COMMIT_SHORT_SHA
  IMAGE_NAME_VOTE: $CI_REGISTRY/devops/devops-2026-03/example-voting-app/voting-app
  IMAGE_NAME_RESULT: $CI_REGISTRY/devops/devops-2026-03/example-voting-app/result-app
  IMAGE_NAME_WORKER: $CI_REGISTRY/devops/devops-2026-03/example-voting-app/worker-app

# ============================================
# CI: Сборка Docker-образов
# ============================================

build_vote:
  stage: build
  script:
    - docker build -t $IMAGE_NAME_VOTE:$IMAGE_TAG ./vote
    - docker build -t $IMAGE_NAME_VOTE:latest ./vote
  tags:
    - docker
  only:
    - main

build_result:
  stage: build
  script:
    - docker build -t $IMAGE_NAME_RESULT:$IMAGE_TAG ./result
    - docker build -t $IMAGE_NAME_RESULT:latest ./result
  tags:
    - docker
  only:
    - main

build_worker:
  stage: build
  script:
    - |
      docker build \
        --build-arg BUILDPLATFORM=linux/amd64 \
        --build-arg TARGETPLATFORM=linux/amd64 \
        --build-arg TARGETARCH=amd64 \
        -t $IMAGE_NAME_WORKER:$IMAGE_TAG ./worker
    - |
      docker build \
        --build-arg BUILDPLATFORM=linux/amd64 \
        --build-arg TARGETPLATFORM=linux/amd64 \
        --build-arg TARGETARCH=amd64 \
        -t $IMAGE_NAME_WORKER:latest ./worker
  tags:
    - docker
  only:
    - main

# ============================================
# CD: Публикация образов в Registry
# ============================================

push_vote:
  stage: push
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin
  script:
    - docker push $IMAGE_NAME_VOTE:$IMAGE_TAG
    - docker push $IMAGE_NAME_VOTE:latest
  tags:
    - docker
  only:
    - main
  needs:
    - build_vote

push_result:
  stage: push
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin
  script:
    - docker push $IMAGE_NAME_RESULT:$IMAGE_TAG
    - docker push $IMAGE_NAME_RESULT:latest
  tags:
    - docker
  only:
    - main
  needs:
    - build_result

push_worker:
  stage: push
  before_script:
    - echo "$CI_REGISTRY_PASSWORD" | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin
  script:
    - docker push $IMAGE_NAME_WORKER:$IMAGE_TAG
    - docker push $IMAGE_NAME_WORKER:latest
  tags:
    - docker
  only:
    - main
  needs:
    - build_worker

# ============================================
# CD: Деплой на Yandex Cloud
# ============================================

deploy:
  stage: deploy
  before_script:
    - sudo apt-get update -qq && sudo apt-get install -y -qq openssh-client rsync
    - eval $(ssh-agent -s)
    - echo "$VM_SSH_KEY" | tr -d '\r' | ssh-add - > /dev/null
    - mkdir -p ~/.ssh
    - chmod 700 ~/.ssh
    - ssh-keyscan -H $VM_IP >> ~/.ssh/known_hosts
  script:
    - scp -o StrictHostKeyChecking=no docker-compose.yml $VM_USER@$VM_IP:~/
    - ssh -o StrictHostKeyChecking=no $VM_USER@$VM_IP "
        echo '$CI_REGISTRY_PASSWORD' | docker login $CI_REGISTRY -u $CI_REGISTRY_USER --password-stdin 2>/dev/null &&
        export CI_REGISTRY='$CI_REGISTRY' &&
        export CI_REGISTRY_USER='$CI_REGISTRY_USER' &&
        docker compose down 2>/dev/null || true &&
        docker compose pull &&
        docker compose up -d &&
        docker compose ps
      "
  tags:
    - docker
  only:
    - main
  needs:
    - push_vote
    - push_result
    - push_worker
```

---

## 6. Docker-compose.yml для деплоя

```yaml
networks:
  voting-network:
    driver: bridge

volumes:
  postgres-data:
  redis-data:

services:
  db:
    image: postgres:15-alpine
    container_name: postgres-db
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: postgres
    volumes:
      - postgres-data:/var/lib/postgresql/data
    networks:
      - voting-network
    restart: always
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "postgres"]
      interval: 10s
      timeout: 5s
      retries: 10

  redis:
    image: redis:alpine
    container_name: redis
    volumes:
      - redis-data:/data
    networks:
      - voting-network
    restart: always
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 10

  voting-app:
    image: ${CI_REGISTRY}/devops/devops-2026-03/example-voting-app/voting-app:latest
    container_name: voting-app
    ports:
      - "8080:80"
    networks:
      - voting-network
    depends_on:
      redis:
        condition: service_healthy
    restart: always

  worker:
    image: ${CI_REGISTRY}/devops/devops-2026-03/example-voting-app/worker-app:latest
    container_name: worker
    networks:
      - voting-network
    depends_on:
      db:
        condition: service_healthy
    restart: always

  result-app:
    image: ${CI_REGISTRY}/devops/devops-2026-03/example-voting-app/result-app:latest
    container_name: result-app
    ports:
      - "8081:80"
    networks:
      - voting-network
    depends_on:
      db:
        condition: service_healthy
    restart: always
```

---

## 7. Идемпотентность сборки и деплоя

### 7.1 Идемпотентность CI (сборка)

- Образы тегируются как `$CI_COMMIT_SHORT_SHA` и `latest`
- При повторном запуске с тем же коммитом — пересборка происходит заново
- Используется кэширование Docker-слоев

### 7.2 Идемпотентность CD (деплой)

```bash
# Остановка старых контейнеров (не падает, если контейнеров нет)
docker compose down 2>/dev/null || true

# Pull свежих образов (только если есть изменения)
docker compose pull

# Запуск (создаст новые контейнеры, если их нет)
docker compose up -d
```

**Результат при повторном запуске:**
- Контейнеры пересоздаются только при изменении образов
- Volumes сохраняются (данные не теряются)
- Сеть пересоздается только при необходимости

---

## 8. Запуск pipeline

### 8.1 Успешный запуск

![Pipeline Success](pipeline.png)

### 8.2 Результат деплоя на ВМ

```bash
elv@deploy-server:~$ docker compose ps
NAME          IMAGE                                                                                             COMMAND                  SERVICE      STATUS                    PORTS
postgres-db   postgres:15-alpine                                                                                "docker-entrypoint.s…"   db           Up (healthy)               5432/tcp
redis         redis:alpine                                                                                      "docker-entrypoint.s…"   redis        Up (healthy)               6379/tcp
result-app    otusteam.gitlab.yandexcloud.net:5050/devops/devops-2026-03/example-voting-app/result-app:latest   "/usr/bin/tini -- no…"   result-app   Up                         0.0.0.0:8081->80/tcp
voting-app    otusteam.gitlab.yandexcloud.net:5050/devops/devops-2026-03/example-voting-app/voting-app:latest   "gunicorn app:app -b…"   voting-app   Up                         0.0.0.0:8080->80/tcp
worker        otusteam.gitlab.yandexcloud.net:5050/devops/devops-2026-03/example-voting-app/worker-app:latest   "dotnet Worker.dll"      worker       Up
```

### 8.3 Логи worker (успешное подключение)

```bash
elv@deploy-server:~$ docker logs worker --tail 50
Connected to db
Connecting to redis
Found redis at 172.18.0.2
```

---

## 9. Доступ к приложению

- **Приложение для голосования:** `http://81.26.191.124:8080`
- **Приложение для результатов:** `http://81.26.191.124:8081`

**Скриншот: Voting App**

![Voting App](app-vote.png)

**Скриншот: Result App**

![Result App](app-result.png)

---

## 10. Полная структура репозитория

```
example-voting-app/
├── .gitlab-ci.yml          # CI/CD pipeline
├── docker-compose.yml      # Docker Compose для деплоя
├── vote/
│   └── Dockerfile
├── result/
│   └── Dockerfile
├── worker/
│   └── Dockerfile          # Исправлен (убрана платформа)
└── README.md
```

---

## Выводы

1. ✅ Написан GitLab CI/CD pipeline для сборки приложения
2. ✅ Реализована публикация образов в GitLab Registry
3. ✅ Настроен автоматический деплой на ВМ в Yandex Cloud
4. ✅ Обеспечена идемпотентность сборки и деплоя
5. ✅ Использованы переменные окружения для защиты секретов
6. ✅ Исправлен worker/Dockerfile (убрана проблемная платформа)
7. ✅ Обнаружена и исправлена проблема с подключением worker к PostgreSQL (несовпадение имен сервисов)
8. ✅ Приложение доступно по публичному IP