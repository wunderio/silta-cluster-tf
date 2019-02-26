variable "gke_credentials" {
  type    = "string"
}
variable "gke_project_id" {
  type = "string"
}
variable "gke_region" {
  type = "string"
}
variable "gke_zone" {
  type = "string"
}
variable "gke_cluster_name" {
  type = "string" 
}
variable "gke_machine_type" {
  type    = "string"
  default = "n1-standard-2"
}
variable "gke_node_count" {
  type    = "string"
  default = "3"
}
variable "silta_cluster_helm_local_values" {
  type    = "string"
  default = "local-values.yaml"
}
