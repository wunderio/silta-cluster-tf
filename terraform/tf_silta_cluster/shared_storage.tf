
resource "google_storage_bucket" "shared-storage" {
  name          = "${var.project_id}-shared-storage"
  location      = var.cluster_location

  # Uncomment this to enable deletion of non-empty buckets.
  # force_destroy = true
}

resource "google_service_account" "shared-storage-sa" {
  account_id   = "shared-storage-sa"
  display_name = "Access to shared storage"
}

resource "google_storage_bucket_acl" "shared-storage-acl" {
  bucket = google_storage_bucket.shared-storage.name

  role_entity = [
    "WRITER:user-${google_service_account.shared-storage-sa.email}",
  ]
}

resource "google_service_account_key" "shared_storage_key" {
  service_account_id = google_service_account.silta_ci.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}