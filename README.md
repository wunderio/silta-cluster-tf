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

### Manual setup

1. Check and create roles for filebeat if not already present
(Not managed via Helm as elevated privileges are needed to create service accounts)
Check: 
```
kubectl get serviceaccount filebeat
kubectl get ClusterRole filebeat
kubectl get ClusterRoleBinding filebeat
```

Create:
```
kubectl --username=admin --password=<yourpassword> create -f filebeat-roles.yaml
```

2. Create GKE cluster

3. Deploy chart to cluster using local values. 
```
helm repo add datawire https://www.getambassador.io
helm dep update chart/
helm upgrade --install --wait silta-cluster chart/  --values local-values.yaml
```

#### Manual updates

- Change `chart/requirements.yaml` ambassador version to an updated one.
- Get the gitAuth parameters (organisation and API token) at hand.

```
helm repo add datawire https://www.getambassador.io
helm dep update chart/
helm upgrade --install --wait silta-cluster chart/  --values local-values.yaml
```
