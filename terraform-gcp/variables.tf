# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
variable "gcp_project_id" {
  type        = string
  description = "The GCP project ID to apply this config to"
}

variable "name" {
  type        = string
  description = "Name given to the new GKE cluster"
  default     = "sock-shop"
}

variable "region" {
  type        = string
  description = "Region of the new GKE cluster"
  default     = "us-east1"
}

variable "zone" {
  type        = string
  description = "Region of the new GKE cluster"
  default     = "us-east1-c"
}

variable "namespace_sock_shop" {
  type        = string
  description = "Kubernetes Namespace in which the Sock Shop resources are to be deployed"
  default     = "sock-shop"
}
variable "namespace_istio" {
  type        = string
  description = "Kubernetes Namespace in which the Istio resources are to be deployed"
  default     = "istio-system"
}

variable "namespace_flux" {
  type        = string
  description = "Kubernetes Namespace in which the Flux resources are to be deployed"
  default     = "flux-system"
}

variable "filepath_sock_shop_namespace" {
  type        = string
  description = "Path to Sock Shop's Kubernetes resources, written using Kustomize"
  default     = "../apps/namespace.yaml"
}

variable "filepath_sock_shop" {
  type        = string
  description = "Path to Sock Shop's Kubernetes resources, written using Kustomize"
  default     = "../apps/"
}

variable "filepath_istio" {
  type        = string
  description = "Path to Sock Shop's Kubernetes resources, written using Kustomize"
  default     = "../istio"
}

variable "node_count" {
  description = "Number of nodes (VMs) after creating the container"
  type        = number
  default = 1
}

variable "repository_ssh_url" {
  description = "hawk-release GitHub repository ssh url"
  type = string
  default = "git@github.com:PrivacyEngineering/hawk-release.git"
}

variable "github_org" {
  description = "GitHub organization name"
  type = string
  default = "PrivacyEngineering"
}

variable "github_repository" {
  description = "GitHub repository name"
  type = string
  default = "hawk-release"
}

variable "github_token" {
  description = "GitHub token"
  type = string
  default = "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"
}