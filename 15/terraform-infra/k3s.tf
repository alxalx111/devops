locals {
  master_ip = yandex_compute_instance.master.network_interface[0].ip_address
}

# Установка k3s на мастер
resource "null_resource" "install_master" {
  depends_on = [yandex_compute_instance.master]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = yandex_compute_instance.master.network_interface[0].nat_ip_address
  }

  provisioner "remote-exec" {
    inline = [
      "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --node-ip=${local.master_ip}' sh -",
      "sudo chmod 644 /etc/rancher/k3s/k3s.yaml",
      "sudo cat /var/lib/rancher/k3s/server/node-token > /tmp/node-token"
    ]
  }
}

# Получаем токен с мастера
resource "null_resource" "get_token" {
  depends_on = [null_resource.install_master]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = yandex_compute_instance.master.network_interface[0].nat_ip_address
  }

  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -i ${var.private_key_path} ubuntu@${yandex_compute_instance.master.network_interface[0].nat_ip_address}:/tmp/node-token ./node-token"
  }
}

# Установка k3s на воркеры
resource "null_resource" "install_workers" {
  count = 2
  depends_on = [null_resource.get_token]

  connection {
    type        = "ssh"
    user        = "ubuntu"
    private_key = file(var.private_key_path)
    host        = yandex_compute_instance.worker[count.index].network_interface[0].nat_ip_address
  }

  provisioner "file" {
    source      = "node-token"
    destination = "/tmp/node-token"
  }

  provisioner "remote-exec" {
    inline = [
      "TOKEN=$(cat /tmp/node-token)",
      "curl -sfL https://get.k3s.io | K3S_URL=https://${local.master_ip}:6443 K3S_TOKEN=$TOKEN sh -"
    ]
  }
}
