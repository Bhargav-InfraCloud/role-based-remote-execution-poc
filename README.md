# Role-Based Remote Execution - Exostellar Terraform Modules Existing-Cluster-Flow AMI-Base

## Prerequisites

- AWS CLI configured
- kubectl configured for your cluster
- Terraform installed
- Helm installed
- IAM user with permissions to create and manage policies

## Step 1: Generate SSH Key Pair

Generate an SSH key pair for EC2 instance access, and place the private key in [keys/](./keys/):

```sh
make ssh-key-create
```

## Step 2: Deploy Remote EC2 Instance

Update the Terraform module if needed: `./terraform/remote/main.tf`

Then deploy:

```sh
make terraform-apply-remote
```

## Step 3: Deploy Existing-Cluster-Flow AMI-Base Module on Remote EC2

SSH into the remote EC2 instance:

```sh
make connect-remote
```

Then deploy the runner application:

```sh
cd ~/terraform-exostellar-modules
terraform -chdir=./examples/existing-cluster-flow/ami-base init
terraform -chdir=./examples/existing-cluster-flow/ami-base plan -input=false
terraform -chdir=./examples/existing-cluster-flow/ami-base apply -auto-approve
```

## Step 4: Clean Up

### On Remote EC2 Instance

```sh
cd ~/terraform-exostellar-modules
terraform -chdir=./examples/existing-cluster-flow/ami-base destroy -auto-approve -refresh=true
```

### Locally

```sh
make terraform-destroy-remote
make ssh-key-delete
```
