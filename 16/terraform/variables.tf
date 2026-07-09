variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Folder ID"
  type        = string
}

variable "zone" {
  description = "Yandex Cloud Zone"
  type        = string
  default     = "ru-central1-a"
}

variable "public_key_path" {
  description = "Path to public SSH key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "private_key_path" {
  description = "Path to private SSH key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "environment" {
  description = "Environment name (staging/production)"
  type        = string
}

variable "vm_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "vm_master_count" {
  description = "Number of master nodes"
  type        = number
  default     = 1
}

variable "vm_resources" {
  description = "VM resources"
  type = object({
    cores         = number
    memory        = number
    core_fraction = number
    disk_size     = number
  })
  default = {
    cores         = 2
    memory        = 4
    core_fraction = 100
    disk_size     = 30
  }
}
