output "internal_ip" {
  description = "Static internal IP of the cmux VM"
  value       = google_compute_address.cmux_internal.address
}

output "vm_name" {
  description = "VM instance name"
  value       = google_compute_instance.cmux.name
}

output "zone" {
  description = "VM zone"
  value       = google_compute_instance.cmux.zone
}

output "ssh_via_tailscale" {
  description = "SSH command once Tailscale is up"
  value       = "ssh user@cmux-dev  # via Tailscale hostname"
}
