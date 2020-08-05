
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

// The cert-manager helm chart requires some CRDs to be installed.
resource "null_resource" "cert_manager" {
  provisioner "local-exec" {
    command = <<EOF
kubectl apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml
(kubectl get namespace silta-cluster && kubectl label namespace silta-cluster certmanager.k8s.io/disable-validation="true") || true
EOF
  }

  depends_on = [google_container_cluster.silta_cluster]
}

resource "helm_release" "silta_cluster" {
  name = "silta-cluster"
  repository = "https://storage.googleapis.com/charts.wdr.io"
  chart = "silta-cluster"
  values = [file(var.silta_cluster_helm_local_values)]
  namespace = "silta-cluster"
  create_namespace = true
  timeout = 900
  depends_on = [null_resource.cert_manager]
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
  }
  depends_on = [google_container_cluster.silta_cluster]
}
