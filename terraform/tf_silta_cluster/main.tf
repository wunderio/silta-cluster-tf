
provider "kubernetes" {
  host = google_container_cluster.silta_cluster.endpoint
  
  username = google_container_cluster.silta_cluster.master_auth.0.username
  password = google_container_cluster.silta_cluster.master_auth.0.password

  client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
  client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = google_container_cluster.silta_cluster.endpoint
    
    username = google_container_cluster.silta_cluster.master_auth.0.username
    password = google_container_cluster.silta_cluster.master_auth.0.password

    client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
    client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
  }
}

// The cert-manager release needs to be installed first, so that CRDs
// are present when the silta-cluster release is created.
resource "helm_release" "cert_manager_legacy_crds" {
  name = "cert-manager-legacy-crds"
  repository = "https://storage.googleapis.com/charts.wdr.io"
  chart = "cert-manager-legacy-crds"
  namespace = "cert-manager"
  create_namespace = true

  // Only install when we have a node pool available.
  depends_on = [google_container_node_pool.np]
}

resource "google_compute_address" "jumphost_ip" {
  name = "ssh-jumphost"
  address_type = "EXTERNAL"
}
resource "google_compute_address" "traefik_ingress" {
  name = "traefik-ingress"
  address_type = "EXTERNAL"
}

resource "helm_release" "silta_cluster" {
  name = "silta-cluster"
  repository = "https://storage.googleapis.com/charts.wdr.io"
  chart = "silta-cluster"
  values = [file(var.silta_cluster_helm_local_values)]
  namespace = "silta-cluster"
  create_namespace = true
  timeout = 900
  depends_on = [helm_release.cert_manager_legacy_crds]

  set {
    name = "gitAuth.loadBalancerIP"
    value = google_compute_address.jumphost_ip.address
  }
  set {
    name = "traefik.loadBalancerIP"
    value = google_compute_address.traefik_ingress.address
  }
}

resource "google_container_cluster" "silta_cluster" {
  provider = google-beta
  name = var.cluster_name
  location = var.cluster_location
  remove_default_node_pool = true
  initial_node_count = 1

  release_channel {
    channel = "REGULAR"
  }
}

resource "google_container_node_pool" "np" {
  name  = "pool-1"
  location = var.cluster_location
  cluster = google_container_cluster.silta_cluster.name
  node_config {
    preemptible = true
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  initial_node_count = 1
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_container_node_pool" "static_ip" {
  name  = "static-ip"
  location = var.cluster_location
  cluster = google_container_cluster.silta_cluster.name
  initial_node_count = 1
  node_config {
    preemptible = false
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_container_registry" "registry" {
  location = "EU"
}

output "dns_info" {
  value = <<EOF
Please add DNS entries for the following domains:

A ${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${google_compute_address.traefik_ingress.address}
CNAME *.${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain}
A ssh.${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${google_compute_address.jumphost_ip.address}

EOF
}