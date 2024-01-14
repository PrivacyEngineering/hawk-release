
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

#provider "helm" {
#  kubernetes {
#    config_path = "~/.kube/config"
#  }
#}
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

#provider "flux" {
#  kubernetes = {
#    config_path = "~/.kube/config"
#  }
#  git = {
#    url = "ssh://git@github.com/${var.github_org}/${var.github_repository}.git"
#    ssh = {
#      username = "git"
#      private_key = tls_private_key.flux.private_key_pem
#    }
#    branch = var.branch
#  }
#}

#resource "tls_private_key" "flux" {
#  algorithm   = "ECDSA"
#  ecdsa_curve = "P256"
#}

#provider "github" {
#  owner = var.github_org
#  token = var.github_token
#}

#resource "github_repository_deploy_key" "this" {
#  title      = "Flux"
#  repository = var.github_repository
#  key        = tls_private_key.flux.public_key_openssh
#  read_only  = "false"
#}

#output "endpoint" {
#  value = aws_eks_cluster.example.endpoint
#}
#
#output "kubeconfig-certificate-authority-data" {
#  value = aws_eks_cluster.example.certificate_authority[0].data
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

#output "security_group_id" {
#  value = aws_security_group.my-security-group.id
#  depends_on = [aws_security_group.my-security-group]
#}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = "hawk-release"
  cluster_version = "1.28"

  vpc_id = "vpc-0f2d9adf03961f221"
  subnet_ids      = ["subnet-028b97041fb0039d2", "subnet-0692049a797200744", "subnet-08caccd9e5f668d89"]
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
    instance_types = ["t3.large"]
  }

  eks_managed_node_groups = {
    one = {
      name = "default"

      instance_types = ["t3.large"]
      min_size     = 1
      max_size     = 4
      desired_size = 2

      vpc_security_group_ids = [aws_security_group.my-security-group.id]
    }
  }
  depends_on = [aws_security_group.my-security-group]
}

resource "terraform_data" "fetch_aws_endpoint" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "aws eks update-kubeconfig --name hawk-release --region eu-central-1"
  }
  depends_on = [module.eks]
}

resource "terraform_data" "apply_sock-shop_ns" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f ../apps/namespace.yaml"
  }
  depends_on = [terraform_data.fetch_aws_endpoint]
}

resource "terraform_data" "install_istio" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "istioctl install -f ../istio/metrics/IstioOperator.yaml -y"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../istio/ "
  }
  depends_on = [terraform_data.apply_sock-shop_ns]
}

data "external" "istio_ingress_ip" {
  program = ["bash", "-c", "kubectl get svc -n istio-system istio-ingressgateway -o json | jq -n '{ ingress_gateway_ip: input.status.loadBalancer.ingress[0].hostname }'"]
  depends_on = [terraform_data.install_istio]
}

output "istio_ingress_gateway_ip" {
  value = data.external.istio_ingress_ip.result.ingress_gateway_ip
  depends_on = [data.external.istio_ingress_ip]
}


resource "terraform_data" "install_flagger" {
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
  depends_on = [terraform_data.install_istio]
}

resource "terraform_data" "apply_prometheus_and_kiali" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../flagger/ && kubectl apply -k ../flagger/metrics/"
  }
  depends_on = [terraform_data.install_flagger]
}

#resource "terraform_data" "create_hawk_namespace" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl create ns hawk-ns"
#  }
#  depends_on = [terraform_data.apply_prometheus_and_kiali]
#}

resource "terraform_data" "install_nginx_ingress" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/aws/deploy.yaml"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "sleep 30"
  }
  depends_on = [terraform_data.apply_prometheus_and_kiali]
}

data "external" "nginx_ingress_ip" {
  program = ["bash", "-c", "kubectl get svc -n ingress-nginx ingress-nginx-controller -o json | jq -n '{ ingress_gateway_ip: input.status.loadBalancer.ingress[0].hostname }'"]
  depends_on = [terraform_data.install_nginx_ingress]
}

output "nginx_ingress_gateway_ip" {
  value = data.external.nginx_ingress_ip.result.ingress_gateway_ip
  depends_on = [data.external.nginx_ingress_ip]
}

resource "terraform_data" "install_hawk" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "helm repo add hawk https://privacyengineering.github.io/hawk-helm-charts/"
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "helm install hawk hawk/hawk --namespace hawk-ns --set ingress.host=\"\" --set monitor.apiUrl=\"\" --create-namespace"
  }
  depends_on = [terraform_data.install_nginx_ingress]
}

resource "terraform_data" "install_flux" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "flux install --components-extra image-reflector-controller,image-automation-controller"
  }
  depends_on = [terraform_data.install_hawk]
}

## Flux bootstrap
#resource "flux_bootstrap_git" "this" {
#  path = var.target_path
#  components_extra = ["image-reflector-controller", "image-automation-controller"]
#  interval = "10m0s"
#  depends_on = [null_resource.install_flux]
#}

resource "terraform_data" "bootstrap_repo" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "export GITHUB_TOKEN=${var.github_token} && flux bootstrap github --components-extra=image-reflector-controller,image-automation-controller --owner=${var.github_org} --repository=${var.github_repository} --path=${var.target_path} --branch=${var.branch}"
  }
  depends_on = [terraform_data.fetch_aws_endpoint, terraform_data.install_flux]
}

#resource "flux_bootstrap_git" "this" {
#  path = "clusters"
#  components_extra = ["image-automation-controller", "image-reflector-controller"]
#  depends_on = [
#    github_repository_deploy_key.this
#  ]
#}

#resource "terraform_data" "apply_flux_resources" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ../clusters/sock-shop/"
#  }
#  depends_on = [terraform_data.install_flux]
#}


#resource "terraform_data" "apply_deployment" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ../apps/"
#  }
#  depends_on = [terraform_data.bootstrap_repo]
#}

resource "terraform_data" "install_opa_gatekeeper" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts && helm install gatekeeper/gatekeeper --name-template=gatekeeper --namespace gatekeeper-system --create-namespace"
  }
  depends_on = [terraform_data.bootstrap_repo]
}

resource "terraform_data" "apply_opa_templates" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f ../gatekeeper-policies/templates/db-us-template.yaml"
  }
  depends_on = [terraform_data.install_opa_gatekeeper]
}

resource "terraform_data" "apply_opa_constraints" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -f ../gatekeeper-policies/constraints/db-us-constraint.yaml"
  }
  depends_on = [terraform_data.apply_opa_templates]
}
