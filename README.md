# GitOps with ArgoCD on Amazon EKS using Terraform: A Complete Implementation Guide

In the rapidly evolving world of DevOps and cloud-native applications, GitOps has emerged as a revolutionary approach to continuous deployment and infrastructure management. This blog post explores how to implement a complete GitOps workflow using ArgoCD on Amazon Elastic Kubernetes Service (EKS), providing you with a production-ready setup that follows industry best practices.

GitOps represents a paradigm shift where Git repositories serve as the single source of truth for both application code and infrastructure configuration. By leveraging ArgoCD as our GitOps operator, we can achieve automated, reliable, and auditable deployments while maintaining the declarative nature of Kubernetes.

## What is GitOps?

GitOps is a modern approach to continuous deployment that uses Git as the single source of truth for declarative infrastructure and applications. The core principles include:

- **Declarative Configuration**: Everything is described declaratively in Git
- **Version Control**: All changes are tracked and auditable
- **Automated Deployment**: Changes in Git trigger automatic deployments
- **Continuous Monitoring**: The system continuously ensures the desired state matches the actual state

## Why ArgoCD?

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes that offers:

- **Application Management**: Centralized management of multiple applications
- **Multi-Cluster Support**: Deploy to multiple Kubernetes clusters
- **Rich UI**: Intuitive web interface for monitoring deployments
- **RBAC Integration**: Fine-grained access control
- **Rollback Capabilities**: Easy rollback to previous versions

## Architecture Overview

This implementation demonstrates a complete GitOps workflow using ArgoCD on Amazon EKS, creating a production-ready, cloud-native application delivery platform. 

The architecture consists of three main layers: 
- **Infrastructure Layer** (Terraform-managed AWS resources) - The infrastructure layer provisions a secure VPC with public and private subnets across multiple availability zones, an EKS cluster with managed node groups, and an NGINX Ingress Controller exposed via AWS Network Load Balancer.

- **Platform Layer** (Kubernetes services and ArgoCD) - The platform layer deploys ArgoCD server with custom ingress configuration for web UI access, implements the App-of-Apps pattern for centralized application management, and establishes Route53 DNS records for both ArgoCD (`argocd.chinmayto.com`) and applications (`app.chinmayto.com`).

- **Application Layer** (containerized workloads) - The application layer showcases a sample Node.js application deployed via GitOps, demonstrating automated synchronization, self-healing capabilities, and ingress-based external access. 

This architecture enables teams to achieve Infrastructure as Code through Terraform, GitOps-driven deployments through ArgoCD, automated application lifecycle management, and secure, scalable access patterns through AWS-native networking services.

```
┌──────────────────────────────────────────────────────────────┐
│                        AWS Cloud                             │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                    VPC                                   ││
│  │  ┌─────────────────┐    ┌──────────────────────────────┐ ││
│  │  │  Public Subnets │    │      Private Subnets         │ ││
│  │  │                 │    │  ┌─────────────────────────┐ │ ││
│  │  │  ┌───────────┐  │    │  │      EKS Cluster        │ │ ││
│  │  │  │    NAT    │  │    │  │  ┌─────────────────────┐│ │ ││
│  │  │  │  Gateway  │  │    │  │  │   NGINX Ingress     ││ │ ││
│  │  │  └───────────┘  │    │  │  │    Controller       ││ │ ││
│  │  │                 │    │  │  └─────────────────────┘│ │ ││
│  │  └─────────────────┘    │  │  ┌─────────────────────┐│ │ ││
│  │                         │  │  │     ArgoCD          ││ │ ││
│  │                         │  │  │     Server          ││ │ ││
│  │                         │  │  └─────────────────────┘│ │ ││
│  │                         │  │  ┌─────────────────────┐│ │ ││
│  │                         │  │  │   Application       ││ │ ││
│  │                         │  │  │   Workloads         ││ │ ││
│  │                         │  │  └─────────────────────┘│ │ ││
│  │                         │  └─────────────────────────┘ │ ││
│  │                         └──────────────────────────────┘ ││
│  └──────────────────────────────────────────────────────────┘│
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐│
│  │                   Route53                                ││
│  │  argocd.chinmayto.com → NGINX Ingress NLB                ││
│  │  app.chinmayto.com → NGINX Ingress NLB                   ││
│  └──────────────────────────────────────────────────────────┘│
└──────────────────────────────────────────────────────────────┘

GitOps Flow:
Git Repository → ArgoCD (App-of-Apps) → Kubernetes Applications
```

### The Significance of App-of-Apps Pattern

The `app-of-apps.yaml` file implements ArgoCD's **App-of-Apps pattern**, which serves as the cornerstone of scalable GitOps architecture in this implementation. This pattern creates a root ArgoCD application that monitors the `argocd/` directory in the Git repository and automatically manages the lifecycle of all other applications defined within it. When the App-of-Apps application syncs, it discovers application manifests like `nodejs-app-application.yaml` and `project.yaml`, then creates and manages these applications in ArgoCD without manual intervention. This approach transforms application deployment from a manual, imperative process into a fully automated, declarative workflow where adding a new application is as simple as committing a new YAML file to the `argocd/` directory. 

The pattern provides several critical benefits: 
- **centralized management** of multiple applications from a single source, 
- **automatic discovery** and deployment of new applications, - **self-healing capabilities** that ensure applications remain in their desired state, and 
- **GitOps compliance** where Git serves as the single source of truth for the entire application portfolio. 

In production environments, this pattern enables teams to achieve true Infrastructure as Code for application management, supports multi-environment deployments through branch-based strategies, provides complete audit trails through Git history, and enables disaster recovery scenarios where the entire application ecosystem can be restored from Git repository state alone.

## Prerequisites

Before starting, ensure you have:

- AWS CLI configured with appropriate permissions
- Terraform installed (version >= 1.0)
- kubectl installed
- A registered domain name in Route53
- Helm installed (version >= 3.0)

## Implementation Steps

### Step 1: Create VPC and EKS Cluster

We start by creating the foundational infrastructure using AWS community Terraform modules. First, let's define our variables:

```hcl
# infrastructure/variables.tf
variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "CT-EKS-Cluster"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.33"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}
```

Now, let's create the VPC and EKS cluster:

```hcl
# infrastructure/main.tf
####################################################################################
# Data source for availability zones
####################################################################################
data "aws_availability_zones" "available" {
  state = "available"
}

####################################################################################
### VPC Module Configuration
####################################################################################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.cluster_name}-VPC"
  cidr = var.vpc_cidr

  azs             = slice(data.aws_availability_zones.available.names, 0, 2)
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway = true
  enable_vpn_gateway = false
  single_nat_gateway = true

  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Name      = "${var.cluster_name}-VPC"
    Terraform = "true"
  }
}

####################################################################################
###  EKS Cluster Module Configuration
####################################################################################
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id                                   = module.vpc.vpc_id
  subnet_ids                               = module.vpc.private_subnets
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true

  # EKS Managed Node Groups
  eks_managed_node_groups = {
    EKS_Node_Group = {
      min_size     = 1
      max_size     = 3
      desired_size = 2

      instance_types = ["t3.medium"]
      capacity_type  = "ON_DEMAND"

      subnet_ids = module.vpc.private_subnets
    }
  }

  # EKS Add-ons
  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  tags = {
    Name      = var.cluster_name
    Terraform = "true"
  }
}

####################################################################################
###  Null Resource to update the kubeconfig file
####################################################################################
resource "null_resource" "update_kubeconfig" {
  provisioner "local-exec" {
    command = "aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}"
  }

  depends_on = [module.eks]
}
```

### Step 2: Deploy NGINX Ingress Controller

The NGINX Ingress Controller provides external access to our services through an AWS Network Load Balancer:

```hcl
# infrastructure/nginx-ingress.tf
################################################################################
# Create ingress-nginx namespace
################################################################################
resource "kubernetes_namespace" "ingress_nginx" {
  metadata {
    name = "ingress-nginx"
    labels = {
      name = "ingress-nginx"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install NGINX Ingress Controller using Helm
################################################################################
resource "helm_release" "nginx_ingress" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = kubernetes_namespace.ingress_nginx.metadata[0].name
  version    = "4.8.3"

  values = [
    yamlencode({
      controller = {
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"                              = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }
        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false
          }
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.ingress_nginx]
}

################################################################################
# Get the NLB hostname from nginx ingress controller
################################################################################
data "kubernetes_service" "nginx_ingress_controller" {
  metadata {
    name      = "ingress-nginx-controller"
    namespace = kubernetes_namespace.ingress_nginx.metadata[0].name
  }
  depends_on = [helm_release.nginx_ingress]
}
```

### Step 3: Deploy ArgoCD Server

First, let's define the ArgoCD-specific variables:

```hcl
# infrastructure/variables.tf (ArgoCD Variables)
variable "argocd_namespace" {
  description = "Kubernetes namespace for ArgoCD"
  type        = string
  default     = "argocd"
}

variable "argocd_chart_version" {
  description = "ArgoCD Helm chart version"
  type        = string
  default     = "5.51.6"
}

variable "argocd_hostname" {
  description = "Hostname for ArgoCD ingress"
  type        = string
  default     = "argocd.chinmayto.com"
}

variable "argocd_admin_password" {
  description = "Custom admin password for ArgoCD (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
  default     = "chinmayto.com"
}

variable "argocd_subdomain" {
  description = "Subdomain for ArgoCD"
  type        = string
  default     = "argocd"
}
```

Now, deploy ArgoCD using Helm with custom configuration for ingress access:

```hcl
# infrastructure/argocd.tf
####################################################################################
### Route53 Hosted Zone
####################################################################################
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

####################################################################################
### ArgoCD Namespace
####################################################################################
resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace
  }

  depends_on = [module.eks]
}

####################################################################################
### ArgoCD Helm Release
####################################################################################
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = [var.argocd_hostname]
          annotations = {
            "nginx.ingress.kubernetes.io/ssl-redirect"       = "false"
            "nginx.ingress.kubernetes.io/force-ssl-redirect" = "false"
            "nginx.ingress.kubernetes.io/backend-protocol"   = "HTTP"
          }
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [kubernetes_namespace.argocd]
}

####################################################################################
### ArgoCD Admin Password Secret (Optional - for custom password)
####################################################################################
resource "kubernetes_secret" "argocd_admin_password" {
  count = var.argocd_admin_password != "" ? 1 : 0

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace.argocd.metadata[0].name
  }

  data = {
    password = bcrypt(var.argocd_admin_password)
  }

  depends_on = [kubernetes_namespace.argocd]
}
```

### Step 4: Configure Route53 DNS

Set up DNS records to access ArgoCD via a custom subdomain:

```hcl
# infrastructure/argocd.tf (continued)
####################################################################################
### Route53 DNS Record for ArgoCD (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "argocd" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.argocd_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.argocd, data.kubernetes_service.nginx_ingress_controller]
}
```

For application DNS records, create a separate file:

```hcl
# infrastructure/app-dns.tf
####################################################################################
### Route53 DNS Record for Node.js App (pointing to NGINX Ingress NLB)
####################################################################################
resource "aws_route53_record" "nodejs_app" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.app_subdomain
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}
```

### Step 5: Create ArgoCD Project

Define an ArgoCD project to manage application deployments:

```yaml
# argocd/project.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: chinmayto-apps
  namespace: argocd
spec:
  description: Project for chinmayto applications
  sourceRepos:
    - 'https://github.com/chinmayto/terraform-aws-eks-argocd.git'
  destinations:
    - namespace: '*'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
```

### Step 6: Implement App-of-Apps Pattern

Create a root application that manages other applications:

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app-of-apps
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/chinmayto/terraform-aws-eks-argocd.git
    targetRevision: HEAD
    path: argocd
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

Create individual application definitions:

```yaml
# argocd/nodejs-app-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nodejs-app
  namespace: argocd
spec:
  project: chinmayto-apps
  source:
    repoURL: https://github.com/chinmayto/terraform-aws-eks-argocd.git
    targetRevision: HEAD
    path: k8s-manifests
  destination:
    server: https://kubernetes.default.svc
    namespace: simple-nodejs-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Deployment Instructions

### 1. Deploy Infrastructure

```bash
cd infrastructure
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Verify Deployment

```bash
# Check EKS cluster
kubectl get nodes

# Check ArgoCD pods
kubectl get pods -n argocd

# Check NGINX Ingress
kubectl get svc -n ingress-nginx

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 3. Access ArgoCD UI

Navigate to `https://argocd.yourdomain.com` and login with:
- Username: `admin`
- Password: (from step 4 above)

### 4. Deploy Applications

Apply the ArgoCD application manifests:

```bash
kubectl apply -f argocd/app-of-apps.yaml
```

## Testing

Accessing argocd using the domain: http://argocd.chinmayto.com

![alt text](/images/argocd_1.png)

![alt text](/images/argocd_2.png)

Deployed app-of-apps:
![alt text](/images/appofapps_deployement.png)

Deployed application with components:

![alt text](/images/appv1_deployed.png)

![alt text](/images/appv1_screen.png)


```bash
$ kubectl get all -n simple-nodejs-app
NAME                                        READY   STATUS    RESTARTS   AGE        
pod/deployment-nodejs-app-bfb4c4d56-pdwtt   1/1     Running   0          10m        
pod/deployment-nodejs-app-bfb4c4d56-rfxfq   1/1     Running   0          10m        

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/service-nodejs-app   ClusterIP   172.20.120.15   <none>        80/TCP    10m

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE        
deployment.apps/deployment-nodejs-app   2/2     2            2           10m        

NAME                                              DESIRED   CURRENT   READY   AGE   
replicaset.apps/deployment-nodejs-app-bfb4c4d56   2         2         2       10m   
```

Update the k8s-manifests, commit the code and see argocd picking up the changes and deploying them.
![alt text](/images/appv2_inprogress.png)

Deployment complete:

![alt text](/images/appv2_deployed.png)

![alt text](/images/appv2_screen.png)

```bash
$ kubectl get all -n simple-nodejs-app
NAME                                         READY   STATUS    RESTARTS   AGE
pod/deployment-nodejs-app-66684f5945-fdwqp   1/1     Running   0          2m42s
pod/deployment-nodejs-app-66684f5945-h6pv9   1/1     Running   0          2m16s
pod/deployment-nodejs-app-66684f5945-tfs45   1/1     Running   0          2m30s

NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/service-nodejs-app   ClusterIP   172.20.120.15   <none>        80/TCP    13m

NAME                                    READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/deployment-nodejs-app   3/3     3            3           13m

NAME                                               DESIRED   CURRENT   READY   AGE
replicaset.apps/deployment-nodejs-app-66684f5945   3         3         3       2m43s
replicaset.apps/deployment-nodejs-app-bfb4c4d56    0         0         0       13m
```

## Cleanup Steps

```bash
# Verify applications present
kubectl get applications -n argocd

# Delete specific applications by name (NEVER use --all with projects)
kubectl delete application app-of-apps -n argocd
kubectl delete application nodejs-app -n argocd

# Verify applications are deleted
kubectl get applications -n argocd

# Verify custom projects
kubectl get appprojects -n argocd

# Only delete the custom project, NEVER delete default project
kubectl delete appproject chinmayto-apps -n argocd

# Verify only custom project is deleted (default should remain)
kubectl get appprojects -n argocd

# Delete the resources and namespace for application
kubectl delete all --all-namespaces -l argocd.argoproj.io/instance=nodejs-app
kubectl delete ns -l argocd.argoproj.io/instance=nodejs-app

# Destroy terraform infrastructure
cd infrastructure
terraform destroy -auto-approve
```

## Conclusion

This implementation demonstrates a production-ready GitOps workflow using ArgoCD on Amazon EKS. By following this guide, you've created:

- A secure, scalable Kubernetes cluster on AWS
- Automated application deployment pipeline
- Centralized application management through ArgoCD
- DNS-based access to your GitOps platform

The GitOps approach with ArgoCD provides numerous benefits including improved deployment reliability, enhanced security through Git-based workflows, and simplified application lifecycle management. This foundation can be extended to support multiple environments, advanced deployment strategies, and comprehensive monitoring solutions.

## References and Further Reading

- **GitHub Repository**: [terraform-aws-eks-argocd](https://github.com/chinmayto/terraform-aws-eks-argocd)
- **ArgoCD Documentation**: [https://argo-cd.readthedocs.io/](https://argo-cd.readthedocs.io/)

