# Hawk Release

We published Hawk at the 16th IEEE International Conference on Cloud Computing 2023, IEEE Cloud 2023.
Please find our paper on Hawk here: https://arxiv.org/abs/2306.02496

## BibTex citation:
```
@misc{grünewald2023hawk,
      title={Hawk: DevOps-driven Transparency and Accountability in Cloud Native Systems}, 
      author={Elias Grünewald and Jannis Kiesel and Siar-Remzi Akbayin and Frank Pallas},
      year={2023},
      eprint={2306.02496},
      archivePrefix={arXiv},
      primaryClass={cs.DC}
}
```
## Overview

This repository contains all needed Kubernetes resources to set up a full-fledged GitOps-based CD pipeline with following features: 
* Automated cluster synchronization
* Service mesh + monitoring
* Canary releasing
* Secrets management 
* Image automation
* Notifications

Furthermore, it contains several configurations of the service mesh to create custom privacy-related metrics. 

## Flux setup

Flux is a tool which provides an operator for pull-based synchronization of infrastructure sources saved in git repositories, for instance, and the running Kubernetes cluster (visit https://fluxcd.io/flux/ for detailed information).

To install Flux in a GitHub repository export the following:
```shell
export GITHUB_USER=<<your-username>>
```
```shell
export GITHUB_REPOSITORY=<<your-repository>>
```
```shell
export GITHUB_BRANCH=<<your-branch>>
```

and then run the following command:
```shell
flux bootstrap github --components-extra=image-reflector-controller,image-automation-controller --owner=GITHUB_USER --repository=GITHUB_REPOSITORY --path=./flux --branch=GITHUB_BRANCH
```

## Flagger and Istio setup

Flagger provides different Kubernetes CRDs for realizing different release strategies. This project uses them for enabling canary releases.

To install Flagger with the needed CRDs using Helm run the following:
```shell
helm repo add flagger https://flagger.app
kubectl apply -f https://raw.githubusercontent.com/fluxcd/flagger/main/artifacts/flagger/crd.yaml
```
For the next step the command line tools of Istio (istioctl) are necessary (brew install istioctl).

Install Istio on the Kubernetes cluster with our custom configurations to enable the privacy-related metrics by running the following from the root dir:
```shell
cd istio/metrics
istioctl install -f IstioOperator.yaml -y
kubectl apply -f lua-destination-country-yaml
kubectl apply -f http-method-attribute.yaml
```
Now Flagger can be deployed for Istio:
```shell
helm upgrade -i flagger flagger/flagger --namespace=istio-system --set crd.create=false --set meshProvider=istio --set metricsServer=http://prometheus:9090
```

Navigate to the flagger folder and run the following to apply the MetricTemplates of Flagger:
```shell
kubectl appply -f flagger-metrics.yaml
```

Now all necessary tools to test the features mentioned above are set up. Some sources have to be customized (paths, webhooks, secrets etc.). We applied all tools to the Front End service in the apps folder exemplary.

## Other useful commands

To encrypt a Secret run the following from the root dir:
```shell
gpg --import secrets/.sops.pub.asc
```
Then navigate to the dir in which your file is stored and run:
```shell
sops --encrypt --in-place <<filename>>
```
