provider "google" {
  credentials  = "${var.gke_credentials}"
  project      = "${var.gke_project_id}"
  region       = "${var.gke_region}"
}

provider "kubernetes" {
  host = google_container_cluster.silta_cluster.endpoint
  
  username = google_container_cluster.silta_cluster.master_auth.0.username
  password = google_container_cluster.silta_cluster.master_auth.0.password

  client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
  client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {

  # TODO: Destroy is broken. Watch out for any changes in this PR: https://github.com/terraform-providers/terraform-provider-helm/pull/203
  namespace       = "kube-system"
  
  kubernetes {
    host = google_container_cluster.silta_cluster.endpoint
    
    username = google_container_cluster.silta_cluster.master_auth.0.username
    password = google_container_cluster.silta_cluster.master_auth.0.password

    #token = data.google_client_config.current.access_token
    client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
    client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
  }
}

resource "helm_release" "silta_cluster" {

  name = "silta-cluster"
  #repository = "https://wunderio.github.io/charts/"
  chart = "silta-cluster"
  values = ["${var.silta_cluster_helm_local_values}"]

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
    value = var.gke_zone
  }
}

resource "google_container_node_pool" "np" {
  name               = "pool-1"
  zone               = var.gke_zone
  cluster            = google_container_cluster.silta_cluster.name
  node_config {
    preemptible  = false
    machine_type = var.gke_machine_type
  }
  node_count = var.gke_node_count
  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_container_cluster" "silta_cluster" {
  name = var.gke_cluster_name
  zone = var.gke_zone
  remove_default_node_pool = true
  node_pool = {
    "name" = "default-pool"
  }
  lifecycle = {
    "ignore_changes" = ["node_pool"]
  }
}
