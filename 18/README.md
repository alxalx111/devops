# Домашнее задание: Настройка окружения через Ansible

## Цель работы
Познакомиться с системой управления конфигурацией Ansible; реализовать Ansible-playbook для конфигурирования окружения приложения.

---

## Описание/Пошаговая инструкция выполнения домашнего задания

1. Написать Ansible-playbook для настройки окружения в ВМ Yandex.Cloud (установка пакетов, зависимостей и т.д.).  
   ***В данной работе делаем в виртуальной лабораторной среде VirtualBox.***

2. Все конфигурации должны быть в репозитории с приложением.

3. Приложить логи запуска Ansible playbook.

---

## Выполнение работы

### 1. Подготовка виртуальной лабораторной среды

Для выполнения работы была создана лабораторная среда на основе VirtualBox с четырьмя виртуальными машинами на базе Debian 13:

| ВМ | Роль | Внутренний IP |
|----|------|---------------|
| `ansible` | Управляющая (control node) | 10.10.10.100 |
| `master` | Управляемая (managed node) | 10.10.10.10 |
| `worker1` | Управляемая (managed node) | 10.10.10.11 |
| `worker2` | Управляемая (managed node) | 10.10.10.12 |

### 2. Настройка VirtualBox

#### 2.1. Клонирование шаблонной ВМ

Из шаблонной ВМ с Debian 13 были созданы клоны:
- `ansible`
- `master`
- `worker1`
- `worker2`

#### 2.2. Настройка внутренней сети

Для всех ВМ был добавлен второй сетевой интерфейс в Internal Network с именем `internal-network` и заданы MAC-адреса:

```bash
VBoxManage modifyvm "ansible" --nic2 intnet --intnet2 internal-network --macaddress2 aabbcc0000ff
VBoxManage modifyvm "master" --nic2 intnet --intnet2 internal-network --macaddress2 aabbcc000000
VBoxManage modifyvm "worker1" --nic2 intnet --intnet2 internal-network --macaddress2 aabbcc000001
VBoxManage modifyvm "worker2" --nic2 intnet --intnet2 internal-network --macaddress2 aabbcc000002
```

#### 2.3. Настройка проброса портов для SSH

Для доступа к ВМ с хоста настроен проброс портов:

| ВМ | Порт на хосте | Порт в ВМ |
|----|---------------|-----------|
| ansible | 2022 | 22 |
| master | 2030 | 22 |
| worker1 | 2031 | 22 |
| worker2 | 2032 | 22 |

```bash
VBoxManage modifyvm "ansible" --natpf1 "ssh,tcp,,2022,,22"
VBoxManage modifyvm "master" --natpf1 "ssh,tcp,,2030,,22"
VBoxManage modifyvm "worker1" --natpf1 "ssh,tcp,,2031,,22"
VBoxManage modifyvm "worker2" --natpf1 "ssh,tcp,,2032,,22"
```

#### 2.4. Запуск ВМ

```bash
VBoxManage startvm "ansible" --type headless
VBoxManage startvm "master" --type headless
VBoxManage startvm "worker1" --type headless
VBoxManage startvm "worker2" --type headless
```

### 3. Настройка статических IP-адресов

На всех ВМ настроены статические IP-адреса на интерфейсе `enp0s8` через **systemd-networkd**.  
Для обеспечения автоматического применения настроек после перезагрузки включена и запущена служба `systemd-networkd` перед созданием конфигураций.

#### 3.1. На ansible:

```bash
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd

sudo tee /etc/systemd/network/20-enp0s8.network <<EOF
[Match]
Name=enp0s8

[Network]
Address=10.10.10.100/24
EOF

sudo systemctl restart systemd-networkd
sudo ip link set enp0s8 up
```

#### 3.2. На master:

```bash
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd

sudo tee /etc/systemd/network/20-enp0s8.network <<EOF
[Match]
Name=enp0s8

[Network]
Address=10.10.10.10/24
EOF

sudo systemctl restart systemd-networkd
sudo ip link set enp0s8 up
```

#### 3.3. На worker1:

```bash
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd

sudo tee /etc/systemd/network/20-enp0s8.network <<EOF
[Match]
Name=enp0s8

[Network]
Address=10.10.10.11/24
EOF

sudo systemctl restart systemd-networkd
sudo ip link set enp0s8 up
```

#### 3.4. На worker2:

```bash
sudo systemctl enable systemd-networkd
sudo systemctl start systemd-networkd

sudo tee /etc/systemd/network/20-enp0s8.network <<EOF
[Match]
Name=enp0s8

[Network]
Address=10.10.10.12/24
EOF

sudo systemctl restart systemd-networkd
sudo ip link set enp0s8 up
```

### 4. Проверка связности между ВМ

```bash
# На ansible
ping -c 3 10.10.10.10    # master
ping -c 3 10.10.10.11    # worker1
ping -c 3 10.10.10.12    # worker2
```

### 5. Настройка SSH-доступа

#### 5.1. Создание SSH-ключа на ВМ ansible

```bash
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa_ansible
```

#### 5.2. Копирование ключа на управляемые ВМ

```bash
ssh-copy-id -i ~/.ssh/id_rsa_ansible.pub elv@10.10.10.10   # master
ssh-copy-id -i ~/.ssh/id_rsa_ansible.pub elv@10.10.10.11   # worker1
ssh-copy-id -i ~/.ssh/id_rsa_ansible.pub elv@10.10.10.12   # worker2
```

### 6. Настройка sudo без пароля на целевых ВМ

Для корректной работы Ansible с привилегиями (`become: yes`) необходимо настроить `sudo` без пароля для пользователя `elv` на каждой целевой ВМ (`master`, `worker1`, `worker2`).

**На каждой ВМ выполните:**

```bash
echo "elv ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/elv
```

### 7. Установка Ansible на ВМ ansible

```bash
sudo apt update
sudo apt install -y ansible
ansible --version
```

### 8. Настройка Ansible для подавления предупреждений

Для подавления предупреждений о выборе интерпретатора Python создан файл `ansible.cfg`:

```bash
cat ansible.cfg
[defaults]
interpreter_python = auto_silent
```

### 9. Создание инвентарного файла

На ВМ `ansible` создан файл `~/infra/hosts.yml`:

```yaml
all:
  hosts:
    master:
      ansible_host: 10.10.10.10
      ansible_user: elv
      ansible_ssh_private_key_file: ~/.ssh/id_rsa_ansible
      ansible_become: yes
    worker1:
      ansible_host: 10.10.10.11
      ansible_user: elv
      ansible_ssh_private_key_file: ~/.ssh/id_rsa_ansible
      ansible_become: yes
    worker2:
      ansible_host: 10.10.10.12
      ansible_user: elv
      ansible_ssh_private_key_file: ~/.ssh/id_rsa_ansible
      ansible_become: yes
```

### 10. Проверка подключения

```bash
ansible -i ~/infra/hosts.yml all -m ping --become
```

**Результат:**

```
master | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
worker1 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
worker2 | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.13"
    },
    "changed": false,
    "ping": "pong"
}
```

### 11. Ansible-playbook для развертывания k3s

#### Полный код плейбука `playbooks/k3s-cluster.yml`

```yaml
---
- name: Подготовка всех ВМ
  hosts: all
  become: yes
  gather_facts: yes

  tasks:
    - name: Устанавливаем hostname
      hostname:
        name: "{{ inventory_hostname }}"

    - name: Добавляем hostname в /etc/hosts
      lineinfile:
        path: /etc/hosts
        regexp: '127\.0\.1\.1'
        line: "127.0.1.1 {{ inventory_hostname }}"

    - name: Обновляем apt
      apt:
        update_cache: yes
        cache_valid_time: 3600

    - name: Устанавливаем базовые пакеты
      apt:
        name:
          - git
          - htop
          - gnupg
          - lsb-release
          - ca-certificates
        state: present

    - name: Отключаем swap
      command: swapoff -a
      when: ansible_swaptotal_mb > 0

    - name: Удаляем swap из fstab
      lineinfile:
        path: /etc/fstab
        regexp: 'swap'
        state: absent
      when: ansible_swaptotal_mb > 0

    - name: Загружаем модули ядра
      modprobe:
        name: "{{ item }}"
        state: present
      loop:
        - br_netfilter
        - overlay

    - name: Настраиваем sysctl
      sysctl:
        name: "{{ item.name }}"
        value: "{{ item.value }}"
        state: present
        reload: yes
      loop:
        - { name: net.bridge.bridge-nf-call-iptables, value: 1 }
        - { name: net.ipv4.ip_forward, value: 1 }

    - name: Устанавливаем containerd
      shell: |
        curl -fsSL https://get.docker.com | sh
      args:
        creates: /usr/bin/docker

    - name: Добавляем пользователя в docker
      user:
        name: elv
        groups: docker
        append: yes

- name: Установка k3s server (master)
  hosts: master
  become: yes

  tasks:
    - name: Устанавливаем k3s server
      shell: |
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION={{ k3s_version }} \
          K3S_TOKEN={{ k3s_token }} \
          INSTALL_K3S_EXEC="server \
            --flannel-backend=host-gw \
            --node-ip={{ ansible_host }} \
            --cluster-cidr=10.42.0.0/16 \
            --service-cidr=10.43.0.0/16 \
            --cluster-domain=cluster.local" \
          sh -
      args:
        creates: /usr/local/bin/k3s

    - name: Создаем .kube для пользователя
      file:
        path: /home/elv/.kube
        state: directory
        owner: elv
        group: elv
        mode: 0755

    - name: Копируем kubeconfig
      copy:
        src: /etc/rancher/k3s/k3s.yaml
        dest: /home/elv/.kube/config
        owner: elv
        group: elv
        mode: 0644
        remote_src: yes

    - name: Получаем токен для воркеров
      slurp:
        src: /var/lib/rancher/k3s/server/node-token
      register: node_token

    - name: Сохраняем токен в файл
      copy:
        content: "{{ node_token.content | b64decode }}"
        dest: /tmp/node-token
        owner: elv
        group: elv
        mode: 0644

- name: Установка k3s agent (worker1, worker2)
  hosts: worker1, worker2
  become: yes

  tasks:
    - name: Получаем токен с мастера
      slurp:
        src: /tmp/node-token
      delegate_to: master
      register: node_token

    - name: Устанавливаем k3s agent
      shell: |
        curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION={{ k3s_version }} \
          K3S_URL=https://{{ hostvars['master']['ansible_host'] }}:6443 \
          K3S_TOKEN={{ node_token.content | b64decode | trim }} \
          INSTALL_K3S_EXEC="agent \
            --node-ip={{ ansible_host }}" \
          sh -
      args:
        creates: /usr/local/bin/k3s

- name: Проверка кластера
  hosts: master
  become: yes

  tasks:
    - name: Ждём, пока все ноды присоединятся
      command: kubectl get nodes
      register: kubectl_result
      until: '"worker1" in kubectl_result.stdout and "worker2" in kubectl_result.stdout'
      retries: 30
      delay: 10

    - name: Показываем ноды
      command: kubectl get nodes -o wide
      register: nodes_status

    - name: Выводим статус нод
      debug:
        msg: "{{ nodes_status.stdout_lines }}"
```

#### Объяснение структуры плейбука

Плейбук состоит из 4 логических блоков и разворачивает полноценный k3s-кластер.

---

##### Блок 1: Подготовка всех ВМ (master, worker1, worker2)

**1.1. Установка hostname**

```yaml
- name: Устанавливаем hostname
  hostname:
    name: "{{ inventory_hostname }}"
```

**Что делает:** Устанавливает имя хоста (`master`, `worker1`, `worker2`) на каждой ВМ.  
**Зачем:** Чтобы в кластере узлы назывались понятно, а не `debian-13`.

---

**1.2. Добавление hostname в /etc/hosts**

```yaml
- name: Добавляем hostname в /etc/hosts
  lineinfile:
    path: /etc/hosts
    regexp: '127\.0\.1\.1'
    line: "127.0.1.1 {{ inventory_hostname }}"
```

**Что делает:** Добавляет запись в `/etc/hosts`.  
**Зачем:** Некоторые приложения (включая k3s) используют `/etc/hosts` для определения имени узла. Без этого могут быть ошибки.

---

**1.3. Обновление apt**

```yaml
- name: Обновляем apt
  apt:
    update_cache: yes
    cache_valid_time: 3600
```

**Что делает:** Обновляет список пакетов.  
**Зачем:** Чтобы устанавливать свежие версии пакетов.

---

**1.4. Установка базовых пакетов**

```yaml
- name: Устанавливаем базовые пакеты
  apt:
    name:
      - git
      - htop
      - gnupg
      - lsb-release
      - ca-certificates
    state: present
```

**Что делает:** Устанавливает утилиты.  
**Зачем:**
- `git` — для клонирования репозиториев
- `htop` — для просмотра процессов
- `gnupg`, `lsb-release`, `ca-certificates` — для безопасного подключения к репозиториям

---

**1.5. Отключение swap**

```yaml
- name: Отключаем swap
  command: swapoff -a
  when: ansible_swaptotal_mb > 0

- name: Удаляем swap из fstab
  lineinfile:
    path: /etc/fstab
    regexp: 'swap'
    state: absent
  when: ansible_swaptotal_mb > 0
```

**Что делает:** Отключает swap (временно и навсегда).  
**Зачем:** Kubernetes требует, чтобы swap был выключен.

---

**1.6. Загрузка модулей ядра**

```yaml
- name: Загружаем модули ядра
  modprobe:
    name: "{{ item }}"
    state: present
  loop:
    - br_netfilter
    - overlay
```

**Что делает:** Загружает модули ядра.  
**Зачем:**
- `br_netfilter` — позволяет iptables видеть трафик на bridge-сетях (нужно для сети подов)
- `overlay` — нужен для работы Docker/containerd (хранение образов)

---

**1.7. Настройка sysctl**

```yaml
- name: Настраиваем sysctl
  sysctl:
    name: "{{ item.name }}"
    value: "{{ item.value }}"
    state: present
    reload: yes
  loop:
    - { name: net.bridge.bridge-nf-call-iptables, value: 1 }
    - { name: net.ipv4.ip_forward, value: 1 }
```

**Что делает:** Включает параметры ядра.  
**Зачем:**
- `net.bridge.bridge-nf-call-iptables = 1` — iptables видит трафик на bridge
- `net.ipv4.ip_forward = 1` — разрешает маршрутизацию пакетов между интерфейсами (нужно для Kubernetes)

---

**1.8. Установка Docker (containerd)**

```yaml
- name: Устанавливаем containerd
  shell: |
    curl -fsSL https://get.docker.com | sh
  args:
    creates: /usr/bin/docker
```

**Что делает:** Устанавливает Docker.  
**Зачем:** k3s по умолчанию использует containerd, но Docker удобен для работы с образами.

---

**1.9. Добавление пользователя в docker**

```yaml
- name: Добавляем пользователя в docker
  user:
    name: elv
    groups: docker
    append: yes
```

**Что делает:** Добавляет пользователя `elv` в группу `docker`.  
**Зачем:** Чтобы запускать `docker` команды без `sudo`.

---

##### Блок 2: Установка k3s на master

**2.1. Установка k3s server**

```yaml
- name: Устанавливаем k3s server
  shell: |
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION={{ k3s_version }} \
      K3S_TOKEN={{ k3s_token }} \
      INSTALL_K3S_EXEC="server \
        --flannel-backend=host-gw \
        --node-ip={{ ansible_host }} \
        --cluster-cidr=10.42.0.0/16 \
        --service-cidr=10.43.0.0/16 \
        --cluster-domain=cluster.local" \
      sh -
  args:
    creates: /usr/local/bin/k3s
```

**Что делает:**  
Устанавливает k3s в режиме **server** (control-plane) на ВМ `master`.

**Подробности выполнения:**

| Что происходит | Описание |
|----------------|----------|
| **Установка бинарника** | Файл `/usr/local/bin/k3s` появляется на системе |
| **Systemd-сервис** | Создаётся и запускается `k3s.service` |
| **Автозапуск** | Сервис настроен на запуск при загрузке системы |

**Параметры установки:**

| Параметр | Значение | Что делает |
|----------|----------|------------|
| `INSTALL_K3S_VERSION` | `v1.36.2+k3s1` | Фиксированная версия k3s |
| `K3S_TOKEN` | `mysecrettoken` | Токен для подключения воркеров |
| `--flannel-backend=host-gw` | `host-gw` | Использует host-gateway для сети (быстрее, чем VXLAN) |
| `--node-ip={{ ansible_host }}` | IP на enp0s8 | Привязывает k3s к Internal Network |
| `--cluster-cidr` | `10.42.0.0/16` | Сеть для подов внутри кластера |
| `--service-cidr` | `10.43.0.0/16` | Сеть для сервисов внутри кластера |
| `--cluster-domain` | `cluster.local` | Внутренний DNS-домен кластера |

**Flannel** — это сетевой плагин для Kubernetes, который отвечает за:

1. Создание виртуальной сети для подов (Pod Network)
2. Назначение IP-адресов каждому поду
3. Маршрутизацию трафика между подами на разных нодах

**`host-gw` (host-gateway)** — один из бэкендов Flannel:

- **Как работает:** Создаёт маршруты на уровне хоста (host) через `ip route`
- **Плюсы:** Высокая производительность (без дополнительного инкапсуляции)
- **Минусы:** Требует, чтобы все ноды были в одной сети (подходит для Internal Network в VirtualBox)

**Сравнение бэкендов:**

| Бэкенд | Производительность | Требования |
|--------|-------------------|------------|
| `host-gw` | ✅ Высокая | Ноды в одной подсети |
| `vxlan` | ❌ Ниже | Не требует одной подсети |

---

**Результат после успешной установки:**

| Файл | Назначение |
|------|------------|
| `/usr/local/bin/k3s` | Исполняемый файл k3s |
| `/etc/rancher/k3s/k3s.yaml` | kubeconfig для доступа к кластеру |
| `/var/lib/rancher/k3s/server/node-token` | Токен для подключения воркеров |
| `k3s.service` | Systemd-сервис (автозапуск) |

---


**2.2. Настройка kubeconfig**

```yaml
- name: Создаем .kube для пользователя
  file:
    path: /home/elv/.kube
    state: directory
    owner: elv
    group: elv
    mode: 0755

- name: Копируем kubeconfig
  copy:
    src: /etc/rancher/k3s/k3s.yaml
    dest: /home/elv/.kube/config
    owner: elv
    group: elv
    mode: 0644
    remote_src: yes
```

**Что делает:** Копирует kubeconfig в домашнюю папку пользователя, чтобы можно было использовать `kubectl`.

---

**2.3. Сохранение токена для воркеров**

```yaml
- name: Получаем токен для воркеров
  slurp:
    src: /var/lib/rancher/k3s/server/node-token
  register: node_token

- name: Сохраняем токен в файл
  copy:
    content: "{{ node_token.content | b64decode }}"
    dest: /tmp/node-token
    owner: elv
    group: elv
    mode: 0644
```

**Что делает:** Читает токен и сохраняет его в `/tmp/node-token`.  
**Зачем:** Воркеры будут использовать этот токен для подключения.

---

##### Блок 3: Установка k3s на воркеры

**3.1. Получение токена с мастера**

```yaml
- name: Получаем токен с мастера
  slurp:
    src: /tmp/node-token
  delegate_to: master
  register: node_token
```

**Что делает:** Читает файл `/tmp/node-token` на мастере.  
**Зачем:** Чтобы получить токен для подключения к кластеру.

---

**3.2. Установка k3s agent**

```yaml
- name: Устанавливаем k3s agent
  shell: |
    curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION={{ k3s_version }} \
      K3S_URL=https://{{ hostvars['master']['ansible_host'] }}:6443 \
      K3S_TOKEN={{ node_token.content | b64decode | trim }} \
      INSTALL_K3S_EXEC="agent \
        --node-ip={{ ansible_host }}" \
      sh -
  args:
    creates: /usr/local/bin/k3s
```

**Что делает:** Устанавливает k3s в режиме agent (воркер).

| Параметр | Значение | Что делает |
|----------|----------|------------|
| `K3S_URL` | `https://10.10.10.10:6443` | Адрес мастера (Internal Network) |
| `K3S_TOKEN` | Токен из файла | Авторизация в кластере |
| `--node-ip={{ ansible_host }}` | `10.10.10.11` или `10.10.10.12` | IP на Internal Network |

---

##### Блок 4: Проверка кластера

```yaml
- name: Проверка кластера
  hosts: master
  become: yes

  tasks:
    - name: Ждём, пока все ноды присоединятся
      command: kubectl get nodes
      register: kubectl_result
      until: '"worker1" in kubectl_result.stdout and "worker2" in kubectl_result.stdout'
      retries: 30
      delay: 10

    - name: Показываем ноды
      command: kubectl get nodes -o wide
      register: nodes_status

    - name: Выводим статус нод
      debug:
        msg: "{{ nodes_status.stdout_lines }}"
```

**Что делает:** Ждёт, пока все ноды присоединятся к кластеру, и выводит их статус.

---

### 12. Итоговая схема работы плейбука

```
1. Подготовка всех ВМ
   ├── hostname
   ├── apt update
   ├── пакеты
   ├── отключение swap
   ├── модули ядра (br_netfilter, overlay)
   ├── sysctl
   └── Docker

2. Установка k3s на master
   ├── установка server (--node-ip={{ ansible_host }})
   ├── настройка kubeconfig
   └── сохранение токена

3. Установка k3s на worker1, worker2
   ├── получение токена с мастера
   └── установка agent (--node-ip={{ ansible_host }})

4. Проверка
   └── kubectl get nodes
```

### 13. Запуск плейбука

```bash
cd ~/infra
ansible-playbook -i ./hosts.yml playbooks/k3s-cluster.yml
```

**Вывод:**

```
PLAY [Проверка кластера] *****************************************************************************************************************************

TASK [Gathering Facts] *******************************************************************************************************************************
ok: [master]

TASK [Ждём, пока все ноды присоединятся] *************************************************************************************************************
changed: [master]

TASK [Показываем ноды] *******************************************************************************************************************************
changed: [master]

TASK [Выводим статус нод] ****************************************************************************************************************************
ok: [master] => {
    "msg": [
        "NAME      STATUS   ROLES           AGE   VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                CONTAINER-RUNTIME",
        "master    Ready    control-plane   61s   v1.36.2+k3s1   10.10.10.10   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2",
        "worker1   Ready    <none>          34s   v1.36.2+k3s1   10.10.10.11   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2",
        "worker2   Ready    <none>          4s    v1.36.2+k3s1   10.10.10.12   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2"
    ]
}

PLAY RECAP *******************************************************************************************************************************************
master                     : ok=19   changed=6    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
worker1                    : ok=12   changed=1    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
worker2                    : ok=12   changed=1    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0
```


### 14. Проверка кластера

Проверка выполняется **на ВМ `master`** (control-plane).

**Перед проверкой** необходимо исправить права на kubeconfig:

```bash
sudo chmod 644 /etc/rancher/k3s/k3s.yaml
```

**Проверка кластера:**

```bash
kubectl get nodes -o wide
```

**Результат:**

```
NAME      STATUS   ROLES           AGE     VERSION        INTERNAL-IP   EXTERNAL-IP   OS-IMAGE                       KERNEL-VERSION                CONTAINER-RUNTIME
master    Ready    control-plane   4m38s   v1.36.2+k3s1   10.10.10.10   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2
worker1   Ready    <none>          4m11s   v1.36.2+k3s1   10.10.10.11   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2
worker2   Ready    <none>          3m41s   v1.36.2+k3s1   10.10.10.12   <none>        Debian GNU/Linux 13 (trixie)   6.12.96+deb13-amd64 (amd64)   containerd://2.3.2-k3s2
```

**Вывод:** Все узлы успешно присоединились к кластеру и находятся в состоянии `Ready`. Кластер готов к использованию.

---

## Выводы

В ходе выполнения домашнего задания были решены следующие задачи:

1. ✅ Создана лабораторная среда из 4 ВМ в VirtualBox.
2. ✅ Настроена внутренняя сеть между ВМ.
3. ✅ Настроен SSH-доступ и sudo без пароля.
4. ✅ Установлен и настроен Ansible на управляющей ВМ.
5. ✅ Создан инвентарный файл для управления ВМ.
6. ✅ Написан и запущен Ansible-playbook для развертывания k3s-кластера.
7. ✅ Получены логи выполнения playbook.
8. ✅ Кластер успешно развернут и проверен.

