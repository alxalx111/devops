# Виртуальная лабораторная среда в VirtualBox

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

### 8. Создание инвентарного файла

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

### 9. Проверка подключения

Для проверки доступности управляемых хостов с ВМ ansible была выполнена команда:

```bash
cd infra
ansible -i hosts.yml all -m ping --become
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

**Вывод:** Все хосты успешно отвечают на запросы Ansible. Подключение настроено корректно, Python-интерпретатор на целевых машинах обнаружен автоматически.

Для подавления предупреждений о выборе интерпретатора Python в ~/infra был создан файл `ansible.cfg`:

```bash
cat ~/infra/ansible.cfg
[defaults]
interpreter_python = auto_silent
```

