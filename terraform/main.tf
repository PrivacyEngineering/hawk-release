
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.56.0"
    }
  }
}

provider "google" {
  project     = "toucan-378111"
  region      = "us-east1"
  zone        = "us-east1-c"
  credentials = "toucan-378111-ca4ae827f2b9.json"
}

provider "google-beta" {
  project     = var.gcp_project_id
  region      = var.region
  zone        = var.zone
  credentials = "toucan-378111-ca4ae827f2b9.json"
}

module "enable_google_apis" {
  source  = "terraform-google-modules/project-factory/google//modules/project_services"
  version = "~> 14.0"

  project_id                  = "toucan-378111"
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
  depends_on = [
    google_container_cluster.sock-shop
  ]
}

# Apply sock-shop namespace
#resource "null_resource" "apply_namespace" {
#  provisioner "local-exec" {
#    interpreter = ["bash", "-exc"]
#    command     = "kubectl apply -f ${var.filepath_sock_shop_namespace}"
#  }
#}

resource "null_resource" "apply_deployment" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl apply -k ../apps -n sock-shop"
  }

  depends_on = [
    module.gcloud
  ]
}

resource "null_resource" "wait_conditions" {
  provisioner "local-exec" {
    interpreter = ["bash", "-exc"]
    command = "kubectl wait --for=condition=ready pods --all -n sock-shop --timeout=-1s 2> /dev/null"
  }

  depends_on = [
    null_resource.apply_deployment
  ]
}

