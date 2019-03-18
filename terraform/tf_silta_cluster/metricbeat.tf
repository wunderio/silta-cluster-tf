resource "kubernetes_cluster_role_binding" "metricbeat" {
  metadata {
    name = "metricbeat"
  }
  subject {
    kind = "ServiceAccount"
    name = "metricbeat"
    namespace = "default"
    api_group = ""
  }
  role_ref {
    kind  = "ClusterRole"
    name = "metricbeat"
    api_group = "rbac.authorization.k8s.io"
  }
  depends_on = [ "kubernetes_cluster_role.metricbeat" ]
}

resource "kubernetes_cluster_role" "metricbeat" {
  metadata {
    name = "metricbeat",
    labels {
      k8s-app = "metricbeat"
    }
  }
  rule {
    api_groups = [""]
    resources  = ["nodes", "namespaces", "events", "pods"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["extensions"]
    resources  = ["replicasets"]
    verbs      = ["get", "list", "watch"]
  }
  rule {
    api_groups = ["apps"]
    resources  = ["statefulsets", ""]
    verbs      = ["get", "list", "watch"]
  }
  depends_on = [ "kubernetes_service_account.metricbeat" ]
}

resource "kubernetes_service_account" "metricbeat" {
  metadata {
    name      = "metricbeat"
    namespace = "default"
    labels {
      k8s-app = "metricbeat"
    }
  }
  automount_service_account_token = true
  depends_on = [ "google_container_cluster.silta_cluster" ]
}
