resource "google_container_registry" "registry" {
  location = "EU"
}

resource "google_service_account" "silta_ci" {
  account_id   = "silta-ci"
  display_name = "Continuous Integration"
}

resource "google_service_account_key" "silta_ci_key" {
  service_account_id = google_service_account.silta_ci.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

output "circleci_instructions" {
  value = <<EOF
The following values need to be set in your CircleCI context:

GCLOUD_PROJECT_NAME=${var.project_id}
GCLOUD_KEY_JSON="${base64decode(google_service_account_key.silta_ci_key.private_key)}"
DOCKER_PASSWORD="${base64decode(google_service_account_key.silta_ci_key.private_key)}"
EOF
  description = "Instructions for creating a CircleCI context using these values."
}

