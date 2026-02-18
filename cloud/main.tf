terraform {
  required_version = ">= 1.5"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# ---------- Network ----------

resource "google_compute_network" "cmux" {
  name                    = "cmux-net"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "cmux" {
  name          = "cmux-subnet"
  ip_cidr_range = "10.10.0.0/24"
  network       = google_compute_network.cmux.id
  region        = var.region
}

# Allow internal + Tailscale only — no public SSH
resource "google_compute_firewall" "internal" {
  name    = "cmux-allow-internal"
  network = google_compute_network.cmux.id

  allow {
    protocol = "icmp"
  }
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
  allow {
    protocol = "udp"
    ports    = ["41641"] # Tailscale WireGuard
  }

  source_ranges = ["10.10.0.0/24"]
}

# ---------- Static internal IP ----------

resource "google_compute_address" "cmux_internal" {
  name         = "cmux-internal-ip"
  address_type = "INTERNAL"
  subnetwork   = google_compute_subnetwork.cmux.id
  region       = var.region
}

# ---------- Storage disk ----------

resource "google_compute_disk" "storage" {
  name = "cmux-storage"
  type = "pd-standard"
  size = var.storage_disk_size_gb
  zone = var.zone
}

# ---------- VM ----------

resource "google_compute_instance" "cmux" {
  name         = "cmux-dev"
  machine_type = var.machine_type
  zone         = var.zone

  tags = ["cmux"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = var.disk_size_gb
      type  = "pd-standard"
    }
  }

  attached_disk {
    source      = google_compute_disk.storage.id
    device_name = "cmux-storage"
  }

  network_interface {
    subnetwork = google_compute_subnetwork.cmux.id
    network_ip = google_compute_address.cmux_internal.address
    # No access_config = no public IP
  }

  # Minimal service account
  service_account {
    scopes = ["cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/setup.sh", {
    tailscale_auth_key = var.tailscale_auth_key
  })

  scheduling {
    preemptible       = false
    automatic_restart = true
  }

  allow_stopping_for_update = true
}
