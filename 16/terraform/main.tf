provider "yandex" {
  service_account_key_file = "authorized_key.json"
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}

resource "yandex_vpc_network" "app_network" {
  name = "voting-app-network-${var.environment}"
}

resource "yandex_vpc_subnet" "app_subnet" {
  name           = "voting-app-subnet-${var.environment}"
  zone           = var.zone
  network_id     = yandex_vpc_network.app_network.id
  v4_cidr_blocks = var.environment == "production" ? ["10.10.0.0/24"] : ["10.20.0.0/24"]
}

resource "yandex_vpc_security_group" "app_sg" {
  name        = "voting-app-sg-${var.environment}"
  description = "Security group for voting app - ${var.environment}"
  network_id  = yandex_vpc_network.app_network.id

  ingress {
    protocol       = "TCP"
    description    = "SSH"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "K3s API"
    port           = 6443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    description    = "NodePort Services"
    from_port      = 30000
    to_port        = 32767
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    description    = "Allow all outbound"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "master" {
  count = var.vm_master_count

  name        = "k3s-master-${var.environment}-${count.index + 1}"
  hostname    = "k3s-master-${var.environment}-${count.index + 1}"
  zone        = var.zone
  platform_id = "standard-v2"

  resources {
    cores         = var.vm_resources.cores
    memory        = var.vm_resources.memory
    core_fraction = var.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = "fd806c8slu9j1pa87msc"  # Ubuntu 22.04 LTS
      size     = var.vm_resources.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}

resource "yandex_compute_instance" "worker" {
  count = var.vm_count

  name        = "k3s-worker-${var.environment}-${count.index + 1}"
  hostname    = "k3s-worker-${var.environment}-${count.index + 1}"
  zone        = var.zone
  platform_id = "standard-v2"

  resources {
    cores         = var.vm_resources.cores
    memory        = var.vm_resources.memory
    core_fraction = var.vm_resources.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = "fd806c8slu9j1pa87msc"  # Ubuntu 22.04 LTS
      size     = var.vm_resources.disk_size
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.app_subnet.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.app_sg.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.public_key_path)}"
  }
}
