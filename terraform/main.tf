
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.56.0"
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

provider "google" {
  project     = var.gcp_project_id
  region      = var.region
  zone        = var.zone
}

provider "google-beta" {
  project     = var.gcp_project_id
  region      = var.region
  zone        = var.zone
}

provider "flux" {
  kubernetes = {
    config_path = "~/.kube/config"
  }
  git = {
    url = "https://github.com/PrivacyEngineering/hawk-release"
    http = {
      username = var.github_org
      password = var.github_token
    }
    branch = "master"
#    url  = "ssh://git@github.com/${var.github_org}/${var.github_repository}.git"
##    url  = var.repository_ssh_url
#    ssh = {
#      username    = "git"
#      private_key = tls_private_key.flux.private_key_pem
#    }
  }
}

module "enable_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.0"

  project_id                  = var.gcp_project_id
  disable_services_on_destroy = false

  activate_apis = [
    "container.googleapis.com",
  ]
}

## Create GKE cluster
resource "google_container_cluster" "sock-shop" {
  name               = "sock-shop"
  location           = var.region
  ip_allocation_policy {}
  node_pool {
    initial_node_count = var.node_count
    node_config {
      image_type = "COS_CONTAINERD"
      machine_type = "n1-standard-8"
      #     service_account = google_service_account.default.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
  depends_on = [
    module.enable_google_apis
  ]
}

module "gcloud" {
  source  = "terraform-google-modules/gcloud/google"
  version = "3.1.2"
  platform = "linux"
  use_tf_google_credentials_env_var = true

  additional_components = ["kubectl", "beta"]
  create_cmd_entrypoint = "gcloud"
  create_cmd_body      = "container clusters get-credentials ${google_container_cluster.sock-shop.name} --zone=${var.region} --project=${var.gcp_project_id}"
  module_depends_on = [
    google_container_cluster.sock-shop
  ]
}

resource "null_resource" "install_istio" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "istioctl install -y"
  }
  depends_on = [
    module.gcloud, google_container_cluster.sock-shop
  ]
}

resource "null_resource" "apply_flagger" {
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
  depends_on = [
    module.gcloud, null_resource.install_istio
  ]
}

resource "null_resource" "create_hawk_namespace" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl create namespace hawk-ns"
  }
  depends_on = [
    module.gcloud, google_container_cluster.sock-shop
  ]
}

resource "flux_bootstrap_git" "this" {
  path = "clusters"
  components_extra = ["image-automation-controller", "image-reflector-controller"]
  depends_on = [
    github_repository_deploy_key.this, google_container_cluster.sock-shop, module.gcloud
  ]
}

resource "null_resource" "apply_flux_resources" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../clusters/"
  }
  depends_on = [
    github_repository_deploy_key.this, google_container_cluster.sock-shop, module.gcloud, flux_bootstrap_git.this
  ]
}


#
#resource "null_resource" "apply_istio" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ${var.filepath_istio} -n istio-system"
#  }
#  depends_on = [
#    module.gcloud, null_resource.install_istio
#  ]
#}
#
#
#resource "null_resource" "apply_deployment" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl apply -k ../apps -n sock-shop"
#  }
#  depends_on = [
#    module.gcloud, null_resource.apply_istio, null_resource.apply_flagger
#  ]
#}
#
#resource "null_resource" "wait_conditions" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command = "kubectl wait --for=condition=ready pods --all -n sock-shop --timeout=-1s 2> /dev/null"
#  }
#
#  depends_on = [
#    module.gcloud, null_resource.apply_deployment
#  ]
#}

