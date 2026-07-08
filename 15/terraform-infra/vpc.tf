resource "yandex_vpc_network" "app_network" {
  name = "voting-app-network"
}

resource "yandex_vpc_subnet" "app_subnet" {
  name           = "voting-app-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.app_network.id
  v4_cidr_blocks = ["10.10.0.0/24"]
}
