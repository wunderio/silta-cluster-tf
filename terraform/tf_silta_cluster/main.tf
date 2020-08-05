
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
resource "helm_release" "cert_manager" {
  name = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart = "cert-manager"
  namespace = "cert-manager"
  create_namespace = true

  set {
    name = "installCRDs"
    value = true
  }
}

resource "helm_release" "silta_cluster" {
  name = "silta-cluster"
  #repository = "https://wunderio.github.io/charts/"
  chart = "silta-cluster"
  values = ["${var.silta_cluster_helm_local_values}"]
  namespace = "silta-cluster"
  create_namespace = true
  timeout = 900

  set {
    name = "gke.keyJSON"
    value = var.gke_credentials
  }
  set {
    name = "gke.projectName"
    value = var.gke_project_id
  }
  set {
    name = "gke.clusterName"
    value = var.gke_cluster_name
  }
  set {
    name = "gke.computeZone"
    value = var.gke_location
  }
  depends_on = [helm_release.cert_manager]
}

resource "google_container_node_pool" "np" {
  name  = "pool-1"
  location = var.gke_location
  cluster = google_container_cluster.silta_cluster.name
  node_config {
    preemptible = true
    machine_type = var.gke_machine_type
  }
  node_count = var.gke_node_count
  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }
  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_container_node_pool" "static_ip" {
  name  = "static-ip"
  location = var.gke_location
  cluster = google_container_cluster.silta_cluster.name
  node_config {
    preemptible = false
    machine_type = var.gke_machine_type
  }
  node_count = var.gke_node_count
  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_container_cluster" "silta_cluster" {
  provider = google-beta
  name = var.gke_cluster_name
  location = var.gke_location
  remove_default_node_pool = true
  initial_node_count = 1

  release_channel {
    channel = "REGULAR"
  }
}
