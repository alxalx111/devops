output "master_ip" {
  value = yandex_compute_instance.master[0].network_interface[0].nat_ip_address
}

output "worker_ips" {
  value = yandex_compute_instance.worker[*].network_interface[0].nat_ip_address
}

output "cluster_name" {
  value = "k3s-cluster-${var.environment}"
}

output "environment" {
  value = var.environment
}

output "kubeconfig_command" {
  value = "ssh ubuntu@${yandex_compute_instance.master[0].network_interface[0].nat_ip_address} sudo cat /etc/rancher/k3s/k3s.yaml"
}
