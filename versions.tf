terraform {
  required_version = ">= 1.3.0"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.100.0"
    }
  }
}

provider "yandex" {
  zone      = var.zone
  folder_id = var.folder_id
  cloud_id  = var.cloud_id
  token     = var.token
}
