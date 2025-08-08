# Rearc Quest — Deployment Notes

This repository contains the solution I built for the Rearc Quest cloud challenge.
It shows how to package the Node/Go web-app into a container, push it to Google
Artifact Registry, deploy it on Cloud Run, and front it with an external
Application Load Balancer that terminates TLS with a self-signed certificate.

## Directory layout

```
.
├── Dockerfile              # builds the app image (node:18-slim + CA certs to keep base image small)
├── src/                    # Node & Go source for quest endpoints
├── iac/                    # Terraform configuration
│   ├── provider.tf         # provider versions & project/region
│   ├── main.tf             # Cloud Run service + IAM
│   └── loadbalancer.tf     # Serverless NEG + external ALB + TLS
└── .gitignore              # ignores node_modules, tfstate, etc.
```
## All the step I took to complete the project:

### Build & Push the image

```bash
# Build for linux/amd64 and tag with Artifact Registry path
docker buildx build \
  --platform linux/amd64 \
  -t us-east1-docker.pkg.dev/quest-i/quest/rearc-quest:v3 .

# Authenticate once (stores helper in ~/.docker/config.json)
gcloud auth configure-docker us-east1-docker.pkg.dev

docker push us-east1-docker.pkg.dev/quest-i/quest/rearc-quest:v3
```

### Deploy with Terraform

```bash
cd iac
terraform init
terraform apply   # review & confirm
```

Outputs to note after apply:

* **Static IP** – the HTTP/S load balancer front-end (e.g. `34.160.103.245`)
* **Cloud Run URL** – default service host used in the Host rewrite header

#### What Terraform creates

1. `google_cloud_run_service`: deploys the container in `us-east1`, env-var
   `SECRET_WORD` is sourced from Secret Manager.
2. `google_compute_region_network_endpoint_group` (serverless): points to the
   Cloud Run service.
3. `google_compute_backend_service`: attaches the NEG and rewrites `Host:` so
   Cloud Run accepts the request.
4. URL map, HTTP proxy, HTTPS proxy, global forwarding rules, and a reserved
   global IPv4.
5. `tls_*` resources create a self-signed cert and upload it as a self-managed
   SSL certificate so HTTPS works without a domain (browser warnings expected).

## Testing

```bash
# HTTP
curl http://<STATIC_IP>/

# HTTPS (ignore self-signed warning)
curl -k https://<STATIC_IP>/
```

You should see the quest index page containing the secret word.

## Clean-up

```bash
cd iac
terraform destroy   
```

## Given more time, I would improve …
* Add a real CICD pipeline, either with cloud build or github actions. 
* Switch to a Google-managed certificate with a real domain.
* Add Cloud Armor rules and Cloud Logging/Monitoring dashboards.


