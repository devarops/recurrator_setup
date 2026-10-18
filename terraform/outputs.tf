output "ip" {
  description = "Public IPv4 address of the droplet."
  value       = digitalocean_droplet.recurrator.ipv4_address
}

output "name" {
  description = "Droplet name."
  value       = digitalocean_droplet.recurrator.name
}
