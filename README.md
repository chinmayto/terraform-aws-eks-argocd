# Observability on Amazon EKS Cluster: A Complete Guide to Prometheus and Grafana with Helm

When deploying applications on Amazon Elastic Kubernetes Service (EKS), ensuring that you can observe, monitor, and troubleshoot workloads effectively is crucial. This is where observability comes into play. In this blog, we’ll set up an EKS cluster using AWS Community Terraform modules, install Prometheus and Grafana for monitoring and visualization, configure Route53 DNS records, and deploy a sample microservices application (Voting App).## Why Prometheus and Grafana?

## What is Observability in EKS?

Observability in Kubernetes (and EKS) refers to the ability to understand the internal state of your cluster and applications by analyzing the outputs such as logs, metrics, and traces. It goes beyond traditional monitoring:
- Monitoring answers “Is my system working?”
- Observability answers “Why is my system not working?”

In Kubernetes on AWS EKS, observability provides insights into:
- Cluster health (nodes, pods, deployments, daemonsets, etc.)
- Application performance (latency, error rates, resource utilization)
- Infrastructure metrics (EC2, VPC, networking, EBS/EFS storage, etc.)
- User experience tracking (via service-level objectives and traces)

Key pillars of observability:
- Metrics – quantitative data collected over time (CPU, memory, request counts).
- Logs – textual event records (pod logs, system logs).
- Traces – request paths across microservices (distributed tracing).

By combining these three, DevOps teams can detect, debug, and optimize Kubernetes workloads effectively.

## What is Prometheus and Grafana
Prometheus is an open-source monitoring and alerting toolkit designed for reliability and scalability. It collects time-series metrics by periodically scraping targets such as Kubernetes nodes, pods, services, and applications. Using its query language PromQL, Prometheus enables detailed analysis of cluster performance, application behavior, and infrastructure health. It also supports alerting rules, making it useful for proactive issue detection.

Grafana is an open-source visualization and analytics platform that integrates with data sources like Prometheus. It allows users to create interactive dashboards and visualizations for monitoring metrics in real time. Grafana turns raw data into meaningful insights by providing charts, graphs, and alerts that help teams detect anomalies and optimize performance.

Together, Prometheus and Grafana form a powerful observability stack on EKS. Prometheus handles metrics collection and storage, while Grafana provides visualization and analysis. This combination allows Kubernetes operators and developers to not only monitor cluster health but also understand why issues occur, enabling faster debugging and better capacity planning.

## Architecture Overview

Our monitoring architecture consists of several key components:

```
┌─────────────────────────────────────────────────────────────┐
│                        EKS Cluster                          │
│                                                             │
│  ┌─────────────────┐    ┌─────────────────┐                 │
│  │   Prometheus    │◄───┤  Node Exporter  │                 │
│  │     Server      │    │                 │                 │
│  │                 │    └─────────────────┘                 │
│  │  - Scrapes      │                                        │
│  │  - Stores       │    ┌─────────────────┐                 │
│  │  - Alerts       │◄───┤ kube-state-     │                 │
│  └─────────────────┘    │ metrics         │                 │
│           │             └─────────────────┘                 │
│           │                                                 │
│           ▼              ┌─────────────────┐                │
│  ┌─────────────────┐◄────┤   Application   │                │
│  │    Grafana      │     │    Metrics      │                │
│  │                 │     └─────────────────┘                │
│  │  - Dashboards   │                                        │
│  │  - Visualization│     ┌─────────────────┐                │
│  │  - Alerting     │◄────┤  AlertManager   │                │
│  └─────────────────┘     │                 │                │
│                          └─────────────────┘                │
└─────────────────────────────────────────────────────────────┘
```

## Architecture of Prometheus and Grafana on EKS

When deploying Prometheus and Grafana on EKS, the architecture typically looks like this:
- Prometheus runs inside the cluster and is responsible for:
    - Scraping metrics from Kubernetes components, node exporters, pods, and application endpoints.
    - Storing time-series data in its own storage backend.
    - Exposing APIs that allow querying using PromQL.

- Grafana runs alongside Prometheus and is responsible for:
    - Connecting to Prometheus as a data source.
    - Querying metrics with PromQL queries.
    - Creating dashboards that visualize cluster health, workload performance, and application-specific data.

**Data Flow:**

Kubernetes Metrics Sources:
- Kubelet – node and pod metrics.
- Kube-state-metrics – state of Kubernetes objects (deployments, pods, nodes, services).
- cAdvisor – container-level CPU, memory, filesystem, and network usage.
- ETCD metrics – key-value store performance.
- Application endpoints – any service exposing /metrics in Prometheus format.

Prometheus Scraping:
- Prometheus periodically queries these endpoints using service discovery (Kubernetes API, annotations, labels).
- Metrics are collected and stored as time-series data.

Grafana Visualization:
- Grafana queries Prometheus using PromQL.
- Dashboards are built to visualize CPU usage, memory utilization, pod restarts, latency, and custom application metrics.
- Dashboards can be customized or imported from Grafana’s community templates.


## Step 1: Create EKS Cluster using AWS Community Terraform Modules
The first step in integrating Amazon EFS with EKS is to provision a Kubernetes cluster that runs securely inside a dedicated VPC. We will use the widely adopted AWS Terraform community modules for both the VPC and EKS setup. Please refer to main module of GitHub repo.

## Step 2: Add Helm Repositories

First, let's add the necessary Helm repositories:

```bash
# Add Prometheus community Helm repository
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# Add Grafana Helm repository  
helm repo add grafana https://grafana.github.io/helm-charts

# Add Nginx Ingress Helm repository  
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

# Update repositories
helm repo update
```

## Step 3: Install NGINX Ingress Controller with Helm

To expose Prometheus, Grafana, and other applications securely outside the cluster, we need an Ingress Controller. We’ll use the NGINX Ingress Controller, installed via Helm in its own namespace.

```terraform
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

## Step 4: Create Route53 Records for Prometheus and Grafana

To make these tools accessible via a domain, configure Route53 DNS records. This allows you to access Prometheus at https://prometheus.chinmayto.com and Grafana at https://grafana.chinmayto.com.

```terraform
################################################################################
# Get Route53 hosted zone for chinmayto.com
################################################################################
data "aws_route53_zone" "main" {
  name         = "chinmayto.com"
  private_zone = false
}

################################################################################
# Create Route53 A records for Prometheus and Grafana
################################################################################
resource "aws_route53_record" "prometheus" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "prometheus.chinmayto.com"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}

resource "aws_route53_record" "grafana" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "grafana.chinmayto.com"
  type    = "A"

  alias {
    name                   = data.kubernetes_service.nginx_ingress_controller.status.0.load_balancer.0.ingress.0.hostname
    zone_id                = "Z26RNL4JYFTOTI" # NLB zone ID for us-east-1
    evaluate_target_health = true
  }

  depends_on = [helm_release.nginx_ingress]
}
```

### Step 5: Install Prometheus Stack

We’ll use the Terraform Helm provider to install both Prometheus (for metrics collection) and Grafana (for visualization) in its own namespace.

The kube-prometheus-stack Helm chart is an umbrella chart maintained by the Prometheus community. It includes Prometheus, Grafana, and kube-state-metrics all bundled together. That’s why deploying just this chart is usually sufficient for Kubernetes observability.

```terraform
################################################################################
# Create monitoring namespace
################################################################################
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = "monitoring"
    labels = {
      name = "monitoring"
    }
  }
  depends_on = [module.eks]
}

################################################################################
# Install Prometheus using Helm (after nginx ingress)
################################################################################
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "55.5.0"

  values = [
    yamlencode({
      prometheus = {
        prometheusSpec = {
          retention = "30d"
        }
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["prometheus.chinmayto.com"]
          paths            = ["/"]
          annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
          }
        }
      }
      grafana = {
        enabled       = true
        adminPassword = "admin123"
        service = {
          type = "ClusterIP"
        }
        ingress = {
          enabled          = true
          ingressClassName = "nginx"
          hosts            = ["grafana.chinmayto.com"]
          path             = "/"
          annotations = {
            "nginx.ingress.kubernetes.io/rewrite-target" = "/"
          }
        }
        persistence = {
          enabled = false
        }
      }
      alertmanager = {
        enabled = true
      }
    })
  ]

  depends_on = [kubernetes_namespace.monitoring, helm_release.nginx_ingress]
}
```

### Step 6: Deploy Sample Microservices Application (Voting App)

Now that observability is in place, let’s deploy a sample microservices app: the Voting App (a simple app with a frontend, backend, and database).

Apply manifests:
```bash
cd example-voting-app/k8s-specifications
kubectl apply -f .
```

## Accessing Your Monitoring Stack
You can access Prometheus at https://prometheus.chinmayto.com and Grafana at https://grafana.chinmayto.com.


### Validation Steps

### 1. Verify Prometheus Targets

In Prometheus UI:
1. Go to Status → Targets
2. Ensure all targets are "UP"
3. Check for any scraping errors

### 2. Test Prometheus Queries

Try these sample queries in Prometheus:

```promql
# CPU usage by node
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Pod count by namespace
count by (namespace) (kube_pod_info)
```

![alt text](/images/prom_1.png)

![alt text](/images/prom_2.png)

![alt text](/images/prom_3.png)

### 3. Verify Grafana Dashboards

Grafana comes with pre-built dashboards:
1. Navigate to Dashboards
2. Check "Kubernetes / Compute Resources / Cluster"
3. Verify data is displaying correctly

![alt text](/images/graf_1.png)

## Few Best Grafana Dashboards for EKS Monitoring

Grafana provides a wide range of prebuilt dashboards for Kubernetes and Prometheus. Some of the most popular ones for EKS monitoring include:

- Kubernetes / Compute Resources Cluster (ID: 315): Visualizes cluster-wide CPU and memory usage.
- Kubernetes / Compute Resources Namespace (Workloads) (ID: 3146): Breaks down metrics by namespace, useful for multi-team environments.
- Kubernetes / Compute Resources Pod (ID: 7633): Pod-level monitoring (CPU, memory, restarts).
- Kubernetes API Server Metrics (ID: 12006): Helps track API server performance, latency, and error rates.
- Node Exporter Full (ID: 1860): Deep-dive into node-level metrics such as disk I/O, CPU, memory, and network.
- ETCD Metrics (ID: 3070): Monitoring the control plane’s key-value store.
- Kube-State-Metrics Dashboards (ID: 13332): Tracks states of Kubernetes objects like deployments, daemonsets, jobs, and cronjobs.
These dashboards can be directly imported into Grafana using their Dashboard IDs from Grafana Labs Dashboard Repository

![alt text](/images/graf_2.png)

![alt text](/images/graf_3.png)

## Cleanup
Delete the k8s resources created
```bash
cd example-voting-app/k8s-specifications
kubectl delete -f .
```
And then `terraform destroy` the EKS infrastructure if you are not using it to save costs.

## Conclusion

Setting up Prometheus and Grafana on EKS provides powerful observability into your Kubernetes clusters. This monitoring stack enables you to:

- Track cluster and application performance
- Set up proactive alerting
- Visualize metrics through beautiful dashboards
- Make data-driven decisions about scaling and optimization

The combination of Prometheus's robust metric collection and Grafana's visualization capabilities creates a comprehensive monitoring solution that scales with your infrastructure needs.

Remember to regularly review and update your monitoring configuration as your applications and infrastructure evolve. Monitoring is not a "set it and forget it" solution – it requires ongoing attention and refinement.

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [kube-prometheus-stack Helm Chart](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)
- [Amazon EKS User Guide](https://docs.aws.amazon.com/eks/latest/userguide/)
- [Kubernetes Monitoring Best Practices](https://kubernetes.io/docs/concepts/cluster-administration/monitoring/)
- [Prometheus Operator Documentation](https://prometheus-operator.dev/)

