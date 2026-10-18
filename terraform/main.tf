locals {
  provisioner_public_key_path = (
    fileexists(var.provisioner_public_key_path)
    ? var.provisioner_public_key_path
    : "/root/.ssh/id_ed25519.pub"
  )
}

data "digitalocean_ssh_key" "user" {
  name = var.ssh_key_name
}

resource "digitalocean_ssh_key" "provisioner" {
  name       = "${var.droplet_name}-provisioner"
  public_key = file(local.provisioner_public_key_path)
}

resource "digitalocean_droplet" "recurrator" {
  name       = var.droplet_name
  region     = var.region
  size       = var.size
  image      = var.image
  backups    = false
  ipv6       = false
  monitoring = false

  ssh_keys = [
    data.digitalocean_ssh_key.user.fingerprint,
    digitalocean_ssh_key.provisioner.fingerprint,
  ]

  tags = var.tags
}

resource "digitalocean_firewall" "recurrator" {
  name        = "${var.droplet_name}-firewall"
  droplet_ids = [digitalocean_droplet.recurrator.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "udp"
    port_range       = "41641"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
