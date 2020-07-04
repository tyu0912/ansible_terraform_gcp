provider "google" {

  credentials = file(var.credentials_file)

  project = var.project
  region  = var.region
  zone    = var.zone
}

resource "google_compute_network" "flask_network" {
  name = "flask-app-network"
}

resource "google_compute_firewall" "allow_ssh_http_https" {
  name    = "flask-app-firewall"
  network = google_compute_network.flask_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "22"]
  }

  source_ranges = ["0.0.0.0/0"]

  source_tags = ["flask-tcp"]
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance-${count.index}"
  machine_type = var.machine_types[var.environment]
  tags         = ["flask-tcp"]
  count        = var.instance_count

  // Installing flask on all instances
  metadata_startup_script = "sudo apt-get update; sudo apt-get install -yq build-essential python-pip rsync"

  boot_disk {
    initialize_params {
      image = "ubuntu-1804-lts"
    }
  }

  network_interface {
    network = google_compute_network.flask_network.name

    access_config {
    }
  }

  metadata = {
    ssh-keys = "${var.username}:${file(var.public_key)}"
 }
}

resource "google_compute_instance_group" "webservers" {
  name        = "terraform-webservers"
  description = "Terraform test instance group"
  zone = var.zone

  instances = google_compute_instance.vm_instance[*].self_link

  named_port {
    name = "http"
    port = "80"
  }
}
