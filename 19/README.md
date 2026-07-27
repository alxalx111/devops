# Домашнее задание: Деплой через Ansible

## Выполненные работы

### 1. Настройка инфраструктуры
- Созданы 4 виртуальные машины в VirtualBox:
  - `deb13` - управляющая нода (Ansible)
  - `master` - control-plane k3s
  - `worker1`, `worker2` - worker ноды k3s
- Настроена внутренняя сеть `internal-network` с IP 10.10.10.0/24
- На всех ВМ настроены статические IP через systemd-networkd

### 2. Создана структура Ansible-репозитория
```
infra-ansible/
├── ansible.cfg
├── group_vars/
│   ├── staging/
│   │   └── all.yml
│   └── production/
│       └── all.yml
├── inventory/
│   ├── staging/
│   │   └── hosts.yml
│   └── production/
│       └── hosts.yml
├── playbooks/
│   ├── site.yml
│   └── deploy-app.yml
└── roles/
    ├── common/
    ├── k3s/
    └── voting-app/
```

### 3. Настроены инвентарные файлы
- `inventory/staging/hosts.yml` - для staging окружения
- `inventory/production/hosts.yml` - для production окружения
- В инвентаре указаны IP, пользователь, SSH ключ для всех нод

### 4. Настроены переменные окружений
- `group_vars/staging/all.yml` - переменные для staging
- `group_vars/production/all.yml` - переменные для production
- Включают: версию k3s, токен, пути к чарту, домен и т.д.

### 5. Созданы роли

#### Роль `common`
- Обновление apt
- Установка базовых пакетов
- Отключение swap
- Загрузка модулей ядра
- Настройка sysctl
- Установка containerd

#### Роль `k3s`
- Установка k3s на master ноду
- Установка k3s-agent на worker ноды
- Настройка kubeconfig
- Передача токена между нодами

#### Роль `voting-app`
- Установка Helm
- Создание PVC для PostgreSQL и Redis
- Создание секрета для GitLab Container Registry
- Настройка containerd для авторизации в GitLab Registry
- Деплой приложения через Helm
- Настройка Ingress (Traefik)

### 6. Созданы плейбуки
- `playbooks/site.yml` - полная настройка кластера (common + k3s + voting-app)
- `playbooks/deploy-app.yml` - только деплой приложения

### 7. Настройка доступа к приложению
- Использован Traefik как Ingress Controller (встроен в k3s)
- Созданы Ingress для vote и result сервисов
- Проброшены порты через NAT на хосте Windows
- Настроены маршруты между нодами для pod сети

## Проблемы и решения

### Проблема 1: Helm не видит переменные из group_vars
**Решение:** Переменные были перемещены в инвентарный файл, так как Ansible не применял group_vars.

### Проблема 2: Чарт отсутствует на мастер-ноде
**Решение:** Использован модуль `synchronize` для копирования чарта с control node на master.

### Проблема 3: 403 Forbidden при pull образов из GitLab Registry
**Решение:** 
- Создан секрет `gitlab-registry` с правильными credentials
- Добавлен `imagePullSecrets` в ServiceAccount default
- Настроен containerd на всех нодах для авторизации в registry

### Проблема 4: Поды не запускаются из-за отсутствия PVC
**Решение:** Добавлено создание PVC для PostgreSQL и Redis перед деплоем Helm чарта.

### Проблема 5: Маршруты между нодами
**Проблема:** При установке k3s flannel использовал интерфейс enp0s3 (NAT) вместо enp0s8 (Internal Network).
**Решение:** Временно исправлены маршруты на всех нодах через `ip route add/del`.
**TODO:** Добавить `--flannel-iface=enp0s8` в установку k3s.

### Проблема 6: Ingress не работал с nginx
**Решение:** Переключен на Traefik (уже установлен в k3s по умолчанию).

### Проблема 7: TLS сертификаты
**Проблема:** Секреты для TLS не были созданы.
**Решение:** Отключен TLS в Ingress (временно).
**TODO:** Настроить cert-manager для автоматического получения сертификатов.

## Текущий статус

✅ **Приложение работает на staging окружении:**

- Все поды в статусе Running
- Доступ через Traefik на порту 32679
- URL: `http://staging.vote.ddgames.ru:32679` и `http://staging.result.ddgames.ru:32679`

## TODO (что нужно доделать)

### 1. Исправить сеть (flannel)
- [ ] Добавить `--flannel-iface=enp0s8` в установку k3s
- [ ] Переустановить k3s на всех нодах
- [ ] Убрать костыли с ручным исправлением маршрутов

### 2. Настроить TLS
- [ ] Установить cert-manager
- [ ] Создать ClusterIssuer (letsencrypt-prod)
- [ ] Включить TLS в Ingress

### 3. Production окружение
- [ ] Настроить отдельный инвентарь `inventory/production/hosts.yml`
- [ ] Настроить групповые переменные для production

### 4. Документация
- [ ] Дополнить README.md
- [ ] Описать процесс деплоя
- [ ] Описать процесс обновления приложения

## Как запустить

### Полная установка кластера:
```bash
cd ~/dev/infra-ansible
ansible-playbook -i inventory/staging/hosts.yml playbooks/site.yml
```

### Только деплой приложения:
```bash
cd ~/dev/infra-ansible
ansible-playbook -i inventory/staging/hosts.yml playbooks/deploy-app.yml
```

## Полезные команды

### Проверка статуса кластера:
```bash
kubectl get nodes -o wide
kubectl get pods -n default
kubectl get svc -n default
kubectl get ingress -n default
```

### Проверка логов:
```bash
kubectl logs -n default deployment/vote
kubectl logs -n kube-system deployment/traefik
```

### Проверка маршрутов:
```bash
ip route | grep 10.42
```

## Используемые технологии

- **Ansible** - автоматизация конфигурации
- **K3s** - легковесный Kubernetes
- **Flannel** - сетевой overlay
- **Traefik** - Ingress Controller
- **Helm** - управление приложениями в Kubernetes
- **VirtualBox** - виртуализация
- **GitLab Registry** - хранение Docker образов

