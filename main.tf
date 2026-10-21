resource "yandex_vpc_network" "net" {
  name = "lamp-net"
}

resource "yandex_vpc_subnet" "public" {
  name           = "public"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = ["192.168.10.0/24"]
}

resource "yandex_iam_service_account" "ig" {
  name = "ig-sa"
}

resource "yandex_resourcemanager_folder_iam_member" "ig_editor" {
  folder_id = var.folder_id
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.ig.id}"
}

resource "yandex_iam_service_account_static_access_key" "sa_key" {
  service_account_id = yandex_iam_service_account.ig.id
}

resource "yandex_storage_bucket" "pictures" {
  bucket     = "victoria-20261009"
  acl        = "public-read"
  folder_id  = var.folder_id
  access_key = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.sa_key.secret_key
}

resource "yandex_storage_object" "cat" {
  bucket       = yandex_storage_bucket.pictures.bucket
  key          = "cat.jpg"
  source       = "${path.module}/cat.jpg"
  acl          = "public-read"
  content_type = "image/jpeg"
  access_key   = yandex_iam_service_account_static_access_key.sa_key.access_key
  secret_key   = yandex_iam_service_account_static_access_key.sa_key.secret_key
}

resource "yandex_compute_instance_group" "lamp" {
  name               = "lamp-group"
  folder_id          = var.folder_id
  service_account_id = yandex_iam_service_account.ig.id
  depends_on         = [yandex_resourcemanager_folder_iam_member.ig_editor]

  instance_template {
    platform_id = "standard-v3"

    resources {
      cores         = 2
      memory        = 2
      core_fraction = 20
    }

    boot_disk {
      mode = "READ_WRITE"
      initialize_params {
        image_id = "fd827b91d99psvq5fjit"
        size     = 10
        type     = "network-hdd"
      }
    }

    network_interface {
      network_id = yandex_vpc_network.net.id
      subnet_ids = [yandex_vpc_subnet.public.id]
      nat        = true
    }

    metadata = {
      user-data = <<-EOT
        #cloud-config
        runcmd:
          - echo '<html><body><h1>LAMP group</h1><img src="https://storage.yandexcloud.net/${yandex_storage_bucket.pictures.bucket}/cat.jpg"></body></html>' > /var/www/html/index.html
      EOT
      ssh-keys = "ubuntu:${file("~/.ssh/id_ed25519.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 3
    }
  }

  allocation_policy {
    zones = [var.zone]
  }

  deploy_policy {
    max_unavailable = 1
    max_expansion   = 0
  }

  health_check {
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    http_options {
      port = 80
      path = "/"
    }
  }

  load_balancer {
    target_group_name = "lamp-targets"
  }
}

resource "yandex_lb_network_load_balancer" "nlb" {
  name = "lamp-nlb"

  listener {
    name = "http"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_compute_instance_group.lamp.load_balancer[0].target_group_id

    healthcheck {
      name                = "http"
      interval            = 5
      timeout             = 3
      healthy_threshold   = 2
      unhealthy_threshold = 3
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

output "bucket_url" {
  value = "https://storage.yandexcloud.net/${yandex_storage_bucket.pictures.bucket}/cat.jpg"
}

output "balancer_ip" {
  value = tolist(tolist(yandex_lb_network_load_balancer.nlb.listener)[0].external_address_spec)[0].address
}
