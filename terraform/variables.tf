variable "droplet_name" {
  description = "Droplet name and base for resource names."
  type        = string
  default     = "recurrator"
}

variable "region" {
  description = "DigitalOcean region. The $4 size is available in sfo2."
  type        = string
  default     = "sfo2"
}

variable "size" {
  description = "Droplet size slug (1 vCPU, 512 MiB, 10 GiB)."
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "image" {
  description = "Ubuntu image slug."
  type        = string
  default     = "ubuntu-26-04-x64"
}

variable "ssh_key_name" {
  description = "DigitalOcean account SSH key used for interactive access."
  type        = string
  default     = "evaro@laptop-msi"
}

variable "provisioner_public_key_path" {
  description = "Provisioner public key inside the setup container."
  type        = string
  default     = "/root/.ssh/id_rsa.pub"
}

variable "tags" {
  description = "Tags applied to the droplet."
  type        = list(string)
  default     = ["recurrator"]
}
