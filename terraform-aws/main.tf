
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    flux = {
      source = "fluxcd/flux"
    }
    github = {
      source  = "integrations/github"
      version = ">=5.18.0"
    }
  }
}
#provider "flux" {
#  kubernetes = {
#    config_path = "~/.kube/config"
#  }
#  git = {
#    url = "https://github.com/PrivacyEngineering/hawk-release"
#    http = {
#      username = var.github_org
#      password = var.github_token
#    }
#    branch = "master"
#    #    url  = "ssh://git@github.com/${var.github_org}/${var.github_repository}.git"
#    ##    url  = var.repository_ssh_url
#    #    ssh = {
#    #      username    = "git"
#    #      private_key = tls_private_key.flux.private_key_pem
#    #    }
#  }
#}

# Configure the AWS Provider
provider "aws" {
  region = "eu-central-1"
}

#output "endpoint" {
#  value = aws_eks_cluster.example.endpoint
#}
#
#output "kubeconfig-certificate-authority-data" {
#  value = aws_eks_cluster.example.certificate_authority[0].data
#}

#resource "aws_eks_cluster" "example" {
#  name     = "hawk-release"
#  role_arn = "arn:aws:iam::471472241282:role/eksClusterRole"
#
#  vpc_config {
#    subnet_ids = ["subnet-0cf8af7fb83e9214c", "subnet-099b18565de436a67", "subnet-002f1b128ecb07d50"]
#  }
#
#  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
#  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
#  #  depends_on = [
#  #    aws_iam_role_policy_attachment.example-AmazonEKSClusterPolicy,
#  #    aws_iam_role_policy_attachment.example-AmazonEKSVPCResourceController,
#  #  ]
#}
#
#resource "aws_eks_node_group" "example" {
#  cluster_name    = aws_eks_cluster.example.name
#  node_group_name = "default"
#  node_role_arn   = "arn:aws:iam::471472241282:role/AmazonEKSNodeRole"
#  subnet_ids      = ["subnet-0cf8af7fb83e9214c", "subnet-099b18565de436a67", "subnet-002f1b128ecb07d50"]
#
#  scaling_config {
#    desired_size = 1
#    max_size     = 2
#    min_size     = 1
#  }
#
#  update_config {
#    max_unavailable = 1
#  }
#
#  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
#  # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
#  depends_on = [
#    aws_eks_cluster.example
#  ]
#}
resource "aws_security_group" "my-security-group" {
  name        = "my-security-group"
  description = "Allow inbound all TCP traffic and outbound all traffic"

  ingress {
    from_port = 0
    to_port   = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "hawk-release"
  cluster_version = "1.28"

  subnet_ids      = ["subnet-0cf8af7fb83e9214c", "subnet-099b18565de436a67", "subnet-002f1b128ecb07d50"]
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }

  eks_managed_node_groups = {
    one = {
      name = "default"

      instance_types = ["t3.large"]
      min_size     = 1
      max_size     = 8
      desired_size = 2

      vpc_security_group_ids = [aws_security_group.my-security-group.id]
    }
  }
}

resource "null_resource" "fetch_aws_endpoint" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "aws eks update-kubeconfig --name hawk-release --region eu-central-1"
  }
  depends_on = [
    module.eks
  ]
}

resource "null_resource" "install_istio" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "istioctl install -f ../istio/metrics/IstioOperator.yaml -y"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../istio/ "
  }
  depends_on = [
    module.eks, null_resource.fetch_aws_endpoint
  ]
}

resource "null_resource" "apply_sock-shop_ns" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f ../apps/namespace.yaml"
  }
  depends_on = [
    module.eks, null_resource.fetch_aws_endpoint, null_resource.install_istio
  ]
}


resource "null_resource" "install_flagger" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "helm repo add flagger https://flagger.app"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "helm upgrade -i flagger flagger/flagger --namespace=istio-system --set crd.create=false --set meshProvider=istio --set metricsServer=http://prometheus:9090"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../flagger/"
  }
  depends_on = [
    null_resource.install_istio, module.eks, null_resource.fetch_aws_endpoint
  ]
}

resource "null_resource" "apply_prometheus_and_kiali" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../flagger/ && kubectl apply -k ../flagger/metrics/"
  }
  depends_on = [
    module.eks, null_resource.fetch_aws_endpoint, null_resource.install_istio, null_resource.install_flagger
  ]
}

#resource "null_resource" "create_hawk_namespace" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl create namespace hawk-ns"
#  }
#  depends_on = [
#    module.eks, null_resource.fetch_aws_endpoint, null_resource.install_istio
#  ]
#}
#resource "null_resource" "install_flux" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "flux install --components-extra image-reflector-controller,image-automation-controller"
#  }
#  depends_on = [
#    module.eks, null_resource.fetch_aws_endpoint, null_resource.install_istio
#  ]
#}
#
##resource "flux_bootstrap_git" "this" {
##  path = "clusters"
##  components_extra = ["image-automation-controller", "image-reflector-controller"]
##  depends_on = [
##    github_repository_deploy_key.this
##  ]
##}
#
#resource "null_resource" "apply_flux_resources_1" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ../clusters/flux-system/"
#  }
#  depends_on = [
##    github_repository_deploy_key.this,
#    null_resource.install_flux, module.eks, null_resource.fetch_aws_endpoint
#  ]
#}
#
#resource "null_resource" "apply_flux_resources_2" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ../clusters/"
#  }
#  depends_on = [
##    github_repository_deploy_key.this,
#    null_resource.install_flux, module.eks, null_resource.fetch_aws_endpoint
#  ]
#}
#
#
resource "null_resource" "apply_deployment" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f ../apps/namespace.yaml"
  }
  depends_on = [
    module.eks, null_resource.install_istio, null_resource.fetch_aws_endpoint, null_resource.install_flagger, null_resource.apply_sock-shop_ns, null_resource.apply_prometheus_and_kiali
#    null_resource.apply_flagger, null_resource.install_flux, null_resource.apply_flux_resources_2
  ]
}

#resource "null_resource" "install_opa_gatekeeper" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts && helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace"
#  }
#  depends_on = [
#    module.eks, null_resource.install_istio, null_resource.apply_flagger, null_resource.install_flux,
#    null_resource.fetch_aws_endpoint, null_resource.apply_deployment
#  ]
#}
#
#resource "null_resource" "apply_opa_templates" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -f ../gatekeeper-policies/templates/complex-template.yaml"
#  }
#  depends_on = [
#    module.eks, null_resource.install_istio, null_resource.apply_flagger, null_resource.install_flux,
#    null_resource.fetch_aws_endpoint, null_resource.apply_deployment, null_resource.install_opa_gatekeeper
#  ]
#}
#
#resource "null_resource" "apply_opa_constraints" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -f ../gatekeeper-policies/constraints/complex-constraint.yaml"
#  }
#  depends_on = [
#    module.eks, null_resource.install_istio, null_resource.apply_flagger, null_resource.install_flux,
#    null_resource.fetch_aws_endpoint, null_resource.apply_deployment, null_resource.install_opa_gatekeeper,
#    null_resource.apply_opa_templates
#  ]
#}
#
##resource "null_resource" "wait_conditions" {
##  provisioner "local-exec" {
##    interpreter = ["bash", "-exc"]
##    command = "kubectl wait --for=condition=ready pods --all -n sock-shop --timeout=-1s 2> /dev/null"
##  }
##
##  depends_on = [
##    module.eks, null_resource.install_istio, null_resource.apply_flagger, null_resource.install_flux,
##    null_resource.fetch_aws_endpoint, null_resource.apply_deployment, null_resource.install_opa_gatekeeper,
##    null_resource.apply_opa_templates
##  ]
##}

