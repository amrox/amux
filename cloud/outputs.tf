output "internal_ip" {
  description = "Static internal IP of the amux VM"
  value       = google_compute_address.amux_internal.address
}

output "vm_name" {
  description = "VM instance name"
  value       = google_compute_instance.amux.name
}

output "zone" {
  description = "VM zone"
  value       = google_compute_instance.amux.zone
}

output "ssh_via_tailscale" {
  description = "SSH command once Tailscale is up"
  value       = "ssh user@amux-dev  # via Tailscale hostname"
}
