# AWS Setup with Terraform

To simplify the setup of the infrastructure in AWS, we provide Terraform files. This configuration will not apply the image
automation configuration of Flux. 

## Prerequirements
•   The terraform cli needs to be installed (https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

•   The flux cli needs to be installed (https://fluxcd.io/flux/installation/#install-the-flux-cli)

•   The istioctl cli needs to be installed (https://istio.io/latest/docs/setup/getting-started/#download)

•   The aws cli needs to be installed (https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions)

•   The kubectl cli needs to be installed (https://kubernetes.io/docs/tasks/tools/#kubectl)

•   The helm cli needs to be installed (https://helm.sh/docs/intro/install/)

## Start
First of all change the following default values in the variable.tf for your needs:
repository_ssh_url, github_org, github_repository, branch and target_path. You might also want to change the AWS region, machine type etc.

Export your GitHub personal access token with repo (and packages, if you want to use the image automation feature) scope:
```shell
export GITHUB_TOKEN=<your token>
```

The provided Terraform files can now be used to create your Kubernetes cluster in your AWS project.

Navigate to the terraform-aws folder and run the following commands:
```shell
terraform init
```
```shell
terraform apply -target=aws_security_group.my-security-group -var="github_token=$GITHUB_TOKEN" -auto-approve &&  terraform apply -var="github_token=$GITHUB_TOKEN -auto-approve
```

Now your cluster will be created which can take up to 20 minutes.

The cluster has the following settings:
•	Region: eu-central-1

•	The security group will allow all inbound TCP traffic and all outbound traffic

•	Instance type: t3.large

•   Node group size: min_size=1, max_size=4, desired_size=2

## Secret Management
Create the following secrets to make the notifications work without using Flux for the secrets management:
github-credentials - you can use a YAML file or run this command:
```shell
kubectl -n flux-system create secret generic github-credentials \
--from-literal=username=<your username> \
--from-literal=password=<your pat or password> \
--dry-run=client 
```
discord-flagger-webhook

discord-flux-webhook

webhook-token.

If you want to use the Mozilla Sops secret management with Flux you will need to do the following steps:
Install the gpg cli (with Homebrew: brew install gnupg sops).
Run:
```shell
export KEY_NAME="privacy-with-canary-sops"
export KEY_COMMENT="flux secrets"
```
Create the key:
```shell
gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
EOF
```
List the keys:
```shell
gpg --list-secret-keys "${KEY_NAME}"
```
Export the key fingerprint (40 digits string):
```shell
export KEY_FP=<your key fp>
```
Navigate to the secrets directory and run the following command to create the corresponding secret:
```shell
gpg --export-secret-keys --armor "${KEY_FP}" |
kubectl create secret generic sops-gpg \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin
```
Delete the key after saving it securely:
```shell
gpg --delete-secret-keys "${KEY_FP}"
```

To store secrets securely in you repository follow the following instructions

Run:
```shell
gpg --export --armor "${KEY_FP}" > ./secrets/.sops.pub.asc
```
```shell
git add ./secrets/.sops.pub.asc
```
```shell
gpg --import ./secrets/.sops.pub.asc
```
```shell
cat <<EOF > ./secrets/.sops.yaml
creation_rules:
- path_regex: .*.yaml
  encrypted_regex: ^(data|stringData)$
  pgp: ${KEY_FP}
  EOF
```

Now you can create you secret YAML files and encrypt them by running:
```shell
sops --encrypt --in-place <filename.yaml>
```

They will now be decrypted and applied by Flux automatically.

## Cleanup
For destroying the resources created by terraform run the following command:
```shell
terraform destroy -var="github_token=$GITHUB_TOKEN" -auto-approve
```

Careful! The terraform script will create one or more AWS load balancers which will not get deleted by the terraform 
destroy command. You will need to destroy them with the UI (EC2).


## Useful commands
Check if Flux resources are running/working: 
```shell
flux get all
```

Check for Flagger logs during the canary release process: 
```shell
kubectl -n istio-system logs deploy/flagger -f | jq .msg
```

Open Kiali, Grafana or Prometheus dashboard:
```shell
istioctl dashboard kiali
```
```shell
istioctl dashboard prometheus
```
```shell
istioctl dashboard grafana
```

Open the Envoy dashboard:
```shell
istioctl dash envoy deploy/<deployment-name>
```