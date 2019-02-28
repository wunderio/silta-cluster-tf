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

  # TODO: Destroy is broken. Watch out for any changes in this PR: https://github.com/terraform-providers/terraform-provider-helm/pull/203
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

  name = "silta-cluster"
  repository = "https://wunderio.github.io/charts/"
  chart = "silta-cluster"
  values = ["${var.silta_cluster_helm_local_values}"]

  set {
    name = "gke.keyJSON"
    value = "${var.gke_credentials}"
  }
  set {
    name = "gke.projectName"
    value = "${var.gke_project_id}"
  }
  set {
    name = "gke.clusterName"
    value = "${var.gke_cluster_name}"
  }
  set {
    name = "gke.computeZone"
    value = "${var.gke_zone}"
  }
  depends_on = [ "kubernetes_cluster_role_binding.tiller", "kubernetes_cluster_role_binding.filebeat" ]
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
  depends_on = [ "kubernetes_service_account.tiller"]
}

resource "kubernetes_cluster_role_binding" "filebeat" {
  metadata {
    name = "filebeat"
  }
  subject {
    kind = "ServiceAccount"
    name = "filebeat"
    namespace = "default"
    api_group = ""
  }
  role_ref {
    kind  = "ClusterRole"
    name = "filebeat"
    api_group = "rbac.authorization.k8s.io"
  }
  depends_on = [ "kubernetes_cluster_role.filebeat" ]
}

resource "kubernetes_cluster_role" "filebeat" {
  metadata {
    name = "filebeat",
    labels {
      k8s-app = "filebeat"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["namespaces", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  depends_on = [ "kubernetes_service_account.filebeat" ]
}

resource "kubernetes_service_account" "filebeat" {
  metadata {
    name      = "filebeat"
    namespace = "default"
    labels {
      k8s-app = "filebeat"
    }
  }
  automount_service_account_token = true
  depends_on = [ "google_container_cluster.silta_cluster" ]
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