# GCP Setup with Terraform

To simplify the setup of the infrastructure in the GCP, we provide Terraform files.
## Prerequirements
•	The Terraform cli needs to be installed (https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

•	Authentication to your GCP project either through this command  
```shell
gcloud auth application-default login
``` 
or by Providing a service account json as an environment variable (run it in the dir with the json file):
```shell
export GOOGLE_CREDENTIALS="$(cat <<your json file>>)"
``` 
or any other method

## Start

First of all export your GCP project ID:
```shell
export GCP_PROJECT_ID=<<your-project-id>>
```
Then run the following command to apply your project-id:
```shell
awk -v new_value="$GCP_PROJECT_ID" '/gcp_project_id/ {sub(/"toucan-378111"/, "\"" new_value "\"")} 1' ./terraform/terraform.tfvars > temp.tfvars && mv temp.tfvars ./terraform/terraform.tfvars
```
Now remove the project specific terraform backend:
```shell
awk '/^ *cloud {/,/^ *} *$/ { if (NR <= FNR + 6) next } 1' terraform/main.tf > temp && mv temp terraform/main.tf
```

The provided Terraform files can now used to create your Kubernetes cluster in your GCP project.

Navigate to the terraform folder (cd terraform) and run the following commands:
```shell
terraform init
```
```shell
terraform apply
```
Check the plan and if it is according to expectations type "yes" and enter.

Now your cluster will be created which can take a couple of minutes.

The cluster has the following settings:
•	Location: us-central1-c

•	Number of nodes: 3

•	Total vCPUs: 24

•	Total memory: 90GB


•	Location type: Zonal

•	Machine type: n1-standard-8
