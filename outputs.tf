output "service" {
  description = "The systemd service that runs Uptime Kuma on each host."
  value       = "uptime-kuma.service"
}

output "image" {
  description = "The Uptime Kuma image the hosts run."
  value       = local.image
}

output "url" {
  description = "Where Uptime Kuma answers on each host itself, such as \"http://127.0.0.1:3001\". Point a reverse proxy here."
  value       = local.local_url
}

output "data_dir" {
  description = "Directory on each host holding Uptime Kuma's SQLite database. Back it up."
  value       = local.data
}
