# Infrastructure for Yandex Cloud Managed Service for Kubernetes cluster
#
# RU: https://cloud.yandex.ru/docs/smartwebsecurity/tutorials/alb-ingress-with-sws-profile
# EN: https://cloud.yandex.com/en/docs/smartwebsecurity/tutorials/alb-ingress-with-sws-profile
#
# Set the configuration of Managed Service for Kubernetes cluster

locals {

  # The following settings are to be specified by the user. Change them as you wish.

  folder_id   = ""       # Set your cloud folder ID.
  k8s_sa_name = ""       # Set a Kubernetes cluster's service account name. It must be unique within the cloud.
  alb_sa_name = ""       # Set an ALB's service account name. It must be unique within the cloud.
  sws_name    = ""       # Set the name of the Smart Web Security profile.
  allowed_ips = ["", ""] # Set the list of the allowed IP addresses.
  k8s_version = ""       # Set the Kubernetes version from https://yandex.cloud/ru/docs/managed-kubernetes/concepts/release-channels-and-updates

  # The following settings are predefined. Change them only if necessary.

  zone_a_v4_cidr_blocks = "10.1.0.0/16"   # Set the CIDR block for subnet in the ru-central1-a availability zone.
  cluster_ipv4_cidr     = "10.112.0.0/16" # Set IP range for allocating pod addresses.
  service_ipv4_cidr     = "10.96.0.0/16"  # Set IP range for allocating service addresses.

}

resource "yandex_vpc_network" "k8s-network" {
  description = "Network for the Managed Service for Kubernetes cluster"
  name        = "k8s-network"
}

resource "yandex_vpc_subnet" "subnet-a" {
  description    = "Subnet in ru-central1-a availability zone"
  name           = "subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
}

resource "yandex_vpc_security_group" "k8s-cluster-nodegroup-traffic" {
  description = "The group rules allow service traffic for the cluster and node groups. Apply the rules to the cluster and the node groups."
  name        = "k8s-cluster-nodegroup-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description       = "The rule allows availability checks from the load balancer's range of addresses."
    from_port         = 0
    to_port           = 65535
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  ingress {
    description       = "The rule allows incoming service traffic between master and nodes."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
  ingress {
    description    = "The rule allows receiving of debugging ICMP packets from internal cloud subnets."
    protocol       = "ICMP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }
  egress {
    description       = "The rule allows outgoing service traffic between master and nodes."
    from_port         = 0
    to_port           = 65535
    protocol          = "ANY"
    predefined_target = "self_security_group"
  }
}

resource "yandex_vpc_security_group" "k8s-nodegroup-traffic" {
  description = "The group rules allow service traffic for the node groups. Apply the rules to the node groups."
  name        = "k8s-nodegroup-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming service traffic between Kubernetes pods and services."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = [local.cluster_ipv4_cidr, local.service_ipv4_cidr]
  }
  egress {
    description    = "The rule allows all outgoing traffic from nodes. Nodes can connect to Yandex Container Registry, Object Storage, Docker Hub, and more."
    from_port      = 0
    to_port        = 65535
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-services-access" {
  name        = "k8s-services-access"
  description = "The group rules allow connections to Kubernetes services from the internet. Apply the rules to the node groups."
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming traffic in order to connect to Kubernetes services."
    from_port      = 30000
    to_port        = 32767
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-ssh-access" {
  description = "The group rules allow connections to Kubernetes nodes via SSH. Apply the rules to the node groups."
  name        = "k8s-ssh-access"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming traffic in order to connect to nodes via SSH."
    port           = 22
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "k8s-cluster-traffic" {
  description = "The group rules allow traffic for the cluster. Apply the rules to the cluster."
  name        = "k8s-cluster-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming traffic in order to access Kubernetes API via 443 port."
    port           = 443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description    = "The rule allows incoming traffic in order to access Kubernetes API via 6443 port."
    port           = 6443
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    description    = "The rule allows outgoing traffic between master node and metric-server pods."
    port           = 4443
    protocol       = "TCP"
    v4_cidr_blocks = [local.cluster_ipv4_cidr]
  }
}

resource "yandex_vpc_security_group" "alb-k8s-nodegroup-traffic" {
  description = "The group rules allow traffic from ALB to the node groups. Apply the rules to the node groups."
  name        = "alb-k8s-nodegroup-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming traffic in order to do backend health checks."
    port           = 10501
    protocol       = "TCP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }
}

resource "yandex_vpc_security_group" "alb-traffic" {
  description = "The group rules allow traffic from ALB to the node groups. Apply the rules to the ALB L7 load balancer."
  name        = "alb-traffic"
  network_id  = yandex_vpc_network.k8s-network.id
  ingress {
    description    = "The rule allows incoming HTTP traffic."
    port           = 80
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description       = "The rule allows incoming traffic in order to do load balancer health checks."
    port              = 30080
    protocol          = "TCP"
    predefined_target = "loadbalancer_healthchecks"
  }
  egress {
    description    = "The rule allows outgoing traffic from the load balancer to the nodes."
    from_port      = 0
    to_port        = 65535
    protocol       = "TCP"
    v4_cidr_blocks = [local.zone_a_v4_cidr_blocks]
  }
}

# Kubernetes service account
resource "yandex_iam_service_account" "k8s-sa" {
  name = local.k8s_sa_name
}

# Assign "k8s.clusters.agent" role to Kubernetes service account
resource "yandex_resourcemanager_folder_iam_binding" "k8s-clusters-agent" {
  folder_id = local.folder_id
  role      = "k8s.clusters.agent"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Assign "vpc.publicAdmin" role to Kubernetes service account
resource "yandex_resourcemanager_folder_iam_binding" "k8s-vpc-publicadmin" {
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  members = [
    "serviceAccount:${yandex_iam_service_account.k8s-sa.id}"
  ]
}

# Application Load Balancer service account
resource "yandex_iam_service_account" "alb-sa" {
  name = local.alb_sa_name
}

# Assign "alb.editor" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-editor" {
  folder_id = local.folder_id
  role      = "alb.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Assign "vpc.publicAdmin" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-vpc-publicadmin" {
  folder_id = local.folder_id
  role      = "vpc.publicAdmin"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Assign "compute.viewer" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-compute-viewer" {
  folder_id = local.folder_id
  role      = "compute.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Assign "smart-web-security.editor" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-sws-editor" {
  folder_id = local.folder_id
  role      = "smart-web-security.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Assign "k8s.viewer" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-k8s-viewer" {
  folder_id = local.folder_id
  role      = "k8s.viewer"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Assign "certificate-manager.editor" role to ALB service account
resource "yandex_resourcemanager_folder_iam_binding" "alb-certificate-manager-editor" {
  folder_id = local.folder_id
  role      = "certificate-manager.editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.alb-sa.id}"
  ]
}

# Managed Service for Kubernetes cluster
resource "yandex_kubernetes_cluster" "k8s-cluster" {
  description = "Managed Service for Kubernetes cluster"
  name        = "k8s-cluster"

  service_account_id      = yandex_iam_service_account.k8s-sa.id # Cluster service account ID
  node_service_account_id = yandex_iam_service_account.k8s-sa.id # Node group service account ID

  network_id         = yandex_vpc_network.k8s-network.id
  cluster_ipv4_range = local.cluster_ipv4_cidr
  service_ipv4_range = local.service_ipv4_cidr

  master {
    master_location {
      zone      = yandex_vpc_subnet.subnet-a.zone
      subnet_id = yandex_vpc_subnet.subnet-a.id
    }
    security_group_ids = [
      yandex_vpc_security_group.k8s-cluster-nodegroup-traffic.id,
      yandex_vpc_security_group.k8s-cluster-traffic.id
    ]
    public_ip = true
  }

  depends_on = [
    yandex_resourcemanager_folder_iam_binding.k8s-clusters-agent,
    yandex_resourcemanager_folder_iam_binding.k8s-vpc-publicadmin
  ]
}

resource "yandex_kubernetes_node_group" "k8s-node-group" {
  description = "Node group for Managed Service for Kubernetes cluster"
  name        = "k8s-node-group"
  cluster_id  = yandex_kubernetes_cluster.k8s-cluster.id
  version     = local.k8s_version

  scale_policy {
    fixed_scale {
      size = 1 # Number of hosts
    }
  }

  allocation_policy {
    location {
      zone = yandex_vpc_subnet.subnet-a.zone
    }
  }

  instance_template {
    platform_id = "standard-v3"

    network_interface {
      nat        = true
      subnet_ids = [yandex_vpc_subnet.subnet-a.id]
      security_group_ids = [
        yandex_vpc_security_group.k8s-cluster-nodegroup-traffic.id,
        yandex_vpc_security_group.k8s-nodegroup-traffic.id,
        yandex_vpc_security_group.k8s-services-access.id,
        yandex_vpc_security_group.k8s-ssh-access.id,
        yandex_vpc_security_group.alb-k8s-nodegroup-traffic.id
      ]
    }

    resources {
      memory = 4 # RAM quantity in GB
      cores  = 4 # Number of CPU cores
    }

    boot_disk {
      type = "network-hdd"
      size = 64 # Disk size in GB
    }
  }
}

# Smart Web Security profile
resource "yandex_sws_security_profile" "sws-profile" {
  description    = "Security profile for the Application Load Balancer"
  name           = local.sws_name
  default_action = "DENY"

  security_rule {
    description = "Smart protection is enabled in full mode"
    name        = "default-sp-rule"
    priority    = 999900
    smart_protection {
      mode = "FULL"
    }
  }

  security_rule {
    description = "Traffic is allowed only from the specified IP address"
    name        = "test-rule1"
    priority    = 999800

    rule_condition {
      action = "ALLOW"

      condition {
        source_ip {
          ip_ranges_match {
            ip_ranges = local.allowed_ips
          }
        }
      }
    }
  }
}
