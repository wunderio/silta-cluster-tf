variable "project_id" {
  type = string
  description = "The Google Cloud project where Silta should be deployed."
}
variable "cluster_location" {
  type = string
  description = "The Google Cloud location of the Silta cluster."
  default = "europe-north1-a"
}
variable "cluster_name" {
  type = string
  description = "The name of the Kubernetes cluster in Google Cloud."
  default = "silta"
}
variable "machine_type" {
  type    = string
  default = "n1-standard-2"
  description = "The machine type used for the node pools of the Kubernetes cluster."
}
variable "min_node_count" {
  type    = string
  default = "1"
}
variable "max_node_count" {
  type    = string
  default = "10"
}
variable "silta_cluster_helm_local_values" {
  type    = string
}
