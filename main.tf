# 指定 Terraform 和 Yandex Provider 的版本要求
terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

# 配置 Yandex Provider
provider "yandex" {
  token     = var.yc_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
}


# 1. 创建一个虚拟私有云 (VPC) 网络
resource "yandex_vpc_network" "ctf_net" {
  name = "ctf-network"
}

# 2. 在 VPC 中创建一个子网
resource "yandex_vpc_subnet" "ctf_subnet" {
  name           = "ctf-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.ctf_net.id
  v4_cidr_blocks = ["10.1.0.0/16"]
}

# 3. 为 K8s 集群和节点创建一个专用的服务账户
resource "yandex_iam_service_account" "k8s_sa" {
  name = "k8s-cluster-and-node-sa"
}

# 4. 为该服务账户绑定所有必要的角色权限 
# 允许拉取镜像
resource "yandex_resourcemanager_folder_iam_binding" "puller" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.puller"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# 允许推送镜像 (用于 CI/CD)
resource "yandex_resourcemanager_folder_iam_binding" "pusher" {
  folder_id = var.yc_folder_id
  role      = "container-registry.images.pusher"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# K8s 集群和节点运行所需的核心权限
resource "yandex_resourcemanager_folder_iam_binding" "k8s_agent" {
  folder_id = var.yc_folder_id
  role      = "k8s.clusters.agent"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# 允许 Ingress Controller 创建负载均衡器
resource "yandex_resourcemanager_folder_iam_binding" "load_balancer_admin" {
  folder_id = var.yc_folder_id
  role      = "load-balancer.admin"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# 允许 K8s 分配公网 IP
resource "yandex_resourcemanager_folder_iam_binding" "vpc_public_admin" {
  folder_id = var.yc_folder_id
  role      = "vpc.publicAdmin"
  members   = ["serviceAccount:${yandex_iam_service_account.k8s_sa.id}"]
}

# 5. 创建一个容器镜像仓库
resource "yandex_container_registry" "ctf_registry" {
  name = "ctf-main-registry"
}

# 6. 创建一个 Managed Kubernetes 集群 (控制平面)
resource "yandex_kubernetes_cluster" "ctf_k8s_cluster" {
  name        = "ctf-k8s-cluster"
  network_id  = yandex_vpc_network.ctf_net.id
  
  # Master 节点的配置
  master {
    zonal {
      zone      = yandex_vpc_subnet.ctf_subnet.zone
      subnet_id = yandex_vpc_subnet.ctf_subnet.id
    }
    public_ip = true # 允许从外部访问 K8s API，方便 kubectl 连接
  }
  
  # 绑定我们之前创建的服务账户
  service_account_id      = yandex_iam_service_account.k8s_sa.id
  node_service_account_id = yandex_iam_service_account.k8s_sa.id
}

# 7. 创建一个节点组 (工作节点)
resource "yandex_kubernetes_node_group" "ctf_node_group" {
  cluster_id = yandex_kubernetes_cluster.ctf_k8s_cluster.id
  name       = "ctf-worker-nodes"
  
  # 定义节点的规模（1个节点）
  scale_policy {
    fixed_scale {
      size = 2
    }
  }
  
  # 定义节点的硬件和软件配置
  instance_template {
    platform_id = "standard-v3" # 这是一个常见的平台 ID
    
    # 节点的计算资源
    resources {
      memory = 8  # 2GB 内存
      cores  = 2  # 2 核 CPU (最小配置)
    }
    
    # 节点的启动磁盘
    boot_disk {
      type = "network-hdd"
      size = 32 # 32GB 硬盘
    }

    network_interface {
      nat                = true
      subnet_ids         = [yandex_vpc_subnet.ctf_subnet.id]
      security_group_ids = [yandex_vpc_security_group.k8s_node_sg.id]
    }

    # 使用可抢占式实例以节省成本，符合作业建议 
    scheduling_policy {
      preemptible = true
    }

  }
}

# 11. 创建一个新的安全组
resource "yandex_vpc_security_group" "k8s_node_sg" {
  name       = "k8s-nodes-sg"
  network_id = yandex_vpc_network.ctf_net.id

  # 允许所有出站流量 (Egress)，这是解决 ErrImagePull 的关键！
  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  # 允许必要的入站流量 (Ingress)
  ingress {
    protocol       = "ANY"
    # 允许来自同一安全组内其他节点的流量
    predefined_target = "self_security_group"
    description    = "Allow traffic from other nodes in the same security group"
  }

  ingress {
    protocol       = "TCP"
    # 允许来自 K8s 控制平面的流量 (用于管理和健康检查)
    v4_cidr_blocks = ["0.0.0.0/0"] # 为简化，这里允许所有来源，生产环境应设为 K8s Master 的地址段
    from_port      = 0
    to_port        = 65535
    description    = "Allow health checks and control plane traffic"
  }
}