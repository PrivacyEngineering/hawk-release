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

## AWS setup instructions
https://github.com/PrivacyEngineering/hawk-release/tree/master/terraform-aws

## GCP setup instructions
https://github.com/PrivacyEngineering/hawk-release/tree/master/terraform-gcp