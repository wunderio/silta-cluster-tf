variable "circleci_context_name" {
  type = string
  description = "The CircleCI context that stores cluster and registry credentials."
}

variable "circleci_org_name" {
  type = string
  description = "The CircleCI organisation name."
  default = "wunderio"
}

variable "circleci_vcs_type" {
  type = string
  description = "The CircleCI VCS type."
  default = "github"
}

resource "null_resource" "circleci_context" {
  provisioner "local-exec" {
    command = <<EOF
if ! circleci context list ${var.circleci_vcs_type} ${var.circleci_org_name} --skip-update-check | grep ${var.circleci_context_name}
then
  circleci context create ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name}
fi
EOF
  }
}

resource "google_service_account" "silta_ci" {
  account_id   = "silta-ci"
  display_name = "Continuous Integration"
}

resource "google_project_iam_member" "silta_ci_cluster_access" {
  // TODO: define a custom role with more limited permissions.
  role   = "roles/container.admin"
  member = "serviceAccount:${google_service_account.silta_ci.email}"
}

resource "google_storage_bucket_iam_member" "silta_ci_registry_access" {
  bucket = google_container_registry.registry.id
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.silta_ci.email}"
}

resource "google_service_account_key" "silta_ci_key" {
  service_account_id = google_service_account.silta_ci.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

resource "random_password" "db_root_pass" {
  length = 16
}

resource "random_password" "db_user_pass" {
  length = 16
}

variable "secret_key" {
  description = "The key used to decrypt sensitive information during the deployment process. Defaults to a generated value"
  type = string
  default = ""
}
resource "random_password" "secret_key" {
  length = 16
}

resource "null_resource" "circleci_context_variables" {
  depends_on = [null_resource.circleci_context]

  triggers = {
    project_id = var.project_id
    cluster_name = var.cluster_name
    circleci_vs_type = var.circleci_vcs_type
    circleci_org_name = var.circleci_org_name
    circleci_context_name = var.circleci_context_name
    private_key = google_service_account_key.silta_ci_key.private_key
    registry_location = google_container_registry.registry.location
    cluster_location = google_container_cluster.silta_cluster.location
    values_file = file(var.silta_cluster_helm_local_values)
    db_root_pass = random_password.db_root_pass.result
    db_user_pass = random_password.db_user_pass.result
    secret_key_var = var.secret_key
    secret_key_generated = random_password.secret_key.result
    version = 2
  }

  provisioner "local-exec" {
    command = <<EOF
printf "${var.project_id}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GCLOUD_PROJECT_NAME
printf "${var.cluster_name}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GCLOUD_CLUSTER_NAME
printf '%s' '${base64decode(google_service_account_key.silta_ci_key.private_key)}' | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GCLOUD_KEY_JSON

printf "${var.project_id}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} DOCKER_REPO_PROJ
printf "${lower(google_container_registry.registry.location)}.gcr.io" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} DOCKER_REPO_HOST
printf "${google_container_cluster.silta_cluster.location}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GCLOUD_COMPUTE_REGION

# The default cluster domain.
printf "${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} CLUSTER_DOMAIN

# The default database credentials.
printf "${random_password.db_root_pass.result}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} DB_ROOT_PASS
printf "${random_password.db_user_pass.result}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} DB_USER_PASS

# The credentials used to validate shell access.
printf "${yamldecode(file(var.silta_cluster_helm_local_values)).sshKeyServer.apiUsername}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GITAUTH_USERNAME
printf "${yamldecode(file(var.silta_cluster_helm_local_values)).sshKeyServer.apiPassword}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} GITAUTH_PASSWORD

# The default key used to encrypt secrets.
printf "${var.secret_key != "" ? var.secret_key : random_password.secret_key.result}" | circleci context store-secret ${var.circleci_vcs_type} ${var.circleci_org_name} ${var.circleci_context_name} SECRET_KEY
EOF
  }
}
