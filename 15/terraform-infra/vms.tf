resource "yandex_compute_instance" "master" {
  name        = "k3s-master"
  hostname    = "k3s-master"
  zone        = var.zone
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = "fd806c8slu9j1pa87msc"  # Ubuntu 22.04 LTS
      size     = 30
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
  count = 2

  name        = "k3s-worker-${count.index + 1}"
  hostname    = "k3s-worker-${count.index + 1}"
  zone        = var.zone
  platform_id = "standard-v2"

  resources {
    cores         = 2
    memory        = 4
    core_fraction = 100
  }

  boot_disk {
    initialize_params {
      image_id = "fd806c8slu9j1pa87msc"  # Ubuntu 22.04 LTS
      size     = 30
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
