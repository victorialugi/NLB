variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "cloud_id"  { type = string }
variable "folder_id" { type = string }
variable "token" {
  type      = string
  sensitive = true
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_pubkey_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}
