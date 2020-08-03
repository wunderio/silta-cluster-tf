# silta cluster

## Installing

1. Create project and service account at - [Service Account creation](https://console.cloud.google.com/projectselector/iam-admin/serviceaccounts?supportedpurview=project&project=&folder=&organizationId=)

Create service account JSON key and save it as `gcloud-credentials.json` file. The file is excluded from repository.

2. Copy https://github.com/wunderio/charts/silta-cluster/values.yaml to `local-values.yaml` and customize information to fit your organisation.

### Setup using terraform

2. Create google cloud storage bucket for shared terraform state file (see `bucket` and `gke_project_id` in `terraform.tf`) - [Google Cloud Platform Storage](https://console.cloud.google.com/storage/browser)

2. Customize `terraform.tfvars` to fit your organisation.

3. Set cluster name as `prefix` in `terraform.tf`.

4. Run terraform
```
terraform init
terraform plan -out=terraform.tfplan
terraform apply "terraform.tfplan"
```

#### Updates

```
terraform plan -out=terraform.tfplan
terraform apply "terraform.tfplan"
```
