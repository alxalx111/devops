terraform {
  backend "s3" {
    endpoint                    = "https://storage.yandexcloud.net"
    bucket                      = "terraform-state-otus"
    region                      = "ru-central1"
    key                         = "staging/terraform.tfstate"
    access_key                  = "YCAJE****************9jUJU"
    secret_key                  = "YC****************1hPVH"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_requesting_account_id  = true
  }
}