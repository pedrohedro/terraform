provider "google" {
  project = "white-list-372815"
  region  = "us-central1"
}

resource "google_compute_instance" "instance" {
  count        = 3
  name         = "minha-instancia-${count.index + 1}"
  machine_type = "n1-standard-1"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-1804-lts"
    }
  }

/* metadata = {
  ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
} */

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }
}
