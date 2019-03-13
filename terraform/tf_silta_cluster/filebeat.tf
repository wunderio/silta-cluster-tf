resource "kubernetes_cluster_role_binding" "filebeat" {
  metadata {
    name = "filebeat"
  }
  subject {
    kind = "ServiceAccount"
    name = "filebeat"
    # namespace = "kube-system"
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
    verbs      = ["get", "watch", "list"]
  }
  depends_on = [ "kubernetes_service_account.filebeat" ]
}

resource "kubernetes_service_account" "filebeat" {
  metadata {
    name      = "filebeat"
    # namespace = "kube-system"
    labels {
      k8s-app = "filebeat"
    }
  }
  automount_service_account_token = true
  depends_on = [ "google_container_cluster.silta_cluster" ]
}
