# Домашнее задание: Автоматизация создания инфраструктуры в Yandex.Cloud

## Цель работы

Научиться инициализировать pipeline для деплоя тестового приложения и писать bash-скрипты для автоматизации задач настройки VM и деплоя приложения.

## Выполненные задачи

1. Разработан bash-скрипт для автоматического создания инфраструктуры в Yandex.Cloud
2. Создана инфраструктура из 3 виртуальных машин:
   - **bastion** — с публичным IP-адресом
   - **vm1** и **vm2** — только с локальными адресами
3. Настроен доступ к приватным ВМ через bastion-хост с использованием SSH-агента

## Используемые инструменты

- Yandex Cloud CLI (yc)
- Bash
- SSH

## Скрипт автоматизации

Скрипт `create-infra.sh` выполняет следующие действия:

1. Создает каталог `dz03`
2. Создает сеть `localnet` и подсеть `subnet-10` с диапазоном `10.10.10.0/24`
3. Создает 3 ВМ с параметрами:
   - Платформа: `standard-v4a`
   - vCPU: 2, RAM: 2 ГБ
   - Диск: 15 ГБ (network-ssd)
   - Прерываемая ВМ: да
4. Настраивает ssh-agent на bastion
5. Копирует приватный ключ на bastion для доступа к приватным ВМ

### Содержимое скрипта `create-infra.sh`

```bash
#!/bin/bash

set -e  # Останавливаем скрипт при любой ошибке

# Цвета для вывода
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Создание инфраструктуры в Yandex Cloud ===${NC}"

# 1. Создание каталога
echo -e "${GREEN}1. Создаю каталог dz03...${NC}"
yc resource-manager folder create --name dz03

# 2. Получение ID каталога и установка
echo -e "${GREEN}2. Устанавливаю каталог по умолчанию...${NC}"
FOLDER_ID=$(yc resource-manager folder get dz03 --format yaml | grep "^id:" | awk '{print $2}')
yc config set folder-id $FOLDER_ID
echo -e "${GREEN}   Каталог ID: $FOLDER_ID${NC}"

# 3. Создание сети
echo -e "${GREEN}3. Создаю сеть localnet...${NC}"
yc vpc network create localnet

# 4. Создание подсети
echo -e "${GREEN}4. Создаю подсеть subnet-10...${NC}"
yc vpc subnet create subnet-10 \
  --network-name localnet \
  --zone ru-central1-d \
  --range 10.10.10.0/24

# Получаем subnet-id
SUBNET_ID=$(yc vpc subnet get subnet-10 --format yaml | grep "^id:" | awk '{print $2}')
echo -e "${GREEN}   Subnet ID: $SUBNET_ID${NC}"

# 5. Создание bastion
echo -e "${GREEN}5. Создаю bastion...${NC}"
yc compute instance create \
  --name bastion \
  --hostname bastion \
  --zone ru-central1-d \
  --platform standard-v4a \
  --memory 2 \
  --cores 2 \
  --core-fraction 20 \
  --create-boot-disk name=disk-bastion,type=network-ssd,size=15,image-id=fd8cdbtd9eepnmm4gpne \
  --network-interface subnet-id=$SUBNET_ID,nat-ip-version=ipv4,address=10.10.10.254 \
  --preemptible=true \
  --ssh-key ~/.ssh/id_ed25519_otus_yc.pub

# 6. Создание vm1
echo -e "${GREEN}6. Создаю vm1...${NC}"
yc compute instance create \
  --name vm1 \
  --hostname vm1 \
  --zone ru-central1-d \
  --platform standard-v4a \
  --memory 2 \
  --cores 2 \
  --core-fraction 20 \
  --create-boot-disk name=disk-vm1,type=network-ssd,size=15,image-id=fd8cdbtd9eepnmm4gpne \
  --network-interface subnet-id=$SUBNET_ID,address=10.10.10.11 \
  --preemptible=true \
  --ssh-key ~/.ssh/id_ed25519_otus_yc.pub

# 7. Создание vm2
echo -e "${GREEN}7. Создаю vm2...${NC}"
yc compute instance create \
  --name vm2 \
  --hostname vm2 \
  --zone ru-central1-d \
  --platform standard-v4a \
  --memory 2 \
  --cores 2 \
  --core-fraction 20 \
  --create-boot-disk name=disk-vm2,type=network-ssd,size=15,image-id=fd8cdbtd9eepnmm4gpne \
  --network-interface subnet-id=$SUBNET_ID,address=10.10.10.12 \
  --preemptible=true \
  --ssh-key ~/.ssh/id_ed25519_otus_yc.pub

# 8. Получение внешнего IP bastion
echo -e "${GREEN}8. Получаю внешний IP bastion...${NC}"
BASTION_IP=$(yc compute instance get bastion --format yaml | grep -A 3 "one_to_one_nat:" | grep "address:" | awk '{print $2}')
echo -e "${GREEN}   Bastion IP: $BASTION_IP${NC}"

# 9. Настройка ssh-agent на bastion
echo -e "${GREEN}9. Настраиваю ssh-agent на bastion...${NC}"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519_otus_yc yc-user@$BASTION_IP "cat >> ~/.bashrc << 'EOF'
# Запуск ssh-agent
if [ -z \"\$SSH_AUTH_SOCK\" ]; then
    eval \"\$(ssh-agent)\" > /dev/null 2>&1
fi
# Добавление ключа
ssh-add ~/.ssh/id_ed25519_otus_yc 2> /dev/null
EOF"

# 10. Копируем приватный ключ на bastion (нужен для подключения к vm1/vm2)
echo -e "${GREEN}10. Копирую приватный ключ на bastion...${NC}"
cat ~/.ssh/id_ed25519_otus_yc | ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519_otus_yc yc-user@$BASTION_IP "cat > ~/.ssh/id_ed25519_otus_yc && chmod 600 ~/.ssh/id_ed25519_otus_yc"

echo -e "${GREEN}=== Инфраструктура создана успешно! ===${NC}"
echo -e "${GREEN}Подключение: ssh -i ~/.ssh/id_ed25519_otus_yc yc-user@$BASTION_IP${NC}"
echo -e "${GREEN}На bastion: ssh 10.10.10.11 или ssh 10.10.10.12${NC}"
```

## Результаты выполнения

### Скриншоты

| № | Описание | Скриншот |
|---|----------|----------|
| 1 | Создание каталога `dz03` | [1.png](1.png) |
| 2 | Создание ВМ `bastion` с публичным IP 81.26.177.148 | [2.png](2.png) |
| 3 | Создание ВМ `vm1` с внутренним IP 10.10.10.11 | [3.png](3.png) |
| 4 | Создание ВМ `vm2` с внутренним IP 10.10.10.12 | [4.png](4.png) |
| 5 | Получение внешнего IP bastion и настройка ssh-agent | [5.png](5.png) |
| 6 | Финальный список ВМ в веб-консоли YC | [dz03.png](dz03.png) |

### Лог выполнения

Полный лог работы скрипта: [run.log](run.log)

### Итоговый список ВМ

```
+----------------------+---------+---------------+---------+---------------+--------------+
|          ID          |  NAME   |    ZONE ID    | STATUS  |  EXTERNAL IP  | INTERNAL IP  |
+----------------------+---------+---------------+---------+---------------+--------------+
| fv46idjf77dsgchgnupd | bastion | ru-central1-d | RUNNING | 81.26.177.148 | 10.10.10.254 |
| fv4qsptokjiqlm7uec00 | vm1     | ru-central1-d | RUNNING |               | 10.10.10.11  |
| fv4hl4jee48eci0g3ojh | vm2     | ru-central1-d | RUNNING |               | 10.10.10.12  |
+----------------------+---------+---------------+---------+---------------+--------------+
```

## Подключение к инфраструктуре

### 1. Подключение к bastion

```bash
ssh -i ~/.ssh/id_ed25519_otus_yc yc-user@81.26.177.148
```

### 2. Подключение к приватным ВМ с bastion

```bash
# На bastion
ssh 10.10.10.11   # vm1
ssh 10.10.10.12   # vm2
```

## Структура инфраструктуры

```
Интернет
   |
[Локальная машина] ---ssh---> [Bastion] (81.26.177.148)
                      |
                      |---ssh---> [vm1] (10.10.10.11)
                      |
                      |---ssh---> [vm2] (10.10.10.12)
```

## Выводы

В ходе выполнения домашнего задания:

1. Создан bash-скрипт для автоматизации развертывания инфраструктуры в Yandex.Cloud
2. Скрипт создает 3 ВМ с заданными параметрами
3. Настроен безопасный доступ к приватным ВМ через bastion-хост
4. SSH-агент настроен на автоматический запуск и добавление ключа при входе на bastion

Инфраструктура готова для дальнейшего деплоя тестового приложения.
