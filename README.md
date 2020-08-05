# silta cluster

## Installing

1. Create a Google Cloud project and note the project id.

2. Make sure you have a user or service account set up locally with gcloud.

3. Copy https://github.com/wunderio/charts/silta-cluster/values.yaml to `local-values.yaml` and customize information to fit your organisation.

4. Call the terraform module with your own parameters:

```hcl-terraform
provider "google" {
  project = "my-silta-project"
}

# Use the beta API where needed.
provider "google-beta" {
  project = "my-silta-project"
}

module "tf_silta_cluster" {
  # Use your Google Cloud project id. 
  project_id = "my-silta-project"
  
  # The path to your values file for the release of the silta-cluster helm chart.
  silta_cluster_helm_local_values = "local-values.yaml"

  source = "git::https://@github.com/wunderio/silta-cluster-tf.git//terraform/tf_silta_cluster"
}
```

5. Run terraform
```bash
terraform init
terraform plan -out=terraform.tfplan
terraform apply "terraform.tfplan"
```

6. Updating terraform
```
terraform plan -out=terraform.tfplan
terraform apply "terraform.tfplan"
```
