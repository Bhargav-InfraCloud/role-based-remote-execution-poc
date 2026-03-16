# ----------------
# Common Variables
# ----------------

AWS_REGION ?= us-east-2
AWS_PROFILE ?= default
PREFIX ?= bhargav

# ------------------
# SSH Key Management
# ------------------

SSH_KEY_PAIR_NAME = $(PREFIX)-ec2-runner-key
SSH_KEY_FILE = keys/$(SSH_KEY_PAIR_NAME).pem

ssh-key-create:
	aws ec2 create-key-pair \
		--key-name $(SSH_KEY_PAIR_NAME) \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
		--query 'KeyMaterial' \
		--output text > $(SSH_KEY_FILE)
	chmod 400 $(SSH_KEY_FILE)

ssh-key-delete:
	aws ec2 delete-key-pair \
		--key-name $(SSH_KEY_PAIR_NAME) \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) | cat
	rm -f $(SSH_KEY_FILE)

# -------------------------
# ECR Repository Management
# -------------------------

ECR_REPO_NAME = $(PREFIX)-ec2-runner
AWS_ACCOUNT_ID ?= $(shell aws sts get-caller-identity --query Account --output text --profile $(AWS_PROFILE))
DOCKER_IMAGE ?= $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com/$(PREFIX)-ec2-runner:latest

.PHONY: ecr-repo-create ecr-repo-delete ecr-repo-login

ecr-repo-login:
	aws ecr get-login-password \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) | \
		docker login \
			--username AWS \
			--password-stdin $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com

ecr-repo-create:
	aws ecr create-repository \
		--repository-name $(ECR_REPO_NAME) \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
		--image-scanning-configuration scanOnPush=true | cat

ecr-repo-delete:
	aws ecr delete-repository \
		--repository-name $(ECR_REPO_NAME) \
		--region $(AWS_REGION) \
		--profile $(AWS_PROFILE) \
		--force | cat

# -------------------------
# Docker Image Build & Push
# -------------------------

.PHONY: docker-build docker-push

docker-build:
	docker build -t $(DOCKER_IMAGE) ./docker

docker-push:
	docker push $(DOCKER_IMAGE)

# ---------------------
# IAM Policy Management
# ---------------------

POLICY_NAME = $(PREFIX)-user-runner-policy
POLICY_FILE = iam/role-based-remote-execution-user-policy.json
IAM_USER_NAME ?= BhargavSandbox

.PHONY: policy-create policy-attach policy-detach policy-delete policy-recreate

policy-recreate: policy-detach policy-delete policy-create policy-attach

policy-create:
	# Replace ${account_id} and ${prefix} in the policy document with actual values before creating the policy.
	TMP_POLICY_FILE=$$(mktemp /tmp/$(POLICY_NAME)-XXXXXX.json); \
	sed -e "s/<aws_account_id>/$(AWS_ACCOUNT_ID)/g" \
	    -e "s/<prefix>/$(PREFIX)/g" \
	    $(POLICY_FILE) > $$TMP_POLICY_FILE; \
	aws iam create-policy \
	    --policy-name $(POLICY_NAME) \
	    --policy-document file://$$TMP_POLICY_FILE \
	    --profile $(AWS_PROFILE) | cat; \
	rm -f $$TMP_POLICY_FILE

policy-attach:
	aws iam attach-user-policy \
		--user-name $(IAM_USER_NAME) \
		--policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(POLICY_NAME) \
		--profile $(AWS_PROFILE) | cat
	@echo "Policies attached to user $(IAM_USER_NAME):"
	aws iam list-attached-user-policies \
		--user-name $(IAM_USER_NAME) \
		--profile $(AWS_PROFILE) | cat

policy-detach:
	aws iam detach-user-policy \
		--user-name $(IAM_USER_NAME) \
		--policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(POLICY_NAME) \
		--profile $(AWS_PROFILE) | cat

policy-delete:
	aws iam delete-policy \
		--policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(POLICY_NAME) \
		--profile $(AWS_PROFILE) | cat

# ----------------------------
# Terraform: Runner Deployment
# ----------------------------

.PHONY: terraform-apply-runner terraform-destroy-runner

terraform-apply-runner:
	terraform -chdir=terraform/runner init
	terraform -chdir=terraform/runner plan -input=false
	terraform -chdir=terraform/runner apply -auto-approve

terraform-destroy-runner:
	terraform -chdir=terraform/runner destroy -auto-approve -refresh=true
	- rm -rf terraform/runner/.terraform \
		terraform/runner/.terraform.lock.hcl \
		terraform/runner/terraform.tfstate \
		terraform/runner/terraform.tfstate.backup

force-destroy-runner:
	- terraform -chdir=terraform/runner destroy -auto-approve -refresh=true
	- helm uninstall ec2-runner -n runner
	- kubectl delete namespace runner --ignore-not-found
	- aws iam detach-role-policy \
		--role-name $(PREFIX)-runner-role \
		--policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(PREFIX)-runner-policy \
		--profile $(AWS_PROFILE) | cat
	- aws iam delete-policy \
		--policy-arn arn:aws:iam::$(AWS_ACCOUNT_ID):policy/$(PREFIX)-runner-policy \
		--profile $(AWS_PROFILE) | cat
	- aws iam delete-role \
		--role-name $(PREFIX)-runner-role \
		--profile $(AWS_PROFILE) | cat
	- aws iam list-open-id-connect-providers \
		--query 'OpenIDConnectProviderList[].Arn' \
		--profile $(AWS_PROFILE) \
		--output text | \
		xargs -n1 -I {} sh -c 'aws iam list-open-id-connect-provider-tags \
			--open-id-connect-provider-arn {} \
			--profile $(AWS_PROFILE) | \
		jq -r ".Tags[] | select(.Key==\"Name\" and .Value==\"$(PREFIX)-runner-oidc\")" && echo {}' | \
		grep arn:aws:iam | \
		xargs -r -n1 aws iam delete-open-id-connect-provider \
			--open-id-connect-provider-arn {} \
			--profile $(AWS_PROFILE)
	- rm -rf terraform/runner/.terraform \
		terraform/runner/.terraform.lock.hcl \
		terraform/runner/terraform.tfstate \
		terraform/runner/terraform.tfstate.backup

# ----------------------------
# Terraform: Remote Deployment
# ----------------------------

.PHONY: terraform-apply-remote terraform-destroy-remote copy-repo-to-remote connect-remote

terraform-apply-remote:
	terraform -chdir=terraform/remote init
	terraform -chdir=terraform/remote plan -input=false
	terraform -chdir=terraform/remote apply -auto-approve


terraform-destroy-remote:
	terraform -chdir=terraform/remote destroy -auto-approve -refresh=true
	- rm -rf terraform/remote/.terraform \
		terraform/remote/.terraform.lock.hcl \
		terraform/remote/terraform.tfstate \
		terraform/remote/terraform.tfstate.backup

copy-repo-to-remote:
	ssh -i $(SSH_KEY_FILE) \
		ubuntu@$(shell terraform -chdir=terraform/remote output -raw public_ip) "mkdir -p ~/poc/terraform/"
	scp -i $(SSH_KEY_FILE) \
		-r helm ubuntu@$(shell terraform -chdir=terraform/remote output -raw public_ip):~/poc/
	scp -i $(SSH_KEY_FILE) \
		-r terraform/runner ubuntu@$(shell terraform -chdir=terraform/remote output -raw public_ip):~/poc/terraform/
	scp -i $(SSH_KEY_FILE) \
		Makefile ubuntu@$(shell terraform -chdir=terraform/remote output -raw public_ip):~/poc/

connect-remote:
	ssh -i $(SSH_KEY_FILE) ubuntu@$(shell terraform -chdir=terraform/remote output -raw public_ip)
