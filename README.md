# silta cluster

### Installing

1. Copy `chart/values.yaml` to `local-values.yaml` and fill out information.

2. Deploy chart to cluster using local values. 
```
helm upgrade --install --wait silta-cluster chart/  --values local-values.yaml
```


### Updating
- Change `chart/requirements.yaml` ambassador version to an updated one.
- Get the gitAuth parameters (organisation and API token) at hand.

```
helm repo add datawire https://www.getambassador.io
helm dep update
helm upgrade --install --wait silta-cluster chart/  --values local-values.yaml
```

#### SSH Jumphost

SSH Jumphost authentication is based on [sshd-gitAuth](https://github.com/wunderio/sshd-gitauth) project that will authorize users based on their SSH private key. The key whitelist is built by listing all users that belong to a certain github organisation.

You need to supply Github API Personal access token that will be used to get the list of organisation users. The access can be read only, following permissions are sufficient for the task: `public_repo, read:org, read:public_key, repo:status`.

#### Deployment remover

This is an exposed webhook that listens for branch delete events, logs in to cluster and removes named deployments using helm. Project code can be inspected at [silta-deployment-remover](https://github.com/wunderio/silta-deployment-remover).
