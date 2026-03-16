# Role-Based Remote Execution POC

## Prerequisites

- AWS CLI configured
- kubectl configured for your cluster
- Terraform installed
- Helm installed
- IAM user with permissions to create and manage policies

## Step 1: IAM Policy Setup

Create and attach the minimal IAM policy [role-based-remote-execution-user-policy.json][user-policy-path] to your IAM
user:

```sh
make policy-create
make policy-attach
```

This will:
1. Create the IAM policy in AWS from [role-based-remote-execution-user-policy.json][user-policy-path].
2. Attach the policy to your IAM user.
3. List all policies attached to your IAM user.

> [!NOTE]
> After attaching policy to IAM user, this step will list all attached policies on your user. Manually remove any
> unnecessary policies before proceeding with Terraform.

## Step 2: ECR Repository and Docker Image

### Create ECR Repository

Creates a private ECR repository for storing Docker images:

```sh
make ecr-repo-create
```

### Authenticate Docker with ECR

Authenticate Docker with your ECR repository:

```sh
make ecr-repo-login
```

### Build and Push Docker Image

Build the Docker image for the runner application from [docker/](./docker/), and push it to your ECR repository:

```sh
make docker-build
make docker-push
```

## Step 3: Generate SSH Key Pair

Generate an SSH key pair for EC2 instance access, and place the private key in [keys/](./keys/):

```sh
make ssh-key-create
```

## Step 4: Deploy Remote EC2 Instance

Update the Terraform module if needed: `./terraform/remote/main.tf`

Then deploy:

```sh
make terraform-apply-remote
```

## Step 5: Copy Project Files to Remote EC2

```sh
make copy-repo-to-remote
```

## Step 6: Deploy Runner Application on Remote EC2

SSH into the remote EC2 instance:

```sh
make connect-remote
```

Then deploy the runner application:

```sh
cd ~/poc
make terraform-apply-runner
```

## Step 7: Clean Up

### On Remote EC2 Instance

```sh
make terraform-destroy-runner
```

### Locally

```sh
make terraform-destroy-remote
make ssh-key-delete
make policy-detach
make policy-delete
make ecr-repo-delete
```

---

[user-policy-path]: iam/role-based-remote-execution-user-policy.json
