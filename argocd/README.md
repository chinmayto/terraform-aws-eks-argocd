# ArgoCD Applications

This directory contains ArgoCD application manifests for GitOps deployment.

## Files

- `project.yaml` - ArgoCD AppProject for organizing applications
- `app-of-apps.yaml` - App of Apps pattern for managing multiple applications
- `nodejs-app-application.yaml` - Application manifest for the Node.js app

## Deployment Options

### Option 1: Deploy Individual Application
```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/nodejs-app-application.yaml
```

### Option 2: Deploy using App of Apps Pattern (Recommended)
```bash
kubectl apply -f argocd/project.yaml
kubectl apply -f argocd/app-of-apps.yaml
```

## Application Details

### Node.js Application
- **Source**: `k8s-manifests/` directory in this repository
- **Destination**: `simple-nodejs-app` namespace
- **Sync Policy**: Automated with self-healing enabled
- **Access**: `http://app.chinmayto.com` (via NGINX Ingress)

## Features

- **Automated Sync**: Applications automatically sync when changes are detected
- **Self-Healing**: ArgoCD will automatically fix any drift from desired state
- **Pruning**: Removes resources that are no longer defined in Git
- **Retry Logic**: Automatic retry with exponential backoff on sync failures
- **Namespace Creation**: Automatically creates target namespaces if they don't exist

## Monitoring

Access ArgoCD UI at: `https://argocd.chinmayto.com`

Default credentials:
- Username: `admin`
- Password: Get via `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d`

## Repository Structure

```
├── argocd/                     # ArgoCD application manifests
│   ├── app-of-apps.yaml       # App of Apps pattern
│   ├── nodejs-app-application.yaml  # Node.js app definition
│   └── project.yaml           # ArgoCD project
├── k8s-manifests/             # Kubernetes manifests (synced by ArgoCD)
│   ├── deploy-simple-nodejs-app.yaml
│   └── nginx-ingress-nodejs-app.yaml
└── infrastructure/            # Terraform infrastructure code
```

## Customization

To customize the applications:

1. **Change Repository**: Update `repoURL` in the application manifests
2. **Change Branch**: Update `targetRevision` to use a specific branch/tag
3. **Change Path**: Update `path` to point to different directories
4. **Add Applications**: Create new application YAML files in this directory