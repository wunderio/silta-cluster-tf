# silta cluster

### Updating
- Change `chart/requirements.yaml` ambassador version to an updated one.

```
helm repo add datawire https://www.getambassador.io
helm dep update
helm upgrade --install --wait silta-cluster chart/ 
```
