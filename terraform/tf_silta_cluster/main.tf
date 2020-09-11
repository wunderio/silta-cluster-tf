
provider "kubernetes" {
  host = google_container_cluster.silta_cluster.endpoint
  
  username = google_container_cluster.silta_cluster.master_auth.0.username
  password = google_container_cluster.silta_cluster.master_auth.0.password

  client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
  client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
  cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host = google_container_cluster.silta_cluster.endpoint
    
    username = google_container_cluster.silta_cluster.master_auth.0.username
    password = google_container_cluster.silta_cluster.master_auth.0.password

    client_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_certificate)
    client_key = base64decode(google_container_cluster.silta_cluster.master_auth.0.client_key)
    cluster_ca_certificate = base64decode(google_container_cluster.silta_cluster.master_auth.0.cluster_ca_certificate)
  }
}

// The cert-manager release needs to be installed first, so that CRDs
// are present when the silta-cluster release is created.
resource "helm_release" "cert_manager_legacy_crds" {
  name = "cert-manager-legacy-crds"
  repository = "https://storage.googleapis.com/charts.wdr.io"
  chart = "cert-manager-legacy-crds"
  namespace = "cert-manager"
  create_namespace = true

  // Only install when we have a node pool available.
  depends_on = [google_container_node_pool.np]
}

resource "google_compute_address" "jumphost_ip" {
  name = "ssh-jumphost"
  address_type = "EXTERNAL"
}
resource "google_compute_address" "traefik_ingress" {
  name = "traefik-ingress"
  address_type = "EXTERNAL"
}

resource "helm_release" "silta_cluster" {
  name = "silta-cluster"
  repository = "https://storage.googleapis.com/charts.wdr.io"
  chart = "silta-cluster"
  values = [file(var.silta_cluster_helm_local_values), <<EOF
gke:
  projectName: ${var.project_id}
  clusterName: ${google_container_cluster.silta_cluster.name}
  computeZone: ${var.cluster_location}
  keyJSON: '${base64decode(google_service_account_key.shared_storage_key.private_key)}'
EOF
  ]
  namespace = "silta-cluster"
  create_namespace = true
  timeout = 900
  depends_on = [helm_release.cert_manager_legacy_crds, google_container_node_pool.np, google_container_node_pool.static_ip]

  set {
    name = "gitAuth.loadBalancerIP"
    value = google_compute_address.jumphost_ip.address
  }
  set {
    name = "traefik.loadBalancerIP"
    value = google_compute_address.traefik_ingress.address
  }
  set {
    name = "csi-rclone.params.remote"
    value = "google cloud storage"
  }
  set {
    name = "csi-rclone.params.remotePath"
    value = google_storage_bucket.shared-storage.name
  }
}

resource "google_container_cluster" "silta_cluster" {
  provider = google-beta
  name = var.cluster_name
  location = var.cluster_location
  remove_default_node_pool = true
  initial_node_count = 1

  release_channel {
    channel = "REGULAR"
  }

  network_policy {
    enabled = true
    provider = "CALICO"
  }

  addons_config {
    network_policy_config {
      disabled = false
    }
  }
}

resource "google_container_node_pool" "np" {
  name  = "pool-${var.machine_type}"
  location = var.cluster_location
  cluster = google_container_cluster.silta_cluster.name
  node_config {
    preemptible = true
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
  initial_node_count = 1
  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  depends_on = [google_container_cluster.silta_cluster]
}

resource "google_compute_address" "static_egress" {
  for_each = toset(var.static_egress_ip_names)
  name = each.value
  address_type = "EXTERNAL"
}

resource "google_container_node_pool" "static_ip" {
  name  = "static-ip"
  location = var.cluster_location
  // We only need static nodes in a single region.
  node_locations = [element(tolist(google_container_cluster.silta_cluster.node_locations), 0)]
  cluster = google_container_cluster.silta_cluster.name
  initial_node_count = 2
  node_count = 2
  node_config {
    preemptible = false
    machine_type = var.machine_type
    oauth_scopes = [
      "https://www.googleapis.com/auth/devstorage.read_only",
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }

  depends_on = [google_container_cluster.silta_cluster]
}


resource "google_container_registry" "registry" {
  location = "EU"
}

resource "null_resource" "static_ip_node_assignment" {

  triggers = {
    version = 1
  }

  provisioner "local-exec" {
    command = <<EOF

static_ip_addresses=(${join(" ", [for address in google_compute_address.static_egress: address.address])})
instance_names=$(gcloud compute instances list --project ${var.project_id} --filter="name~'static-ip'" --format="value(name)")
index=0
for instance_name in $instance_names; do

  static_ip_address=$${static_ip_addresses[index]}
  # Delete the existing access-config
  gcloud compute instances delete-access-config $instance_name --project ${var.project_id} --zone ${element(tolist(google_container_cluster.silta_cluster.node_locations), 0)} --access-config-name "external-nat" || true
  # Create the new access-config
  gcloud compute instances add-access-config $instance_name --project ${var.project_id} --zone ${element(tolist(google_container_cluster.silta_cluster.node_locations), 0)} --access-config-name "external-nat" --address $static_ip_address
  index=$((index+1))
done

EOF
  }
}

output "dns_info" {
  value = <<EOF
Please add DNS entries for the following domains:

A ${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${google_compute_address.traefik_ingress.address}
CNAME *.${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain}
A ssh.${yamldecode(file(var.silta_cluster_helm_local_values)).clusterDomain} pointing to ${google_compute_address.jumphost_ip.address}

Static egress IPs:
${join("\n", [for address in google_compute_address.static_egress: address.address])}
EOF
}