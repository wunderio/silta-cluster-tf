terraform {
  backend "gcs" {
    prefix = "silta-test"
    bucket  = "silta-terraform-states"
    credentials = "gcloud-credentials.json"
  }
}

module "tf_silta_cluster" {
  gke_credentials = "${file("gcloud-credentials.json")}"
  gke_project_id = "<project-id>"
  gke_region = "europe-west2"
  gke_zone = "europe-west2-a"
  gke_cluster_name = "<cluster-name>"
  gke_machine_type = "n1-standard-2"
  gke_node_count = "2"
  silta_cluster_helm_local_values = "${file("local-values.yaml")}"

  source = "git::https://@github.com/wunderio/silta-cluster-tf.git//terraform/tf_silta_cluster"
  # source = "./terraform/tf_silta_cluster"
  version = "0.1"
}
