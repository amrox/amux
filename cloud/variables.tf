variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "machine_type" {
  description = "VM machine type"
  type        = string
  default     = "e2-small"
}

variable "disk_size_gb" {
  description = "Boot disk size in GB"
  type        = number
  default     = 20
}

variable "storage_disk_size_gb" {
  description = "Attached HDD for cold storage"
  type        = number
  default     = 100
}

variable "tailscale_auth_key" {
  description = "Tailscale auth key (reusable, ephemeral recommended)"
  type        = string
  sensitive   = true
}
