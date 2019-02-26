provider "google" {
  credentials  = "${var.gke_credentials}"
  project      = "${var.gke_project_id}"
  region       = "${var.gke_region}"
}

provider "kubernetes" {
  host = "${google_container_cluster.silta_cluster.endpoint}"
  
  username = "${google_container_cluster.silta_cluster.master_auth.0.username}"
  password = "${google_container_cluster.silta_cluster.master_auth.0.password}"

  client_certificate = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)}"
  client_key = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)}"
  cluster_ca_certificate = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)}"
}

provider "helm" {
  install_tiller  = true
  namespace       = "kube-system"
  service_account = "tiller"
  tiller_image    = "gcr.io/kubernetes-helm/tiller:v2.11.0"
  
  kubernetes {
    host = "${google_container_cluster.silta_cluster.endpoint}"
    
    username = "${google_container_cluster.silta_cluster.master_auth.0.username}"
    password = "${google_container_cluster.silta_cluster.master_auth.0.password}"

    #token = "${data.google_client_config.current.access_token}"
    client_certificate = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)}"
    client_key = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)}"
    cluster_ca_certificate = "${base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)}"
  }
}

resource "helm_release" "silta_cluster" {

  name = "silta-cluster-test"
  repository = "https://wunderio.github.io/charts/"
  chart = "silta-cluster"
  values = ["${var.silta_cluster_helm_local_values}"]

  # depends_on = [ "null_resource.helm_depupdate", "kubernetes_cluster_role_binding.tiller" ]
  depends_on = [ "kubernetes_cluster_role_binding.tiller" ]
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  subject {
    kind = "User"
    name = "system:serviceaccount:kube-system:tiller"
  }

  subject {
    kind = "ServiceAccount"
    name = "tiller"

    api_group = ""
    namespace = "kube-system"
  }

  role_ref {
    kind  = "ClusterRole"
    name = "cluster-admin"
  }

  depends_on = [ "kubernetes_service_account.tiller" ]
} 

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }
  automount_service_account_token = true
  depends_on = [ "google_container_cluster.silta_cluster" ]
}

resource "google_container_node_pool" "np" {
  name               = "pool-1"
  zone               = "${var.gke_zone}"
  cluster            = "${google_container_cluster.silta_cluster.name}"
  node_config {
    preemptible  = false
    machine_type = "${var.gke_machine_type}"
  }
  node_count = "${var.gke_node_count}"
  depends_on = ["google_container_cluster.silta_cluster"]
}

resource "google_container_cluster" "silta_cluster" {
  name = "${var.gke_cluster_name}"
  zone = "${var.gke_zone}"
  remove_default_node_pool = true
  "node_pool" = {
    "name" = "default-pool"
  }
  "lifecycle" = {
    "ignore_changes" = ["node_pool"]
  }
}
